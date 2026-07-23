import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { assist } from '../state/Assist'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { addGlow } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'

const FAIL_FLASH_MS = 450

/**
 * Timing-Gate („PIN-Schleuse"): N Lichter — es pulsiert IMMER das nächste
 * fällige Licht (kein Weiterwandern bei verpasstem Fenster: verpasst = einfach
 * auf den nächsten Puls desselben Schritts warten, ohne Strafe). Blauer Knopf
 * im Pulsfenster bestätigt; Druck außerhalb = sichtbare rote Phase + Reset.
 * Fachliches Framing aus dem Level-JSON (Dr. Pixel signiert mit eHBA + Arzt-PIN).
 * Barrierefreiheit: aktives Licht zusätzlich GRÖSSER, nicht nur andersfarbig.
 * Assist: Fehlversuche verlangsamen die Sequenz sichtbar.
 */
export class TimingGate extends Mechanic {
  private zone!: Phaser.Geom.Rectangle
  private lights: Phaser.GameObjects.Arc[] = []
  private steps = 4
  private stepMs = 900
  private windowRatio = 0.45
  private progress = 0
  private running = false
  private done = false
  private stepStartMs = 0
  /** Bis zu diesem Zeitpunkt bleibt das rote Fehler-Feedback stehen. */
  private failUntilMs = 0
  private hintShown = false
  private lastTipMs = -Infinity
  private activeGlow?: Phaser.GameObjects.Image

  spawn(): void {
    const { x, y, w, h } = objCenter(this.obj)
    this.steps = this.param<number>('steps', 4)
    this.stepMs = this.param<number>('stepMs', 900)
    this.zone = new Phaser.Geom.Rectangle(this.obj.x ?? 0, this.obj.y ?? 0, w || 48, h || 48)

    // Anrempel-Tipp am verknüpften Tor: sagt, WIE es aufgeht
    const gate = this.linkedGate()
    if (gate) {
      gate.openHint = this.paramText('gateHint', {
        de: 'Das Tor ist zu! Schaff erst die PIN-Schleuse: im Takt der pulsierenden Lichter drücken.',
        en: 'The gate is locked! Pass the PIN check first: press on the beat of the pulsing lights.',
      })
    }

    const spread = 16
    const startX = x - ((this.steps - 1) * spread) / 2
    for (let i = 0; i < this.steps; i++) {
      const light = this.host.scene.add.arc(startX + i * spread, y - (h || 48) / 2 - 12, 4, 0, 360, false, 0x3a4152, 1)
      light.setStrokeStyle(1, 0x8a93a8, 1)
      light.setDepth(6)
      this.lights.push(light)
    }
    // Halo hinter dem gerade fälligen Licht — der Takt wird auch peripher lesbar
    this.activeGlow = addGlow(this.host.scene, startX, this.lights[0]?.y ?? y, 0xffd75e, 11, {
      alpha: 0.55,
      depth: 5,
      pulse: false,
    })
    this.activeGlow.setVisible(false)
  }

  private get slowMs(): number {
    return this.stepMs * assist.slowdown(`timing-gate-${this.obj.id}`)
  }

  private get playerInZone(): boolean {
    const p = this.host.player
    return this.zone.contains(p.x, p.y)
  }

  update(time: number): void {
    if (this.done) return

    // Rote Fehler-Phase: Feedback sichtbar stehen lassen, Eingaben ignorieren
    if (time < this.failUntilMs) return

    if (!this.running && this.playerInZone) {
      this.running = true
      this.progress = 0
      this.stepStartMs = time
      if (!this.hintShown) {
        this.hintShown = true
        const hint = this.params['hint'] as LText | undefined
        if (hint) this.host.rezi.say(t(hint))
      }
    }
    if (!this.running) return
    if (!this.playerInZone) {
      // Weggelaufen: Sequenz pausiert ohne Strafe
      this.running = false
      this.renderLights(false)
      return
    }

    const stepElapsed = time - this.stepStartMs
    const inWindow = stepElapsed < this.slowMs * this.windowRatio

    if (stepElapsed >= this.slowMs) {
      // Fenster verpasst → DERSELBE Schritt pulsiert erneut, kein Reset, keine Strafe
      this.stepStartMs = time
    }

    if (inputManager.justPressed(GameAction.Action)) {
      if (inWindow) {
        this.progress += 1
        this.flashLight(this.progress - 1, 0x7fd07f)
        if (this.progress >= this.steps) return this.succeed()
        this.stepStartMs = time
      } else {
        this.failFlash(time)
        return
      }
    }

    this.renderLights(inWindow)
  }

  /** Falscher Moment: alle Lichter rot, kurze Pause, dann Neustart der Sequenz. */
  private failFlash(time: number): void {
    const key = `timing-gate-${this.obj.id}`
    assist.fail(key)
    this.progress = 0
    this.failUntilMs = time + FAIL_FLASH_MS
    this.stepStartMs = time + FAIL_FLASH_MS
    this.activeGlow?.setVisible(false)

    // Ab dem 2. Fehlversuch erklärt REZI den Trick konkret (Assist macht parallel langsamer)
    if (assist.failCount(key) >= 2 && time - this.lastTipMs > 6000) {
      this.lastTipMs = time
      const btn = inputManager.hasGamepad() ? 'BLAU' : 'Taste E'
      this.host.rezi.say(
        this.paramText('failHint', {
          de: `Tipp: Drück ${btn} genau dann, wenn das gelbe Licht groß aufleuchtet!`,
          en: `Tip: press ${inputManager.hasGamepad() ? 'BLUE' : 'E'} right when the yellow light glows big!`,
        }),
      )
    }
    this.lights.forEach((light, i) => {
      light.setFillStyle(0xff4040, 1)
      light.setRadius(4)
      this.host.scene.tweens.add({ targets: light, scale: { from: 1.5, to: 1 }, duration: 200, delay: i * 30 })
    })
  }

  private renderLights(pulseActive: boolean): void {
    this.lights.forEach((light, i) => {
      if (i < this.progress) {
        light.setFillStyle(0x7fd07f, 1)
        light.setRadius(4)
      } else if (i === this.progress && pulseActive) {
        light.setFillStyle(0xffd75e, 1)
        light.setRadius(6) // größer, nicht nur andersfarbig (Farbfehlsichtigkeit)
      } else {
        light.setFillStyle(0x3a4152, 1)
        light.setRadius(4)
      }
    })
    // Halo folgt dem aktiven Licht
    const active = this.lights[this.progress]
    if (this.activeGlow && active) {
      this.activeGlow.setPosition(active.x, active.y).setVisible(pulseActive && this.running && !this.done)
    }
  }

  private flashLight(index: number, color: number): void {
    const light = this.lights[index]
    if (!light) return
    light.setFillStyle(color, 1)
    this.host.scene.tweens.add({ targets: light, scale: { from: 1.6, to: 1 }, duration: 200 })
  }

  private succeed(): void {
    this.done = true
    this.running = false
    this.activeGlow?.setVisible(false)
    this.lights.forEach((l) => {
      l.setFillStyle(0x7fd07f, 1)
      l.setRadius(4)
    })
    if (assist.wasClean(`timing-gate-${this.obj.id}`)) gameState.addSecurityBonus()
    this.linkedGate()?.open()
    this.host.scene.game.events.emit('hud:update')
  }
}
registerMechanic('timing-gate', TimingGate)
