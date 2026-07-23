import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { gameState } from '../state/GameState'
import { collectSparkle } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * Basisbausteine des Baukastens. Jeder Baustein liest seine Parameter aus
 * level.mechanics[typ] + Tiled-Objekt-Properties — Verhalten kommt nie aus der Map.
 */

// ---------------------------------------------------------------- Gate

/** Benanntes Tor: blockiert, bis eine Sicherheits-Mechanik es öffnet. */
export class Gate extends Mechanic {
  private sprite!: Phaser.Physics.Arcade.Image
  isOpen = false

  spawn(): void {
    const { x, y, h } = objCenter(this.obj)
    this.sprite = this.host.scene.physics.add.staticImage(x, y, 'gate') as unknown as Phaser.Physics.Arcade.Image
    this.sprite.setDisplaySize(8, h || 48)
    this.sprite.refreshBody()
    this.sprite.setDepth(5)
    this.host.addSolid(this.sprite)
    const name = this.obj.name || `gate-${this.obj.id}`
    this.host.gates.set(name, this)
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
    this.host.scene.tweens.add({
      targets: sprite,
      y: y - 3,
      duration: 900 + Math.random() * 400,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    })
    const collider = this.host.addSensor(sprite, () => {
      collider.destroy()
      sprite.destroy()
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
  private hintShown = false
  private completed = false

  spawn(): void {
    const { x, y } = objCenter(this.obj)
    this.door = this.host.scene.physics.add.staticImage(x, y, 'door') as unknown as Phaser.Physics.Arcade.Image
    this.door.setDepth(3)
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
