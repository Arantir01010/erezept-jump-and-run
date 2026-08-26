/**
 * PRE-/POST-TEST (KAPSEL 4.4) — Fragebogen und Auswertung.
 *
 * Der wichtigste Test dieser Suite ist der erste: Er erzwingt, dass JEDER der
 * fünf Vereinfachungsfehler aus KAPSEL 1.4 abgefragt wird. Streicht jemand
 * später eine Frage „weil der Bogen zu lang ist", schlägt er an — und genau an
 * diesen Stellen kann ein Lernspiel fachlich Schaden anrichten.
 */
import { suite, test, assertEqual, assertTrue, assertFalse, assertDeepEqual, assertClose } from './harness'
import {
  FRAGEN,
  LERNZIELE,
  bewerte,
  werteAus,
  gruppenBilanz,
  type Antwortbogen,
} from '../../src/playtest/fragebogen'
import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const lies = (rel: string): string => readFileSync(join(ROOT, rel), 'utf-8')

/** Ein Bogen mit ausschließlich richtigen Antworten. */
const alleRichtig = (): Antwortbogen => FRAGEN.map((f) => f.richtig)
/** Ein Bogen mit ausschließlich falschen Antworten. */
const alleFalsch = (): Antwortbogen => FRAGEN.map((f) => (f.richtig === 0 ? 1 : 0))

export function run(): void {
  suite('Fragebogen — deckt die Vereinfachungsfehler ab (KAPSEL 1.4)', () => {
    test('jedes Lernziel wird von genau einer Frage abgedeckt', () => {
      for (const ziel of LERNZIELE) {
        const treffer = FRAGEN.filter((f) => f.lernziel === ziel)
        assertEqual(treffer.length, 1, `Lernziel "${ziel}" ist ${treffer.length}x abgefragt`)
      }
    })

    test('die vier großen Irrtümer sind dabei', () => {
      const ziele = FRAGEN.map((f) => f.lernziel)
      // Genau die Punkte, die KAPSEL 1.4 als Reputationsrisiko nennt
      for (const pflicht of ['vau-kein-tunnel', 'signatur-vs-krypto', 'egk-schluessel', 'zero-trust'] as const) {
        assertTrue(ziele.includes(pflicht), `${pflicht} wird nicht abgefragt`)
      }
    })

    test('keine Frage ohne Lernziel (sonst ist eine falsche Antwort nicht deutbar)', () => {
      for (const f of FRAGEN) {
        assertTrue((LERNZIELE as readonly string[]).includes(f.lernziel), `Frage ${f.id}: unbekanntes Lernziel`)
      }
    })

    test('jede Frage sagt, was bei Misserfolg zu tun ist', () => {
      for (const f of FRAGEN) {
        assertTrue(f.konsequenz.length > 20, `Frage ${f.id}: Konsequenz zu vage`)
      }
    })
  })

  suite('Fragebogen — Aufbau', () => {
    test('jede Frage hat mindestens drei Antworten', () => {
      for (const f of FRAGEN) assertTrue(f.antworten.length >= 3, `Frage ${f.id}`)
    })

    test('der richtige Index liegt im gültigen Bereich', () => {
      for (const f of FRAGEN) {
        assertTrue(f.richtig >= 0 && f.richtig < f.antworten.length, `Frage ${f.id}: Index ${f.richtig}`)
      }
    })

    test('keine doppelten Antworttexte innerhalb einer Frage', () => {
      for (const f of FRAGEN) {
        assertEqual(new Set(f.antworten).size, f.antworten.length, `Frage ${f.id} hat Dubletten`)
      }
    })

    test('die IDs sind eindeutig und lückenlos', () => {
      assertDeepEqual(FRAGEN.map((f) => f.id), FRAGEN.map((_, i) => i + 1))
    })

    test('die richtige Antwort steht nicht immer an derselben Stelle', () => {
      // Sonst könnte man den Bogen ohne Wissen ausfüllen
      assertTrue(new Set(FRAGEN.map((f) => f.richtig)).size > 1, 'Antwortmuster zu vorhersehbar')
    })
  })

  suite('Fragebogen — Bewertung', () => {
    test('alles richtig gibt die volle Punktzahl', () => {
      assertEqual(bewerte(alleRichtig()), FRAGEN.length)
    })

    test('alles falsch gibt null', () => {
      assertEqual(bewerte(alleFalsch()), 0)
    })

    test('fehlende Angaben (-1) zählen als falsch', () => {
      assertEqual(bewerte(FRAGEN.map(() => -1)), 0)
    })

    test('ein leerer Bogen stürzt nicht ab', () => {
      assertEqual(bewerte([]), 0)
    })

    test('der Lernzuwachs ist die Differenz', () => {
      const a = werteAus(alleFalsch(), alleRichtig())
      assertEqual(a.vorher, 0)
      assertEqual(a.nachher, FRAGEN.length)
      assertEqual(a.zuwachs, FRAGEN.length)
      assertEqual(a.gesamt, FRAGEN.length)
    })

    test('ein negativer Zuwachs ist darstellbar (Warnsignal, kein Absturz)', () => {
      const a = werteAus(alleRichtig(), alleFalsch())
      assertEqual(a.zuwachs, -FRAGEN.length)
    })

    test('offene Lernziele benennen genau die falschen Fragen', () => {
      const bogen = alleRichtig()
      const vauIndex = FRAGEN.findIndex((f) => f.lernziel === 'vau-kein-tunnel')
      bogen[vauIndex] = FRAGEN[vauIndex].richtig === 0 ? 1 : 0
      const a = werteAus(alleFalsch(), bogen)
      assertDeepEqual(a.offeneLernziele, ['vau-kein-tunnel'])
    })

    test('wer schon vorher alles weiß, zeigt Zuwachs 0 (kein Fehler)', () => {
      const a = werteAus(alleRichtig(), alleRichtig())
      assertEqual(a.zuwachs, 0)
      assertEqual(a.offeneLernziele.length, 0)
    })
  })

  suite('Fragebogen — Gruppenbilanz', () => {
    test('Mittelwerte über mehrere Bögen', () => {
      const b = gruppenBilanz([
        { vorher: alleFalsch(), nachher: alleRichtig() },
        { vorher: alleRichtig(), nachher: alleRichtig() },
      ])
      assertEqual(b.n, 2)
      assertClose(b.mittlerNachher, FRAGEN.length, 0.05)
      assertClose(b.mittlererZuwachs, FRAGEN.length / 2, 0.05)
    })

    test('ein Problem-Lernziel wird erkannt, wenn die Mehrheit es nicht versteht', () => {
      const vauIndex = FRAGEN.findIndex((f) => f.lernziel === 'vau-kein-tunnel')
      const mitVauFehler = (): Antwortbogen => {
        const b = alleRichtig()
        b[vauIndex] = FRAGEN[vauIndex].richtig === 0 ? 1 : 0
        return b
      }
      const b = gruppenBilanz([
        { vorher: alleFalsch(), nachher: mitVauFehler() },
        { vorher: alleFalsch(), nachher: mitVauFehler() },
        { vorher: alleFalsch(), nachher: alleRichtig() },
      ])
      assertDeepEqual(b.problemLernziele, ['vau-kein-tunnel'])
    })

    test('versteht die Mehrheit alles, gibt es keine Problem-Lernziele', () => {
      const b = gruppenBilanz([
        { vorher: alleFalsch(), nachher: alleRichtig() },
        { vorher: alleFalsch(), nachher: alleRichtig() },
      ])
      assertEqual(b.problemLernziele.length, 0)
    })

    test('leere Gruppe liefert Nullen statt NaN', () => {
      const b = gruppenBilanz([])
      assertEqual(b.n, 0)
      assertEqual(b.mittlererZuwachs, 0)
      assertFalse(Number.isNaN(b.mittlerVorher))
    })
  })

  suite('Playtest-Anleitung ist vollständig', () => {
    const doku = lies('docs/PLAYTEST.md')

    test('nennt das 80-%-Abbruchkriterium', () => {
      assertTrue(doku.includes('80'), 'Schwelle fehlt')
      assertTrue(doku.includes('Mechanik überarbeiten'), 'Konsequenz fehlt')
    })

    test('schärft ein, dass nicht geholfen werden darf', () => {
      assertTrue(
        doku.includes('erkläre absichtlich nichts') || doku.includes('nicht helfen'),
        'ohne diese Regel ist die Messung unbrauchbar',
      )
    })

    test('erklärt proaktiv / reaktiv / passiv', () => {
      for (const wort of ['proaktiv', 'reaktiv', 'passiv']) {
        assertTrue(doku.includes(wort), `${wort} nicht erklärt`)
      }
    })

    test('nennt F9 als Auswertung', () => {
      assertTrue(doku.includes('F9'), 'das Standpersonal findet die Auswertung nicht')
    })

    test('enthält jede Frage des Bogens', () => {
      // Vergleich ohne Anführungszeichen und Auslassungspunkte: Die Doku nutzt
      // typografische Zeichen („ "), der Code teils gerade — inhaltlich identisch.
      const normal = (s: string): string => s.replace(/[\u201a\u201e\u2018\u2019\u201c\u201d"'\u2026]/g, '')
      const dokuNormal = normal(doku)
      for (const f of FRAGEN) {
        const kern = normal(f.text).slice(0, 25).trim()
        assertTrue(dokuNormal.includes(kern), `Frage ${f.id} fehlt in der Anleitung: "${kern}"`)
      }
    })

    test('nennt zu jeder Frage die richtige Antwort (fett)', () => {
      for (const f of FRAGEN) {
        const richtig = f.antworten[f.richtig].replace(/^…\s*/, '').slice(0, 20)
        assertTrue(doku.includes(richtig), `Lösung zu Frage ${f.id} fehlt: "${richtig}"`)
      }
    })

    test('weist auf den Datenschutz hin', () => {
      assertTrue(doku.includes('Datenschutz'), 'Abschnitt fehlt')
      assertTrue(doku.includes('keine') && doku.includes('Personendaten'), 'Zusage fehlt')
    })

    test('sagt, wie alte Daten vor dem Test gelöscht werden', () => {
      assertTrue(doku.includes('localStorage.removeItem'), 'sonst mischen sich Entwicklungsläufe ein')
    })
  })
}
