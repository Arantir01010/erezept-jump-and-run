import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { showDenyStamp, addGlow } from '../gfx/effects'
import { protokoll } from '../state/Protokoll'
import { telemetry } from '../telemetry/Telemetry'
import { patrouille, wirdGesehen, type Blick } from './sicht'
import { LauscherLogik } from './lauscherLogik'
import { inputManager } from '../input/InputManager'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * LAUSCHER (KAPSEL Level 3 „Lauscher") — sieht ausschließlich KLARTEXT.
 *
 * Fachlich: Unverschlüsselte Daten sind auf dem Transportweg mitlesbar.
 * Verschlüsselt oder in der VAU ist der Spieler unsichtbar — die TI schützt,
 * nicht der Reflex.
 *
 * Markenregel bleibt gewahrt: Der Spieler kämpft nicht und stirbt nicht.
 * Erwischt der Lauscher Klartext, kostet das Datenbits und der Vorfall landet
 * im Zugriffsprotokoll („du wurdest gesehen") — das ist die Währung des
 * Siegels „Lückenloses Protokoll".
 *
 * Die Sichtprüfung selbst liegt in sicht.ts (Phaser-frei, vollständig getestet).
 */
export class Lauscher extends Mechanic {
  private auge!: Phaser.GameObjects.Sprite
  private kegel!: Phaser.GameObjects.Graphics
  private baseX = 0
  private patrolTo = 0
  private speed = 30
  private reach = 110
  private spread = 22
  private pauseMs = 600
  private dir: -1 | 1 = 1
  /** Abklingzeiten und Tipp-Eskalation (getestet, Phaser-frei). */
  private logik = new LauscherLogik()
  /** Merkt den letzten Kegel-Zustand, damit nur bei Änderung neu gezeichnet wird. */
  private kegelAktiv: boolean | null = null

  spawn(): void {
    const { x, y } = objCenter(this.obj)
    this.baseX = x
    this.speed = this.param<number>('speed', 30)
    this.reach = this.param<number>('reach', 110)
    this.spread = this.param<number>('spread', 22)
    this.pauseMs = this.param<number>('pauseMs', 600)
    this.patrolTo = x + this.param<number>('patrol', 0)

    this.kegel = this.host.scene.add.graphics().setDepth(3)
    this.auge = this.host.scene.add.sprite(x, y, 'lauscher-0').setDepth(6)
    if (this.host.scene.anims.exists('lauscher-blink')) this.auge.play('lauscher-blink')
    // Warmes Eigenlicht: der Lauscher ist auch im Augenwinkel sichtbar
    addGlow(this.host.scene, x, y, 0xff8a3a, 12, { alpha: 0.3, depth: 5 })
  }

  private get blick(): Blick {
    return { x: this.auge.x, y: this.auge.y, dir: this.dir, reach: this.reach, spread: this.spread }
  }

  update(time: number): void {
    // Patrouille: deterministisch aus der Zeit berechnet (sicht.ts) — kein
    // Zustand, kein Zufall, damit das Timing lernbar bleibt.
    if (Math.abs(this.patrolTo - this.baseX) >= 1) {
      const p = patrouille(time, this.baseX, this.patrolTo, this.speed, this.pauseMs)
      this.auge.x = p.x
      this.dir = p.dir
    }
    this.auge.setFlipX(this.dir < 0)

    const player = this.host.player
    const gesehen = wirdGesehen(this.blick, {
      x: player.x,
      y: player.y,
      sichtbar: player.istSichtbar,
    })

    this.zeichneKegel(gesehen)
    if (this.logik.pruefe(time, gesehen)) this.erwischt(time)
  }

  /** Der Moment der Lehre: „unverschlüsselt = mitlesbar". */
  private erwischt(time: number): void {
    const player = this.host.player
    const verloren = player.hurt(this.auge.x)
    protokoll.markGesehen(this.host.level.id, time, t(this.paramLText('akteur', { de: 'Lauscher' })))
    telemetry.note('gesehen', time)
    showDenyStamp(
      this.host.scene,
      this.auge.x,
      this.auge.y - 20,
      t(this.paramLText('seenText', { de: 'MITGELESEN!', en: 'READ!' })),
    )
    // Die Logik entscheidet, ob der Tipp fällig ist (Treffer ohne Bitverlust
    // zählen nicht — der Spieler war noch in der Unverwundbarkeit).
    if (!this.logik.melde(time, verloren)) return
    // Ein noetiger Tipp ist ein Verstaendnisproblem — genau das wollen wir sehen
    telemetry.note('tipp', time, 'huelleHint')
    const wie = inputManager.hasGamepad() ? 'Joystick HOCH' : 'Shift (oder Pfeil hoch)'
    this.host.rezi.say(
      this.paramText('huelleHint', {
        de: `Tipp: ${wie} = verschlüsseln — dann kann dich niemand mitlesen!`,
        en: 'Tip: press UP to encrypt — then nobody can read you!',
      }),
    )
  }

  /** LText-Parameter mit Fallback holen (ohne ihn schon zu lokalisieren). */
  private paramLText(key: string, fallback: LText): LText {
    const v = this.params[key] as LText | undefined
    return v && typeof v === 'object' && 'de' in v ? v : fallback
  }

  /**
   * Sichtkegel zeichnen. Erfasst er den Spieler, wird er rot UND deutlich
   * dichter — der Zustand hängt nie allein an der Farbe (Barrierefreiheit,
   * KAPSEL 3.3). Neu gezeichnet wird nur bei Zustandswechsel oder Bewegung.
   */
  private zeichneKegel(aktiv: boolean): void {
    const bewegt = Math.abs(this.patrolTo - this.baseX) >= 1
    if (!bewegt && this.kegelAktiv === aktiv) return
    this.kegelAktiv = aktiv
    const g = this.kegel
    g.clear()
    const x = this.auge.x
    const y = this.auge.y
    const end = x + this.dir * this.reach
    g.fillStyle(aktiv ? 0xff4040 : 0xffb347, aktiv ? 0.3 : 0.12)
    g.beginPath()
    g.moveTo(x, y - 2)
    g.lineTo(end, y - this.spread)
    g.lineTo(end, y + this.spread)
    g.lineTo(x, y + 2)
    g.closePath()
    g.fillPath()
  }

  destroy(): void {
    this.kegel.destroy()
  }
}
registerMechanic('lauscher', Lauscher)
