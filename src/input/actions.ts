/**
 * Das komplette Eingabe-Vokabular des Spiels.
 * Joystick = Left/Right/Up/Down, roter Button = Jump, blauer Button = Action,
 * Toggle = Hülle wechseln (Klartext ⇄ Verschlüsselt).
 *
 * Die Messe-Hardware hat nur ZWEI Buttons. Der Toggle liegt deshalb per Default
 * auf JOYSTICK HOCH (public/config/input-bindings.json: gamepad.toggleOnUp) und
 * zusätzlich auf Shift/Q an der Tastatur. Die Spiellogik kennt ausschließlich
 * GameAction — nie Tasten oder Button-Indizes.
 */
export enum GameAction {
  Left = 'left',
  Right = 'right',
  Up = 'up',
  Down = 'down',
  Jump = 'jump',
  Action = 'action',
  Toggle = 'toggle',
}

export const ALL_ACTIONS: GameAction[] = [
  GameAction.Left,
  GameAction.Right,
  GameAction.Up,
  GameAction.Down,
  GameAction.Jump,
  GameAction.Action,
  GameAction.Toggle,
]
