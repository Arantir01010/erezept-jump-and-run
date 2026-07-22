import Phaser from 'phaser'
import QRCode from 'qrcode'

/**
 * Offline-QR: qrcode ist gebundelt, kein Netz nötig. Liefert den Texture-Key,
 * sobald die Base64-Textur wirklich im TextureManager angekommen ist.
 */
export async function createQrTexture(scene: Phaser.Scene, key: string, payload: string): Promise<string> {
  const dataUrl = await QRCode.toDataURL(payload, {
    margin: 1,
    scale: 4,
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
