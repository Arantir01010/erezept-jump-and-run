import Phaser from 'phaser'

/**
 * Design- vs. Render-Auflösung:
 * Gestaltet wird alles in 640×360 („Design-Raum" — Tiles, Layouts, Physik).
 * Gerendert wird intern in 1920×1080 (VIEW_ZOOM 3): Die Kameras zoomen 3-fach,
 * Pixel-Art bleibt dadurch knackig-blockig (NEAREST), aber Schrift und QR-Code
 * werden mit ihrer 4-fachen Textur-Auflösung nativ scharf gezeichnet —
 * auf dem Messe-TV (1080p, 1:1) genauso wie in jedem Browserfenster.
 */
export const DESIGN_W = 640
export const DESIGN_H = 360
export const VIEW_ZOOM = 3

/**
 * Kamera einer „Screen-Szene" (Attract, City, Reward, UI, Boot) auf den
 * Design-Raum ausrichten. Liefert die Design-Maße für das Layout zurück.
 */
export function setupDesignCamera(scene: Phaser.Scene): { W: number; H: number } {
  const cam = scene.cameras.main
  cam.setZoom(VIEW_ZOOM)
  cam.centerOn(DESIGN_W / 2, DESIGN_H / 2)
  return { W: cam.displayWidth, H: cam.displayHeight }
}
