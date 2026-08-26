/**
 * Ein Import lädt den kompletten Baukasten (Side-Effect-Registrierung).
 * 'tube-scroll' ist bewusst KEIN Baustein: Der Auto-Scroll gehört der Kamera
 * (GameScene liest level.mechanics['tube-scroll'] direkt).
 */
import './basics'
import './TimingGate'
import './DenyEnemy'
import './StampExit'
import './StillstandPodest'
import './KryptoDusche'
import './Lauscher'
import './AndockPlattform'
import './VauFeld'
import './KontextAnker'
import './Karten'
import './stubs'

export { spawnMechanic, registerMechanic } from './registry'
export { Mechanic, type MechanicHost, type TiledObj } from './Mechanic'
export { Gate } from './basics'
