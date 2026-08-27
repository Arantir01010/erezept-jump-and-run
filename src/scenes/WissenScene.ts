import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { drawBackdrop } from '../gfx/backdrop'
import { addVignette } from '../gfx/effects'
import { setupDesignCamera } from '../gfx/view'
import { zeichneWissen, WISSEN_SPERRE, type WissenId } from '../gfx/wissen'

/**
 * WISSEN — animierte ePA-Lehrsequenz VOR einer Station, statt des City-Laufs.
 *
 * GameScene.completeLevel schaut in WISSEN_VOR_LEVEL (src/gfx/wissen.ts):
 * Hat die nächste Station eine Lehrsequenz, landet der Spieler hier statt in
 * der City — erst verstehen, dann spielen. Mechanik wie die IntroScene:
 * Mindest-Anzeigedauer schluckt jede Eingabe (die Botschaft lässt sich nicht
 * wegdrücken), danach startet jeder Knopf die Station direkt. Bleibt jemand
 * stehen, holt ihn der IdleWatchdog zurück in den Attract-Mode.
 */
export class WissenScene extends Phaser.Scene {
  private id: WissenId = 'epa-konto'
  private toLevelIndex = 0
  /** Sperrdauer in ms; der Ablauf-Zeitpunkt wird erst im ersten update
   *  geankert — NUR auf der Szenen-Uhr. Ein Mix aus game.loop.time und
   *  scene.time.now driftet nach Drosselung/Standby auseinander. */
  private sperrDauer = 0
  private sperrBis = -1

  constructor() {
    super('Wissen')
  }

  create(data: { id?: WissenId; toLevelIndex?: number } = {}): void {
    this.id = data.id ?? 'epa-konto'
    this.toLevelIndex = data.toLevelIndex ?? 0
    const { W, H } = setupDesignCamera(this)
    const theme = configService.theme('city')
    drawBackdrop(this, theme, W, H, { nurFerneSilhouette: true })
    zeichneWissen(this, theme, W, H, this.id)
    addVignette(this, W, H)
    this.cameras.main.fadeIn(280, 4, 7, 12)
    this.sperrDauer = WISSEN_SPERRE[this.id] * 1000
    this.sperrBis = -1
  }

  update(): void {
    // Anker im ersten Update: Der Scene-Clock ist in create() noch veraltet.
    if (this.sperrBis < 0) this.sperrBis = this.time.now + this.sperrDauer
    if (this.time.now < this.sperrBis) return
    if (!inputManager.anyButtonJustPressed()) return
    this.scene.start('Game', { levelIndex: this.toLevelIndex })
  }
}
