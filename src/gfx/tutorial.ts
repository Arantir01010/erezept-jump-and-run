import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { darken, depthMixN, fogColor } from './atmos'
import { addGlow } from './effects'
import { addText } from './text'
import { KUEHL_GESCHUETZT } from './material'
import { silhouettePaul, FY } from './PaulSilhouette'
import { Rezi } from '../actors/Rezi'

/**
 * PROBELAUF — der dritte Intro-Screen vor dem Spielstart.
 *
 * Paul führt in einer Endlos-Schleife die Steuerung vor: laufen, über eine
 * Lücke springen, ein Datenbit einsammeln, mit E die Hülle an- und
 * ausschalten. Über der Bühne wechseln Popups mit gezeichneten Tastenkappen
 * synchron zur jeweiligen Aktion. Die Choreografie ist eine reine Funktion
 * der Zeit seit Szenenstart — kein Zustand, kein Timer (Muster wie in
 * krankenhaus.ts und zeitreise.ts).
 */

/** Mindest-Anzeigedauer in Sekunden, bevor die LEERTASTE-Zeile erscheint. */
export const TUTORIAL_SPERRE = 4

/** Größe, in der Paul hier steht — Popups und Podestabstände sind darauf abgestimmt. */
const PAUL_SCALE = 2

/** Länge einer Demo-Runde. */
const RUNDE = 12

/** Popup-Fenster innerhalb der Runde: [von, bis) in Sekunden. */
const POPUP_FENSTER: [number, number][] = [
  [0.4, 3.1],
  [3.1, 4.6],
  [4.6, 6.2],
  [6.2, 9.4],
]

export function zeichneTutorial(scene: Phaser.Scene, theme: Theme, W: number, H: number): void {
  void H
  const K = KUEHL_GESCHUETZT
  const detail = Phaser.Display.Color.HexStringToColor(theme.detail).color
  const fels = darken(theme.skyTop, 0.5)

  // ---- Bühne: ein Stück Level statt schwebender Klötze ----
  const g = scene.add.graphics().setDepth(0)
  const fog = fogColor(theme)

  // Silhouetten-Häuserzeile hinter der Bühne — dieselbe Nachtstadt wie überall
  const silhouette = depthMixN(darken(theme.skyTop, 0.2), fog, 0.5)
  const silhouetteFenster = depthMixN(0xffd9a0, fog, 0.65)
  for (const [sx, sb, sdach] of [
    [24, 66, 196], [118, 48, 222], [400, 56, 210], [488, 70, 188], [586, 44, 216],
  ] as const) {
    g.fillStyle(silhouette, 1)
    g.fillRect(sx, sdach, sb, 316 - sdach)
    g.fillRect(sx + 6, sdach - 7, 9, 7)
    for (let fy = sdach + 10; fy < 300; fy += 20) {
      for (let fx = sx + 7; fx < sx + sb - 8; fx += 14) {
        if ((Math.round(fx * 5 + fy * 11) % 7) < 2) {
          g.fillStyle(silhouetteFenster, 0.45)
          g.fillRect(fx, fy, 4.5, 6)
        }
      }
    }
  }

  // Boden mit Grube: Die Podeste stehen auf echtem Grund, die Lücke ist ein
  // Abgrund — genau das Bild, das gleich im Spiel wiederkehrt.
  const boden = (x0: number, x1: number, oben: number): void => {
    g.fillStyle(fels, 1)
    g.fillRect(x0, oben, x1 - x0, 360 - oben)
    g.fillStyle(detail, 1)
    g.fillRect(x0 + 1, oben, x1 - x0 - 2, 1.4)
    g.fillStyle(0xffffff, 0.5)
    g.fillRect(x0 + 1, oben, x1 - x0 - 2, 0.5)
    g.fillStyle(darken(theme.skyTop, 0.62), 1)
    for (let kx = x0 + 6; kx < x1 - 8; kx += 26) g.fillRect(kx, oben + 8, 10, 1) // Fugen
  }
  boden(0, 350, 316)
  boden(390, W, 316)
  boden(140, 350, 290)
  boden(390, 520, 290)
  // Grubenränder abdunkeln
  g.fillStyle(0x040810, 0.9)
  g.fillRect(350, 316, 40, 44)
  addGlow(scene, 245, 290, detail, 30, { alpha: 0.06 })
  addGlow(scene, 455, 290, detail, 26, { alpha: 0.06 })

  // Zwei Laternen rahmen die Bühne — Licht wie auf der Zeitreise-Straße
  for (const lx of [96, 560]) {
    g.fillStyle(0x39445e, 1)
    g.fillRect(lx, 278, 1.6, 38)
    g.fillRect(lx - 1, 277.4, 3.6, 1)
    g.fillStyle(0xffd9a0, 0.95)
    g.fillRect(lx - 1.4, 274, 4.4, 3.6)
    addGlow(scene, lx + 1, 276, 0xffd9a0, 12, { alpha: 0.14 })
    // Flacher Lichtschein am Boden — gezeichnet statt schwebendem Glow-Ball
    // (licht() braucht den Bodenfinder der Level, den es hier nicht gibt)
    g.fillStyle(0xffd9a0, 0.055)
    g.fillEllipse(lx + 1, 317, 58, 6)
    g.fillStyle(0xffd9a0, 0.09)
    g.fillEllipse(lx + 1, 317, 34, 4)
  }

  // ---- Titel & Weiter-Zeile ----
  addText(scene, W / 2, 44, 'SO SPIELST DU', 26, {
    stroke: '#0a1730',
    strokeThickness: 1.2,
    spacing: 1.2,
  }).setOrigin(0.5)
  addText(scene, W / 2, 72, 'Ein kurzer Probelauf — gleich bist du dran.', 10.5, {
    color: '#cfe0ff',
    bold: false,
    stroke: '#0a1730',
    strokeThickness: 1,
  }).setOrigin(0.5)
  const weiter = addText(scene, W - 12, 340, 'LEERTASTE: Los geht’s!', 12, {
    color: '#ffd591',
    spacing: 0.5,
  })
    .setOrigin(1, 0.5)
    .setDepth(3)
    .setAlpha(0)
  const punkte = scene.add.graphics().setDepth(3)
  punkte.fillStyle(0xffd591, 0.3)
  punkte.fillCircle(W - 40, 352, 2)
  punkte.fillCircle(W - 30, 352, 2)
  punkte.fillStyle(0xffd591, 0.9)
  punkte.fillCircle(W - 20, 352, 2)

  // ---- Popups mit Tastenkappen ----
  const baueTastenkappe = (
    pg: Phaser.GameObjects.Graphics,
    container: Phaser.GameObjects.Container,
    x: number,
    breite: number,
    beschriftung: string,
  ): void => {
    pg.fillStyle(0x1b2438, 0.9)
    pg.fillRoundedRect(x, -6, breite, 15, 3)
    pg.fillStyle(0xdfe6f0, 0.95)
    pg.fillRoundedRect(x, -7.5, breite, 14, 3)
    container.add(
      addText(scene, x + breite / 2, -0.5, beschriftung, 8, { color: '#16233a', spacing: 0.4 }).setOrigin(0.5),
    )
  }

  const bauePopup = (titel: string, tasten: string[], hinweis: string): Phaser.GameObjects.Container => {
    const c = scene.add.container(W / 2, 158).setDepth(3).setAlpha(0)
    const pg = scene.add.graphics()
    c.add(pg)
    const hoehe = tasten.length > 0 ? 62 : 46
    pg.fillStyle(0x060d16, 0.78)
    pg.fillRoundedRect(-130, -hoehe / 2 - 8, 260, hoehe, 7)
    pg.lineStyle(0.8, 0xffffff, 0.16)
    pg.strokeRoundedRect(-130, -hoehe / 2 - 8, 260, hoehe, 7)
    pg.fillStyle(0xffffff, 0.2)
    pg.fillRoundedRect(-124, -hoehe / 2 - 7.6, 248, 0.6, 0.3)
    c.add(addText(scene, 0, -hoehe / 2 + 2, titel, 11, { color: '#ffd75e', spacing: 1.4 }).setOrigin(0.5))
    if (tasten.length > 0) {
      const breiten = tasten.map((tst) => (tst.length > 2 ? 12 + tst.length * 5.2 : 16))
      const gesamt = breiten.reduce((a, b) => a + b, 0) + (tasten.length - 1) * 6
      let x = -gesamt / 2
      for (let i = 0; i < tasten.length; i++) {
        baueTastenkappe(pg, c, x, breiten[i], tasten[i])
        x += breiten[i] + 6
      }
      c.add(addText(scene, 0, 14.5, hinweis, 8, { color: '#b8c6e0', bold: false }).setOrigin(0.5))
    } else {
      c.add(addText(scene, 0, 1, hinweis, 9, { color: '#b8c6e0', bold: false }).setOrigin(0.5))
    }
    return c
  }

  const popups = [
    bauePopup('LAUFEN', ['←', '→'], 'oder A / D — auch am Joystick'),
    bauePopup('SPRINGEN', ['LEERTASTE'], 'trägt dich über jede Lücke'),
    bauePopup('DATENBITS', [], 'einfach durchlaufen — sie zählen für dein Rezept'),
    bauePopup('TI-AKTION', ['E'], 'Hülle an & aus — verschlüsselt bist du geschützt'),
  ]

  // ---- Paul + Leben ----
  // Dieselbe Vektor-Silhouette wie im echten Spiel (PaulSilhouette.ts) —
  // kein eigens gezeichneter Ersatz, damit hier wirklich UNSER Paul steht
  // und nicht irgendeine andere Figur.
  const fussY = 290 // Oberkante der Podeste, siehe boden()
  const paul = scene.add.sprite(160, fussY - FY * PAUL_SCALE, 'player-idle0').setScale(PAUL_SCALE).setDepth(2)
  paul.play('player-idle')
  silhouettePaul(scene, paul, theme, { lightSide: 1 })
  // REZI schwebt neben Paul — wie im echten Spiel (dieselbe Klasse, dieselbe
  // Vektorform). Sie folgt der Choreografie von selbst.
  const rezi = new Rezi(scene, 160 - 20, fussY - FY * PAUL_SCALE - 30)
  rezi.follow(paul)
  rezi.setScale(1.4)

  const leben = scene.add.graphics().setDepth(1)
  // game.loop.time statt scene.time.now: Der Scene-Clock ist in create()
  // noch veraltet (er wird nur während Updates gestellt).
  const t0 = scene.game.loop.time / 1000

  /**
   * Choreografie: Position, Sprunghöhe, Animation, Blickrichtung.
   * In der Luft wechselt die Animation genau wie beim echten Spielercharakter
   * (Player.ts) an der Kuppe von 'player-jump' auf 'player-fall'.
   */
  const choreo = (td: number): { x: number; dy: number; anim: string; links: boolean } => {
    if (td < 1) return { x: 160, dy: 0, anim: 'player-idle', links: false }
    if (td < 3) return { x: 160 + ((330 - 160) * (td - 1)) / 2, dy: 0, anim: 'player-run', links: false }
    if (td < 3.8) {
      const k = (td - 3) / 0.8
      return { x: 330 + 80 * k, dy: -30 * Math.sin(Math.PI * k), anim: k < 0.5 ? 'player-jump' : 'player-fall', links: false }
    }
    if (td < 5) return { x: 410 + ((470 - 410) * (td - 3.8)) / 1.2, dy: 0, anim: 'player-run', links: false }
    if (td < 9.4) return { x: 470, dy: 0, anim: 'player-idle', links: false }
    if (td < 10.1) return { x: 470 - ((470 - 410) * (td - 9.4)) / 0.7, dy: 0, anim: 'player-run', links: true }
    if (td < 10.9) {
      const k = (td - 10.1) / 0.8
      return { x: 410 - 80 * k, dy: -30 * Math.sin(Math.PI * k), anim: k < 0.5 ? 'player-jump' : 'player-fall', links: true }
    }
    return { x: 330 - ((330 - 160) * (td - 10.9)) / 1.1, dy: 0, anim: 'player-run', links: true }
  }

  /** Sekunden seit dem letzten Einschalten der Hülle, oder -1 wenn aus. */
  const huelleSeit = (td: number): number => {
    if (td >= 6.6 && td < 7.8) return td - 6.6
    if (td >= 8.6 && td < 9.4) return td - 8.6
    return -1
  }

  const malLeben = (t: number): void => {
    const tz = t - t0
    const td = tz % RUNDE
    const l = leben
    l.clear()

    // Weiter-Zeile nach Mindestdauer, vorher Zeitbalken
    if (tz < TUTORIAL_SPERRE) {
      weiter.setAlpha(0)
      l.fillStyle(0xffd591, 0.2)
      l.fillRect(W - 72, 339, 60, 1.6)
      l.fillStyle(0xffd591, 0.6)
      l.fillRect(W - 72, 339, (60 * tz) / TUTORIAL_SPERRE, 1.6)
    } else {
      weiter.setAlpha(0.65 + 0.35 * Math.sin(tz * 4))
    }

    // Popups im Takt der Vorführung
    for (let i = 0; i < popups.length; i++) {
      const [von, bis] = POPUP_FENSTER[i]
      popups[i].setAlpha(Phaser.Math.Clamp(Math.min((td - von) / 0.4, (bis - td) / 0.4, 1), 0, 1))
    }

    // Paul bewegen
    const c = choreo(td)
    paul.setX(c.x)
    paul.setY(fussY - FY * PAUL_SCALE + c.dy)
    paul.setFlipX(c.links)
    if (paul.anims.currentAnim?.key !== c.anim) paul.play(c.anim)

    // Datenbit: liegt auf Podest B, wird im Vorbeilaufen eingesammelt
    if (td < 4.55) {
      const puls = 4.5 + Math.sin(t * 2.4) * 0.5
      l.fillStyle(K, 0.16)
      l.fillCircle(450, 268, 7)
      l.lineStyle(1, K, 0.95)
      l.strokeCircle(450, 268, 3.4)
      l.lineStyle(0.5, K, 0.4)
      l.strokeCircle(450, 268, puls)
      l.fillStyle(0xffffff, 1)
      l.fillCircle(450, 268, 1.4)
    } else if (td < 5.1) {
      const k = (td - 4.55) / 0.55
      l.lineStyle(0.8, K, 0.9 * (1 - k))
      l.strokeCircle(450, 268, 4 + 10 * k)
      l.fillStyle(0xffffff, 0.9 * (1 - k))
      for (let i = 0; i < 4; i++) {
        const a = (i / 4) * Math.PI * 2 + 0.6
        l.fillCircle(450 + Math.cos(a) * 9 * k, 268 + Math.sin(a) * 7 * k, 1)
      }
    }

    // Hülle: kühler Ring um Paul — dieselbe Semantik wie im Spiel
    const seit = huelleSeit(td)
    if (seit >= 0) {
      const einrast = Math.max(0, 1 - seit / 0.25)
      const r = 27 + 10 * einrast + Math.sin(t * 3) * 1.2
      l.fillStyle(K, 0.08)
      l.fillCircle(paul.x, paul.y, r)
      l.lineStyle(1.2, K, 0.9)
      l.strokeCircle(paul.x, paul.y, r)
    }
  }

  const onUpdate = (): void => {
    malLeben(scene.time.now / 1000)
  }
  scene.events.on(Phaser.Scenes.Events.UPDATE, onUpdate)
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, onUpdate)
  })
  malLeben(scene.game.loop.time / 1000)
}
