import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { drawBackdrop } from '../gfx/backdrop'
import { addVignette } from '../gfx/effects'
import { setupDesignCamera } from '../gfx/view'
import { zeichneZeitreise } from '../gfx/zeitreise'

/**
 * Zeitreise-Intro zwischen Attract-Mode und Spielstart:
 *
 *   Leertaste im Menü  →  Phase 1 „FRÜHER"  (Papierstapel von Tür zu Tür)
 *   Leertaste          →  Phase 2 „HEUTE"   (das E-Rezept reist durch die TI)
 *   Leertaste          →  Spielstart (City, Level 1)
 *
 * Der Phasenwechsel läuft über scene.restart — der Szenen-Shutdown räumt
 * Grafiken, Tweens und Update-Hooks der Kulisse von selbst ab. Bleibt ein
 * Besucher hier stehen, holt ihn der IdleWatchdog zurück in den Attract-Mode.
 */
export class IntroScene extends Phaser.Scene {
  private phase: 1 | 2 = 1
  private sperre = 0

  constructor() {
    super('Intro')
  }

  create(data: { phase?: number } = {}): void {
    this.phase = data.phase === 2 ? 2 : 1
    const { W, H } = setupDesignCamera(this)
    const theme = configService.theme('city')
    drawBackdrop(this, theme, W, H, { nurFerneSilhouette: true })
    zeichneZeitreise(this, theme, W, H, this.phase)
    addVignette(this, W, H)
    this.cameras.main.fadeIn(280, 4, 7, 12)
    // Entprellen: Der Druck, der hierher geführt hat, blättert nicht weiter
    this.sperre = this.time.now + 600
  }

  update(): void {
    if (this.time.now < this.sperre) return
    if (!inputManager.anyButtonJustPressed()) return
    if (this.phase === 1) {
      this.scene.restart({ phase: 2 })
      return
    }
    if (!this.scene.isActive('UI')) this.scene.launch('UI')
    this.scene.start('City', { toLevelIndex: 0 })
  }
}
