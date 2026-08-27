import Phaser from 'phaser'
import { GameAction } from './actions'
import { bindingNameToCode } from './keycodes'
import { resolveAll, axisXOf, axisYOf, type PadSnapshot } from './resolve'
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

  /** Von der On-Screen-Steuerung GEHALTENE Aktionen (Steuerkreuz, Buttons). */
  private touchHeld = new Set<GameAction>()
  /** Ein-Frame-Impulse (Tipp aufs Spielfeld = Sprung) — nach einem Update verbraucht. */
  private touchPulse = new Set<GameAction>()

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
      [GameAction.Toggle]: bindings.keyboard.toggle.map(bindingNameToCode),
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
    window.addEventListener('blur', () => {
      this.pressedCodes.clear()
      // Touch-Zustände mit verwerfen: Ein pointerup, das im Hintergrund verloren
      // ging, darf keinen Dauerlauf hinterlassen (Kiosk-Anforderung).
      this.touchHeld.clear()
      this.touchPulse.clear()
    })

    game.events.on(Phaser.Core.Events.PRE_STEP, () => this.update())
  }

  /** Browser-Gamepads in prüfbare Momentaufnahmen übersetzen. */
  private padSnapshots(): (PadSnapshot | null)[] {
    const pads = navigator.getGamepads ? navigator.getGamepads() : []
    const out: (PadSnapshot | null)[] = []
    for (const pad of pads) {
      if (!pad) {
        out.push(null)
        continue
      }
      out.push({
        connected: pad.connected,
        buttons: pad.buttons.map((b) => b.pressed),
        axes: [...pad.axes],
      })
    }
    return out
  }

  // ------------------------------------------------- Touch (TouchControls)

  /**
   * On-Screen-Steuerung meldet Halten/Loslassen einer Aktion
   * (src/input/TouchControls.ts — Steuerkreuz und die zwei Buttons).
   */
  setTouchHeld(action: GameAction, down: boolean): void {
    if (down) this.touchHeld.add(action)
    else this.touchHeld.delete(action)
    this.lastInputMs = performance.now()
  }

  /**
   * Ein-Frame-Impuls: Ein Tipp direkt aufs Spielfeld lässt Paul springen —
   * wirkt beim nächsten Update genau einmal als „frisch gedrückt".
   */
  pulseTouch(action: GameAction): void {
    this.touchPulse.add(action)
    this.lastInputMs = performance.now()
  }

  /**
   * Einmal pro Frame: Rohzustände einsammeln und von src/input/resolve.ts in
   * Aktionen übersetzen (dort liegt die getestete Logik inkl. Toggle-auf-Hoch).
   */
  private update(): void {
    this.prev = this.curr
    const touch = this.touchPulse.size > 0 ? new Set([...this.touchHeld, ...this.touchPulse]) : this.touchHeld
    this.touchPulse = new Set() // Impulse sind jetzt verbraucht
    this.curr = resolveAll(this.padSnapshots(), this.pressedCodes, this.keyboardMap, this.bindings, touch)
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
    return axisXOf(this.curr)
  }

  axisY(): number {
    return axisYOf(this.curr)
  }

  /** Roter ODER blauer Button frisch gedrückt (Attract-Start, Overlays). */
  anyButtonJustPressed(): boolean {
    return this.justPressed(GameAction.Jump) || this.justPressed(GameAction.Action)
  }

  /**
   * Steht der Joystick komplett neutral? (Stillstand-Podest)
   * Hinweis: Toggle-aus-Hoch zählt mit — „hoch" ist eine echte Eingabe und
   * darf den Scan zu Recht unterbrechen.
   */
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
