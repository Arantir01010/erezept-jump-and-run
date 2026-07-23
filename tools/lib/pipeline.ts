/**
 * PIPELINE — orchestriert den Level-Baukasten:
 * liest design/playlist.json + design/levels/<id>/, kompiliert alle Level
 * und schreibt (oder prüft) die erzeugten Spieldateien in public/.
 *
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */
import { readFileSync, writeFileSync, existsSync, readdirSync, mkdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { compileLevel, type CompiledLevel } from './compile'
import { LEVEL_ID_PATTERN } from './catalog'

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
export const DESIGN = join(ROOT, 'design')
export const PUBLIC = join(ROOT, 'public')

export interface PipelineReport {
  ok: boolean
  errors: string[]
  warnings: string[]
  /** Erzeugte/aktualisierte Dateien (write-Modus) bzw. veraltete Dateien (check-Modus). */
  written: string[]
  stale: string[]
  levels: CompiledLevel[]
}

function readJson(file: string, errors: string[], label: string): unknown {
  if (!existsSync(file)) {
    errors.push(`${label}: Datei fehlt (${file}).`)
    return null
  }
  try {
    return JSON.parse(readFileSync(file, 'utf-8'))
  } catch (e) {
    errors.push(`${label}: kein gültiges JSON (${e instanceof Error ? e.message : e}).`)
    return null
  }
}

/** Kanonischer Vergleich (Whitespace-/Formatunabhängig, aber Reihenfolge zählt). */
function sameJson(a: unknown, bText: string | null): boolean {
  if (bText === null) return false
  try {
    return JSON.stringify(a) === JSON.stringify(JSON.parse(bText))
  } catch {
    return false
  }
}

function readTextIfExists(file: string): string | null {
  return existsSync(file) ? readFileSync(file, 'utf-8') : null
}

export function runPipeline(opts: { write: boolean }): PipelineReport {
  const report: PipelineReport = { ok: true, errors: [], warnings: [], written: [], stale: [], levels: [] }
  const { errors, warnings } = report

  // --- Themes (für Theme-Existenz-Prüfung) ---
  const themesRaw = readJson(join(PUBLIC, 'config', 'themes.json'), errors, 'public/config/themes.json')
  const themes = (themesRaw ?? {}) as Record<string, unknown>

  // --- Playlist ---
  const playlistRaw = readJson(join(DESIGN, 'playlist.json'), errors, 'design/playlist.json')
  if (!Array.isArray(playlistRaw) || !playlistRaw.every((e) => typeof e === 'string')) {
    errors.push('design/playlist.json muss eine Liste von Level-IDs sein, z. B. ["01-stammdaten", "02-kartenterminal"].')
    report.ok = false
    return report
  }
  const playlist = playlistRaw as string[]
  if (playlist.length === 0) errors.push('design/playlist.json ist leer — mindestens ein Level nötig.')
  const seen = new Set<string>()
  for (const id of playlist) {
    if (seen.has(id)) errors.push(`design/playlist.json: "${id}" steht doppelt in der Liste.`)
    seen.add(id)
  }

  // --- Verwaiste Level-Ordner (nicht in der Playlist) ---
  const levelsDir = join(DESIGN, 'levels')
  if (existsSync(levelsDir)) {
    for (const entry of readdirSync(levelsDir, { withFileTypes: true })) {
      if (!entry.isDirectory() || entry.name.startsWith('_')) continue
      if (!seen.has(entry.name)) {
        warnings.push(`design/levels/${entry.name}/ existiert, steht aber nicht in design/playlist.json — wird ignoriert.`)
      }
    }
  }

  // --- Level kompilieren ---
  for (const id of playlist) {
    const dir = join(levelsDir, id)
    if (!existsSync(dir)) {
      errors.push(`design/levels/${id}/ fehlt (steht aber in der Playlist). Neues Level anlegen: npm run neues-level -- ${id}`)
      continue
    }
    if (!LEVEL_ID_PATTERN.test(id)) {
      errors.push(`Level-ID "${id}": Muster ist NN-kleinbuchstaben, z. B. "04-fachdienst".`)
      continue
    }
    const layout = readTextIfExists(join(dir, 'layout.txt'))
    if (layout === null) {
      errors.push(`design/levels/${id}/layout.txt fehlt.`)
      continue
    }
    const levelRaw = readJson(join(dir, 'level.json'), errors, `design/levels/${id}/level.json`)
    if (levelRaw === null) continue

    const compiled = compileLevel(id, layout, levelRaw, themes)
    report.levels.push(compiled)
    errors.push(...compiled.errors.map((e) => `[${id}] ${e}`))
    warnings.push(...compiled.warnings.map((w) => `[${id}] ${w}`))
  }

  if (errors.length > 0) {
    report.ok = false
    return report // Bei Fehlern wird NICHTS geschrieben (kein halber Zustand)
  }

  // --- Schreiben bzw. Aktualitäts-Check ---
  const gameConfigFile = join(PUBLIC, 'config', 'game-config.json')
  const gameConfigRaw = readJson(gameConfigFile, errors, 'public/config/game-config.json')
  const gameConfig = (gameConfigRaw ?? {}) as Record<string, unknown>

  for (const level of report.levels) {
    const tmjFile = join(PUBLIC, 'assets', 'tilemaps', `${level.id}.tmj`)
    const jsonFile = join(PUBLIC, 'config', 'levels', `${level.id}.json`)
    const tmjText = JSON.stringify(level.tmj)
    const jsonText = JSON.stringify(level.levelJson, null, 2) + '\n'

    if (opts.write) {
      mkdirSync(dirname(tmjFile), { recursive: true })
      mkdirSync(dirname(jsonFile), { recursive: true })
      if (readTextIfExists(tmjFile) !== tmjText) {
        writeFileSync(tmjFile, tmjText)
        report.written.push(`public/assets/tilemaps/${level.id}.tmj`)
      }
      if (readTextIfExists(jsonFile) !== jsonText) {
        writeFileSync(jsonFile, jsonText)
        report.written.push(`public/config/levels/${level.id}.json`)
      }
    } else {
      if (!sameJson(level.tmj, readTextIfExists(tmjFile))) report.stale.push(`public/assets/tilemaps/${level.id}.tmj`)
      if (!sameJson(level.levelJson, readTextIfExists(jsonFile))) report.stale.push(`public/config/levels/${level.id}.json`)
    }
  }

  // --- levelOrder in game-config.json spiegelt die Playlist ---
  const currentOrder = JSON.stringify(gameConfig.levelOrder ?? [])
  if (currentOrder !== JSON.stringify(playlist)) {
    if (opts.write) {
      gameConfig.levelOrder = playlist
      writeFileSync(gameConfigFile, JSON.stringify(gameConfig, null, 2) + '\n')
      report.written.push('public/config/game-config.json (levelOrder)')
    } else {
      report.stale.push('public/config/game-config.json (levelOrder ≠ design/playlist.json)')
    }
  }

  if (report.stale.length > 0) {
    errors.push(
      `Erzeugte Spieldateien sind veraltet: ${report.stale.join(', ')} — einmal "npm run build:levels" ausführen ` +
        '(design/ ist die Quelle der Wahrheit; public/-Leveldateien werden generiert).',
    )
    report.ok = false
  }

  return report
}
