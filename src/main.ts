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

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  width: 640,
  height: 360,
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

// Debug-/Diagnose-Zugriff (Standaufbau, Tests) — greift nicht ins Spiel ein
;(window as unknown as { __game: Phaser.Game }).__game = game
