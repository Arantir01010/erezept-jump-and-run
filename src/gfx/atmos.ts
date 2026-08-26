import Phaser from 'phaser'
import type { Theme } from '../level/schema'

/**
 * ATMOSPHÄRE — die Werkzeuge für den Tiefen-Look.
 *
 * Der Trick, der ein flaches Bild in eine Welt verwandelt, heißt
 * „atmosphärische Perspektive": Alles, was weiter weg ist, verliert Kontrast
 * und wandert farblich in Richtung Dunst. Genau das macht die Silhouetten-
 * Staffelung in `backdrop.ts` und das Gelände in `TerrainRenderer.ts`.
 *
 * Die Dunstfarbe ist bewusst KEINE neue Theme-Einstellung: `skyBottom` ist der
 * Horizont — das ist per Definition die Farbe, in der die Ferne verschwindet.
 * Damit bleiben `themes.json` und das Schema unverändert.
 */

/** Dunstfarbe einer Farbwelt (= Horizont). */
export function fogColor(theme: Theme): Phaser.Display.Color {
  return Phaser.Display.Color.HexStringToColor(theme.skyBottom)
}

/**
 * Farbe in die Ferne rücken: t = 0 → Originalfarbe, t = 1 → reiner Dunst.
 * Eine Ebene weiter hinten bekommt ein höheres t — mehr braucht Tiefe nicht.
 */
export function depthMix(hex: string, fog: Phaser.Display.Color, t: number): number {
  const c = Phaser.Display.Color.HexStringToColor(hex)
  const k = Math.round(Phaser.Math.Clamp(t, 0, 1) * 100)
  const m = Phaser.Display.Color.Interpolate.ColorWithColor(c, fog, 100, k)
  return Phaser.Display.Color.GetColor(m.r, m.g, m.b)
}

/** Wie depthMix, aber Richtung Schwarz — für Silhouetten im Vordergrund. */
export function darken(hex: string, t: number): number {
  const c = Phaser.Display.Color.HexStringToColor(hex)
  const k = 1 - Phaser.Math.Clamp(t, 0, 1)
  return Phaser.Display.Color.GetColor(
    Math.round(c.red * k),
    Math.round(c.green * k),
    Math.round(c.blue * k),
  )
}

export interface AtmosphereOpts {
  /** Stärke des Leuchtens (0 = aus). Default 0.7. */
  bloom?: number
  /** Stärke der Randabdunklung. Default 0.28. */
  vignette?: number
  /** Entsättigung: hält die Palette eng, wie in Hollow Knight. Default 0.1. */
  desaturate?: number
}

/**
 * Kamera-Nachbearbeitung: Leuchten, Randabdunklung, leichte Entsättigung.
 *
 * Nur WebGL — der `?renderer=canvas`-Notfallpfad am Messestand kennt keine
 * Post-FX und läuft ohne. Das Bild ist dort flacher, aber vollständig lesbar.
 * Die UIScene hat ihre eigene Kamera und bleibt bewusst unbehandelt, damit
 * Schrift und QR-Code hart und scharf bleiben.
 */
export function applyAtmosphere(scene: Phaser.Scene, opts: AtmosphereOpts = {}): void {
  if (scene.game.renderer.type !== Phaser.WEBGL) return
  const cam = scene.cameras.main
  const bloom = opts.bloom ?? 0.7
  const vignette = opts.vignette ?? 0.28
  const desaturate = opts.desaturate ?? 0.1
  if (bloom > 0) cam.postFX.addBloom(0xffffff, 1, 1, 1, bloom, 4)
  if (vignette > 0) cam.postFX.addVignette(0.5, 0.52, 0.9, vignette)
  if (desaturate > 0) cam.postFX.addColorMatrix().saturate(-desaturate)
}
