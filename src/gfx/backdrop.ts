import Phaser from 'phaser'
import type { Theme } from '../level/schema'

/**
 * Hintergrund pro Level: Farbverlauf + Silhouetten-Parallax aus dem Theme.
 * Bewusst Graphics statt Assets — Custom-Art ersetzt das später 1:1.
 */
export function drawBackdrop(scene: Phaser.Scene, theme: Theme, worldWidth: number, worldHeight: number): void {
  const cam = scene.cameras.main
  const g = scene.add.graphics().setScrollFactor(0).setDepth(0)
  g.fillGradientStyle(
    Phaser.Display.Color.HexStringToColor(theme.skyTop).color,
    Phaser.Display.Color.HexStringToColor(theme.skyTop).color,
    Phaser.Display.Color.HexStringToColor(theme.skyBottom).color,
    Phaser.Display.Color.HexStringToColor(theme.skyBottom).color,
    1,
  )
  g.fillRect(0, 0, cam.width, cam.height)

  // Silhouetten (Server-Türme/Häuserblöcke) mit leichtem Parallax
  const sil = scene.add.graphics().setScrollFactor(0.25).setDepth(0)
  const color = Phaser.Display.Color.HexStringToColor(theme.skyBottom).color
  const detail = Phaser.Display.Color.HexStringToColor(theme.detail).color
  const span = Math.max(worldWidth * 0.3 + cam.width, cam.width * 2)
  let x = 0
  let i = 0
  while (x < span) {
    const w = 30 + ((i * 37) % 50)
    const h = 60 + ((i * 53) % 120)
    sil.fillStyle(color, 0.55)
    sil.fillRect(x, worldHeight - h - 40, w, h + 40)
    sil.fillStyle(detail, 0.25)
    for (let wy = 0; wy < 3; wy++) {
      sil.fillRect(x + 6, worldHeight - h - 30 + wy * 24, 4, 4)
      sil.fillRect(x + w - 10, worldHeight - h - 18 + wy * 24, 4, 4)
    }
    x += w + 14 + ((i * 17) % 22)
    i += 1
  }
}
