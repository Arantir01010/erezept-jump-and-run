import Phaser from 'phaser'

/**
 * Zentraler Text-Helfer: Alle UI-Schriften laufen hier durch, damit sie überall
 * lesbar sind. Zwei Stellschrauben gegen Schrift-Matsch:
 * 1. setResolution(4) — der Text wird intern 4-fach aufgelöst gerendert.
 * 2. LINEAR-Filter nur für die Text-Textur — pixelArt:true stellt global NEAREST
 *    ein (richtig für Sprites), Schrift wird damit beim Skalieren aber unlesbar.
 * Fett ist Standard: Bold-Monospace bleibt auch bei kleinen Graden lesbar.
 */
export interface TextOpts {
  color?: string
  bold?: boolean
  bg?: string
  stroke?: string
  strokeThickness?: number
  align?: 'left' | 'center' | 'right'
  wrapWidth?: number
  padding?: { x: number; y: number }
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
    fontFamily: '"Courier New", Consolas, monospace',
    fontSize: `${size}px`,
    fontStyle: opts.bold === false ? 'normal' : 'bold',
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
  // Nur unter WebGL: Der Canvas-Renderer verrechnet Text-Resolution falsch
  // (Riesen-Text) und kennt keine Textur-Filter — dort bleibt Resolution 1.
  if (scene.game.renderer.type === Phaser.WEBGL) {
    text.setResolution(4)
    text.texture.setFilter(Phaser.Textures.FilterMode.LINEAR)
  }
  return text
}
