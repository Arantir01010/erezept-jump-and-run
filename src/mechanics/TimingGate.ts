import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { assist } from '../state/Assist'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * Timing-Gate („PIN-Schleuse"): N Lichter pulsieren nacheinander; der blaue
 * Knopf muss im Pulsfenster gedrückt werden. Fachliches Framing kommt aus dem
 * Level-JSON (hier: Dr. Pixel signiert mit eHBA + Arzt-PIN — nie eine echte PIN).
 * Barrierefreiheit: aktives Licht zusätzlich GRÖSSER, nicht nur andersfarbig.
 * Assist: Fehlversuche verlangsamen die Sequenz sichtbar.
 */
export class TimingGate extends Mechanic {
  private zone!: Phaser.Geom.Rectangle
  private lights: Phaser.GameObjects.Arc[] = []
  private steps = 4
  private stepMs = 900
  private windowRatio = 0.45
  private progress = 0
  private running = false
  private done = false
  private stepStartMs = 0
  private activeStep = 0
  private hintShown = false

  spawn(): void {
    const { x, y, w, h } = objCenter(this.obj)
    this.steps = this.param<number>('steps', 4)
    this.stepMs = this.param<number>('stepMs', 900)
    this.zone = new Phaser.Geom.Rectangle((this.obj.x ?? 0), (this.obj.y ?? 0), w || 48, h || 48)

    const spread = 16
    const startX = x - ((this.steps - 1) * spread) / 2
    for (let i = 0; i < this.steps; i++) {
      const light = this.host.scene.add.arc(startX + i * spread, y - (h || 48) / 2 - 12, 4, 0, 360, false, 0x3a4152, 1)
      light.setStrokeStyle(1, 0x8a93a8, 1)
      light.setDepth(6)
      this.lights.push(light)
    }
  }

  private get slowMs(): number {
    return this.stepMs * assist.slowdown(`timing-gate-${this.obj.id}`)
  }

  private get playerInZone(): boolean {
    const p = this.host.player
    return this.zone.contains(p.x, p.y)
  }

  update(time: number): void {
    if (this.done) return

    if (!this.running && this.playerInZone) {
      this.running = true
      this.progress = 0
      this.activeStep = 0
      this.stepStartMs = time
      if (!this.hintShown) {
        this.hintShown = true
        const hint = this.params['hint'] as LText | undefined
        if (hint) this.host.rezi.say(t(hint))
      }
    }
    if (!this.running) return
    if (!this.playerInZone) {
      // Weggelaufen: Sequenz pausiert ohne Strafe
      this.running = false
      this.renderLights(-1)
      return
    }

    const stepElapsed = time - this.stepStartMs
    const inWindow = stepElapsed < this.slowMs * this.windowRatio

    if (stepElapsed >= this.slowMs) {
      // Fenster verpasst → Schritt läuft weiter zum nächsten Licht, kein Reset
      this.activeStep = (this.activeStep + 1) % this.steps
      this.stepStartMs = time
    }

    if (inputManager.justPressed(GameAction.Action)) {
      if (inWindow && this.activeStep === this.progress) {
        this.progress += 1
        this.flashLight(this.progress - 1, 0x7fd07f)
        if (this.progress >= this.steps) return this.succeed()
        this.activeStep = (this.activeStep + 1) % this.steps
        this.stepStartMs = time
      } else {
        // Falscher Moment: rotes Blinken, Fortschritt zurück, Assist merkt sich das
        assist.fail(`timing-gate-${this.obj.id}`)
        this.progress = 0
        this.activeStep = 0
        this.stepStartMs = time
        this.lights.forEach((l) => this.flashLight(this.lights.indexOf(l), 0xff4040))
      }
    }

    this.renderLights(inWindow ? this.activeStep : -1)
  }

  private renderLights(active: number): void {
    this.lights.forEach((light, i) => {
      if (i < this.progress) {
        light.setFillStyle(0x7fd07f, 1)
        light.setRadius(4)
      } else if (i === active) {
        light.setFillStyle(0xffd75e, 1)
        light.setRadius(6) // größer, nicht nur andersfarbig (Farbfehlsichtigkeit)
      } else {
        light.setFillStyle(0x3a4152, 1)
        light.setRadius(4)
      }
    })
  }

  private flashLight(index: number, color: number): void {
    const light = this.lights[index]
    if (!light) return
    light.setFillStyle(color, 1)
    this.host.scene.tweens.add({ targets: light, scale: { from: 1.6, to: 1 }, duration: 200 })
  }

  private succeed(): void {
    this.done = true
    this.running = false
    this.lights.forEach((l) => l.setFillStyle(0x7fd07f, 1))
    if (assist.wasClean(`timing-gate-${this.obj.id}`)) gameState.addSecurityBonus()
    this.linkedGate()?.open()
    this.host.scene.game.events.emit('hud:update')
  }
}
registerMechanic('timing-gate', TimingGate)
