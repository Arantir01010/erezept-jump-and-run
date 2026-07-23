import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { showDenyStamp } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * Gegner-Framework, Ausprägung „Skimming-Kralle": will Daten abgreifen,
 * scheitert nach N Versuchen sichtbar an der TI (gematik-Siegel-Blende).
 * Markenregel: Der Spieler kämpft nie — er weicht aus (Ducken), die TI blockt.
 */
export class DenyEnemy extends Mechanic {
  private claw!: Phaser.Physics.Arcade.Image
  private baseX = 0
  private baseY = 0
  private reach = 40
  private grabs = 0
  private grabsBeforeBlock = 2
  private blocked = false
  private grabbing = false
  private started = false
  private activationRange = 220
  private overlap?: Phaser.Physics.Arcade.Collider

  spawn(): void {
    const { x, y } = objCenter(this.obj)
    this.baseX = x
    this.baseY = y
    this.reach = this.param<number>('reach', 40)
    this.grabsBeforeBlock = this.param<number>('grabsBeforeBlock', 2)

    this.claw = this.host.scene.physics.add.image(x, y, 'kralle-open')
    const body = this.claw.body as Phaser.Physics.Arcade.Body
    body.setAllowGravity(false)
    body.setImmovable(true)
    // Flache Hitbox: geduckter Paul (13 px) passt sicher darunter durch
    body.setSize(20, 6)
    this.claw.setDepth(6)
    this.claw.setFlipX(this.param<boolean>('fromRight', true))

    // Schaden nur beim Zugriff — geducktem Spieler greift die Kralle über den Kopf
    this.overlap = this.host.addSensor(this.claw, (player) => {
      if (!this.grabbing || this.blocked) return
      player.hurt(this.claw.x)
    })

    this.activationRange = this.param<number>('activationRange', 220)
    // Kein Auto-Start: Die Kralle wird erst aktiv, wenn der Spieler in der Nähe ist —
    // sonst hat sie ihre 2 Grabs längst verbraucht und ist geblockt, bevor jemand sie sieht.
  }

  update(): void {
    if (this.started || this.blocked) return
    if (Math.abs(this.host.player.x - this.baseX) <= this.activationRange) {
      this.started = true
      this.scheduleGrab()
    }
  }

  private scheduleGrab(): void {
    if (this.blocked) return
    this.host.scene.time.delayedCall(this.param<number>('idleMs', 1300), () => this.telegraph())
  }

  private telegraph(): void {
    if (this.blocked) return
    // Ankündigung: Zittern — fair, lesbar, ohne Blitzeffekt
    this.host.scene.tweens.add({
      targets: this.claw,
      x: this.baseX + 2,
      duration: 60,
      yoyo: true,
      repeat: 4,
      onComplete: () => this.extend(),
    })
  }

  private extend(): void {
    if (this.blocked) return
    this.grabbing = true
    const dir = this.claw.flipX ? -1 : 1
    this.claw.setTexture('kralle-open')
    this.host.scene.tweens.add({
      targets: this.claw,
      x: this.baseX + dir * this.reach,
      duration: 320,
      ease: 'Cubic.easeIn',
      onComplete: () => {
        this.claw.setTexture('kralle-closed')
        this.grabs += 1
        this.host.scene.time.delayedCall(220, () => this.retract())
      },
    })
  }

  private retract(): void {
    this.grabbing = false
    this.host.scene.tweens.add({
      targets: this.claw,
      x: this.baseX,
      duration: 400,
      ease: 'Cubic.easeOut',
      onComplete: () => {
        if (this.grabs >= this.grabsBeforeBlock) this.block()
        else this.scheduleGrab()
      },
    })
  }

  /** Der Payoff: Die zugelassene Hardware sperrt den Fremdleser aus. */
  private block(): void {
    this.blocked = true
    this.grabbing = false
    const blende = this.host.scene.add.image(this.baseX, this.baseY - 60, 'siegel-blende').setDepth(7)
    this.host.scene.tweens.add({
      targets: blende,
      y: this.baseY - 2,
      duration: 350,
      ease: 'Bounce.easeOut',
      onComplete: () => {
        this.claw.setTexture('kralle-closed')
        this.claw.setTint(0x8888aa)
        const denyText = (this.params['denyText'] as LText | undefined) ?? { de: 'ZUGRIFF VERWEIGERT' }
        showDenyStamp(this.host.scene, this.baseX, this.baseY - 24, t(denyText))
        this.overlap?.destroy()
      },
    })
  }
}
registerMechanic('deny-enemy', DenyEnemy)
