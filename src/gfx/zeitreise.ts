import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { darken, depthMix, fogColor } from './atmos'
import { addGlow } from './effects'
import { addText } from './text'
import { KUEHL_GESCHUETZT, WARM_OFFEN } from './material'
import {
  HAUT,
  malEkg,
  malFigur,
  malSitzend,
  pendel,
  P_AERZTIN,
  P_ARZT,
  P_BESUCH,
  P_PATIENT,
  P_PFLEGE,
  P_TECHNIK,
  type Person,
} from './krankenhaus'

/**
 * ZEITREISE — die zweiteilige Intro-Sequenz vor dem Spielstart.
 *
 * Gleiche Bühne, zwei Zeiten: Hausarzt, Facharzt, Klinikum und Apotheke
 * stehen an einer Straße.
 *
 *  Phase 1 „FRÜHER":  Papier regiert. Boten und Patienten pendeln mit
 *                     Aktenstapeln von Tür zu Tür, verlieren Blätter,
 *                     vor den Türen stauen sich Schlangen, das Fax
 *                     spuckt ohne Pause, die Uhr rast.
 *  Phase 2 „HEUTE":   Die TI als Lehrstück in fünf Schritten: Arztgespräch
 *                     im Sprechzimmer, der Eintrag wird getippt, der
 *                     Konnektor legt die Hülle an (warm = offen, kühl =
 *                     geschützt — dieselbe Semantik wie im Spiel), durchs
 *                     TI-Gateway ins Rechenzentrum, die VAU schreibt die
 *                     Akte (Hülle öffnet sich im geschützten Raum), und am
 *                     Ende ist der Eintrag in der App und beim nächsten
 *                     Arzt abrufbar. Eine Schritt-Zeile benennt jede
 *                     Station, während der Datenfunke sie durchläuft.
 *
 * Technik wie in krankenhaus.ts: statische Ebene einmal, „Leben" jeden
 * Frame als reine Funktion der Zeit. Die IntroScene wechselt die Phase
 * per scene.restart — der SHUTDOWN-Hook räumt hier alles ab.
 * Barrierefreiheit: kein Blinken über 3 Hz.
 */

const BODEN = 320

/**
 * Mindest-Anzeigedauer pro Phase in Sekunden: Die Zeitreise ist das
 * Herzstück der Botschaft — sie lässt sich bewusst NICHT sofort
 * überspringen. Erst wenn die Story einmal durchgelaufen ist, erscheint
 * die LEERTASTE-Zeile (die IntroScene sperrt die Eingabe genauso lange).
 */
export const ZEITREISE_SPERRE: Record<1 | 2, number> = { 1: 7.5, 2: 10.5 }

/** Story-Takt der FRÜHER-Phase: vier Zeilen à 3,75 s. */
const FRUEHER_TAKT = 3.75
const FRUEHER_ZEILEN = [
  'Ein Rezept? Gibt es in der Praxis — auf Papier, versteht sich.',
  'Befunde reisen per Bote, per Fax, per Fußweg.',
  'Der nächste Arzt? Fängt ohne deine Unterlagen von vorn an.',
  'Zettel gehen verloren — und mit ihnen Zeit.',
]

/** Die vier Häuser: Außenkanten, Dachlinie und Türmitte. */
const HAEUSER = {
  praxis: { x0: 36, x1: 146, dach: 232, tuer: 92 },
  facharzt: { x0: 176, x1: 286, dach: 224, tuer: 232 },
  klinik: { x0: 316, x1: 466, dach: 176, tuer: 392 },
  apotheke: { x0: 496, x1: 606, dach: 240, tuer: 571 },
} as const

// Zwei zusätzliche Gesichter, die es nur in der Zeitreise gibt
const P_BOTE: Person = { haut: HAUT[2], oben: 0xa0764d, unten: 0x2e3a50, haar: 0x14101a }
const P_OMA: Person = { haut: HAUT[0], oben: 0x8a5f9e, unten: 0x4a3a5c, haar: 0xcfd4de }

/** Einzelnes Blatt Papier, um `winkel` gedreht — für Verlust und Wind. */
function malBlatt(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  winkel: number,
  alpha = 1,
  w = 4.6,
  h = 6,
): void {
  const c = Math.cos(winkel)
  const s = Math.sin(winkel)
  const ecken = [
    [-w / 2, -h / 2],
    [w / 2, -h / 2],
    [w / 2, h / 2],
    [-w / 2, h / 2],
  ].map(([dx, dy]) => new Phaser.Geom.Point(x + dx * c - dy * s, y + dx * s + dy * c))
  g.fillStyle(0xeef2f8, alpha)
  g.fillPoints(ecken, true)
  g.fillStyle(0x9aa6bc, alpha * 0.6)
  g.fillPoints(
    [
      [-w / 2 + 0.8, -h / 2 + 1.2],
      [w / 2 - 0.8, -h / 2 + 1.2],
      [w / 2 - 0.8, -h / 2 + 1.8],
      [-w / 2 + 0.8, -h / 2 + 1.8],
    ].map(([dx, dy]) => new Phaser.Geom.Point(x + dx * c - dy * s, y + dx * s + dy * c)),
    true,
  )
}

/** Aktenstapel auf den Armen einer Figur — schwankt oben stärker als unten. */
function malStapel(g: Phaser.GameObjects.Graphics, x: number, yFuss: number, n: number, t: number, ph: number): void {
  const yArm = yFuss - 7.2
  for (let i = 0; i < n; i++) {
    const sway = Math.sin(t * 2.6 + ph + i * 0.8) * (0.25 + i * 0.22)
    g.fillStyle(0xeef2f8, 1)
    g.fillRect(x - 3.5 + sway, yArm - 1.3 * (i + 1), 7, 1.1)
    g.fillStyle(0x9aa6bc, 0.5)
    g.fillRect(x - 3.5 + sway, yArm - 1.3 * (i + 1) + 0.8, 7, 0.25)
  }
}

export function zeichneZeitreise(
  scene: Phaser.Scene,
  theme: Theme,
  W: number,
  H: number,
  phase: 1 | 2,
): void {
  void H
  const fog = fogColor(theme)
  const K = KUEHL_GESCHUETZT
  const accent = Phaser.Display.Color.HexStringToColor(theme.accent).color
  const detail = Phaser.Display.Color.HexStringToColor(theme.detail).color

  const wand = darken(theme.skyTop, 0.32)
  const wandDunkel = darken(theme.skyTop, 0.5)
  const fensterWarm = 0xffd9a0
  const fensterKalt = depthMix(theme.skyBottom, fog, 0.5)
  const strasse = darken(theme.ground, 0.45)
  const gehweg = darken(theme.groundTop, 0.3)

  const statik = scene.add.graphics().setDepth(0)
  const g = statik

  // ---- Straße ----
  g.fillStyle(gehweg, 1)
  g.fillRect(0, BODEN - 2, W, 8)
  g.fillStyle(0xffffff, 0.08)
  g.fillRect(0, BODEN - 2, W, 0.8)
  g.fillStyle(strasse, 1)
  g.fillRect(0, BODEN + 6, W, 40)
  for (let x = 4; x < W; x += 16) {
    g.fillStyle(detail, 0.35)
    g.fillRect(x, 339, 7, 1.2)
  }

  // ---- Häuser: gemeinsamer Rumpf, dann Eigenheiten ----
  const rumpf = (x0: number, x1: number, dachY: number, tuerMitte: number, tuerBreite: number): void => {
    g.fillStyle(wand, 1)
    g.fillRect(x0, dachY, x1 - x0, BODEN - dachY)
    g.fillStyle(detail, 0.85)
    g.fillRect(x0 - 2, dachY - 2, x1 - x0 + 4, 2.5)
    // Fensterraster (spart die Türspalte aus)
    for (let fy = dachY + 12; fy < BODEN - 26; fy += 22) {
      for (let fx = x0 + 10; fx < x1 - 12; fx += 16) {
        if (Math.abs(fx + 4 - tuerMitte) < tuerBreite) continue
        const an = (Math.round(fx * 7 + fy * 13) % 5) < 2
        g.fillStyle(an ? fensterWarm : fensterKalt, an ? 0.55 : 0.5)
        g.fillRect(fx, fy, 8, 10)
        g.fillStyle(0xffffff, 0.1)
        g.fillRect(fx, fy, 8, 0.8)
      }
    }
    // Tür
    g.fillStyle(0x0d1a2c, 1)
    g.fillRect(tuerMitte - tuerBreite / 2, BODEN - 26, tuerBreite, 26)
    g.lineStyle(0.8, detail, 0.8)
    g.strokeRect(tuerMitte - tuerBreite / 2, BODEN - 26, tuerBreite, 26)
    g.fillStyle(accent, 0.55)
    g.fillCircle(tuerMitte + tuerBreite / 2 - 3, BODEN - 13, 0.8)
  }

  const schild = (mitte: number, y: number, text: string, farbe: string): void => {
    g.fillStyle(0x0e1a2c, 0.92)
    g.fillRect(mitte - 32, y, 64, 12)
    g.lineStyle(0.7, detail, 0.8)
    g.strokeRect(mitte - 32, y, 64, 12)
    addText(scene, mitte, y + 6, text, 5.5, { color: farbe, spacing: 1 }).setOrigin(0.5)
  }

  const P = HAEUSER.praxis
  const F = HAEUSER.facharzt
  const KL = HAEUSER.klinik
  const A = HAEUSER.apotheke

  rumpf(P.x0, P.x1, P.dach, P.tuer, 20)
  schild((P.x0 + P.x1) / 2, P.dach + 5, 'HAUSARZT', '#dfe6f0')
  rumpf(F.x0, F.x1, F.dach, F.tuer, 20)
  schild((F.x0 + F.x1) / 2, F.dach + 5, 'FACHARZT', '#dfe6f0')
  rumpf(KL.x0, KL.x1, KL.dach, KL.tuer, 28)
  schild((KL.x0 + KL.x1) / 2, KL.dach + 5, 'KLINIKUM', '#dfe6f0')
  rumpf(A.x0, A.x1, A.dach, A.tuer, 20)
  schild((A.x0 + A.x1) / 2, A.dach + 5, 'APOTHEKE', '#ffd75e')

  // Klinik: weißes H auf Blau neben der Tür + EKG-Linie darüber
  g.fillStyle(0x1d4f9c, 1)
  g.fillRect(362, 292, 14, 11)
  g.fillStyle(0xffffff, 0.95)
  g.fillRect(364.5, 294, 2.2, 7)
  g.fillRect(371.3, 294, 2.2, 7)
  g.fillRect(364.5, 296.6, 9, 1.8)
  malEkg(g, 380, 290, 24, 2, 0.35, 0)
  // Apotheken-„A" am Ausleger
  g.fillStyle(0x39445e, 1)
  g.fillRect(A.x0, 258, 5, 1.6)
  g.fillStyle(0x0d2440, 0.95)
  g.fillRect(A.x0 - 6, 259.6, 11, 11)
  g.lineStyle(1.1, accent, 0.95)
  g.beginPath()
  g.moveTo(A.x0 - 4, 268.6)
  g.lineTo(A.x0 - 0.5, 261.6)
  g.lineTo(A.x0 + 3, 268.6)
  g.moveTo(A.x0 - 2.4, 266)
  g.lineTo(A.x0 + 1.4, 266)
  g.strokePath()
  // Praxis: das Faxgerät im Fenster — DAS Gerät der Papierzeit
  g.fillStyle(wandDunkel, 1)
  g.fillRect(50, 252, 18, 12)
  g.fillStyle(0x39445e, 1)
  g.fillRect(53, 255, 12, 6)
  g.fillStyle(0x7fd07f, 0.9)
  g.fillRect(54.2, 256.2, 1.2, 1.2)
  addText(scene, 59, 250, 'FAX', 4, { color: '#9fb0cc', bold: false }).setOrigin(0.5)

  // Straßenuhr in der Mitte — ihr Tempo erzählt die halbe Geschichte
  g.fillStyle(0x39445e, 1)
  g.fillRect(304, 266, 2.2, 54)
  g.fillStyle(0x0e1a2c, 1)
  g.fillCircle(305, 258, 9)
  g.lineStyle(1, detail, 0.9)
  g.strokeCircle(305, 258, 9)

  // Laternen an beiden Rändern
  for (const lx of [16, 628]) {
    g.fillStyle(0x39445e, 1)
    g.fillRect(lx, 282, 1.6, 38)
    g.fillStyle(0xffd9a0, 0.95)
    g.fillRect(lx - 1.4, 279, 4.4, 3.4)
    addGlow(scene, lx + 1, 281, 0xffd9a0, 13, { alpha: 0.15 })
  }

  // ---- Phasen-Stimmung: warmer bzw. kühler Schleier + Titel ----
  scene.add
    .rectangle(W / 2, 180, W, 360, phase === 1 ? 0xc08a4a : 0x4de3ff, phase === 1 ? 0.07 : 0.04)
    .setDepth(1)
  addText(scene, W / 2, 44, phase === 1 ? 'FRÜHER' : 'HEUTE', 26, {
    stroke: '#0a1730',
    strokeThickness: 1.2,
    spacing: 1.2,
  }).setOrigin(0.5)
  addText(
    scene,
    W / 2,
    72,
    phase === 1
      ? 'Rezepte auf Papier: jeder Weg zu Fuß, Zettel für Zettel.'
      : 'So arbeitet die Telematikinfrastruktur — Schritt für Schritt.',
    10.5,
    { color: '#cfe0ff', bold: false, stroke: '#0a1730', strokeThickness: 1 },
  ).setOrigin(0.5)
  // Die Weiter-Zeile erscheint erst nach Ablauf der Mindest-Anzeigedauer;
  // bis dahin zeigt ein schmaler Balken, dass die Geschichte noch läuft
  // (Alpha-Steuerung in malLeben, deshalb kein Tween).
  const weiter = addText(scene, W - 12, 340, phase === 1 ? 'LEERTASTE: Und heute?' : 'LEERTASTE: Zum Probelauf!', 12, {
    color: '#ffd591',
    spacing: 0.5,
  })
    .setOrigin(1, 0.5)
    .setDepth(3)
    .setAlpha(0)
  // Fortschrittspunkte: wo bin ich in der Sequenz? (3. Punkt = Probelauf)
  const punkte = scene.add.graphics().setDepth(3)
  punkte.fillStyle(0xffd591, phase === 1 ? 0.9 : 0.3)
  punkte.fillCircle(W - 40, 352, 2)
  punkte.fillStyle(0xffd591, phase === 2 ? 0.9 : 0.3)
  punkte.fillCircle(W - 30, 352, 2)
  punkte.fillStyle(0xffd591, 0.3)
  punkte.fillCircle(W - 20, 352, 2)

  // ---- Phase 1: Story-Zeilen + liegengebliebene Blätter ----
  let storyZeilen: Phaser.GameObjects.Text[] = []
  if (phase === 1) {
    // Vier Erzähl-Zeilen laufen im Takt durch (Steuerung in malLeben) —
    // die Geschichte trägt die Phase, nicht nur das Gewusel.
    storyZeilen = FRUEHER_ZEILEN.map((s) =>
      addText(scene, W / 2, 92, s, 9.5, { color: '#ffc98a', bold: false, stroke: '#0a1730', strokeThickness: 1 })
        .setOrigin(0.5)
        .setAlpha(0),
    )
  }
  if (phase === 1) {
    const muell: [number, number, number][] = [
      [122, 323, 0.3],
      [208, 331, -0.25],
      [262, 344, 0.12],
      [341, 336, 0.5],
      [428, 324, -0.4],
      [468, 342, 0.2],
      [522, 330, -0.15],
    ]
    for (const [mx, my, mw] of muell) malBlatt(g, mx, my, mw, 0.5)
  }

  // ---- Phase 2: die TI zum Anfassen — Sprechzimmer, Netz, Rechenzentrum ----
  const NETZ_Y = 351
  let schrittZeilen: Phaser.GameObjects.Text[] = []
  if (phase === 2) {
    const raum = darken(theme.skyBottom, 0.62)
    // Netz unter der Straße: Praxis → Gateway → Rechenzentrum + Abzweige
    g.lineStyle(0.7, K, 0.3)
    g.beginPath()
    g.moveTo(73.5, NETZ_Y)
    g.lineTo(590, NETZ_Y)
    g.strokePath()
    g.lineStyle(0.5, K, 0.22)
    g.beginPath()
    g.moveTo(73.5, 278) // vom Konnektor im Sprechzimmer hinab
    g.lineTo(73.5, NETZ_Y)
    g.moveTo(262, 296) // hinauf zum Facharzt-Monitor
    g.lineTo(262, NETZ_Y)
    g.strokePath()
    // Handys hängen am Mobilnetz: gepunktete Strecken statt fester Leitung.
    // Zwei Empfänger — so sieht man: Der Abruf ist kein Einzelfall.
    // (x=473: weiter rechts stiege der Puls durch die LEERTASTE-Zeile auf.)
    for (const hx of [348, 473]) {
      for (let dy = NETZ_Y - 4; dy > 314; dy -= 4) {
        g.fillStyle(K, 0.35)
        g.fillCircle(hx, dy, 0.5)
      }
    }
    // Apotheken-Knoten als stiller Mitnutzer derselben Leitung
    g.fillStyle(K, 0.5)
    g.fillRect(569.5, NETZ_Y - 1.5, 3, 3)

    // TI-Gateway: der bewachte Zugang zur TI
    g.fillStyle(0x141c2e, 1)
    g.fillRect(292, 343, 36, 13)
    g.lineStyle(0.7, detail, 0.7)
    g.strokeRect(292, 343, 36, 13)
    addText(scene, 310, 349.5, 'TI-GATEWAY', 3.8, { color: '#4de3ff', spacing: 0.4 }).setOrigin(0.5)
    addGlow(scene, 310, 349, K, 10, { alpha: 0.1 })

    // Rechenzentrum: VAU-Raum + ePA-Racks (Fachdienste wohnen nicht in Wolken)
    g.fillStyle(0x0a1220, 1)
    g.fillRect(378, 332, 92, 26)
    g.lineStyle(0.8, detail, 0.7)
    g.strokeRect(378, 332, 92, 26)
    addText(scene, 424, 336.5, 'RECHENZENTRUM', 3.8, { color: '#9fb0cc', spacing: 0.5, bold: false }).setOrigin(0.5)
    g.fillStyle(K, 0.07)
    g.fillRect(383, 340, 32, 16)
    g.lineStyle(0.6, K, 0.5)
    g.strokeRect(383, 340, 32, 16)
    addText(scene, 391, 352.2, 'VAU', 3.8, { color: '#4de3ff', spacing: 0.6 }).setOrigin(0.5)
    for (const rx of [421, 437, 453]) {
      g.fillStyle(0x141c2e, 1)
      g.fillRect(rx, 340, 12, 16)
      g.lineStyle(0.6, detail, 0.6)
      g.strokeRect(rx, 340, 12, 16)
    }
    addText(scene, 443, 344.5, 'ePA', 3.5, { color: '#4de3ff', spacing: 0.3 }).setOrigin(0.5)
    addGlow(scene, 399, 348, K, 12, { alpha: 0.12 })

    // Sprechzimmer in der Praxis (Schnitt): Stühle, Schreibtisch, Monitor,
    // Konnektor an der Wand — wie im Klinik-Keller, nur eine Nummer kleiner
    g.fillStyle(raum, 1)
    g.fillRect(44, 268, 36, 48)
    g.lineStyle(0.8, detail, 0.6)
    g.strokeRect(44, 268, 36, 48)
    for (const sx of [49, 75]) {
      g.fillStyle(0x39445e, 1)
      g.fillRect(sx - 3, 302, 6, 1.4)
      g.fillRect(sx - 2.6, 303.4, 1.2, 12.6)
      g.fillRect(sx + 1.4, 303.4, 1.2, 12.6)
    }
    g.fillStyle(0x2f3a52, 1)
    g.fillRect(56, 296, 14, 2)
    g.fillRect(58, 298, 1.6, 18)
    g.fillRect(66, 298, 1.6, 18)
    g.fillStyle(0x0a1220, 1)
    g.fillRect(57, 287, 8, 8)
    g.lineStyle(0.5, 0x39445e, 1)
    g.strokeRect(57, 287, 8, 8)
    g.fillStyle(0x3a4358, 1)
    g.fillRect(69, 271, 9, 7)
    g.lineStyle(0.5, detail, 0.8)
    g.strokeRect(69, 271, 9, 7)
    g.fillStyle(0xffd75e, 0.95) // steckende SMC-B
    g.fillRect(77.2, 275, 2, 1.4)

    // Facharzt-Zimmer (Schnitt): der Monitor wartet auf die Akte
    g.fillStyle(raum, 1)
    g.fillRect(246, 272, 34, 44)
    g.lineStyle(0.8, detail, 0.6)
    g.strokeRect(246, 272, 34, 44)
    g.fillStyle(0x39445e, 1)
    g.fillRect(247, 302, 6, 1.4)
    g.fillRect(247.4, 303.4, 1.2, 12.6)
    g.fillRect(251.4, 303.4, 1.2, 12.6)
    g.fillStyle(0x2f3a52, 1)
    g.fillRect(256, 296, 14, 2)
    g.fillRect(258, 298, 1.6, 18)
    g.fillRect(266, 298, 1.6, 18)
    g.fillStyle(0x0a1220, 1)
    g.fillRect(258, 287, 8, 8)
    g.lineStyle(0.5, 0x39445e, 1)
    g.strokeRect(258, 287, 8, 8)

    // Schritt-Zeilen: Eine Zeile pro Station, ein-/ausgeblendet im Takt
    // des Datenfunkens (Steuerung in malLeben)
    const schritte = [
      '1 · Im Sprechzimmer: Der Arzt tippt Diagnose und Rezept ins Praxissystem.',
      '2 · Der Konnektor legt die Hülle an — verschlüsselt geht es in die TI.',
      '3 · Durchs TI-Gateway: den bewachten Zugang zur Telematikinfrastruktur.',
      '4 · Fachdienst ePA: In der VAU wird die Akte geschrieben — niemand liest mit.',
      '5 · Sofort da: auf den Handys der Versicherten und beim nächsten Arzt.',
    ]
    schrittZeilen = schritte.map((s) =>
      addText(scene, W / 2, 92, s, 9.5, { color: '#8fd6c8', bold: false, stroke: '#0a1730', strokeThickness: 1 })
        .setOrigin(0.5)
        .setAlpha(0),
    )
  }

  // ---------------------------------------------------------------- Leben
  const leben = scene.add.graphics().setDepth(0)

  // Papier-Pendler der FRÜHER-Phase: wer, wohin, wie viel Papier
  const BOTEN: { a: number; b: number; tempo: number; off: number; p: Person; stapel: number }[] = [
    { a: P.tuer, b: F.tuer, tempo: 22, off: 0, p: P_BESUCH, stapel: 2 },
    { a: KL.tuer, b: A.tuer, tempo: 17, off: 5, p: P_BOTE, stapel: 6 },
    { a: F.tuer, b: KL.tuer, tempo: 26, off: 2, p: P_AERZTIN, stapel: 4 },
    { a: P.tuer, b: A.tuer, tempo: 9, off: 9, p: P_OMA, stapel: 1 },
    { a: P.tuer, b: KL.tuer, tempo: 33, off: 12, p: P_TECHNIK, stapel: 5 },
    { a: F.tuer, b: A.tuer, tempo: 15, off: 7, p: P_PFLEGE, stapel: 3 },
  ]

  // Zyklen zählen ab Szenenstart: Die Geschichte beginnt IMMER bei Zeile 1
  // bzw. Schritt 1 — nicht irgendwo mitten im globalen Takt.
  // WICHTIG: game.loop.time, nicht scene.time.now — der Scene-Clock wird
  // nur während Updates gestellt und ist in create() noch veraltet.
  const t0 = scene.game.loop.time / 1000

  const malLeben = (t: number): void => {
    const l = leben
    l.clear()
    const tz = t - t0

    // Weiter-Zeile erst nach der Mindestdauer; vorher ein feiner Zeitbalken
    const frei = ZEITREISE_SPERRE[phase]
    if (tz < frei) {
      weiter.setAlpha(0)
      l.fillStyle(0xffd591, 0.2)
      l.fillRect(W - 72, 339, 60, 1.6)
      l.fillStyle(0xffd591, 0.6)
      l.fillRect(W - 72, 339, (60 * tz) / frei, 1.6)
    } else {
      weiter.setAlpha(0.65 + 0.35 * Math.sin(tz * 4))
    }

    // Uhr: FRÜHER rast der Minutenzeiger, HEUTE tickt er gemütlich
    const mA = t * (phase === 1 ? 2.4 : 0.06)
    l.lineStyle(1, 0xd8e0f0, 0.95)
    l.beginPath()
    l.moveTo(305, 258)
    l.lineTo(305 + Math.sin(mA) * 6.5, 258 - Math.cos(mA) * 6.5)
    l.moveTo(305, 258)
    l.lineTo(305 + Math.sin(mA / 12 + 0.8) * 4, 258 - Math.cos(mA / 12 + 0.8) * 4)
    l.strokePath()

    if (phase === 1) {
      // Story-Zeilen im Takt durchwechseln (weiche Blenden)
      const us = tz % (FRUEHER_TAKT * FRUEHER_ZEILEN.length)
      for (let i = 0; i < storyZeilen.length; i++) {
        const von = i * FRUEHER_TAKT + (i === 0 ? 0.2 : 0)
        const bis = (i + 1) * FRUEHER_TAKT
        storyZeilen[i].setAlpha(Phaser.Math.Clamp(Math.min((us - von) / 0.45, (bis - us) / 0.45, 1), 0, 1))
      }
      // Pendler mit Aktenstapeln
      for (const b of BOTEN) {
        const xa = Math.min(b.a, b.b)
        const xb = Math.max(b.a, b.b)
        const pos = pendel(t, xa, xb, b.tempo, b.off)
        const schritt = t * (b.tempo / 14)
        malFigur(l, pos.x, BODEN, b.p, schritt, pos.dir)
        malStapel(l, pos.x + pos.dir * 2.5, BODEN, b.stapel, t, b.off)
      }
      // Warteschlangen vor Praxis und Apotheke
      for (const [qx, qp] of [
        [P.tuer + 16, P_PATIENT],
        [P.tuer + 24, P_BESUCH],
        [P.tuer + 32, P_OMA],
        [A.tuer + 16, P_PATIENT],
        [A.tuer + 24, P_TECHNIK],
      ] as [number, Person][]) {
        malFigur(l, qx, BODEN, qp, 0, -1)
      }
      // Verlorene Blätter: flattern herab, liegen kurz, verschwinden
      for (const [ex, eo] of [
        [300, 0],
        [478, 2.2],
        [162, 4.1],
      ]) {
        const u = ((t + eo) % 6) / 6
        if (u < 0.2) {
          const k = u / 0.2
          malBlatt(l, ex + Math.sin(k * 9) * 4, 300 + k * 17, k * 2.4, 0.95)
        } else if (u < 0.85) {
          malBlatt(l, ex + Math.sin(9) * 4, 317.5, 0.18, 0.85)
        } else {
          malBlatt(l, ex + Math.sin(9) * 4, 317.5, 0.18, 0.85 * (1 - (u - 0.85) / 0.15))
        }
      }
      // Ein Blatt segelt im Wind über die ganze Straße
      {
        const u = (t % 9) / 9
        malBlatt(l, -10 + u * 660, 314 - Math.abs(Math.sin(u * 18)) * 4, u * 30, 0.9)
      }
      // Das Fax spuckt ohne Unterlass
      const fax = ((t % 3.2) / 3.2) * 8
      l.fillStyle(0xeef2f8, 0.95)
      l.fillRect(56, 261, 2.8, fax)
    } else {
      // HEUTE als Lehrstück: Ein Eintrag entsteht im Sprechzimmer und reist
      // durch die echte TI. Alles ist eine reine Funktion von u (Zykluszeit
      // ab Szenenstart — der Besucher sieht Schritt 1 zuerst).
      const Z = 30
      const u = tz % Z

      // Schritt-Zeilen weich ein- und ausblenden
      const FENSTER: [number, number][] = [
        [0.4, 7.2],
        [7.2, 10.6],
        [10.6, 14.4],
        [14.4, 20],
        [20, 28],
      ]
      for (let i = 0; i < schrittZeilen.length; i++) {
        const [von, bis] = FENSTER[i]
        schrittZeilen[i].setAlpha(Phaser.Math.Clamp(Math.min((u - von) / 0.5, (bis - u) / 0.5, 1), 0, 1))
      }

      // --- Schritt 1: Gespräch, dann tippt der Arzt ---
      malSitzend(l, 49, 302, P_PATIENT)
      malSitzend(l, 75, 302, P_ARZT)
      if (u < 4.2) {
        const wer = Math.sin(t * 1.6) > 0
        l.fillStyle(0xe9eef8, wer ? 0.9 : 0.25)
        l.fillRoundedRect(44, 283, 8, 5, 1.5)
        l.fillStyle(0x8fd6c8, wer ? 0.25 : 0.9)
        l.fillRoundedRect(72, 281, 8, 5, 1.5)
      }
      const tippen = Phaser.Math.Clamp((u - 4.2) / 2.6, 0, 1)
      if (u >= 4.2 && u < 7.2) {
        l.fillStyle(P_ARZT.haut, 1)
        l.fillRect(69, 292.6 + Math.sin(t * 14) * 0.5, 3.4, 1)
      }
      for (let i = 0; i < 3; i++) {
        const zeile = Phaser.Math.Clamp(tippen * 3 - i, 0, 1)
        if (zeile > 0) {
          l.fillStyle(0x8fd6c8, 0.85)
          l.fillRect(58, 288.5 + i * 2.2, 6 * zeile, 0.9)
        }
      }

      // --- Der Eintrag als Datenfunke: Weg über alle Stationen ---
      const orbPos = (): [number, number] | null => {
        if (u < 7.2) return null
        if (u < 8) {
          const k = (u - 7.2) / 0.8
          return [61 + 12.5 * k, 291 - 16.5 * k] // Monitor → Konnektor
        }
        if (u < 9.6) return [73.5, 274.5] // Hülle anlegen
        if (u < 10.6) return [73.5, 274.5 + (NETZ_Y - 274.5) * (u - 9.6)] // hinab
        if (u < 12.2) return [73.5 + (310 - 73.5) * ((u - 10.6) / 1.6), NETZ_Y]
        if (u < 13.2) return [310, NETZ_Y - 1.5] // Prüfung im Gateway
        if (u < 14.4) return [310 + (399 - 310) * ((u - 13.2) / 1.2), NETZ_Y]
        if (u < 15.4) return [399, NETZ_Y - 4 * (u - 14.4)] // hinein in die VAU
        if (u < 18.6) return [399, 347] // Hülle öffnet sich, Akte wird geschrieben
        return null // gespeichert
      }
      const orb = orbPos()
      if (orb) {
        const [ox, oy] = orb
        // Hülle: warm = offen (vor dem Konnektor), kühl = geschützt danach.
        // In der VAU öffnet sie sich — Klartext IM geschützten Raum.
        const zu = u >= 8.8 && u < 15.6
        if (!zu) {
          l.fillStyle(WARM_OFFEN, 0.3)
          l.fillCircle(ox, oy, 3)
        } else {
          l.fillStyle(K, 0.16)
          l.fillCircle(ox, oy, 3.4)
        }
        if (u >= 8 && u < 8.8) {
          l.lineStyle(0.8, K, 0.9)
          l.strokeCircle(ox, oy, 6 - 3.6 * ((u - 8) / 0.8)) // Hülle schließt sich
        } else if (zu) {
          l.lineStyle(0.8, K, 0.9)
          l.strokeCircle(ox, oy, 2.4)
        } else if (u >= 15.6 && u < 16.4) {
          l.lineStyle(0.8, K, 0.9 * (1 - (u - 15.6) / 0.8))
          l.strokeCircle(ox, oy, 2.4 + 4 * ((u - 15.6) / 0.8)) // öffnet sich in der VAU
        }
        l.fillStyle(0xffffff, 0.95)
        l.fillCircle(ox, oy, 1.1)
      }

      // Konnektor-LEDs: grün, beim Anlegen der Hülle flackert es geschäftig
      for (let i = 0; i < 2; i++) {
        const an = Math.sin(t * (u >= 8 && u < 9.6 ? 9 : 2.2) + i * 1.9) > -0.2
        l.fillStyle(0x7fd07f, an ? 0.95 : 0.25)
        l.fillRect(70.5 + i * 3, 272.5, 1.6, 1.6)
      }
      // Gateway: Scanlinie während der Prüfung, danach ein grüner Haken
      if (u >= 12.2 && u < 13.2) {
        const k = (u - 12.2) / 1
        l.fillStyle(K, 0.35)
        l.fillRect(294 + 30 * k, 344.5, 1.2, 10)
      }
      if (u >= 13 && u < 14.2) {
        l.lineStyle(1, 0x7fd07f, 0.95)
        l.beginPath()
        l.moveTo(320.5, 346.5)
        l.lineTo(322, 348)
        l.lineTo(325, 344.5)
        l.strokePath()
      }
      // Rechenzentrum: Rack-LEDs blinken leise vor sich hin
      for (const [ri, rx] of [421, 437, 453].entries()) {
        for (let reihe = 0; reihe < 4; reihe++) {
          const an = (ri * 7 + reihe * 13 + Math.floor(t * 2.5) * 29) % 11 < 4
          l.fillStyle(an ? K : 0x333c4e, an ? 0.9 : 0.3)
          l.fillRect(rx + 2.5, 342.5 + reihe * 3.2, 1.6, 1.2)
          l.fillRect(rx + 6.5, 342.5 + reihe * 3.2, 1.6, 1.2)
        }
      }
      // --- Schritt 4: Die Akte bekommt ihren neuen Eintrag ---
      {
        l.fillStyle(0xeef2f8, 0.92)
        l.fillRect(400, 342, 9, 11)
        l.fillStyle(0x9aa6bc, 0.8)
        for (let i = 0; i < 3; i++) l.fillRect(401.2, 344 + i * 2.2, 6.6, 0.8)
        const schreiben = Phaser.Math.Clamp((u - 16.4) / 1.8, 0, 1)
        if (schreiben > 0) {
          l.fillStyle(0x2fa88c, 0.95)
          l.fillRect(401.2, 350.6, 6.6 * schreiben, 0.9)
          if (schreiben < 1 && Math.sin(t * 10) > 0) {
            l.fillRect(401.2 + 6.6 * schreiben + 0.4, 350.2, 0.8, 1.6) // Cursor
          }
        }
        if (u >= 18.6 && u < 19.6) {
          l.lineStyle(0.8, 0x7fd07f, 0.9 * (1 - (u - 18.6)))
          l.strokeCircle(404.5, 347.5, 3 + 5 * (u - 18.6))
        }
      }

      // --- Schritt 5: Abruf — App des Patienten und der nächste Arzt ---
      const pulsA = ((): [number, number] | null => {
        if (u < 20 || u >= 23) return null
        const k = (u - 20) / 3
        if (k < 0.6) return [399 + (473 - 399) * (k / 0.6), NETZ_Y]
        return [473, NETZ_Y - (NETZ_Y - 313) * ((k - 0.6) / 0.4)]
      })()
      const pulsB = ((): [number, number] | null => {
        if (u < 21 || u >= 24.6) return null
        const k = (u - 21) / 3.6
        if (k < 0.7) return [399 - (399 - 262) * (k / 0.7), NETZ_Y]
        return [262, NETZ_Y - (NETZ_Y - 293) * ((k - 0.7) / 0.3)]
      })()
      const pulsC = ((): [number, number] | null => {
        if (u < 21.8 || u >= 24.4) return null
        const k = (u - 21.8) / 2.6
        if (k < 0.55) return [399 - (399 - 348) * (k / 0.55), NETZ_Y]
        return [348, NETZ_Y - (NETZ_Y - 313) * ((k - 0.55) / 0.45)]
      })()
      for (const p of [pulsA, pulsB, pulsC]) {
        if (!p) continue
        l.fillStyle(K, 0.2)
        l.fillCircle(p[0], p[1], 2.6)
        l.lineStyle(0.7, K, 0.9)
        l.strokeCircle(p[0], p[1], 1.9)
        l.fillStyle(0xffffff, 0.95)
        l.fillCircle(p[0], p[1], 0.8)
      }
      // Zwei Menschen auf dem Gehweg: Ihre Handys leuchten auf, sobald der
      // Abruf ankommt — mit Benachrichtigungs-Karte über dem Kopf, damit
      // man das Ereignis auch aus der letzten Messereihe sieht.
      const abklang = u > 27.5 ? Phaser.Math.Clamp(28.5 - u, 0, 1) : 1
      const malMeldung = (x: number, seit: number): void => {
        const pop = Phaser.Math.Clamp(seit / 0.35, 0, 1)
        const oy = BODEN - 22 - 4 * pop
        l.fillStyle(0xeef2f8, 0.95 * abklang)
        l.fillRoundedRect(x - 4.5, oy, 10, 8.5, 1.2)
        l.fillTriangle(x - 0.5, oy + 8.5, x + 1.8, oy + 8.5, x + 0.6, oy + 10.2)
        l.fillStyle(0x2fa88c, 0.95 * abklang)
        l.fillRect(x - 3, oy + 1.6, 7, 1.1)
        l.fillStyle(0x9aa6bc, 0.85 * abklang)
        l.fillRect(x - 3, oy + 3.6, 7, 1)
        l.fillRect(x - 3, oy + 5.6, 4.6, 1)
      }
      const malHandyMensch = (fx: number, p: Person, an: boolean, seit: number): void => {
        malFigur(l, fx, BODEN, p, 0, 1)
        if (an) {
          l.fillStyle(K, 0.22 * abklang)
          l.fillCircle(fx + 3.8, BODEN - 6.3, 4)
        }
        l.fillStyle(K, an ? 0.95 : 0.35)
        l.fillRect(fx + 3, BODEN - 7.6, 1.6, 2.6)
        if (an) {
          const k = (((seit % 1.6) + 1.6) % 1.6) / 1.6
          l.lineStyle(0.6, K, 0.7 * (1 - k) * abklang)
          l.strokeCircle(fx + 3.8, BODEN - 6.4, 2 + 5 * k)
          malMeldung(fx + 3.8, seit)
        }
      }
      malHandyMensch(470, P_BESUCH, u >= 23 && u < 28.5, u - 23)
      malHandyMensch(
        345,
        { haut: HAUT[1], oben: 0x6a8f4d, unten: 0x2e3a50, haar: 0x2b2530 },
        u >= 24.4 && u < 28.5,
        u - 24.4,
      )
      // Facharzt: dieselben Zeilen erscheinen auf seinem Monitor
      malSitzend(l, 250, 302, P_AERZTIN)
      if (u >= 24.6 && u < 28.5) {
        l.fillStyle(K, 0.1 * abklang) // Lese-Glow hinter dem Monitor
        l.fillCircle(262, 291, 7)
        const lesen = Phaser.Math.Clamp((u - 24.6) / 1.2, 0, 1)
        const blende = u > 27.5 ? 1 - (u - 27.5) : 1
        for (let i = 0; i < 3; i++) {
          const zeile = Phaser.Math.Clamp(lesen * 3 - i, 0, 1)
          if (zeile > 0) {
            l.fillStyle(0x8fd6c8, 0.85 * blende)
            l.fillRect(259, 288.3 + i * 1.8, 6 * zeile, 0.8)
          }
        }
        l.fillStyle(0x2fa88c, 0.9 * blende)
        if (lesen >= 1) l.fillRect(259, 288.3 + 3 * 1.8, 6, 0.8)
      }

      // Hintergrundleben: ein Spaziergänger, der Kaffee-Bote von früher
      const s1 = pendel(t, 310, 620, 11, 20)
      malFigur(l, s1.x, BODEN, P_OMA, t * 0.8, s1.dir)
      malFigur(l, KL.tuer + 22, BODEN, P_BOTE, 0, -1)
      l.fillStyle(0xd8e0f0, 0.95)
      l.fillRect(KL.tuer + 17.5, BODEN - 7.8, 1.8, 2.2)
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
