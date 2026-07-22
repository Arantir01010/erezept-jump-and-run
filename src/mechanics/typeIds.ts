/**
 * Alle bekannten Mechanik-Typ-IDs — Phaser-frei, damit tools/validate-levels.ts
 * sie unter Node prüfen kann. Registry (registry.ts) muss jede ID bedienen.
 */
export const MECHANIC_TYPE_IDS = [
  // Basisbausteine
  'spawn',
  'gate',
  'collectible',
  'checkpoint',
  'info-sign',
  'door-exit',
  'moving-platform',
  'hazard',
  'deco',
  // Design-Module (Sicherheits-Mechaniken)
  'timing-gate',
  'deny-enemy',
  'stamp-exit',
  'stillstand-podest',
  'krypto-dusche',
  'tube-scroll',
  // Ausbaustufe (Stubs im Prototyp)
  'pruef-scanner',
  'rechte-tueren',
  'finale-sprint',
  'vervollstaendigen',
] as const

export type MechanicTypeId = (typeof MECHANIC_TYPE_IDS)[number]

export function isKnownMechanicType(type: string): type is MechanicTypeId {
  return (MECHANIC_TYPE_IDS as readonly string[]).includes(type)
}
