import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import type { LevelConfig } from '../level/schema'
import { Player } from '../player/Player'
import { PLAYER_TUNING } from '../player/PlayerConfig'
import { eckKorrektur } from '../player/sprungphysik'
import { klang } from '../audio/klang'
import { Rezi } from '../actors/Rezi'
import { spawnMechanic, type MechanicHost, Gate } from '../mechanics'
import type { Mechanic } from '../mechanics'
import { gameState } from '../state/GameState'
import { drawBackdrop } from '../gfx/backdrop'
import { drawTerrain } from '../gfx/TerrainRenderer'
import { applyAtmosphere, attachLantern } from '../gfx/atmos'
import { lichtwisch } from '../gfx/licht'
import { silhouettePaul } from '../gfx/PaulSilhouette'
import { addSpeedStreaks, collectSparkle } from '../gfx/effects'
import { inputManager } from '../input/InputManager'
import { istTouchUiAktiv } from '../input/TouchControls'
import { WISSEN_VOR_LEVEL } from '../gfx/wissen'
import { GameAction } from '../input/actions'
import { VIEW_ZOOM } from '../gfx/view'
import { naechsterTubeScroll } from '../gfx/tubeKamera'
import { Huelle } from '../state/HuelleState'
import { protokoll } from '../state/Protokoll'
import { telemetry } from '../telemetry/Telemetry'
import { t } from '../i18n'
import type { LText } from '../i18n'
import { setzeZeichenTheme } from '../gfx/vektor'

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
  /** Kollisionsgitter — die Kanten-Korrektur fragt Kacheln über dem Kopf ab. */
  private terrain!: Phaser.Tilemaps.TilemapLayer
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
    // Telemetrie (KAPSEL 4.4): ab hier gehören alle Ereignisse zu dieser Station
    telemetry.setLevel(this.level.id)
    telemetry.note('level-start', this.time.now)
    const theme = configService.theme(this.level.theme)
    // Ab hier zeichnen alle Vektor-Objekte in dieser Farbwelt
    setzeZeichenTheme(theme)
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
    this.terrain = terrain
    terrain.setDepth(1)
    // GID 8 = Deko-Strebe (nicht solide); alles andere kollidiert
    terrain.setCollisionByExclusion([-1, 0, 8])
    // Die Kachel-Ebene bleibt Kollisionsgitter, wird aber nicht mehr gezeichnet:
    // Das Gelände entsteht als zusammengefasste Silhouette mit Kantenlicht.
    drawTerrain(this, map, terrain, theme)

    this.physics.world.setBounds(0, 0, map.widthInPixels, map.heightInPixels)

    // --- Verstreute Bits: bleiben liegen und sind WIEDER einsammelbar ---
    // (Anti-Softlock: das Sammelziel darf durch Treffer nie unerreichbar
    // werden. Kein Despawn — die Bits warten, bis jemand sie holt.)
    const onVerstreut = (payload: { x: number; y: number; count: number }): void => {
      for (let i = 0; i < payload.count; i++) {
        const bit = this.physics.add.image(payload.x, payload.y, 'datenbit').setDepth(6)
        const body = bit.body as Phaser.Physics.Arcade.Body
        body.setBounce(0.45, 0.45)
        body.setDrag(60, 0)
        body.setVelocity((Math.random() - 0.5) * 160, -120 - Math.random() * 80)
        this.physics.add.collider(bit, terrain)
        let sammelbar = false
        this.time.delayedCall(700, () => {
          sammelbar = true
          this.tweens.add({ targets: bit, alpha: { from: 1, to: 0.55 }, duration: 500, yoyo: true, repeat: -1 })
        })
        const overlap = this.physics.add.overlap(this.player, bit, () => {
          if (!sammelbar) return
          overlap.destroy()
          bit.destroy()
          // Bewusst OHNE Punkte (sonst wäre absichtliches Getroffenwerden
          // eine Punkteschleife) — nur die Bits kommen zurück.
          gameState.bits += 1
          collectSparkle(this, bit.x, bit.y)
          klang.sammeln()
          this.game.events.emit('hud:update')
        })
      }
    }
    this.events.on('bits:verstreut', onVerstreut)
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.events.off('bits:verstreut', onVerstreut))

    // --- Spieler + REZI ---
    const objects = map.getObjectLayer('objects')?.objects ?? []
    const spawn = objects.find((o) => o.type === 'spawn')
    const sx = (spawn?.x ?? 32) + (spawn?.width ?? 0) / 2
    const sy = (spawn?.y ?? map.heightInPixels - 48) + (spawn?.height ?? 0) / 2
    this.player = new Player(this, sx, sy)
    this.player.setRespawn(sx, sy)

    // --- Hülle-Mechanik: nur aktiv, wenn das Level sie einschaltet ---
    // (Die drei Messe-Level haben huelle.enabled = false und bleiben unberührt.)
    const huelleCfg = this.level.huelle
    this.player.huelleEnabled = huelleCfg.enabled
    if (huelleCfg.enabled) {
      this.player.huelle.toggleCooldownMs = huelleCfg.toggleCooldownMs
      this.player.huelle.reset(
        huelleCfg.start === 'verschluesselt' ? Huelle.Verschluesselt : Huelle.Klartext,
        this.time.now,
      )
      // HUD sofort nachziehen, wenn sich der Zustand ändert
      this.player.huelle.onChange((c) => {
        this.game.events.emit('hud:update')
        // Der Zielzustand ist die entscheidende Information: Nur ein Wechsel
        // nach „verschluesselt" ist ein Schutzwechsel (siehe kennzahlen.ts).
        if (c.reason === 'toggle') telemetry.note('huelle-wechsel', this.time.now, c.to)
        if (c.reason === 'enter-vau') telemetry.note('vau-betreten', this.time.now)
        if (c.reason === 'session-expired') telemetry.note('vau-abgelaufen', this.time.now)
      })
    }
    this.physics.add.collider(this.player, terrain)
    this.maxProgressX = sx

    this.rezi = new Rezi(this, sx - 16, sy - 26)
    this.rezi.follow(this.player)
    // REZI leuchtet — Paul läuft in ihrem Schein. Das hält die Figur in einer
    // dunklen Kulisse jederzeit auffindbar, ohne das Bild aufzuhellen.
    attachLantern(this, this.rezi, Phaser.Display.Color.HexStringToColor(theme.detail).color, 52)
    // Paul wird als Vektor-Silhouette gezeichnet; die Physik-Sprite bleibt
    // erhalten und liefert Pose, Blinken und Squash & Stretch.
    silhouettePaul(this, this.player, theme, { light: this.rezi })
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
    // Kein Pixel-Runden mehr: Die Parallax-Ebenen und das Kantenlicht sollen
    // stufenlos gleiten. Der Tube-Akkumulator unten bleibt trotzdem korrekt.
    cam.setRoundPixels(false)
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
      // Vorausschauen: Die Kamera schiebt sich in Laufrichtung. Das gibt beim
      // Rennen mehr Sicht nach vorn — der häufigste Grund für unfaire Treffer
      // ist eine Kamera, die den Spieler mittig festhält.
      cam.setFollowOffset(0, 0)
    }
    cam.fadeIn(350)
    lichtwisch(this, 0xbfe9ff, 560, 1)

    // Leuchten, Randabdunklung, leichte Entsättigung — hält die Palette eng
    // und lässt Kantenlicht und Datenfunken glühen. Nur WebGL.
    applyAtmosphere(this)

    this.game.events.emit('level:start', { level: this.level, index: this.levelIndex })
    // Gegenstück zu level:start — Overlays (Touch-Steuerung) räumen die Bühne,
    // sobald das Level endet (City-Übergang, Reward, Idle-Reset).
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.game.events.emit('level:ende'))
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
    // Zugriffsprotokoll: Station abgeschlossen (Grundlage der drei Siegel)
    protokoll.markAbgeschlossen(this.level.id, this.time.now)
    telemetry.note('level-ende', this.time.now)
    gameState.addSeal(this.level.siegelIcon, this.level.id)
    this.rezi.addSealIcon(this.level.siegelIcon)
    klang.siegel()
    this.game.events.emit('hud:update')
    this.player.controlsLocked = true
    this.player.setAccelerationX(0)

    this.time.delayedCall(600, () => {
      this.cameras.main.fadeOut(400, 6, 9, 15)
      this.cameras.main.once(Phaser.Cameras.Scene2D.Events.FADE_OUT_COMPLETE, () => {
        const next = this.levelIndex + 1
        if (next < configService.levels.length) {
          // ePA-Stationen bekommen statt des City-Laufs eine Lehrsequenz:
          // erst verstehen, dann spielen (src/gfx/wissen.ts).
          const wissen = WISSEN_VOR_LEVEL[configService.levels[next].id]
          if (wissen) this.scene.start('Wissen', { id: wissen, toLevelIndex: next })
          else this.scene.start('City', { toLevelIndex: next })
        } else {
          this.scene.start('Reward')
        }
      })
    })
  }

  // ------------------------------------------------------------- Update

  update(time: number, delta: number): void {
    // Kamera-Vorlauf sanft nachziehen (nur im Follow-Modus)
    if (this.level.cameraMode !== 'tube' && !this.completed) {
      const cam0 = this.cameras.main
      const ziel = Phaser.Math.Clamp(this.player.body.velocity.x / 130, -1, 1) * -34
      cam0.followOffset.x += (ziel - cam0.followOffset.x) * Math.min(1, (delta / 1000) * 2.2)
    }
    // Hülle vor der Spielerlogik: Sitzungsablauf soll im gleichen Frame wirken
    if (this.player.huelleEnabled && !this.completed) {
      this.player.tickHuelle(delta)
      if (inputManager.justPressed(GameAction.Toggle)) this.player.tryToggleHuelle()
    }
    this.player.update()
    this.pruefeEckKorrektur()
    for (const mechanic of this.mechanics) mechanic.update(time, delta)
    if (this.level.cameraMode === 'tube' && !this.completed) this.updateTubeCamera(delta)
    if (!this.completed) this.checkStuckTip(time)
  }

  /**
   * Kanten-Korrektur (Celeste-Schule): Bonkt der Kopf im Steigen knapp neben
   * einer Kachelkante an, wird Paul seitlich vorbeigeschoben und der Sprung
   * fortgesetzt, statt ihn zu töten. Die Geometrie-Logik ist Phaser-frei
   * (sprungphysik.ts, getestet) — hier nur die Kachel-Abfrage.
   */
  private pruefeEckKorrektur(): void {
    const b = this.player.body
    if (!b.blocked.up || this.player.letztesVy > -20) return
    const kopfY = b.top - 1
    const solideLinks = this.terrain.getTileAtWorldXY(b.left + 0.5, kopfY)?.collides === true
    const solideRechts = this.terrain.getTileAtWorldXY(b.right - 0.5, kopfY)?.collides === true
    const schub = eckKorrektur(
      b.left, b.right, this.terrain.tilemap.tileWidth,
      solideLinks, solideRechts, PLAYER_TUNING.cornerCorrectionPx,
    )
    if (schub !== 0) {
      this.player.x += schub
      this.player.setVelocityY(this.player.letztesVy) // Sprung läuft weiter
    }
  }

  private updateTubeCamera(delta: number): void {
    const cam = this.cameras.main
    const viewW = cam.displayWidth // sichtbare Breite im Design-Raum (Zoom-fest)
    // Wohin der Tunnel rückt, entscheidet gfx/tubeKamera.ts (Phaser-frei, getestet).
    // Wichtig: Der Auto-Scroll ist die UNTERGRENZE des Tempos. Läuft Paul
    // schneller als der Tunnel — er läuft 130 px/s, der Tunnel 55 —, zieht er
    // die Kamera mit, statt an der Bildkante auf sie zu warten.
    this.tubeScrollX = naechsterTubeScroll({
      scrollX: this.tubeScrollX,
      speed: this.tubeSpeed,
      deltaMs: delta,
      playerX: this.player.x,
      viewW,
      mapWidth: this.mapWidth,
      held: this.scrollLocks.some((lock) => lock()),
    })
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
      const fallback: LText = istTouchUiAktiv()
        ? { de: 'Weiter nach rechts! Tippen = springen · Doppeltipp = TI-Aktion', en: 'Keep heading right! Tap = jump · double-tap = TI action' }
        : inputManager.hasGamepad()
          ? { de: 'Weiter nach rechts! ROT = springen · BLAU = TI-Aktion', en: 'Keep heading right! RED = jump · BLUE = TI action' }
          : { de: 'Weiter nach rechts! LEERTASTE = springen · E = TI-Aktion', en: 'Keep heading right! SPACE = jump · E = TI action' }
      this.rezi.say(t(this.level.stuckHint ?? fallback))
    }
  }
}
