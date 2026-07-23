import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { assist } from '../state/Assist'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { showDenyStamp, addGlow } from '../gfx/effects'
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
  private scanGlow?: Phaser.GameObjects.Image
  private krake?: Phaser.GameObjects.Sprite
  private progressMs = 0
  private done = false
  private hintShown = false
  private interruptions = 0
  private lastTipMs = -Infinity

  spawn(): void {
    const { x, y, w } = objCenter(this.obj)
    this.podest = this.host.scene.physics.add.staticImage(x, y, 'podest')
    this.podest.setDisplaySize(Math.max(w, 32), 6)
    ;(this.podest.body as Phaser.Physics.Arcade.StaticBody).setSize(Math.max(w, 32), 6)
    this.podest.setDepth(4)
    this.host.addSolid(this.podest)

    this.host.scene.add.rectangle(x, y - 26, 36, 6).setStrokeStyle(1, 0x4de3ff, 1).setDepth(6)
    this.scanBar = this.host.scene.add.rectangle(x - 17, y - 26, 0, 4, 0x4de3ff, 1).setOrigin(0, 0.5).setDepth(6)
    // Scan-Licht: schwillt mit dem Fortschritt an (Feedback ohne Hinschauen)
    this.scanGlow = addGlow(this.host.scene, x, y - 14, 0x4de3ff, 24, { alpha: 0, depth: 3, pulse: false })

    // Tube-Modus: Auto-Scroll hält an, sobald das Podest ins Bild rückt, bis gescannt ist
    // (worldView statt scrollX/width: bleibt auch bei gezoomter Kamera korrekt)
    this.host.registerScrollLock(() => {
      if (this.done) return false
      const view = this.host.scene.cameras.main.worldView
      return view.width > 0 && view.x + view.width * 0.7 >= this.podest.x
    })

    // Anrempel-Tipp am verknüpften Tor: sagt, WIE es aufgeht
    const gate = this.linkedGate()
    if (gate) {
      gate.openHint = this.paramText('gateHint', {
        de: 'Das Tor ist zu! Stell dich aufs Podest und steh still, bis der Scan durch ist.',
        en: 'The gate is locked! Step onto the pedestal and stand still until the scan completes.',
      })
    }

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

  update(time: number, delta: number): void {
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
        if (this.interruptions >= 2) {
          assist.fail(`podest-${this.obj.id}`)
          // Ab dem 2. abgebrochenen Scan sagt REZI klar, was fehlt (Assist verkürzt parallel)
          if (time - this.lastTipMs > 6000) {
            this.lastTipMs = time
            this.host.rezi.say(
              this.paramText('stillHint', {
                de: 'Tipp: Alles loslassen und ganz stillstehen — erst dann läuft der Scan durch!',
                en: 'Tip: let go of everything and stand perfectly still — only then the scan completes!',
              }),
            )
          }
        }
      }
    } else if (this.playerOnPodest() && !this.hintShown) {
      this.hintShown = true
      const hint = this.params['hint'] as LText | undefined
      if (hint) this.host.rezi.say(t(hint))
    }

    const ratio = Math.min(1, this.progressMs / this.scanMs)
    this.scanBar.width = 34 * ratio
    if (this.scanGlow) this.scanGlow.setAlpha(0.4 * ratio)
    // Krake nähert sich während des Scans
    if (this.krake && scanning) this.krake.x = Math.min(this.krake.x + delta * 0.02, this.podest.x - 40)
  }

  private succeed(): void {
    this.done = true
    this.scanBar.width = 34
    this.scanBar.setFillStyle(0x7fd07f)
    // Erfolg: Licht springt auf Grün und verglimmt
    if (this.scanGlow) {
      this.scanGlow.setTint(0x7fd07f).setAlpha(0.55)
      this.host.scene.tweens.add({ targets: this.scanGlow, alpha: 0, duration: 1100, delay: 300 })
    }
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
