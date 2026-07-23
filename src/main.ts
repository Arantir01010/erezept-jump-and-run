import Phaser from 'phaser'
import { BootScene } from './scenes/BootScene'
import { PreloadScene } from './scenes/PreloadScene'
import { AttractScene } from './scenes/AttractScene'
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
  pixelArt: true,
  roundPixels: true,
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
  scene: [BootScene, PreloadScene, AttractScene, CityScene, GameScene, UIScene, RewardScene],
})

// Lesbare Schrift in JEDER Fenstergröße: pixelArt:true setzt image-rendering:
// pixelated als Inline-Stil auf das Canvas (Phaser, CreateRenderer) — der
// überstimmt jede CSS-Regel. Bei ganzzahliger Skalierung (Messe-TV 1080p = 3x)
// ist Nearest-Neighbor perfekt; bei krummen Faktoren (Browserfenster) zerlegt
// er 11-px-Schrift in ungleiche Blöcke. Deshalb dynamisch: ganzzahlig → knackig
// pixelig, sonst → Browser-Glättung (weich, aber lesbar).
const applyCanvasSmoothing = (): void => {
  const zoom = game.scale.displaySize.width / game.scale.gameSize.width
  const nearInteger = zoom >= 1 && Math.abs(zoom - Math.round(zoom)) < 0.02
  game.canvas.style.imageRendering = nearInteger ? 'pixelated' : 'auto'
}
game.events.once(Phaser.Core.Events.READY, applyCanvasSmoothing)
game.scale.on(Phaser.Scale.Events.RESIZE, applyCanvasSmoothing)

// Debug-/Diagnose-Zugriff (Standaufbau, Tests) — greift nicht ins Spiel ein
;(window as unknown as { __game: Phaser.Game }).__game = game
