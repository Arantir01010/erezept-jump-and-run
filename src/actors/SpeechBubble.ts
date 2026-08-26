import Phaser from 'phaser'
import { addText } from '../gfx/text'

/**
 * Sprechblase im Spielraum (pausiert das Spiel nie).
 * Max. 1 Satz — Textmenge wird durch die Level-JSONs diszipliniert.
 */

/**
 * Abstand der Blasen-Oberkante zur oberen Bildkante.
 *
 * Das HUD (UIScene) belegt die obersten ~25 px des Design-Raums: Stationsname,
 * Streckenkarte, Prüfsummen-Zähler, Hülle-Anzeige. Darunter beginnt das
 * Hinweis-Band.
 */
const BAND_OBEN = 30
export class SpeechBubble extends Phaser.GameObjects.Container {
  private bg: Phaser.GameObjects.Graphics
  private label: Phaser.GameObjects.Text
  private hideTimer?: Phaser.Time.TimerEvent

  constructor(scene: Phaser.Scene) {
    super(scene, 0, 0)
    this.bg = scene.add.graphics()
    this.label = addText(scene, 0, 0, '', 10, {
      color: '#20242e',
      align: 'center',
      wrapWidth: 160,
    }).setOrigin(0.5, 0.5)
    this.add([this.bg, this.label])
    this.setDepth(60)
    this.setVisible(false)
    scene.add.existing(this)
  }

  show(text: string, holdMs = 2800): void {
    this.label.setText(text)
    const w = Math.min(172, this.label.width + 14)
    const h = this.label.height + 10
    this.bg.clear()
    this.bg.fillStyle(0xffffff, 0.95)
    this.bg.lineStyle(1, 0x20242e, 1)
    this.bg.fillRoundedRect(-w / 2, -h / 2, w, h, 4)
    this.bg.strokeRoundedRect(-w / 2, -h / 2, w, h, 4)
    // Sprechblasen-Zipfel unten
    this.bg.fillTriangle(-4, h / 2, 4, h / 2, 0, h / 2 + 5)
    this.setVisible(true)
    this.setAlpha(1)
    this.hideTimer?.remove()
    this.hideTimer = this.scene.time.delayedCall(holdMs, () => {
      this.scene.tweens.add({ targets: this, alpha: 0, duration: 250, onComplete: () => this.setVisible(false) })
    })
  }

  /**
   * Blase im Kamerabild platzieren.
   *
   * Sie folgt REZI WAAGERECHT, sitzt senkrecht aber immer im festen Band
   * knapp unter dem HUD.
   *
   * Vorher hing sie an REZIs Höhe, also rund 52 px über dem Spieler — und
   * damit genau dort, wo das Spiel stattfindet: über Lauschern, deren
   * Sichtkegeln, über Plattformen und Toren. Ein Hinweis, der verdeckt,
   * worüber er spricht, ist keiner. Ein fester Platz hat zusätzlich den
   * Vorteil, dass der Blick ihn nach dem ersten Mal von selbst findet.
   *
   * Der Zipfel unten zeigt weiterhin nach unten ins Geschehen, damit die
   * Blase erkennbar zu REZI gehört und nicht zum HUD.
   */
  pointAt(x: number): void {
    const cam = this.scene.cameras.main
    const halfW = Math.min(172, this.label.width + 14) / 2
    const clampedX = Phaser.Math.Clamp(x, cam.worldView.x + halfW + 2, cam.worldView.right - halfW - 2)
    const halfH = (this.label.height + 10) / 2
    this.setPosition(clampedX, cam.worldView.y + BAND_OBEN + halfH)
  }
}
