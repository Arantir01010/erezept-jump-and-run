import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { addGlow } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'
import { veredele } from '../gfx/vektor'

/**
 * ANDOCK-PLATTFORM (KAPSEL Level 2, Beat „Ten" bei 1:30).
 *
 * Trägt den Spieler NUR im Klartext oder in der VAU — verschlüsselte Daten
 * können nicht andocken. Damit entsteht der Zielkonflikt, der die Mechanik erst
 * tragfähig macht: Um weiterzukommen, muss man sich sichtbar machen und das
 * Timing des Lauschers treffen.
 *
 * Fachliches Bild: Zum Verarbeiten müssen Daten im Klartext vorliegen — entweder
 * offen (dann sieht man sie) oder geschützt in der VAU.
 */
export class AndockPlattform extends Mechanic {
  private sprite!: Phaser.Physics.Arcade.Image
  private glow?: Phaser.GameObjects.Image
  /** Zuletzt gesetzter Zustand (null = noch nie gesetzt → erstes update greift). */
  private traegt: boolean | null = null
  private hintShown = false

  spawn(): void {
    const { x, y, w } = objCenter(this.obj)
    const breite = Math.max(w, 24)
    this.sprite = this.host.scene.physics.add.staticImage(x, y, 'podest')
    this.host.scene.time.delayedCall(0, () => veredele(this.host.scene, this.sprite))
    this.sprite.setDisplaySize(breite, 6)
    ;(this.sprite.body as Phaser.Physics.Arcade.StaticBody).setSize(breite, 6)
    this.sprite.setDepth(4)
    this.host.addSolid(this.sprite)
    // Goldener Schimmer: „hier ist Klartext gefragt"
    this.glow = addGlow(this.host.scene, x, y - 4, 0xffd75e, 14, { alpha: 0.25, depth: 3, pulse: false })
  }

  update(): void {
    const player = this.host.player
    const soll = player.istAndockfaehig
    if (soll === this.traegt) return
    this.traegt = soll

    const body = this.sprite.body as Phaser.Physics.Arcade.StaticBody
    body.enable = soll
    // Sichtbar UND lesbar ohne Farbe: Deckkraft plus Leuchten ändern sich
    // deutlich (Barrierefreiheit, KAPSEL 3.3).
    this.sprite.setAlpha(soll ? 1 : 0.3)
    this.glow?.setAlpha(soll ? 0.25 : 0.04)

    // Einmalige Erklärung, wenn der Spieler verschlüsselt davorsteht
    if (!soll && !this.hintShown && Math.abs(player.x - this.sprite.x) < this.sprite.displayWidth) {
      this.hintShown = true
      const hint = this.params['hint'] as LText | undefined
      this.host.rezi.say(
        t(
          hint ?? {
            de: 'Diese Plattform trägt nur Klartext — kurz entschlüsseln und schnell sein!',
            en: 'This platform only carries plain text — decrypt briefly and be quick!',
          },
        ),
      )
    }
  }
}
registerMechanic('andock-plattform', AndockPlattform)
