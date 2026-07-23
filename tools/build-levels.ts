/**
 * LEVEL-BUILD — kompiliert alle Level aus design/ nach public/.
 *
 * Aufruf: npm run build:levels
 *
 * Bei Fehlern wird NICHTS geschrieben; jede Meldung sagt, wo und was zu
 * korrigieren ist. Nur eine fehlerfreie Playlist landet im Spiel.
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */
import { runPipeline } from './lib/pipeline'

const report = runPipeline({ write: true })

for (const w of report.warnings) console.warn(`⚠ ${w}`)
for (const e of report.errors) console.error(`✗ ${e}`)

if (!report.ok) {
  console.error(`\nBuild abgebrochen — ${report.errors.length} Fehler. Es wurde nichts geschrieben.`)
  console.error('Anleitung und alle Regeln: design/LEVELBAU.md')
  process.exit(1)
}

for (const level of report.levels) console.log(`✓ ${level.id}`)
if (report.written.length > 0) {
  console.log(`\nAktualisiert:\n  ${report.written.join('\n  ')}`)
} else {
  console.log('\nAlles bereits aktuell — nichts zu schreiben.')
}
if (report.warnings.length > 0) {
  console.log(`\n${report.warnings.length} Warnung(en) — bitte kurz prüfen (siehe oben).`)
}
console.log('\nFertig. Test im Browser: npm run dev  ·  Komplett-Prüfung: npm run validate')
