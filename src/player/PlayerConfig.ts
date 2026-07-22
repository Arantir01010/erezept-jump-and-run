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
  hurtInvulnMs: 1100,
  hurtKnockback: 130,
  hurtBitsLost: 5,
  bodyWidth: 10,
  bodyHeight: 21,
  duckBodyHeight: 13,
}
