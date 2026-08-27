import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { licht, type LichtHandle } from './licht'

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

/**
 * Dunstfarbe einer Farbwelt: der Horizont, aufgehellt.
 *
 * `skyBottom` allein reicht nicht — manche Farbwelten (KOV-Gateway: #0d1638)
 * sind so dunkel, dass die ganze Tiefenstaffelung in Schwarz zusammenfällt.
 * Der Dunst braucht Leuchtkraft, sonst gibt es kein „weiter weg". Deshalb
 * wird der Horizont fest Richtung Weiß gezogen, bevor er als Ziel dient.
 */
const DUNST_AUFHELLUNG = 0.34

export function fogColor(theme: Theme): Phaser.Display.Color {
  const c = Phaser.Display.Color.HexStringToColor(theme.skyBottom)
  const k = Math.round(DUNST_AUFHELLUNG * 100)
  const weiss = new Phaser.Display.Color(255, 255, 255)
  const m = Phaser.Display.Color.Interpolate.ColorWithColor(c, weiss, 100, k)
  return new Phaser.Display.Color(m.r, m.g, m.b)
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

/** Wie depthMix, aber für bereits aufgelöste Integer-Farben (z. B. aus darken). */
export function depthMixN(farbe: number, fog: Phaser.Display.Color, t: number): number {
  const c = Phaser.Display.Color.IntegerToColor(farbe)
  const k = Math.round(Phaser.Math.Clamp(t, 0, 1) * 100)
  const m = Phaser.Display.Color.Interpolate.ColorWithColor(c, fog, 100, k)
  return Phaser.Display.Color.GetColor(m.r, m.g, m.b)
}

/** Zwei Integer-Farben mischen: t = 0 → a, t = 1 → b (Fassaden-Tonungen). */
export function mischFarben(a: number, b: number, t: number): number {
  const ca = Phaser.Display.Color.IntegerToColor(a)
  const cb = Phaser.Display.Color.IntegerToColor(b)
  const m = Phaser.Display.Color.Interpolate.ColorWithColor(ca, cb, 100, Math.round(Phaser.Math.Clamp(t, 0, 1) * 100))
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
  /** Stärke des Leuchtens (0 = aus). Default 0.6. */
  bloom?: number
  /** Stärke der Randabdunklung. Default 0.18. */
  vignette?: number
  /** Entsättigung: hält die Palette eng, wie in Hollow Knight. Default 0.1. */
  desaturate?: number
  /** Gesamthelligkeit (1 = unverändert). Default 1.18 — für den Messe-TV. */
  brightness?: number
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
  // ?hell=1 — Notfallschalter für helle Messehallen. Der Stil ist bewusst
  // dunkel; auf einem TV bei Hallenlicht kann das zu dunkel werden. Ein
  // Handgriff am Stand statt einer Nacht am Code.
  const hell = new URLSearchParams(location.search).get('hell') === '1'
  const bloom = opts.bloom ?? (hell ? 0.4 : 0.6)
  const vignette = opts.vignette ?? (hell ? 0 : 0.18)
  const desaturate = opts.desaturate ?? 0.1
  const brightness = opts.brightness ?? (hell ? 1.55 : 1.24)
  if (bloom > 0) {
    // Zwei Durchgänge statt einem: ein enger für den harten Kern, ein weiter
    // für den Schleier. Teurer, aber der Unterschied zwischen „glüht" und
    // „strahlt" steckt genau in dieser zweiten Runde.
    cam.postFX.addBloom(0xffffff, 1, 1, 1, bloom * 0.75, 8)
    cam.postFX.addBloom(0xffffff, 2.4, 2.4, 1, bloom * 0.35, 6)
  }
  if (vignette > 0) cam.postFX.addVignette(0.5, 0.52, 0.9, vignette)
  if (desaturate > 0) cam.postFX.addColorMatrix().saturate(-desaturate)
  // Gegenlicht für den Messe-TV: Die Palette ist absichtlich dunkel, das Bild
  // darf es nicht sein. Eine Blende mehr hält Silhouetten und Kantenlicht auch
  // bei Hallenlicht lesbar.
  if (brightness !== 1) cam.postFX.addColorMatrix().brightness(brightness)
  // Leichte Kontrastanhebung ganz am Ende: Bloom hebt die Tiefen mit an,
  // ohne diesen Schritt wird das Bild milchig.
  cam.postFX.addColorMatrix().contrast(0.06)
}

/**
 * Laterne: das Leitlicht der Szene, gebunden an ein Objekt.
 *
 * Läuft jetzt über `licht()` — also mit dreischichtigem Abfall und einer
 * Lichtpfütze auf dem Boden darunter. Der Unterschied ist genau der zwischen
 * „REZI leuchtet" und „REZI beleuchtet den Boden, über den Paul läuft".
 */
export function attachLantern(
  scene: Phaser.Scene,
  target: Phaser.GameObjects.Components.Transform,
  color: number,
  radius = 46,
  alpha = 0.34,
): LichtHandle {
  return licht(scene, {
    ziel: target,
    farbe: color,
    radius,
    staerke: alpha * 1.6,
    depth: 6,
  })
}
