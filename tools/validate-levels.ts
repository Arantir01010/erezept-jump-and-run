/**
 * Redaktions-Sicherheitsnetz: prüft alle JSON-Konfigurationen gegen die
 * zod-Schemas, ob referenzierte Dateien existieren und ob jede Tilemap nur
 * bekannte Mechanik-Typen verwendet. CI-fähig (Exit-Code ≠ 0 bei Fehlern).
 *
 * Aufruf: npm run validate
 */
import { readFileSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  GameConfigSchema,
  ThemesSchema,
  BindingsSchema,
  LevelSchema,
  formatZodError,
} from '../src/level/schema'
import { isKnownMechanicType, MECHANIC_TYPE_IDS } from '../src/mechanics/typeIds'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const PUBLIC = join(ROOT, 'public')

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

// --- game-config ---
const gameRaw = readJson('config/game-config.json')
const game = gameRaw ? GameConfigSchema.safeParse(gameRaw) : null
if (game && !game.success) fail(formatZodError('config/game-config.json', game.error))
else if (game) ok('config/game-config.json')

// --- themes ---
const themesRaw = readJson('config/themes.json')
const themes = themesRaw ? ThemesSchema.safeParse(themesRaw) : null
if (themes && !themes.success) fail(formatZodError('config/themes.json', themes.error))
else if (themes) ok('config/themes.json')

// --- bindings ---
const bindingsRaw = readJson('config/input-bindings.json')
const bindings = bindingsRaw ? BindingsSchema.safeParse(bindingsRaw) : null
if (bindings && !bindings.success) fail(formatZodError('config/input-bindings.json', bindings.error))
else if (bindings) ok('config/input-bindings.json')

// --- Levels der Playlist ---
if (game?.success) {
  for (const id of game.data.levelOrder) {
    const rel = `config/levels/${id}.json`
    const raw = readJson(rel)
    if (!raw) continue
    const parsed = LevelSchema.safeParse(raw)
    if (!parsed.success) {
      fail(formatZodError(rel, parsed.error))
      continue
    }
    const level = parsed.data
    if (level.id !== id) fail(`${rel}: Feld "id" (${level.id}) entspricht nicht dem Dateinamen`)
    if (themes?.success && !themes.data[level.theme]) {
      fail(`${rel}: Theme "${level.theme}" fehlt in config/themes.json`)
    }
    for (const type of Object.keys(level.mechanics)) {
      if (!isKnownMechanicType(type)) {
        fail(`${rel}: unbekannter Mechanik-Typ "${type}" (bekannt: ${MECHANIC_TYPE_IDS.join(', ')})`)
      }
    }

    // Tilemap: Existenz + Objekt-Typen + Pflicht-Layer
    const mapFile = join(PUBLIC, level.tilemap)
    if (!existsSync(mapFile)) {
      fail(`${rel}: Tilemap "${level.tilemap}" fehlt (npm run gen:maps vergessen?)`)
      continue
    }
    try {
      const map = JSON.parse(readFileSync(mapFile, 'utf-8')) as {
        layers?: { type: string; name: string; objects?: { type?: string; x?: number; y?: number }[] }[]
      }
      const terrain = map.layers?.find((l) => l.type === 'tilelayer' && l.name === 'terrain')
      const objectLayer = map.layers?.find((l) => l.type === 'objectgroup' && l.name === 'objects')
      if (!terrain) fail(`${level.tilemap}: Tile-Layer "terrain" fehlt`)
      if (!objectLayer) fail(`${level.tilemap}: Objekt-Layer "objects" fehlt`)
      const objects = objectLayer?.objects ?? []
      if (!objects.some((o) => o.type === 'spawn')) fail(`${level.tilemap}: kein "spawn"-Objekt`)
      const hasExit = objects.some((o) => o.type === 'door-exit' || o.type === 'stamp-exit' || o.type === 'finale-sprint')
      if (!hasExit) fail(`${level.tilemap}: kein Levelausgang (door-exit / stamp-exit / finale-sprint)`)
      for (const obj of objects) {
        const type = obj.type ?? ''
        if (type && !isKnownMechanicType(type)) {
          fail(`${level.tilemap}: unbekannter Objekt-Typ "${type}" bei x=${obj.x}, y=${obj.y}`)
        }
      }
      ok(`${rel} + ${level.tilemap}`)
    } catch (e) {
      fail(`${level.tilemap}: kein gültiges Tiled-JSON (${e instanceof Error ? e.message : e})`)
    }
  }
}

console.log('')
if (errors > 0) {
  console.error(`${errors} Problem(e) gefunden.`)
  process.exit(1)
}
console.log('Alle Konfigurationen sind gültig.')
