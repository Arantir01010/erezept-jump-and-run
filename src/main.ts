import Phaser from 'phaser'
import { BootScene } from './scenes/BootScene'
import { PreloadScene } from './scenes/PreloadScene'
import { AttractScene } from './scenes/AttractScene'
import { IntroScene } from './scenes/IntroScene'
import { WissenScene } from './scenes/WissenScene'
import { CityScene } from './scenes/CityScene'
import { GameScene } from './scenes/GameScene'
import { UIScene } from './scenes/UIScene'
import { RewardScene } from './scenes/RewardScene'
import { installCrashGuard } from './kiosk/CrashGuard'
import { PLAYER_TUNING } from './player/PlayerConfig'

installCrashGuard()

// Kiosk-Modus: Cursor aus, Kontextmenü aus (start-messe.bat ruft ?kiosk=1 auf)
if (new URLSearchParams(location.search).get('kiosk') === '1') {
  document.body.classList.add('kiosk')
}
document.addEventListener('contextmenu', (e) => e.preventDefault())

// ?testloop=1: Game-Loop über setTimeout statt requestAnimationFrame —
// läuft auch ohne sichtbares Fenster weiter (automatisierte Tests/QA)
const params = new URLSearchParams(location.search)

// Interne Auflösung 1920×1080: Die Welt wird per Kamera-Zoom 3× vergrößert
// (Pixel-Art bleibt blockig), Texte/QR rendern dagegen nativ scharf in Full HD.
// Layout und Physik bleiben im 640×360-Design-Raum (src/gfx/view.ts).
const game = new Phaser.Game({
  // ?renderer=canvas: 2D-Fallback für Rechner ohne brauchbares WebGL (Not-Option am Stand)
  type: params.get('renderer') === 'canvas' ? Phaser.CANVAS : Phaser.AUTO,
  parent: 'game',
  width: 1920,
  height: 1080,
  fps: params.get('testloop') === '1' ? { forceSetTimeOut: true, target: 60 } : undefined,
  backgroundColor: '#06090f',
  // Vektorgrafik statt Bitmap-Skalierung: Gelände, Hintergrund und HUD werden
  // als Formen gezeichnet und deshalb pro Frame in die Kameramatrix gerechnet —
  // bei Zoom 3 gibt es keine Klötze, weil es keine Quellpixel gibt.
  // Die verbliebenen Pixel-Art-Texturen holen sich ihren NEAREST-Filter
  // gezielt in der TextureFactory zurück.
  antialias: true,
  antialiasGL: true,
  roundPixels: false,
  physics: {
    default: 'arcade',
    arcade: {
      gravity: { x: 0, y: PLAYER_TUNING.gravityY },
      debug: new URLSearchParams(location.search).get('debug') === '2',
    },
  },
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  scene: [BootScene, PreloadScene, AttractScene, IntroScene, WissenScene, CityScene, GameScene, UIScene, RewardScene],
})

// Früher musste hier je nach Skalierungsfaktor zwischen „pixelated" und „auto"
// umgeschaltet werden, weil pixelArt:true image-rendering:pixelated als
// Inline-Stil erzwang und 11-px-Schrift bei krummen Faktoren zerlegte.
// Mit Vektorgrafik entfällt das Problem: Glättung ist in JEDER Fenstergröße
// richtig — am Messe-TV (1080p, 1:1) ändert sie ohnehin nichts.
const applyCanvasSmoothing = (): void => {
  game.canvas.style.imageRendering = 'auto'
}
game.events.once(Phaser.Core.Events.READY, applyCanvasSmoothing)
game.scale.on(Phaser.Scale.Events.RESIZE, applyCanvasSmoothing)

// Debug-/Diagnose-Zugriff (Standaufbau, Tests) — greift nicht ins Spiel ein
;(window as unknown as { __game: Phaser.Game }).__game = game
