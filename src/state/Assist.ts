/**
 * Assist-Eskalation (Basisstufe des Prototyps):
 * Scheitert eine Sicherheits-Interaktion wiederholt, wird sie sichtbar
 * langsamer — Framing: „Die TI sichert dich zusätzlich ab", nie „du bist schlecht".
 * Ausbaustufen (TI-Schutzschild, Express-Autopilot) siehe Konzept.
 */
class Assist {
  private fails: Record<string, number> = {}

  reset(): void {
    this.fails = {}
  }

  fail(key: string): void {
    this.fails[key] = (this.fails[key] ?? 0) + 1
  }

  failCount(key: string): number {
    return this.fails[key] ?? 0
  }

  /** Multiplikator für Zeitfenster/Sequenzdauern: 1 → 1.3 → 1.6 (Deckel). */
  slowdown(key: string): number {
    const f = this.failCount(key)
    if (f >= 2) return 1.6
    if (f === 1) return 1.3
    return 1
  }

  /** War die Interaktion im ersten Anlauf fehlerfrei? (Sicherheits-Bonus) */
  wasClean(key: string): boolean {
    return this.failCount(key) === 0
  }
}

export const assist = new Assist()
