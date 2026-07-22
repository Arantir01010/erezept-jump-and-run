/**
 * Das komplette Eingabe-Vokabular des Spiels.
 * Joystick = Left/Right/Up/Down, roter Button = Jump, blauer Button = Action.
 * Die Spiellogik kennt ausschließlich GameAction — nie Tasten oder Button-Indizes.
 */
export enum GameAction {
  Left = 'left',
  Right = 'right',
  Up = 'up',
  Down = 'down',
  Jump = 'jump',
  Action = 'action',
}

export const ALL_ACTIONS: GameAction[] = [
  GameAction.Left,
  GameAction.Right,
  GameAction.Up,
  GameAction.Down,
  GameAction.Jump,
  GameAction.Action,
]
