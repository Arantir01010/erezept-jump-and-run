import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { addGlow } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'

/** Mindestabstand zwischen zwei Auffrischungen. */
const REFRESH_COOLDOWN_MS = 400

/**
 * KONTEXT-ANKER (KAPSEL Level 15) — frischt die VAU-Sitzung auf.
 *
 * Fachlich: Der Kontextschlüssel wird beim Sitzungsstart in die VAU eingebracht
 * und beim Sitzungsende aus dem Arbeitsspeicher gelöscht. Wer drinbleiben will,
 * muss die Sitzung erneuern — genau das ist die Spielhandlung.
 */
export class KontextAnker extends Mechanic {
  private sprite!: Phaser.Physics.Arcade.Image
  private lastMs = -Infinity

  spawn(): void {
    const { x, y } = objCenter(this.obj)
    this.sprite = this.host.scene.physics.add.staticImage(x, y, 'checkpoint') as unknown as Phaser.Physics.Arcade.Image
    this.sprite.setDepth(4).setTint(0xb9a6ff)
    addGlow(this.host.scene, x, y, 0xb9a6ff, 12, { alpha: 0.35, depth: 3 })

    this.host.addSensor(this.sprite, (player) => {
      const now = this.host.scene.time.now
      // Nur sinnvoll, wenn überhaupt eine ablaufende Sitzung läuft
      if (!player.huelle.vauExpires) return
      if (now - this.lastMs < REFRESH_COOLDOWN_MS) return
      if (!player.huelle.refreshSession(now)) return
      this.lastMs = now
      // Sichtbare Quittung: kurzer weißer Puls
      this.sprite.setTint(0xffffff)
      this.host.scene.tweens.add({
        targets: this.sprite,
        scale: { from: 1.4, to: 1 },
        duration: 250,
        onComplete: () => this.sprite.setTint(0xb9a6ff),
      })
      const hint = this.params['hint'] as LText | undefined
      if (hint) this.host.rezi.say(t(hint))
    })
  }
}
registerMechanic('kontext-anker', KontextAnker)
