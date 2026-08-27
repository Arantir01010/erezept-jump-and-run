import Phaser from 'phaser'
import { GameAction } from './actions'
import { inputManager } from './InputManager'

/**
 * ON-SCREEN-STEUERUNG für Touch-Geräte (Windows-Touchscreens, Tablets, PWA).
 *
 * Bewusst als DOM-Overlay statt Phaser-Objekte: Pointer-Events liefern auf
 * Windows-Touchscreens verlässliches Multi-Touch (laufen + gleichzeitig
 * springen), das Element liegt über dem letterboxten Canvas und skaliert
 * per CSS (vmin/clamp) — unabhängig von Kamera und Design-Raum. Die
 * Spiellogik bleibt unberührt: Alles mündet als dritte Quelle im
 * InputManager (setTouchHeld/pulseTouch → resolve.ts).
 *
 * Bedienkonzept — bewusst EIN einziges sichtbares Element:
 *   links   Steuerkreuz mit Knüppel (8 Richtungen; HOCH schaltet die Hülle
 *           wie am Arcade-Joystick). Gehalten leuchtet es auf, in Ruhe ist
 *           es halb durchsichtig und verdeckt kaum Bild.
 *   überall Tipp aufs Spielfeld = Sprung, DOPPELTIPP = TI-Aktion — keine
 *           eigenen Buttons, die die Kulisse verstellen. (Der erste Tipp
 *           eines Doppeltipps springt mit — ein Sprung auf der Stelle ist
 *           harmlos, Sprung-Latenz dagegen tödlich fürs Spielgefühl.)
 *
 * Optik: die Glas-Sprache des HUD (dunkles Glas, feine weiße Kante,
 * gedämpfte Pfeile) — Akzentfarbe erst bei aktiver Richtung.
 *
 * Sichtbarkeit — zwei Bedingungen müssen zusammenkommen:
 *   1. Touch erkannt (erste echte Berührung; ?touch=1 erzwingt, ?touch=0
 *      schaltet komplett ab) — Maus-/Tastatur-Rechner sehen nie Steuerung.
 *   2. Ein Level läuft (game.events 'level:start' … 'level:ende') — auf
 *      Attract-, Intro-, City- und Reward-Screens bleibt das Bild frei;
 *      Tipp-zum-Starten/Weiterblättern wirkt dort trotzdem.
 * Beim Ausblenden werden gehaltene Aktionen gelöst (kein Geister-Lauf).
 * UIScene lauscht auf 'touchui:aktiv' und räumt die linke untere Ecke frei.
 */

let aktiv = false
let beruehrt = false

/** Liegt die On-Screen-Steuerung sichtbar über dem Spiel? (HUD-Layout) */
export function istTouchUiAktiv(): boolean {
  return aktiv
}

/**
 * Spielt hier jemand per Touch? (Erste echte Berührung erkannt bzw. ?touch=1.)
 * Anders als istTouchUiAktiv auch AUSSERHALB eines Levels wahr — für
 * Hinweistexte auf City-/Info-Screens („Doppeltipp: Abtauchen!").
 */
export function istTouchBedienung(): boolean {
  return beruehrt
}

/** Zwei Tipps innerhalb dieses Fensters = Doppeltipp (TI-Aktion). */
const DOPPELTIPP_MS = 300

const STYLE = `
#touch-ui {
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 10;
  display: none;
  --tc-dpad: clamp(84px, 16vmin, 124px);
  -webkit-user-select: none;
  user-select: none;
}
#touch-ui.sichtbar { display: block; }
#touch-dpad {
  pointer-events: auto;
  touch-action: none;
  position: absolute;
  -webkit-tap-highlight-color: transparent;
  left: calc(16px + env(safe-area-inset-left, 0px));
  bottom: calc(16px + env(safe-area-inset-bottom, 0px));
  width: var(--tc-dpad);
  height: var(--tc-dpad);
  border-radius: 50%;
  background: rgba(4, 9, 15, 0.42);
  border: 1px solid rgba(255, 255, 255, 0.14);
  opacity: 0.55;
  transition: opacity 150ms ease-out;
}
#touch-dpad.griff { opacity: 0.95; }
#touch-knueppel {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 44%;
  height: 44%;
  border-radius: 50%;
  background: rgba(159, 179, 200, 0.14);
  border: 1px solid rgba(159, 179, 200, 0.45);
  transform: translate(-50%, -50%);
  transition: transform 110ms ease-out;
  pointer-events: none;
}
#touch-knueppel.folgt { transition: none; }
#touch-knueppel.an {
  background: rgba(127, 232, 255, 0.22);
  border-color: rgba(127, 232, 255, 0.85);
  box-shadow: 0 0 10px rgba(77, 227, 255, 0.35);
}
.tc-pfeil {
  position: absolute;
  width: 0; height: 0;
  border: calc(var(--tc-dpad) * 0.065) solid transparent;
  opacity: 0.4;
}
.tc-pfeil.an { opacity: 1; filter: drop-shadow(0 0 5px rgba(127, 232, 255, 0.9)); }
.tc-oben   { top: 5%;   left: 50%; transform: translateX(-50%); border-bottom-color: #9fb3c8; border-top-width: 0; }
.tc-unten  { bottom: 5%; left: 50%; transform: translateX(-50%); border-top-color: #9fb3c8; border-bottom-width: 0; }
.tc-links  { left: 5%;  top: 50%;  transform: translateY(-50%); border-right-color: #9fb3c8; border-left-width: 0; }
.tc-rechts { right: 5%; top: 50%;  transform: translateY(-50%); border-left-color: #9fb3c8; border-right-width: 0; }
.tc-pfeil.an.tc-oben { border-bottom-color: #7fe8ff; }
.tc-pfeil.an.tc-unten { border-top-color: #7fe8ff; }
.tc-pfeil.an.tc-links { border-right-color: #7fe8ff; }
.tc-pfeil.an.tc-rechts { border-left-color: #7fe8ff; }
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

/** Kurzer Vibrations-Tick, wo die Hardware es kann (Windows-Monitore: no-op). */
function vibriere(): void {
  if ('vibrate' in navigator) navigator.vibrate(8)
}

/**
 * Steuerkreuz: Pointer-Lage → gehaltene Richtungen (8-Wege, tote Mitte).
 * Der Knüppel folgt dem Finger 1:1 (begrenzt auf den Kreis) und federt beim
 * Loslassen zurück; jede NEU gedrückte Richtungskombination wird sichtbar
 * (Knüppel leuchtet) und per Vibration quittiert.
 * Gibt eine Loslass-Funktion zurück (fürs Ausblenden mitten im Griff).
 */
function verdrahteSteuerkreuz(dpad: HTMLElement): () => void {
  const knueppel = document.createElement('div')
  knueppel.id = 'touch-knueppel'
  dpad.appendChild(knueppel)

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
  let letzteKombi = ''

  const setze = (action: GameAction, an: boolean, pfeil: HTMLElement): void => {
    inputManager.setTouchHeld(action, an)
    pfeil.classList.toggle('an', an)
  }

  const neutral = (): void => {
    setze(GameAction.Left, false, pfeile['links'])
    setze(GameAction.Right, false, pfeile['rechts'])
    setze(GameAction.Up, false, pfeile['oben'])
    setze(GameAction.Down, false, pfeile['unten'])
    letzteKombi = ''
    dpad.classList.remove('griff')
    knueppel.classList.remove('an', 'folgt')
    knueppel.style.transform = 'translate(-50%, -50%)'
  }

  const aktualisiere = (e: PointerEvent): void => {
    const r = dpad.getBoundingClientRect()
    let dx = e.clientX - (r.left + r.width / 2)
    let dy = e.clientY - (r.top + r.height / 2)
    // Tote Mitte gegen Zittern; 45°-Sektoren erlauben saubere Diagonalen
    const tot = r.width * 0.14
    const links = dx < -tot && Math.abs(dx) >= Math.abs(dy) * 0.45
    const rechts = dx > tot && Math.abs(dx) >= Math.abs(dy) * 0.45
    const oben = dy < -tot && Math.abs(dy) >= Math.abs(dx) * 0.45
    const unten = dy > tot && Math.abs(dy) >= Math.abs(dx) * 0.45
    setze(GameAction.Left, links, pfeile['links'])
    setze(GameAction.Right, rechts, pfeile['rechts'])
    setze(GameAction.Up, oben, pfeile['oben'])
    setze(GameAction.Down, unten, pfeile['unten'])

    // Knüppel nachführen (auf den Kreisrand begrenzt)
    const max = r.width * 0.28
    const laenge = Math.hypot(dx, dy)
    if (laenge > max) {
      dx = (dx / laenge) * max
      dy = (dy / laenge) * max
    }
    knueppel.style.transform = `translate(calc(-50% + ${dx.toFixed(1)}px), calc(-50% + ${dy.toFixed(1)}px))`

    // Neue Richtungskombination? Sichtbar quittieren + Vibrations-Tick.
    const kombi = `${links ? 'L' : ''}${rechts ? 'R' : ''}${oben ? 'O' : ''}${unten ? 'U' : ''}`
    knueppel.classList.toggle('an', kombi !== '')
    if (kombi !== '' && kombi !== letzteKombi) vibriere()
    letzteKombi = kombi
  }

  dpad.addEventListener('pointerdown', (e) => {
    if (pointerId !== null) return // ein Finger steuert — der erste gewinnt
    pointerId = e.pointerId
    fange(dpad, e.pointerId)
    e.preventDefault() // keine Maus-Emulation obendrauf
    dpad.classList.add('griff')
    knueppel.classList.add('folgt') // 1:1 folgen, ohne Feder-Animation
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

  return () => {
    pointerId = null
    neutral()
  }
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
  const dpadLoslassen = verdrahteSteuerkreuz(dpad)

  root.append(dpad)
  document.body.appendChild(root)

  // --- Sichtbarkeit: Touch erkannt UND ein Level läuft ---
  beruehrt = param === '1'
  let imLevel = false

  const aktualisiereSichtbarkeit = (): void => {
    const soll = beruehrt && imLevel
    if (soll === aktiv) return
    aktiv = soll
    root.classList.toggle('sichtbar', aktiv)
    // Verschwindet die Steuerung mitten im Griff (Levelende), dürfen keine
    // gehaltenen Aktionen zurückbleiben — sonst läuft Paul im nächsten Level los.
    if (!aktiv) dpadLoslassen()
    game.events.emit('touchui:aktiv', aktiv)
  }

  game.events.on('level:start', () => {
    imLevel = true
    aktualisiereSichtbarkeit()
  })
  game.events.on('level:ende', () => {
    imLevel = false
    aktualisiereSichtbarkeit()
  })

  // Tipp aufs Spielfeld = Sprung, Doppeltipp = TI-Aktion (nur echte Berührung —
  // Mausklicks von Laptop-Spielern dürfen Paul nicht springen lassen).
  // Wirkt auf allen Screens: startet Attract und blättert Info-Screens weiter.
  let letzterTippMs = -Infinity
  game.canvas.addEventListener('pointerdown', (e) => {
    if (e.pointerType !== 'touch') return
    const jetzt = performance.now()
    if (jetzt - letzterTippMs < DOPPELTIPP_MS) {
      inputManager.pulseTouch(GameAction.Action)
      letzterTippMs = -Infinity // Dreifach-Tipp beginnt neu (Sprung)
    } else {
      inputManager.pulseTouch(GameAction.Jump)
      letzterTippMs = jetzt
    }
  })

  // Erste echte Berührung merken — egal wo (macht das Gerät als Touch kenntlich)
  window.addEventListener(
    'pointerdown',
    (e) => {
      if (e.pointerType !== 'touch') return
      beruehrt = true
      aktualisiereSichtbarkeit()
    },
    { capture: true, passive: true },
  )
}
