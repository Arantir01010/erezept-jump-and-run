import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { assist } from '../state/Assist'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { addGlow, hitstop } from '../gfx/effects'
import { klang } from '../audio/klang'
import { PLAYER_TUNING } from '../player/PlayerConfig'
import { t } from '../i18n'
import type { LText } from '../i18n'
import { veredele } from '../gfx/vektor'

/**
 * Signatur-Stempel-Setpiece (Levelausgang Kartenterminal):
 * Dr. Pixels Stempel fährt rhythmisch auf und ab. Blauer Knopf, wenn der
 * Stempel oben wartet → WUMM, REZI trägt das Siegel, Level geschafft.
 * Fachbezug: Die qualifizierte elektronische Signatur (eHBA) macht das Rezept gültig.
 */
export class StampExit extends Mechanic {
  private stamp!: Phaser.GameObjects.Image
  private zone!: Phaser.Geom.Rectangle
  private topY = 0
  private bottomY = 0
  private done = false
  private hintShown = false
  private cycleTween?: Phaser.Tweens.Tween
  private lastTipMs = -Infinity

  /** Robust statt Callback-Buchhaltung: oben = Annahme-Fenster. */
  private get stampIsUp(): boolean {
    return this.stamp.y <= this.topY + (this.bottomY - this.topY) * 0.35
  }

  spawn(): void {
    const { x, y, w, h } = objCenter(this.obj)
    this.zone = new Phaser.Geom.Rectangle(this.obj.x ?? 0, this.obj.y ?? 0, w || 48, h || 48)
    this.topY = y - (h || 48) / 2 - 10
    this.bottomY = y + (h || 48) / 2 - 12
    this.stamp = this.host.scene.add.image(x, this.topY, 'stempel').setDepth(6)
    veredele(this.host.scene, this.stamp)
    // Goldenes Glimmen an der Warteposition: „hier passiert der Signatur-Moment"
    addGlow(this.host.scene, x, this.topY, 0xffd75e, 15, { alpha: 0.22, depth: 5 })
    this.startCycle()
  }

  private startCycle(): void {
    // Assist: Fehlversuche verlängern die Wartephase oben — das Fenster wächst
    const holdMs = 700 * assist.slowdown(`stamp-${this.obj.id}`)
    this.cycleTween = this.host.scene.tweens.add({
      targets: this.stamp,
      y: this.bottomY,
      delay: holdMs,
      duration: 260,
      ease: 'Cubic.easeIn',
      yoyo: true,
      hold: 200,
      onComplete: () => {
        if (!this.done) this.startCycle()
      },
    })
  }

  update(): void {
    if (this.done) return
    const p = this.host.player
    const inZone = this.zone.contains(p.x, p.y)
    if (!inZone) return

    if (!this.hintShown) {
      this.hintShown = true
      const hint = this.params['hint'] as LText | undefined
      if (hint) this.host.rezi.say(t(hint))
    }

    if (inputManager.justPressed(GameAction.Action)) {
      if (this.stampIsUp) this.succeed()
      else {
        // Falscher Takt: kurzer Shake, auf den nächsten Hub warten — keine Strafe
        const key = `stamp-${this.obj.id}`
        assist.fail(key)
        this.host.scene.cameras.main.shake(80, 0.002)
        // Ab dem 2. Fehlgriff erklärt REZI das Timing (Assist verlängert parallel die Wartephase)
        const now = this.host.scene.time.now
        if (assist.failCount(key) >= 2 && now - this.lastTipMs > 6000) {
          this.lastTipMs = now
          const btn = inputManager.hasGamepad() ? 'BLAU' : 'Taste E'
          this.host.rezi.say(
            this.paramText('failHint', {
              de: `Tipp: Warte, bis der Stempel OBEN kurz stehen bleibt — dann ${btn}!`,
              en: `Tip: wait until the stamp rests at the TOP — then ${inputManager.hasGamepad() ? 'BLUE' : 'E'}!`,
            }),
          )
        }
      }
    }
  }

  private succeed(): void {
    this.done = true
    this.cycleTween?.stop()
    const p = this.host.player
    p.controlsLocked = true
    this.host.scene.tweens.add({
      targets: this.stamp,
      y: p.y - 18,
      duration: 160,
      ease: 'Cubic.easeIn',
      onComplete: () => {
        this.host.scene.cameras.main.shake(120, 0.004)
        // Der große Moment des Levels: Standbild + Stempel-Klang
        hitstop(this.host.scene, PLAYER_TUNING.hitstopMs)
        klang.siegel()
        if (assist.wasClean(`stamp-${this.obj.id}`)) gameState.addSecurityBonus()
        this.host.rezi.say(t(this.host.level.station.reziText))
        this.host.scene.tweens.add({ targets: this.stamp, y: this.topY, duration: 400, delay: 250 })
        this.host.scene.time.delayedCall(1400, () => this.host.completeLevel())
      },
    })
  }
}
registerMechanic('stamp-exit', StampExit)
