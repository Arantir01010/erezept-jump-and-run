import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { drawBackdrop } from '../gfx/backdrop'
import { addVignette } from '../gfx/effects'
import { setupDesignCamera } from '../gfx/view'
import { zeichneZeitreise, ZEITREISE_SPERRE } from '../gfx/zeitreise'
import { zeichneTutorial, TUTORIAL_SPERRE } from '../gfx/tutorial'

/**
 * Intro-Strecke zwischen Attract-Mode und Spielstart:
 *
 *   Leertaste im Menü  →  Phase 1 „FRÜHER"      (Papierzeit, Story-Zeilen)
 *   Leertaste          →  Phase 2 „HEUTE"       (die TI Schritt für Schritt)
 *   Leertaste          →  Phase 3 „PROBELAUF"   (Paul zeigt die Steuerung)
 *   Leertaste          →  Spielstart (City, Level 1)
 *
 * Jede Phase hat eine MINDEST-ANZEIGEDAUER (Konstanten der Kulissen-Module):
 * Solange sie läuft, wird jede Eingabe verschluckt und die LEERTASTE-Zeile
 * bleibt unsichtbar — die Geschichte lässt sich nicht wegdrücken. Die
 * Kulisse zeigt stattdessen einen feinen Zeitbalken.
 *
 * Der Phasenwechsel läuft über scene.restart — der Szenen-Shutdown räumt
 * Grafiken, Tweens und Update-Hooks von selbst ab. Bleibt ein Besucher
 * stehen, holt ihn der IdleWatchdog zurück in den Attract-Mode.
 */
export class IntroScene extends Phaser.Scene {
  private phase: 1 | 2 | 3 = 1
  /** Sperrdauer in ms; Ablauf wird im ersten update auf der SZENEN-Uhr
   *  geankert — ein Mix aus game.loop.time und scene.time.now driftet
   *  nach Drosselung/Standby auseinander. */
  private sperrDauer = 0
  private sperrBis = -1

  constructor() {
    super('Intro')
  }

  create(data: { phase?: number } = {}): void {
    this.phase = data.phase === 2 ? 2 : data.phase === 3 ? 3 : 1
    const { W, H } = setupDesignCamera(this)
    const theme = configService.theme('city')
    drawBackdrop(this, theme, W, H, { nurFerneSilhouette: true })
    let dauer: number
    if (this.phase === 3) {
      zeichneTutorial(this, theme, W, H)
      dauer = TUTORIAL_SPERRE
    } else {
      zeichneZeitreise(this, theme, W, H, this.phase)
      dauer = ZEITREISE_SPERRE[this.phase]
    }
    addVignette(this, W, H)
    this.cameras.main.fadeIn(280, 4, 7, 12)
    // Mindest-Anzeigedauer: verschluckt auch den Druck, der hierher führte.
    this.sperrDauer = dauer * 1000
    this.sperrBis = -1
  }

  update(): void {
    // Anker im ersten Update: Der Scene-Clock ist in create() noch veraltet.
    if (this.sperrBis < 0) this.sperrBis = this.time.now + this.sperrDauer
    if (this.time.now < this.sperrBis) return
    if (!inputManager.anyButtonJustPressed()) return
    if (this.phase < 3) {
      this.scene.restart({ phase: this.phase + 1 })
      return
    }
    if (!this.scene.isActive('UI')) this.scene.launch('UI')
    this.scene.start('City', { toLevelIndex: 0 })
  }
}
