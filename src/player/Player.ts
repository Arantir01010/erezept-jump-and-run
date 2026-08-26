import Phaser from 'phaser'
import { GameAction } from '../input/actions'
import { inputManager } from '../input/InputManager'
import { gameState } from '../state/GameState'
import { dustPuff } from '../gfx/effects'
import { PLAYER_TUNING as T } from './PlayerConfig'
import { HuelleState, Huelle } from '../state/HuelleState'

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
  /**
   * Hülle-Mechanik. Immer vorhanden (nie null → keine Sonderfälle im Code),
   * aber nur wirksam, wenn das Level sie einschaltet (huelleEnabled).
   */
  readonly huelle = new HuelleState()
  huelleEnabled = false

  private lastGroundedMs = 0
  private jumpBufferedMs = -Infinity
  private invulnUntilMs = 0
  private wasOnFloor = false
  private lastRunDustMs = 0
  /** Squash & Stretch (rein visuell — die Physik-Hitbox bleibt unberührt). */
  private squashTween?: Phaser.Tweens.Tween

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

  /** Von der GameScene pro Frame aufgerufen (nur wenn die Hülle aktiv ist). */
  tickHuelle(deltaMs: number): void {
    if (this.huelleEnabled) this.huelle.tick(deltaMs)
  }

  /** Hülle wechseln (Joystick hoch / Shift). true bei echtem Wechsel. */
  tryToggleHuelle(): boolean {
    if (!this.huelleEnabled || this.controlsLocked) return false
    return this.huelle.toggle(this.scene.time.now).ok
  }

  /** Sehen Lauscher den Spieler? Ohne Hülle-Level immer true. */
  get istSichtbar(): boolean {
    return this.huelleEnabled ? this.huelle.sichtbar : true
  }

  /** Tragen Andock-Plattformen? Ohne Hülle-Level immer true. */
  get istAndockfaehig(): boolean {
    return this.huelleEnabled ? this.huelle.andockfaehig : true
  }

  get huelleZustand(): Huelle {
    return this.huelle.state
  }

  update(): void {
    const now = this.scene.time.now
    const onFloor = this.body.blocked.down
    if (onFloor) this.lastGroundedMs = now

    // Staub-Feedback (rein visuell): Aufsetzen nach Sprung/Fall + Laufschritte
    if (onFloor && !this.wasOnFloor) {
      dustPuff(this.scene, this.x, this.body.bottom, 4)
      this.squashStretch(1.22, 0.82) // Lande-Squash
      // BEWUSST KEIN Kamera-Shake beim Aufsetzen: Er feuert bei jedem Sprung —
      // in einem Jump'n'Run also im Sekundentakt — und wackelt damit das ganze
      // Bild durch (Playtest-Rückmeldung: „rüttelt, mega nervig"). Gewicht
      // vermitteln Squash und Staub; der Shake bleibt den seltenen, großen
      // Momenten vorbehalten (Signatur-Stempel).
    }
    if (onFloor && Math.abs(this.body.velocity.x) > 70 && now - this.lastRunDustMs > 170) {
      this.lastRunDustMs = now
      dustPuff(this.scene, this.x - Math.sign(this.body.velocity.x) * 5, this.body.bottom, 1)
    }
    this.wasOnFloor = onFloor

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
    // Die Hülle wirkt NUR aufs Tempo (Klartext schnell, Verschlüsselt langsam).
    // Sprungkraft und Schwerkraft bleiben bewusst unberührt — sonst würde die
    // Erreichbarkeits-Simulation des Level-Compilers ungültig.
    const huelleFactor = this.huelleEnabled ? this.huelle.speedFactor : 1
    const speed = (ducking ? T.runSpeed * T.duckSpeedFactor : T.runSpeed) * huelleFactor
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
      this.squashStretch(0.84, 1.18) // Absprung-Stretch
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

  /** Kurzer Kadergummi-Impuls (Landung/Absprung) — federt zurück auf 1:1. */
  private squashStretch(sx: number, sy: number): void {
    this.squashTween?.stop()
    this.setScale(sx, sy)
    this.squashTween = this.scene.tweens.add({
      targets: this,
      scaleX: 1,
      scaleY: 1,
      duration: 160,
      ease: 'Back.easeOut',
    })
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
    // Verstreute Bits sind ECHTE Objekte und wieder einsammelbar (GameScene
    // hört auf dieses Event) — Anti-Softlock: Das Sammelziel darf durch
    // Treffer nie unerreichbar werden. NICHT durch bitScatter ersetzen,
    // das ist nur Optik und macht Level mit knappem Puffer unschaffbar.
    if (lost > 0) this.scene.events.emit('bits:verstreut', { x: this.x, y: this.y - 8, count: lost })
    this.scene.game.events.emit('hud:update')
    this.emit('player:hurt', lost)
    return lost
  }
}
