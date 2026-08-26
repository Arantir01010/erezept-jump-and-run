/**
 * KARTEN STECKEN (KAPSEL 2.1, Zusatzmechanik 1) — Zustandsmaschine.
 *
 * Die wichtigste Gruppe in dieser Suite ist die letzte: Sie nagelt die
 * fachlichen Leitplanken aus KAPSEL 1.4 fest. Ein Lernspiel, das die eGK als
 * Datenspeicher darstellt, richtet Schaden an — deshalb wird hier geprüft, dass
 * das Modell das gar nicht zulässt.
 */
import { suite, test, assertEqual, assertTrue, assertFalse, assertDeepEqual } from './harness'
import {
  KartenState,
  Karte,
  ALLE_KARTEN,
  KARTEN_INFO,
  type KartenChange,
} from '../../src/state/KartenState'

/** Ein Terminal, das nur die eGK akzeptiert (z. B. Apotheke, E-Rezept). */
const NUR_EGK = [Karte.EGK] as const
/** Ein Terminal, das nur die Institutionskarte akzeptiert (Praxis-Zugang). */
const NUR_SMCB = [Karte.SMCB] as const
/** Ein Terminal, das jede Heilberufs-/Institutionsidentität akzeptiert. */
const HBA_ODER_SMCB = [Karte.HBA, Karte.SMCB] as const

export function run(): void {
  suite('Karten — Besitz', () => {
    test('zu Beginn hat der Spieler keine Karte', () => {
      const k = new KartenState()
      assertEqual(k.anzahl, 0)
      assertFalse(k.hat(Karte.EGK))
      assertEqual(k.gesteckt, null)
      assertFalse(k.sitzungOffen)
    })

    test('eine gefundene Karte bleibt im Besitz', () => {
      const k = new KartenState()
      assertTrue(k.nimm(Karte.EGK))
      assertTrue(k.hat(Karte.EGK))
      assertEqual(k.anzahl, 1)
    })

    test('dieselbe Karte zweimal aufsammeln ändert nichts', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      assertFalse(k.nimm(Karte.EGK), 'zweiter Fund ist kein neuer Fund')
      assertEqual(k.anzahl, 1)
    })

    test('gefundene Karten kommen in fester Reihenfolge (HUD bleibt ruhig)', () => {
      const k = new KartenState()
      k.nimm(Karte.SMCB)
      k.nimm(Karte.EGK)
      assertDeepEqual(k.gefunden, [Karte.EGK, Karte.SMCB], 'Reihenfolge folgt ALLE_KARTEN, nicht dem Fundzeitpunkt')
    })

    test('jede Kartenart hat Anzeigename und Träger', () => {
      for (const karte of ALLE_KARTEN) {
        assertTrue(KARTEN_INFO[karte].kurz.length > 1, `${karte}: Kurzname fehlt`)
        assertTrue(KARTEN_INFO[karte].wer.length > 3, `${karte}: Träger fehlt`)
      }
    })

    test('die drei Kartenarten sind unterscheidbar', () => {
      assertEqual(new Set(ALLE_KARTEN).size, 3)
      assertEqual(new Set(ALLE_KARTEN.map((k) => KARTEN_INFO[k].kurz)).size, 3)
    })
  })

  suite('Karten — Stecken und Ziehen', () => {
    test('die richtige Karte am richtigen Terminal wird angenommen', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      assertEqual(k.stecke(Karte.EGK, 't1', NUR_EGK), 'ok')
      assertEqual(k.gesteckt, Karte.EGK)
      assertTrue(k.istGestecktAn('t1'))
      assertTrue(k.sitzungOffen)
    })

    test('die falsche Karte wird abgelehnt — ZUGRIFF VERWEIGERT', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      assertEqual(k.stecke(Karte.EGK, 't1', NUR_SMCB), 'falsche-karte')
      assertEqual(k.gesteckt, null, 'nach Ablehnung steckt nichts')
      assertFalse(k.sitzungOffen)
    })

    test('eine Karte, die man nicht hat, kann man nicht stecken', () => {
      const k = new KartenState()
      assertEqual(k.stecke(Karte.HBA, 't1', HBA_ODER_SMCB), 'nicht-dabei')
    })

    test('ein Terminal hat genau einen Schlitz', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.nimm(Karte.SMCB)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      assertEqual(k.stecke(Karte.SMCB, 't2', NUR_SMCB), 'belegt', 'erst ziehen, dann neu stecken')
      assertEqual(k.gesteckt, Karte.EGK, 'die erste Karte bleibt')
    })

    test('dieselbe Karte am selben Terminal erneut stecken ist kein Fehler', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      assertEqual(k.stecke(Karte.EGK, 't1', NUR_EGK), 'ok', 'mehrfaches Drücken darf nicht bestrafen')
    })

    test('Ziehen beendet die Sitzung', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      assertTrue(k.zieh())
      assertEqual(k.gesteckt, null)
      assertFalse(k.istGestecktAn('t1'))
      assertFalse(k.sitzungOffen)
    })

    test('Ziehen ohne gesteckte Karte ist ein No-Op', () => {
      assertFalse(new KartenState().zieh())
    })

    test('nach dem Ziehen ist dasselbe Terminal wieder nutzbar', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      k.zieh()
      assertEqual(k.stecke(Karte.EGK, 't1', NUR_EGK), 'ok')
    })

    test('die Karte bleibt nach dem Ziehen im Besitz (ein Ausweis wird nicht verbraucht)', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      k.zieh()
      assertTrue(k.hat(Karte.EGK))
      assertEqual(k.anzahl, 1)
    })
  })

  suite('Karten — automatische Kartenwahl am Terminal', () => {
    test('nimmt die passende Karte aus dem Besitz', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.nimm(Karte.SMCB)
      assertEqual(k.steckePassende('t1', NUR_SMCB), 'ok')
      assertEqual(k.gesteckt, Karte.SMCB, 'wählt die, die das Terminal akzeptiert')
    })

    test('ohne jede Karte: nicht-dabei', () => {
      assertEqual(new KartenState().steckePassende('t1', NUR_EGK), 'nicht-dabei')
    })

    test('mit Karten, aber keiner passenden: falsche-karte', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      assertEqual(k.steckePassende('t1', NUR_SMCB), 'falsche-karte', 'anderer Tipp als „nichts dabei"')
    })

    test('erneutes Drücken am selben Terminal bleibt ok', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.steckePassende('t1', NUR_EGK)
      assertEqual(k.steckePassende('t1', NUR_EGK), 'ok')
    })

    test('an einem anderen Terminal, während etwas steckt: belegt', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.nimm(Karte.SMCB)
      k.steckePassende('t1', NUR_EGK)
      assertEqual(k.steckePassende('t2', NUR_SMCB), 'belegt')
    })

    test('die Terminal-Reihenfolge entscheidet bei mehreren Möglichkeiten', () => {
      const k = new KartenState()
      k.nimm(Karte.HBA)
      k.nimm(Karte.SMCB)
      k.steckePassende('t1', HBA_ODER_SMCB)
      assertEqual(k.gesteckt, Karte.HBA, 'erste erlaubte Karte gewinnt — vorhersehbar für Leveldesign')
    })
  })

  suite('Karten — Meldungen an das Spiel', () => {
    test('jedes Ereignis nennt Grund, Karte und Terminal', () => {
      const k = new KartenState()
      const gesehen: string[] = []
      k.onChange((c: KartenChange) => gesehen.push(`${c.reason}:${c.karte ?? '-'}:${c.terminalId ?? '-'}`))
      k.nimm(Karte.EGK)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      k.zieh()
      assertDeepEqual(gesehen, ['gefunden:egk:-', 'gesteckt:egk:t1', 'gezogen:egk:t1'])
    })

    test('eine Ablehnung wird gemeldet (Grundlage für „ZUGRIFF VERWEIGERT")', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      const gesehen: KartenChange[] = []
      k.onChange((c) => gesehen.push(c))
      k.stecke(Karte.EGK, 't9', NUR_SMCB)
      assertEqual(gesehen.length, 1)
      assertEqual(gesehen[0].reason, 'abgelehnt')
      assertEqual(gesehen[0].terminalId, 't9', 'das Spiel muss wissen, WO der Stempel erscheint')
    })

    test('ein blockierter Versuch meldet nichts (kein Ereignis-Spam beim Halten)', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.nimm(Karte.SMCB)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      let n = 0
      k.onChange(() => (n += 1))
      k.stecke(Karte.SMCB, 't2', NUR_SMCB)
      assertEqual(n, 0)
    })

    test('Abmelden stoppt die Benachrichtigung', () => {
      const k = new KartenState()
      let n = 0
      const off = k.onChange(() => (n += 1))
      k.nimm(Karte.EGK)
      off()
      k.nimm(Karte.HBA)
      assertEqual(n, 1)
    })

    test('reset räumt Besitz und Sitzung auf (neuer Besucher am Stand)', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      k.reset()
      assertEqual(k.anzahl, 0)
      assertEqual(k.gesteckt, null)
      assertFalse(k.sitzungOffen)
    })
  })

  suite('Karten — fachliche Leitplanken (KAPSEL 1.4)', () => {
    test('die Karte ist ein SCHLÜSSEL, kein Speicher: das Modell kennt keine Daten', () => {
      // Würde die Karte Befunde tragen, müsste es hier ein Feld dafür geben.
      // Dieser Test schlägt an, wenn jemand später „inhalt" o. Ä. ergänzt.
      const k = new KartenState()
      k.nimm(Karte.EGK)
      const felder = Object.keys(JSON.parse(JSON.stringify({ ...KARTEN_INFO[Karte.EGK] })))
      assertDeepEqual(felder.sort(), ['kurz', 'wer'], 'eine Karte hat Identität — keine Inhalte')
    })

    test('Ziehen beendet den Zugriff SOFORT — es bleibt nichts zurück', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.stecke(Karte.EGK, 't1', NUR_EGK)
      k.zieh()
      assertFalse(k.sitzungOffen, 'kein Nachlauf, kein Restzugriff')
      assertFalse(k.istGestecktAn('t1'))
    })

    test('ohne die richtige Identität gibt es keinen Zugriff — auch nicht „ein bisschen"', () => {
      const k = new KartenState()
      k.nimm(Karte.EGK)
      k.nimm(Karte.HBA)
      assertEqual(k.stecke(Karte.EGK, 'praxis', NUR_SMCB), 'falsche-karte')
      assertEqual(k.stecke(Karte.HBA, 'praxis', NUR_SMCB), 'falsche-karte')
      assertFalse(k.sitzungOffen, 'zwei Fehlversuche öffnen nichts')
    })

    test('die eGK öffnet den Zugriff, ersetzt aber keine Institutionskarte', () => {
      // Fachlich: eGK = Versicherte, SMC-B = Einrichtung. Zwei Rollen, zwei Karten.
      const k = new KartenState()
      k.nimm(Karte.EGK)
      assertEqual(k.stecke(Karte.EGK, 'apotheke', NUR_EGK), 'ok')
      k.zieh()
      assertEqual(k.stecke(Karte.EGK, 'praxis', NUR_SMCB), 'falsche-karte')
    })

    test('dieses Modul signiert nichts (Verschlüsselung ≠ Signatur)', () => {
      const methoden = Object.getOwnPropertyNames(KartenState.prototype)
      for (const verboten of ['signiere', 'sign', 'stempel', 'qes']) {
        assertFalse(
          methoden.some((m) => m.toLowerCase().includes(verboten)),
          `KartenState darf nicht signieren — das ist stamp-exit (gefunden: ${verboten})`,
        )
      }
    })
  })
}
