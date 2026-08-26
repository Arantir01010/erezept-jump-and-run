import Phaser from 'phaser'
import { configService } from '../level/ConfigService'
import type { LevelConfig } from '../level/schema'
import { gameState } from '../state/GameState'
import { inputManager } from '../input/InputManager'
import { sealTextureKey } from '../gfx/TextureFactory'
import { addText } from '../gfx/text'
import { addVignette } from '../gfx/effects'
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
  bitsText!: Phaser.GameObjects.Text
  private sealSlots: { frame: Phaser.GameObjects.Rectangle; icon: Phaser.GameObjects.Image }[] = []
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

    const bar = this.add.graphics().setDepth(0)
    bar.fillStyle(0x06090f, 0.6)
    bar.fillRect(0, 0, W, 24)

    this.stationText = addText(this, 6, 5, '', 11)

    this.add.image(W - 56, 12, 'datenbit')
    this.bitsText = addText(this, W - 47, 5, '0', 11, { color: '#4de3ff' })

    // TI-Streckenkarte: ein Slot pro Station der Playlist (rein datengetrieben)
    const levels = configService.levels
    const slotW = 22
    const startX = W / 2 - ((levels.length - 1) * slotW) / 2
    levels.forEach((level, i) => {
      const x = startX + i * slotW
      const frame = this.add.rectangle(x, 12, 18, 18).setStrokeStyle(1, 0x8a93a8, 0.9)
      const icon = this.add.image(x, 12, sealTextureKey(this, level.siegelIcon)).setAlpha(0.25)
      this.sealSlots.push({ frame, icon })
      if (i < levels.length - 1) {
        this.add.rectangle(x + slotW / 2, 12, 6, 2, 0x8a93a8, 0.7)
      }
    })

    // --- Hülle-Badge unten links (nur in Leveln mit Hülle sichtbar) ---
    this.huelleShape = this.add.graphics()
    this.huelleLabel = addText(this, 17, 1, '', 10)
    this.huelleHint = addText(this, 0, 15, '', 8, { color: '#8a93a8' })
    this.huelleBadge = this.add
      .container(8, H - 26, [this.huelleShape, this.huelleLabel, this.huelleHint])
      .setDepth(20)
      .setVisible(false)

    // --- Kartenanzeige unten rechts (Gegenstück zum Hülle-Badge links) ---
    // Gezeigt werden nur GEFUNDENE Karten. Leere Slots für Unbekanntes wären
    // eine Sammel-Checkliste — Karten sind aber Identität, keine Währung
    // (KAPSEL 3.2: HUD minimal halten).
    this.kartenBadge = this.add.container(W - 8, H - 18, []).setDepth(20).setVisible(false)

    this.idleText = addText(this, W / 2, 46, '', 12, {
      color: '#ffd75e',
      bg: '#20242e',
      padding: { x: 7, y: 4 },
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
      this.fpsText = addText(this, 6, H - 16, '', 10, { color: '#7fd07f' })
    }

    // --- globale Events ---
    const events = this.game.events
    const onHud = () => this.refresh()
    const onLevelStart = (payload: { level: LevelConfig }) => {
      this.refresh()
      this.stationText.setText(t(payload.level.station.name))
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
    const name = addText(this, 0, -11, t(level.station.name), 17).setOrigin(0.5)
    const line = addText(this, 0, 9, t(level.station.portalText), 11, { color: '#cfe0ff' }).setOrigin(0.5)
    const bg = this.add
      .rectangle(0, 0, Math.max(name.width, line.width) + 34, 48, 0x06090f, 0.8)
      .setStrokeStyle(1, 0x4de3ff, 0.8)
    this.portalOverlay = this.add.container(W / 2, 62, [bg, name, line]).setDepth(50).setAlpha(0)
    this.tweens.add({ targets: this.portalOverlay, alpha: 1, duration: 250 })
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
    const game = this.scene.get('Game') as
      | (Phaser.Scene & { player?: { huelleEnabled: boolean; huelleZustand: Huelle } })
      | undefined
    const player = game?.player
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
    g.fillStyle(spec.color, 1)
    if (spec.form === 'kreis') {
      g.fillCircle(6, 6, 6)
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
    const SLOT = 34
    gefunden.forEach((karte: Karte, i: number) => {
      const x = -(gefunden.length - 1 - i) * SLOT
      const gesteckt = kartenState.gesteckt === karte
      const rahmen = this.add
        .rectangle(x - 14, 0, 28, 22)
        .setStrokeStyle(1, gesteckt ? 0xffd75e : 0x8a93a8, gesteckt ? 1 : 0.7)
      const icon = this.add.image(x - 14, -3, `karte-${karte}`).setAlpha(gesteckt ? 1 : 0.75)
      const label = addText(this, x - 14, 4, KARTEN_INFO[karte].kurz, 8, {
        color: gesteckt ? '#ffd75e' : '#8a93a8',
      }).setOrigin(0.5, 0)
      this.kartenBadge?.add([rahmen, icon, label])
    })
  }

  private refresh(): void {
    this.refreshHuelle()
    this.refreshKarten()
    this.bitsText.setText(String(gameState.bits))
    this.sealSlots.forEach((slot, i) => {
      const earned = i < gameState.seals.length
      slot.icon.setAlpha(earned ? 1 : 0.25)
      slot.frame.setStrokeStyle(1, earned ? 0xffd75e : 0x8a93a8, 0.9)
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
    this.auswertungText = addText(this, W / 2, H / 2, zeilen.join('\n'), 11, {
      color: b.erfuellt ? '#7fd07f' : '#ffd75e',
      bg: '#06090f',
      align: 'center',
      padding: { x: 12, y: 10 },
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
    this.calibText = addText(this, 6, 32, '', 9, {
      color: '#7fd07f',
      bg: '#06090f',
      padding: { x: 5, y: 4 },
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
