import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { Rezi } from '../actors/Rezi'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { gameState } from '../state/GameState'
import { sealTextureKey } from '../gfx/TextureFactory'
import { drawBackdrop } from '../gfx/backdrop'
import { addText } from '../gfx/text'
import { t } from '../i18n'

const WALK_MS = 2200
const STAMP_MS = 1700

/**
 * Stadt-Band zwischen den Stationen (≤ 5 s): Auftauch-Stempel des letzten
 * Levels, kurzer Lauf zur nächsten Fassade, Portal-Dive per blauem Knopf.
 * Der blaue Knopf ist hier zugleich Tutorial: Blau = TI-Aktion.
 */
export class CityScene extends Phaser.Scene {
  private toLevelIndex = 0
  private paul!: Phaser.GameObjects.Sprite
  private rezi!: Rezi
  private portal!: Phaser.GameObjects.Sprite
  private portalX = 0
  private phase: 'stamp' | 'walk' | 'portal' | 'dive' = 'walk'
  private walkTween?: Phaser.Tweens.Tween

  constructor() {
    super('City')
  }

  init(data: { toLevelIndex?: number }): void {
    this.toLevelIndex = data.toLevelIndex ?? 0
    this.phase = 'walk'
  }

  create(): void {
    const theme = configService.theme('city')
    const W = this.cameras.main.width
    const H = this.cameras.main.height
    drawBackdrop(this, theme, W, H)

    // Straße
    const street = this.add.graphics().setDepth(1)
    street.fillStyle(Phaser.Display.Color.HexStringToColor(theme.ground).color, 1)
    street.fillRect(0, H - 40, W, 40)
    street.fillStyle(Phaser.Display.Color.HexStringToColor(theme.groundTop).color, 1)
    street.fillRect(0, H - 40, W, 4)

    const target = configService.level(this.toLevelIndex)
    const from = this.toLevelIndex > 0 ? configService.level(this.toLevelIndex - 1) : null

    // Fassaden: links Herkunft, rechts Ziel mit Portal
    this.drawFacade(70, from ? t(from.cityAnchor.label) : 'Arztpraxis', theme)
    this.portalX = W - 120
    this.drawFacade(this.portalX + 50, t(target.cityAnchor.label), theme)
    this.portal = this.add.sprite(this.portalX, H - 40 - 16, 'portal-0').setDepth(3)
    this.portal.play('portal-spin')

    // Paul + REZI
    this.paul = this.add.sprite(80, H - 40 - 12, 'player-idle0').setDepth(10)
    this.rezi = new Rezi(this, 60, H - 40 - 40)
    this.rezi.follow(this.paul)
    for (const seal of gameState.seals) this.rezi.addSealIcon(seal.sealId)
    if (gameState.encrypted) this.rezi.setEncrypted(true)

    this.cameras.main.fadeIn(300)

    if (from) {
      this.phase = 'stamp'
      this.showArrivalStamp(from, () => this.startWalk())
    } else {
      this.startWalk()
    }
  }

  /** Auftauch-Stempel: Lernsatz-Bestätigung + Siegel-Moment des letzten Levels. */
  private showArrivalStamp(from: ReturnType<typeof configService.level>, done: () => void): void {
    const W = this.cameras.main.width
    const box = this.add.container(W / 2, 70).setDepth(80).setScale(0.3)
    const text = addText(this, 0, 0, t(from.station.stampText), 13, {
      color: '#20242e',
      bg: '#ffffff',
      padding: { x: 9, y: 6 },
    }).setOrigin(0.5)
    const badge = addText(this, 0, 22, from.station.badge, 10, {
      color: '#ffffff',
      bg: '#2f6fd0',
      padding: { x: 5, y: 3 },
    }).setOrigin(0.5)
    const seal = this.add.image(-text.width / 2 - 14, 0, sealTextureKey(this, from.siegelIcon))
    box.add([text, badge, seal])
    this.tweens.add({ targets: box, scale: 1, duration: 250, ease: 'Back.easeOut' })
    this.time.delayedCall(STAMP_MS, () => {
      this.tweens.add({ targets: box, alpha: 0, y: 40, duration: 300, onComplete: () => box.destroy() })
      done()
    })
  }

  private startWalk(): void {
    this.phase = 'walk'
    this.paul.play('player-run')
    this.walkTween = this.tweens.add({
      targets: this.paul,
      x: this.portalX - 18,
      duration: WALK_MS,
      onComplete: () => this.arriveAtPortal(),
    })
  }

  private arriveAtPortal(): void {
    if (this.phase === 'dive') return
    this.phase = 'portal'
    this.paul.play('player-idle')
    const actionLabel = inputManager.hasGamepad() ? 'Blauer Knopf' : 'Taste E'
    this.rezi.say(t(configService.level(this.toLevelIndex).cityAnchor.label) + ` — ${actionLabel}: Abtauchen!`)
    this.tweens.add({ targets: this.portal, scale: { from: 1, to: 1.15 }, duration: 500, yoyo: true, repeat: -1 })
  }

  private dive(): void {
    this.phase = 'dive'
    this.walkTween?.stop()
    // Paul löst sich in Pixel auf und taucht in die digitale Ebene ab
    this.tweens.add({
      targets: [this.paul, this.rezi],
      x: this.portalX,
      alpha: 0,
      scale: 0.3,
      duration: 450,
      ease: 'Cubic.easeIn',
    })
    this.tweens.add({ targets: this.portal, scale: 2, alpha: 0, duration: 500, delay: 200 })
    this.cameras.main.flash(250, 77, 227, 255)
    this.time.delayedCall(550, () => this.scene.start('Game', { levelIndex: this.toLevelIndex }))
  }

  update(): void {
    if (inputManager.justPressed(GameAction.Action)) {
      if (this.phase === 'walk') {
        // Blau überspringt den Lauf — Durchsatz vor Schönheit
        this.walkTween?.stop()
        this.paul.x = this.portalX - 18
        this.arriveAtPortal()
      } else if (this.phase === 'portal') {
        this.dive()
      }
    }
  }

  private drawFacade(cx: number, label: string, theme: { detail: string; skyTop: string; accent: string }): void {
    const H = this.cameras.main.height
    const g = this.add.graphics().setDepth(2)
    const w = 90
    const h = 150
    g.fillStyle(Phaser.Display.Color.HexStringToColor(theme.detail).color, 1)
    g.fillRect(cx - w / 2, H - 40 - h, w, h)
    g.fillStyle(Phaser.Display.Color.HexStringToColor(theme.skyTop).color, 1)
    for (let row = 0; row < 4; row++) {
      for (let col = 0; col < 3; col++) {
        g.fillRect(cx - w / 2 + 12 + col * 26, H - 40 - h + 14 + row * 32, 14, 18)
      }
    }
    addText(this, cx, H - 40 - h - 11, label, 10, {
      color: '#ffffff',
      bg: '#20242e',
      padding: { x: 5, y: 3 },
    })
      .setOrigin(0.5)
      .setDepth(3)
  }
}
