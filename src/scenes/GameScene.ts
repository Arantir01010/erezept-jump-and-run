import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import type { LevelConfig } from '../level/schema'
import { Player } from '../player/Player'
import { Rezi } from '../actors/Rezi'
import { spawnMechanic, type MechanicHost, Gate } from '../mechanics'
import type { Mechanic } from '../mechanics'
import { gameState } from '../state/GameState'
import { drawBackdrop } from '../gfx/backdrop'
import { addSpeedStreaks } from '../gfx/effects'
import { inputManager } from '../input/InputManager'
import { VIEW_ZOOM } from '../gfx/view'
import { t } from '../i18n'
import type { LText } from '../i18n'

/** Kein Streckenfortschritt trotz Eingaben → genereller REZI-Schubs. */
const STUCK_AFTER_MS = 18_000
const STUCK_REPEAT_MS = 20_000

/**
 * Ein Stationslevel. Alles Inhaltliche kommt aus Level-JSON + Tilemap —
 * die Szene kennt nur den Baukasten und die Kameramodi.
 *
 * Kameramodi im Prototyp: 'horizontal' (Follow) und 'tube' (Auto-Scroll-Korridor;
 * Scroll pausiert an Sicherheits-Stationen via ScrollLocks). 'vertical', 'chamber'
 * und 'sprint' fallen bis zur Ausbaustufe auf 'horizontal' zurück.
 */
export class GameScene extends Phaser.Scene {
  player!: Player
  rezi!: Rezi
  level!: LevelConfig
  gates = new Map<string, Gate>()

  private levelIndex = 0
  private mechanics: Mechanic[] = []
  private scrollLocks: (() => boolean)[] = []
  private completed = false
  private tubeSpeed = 0
  /** Float-Akkumulator: roundPixels rundet cam.scrollX — Sub-Pixel-Zuwächse
   *  (55 px/s ≈ 0,92 px/Frame) würden sonst jeden Frame weggerundet. */
  private tubeScrollX = 0
  private mapWidth = 0
  /** Festhäng-Erkennung: weitester Fortschritt + Zeitpunkte für den Generaltipp. */
  private maxProgressX = 0
  private lastProgressMs = -1
  private lastStuckTipMs = -Infinity

  constructor() {
    super('Game')
  }

  init(data: { levelIndex?: number }): void {
    this.levelIndex = data.levelIndex ?? 0
    this.gates = new Map()
    this.mechanics = []
    this.scrollLocks = []
    this.completed = false
    this.maxProgressX = 0
    this.lastProgressMs = -1
    this.lastStuckTipMs = -Infinity
  }

  create(): void {
    this.level = configService.level(this.levelIndex)
    gameState.markLevelStart()
    const theme = configService.theme(this.level.theme)
    // 3x-Zoom zuerst: drawBackdrop & Co. lesen displayWidth/worldView der Kamera
    this.cameras.main.setZoom(VIEW_ZOOM)

    // --- Tilemap ---
    const map = this.make.tilemap({ key: `map-${this.level.id}` })
    const tileset = map.addTilesetImage('ti-tiles', `tiles-${this.level.theme}`)
    if (!tileset) throw new Error(`Tileset für Theme "${this.level.theme}" fehlt`)
    this.mapWidth = map.widthInPixels

    drawBackdrop(this, theme, map.widthInPixels, map.heightInPixels, { lightShafts: true })

    const terrain = map.createLayer('terrain', tileset, 0, 0)
    if (!terrain) throw new Error(`Layer "terrain" fehlt in ${this.level.tilemap}`)
    terrain.setDepth(1)
    // GID 8 = Deko-Strebe (nicht solide); alles andere kollidiert
    terrain.setCollisionByExclusion([-1, 0, 8])

    this.physics.world.setBounds(0, 0, map.widthInPixels, map.heightInPixels)

    // --- Spieler + REZI ---
    const objects = map.getObjectLayer('objects')?.objects ?? []
    const spawn = objects.find((o) => o.type === 'spawn')
    const sx = (spawn?.x ?? 32) + (spawn?.width ?? 0) / 2
    const sy = (spawn?.y ?? map.heightInPixels - 48) + (spawn?.height ?? 0) / 2
    this.player = new Player(this, sx, sy)
    this.player.setRespawn(sx, sy)
    this.physics.add.collider(this.player, terrain)
    this.maxProgressX = sx

    this.rezi = new Rezi(this, sx - 16, sy - 26)
    this.rezi.follow(this.player)
    for (const seal of gameState.seals) this.rezi.addSealIcon(seal.sealId)
    if (gameState.encrypted) {
      this.player.setTint(0x9fd8ff)
      this.rezi.setEncrypted(true)
    }

    // --- Baukasten: erst Tore (benannt), dann alles andere ---
    // Adapter statt "implements": Phaser.Scene besitzt bereits ein eigenes
    // `scene`-Property (ScenePlugin), das mit MechanicHost.scene kollidieren würde.
    const host = this.buildMechanicHost()
    for (const obj of objects.filter((o) => o.type === 'gate')) {
      const gate = spawnMechanic(host, obj)
      if (gate) this.mechanics.push(gate)
    }
    for (const obj of objects.filter((o) => o.type !== 'gate')) {
      const mechanic = spawnMechanic(host, obj)
      if (mechanic) this.mechanics.push(mechanic)
    }

    // --- Kamera ---
    const cam = this.cameras.main
    cam.setBounds(0, 0, map.widthInPixels, map.heightInPixels)
    cam.setRoundPixels(true)
    if (this.level.cameraMode === 'tube') {
      const tubeParams = (this.level.mechanics['tube-scroll'] ?? {}) as { speed?: number }
      this.tubeSpeed = tubeParams.speed ?? 50
      this.tubeScrollX = 0
      cam.centerOn(cam.displayWidth / 2, cam.displayHeight / 2)
      // Tempo-Streifen verkaufen den Datenstrom im Tunnel
      addSpeedStreaks(this, Phaser.Display.Color.HexStringToColor(theme.accent).color)
    } else {
      if (this.level.cameraMode !== 'horizontal') {
        console.warn(`[camera] Modus "${this.level.cameraMode}" ist Ausbaustufe — fallback auf horizontal`)
      }
      cam.startFollow(this.player, true, 0.15, 0.15)
    }
    cam.fadeIn(350)

    this.game.events.emit('level:start', { level: this.level, index: this.levelIndex })
  }

  // ------------------------------------------------------------- MechanicHost

  private buildMechanicHost(): MechanicHost {
    const self = this
    return {
      scene: this,
      gates: this.gates,
      get player() {
        return self.player
      },
      get rezi() {
        return self.rezi
      },
      get level() {
        return self.level
      },
      addSolid: (body, onCollide) => {
        this.physics.add.collider(this.player, body, onCollide ? () => onCollide(this.player) : undefined)
      },
      addSensor: (body, onOverlap) => this.physics.add.overlap(this.player, body, () => onOverlap(this.player)),
      registerScrollLock: (lock) => {
        this.scrollLocks.push(lock)
      },
      completeLevel: () => this.completeLevel(),
    }
  }

  completeLevel(): void {
    if (this.completed) return
    this.completed = true
    gameState.addSeal(this.level.siegelIcon, this.level.id)
    this.rezi.addSealIcon(this.level.siegelIcon)
    this.game.events.emit('hud:update')
    this.player.controlsLocked = true
    this.player.setAccelerationX(0)

    this.time.delayedCall(600, () => {
      this.cameras.main.fadeOut(400, 6, 9, 15)
      this.cameras.main.once(Phaser.Cameras.Scene2D.Events.FADE_OUT_COMPLETE, () => {
        const next = this.levelIndex + 1
        if (next < configService.levels.length) {
          this.scene.start('City', { toLevelIndex: next })
        } else {
          this.scene.start('Reward')
        }
      })
    })
  }

  // ------------------------------------------------------------- Update

  update(time: number, delta: number): void {
    this.player.update()
    for (const mechanic of this.mechanics) mechanic.update(time, delta)
    if (this.level.cameraMode === 'tube' && !this.completed) this.updateTubeCamera(delta)
    if (!this.completed) this.checkStuckTip(time)
  }

  private updateTubeCamera(delta: number): void {
    const cam = this.cameras.main
    const viewW = cam.displayWidth // sichtbare Breite im Design-Raum (Zoom-fest)
    const held = this.scrollLocks.some((lock) => lock())
    if (!held) {
      this.tubeScrollX = Math.min(this.tubeScrollX + (this.tubeSpeed * delta) / 1000, this.mapWidth - viewW)
    }
    // centerOn statt scrollX: rechnet den Kamera-Zoom automatisch heraus
    cam.centerOn(this.tubeScrollX + viewW / 2, cam.displayHeight / 2)
    // Der Tunnel nimmt Paul mit: linke Bildkante schiebt sanft (kein Schaden — im
    // Tunnel ist man unantastbar), rechte Kante hält ihn im Bild — der Tunnel gibt das Tempo vor
    const minX = this.tubeScrollX + 14
    const maxX = this.tubeScrollX + viewW - 14
    if (this.player.x < minX) {
      this.player.x = minX
      if (this.player.body.velocity.x < 0) this.player.setVelocityX(0)
    } else if (this.player.x > maxX) {
      this.player.x = maxX
      if (this.player.body.velocity.x > 0) this.player.setVelocityX(0)
    }
    // Kamera folgt vertikal nicht — der Korridor ist bildschirmhoch
  }

  /**
   * Generaltipp gegen Festhängen: Der Spieler ist aktiv (Eingaben kommen),
   * macht aber seit STUCK_AFTER_MS keinen Streckenfortschritt → REZI gibt
   * einen Schubs mit der Grundsteuerung. Komplett inaktive Spieler behandelt
   * der IdleWatchdog (Reset in den Attract-Mode), nicht dieser Tipp.
   */
  private checkStuckTip(time: number): void {
    if (this.lastProgressMs < 0) this.lastProgressMs = time
    if (this.player.x > this.maxProgressX + 4) {
      this.maxProgressX = this.player.x
      this.lastProgressMs = time
      return
    }
    if (this.player.controlsLocked || performance.now() - inputManager.lastInputMs > 5000) {
      this.lastProgressMs = time // Setpiece bzw. Inaktivität zählt nicht als „hängt"
      return
    }
    if (time - this.lastProgressMs >= STUCK_AFTER_MS && time - this.lastStuckTipMs >= STUCK_REPEAT_MS) {
      this.lastStuckTipMs = time
      const fallback: LText = inputManager.hasGamepad()
        ? { de: 'Weiter nach rechts! ROT = springen · BLAU = TI-Aktion', en: 'Keep heading right! RED = jump · BLUE = TI action' }
        : { de: 'Weiter nach rechts! LEERTASTE = springen · E = TI-Aktion', en: 'Keep heading right! SPACE = jump · E = TI action' }
      this.rezi.say(t(this.level.stuckHint ?? fallback))
    }
  }
}
