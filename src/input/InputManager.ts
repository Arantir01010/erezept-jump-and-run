import Phaser from 'phaser'
import { GameAction, ALL_ACTIONS } from './actions'
import { bindingNameToCode } from './keycodes'
import type { Bindings } from '../level/schema'

/**
 * Zentrale Eingabe-Abstraktion: USB-Arcade-Encoder (als Gamepad ODER Tastatur)
 * und Entwickler-Tastatur laufen immer parallel (logisches ODER).
 * Wird einmal pro Frame über Phaser PRE_STEP aktualisiert — Szenen pollen nur.
 */
class InputManagerImpl {
  private bindings!: Bindings
  private keyboardMap: Record<GameAction, string[]> = {} as Record<GameAction, string[]>
  private pressedCodes = new Set<string>()
  private preventCodes = new Set<string>()

  private prev = new Set<GameAction>()
  private curr = new Set<GameAction>()

  /** Zeitstempel der letzten echten Eingabe — Futter für den IdleWatchdog. */
  lastInputMs = performance.now()

  init(game: Phaser.Game, bindings: Bindings): void {
    this.bindings = bindings
    this.keyboardMap = {
      [GameAction.Left]: bindings.keyboard.left.map(bindingNameToCode),
      [GameAction.Right]: bindings.keyboard.right.map(bindingNameToCode),
      [GameAction.Up]: bindings.keyboard.up.map(bindingNameToCode),
      [GameAction.Down]: bindings.keyboard.down.map(bindingNameToCode),
      [GameAction.Jump]: bindings.keyboard.jump.map(bindingNameToCode),
      [GameAction.Action]: bindings.keyboard.action.map(bindingNameToCode),
    }
    for (const codes of Object.values(this.keyboardMap)) codes.forEach((c) => this.preventCodes.add(c))

    window.addEventListener('keydown', (e) => {
      // Browser-Defaults blocken (Space scrollt, Pfeile scrollen) — Kiosk-Anforderung
      if (this.preventCodes.has(e.code)) e.preventDefault()
      if (!e.repeat) {
        this.pressedCodes.add(e.code)
        this.lastInputMs = performance.now()
      }
    })
    window.addEventListener('keyup', (e) => this.pressedCodes.delete(e.code))
    window.addEventListener('blur', () => this.pressedCodes.clear())

    game.events.on(Phaser.Core.Events.PRE_STEP, () => this.update())
  }

  private gamepadActions(): Set<GameAction> {
    const actions = new Set<GameAction>()
    const pads = navigator.getGamepads ? navigator.getGamepads() : []
    const { axisDeadzone, jumpButtons, actionButtons, useDpad } = this.bindings.gamepad
    for (const pad of pads) {
      if (!pad || !pad.connected) continue
      const ax = pad.axes[0] ?? 0
      const ay = pad.axes[1] ?? 0
      if (ax < -axisDeadzone) actions.add(GameAction.Left)
      if (ax > axisDeadzone) actions.add(GameAction.Right)
      if (ay < -axisDeadzone) actions.add(GameAction.Up)
      if (ay > axisDeadzone) actions.add(GameAction.Down)
      if (useDpad) {
        if (pad.buttons[12]?.pressed) actions.add(GameAction.Up)
        if (pad.buttons[13]?.pressed) actions.add(GameAction.Down)
        if (pad.buttons[14]?.pressed) actions.add(GameAction.Left)
        if (pad.buttons[15]?.pressed) actions.add(GameAction.Right)
      }
      if (jumpButtons.some((i) => pad.buttons[i]?.pressed)) actions.add(GameAction.Jump)
      if (actionButtons.some((i) => pad.buttons[i]?.pressed)) actions.add(GameAction.Action)
    }
    return actions
  }

  private update(): void {
    this.prev = this.curr
    const next = this.gamepadActions()
    for (const action of ALL_ACTIONS) {
      if (this.keyboardMap[action]?.some((code) => this.pressedCodes.has(code))) next.add(action)
    }
    this.curr = next
    if (this.curr.size > 0) this.lastInputMs = performance.now()
  }

  isDown(action: GameAction): boolean {
    return this.curr.has(action)
  }

  justPressed(action: GameAction): boolean {
    return this.curr.has(action) && !this.prev.has(action)
  }

  /** -1 | 0 | 1 für horizontale Joystick-Lage. */
  axisX(): number {
    return (this.isDown(GameAction.Right) ? 1 : 0) - (this.isDown(GameAction.Left) ? 1 : 0)
  }

  axisY(): number {
    return (this.isDown(GameAction.Down) ? 1 : 0) - (this.isDown(GameAction.Up) ? 1 : 0)
  }

  /** Roter ODER blauer Button frisch gedrückt (Attract-Start, Overlays). */
  anyButtonJustPressed(): boolean {
    return this.justPressed(GameAction.Jump) || this.justPressed(GameAction.Action)
  }

  /** Steht der Joystick komplett neutral? (Stillstand-Podest) */
  isNeutral(): boolean {
    return this.curr.size === 0
  }

  /** Ist ein Gamepad/Arcade-Encoder angeschlossen? (steuert die Beschriftungen) */
  hasGamepad(): boolean {
    const pads = navigator.getGamepads ? navigator.getGamepads() : []
    for (const pad of pads) if (pad && pad.connected) return true
    return false
  }

  /** Roh-Zustand für das F8-Kalibrier-Overlay beim Standaufbau. */
  rawGamepads(): { id: string; pressed: number[]; axes: number[] }[] {
    const pads = navigator.getGamepads ? navigator.getGamepads() : []
    const result: { id: string; pressed: number[]; axes: number[] }[] = []
    for (const pad of pads) {
      if (!pad || !pad.connected) continue
      result.push({
        id: pad.id,
        pressed: pad.buttons.map((b, i) => (b.pressed ? i : -1)).filter((i) => i >= 0),
        axes: pad.axes.map((a) => Math.round(a * 100) / 100),
      })
    }
    return result
  }
}

export const inputManager = new InputManagerImpl()
