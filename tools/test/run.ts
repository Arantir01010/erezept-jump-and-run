/**
 * TESTLAUF — `npm test`
 *
 * Führt alle Testmodule in EINEM Node-Prozess aus. Bewusst ohne Test-Framework
 * (vitest/jest), damit `npm test` auf dem Messe-PC und in der CI ohne
 * zusätzliche Netzwerk-Installation läuft — die Abhängigkeiten des Projekts
 * reichen aus (tsx ist bereits devDependency).
 *
 * Neue Testdatei? Hier importieren und in SUITES eintragen.
 *
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */
import { finish, summary } from './harness'
import { run as huelle } from './huelle.test'
import { run as protokoll } from './protokoll.test'
import { run as karten } from './karten.test'
import { run as kartenleser } from './kartenleser.test'
import { run as lauscher } from './lauscher.test'
import { run as podest } from './podest.test'
import { run as tubekamera } from './tubekamera.test'
import { run as input } from './input.test'
import { run as katalog } from './katalog.test'
import { run as compiler } from './compiler.test'
import { run as levels } from './levels.test'
import { run as registry } from './registry.test'
import { run as hud } from './hud.test'
import { run as verdrahtung } from './verdrahtung.test'
import { run as recht } from './recht.test'
import { run as telemetrie } from './telemetrie.test'
import { run as playtest } from './playtest.test'
import { run as bericht } from './bericht.test'

/** Reihenfolge: von innen nach außen — Kern zuerst, echte Level zuletzt. */
const SUITES: [string, () => void][] = [
  ['Hülle-Zustandsmaschine', huelle],
  ['Karten stecken', karten],
  ['Kartenleser (Terminal)', kartenleser],
  ['Zugriffsprotokoll', protokoll],
  ['Lauscher-Sichtlogik', lauscher],
  ['Podest-Fortschritt', podest],
  ['Tube-Kamera', tubekamera],
  ['Eingabe (Toggle-Belegung)', input],
  ['Objektkatalog', katalog],
  ['Level-Compiler', compiler],
  ['Baustein-Registry', registry],
  ['HUD-Anzeige', hud],
  ['Recht, Marke & Protokoll', recht],
  ['Telemetrie & 80-%-Kriterium', telemetrie],
  ['Pre-/Post-Test (Fragebogen)', playtest],
  ['Playtest-Bericht (Auswertung)', bericht],
  ['Verdrahtung (Szenen & Bausteine)', verdrahtung],
  ['Echte Level (Regression)', levels],
]

console.log("e-Rezept Jump'n'Run — Testlauf")
for (const [, fn] of SUITES) fn()

const s = summary()
console.log(`\n${s.passed + s.failed} Tests · ${s.passed} grün · ${s.failed} rot`)
finish()
