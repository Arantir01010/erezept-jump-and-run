import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { darken, depthMix, fogColor } from './atmos'

/**
 * MATERIALSYSTEM — sechs benannte Oberflächen statt Farben pro Objekt.
 *
 * Vorher wählte jedes Objekt seine Farben selbst. Das Ergebnis sieht
 * zusammengetragen aus statt entworfen, und jede neue Grafik ist eine neue
 * Einzelentscheidung. Hier gibt es stattdessen sechs Materialien, die sich
 * aus der Farbwelt ableiten — danach ist jedes Objekt nur noch eine Formfrage.
 *
 * ZWEI MATERIALIEN SIND FACHLICH GEBUNDEN, NICHT GESTALTERISCH:
 * `gefahr` (warm) heißt „offen, sichtbar, mitlesbar", `schutz` (kühl) heißt
 * „verschlüsselt, geschützt". Diese Zuordnung trägt die Lern-Level und darf
 * sich zwischen Farbwelten NICHT ändern — sonst lernt der Besucher in
 * Station 3 etwas anderes als in Station 4. Deshalb sind beide feste Werte
 * und keine Theme-Ableitung.
 */

/** Warm = offen/sichtbar. Fest, siehe Kopfkommentar. */
export const WARM_OFFEN = 0xff8a3a
/** Kühl = geschützt/verschlüsselt. Fest, siehe Kopfkommentar. */
export const KUEHL_GESCHUETZT = 0x4de3ff

export type MaterialName = 'fels' | 'glas' | 'metall' | 'signal' | 'gefahr' | 'schutz'

export interface Material {
  /** Füllfarbe der Masse. */
  flaeche: number
  /** Deckkraft der Fläche (Glas ist durchlässig). */
  deckkraft: number
  /** Farbe der Kante — das, was die Form lesbar macht. */
  kante: number
  /** Deckkraft der Kante. */
  kantenDeckkraft: number
  /** Farbe des Eigenlichts (0 = leuchtet nicht). */
  licht: number
  /** Grundstärke des Eigenlichts, vor der Licht-Stufe (siehe LICHT). */
  lichtStaerke: number
}

/**
 * Licht-Stufen. Genau EIN Leitlicht pro Bild (REZI), alles andere ordnet sich
 * unter. Ohne diese Ordnung glüht alles ein bisschen — und damit nichts.
 */
export const LICHT = {
  /** Der eine Blickfang. Nur REZI. */
  leit: 1,
  /** Interaktives: findet den Blick, überstrahlt aber nicht. */
  signal: 0.45,
  /** Textur: Fenster, Funken, Kantenlicht. Nie Blickfang. */
  ambient: 0.18,
} as const

export function materialien(theme: Theme): Record<MaterialName, Material> {
  const fog = fogColor(theme)
  const detail = Phaser.Display.Color.HexStringToColor(theme.detail).color
  const accent = Phaser.Display.Color.HexStringToColor(theme.accent).color
  return {
    // Tragende Masse: das Dunkelste im Bild, damit das Spielfeld immer vorn liegt
    fels: {
      flaeche: darken(theme.skyTop, 0.5),
      deckkraft: 1,
      kante: detail,
      kantenDeckkraft: 1,
      licht: detail,
      lichtStaerke: 0.42,
    },
    // Durchlässig, aber eine Grenze — der Korridor muss als Raum lesbar bleiben
    glas: {
      flaeche: detail,
      deckkraft: 0.13,
      kante: detail,
      kantenDeckkraft: 0.75,
      licht: detail,
      lichtStaerke: 0.16,
    },
    // Technik: fest, kalt, ohne Eigenlicht
    metall: {
      flaeche: depthMix(theme.detail, fog, 0.7),
      deckkraft: 1,
      kante: depthMix(theme.detail, fog, 0.2),
      kantenDeckkraft: 0.9,
      licht: 0,
      lichtStaerke: 0,
    },
    // Hier kann man etwas tun
    signal: {
      flaeche: darken(theme.accent, 0.68),
      deckkraft: 1,
      kante: accent,
      kantenDeckkraft: 1,
      licht: accent,
      lichtStaerke: 0.5,
    },
    gefahr: {
      flaeche: darken('#ff8a3a', 0.55),
      deckkraft: 1,
      kante: WARM_OFFEN,
      kantenDeckkraft: 1,
      licht: WARM_OFFEN,
      lichtStaerke: 0.55,
    },
    schutz: {
      flaeche: darken('#4de3ff', 0.62),
      deckkraft: 1,
      kante: KUEHL_GESCHUETZT,
      kantenDeckkraft: 1,
      licht: KUEHL_GESCHUETZT,
      lichtStaerke: 0.45,
    },
  }
}

// ---------------------------------------------------------------- Bausteine

/**
 * Glas-Pille: der HUD-Baustein. Dunkle, halbdurchlässige Fläche mit einer
 * hauchdünnen Lichtkante oben — das liest sich als Glas und nicht als Kasten.
 */
export function pille(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  w: number,
  h: number,
  opts: { fuellung?: number; alpha?: number; kante?: number; kantenAlpha?: number } = {},
): void {
  const r = h / 2
  g.fillStyle(opts.fuellung ?? 0x060d16, opts.alpha ?? 0.55)
  g.fillRoundedRect(x, y, w, h, r)
  g.lineStyle(0.7, opts.kante ?? 0xffffff, opts.kantenAlpha ?? 0.14)
  g.strokeRoundedRect(x, y, w, h, r)
  // Lichtkante oben: nur die obere Hälfte, sonst wirkt es wie ein Rahmen
  g.fillStyle(0xffffff, (opts.kantenAlpha ?? 0.14) * 1.3)
  g.fillRoundedRect(x + r * 0.6, y + 0.35, w - r * 1.2, 0.6, 0.3)
}

/**
 * Weicher Verlauf statt harter Kante — für HUD-Ränder und Nebelbänder.
 * Der Canvas-Renderer kennt `fillGradientStyle` nicht, deshalb der Fallback.
 */
export function verlaufBand(
  scene: Phaser.Scene,
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  w: number,
  h: number,
  farbe: number,
  vonAlpha: number,
  bisAlpha: number,
): void {
  if (scene.game.renderer.type === Phaser.WEBGL) {
    g.fillGradientStyle(farbe, farbe, farbe, farbe, vonAlpha, vonAlpha, bisAlpha, bisAlpha)
    g.fillRect(x, y, w, h)
    return
  }
  const STUFEN = 10
  for (let s = 0; s < STUFEN; s++) {
    g.fillStyle(farbe, vonAlpha + ((bisAlpha - vonAlpha) * s) / (STUFEN - 1))
    g.fillRect(x, y + (h / STUFEN) * s, w, h / STUFEN + 1)
  }
}
