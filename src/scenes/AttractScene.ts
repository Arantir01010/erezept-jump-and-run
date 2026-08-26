import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { gameState } from '../state/GameState'
import { assist } from '../state/Assist'
import { protokoll } from '../state/Protokoll'
import { kartenState } from '../state/KartenState'
import { telemetry } from '../telemetry/Telemetry'
import { speichereSitzung } from '../telemetry/speicher'
import { getHighscores } from '../state/Highscore'
import { drawBackdrop } from '../gfx/backdrop'
import { addText } from '../gfx/text'
import { addGlow, addVignette } from '../gfx/effects'
import { setupDesignCamera } from '../gfx/view'
import { t } from '../i18n'
import { silhouettePaul } from '../gfx/PaulSilhouette'
import { zeichneReziKoerper } from '../gfx/ReziBody'
import { verlaufBand } from '../gfx/material'
import { zeichneKrankenhaus } from '../gfx/krankenhaus'

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
    const { W, H } = setupDesignCamera(this)
    const theme = configService.theme('city')
    // Statt der Hochhaus-Silhouetten: das lebende Klinikum als Hauptmotiv.
    // Die fernste Skyline bleibt als Tiefenebene dahinter stehen.
    drawBackdrop(this, theme, W, H, { nurFerneSilhouette: true })
    zeichneKrankenhaus(this, theme, W, H)

    // Titel-Aura + sanftes Bühnenlicht auf Paul & REZI
    addGlow(this, W / 2, 78, 0x2f6fd0, 120, { alpha: 0.3 })
    addGlow(this, W / 2, 185, 0xcfe0ff, 65, { alpha: 0.12 })

    // Kein dicker Konturrahmen mehr: Eine 4-px-Kontur um eine Groteske sieht
    // nach Vereinsplakat aus. Die Lesbarkeit trägt jetzt die Aura darunter
    // plus eine hauchdünne dunkle Kontur gegen helle Fassaden.
    addText(this, W / 2, 76, t(cfg.titleScreen.headline), 36, {
      stroke: '#0a1730',
      strokeThickness: 1.2,
      spacing: 0.5,
    }).setOrigin(0.5)

    // Hauchdünne Kontur wie an der Headline: Durch die Kulisse fliegt u. a.
    // ein heller Heli — ohne Kontur wäre der Text davor kurz weiß auf weiß.
    addText(this, W / 2, 112, t(cfg.titleScreen.subline), 11.5, {
      color: '#cfe0ff',
      bold: false,
      stroke: '#0a1730',
      strokeThickness: 1,
    }).setOrigin(0.5)

    // Paul + REZI als Blickfang
    const paul = this.add.sprite(W / 2 - 20, 188, 'player-idle0').setScale(2)
    paul.play('player-idle')
    silhouettePaul(this, paul, configService.theme('city'), { lightSide: 1 })
    // Dieselbe REZI wie im Spiel (Vektorkarte), nur doppelt so groß
    const rezi = this.add.container(W / 2 + 24, 174, [zeichneReziKoerper(this)]).setScale(2)
    const reziGlow = this.add
      .image(W / 2 + 24, 174, 'fx-glow')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(0x8fffe4)
      .setAlpha(0.3)
    reziGlow.setDisplaySize(90, 90)
    this.tweens.add({
      targets: [rezi, reziGlow],
      y: 168,
      duration: 1200,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    })

    // Aufforderung: warmes Gold statt Signalrot. Rot heißt in diesem Spiel
    // „Gefahr/offen" (siehe material.ts) — an der Einladung zum Spielen wäre
    // das die falsche Aussage.
    this.pressText = addText(this, W / 2, 240, '', 16, {
      color: '#ffd591',
      spacing: 0.6,
    }).setOrigin(0.5)
    // Blinken deutlich unter 3 Hz (Barrierefreiheit)
    this.tweens.add({
      targets: this.pressText,
      alpha: 0.35,
      duration: 750,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    })

    // Schleier hinter dem Fußbereich: Der Rechtshinweis stand bisher direkt
    // auf den Fassaden und war kaum lesbar.
    const fuss = this.add.graphics()
    verlaufBand(this, fuss, 0, H - 60, W, 60, 0x04090f, 0, 0.72)

    this.legendText = addText(this, W / 2, 268, '', 10.5, {
      color: '#b8c6e0',
      bold: false,
    }).setOrigin(0.5)

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

    addText(this, W / 2, H - 22, cfg.event + ' — Einfach. Sicher. Digital.', 9, { color: '#7c88a6' }).setOrigin(0.5)

    // Rechtlicher Hinweis (KAPSEL 4.5): klein am Rand, aber immer sichtbar.
    // Inhalt kommt aus der Config und wird von tools/test/recht.test.ts geprüft.
    addText(this, W / 2, H - 10, t(cfg.disclaimer), 8, { color: '#5f6a85' }).setOrigin(0.5)

    addVignette(this, W, H)
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
      // Der vorige Durchlauf ist vorbei: sichern, dann eine frische Sitzung.
      // Reihenfolge ist wichtig — nach neueSitzung() waere er weg.
      speichereSitzung(telemetry.toJSON())
      telemetry.neueSitzung()
      gameState.reset()
      assist.reset()
      protokoll.reset()
      // Ausweise gehören dem Besucher, nicht dem Automaten — jeder Durchlauf
      // fängt ohne Karten an (sonst erbt der Nächste fremde Identitäten).
      kartenState.reset()
      if (!this.scene.isActive('UI')) this.scene.launch('UI')
      this.scene.start('City', { toLevelIndex: 0 })
    }
  }
}
