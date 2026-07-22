import type { GameConfig } from '../level/schema'

/**
 * Was am Ende im QR-Code steckt. Prototyp: statischer Gewinn-Code (Variante A).
 * Variante B (generierte Einmal-Codes mit Prüfziffer, Abgleich am Automaten)
 * bekommt eine eigene Implementierung dieses Interfaces — siehe Konzept.
 */
export interface RewardCodeProvider {
  payload(): string
}

export class StaticCodeProvider implements RewardCodeProvider {
  constructor(private readonly staticPayload: string) {}
  payload(): string {
    return this.staticPayload
  }
}

export function createRewardCodeProvider(config: GameConfig): RewardCodeProvider {
  if (config.ending.type === 'generated') {
    console.warn('[reward] ending.type "generated" ist Ausbaustufe — fallback auf statischen Code')
  }
  return new StaticCodeProvider(config.ending.staticPayload)
}
