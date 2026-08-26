/**
 * SICHTLOGIK der Lauscher — bewusst Phaser-frei und ohne Zufall,
 * damit sie vollständig unter Node testbar ist (tools/test/lauscher.test.ts).
 *
 * Fachliches Motiv (KAPSEL 1.2/2.3): Unverschlüsselte Daten sind auf dem
 * Transportweg mitlesbar. Ein Lauscher „sieht" deshalb ausschließlich
 * Klartext — verschlüsselte Daten und alles innerhalb der VAU bleiben ihm
 * verborgen (auch dem Betreiber: KAPSEL 1.4).
 */

export interface Rect {
  x: number
  y: number
  w: number
  h: number
}

export interface Blick {
  /** Augenposition (Weltkoordinaten, Design-Raum). */
  x: number
  y: number
  /** Blickrichtung: -1 = links, +1 = rechts. */
  dir: -1 | 1
  /** Reichweite in Pixeln. */
  reach: number
  /** Halbe Öffnung des Kegels in Pixeln (vertikal, am Kegelende). */
  spread: number
}

/**
 * Liegt der Punkt im Sichtkegel? Der Kegel öffnet sich linear mit der
 * Entfernung — nah am Auge schmal, am Ende `spread` hoch. Das macht Ducken
 * und Abstand halten zu echten Optionen.
 */
export function imSichtkegel(blick: Blick, px: number, py: number): boolean {
  const dx = (px - blick.x) * blick.dir
  if (dx < 0 || dx > blick.reach) return false
  const ratio = blick.reach > 0 ? dx / blick.reach : 0
  const halfHeight = Math.max(2, blick.spread * ratio)
  return Math.abs(py - blick.y) <= halfHeight
}

/** Achsenparallele Überdeckung zweier Rechtecke. */
export function rectsOverlap(a: Rect, b: Rect): boolean {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

/**
 * Blockiert eines der Rechtecke die Sichtlinie Auge → Ziel?
 * Bewusst einfache Abtastung (feste Schrittweite) statt exakter Geometrie:
 * deterministisch, schnell und für Kachelwelten völlig ausreichend.
 */
export function sichtlinieFrei(
  blick: Blick,
  px: number,
  py: number,
  blocker: Rect[],
  step = 4,
): boolean {
  if (blocker.length === 0) return true
  const dx = px - blick.x
  const dy = py - blick.y
  const dist = Math.hypot(dx, dy)
  if (dist <= 0) return true
  const steps = Math.max(1, Math.ceil(dist / step))
  for (let i = 1; i < steps; i++) {
    const t = i / steps
    const sx = blick.x + dx * t
    const sy = blick.y + dy * t
    for (const b of blocker) {
      if (sx >= b.x && sx <= b.x + b.w && sy >= b.y && sy <= b.y + b.h) return false
    }
  }
  return true
}

export interface SichtZiel {
  x: number
  y: number
  /** Trägt das Ziel gerade eine sichtbare (= Klartext-)Hülle? */
  sichtbar: boolean
}

/**
 * Die eine Frage, die ein Lauscher stellt: „Sehe ich dich?"
 * Reihenfolge der Prüfungen ist Absicht — die Hülle entscheidet ZUERST,
 * damit die Lehre eindeutig bleibt: verschlüsselt = unsichtbar, Punkt.
 */
export function wirdGesehen(blick: Blick, ziel: SichtZiel, blocker: Rect[] = []): boolean {
  if (!ziel.sichtbar) return false
  if (!imSichtkegel(blick, ziel.x, ziel.y)) return false
  return sichtlinieFrei(blick, ziel.x, ziel.y, blocker)
}

/**
 * Patrouille zwischen zwei Punkten mit Wartezeit an den Enden — als reine
 * Funktion der Zeit (kein Zustand, kein Zufall): identisch reproduzierbar
 * und damit testbar. Liefert Position und Blickrichtung.
 */
export function patrouille(
  tMs: number,
  fromX: number,
  toX: number,
  speed: number,
  pauseMs = 600,
): { x: number; dir: -1 | 1 } {
  const span = Math.abs(toX - fromX)
  if (span < 1 || speed <= 0) return { x: fromX, dir: 1 }
  const travelMs = (span / speed) * 1000
  const legMs = travelMs + pauseMs
  const cycleMs = legMs * 2
  const t = ((tMs % cycleMs) + cycleMs) % cycleMs
  const forward = t < legMs
  const local = forward ? t : t - legMs
  const progress = Math.min(1, local / travelMs)
  const a = forward ? fromX : toX
  const b = forward ? toX : fromX
  const x = a + (b - a) * progress
  const dir: -1 | 1 = b >= a ? 1 : -1
  return { x, dir }
}
