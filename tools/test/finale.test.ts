/**
 * DAS FINALE — was die letzte Tür zeigt (finaleLogik.ts).
 *
 * Die Pointe des Spiels hängt an diesen Regeln: Der Spieler steht vor der
 * Akte, kann nichts tun, und sein eigenes Zugriffsprotokoll entscheidet, was
 * er zu sehen bekommt. Diese Tests halten fest, dass die Anzeige kurz bleibt
 * (Messebetrieb), die NEUESTEN Einträge zeigt und den Lückenlos-Fall adelt
 * statt ihn als leere Liste zu verschenken.
 */
import { suite, test, assertEqual, assertTrue, assertFalse } from './harness'
import { baueFinaleAnzeige, MAX_ZEILEN } from '../../src/mechanics/finaleLogik'
import type { ProtokollEintrag } from '../../src/state/Protokoll'

const eintrag = (n: number, levelId = '04-die-huelle'): ProtokollEintrag => ({
  levelId,
  akteur: 'Lauscher',
  aktion: 'hat dich gesehen',
  tMs: n * 1000,
})

const namen = (id: string): string => (id === '04-die-huelle' ? 'Die Hülle' : id)

export function run(): void {
  suite('Finale — lückenloses Protokoll ist der Sonderfall, nicht die leere Liste', () => {
    test('keine Einträge → zwei Zeilen, die es aussprechen', () => {
      const a = baueFinaleAnzeige([], namen)
      assertTrue(a.lueckenlos)
      assertEqual(a.zeilen.length, 2)
      assertTrue(a.zeilen[1].includes('Niemand hat mitgelesen'))
    })

    test('schon EIN Eintrag ist nicht mehr lückenlos', () => {
      const a = baueFinaleAnzeige([eintrag(1)], namen)
      assertFalse(a.lueckenlos)
    })
  })

  suite('Finale — Zeilen nennen Akteur, Tat und Station', () => {
    test('eine Zeile pro Eintrag, mit Stationsname statt Level-ID', () => {
      const a = baueFinaleAnzeige([eintrag(1)], namen)
      assertEqual(a.zeilen.length, 1)
      assertTrue(a.zeilen[0].includes('Lauscher'), a.zeilen[0])
      assertTrue(a.zeilen[0].includes('hat dich gesehen'))
      assertTrue(a.zeilen[0].includes('Die Hülle'), 'Stationsname, nicht 04-die-huelle')
      assertFalse(a.zeilen[0].includes('04-die-huelle'))
    })

    test('unbekannte Level-ID fällt auf die ID zurück statt zu werfen', () => {
      const a = baueFinaleAnzeige([eintrag(1, 'xx-weg')], (id) => id)
      assertTrue(a.zeilen[0].includes('xx-weg'))
    })
  })

  suite('Finale — die Anzeige bleibt kurz (Messebetrieb)', () => {
    test('bis MAX_ZEILEN Einträge werden alle gezeigt', () => {
      const a = baueFinaleAnzeige(Array.from({ length: MAX_ZEILEN }, (_, i) => eintrag(i)), namen)
      assertEqual(a.zeilen.length, MAX_ZEILEN)
    })

    test('darüber: Summenzeile + die NEUESTEN Einträge', () => {
      const viele = Array.from({ length: 12 }, (_, i) => eintrag(i))
      const a = baueFinaleAnzeige(viele, namen)
      assertEqual(a.zeilen.length, MAX_ZEILEN, 'nie mehr Zeilen als das Maximum')
      assertTrue(a.zeilen[0].includes('frühere Einträge'), a.zeilen[0])
      // 12 Einträge, 4 gezeigt → 8 zusammengefasst
      assertTrue(a.zeilen[0].includes('8'), a.zeilen[0])
    })

    test('die neuesten stehen drin, die ältesten nicht', () => {
      const viele = Array.from({ length: 12 }, (_, i) => eintrag(i, `level-${i}`))
      const a = baueFinaleAnzeige(viele, (id) => id)
      const text = a.zeilen.join('\n')
      assertTrue(text.includes('level-11'), 'der letzte Vorfall ist dem Spieler noch präsent')
      assertFalse(text.includes('level-0)'), 'der erste ist längst Summenzeile')
    })
  })
}
