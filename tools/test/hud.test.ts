/**
 * Tests der Hülle-Anzeige (src/gfx/huelleBadge.ts).
 *
 * Kernfrage: Ist der Zustand auch ohne Farbwahrnehmung erkennbar?
 * Diese Tests halten die Barrierefreiheits-Zusage aus KAPSEL 3.3 fest, damit sie
 * ein späterer Umfärb-Durchgang nicht versehentlich aufhebt.
 */
import { suite, test, assertEqual, assertTrue, assertFalse } from './harness'
import { Huelle, HUELLE_STATES } from '../../src/state/HuelleState'
import {
  BADGE_SPECS,
  badgeSpec,
  badgeColorCss,
  badgePoints,
  toggleHinweis,
  alleBadges,
} from '../../src/gfx/huelleBadge'

export function run(): void {
  suite('HUD — Zustand ist dreifach redundant codiert', () => {
    test('jeder Zustand hat eine Darstellung', () => {
      for (const s of HUELLE_STATES) {
        assertTrue(BADGE_SPECS[s] !== undefined, `${s} fehlt`)
      }
      assertEqual(alleBadges().length, HUELLE_STATES.length)
    })

    test('jede FORM kommt nur einmal vor (Farbfehlsichtigkeit)', () => {
      const formen = HUELLE_STATES.map((s) => BADGE_SPECS[s].form)
      assertEqual(new Set(formen).size, formen.length, `Formen: ${formen.join(', ')}`)
    })

    test('jeder TEXT kommt nur einmal vor', () => {
      const texte = HUELLE_STATES.map((s) => BADGE_SPECS[s].label)
      assertEqual(new Set(texte).size, texte.length, `Texte: ${texte.join(', ')}`)
    })

    test('jede FARBE kommt nur einmal vor', () => {
      const farben = HUELLE_STATES.map((s) => BADGE_SPECS[s].color)
      assertEqual(new Set(farben).size, farben.length)
    })

    test('kein Label ist leer und alle sind großgeschrieben (TV-Lesbarkeit)', () => {
      for (const s of HUELLE_STATES) {
        const l = BADGE_SPECS[s].label
        assertTrue(l.length >= 3, `${s}: Label zu kurz`)
        assertEqual(l, l.toUpperCase(), `${s}: Label soll großgeschrieben sein`)
      }
    })
  })

  suite('HUD — Formen', () => {
    test('Klartext ist der Kreis (offen, rund)', () => {
      assertEqual(badgeSpec(Huelle.Klartext).form, 'kreis')
      assertEqual(badgePoints('kreis').length, 0, 'Kreis zeichnet Phaser direkt')
    })

    test('Verschlüsselt ist die Raute mit 4 Ecken', () => {
      assertEqual(badgeSpec(Huelle.Verschluesselt).form, 'raute')
      assertEqual(badgePoints('raute').length, 4)
    })

    test('VAU ist das Sechseck mit 6 Ecken', () => {
      assertEqual(badgeSpec(Huelle.Vau).form, 'sechseck')
      assertEqual(badgePoints('sechseck').length, 6)
    })

    test('alle Eckpunkte liegen im Zeichenfeld', () => {
      for (const form of ['raute', 'sechseck'] as const) {
        for (const p of badgePoints(form, 12)) {
          assertTrue(p.x >= -0.001 && p.x <= 12.001, `${form}: x=${p.x} außerhalb`)
          assertTrue(p.y >= -0.001 && p.y <= 12.001, `${form}: y=${p.y} außerhalb`)
        }
      }
    })

    test('Formen skalieren mit der Größe', () => {
      const klein = badgePoints('raute', 12)
      const gross = badgePoints('raute', 24)
      assertEqual(gross[1].x, klein[1].x * 2, 'doppelte Größe = doppelte Koordinaten')
    })
  })

  suite('HUD — Farben & Hinweise', () => {
    test('CSS-Farbe hat immer sechs Stellen', () => {
      for (const s of HUELLE_STATES) {
        const css = badgeColorCss(s)
        assertTrue(/^#[0-9a-f]{6}$/.test(css), `${s}: "${css}" ist kein gültiges Hex`)
      }
    })

    test('Klartext ist warm, Verschlüsselt und VAU sind kühl', () => {
      // Farbdramaturgie: warm = offen/sichtbar, kühl = geschützt
      const rot = (c: number): number => (c >> 16) & 0xff
      const blau = (c: number): number => c & 0xff
      const klar = BADGE_SPECS[Huelle.Klartext].color
      assertTrue(rot(klar) > blau(klar), 'Klartext muss warm wirken')
      for (const s of [Huelle.Verschluesselt, Huelle.Vau]) {
        const c = BADGE_SPECS[s].color
        assertTrue(blau(c) >= rot(c), `${s} muss kühl wirken`)
      }
    })

    test('der Umschalt-Hinweis passt zur Hardware', () => {
      assertTrue(toggleHinweis(true).includes('JOYSTICK'), 'am Stand kein dritter Knopf')
      assertTrue(toggleHinweis(false).includes('SHIFT'))
      assertFalse(toggleHinweis(true).includes('SHIFT'), 'keine Tastatur-Hinweise am Automaten')
    })
  })
}
