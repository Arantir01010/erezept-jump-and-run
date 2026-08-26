import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { Rezi } from '../actors/Rezi'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { gameState } from '../state/GameState'
import { sealTextureKey } from '../gfx/TextureFactory'
import { drawBackdrop } from '../gfx/backdrop'
import { addText } from '../gfx/text'
import { addGlow } from '../gfx/effects'
import { setupDesignCamera } from '../gfx/view'
import { t } from '../i18n'
import { silhouettePaul } from '../gfx/PaulSilhouette'
import { setzeZeichenTheme, veredele } from '../gfx/vektor'
import { licht } from '../gfx/licht'
import { pille } from '../gfx/material'
import { darken } from '../gfx/atmos'

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
    setzeZeichenTheme(theme)
    const { W, H } = setupDesignCamera(this)
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
    veredele(this, this.portal)
    // Portal-Aura: das Ziel leuchtet — der Blick geht automatisch nach rechts
    addGlow(this, this.portalX, H - 40 - 16, 0x4de3ff, 26, { alpha: 0.4, depth: 2 })

    // Paul + REZI
    this.paul = this.add.sprite(80, H - 40 - 12, 'player-idle0').setDepth(10)
    this.rezi = new Rezi(this, 60, H - 40 - 40)
    this.rezi.follow(this.paul)
    // Silhouette erst NACH REZI: sie braucht die Lichtquelle beim Anlegen.
    silhouettePaul(this, this.paul, theme, { light: this.rezi })
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
    const W = this.cameras.main.displayWidth
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
    const H = this.cameras.main.displayHeight
    const g = this.add.graphics().setDepth(2)
    const w = 90
    const h = 150
    const top = H - 40 - h
    const wand = darken(theme.skyTop, 0.05)
    const kante = Phaser.Display.Color.HexStringToColor(theme.detail).color

    // Baukörper mit Sockel und leicht abgesetztem Obergeschoss — eine
    // rechteckige Platte liest sich als Kulisse, gestufte Massen als Haus.
    g.fillStyle(wand, 1)
    g.fillRoundedRect(cx - w / 2, top, w, h, { tl: 4, tr: 4, bl: 0, br: 0 })
    g.fillStyle(darken(theme.skyTop, 0.25), 1)
    g.fillRect(cx - w / 2 - 4, top + h - 26, w + 8, 26)
    // Kantenlicht auf Dach und Sockel
    g.fillStyle(kante, 0.5)
    g.fillRect(cx - w / 2, top, w, 1.2)
    g.fillStyle(kante, 0.32)
    g.fillRect(cx - w / 2 - 4, top + h - 26, w + 8, 1)

    // Eingang: der Ort, auf den es ankommt — dunkel mit warmem Licht darin
    const tuerB = 20
    g.fillStyle(darken(theme.skyTop, 0.6), 1)
    g.fillRoundedRect(cx - tuerB / 2, top + h - 24, tuerB, 24, { tl: 8, tr: 8, bl: 0, br: 0 })
    g.lineStyle(0.8, 0xffd591, 0.5)
    g.strokeRoundedRect(cx - tuerB / 2, top + h - 24, tuerB, 24, { tl: 8, tr: 8, bl: 0, br: 0 })
    licht(this, { x: cx, y: top + h - 12, farbe: 0xffd591, radius: 26, staerke: 0.4, depth: 2, pfuetze: false })

    // Fenster: schlanke Bogenfenster statt Klötze, ein Drittel bewohnt
    for (let row = 0; row < 4; row++) {
      for (let col = 0; col < 3; col++) {
        const wx = cx - w / 2 + 14 + col * 26
        const wy = top + 16 + row * 31
        const lit = (row * 3 + col + Math.floor(cx / 10)) % 3 === 0
        g.fillStyle(lit ? 0xffd591 : darken(theme.skyTop, 0.45), lit ? 0.9 : 1)
        g.fillRect(wx, wy + 3, 11, 15)
        g.fillTriangle(wx, wy + 3, wx + 11, wy + 3, wx + 5.5, wy - 2)
        if (lit) {
          licht(this, { x: wx + 5.5, y: wy + 8, farbe: 0xffd591, radius: 16, staerke: 0.22, depth: 2, pfuetze: false })
        }
      }
    }

    // Beschriftung: Glas-Pille statt Farbkasten
    const t2 = addText(this, cx, top - 13, label, 9.5, { color: '#eaf6ff' }).setOrigin(0.5).setDepth(4)
    const p2 = this.add.graphics().setDepth(3)
    pille(p2, cx - t2.width / 2 - 8, top - 18, t2.width + 16, 15)
  }
}
