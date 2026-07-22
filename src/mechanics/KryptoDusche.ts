import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { t } from '../i18n'
import type { LText } from '../i18n'

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
    this.host.scene.tweens.add({ targets: this.head, alpha: { from: 1, to: 0.7 }, duration: 800, yoyo: true, repeat: -1 })

    // Tube-Modus: Ohne Verschlüsselung rollt der Tunnel nicht weiter
    this.host.registerScrollLock(() => {
      if (this.done) return false
      const cam = this.host.scene.cameras.main
      return cam.scrollX + cam.width * 0.7 >= this.head.x
    })
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
