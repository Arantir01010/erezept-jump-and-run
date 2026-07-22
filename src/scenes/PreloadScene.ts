import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import { generateAllTextures, createAnimations } from '../gfx/TextureFactory'

/**
 * Lädt die Tilemaps der Playlist und erzeugt alle prozeduralen Texturen.
 * (Config ist zu diesem Zeitpunkt bereits validiert — BootScene.)
 */
export class PreloadScene extends Phaser.Scene {
  constructor() {
    super('Preload')
  }

  preload(): void {
    for (const level of configService.levels) {
      this.load.tilemapTiledJSON(`map-${level.id}`, `${import.meta.env.BASE_URL}${level.tilemap}`)
    }
    this.load.on(Phaser.Loader.Events.FILE_LOAD_ERROR, (file: Phaser.Loader.File) => {
      console.error(`[preload] Datei nicht ladbar: ${file.src}`)
    })
  }

  create(): void {
    generateAllTextures(this, configService.themes)
    createAnimations(this)
    this.scene.start('Attract')
  }
}
