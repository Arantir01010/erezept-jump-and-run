import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { gameState } from '../state/GameState'
import { qualifies, addHighscore, getHighscores } from '../state/Highscore'
import { createRewardCodeProvider } from '../reward/RewardCodeProvider'
import { createQrTexture } from '../reward/QrRenderer'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { sealTextureKey } from '../gfx/TextureFactory'
import { addText } from '../gfx/text'
import { addGlow, addVignette } from '../gfx/effects'
import { setupDesignCamera } from '../gfx/view'
import { t } from '../i18n'

const AVATAR_COUNT = 12

/**
 * Der Payoff: „Dein e-Rezept ist da!" — QR-Code für den Medikamentenautomaten,
 * Siegel-Reihe des Wegs, Sicherheitsstufe, Tages-Highscore (Avatar statt Name).
 * Rot überspringt (frühestens nach minQrSeconds), Auto-Reset nach rewardScreenSeconds.
 */
export class RewardScene extends Phaser.Scene {
  /** Akkumulierte Update-Deltas — unabhängig von der absoluten Zeitbasis. */
  private elapsedMs = 0
  private avatarIndex = 0
  private avatarCursor?: Phaser.GameObjects.Rectangle
  private avatarSaved = false
  private pickerActive = false
  private hintText!: Phaser.GameObjects.Text

  constructor() {
    super('Reward')
  }

  create(): void {
    this.scene.stop('UI')
    this.elapsedMs = 0
    this.avatarSaved = false
    this.avatarIndex = 0

    const cfg = configService.gameConfig
    const { W, H } = setupDesignCamera(this)
    this.cameras.main.setBackgroundColor('#0d1638')
    this.cameras.main.fadeIn(400)

    // Konfetti-Bits (dezent, keine Blitze)
    for (let i = 0; i < 24; i++) {
      const bit = this.add.image(Math.random() * W, -10 - Math.random() * 150, 'datenbit').setAlpha(0.7)
      this.tweens.add({
        targets: bit,
        y: H + 10,
        x: bit.x + (Math.random() * 40 - 20),
        angle: 180,
        duration: 4000 + Math.random() * 3000,
        repeat: -1,
        delay: Math.random() * 2000,
      })
    }

    addText(this, W / 2, 32, 'Dein e-Rezept ist da!', 23, { stroke: '#2f6fd0', strokeThickness: 3 }).setOrigin(0.5)
    addText(this, W / 2, 56, 'Löse es am Medikamentenautomaten ein!', 12, { color: '#cfe0ff' }).setOrigin(0.5)

    // Weg-Zeile: alle Siegel des Durchlaufs
    const seals = gameState.seals
    const startX = W / 2 - ((seals.length - 1) * 26) / 2
    seals.forEach((seal, i) => {
      this.add.image(startX + i * 26, 82, sealTextureKey(this, seal.sealId)).setScale(1.2)
    })

    // Titel-Aura + goldenes Licht hinter dem QR-Rahmen (der Payoff strahlt)
    addGlow(this, W / 2, 32, 0x2f6fd0, 95, { alpha: 0.28 })
    addGlow(this, W / 2, 158, 0xffd75e, 85, { alpha: 0.22 })

    // QR-Code (offline generiert) — nativ 1:1 gezeichnet, nie skaliert:
    // Nur so bleiben alle Module gleich breit und der Scan zuverlässig.
    this.add.rectangle(W / 2, 158, 108, 108, 0xffffff).setStrokeStyle(2, 0xffd75e)
    const provider = createRewardCodeProvider(cfg)
    createQrTexture(this, 'qr-reward', provider.payload())
      .then((key) => {
        if (!this.scene.isActive('Reward')) return // Szene inzwischen verlassen
        this.add.image(W / 2, 158, key)
      })
      .catch((err: unknown) => console.error('[reward] QR fehlgeschlagen', err))

    // Score + Sicherheitsstufe
    const rank = gameState.rank()
    addText(this, W / 2, 226, `${gameState.score} Punkte  ·  Sicherheitsstufe: ${t(rank.label)}`, 12, {
      color: rank.key === 'gold' ? '#ffd75e' : rank.key === 'silber' ? '#c8d4e8' : '#d09a6a',
    }).setOrigin(0.5)

    // Highscore-Eintrag per Avatar-Wahl
    if (qualifies(gameState.score)) {
      this.pickerActive = true
      addText(this, W / 2, 249, 'Tages-Top-5! Icon wählen (←/→ oder Joystick), BLAU/E bestätigt:', 10, {
        color: '#7fd07f',
      }).setOrigin(0.5)
      const pickerStartX = W / 2 - ((AVATAR_COUNT - 1) * 22) / 2
      for (let i = 0; i < AVATAR_COUNT; i++) {
        this.add.image(pickerStartX + i * 22, 272, `avatar-${i}`)
      }
      this.avatarCursor = this.add
        .rectangle(pickerStartX, 272, 20, 20)
        .setStrokeStyle(2, 0xffd75e)
    }

    this.hintText = addText(this, W / 2, H - 16, '', 10, { color: '#aab6d4' }).setOrigin(0.5)

    addVignette(this, W, H)
  }

  private backToAttract(): void {
    if (!this.scene.isActive('Reward')) return
    this.scene.start('Attract')
  }

  update(_time: number, delta: number): void {
    const cfg = configService.gameConfig
    this.elapsedMs += delta
    const elapsed = this.elapsedMs / 1000
    if (elapsed >= cfg.ending.rewardScreenSeconds) {
      this.backToAttract()
      return
    }
    const canSkip = elapsed >= cfg.ending.minQrSeconds
    this.hintText.setText(canSkip ? (inputManager.hasGamepad() ? 'ROT: weiter' : 'LEERTASTE: weiter') : '')

    // Avatar-Picker
    if (this.pickerActive && !this.avatarSaved && this.avatarCursor) {
      if (inputManager.justPressed(GameAction.Left)) this.avatarIndex = (this.avatarIndex + AVATAR_COUNT - 1) % AVATAR_COUNT
      if (inputManager.justPressed(GameAction.Right)) this.avatarIndex = (this.avatarIndex + 1) % AVATAR_COUNT
      const W = this.cameras.main.displayWidth
      const pickerStartX = W / 2 - ((AVATAR_COUNT - 1) * 22) / 2
      this.avatarCursor.x = pickerStartX + this.avatarIndex * 22
      if (inputManager.justPressed(GameAction.Action)) {
        addHighscore({ avatar: this.avatarIndex, score: gameState.score })
        this.avatarSaved = true
        this.avatarCursor.setStrokeStyle(2, 0x7fd07f)
        const rankPos = getHighscores().findIndex((e) => e.score === gameState.score) + 1
        addText(this, this.cameras.main.displayWidth / 2, 292, `Gespeichert — Platz ${rankPos} heute!`, 10, {
          color: '#7fd07f',
        }).setOrigin(0.5)
      }
    }

    // QR mindestens minQrSeconds zeigen — wer das Handy zückt, wird nicht überrascht
    if (canSkip && inputManager.justPressed(GameAction.Jump)) this.backToAttract()
  }
}
