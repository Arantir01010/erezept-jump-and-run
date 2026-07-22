import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import type { LevelConfig } from '../level/schema'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { sealTextureKey } from '../gfx/TextureFactory'
import { addText } from '../gfx/text'
import { t } from '../i18n'

/**
 * Persistentes HUD über City- und Game-Szenen:
 * Stationsname, Datenbits, TI-Streckenkarte (Siegel-Slots = QR-Fragmente),
 * Portal-Einblendung, Idle-Warnung, F8-Kalibrier-Overlay, ?debug=1-FPS.
 */
export class UIScene extends Phaser.Scene {
  private stationText!: Phaser.GameObjects.Text
  bitsText!: Phaser.GameObjects.Text
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
    bar.fillStyle(0x06090f, 0.6)
    bar.fillRect(0, 0, W, 24)

    this.stationText = addText(this, 6, 5, '', 11)

    this.add.image(W - 56, 12, 'datenbit')
    this.bitsText = addText(this, W - 47, 5, '0', 11, { color: '#4de3ff' })

    // TI-Streckenkarte: ein Slot pro Station der Playlist (rein datengetrieben)
    const levels = configService.levels
    const slotW = 22
    const startX = W / 2 - ((levels.length - 1) * slotW) / 2
    levels.forEach((level, i) => {
      const x = startX + i * slotW
      const frame = this.add.rectangle(x, 12, 18, 18).setStrokeStyle(1, 0x8a93a8, 0.9)
      const icon = this.add.image(x, 12, sealTextureKey(this, level.siegelIcon)).setAlpha(0.25)
      this.sealSlots.push({ frame, icon })
      if (i < levels.length - 1) {
        this.add.rectangle(x + slotW / 2, 12, 6, 2, 0x8a93a8, 0.7)
      }
    })

    this.idleText = addText(this, W / 2, 46, '', 12, {
      color: '#ffd75e',
      bg: '#20242e',
      padding: { x: 7, y: 4 },
    })
      .setOrigin(0.5)
      .setVisible(false)

    // F8 = Kalibrier-Overlay (bewusst nicht Ctrl+Shift+I — das sind die DevTools)
    this.input.keyboard?.on('keydown-F8', () => this.toggleCalibration())

    if (new URLSearchParams(location.search).get('debug') === '1') {
      this.fpsText = addText(this, 6, this.cameras.main.height - 16, '', 10, { color: '#7fd07f' })
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
    const name = addText(this, 0, -11, t(level.station.name), 17).setOrigin(0.5)
    const line = addText(this, 0, 9, t(level.station.portalText), 11, { color: '#cfe0ff' }).setOrigin(0.5)
    const bg = this.add
      .rectangle(0, 0, Math.max(name.width, line.width) + 34, 48, 0x06090f, 0.8)
      .setStrokeStyle(1, 0x4de3ff, 0.8)
    this.portalOverlay = this.add.container(W / 2, 62, [bg, name, line]).setDepth(50).setAlpha(0)
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
    this.calibText = addText(this, 6, 32, '', 9, {
      color: '#7fd07f',
      bg: '#06090f',
      padding: { x: 5, y: 4 },
    }).setDepth(90)
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
