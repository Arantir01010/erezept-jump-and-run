import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { installTouchControls } from '../input/TouchControls'
import { registerPwa } from '../kiosk/pwa'
import { klang } from '../audio/klang'
import { idleWatchdog } from '../kiosk/IdleWatchdog'
import { telemetry } from '../telemetry/Telemetry'
import { addText } from '../gfx/text'
import { setupDesignCamera } from '../gfx/view'

/**
 * Lädt und validiert alle JSON-Konfigurationen, bevor irgendetwas startet.
 * Redakteursfehler (kaputtes Level-JSON) erscheinen hier als lesbarer Text
 * statt als weißer Bildschirm.
 */
export class BootScene extends Phaser.Scene {
  constructor() {
    super('Boot')
  }

  create(): void {
    const { W, H } = setupDesignCamera(this)
    addText(this, W / 2, H / 2, 'Lade Konfiguration …', 13, { color: '#8a93a8' }).setOrigin(0.5)

    configService
      .load()
      .then(() => {
        inputManager.init(this.game, configService.bindings)
        // Touch als dritte Eingabequelle (Windows-Touchscreens, Tablets, PWA)
        installTouchControls(this.game)
        registerPwa()
        // Telemetrie folgt der Config (KAPSEL 4.4) — im Messebetrieb abschaltbar
        telemetry.aktiv = configService.gameConfig.telemetrie
        // Klang ebenso: laute Messestände können das Spiel stummschalten
        klang.aktiv = configService.gameConfig.audio
        idleWatchdog.init(this.game, configService.gameConfig.idleResetSeconds)
        this.scene.start('Preload')
      })
      .catch((err: unknown) => {
        const message = err instanceof Error ? err.message : String(err)
        this.cameras.main.setBackgroundColor('#200a0a')
        addText(this, W / 2, H / 2, `Konfiguration fehlerhaft:\n\n${message}\n\nDatei korrigieren und Seite neu laden.`, 11, {
          color: '#ff8080',
          align: 'center',
          wrapWidth: W - 60,
        }).setOrigin(0.5)
      })
  }
}
