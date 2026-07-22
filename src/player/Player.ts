import Phaser from 'phaser'
import { GameAction } from '../input/actions'
import { inputManager } from '../input/InputManager'
import { gameState } from '../state/GameState'
import { bitScatter } from '../gfx/effects'
import { PLAYER_TUNING as T } from './PlayerConfig'

export type PlayerState = 'idle' | 'run' | 'jump' | 'fall' | 'duck' | 'hurt'

/**
 * Pixel-Paul. Zustandsmaschine mit Duck-State (eigene Hitbox),
 * Coyote-Time und Jump-Buffering. Kein Tod — Treffer kosten Datenbits.
 */
export class Player extends Phaser.Physics.Arcade.Sprite {
  declare body: Phaser.Physics.Arcade.Body

  state: PlayerState = 'idle'
  respawnPoint = new Phaser.Math.Vector2(0, 0)
  /** Eingaben gesperrt (Cutscenes, Setpieces) — Physik läuft weiter. */
  controlsLocked = false

  private lastGroundedMs = 0
  private jumpBufferedMs = -Infinity
  private invulnUntilMs = 0

  constructor(scene: Phaser.Scene, x: number, y: number) {
    super(scene, x, y, 'player-idle0')
    scene.add.existing(this)
    scene.physics.add.existing(this)
    this.body.setSize(T.bodyWidth, T.bodyHeight)
    this.body.setOffset((this.width - T.bodyWidth) / 2, this.height - T.bodyHeight)
    this.body.setMaxVelocityY(600)
    this.setDepth(10)
    this.respawnPoint.set(x, y)
  }

  get isDucking(): boolean {
    return this.state === 'duck'
  }

  get isInvulnerable(): boolean {
    return this.scene.time.now < this.invulnUntilMs
  }

  update(): void {
    const now = this.scene.time.now
    const onFloor = this.body.blocked.down
    if (onFloor) this.lastGroundedMs = now

    const locked = this.controlsLocked
    const ax = locked ? 0 : inputManager.axisX()
    const wantsDuck = !locked && inputManager.isDown(GameAction.Down) && onFloor
    if (!locked && inputManager.justPressed(GameAction.Jump)) this.jumpBufferedMs = now

    // --- Duck-Hitbox umschalten ---
    const wasDucking = this.isDucking
    const ducking = wantsDuck && this.state !== 'hurt'
    if (ducking && !wasDucking) {
      this.body.setSize(T.bodyWidth, T.duckBodyHeight)
      this.body.setOffset((this.width - T.bodyWidth) / 2, this.height - T.duckBodyHeight)
    } else if (!ducking && wasDucking) {
      this.body.setSize(T.bodyWidth, T.bodyHeight)
      this.body.setOffset((this.width - T.bodyWidth) / 2, this.height - T.bodyHeight)
    }

    // --- Horizontalbewegung ---
    const speed = ducking ? T.runSpeed * T.duckSpeedFactor : T.runSpeed
    const accel = onFloor ? T.accel : T.airAccel
    if (ax !== 0) {
      this.setAccelerationX(ax * accel)
      if (Math.abs(this.body.velocity.x) > speed) this.setVelocityX(Math.sign(this.body.velocity.x) * speed)
      this.setFlipX(ax < 0)
    } else {
      this.setAccelerationX(0)
      this.setDragX(T.drag)
    }

    // --- Springen: Buffer + Coyote ---
    const coyoteOk = now - this.lastGroundedMs <= T.coyoteMs
    const bufferOk = now - this.jumpBufferedMs <= T.jumpBufferMs
    if (bufferOk && coyoteOk && !ducking && this.state !== 'hurt') {
      this.setVelocityY(-T.jumpVelocity)
      this.jumpBufferedMs = -Infinity
      this.lastGroundedMs = -Infinity
    }

    // --- Zustand bestimmen ---
    if (this.state === 'hurt' && now < this.invulnUntilMs - T.hurtInvulnMs + 350) {
      // kurze Hurt-Phase, danach normale Zustände (Blinken läuft weiter)
    } else if (ducking) {
      this.state = 'duck'
    } else if (!onFloor) {
      this.state = this.body.velocity.y < -20 ? 'jump' : 'fall'
    } else if (Math.abs(this.body.velocity.x) > 15) {
      this.state = 'run'
    } else {
      this.state = 'idle'
    }
    this.playAnimForState()

    // Sicherheitsnetz: unter die Karte gefallen (sollte designbedingt nie passieren)
    const worldBottom = this.scene.physics.world.bounds.bottom
    if (this.y > worldBottom + 64) {
      this.setPosition(this.respawnPoint.x, this.respawnPoint.y)
      this.setVelocity(0, 0)
    }
  }

  private playAnimForState(): void {
    const anims: Record<PlayerState, string> = {
      idle: 'player-idle',
      run: 'player-run',
      jump: 'player-jump',
      fall: 'player-fall',
      duck: 'player-duck',
      hurt: 'player-hurt',
    }
    const key = anims[this.state]
    if (this.anims.currentAnim?.key !== key) this.play(key, true)
  }

  setRespawn(x: number, y: number): void {
    this.respawnPoint.set(x, y)
  }

  /**
   * Treffer: Datenbits spritzen weg (Sonic-Prinzip), kurzer Rückstoß, Blinken.
   * Gibt die Zahl verlorener Bits zurück (0 während Unverwundbarkeit).
   */
  hurt(fromX: number): number {
    if (this.isInvulnerable) return 0
    const now = this.scene.time.now
    this.invulnUntilMs = now + T.hurtInvulnMs
    this.state = 'hurt'
    const dir = this.x < fromX ? -1 : 1
    this.setVelocity(dir * T.hurtKnockback, -140)
    this.scene.tweens.add({
      targets: this,
      alpha: { from: 0.25, to: 1 },
      duration: 120,
      repeat: Math.floor(T.hurtInvulnMs / 240),
      yoyo: true,
      onComplete: () => this.setAlpha(1),
    })
    const lost = gameState.loseBits(T.hurtBitsLost)
    if (lost > 0) bitScatter(this.scene, this.x, this.y - 8, Math.min(lost, 6))
    this.scene.game.events.emit('hud:update')
    this.emit('player:hurt', lost)
    return lost
  }
}
