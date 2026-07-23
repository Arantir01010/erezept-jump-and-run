/**
 * Level-Compiler des Baukastens: liest levels-src/<id>.level.json (Metadaten +
 * ASCII-Karte), prüft SPIELBARKEIT und erzeugt daraus die Runtime-Dateien:
 *
 *   levels-src/04-xyz.level.json ──▶ public/config/levels/04-xyz.json
 *                                ──▶ public/assets/tilemaps/04-xyz.tmj
 *
 * Aufruf: npm run levels            (alle Quellen kompilieren)
 *         npm run levels -- 04-xyz  (nur eine)
 *
 * Die erzeugten Dateien sind WEGWERF-ARTEFAKTE — niemals von Hand bearbeiten.
 * Alle Regeln für Level-Autoren (Mensch wie KI): levels-src/ANLEITUNG.md.
 */
import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { LevelSchema, formatZodError } from '../src/level/schema'
import { PLAYER_TUNING } from '../src/player/PlayerConfig'
import {
  LevelSourceSchema,
  type LevelSource,
  MAP_HEIGHT,
  MAP_MIN_WIDTH,
  MAP_MAX_WIDTH,
  ALL_CHARS,
} from './levelSourceSchema'

const TILE = 16
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const SRC_DIR = join(ROOT, 'levels-src')
const MAP_OUT = join(ROOT, 'public', 'assets', 'tilemaps')
const CFG_OUT = join(ROOT, 'public', 'config', 'levels')

// Aus dem Spielgefühl abgeleitete Physik-Grenzen (siehe PLAYER_TUNING):
// Sprunghöhe v²/2g ≈ 56 px → 3 Kacheln; Sprungweite ≈ 87 px → sicher 4 Kacheln.
const JUMP_UP_TILES = Math.floor((PLAYER_TUNING.jumpVelocity ** 2) / (2 * PLAYER_TUNING.gravityY) / TILE) // 3
const JUMP_GAP_TILES = 4

const SOLID = new Set(['#', '=', 'G', 'A', '~'])
const TERRAIN_GID: Record<string, number> = {
  '#': 1, // Boden (Oberkante wird automatisch zu GID 2)
  '=': 3, // Plattform
  G: 4, // Gold-Pad
  A: 5, // Akzentblock
  '~': 6, // Glas (solide Tunnelwand)
  '-': 7, // dunkle Füllung (solide)
}
// '-' ist solide Füllung, '|' ist Deko-Strebe (GID 8, NICHT solide)
SOLID.add('-')

interface Cell {
  ch: string
  col: number
  row: number
}

export interface CompileResult {
  id: string
  config: Record<string, unknown>
  tmj: Record<string, unknown>
  warnings: string[]
}

class LevelFehler extends Error {}

const fail = (msg: string): never => {
  throw new LevelFehler(msg)
}

const pos = (c: { col: number; row: number }): string => `Spalte ${c.col + 1}, Zeile ${c.row + 1}`

// ------------------------------------------------------------------ Parsen

function parseMap(src: LevelSource): { grid: string[][]; width: number } {
  const width = src.map[0].length
  if (width < MAP_MIN_WIDTH || width > MAP_MAX_WIDTH) {
    fail(`Kartenbreite ${width} — erlaubt sind ${MAP_MIN_WIDTH} bis ${MAP_MAX_WIDTH} Kacheln`)
  }
  const grid: string[][] = []
  src.map.forEach((line, row) => {
    if (line.length !== width) {
      fail(`Zeile ${row + 1} hat ${line.length} Zeichen, Zeile 1 hat ${width} — alle Zeilen müssen gleich lang sein`)
    }
    const cells = [...line]
    cells.forEach((ch, col) => {
      if (!(ALL_CHARS as readonly string[]).includes(ch)) {
        fail(`Unbekanntes Zeichen "${ch}" bei ${pos({ col, row })} — erlaubte Zeichen: ${ALL_CHARS.join(' ')}`)
      }
    })
    grid.push(cells)
  })
  return { grid, width }
}

const isSolid = (grid: string[][], col: number, row: number): boolean => {
  if (row < 0 || row >= grid.length || col < 0 || col >= grid[0].length) return false
  return SOLID.has(grid[row][col])
}

/** Erste solide Zeile unterhalb (inklusive row) — oder -1. */
function groundBelow(grid: string[][], col: number, row: number): number {
  for (let r = row; r < grid.length; r++) if (isSolid(grid, col, r)) return r
  return -1
}

function collect(grid: string[][], chars: string[]): Cell[] {
  const out: Cell[] = []
  grid.forEach((line, row) =>
    line.forEach((ch, col) => {
      if (chars.includes(ch)) out.push({ ch, col, row })
    }),
  )
  return out
}

// ------------------------------------------------------------------ Objekte

interface TiledObj {
  id: number
  name: string
  type: string
  class: string
  x: number
  y: number
  width: number
  height: number
  rotation: 0
  visible: true
  point: false
  properties: { name: string; type: string; value: string | number | boolean }[]
}

function makeObj(
  nextId: () => number,
  type: string,
  x: number,
  y: number,
  w: number,
  h: number,
  name = '',
  props: Record<string, string | number | boolean> = {},
): TiledObj {
  const round = (v: number): number => Math.round(v * 100) / 100
  return {
    id: nextId(),
    name,
    type,
    class: type,
    x: round(x),
    y: round(y),
    width: round(w),
    height: round(h),
    rotation: 0,
    visible: true,
    point: false,
    properties: Object.entries(props).map(([n, value]) => ({
      name: n,
      type: typeof value === 'number' ? 'float' : typeof value === 'boolean' ? 'bool' : 'string',
      value,
    })),
  }
}

// ------------------------------------------------------------------ Spielbarkeit (BFS)

/**
 * Vereinfachte Erreichbarkeits-Simulation: „stehbare" Kacheln (Luft mit Boden
 * darunter) bilden Knoten; Kanten = gehen, springen (≤ JUMP_UP_TILES hoch,
 * ≤ JUMP_GAP_TILES weit) und beliebig tief fallen. Geschlossene Tore blockieren,
 * bis die Zone ihrer Öffner-Mechanik erreichbar ist.
 */
function checkReachability(
  grid: string[][],
  spawn: Cell,
  targets: { name: string; col: number; row: number; required: boolean }[],
  gates: { name: string; col: number; rows: [number, number]; openerCol: number; openerRow: number }[],
  bits: Cell[],
): { reachableBits: number; errors: string[] } {
  const H = grid.length
  const W = grid[0].length
  const blockedByGate = (col: number, row: number, closed: Set<string>): boolean =>
    gates.some((g) => closed.has(g.name) && g.col === col && row >= g.rows[0] && row <= g.rows[1])

  const key = (c: number, r: number): number => r * W + c

  const runBfs = (closed: Set<string>): Set<number> => {
    const seen = new Set<number>()
    const queue: [number, number][] = []
    // Startpunkt: auf den Boden fallen lassen
    const startRow = (groundBelow(grid, spawn.col, spawn.row) === -1 ? spawn.row : groundBelow(grid, spawn.col, spawn.row) - 1)
    queue.push([spawn.col, startRow])
    seen.add(key(spawn.col, startRow))
    while (queue.length > 0) {
      const [c, r] = queue.shift() as [number, number]
      // Zielkandidaten: alle Kacheln im Sprungfenster
      for (let dc = -JUMP_GAP_TILES; dc <= JUMP_GAP_TILES; dc++) {
        for (let dr = -JUMP_UP_TILES; dr <= H; dr++) {
          const nc = c + dc
          const nr = r + dr
          if (nc < 0 || nc >= W || nr < 0 || nr >= H) continue
          if (seen.has(key(nc, nr))) continue
          if (blockedByGate(nc, nr, closed)) continue
          if (isSolid(grid, nc, nr)) continue
          // Stehbar NUR mit solidem Boden darunter — der Kartenboden zählt nicht:
          // bodenlose Spalten bedeuten im Spiel „durchfallen + Respawn", nie Stand.
          const isStand = isSolid(grid, nc, nr + 1)
          if (!isStand) continue
          // Weg grob prüfen: kein Tor zwischen c und nc auf Zielhöhe
          let gateBlocked = false
          const from = Math.min(c, nc)
          const to = Math.max(c, nc)
          for (let cc = from; cc <= to && !gateBlocked; cc++) {
            if (blockedByGate(cc, Math.min(r, nr), closed) || blockedByGate(cc, Math.max(r, nr), closed)) gateBlocked = true
          }
          if (gateBlocked) continue
          seen.add(key(nc, nr))
          queue.push([nc, nr])
        }
      }
    }
    return seen
  }

  // Tore nacheinander öffnen, solange ihre Öffner erreichbar werden
  const closed = new Set(gates.map((g) => g.name))
  let reached = runBfs(closed)
  let progress = true
  while (progress) {
    progress = false
    for (const g of [...gates]) {
      if (!closed.has(g.name)) continue
      const openerGround = groundBelow(grid, g.openerCol, g.openerRow)
      const openerStand = openerGround === -1 ? g.openerRow : openerGround - 1
      if (reached.has(g.openerRow * W + g.openerCol) || reached.has(openerStand * W + g.openerCol)) {
        closed.delete(g.name)
        reached = runBfs(closed)
        progress = true
      }
    }
  }

  const errors: string[] = []
  const cellReachable = (col: number, row: number): boolean => {
    const ground = groundBelow(grid, col, row)
    const stand = ground === -1 ? row : ground - 1
    return reached.has(stand * W + col) || reached.has(row * W + col)
  }
  for (const t of targets) {
    if (t.required && !cellReachable(t.col, t.row)) {
      errors.push(`"${t.name}" bei ${pos(t)} ist vom Spawn aus NICHT erreichbar (Sprunghöhe ${JUMP_UP_TILES}, Sprungweite ${JUMP_GAP_TILES} Kacheln)`)
    }
  }
  for (const g of gates) {
    if (closed.has(g.name)) {
      errors.push(`Tor "${g.name}" (Spalte ${g.col + 1}) bleibt für immer zu — seine Öffner-Mechanik ist unerreichbar`)
    }
  }
  // Bits werden auch IM SPRUNG eingesammelt: erreichbar, wenn eine stehbare
  // Kachel im Sprungfenster liegt (nicht nur direkt darunter).
  const touchable = (col: number, row: number): boolean => {
    for (let dc = -JUMP_GAP_TILES; dc <= JUMP_GAP_TILES; dc++) {
      for (let dr = -1; dr <= JUMP_UP_TILES + 1; dr++) {
        if (reached.has((row + dr) * W + (col + dc))) return true
      }
    }
    return false
  }
  const reachableBits = bits.filter((b) => cellReachable(b.col, b.row) || touchable(b.col, b.row)).length
  return { reachableBits, errors }
}

// ------------------------------------------------------------------ Kompilieren

export function compileLevelSource(raw: unknown, fileLabel: string): CompileResult {
  const parsed = LevelSourceSchema.safeParse(raw)
  if (!parsed.success) fail(formatZodError(fileLabel, parsed.error))
  const src = (parsed as { data: LevelSource }).data
  const warnings: string[] = []

  const { grid, width } = parseMap(src)
  const height = MAP_HEIGHT

  // --- Terrain-GIDs (mit automatischer Boden-Oberkante) ---
  const terrain: number[][] = grid.map((line, row) =>
    line.map((ch, col) => {
      if (ch === '|') return 8
      const gid = TERRAIN_GID[ch]
      if (!gid) return 0
      if (ch === '#' && !isSolid(grid, col, row - 1)) return 2 // Oberkante
      return gid
    }),
  )

  // --- Marker einsammeln ---
  const spawns = collect(grid, ['P'])
  if (spawns.length !== 1) fail(`Genau EIN Spawn "P" nötig — gefunden: ${spawns.length}`)
  const spawn = spawns[0]
  const exitsS = collect(grid, ['S'])
  const exitsD = collect(grid, ['D'])
  if (exitsS.length + exitsD.length !== 1) {
    fail(`Genau EIN Ausgang nötig ("S" Stempel ODER "D" Tür) — gefunden: ${exitsS.length + exitsD.length}`)
  }
  const bits = collect(grid, ['b'])
  const gatesRaw = collect(grid, ['1', '2', '3', '4'])
  const openersRaw = collect(grid, ['t', 'p', 'Q'])
  const timingGates = collect(grid, ['t'])
  if (timingGates.length > 1) fail('Höchstens EIN Timing-Gate "t" pro Level (klare Regel für klare Level)')
  if (collect(grid, ['Q']).length > 1) fail('Höchstens EINE Krypto-Dusche "Q" pro Level')

  // Marker müssen Boden unter sich haben
  for (const m of [spawn, ...exitsS, ...exitsD, ...openersRaw, ...collect(grid, ['c', 'K'])]) {
    if (groundBelow(grid, m.col, m.row) === -1) {
      fail(`"${m.ch}" bei ${pos(m)} schwebt — darunter muss (irgendwo) Boden sein`)
    }
  }

  // --- Tore: vertikale Läufe gleicher Ziffer zusammenfassen ---
  const gateRuns = new Map<string, { col: number; top: number; bottom: number }>()
  for (const g of gatesRaw) {
    const existing = gateRuns.get(g.ch)
    if (!existing) gateRuns.set(g.ch, { col: g.col, top: g.row, bottom: g.row })
    else {
      if (existing.col !== g.col) fail(`Tor "${g.ch}" kommt in mehreren Spalten vor — eine Ziffer = ein Tor (senkrechte Linie malen)`)
      existing.top = Math.min(existing.top, g.row)
      existing.bottom = Math.max(existing.bottom, g.row)
    }
  }

  // --- Öffner-Mechanik ↔ Tor verknüpfen: nächster freier Öffner LINKS vom Tor ---
  const openerFor = new Map<string, Cell>() // torName -> Öffner
  const usedOpeners = new Set<Cell>()
  const sortedGates = [...gateRuns.entries()].sort((a, b) => a[1].col - b[1].col)
  for (const [digit, run] of sortedGates) {
    const candidates = openersRaw
      .filter((o) => o.col < run.col && !usedOpeners.has(o))
      .sort((a, b) => b.col - a.col)
    if (candidates.length === 0) {
      fail(`Tor "${digit}" (Spalte ${run.col + 1}) hat keine freie Öffner-Mechanik links davon (t, p oder Q)`)
    }
    openerFor.set(`tor-${digit}`, candidates[0])
    usedOpeners.add(candidates[0])
  }
  for (const o of openersRaw) {
    if (!usedOpeners.has(o) && o.ch !== 't') {
      // Podeste/Duschen ohne Tor sind erlaubt (reine Scan-Momente), nur Hinweis
      warnings.push(`Öffner "${o.ch}" bei ${pos(o)} ist mit keinem Tor verknüpft`)
    }
  }

  // --- Spielbarkeit prüfen ---
  const exit = exitsS[0] ?? exitsD[0]
  const gateInfos = sortedGates.map(([digit, run]) => {
    const opener = openerFor.get(`tor-${digit}`) as Cell
    return { name: `tor-${digit}`, col: run.col, rows: [run.top, run.bottom] as [number, number], openerCol: opener.col, openerRow: opener.row }
  })
  const targets = [
    { name: exitsS.length ? 'Stempel-Ausgang' : 'Tür-Ausgang', col: exit.col, row: exit.row, required: true },
    ...openersRaw.map((o) => ({ name: `Öffner ${o.ch}`, col: o.col, row: o.row, required: usedOpeners.has(o) })),
  ]
  const reach = checkReachability(grid, spawn, targets, gateInfos, bits)
  if (reach.errors.length > 0) fail(reach.errors.join('\n'))

  if (src.collectibleCountRequired > 0) {
    const margin = reach.reachableBits - src.collectibleCountRequired
    if (margin < 2) {
      fail(
        `Sammelziel zu knapp: ${src.collectibleCountRequired} Bits verlangt, aber nur ${reach.reachableBits} erreichbar — es müssen mindestens 2 MEHR erreichbar sein als verlangt (Messe-Marge)`,
      )
    }
  }
  const infoSigns = collect(grid, ['i'])
  if (infoSigns.length !== src.infoSchilder.length) {
    fail(`${infoSigns.length}× "i" in der Karte, aber ${src.infoSchilder.length} Einträge in "infoSchilder" — beides muss zusammenpassen`)
  }

  // --- Tiled-Objekte bauen ---
  let idCounter = 0
  const nextId = (): number => ++idCounter
  const objects: TiledObj[] = []
  const T = TILE

  // Spawn
  objects.push(makeObj(nextId, 'spawn', spawn.col * T, spawn.row * T, T, T))

  // Tore (zuerst benannt — die Szene spawnt sie vor allen anderen)
  for (const [digit, run] of sortedGates) {
    objects.push(makeObj(nextId, 'gate', run.col * T, run.top * T, 8, (run.bottom - run.top + 1) * T, `tor-${digit}`))
  }

  const bottomAligned = (c: Cell, w: number, h: number, type: string, name = '', props: Record<string, string | number | boolean> = {}): void => {
    const groundRow = groundBelow(grid, c.col, c.row)
    const bottomY = (groundRow === -1 ? c.row + 1 : groundRow) * T
    objects.push(makeObj(nextId, type, c.col * T + T / 2 - w / 2, bottomY - h, w, h, name, props))
  }

  // Öffner-Zonen mit automatischer Tor-Verknüpfung
  const openerProps = (o: Cell): Record<string, string | number | boolean> => {
    for (const [torName, opener] of openerFor.entries()) if (opener === o) return { gate: torName }
    return {}
  }
  for (const o of openersRaw) {
    if (o.ch === 't') bottomAligned(o, 8 * T, 5 * T, 'timing-gate', '', openerProps(o))
    if (o.ch === 'Q') bottomAligned(o, 5 * T, 6 * T, 'krypto-dusche', '', openerProps(o))
    if (o.ch === 'p') {
      // Podest: dünne Plattform auf Höhe der Marker-Kachel
      objects.push(makeObj(nextId, 'stillstand-podest', o.col * T + T / 2 - 24, o.row * T + T * 0.6, 48, 6.4, '', openerProps(o)))
    }
  }

  // Ausgänge
  for (const s of exitsS) bottomAligned(s, 6 * T, 6 * T, 'stamp-exit')
  for (const d of exitsD) bottomAligned(d, 24, 48, 'door-exit')

  // Einfache Objekte
  for (const b of bits) objects.push(makeObj(nextId, 'collectible', b.col * T + 2, b.row * T + 2, 12, 12))
  for (const c of collect(grid, ['c'])) bottomAligned(c, T, 24, 'checkpoint')
  for (const k of collect(grid, ['K'])) {
    objects.push(makeObj(nextId, 'deny-enemy', k.col * T + T / 2 - 11.2, k.row * T + T / 2 - 3.2, 22.4, 6.4, '', { fromRight: true, reach: 42 }))
  }
  for (const h of collect(grid, ['H'])) objects.push(makeObj(nextId, 'hazard', h.col * T, h.row * T, T, T))
  for (const m of collect(grid, ['M'])) objects.push(makeObj(nextId, 'moving-platform', m.col * T, m.row * T + T * 0.6, 32, 6))
  for (const x of collect(grid, ['x'])) {
    objects.push(makeObj(nextId, 'deco', x.col * T - 4, x.row * T - 4, 24, 24, '', { sprite: 'krake-0', anim: 'krake-swim', drift: 4 }))
  }
  infoSigns.forEach((sign, i) => {
    const text = src.infoSchilder[i]
    const props: Record<string, string> = { textDe: text.de }
    if (text.en) props.textEn = text.en
    bottomAligned(sign, 40, 64, 'info-sign', '', props)
  })

  // --- Runtime-Config bauen ---
  const mechanics: Record<string, Record<string, unknown>> = { ...src.mechanics }
  if (src.cameraMode === 'tube' && !mechanics['tube-scroll']) mechanics['tube-scroll'] = { speed: 55 }

  const config = {
    _generiert: `AUS levels-src/${src.id}.level.json — NICHT von Hand bearbeiten (npm run levels)`,
    id: src.id,
    station: src.station,
    siegelIcon: src.siegelIcon,
    cityAnchor: src.cityAnchor,
    cameraMode: src.cameraMode,
    theme: src.theme,
    enemySkin: src.enemySkin,
    tilemap: `assets/tilemaps/${src.id}.tmj`,
    collectible: {
      type: 'datenbit',
      countRequired: src.collectibleCountRequired,
      label: { de: 'Datenbits', en: 'Data bits' },
    },
    mechanics,
    parTimeSeconds: src.parTimeSeconds,
  }
  // Selbst-Check gegen das Runtime-Schema — der Compiler darf nie Ungültiges liefern
  const check = LevelSchema.safeParse(config)
  if (!check.success) fail('INTERNER FEHLER — generierte Config ungültig:\n' + formatZodError(src.id, check.error))

  const tmj = {
    compressionlevel: -1,
    type: 'map',
    version: '1.10',
    tiledversion: '1.10.2',
    orientation: 'orthogonal',
    renderorder: 'right-down',
    infinite: false,
    width,
    height,
    tilewidth: T,
    tileheight: T,
    nextlayerid: 3,
    nextobjectid: idCounter + 1,
    properties: [
      { name: '_generiert', type: 'string', value: `AUS levels-src/${src.id}.level.json — NICHT von Hand bearbeiten` },
    ],
    tilesets: [
      {
        columns: 8,
        firstgid: 1,
        image: '../tilesets/ti-tiles.png',
        imageheight: 16,
        imagewidth: 128,
        margin: 0,
        name: 'ti-tiles',
        spacing: 0,
        tilecount: 8,
        tileheight: T,
        tilewidth: T,
      },
    ],
    layers: [
      { id: 1, type: 'tilelayer', name: 'terrain', width, height, opacity: 1, visible: true, x: 0, y: 0, data: terrain.flat() },
      { id: 2, type: 'objectgroup', name: 'objects', draworder: 'topdown', opacity: 1, visible: true, x: 0, y: 0, objects },
    ],
  }

  if (reach.reachableBits < bits.length) {
    warnings.push(`${bits.length - reach.reachableBits} von ${bits.length} Datenbits sind evtl. schwer erreichbar (Simulation)`)
  }
  return { id: src.id, config, tmj, warnings }
}

// ------------------------------------------------------------------ CLI

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]
if (isMain) {
  const only = process.argv[2]
  if (!existsSync(SRC_DIR)) {
    console.error('levels-src/ fehlt — nichts zu tun.')
    process.exit(1)
  }
  const files = readdirSync(SRC_DIR)
    .filter((f) => f.endsWith('.level.json') && !f.startsWith('_'))
    .filter((f) => !only || f === `${only}.level.json`)
  if (files.length === 0) {
    console.error(only ? `levels-src/${only}.level.json nicht gefunden.` : 'Keine .level.json-Quellen in levels-src/.')
    process.exit(1)
  }
  let failed = 0
  for (const file of files) {
    try {
      const raw = JSON.parse(readFileSync(join(SRC_DIR, file), 'utf-8')) as unknown
      const result = compileLevelSource(raw, `levels-src/${file}`)
      mkdirSync(MAP_OUT, { recursive: true })
      mkdirSync(CFG_OUT, { recursive: true })
      writeFileSync(join(MAP_OUT, `${result.id}.tmj`), JSON.stringify(result.tmj))
      writeFileSync(join(CFG_OUT, `${result.id}.json`), JSON.stringify(result.config, null, 2) + '\n')
      console.log(`✓ ${file} → ${result.id}.json + ${result.id}.tmj`)
      for (const w of result.warnings) console.log(`  ⚠ ${w}`)
    } catch (e) {
      failed += 1
      console.error(`✗ ${file}:\n${e instanceof Error ? e.message : e}\n`)
    }
  }
  if (failed > 0) {
    console.error(`${failed} Level fehlerhaft — nichts kaputt: fehlerhafte Level wurden NICHT geschrieben.`)
    process.exit(1)
  }
  console.log('\nAlle Level kompiliert. Danach: npm run validate — und neue IDs in game-config.json → levelOrder eintragen.')
}
