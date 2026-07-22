import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { gameState } from '../state/GameState'
import { assist } from '../state/Assist'
import { getHighscores } from '../state/Highscore'
import { drawBackdrop } from '../gfx/backdrop'
import { t } from '../i18n'

/**
 * Attract-Mode / Startbildschirm: zieht Besucher an, erklärt in einer Zeile
 * die Steuerung und startet auf jeden Knopfdruck. (Auto-Play-Demo: Ausbaustufe.)
 */
const LEGEND_ARCADE = 'Joystick: laufen & ducken   ·   ROT: springen   ·   BLAU: TI-Aktion'
const LEGEND_KEYBOARD = 'Pfeiltasten/WASD: laufen & ducken   ·   LEERTASTE: springen   ·   E/ENTER: TI-Aktion'

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

    this.add
      .text(W / 2, 78, t(cfg.titleScreen.headline), {
        fontFamily: 'Courier New, monospace',
        fontSize: '34px',
        fontStyle: 'bold',
        color: '#ffffff',
        stroke: '#2f6fd0',
        strokeThickness: 4,
      })
      .setResolution(2)
      .setOrigin(0.5)

    this.add
      .text(W / 2, 112, t(cfg.titleScreen.subline), {
        fontFamily: 'Courier New, monospace',
        fontSize: '11px',
        color: '#bfd4ff',
      })
      .setResolution(3)
      .setOrigin(0.5)

    // Paul + REZI als Blickfang
    const paul = this.add.sprite(W / 2 - 20, 190, 'player-idle0').setScale(2)
    paul.play('player-idle')
    const rezi = this.add.sprite(W / 2 + 24, 176, 'rezi-0').setScale(2)
    rezi.play('rezi-float')
    this.tweens.add({ targets: rezi, y: 170, duration: 1200, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' })

    this.pressText = this.add
      .text(W / 2, 240, '', {
        fontFamily: 'Courier New, monospace',
        fontSize: '15px',
        fontStyle: 'bold',
        color: '#ff4040',
      })
      .setResolution(3)
      .setOrigin(0.5)
    // Blinken deutlich unter 3 Hz (Barrierefreiheit)
    this.tweens.add({ targets: this.pressText, alpha: 0.15, duration: 650, yoyo: true, repeat: -1 })

    this.legendText = this.add
      .text(W / 2, 270, '', {
        fontFamily: 'Courier New, monospace',
        fontSize: '9px',
        color: '#8a93a8',
      })
      .setResolution(3)
      .setOrigin(0.5)

    // Steuerungsanzeige folgt der angeschlossenen Hardware — auch live beim Ein-/Ausstecken
    this.gamepadMode = !inputManager.hasGamepad()
    this.refreshControlLabels()

    // Tages-Highscore (Avatar-Icons statt Namen — keine Personendaten)
    const scores = getHighscores()
    if (scores.length > 0) {
      this.add
        .text(W - 70, 150, 'Heute Top 5', { fontFamily: 'Courier New, monospace', fontSize: '9px', fontStyle: 'bold', color: '#ffd75e' })
        .setResolution(3)
        .setOrigin(0.5)
      scores.forEach((entry, i) => {
        this.add.image(W - 100, 168 + i * 18, `avatar-${entry.avatar}`)
        this.add
          .text(W - 88, 163 + i * 18, String(entry.score).padStart(6, ' '), {
            fontFamily: 'Courier New, monospace',
            fontSize: '9px',
            color: '#ffffff',
          })
          .setResolution(3)
      })
    }

    this.add
      .text(W / 2, H - 12, cfg.event + ' — Einfach. Sicher. Digital.', {
        fontFamily: 'Courier New, monospace',
        fontSize: '8px',
        color: '#5a6580',
      })
      .setResolution(3)
      .setOrigin(0.5)
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
