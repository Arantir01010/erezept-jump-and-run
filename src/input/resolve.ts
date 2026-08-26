/**
 * REINE EINGABE-AUFLÖSUNG — Phaser- und browserfrei, damit sie unter Node
 * vollständig testbar ist (tools/test/input.test.ts).
 *
 * Der InputManager sammelt nur Rohdaten (gedrückte Key-Codes, Gamepad-Zustände)
 * und lässt hier daraus die Menge der logischen Aktionen berechnen. So ist die
 * knifflige Logik (Deadzone, D-Pad, Toggle-auf-Joystick-hoch) prüfbar, ohne
 * je einen Browser zu starten.
 */
import { GameAction, ALL_ACTIONS } from './actions'
import type { Bindings } from '../level/schema'

/** Das, was wir von einem Gamepad brauchen (Teilmenge der Browser-API). */
export interface PadSnapshot {
  connected: boolean
  /** Index → gedrückt. */
  buttons: boolean[]
  axes: number[]
}

/** Gamepad-Zustände in Aktionen übersetzen. */
export function resolveGamepad(pads: (PadSnapshot | null)[], bindings: Bindings): Set<GameAction> {
  const actions = new Set<GameAction>()
  const { axisDeadzone, jumpButtons, actionButtons, toggleButtons, useDpad } = bindings.gamepad
  for (const pad of pads) {
    if (!pad || !pad.connected) continue
    const ax = pad.axes[0] ?? 0
    const ay = pad.axes[1] ?? 0
    if (ax < -axisDeadzone) actions.add(GameAction.Left)
    if (ax > axisDeadzone) actions.add(GameAction.Right)
    if (ay < -axisDeadzone) actions.add(GameAction.Up)
    if (ay > axisDeadzone) actions.add(GameAction.Down)
    if (useDpad) {
      if (pad.buttons[12]) actions.add(GameAction.Up)
      if (pad.buttons[13]) actions.add(GameAction.Down)
      if (pad.buttons[14]) actions.add(GameAction.Left)
      if (pad.buttons[15]) actions.add(GameAction.Right)
    }
    if (jumpButtons.some((i) => pad.buttons[i])) actions.add(GameAction.Jump)
    if (actionButtons.some((i) => pad.buttons[i])) actions.add(GameAction.Action)
    if (toggleButtons.some((i) => pad.buttons[i])) actions.add(GameAction.Toggle)
  }
  return actions
}

/** Tastatur: KeyboardEvent.code-Menge → Aktionen. */
export function resolveKeyboard(
  pressedCodes: ReadonlySet<string>,
  keyboardMap: Record<GameAction, string[]>,
): Set<GameAction> {
  const actions = new Set<GameAction>()
  for (const action of ALL_ACTIONS) {
    if (keyboardMap[action]?.some((code) => pressedCodes.has(code))) actions.add(action)
  }
  return actions
}

/**
 * Gamepad und Tastatur zusammenführen (logisches ODER) und die
 * 2-Button-Sonderregel anwenden: Joystick HOCH schaltet zusätzlich die Hülle.
 *
 * `Up` bleibt dabei absichtlich erhalten — Menüs und die Avatarwahl brauchen es
 * weiterhin als eigene Richtung.
 */
export function resolveAll(
  pads: (PadSnapshot | null)[],
  pressedCodes: ReadonlySet<string>,
  keyboardMap: Record<GameAction, string[]>,
  bindings: Bindings,
): Set<GameAction> {
  const actions = resolveGamepad(pads, bindings)
  for (const a of resolveKeyboard(pressedCodes, keyboardMap)) actions.add(a)
  if (bindings.gamepad.toggleOnUp && actions.has(GameAction.Up)) actions.add(GameAction.Toggle)
  return actions
}

/** -1 | 0 | 1 aus einer Aktionsmenge (beide Richtungen gleichzeitig = 0). */
export function axisXOf(actions: ReadonlySet<GameAction>): number {
  return (actions.has(GameAction.Right) ? 1 : 0) - (actions.has(GameAction.Left) ? 1 : 0)
}

export function axisYOf(actions: ReadonlySet<GameAction>): number {
  return (actions.has(GameAction.Down) ? 1 : 0) - (actions.has(GameAction.Up) ? 1 : 0)
}

/**
 * Frisch gedrückte Aktionen (Flankenerkennung): in `curr`, aber nicht in `prev`.
 */
export function justPressedOf(
  curr: ReadonlySet<GameAction>,
  prev: ReadonlySet<GameAction>,
): Set<GameAction> {
  const out = new Set<GameAction>()
  for (const a of curr) if (!prev.has(a)) out.add(a)
  return out
}
