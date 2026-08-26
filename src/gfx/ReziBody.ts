import Phaser from 'phaser'

/**
 * REZIs Vektorkörper: dunkle Kapsel mit leuchtender Kontur und Rezept-Kreuz.
 *
 * Ausgelagert, damit Spiel, Stadt und Titelbildschirm dieselbe REZI zeigen —
 * der Titelbildschirm setzt sie als eigenständige Sprite ein, nicht als
 * Rezi-Instanz. Zwei verschiedene REZIs im selben Spiel fallen sofort auf.
 */
export const REZI_MINT = 0x8fffe4

export function zeichneReziKoerper(scene: Phaser.Scene): Phaser.GameObjects.Graphics {
  const g = scene.add.graphics()
  g.fillStyle(0x08211d, 1)
  g.fillRoundedRect(-9, -9, 18, 18, 6)
  g.lineStyle(1.1, REZI_MINT, 0.95)
  g.strokeRoundedRect(-9, -9, 18, 18, 6)
  // Glanzkante oben — macht aus der Fläche eine Karte
  g.fillStyle(0xffffff, 0.16)
  g.fillRoundedRect(-7, -7, 14, 5, { tl: 4, tr: 4, bl: 4, br: 4 })
  // Augen
  g.fillStyle(0xdff4ff, 0.95)
  g.fillCircle(-3.1, -2.6, 1.15)
  g.fillCircle(3.1, -2.6, 1.15)
  // Rezept-Kreuz
  g.fillStyle(REZI_MINT, 0.9)
  g.fillRoundedRect(-1.1, 1.4, 2.2, 6, 0.9)
  g.fillRoundedRect(-3.5, 3.6, 7, 2.2, 0.9)
  return g
}
