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
import { verlaufBand } from '../gfx/material'
import { zeichneKrankenhaus } from '../gfx/krankenhaus'

/**
 * Attract-Mode / Startbildschirm: zieht Besucher an und startet auf jeden
 * Knopfdruck in die Intro-Strecke. Die Steuerung wird dort im Probelauf-
 * Screen (gfx/tutorial.ts) vorgeführt — hier steht deshalb kein Paul und
 * keine Steuerungstafel mehr, nur die lebende Klinik-Kulisse.
 * (Auto-Play-Demo: Ausbaustufe.)
 */
export class AttractScene extends Phaser.Scene {
  private pressText!: Phaser.GameObjects.Text
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

    // Titel-Aura
    addGlow(this, W / 2, 78, 0x2f6fd0, 120, { alpha: 0.3 })

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

    // Aufforderung: warmes Gold statt Signalrot. Rot heißt in diesem Spiel
    // „Gefahr/offen" (siehe material.ts) — an der Einladung zum Spielen wäre
    // das die falsche Aussage. Unten rechts in der Ecke, über dem Fußschleier
    // (deshalb depth 3) — die Bildmitte bleibt der Kulisse.
    this.pressText = addText(this, W - 12, 340, '', 16, {
      color: '#ffd591',
      spacing: 0.6,
    })
      .setOrigin(1, 0.5)
      .setDepth(3)
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

    // Info-Tafel am linken Bildschirmrand — Glas-Optik wie die HUD-Pillen
    // (material.ts): Veranstaltungszeile + Rechtshinweis (KAPSEL 4.5 —
    // klein, aber immer sichtbar; Inhalte kommen aus der Config und werden
    // von tools/test/recht.test.ts geprüft). Die Steuerung selbst zeigt
    // jetzt der Probelauf-Screen — hier steht nur noch diese eine Tafel.
    const tafel = this.add.graphics()
    tafel.fillStyle(0x060d16, 0.6)
    tafel.fillRoundedRect(4, 282, 82, 74, 5)
    tafel.lineStyle(0.7, 0xffffff, 0.14)
    tafel.strokeRoundedRect(4, 282, 82, 74, 5)
    tafel.fillStyle(0xffffff, 0.18)
    tafel.fillRoundedRect(8, 282.4, 74, 0.6, 0.3)
    addText(this, 12, 289, cfg.event + ' — Einfach. Sicher. Digital.', 6.5, {
      color: '#7c88a6',
      bold: false,
      wrapWidth: 68,
    }).setOrigin(0, 0)
    addText(this, 12, 321, t(cfg.disclaimer), 6, {
      color: '#5f6a85',
      bold: false,
      wrapWidth: 68,
    }).setOrigin(0, 0)

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

    addVignette(this, W, H)
  }

  private refreshControlLabels(): void {
    const hasPad = inputManager.hasGamepad()
    if (hasPad === this.gamepadMode) return
    this.gamepadMode = hasPad
    const cfg = configService.gameConfig
    this.pressText.setText(t(hasPad ? cfg.titleScreen.pressStart : cfg.titleScreen.pressStartKeyboard))
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
      // Erst die Zeitreise (Früher/Heute) — die IntroScene startet danach
      // UI + City. Die Resets oben bleiben hier: Sie gehören zum Run-Beginn.
      // Phase IMMER explizit mitgeben: Ohne Daten recycelt Phaser die
      // settings.data des letzten Starts — der nächste Besucher begänne
      // sonst mitten in Phase 2.
      this.scene.start('Intro', { phase: 1 })
    }
  }
}
