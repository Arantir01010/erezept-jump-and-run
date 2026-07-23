import Phaser from 'phaser'
import QRCode from 'qrcode'

/**
 * Offline-QR: qrcode ist gebundelt, kein Netz nötig. Liefert den Texture-Key,
 * sobald die Base64-Textur wirklich im TextureManager angekommen ist.
 *
 * Der Maßstab wird GANZZAHLIG auf targetPx eingepasst und die Textur nativ
 * (1:1, ohne setDisplaySize) gezeichnet: Jedes QR-Modul bleibt gleich breit.
 * Ein Downscale (z. B. 108-px-Textur auf 100 px) würde mit NEAREST ganze
 * Pixelzeilen verschlucken — unsaubere Module gefährden den Handy-Scan.
 */
export async function createQrTexture(
  scene: Phaser.Scene,
  key: string,
  payload: string,
  targetPx = 100,
): Promise<string> {
  const MARGIN = 1 // Ruhezone in Modulen (der weiße Rahmen im Spiel ergänzt den Rest)
  const moduleCount = QRCode.create(payload, { errorCorrectionLevel: 'M' }).modules.size
  const scale = Math.max(1, Math.floor(targetPx / (moduleCount + MARGIN * 2)))
  const dataUrl = await QRCode.toDataURL(payload, {
    margin: MARGIN,
    scale,
    errorCorrectionLevel: 'M',
    color: { dark: '#20242e', light: '#ffffff' },
  })

  return new Promise<string>((resolve) => {
    if (scene.textures.exists(key)) {
      resolve(key)
      return
    }
    const onAdd = (addedKey: string): void => {
      if (addedKey !== key) return
      scene.textures.off(Phaser.Textures.Events.ADD, onAdd)
      resolve(key)
    }
    scene.textures.on(Phaser.Textures.Events.ADD, onAdd)
    scene.textures.addBase64(key, dataUrl)
  })
}
