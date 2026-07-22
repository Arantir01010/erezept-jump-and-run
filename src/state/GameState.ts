/**
 * Zustand eines Spieldurchlaufs. Bewusst ohne Persistenz —
 * nur der Tages-Highscore landet in localStorage (siehe Highscore.ts).
 */

export interface EarnedSeal {
  sealId: string
  levelId: string
}

const POINTS_PER_BIT = 10
const POINTS_PER_SEAL = 1000
const SECURITY_BONUS = 250

class GameState {
  levelIndex = 0
  bits = 0
  score = 0
  seals: EarnedSeal[] = []
  encrypted = false
  runStartMs = 0
  cleanInteractions = 0

  reset(): void {
    this.levelIndex = 0
    this.bits = 0
    this.score = 0
    this.seals = []
    this.encrypted = false
    this.runStartMs = performance.now()
    this.cleanInteractions = 0
  }

  addBits(n: number): void {
    this.bits += n
    this.score += n * POINTS_PER_BIT
  }

  /** Sonic-Prinzip: Treffer kostet ein paar Bits, nie den Fortschritt. */
  loseBits(max: number): number {
    const lost = Math.min(this.bits, max)
    this.bits -= lost
    return lost
  }

  addSeal(sealId: string, levelId: string): void {
    this.seals.push({ sealId, levelId })
    this.score += POINTS_PER_SEAL
  }

  /** Fehlerfreie Sicherheits-Interaktion (Timing-Gate im ersten Anlauf usw.) */
  addSecurityBonus(): void {
    this.cleanInteractions += 1
    this.score += SECURITY_BONUS
  }

  elapsedSeconds(): number {
    return (performance.now() - this.runStartMs) / 1000
  }

  /** Endscreen-Rang als Sicherheitsstufe. */
  rank(): { key: 'bronze' | 'silber' | 'gold'; label: { de: string; en: string } } {
    if (this.cleanInteractions >= 3 && this.bits >= 12) {
      return { key: 'gold', label: { de: 'TI-zertifiziert', en: 'TI certified' } }
    }
    if (this.cleanInteractions >= 1) {
      return { key: 'silber', label: { de: 'Stark verschlüsselt', en: 'Strongly encrypted' } }
    }
    return { key: 'bronze', label: { de: 'Gut geschützt', en: 'Well protected' } }
  }
}

export const gameState = new GameState()
