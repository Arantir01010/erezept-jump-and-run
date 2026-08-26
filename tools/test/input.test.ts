/**
 * Tests der Eingabe-Auflösung (src/input/resolve.ts) und der Bindings-Defaults.
 * Kernfrage: Funktioniert der Hülle-Toggle auf Hardware mit nur ZWEI Buttons?
 */
import { suite, test, assertTrue, assertFalse, assertEqual, assertDeepEqual } from './harness'
import { GameAction, ALL_ACTIONS } from '../../src/input/actions'
import {
  resolveGamepad,
  resolveKeyboard,
  resolveAll,
  axisXOf,
  axisYOf,
  justPressedOf,
  type PadSnapshot,
} from '../../src/input/resolve'
import { BindingsSchema } from '../../src/level/schema'
import { bindingNameToCode } from '../../src/input/keycodes'

const RAW_BINDINGS = {
  gamepad: {
    axisDeadzone: 0.4,
    jumpButtons: [0, 2],
    actionButtons: [1, 3],
    toggleButtons: [4, 5],
    toggleOnUp: true,
    useDpad: true,
  },
  keyboard: {
    left: ['LEFT', 'A'],
    right: ['RIGHT', 'D'],
    up: ['UP', 'W'],
    down: ['DOWN', 'S'],
    jump: ['SPACE'],
    action: ['E', 'ENTER'],
    toggle: ['SHIFT', 'Q'],
  },
}

const parsed = BindingsSchema.safeParse(RAW_BINDINGS)
if (!parsed.success) throw new Error('Test-Bindings ungültig: ' + JSON.stringify(parsed.error.issues))
const B = parsed.data

const pad = (over: Partial<PadSnapshot> = {}): PadSnapshot => ({
  connected: true,
  buttons: Array<boolean>(16).fill(false),
  axes: [0, 0],
  ...over,
})

const keymap = (): Record<GameAction, string[]> => ({
  [GameAction.Left]: B.keyboard.left.map(bindingNameToCode),
  [GameAction.Right]: B.keyboard.right.map(bindingNameToCode),
  [GameAction.Up]: B.keyboard.up.map(bindingNameToCode),
  [GameAction.Down]: B.keyboard.down.map(bindingNameToCode),
  [GameAction.Jump]: B.keyboard.jump.map(bindingNameToCode),
  [GameAction.Action]: B.keyboard.action.map(bindingNameToCode),
  [GameAction.Toggle]: B.keyboard.toggle.map(bindingNameToCode),
})

export function run(): void {
  suite('Bindings-Schema', () => {
    test('toggle-Tasten und toggleOnUp haben Defaults', () => {
      const minimal = BindingsSchema.safeParse({
        gamepad: { jumpButtons: [0], actionButtons: [1] },
        keyboard: {
          left: ['LEFT'], right: ['RIGHT'], up: ['UP'], down: ['DOWN'],
          jump: ['SPACE'], action: ['E'],
        },
      })
      assertTrue(minimal.success, 'alte Bindings-Datei muss weiter gültig sein')
      if (!minimal.success) return
      assertDeepEqual(minimal.data.keyboard.toggle, ['SHIFT', 'Q'], 'Default-Toggle-Tasten')
      assertEqual(minimal.data.gamepad.toggleOnUp, true, 'Joystick hoch schaltet per Default')
      assertDeepEqual(minimal.data.gamepad.toggleButtons, [], 'ohne dritten Button')
    })

    test('Toggle ist Teil des Vokabulars', () => {
      assertTrue(ALL_ACTIONS.includes(GameAction.Toggle))
      assertEqual(new Set(ALL_ACTIONS).size, ALL_ACTIONS.length, 'keine Duplikate')
    })

    test('Tastennamen werden korrekt in Codes übersetzt', () => {
      assertEqual(bindingNameToCode('SHIFT'), 'ShiftLeft')
      assertEqual(bindingNameToCode('Q'), 'KeyQ')
      assertEqual(bindingNameToCode('SPACE'), 'Space')
    })
  })

  suite('Gamepad-Auflösung', () => {
    test('Achse links/rechts jenseits der Deadzone', () => {
      assertTrue(resolveGamepad([pad({ axes: [-0.9, 0] })], B).has(GameAction.Left))
      assertTrue(resolveGamepad([pad({ axes: [0.9, 0] })], B).has(GameAction.Right))
    })

    test('innerhalb der Deadzone passiert nichts (Arcade-Drift)', () => {
      const a = resolveGamepad([pad({ axes: [0.3, 0.3] })], B)
      assertEqual(a.size, 0, 'leichtes Zittern darf nichts auslösen')
    })

    test('nicht verbundene Pads werden ignoriert', () => {
      assertEqual(resolveGamepad([pad({ connected: false, axes: [-1, 0] }), null], B).size, 0)
    })

    test('roter Button = Jump, blauer Button = Action', () => {
      const b = Array<boolean>(16).fill(false)
      b[0] = true
      b[1] = true
      const a = resolveGamepad([pad({ buttons: b })], B)
      assertTrue(a.has(GameAction.Jump))
      assertTrue(a.has(GameAction.Action))
    })

    test('D-Pad wirkt wie die Achse', () => {
      const b = Array<boolean>(16).fill(false)
      b[14] = true
      assertTrue(resolveGamepad([pad({ buttons: b })], B).has(GameAction.Left))
    })

    test('dritter Button schaltet die Hülle, wenn vorhanden', () => {
      const b = Array<boolean>(16).fill(false)
      b[4] = true
      assertTrue(resolveGamepad([pad({ buttons: b })], B).has(GameAction.Toggle))
    })

    test('mehrere Pads werden zusammengeführt', () => {
      const b = Array<boolean>(16).fill(false)
      b[0] = true
      const a = resolveGamepad([pad({ axes: [0.9, 0] }), pad({ buttons: b })], B)
      assertTrue(a.has(GameAction.Right) && a.has(GameAction.Jump))
    })
  })

  suite('Toggle auf 2-Button-Hardware (die entscheidende Regel)', () => {
    test('Joystick HOCH löst zusätzlich den Toggle aus', () => {
      const a = resolveAll([pad({ axes: [0, -0.9] })], new Set(), keymap(), B)
      assertTrue(a.has(GameAction.Toggle), 'ohne dritten Button muss Hoch schalten')
      assertTrue(a.has(GameAction.Up), 'Up bleibt erhalten (Menüs/Avatarwahl)')
    })

    test('abschaltbar über toggleOnUp=false', () => {
      const off = { ...B, gamepad: { ...B.gamepad, toggleOnUp: false } }
      const a = resolveAll([pad({ axes: [0, -0.9] })], new Set(), keymap(), off)
      assertFalse(a.has(GameAction.Toggle))
      assertTrue(a.has(GameAction.Up))
    })

    test('Tastatur: Shift und Q schalten die Hülle', () => {
      assertTrue(resolveAll([], new Set(['ShiftLeft']), keymap(), B).has(GameAction.Toggle))
      assertTrue(resolveAll([], new Set(['KeyQ']), keymap(), B).has(GameAction.Toggle))
    })

    test('Pfeil hoch an der Tastatur schaltet ebenfalls (gleiche Regel)', () => {
      const a = resolveAll([], new Set(['ArrowUp']), keymap(), B)
      assertTrue(a.has(GameAction.Toggle), 'Laptop-Spieler bekommen dieselbe Mechanik')
    })

    test('Springen löst KEINEN Toggle aus (kein Konflikt mit ROT)', () => {
      const a = resolveAll([], new Set(['Space']), keymap(), B)
      assertTrue(a.has(GameAction.Jump))
      assertFalse(a.has(GameAction.Toggle))
    })

    test('TI-Aktion löst KEINEN Toggle aus (kein Konflikt mit BLAU)', () => {
      const a = resolveAll([], new Set(['KeyE']), keymap(), B)
      assertTrue(a.has(GameAction.Action))
      assertFalse(a.has(GameAction.Toggle))
    })
  })

  suite('Tastatur + Zusammenführung', () => {
    test('WASD und Pfeile laufen parallel', () => {
      assertTrue(resolveKeyboard(new Set(['KeyA']), keymap()).has(GameAction.Left))
      assertTrue(resolveKeyboard(new Set(['ArrowLeft']), keymap()).has(GameAction.Left))
    })

    test('Gamepad und Tastatur sind ein logisches ODER', () => {
      const a = resolveAll([pad({ axes: [0.9, 0] })], new Set(['Space']), keymap(), B)
      assertTrue(a.has(GameAction.Right) && a.has(GameAction.Jump))
    })

    test('unbekannte Codes lösen nichts aus', () => {
      assertEqual(resolveKeyboard(new Set(['KeyZ', 'F13']), keymap()).size, 0)
    })
  })

  suite('Achsen & Flanken', () => {
    test('axisX/axisY liefern -1|0|1', () => {
      assertEqual(axisXOf(new Set([GameAction.Right])), 1)
      assertEqual(axisXOf(new Set([GameAction.Left])), -1)
      assertEqual(axisXOf(new Set()), 0)
      assertEqual(axisYOf(new Set([GameAction.Down])), 1)
      assertEqual(axisYOf(new Set([GameAction.Up])), -1)
    })

    test('beide Richtungen gleichzeitig neutralisieren sich', () => {
      assertEqual(axisXOf(new Set([GameAction.Left, GameAction.Right])), 0)
    })

    test('justPressed erkennt nur die Flanke (kein Dauerfeuer)', () => {
      const prev = new Set<GameAction>()
      const curr = new Set([GameAction.Toggle])
      assertTrue(justPressedOf(curr, prev).has(GameAction.Toggle))
      assertFalse(justPressedOf(curr, curr).has(GameAction.Toggle), 'gehalten ≠ frisch gedrückt')
    })

    test('Loslassen und erneutes Drücken feuert wieder', () => {
      const held = new Set([GameAction.Toggle])
      const released = new Set<GameAction>()
      assertFalse(justPressedOf(held, held).has(GameAction.Toggle))
      assertTrue(justPressedOf(held, released).has(GameAction.Toggle))
    })
  })
}
