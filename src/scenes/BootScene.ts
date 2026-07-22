import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { idleWatchdog } from '../kiosk/IdleWatchdog'

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
    const W = this.cameras.main.width
    const H = this.cameras.main.height
    this.add
      .text(W / 2, H / 2, 'Lade Konfiguration …', { fontFamily: 'Courier New, monospace', fontSize: '12px', color: '#8a93a8' })
      .setResolution(3)
      .setOrigin(0.5)

    configService
      .load()
      .then(() => {
        inputManager.init(this.game, configService.bindings)
        idleWatchdog.init(this.game, configService.gameConfig.idleResetSeconds)
        this.scene.start('Preload')
      })
      .catch((err: unknown) => {
        const message = err instanceof Error ? err.message : String(err)
        this.cameras.main.setBackgroundColor('#200a0a')
        this.add
          .text(W / 2, H / 2, `Konfiguration fehlerhaft:\n\n${message}\n\nDatei korrigieren und Seite neu laden.`, {
            fontFamily: 'Courier New, monospace',
            fontSize: '10px',
            color: '#ff8080',
            align: 'center',
            wordWrap: { width: W - 60 },
          })
          .setResolution(3)
          .setOrigin(0.5)
      })
  }
}
