import { Mechanic, MechanicHost, TiledObj, tiledProps } from './Mechanic'
import { isKnownMechanicType } from './typeIds'

type MechanicCtor = new (host: MechanicHost, obj: TiledObj, params: Record<string, unknown>) => Mechanic

const registry = new Map<string, MechanicCtor>()

export function registerMechanic(type: string, ctor: MechanicCtor): void {
  registry.set(type, ctor)
}

/**
 * Baustein für ein Tiled-Objekt erzeugen. Unbekannter Typ wird im Kiosk-Betrieb
 * übersprungen und geloggt — das Spiel darf auf der Messe nie crashen.
 */
export function spawnMechanic(host: MechanicHost, obj: TiledObj): Mechanic | null {
  const type = (obj.type as string) || ''
  if (!type || type === 'spawn') return null // Spawnpunkt behandelt die Szene selbst
  if (!isKnownMechanicType(type)) {
    console.warn(`[mechanics] Unbekannter Objekt-Typ "${type}" in Level "${host.level.id}" bei x=${obj.x}, y=${obj.y} — übersprungen`)
    return null
  }
  const ctor = registry.get(type)
  if (!ctor) {
    console.warn(`[mechanics] Typ "${type}" ist bekannt, aber nicht registriert — übersprungen`)
    return null
  }
  const levelParams = (host.level.mechanics[type] ?? {}) as Record<string, unknown>
  const params = { ...levelParams, ...tiledProps(obj) }
  const mechanic = new ctor(host, obj, params)
  mechanic.spawn()
  return mechanic
}
