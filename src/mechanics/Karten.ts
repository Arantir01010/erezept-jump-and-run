import Phaser from 'phaser'
import { Mechanic, objCenter } from './Mechanic'
import { registerMechanic } from './registry'
import { gameState } from '../state/GameState'
import { telemetry } from '../telemetry/Telemetry'
import { assist } from '../state/Assist'
import { inputManager } from '../input/InputManager'
import { GameAction } from '../input/actions'
import { kartenState, Karte, KARTEN_INFO } from '../state/KartenState'
import type { SteckResultat } from '../state/KartenState'
import { parseKarten, kartenListe, terminalId, STECK_MELDUNG, istZurueckweisung } from './kartenLeserLogik'
import { addGlow, destroyGlow, collectSparkle, showDenyStamp } from '../gfx/effects'
import { t } from '../i18n'
import type { LText } from '../i18n'

/**
 * KARTEN STECKEN — Zusatzmechanik 1 aus KAPSEL 2.1, Paket B2 (die Bausteine).
 *
 * Zwei Objekte, die zusammengehören:
 *   `karte`        — der Ausweis liegt im Level und wird aufgesammelt
 *   `kartenleser`  — das Terminal, an dem er steckt und ein Tor öffnet
 *
 * „Verbindet Bewegung mit Identität": Der Weg durch das Level hängt nicht mehr
 * nur daran, ob man springen kann, sondern daran, WER man ist.
 *
 * Die Zustandsmaschine liegt in src/state/KartenState.ts (Paket B1), die
 * Entscheidungen in kartenLeserLogik.ts — hier steht nur Darstellung und
 * Eingabe. Alles Prüfbare ist damit ohne Browser testbar.
 */

// ---------------------------------------------------------------- Karten-Fund

/**
 * Ein Ausweis, der im Level liegt. Aufsammeln kostet nichts und geht nie
 * verloren: Ein Ausweis bleibt beim Besitzer (KartenState.nimm()).
 *
 * Bewusst KEIN Sammelziel: Karten zählen nicht als Prüfsummen und öffnen keine
 * Tür-Ausgänge. Sie sind Identität, keine Währung.
 */
export class KartenFund extends Mechanic {
  spawn(): void {
    const { x, y } = objCenter(this.obj)
    const karte = this.karteAusParam()
    if (!karte) {
      console.warn(`[mechanics] karte ohne gültigen Parameter "karte" bei x=${this.obj.x} — übersprungen`)
      return
    }

    const sprite = this.host.scene.physics.add.staticImage(x, y, `karte-${karte}`) as unknown as Phaser.Physics.Arcade.Image
    sprite.setDepth(4)
    // Goldener Schimmer: Ausweise sollen sich von den cyanfarbenen Prüfsummen
    // deutlich unterscheiden — verschiedene Dinge sehen verschieden aus.
    const glow = addGlow(this.host.scene, x, y, 0xffd75e, 10, { alpha: 0.3, depth: 3 })
    this.host.scene.tweens.add({
      targets: [sprite, glow],
      y: y - 3,
      duration: 1100,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    })

    const collider = this.host.addSensor(sprite, () => {
      collider.destroy()
      sprite.destroy()
      destroyGlow(this.host.scene, glow)
      kartenState.nimm(karte)
      telemetry.note('karte-gefunden', this.host.scene.time.now, karte)
      collectSparkle(this.host.scene, x, y)
      this.host.rezi.say(this.paramText('hint', this.fundText(karte)))
      this.host.scene.game.events.emit('hud:update')
    })
  }

  private karteAusParam(): Karte | undefined {
    return parseKarten(this.param<string>('karte', ''))[0]
  }

  /** Was REZI beim Fund sagt — nennt die Karte UND wofür sie steht. */
  private fundText(karte: Karte): LText {
    const info = KARTEN_INFO[karte]
    return {
      de: `${info.kurz} gefunden — deine Identität als ${info.wer}.`,
      en: `Found the ${info.kurz} — your identity as ${info.wer}.`,
    }
  }
}
registerMechanic('karte', KartenFund)

// ---------------------------------------------------------------- Kartenleser

const LESER_HINT: LText = {
  de: 'Ein Kartenterminal — steck deine Karte: TI-Aktion drücken.',
  en: 'A card terminal — insert your card: press the TI action.',
}

/**
 * Das Terminal. Blauer Knopf in der Zone = „Karte stecken".
 *
 * Zwei Entscheidungen, die das Spielgefühl tragen:
 *
 * 1. **Automatische Kartenwahl.** Am echten Terminal steht „Karte stecken",
 *    nicht „wähle Karte 2 von 3" — deshalb `steckePassende()`. Der Spieler
 *    denkt über den WEG nach, nicht über ein Menü.
 *
 * 2. **Verlassen zieht die Karte.** Ein Terminal hat genau einen Schlitz. Wer
 *    weggeht, nimmt seinen Ausweis mit — das ist so selbstverständlich, dass
 *    es keine Erklärung braucht, und hält den nächsten Schlitz frei, ohne dass
 *    der Spieler je „ziehen" lernen muss.
 *
 * Das einmal geöffnete Tor bleibt offen: Die Sitzung hat stattgefunden und war
 * berechtigt. „Ziehen beendet den Zugriff sofort" (KAPSEL 1.4) heißt, dass
 * danach kein WEITERER Zugriff möglich ist — nicht, dass Geschehenes zurückrollt.
 */
export class KartenLeser extends Mechanic {
  private zone!: Phaser.Geom.Rectangle
  private id = ''
  private erlaubt: Karte[] = []
  private schlitzLicht?: Phaser.GameObjects.Image
  private done = false
  private hintShown = false
  private lastTryMs = -Infinity

  spawn(): void {
    const { x, y, w, h } = objCenter(this.obj)
    this.zone = new Phaser.Geom.Rectangle(this.obj.x ?? 0, this.obj.y ?? 0, w || 48, h || 48)
    this.id = terminalId(this.obj.name, this.obj.id)
    this.erlaubt = parseKarten(this.params['karten'])
    if (this.erlaubt.length === 0) {
      // Ein Leser ohne erlaubte Karte wäre eine Sackgasse. Der Compiler fängt
      // das ab Paket B3 ab; bis dahin ist die Warnung die Rückfallebene.
      console.warn(`[mechanics] kartenleser "${this.id}" akzeptiert keine Karte (Parameter "karten") — Tor bliebe zu`)
    }

    this.host.scene.add.image(x, y, 'kartenleser').setDepth(6)
    this.schlitzLicht = addGlow(this.host.scene, x, y - 6, 0xffd75e, 10, { alpha: 0.35, depth: 5 })

    // Tube-Modus: Der Tunnel wartet, bis die Identität geprüft ist
    this.host.registerScrollLock(() => {
      if (this.done) return false
      const view = this.host.scene.cameras.main.worldView
      return view.width > 0 && view.x + view.width * 0.7 >= x
    })

    // Anrempel-Tipp am Tor sagt, WIE es aufgeht — inklusive der Karte, die zählt
    const gate = this.linkedGate()
    if (gate) {
      const liste = kartenListe(this.erlaubt)
      gate.openHint = this.paramText('gateHint', {
        de: `Das Tor prüft deine Identität — steck ${liste || 'deine Karte'} am Terminal.`,
        en: `The gate checks your identity — insert ${liste || 'your card'} at the terminal.`,
      })
    }
  }

  update(): void {
    const p = this.host.player
    const drin = this.zone.contains(p.x, p.y)

    if (!drin) {
      // Weggegangen: Ausweis mitgenommen, der Schlitz ist wieder frei.
      if (kartenState.istGestecktAn(this.id)) kartenState.zieh()
      return
    }

    if (!this.hintShown) {
      this.hintShown = true
      if (!this.done) this.host.rezi.say(this.paramText('hint', LESER_HINT))
    }

    if (!this.done && inputManager.justPressed(GameAction.Action)) this.versuche()
  }

  private versuche(): void {
    const now = this.host.scene.time.now
    if (now - this.lastTryMs < 250) return // Arcade-Hämmern nicht als Fehlversuch werten
    this.lastTryMs = now

    const resultat = kartenState.steckePassende(this.id, this.erlaubt)
    if (resultat === 'ok') this.gelungen()
    else this.abgelehnt(resultat)
  }

  private gelungen(): void {
    this.done = true
    const scene = this.host.scene
    const { x, y } = objCenter(this.obj)

    // Schlitzlicht springt auf Grün: „Sitzung offen" ohne ein Wort
    if (this.schlitzLicht) {
      scene.tweens.killTweensOf(this.schlitzLicht)
      this.schlitzLicht.setTint(0x7fd07f).setAlpha(0.75)
    }
    collectSparkle(scene, x, y - 4)

    telemetry.note('karte-gesteckt', scene.time.now, kartenState.gesteckt ?? undefined)
    if (assist.wasClean(this.id)) gameState.addSecurityBonus()
    this.host.rezi.say(t(this.host.level.station.reziText))
    this.linkedGate()?.open()
    scene.game.events.emit('hud:update')
  }

  private abgelehnt(resultat: Exclude<SteckResultat, 'ok'>): void {
    assist.fail(this.id)
    const scene = this.host.scene
    const { x, y } = objCenter(this.obj)
    // Der Grund gehört ins Ereignis: „falsche Karte" heißt, der Spieler hält
    // eine Rolle für austauschbar — das ist etwas ganz anderes als „noch nicht
    // gefunden" und braucht eine andere Konsequenz im Leveldesign.
    telemetry.note('karte-abgelehnt', scene.time.now, resultat)

    if (istZurueckweisung(resultat)) {
      // Nur die echte Zurückweisung durch die TI bekommt den Stempel.
      showDenyStamp(scene, x, y - 20, this.paramText('denyText', { de: 'ZUGRIFF VERWEIGERT', en: 'ACCESS DENIED' }))
    }
    this.linkedGate()?.shake()
    this.host.rezi.say(this.paramText(`${resultat}Hint`, STECK_MELDUNG[resultat]))
  }
}
registerMechanic('kartenleser', KartenLeser)
