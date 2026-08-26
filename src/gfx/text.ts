import Phaser from 'phaser'

/**
 * Zentraler Text-Helfer: Alle Schriften laufen hier durch.
 *
 * SCHRIFTWAHL. Vorher stand hier Courier New. Eine Schreibmaschinenschrift
 * signalisiert „Terminal, 1985" stärker als jedes Sprite — sie war der
 * größte einzelne Retro-Anteil im Bild. Jetzt ist eine Groteske Standard.
 *
 * Bewusst KEIN Webfont: Der Messe-Build läuft offline, ein nachzuladender
 * Font wäre ein Einzelfehlerpunkt am Stand. Segoe UI liegt auf jedem
 * Windows-Rechner; die Kette dahinter fängt Mac und Linux ab.
 *
 * Monospace bleibt für DIAGNOSE-Anzeigen (F8-Kalibrierung, F9-Auswertung):
 * Dort stehen Zahlen untereinander, und dafür ist gleiche Zeichenbreite
 * schlicht das richtige Werkzeug.
 *
 * Zwei Stellschrauben gegen Schrift-Matsch bleiben:
 * 1. setResolution(3) — der Text wird intern höher aufgelöst gerendert.
 * 2. LINEAR-Filter auf der Text-Textur.
 */

export const SANS = '"Segoe UI", Inter, Roboto, system-ui, -apple-system, "Helvetica Neue", Arial, sans-serif'
export const MONO = 'Consolas, "SF Mono", "DejaVu Sans Mono", "Courier New", monospace'

export interface TextOpts {
  color?: string
  bold?: boolean
  bg?: string
  stroke?: string
  strokeThickness?: number
  align?: 'left' | 'center' | 'right'
  wrapWidth?: number
  padding?: { x: number; y: number }
  /** 'mono' nur für Diagnose-Anzeigen mit Zahlenkolonnen. */
  font?: 'sans' | 'mono'
  /** Buchstabenabstand — bei Versalien und kleinen Graden sinnvoll. */
  spacing?: number
}

export function addText(
  scene: Phaser.Scene,
  x: number,
  y: number,
  content: string,
  size = 11,
  opts: TextOpts = {},
): Phaser.GameObjects.Text {
  const style: Phaser.Types.GameObjects.Text.TextStyle = {
    fontFamily: opts.font === 'mono' ? MONO : SANS,
    fontSize: `${size}px`,
    // Groteske trägt bei kleinen Graden mit 600 besser als mit 700 —
    // fett läuft in 8-px-Schrift zu.
    fontStyle: opts.bold === false ? '400' : '600',
    color: opts.color ?? '#ffffff',
  }
  if (opts.bg) style.backgroundColor = opts.bg
  if (opts.stroke) {
    style.stroke = opts.stroke
    style.strokeThickness = opts.strokeThickness ?? 3
  }
  if (opts.align) style.align = opts.align
  if (opts.wrapWidth) style.wordWrap = { width: opts.wrapWidth }
  if (opts.padding) style.padding = opts.padding

  const text = scene.add.text(x, y, content, style)
  if (opts.spacing) text.setLetterSpacing(opts.spacing)
  // Nur unter WebGL: Der Canvas-Renderer verrechnet Text-Resolution falsch
  // (Riesen-Text) und kennt keine Textur-Filter — dort bleibt Resolution 1.
  if (scene.game.renderer.type === Phaser.WEBGL) {
    text.setResolution(3)
    text.texture.setFilter(Phaser.Textures.FilterMode.LINEAR)
  }
  return text
}
