/**
 * TELEMETRIE (KAPSEL 4.4) — Erfassung, Kennzahlen und das 80-%-Kriterium.
 *
 * Zwei Dinge prüft diese Suite besonders streng:
 *
 * 1. DATENSCHUTZ. Das Spiel erklärt Vertraulichkeit — es darf nicht selbst
 *    Personendaten sammeln. Kein Ereignis darf ein Feld bekommen, das über
 *    typ/levelId/tMs/wert hinausgeht, und `tMs` muss eine Laufzeit sein,
 *    kein Datum.
 *
 * 2. DIE KERNFRAGE aus KAPSEL 4.1: „Wechseln ≥ 80 % den Zustand freiwillig
 *    sinnvoll?" Gemessen über die Reihenfolge — verschlüsselt der Spieler,
 *    BEVOR ein Lauscher ihn erwischt (proaktiv = verstanden) oder erst danach
 *    (reaktiv = Strafe gebraucht)?
 */
import { suite, test, assertEqual, assertTrue, assertFalse, assertDeepEqual, assertClose } from './harness'
import { Telemetry, MAX_EVENTS } from '../../src/telemetry/Telemetry'
import { TELEMETRIE_TYPEN, ERLAUBTE_FELDER, istTelemetrieTyp } from '../../src/telemetry/events'
import type { TelemetrieEvent } from '../../src/telemetry/events'
import {
  levelKennzahlen,
  sitzungKennzahlen,
  beteiligteLevel,
  benchmark,
  BENCHMARK_PROZENT,
  type SitzungKennzahlen,
} from '../../src/telemetry/kennzahlen'

/** Kurzform zum Bauen von Ereignisfolgen. */
const ev = (typ: string, tMs: number, wert?: string, levelId = '04-die-huelle'): TelemetrieEvent =>
  ({ typ, levelId, tMs, wert } as TelemetrieEvent)

/** Ein Durchlauf, der proaktiv verschlüsselt (verstanden). */
const proaktiverLauf = (id = 's1'): SitzungKennzahlen =>
  sitzungKennzahlen(id, [
    ev('level-start', 0),
    ev('huelle-wechsel', 3_000, 'verschluesselt'),
    ev('gesehen', 9_000),
    ev('level-ende', 60_000),
  ])

/** Ein Durchlauf, der erst nach der Strafe reagiert. */
const reaktiverLauf = (id = 's2'): SitzungKennzahlen =>
  sitzungKennzahlen(id, [
    ev('level-start', 0),
    ev('gesehen', 5_000),
    ev('huelle-wechsel', 8_000, 'verschluesselt'),
    ev('level-ende', 60_000),
  ])

/** Ein Durchlauf, der nie verschlüsselt. */
const passiverLauf = (id = 's3'): SitzungKennzahlen =>
  sitzungKennzahlen(id, [ev('level-start', 0), ev('gesehen', 5_000), ev('level-ende', 60_000)])

export function run(): void {
  suite('Telemetrie — Datenschutz (das Spiel muss sich selbst treu bleiben)', () => {
    test('ein Ereignis hat NUR die erlaubten Felder', () => {
      const t = new Telemetry()
      t.setLevel('04-die-huelle')
      t.note('huelle-wechsel', 1234, 'verschluesselt')
      const felder = Object.keys(t.alle()[0])
      for (const f of felder) {
        assertTrue(
          (ERLAUBTE_FELDER as readonly string[]).includes(f),
          `unerwartetes Feld "${f}" — Personenbezug-Risiko`,
        )
      }
    })

    test('kein Feld heißt wie ein Personendatum', () => {
      const verboten = ['name', 'user', 'id', 'ip', 'email', 'datum', 'date', 'timestamp']
      for (const f of ERLAUBTE_FELDER) {
        assertFalse(verboten.includes(f.toLowerCase()), `Feld "${f}" klingt nach Personendatum`)
      }
    })

    test('tMs ist eine Laufzeit, kein Datum', () => {
      const t = new Telemetry()
      t.note('level-start', 500)
      const wert = t.alle()[0].tMs
      assertTrue(wert < 1e11, 'ein Unix-Zeitstempel wäre viel größer — hier wäre ein Datum drin')
    })

    test('die Sitzungskennung identifiziert niemanden und wechselt', () => {
      const t = new Telemetry()
      const erste = t.sitzung
      assertTrue(erste.length >= 4 && erste.length <= 12, 'kurze Zufallskennung erwartet')
      t.neueSitzung()
      assertFalse(t.sitzung === erste, 'jeder Durchlauf bekommt eine neue Kennung')
    })

    test('das Exportformat enthält nichts außer Kennung, Version und Ereignissen', () => {
      const t = new Telemetry()
      t.note('level-start', 0)
      assertDeepEqual(Object.keys(t.toJSON()).sort(), ['events', 'sitzung', 'version'])
    })
  })

  suite('Telemetrie — Erfassung', () => {
    test('setLevel füllt die levelId automatisch', () => {
      const t = new Telemetry()
      t.setLevel('01-stammdaten')
      t.note('gesammelt', 100)
      assertEqual(t.alle()[0].levelId, '01-stammdaten')
    })

    test('abschaltbar (Messebetrieb ohne Auswertung)', () => {
      const t = new Telemetry(false)
      t.note('level-start', 0)
      assertEqual(t.anzahl, 0)
    })

    test('unbekannte Typen werden verworfen, nicht geworfen', () => {
      const t = new Telemetry()
      t.note('gibtsnicht' as never, 0)
      assertEqual(t.anzahl, 0, 'Telemetrie darf im Kiosk NIE ein Spiel abbrechen')
    })

    test('Kiosk-Schutz: die Liste ist gedeckelt', () => {
      const t = new Telemetry()
      for (let i = 0; i < MAX_EVENTS + 50; i++) t.note('gesammelt', i)
      assertEqual(t.anzahl, MAX_EVENTS)
      assertEqual(t.alle()[t.anzahl - 1].tMs, MAX_EVENTS + 49, 'die neuesten bleiben')
    })

    test('neueSitzung leert die Liste', () => {
      const t = new Telemetry()
      t.note('level-start', 0)
      t.neueSitzung()
      assertEqual(t.anzahl, 0)
    })

    test('zaehle filtert nach Typ und Level', () => {
      const t = new Telemetry()
      t.setLevel('a')
      t.note('gesehen', 1)
      t.note('gesehen', 2)
      t.setLevel('b')
      t.note('gesehen', 3)
      assertEqual(t.zaehle('gesehen'), 3)
      assertEqual(t.zaehle('gesehen', 'a'), 2)
    })

    test('alle erfassten Typen sind gültig und eindeutig', () => {
      assertEqual(new Set(TELEMETRIE_TYPEN).size, TELEMETRIE_TYPEN.length)
      for (const typ of TELEMETRIE_TYPEN) assertTrue(istTelemetrieTyp(typ))
      assertFalse(istTelemetrieTyp('quatsch'))
    })
  })

  suite('Telemetrie — die Kernfrage: freiwillig und sinnvoll gewechselt?', () => {
    test('verschlüsselt VOR dem ersten Treffer = proaktiv (verstanden)', () => {
      assertEqual(proaktiverLauf().verstehen, 'proaktiv')
    })

    test('verschlüsselt erst NACH dem Treffer = reaktiv (Strafe gebraucht)', () => {
      assertEqual(reaktiverLauf().verstehen, 'reaktiv')
    })

    test('nie verschlüsselt = passiv', () => {
      assertEqual(passiverLauf().verstehen, 'passiv')
    })

    test('nie erwischt UND verschlüsselt = proaktiv (der Idealfall)', () => {
      const k = levelKennzahlen('L', [
        ev('level-start', 0, undefined, 'L'),
        ev('huelle-wechsel', 2_000, 'verschluesselt', 'L'),
        ev('level-ende', 40_000, undefined, 'L'),
      ])
      assertEqual(k.verstehen, 'proaktiv')
      assertEqual(k.gesehen, 0)
    })

    test('ein Wechsel ZURÜCK auf Klartext gilt nicht als Schutz', () => {
      const k = levelKennzahlen('L', [
        ev('level-start', 0, undefined, 'L'),
        ev('huelle-wechsel', 1_000, 'klartext', 'L'),
        ev('gesehen', 2_000, undefined, 'L'),
      ])
      assertEqual(k.verstehen, 'passiv', 'nur „verschluesselt" ist ein Schutzwechsel')
    })

    test('die Bewertung nimmt das ERSTE Hülle-Level (dort wird gelernt)', () => {
      const s = sitzungKennzahlen(
        'x',
        [
          ev('level-start', 0, undefined, '01-stammdaten'),
          ev('level-ende', 20_000, undefined, '01-stammdaten'),
          ev('level-start', 21_000, undefined, '04-die-huelle'),
          ev('huelle-wechsel', 23_000, 'verschluesselt', '04-die-huelle'),
          ev('level-ende', 80_000, undefined, '04-die-huelle'),
        ],
        ['04-die-huelle'],
      )
      assertEqual(s.verstehen, 'proaktiv', 'Level 1 hat keine Hülle und darf nicht zählen')
    })
  })

  suite('Telemetrie — Kennzahlen pro Level', () => {
    const k = levelKennzahlen('L', [
      ev('level-start', 0, undefined, 'L'),
      ev('huelle-wechsel', 2_000, 'verschluesselt', 'L'),
      ev('huelle-wechsel', 8_000, 'klartext', 'L'),
      ev('gesammelt', 9_000, undefined, 'L'),
      ev('gesammelt', 10_000, undefined, 'L'),
      ev('checkpoint', 12_000, undefined, 'L'),
      ev('tipp', 15_000, 'huelleHint', 'L'),
      ev('vau-betreten', 20_000, undefined, 'L'),
      ev('vau-abgelaufen', 25_000, undefined, 'L'),
      ev('level-ende', 60_000, undefined, 'L'),
    ])

    test('Dauer wird aus Start und Ende gerechnet', () => {
      assertClose(k.dauerSek, 60, 0.05)
      assertTrue(k.beendet)
      assertFalse(k.abgebrochen)
    })

    test('Toggle-Häufigkeit inklusive Rate pro Minute', () => {
      assertEqual(k.wechsel, 2)
      assertClose(k.wechselProMinute, 2, 0.05)
    })

    test('Tipps zählen als Verständnisproblem', () => {
      assertEqual(k.tipps, 1)
    })

    test('VAU-Nutzung wird getrennt erfasst', () => {
      assertEqual(k.vauBetreten, 1)
      assertEqual(k.vauAbgelaufen, 1)
    })

    test('Sammeln und Checkpoints werden gezählt', () => {
      assertEqual(k.gesammelt, 2)
      assertEqual(k.checkpoints, 1)
    })

    test('Ereignisse anderer Level fließen nicht ein', () => {
      const gemischt = levelKennzahlen('L', [
        ev('level-start', 0, undefined, 'L'),
        ev('gesammelt', 1_000, undefined, 'ANDERES'),
        ev('level-ende', 10_000, undefined, 'L'),
      ])
      assertEqual(gemischt.gesammelt, 0)
    })
  })

  suite('Telemetrie — Abbruchpunkte', () => {
    test('ein Abbruch wird als solcher erkannt', () => {
      const k = levelKennzahlen('L', [
        ev('level-start', 0, undefined, 'L'),
        ev('level-abbruch', 30_000, 'idle', 'L'),
      ])
      assertTrue(k.abgebrochen)
      assertFalse(k.beendet)
      assertClose(k.dauerSek, 30, 0.05)
    })

    test('die Sitzung nennt das Level, in dem abgebrochen wurde', () => {
      const s = sitzungKennzahlen('x', [
        ev('level-start', 0, undefined, 'A'),
        ev('level-ende', 10_000, undefined, 'A'),
        ev('level-start', 11_000, undefined, 'B'),
        ev('level-abbruch', 40_000, 'idle', 'B'),
      ])
      assertEqual(s.abbruchIn, 'B')
    })

    test('durchgespielt heißt: kein Abbruchpunkt', () => {
      assertEqual(proaktiverLauf().abbruchIn, '')
    })

    test('beteiligte Level kommen in Spielreihenfolge', () => {
      assertDeepEqual(
        beteiligteLevel([ev('level-start', 0, undefined, 'B'), ev('level-start', 1, undefined, 'A')]),
        ['B', 'A'],
      )
    })

    test('unbeendetes Level hat keine Dauer (nicht raten)', () => {
      const k = levelKennzahlen('L', [ev('level-start', 0, undefined, 'L')])
      assertEqual(k.dauerSek, 0)
      assertEqual(k.wechselProMinute, 0, 'keine Division durch Null')
    })
  })

  suite('Telemetrie — das 80-%-Kriterium (KAPSEL 4.1)', () => {
    test('die Schwelle steht im Code und ist 80', () => {
      assertEqual(BENCHMARK_PROZENT, 80)
    })

    test('4 von 5 proaktiv = 80 % = erfüllt (Grenzfall zählt als bestanden)', () => {
      const b = benchmark([
        proaktiverLauf('a'), proaktiverLauf('b'), proaktiverLauf('c'), proaktiverLauf('d'),
        reaktiverLauf('e'),
      ])
      assertEqual(b.n, 5)
      assertEqual(b.proaktiv, 4)
      assertClose(b.quote, 80, 0.01)
      assertTrue(b.erfuellt, 'genau 80 % müssen bestehen')
    })

    test('3 von 5 = 60 % = verfehlt → Mechanik überarbeiten, nicht Content bauen', () => {
      const b = benchmark([
        proaktiverLauf('a'), proaktiverLauf('b'), proaktiverLauf('c'),
        reaktiverLauf('d'), passiverLauf('e'),
      ])
      assertClose(b.quote, 60, 0.01)
      assertFalse(b.erfuellt)
    })

    test('reaktiv und passiv werden getrennt gezählt (unterschiedliche Konsequenz)', () => {
      const b = benchmark([reaktiverLauf('a'), passiverLauf('b'), passiverLauf('c')])
      assertEqual(b.reaktiv, 1)
      assertEqual(b.passiv, 2)
      assertEqual(b.proaktiv, 0)
    })

    test('ohne Daten ist das Kriterium NICHT erfüllt (kein Freifahrtschein)', () => {
      const b = benchmark([])
      assertEqual(b.n, 0)
      assertFalse(b.erfuellt, '0 Tester dürfen nie als Bestätigung gelten')
    })

    test('alle proaktiv = 100 %', () => {
      const b = benchmark([proaktiverLauf('a'), proaktiverLauf('b')])
      assertClose(b.quote, 100, 0.01)
      assertTrue(b.erfuellt)
    })
  })

  suite('Kennzahlen — Karten (KAPSEL 2.1, Paket B4)', () => {
    const ev = (typ: string, tMs: number, wert?: string) =>
      ({ typ, levelId: 'L', tMs, ...(wert !== undefined ? { wert } : {}) }) as never

    test('gefundene Ausweise werden gezählt', () => {
      const k = levelKennzahlen('L', [
        ev('level-start', 0),
        ev('karte-gefunden', 100, 'egk'),
        ev('karte-gefunden', 200, 'smcb'),
      ])
      assertEqual(k.kartenGefunden, 2)
    })

    test('gelungene Steckversuche werden gezählt', () => {
      const k = levelKennzahlen('L', [ev('level-start', 0), ev('karte-gesteckt', 500, 'egk')])
      assertEqual(k.kartenGesteckt, 1)
    })

    test('NUR „falsche-karte" zählt als Rollenverwechslung', () => {
      // Ein vergessener Ausweis ist etwas völlig anderes als der Glaube, eine
      // Karte ersetze die andere. Würden beide in dieselbe Zahl laufen, wäre
      // sie nicht deutbar (KAPSEL 1.4).
      const k = levelKennzahlen('L', [
        ev('level-start', 0),
        ev('karte-abgelehnt', 100, 'falsche-karte'),
        ev('karte-abgelehnt', 200, 'nicht-dabei'),
        ev('karte-abgelehnt', 300, 'belegt'),
        ev('karte-abgelehnt', 400, 'falsche-karte'),
      ])
      assertEqual(k.falscheKarte, 2)
    })

    test('ohne Karten-Ereignisse sind alle drei Zahlen 0', () => {
      const k = levelKennzahlen('L', [ev('level-start', 0), ev('gesammelt', 100)])
      assertEqual(k.kartenGefunden, 0)
      assertEqual(k.kartenGesteckt, 0)
      assertEqual(k.falscheKarte, 0)
    })

    test('Ereignisse fremder Level zählen nicht mit', () => {
      const k = levelKennzahlen('L', [
        ev('level-start', 0),
        { typ: 'karte-abgelehnt', levelId: 'ANDERES', tMs: 100, wert: 'falsche-karte' } as never,
      ])
      assertEqual(k.falscheKarte, 0)
    })

    test('die drei Karten-Typen sind erfasst und datenschutzkonform', () => {
      for (const typ of ['karte-gefunden', 'karte-gesteckt', 'karte-abgelehnt']) {
        assertTrue((TELEMETRIE_TYPEN as readonly string[]).includes(typ), `${typ} fehlt`)
      }
      const t = new Telemetry()
      t.setLevel('L')
      t.note('karte-gefunden', 10, 'egk')
      // Kein Feld über typ/levelId/tMs/wert hinaus — der Ausweis ist eine
      // Kartenart, keine Person.
      assertDeepEqual(Object.keys(t.alle()[0]).sort(), ['levelId', 'tMs', 'typ', 'wert'])
    })
  })
}
