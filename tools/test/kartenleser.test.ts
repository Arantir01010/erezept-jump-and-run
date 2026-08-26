/**
 * KARTENLESER — die Entscheidungen des Terminals (Paket B2).
 *
 * Die Zustandsmaschine dahinter (KartenState, Paket B1) hat eigene Tests.
 * Hier geht es um das, was zwischen Level-JSON und Terminal passiert: Welche
 * Karten akzeptiert ein Leser, und was bekommt der Spieler bei welchem
 * Ergebnis zu hören?
 */
import { suite, test, assertEqual, assertTrue, assertFalse } from './harness'
import {
  parseKarten,
  kartenListe,
  terminalId,
  istZurueckweisung,
  STECK_MELDUNG,
} from '../../src/mechanics/kartenLeserLogik'
import { Karte, ALLE_KARTEN } from '../../src/state/KartenState'

export function run(): void {
  suite('Kartenleser — erlaubte Karten aus dem Level lesen', () => {
    test('Liste aus dem level.json', () => {
      assertEqual(parseKarten(['egk', 'smcb']).join(','), 'egk,smcb')
    })

    test('Komma-String aus einer Tiled-Property (Tiled kennt keine Listen)', () => {
      assertEqual(parseKarten('egk,smcb').join(','), 'egk,smcb')
    })

    test('Leerzeichen und Großschreibung stören nicht', () => {
      assertEqual(parseKarten(' eGK , SMCB ').join(','), 'egk,smcb')
    })

    test('die Reihenfolge ist IMMER die feste aus ALLE_KARTEN', () => {
      // Damit steckePassende() vorhersehbar wählt: Leveldesign darf sich nicht
      // auf die Schreibreihenfolge im JSON verlassen.
      assertEqual(parseKarten(['smcb', 'egk']).join(','), ALLE_KARTEN.filter((k) => k !== Karte.HBA).join(','))
    })

    test('Unbekanntes wird verworfen, nicht geraten', () => {
      assertEqual(parseKarten(['egk', 'personalausweis']).join(','), 'egk')
    })

    test('nichts angegeben ergibt eine leere Liste (der Compiler meckert, nicht der Baustein)', () => {
      assertEqual(parseKarten(undefined).length, 0)
      assertEqual(parseKarten('').length, 0)
      assertEqual(parseKarten(42).length, 0)
    })

    test('keine Dubletten, auch bei doppelter Nennung', () => {
      assertEqual(parseKarten(['egk', 'egk', 'egk']).length, 1)
    })
  })

  suite('Kartenleser — Hinweistexte nennen die richtige Karte', () => {
    test('eine Karte', () => {
      assertEqual(kartenListe([Karte.EGK]), 'eGK')
    })

    test('zwei Karten werden mit „oder" verbunden', () => {
      assertEqual(kartenListe([Karte.EGK, Karte.SMCB]), 'eGK oder SMC-B')
    })

    test('drei Karten: Komma, Komma, oder', () => {
      assertEqual(kartenListe(ALLE_KARTEN), 'eGK, HBA oder SMC-B')
    })

    test('leere Liste ergibt leeren Text (der Aufrufer setzt dann seinen Ersatz ein)', () => {
      assertEqual(kartenListe([]), '')
    })
  })

  suite('Kartenleser — nur echte Zurückweisung bekommt den Stempel', () => {
    test('falsche Karte = ZUGRIFF VERWEIGERT', () => {
      assertTrue(istZurueckweisung('falsche-karte'))
    })

    test('„noch nicht gefunden" ist KEINE Zurückweisung', () => {
      // Sonst schiebt das Spiel dem Spieler Schuld zu, wo er nur noch nicht
      // so weit ist — Markenregel: es wird nie jemand vorgeführt.
      assertFalse(istZurueckweisung('nicht-dabei'))
    })

    test('„Karte steckt woanders" ist KEINE Zurückweisung', () => {
      assertFalse(istZurueckweisung('belegt'))
    })

    test('Erfolg schon gar nicht', () => {
      assertFalse(istZurueckweisung('ok'))
    })
  })

  suite('Kartenleser — jedes Ergebnis hat einen eigenen Satz', () => {
    test('drei Misserfolge, drei verschiedene Texte', () => {
      const texte = [
        STECK_MELDUNG['nicht-dabei'].de,
        STECK_MELDUNG['falsche-karte'].de,
        STECK_MELDUNG['belegt'].de,
      ]
      assertEqual(new Set(texte).size, 3, 'ein Einheitssatz („geht nicht") nimmt dem Spieler die Information')
    })

    test('jeder Text ist auch auf Englisch da', () => {
      for (const [grund, text] of Object.entries(STECK_MELDUNG)) {
        assertTrue(!!text.en, `${grund} hat keinen englischen Text`)
      }
    })

    test('für „ok" gibt es bewusst KEINEN Standardsatz', () => {
      // Der Erfolgssatz gehört dem Level (station.reziText) — er trägt die
      // fachliche Aussage der Station und darf nicht generisch sein.
      assertFalse('ok' in STECK_MELDUNG)
    })
  })

  suite('Kartenleser — Terminal-Kennung', () => {
    test('der Name aus dem Level gewinnt', () => {
      assertEqual(terminalId('praxis-terminal', 7), 'praxis-terminal')
    })

    test('ohne Namen wird aus der Objekt-ID eine gebaut', () => {
      assertEqual(terminalId(undefined, 7), 'kartenleser-7')
      assertEqual(terminalId('   ', 7), 'kartenleser-7')
    })

    test('zwei namenlose Leser bekommen verschiedene Kennungen', () => {
      // „Ein Terminal hat genau einen Schlitz" funktioniert nur mit
      // unterscheidbaren Kennungen.
      assertTrue(terminalId(undefined, 1) !== terminalId(undefined, 2))
    })
  })
}
