/**
 * PLAYTEST-BERICHT (KAPSEL 4.4) — Zusammenführung, Auswertung und ABLEITUNG.
 *
 * Der Schwerpunkt liegt auf der Ableitung: „< 80 %" allein sagt nicht, was zu
 * tun ist. Ob die Tester REAKTIV (Regel verstanden, aber zu spät) oder PASSIV
 * (Zusammenhang nicht erkannt) waren, führt zu völlig verschiedenen Maßnahmen.
 * Diese Unterscheidung soll nicht von der Tagesform der auswertenden Person
 * abhängen — deshalb ist sie Code und hier festgenagelt.
 */
import { suite, test, assertEqual, assertTrue, assertFalse, assertClose } from './harness'
import {
  sammleSitzungen,
  erstelleBericht,
  formatBericht,
  bestimmeAbleitung,
  MINDEST_DURCHLAEUFE,
  type RohSitzung,
} from '../../src/playtest/bericht'
import { benchmark, sitzungKennzahlen } from '../../src/telemetry/kennzahlen'
import type { TelemetrieEvent } from '../../src/telemetry/events'

const ev = (typ: string, tMs: number, wert?: string, levelId = '04-die-huelle'): TelemetrieEvent =>
  ({ typ, levelId, tMs, wert } as TelemetrieEvent)

/** Durchlauf, der proaktiv verschlüsselt (verstanden). */
const proaktiv = (id: string): RohSitzung => ({
  sitzung: id,
  events: [ev('level-start', 0), ev('huelle-wechsel', 3_000, 'verschluesselt'), ev('level-ende', 60_000)],
})
/** Durchlauf, der erst nach dem Treffer reagiert. */
const reaktiv = (id: string): RohSitzung => ({
  sitzung: id,
  events: [
    ev('level-start', 0),
    ev('gesehen', 4_000),
    ev('huelle-wechsel', 9_000, 'verschluesselt'),
    ev('tipp', 10_000, 'huelleHint'),
    ev('level-ende', 60_000),
  ],
})
/** Durchlauf, der nie verschlüsselt. */
const passiv = (id: string): RohSitzung => ({
  sitzung: id,
  events: [ev('level-start', 0), ev('gesehen', 4_000), ev('tipp', 8_000), ev('level-abbruch', 40_000, 'idle')],
})

const bericht = (rohe: RohSitzung[]) => erstelleBericht(rohe, ['04-die-huelle'])

export function run(): void {
  suite('Bericht — Dateien zusammenführen', () => {
    test('liest das Exportformat { sitzungen: [...] }', () => {
      assertEqual(sammleSitzungen([{ exportiert: 'egal', sitzungen: [proaktiv('a')] }]).length, 1)
    })

    test('liest auch ein bloßes Array', () => {
      assertEqual(sammleSitzungen([[proaktiv('a'), proaktiv('b')]]).length, 2)
    })

    test('liest auch einen einzelnen Durchlauf', () => {
      assertEqual(sammleSitzungen([proaktiv('a')]).length, 1)
    })

    test('mehrere Dateien werden zusammengeführt', () => {
      const s = sammleSitzungen([{ sitzungen: [proaktiv('a')] }, { sitzungen: [proaktiv('b')] }])
      assertEqual(s.length, 2)
    })

    test('doppelte Durchläufe zählen nur EINMAL (doppelter Export verfälscht sonst die Quote)', () => {
      const s = sammleSitzungen([{ sitzungen: [proaktiv('a')] }, { sitzungen: [proaktiv('a'), proaktiv('b')] }])
      assertEqual(s.length, 2)
    })

    test('leere Durchläufe werden verworfen (sagen nichts aus)', () => {
      assertEqual(sammleSitzungen([{ sitzungen: [{ sitzung: 'leer', events: [] }] }]).length, 0)
    })

    test('kaputte Einträge blockieren die anderen nicht', () => {
      const s = sammleSitzungen([
        { sitzungen: [null, 'quatsch', 42, { ohneEvents: true }, proaktiv('gut')] },
      ])
      assertEqual(s.length, 1)
      assertEqual(s[0].sitzung, 'gut')
    })

    test('unbekannte Strukturen ergeben eine leere Liste statt eines Absturzes', () => {
      assertEqual(sammleSitzungen([null, 7, 'text', {}]).length, 0)
    })
  })

  suite('Bericht — Ableitung nach KAPSEL 4.1', () => {
    test('ohne Daten: klarer Hinweis, kein Ergebnis', () => {
      const b = bericht([])
      assertEqual(b.ableitung, 'keine-daten')
      assertTrue(b.empfehlung.includes('localStorage'), 'sagt, woran es liegen kann')
    })

    test('unter drei Durchläufen ist die Quote keine Aussage', () => {
      const b = bericht([proaktiv('a'), proaktiv('b')])
      assertEqual(b.ableitung, 'zu-wenige')
      assertTrue(b.benchmark.quote === 100, 'die Quote wird berechnet …')
      assertTrue(b.empfehlung.includes('Weiter testen'), '… aber ausdrücklich nicht gedeutet')
      assertEqual(MINDEST_DURCHLAEUFE, 3)
    })

    test('erfüllt: weiterbauen', () => {
      const b = bericht([proaktiv('a'), proaktiv('b'), proaktiv('c'), proaktiv('d'), reaktiv('e')])
      assertClose(b.benchmark.quote, 80, 0.01)
      assertEqual(b.ableitung, 'erfuellt')
      assertTrue(b.empfehlung.includes('Welt 2'), 'nennt den nächsten Schritt')
    })

    test('verfehlt mit Mehrheit REAKTIV: Einführung nachbessern, NICHT die Mechanik', () => {
      const b = bericht([proaktiv('a'), reaktiv('b'), reaktiv('c'), reaktiv('d')])
      assertFalse(b.benchmark.erfuellt)
      assertEqual(b.ableitung, 'zu-spaet')
      assertTrue(b.empfehlung.includes('EINFÜHRUNG'), 'nennt die richtige Baustelle')
      assertTrue(b.empfehlung.includes('HUELLE_TUNING nicht anfassen'), 'warnt vor der falschen Baustelle')
    })

    test('verfehlt mit Mehrheit PASSIV: Pivot — Mechanik überarbeiten', () => {
      const b = bericht([proaktiv('a'), passiv('b'), passiv('c'), passiv('d')])
      assertEqual(b.ableitung, 'nicht-erkannt')
      assertTrue(b.empfehlung.includes('HUELLE_TUNING überarbeiten'))
      assertTrue(b.empfehlung.includes('KEINEN weiteren Content'), 'nennt die Konsequenz aus KAPSEL 4.1')
    })

    test('bei Gleichstand gilt die mildere Deutung (zu spät)', () => {
      // 1 reaktiv, 1 passiv: die Regel wurde immerhin von einem verstanden
      const b = bericht([passiv('a'), reaktiv('b'), passiv('c'), reaktiv('d')])
      assertEqual(b.ableitung, 'zu-spaet')
    })

    test('die Ableitung hängt nur am Benchmark (direkt prüfbar)', () => {
      assertEqual(bestimmeAbleitung(benchmark([])), 'keine-daten')
      const drei = [proaktiv('a'), proaktiv('b'), proaktiv('c')].map((s) =>
        sitzungKennzahlen(s.sitzung, s.events, ['04-die-huelle']),
      )
      assertEqual(bestimmeAbleitung(benchmark(drei)), 'erfuellt')
    })
  })

  suite('Bericht — Auffälligkeiten je Station', () => {
    test('Abbrüche, Tipps und Treffer werden aufsummiert', () => {
      const a = bericht([passiv('a'), passiv('b'), proaktiv('c')]).auffaellig
      assertEqual(a.length, 1)
      assertEqual(a[0].levelId, '04-die-huelle')
      assertEqual(a[0].abbrueche, 2)
      assertEqual(a[0].tipps, 2)
      assertEqual(a[0].gesehen, 2)
    })

    test('die problematischste Station steht oben', () => {
      const heikel: RohSitzung = {
        sitzung: 'x',
        events: [
          ev('level-start', 0, undefined, 'A'),
          ev('level-ende', 10_000, undefined, 'A'),
          ev('level-start', 11_000, undefined, 'B'),
          ev('level-abbruch', 30_000, 'idle', 'B'),
        ],
      }
      const a = erstelleBericht([heikel], []).auffaellig
      assertEqual(a[0].levelId, 'B', 'wo abgebrochen wurde, ist die Baustelle')
    })

    test('die Durchschnittszeit zählt nur beendete Läufe', () => {
      const a = bericht([proaktiv('a'), passiv('b')]).auffaellig
      assertClose(a[0].dauerSchnitt, 60, 0.05, 'der abgebrochene Lauf darf den Schnitt nicht senken')
    })

    test('ohne beendete Läufe gibt es keine erfundene Zeit', () => {
      assertEqual(bericht([passiv('a')]).auffaellig[0].dauerSchnitt, 0)
    })
  })

  suite('Bericht — Textausgabe', () => {
    const text = formatBericht(bericht([proaktiv('a'), proaktiv('b'), proaktiv('c'), reaktiv('d')]))

    test('nennt Quote, Ziel und Ergebnis in einer Zeile', () => {
      assertTrue(text.includes('Quote:'), 'Quote fehlt')
      assertTrue(text.includes('Ziel: 80 %'), 'Ziel fehlt')
      assertTrue(text.includes('ERREICHT'), 'Ergebnis fehlt')
    })

    test('zeigt die drei Klassen mit Klartext-Bezeichnung', () => {
      for (const wort of ['proaktiv', 'erst nach Treffer', 'nie verschlüsselt']) {
        assertTrue(text.includes(wort), `"${wort}" fehlt`)
      }
    })

    test('enthält die Stationstabelle und die Ableitung', () => {
      assertTrue(text.includes('Auffälligkeiten je Station'))
      assertTrue(text.includes('Ableitung'))
    })

    test('bricht lange Empfehlungen um (Konsolenbreite)', () => {
      const lang = formatBericht(bericht([proaktiv('a'), passiv('b'), passiv('c'), passiv('d')]))
      for (const zeile of lang.split('\n')) {
        assertTrue(zeile.length <= 80, `Zeile zu lang (${zeile.length}): ${zeile.slice(0, 40)}…`)
      }
    })

    test('funktioniert auch ohne Daten', () => {
      const leer = formatBericht(bericht([]))
      assertTrue(leer.includes('Auswertbare Durchläufe: 0'))
      assertFalse(leer.includes('Auffälligkeiten'), 'keine leere Tabelle')
    })
  })
}
