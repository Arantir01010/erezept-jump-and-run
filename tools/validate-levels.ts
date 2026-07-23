/**
 * KOMPLETT-PRÜFUNG — das Sicherheitsnetz vor jedem Commit/Start.
 *
 * Aufruf: npm run validate   (CI-fähig, Exit-Code ≠ 0 bei Fehlern)
 *
 * Prüft in einem Durchlauf:
 *   1. Basis-Konfigurationen (game-config, themes, input-bindings) gegen die zod-Schemas
 *   2. Alle Level-Quellen in design/ (Compiler im Check-Modus: Struktur, Vokabular,
 *      Softlocks, Erreichbarkeit) UND ob die erzeugten public/-Dateien aktuell sind
 *   3. Den Spielkern (npm run guard): keine geschützte Datei verändert/ergänzt/gelöscht
 *
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */
import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { GameConfigSchema, ThemesSchema, BindingsSchema, formatZodError } from '../src/level/schema'
import { runPipeline, PUBLIC } from './lib/pipeline'
import { checkCore } from './check-core'

let errors = 0
const fail = (msg: string): void => {
  errors += 1
  console.error(`✗ ${msg}`)
}
const ok = (msg: string): void => console.log(`✓ ${msg}`)

function readJson(relPath: string): unknown {
  const file = join(PUBLIC, relPath)
  if (!existsSync(file)) {
    fail(`${relPath}: Datei fehlt`)
    return null
  }
  try {
    return JSON.parse(readFileSync(file, 'utf-8'))
  } catch (e) {
    fail(`${relPath}: kein gültiges JSON (${e instanceof Error ? e.message : e})`)
    return null
  }
}

// --- 1. Basis-Konfigurationen ---
console.log('— Basis-Konfigurationen —')
const gameRaw = readJson('config/game-config.json')
const game = gameRaw ? GameConfigSchema.safeParse(gameRaw) : null
if (game && !game.success) fail(formatZodError('config/game-config.json', game.error))
else if (game) ok('config/game-config.json')

const themesRaw = readJson('config/themes.json')
const themes = themesRaw ? ThemesSchema.safeParse(themesRaw) : null
if (themes && !themes.success) fail(formatZodError('config/themes.json', themes.error))
else if (themes) ok('config/themes.json')

const bindingsRaw = readJson('config/input-bindings.json')
const bindings = bindingsRaw ? BindingsSchema.safeParse(bindingsRaw) : null
if (bindings && !bindings.success) fail(formatZodError('config/input-bindings.json', bindings.error))
else if (bindings) ok('config/input-bindings.json')

// --- 2. Level-Quellen + erzeugte Dateien ---
console.log('\n— Level (design/ → public/) —')
const report = runPipeline({ write: false })
for (const w of report.warnings) console.warn(`⚠ ${w}`)
for (const e of report.errors) fail(e)
if (report.ok) for (const level of report.levels) ok(`design/levels/${level.id}/ → Struktur, Vokabular, Tore, Erreichbarkeit`)

// --- 3. Spielkern-Schutz ---
console.log('\n— Spielkern (geschützte Dateien) —')
const guard = checkCore()
if (guard.ok) {
  ok('Kern unverändert (tools/core-manifest.json)')
} else {
  for (const p of guard.problems) fail(p)
  console.error('  → Bewusste Engine-Änderung durch einen Menschen? Dann: npm run guard:update')
  console.error('  → Levelbau-KI? Änderung zurücknehmen — erlaubt sind nur design/levels/**, design/playlist.json, public/config/themes.json')
}

console.log('')
if (errors > 0) {
  console.error(`${errors} Problem(e) gefunden. Anleitung: design/LEVELBAU.md`)
  process.exit(1)
}
console.log('Alles gültig: Konfigurationen ✓ Level ✓ Spielkern ✓')
