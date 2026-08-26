import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { protokoll } from '../state/Protokoll'
import { configService } from '../level/ConfigService'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { baueFinaleAnzeige } from './finaleLogik'
import { addGlow, destroyGlow } from '../gfx/effects'
import { addText } from '../gfx/text'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * DIE LETZTE TÜR (KAPSEL v0.1, Welt 5) — die Pointe des Spiels als Mechanik.
 *
 * Vier Welten lang hat der Spieler gelernt, Hindernisse zu überwinden. Diese
 * Tür überwindet er nicht: Kein Schlüssel passt, kein Sprung hilft, der blaue
 * Knopf wird höflich abgewiesen. Stattdessen erscheint sein eigenes
 * Zugriffsprotokoll — jeder Moment, in dem er sich gezeigt hat. Dann, nach
 * einem Moment der Stille, öffnet die Versicherte. Nicht er.
 *
 * Die Botschaft ohne einen Satz Erklärung: Die ganze Architektur existiert
 * nicht, um Daten zu bewegen — sie existiert, damit EINE PERSON die Kontrolle
 * behält (Datensouveränität, KAPSEL 1.4: ePA-Rechte korrekt darstellen).
 *
 * Ablauf: wartet → Spieler kommt an → Protokoll erscheint Zeile für Zeile →
 * Stille → Freigabe → Tür hebt sich → Durchgehen beendet das Level.
 * Was gezeigt wird, entscheidet finaleLogik.ts (Phaser-frei, getestet).
 */

const WARTE_FALLBACK: LText = {
  de: 'Hier endet mein Weg. Jetzt entscheidet sie.',
  en: 'This is where my path ends. Now she decides.',
}
const DENY_FALLBACK: LText = {
  de: 'Kein Schlüssel öffnet diese Tür. Sie gehört nicht dir.',
  en: 'No key opens this door. It is not yours.',
}
const FREIGABE_FALLBACK: LText = {
  de: 'Freigegeben — von ihr.',
  en: 'Released — by her.',
}
const LUECKENLOS_FALLBACK: LText = {
  de: 'Sie sieht: Niemand hat mitgelesen.',
  en: 'She sees: nobody read along.',
}

/** Zeitmaße der Sequenz — zusammen unter ~8 s (Messebetrieb). */
const ZEILE_MS = 550
const STILLE_MS = 1800
const OEFFNEN_MS = 700

export class LetzteTuer extends Mechanic {
  private tuer!: Phaser.Physics.Arcade.Image
  private licht?: Phaser.GameObjects.Image
  private zone!: Phaser.Geom.Rectangle
  private phase: 'wartet' | 'protokoll' | 'offen' = 'wartet'
  private hintShown = false
  private lastDenyMs = -Infinity

  spawn(): void {
    const { x, y, w, h } = objCenter(this.obj)
    this.tuer = this.host.scene.physics.add.staticImage(x, y, 'door') as unknown as Phaser.Physics.Arcade.Image
    this.tuer.setDisplaySize(20, h || 48)
    ;(this.tuer.body as Phaser.Physics.Arcade.StaticBody).setSize(20, h || 48)
    this.tuer.refreshBody()
    this.tuer.setDepth(5)
    this.host.addSolid(this.tuer)
    // Rotes Statuslicht wie am Gate: „zu" — aber hier gibt es keinen Öffner.
    this.licht = addGlow(this.host.scene, x, y - (h || 48) / 2 + 4, 0xff5050, 8, { alpha: 0.5, depth: 6 })
    // Annäherungszone LINKS vor der Tür
    this.zone = new Phaser.Geom.Rectangle((this.obj.x ?? 0) - (w || 48) - 32, (this.obj.y ?? 0) - 16, (w || 48) + 32, (h || 48) + 32)
  }

  update(): void {
    const p = this.host.player
    if (this.phase === 'offen') return
    if (!this.zone.contains(p.x, p.y)) return

    if (!this.hintShown) {
      this.hintShown = true
      this.host.rezi.say(this.paramText('warteText', WARTE_FALLBACK), 3600)
      // Der Moment beginnt, sobald der Spieler ankommt — Warten IST die Mechanik.
      this.host.scene.time.delayedCall(2400, () => this.zeigeProtokoll())
    }

    // Der blaue Knopf wird abgewiesen — freundlich, aber unmissverständlich.
    if (this.phase === 'wartet' && inputManager.justPressed(GameAction.Action)) {
      const now = this.host.scene.time.now
      if (now - this.lastDenyMs > 2500) {
        this.lastDenyMs = now
        this.host.scene.tweens.add({ targets: this.tuer, x: this.tuer.x + 2, duration: 50, yoyo: true, repeat: 2 })
        this.host.rezi.say(this.paramText('denyText', DENY_FALLBACK))
      }
    }
  }

  /** Das Zugriffsprotokoll des ganzen Durchlaufs, Zeile für Zeile. */
  private zeigeProtokoll(): void {
    if (this.phase !== 'wartet') return
    this.phase = 'protokoll'
    const scene = this.host.scene
    const cam = scene.cameras.main

    const anzeige = baueFinaleAnzeige(protokoll.entries, (levelId) => {
      const lvl = configService.levels.find((l) => l.id === levelId)
      return lvl ? t(lvl.station.name) : levelId
    })

    // Zeilen erscheinen mittig im Bild, im festen Band unter dem HUD —
    // derselbe Ort, an dem das Spiel immer spricht.
    const texte: Phaser.GameObjects.Text[] = []
    const baseX = cam.worldView.x + cam.displayWidth / 2
    const baseY = cam.worldView.y + 60
    anzeige.zeilen.forEach((zeile, i) => {
      scene.time.delayedCall(i * ZEILE_MS, () => {
        const text = addText(scene, baseX, baseY + i * 14, zeile, 10, {
          color: anzeige.lueckenlos ? '#7fd07f' : '#cfe0ff',
          bg: '#06090f',
        }).setOrigin(0.5, 0).setDepth(70).setAlpha(0)
        scene.tweens.add({ targets: text, alpha: 1, duration: 250 })
        texte.push(text)
      })
    })

    const nachZeilen = anzeige.zeilen.length * ZEILE_MS
    if (anzeige.lueckenlos) {
      scene.time.delayedCall(nachZeilen + 400, () => {
        this.host.rezi.say(this.paramText('lueckenlosText', LUECKENLOS_FALLBACK), 3000)
      })
    }

    // Stille. Dann entscheidet sie.
    scene.time.delayedCall(nachZeilen + STILLE_MS, () => {
      this.oeffne(texte)
    })
  }

  private oeffne(texte: Phaser.GameObjects.Text[]): void {
    this.phase = 'offen'
    const scene = this.host.scene

    // Licht springt auf Grün — dieselbe Sprache wie jedes Tor, nur dass
    // diesmal niemand am Stand einen Öffner gefunden hat: Es war nie einer da.
    if (this.licht) {
      scene.tweens.killTweensOf(this.licht)
      this.licht.setTint(0x7fd07f).setAlpha(0.8)
      scene.tweens.add({
        targets: this.licht, alpha: 0, duration: 1200, delay: 600,
        onComplete: () => destroyGlow(scene, this.licht),
      })
    }
    this.host.rezi.say(this.paramText('freigabeText', FREIGABE_FALLBACK), 3200)

    const body = this.tuer.body as Phaser.Physics.Arcade.StaticBody
    body.enable = false
    scene.tweens.add({
      targets: this.tuer,
      y: this.tuer.y - (this.tuer.displayHeight - 6),
      duration: OEFFNEN_MS,
      ease: 'Cubic.easeOut',
    })
    for (const text of texte) {
      scene.tweens.add({ targets: text, alpha: 0, duration: 900, delay: 1200, onComplete: () => text.destroy() })
    }

    // Durchgehen beendet das Level: Die Kontrolle kommt genau dann zurück,
    // wenn sie gewährt wurde.
    const { x, y, h } = objCenter(this.obj)
    const sensor = scene.physics.add.staticImage(x + 20, y, 'datenbit') as unknown as Phaser.Physics.Arcade.Image
    sensor.setVisible(false)
    sensor.body!.setSize(16, h || 48)
    this.host.addSensor(sensor, () => this.host.completeLevel())
  }
}
registerMechanic('letzte-tuer', LetzteTuer)
