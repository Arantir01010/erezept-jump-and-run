import Phaser from 'phaser'
import type { LevelConfig } from '../level/schema'
import type { Player } from '../player/Player'
import type { Rezi } from '../actors/Rezi'
import type { Gate } from './basics'

/**
 * Schnittstelle, die die GameScene den Mechanik-Bausteinen bereitstellt.
 * (Interface statt direkter Import der Szene → kein Zyklus.)
 */
export interface MechanicHost {
  scene: Phaser.Scene
  player: Player
  rezi: Rezi
  level: LevelConfig
  /** Benannte Tore (Objekt-Name in Tiled), die Mechaniken öffnen können. */
  gates: Map<string, Gate>
  /** Kollision Spieler ↔ solider Körper registrieren. */
  addSolid(body: Phaser.Physics.Arcade.Image): void
  /** Overlap Spieler ↔ Sensor registrieren. */
  addSensor(
    body: Phaser.Physics.Arcade.Image,
    onOverlap: (player: Player) => void,
  ): Phaser.Physics.Arcade.Collider
  /** Tube-Modus: Kamera pausiert, solange irgendein Lock true liefert. */
  registerScrollLock(lock: () => boolean): void
  /** Level erfolgreich beendet (Siegel, Übergang übernimmt die Szene). */
  completeLevel(): void
}

export type TiledObj = Phaser.Types.Tilemaps.TiledObject

/** Tiled-Objekt-Properties ([{name, value}]) als flaches Objekt. */
export function tiledProps(obj: TiledObj): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  const props = obj.properties as { name: string; value: unknown }[] | undefined
  if (Array.isArray(props)) for (const p of props) out[p.name] = p.value
  return out
}

/** Mittelpunkt eines Tiled-Rechteck-Objekts (x/y sind dort oben links). */
export function objCenter(obj: TiledObj): { x: number; y: number; w: number; h: number } {
  const w = obj.width ?? 0
  const h = obj.height ?? 0
  return { x: (obj.x ?? 0) + w / 2, y: (obj.y ?? 0) + h / 2, w, h }
}

export abstract class Mechanic {
  constructor(
    protected host: MechanicHost,
    protected obj: TiledObj,
    /** level.mechanics[typ] + Tiled-Objekt-Properties (Objekt gewinnt). */
    protected params: Record<string, unknown>,
  ) {}

  abstract spawn(): void

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  update(_time: number, _delta: number): void {}

  destroy(): void {}

  protected param<T>(key: string, fallback: T): T {
    const v = this.params[key]
    return v === undefined ? fallback : (v as T)
  }

  /** Benanntes Tor aus den Objekt-/Level-Parametern auflösen. */
  protected linkedGate(): Gate | undefined {
    const name = this.param<string>('gate', '')
    if (!name) return undefined
    const gate = this.host.gates.get(name)
    if (!gate) console.warn(`[mechanics] Tor "${name}" nicht gefunden (Objekt bei x=${this.obj.x})`)
    return gate
  }
}
