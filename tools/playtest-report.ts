/**
 * PLAYTEST-AUSWERTUNG — `npm run playtest:report -- <datei-oder-ordner> [...]`
 *
 * Liest die mit F9 exportierten JSON-Dateien, führt sie zusammen und druckt den
 * Bericht. Ohne Argument wird der Ordner `playtest-daten/` gesucht.
 *
 * `--strict` liefert Exit-Code 1, wenn das 80-%-Kriterium verfehlt ist —
 * praktisch, wenn die Auswertung in einem Skript hängt. Ohne `--strict` ist ein
 * verfehltes Kriterium KEIN Programmfehler, sondern ein Ergebnis.
 *
 * Die Logik selbst steht in src/playtest/bericht.ts (getestet). Diese Datei ist
 * nur Ein- und Ausgabe.
 *
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { sammleSitzungen, erstelleBericht, formatBericht } from '../src/playtest/bericht'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

const argumente = process.argv.slice(2)
const strikt = argumente.includes('--strict')
const pfade = argumente.filter((a) => !a.startsWith('--'))
if (pfade.length === 0) pfade.push('playtest-daten')

/** Alle JSON-Dateien hinter einem Pfad (Datei oder Ordner). */
function dateien(pfad: string): string[] {
  const abs = resolve(ROOT, pfad)
  if (!existsSync(abs)) return []
  if (statSync(abs).isDirectory()) {
    return readdirSync(abs)
      .filter((f) => f.toLowerCase().endsWith('.json'))
      .map((f) => join(abs, f))
  }
  return [abs]
}

const gefunden = pfade.flatMap(dateien)
if (gefunden.length === 0) {
  console.error(`Keine JSON-Dateien gefunden unter: ${pfade.join(', ')}`)
  console.error('')
  console.error('So kommst du an die Daten:')
  console.error('  1. Im Spiel F9 drücken — es wird eine Datei telemetrie-*.json gespeichert.')
  console.error('  2. Die Datei(en) nach playtest-daten/ legen.')
  console.error('  3. npm run playtest:report')
  console.error('')
  console.error('Anleitung: docs/PLAYTEST.md')
  process.exit(1)
}

const inhalte: unknown[] = []
for (const datei of gefunden) {
  try {
    inhalte.push(JSON.parse(readFileSync(datei, 'utf-8')))
  } catch (e) {
    // Eine kaputte Datei darf die anderen nicht blockieren
    console.warn(`⚠ ${datei}: kein gültiges JSON — übersprungen (${e instanceof Error ? e.message : e})`)
  }
}

/** Welche Level nutzen die Hülle? Nur dort ist „verstanden" aussagekräftig. */
function huelleLevel(): string[] {
  try {
    const cfg = JSON.parse(readFileSync(join(ROOT, 'public', 'config', 'game-config.json'), 'utf-8')) as {
      levelOrder: string[]
    }
    return cfg.levelOrder.filter((id) => {
      const datei = join(ROOT, 'public', 'config', 'levels', `${id}.json`)
      if (!existsSync(datei)) return false
      const level = JSON.parse(readFileSync(datei, 'utf-8')) as { huelle?: { enabled?: boolean } }
      return level.huelle?.enabled === true
    })
  } catch {
    return []
  }
}

const rohe = sammleSitzungen(inhalte)
const bericht = erstelleBericht(rohe, huelleLevel())

console.log('')
console.log(formatBericht(bericht))
console.log('')
console.log(`(${gefunden.length} Datei(en) gelesen, ${rohe.length} Durchläufe nach Entdoppelung)`)

if (strikt && !bericht.benchmark.erfuellt) process.exit(1)
