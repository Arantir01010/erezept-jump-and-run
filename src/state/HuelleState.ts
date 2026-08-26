/**
 * HÜLLE — die Kernmechanik (KAPSEL 2.1).
 *
 * Drei Zustände mit JE MEHREREN gleichzeitigen Konsequenzen (die Lehre aus
 * Ikaruga/Outland: ein Toggle trägt nur, wenn er offensiv UND defensiv wirkt):
 *
 *   Klartext       — schnell, kann andocken, aber für „Lauscher" SICHTBAR
 *   Verschlüsselt  — langsam, kann NICHT andocken, dafür unsichtbar
 *   VAU            — schnell UND unsichtbar UND andockfähig, aber nur im Feld
 *                    und (optional) nur solange die Sitzung frisch ist
 *
 * Fachliche Leitplanken (KAPSEL 1.4 — Vereinfachungsfehler vermeiden):
 *   • Die VAU ist KEIN Tunnel, sondern ein Raum, in dem im Klartext gearbeitet
 *     werden darf, ohne dass Betreiber mitlesen → deshalb innen schnell (wie
 *     Klartext) und trotzdem unsichtbar.
 *   • Verschlüsselung ≠ Signatur: Diese Datei kennt bewusst KEINE Signatur.
 *     Signieren bleibt eine eigene Aktion (src/mechanics/StampExit.ts).
 *   • Läuft die Sitzung ab, wird der Kontextschlüssel verworfen → der Spieler
 *     fällt auf KLARTEXT zurück (sichtbar!), nicht auf „verschlüsselt".
 *
 * Phaser-frei und uhrenfrei (alle Zeiten kommen als Parameter) — damit unter
 * Node vollständig testbar (tools/test/huelle.test.ts).
 */

export enum Huelle {
  Klartext = 'klartext',
  Verschluesselt = 'verschluesselt',
  Vau = 'vau',
}

/** Alle Zustände in Anzeige-Reihenfolge (HUD, Tests, Validierung). */
export const HUELLE_STATES: readonly Huelle[] = [Huelle.Klartext, Huelle.Verschluesselt, Huelle.Vau]

export interface HuelleEffects {
  /** Faktor auf die Laufgeschwindigkeit. */
  speedFactor: number
  /** Sehen „Lauscher" den Spieler? */
  sichtbar: boolean
  /** Tragen Andock-Plattformen den Spieler? */
  andockfaehig: boolean
}

/**
 * Tuning der drei Zustände.
 *
 * WICHTIG (Level-Validierung): Sprungkraft und Schwerkraft sind in ALLEN
 * Zuständen identisch — nur das Tempo unterscheidet sich. Damit bleibt die
 * Erreichbarkeits-Simulation des Level-Compilers gültig; sie rechnet für
 * Hülle-Level zusätzlich mit dem langsamsten Tempo (tools/lib/compile.ts,
 * MAX_DX_FOR_RISE_SLOW). Wer hier den Sprung verändert, muss dort nachziehen.
 */
export const HUELLE_TUNING: Record<Huelle, HuelleEffects> = {
  [Huelle.Klartext]: { speedFactor: 1, sichtbar: true, andockfaehig: true },
  [Huelle.Verschluesselt]: { speedFactor: 0.8, sichtbar: false, andockfaehig: false },
  [Huelle.Vau]: { speedFactor: 1, sichtbar: false, andockfaehig: true },
}

/** Der langsamste Tempo-Faktor über alle Zustände (Level-Validierung). */
export const SLOWEST_SPEED_FACTOR: number = Math.min(
  ...HUELLE_STATES.map((s) => HUELLE_TUNING[s].speedFactor),
)

export type HuelleChangeReason = 'reset' | 'toggle' | 'enter-vau' | 'leave-vau' | 'session-expired'

export interface HuelleChange {
  from: Huelle
  to: Huelle
  reason: HuelleChangeReason
}

export type ToggleBlocked = 'vau' | 'cooldown' | 'locked'

export interface ToggleResult {
  ok: boolean
  /** Warum der Wechsel nicht ging (für REZI-Tipps / HUD). */
  blocked?: ToggleBlocked
  state: Huelle
}

const DEFAULT_COOLDOWN_MS = 150

/**
 * Zustandsmaschine der Hülle. Eine Instanz pro Level (GameScene).
 * Alle Zeitangaben in Millisekunden, immer von außen hereingegeben.
 */
export class HuelleState {
  private current: Huelle = Huelle.Klartext
  /** Hülle, die vor dem Betreten der VAU getragen wurde. */
  private beforeVau: Huelle = Huelle.Klartext
  private lastToggleMs = -Infinity
  private ttlMs = 0
  private leftMs = 0
  private listeners: ((c: HuelleChange) => void)[] = []

  /** Wechsel gesperrt (Setpiece/Cutscene) — VAU-Logik läuft weiter. */
  locked = false

  constructor(
    /** Mindestabstand zwischen zwei Wechseln (Anti-Spam, Arcade-Prellen). */
    public toggleCooldownMs: number = DEFAULT_COOLDOWN_MS,
  ) {}

  // ------------------------------------------------------------------ Lesen

  get state(): Huelle {
    return this.current
  }

  get effects(): HuelleEffects {
    return HUELLE_TUNING[this.current]
  }

  get sichtbar(): boolean {
    return this.effects.sichtbar
  }

  get andockfaehig(): boolean {
    return this.effects.andockfaehig
  }

  get speedFactor(): number {
    return this.effects.speedFactor
  }

  get inVau(): boolean {
    return this.current === Huelle.Vau
  }

  /** Restlaufzeit der VAU-Sitzung in ms (0 = keine Sitzung / unbegrenzt). */
  get vauMsLeft(): number {
    return this.inVau && this.ttlMs > 0 ? Math.max(0, this.leftMs) : 0
  }

  /** Frische der Sitzung: 1 = frisch, 0 = abgelaufen. Ohne Ablauf immer 1. */
  get vauRatio(): number {
    if (!this.inVau || this.ttlMs <= 0) return 1
    return Math.max(0, Math.min(1, this.leftMs / this.ttlMs))
  }

  /** Hat die aktuelle VAU-Sitzung überhaupt ein Ablaufdatum? */
  get vauExpires(): boolean {
    return this.inVau && this.ttlMs > 0
  }

  // ------------------------------------------------------------------ Ändern

  reset(start: Huelle = Huelle.Klartext, nowMs = 0): void {
    const from = this.current
    this.current = start
    this.beforeVau = start === Huelle.Vau ? Huelle.Klartext : start
    this.lastToggleMs = nowMs - this.toggleCooldownMs
    this.ttlMs = 0
    this.leftMs = 0
    this.locked = false
    this.emit({ from, to: start, reason: 'reset' })
  }

  canToggle(nowMs: number): boolean {
    if (this.locked || this.inVau) return false
    return nowMs - this.lastToggleMs >= this.toggleCooldownMs
  }

  /** Klartext ⇄ Verschlüsselt. In der VAU bewusst wirkungslos. */
  toggle(nowMs: number): ToggleResult {
    if (this.locked) return { ok: false, blocked: 'locked', state: this.current }
    if (this.inVau) return { ok: false, blocked: 'vau', state: this.current }
    if (nowMs - this.lastToggleMs < this.toggleCooldownMs) {
      return { ok: false, blocked: 'cooldown', state: this.current }
    }
    const from = this.current
    this.current = from === Huelle.Klartext ? Huelle.Verschluesselt : Huelle.Klartext
    this.beforeVau = this.current
    this.lastToggleMs = nowMs
    this.emit({ from, to: this.current, reason: 'toggle' })
    return { ok: true, state: this.current }
  }

  /**
   * VAU-Feld betreten. `ttlMs = 0` bedeutet: Sitzung läuft nicht ab
   * (Level 14 „Die VAU"); `ttlMs > 0` ist die Kontextschlüssel-Variante
   * (Level 15 „Kontextschlüssel").
   */
  enterVau(_nowMs: number, ttlMs = 0): boolean {
    if (this.inVau) {
      // Erneutes Betreten frischt die Sitzung auf, wechselt aber nichts.
      if (ttlMs > 0) {
        this.ttlMs = ttlMs
        this.leftMs = ttlMs
      }
      return false
    }
    const from = this.current
    this.beforeVau = from
    this.current = Huelle.Vau
    this.ttlMs = Math.max(0, ttlMs)
    this.leftMs = this.ttlMs
    this.emit({ from, to: Huelle.Vau, reason: 'enter-vau' })
    return true
  }

  /** VAU-Feld regulär verlassen: Der Spieler trägt wieder seine alte Hülle. */
  leaveVau(_nowMs = 0): boolean {
    if (!this.inVau) return false
    const from = this.current
    this.current = this.beforeVau === Huelle.Vau ? Huelle.Klartext : this.beforeVau
    this.ttlMs = 0
    this.leftMs = 0
    this.emit({ from, to: this.current, reason: 'leave-vau' })
    return true
  }

  /** Kontext-Anker: Sitzung wieder auf volle Laufzeit setzen. */
  refreshSession(_nowMs = 0): boolean {
    if (!this.vauExpires) return false
    this.leftMs = this.ttlMs
    return true
  }

  /**
   * Zeit vergeht. Läuft die Sitzung ab, verfällt der Kontextschlüssel und der
   * Spieler steht wieder im KLARTEXT (sichtbar) — das ist die Lehre.
   */
  tick(deltaMs: number): void {
    if (!this.vauExpires) return
    this.leftMs -= deltaMs
    if (this.leftMs > 0) return
    const from = this.current
    this.current = Huelle.Klartext
    this.beforeVau = Huelle.Klartext
    this.ttlMs = 0
    this.leftMs = 0
    this.emit({ from, to: this.current, reason: 'session-expired' })
  }

  // ------------------------------------------------------------------ Events

  onChange(listener: (c: HuelleChange) => void): () => void {
    this.listeners.push(listener)
    return () => {
      this.listeners = this.listeners.filter((l) => l !== listener)
    }
  }

  private emit(change: HuelleChange): void {
    for (const l of [...this.listeners]) l(change)
  }
}
