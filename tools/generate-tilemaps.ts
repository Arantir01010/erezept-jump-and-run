/**
 * Erzeugt die Prototyp-Tilemaps als Standard-Tiled-JSON (.tmj) aus
 * ASCII-/Helfer-Definitionen. Die Ausgaben sind ganz normale Tiled-Dateien —
 * Leveldesigner können sie später direkt im Tiled Map Editor weiterbearbeiten.
 *
 * Aufruf: npm run gen:maps
 *
 * Kachel-GIDs (Tileset "ti-tiles", 8 Kacheln, siehe src/gfx/TextureFactory.ts):
 *   1 Boden-Füllung · 2 Boden-Oberkante · 3 Plattform · 4 Gold-Pad
 *   5 Akzentblock · 6 Glas (Tunnelwand) · 7 dunkle Füllung · 8 Deko-Strebe (nicht solide)
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const TILE = 16
const OUT_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'assets', 'tilemaps')

// ------------------------------------------------------------------ Helfer

type Grid = number[][]

function makeGrid(width: number, height: number): Grid {
  return Array.from({ length: height }, () => Array<number>(width).fill(0))
}

function fillRect(grid: Grid, x: number, y: number, w: number, h: number, gid: number): void {
  for (let yy = y; yy < y + h; yy++) {
    for (let xx = x; xx < x + w; xx++) {
      if (grid[yy] && xx >= 0 && xx < grid[yy].length) grid[yy][xx] = gid
    }
  }
}

interface ObjDef {
  type: string
  name?: string
  /** Position/Größe in Kacheln (Floats erlaubt), x/y = obere linke Ecke. */
  tx: number
  ty: number
  tw?: number
  th?: number
  props?: Record<string, string | number | boolean>
}

function buildMap(id: string, grid: Grid, objects: ObjDef[]): void {
  const height = grid.length
  const width = grid[0].length
  let nextId = 1
  const tiledObjects = objects.map((o) => ({
    id: nextId++,
    name: o.name ?? '',
    type: o.type,
    class: o.type,
    x: Math.round(o.tx * TILE * 100) / 100,
    y: Math.round(o.ty * TILE * 100) / 100,
    width: Math.round((o.tw ?? 1) * TILE * 100) / 100,
    height: Math.round((o.th ?? 1) * TILE * 100) / 100,
    rotation: 0,
    visible: true,
    point: false,
    properties: Object.entries(o.props ?? {}).map(([name, value]) => ({
      name,
      type: typeof value === 'number' ? 'float' : typeof value === 'boolean' ? 'bool' : 'string',
      value,
    })),
  }))

  const map = {
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
    nextobjectid: nextId,
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
        data: grid.flat(),
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
        objects: tiledObjects,
      },
    ],
  }

  mkdirSync(OUT_DIR, { recursive: true })
  const file = join(OUT_DIR, `${id}.tmj`)
  writeFileSync(file, JSON.stringify(map))
  console.log(`✓ ${file} (${width}×${height} Kacheln, ${tiledObjects.length} Objekte)`)
}

/** Datenbits entlang eines Bogens platzieren. */
function bitArc(objects: ObjDef[], startTx: number, ty: number, count: number, stepTx = 2, wave = 0): void {
  for (let i = 0; i < count; i++) {
    const y = ty + (wave > 0 ? Math.round(Math.sin(i * 1.1) * wave * 10) / 10 : 0)
    objects.push({ type: 'collectible', tx: startTx + i * stepTx, ty: y, tw: 0.75, th: 0.75 })
  }
}

// ================================================================== Level 02: Kartenterminal
// Horizontal, Innenwelt des Lesegeräts: Kontaktpads, Skimming-Kralle (ducken!),
// PIN-Schleuse (Timing-Gate, Arzt-PIN/eHBA-Framing), Signatur-Stempel als Ausgang.
{
  const W = 100
  const H = 23
  const grid = makeGrid(W, H)

  // Boden
  fillRect(grid, 0, 20, W, 1, 2)
  fillRect(grid, 0, 21, W, 2, 1)

  // Einstieg: sanfte Sprünge über Kontaktpad-Stufen
  fillRect(grid, 12, 18, 2, 2, 4) // Gold-Pad-Stufe
  fillRect(grid, 18, 16, 3, 1, 3) // Plattform
  fillRect(grid, 24, 14, 3, 1, 3)
  fillRect(grid, 30, 18, 2, 2, 5) // Akzentblock-Stufe (max. 32 px — verzeihende Sprünge)
  fillRect(grid, 36, 15, 3, 1, 3)

  // Deko-Streben im Hintergrund (nicht solide)
  fillRect(grid, 8, 4, 1, 12, 8)
  fillRect(grid, 42, 4, 1, 12, 8)
  fillRect(grid, 78, 4, 1, 12, 8)

  // Skimming-Kralle: Fake-Aufsatz-Box auf dem Boden, Kralle greift nach links
  fillRect(grid, 49, 18, 2, 2, 5)

  // PIN-Schleuse: Zone vor dem Tor
  fillRect(grid, 58, 19, 8, 1, 4) // goldener Kontaktboden markiert die Schleuse

  // Nach dem Tor: Belohnungs-Plattformen
  fillRect(grid, 72, 16, 3, 1, 3)
  fillRect(grid, 78, 14, 3, 1, 3)

  // Stempel-Podium am Ausgang
  fillRect(grid, 88, 19, 8, 1, 4)

  const objects: ObjDef[] = [
    { type: 'spawn', tx: 3, ty: 18 },
    // Bits: Einstieg + Plattformen (countRequired: 8, platziert: 12)
    { type: 'collectible', tx: 12.6, ty: 16.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 18.5, ty: 14.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 19.5, ty: 14.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 24.5, ty: 12.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 25.5, ty: 12.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 36.5, ty: 13.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 37.5, ty: 13.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 44, ty: 18.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 72.5, ty: 14.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 78.5, ty: 12.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 79.5, ty: 12.5, tw: 0.75, th: 0.75 },
    { type: 'collectible', tx: 84, ty: 18.5, tw: 0.75, th: 0.75 },
    // Checkpoint vor der Kralle
    { type: 'checkpoint', tx: 42, ty: 18.5, tw: 1, th: 1.5 },
    // REZI warnt vor der Kralle
    {
      type: 'info-sign',
      tx: 43.5,
      ty: 16,
      tw: 2.5,
      th: 4,
      props: { textDe: 'Vorsicht, Skimming-Kralle — duck dich!', textEn: 'Careful, skimming claw — duck!' },
    },
    // Die Kralle selbst (greift aus der Box nach links, gematik-Siegel blockt sie)
    { type: 'deny-enemy', tx: 48.1, ty: 18.55, tw: 1.4, th: 0.4, props: { fromRight: true, reach: 42 } },
    // PIN-Schleuse: Timing-Gate + Tor
    { type: 'timing-gate', tx: 58, ty: 15, tw: 8, th: 5, props: { gate: 'gate-pin' } },
    { type: 'gate', name: 'gate-pin', tx: 67, ty: 14, tw: 0.5, th: 6 },
    // Checkpoint nach dem Tor
    { type: 'checkpoint', tx: 70, ty: 18.5, tw: 1, th: 1.5 },
    // Signatur-Stempel = Levelausgang (Setpiece)
    { type: 'stamp-exit', tx: 89, ty: 14, tw: 6, th: 6 },
  ]

  buildMap('02-kartenterminal', grid, objects)
}

// ================================================================== Level 03: KOV Gateway
// Tube (Auto-Scroll-Korridor im Glastunnel): Prüf-Podeste (stillstehen!),
// Verschlüsselungs-Dusche, VPN-Ride mit Bits — im Tunnel gibt es KEINE Schadensquellen.
{
  const W = 140
  const H = 23
  const grid = makeGrid(W, H)

  // Glastunnel: Decke + Boden aus Glas, außen dunkles „offenes Internet"
  fillRect(grid, 0, 2, W, 1, 6)
  fillRect(grid, 0, 19, W, 1, 6)
  fillRect(grid, 0, 0, W, 2, 7)
  fillRect(grid, 0, 20, W, 3, 7)

  // Tunnel-Streben als Rhythmus (nicht solide)
  for (let x = 10; x < W; x += 14) fillRect(grid, x, 3, 1, 16, 8)

  // Sprung-Inseln für den Ride
  fillRect(grid, 44, 16, 3, 1, 3)
  fillRect(grid, 52, 14, 3, 1, 3)
  fillRect(grid, 74, 16, 3, 1, 3)
  fillRect(grid, 80, 14, 3, 1, 3)
  fillRect(grid, 86, 16, 3, 1, 3)
  fillRect(grid, 108, 16, 3, 1, 3)
  fillRect(grid, 114, 14, 3, 1, 3)
  fillRect(grid, 120, 16, 3, 1, 3)

  const objects: ObjDef[] = [
    { type: 'spawn', tx: 3, ty: 17 },
    // Prüf-Podest 1 + Tor (Krake bekommt „ZUGRIFF VERWEIGERT")
    { type: 'stillstand-podest', tx: 26, ty: 17.6, tw: 3, th: 0.4, props: { gate: 'gate-scan-1' } },
    { type: 'gate', name: 'gate-scan-1', tx: 33, ty: 14, tw: 0.5, th: 5 },
    // Ride-Abschnitt 1
    // Verschlüsselungs-Dusche + Tor: unverschlüsselt geht es nicht weiter
    { type: 'krypto-dusche', tx: 58, ty: 13, tw: 5, th: 6 },
    { type: 'gate', name: 'gate-krypto', tx: 66, ty: 14, tw: 0.5, th: 5, props: {} },
    // Prüf-Podest 2 + Tor
    { type: 'stillstand-podest', tx: 94, ty: 17.6, tw: 3, th: 0.4, props: { gate: 'gate-scan-2' } },
    { type: 'gate', name: 'gate-scan-2', tx: 101, ty: 14, tw: 0.5, th: 5 },
    // Levelausgang (tief genug, dass die Tür den laufenden Paul sicher erfasst)
    { type: 'door-exit', tx: 133, ty: 17, tw: 1.5, th: 3 },
    // Datenkraken & Lauscher AUSSEN am Glas — sichtbar, aber machtlos
    { type: 'deco', tx: 18, ty: 0.4, tw: 1.5, th: 1.5, props: { sprite: 'krake-0', anim: 'krake-swim', drift: 4 } },
    { type: 'deco', tx: 48, ty: 0.2, tw: 1.5, th: 1.5, props: { sprite: 'krake-0', anim: 'krake-swim', drift: 5 } },
    { type: 'deco', tx: 77, ty: 0.5, tw: 1.5, th: 1.5, props: { sprite: 'krake-0', anim: 'krake-swim', drift: 3 } },
    { type: 'deco', tx: 105, ty: 0.3, tw: 1.5, th: 1.5, props: { sprite: 'krake-0', anim: 'krake-swim', drift: 5 } },
    { type: 'deco', tx: 128, ty: 0.5, tw: 1.5, th: 1.5, props: { sprite: 'krake-0', anim: 'krake-swim', drift: 4 } },
  ]

  // Krypto-Dusche verknüpft ihr Tor über die Level-JSON? Nein — per Objekt-Property:
  const dusche = objects.find((o) => o.type === 'krypto-dusche')
  if (dusche) dusche.props = { ...dusche.props, gate: 'gate-krypto' }

  // Bits: countRequired 10, platziert deutlich mehr — Bodenreihe im Lauf sammelbar
  // (ty 18.2 → auf Kopf-/Körperhöhe), Bonusreihen über den Inseln belohnen Springen
  bitArc(objects, 38, 18.2, 4, 2)
  bitArc(objects, 44.5, 14.5, 2, 4) // über den Inseln
  bitArc(objects, 70, 18.2, 3, 2)
  bitArc(objects, 74.5, 14.5, 3, 3)
  bitArc(objects, 104, 18.2, 3, 2)
  bitArc(objects, 108.5, 14.5, 3, 3)
  bitArc(objects, 124, 18.2, 4, 2)

  buildMap('03-kov-gateway', grid, objects)
}

console.log('Fertig. Die .tmj-Dateien sind normale Tiled-JSON-Maps (editierbar im Tiled Map Editor).')
