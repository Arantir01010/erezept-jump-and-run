/**
 * CORE-SCHUTZ — Integritätsprüfung des Spielkerns.
 *
 * Level bauen heißt: NUR design/levels/**, design/playlist.json und
 * public/config/themes.json anfassen. Alles andere ist Engine/Werkzeug und
 * in tools/core-manifest.json mit SHA-256-Hashes festgeschrieben.
 *
 *   npm run guard         → prüfen (auch Teil von npm run validate)
 *   npm run guard:update  → Manifest neu schreiben (NUR für Menschen, nach
 *                           bewussten Engine-Änderungen)
 *
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen.
 */
import { createHash } from 'node:crypto'
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { ROOT } from './lib/pipeline'

const MANIFEST_FILE = join(ROOT, 'tools', 'core-manifest.json')

/** Geschützte Bereiche: Verzeichnisse (rekursiv) und Einzeldateien. */
const PROTECTED_DIRS = ['src', 'tools', 'docs', '.github', join('design', 'levels', '_vorlage')]
const PROTECTED_FILES = [
  'index.html',
  '.gitignore',
  '.gitattributes',
  'eslint.config.js',
  'vite.config.ts',
  'tsconfig.json',
  'package.json',
  'package-lock.json',
  'start-spiel.bat',
  'start-messe.bat',
  'level-build.bat',
  'CLAUDE.md',
  'AGENTS.md',
  join('design', 'LEVELBAU.md'),
  join('public', 'config', 'input-bindings.json'),
]
/** Ausnahmen (das Manifest selbst kann sich nicht enthalten). */
const EXCLUDED = new Set(['tools/core-manifest.json'])

function walk(dir: string, out: string[]): void {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name === '.git') continue
      walk(full, out)
    } else if (entry.isFile()) {
      out.push(full)
    }
  }
}

function collectProtectedFiles(): string[] {
  const files: string[] = []
  for (const dir of PROTECTED_DIRS) {
    const full = join(ROOT, dir)
    if (existsSync(full)) walk(full, files)
  }
  for (const file of PROTECTED_FILES) {
    const full = join(ROOT, file)
    if (existsSync(full) && statSync(full).isFile()) files.push(full)
  }
  return files
    .map((f) => relative(ROOT, f).split('\\').join('/'))
    .filter((f) => !EXCLUDED.has(f))
    .sort()
}

function hashFile(relPath: string): string {
  return createHash('sha256').update(readFileSync(join(ROOT, relPath))).digest('hex')
}

export interface GuardResult {
  ok: boolean
  problems: string[]
}

export function checkCore(): GuardResult {
  if (!existsSync(MANIFEST_FILE)) {
    return { ok: false, problems: ['tools/core-manifest.json fehlt — einmal "npm run guard:update" ausführen (Mensch).'] }
  }
  const manifest = JSON.parse(readFileSync(MANIFEST_FILE, 'utf-8')) as { files: Record<string, string> }
  const current = collectProtectedFiles()
  const problems: string[] = []

  for (const file of current) {
    const expected = manifest.files[file]
    if (!expected) {
      problems.push(`NEUE Datei im geschützten Bereich: ${file} — Engine-Bereiche sind für den Levelbau tabu.`)
    } else if (hashFile(file) !== expected) {
      problems.push(`VERÄNDERT: ${file} — geschützte Kern-Datei wurde angefasst.`)
    }
  }
  for (const file of Object.keys(manifest.files)) {
    if (!current.includes(file)) problems.push(`GELÖSCHT/FEHLT: ${file} — geschützte Kern-Datei ist weg.`)
  }
  return { ok: problems.length === 0, problems }
}

export function updateManifest(): number {
  const files: Record<string, string> = {}
  for (const file of collectProtectedFiles()) files[file] = hashFile(file)
  const manifest = {
    _hinweis:
      'Integritäts-Manifest des Spielkerns. Prüfen: npm run guard · Neu schreiben (nur Menschen, nach bewussten Engine-Änderungen): npm run guard:update',
    files,
  }
  writeFileSync(MANIFEST_FILE, JSON.stringify(manifest, null, 2) + '\n')
  return Object.keys(files).length
}

// ------------------------------------------------------------------ CLI
const isMain = process.argv[1]?.replace(/\\/g, '/').endsWith('check-core.ts')
if (isMain) {
  if (process.argv.includes('--update')) {
    const n = updateManifest()
    console.log(`✓ tools/core-manifest.json neu geschrieben (${n} geschützte Dateien).`)
  } else {
    const result = checkCore()
    if (result.ok) {
      console.log('✓ Spielkern unverändert — alle geschützten Dateien intakt.')
    } else {
      for (const p of result.problems) console.error(`✗ ${p}`)
      console.error(
        '\nFalls das eine BEWUSSTE Engine-Änderung durch einen Menschen war: npm run guard:update.' +
          '\nFalls nicht: Änderung rückgängig machen — Levelbau braucht nur design/levels/**, design/playlist.json, public/config/themes.json.',
      )
      process.exit(1)
    }
  }
}
