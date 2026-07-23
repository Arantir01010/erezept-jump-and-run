import Phaser from 'phaser'
import { SpeechBubble } from './SpeechBubble'
import { sealTextureKey } from '../gfx/TextureFactory'

/**
 * REZI — das e-Rezept als Begleiter. Schwebt beim Spieler, spricht die
 * Lernsätze und trägt die gesammelten Siegel sichtbar am Körper.
 */
export class Rezi extends Phaser.GameObjects.Container {
  private body_: Phaser.GameObjects.Sprite
  private sealIcons: Phaser.GameObjects.Image[] = []
  private bubble: SpeechBubble
  private target?: Phaser.GameObjects.Components.Transform
  private bobT = 0
  /** Verschlüsselungs-Optik (Level 3): Schimmer statt Klartext. */
  private shield?: Phaser.GameObjects.Arc

  constructor(scene: Phaser.Scene, x: number, y: number) {
    super(scene, x, y)
    // Weiches Eigenlicht: REZI ist ein digitales Wesen und leuchtet dezent
    const glow = scene.add
      .image(0, 0, 'fx-glow')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(0xbfe9ff)
      .setAlpha(0.22)
    glow.setDisplaySize(30, 30)
    scene.tweens.add({ targets: glow, alpha: 0.13, duration: 1300, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' })
    this.add(glow)
    this.body_ = scene.add.sprite(0, 0, 'rezi-0')
    this.body_.play('rezi-float')
    this.add(this.body_)
    this.setDepth(11)
    scene.add.existing(this)
    // Container stehen nicht automatisch auf der UpdateList → preUpdate aktivieren
    scene.sys.updateList.add(this)
    this.bubble = new SpeechBubble(scene)
  }

  follow(target: Phaser.GameObjects.Components.Transform): void {
    this.target = target
  }

  say(text: string, holdMs = 2800): void {
    this.bubble.show(text, holdMs)
  }

  addSealIcon(sealId: string): void {
    const icon = this.scene.add.image(0, 0, sealTextureKey(this.scene, sealId)).setScale(0.5)
    this.add(icon)
    this.sealIcons.push(icon)
    this.layoutSeals()
    this.scene.tweens.add({ targets: icon, scale: { from: 1.4, to: 0.5 }, duration: 350, ease: 'Back.easeOut' })
  }

  private layoutSeals(): void {
    this.sealIcons.forEach((icon, i) => {
      icon.setPosition(-6 + i * 7, 12)
    })
  }

  setEncrypted(on: boolean): void {
    if (on && !this.shield) {
      this.shield = this.scene.add.arc(0, 0, 16, 0, 360, false, 0x4de3ff, 0.25)
      this.shield.setStrokeStyle(1, 0x4de3ff, 0.8)
      this.addAt(this.shield, 0)
      this.body_.setTint(0x9fd8ff)
    } else if (!on && this.shield) {
      this.shield.destroy()
      this.shield = undefined
      this.body_.clearTint()
    }
  }

  preUpdate(_time: number, delta: number): void {
    this.bobT += delta / 1000
    if (this.target) {
      const tx = this.target.x - 16
      const ty = this.target.y - 26 + Math.sin(this.bobT * 3) * 3
      this.x = Phaser.Math.Linear(this.x, tx, 0.08)
      this.y = Phaser.Math.Linear(this.y, ty, 0.08)
      // Funkenspur, wenn REZI zügig unterwegs ist (dezent, selbstlöschend)
      this.trailCooldown -= delta
      if (this.trailCooldown <= 0 && Math.abs(tx - this.x) > 6) {
        this.trailCooldown = 150
        const spark = this.scene.add
          .image(this.x, this.y + 2, 'fx-mote')
          .setBlendMode(Phaser.BlendModes.ADD)
          .setTint(0x9fd8ff)
          .setAlpha(0.4)
          .setScale(0.5)
          .setDepth(10)
        this.scene.tweens.add({
          targets: spark,
          alpha: 0,
          scale: 0.15,
          y: spark.y + 4,
          duration: 420,
          ease: 'Cubic.easeOut',
          onComplete: () => spark.destroy(),
        })
      }
    }
    this.bubble.pointAt(this.x, this.y - 26)
  }

  private trailCooldown = 0
}
