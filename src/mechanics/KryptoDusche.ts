import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { addGlow } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'
import { veredele } from '../gfx/vektor'

/**
 * Verschlüsselungs-Dusche: Blauer Knopf = „Ich beauftrage die TI" —
 * Paul & REZI bekommen die Schutz-Optik, Lauscher sehen ab jetzt nur Static.
 * Das verknüpfte Tor öffnet nur verschlüsselt (unverschlüsselt geht es nicht weiter).
 */
export class KryptoDusche extends Mechanic {
  private zone!: Phaser.Geom.Rectangle
  private head!: Phaser.GameObjects.Image
  private done = false
  private hintShown = false

  spawn(): void {
    const { x, w, h } = objCenter(this.obj)
    this.zone = new Phaser.Geom.Rectangle(this.obj.x ?? 0, this.obj.y ?? 0, w || 48, h || 64)
    this.head = this.host.scene.add.image(x, (this.obj.y ?? 0) + 6, 'dusche').setDepth(6)
    veredele(this.host.scene, this.head)
    this.host.scene.tweens.add({ targets: this.head, alpha: { from: 1, to: 0.7 }, duration: 800, yoyo: true, repeat: -1 })
    // Violettes Duschlicht markiert die Station schon von Weitem
    addGlow(this.host.scene, x, (this.obj.y ?? 0) + 10, 0x7a5cff, 18, { alpha: 0.35, depth: 5 })

    // Tube-Modus: Ohne Verschlüsselung rollt der Tunnel nicht weiter
    // (worldView statt scrollX/width: bleibt auch bei gezoomter Kamera korrekt)
    this.host.registerScrollLock(() => {
      if (this.done) return false
      const view = this.host.scene.cameras.main.worldView
      return view.width > 0 && view.x + view.width * 0.7 >= this.head.x
    })

    // Anrempel-Tipp am verknüpften Tor: sagt, WIE es aufgeht
    const gate = this.linkedGate()
    if (gate) {
      gate.openHint = this.paramText('gateHint', {
        de: 'Das Tor ist zu! Erst verschlüsseln: unter der Dusche die TI-Aktion drücken.',
        en: 'The gate is locked! Encrypt first: press the TI action under the shower.',
      })
    }
  }

  update(): void {
    if (this.done) return
    const p = this.host.player
    if (!this.zone.contains(p.x, p.y)) return

    if (!this.hintShown) {
      this.hintShown = true
      const hint = this.params['hint'] as LText | undefined
      if (hint) this.host.rezi.say(t(hint))
    }

    if (inputManager.justPressed(GameAction.Action)) this.activate()
  }

  private activate(): void {
    this.done = true
    const scene = this.host.scene
    const p = this.host.player

    // Regen aus Zeichensalat-Pixeln
    for (let i = 0; i < 14; i++) {
      const drop = scene.add
        .rectangle(this.head.x - 8 + Math.random() * 16, this.head.y + 4, 2, 4, 0x4de3ff, 0.9)
        .setDepth(6)
      scene.tweens.add({
        targets: drop,
        y: p.y + 8,
        alpha: 0,
        duration: 350 + Math.random() * 250,
        delay: Math.random() * 300,
        onComplete: () => drop.destroy(),
      })
    }

    gameState.encrypted = true
    p.setTint(0x9fd8ff)
    this.host.rezi.setEncrypted(true)
    this.host.rezi.say(t(this.host.level.station.reziText))
    this.linkedGate()?.open()
    scene.game.events.emit('hud:update')
  }
}
registerMechanic('krypto-dusche', KryptoDusche)
