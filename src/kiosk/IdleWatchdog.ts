import Phaser from 'phaser'
import { inputManager } from '../input/InputManager'
import { telemetry } from '../telemetry/Telemetry'
import { speichereSitzung } from '../telemetry/speicher'

/** Szenen, in denen Inaktivität zum Reset in den Attract-Mode führt. */
const GAMEPLAY_SCENES = ['City', 'Game', 'Reward', 'UI']
const WARN_WINDOW_MS = 8000

/**
 * Messebetrieb: Läuft ein Durchlauf und niemand fasst die Controls an,
 * warnt das HUD 8 s lang und setzt dann in den Attract-Mode zurück.
 */
class IdleWatchdog {
  private game!: Phaser.Game
  private resetMs = 60_000

  init(game: Phaser.Game, resetSeconds: number): void {
    this.game = game
    this.resetMs = resetSeconds * 1000
    game.events.on(Phaser.Core.Events.PRE_STEP, () => this.check())
  }

  private inGameplay(): boolean {
    return GAMEPLAY_SCENES.some((key) => this.game.scene.isActive(key))
  }

  private check(): void {
    if (!this.inGameplay()) return
    const idle = performance.now() - inputManager.lastInputMs
    if (idle >= this.resetMs) {
      this.reset()
    } else if (idle >= this.resetMs - WARN_WINDOW_MS) {
      this.game.events.emit('idle:warn', Math.ceil((this.resetMs - idle) / 1000))
    }
  }

  reset(): void {
    // Abbruchpunkt festhalten UND den Durchlauf sichern, BEVOR die Szenen
    // gestoppt werden — sonst ist die Beobachtung verloren (KAPSEL 4.4).
    telemetry.note('level-abbruch', performance.now(), 'idle')
    speichereSitzung(telemetry.toJSON())

    const sm = this.game.scene
    for (const key of GAMEPLAY_SCENES) {
      if (sm.isActive(key) || sm.isSleeping(key)) sm.stop(key)
    }
    if (!sm.isActive('Attract')) sm.start('Attract')
  }
}

export const idleWatchdog = new IdleWatchdog()
