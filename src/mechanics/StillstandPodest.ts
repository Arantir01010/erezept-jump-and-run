import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { assist } from '../state/Assist'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { showDenyStamp } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * Stillstand-Podest (Firewall-Tor): Joystick loslassen, der Scan läuft durch,
 * das Tor öffnet. Die hinterherschleichende Datenkrake bekommt das Tor vor
 * die Nase — „ZUGRIFF VERWEIGERT". Im Tube-Modus pausiert der Auto-Scroll hier.
 */
export class StillstandPodest extends Mechanic {
  private podest!: Phaser.Physics.Arcade.Image
  private scanBar!: Phaser.GameObjects.Rectangle
  private krake?: Phaser.GameObjects.Sprite
  private progressMs = 0
  private done = false
  private hintShown = false
  private interruptions = 0

  spawn(): void {
    const { x, y, w } = objCenter(this.obj)
    this.podest = this.host.scene.physics.add.staticImage(x, y, 'podest')
    this.podest.setDisplaySize(Math.max(w, 32), 6)
    ;(this.podest.body as Phaser.Physics.Arcade.StaticBody).setSize(Math.max(w, 32), 6)
    this.podest.setDepth(4)
    this.host.addSolid(this.podest)

    this.host.scene.add.rectangle(x, y - 26, 36, 6).setStrokeStyle(1, 0x4de3ff, 1).setDepth(6)
    this.scanBar = this.host.scene.add.rectangle(x - 17, y - 26, 0, 4, 0x4de3ff, 1).setOrigin(0, 0.5).setDepth(6)

    // Tube-Modus: Auto-Scroll hält an, sobald das Podest ins Bild rückt, bis gescannt ist
    this.host.registerScrollLock(() => {
      if (this.done) return false
      const cam = this.host.scene.cameras.main
      return cam.scrollX + cam.width * 0.7 >= this.podest.x
    })

    // Die Krake schleicht hinterher — Sichtbarkeit für den Deny-Gag
    this.krake = this.host.scene.add.sprite(x - 90, y - 20, 'krake-0').setDepth(2).setAlpha(0.9)
    this.krake.play('krake-swim')
  }

  private get scanMs(): number {
    // Assist macht den Scan KÜRZER, nie länger — niemand hängt fest
    return this.param<number>('scanMs', 1200) / assist.slowdown(`podest-${this.obj.id}`)
  }

  private playerOnPodest(): boolean {
    const p = this.host.player
    const onTop = Math.abs(p.body.bottom - (this.podest.y - 3)) < 4
    const inX = Math.abs(p.x - this.podest.x) < this.podest.displayWidth / 2 + 2
    return onTop && inX && p.body.blocked.down
  }

  update(_time: number, delta: number): void {
    if (this.done) return

    const scanning = this.playerOnPodest() && inputManager.isNeutral()
    if (scanning) {
      if (!this.hintShown) {
        this.hintShown = true
        const hint = this.params['hint'] as LText | undefined
        if (hint) this.host.rezi.say(t(hint))
      }
      this.progressMs += delta
      if (this.progressMs >= this.scanMs) return this.succeed()
    } else if (this.progressMs > 0) {
      // Bewegt → Balken leert sich, ohne Strafe; wiederholtes Abbrechen füttert den Assist
      this.progressMs = Math.max(0, this.progressMs - delta * 2)
      if (this.progressMs === 0) {
        this.interruptions += 1
        if (this.interruptions >= 2) assist.fail(`podest-${this.obj.id}`)
      }
    } else if (this.playerOnPodest() && !this.hintShown) {
      this.hintShown = true
      const hint = this.params['hint'] as LText | undefined
      if (hint) this.host.rezi.say(t(hint))
    }

    this.scanBar.width = 34 * Math.min(1, this.progressMs / this.scanMs)
    // Krake nähert sich während des Scans
    if (this.krake && scanning) this.krake.x = Math.min(this.krake.x + delta * 0.02, this.podest.x - 40)
  }

  private succeed(): void {
    this.done = true
    this.scanBar.width = 34
    this.scanBar.setFillStyle(0x7fd07f)
    if (assist.wasClean(`podest-${this.obj.id}`)) gameState.addSecurityBonus()
    const gate = this.linkedGate()
    gate?.open()

    // Deny-Gag: Blende knallt hinter dem Spieler runter, Krake prallt ab
    if (this.krake) {
      const krake = this.krake
      const blockX = this.podest.x + 20
      const denyText = (this.params['denyText'] as LText | undefined) ?? { de: 'ZUGRIFF VERWEIGERT' }
      this.host.scene.tweens.add({
        targets: krake,
        x: blockX - 24,
        duration: 500,
        onComplete: () => {
          const blende = this.host.scene.add.image(blockX, krake.y - 50, 'siegel-blende').setDepth(7)
          this.host.scene.tweens.add({
            targets: blende,
            y: krake.y,
            duration: 250,
            ease: 'Bounce.easeOut',
            onComplete: () => {
              showDenyStamp(this.host.scene, krake.x, krake.y - 20, t(denyText))
              this.host.scene.tweens.add({
                targets: krake,
                x: krake.x - 60,
                y: krake.y + 30,
                alpha: 0,
                angle: -30,
                duration: 900,
                delay: 400,
                onComplete: () => krake.destroy(),
              })
              this.host.scene.tweens.add({ targets: blende, alpha: 0, duration: 400, delay: 1200, onComplete: () => blende.destroy() })
            },
          })
        },
      })
    }
  }
}
registerMechanic('stillstand-podest', StillstandPodest)
