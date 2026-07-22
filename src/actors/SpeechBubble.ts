import Phaser from 'phaser'

/**
 * Sprechblase im Spielraum (pausiert das Spiel nie).
 * Max. 1 Satz — Textmenge wird durch die Level-JSONs diszipliniert.
 */
export class SpeechBubble extends Phaser.GameObjects.Container {
  private bg: Phaser.GameObjects.Graphics
  private label: Phaser.GameObjects.Text
  private hideTimer?: Phaser.Time.TimerEvent

  constructor(scene: Phaser.Scene) {
    super(scene, 0, 0)
    this.bg = scene.add.graphics()
    this.label = scene.add
      .text(0, 0, '', {
        fontFamily: 'Courier New, monospace',
        fontSize: '9px',
        color: '#20242e',
        align: 'center',
        wordWrap: { width: 150 },
      })
      .setResolution(3)
      .setOrigin(0.5, 0.5)
    this.add([this.bg, this.label])
    this.setDepth(60)
    this.setVisible(false)
    scene.add.existing(this)
  }

  show(text: string, holdMs = 2800): void {
    this.label.setText(text)
    const w = Math.min(160, this.label.width + 12)
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

  /** Blase über einem Punkt positionieren, im Kamerabild halten. */
  pointAt(x: number, y: number): void {
    const cam = this.scene.cameras.main
    const halfW = Math.min(160, this.label.width + 12) / 2
    const clampedX = Phaser.Math.Clamp(x, cam.worldView.x + halfW + 2, cam.worldView.right - halfW - 2)
    this.setPosition(clampedX, y)
  }
}
