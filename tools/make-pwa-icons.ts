/**
 * PWA-ICONS GENERIEREN — abhängigkeitsfrei (eigener PNG-Encoder via node:zlib).
 *
 *   npm run icons   →   public/icons/icon-192.png, icon-512.png,
 *                       icon-512-maskable.png
 *
 * Motiv: die REZI-Kapsel (dunkle Karte mit Mint-Kontur und Rezept-Kreuz,
 * vgl. src/gfx/ReziBody.ts) auf dem Spiel-Hintergrund #06090f. Gezeichnet
 * per Signed-Distance-Funktionen mit weicher Kante — kein Canvas, keine
 * Bild-Bibliothek, damit der Messe-/CI-Rechner nichts nachinstallieren muss.
 *
 * Die PNGs sind eingecheckt; dieses Skript existiert, um sie reproduzierbar
 * neu zu erzeugen (z. B. nach einer Motiv-Änderung).
 */
import { deflateSync } from 'node:zlib'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { ROOT } from './lib/pipeline'

// ------------------------------------------------------------- PNG-Encoder

const CRC_TABLE = (() => {
  const t = new Uint32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    t[n] = c >>> 0
  }
  return t
})()

function crc32(buf: Buffer): number {
  let c = 0xffffffff
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff]! ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}

function chunk(type: string, data: Buffer): Buffer {
  const head = Buffer.alloc(8)
  head.writeUInt32BE(data.length, 0)
  head.write(type, 4, 'ascii')
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])), 0)
  return Buffer.concat([head, data, crc])
}

function encodePng(size: number, rgba: Uint8Array): Buffer {
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(size, 0)
  ihdr.writeUInt32BE(size, 4)
  ihdr[8] = 8 // Bittiefe
  ihdr[9] = 6 // Farbtyp RGBA
  // Scanlines: je Zeile ein Filterbyte 0 + Rohdaten
  const raw = Buffer.alloc((size * 4 + 1) * size)
  for (let y = 0; y < size; y++) {
    const zeile = y * (size * 4 + 1)
    raw[zeile] = 0
    Buffer.from(rgba.buffer, rgba.byteOffset + y * size * 4, size * 4).copy(raw, zeile + 1)
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

// ------------------------------------------------------------- Zeichnen

type Farbe = [number, number, number]
const HINTERGRUND: Farbe = [6, 9, 15] // #06090f — Spiel-Hintergrund
const KAPSEL: Farbe = [8, 33, 29] // #08211d — REZI-Körper
const MINT: Farbe = [143, 255, 228] // #8fffe4 — REZI-Kontur
const WEISS: Farbe = [255, 255, 255]

/** Signed Distance eines achsparallelen Rechtecks (Mittelpunkt, Halbmaße). */
function rechteckSdf(px: number, py: number, cx: number, cy: number, hw: number, hh: number): number {
  const dx = Math.abs(px - cx) - hw
  const dy = Math.abs(py - cy) - hh
  return Math.hypot(Math.max(dx, 0), Math.max(dy, 0)) + Math.min(Math.max(dx, dy), 0)
}

function rundRechteckSdf(px: number, py: number, cx: number, cy: number, hw: number, hh: number, r: number): number {
  return rechteckSdf(px, py, cx, cy, hw - r, hh - r) - r
}

const deckung = (sdf: number): number => Math.min(1, Math.max(0, 0.5 - sdf))

function mische(ziel: Farbe, quelle: Farbe, a: number): Farbe {
  return [
    ziel[0] * (1 - a) + quelle[0] * a,
    ziel[1] * (1 - a) + quelle[1] * a,
    ziel[2] * (1 - a) + quelle[2] * a,
  ]
}

/**
 * Ein Icon rastern. `maskable` hält das Motiv in der inneren Sicherheitszone
 * (~60 %), damit runde/gestanzte Launcher-Masken nichts abschneiden.
 */
function zeichneIcon(size: number, maskable: boolean): Uint8Array {
  const img = new Uint8Array(size * size * 4)
  const c = size / 2
  const halb = size * (maskable ? 0.3 : 0.37) // halbe Kapselbreite
  const ecke = halb * 0.36
  const rand = Math.max(2, size * 0.033)
  const balkenLang = halb * 0.52 // halbe Kreuzlänge
  const balkenDick = halb * 0.16 // halbe Kreuzdicke

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const px = x + 0.5
      const py = y + 0.5
      const kapselSdf = rundRechteckSdf(px, py, c, c, halb, halb, ecke)
      const fuellung = deckung(kapselSdf)
      const kontur = deckung(Math.abs(kapselSdf) - rand / 2)
      const kreuzSdf = Math.min(
        rechteckSdf(px, py, c, c, balkenLang, balkenDick),
        rechteckSdf(px, py, c, c, balkenDick, balkenLang),
      )
      const kreuz = deckung(kreuzSdf) * fuellung

      let farbe = HINTERGRUND
      farbe = mische(farbe, KAPSEL, fuellung)
      farbe = mische(farbe, WEISS, kreuz)
      farbe = mische(farbe, MINT, kontur)

      const i = (y * size + x) * 4
      img[i] = Math.round(farbe[0])
      img[i + 1] = Math.round(farbe[1])
      img[i + 2] = Math.round(farbe[2])
      img[i + 3] = 255
    }
  }
  return img
}

// ------------------------------------------------------------- Hauptlauf

const ziel = join(ROOT, 'public', 'icons')
mkdirSync(ziel, { recursive: true })

const AUFTRAEGE: { datei: string; size: number; maskable: boolean }[] = [
  { datei: 'icon-192.png', size: 192, maskable: false },
  { datei: 'icon-512.png', size: 512, maskable: false },
  { datei: 'icon-512-maskable.png', size: 512, maskable: true },
]

for (const { datei, size, maskable } of AUFTRAEGE) {
  const png = encodePng(size, zeichneIcon(size, maskable))
  writeFileSync(join(ziel, datei), png)
  console.log(`✓ public/icons/${datei} (${size}×${size}${maskable ? ', maskable' : ''}, ${png.length} Bytes)`)
}
