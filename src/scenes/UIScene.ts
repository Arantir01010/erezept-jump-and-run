import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import type { LevelConfig } from '../level/schema'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { sealTextureKey } from '../gfx/TextureFactory'
import { t } from '../i18n'

/**
 * Persistentes HUD über City- und Game-Szenen:
 * Stationsname, Datenbits, TI-Streckenkarte (Siegel-Slots = QR-Fragmente),
 * Portal-Einblendung, Idle-Warnung, F8-Kalibrier-Overlay, ?debug=1-FPS.
 */
export class UIScene extends Phaser.Scene {
  private stationText!: Phaser.GameObjects.Text
  private bitsText!: Phaser.GameObjects.Text
  private sealSlots: { frame: Phaser.GameObjects.Rectangle; icon: Phaser.GameObjects.Image }[] = []
  private idleText!: Phaser.GameObjects.Text
  private lastIdleWarnMs = 0
  private calibText?: Phaser.GameObjects.Text
  private fpsText?: Phaser.GameObjects.Text
  private portalOverlay?: Phaser.GameObjects.Container

  constructor() {
    super('UI')
  }

  create(): void {
    const W = this.cameras.main.width
    this.sealSlots = []

    const bar = this.add.graphics().setDepth(0)
    bar.fillStyle(0x06090f, 0.55)
    bar.fillRect(0, 0, W, 22)

    this.stationText = this.add
      .text(6, 5, '', { fontFamily: 'Courier New, monospace', fontSize: '10px', fontStyle: 'bold', color: '#ffffff' })
      .setResolution(3)

    this.add.image(W - 52, 11, 'datenbit')
    this.bitsText = this.add
      .text(W - 44, 5, '0', { fontFamily: 'Courier New, monospace', fontSize: '10px', fontStyle: 'bold', color: '#4de3ff' })
      .setResolution(3)

    // TI-Streckenkarte: ein Slot pro Station der Playlist (rein datengetrieben)
    const levels = configService.levels
    const slotW = 22
    const startX = W / 2 - ((levels.length - 1) * slotW) / 2
    levels.forEach((level, i) => {
      const x = startX + i * slotW
      const frame = this.add.rectangle(x, 11, 18, 18).setStrokeStyle(1, 0x8a93a8, 0.9)
      const icon = this.add.image(x, 11, sealTextureKey(this, level.siegelIcon)).setAlpha(0.25)
      this.sealSlots.push({ frame, icon })
      if (i < levels.length - 1) {
        this.add.rectangle(x + slotW / 2, 11, 6, 2, 0x8a93a8, 0.7)
      }
    })

    this.idleText = this.add
      .text(W / 2, 44, '', {
        fontFamily: 'Courier New, monospace',
        fontSize: '11px',
        fontStyle: 'bold',
        color: '#ffd75e',
        backgroundColor: '#20242e',
        padding: { x: 6, y: 3 },
      })
      .setResolution(3)
      .setOrigin(0.5)
      .setVisible(false)

    // F8 = Kalibrier-Overlay (bewusst nicht Ctrl+Shift+I — das sind die DevTools)
    this.input.keyboard?.on('keydown-F8', () => this.toggleCalibration())

    if (new URLSearchParams(location.search).get('debug') === '1') {
      this.fpsText = this.add
        .text(6, this.cameras.main.height - 14, '', { fontFamily: 'monospace', fontSize: '9px', color: '#7fd07f' })
        .setResolution(3)
    }

    // --- globale Events ---
    const events = this.game.events
    const onHud = () => this.refresh()
    const onLevelStart = (payload: { level: LevelConfig }) => {
      this.refresh()
      this.stationText.setText(t(payload.level.station.name))
      this.showPortalText(payload.level)
    }
    const onIdleWarn = (seconds: number) => {
      this.lastIdleWarnMs = performance.now()
      this.idleText.setText(`Noch da? Neustart in ${seconds} s …`).setVisible(true)
    }
    events.on('hud:update', onHud)
    events.on('level:start', onLevelStart)
    events.on('idle:warn', onIdleWarn)
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      events.off('hud:update', onHud)
      events.off('level:start', onLevelStart)
      events.off('idle:warn', onIdleWarn)
    })

    this.refresh()
  }

  /** Portal-Einblendung: Stationsname groß, 1 Lernsatz, ~2 s. */
  private showPortalText(level: LevelConfig): void {
    this.portalOverlay?.destroy()
    const W = this.cameras.main.width
    const name = this.add
      .text(0, -10, t(level.station.name), {
        fontFamily: 'Courier New, monospace',
        fontSize: '16px',
        fontStyle: 'bold',
        color: '#ffffff',
      })
      .setResolution(3)
      .setOrigin(0.5)
    const line = this.add
      .text(0, 8, t(level.station.portalText), {
        fontFamily: 'Courier New, monospace',
        fontSize: '9px',
        color: '#bfd4ff',
      })
      .setResolution(3)
      .setOrigin(0.5)
    const bg = this.add
      .rectangle(0, 0, Math.max(name.width, line.width) + 30, 44, 0x06090f, 0.75)
      .setStrokeStyle(1, 0x4de3ff, 0.8)
    this.portalOverlay = this.add.container(W / 2, 60, [bg, name, line]).setDepth(50).setAlpha(0)
    this.tweens.add({ targets: this.portalOverlay, alpha: 1, duration: 250 })
    this.time.delayedCall(2100, () => {
      if (!this.portalOverlay) return
      this.tweens.add({
        targets: this.portalOverlay,
        alpha: 0,
        duration: 350,
        onComplete: () => {
          this.portalOverlay?.destroy()
          this.portalOverlay = undefined
        },
      })
    })
  }

  private refresh(): void {
    this.bitsText.setText(String(gameState.bits))
    this.sealSlots.forEach((slot, i) => {
      const earned = i < gameState.seals.length
      slot.icon.setAlpha(earned ? 1 : 0.25)
      slot.frame.setStrokeStyle(1, earned ? 0xffd75e : 0x8a93a8, 0.9)
    })
  }

  update(): void {
    // Idle-Warnung ausblenden, sobald wieder Eingaben kommen
    if (this.idleText.visible && performance.now() - this.lastIdleWarnMs > 300) {
      this.idleText.setVisible(false)
    }
    if (this.fpsText) this.fpsText.setText(`${Math.round(this.game.loop.actualFps)} fps`)
  }

  toggleCalibration(): void {
    if (this.calibText) {
      this.calibText.destroy()
      this.calibText = undefined
      return
    }
    this.calibText = this.add
      .text(6, 30, '', {
        fontFamily: 'monospace',
        fontSize: '8px',
        color: '#7fd07f',
        backgroundColor: '#06090f',
        padding: { x: 4, y: 3 },
      })
      .setResolution(3)
      .setDepth(90)
    this.time.addEvent({
      delay: 100,
      loop: true,
      callback: () => {
        if (!this.calibText) return
        const pads = inputManager.rawGamepads()
        this.calibText.setText(
          pads.length === 0
            ? 'Kalibrierung (F8): kein Gamepad erkannt'
            : pads.map((p) => `${p.id}\n gedrückt: [${p.pressed.join(',')}] achsen: [${p.axes.join(',')}]`).join('\n'),
        )
      },
    })
  }
}
