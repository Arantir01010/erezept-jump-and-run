/**
 * STILLSTAND-PODEST — die Fortschrittsregel.
 *
 * Anlass dieser Tests war eine Spielbeobachtung im KOV-Gateway: „Das Scannen
 * mit Stillstehen funktioniert zu schleppend, der Neustart erfolgt zu schnell."
 * Beides steckte in derselben Zeile — der Balken füllte sich mit `delta`, leerte
 * sich aber mit `delta * 2`, und zwar ab dem allerersten Frame mit Eingabe.
 *
 * Damit das nicht bei der nächsten Nachjustierung zurückkehrt, steht die Regel
 * jetzt in src/mechanics/podestLogik.ts und wird hier festgehalten.
 */
import { suite, test, assertEqual, assertTrue, assertFalse } from './harness'
import { podestSchritt, podestAnteil, NACHSICHT_MS, LEER_FAKTOR } from '../../src/mechanics/podestLogik'

const START = { progressMs: 0, stoerungMs: 0 }
const SCAN_MS = 850

/** Mehrere Frames am Stück rechnen — so läuft es im Spiel auch. */
function frames(
  stand: { progressMs: number; stoerungMs: number },
  scanning: boolean,
  delta: number,
  anzahl: number,
) {
  let s = { ...stand, fertig: false, abgebrochen: false }
  for (let i = 0; i < anzahl; i++) s = podestSchritt(s, scanning, delta, SCAN_MS)
  return s
}

export function run(): void {
  suite('Podest — Stillstehen füllt', () => {
    test('ein Frame Stillstand zählt voll', () => {
      const s = podestSchritt(START, true, 16, SCAN_MS)
      assertEqual(s.progressMs, 16)
      assertFalse(s.fertig)
    })

    test('nach scanMs ist der Scan fertig', () => {
      const s = frames(START, true, 17, 50) // 850 ms
      assertTrue(s.fertig, `nach 850 ms muss der Scan durch sein (war ${s.progressMs})`)
    })

    test('vorher ist er NICHT fertig — kein Vorschuss', () => {
      const s = frames(START, true, 17, 49) // 833 ms
      assertFalse(s.fertig)
    })

    test('Stillstand setzt die Störungsuhr zurück', () => {
      const gestoert = podestSchritt({ progressMs: 400, stoerungMs: 150 }, false, 16, SCAN_MS)
      assertTrue(gestoert.stoerungMs > 0)
      const wieder = podestSchritt(gestoert, true, 16, SCAN_MS)
      assertEqual(wieder.stoerungMs, 0, 'wer wieder stillsteht, fängt mit der Nachsicht neu an')
    })
  })

  suite('Podest — kurzes Nachzucken kostet nichts', () => {
    test('eine Störung unter der Nachsicht lässt den Fortschritt unangetastet', () => {
      const s = frames({ progressMs: 500, stoerungMs: 0 }, false, 16, 13) // 208 ms < 220 ms
      assertTrue(s.stoerungMs < NACHSICHT_MS, 'Testaufbau: muss unter der Nachsicht bleiben')
      assertEqual(s.progressMs, 500, 'innerhalb der Nachsicht darf nichts verloren gehen')
    })

    test('genau AN der Nachsichtsgrenze beginnt das Leeren', () => {
      const s = podestSchritt({ progressMs: 500, stoerungMs: NACHSICHT_MS }, false, 16, SCAN_MS)
      assertTrue(s.progressMs < 500, 'ab der Grenze läuft der Balken zurück')
    })

    test('das war der eigentliche Fehler: ein einzelner Frame darf nicht zurücksetzen', () => {
      const s = podestSchritt({ progressMs: 800, stoerungMs: 0 }, false, 16, SCAN_MS)
      assertEqual(s.progressMs, 800, 'ein fast fertiger Scan überlebt einen Wackler')
    })
  })

  suite('Podest — Leeren ist nicht teurer als Füllen', () => {
    test('eine Sekunde Störung kostet höchstens eine Sekunde Fortschritt', () => {
      // Nachsicht abwarten, dann 1000 ms stören
      const nachNachsicht = frames({ progressMs: 800, stoerungMs: NACHSICHT_MS }, false, 20, 50)
      const verloren = 800 - nachNachsicht.progressMs
      assertTrue(
        verloren <= 1000,
        `1000 ms Störung dürfen nicht mehr als 1000 ms kosten (verloren: ${verloren})`,
      )
    })

    test('der Leer-Faktor ist 1 — vorher war er 2 und genau das fühlte sich zäh an', () => {
      assertEqual(LEER_FAKTOR, 1)
    })

    test('Fortschritt wird nie negativ', () => {
      const s = frames({ progressMs: 50, stoerungMs: NACHSICHT_MS }, false, 30, 20)
      assertEqual(s.progressMs, 0)
    })

    test('erreicht der Balken null, wird das genau EINMAL gemeldet', () => {
      const knappUeberNull = podestSchritt({ progressMs: 10, stoerungMs: NACHSICHT_MS }, false, 30, SCAN_MS)
      assertTrue(knappUeberNull.abgebrochen, 'der Sturz auf null ist der Abbruch')
      const weiter = podestSchritt(knappUeberNull, false, 30, SCAN_MS)
      assertFalse(weiter.abgebrochen, 'wer schon bei null ist, bricht nicht noch einmal ab')
    })
  })

  suite('Podest — Balkenanzeige', () => {
    test('leer, halb, voll', () => {
      assertEqual(podestAnteil(0, SCAN_MS), 0)
      assertEqual(podestAnteil(SCAN_MS / 2, SCAN_MS), 0.5)
      assertEqual(podestAnteil(SCAN_MS, SCAN_MS), 1)
    })

    test('über die Grenze hinaus bleibt sie bei 1 (der Assist verkürzt scanMs mitten im Scan)', () => {
      assertEqual(podestAnteil(SCAN_MS * 3, SCAN_MS), 1)
    })

    test('scanMs 0 lässt die Anzeige nicht durch Null teilen', () => {
      assertEqual(podestAnteil(0, 0), 1)
    })
  })
}
