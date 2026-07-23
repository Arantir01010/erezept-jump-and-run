import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { gameState } from '../state/GameState'
import { collectSparkle, addGlow, destroyGlow } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * Basisbausteine des Baukastens. Jeder Baustein liest seine Parameter aus
 * level.mechanics[typ] + Tiled-Objekt-Properties — Verhalten kommt nie aus der Map.
 */

// ---------------------------------------------------------------- Gate

const GATE_BUMP_FALLBACK: LText = {
  de: 'Zu! Eine TI-Prüfung in der Nähe öffnet dieses Tor — schau dich um.',
  en: 'Locked! A nearby TI check opens this gate — look around.',
}

/** Benanntes Tor: blockiert, bis eine Sicherheits-Mechanik es öffnet. */
export class Gate extends Mechanic {
  private sprite!: Phaser.Physics.Arcade.Image
  isOpen = false
  /** Tipp fürs Anrempeln — setzt die öffnende Mechanik beim Spawn (gateHint). */
  openHint?: string
  private lastBumpMs = -Infinity
  private bumpStartMs = -Infinity
  private lastShakeMs = -Infinity
  private lastTipMs = -Infinity

  private lockLight?: Phaser.GameObjects.Image

  spawn(): void {
    const { x, y, h } = objCenter(this.obj)
    this.sprite = this.host.scene.physics.add.staticImage(x, y, 'gate') as unknown as Phaser.Physics.Arcade.Image
    this.sprite.setDisplaySize(8, h || 48)
    this.sprite.refreshBody()
    this.sprite.setDepth(5)
    this.host.addSolid(this.sprite, () => this.onBump())
    // Status-Licht: rot = gesperrt, grün beim Öffnen (liest sich ohne Worte)
    this.lockLight = addGlow(this.host.scene, x, y - (h || 48) / 2 + 3, 0xff5050, 7, { alpha: 0.5, depth: 6 })
    const name = this.obj.name || `gate-${this.obj.id}`
    this.host.gates.set(name, this)
  }

  /**
   * Spieler drückt gegen das geschlossene Tor: sofort sichtbares „Zu!"-Wackeln,
   * nach ~2 s Dagegenstemmen sagt REZI, WIE es aufgeht (openHint der Mechanik).
   */
  private onBump(): void {
    if (this.isOpen) return
    const body = this.host.player.body
    if (!body.touching.left && !body.touching.right) return // nur seitliches Anrempeln, nicht draufstehen
    const now = this.host.scene.time.now
    if (now - this.lastBumpMs > 600) this.bumpStartMs = now // neuer Anlauf
    this.lastBumpMs = now
    if (now - this.lastShakeMs > 1500) {
      this.lastShakeMs = now
      this.shake()
    }
    if (now - this.bumpStartMs > 1800 && now - this.lastTipMs > 7000) {
      this.lastTipMs = now
      this.host.rezi.say(this.openHint ?? this.paramText('bumpHint', GATE_BUMP_FALLBACK))
    }
  }

  open(): void {
    if (this.isOpen) return
    this.isOpen = true
    const body = this.sprite.body as Phaser.Physics.Arcade.StaticBody
    body.enable = false
    this.host.scene.tweens.add({
      targets: this.sprite,
      y: this.sprite.y - (this.sprite.displayHeight - 6),
      duration: 450,
      ease: 'Cubic.easeOut',
    })
    // Licht springt auf Grün und verglimmt
    if (this.lockLight) {
      this.host.scene.tweens.killTweensOf(this.lockLight)
      this.lockLight.setTint(0x7fd07f).setAlpha(0.7)
      this.host.scene.tweens.add({
        targets: this.lockLight,
        alpha: 0,
        duration: 900,
        delay: 350,
        onComplete: () => destroyGlow(this.host.scene, this.lockLight),
      })
    }
  }

  /** Kurzes „Zu!"-Wackeln, wenn jemand ohne Berechtigung dagegen läuft. */
  shake(): void {
    this.host.scene.tweens.add({ targets: this.sprite, x: this.sprite.x + 2, duration: 50, yoyo: true, repeat: 2 })
  }

  get x(): number {
    return this.sprite.x
  }
  get y(): number {
    return this.sprite.y
  }
}
registerMechanic('gate', Gate)

// ---------------------------------------------------------------- Collectible

export class Collectible extends Mechanic {
  spawn(): void {
    const { x, y } = objCenter(this.obj)
    const sprite = this.host.scene.physics.add.staticImage(x, y, 'datenbit') as unknown as Phaser.Physics.Arcade.Image
    sprite.setDepth(4)
    // Cyan-Schimmer macht Sammelbits aus dem Augenwinkel sichtbar
    const glow = addGlow(this.host.scene, x, y, 0x4de3ff, 9, { alpha: 0.28, depth: 3 })
    this.host.scene.tweens.add({
      targets: [sprite, glow],
      y: y - 3,
      duration: 900 + Math.random() * 400,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    })
    const collider = this.host.addSensor(sprite, () => {
      collider.destroy()
      sprite.destroy()
      destroyGlow(this.host.scene, glow)
      gameState.addBits(1)
      collectSparkle(this.host.scene, x, y)
      this.host.scene.game.events.emit('hud:update')
    })
  }
}
registerMechanic('collectible', Collectible)

// ---------------------------------------------------------------- Checkpoint

export class Checkpoint extends Mechanic {
  private active = false

  spawn(): void {
    const { x, y } = objCenter(this.obj)
    const sprite = this.host.scene.physics.add.staticImage(x, y, 'checkpoint') as unknown as Phaser.Physics.Arcade.Image
    sprite.setDepth(3)
    sprite.setAlpha(0.6)
    this.host.addSensor(sprite, (player) => {
      if (this.active) return
      this.active = true
      sprite.setAlpha(1)
      sprite.setTint(0xffffff)
      player.setRespawn(x, y - 8)
      // Aktivierungs-Blitz + dauerhaftes grünes Glimmen: „hier bist du sicher"
      const glow = addGlow(this.host.scene, x, y - 2, 0x7fd07f, 12, { alpha: 0.4, depth: 3 })
      this.host.scene.tweens.add({ targets: glow, alpha: { from: 0.85, to: 0.4 }, duration: 450, ease: 'Cubic.easeOut' })
    })
  }
}
registerMechanic('checkpoint', Checkpoint)

// ---------------------------------------------------------------- Info-Sign

export class InfoSign extends Mechanic {
  spawn(): void {
    const { x, y, w, h } = objCenter(this.obj)
    const zone = this.host.scene.physics.add.staticImage(x, y, 'datenbit') as unknown as Phaser.Physics.Arcade.Image
    zone.setVisible(false)
    zone.body!.setSize(Math.max(w, 24), Math.max(h, 24))
    let lastShownMs = -Infinity
    this.host.addSensor(zone, () => {
      const now = this.host.scene.time.now
      if (now - lastShownMs < 4000) return
      lastShownMs = now
      // Text aus Tiled-Properties (textDe/textEn, flache Strings) oder level.mechanics (LText)
      const textDe = this.params['textDe'] as string | undefined
      const text = textDe
        ? ({ de: textDe, en: this.params['textEn'] as string | undefined } satisfies LText)
        : (this.params['text'] as LText | undefined)
      if (text) this.host.rezi.say(t(text))
    })
  }
}
registerMechanic('info-sign', InfoSign)

// ---------------------------------------------------------------- Door-Exit

/** Levelausgang: öffnet erst, wenn genug Datenbits gesammelt sind. */
export class DoorExit extends Mechanic {
  private door!: Phaser.Physics.Arcade.Image
  private doorGlow?: Phaser.GameObjects.Image
  private hintShown = false
  private completed = false

  spawn(): void {
    const { x, y } = objCenter(this.obj)
    this.door = this.host.scene.physics.add.staticImage(x, y, 'door') as unknown as Phaser.Physics.Arcade.Image
    this.door.setDepth(3)
    // Gedimmt solange verschlossen — leuchtet auf, sobald genug Bits gesammelt sind
    this.doorGlow = addGlow(this.host.scene, x, y, 0xffd75e, 16, { alpha: 0.1, depth: 2, pulse: false })
    this.host.addSensor(this.door, () => this.tryEnter())
  }

  private get unlocked(): boolean {
    // Sammelziel gilt PRO Level — Bits aus früheren Stationen zählen nicht
    return gameState.bitsThisLevel >= this.host.level.collectible.countRequired
  }

  private tryEnter(): void {
    if (this.completed) return
    if (this.unlocked) {
      this.completed = true
      this.host.completeLevel()
    } else if (!this.hintShown) {
      this.hintShown = true
      const need = this.host.level.collectible.countRequired - gameState.bitsThisLevel
      const label = t(this.host.level.collectible.label)
      this.host.rezi.say(`Noch ${need} ${label} sammeln!`)
      this.host.scene.time.delayedCall(3000, () => (this.hintShown = false))
    }
  }

  update(): void {
    if (this.door && this.unlocked && !this.door.getData('glow')) {
      this.door.setData('glow', true)
      this.host.scene.tweens.add({ targets: this.door, alpha: { from: 1, to: 0.75 }, duration: 500, yoyo: true, repeat: -1 })
      if (this.doorGlow) {
        this.host.scene.tweens.add({ targets: this.doorGlow, alpha: 0.45, duration: 600, yoyo: true, repeat: -1 })
      }
    }
  }
}
registerMechanic('door-exit', DoorExit)

// ---------------------------------------------------------------- Moving Platform

export class MovingPlatform extends Mechanic {
  private sprite!: Phaser.Physics.Arcade.Image
  private minX = 0
  private maxX = 0
  private dir = 1

  spawn(): void {
    const { x, y, w } = objCenter(this.obj)
    const range = this.param<number>('range', 48)
    const speed = this.param<number>('speed', 40)
    this.minX = x
    this.maxX = x + range
    this.sprite = this.host.scene.physics.add.image(x, y, 'podest')
    this.sprite.setDisplaySize(Math.max(w, 24), 6)
    const body = this.sprite.body as Phaser.Physics.Arcade.Body
    body.setAllowGravity(false)
    body.setImmovable(true)
    body.setVelocityX(speed)
    this.host.addSolid(this.sprite)
  }

  update(): void {
    const body = this.sprite.body as Phaser.Physics.Arcade.Body
    if (this.sprite.x >= this.maxX && this.dir > 0) {
      this.dir = -1
      body.setVelocityX(-Math.abs(body.velocity.x))
    } else if (this.sprite.x <= this.minX && this.dir < 0) {
      this.dir = 1
      body.setVelocityX(Math.abs(body.velocity.x))
    }
  }
}
registerMechanic('moving-platform', MovingPlatform)

// ---------------------------------------------------------------- Hazard

/** Schadenszone (nur außerhalb geschützter Bereiche einsetzen — siehe Konzept). */
export class Hazard extends Mechanic {
  spawn(): void {
    const { x, y, w, h } = objCenter(this.obj)
    const zone = this.host.scene.physics.add.staticImage(x, y, 'datenbit') as unknown as Phaser.Physics.Arcade.Image
    zone.setVisible(false)
    zone.body!.setSize(w || 16, h || 16)
    this.host.addSensor(zone, (player) => {
      player.hurt(x)
    })
  }
}
registerMechanic('hazard', Hazard)

// ---------------------------------------------------------------- Deco

/** Reine Kulisse (z. B. Datenkraken außen am Glastunnel) — keine Physik. */
export class Deco extends Mechanic {
  spawn(): void {
    const { x, y } = objCenter(this.obj)
    const texture = this.param<string>('sprite', 'krake-0')
    const anim = this.param<string>('anim', '')
    const sprite = this.host.scene.add.sprite(x, y, texture).setDepth(2)
    if (anim && this.host.scene.anims.exists(anim)) sprite.play(anim)
    const drift = this.param<number>('drift', 6)
    if (drift > 0) {
      this.host.scene.tweens.add({
        targets: sprite,
        y: y - drift,
        duration: 1400 + Math.random() * 800,
        yoyo: true,
        repeat: -1,
        ease: 'Sine.easeInOut',
      })
    }
  }
}
registerMechanic('deco', Deco)
