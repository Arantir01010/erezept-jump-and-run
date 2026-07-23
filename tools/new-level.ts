/**
 * NEUES LEVEL ANLEGEN — kopiert die Vorlage und trägt das Level in die Playlist ein.
 *
 * Aufruf: npm run neues-level -- 04-fachdienst
 *
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */
import { cpSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { DESIGN } from './lib/pipeline'
import { LEVEL_ID_PATTERN } from './lib/catalog'

const id = process.argv[2]

if (!id || !LEVEL_ID_PATTERN.test(id)) {
  console.error('Aufruf: npm run neues-level -- <id>')
  console.error('Die ID folgt dem Muster NN-kleinbuchstaben, z. B.: npm run neues-level -- 04-fachdienst')
  process.exit(1)
}

const template = join(DESIGN, 'levels', '_vorlage')
const target = join(DESIGN, 'levels', id)
const playlistFile = join(DESIGN, 'playlist.json')

if (!existsSync(template)) {
  console.error('design/levels/_vorlage/ fehlt — Projekt unvollständig.')
  process.exit(1)
}
if (existsSync(target)) {
  console.error(`design/levels/${id}/ existiert bereits — andere ID wählen oder Ordner zuerst umbenennen.`)
  process.exit(1)
}

cpSync(template, target, { recursive: true })

const playlist = JSON.parse(readFileSync(playlistFile, 'utf-8')) as string[]
if (!playlist.includes(id)) {
  playlist.push(id)
  writeFileSync(playlistFile, JSON.stringify(playlist, null, 2) + '\n')
}

console.log(`✓ design/levels/${id}/ angelegt (aus der Vorlage) und in design/playlist.json eingetragen.`)
console.log('\nNächste Schritte:')
console.log(`  1. design/levels/${id}/layout.txt zeichnen (Gelände + Marker)`)
console.log(`  2. design/levels/${id}/level.json ausfüllen (Texte, Objekte, Parameter)`)
console.log('  3. npm run build:levels   → baut und prüft ALLES (Fehler genau lesen!)')
console.log('  4. npm run validate       → Komplett-Prüfung inkl. Kern-Schutz')
console.log('\nAlle Regeln, Zeichen und Objekte: design/LEVELBAU.md')
