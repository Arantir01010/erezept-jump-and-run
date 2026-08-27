/**
 * DARSTELLUNG des Hülle-Zustands — die Zuordnung Zustand → Farbe/Form/Text.
 *
 * Bewusst Phaser-frei: So ist testbar, dass jeder Zustand eine EIGENE Form und
 * einen EIGENEN Text hat und nicht allein an der Farbe hängt. Genau das fordert
 * KAPSEL 3.3 (Barrierefreiheit bei Farbfehlsichtigkeit) — und genau so ein
 * Detail rutscht sonst beim Umfärben durch.
 */
import { Huelle, HUELLE_STATES } from '../state/HuelleState'

/** Form des Abzeichens — zusätzlich zur Farbe, nie nur Farbe. */
export type BadgeForm = 'kreis' | 'raute' | 'sechseck'

export interface BadgeSpec {
  color: number
  form: BadgeForm
  /** Kurztext im HUD (in Großbuchstaben, damit er auf dem TV lesbar bleibt). */
  label: string
}

/**
 * Klartext = warm/gelb + Kreis (offen, rund, „nichts verborgen")
 * Verschlüsselt = kühl/cyan + Raute (verschlossen, kantig)
 * VAU = violett + Sechseck (der geschützte Raum, eigene Klasse)
 */
export const BADGE_SPECS: Record<Huelle, BadgeSpec> = {
  [Huelle.Klartext]: { color: 0xffd75e, form: 'kreis', label: 'KLARTEXT' },
  [Huelle.Verschluesselt]: { color: 0x4de3ff, form: 'raute', label: 'VERSCHLÜSSELT' },
  [Huelle.Vau]: { color: 0xb9a6ff, form: 'sechseck', label: 'VAU' },
}

export function badgeSpec(state: Huelle): BadgeSpec {
  return BADGE_SPECS[state]
}

/** Farbe als CSS-Hex (für Phaser-Textfarben). */
export function badgeColorCss(state: Huelle): string {
  return `#${BADGE_SPECS[state].color.toString(16).padStart(6, '0')}`
}

/**
 * Eckpunkte der Form in einem `size`×`size`-Feld (lokale Koordinaten).
 * Der Kreis liefert bewusst keine Punkte — ihn zeichnet Phaser direkt.
 */
export function badgePoints(form: BadgeForm, size = 12): { x: number; y: number }[] {
  const r = size / 2
  if (form === 'raute') {
    return [
      { x: r, y: 0 },
      { x: size, y: r },
      { x: r, y: size },
      { x: 0, y: r },
    ]
  }
  if (form === 'sechseck') {
    const pts: { x: number; y: number }[] = []
    for (let i = 0; i < 6; i++) {
      const a = (Math.PI / 3) * i - Math.PI / 6
      pts.push({ x: r + Math.cos(a) * r, y: r + Math.sin(a) * r })
    }
    return pts
  }
  return []
}

/**
 * Zusatzhinweis fürs HUD: Wie schaltet man um? Hängt an der Hardware, damit
 * niemand nach einem dritten Knopf sucht, den es am Stand nicht gibt.
 * Touch gewinnt vor Gamepad: Wer die On-Screen-Steuerung nutzt, soll nicht
 * nach Shift-Tasten suchen.
 */
export function toggleHinweis(hasGamepad: boolean, touchUi = false): string {
  if (touchUi) return 'STEUERKREUZ HOCH: Hülle wechseln'
  return hasGamepad ? 'JOYSTICK HOCH: Hülle wechseln' : 'SHIFT / Pfeil hoch: Hülle wechseln'
}

/** Alle Zustände mit ihrer Darstellung (Legende, Attract-Bildschirm, Tests). */
export function alleBadges(): { state: Huelle; spec: BadgeSpec }[] {
  return HUELLE_STATES.map((state) => ({ state, spec: BADGE_SPECS[state] }))
}
