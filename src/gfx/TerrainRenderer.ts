import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { darken } from './atmos'
import { TILE_SIZE } from './TextureFactory'

/**
 * GELÄNDE-DARSTELLUNG — trennt Aussehen von Kollision.
 *
 * Die Tilemap bleibt exakt so, wie der Level-Compiler sie erzeugt: Sie ist
 * weiterhin das Kollisionsgitter (16 px), nur unsichtbar. Gezeichnet wird
 * stattdessen hier — aus zusammengefassten Blöcken, als durchgehende dunkle
 * Silhouette mit Kantenlicht auf den freiliegenden Oberkanten.
 *
 * Damit ändert sich NICHTS an `design/`, am Compiler, an der Sprungphysik
 * oder an der Erreichbarkeitsprüfung. Der geschützte Baukasten bleibt
 * unangetastet — ausgetauscht wird nur die Darstellung.
 *
 * Kachel-GIDs (siehe TextureFactory.makeTileset):
 *   1 Boden · 2 Boden-Oberkante · 3 Plattform · 4 Gold-Pad ·
 *   5 Akzentblock · 6 Glas · 7 dunkle Füllung · 8 Strebe (nicht solide)
 */

type Klasse = 'fels' | 'pad' | 'glas' | 'strebe'

function klasse(index: number): Klasse | null {
  if (index === 4) return 'pad'
  if (index === 6) return 'glas'
  if (index === 8) return 'strebe'
  if (index >= 1 && index <= 7) return 'fels'
  return null
}

interface Rect {
  x: number
  y: number
  w: number
  h: number
}

/**
 * Gleichartige Kacheln zu möglichst wenigen Rechtecken zusammenfassen.
 * Erst waagerechte Läufe je Zeile, dann senkrecht verschmelzen, wenn der Lauf
 * darunter deckungsgleich ist. Aus 200 Kacheln werden so ~8 Flächen — und
 * genau deshalb entstehen durchgehende Kanten statt eines Kachelrasters.
 */
function merge(cells: boolean[][], cols: number, rows: number): Rect[] {
  const offen = new Map<string, Rect>()
  const fertig: Rect[] = []
  for (let y = 0; y < rows; y++) {
    const laeufe = new Map<string, Rect>()
    let x = 0
    while (x < cols) {
      if (!cells[y][x]) {
        x += 1
        continue
      }
      let end = x
      while (end + 1 < cols && cells[y][end + 1]) end += 1
      laeufe.set(`${x}:${end}`, { x, y, w: end - x + 1, h: 1 })
      x = end + 1
    }
    // Läufe, die es in dieser Zeile nicht mehr gibt, sind abgeschlossen
    for (const [key, rect] of offen) {
      if (!laeufe.has(key)) {
        fertig.push(rect)
        offen.delete(key)
      }
    }
    for (const [key, rect] of laeufe) {
      const vorhanden = offen.get(key)
      if (vorhanden) vorhanden.h += 1
      else offen.set(key, rect)
    }
  }
  for (const rect of offen.values()) fertig.push(rect)
  return fertig
}

function sammle(
  layer: Phaser.Tilemaps.TilemapLayer,
  cols: number,
  rows: number,
  gesucht: Klasse,
): Rect[] {
  const cells: boolean[][] = []
  for (let y = 0; y < rows; y++) {
    const zeile: boolean[] = []
    for (let x = 0; x < cols; x++) {
      const tile = layer.getTileAt(x, y, true)
      zeile.push(!!tile && klasse(tile.index) === gesucht)
    }
    cells.push(zeile)
  }
  return merge(cells, cols, rows)
}

/**
 * Zeichnet das Gelände und macht die Kachel-Ebene unsichtbar.
 * Die Ebene selbst bleibt bestehen und kollidiert weiter.
 */
export function drawTerrain(
  scene: Phaser.Scene,
  map: Phaser.Tilemaps.Tilemap,
  layer: Phaser.Tilemaps.TilemapLayer,
  theme: Theme,
): void {
  layer.setVisible(false)

  const cols = map.width
  const rows = map.height
  const T = TILE_SIZE
  const accent = Phaser.Display.Color.HexStringToColor(theme.accent).color

  // Silhouette: an der DUNKELSTEN Themefarbe orientiert, nicht an der
  // Bodenfarbe. Entscheidend ist die Reihenfolge der Helligkeiten:
  // Gelände am dunkelsten, dann nahe Türme, dann mittlere, dann ferne.
  // Kippt diese Ordnung, wirkt der Hintergrund näher als das Spielfeld.
  const fels = darken(theme.skyTop, 0.5)
  const kanteHell = Phaser.Display.Color.HexStringToColor(theme.detail).color

  const flaechen = scene.add.graphics().setDepth(1)
  const kanten = scene.add.graphics().setDepth(2)

  // --- Bodennebel: das Band, das die Spielebene vom Hintergrund trennt ---
  // Ohne diese Schicht kleben Gelände und Kulisse aufeinander; mit ihr liegt
  // das Spielfeld sichtbar VOR der Stadt. Der günstigste Tiefen-Effekt, den es
  // gibt — und der Grund, warum Hollow Knight nie flach wirkt.
  {
    const nebel = scene.add.graphics().setDepth(0.9)
    const c = Phaser.Display.Color.HexStringToColor(theme.skyBottom).color
    const h = 150
    const yTop = map.heightInPixels - h
    if (scene.game.renderer.type === Phaser.WEBGL) {
      nebel.fillGradientStyle(c, c, c, c, 0, 0, 0.5, 0.5)
      nebel.fillRect(0, yTop, map.widthInPixels, h)
    } else {
      const STEPS = 10
      for (let s = 0; s < STEPS; s++) {
        nebel.fillStyle(c, (0.5 * s) / (STEPS - 1))
        nebel.fillRect(0, yTop + (h / STEPS) * s, map.widthInPixels, h / STEPS + 1)
      }
    }
  }

  // --- Fels / Plattformen: dunkle Flächen ---
  for (const r of sammle(layer, cols, rows, 'fels')) {
    flaechen.fillStyle(fels, 1)
    flaechen.fillRect(r.x * T, r.y * T, r.w * T, r.h * T)
    // Innenschatten unten: gibt der Masse Gewicht
    flaechen.fillStyle(0x000000, 0.28)
    flaechen.fillRect(r.x * T, r.y * T + r.h * T - 6, r.w * T, 6)
  }

  // --- Glas (Tunnelwand): durchscheinend, aber deutlich. Der Korridor muss
  //     als Raum lesbar bleiben — sonst verliert das Gateway-Level seine Form.
  for (const r of sammle(layer, cols, rows, 'glas')) {
    const w = r.w * T
    const h = r.h * T
    flaechen.fillStyle(kanteHell, 0.13)
    flaechen.fillRect(r.x * T, r.y * T, w, h)
    // Kanten: außen kräftig, innen ein Lichtreflex — das liest sich als Scheibe
    kanten.lineStyle(1.4, kanteHell, 0.75)
    kanten.strokeRect(r.x * T + 0.7, r.y * T + 0.7, w - 1.4, h - 1.4)
    kanten.fillStyle(0xffffff, 0.22)
    kanten.fillRect(r.x * T + w * 0.18, r.y * T + 2, Math.max(1, w * 0.04), h - 4)
    const glow = scene.add
      .image(r.x * T + w / 2, r.y * T + h / 2, 'fx-glow')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(kanteHell)
      .setAlpha(0.16)
      .setDepth(1)
    glow.setDisplaySize(w * 1.2, h * 1.4)
  }

  // --- Gold-Pads: Kontaktflächen bleiben warm und deutlich sichtbar ---
  for (const r of sammle(layer, cols, rows, 'pad')) {
    flaechen.fillStyle(darken(theme.accent, 0.68), 1)
    flaechen.fillRect(r.x * T, r.y * T, r.w * T, r.h * T)
    kanten.fillStyle(accent, 0.95)
    kanten.fillRect(r.x * T, r.y * T, r.w * T, 2)
    const glow = scene.add
      .image(r.x * T + (r.w * T) / 2, r.y * T, 'fx-glow')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(accent)
      .setAlpha(0.35)
      .setDepth(1)
    glow.setDisplaySize(r.w * T * 1.9, 38)
  }

  // --- Streben: reine Deko, bleiben zart ---
  for (const r of sammle(layer, cols, rows, 'strebe')) {
    flaechen.fillStyle(darken(theme.detail, 0.5), 0.55)
    flaechen.fillRect(r.x * T + T * 0.35, r.y * T, r.w * T * 0.3, r.h * T)
  }

  // --- Kantenlicht auf allen freiliegenden Oberkanten ---
  // Das ist der Effekt, der die Silhouette lesbar macht: eine helle Linie
  // genau dort, wo man landen kann. Gleichzeitig Gameplay-Information.
  const glowKanten: { x: number; w: number; y: number }[] = []
  for (let y = 0; y < rows; y++) {
    let x = 0
    while (x < cols) {
      const hier = layer.getTileAt(x, y, true)
      const k = hier ? klasse(hier.index) : null
      const solide = k === 'fels' || k === 'pad'
      const oben = y > 0 ? layer.getTileAt(x, y - 1, true) : null
      const obenSolide = oben ? klasse(oben.index) === 'fels' || klasse(oben.index) === 'pad' : false
      if (!solide || obenSolide) {
        x += 1
        continue
      }
      let end = x
      while (end + 1 < cols) {
        const n = layer.getTileAt(end + 1, y, true)
        const nk = n ? klasse(n.index) : null
        const nSolide = nk === 'fels' || nk === 'pad'
        const nOben = y > 0 ? layer.getTileAt(end + 1, y - 1, true) : null
        const nObenSolide = nOben
          ? klasse(nOben.index) === 'fels' || klasse(nOben.index) === 'pad'
          : false
        if (!nSolide || nObenSolide) break
        end += 1
      }
      glowKanten.push({ x: x * T, w: (end - x + 1) * T, y: y * T })
      x = end + 1
    }
  }
  for (const e of glowKanten) {
    kanten.fillStyle(kanteHell, 1)
    kanten.fillRect(e.x, e.y - 0.4, e.w, 2)
    kanten.fillStyle(0xffffff, 0.7)
    kanten.fillRect(e.x, e.y - 0.4, e.w, 0.8)
    // Wichtig: das Leuchten in Abschnitte teilen. Ein einziges Glow-Bild über
    // 1300 px gestreckt verteilt seine Helligkeit auf die ganze Breite und
    // verschwindet — genau dort, wo der Boden am meisten Kante braucht.
    const SEG = 110
    const stuecke = Math.max(1, Math.round(e.w / SEG))
    const breite = e.w / stuecke
    for (let s = 0; s < stuecke; s++) {
      const glow = scene.add
        .image(e.x + breite * (s + 0.5), e.y, 'fx-glow')
        .setBlendMode(Phaser.BlendModes.ADD)
        .setTint(kanteHell)
        .setAlpha(0.42)
        .setDepth(1)
      glow.setDisplaySize(breite * 1.6, 58)
    }
  }
}
