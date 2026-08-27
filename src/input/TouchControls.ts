import Phaser from 'phaser'
import { GameAction } from './actions'
import { inputManager } from './InputManager'

/**
 * ON-SCREEN-STEUERUNG für Touch-Geräte (Windows-Touchscreens, Tablets, PWA).
 *
 * Bewusst als DOM-Overlay statt Phaser-Objekte: Pointer-Events liefern auf
 * Windows-Touchscreens verlässliches Multi-Touch (laufen + gleichzeitig
 * springen), die Elemente liegen über dem letterboxten Canvas und skalieren
 * per CSS (vmin/clamp) auf jede Bildschirmgröße — unabhängig von Kamera und
 * Design-Raum. Die Spiellogik bleibt unberührt: Alles mündet als dritte
 * Quelle im InputManager (setTouchHeld/pulseTouch → resolve.ts).
 *
 * Layout — spiegelt die Messe-Hardware:
 *   links  Steuerkreuz (8 Richtungen; HOCH schaltet wie am Joystick die Hülle)
 *   rechts ROT = springen, BLAU = TI-Aktion (dieselbe Sprache wie am Stand)
 *   Tipp direkt aufs Spielfeld = Sprung (schnellster Einstieg, startet auch
 *   den Attract-Screen)
 *
 * Sichtbarkeit: erscheint bei der ERSTEN echten Berührung und bleibt dann an
 * (Maus-/Tastatur-Rechner sehen nie Buttons). ?touch=1 erzwingt die Anzeige
 * (Kiosk-Aufstellung), ?touch=0 schaltet sie komplett ab.
 * UIScene lauscht auf 'touchui:aktiv' und räumt ihre unteren HUD-Ecken frei.
 */

let aktiv = false

/** Liegt die On-Screen-Steuerung sichtbar über dem Spiel? (HUD-Layout) */
export function istTouchUiAktiv(): boolean {
  return aktiv
}

const STYLE = `
#touch-ui {
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 10;
  display: none;
  --tc-dpad: clamp(140px, 30vmin, 230px);
  --tc-btn: clamp(76px, 17vmin, 122px);
  --tc-bottom: calc(20px + env(safe-area-inset-bottom, 0px));
  font-family: system-ui, 'Segoe UI', sans-serif;
  -webkit-user-select: none;
  user-select: none;
}
#touch-ui.sichtbar { display: block; }
#touch-ui > div {
  pointer-events: auto;
  touch-action: none;
  position: absolute;
  -webkit-tap-highlight-color: transparent;
}
#touch-dpad {
  left: calc(20px + env(safe-area-inset-left, 0px));
  bottom: var(--tc-bottom);
  width: var(--tc-dpad);
  height: var(--tc-dpad);
  border-radius: 50%;
  background: rgba(10, 20, 34, 0.55);
  border: 1.5px solid rgba(127, 232, 255, 0.35);
  box-shadow: 0 0 24px rgba(77, 227, 255, 0.12) inset;
}
.tc-pfeil {
  position: absolute;
  width: 0; height: 0;
  border: calc(var(--tc-dpad) * 0.085) solid transparent;
  opacity: 0.55;
}
.tc-pfeil.an { opacity: 1; filter: drop-shadow(0 0 6px rgba(127, 232, 255, 0.9)); }
.tc-oben   { top: 7%;   left: 50%; transform: translateX(-50%); border-bottom-color: #7fe8ff; border-top-width: 0; }
.tc-unten  { bottom: 7%; left: 50%; transform: translateX(-50%); border-top-color: #7fe8ff; border-bottom-width: 0; }
.tc-links  { left: 7%;  top: 50%;  transform: translateY(-50%); border-right-color: #7fe8ff; border-left-width: 0; }
.tc-rechts { right: 7%; top: 50%;  transform: translateY(-50%); border-left-color: #7fe8ff; border-right-width: 0; }
.tc-btn {
  width: var(--tc-btn);
  height: var(--tc-btn);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.92);
  font-size: calc(var(--tc-btn) * 0.17);
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.tc-btn.an { transform: scale(0.93); }
#touch-jump {
  right: calc(24px + env(safe-area-inset-right, 0px));
  bottom: var(--tc-bottom);
  background: rgba(201, 59, 59, 0.55);
  border: 1.5px solid rgba(255, 128, 128, 0.75);
  box-shadow: 0 0 22px rgba(255, 80, 80, 0.25);
}
#touch-jump.an { background: rgba(201, 59, 59, 0.85); }
#touch-action {
  right: calc(24px + env(safe-area-inset-right, 0px) + var(--tc-btn) * 1.12);
  bottom: calc(var(--tc-bottom) + var(--tc-btn) * 0.62);
  background: rgba(43, 98, 201, 0.55);
  border: 1.5px solid rgba(127, 178, 255, 0.75);
  box-shadow: 0 0 22px rgba(77, 141, 255, 0.25);
}
#touch-action.an { background: rgba(43, 98, 201, 0.85); }
`

/**
 * setPointerCapture wirft NotFoundError, wenn der Pointer schon beendet ist
 * (Finger blitzschnell weg) — das darf die Steuerung nie aus dem Tritt bringen.
 */
function fange(el: HTMLElement, pointerId: number): void {
  try {
    el.setPointerCapture(pointerId)
  } catch {
    /* ohne Capture funktioniert die Steuerung weiter, nur ohne Nachführen */
  }
}

/** Steuerkreuz: Pointer-Lage → gehaltene Richtungen (8-Wege, tote Mitte). */
function verdrahteSteuerkreuz(dpad: HTMLElement): void {
  const pfeile: Record<string, HTMLElement> = {}
  for (const [cls, richtung] of [
    ['tc-oben', 'oben'], ['tc-unten', 'unten'], ['tc-links', 'links'], ['tc-rechts', 'rechts'],
  ] as const) {
    const el = document.createElement('div')
    el.className = `tc-pfeil ${cls}`
    dpad.appendChild(el)
    pfeile[richtung] = el
  }

  let pointerId: number | null = null

  const setze = (action: GameAction, an: boolean, pfeil: HTMLElement): void => {
    inputManager.setTouchHeld(action, an)
    pfeil.classList.toggle('an', an)
  }

  const neutral = (): void => {
    setze(GameAction.Left, false, pfeile['links'])
    setze(GameAction.Right, false, pfeile['rechts'])
    setze(GameAction.Up, false, pfeile['oben'])
    setze(GameAction.Down, false, pfeile['unten'])
  }

  const aktualisiere = (e: PointerEvent): void => {
    const r = dpad.getBoundingClientRect()
    const dx = e.clientX - (r.left + r.width / 2)
    const dy = e.clientY - (r.top + r.height / 2)
    // Tote Mitte gegen Zittern; 45°-Sektoren erlauben saubere Diagonalen
    const tot = r.width * 0.14
    setze(GameAction.Left, dx < -tot && Math.abs(dx) >= Math.abs(dy) * 0.45, pfeile['links'])
    setze(GameAction.Right, dx > tot && Math.abs(dx) >= Math.abs(dy) * 0.45, pfeile['rechts'])
    setze(GameAction.Up, dy < -tot && Math.abs(dy) >= Math.abs(dx) * 0.45, pfeile['oben'])
    setze(GameAction.Down, dy > tot && Math.abs(dy) >= Math.abs(dx) * 0.45, pfeile['unten'])
  }

  dpad.addEventListener('pointerdown', (e) => {
    if (pointerId !== null) return // ein Finger steuert — der erste gewinnt
    pointerId = e.pointerId
    fange(dpad, e.pointerId)
    e.preventDefault() // keine Maus-Emulation obendrauf
    aktualisiere(e)
  })
  dpad.addEventListener('pointermove', (e) => {
    if (e.pointerId === pointerId) aktualisiere(e)
  })
  const loslassen = (e: PointerEvent): void => {
    if (e.pointerId !== pointerId) return
    pointerId = null
    neutral()
  }
  dpad.addEventListener('pointerup', loslassen)
  dpad.addEventListener('pointercancel', loslassen)
}

/** Runder Halte-Button (mehrere Finger erlaubt — held, solange einer drückt). */
function verdrahteButton(el: HTMLElement, action: GameAction): void {
  const finger = new Set<number>()
  const melde = (): void => {
    inputManager.setTouchHeld(action, finger.size > 0)
    el.classList.toggle('an', finger.size > 0)
  }
  el.addEventListener('pointerdown', (e) => {
    fange(el, e.pointerId)
    e.preventDefault()
    finger.add(e.pointerId)
    melde()
  })
  const runter = (e: PointerEvent): void => {
    finger.delete(e.pointerId)
    melde()
  }
  el.addEventListener('pointerup', runter)
  el.addEventListener('pointercancel', runter)
}

/**
 * Overlay aufbauen und mit dem InputManager verdrahten. Einmal beim Start
 * aufrufen (BootScene) — davor gibt es nichts zu steuern.
 */
export function installTouchControls(game: Phaser.Game): void {
  const param = new URLSearchParams(location.search).get('touch')
  if (param === '0') return

  const style = document.createElement('style')
  style.textContent = STYLE
  document.head.appendChild(style)

  const root = document.createElement('div')
  root.id = 'touch-ui'

  const dpad = document.createElement('div')
  dpad.id = 'touch-dpad'
  verdrahteSteuerkreuz(dpad)

  const jump = document.createElement('div')
  jump.id = 'touch-jump'
  jump.className = 'tc-btn'
  jump.textContent = 'Sprung'
  verdrahteButton(jump, GameAction.Jump)

  const action = document.createElement('div')
  action.id = 'touch-action'
  action.className = 'tc-btn'
  action.textContent = 'Aktion'
  verdrahteButton(action, GameAction.Action)

  root.append(dpad, jump, action)
  document.body.appendChild(root)

  const zeige = (): void => {
    if (aktiv) return
    aktiv = true
    root.classList.add('sichtbar')
    game.events.emit('touchui:aktiv', true)
  }

  // Tipp direkt aufs Spielfeld = Sprung (nur echte Berührung — Mausklicks
  // von Laptop-Spielern dürfen Paul nicht springen lassen)
  game.canvas.addEventListener('pointerdown', (e) => {
    if (e.pointerType !== 'touch') return
    inputManager.pulseTouch(GameAction.Jump)
  })

  // Buttons erscheinen bei der ersten echten Berührung — egal wo
  window.addEventListener(
    'pointerdown',
    (e) => {
      if (e.pointerType === 'touch') zeige()
    },
    { capture: true, passive: true },
  )

  if (param === '1') zeige()
}
