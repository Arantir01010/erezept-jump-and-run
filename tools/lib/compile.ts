/**
 * LEVEL-COMPILER — übersetzt eine Level-Quelle (design/levels/<id>/) in die
 * Spieldateien (public/config/levels/<id>.json + public/assets/tilemaps/<id>.tmj)
 * und prüft dabei ALLES, was ein Level kaputt machen könnte:
 *
 *   Struktur   → Raster rechteckig, genau 1 Spawn, mindestens 1 Ausgang, …
 *   Vokabular  → nur bekannte Zeichen, Objekt-Typen, Parameter (strikt, mit
 *                „meintest du …?"-Vorschlägen)
 *   Softlocks  → jedes Tor hat einen Öffner, jeder Öffner ein existierendes Tor
 *   Spielbarkeit → Erreichbarkeits-Simulation mit den ECHTEN Physikwerten aus
 *                src/player/PlayerConfig.ts (Sprunghöhe/-weite, BFS vom Spawn)
 *
 * Fehler (errors) blockieren den Build. Warnungen (warnings) sind Hinweise.
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */
import { formatZodError } from '../../src/level/schema'
import { PLAYER_TUNING } from '../../src/player/PlayerConfig'
import {
  TILE,
  GRID_HEIGHT,
  GRID_WIDTH_MIN,
  GRID_WIDTH_MAX,
  GID,
  TILE_CHARS,
  MARKER_CHARS,
  OBJECT_TYPES,
  FORBIDDEN_TYPES,
  MECHANICS_SCHEMAS,
  KNOWN_SEAL_ICONS,
  KNOWN_DECO_SPRITES,
  KNOWN_DECO_ANIMS,
  KNOWN_ENEMY_SKINS,
  DesignLevelSchema,
  LEVEL_ID_PATTERN,
  suggest,
  type DesignLevel,
} from './catalog'

// ------------------------------------------------------------------ Typen

export interface CompiledLevel {
  id: string
  errors: string[]
  warnings: string[]
  /** Tiled-JSON (.tmj) — nur gesetzt, wenn keine Fehler. */
  tmj?: Record<string, unknown>
  /** Laufzeit-Level-JSON — nur gesetzt, wenn keine Fehler. */
  levelJson?: Record<string, unknown>
}

interface Marker {
  tx: number
  ty: number
  type: string
}

interface ParsedObject {
  type: string
  name?: string
  tx: number
  ty: number
  tw: number
  th: number
  /** Zusätzliche Props (gate, steps, …) in Autoren-Reihenfolge. */
  props: Record<string, string | number | boolean>
}

// ------------------------------------------------------- Sprungphysik-Grenzen

const G = PLAYER_TUNING.gravityY
const V = PLAYER_TUNING.jumpVelocity
/** Maximale Sprunghöhe in Kacheln (v²/2g, abgerundet) — aktuell 3. */
export const MAX_RISE_TILES = Math.floor(V ** 2 / (2 * G) / TILE)
/**
 * Maximale horizontale Distanz (Kachelmitte → Kachelmitte) je Steighöhe.
 * Aus der Flugbahn hergeleitet (inkl. Coyote-Time und Kantentoleranz),
 * bewusst eine Spur strenger als das physikalische Maximum.
 */
const MAX_DX_FOR_RISE: Record<number, number> = { 0: 6, 1: 5, 2: 5, 3: 5 }
const MAX_DX_DROP = 7

// ------------------------------------------------------------------ Layout

function parseLayout(
  text: string,
  errors: string[],
): { grid: string[][]; width: number; markers: Marker[] } {
  const rawLines = text.replace(/\r/g, '').split('\n')
  // Leere Zeilen am Ende sind okay (Datei endet mit Newline)
  while (rawLines.length > 0 && rawLines[rawLines.length - 1].trim() === '') rawLines.pop()

  if (rawLines.length !== GRID_HEIGHT) {
    errors.push(
      `layout.txt: genau ${GRID_HEIGHT} Zeilen erwartet, gefunden: ${rawLines.length}. ` +
        `(Jede Zeile = eine Kachelreihe, das Spielfeld ist immer ${GRID_HEIGHT} Kacheln hoch.)`,
    )
  }

  const width = Math.max(...rawLines.map((l) => l.length), 0)
  if (width < GRID_WIDTH_MIN || width > GRID_WIDTH_MAX) {
    errors.push(
      `layout.txt: Breite ${width} Kacheln — erlaubt sind ${GRID_WIDTH_MIN} bis ${GRID_WIDTH_MAX}.`,
    )
  }

  const grid: string[][] = []
  const markers: Marker[] = []
  const badChars = new Map<string, string>()

  rawLines.forEach((line, y) => {
    const row: string[] = []
    for (let x = 0; x < width; x++) {
      const ch = x < line.length ? line[x] : '.'
      if (MARKER_CHARS[ch]) {
        markers.push({ tx: x, ty: y, type: MARKER_CHARS[ch] })
        row.push('.')
      } else if (TILE_CHARS[ch]) {
        row.push(ch === ' ' ? '.' : ch)
      } else {
        if (!badChars.has(ch)) {
          const known = [...Object.keys(TILE_CHARS), ...Object.keys(MARKER_CHARS)].filter((c) => c !== ' ')
          badChars.set(ch, `layout.txt Zeile ${y + 1}, Spalte ${x + 1}: unbekanntes Zeichen "${ch}". Erlaubt: ${known.join(' ')}`)
        }
        row.push('.')
      }
    }
    grid.push(row)
  })
  errors.push(...badChars.values())

  return { grid, width, markers }
}

/** GID-Raster aus dem Zeichen-Raster. `#` bekommt automatisch eine Oberkante. */
function toGidGrid(grid: string[][]): number[][] {
  return grid.map((row, y) =>
    row.map((ch, x) => {
      const def = TILE_CHARS[ch]
      if (ch === '#') {
        const above = y > 0 ? grid[y - 1][x] : '.'
        return above === '#' ? GID.BODEN_FUELLUNG : GID.BODEN_OBERKANTE
      }
      return def.gid
    }),
  )
}

// ------------------------------------------------------------------ Objekte

function parseObjects(design: DesignLevel, errors: string[]): ParsedObject[] {
  const result: ParsedObject[] = []
  design.objects.forEach((raw, i) => {
    const where = `objects[${i}]`
    const type = typeof raw.type === 'string' ? raw.type : ''
    if (!type) {
      errors.push(`${where}: Feld "type" fehlt.`)
      return
    }
    if (FORBIDDEN_TYPES[type]) {
      errors.push(`${where}: Typ "${type}" ist hier nicht erlaubt. ${FORBIDDEN_TYPES[type]}`)
      return
    }
    const def = OBJECT_TYPES[type]
    if (!def) {
      errors.push(
        `${where}: unbekannter Objekt-Typ "${type}"${suggest(type, Object.keys(OBJECT_TYPES))} ` +
          `(erlaubt: ${Object.keys(OBJECT_TYPES).join(', ')})`,
      )
      return
    }
    const parsed = def.schema.safeParse(raw)
    if (!parsed.success) {
      // Unbekannte Felder bekommen einen „meintest du …?"-Vorschlag
      const knownKeys = Object.keys((def.schema as { shape?: Record<string, unknown> }).shape ?? {})
      const msgs = parsed.error.issues.map((issue) => {
        if (issue.code === 'unrecognized_keys') {
          return issue.keys
            .map((k) => `Feld "${k}" gibt es bei ${type} nicht${suggest(k, knownKeys)}`)
            .join('; ')
        }
        return `${issue.path.join('.') || '(Wurzel)'}: ${issue.message}`
      })
      errors.push(`${where} (${type}): ${msgs.join('; ')}`)
      return
    }
    const data = parsed.data as Record<string, unknown>
    const { tx, ty } = data as { tx: number; ty: number }
    const tw = (data.tw as number | undefined) ?? def.defaults.tw
    const th = (data.th as number | undefined) ?? def.defaults.th
    const props: Record<string, string | number | boolean> = {}
    for (const [k, v] of Object.entries(data)) {
      if (['type', 'tx', 'ty', 'tw', 'th', 'name'].includes(k)) continue
      if (v !== undefined) props[k] = v as string | number | boolean
    }
    result.push({ type, name: data.name as string | undefined, tx, ty, tw, th, props })
  })
  return result
}

// ------------------------------------------------------ Struktur-/Logik-Checks

function checkStructure(
  design: DesignLevel,
  objects: ParsedObject[],
  markers: Marker[],
  width: number,
  themes: Record<string, unknown>,
  errors: string[],
  warnings: string[],
): void {
  const isTube = design.cameraMode === 'tube'

  // --- Spawn & Ausgang ---
  const spawns = markers.filter((m) => m.type === 'spawn')
  if (spawns.length !== 1) {
    errors.push(
      `layout.txt: genau EIN Spawn-Marker "P" nötig, gefunden: ${spawns.length}.`,
    )
  }
  const exits =
    markers.filter((m) => m.type === 'door-exit').length +
    objects.filter((o) => OBJECT_TYPES[o.type]?.isExit).length
  if (exits === 0) {
    errors.push(
      'Kein Levelausgang: Setze eine Tür "D" ins layout.txt ODER ein "stamp-exit"-Objekt ins level.json.',
    )
  } else if (exits > 1) {
    warnings.push(`${exits} Levelausgänge gefunden — erlaubt, aber ungewöhnlich.`)
  }

  // --- Objekte im Raster? ---
  for (const o of objects) {
    if (o.tx + o.tw > width || o.ty + o.th > GRID_HEIGHT || o.tx < 0 || o.ty < 0) {
      errors.push(
        `${o.type}${o.name ? ` "${o.name}"` : ''} bei tx=${o.tx}, ty=${o.ty} ragt aus dem Spielfeld (Breite ${width}, Höhe ${GRID_HEIGHT}).`,
      )
    }
  }

  // --- Tore & Öffner (Softlock-Schutz) ---
  const gates = objects.filter((o) => o.type === 'gate')
  const gateNames = new Set<string>()
  for (const g of gates) {
    if (!g.name) {
      errors.push(`gate bei tx=${g.tx}: Feld "name" ist Pflicht (der Öffner verweist darauf).`)
      continue
    }
    if (gateNames.has(g.name)) errors.push(`Tor-Name "${g.name}" ist doppelt vergeben.`)
    gateNames.add(g.name)
  }
  const referencedGates = new Set<string>()
  for (const o of objects) {
    const ref = o.props['gate']
    if (typeof ref !== 'string') continue
    referencedGates.add(ref)
    const gate = gates.find((g) => g.name === ref)
    if (!gate) {
      errors.push(
        `${o.type} bei tx=${o.tx}: verweist auf unbekanntes Tor "${ref}"${suggest(ref, [...gateNames])} ` +
          `(vorhandene Tore: ${[...gateNames].join(', ') || 'keine'}).`,
      )
      continue
    }
    // Öffner sollte VOR dem Tor kommen (in Laufrichtung links davon)
    if (o.tx >= gate.tx) {
      const msg = `${o.type} bei tx=${o.tx} liegt HINTER seinem Tor "${ref}" (tx=${gate.tx}) — der Spieler stünde vor verschlossenem Tor, ohne den Öffner erreichen zu können.`
      if (isTube) errors.push(msg + ' Im Tube-Modus gibt es kein Zurück → Fehler.')
      else warnings.push(msg)
    }
  }
  for (const g of gates) {
    if (g.name && !referencedGates.has(g.name)) {
      errors.push(
        `Tor "${g.name}" (tx=${g.tx}) hat KEINEN Öffner — es bliebe für immer zu (Softlock). ` +
          `Verknüpfe eine Mechanik (timing-gate, stillstand-podest, krypto-dusche) per "gate": "${g.name}".`,
      )
    }
  }

  // --- Sammelziel erfüllbar? ---
  const bitsPlaced = markers.filter((m) => m.type === 'collectible').length
  const required = design.collectible.countRequired
  if (required > bitsPlaced) {
    errors.push(
      `collectible.countRequired = ${required}, aber nur ${bitsPlaced} Datenbits "o" im layout.txt — das Level wäre unschaffbar.`,
    )
  } else if (required > 0) {
    const hasDamage = objects.some((o) => o.type === 'hazard' || o.type === 'deny-enemy')
    if (hasDamage && bitsPlaced < required + PLAYER_TUNING.hurtBitsLost) {
      warnings.push(
        `Nur ${bitsPlaced} Bits bei countRequired=${required} und vorhandenen Schadensquellen — ein Treffer kostet bis zu ${PLAYER_TUNING.hurtBitsLost} Bits. Empfehlung: mindestens ${required + PLAYER_TUNING.hurtBitsLost} Bits platzieren.`,
      )
    }
  }

  // --- Tube-Regeln ---
  if (isTube) {
    for (const o of objects) {
      if (o.type === 'hazard') {
        errors.push(
          `hazard bei tx=${o.tx}: In Tube-Leveln VERBOTEN — der Glastunnel ist die geschützte Zone, dort gibt es keine Schadensquellen (Markenregel).`,
        )
      }
    }
    const doorMarkers = markers.filter((m) => m.type === 'door-exit')
    for (const d of doorMarkers) {
      if (d.tx < width - 20) {
        warnings.push(
          `Tür "D" bei tx=${d.tx}: In Tube-Leveln gehört der Ausgang ans rechte Ende (letzte ~20 Kacheln), sonst schiebt der Auto-Scroll den Spieler daran vorbei.`,
        )
      }
    }
    if (!design.mechanics['tube-scroll']) {
      warnings.push('Tube-Level ohne mechanics["tube-scroll"] — Standardtempo 50 px/s greift.')
    }
  }

  // --- mechanics-Abschnitt strikt prüfen ---
  const presentTypes = new Set<string>([...objects.map((o) => o.type), ...markers.map((m) => m.type)])
  if (isTube) presentTypes.add('tube-scroll')
  for (const [mechType, params] of Object.entries(design.mechanics)) {
    const schema = MECHANICS_SCHEMAS[mechType]
    if (!schema) {
      errors.push(
        `mechanics."${mechType}": unbekannter Abschnitt${suggest(mechType, Object.keys(MECHANICS_SCHEMAS))} ` +
          `(erlaubt: ${Object.keys(MECHANICS_SCHEMAS).join(', ')}).`,
      )
      continue
    }
    const parsed = schema.safeParse(params)
    if (!parsed.success) {
      const knownKeys = Object.keys((schema as { shape?: Record<string, unknown> }).shape ?? {})
      const msgs = parsed.error.issues.map((issue) =>
        issue.code === 'unrecognized_keys'
          ? issue.keys.map((k) => `Feld "${k}" gibt es hier nicht${suggest(k, knownKeys)}`).join('; ')
          : `${issue.path.join('.') || '(Wurzel)'}: ${issue.message}`,
      )
      errors.push(`mechanics."${mechType}": ${msgs.join('; ')}`)
    }
    if (!presentTypes.has(mechType)) {
      warnings.push(`mechanics."${mechType}" ist gesetzt, aber kein solches Objekt existiert im Level (harmlos, wirkt nur nicht).`)
    }
  }

  // --- Bekannte Werte ---
  if (!themes[design.theme]) {
    errors.push(
      `Theme "${design.theme}" fehlt in public/config/themes.json${suggest(design.theme, Object.keys(themes))}. ` +
        'Entweder vorhandenes Theme wählen oder neuen Eintrag (6 Hex-Farben) in themes.json ergänzen.',
    )
  }
  if (!KNOWN_SEAL_ICONS.includes(design.siegelIcon)) {
    warnings.push(
      `siegelIcon "${design.siegelIcon}" hat keine eigene Grafik — das Spiel zeigt ersatzweise "seal-generic" (bekannt: ${KNOWN_SEAL_ICONS.join(', ')}).`,
    )
  }
  if (!KNOWN_ENEMY_SKINS.includes(design.enemySkin)) {
    warnings.push(`enemySkin "${design.enemySkin}" ist keiner der Konzept-Skins (${KNOWN_ENEMY_SKINS.join(', ')}) — rein kosmetisch, kein Problem.`)
  }
  for (const o of objects) {
    if (o.type !== 'deco') continue
    const sprite = o.props['sprite']
    if (typeof sprite === 'string' && !KNOWN_DECO_SPRITES.includes(sprite)) {
      errors.push(
        `deco bei tx=${o.tx}: Sprite "${sprite}" existiert nicht${suggest(sprite, KNOWN_DECO_SPRITES)} (vorhanden: ${KNOWN_DECO_SPRITES.join(', ')}).`,
      )
    }
    const anim = o.props['anim']
    if (typeof anim === 'string' && !KNOWN_DECO_ANIMS.includes(anim)) {
      warnings.push(`deco bei tx=${o.tx}: Animation "${anim}" unbekannt (vorhanden: ${KNOWN_DECO_ANIMS.join(', ')}) — Sprite steht dann still.`)
    }
  }
}

// ------------------------------------------------------ Erreichbarkeit (BFS)

interface ReachResult {
  /** Erreichbare Steh-Zellen als "x,y". */
  standable: Set<string>
}

function analyzeReachability(
  grid: string[][],
  width: number,
  objects: ParsedObject[],
  markers: Marker[],
  errors: string[],
  warnings: string[],
): void {
  const spawn = markers.find((m) => m.type === 'spawn')
  if (!spawn) return // ohne Spawn wurde schon ein Fehler gemeldet

  // Solidität: Gelände + Objekt-Plattformen; Tore mit gültigem Öffner gelten als offen.
  const solid: boolean[][] = grid.map((row) => row.map((ch) => TILE_CHARS[ch].solid))
  const gateNames = new Set(objects.filter((o) => o.type === 'gate' && o.name).map((o) => o.name as string))
  const openedGates = new Set<string>()
  for (const o of objects) {
    const ref = o.props['gate']
    if (typeof ref === 'string' && gateNames.has(ref)) openedGates.add(ref)
  }
  const mark = (x: number, y: number): void => {
    if (y >= 0 && y < GRID_HEIGHT && x >= 0 && x < width) solid[y][x] = true
  }
  for (const o of objects) {
    if (o.type === 'gate' && o.name && !openedGates.has(o.name)) {
      // Tor ohne Öffner (separater Fehler existiert bereits): blockiert
      for (let y = Math.floor(o.ty); y < Math.ceil(o.ty + o.th); y++) mark(Math.floor(o.tx), y)
    }
    if (OBJECT_TYPES[o.type]?.makesPlatform) {
      const row = Math.floor(o.ty)
      const from = Math.floor(o.tx)
      const to = Math.ceil(o.tx + o.tw) - 1
      const extraRange = o.type === 'moving-platform' ? Math.ceil(((o.props['range'] as number) ?? 48) / TILE) : 0
      for (let x = from; x <= to + extraRange; x++) mark(x, row)
    }
  }

  const isSolid = (x: number, y: number): boolean =>
    x < 0 || x >= width ? true : y < 0 ? false : y >= GRID_HEIGHT ? true : solid[y][x]
  const isStandable = (x: number, y: number): boolean =>
    x >= 0 && x < width && y >= 0 && y < GRID_HEIGHT && !isSolid(x, y) && isSolid(x, y + 1)
  const hasHeadroom = (x: number, y: number): boolean => !isSolid(x, y - 1)

  // Start: vom Spawn senkrecht nach unten auf die erste Steh-Zelle fallen
  let start: [number, number] | null = null
  for (let y = spawn.ty; y < GRID_HEIGHT; y++) {
    if (isStandable(spawn.tx, y)) {
      start = [spawn.tx, y]
      break
    }
    if (isSolid(spawn.tx, y)) break
  }
  if (!start) {
    errors.push(
      `Spawn "P" bei tx=${spawn.tx}, ty=${spawn.ty}: Darunter ist kein Boden — Paul würde ins Leere fallen.`,
    )
    return
  }

  const reachable = new Set<string>()
  const queue: [number, number][] = [start]
  reachable.add(start.join(','))

  const tryAdd = (x: number, y: number): void => {
    const key = `${x},${y}`
    if (!reachable.has(key) && isStandable(x, y)) {
      reachable.add(key)
      queue.push([x, y])
    }
  }

  while (queue.length > 0) {
    const [x, y] = queue.shift() as [number, number]
    // Gehen (auch geduckt)
    for (const d of [-1, 1]) tryAdd(x + d, y)
    // Von der Kante fallen
    for (const d of [-1, 1]) {
      const nx = x + d
      if (nx < 0 || nx >= width || isSolid(nx, y)) continue
      for (let ny = y + 1; ny < GRID_HEIGHT; ny++) {
        if (isSolid(nx, ny)) break
        if (isStandable(nx, ny)) {
          tryAdd(nx, ny)
          break
        }
      }
    }
    // Springen (nur mit Kopffreiheit) — inkl. Flugbahn-Check: eine hohe Wand
    // zwischen Absprung und Landung kann nicht „durchsprungen" werden.
    if (!hasHeadroom(x, y)) continue
    const pathClear = (fromX: number, toX: number, lowRow: number): boolean => {
      const [a, b] = fromX < toX ? [fromX + 1, toX - 1] : [toX + 1, fromX - 1]
      for (let c = a; c <= b; c++) {
        if (isSolid(c, lowRow) && isSolid(c, lowRow - 1) && isSolid(c, lowRow - 2)) return false
      }
      return true
    }
    for (let ty = Math.max(0, y - MAX_RISE_TILES); ty < GRID_HEIGHT; ty++) {
      const rise = y - ty
      const maxDx = rise >= 0 ? (MAX_DX_FOR_RISE[rise] ?? 0) : MAX_DX_DROP
      if (maxDx <= 0) continue
      for (let tx = Math.max(0, x - maxDx); tx <= Math.min(width - 1, x + maxDx); tx++) {
        if (tx === x && ty === y) continue
        if (isStandable(tx, ty) && hasHeadroom(tx, ty) && pathClear(x, tx, Math.min(y, ty))) tryAdd(tx, ty)
      }
    }
  }

  const reach: ReachResult = { standable: reachable }

  // --- Ausgang erreichbar? ---
  for (const d of markers.filter((m) => m.type === 'door-exit')) {
    if (!nearReachable(reach, d.tx, d.ty, 1, 3)) {
      errors.push(
        `Tür "D" bei tx=${d.tx}, ty=${d.ty} ist vom Spawn aus NICHT erreichbar — prüfe Sprunghöhen (max. ${MAX_RISE_TILES} Kacheln hoch, ~5 weit) und ob ein Tor ohne Öffner den Weg blockiert.`,
      )
    }
  }
  for (const o of objects) {
    const def = OBJECT_TYPES[o.type]
    if (!def) continue
    if (def.isExit || def.needsStandableInZone) {
      if (!zoneReachable(reach, o)) {
        errors.push(
          `${o.type} bei tx=${o.tx}, ty=${o.ty} (${o.tw}×${o.th}): Der Spieler kann diese Zone nie betreten — es fehlt erreichbarer Boden darin/darunter.`,
        )
      }
    }
    if (def.makesPlatform) {
      const top = Math.floor(o.ty) - 1
      let found = false
      for (let x = Math.floor(o.tx); x <= Math.ceil(o.tx + o.tw) - 1 && !found; x++) {
        if (reach.standable.has(`${x},${top}`)) found = true
      }
      if (!found) {
        errors.push(
          `${o.type} bei tx=${o.tx}, ty=${o.ty}: Die Plattform-Oberseite ist nicht erreichbar (zu hoch/zu weit? Max. ${MAX_RISE_TILES} Kacheln Steigung pro Sprung).`,
        )
      }
    }
  }

  // --- Datenbits erreichbar? ---
  const unreachableBits: string[] = []
  let reachableBits = 0
  for (const b of markers.filter((m) => m.type === 'collectible')) {
    if (nearReachable(reach, b.tx, b.ty, 2, 4)) reachableBits += 1
    else unreachableBits.push(`(tx=${b.tx}, ty=${b.ty})`)
  }
  if (unreachableBits.length > 0) {
    warnings.push(
      `${unreachableBits.length} Datenbit(s) wahrscheinlich nicht erreichbar: ${unreachableBits.join(', ')} — näher an begehbaren Boden setzen (max. ~3 Kacheln über einer Standfläche).`,
    )
  }
  return
}

/** Gibt es eine erreichbare Steh-Zelle im Umkreis (dx horizontal, dy vertikal)? */
function nearReachable(reach: ReachResult, tx: number, ty: number, dx: number, dy: number): boolean {
  for (const key of reach.standable) {
    const [sx, sy] = key.split(',').map(Number)
    if (Math.abs(sx - tx) <= dx && sy - ty >= -1 && sy - ty <= dy) return true
  }
  return false
}

/** Liegt eine erreichbare Steh-Zelle in der (leicht vergrößerten) Zone? */
function zoneReachable(reach: ReachResult, o: ParsedObject): boolean {
  for (const key of reach.standable) {
    const [sx, sy] = key.split(',').map(Number)
    const cx = sx + 0.5
    const cy = sy + 0.5
    if (cx >= o.tx - 1 && cx <= o.tx + o.tw + 1 && cy >= o.ty - 1.5 && cy <= o.ty + o.th + 1.5) return true
  }
  return false
}

// ------------------------------------------------------------------ Emission

function round2(n: number): number {
  return Math.round(n * 100) / 100
}

interface TmjObject {
  id: number
  name: string
  type: string
  class: string
  x: number
  y: number
  width: number
  height: number
  rotation: number
  visible: boolean
  point: boolean
  properties: { name: string; type: string; value: string | number | boolean }[]
}

function emitTmjObjects(objects: ParsedObject[], markers: Marker[]): TmjObject[] {
  let nextId = 1
  const out: TmjObject[] = []
  const push = (
    type: string,
    name: string,
    tx: number,
    ty: number,
    tw: number,
    th: number,
    props: Record<string, string | number | boolean>,
  ): void => {
    out.push({
      id: nextId++,
      name,
      type,
      class: type,
      x: round2(tx * TILE),
      y: round2(ty * TILE),
      width: round2(tw * TILE),
      height: round2(th * TILE),
      rotation: 0,
      visible: true,
      point: false,
      properties: Object.entries(props).map(([name, value]) => ({
        name,
        type: typeof value === 'number' ? 'float' : typeof value === 'boolean' ? 'bool' : 'string',
        value,
      })),
    })
  }

  for (const o of objects) push(o.type, o.name ?? '', o.tx, o.ty, o.tw, o.th, o.props)
  for (const m of markers) {
    switch (m.type) {
      case 'spawn':
        push('spawn', '', m.tx, m.ty, 1, 1, {})
        break
      case 'collectible':
        // 0,75-Kachel-Box mittig in der Marker-Kachel
        push('collectible', '', m.tx + 0.125, m.ty + 0.125, 0.75, 0.75, {})
        break
      case 'checkpoint':
        // Marker-Kachel = Fußpunkt (Unterkante bündig mit der Standfläche darunter)
        push('checkpoint', '', m.tx, m.ty - 0.5, 1, 1.5, {})
        break
      case 'door-exit':
        // Tür steht auf der Standfläche unter der Marker-Kachel und „sinkt" 1 Kachel
        // ein, damit der Sensor den laufenden Paul sicher erfasst (wie im Original).
        push('door-exit', '', m.tx - 0.25, m.ty - 1, 1.5, 3, {})
        break
    }
  }
  return out
}

function emitTmj(id: string, gidGrid: number[][], objects: TmjObject[]): Record<string, unknown> {
  const height = gidGrid.length
  const width = gidGrid[0]?.length ?? 0
  return {
    compressionlevel: -1,
    type: 'map',
    version: '1.10',
    tiledversion: '1.10.2',
    orientation: 'orthogonal',
    renderorder: 'right-down',
    infinite: false,
    width,
    height,
    tilewidth: TILE,
    tileheight: TILE,
    nextlayerid: 3,
    nextobjectid: objects.length + 1,
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
        tileheight: TILE,
        tilewidth: TILE,
      },
    ],
    layers: [
      {
        id: 1,
        type: 'tilelayer',
        name: 'terrain',
        width,
        height,
        opacity: 1,
        visible: true,
        x: 0,
        y: 0,
        data: gidGrid.flat(),
      },
      {
        id: 2,
        type: 'objectgroup',
        name: 'objects',
        draworder: 'topdown',
        opacity: 1,
        visible: true,
        x: 0,
        y: 0,
        objects,
      },
    ],
  }
}

function emitLevelJson(id: string, design: DesignLevel): Record<string, unknown> {
  const out: Record<string, unknown> = {
    _generiert: `AUS design/levels/${id}/ ERZEUGT — nicht von Hand editieren, sondern dort ändern und "npm run build:levels" ausführen.`,
    id,
    station: design.station,
    siegelIcon: design.siegelIcon,
    cityAnchor: design.cityAnchor,
    cameraMode: design.cameraMode,
    theme: design.theme,
    enemySkin: design.enemySkin,
    tilemap: `assets/tilemaps/${id}.tmj`,
    collectible: design.collectible,
    mechanics: design.mechanics,
    parTimeSeconds: design.parTimeSeconds,
  }
  if (design.stuckHint) out.stuckHint = design.stuckHint
  return out
}

// ------------------------------------------------------------------ Haupt-API

export function compileLevel(
  id: string,
  layoutText: string,
  levelRaw: unknown,
  themes: Record<string, unknown>,
): CompiledLevel {
  const errors: string[] = []
  const warnings: string[] = []

  if (!LEVEL_ID_PATTERN.test(id)) {
    errors.push(
      `Level-ID "${id}" ungültig — Muster: zweistellige Nummer + Kleinbuchstaben-Name, z. B. "04-fachdienst".`,
    )
  }

  const parsedDesign = DesignLevelSchema.safeParse(levelRaw)
  if (!parsedDesign.success) {
    errors.push(formatZodError(`design/levels/${id}/level.json`, parsedDesign.error))
    return { id, errors, warnings }
  }
  const design = parsedDesign.data

  const { grid, width, markers } = parseLayout(layoutText, errors)
  if (errors.length > 0 && grid.length !== GRID_HEIGHT) {
    return { id, errors, warnings } // Grundstruktur kaputt — Folgechecks wären Rauschen
  }

  const objects = parseObjects(design, errors)
  checkStructure(design, objects, markers, width, themes, errors, warnings)
  if (errors.length === 0) {
    analyzeReachability(grid, width, objects, markers, errors, warnings)
  }

  if (errors.length > 0) return { id, errors, warnings }

  const tmjObjects = emitTmjObjects(objects, markers)
  return {
    id,
    errors,
    warnings,
    tmj: emitTmj(id, toGidGrid(grid), tmjObjects),
    levelJson: emitLevelJson(id, design),
  }
}
