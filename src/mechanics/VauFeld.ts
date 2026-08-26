import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { addGlow } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * VAU-FELD (KAPSEL Level 14 „Die VAU" und 15 „Kontextschlüssel").
 *
 * Innen ist der Spieler Klartext-schnell UND unsichtbar — die VAU ist eben
 * KEIN Tunnel, sondern ein Raum, in dem im Klartext gearbeitet werden darf,
 * ohne dass Betreiber mitlesen (KAPSEL 1.4, Vereinfachungsfehler vermeiden).
 *
 * Mit `ttlMs > 0` wird daraus der Kontextschlüssel: Die Sitzung läuft ab, der
 * Spieler fällt in den Klartext zurück (also sichtbar!) und muss die Sitzung an
 * einem `kontext-anker` auffrischen. Die Uhr läuft nur, solange er im Feld ist.
 */
export class VauFeld extends Mechanic {
  private zone!: Phaser.Geom.Rectangle
  private feld!: Phaser.GameObjects.Rectangle
  private rahmen?: Phaser.GameObjects.Rectangle
  private balken?: Phaser.GameObjects.Rectangle
  private drin = false
  private hintShown = false
  private ttlMs = 0

  spawn(): void {
    const { x, y, w, h } = objCenter(this.obj)
    const bw = w || 48
    const bh = h || 48
    this.zone = new Phaser.Geom.Rectangle(this.obj.x ?? 0, this.obj.y ?? 0, bw, bh)
    this.ttlMs = this.param<number>('ttlMs', 0)

    // Markanter dritter Farbton (violett) — eigene Farb- UND Formsprache,
    // damit der VAU-Zustand nie mit Klartext/Verschlüsselt verwechselt wird.
    this.feld = this.host.scene.add
      .rectangle(x, y, bw, bh, 0x7a5cff, 0.18)
      .setStrokeStyle(1, 0xb9a6ff, 0.9)
      .setDepth(3)
    addGlow(this.host.scene, x, y, 0x7a5cff, Math.max(bw, bh) * 0.6, { alpha: 0.16, depth: 2 })

    if (this.ttlMs > 0) {
      // Frische-Anzeige der Sitzung über dem Feld
      this.rahmen = this.host.scene.add
        .rectangle(x, this.zone.y - 6, 36, 5)
        .setStrokeStyle(1, 0xb9a6ff, 1)
        .setDepth(6)
      this.balken = this.host.scene.add
        .rectangle(x - 17, this.zone.y - 6, 34, 3, 0xb9a6ff, 1)
        .setOrigin(0, 0.5)
        .setDepth(6)
    }
  }

  update(): void {
    const player = this.host.player
    if (!player.huelleEnabled) return
    const innen = this.zone.contains(player.x, player.y)

    if (innen && !this.drin) {
      this.drin = true
      player.huelle.enterVau(this.host.scene.time.now, this.ttlMs)
      this.feld.setFillStyle(0x7a5cff, 0.3)
      if (!this.hintShown) {
        this.hintShown = true
        const hint = this.params['hint'] as LText | undefined
        this.host.rezi.say(
          t(
            hint ?? {
              de: 'VAU: Hier arbeitest du im Klartext — und trotzdem sieht dich niemand!',
              en: 'VAU: here you work in plain text — and still nobody can see you!',
            },
          ),
        )
      }
    } else if (!innen && this.drin) {
      this.drin = false
      player.huelle.leaveVau(this.host.scene.time.now)
      this.feld.setFillStyle(0x7a5cff, 0.18)
    }

    if (this.balken) {
      // Sitzungsfrische: Breite UND Farbe — bei < 30 % wird es dringend
      const ratio = this.drin ? player.huelle.vauRatio : 1
      this.balken.width = 34 * ratio
      this.balken.setFillStyle(ratio < 0.3 ? 0xff6b6b : 0xb9a6ff)
      this.balken.setVisible(this.drin)
      this.rahmen?.setVisible(this.drin)
    }
  }
}
registerMechanic('vau-feld', VauFeld)
