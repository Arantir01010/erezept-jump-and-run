/**
 * TREFFER-BUCHHALTUNG des Lauschers — Phaser-frei und uhrenfrei, damit sie
 * unter Node testbar ist (tools/test/lauscher.test.ts).
 *
 * Die Sichtprüfung („sehe ich dich?") steht in sicht.ts. Hier liegt die Frage
 * danach: „Was passiert, wenn er mich sieht?" Also Abklingzeit zwischen zwei
 * Treffern und die Eskalation der REZI-Tipps.
 *
 * Warum getrennt? Der Phaser-Baustein (Lauscher.ts) soll eine dünne Hülle sein:
 * zeichnen, Sprite bewegen, Schaden auslösen. Jede Entscheidung, die man falsch
 * treffen kann, gehört in getesteten Code.
 */

/** Mindestabstand zwischen zwei Treffern desselben Lauschers. */
export const HIT_COOLDOWN_MS = 900
/** Ab dem zweiten echten Treffer erklärt REZI die Hülle. */
export const TIPP_AB_TREFFER = 2
/** Sperrfrist, damit der Tipp nicht mehrfach hintereinander kommt. */
export const TIPP_COOLDOWN_MS = 6000

export class LauscherLogik {
  private lastHitMs = -Infinity
  private lastTipMs = -Infinity
  private hits = 0

  /** Anzahl echter Treffer (für Tests und Debug-Anzeigen). */
  get treffer(): number {
    return this.hits
  }

  /**
   * Darf JETZT ein Treffer ausgelöst werden?
   * `gesehen` kommt aus `wirdGesehen()` (sicht.ts).
   */
  pruefe(timeMs: number, gesehen: boolean): boolean {
    if (!gesehen) return false
    if (timeMs - this.lastHitMs < HIT_COOLDOWN_MS) return false
    this.lastHitMs = timeMs
    return true
  }

  /**
   * Nach dem Treffer melden, wie viele Bits verloren gingen.
   * `0` bedeutet: Der Spieler war unverwundbar (Blinkphase nach einem Treffer) —
   * das zählt NICHT als Lernerfahrung und löst deshalb keinen Tipp aus.
   *
   * Liefert `true`, wenn REZI jetzt den Hülle-Tipp geben soll.
   */
  melde(timeMs: number, verloreneBits: number): boolean {
    if (verloreneBits <= 0) return false
    this.hits += 1
    if (this.hits < TIPP_AB_TREFFER) return false
    if (timeMs - this.lastTipMs < TIPP_COOLDOWN_MS) return false
    this.lastTipMs = timeMs
    return true
  }

  reset(): void {
    this.lastHitMs = -Infinity
    this.lastTipMs = -Infinity
    this.hits = 0
  }
}
