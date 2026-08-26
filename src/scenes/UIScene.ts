import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import type { GameScene } from './GameScene'
import type { LevelConfig } from '../level/schema'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { addText } from '../gfx/text'
import { addVignette } from '../gfx/effects'
import { pille, verlaufBand, LICHT } from '../gfx/material'
import { Huelle } from '../state/HuelleState'
import { kartenState, KARTEN_INFO, type Karte } from '../state/KartenState'
import { badgeSpec, badgeColorCss, badgePoints, toggleHinweis } from '../gfx/huelleBadge'
import { telemetry } from '../telemetry/Telemetry'
import { exportiereDatei, ladeSitzungen, speichereSitzung } from '../telemetry/speicher'
import { sitzungKennzahlen, benchmark } from '../telemetry/kennzahlen'
import { setupDesignCamera } from '../gfx/view'
import { t } from '../i18n'

/**
 * Persistentes HUD über City- und Game-Szenen:
 * Stationsname, Datenbits, TI-Streckenkarte (Siegel-Slots = QR-Fragmente),
 * Portal-Einblendung, Idle-Warnung, F8-Kalibrier-Overlay, ?debug=1-FPS.
 */
export class UIScene extends Phaser.Scene {
  private stationText!: Phaser.GameObjects.Text
  private namePille!: Phaser.GameObjects.Graphics
  bitsText!: Phaser.GameObjects.Text
  private sealSlots: { punkt: Phaser.GameObjects.Graphics; x: number }[] = []
  private idleText!: Phaser.GameObjects.Text
  private lastIdleWarnMs = 0
  private calibText?: Phaser.GameObjects.Text
  private calibTimer?: Phaser.Time.TimerEvent
  private fpsText?: Phaser.GameObjects.Text
  private portalOverlay?: Phaser.GameObjects.Container
  /** Hülle-Anzeige: Farbe UND Form UND Text (Barrierefreiheit, KAPSEL 3.3). */
  private huelleBadge?: Phaser.GameObjects.Container
  private huelleShape?: Phaser.GameObjects.Graphics
  private huelleLabel?: Phaser.GameObjects.Text
  private huelleHint?: Phaser.GameObjects.Text
  /** Letzter gezeichneter Zustand — verhindert Neuzeichnen pro Frame. */
  private huelleGezeigt: Huelle | null = null
  /** F9-Auswertung (Playtest) — nur für das Standpersonal. */
  private auswertungText?: Phaser.GameObjects.Text
  private huellePadGezeigt: boolean | null = null
  /** Kartenanzeige unten rechts: gefundene Ausweise, gesteckter hervorgehoben. */
  private kartenBadge?: Phaser.GameObjects.Container
  /** Was zuletzt gezeichnet wurde — verhindert Neuaufbau pro Frame. */
  private kartenGezeigt = ''

  constructor() {
    super('UI')
  }

  create(): void {
    const { W, H } = setupDesignCamera(this)
    this.sealSlots = []

    // Vignette über dem Spielgeschehen (UI liegt als Overlay über City & Game),
    // unterhalb der HUD-Elemente (deren Depth ≥ 0)
    addVignette(this, W, H).setDepth(-10)

    // Kopfleiste: kein Balken mit harter Unterkante mehr, sondern ein weicher
    // Verlauf. Er hält die Schrift lesbar, ohne das Bild abzuschneiden.
    const bar = this.add.graphics().setDepth(0)
    verlaufBand(this, bar, 0, 0, W, 34, 0x04090f, 0.72, 0)

    // Stationsname in einer Glas-Pille
    this.namePille = this.add.graphics().setDepth(0)
    this.stationText = addText(this, 14, 8, '', 9.5).setDepth(1)

    // Datenbit-Zähler rechts — der Bit als Vektor statt als Pixelkreuz
    const bitPille = this.add.graphics().setDepth(0)
    pille(bitPille, W - 62, 5, 56, 15)
    const bitIcon = this.add.graphics().setDepth(1)
    bitIcon.fillStyle(0xffffff, 1)
    bitIcon.fillCircle(W - 51, 12.5, 1.7)
    bitIcon.lineStyle(0.9, 0x7fe8ff, 0.95)
    bitIcon.strokeCircle(W - 51, 12.5, 3.8)
    this.add
      .image(W - 51, 12.5, 'fx-glow')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(0x7fe8ff)
      .setAlpha(LICHT.signal * 0.5)
      .setDisplaySize(20, 20)
      .setDepth(0)
    this.bitsText = addText(this, W - 43, 8, '0', 9.5, { color: '#a8f0ff' }).setDepth(1)

    // TI-Streckenkarte: ein Punkt pro Station, verbunden zu einer Linie.
    // Rein datengetrieben aus der Playlist — die Reihenfolge ist die Strecke.
    const levels = configService.levels
    const slotW = 17
    const startX = W / 2 - ((levels.length - 1) * slotW) / 2
    const spur = this.add.graphics().setDepth(0)
    spur.lineStyle(1, 0xffffff, 0.16)
    spur.beginPath()
    spur.moveTo(startX, 12.5)
    spur.lineTo(startX + (levels.length - 1) * slotW, 12.5)
    spur.strokePath()
    levels.forEach((_level, i) => {
      const x = startX + i * slotW
      const punkt = this.add.graphics().setDepth(1)
      this.sealSlots.push({ punkt, x })
    })

    // --- Hülle-Badge unten links (nur in Leveln mit Hülle sichtbar) ---
    const huellePille = this.add.graphics()
    pille(huellePille, -3, -3, 92, 18)
    this.huelleShape = this.add.graphics()
    this.huelleLabel = addText(this, 17, 0, '', 9.5, { spacing: 0.4 })
    this.huelleHint = addText(this, 0, 18, '', 7.5, { color: '#9fb3c8', bold: false })
    this.huelleBadge = this.add
      .container(8, H - 30, [huellePille, this.huelleShape, this.huelleLabel, this.huelleHint])
      .setDepth(20)
      .setVisible(false)

    // --- Kartenanzeige unten rechts (Gegenstück zum Hülle-Badge links) ---
    // Gezeigt werden nur GEFUNDENE Karten. Leere Slots für Unbekanntes wären
    // eine Sammel-Checkliste — Karten sind aber Identität, keine Währung
    // (KAPSEL 3.2: HUD minimal halten).
    this.kartenBadge = this.add.container(W - 8, H - 18, []).setDepth(20).setVisible(false)

    this.idleText = addText(this, W / 2, 46, '', 11, {
      color: '#ffd591',
      bg: 'rgba(6,13,22,0.75)',
      padding: { x: 10, y: 6 },
    })
      .setOrigin(0.5)
      .setVisible(false)

    // F8 = Kalibrier-Overlay (bewusst nicht Ctrl+Shift+I — das sind die DevTools)
    this.input.keyboard?.on('keydown-F8', () => this.toggleCalibration())

    // F9 = Playtest-Auswertung: Quote gegen das 80-%-Kriterium + Export.
    // Für das Standpersonal gedacht, deshalb eine einzelne Taste und eine
    // Anzeige, die ohne Erklärung verständlich ist (KAPSEL 4.4).
    this.input.keyboard?.on('keydown-F9', () => this.zeigeAuswertung())

    if (new URLSearchParams(location.search).get('debug') === '1') {
      this.fpsText = addText(this, 6, H - 14, '', 9, { color: '#7fd07f', font: 'mono' })
    }

    // --- globale Events ---
    const events = this.game.events
    const onHud = () => this.refresh()
    const onLevelStart = (payload: { level: LevelConfig }) => {
      this.refresh()
      this.stationText.setText(t(payload.level.station.name))
      // Pille an die Textbreite anpassen — ein fester Kasten sieht bei kurzen
      // Stationsnamen leer aus und schneidet bei langen ab.
      this.namePille.clear()
      pille(this.namePille, 6, 5, this.stationText.width + 16, 15)
      this.showPortalText(payload.level)
    }
    const onIdleWarn = (seconds: number) => {
      this.lastIdleWarnMs = performance.now()
      this.idleText.setText(`Noch da? Neustart in ${seconds} s …`).setVisible(true)
    }
    // Karten melden sich selbst — sie ändern sich auch ohne hud:update
    // (Ziehen beim Verlassen eines Terminals passiert lautlos).
    const offKarten = kartenState.onChange(() => this.refreshKarten())
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, offKarten)

    events.on('hud:update', onHud)
    events.on('level:start', onLevelStart)
    events.on('idle:warn', onIdleWarn)
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      events.off('hud:update', onHud)
      events.off('level:start', onLevelStart)
      events.off('idle:warn', onIdleWarn)
    })

    this.refresh()
  }

  /** Portal-Einblendung: Stationsname groß, 1 Lernsatz, ~2 s. */
  private showPortalText(level: LevelConfig): void {
    this.portalOverlay?.destroy()
    const W = this.cameras.main.displayWidth
    // Kein Rahmen mehr: Ein Kasten mit Kontur schneidet ein Loch in die Kulisse.
    // Stattdessen ein weicher Schleier, der nach außen ausläuft, und darunter
    // eine feine Linie — der Titel liegt IM Bild statt darüber.
    const name = addText(this, 0, -13, t(level.station.name), 19, { spacing: 0.6 }).setOrigin(0.5)
    const line = addText(this, 0, 9, t(level.station.portalText), 10, {
      color: '#cfe0ff',
      bold: false,
    }).setOrigin(0.5)
    const breite = Math.max(name.width, line.width) + 90
    const schleier = this.add.graphics()
    verlaufBand(this, schleier, -breite / 2, -34, breite, 34, 0x04090f, 0, 0.72)
    verlaufBand(this, schleier, -breite / 2, 0, breite, 36, 0x04090f, 0.72, 0)
    schleier.fillStyle(0x7fe8ff, 0.5)
    schleier.fillRect(-Math.min(breite, 200) / 2, 24, Math.min(breite, 200), 0.6)
    this.portalOverlay = this.add.container(W / 2, 66, [schleier, name, line]).setDepth(50).setAlpha(0)
    this.tweens.add({ targets: this.portalOverlay, alpha: 1, duration: 320, ease: 'Sine.easeOut' })
    this.time.delayedCall(2100, () => {
      if (!this.portalOverlay) return
      this.tweens.add({
        targets: this.portalOverlay,
        alpha: 0,
        duration: 350,
        onComplete: () => {
          this.portalOverlay?.destroy()
          this.portalOverlay = undefined
        },
      })
    })
  }

  /**
   * Hülle-Zustand anzeigen: eigene FORM je Zustand (Kreis/Raute/Sechseck),
   * eigene Farbe UND ausgeschriebener Name — dreifach redundant, damit
   * Farbfehlsichtigkeit den Zustand nie verdeckt (KAPSEL 3.3).
   * Die Zuordnung liegt in src/gfx/huelleBadge.ts (getestet).
   */
  private refreshHuelle(): void {
    if (!this.huelleBadge || !this.huelleShape || !this.huelleLabel || !this.huelleHint) return
    // Typ-Import statt Struktur-Behauptung: Benennt jemand player/huelleEnabled
    // um, bricht das hier beim Kompilieren statt still zur Laufzeit.
    // (player ist erst nach GameScene.create() belegt — über der CityScene nicht.)
    const game = this.scene.get('Game') as GameScene | undefined
    const player: GameScene['player'] | undefined = game?.player
    if (!player?.huelleEnabled) {
      this.huelleBadge.setVisible(false)
      this.huelleGezeigt = null
      return
    }
    this.huelleBadge.setVisible(true)

    // Hinweistext folgt der Hardware (am Stand gibt es keinen dritten Knopf)
    const hasPad = inputManager.hasGamepad()
    if (hasPad !== this.huellePadGezeigt) {
      this.huellePadGezeigt = hasPad
      this.huelleHint.setText(toggleHinweis(hasPad))
    }

    const state = player.huelleZustand
    if (state === this.huelleGezeigt) return
    this.huelleGezeigt = state

    const spec = badgeSpec(state)
    const g = this.huelleShape
    g.clear()
    // Weicher Hof unter der Form — sie sitzt sonst flach auf dem Glas
    g.fillStyle(spec.color, 0.18)
    g.fillCircle(6, 6, 8.5)
    g.fillStyle(spec.color, 1)
    if (spec.form === 'kreis') {
      g.fillCircle(6, 6, 5.6)
    } else {
      g.fillPoints(
        badgePoints(spec.form, 12).map((p) => new Phaser.Geom.Point(p.x, p.y)),
        true,
      )
    }
    this.huelleLabel.setText(spec.label).setColor(badgeColorCss(state))
  }

  /**
   * Gefundene Ausweise unten rechts. Der gesteckte bekommt einen goldenen
   * Rahmen — „Sitzung offen" ohne ein Wort, und ohne dass der Spieler das HUD
   * lesen muss, um es zu bemerken.
   *
   * Karten sind zusätzlich beschriftet (eGK / HBA / SMC-B): Die drei Texturen
   * unterscheiden sich zwar in Farbe UND Muster, aber im HUD sind sie nur
   * 12 px breit — da trägt die Schrift die Unterscheidung (KAPSEL 3.3).
   */
  private refreshKarten(): void {
    if (!this.kartenBadge) return
    const gefunden = kartenState.gefunden
    const signatur = `${gefunden.join(',')}|${kartenState.gesteckt ?? ''}`
    if (signatur === this.kartenGezeigt) return
    this.kartenGezeigt = signatur

    this.kartenBadge.removeAll(true)
    if (gefunden.length === 0) {
      this.kartenBadge.setVisible(false)
      return
    }
    this.kartenBadge.setVisible(true)

    // Von rechts nach links aufbauen, damit die neueste Karte nicht springt
    const SLOT = 36
    gefunden.forEach((karte: Karte, i: number) => {
      const x = -(gefunden.length - 1 - i) * SLOT
      const gesteckt = kartenState.gesteckt === karte
      const g = this.add.graphics()
      // Gesteckte Karte: goldene Kante und Eigenlicht — „Sitzung offen"
      // ohne ein Wort, und ohne dass man das HUD lesen muss.
      pille(g, x - 32, -9, 30, 18, {
        alpha: gesteckt ? 0.72 : 0.45,
        kante: gesteckt ? 0xffd75e : 0xffffff,
        kantenAlpha: gesteckt ? 0.9 : 0.14,
      })
      // Kartensymbol als Vektor: liegende Karte mit Chip
      g.fillStyle(gesteckt ? 0xffd75e : 0x9fb3c8, gesteckt ? 1 : 0.75)
      g.fillRoundedRect(x - 28.5, -5.5, 8, 6, 1.4)
      g.fillStyle(0x06111c, 1)
      g.fillRoundedRect(x - 27, -4.2, 2.6, 3.4, 0.6)
      const label = addText(this, x - 17, -5, KARTEN_INFO[karte].kurz, 7.5, {
        color: gesteckt ? '#ffd75e' : '#9fb3c8',
      }).setOrigin(0.5, 0)
      this.kartenBadge?.add([g, label])
    })
  }

  private refresh(): void {
    this.refreshHuelle()
    this.refreshKarten()
    this.bitsText.setText(String(gameState.bits))
    // Streckenpunkte: erledigt = gefüllt und leuchtend, aktuell = Ring,
    // offen = matter Punkt. Drei klar unterscheidbare Formen, keine Farbe allein.
    const erledigt = gameState.seals.length
    this.sealSlots.forEach((slot, i) => {
      const g = slot.punkt
      g.clear()
      if (i < erledigt) {
        g.fillStyle(0xffd75e, 1)
        g.fillCircle(slot.x, 12.5, 3.4)
        g.fillStyle(0xffffff, 0.55)
        g.fillCircle(slot.x, 11.6, 1.2)
      } else if (i === erledigt) {
        g.lineStyle(1.2, 0xffffff, 0.85)
        g.strokeCircle(slot.x, 12.5, 3.6)
        g.fillStyle(0xffffff, 0.9)
        g.fillCircle(slot.x, 12.5, 1.2)
      } else {
        g.fillStyle(0xffffff, 0.22)
        g.fillCircle(slot.x, 12.5, 2.2)
      }
    })
  }

  update(): void {
    // Idle-Warnung ausblenden, sobald wieder Eingaben kommen
    if (this.idleText.visible && performance.now() - this.lastIdleWarnMs > 300) {
      this.idleText.setVisible(false)
    }
    this.refreshHuelle()
    if (this.fpsText) this.fpsText.setText(`${Math.round(this.game.loop.actualFps)} fps`)
  }

  /**
   * Playtest-Auswertung (F9): Wie viele Durchläufe haben die Hülle FREIWILLIG
   * und rechtzeitig genutzt? Grün ab 80 % (KAPSEL 4.1). Der Export legt die
   * Rohdaten als Datei ab — ohne Personenbezug (siehe telemetry/events.ts).
   */
  private zeigeAuswertung(): void {
    // Den laufenden Durchlauf ZUERST sichern, sonst zeigt der Bildschirm ihn an,
    // die exportierte Datei enthält ihn aber nicht — und `npm run playtest:report`
    // rechnet hinterher mit einer anderen Zahl als der Auswerter gesehen hat.
    // Gesichert wird sonst erst am Reward-Screen bzw. beim Idle-Reset; wer
    // mittendrin aufhört (im Playtest der Normalfall), fiele genau durch dieses
    // Loch. speichereSitzung() ersetzt gleichnamige Einträge, ist also gefahrlos
    // mehrfach aufrufbar.
    speichereSitzung(telemetry.toJSON())

    // Den laufenden Durchlauf mitzählen, damit die Anzeige nicht hinterherhängt
    const gespeichert = ladeSitzungen().filter((s) => s.sitzung !== telemetry.sitzung)
    const alle = [...gespeichert, telemetry.toJSON()].filter((s) => s.events.length > 0)
    const huelleLevel = configService.levels.filter((l) => l.huelle.enabled).map((l) => l.id)
    const b = benchmark(alle.map((s) => sitzungKennzahlen(s.sitzung, s.events, huelleLevel)))
    const anzahl = exportiereDatei()

    const W = this.cameras.main.displayWidth
    const H = this.cameras.main.displayHeight
    const zeilen = [
      `Playtest-Auswertung  (${b.n} Durchläufe)`,
      '',
      `verstanden (proaktiv):  ${b.proaktiv}`,
      `erst nach Treffer:      ${b.reaktiv}`,
      `nie verschlüsselt:      ${b.passiv}`,
      '',
      `Quote: ${b.quote} %   Ziel: 80 %   ${b.erfuellt ? 'ERREICHT' : 'NICHT ERREICHT'}`,
      `${anzahl} Durchläufe exportiert`,
    ]
    this.auswertungText?.destroy()
    this.auswertungText = addText(this, W / 2, H / 2, zeilen.join('\n'), 10, {
      color: b.erfuellt ? '#8fe8a0' : '#ffd591',
      bg: 'rgba(4,9,15,0.92)',
      align: 'center',
      padding: { x: 16, y: 12 },
      font: 'mono',
    })
      .setOrigin(0.5)
      .setDepth(95)
    this.time.delayedCall(9000, () => {
      this.auswertungText?.destroy()
      this.auswertungText = undefined
    })
  }

  toggleCalibration(): void {
    if (this.calibText) {
      // Timer MIT ausschalten — sonst leakt jeder Toggle einen 10-Hz-Loop
      this.calibTimer?.remove()
      this.calibTimer = undefined
      this.calibText.destroy()
      this.calibText = undefined
      return
    }
    this.calibText = addText(this, 6, 40, '', 8.5, {
      color: '#8fe8a0',
      bg: 'rgba(4,9,15,0.9)',
      padding: { x: 8, y: 6 },
      font: 'mono',
    }).setDepth(90)
    this.calibTimer = this.time.addEvent({
      delay: 100,
      loop: true,
      callback: () => {
        if (!this.calibText) return
        const pads = inputManager.rawGamepads()
        this.calibText.setText(
          pads.length === 0
            ? 'Kalibrierung (F8): kein Gamepad erkannt'
            : pads.map((p) => `${p.id}\n gedrückt: [${p.pressed.join(',')}] achsen: [${p.axes.join(',')}]`).join('\n'),
        )
      },
    })
  }
}
