/**
 * Zentrale Tuning-Werte für das Spielgefühl — hier stellen, nicht im Code suchen.
 * Coyote-Time und Jump-Buffering sind messe-entscheidend: verzeihende Sprünge.
 */
export const PLAYER_TUNING = {
  runSpeed: 130,
  duckSpeedFactor: 0.45,
  accel: 1600,
  airAccel: 1100,
  drag: 1800,
  jumpVelocity: 335,
  gravityY: 1000,
  coyoteMs: 90,
  jumpBufferMs: 140,
  /**
   * Sprungkurve (src/player/sprungphysik.ts) — Faktoren auf gravityY:
   * Loslassen im Steigen beendet den Sprung früher (variable Sprunghöhe),
   * am Scheitel schwebt Paul bei gehaltener Taste kurz, Fallen wirkt
   * schwerer als Steigen (Mario ≈ 2×, hier bewusst moderat).
   * ACHTUNG: fallGravityFactor verkürzt reale Sprungweiten — die
   * MAX_DX-Konstanten in tools/lib/compile.ts sind dagegen nachgerechnet
   * (tools/test/sprungfeel.test.ts erzwingt die Deckung).
   */
  lowJumpGravityFactor: 2.0,
  apexGravityFactor: 0.55,
  apexWindow: 40,
  fallGravityFactor: 1.4,
  /** Kanten-Korrektur: Kopf-Bonk bis zu so viele px neben der Kante wird umgeleitet. */
  cornerCorrectionPx: 5,
  /** Hitstop: eingefrorene Physik-Zeit bei Treffer/Stempel (Wucht ohne Wackeln). */
  hitstopMs: 70,
  hurtInvulnMs: 1100,
  hurtKnockback: 130,
  hurtBitsLost: 5,
  bodyWidth: 10,
  bodyHeight: 21,
  duckBodyHeight: 13,
}
