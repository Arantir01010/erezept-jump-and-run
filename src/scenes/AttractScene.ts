import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { gameState } from '../state/GameState'
import { assist } from '../state/Assist'
import { getHighscores } from '../state/Highscore'
import { drawBackdrop } from '../gfx/backdrop'
import { addText } from '../gfx/text'
import { t } from '../i18n'

/**
 * Attract-Mode / Startbildschirm: zieht Besucher an, erklärt in einer Zeile
 * die Steuerung und startet auf jeden Knopfdruck. (Auto-Play-Demo: Ausbaustufe.)
 */
const LEGEND_ARCADE = 'Joystick: laufen & ducken  ·  ROT: springen  ·  BLAU: TI-Aktion'
const LEGEND_KEYBOARD = 'Pfeile/WASD: laufen & ducken  ·  LEERTASTE: springen  ·  E: TI-Aktion'

export class AttractScene extends Phaser.Scene {
  private pressText!: Phaser.GameObjects.Text
  private legendText!: Phaser.GameObjects.Text
  private gamepadMode = false

  constructor() {
    super('Attract')
  }

  create(): void {
    const cfg = configService.gameConfig
    const W = this.cameras.main.width
    const H = this.cameras.main.height
    drawBackdrop(this, configService.theme('city'), W, H)

    addText(this, W / 2, 76, t(cfg.titleScreen.headline), 34, {
      stroke: '#2f6fd0',
      strokeThickness: 4,
    }).setOrigin(0.5)

    addText(this, W / 2, 110, t(cfg.titleScreen.subline), 12, { color: '#cfe0ff' }).setOrigin(0.5)

    // Paul + REZI als Blickfang
    const paul = this.add.sprite(W / 2 - 20, 188, 'player-idle0').setScale(2)
    paul.play('player-idle')
    const rezi = this.add.sprite(W / 2 + 24, 174, 'rezi-0').setScale(2)
    rezi.play('rezi-float')
    this.tweens.add({ targets: rezi, y: 168, duration: 1200, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' })

    this.pressText = addText(this, W / 2, 238, '', 17, { color: '#ff5050' }).setOrigin(0.5)
    // Blinken deutlich unter 3 Hz (Barrierefreiheit)
    this.tweens.add({ targets: this.pressText, alpha: 0.15, duration: 650, yoyo: true, repeat: -1 })

    this.legendText = addText(this, W / 2, 268, '', 11, { color: '#aab6d4' }).setOrigin(0.5)

    // Steuerungsanzeige folgt der angeschlossenen Hardware — auch live beim Ein-/Ausstecken
    this.gamepadMode = !inputManager.hasGamepad()
    this.refreshControlLabels()

    // Tages-Highscore (Avatar-Icons statt Namen — keine Personendaten)
    const scores = getHighscores()
    if (scores.length > 0) {
      addText(this, W - 70, 148, 'Heute Top 5', 10, { color: '#ffd75e' }).setOrigin(0.5)
      scores.forEach((entry, i) => {
        this.add.image(W - 104, 168 + i * 19, `avatar-${entry.avatar}`)
        addText(this, W - 92, 162 + i * 19, String(entry.score).padStart(6, ' '), 10)
      })
    }

    addText(this, W / 2, H - 12, cfg.event + ' — Einfach. Sicher. Digital.', 9, { color: '#7c88a6' }).setOrigin(0.5)
  }

  private refreshControlLabels(): void {
    const hasPad = inputManager.hasGamepad()
    if (hasPad === this.gamepadMode) return
    this.gamepadMode = hasPad
    const cfg = configService.gameConfig
    this.pressText.setText(t(hasPad ? cfg.titleScreen.pressStart : cfg.titleScreen.pressStartKeyboard))
    this.legendText.setText(hasPad ? LEGEND_ARCADE : LEGEND_KEYBOARD)
  }

  update(): void {
    this.refreshControlLabels()
    if (inputManager.anyButtonJustPressed()) {
      gameState.reset()
      assist.reset()
      if (!this.scene.isActive('UI')) this.scene.launch('UI')
      this.scene.start('City', { toLevelIndex: 0 })
    }
  }
}
