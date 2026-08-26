import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { darken, depthMix, fogColor } from './atmos'
import { addGlow } from './effects'
import { addText } from './text'
import { KUEHL_GESCHUETZT, WARM_OFFEN } from './material'

/**
 * KRANKENHAUS-KULISSE — die Attract-Bühne als lebendes Wimmelbild.
 *
 * Ein Klinikum im Puppenhaus-Schnitt (wie ein aufgeklapptes Setzkasten-Haus):
 * OP, Stationen, Flur, Empfang — und darunter der Keller, in dem die TI
 * wohnt (Konnektor → VAU → Fachdienst ePA). Genau die Pointe des Spiels:
 * Oben sieht man Medizin, unten läuft unsichtbar die Infrastruktur, und
 * kleine Datenpulse wandern vom Empfangs-Terminal hinunter in den Keller.
 *
 * Aufbau in zwei Schichten:
 *  - `statik`: einmal gezeichnet (Gebäude, Möbel, Straße, Schilder).
 *  - `leben`:  wird jeden Frame neu gezeichnet — alles, was sich bewegt,
 *              ist eine REINE FUNKTION der Zeit t (kein Zustand, keine
 *              Timer): Läufer pendeln, Heli und Rettungswagen folgen einem
 *              festen Zyklus, Monitore zeichnen ihre EKG-Kurve selbst.
 *              Dasselbe Muster wie `veredele()` in vektor.ts.
 *
 * Barrierefreiheit: kein Blinken über 3 Hz (Blaulicht 2,5 Hz, Beacon 2 Hz).
 * KAPSEL 4.5: keine geschützten Symbole — kein rotes Kreuz, stattdessen
 * weißes H auf Blau, EKG-Linien und Wortmarken als Easter Eggs.
 */

// ---------------------------------------------------------------- Bühnenmaße
// Design-Raum 640×360, Boden wie im Backdrop bei H−40 = 320.
const BODEN = 320
const HAUS = { links: 84, rechts: 484, dach: 138 }
/** Geschossdecken (Oberkanten): Dach, 2. OG, 1. OG, EG-Decke, EG-Boden. */
const DECKEN = [138, 176, 214, 252, 316]
const SCHACHT = { links: 450, rechts: 476 }
const KELLER = { links: 96, rechts: 472, oben: 324, unten: 352 }
/** Fußhöhen je Ebene (auf der jeweiligen Decke stehend). */
const FUSS = { f3: 176, f2: 214, f1: 252, eg: 316, keller: 348, strasse: 320 }

// ---------------------------------------------------------------- Menschen
const HAUT = [0xeec39a, 0xc98850, 0x8a5a3b]

interface Person {
  haut: number
  oben: number
  unten: number
  haar: number
  /** Weißer Arztkittel über der Kleidung. */
  kittel?: boolean
}

const P_ARZT: Person = { haut: HAUT[0], oben: 0x5c7ba8, unten: 0x33405c, haar: 0x2b2530, kittel: true }
const P_AERZTIN: Person = { haut: HAUT[2], oben: 0x8a5f9e, unten: 0x33405c, haar: 0x14101a, kittel: true }
const P_PFLEGE: Person = { haut: HAUT[1], oben: 0x5fc4b8, unten: 0x3d5a74, haar: 0x6b4326 }
const P_OP: Person = { haut: HAUT[0], oben: 0x69b894, unten: 0x4d8a70, haar: 0x69b894 } // Haube
const P_PATIENT: Person = { haut: HAUT[1], oben: 0xa9b9d6, unten: 0xa9b9d6, haar: 0xcfd4de }
const P_BESUCH: Person = { haut: HAUT[0], oben: 0xc07a4f, unten: 0x2e3a50, haar: 0x8a5a33 }
const P_TECHNIK: Person = { haut: HAUT[2], oben: 0x4d6a8f, unten: 0x2e3a50, haar: 0x2b2530 }

/**
 * Pixel-Figur, ~13 px hoch, Füße auf (x, yFuss). `schritt` ist der
 * Laufzyklus (0 = stehen), `dir` die Blickrichtung (nur fürs Haar).
 */
function malFigur(
  g: Phaser.GameObjects.Graphics,
  x: number,
  yFuss: number,
  p: Person,
  schritt = 0,
  dir: 1 | -1 = 1,
): void {
  const bob = schritt === 0 ? 0 : Math.abs(Math.sin(schritt * Math.PI * 2)) * 0.6
  const bein = schritt === 0 ? 0 : Math.sin(schritt * Math.PI * 2) * 1.7
  const y = yFuss - bob
  g.fillStyle(p.unten, 1)
  g.fillRect(x - 2 + bein, y - 4, 1.8, 4 + bob)
  g.fillRect(x + 0.2 - bein, y - 4, 1.8, 4 + bob)
  g.fillStyle(p.kittel ? 0xe9eef8 : p.oben, 1)
  g.fillRect(x - 2.6, y - 9.2, 5.2, 5.4)
  if (p.kittel) {
    // Offener Kittel: das Hemd blitzt in der Mitte durch
    g.fillStyle(p.oben, 1)
    g.fillRect(x - 0.7, y - 9.2, 1.4, 5.4)
  }
  // Arme schwingen gegenläufig zu den Beinen
  g.fillStyle(p.kittel ? 0xe9eef8 : p.oben, 1)
  g.fillRect(x - 3.4 - bein * 0.4, y - 8.8, 1, 3.6)
  g.fillRect(x + 2.4 + bein * 0.4, y - 8.8, 1, 3.6)
  g.fillStyle(p.haut, 1)
  g.fillRect(x - 1.8, y - 13, 3.6, 3.8)
  g.fillStyle(p.haar, 1)
  g.fillRect(x - 1.8, y - 13, 3.6, 1.3)
  // Haaransatz seitlich = Blickrichtung, sonst schaut die Figur ins Leere
  if (dir === 1) g.fillRect(x - 1.8, y - 13, 1, 2.6)
  else g.fillRect(x + 0.8, y - 13, 1, 2.6)
}

/** Sitzende Figur auf Sitzhöhe `ySitz`; `beinSchwung` lässt Beine baumeln. */
function malSitzend(g: Phaser.GameObjects.Graphics, x: number, ySitz: number, p: Person, beinSchwung = 0): void {
  g.fillStyle(p.unten, 1)
  g.fillRect(x - 2.4, ySitz - 1.6, 4.6, 1.6)
  g.fillRect(x + 1 + beinSchwung, ySitz, 1.6, 3.4)
  g.fillRect(x - 1.6 - beinSchwung, ySitz, 1.6, 3.4)
  g.fillStyle(p.kittel ? 0xe9eef8 : p.oben, 1)
  g.fillRect(x - 2.4, ySitz - 6.8, 4.8, 5.2)
  g.fillStyle(p.haut, 1)
  g.fillRect(x - 1.7, ySitz - 10.4, 3.4, 3.6)
  g.fillStyle(p.haar, 1)
  g.fillRect(x - 1.7, ySitz - 10.4, 3.4, 1.2)
}

/** Krankenbett mit atmender Decke, Kopf rechts. Komplett dynamisch — billig. */
function malBett(
  g: Phaser.GameObjects.Graphics,
  x: number,
  yBoden: number,
  decke: number,
  haut: number,
  t: number,
  phase: number,
): void {
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(x, yBoden - 6, 1.6, 6)
  g.fillRect(x + 20.5, yBoden - 6, 1.6, 6)
  g.fillStyle(0xcfd6e6, 1)
  g.fillRect(x - 0.5, yBoden - 7.6, 23, 1.8)
  g.fillStyle(0xf2f5fb, 0.95)
  g.fillRect(x + 17, yBoden - 9.6, 5, 2.2)
  g.fillStyle(haut, 1)
  g.fillRect(x + 18, yBoden - 11.2, 3.2, 2.6)
  const atem = Math.sin(t * 1.4 + phase) * 0.5
  g.fillStyle(decke, 1)
  g.fillRect(x + 1, yBoden - 9.8, 16.5, 2.6)
  g.fillRect(x + 6, yBoden - 10.8 - atem, 7, 1.4)
}

// ---------------------------------------------------------------- EKG & Wege

/** PQRST grob: flach, kleine Welle, Spitze, Tal, Erholung — reicht fürs Auge. */
function ekgPuls(u: number): number {
  if (u < 0.55) return 0
  if (u < 0.62) return -0.25
  if (u < 0.68) return 1
  if (u < 0.74) return -0.55
  if (u < 0.84) return 0.18
  return 0
}

function malEkg(
  g: Phaser.GameObjects.Graphics,
  x: number,
  yMitte: number,
  w: number,
  amp: number,
  t: number,
  phase: number,
): void {
  g.lineStyle(0.6, KUEHL_GESCHUETZT, 0.9)
  g.beginPath()
  const N = 14
  for (let i = 0; i <= N; i++) {
    const u = i / N
    const v = ekgPuls((u * 1.15 + t * 0.55 + phase) % 1)
    const yy = yMitte - v * amp
    if (i === 0) g.moveTo(x + u * w, yy)
    else g.lineTo(x + u * w, yy)
  }
  g.strokePath()
}

/** Überwachungsmonitor am Ständer neben einem Bett. */
function malMonitor(g: Phaser.GameObjects.Graphics, x: number, yBoden: number, t: number, phase: number): void {
  g.fillStyle(0x39445e, 1)
  g.fillRect(x + 3.6, yBoden - 6, 1.4, 6)
  g.fillStyle(0x0a1220, 1)
  g.fillRect(x, yBoden - 13, 9, 7)
  g.lineStyle(0.6, 0x39445e, 1)
  g.strokeRect(x, yBoden - 13, 9, 7)
  malEkg(g, x + 0.8, yBoden - 9.4, 7.4, 2.2, t, phase)
}

/** Hin- und herlaufende Figur zwischen xa und xb (Dreieckswelle über t). */
function pendel(t: number, xa: number, xb: number, tempo: number, versatz: number): { x: number; dir: 1 | -1 } {
  const dauer = (xb - xa) / tempo
  const u = ((t + versatz) / dauer) % 2
  return u < 1 ? { x: xa + (xb - xa) * u, dir: 1 } : { x: xb - (xb - xa) * (u - 1), dir: -1 }
}

/** Polylinien-Pfad für die wandernden Datenpulse (Terminal → Keller-TI). */
interface Pfad {
  pts: [number, number][]
  laengen: number[]
  gesamt: number
}

function pfad(pts: [number, number][]): Pfad {
  const laengen: number[] = []
  let gesamt = 0
  for (let i = 0; i + 1 < pts.length; i++) {
    const l = Math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
    laengen.push(l)
    gesamt += l
  }
  return { pts, laengen, gesamt }
}

function pfadPunkt(p: Pfad, u: number): [number, number] {
  let rest = Phaser.Math.Clamp(u, 0, 1) * p.gesamt
  for (let i = 0; i < p.laengen.length; i++) {
    if (rest <= p.laengen[i]) {
      const k = p.laengen[i] === 0 ? 0 : rest / p.laengen[i]
      const a = p.pts[i]
      const b = p.pts[i + 1]
      return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k]
    }
    rest -= p.laengen[i]
  }
  return p.pts[p.pts.length - 1]
}

// ---------------------------------------------------------------- Hauptaufbau

export function zeichneKrankenhaus(scene: Phaser.Scene, theme: Theme, W: number, H: number): void {
  void H
  const fog = fogColor(theme)
  const K = KUEHL_GESCHUETZT
  const accent = Phaser.Display.Color.HexStringToColor(theme.accent).color
  const detail = Phaser.Display.Color.HexStringToColor(theme.detail).color

  // Palette: alles aus der Farbwelt abgeleitet, damit die Kulisse zum Rest passt
  const wand = darken(theme.skyTop, 0.35)
  const raum = darken(theme.skyBottom, 0.62)
  const raumHell = darken(theme.skyBottom, 0.52)
  const fensterHell = depthMix(theme.skyBottom, fog, 0.55)
  const strasse = darken(theme.ground, 0.45)
  const gehweg = darken(theme.groundTop, 0.3)

  const statik = scene.add.graphics().setDepth(0)
  const g = statik

  // ---- Straße & Gehweg (volle Breite; der Keller überdeckt sie im Haus) ----
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
  // Zebrastreifen vor dem Eingang + Gullydeckel
  for (let i = 0; i < 4; i++) {
    g.fillStyle(0xffffff, 0.26 - i * 0.04)
    g.fillRect(190, 328 + i * 6, 34, 3)
  }
  g.fillStyle(0x1a2333, 0.9)
  g.fillEllipse(368, 333, 7, 2.6)
  g.lineStyle(0.5, detail, 0.4)
  g.strokeEllipse(368, 333, 7, 2.6)

  // ---- Kleiner Park links: Bäume, Bank mit Leser, Laterne ----
  const laub = depthMix('#3a6a55', fog, 0.25)
  const treeAt = (tx: number, s: number): void => {
    g.fillStyle(0x3a2f28, 1)
    g.fillRect(tx - 1, BODEN - 10 * s, 2, 10 * s)
    g.fillStyle(laub, 1)
    g.fillRect(tx - 6 * s, BODEN - 20 * s, 12 * s, 9 * s)
    g.fillRect(tx - 4 * s, BODEN - 24 * s, 8 * s, 6 * s)
    g.fillStyle(0xffffff, 0.06)
    g.fillRect(tx - 6 * s, BODEN - 20 * s, 12 * s, 1)
  }
  treeAt(20, 1.1)
  treeAt(38, 0.8)
  // Bank
  g.fillStyle(0x3a4358, 1)
  g.fillRect(46, 312, 1.6, 8)
  g.fillRect(64, 312, 1.6, 8)
  g.fillStyle(0x6b5a3f, 1)
  g.fillRect(44, 311, 24, 1.8)
  g.fillRect(44, 305, 24, 1.4)
  malSitzend(g, 54, 310, P_BESUCH)
  g.fillStyle(0xe9eef8, 0.9) // Zeitung
  g.fillRect(56.5, 302, 4, 3)
  // Laterne
  g.fillStyle(0x39445e, 1)
  g.fillRect(75, 282, 1.6, 38)
  g.fillStyle(0xffd9a0, 0.95)
  g.fillRect(73.6, 279, 4.4, 3.4)

  // ---- Hauptgebäude: Hülle, Geschossdecken, Aufzugsschacht ----
  g.fillStyle(wand, 1)
  g.fillRect(HAUS.links, HAUS.dach, HAUS.rechts - HAUS.links, BODEN - HAUS.dach)
  // Innenräume je Geschoss (der Schnitt: man sieht hinein)
  for (let i = 0; i + 1 < DECKEN.length; i++) {
    g.fillStyle(i % 2 === 0 ? raum : raumHell, 1)
    g.fillRect(90, DECKEN[i] + 4, SCHACHT.links - 90, DECKEN[i + 1] - DECKEN[i] - 4)
  }
  // Geschossdecken
  for (const y of DECKEN) {
    g.fillStyle(detail, 0.85)
    g.fillRect(HAUS.links - 2, y, HAUS.rechts - HAUS.links + 4, 4)
    g.fillStyle(0xffffff, 0.14)
    g.fillRect(HAUS.links - 2, y, HAUS.rechts - HAUS.links + 4, 0.7)
  }
  // Außenwände
  g.fillStyle(darken(theme.skyTop, 0.5), 1)
  g.fillRect(HAUS.links, HAUS.dach, 6, BODEN - HAUS.dach)
  g.fillRect(HAUS.rechts - 8, HAUS.dach, 8, BODEN - HAUS.dach)
  // Aufzugsschacht (alle Geschosse) + Maschinenhäuschen auf dem Dach
  g.fillStyle(darken(theme.skyTop, 0.55), 1)
  g.fillRect(SCHACHT.links - 2, 142, SCHACHT.rechts - SCHACHT.links + 4, 316 - 142)
  g.fillStyle(0x0b1322, 1)
  g.fillRect(SCHACHT.links, 142, SCHACHT.rechts - SCHACHT.links, 316 - 142)
  g.fillStyle(wand, 1)
  g.fillRect(SCHACHT.links - 2, 122, SCHACHT.rechts - SCHACHT.links + 4, 16)
  g.fillStyle(detail, 0.8)
  g.fillRect(SCHACHT.links - 2, 122, SCHACHT.rechts - SCHACHT.links + 4, 1.5)
  g.fillStyle(0x0e1a2c, 1) // Dachtür fürs Heli-Team
  g.fillRect(SCHACHT.links + 6, 126, 9, 12)
  g.fillStyle(accent, 0.7)
  g.fillCircle(SCHACHT.links + 13, 132, 0.7)

  // ---- Dach: Brüstung, Schild, Lüftung, Helipad, Antenne ----
  g.fillStyle(detail, 0.9)
  g.fillRect(HAUS.links - 2, HAUS.dach - 2, HAUS.rechts - HAUS.links + 4, 2)
  // Schild „gematik KLINIKUM" (Wortmarke als Easter Egg — kein Logo).
  // Sitzt bewusst links UNTER der Titel-Subline direkt auf der Dachkante,
  // damit sich die beiden Schriften nicht ins Gehege kommen.
  g.fillStyle(0x0d2440, 0.96)
  g.fillRect(104, 116, 72, 22)
  g.lineStyle(1, detail, 0.8)
  g.strokeRect(104, 116, 72, 22)
  g.fillStyle(K, 0.8) // türkise Unterlinie — Farbnicken Richtung TI
  g.fillRect(112, 129.5, 56, 1)
  // Lüftungskasten (Dampf kommt per Tween, siehe unten)
  g.fillStyle(0x39445e, 1)
  g.fillRect(246, 130, 14, 8)
  g.fillRect(249, 126, 3, 4)
  g.fillRect(255, 126, 3, 4)
  // Helipad: Podest + Kreis + „H"
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(384, 132, 4, 6)
  g.fillRect(448, 132, 4, 6)
  g.fillStyle(0x1c2536, 1)
  g.fillRect(378, 128, 82, 4)
  g.lineStyle(1.2, 0xd8e0f0, 0.75)
  g.strokeEllipse(419, 130, 26, 2.6)
  g.fillStyle(0xd8e0f0, 0.85)
  g.fillRect(415, 128.6, 1.6, 2.8)
  g.fillRect(421.4, 128.6, 1.6, 2.8)
  g.fillRect(415, 129.6, 8, 0.9)
  // Antenne (die Klinik ist ans Netz angeschlossen …)
  g.fillStyle(0x39445e, 1)
  g.fillRect(466, 96, 1.8, 42)
  g.fillRect(462, 104, 10, 1.2)
  g.fillRect(463.5, 112, 7, 1.2)
  g.fillStyle(detail, 0.9)
  g.fillEllipse(463, 106, 4, 3)

  // ================================================================ 2. OG
  // OP-Saal | Labor | KIM-Büro | Röntgen
  for (const tx of [190, 282, 372]) {
    g.fillStyle(darken(theme.skyTop, 0.45), 1)
    g.fillRect(tx, 142, 2, 34)
  }
  // OP: Lampe, Tisch, Geräteturm (Chirurgen + Patient sind dynamisch)
  g.fillStyle(0x39445e, 1)
  g.fillRect(137, 142, 1.4, 6)
  g.fillStyle(0xe9eef8, 0.95)
  g.fillRect(132, 148, 11, 2.6)
  g.fillStyle(0xffffff, 0.06) // Lichtkegel
  g.fillTriangle(137.5, 151, 122, 168, 154, 168)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(120, 168, 40, 2.4)
  g.fillRect(126, 170, 3, 6)
  g.fillRect(150, 170, 3, 6)
  g.fillStyle(0x39445e, 1) // Instrumentenwagen
  g.fillRect(104, 166, 9, 2)
  g.fillRect(107, 168, 1.4, 8)
  g.fillStyle(0xd8e0f0, 0.9)
  g.fillRect(105, 164.5, 2.5, 1.2)
  g.fillRect(109, 164.5, 3.5, 1.2)
  // Labor: Werkbank, Regal, Kolben in Kartenfarben (eGK/HBA/SMC-B — wer's kennt)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(196, 164, 78, 2.4)
  g.fillRect(200, 166.4, 2.4, 9.6)
  g.fillRect(266, 166.4, 2.4, 9.6)
  g.fillStyle(detail, 0.6)
  g.fillRect(198, 150, 44, 1.6)
  for (let i = 0; i < 5; i++) {
    const farben = [0x7fd07f, 0x4de3ff, 0xffd75e, 0x7fd07f, 0x9a7ae8]
    g.fillStyle(farben[i], 0.85)
    g.fillRect(202 + i * 8, 146.5, 3, 3.5)
  }
  g.fillStyle(0x7fd07f, 0.9)
  g.fillTriangle(226, 164, 233, 164, 229.5, 157)
  g.fillStyle(0x4de3ff, 0.9)
  g.fillRect(244, 158, 3, 6)
  // KIM-Büro: Schreibtisch + Monitor (Briefumschlag pingt dynamisch)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(292, 166, 34, 2.4)
  g.fillRect(296, 168.4, 2.4, 7.6)
  g.fillRect(318, 168.4, 2.4, 7.6)
  g.fillStyle(0x0a1220, 1)
  g.fillRect(297, 157, 9, 7)
  g.lineStyle(0.6, 0x39445e, 1)
  g.strokeRect(297, 157, 9, 7)
  g.fillStyle(detail, 0.5) // Pinnwand
  g.fillRect(338, 150, 16, 10)
  g.fillStyle(0xffd75e, 0.7)
  g.fillRect(340, 152, 4, 3)
  g.fillStyle(0x7fd07f, 0.7)
  g.fillRect(347, 154, 4, 3)
  // Röntgen: Leuchtkasten mit Brustkorb + Anatomie-Skelett in der Ecke
  g.fillStyle(0x0a1626, 1)
  g.fillRect(380, 146, 36, 24)
  g.lineStyle(0.8, 0x39445e, 1)
  g.strokeRect(380, 146, 36, 24)
  g.lineStyle(0.8, 0xcfe4ff, 0.75)
  g.beginPath()
  g.moveTo(398, 149)
  g.lineTo(398, 167)
  g.strokePath()
  for (let i = 0; i < 5; i++) {
    g.lineStyle(0.6, 0xcfe4ff, 0.6)
    g.strokeEllipse(398, 152 + i * 3.2, 10 - i * 0.8, 2)
  }
  g.fillStyle(0xe9eef8, 0.9) // Skelett-Modell
  g.fillRect(438, 148, 3.4, 3.4)
  g.fillRect(439.2, 151.4, 1, 8)
  for (let i = 0; i < 3; i++) g.fillRect(436.6, 153 + i * 2.2, 6.2, 0.9)
  g.fillRect(437, 161, 5.4, 1.4)
  g.fillRect(437.4, 162.4, 1.2, 8)
  g.fillRect(440.8, 162.4, 1.2, 8)
  g.fillRect(438, 170.5, 1.4, 5.5)
  g.fillRect(440.4, 170.5, 1.4, 5.5)

  // ================================================================ 1. OG
  // Drei Patientenzimmer + Stationszimmer (Betten sind dynamisch)
  for (const tx of [190, 288, 386]) {
    g.fillStyle(darken(theme.skyTop, 0.45), 1)
    g.fillRect(tx, 180, 2, 34)
  }
  // Rückfenster — dahinter heller Himmel: der Schnitt bekommt Tiefe
  for (const fx of [112, 160, 226, 258, 318, 356]) {
    g.fillStyle(fensterHell, 0.85)
    g.fillRect(fx, 184, 6, 8)
    g.fillStyle(0xffffff, 0.12)
    g.fillRect(fx, 184, 6, 0.8)
  }
  // Zimmer 1: Infusionsständer (Tropfen dynamisch)
  g.fillStyle(0x39445e, 1)
  g.fillRect(98, 192, 1.2, 22)
  g.fillRect(95, 192, 7, 1.2)
  g.fillStyle(0xffd75e, 0.85)
  g.fillRect(94.5, 193, 3, 4.4)
  // Zimmer 2: TV an der Wand (Flimmern dynamisch), Schrank
  g.fillStyle(0x0a1220, 1)
  g.fillRect(262, 186, 14, 8)
  g.lineStyle(0.6, 0x39445e, 1)
  g.strokeRect(262, 186, 14, 8)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(240, 200, 12, 14)
  g.fillStyle(detail, 0.5)
  g.fillRect(240, 206.5, 12, 0.8)
  // Zimmer 3: Rollstuhl + Pflanze
  g.lineStyle(0.9, 0x8fa2c4, 0.9)
  g.strokeCircle(348, 209, 4.4)
  g.strokeCircle(354.5, 211.5, 1.8)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(344, 200, 7, 2)
  g.fillRect(343, 196, 1.6, 6)
  g.fillStyle(0x3a6a55, 1)
  g.fillRect(370, 204, 5, 6)
  g.fillStyle(0x7fd07f, 0.8)
  g.fillRect(369, 199, 7, 5)
  // Stationszimmer: Tresen + Kaffeemaschine (LED dynamisch)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(392, 202, 30, 2.4)
  g.fillRect(394, 204.4, 2.4, 9.6)
  g.fillRect(416, 204.4, 2.4, 9.6)
  g.fillStyle(0x39445e, 1)
  g.fillRect(428, 196, 10, 12)
  g.fillStyle(0xd8e0f0, 0.85)
  g.fillRect(430.5, 205.5, 3, 2)

  // ================================================================ EG-Flur (1. OG unten)
  // Offener Flur: Türen an der Rückwand, Uhr, geparkte Liege, TIM-Ecke
  for (const tx of [120, 168, 216, 264, 312]) {
    g.fillStyle(darken(theme.skyBottom, 0.72), 1)
    g.fillRect(tx, 226, 10, 26)
    g.fillStyle(accent, 0.5)
    g.fillCircle(tx + 8, 240, 0.7)
    g.fillStyle(detail, 0.6)
    g.fillRect(tx + 2, 229, 6, 1.6)
  }
  g.fillStyle(detail, 0.3)
  g.fillRect(92, 249, SCHACHT.links - 94, 1)
  // Geparkte Rolltrage
  g.fillStyle(0xcfd6e6, 1)
  g.fillRect(96, 240, 20, 1.8)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(98, 242, 1.4, 8)
  g.fillRect(111, 242, 1.4, 8)
  g.fillStyle(0x8fa2c4, 0.9)
  g.fillCircle(99, 251, 1.4)
  g.fillCircle(112, 251, 1.4)
  g.fillStyle(0xf2f5fb, 0.9)
  g.fillRect(110, 237.6, 5, 2)

  // ================================================================ Erdgeschoss
  // Notaufnahme-Bucht | Eingangshalle | Empfang | Wartebereich
  g.fillStyle(darken(theme.skyTop, 0.45), 1)
  g.fillRect(152, 256, 2, 60)
  // Notaufnahme: Rolltor mit Lamellen + Rampe zur Straße
  g.fillStyle(darken(theme.skyBottom, 0.72), 1)
  g.fillRect(100, 262, 42, 54)
  for (let y = 266; y < 314; y += 6) {
    g.fillStyle(detail, 0.35)
    g.fillRect(102, y, 38, 1)
  }
  g.fillStyle(gehweg, 1)
  g.fillTriangle(96, BODEN + 6, 148, BODEN + 6, 148, BODEN - 2)
  // Eingang: Glasfront, Vordach, weißes H auf Blau (Schiebetüren dynamisch)
  g.fillStyle(0x0d1a2c, 1)
  g.fillRect(184, 262, 40, 54)
  g.lineStyle(0.8, detail, 0.7)
  g.strokeRect(184, 262, 40, 54)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(178, 256, 52, 4)
  // Weißes H auf Blau: an der Wand NEBEN dem Eingang. Über dem Vordach wäre
  // es im aufgeschnittenen Flur — dort rollen Tragen quer durchs Schild.
  g.fillStyle(0x1d4f9c, 1)
  g.fillRect(162, 257, 16, 12)
  g.fillStyle(0xffffff, 0.95)
  g.fillRect(165, 259.5, 2.4, 7)
  g.fillRect(172.6, 259.5, 2.4, 7)
  g.fillRect(165, 262, 10, 2)
  // EKG-Neonlinie über der Schiebetür — das Gesundheits-Zeichen des Spiels
  malEkg(g, 186, 259.5, 36, 2, 0.35, 0)
  // Wegweiser in der Halle (drei farbige Pfeile — Kartenfarben)
  g.fillStyle(0x0e1a2c, 0.9)
  g.fillRect(162, 271, 18, 14)
  for (let i = 0; i < 3; i++) {
    const farben = [0x7fd07f, 0x4de3ff, 0xffd75e]
    g.fillStyle(farben[i], 0.85)
    g.fillRect(164, 274 + i * 3.6, 10, 1.4)
    g.fillTriangle(174, 273.2 + i * 3.6, 174, 276.4 + i * 3.6, 177, 274.8 + i * 3.6)
  }
  // E-Rezept-Plakat mit Pixel-QR (der Bogen zur Telemetrie-Wand des Spiels)
  g.fillStyle(0xf2f5fb, 0.92)
  g.fillRect(230, 266, 14, 18)
  g.fillStyle(0x0d1a2c, 1)
  for (let i = 0; i < 6; i++)
    for (let j = 0; j < 6; j++) {
      if ((i * 3 + j * 5 + ((i * j) % 3)) % 4 < 2) g.fillRect(232 + i * 1.7, 268 + j * 1.7, 1.4, 1.4)
    }
  g.fillRect(232, 268, 3.4, 3.4)
  g.fillRect(238.8, 268, 3.4, 3.4)
  g.fillRect(232, 274.8, 3.4, 3.4)
  g.fillStyle(K, 0.9)
  g.fillRect(232, 280.5, 10, 1.6)
  // Empfangstresen + Kartenterminal (Personal & Patient dynamisch)
  g.fillStyle(0x2f3a52, 1)
  g.fillRect(258, 300, 64, 16)
  g.fillStyle(0x39445e, 1)
  g.fillRect(256, 298, 68, 3)
  g.fillStyle(0xffffff, 0.1)
  g.fillRect(256, 298, 68, 0.8)
  // Die drei Ausweise des Spiels als Aufkleber am Tresen: eGK, HBA, SMC-B
  g.fillStyle(0x7fd07f, 0.85)
  g.fillRect(264, 305, 4, 2.6)
  g.fillStyle(0x4de3ff, 0.85)
  g.fillRect(270, 305, 4, 2.6)
  g.fillStyle(0xffd75e, 0.85)
  g.fillRect(276, 305, 4, 2.6)
  // Kartenterminal mit steckender SMC-B
  g.fillStyle(0x39445e, 1)
  g.fillRect(304, 290, 10, 8)
  g.fillStyle(0x0a1220, 1)
  g.fillRect(305.5, 291.5, 7, 4)
  g.fillStyle(0xffd75e, 0.95)
  g.fillRect(313, 295.5, 3.4, 1.6)
  // Wartebereich: Stühle, Automat, Plakat „116 117"
  for (const cx of [346, 362, 378]) {
    g.fillStyle(0x39445e, 1)
    g.fillRect(cx - 3, 306, 6, 1.6)
    g.fillRect(cx - 3, 307.6, 1.2, 8.4)
    g.fillRect(cx + 1.8, 307.6, 1.2, 8.4)
    g.fillRect(cx + 2.4, 298, 1.2, 8.4)
  }
  g.fillStyle(0x2f3a52, 1) // Snackautomat
  g.fillRect(424, 288, 18, 28)
  g.fillStyle(0x102138, 1)
  g.fillRect(426, 290, 10, 20)
  for (let r = 0; r < 3; r++)
    for (let c = 0; c < 3; c++) {
      const farben = [0xffd75e, 0x7fd07f, 0x9a7ae8]
      g.fillStyle(farben[(r + c) % 3], 0.8)
      g.fillRect(427.5 + c * 3, 292 + r * 5, 2, 3)
    }
  g.fillStyle(0x0e1a2c, 0.92) // Plakat 116117 (Text kommt unten dazu) —
  g.fillRect(394, 276, 24, 13) // unterhalb der Steuerungslegende (y≈262–274)
  g.lineStyle(0.6, detail, 0.7)
  g.strokeRect(394, 276, 24, 13)
  g.fillStyle(0x3a6a55, 1) // Pflanze am Übergang
  g.fillRect(338, 308, 5, 8)
  g.fillStyle(0x7fd07f, 0.8)
  g.fillRect(336.5, 302, 8, 6)

  // ================================================================ Keller: hier wohnt die TI
  g.fillStyle(0x080d16, 1)
  g.fillRect(KELLER.links, KELLER.oben, KELLER.rechts - KELLER.links, KELLER.unten - KELLER.oben)
  g.lineStyle(1, darken(theme.skyTop, 0.2), 0.5)
  g.strokeRect(KELLER.links, KELLER.oben, KELLER.rechts - KELLER.links, KELLER.unten - KELLER.oben)
  for (const tx of [190, 300, 390]) {
    g.fillStyle(darken(theme.skyTop, 0.35), 1)
    g.fillRect(tx, KELLER.oben, 2, KELLER.unten - KELLER.oben)
  }
  // Technikraum: Konnektor an der Wand (LEDs dynamisch — inkl. „hängt mal wieder")
  g.fillStyle(0x3a4358, 1)
  g.fillRect(108, 328, 20, 13)
  g.lineStyle(0.7, detail, 0.8)
  g.strokeRect(108, 328, 20, 13)
  g.fillStyle(0xffd75e, 0.95) // steckende SMC-B auch hier
  g.fillRect(126.5, 336, 3.6, 2)
  // VAU: kühler, geschützter Raum mit Tresortür — hier wird im Klartext gearbeitet
  g.fillStyle(K, 0.05)
  g.fillRect(192, KELLER.oben + 1, 106, KELLER.unten - KELLER.oben - 2)
  // Tresortür bewusst gedämpft und etwas höher: Auf Höhe 338 läuft die
  // Footer-Zeile der AttractScene — eine helle Rosette dahinter las sich
  // wie ein verunglücktes Zeichen vor dem Text.
  g.lineStyle(1.2, 0x8fa2c4, 0.5)
  g.strokeCircle(191, 336, 5.5)
  g.lineStyle(0.7, 0x8fa2c4, 0.45)
  g.beginPath()
  g.moveTo(186.5, 336)
  g.lineTo(195.5, 336)
  g.moveTo(191, 331.5)
  g.lineTo(191, 340.5)
  g.strokePath()
  g.fillStyle(0x2f3a52, 1) // Arbeitsplatz in der VAU
  g.fillRect(238, 340, 30, 2.2)
  g.fillRect(241, 342.2, 2, 6)
  g.fillRect(262, 342.2, 2, 6)
  g.fillStyle(0x0a1220, 1)
  g.fillRect(242, 333, 8, 6.4)
  g.fillRect(252, 333, 8, 6.4)
  // Fachdienst ePA: drei Racks (LED-Spalten dynamisch)
  for (const rx of [308, 328, 348]) {
    g.fillStyle(0x141c2e, 1)
    g.fillRect(rx, 328, 14, 21)
    g.lineStyle(0.7, detail, 0.7)
    g.strokeRect(rx, 328, 14, 21)
  }
  // Archiv: Ordner in den Kartenfarben — die ePA als geordneter Speicher
  g.fillStyle(0x39445e, 1)
  g.fillRect(396, 335, 68, 1.4)
  g.fillRect(396, 344.5, 68, 1.4)
  for (let i = 0; i < 14; i++) {
    const farben = [0x7fd07f, 0x4de3ff, 0xffd75e]
    g.fillStyle(farben[i % 3], 0.75)
    g.fillRect(398 + i * 4.6, i % 2 === 0 ? 329 : 338.5, 3.4, i % 2 === 0 ? 6 : 6)
  }
  // Datenleitung Empfang → Keller (Pulse laufen dynamisch darüber)
  const leitungA = pfad([
    [309, 296],
    [309, 322],
    [160, 322],
    [160, 332],
    [128, 332],
  ])
  const leitungB = pfad([
    [128, 340],
    [240, 340],
    [240, 344],
    [338, 344],
  ])
  for (const p of [leitungA, leitungB]) {
    g.lineStyle(0.6, K, 0.18)
    g.beginPath()
    g.moveTo(p.pts[0][0], p.pts[0][1])
    for (let i = 1; i < p.pts.length; i++) g.lineTo(p.pts[i][0], p.pts[i][1])
    g.strokePath()
  }

  // ---- Apotheke rechts: wohin die E-Rezept-Reise führt ----
  g.fillStyle(darken(theme.skyTop, 0.25), 1)
  g.fillRect(524, 262, 92, 58)
  g.fillStyle(darken(theme.skyTop, 0.5), 1)
  g.fillRect(524, 262, 92, 10)
  g.fillStyle(detail, 0.85)
  g.fillRect(522, 260, 96, 2)
  // Schaufenster mit Regalen + großem Pixel-QR
  g.fillStyle(fensterHell, 0.45)
  g.fillRect(532, 278, 44, 34)
  g.lineStyle(0.8, detail, 0.8)
  g.strokeRect(532, 278, 44, 34)
  for (let r = 0; r < 2; r++) {
    g.fillStyle(0x39445e, 0.9)
    g.fillRect(534, 288 + r * 9, 40, 1)
    for (let i = 0; i < 7; i++) {
      const farben = [0xffd75e, 0x7fd07f, 0x9a7ae8, 0x4de3ff]
      g.fillStyle(farben[(i + r) % 4], 0.8)
      g.fillRect(536 + i * 5.4, 284.5 + r * 9, 2.6, 3.2)
    }
  }
  g.fillStyle(0xf2f5fb, 0.95)
  g.fillRect(538, 296, 12, 12)
  g.fillStyle(0x0d1a2c, 1)
  for (let i = 0; i < 5; i++)
    for (let j = 0; j < 5; j++) {
      if ((i * 5 + j * 3 + ((i + j) * 2) % 5) % 4 < 2) g.fillRect(539.5 + i * 1.8, 297.5 + j * 1.8, 1.5, 1.5)
    }
  // Tür + Apotheken-„A" am Ausleger
  g.fillStyle(0x0d1a2c, 1)
  g.fillRect(588, 288, 18, 28)
  g.lineStyle(0.8, detail, 0.8)
  g.strokeRect(588, 288, 18, 28)
  g.fillStyle(accent, 0.6)
  g.fillCircle(603, 302, 0.8)
  g.fillStyle(0x39445e, 1)
  g.fillRect(524, 274, 6, 1.6)
  g.fillStyle(0x0d2440, 0.95)
  g.fillRect(519, 275.6, 11, 11)
  g.lineStyle(1.1, accent, 0.95)
  g.beginPath()
  g.moveTo(521, 284.6)
  g.lineTo(524.5, 277.6)
  g.lineTo(528, 284.6)
  g.moveTo(522.6, 282)
  g.lineTo(526.4, 282)
  g.strokePath()
  // Katze auf dem Apotheken-Dach (Schwanz wedelt dynamisch)
  g.fillStyle(0x1c2536, 1)
  g.fillRect(596, 256.5, 6, 3.5)
  g.fillRect(600.5, 254.5, 3, 3)
  g.fillTriangle(600.5, 255, 601.5, 253, 602, 255)
  g.fillTriangle(602.2, 255, 603.2, 253, 603.6, 255)

  // Geparktes Auto + zweite Laterne rechts
  g.fillStyle(0x2e4a6a, 1)
  g.fillRect(492, 310, 24, 6)
  g.fillRect(496, 306, 14, 5)
  g.fillStyle(0x0d1a2c, 0.9)
  g.fillRect(498, 307, 4.6, 3.4)
  g.fillRect(504, 307, 4.6, 3.4)
  g.fillStyle(0x11182a, 1)
  g.fillCircle(497, 316.5, 2.4)
  g.fillCircle(511, 316.5, 2.4)
  g.fillStyle(0x39445e, 1)
  g.fillRect(628, 282, 1.6, 38)
  g.fillStyle(0xffd9a0, 0.95)
  g.fillRect(626.6, 279, 4.4, 3.4)

  // ---------------------------------------------------------------- Schriften
  // Kleine Wortmarken als Easter Eggs — alle Teil der echten TI-Welt.
  const sign = addText(scene, 140, 123, 'gematik', 9, { color: '#ffffff', spacing: 0.4 }).setOrigin(0.5)
  addText(scene, 140, 133, 'KLINIKUM', 4.6, { color: '#9fc4e8', spacing: 1.3, bold: false }).setOrigin(0.5)
  scene.tweens.add({
    // Neon-Zucken: kurz, selten, deutlich unter 3 Hz
    targets: sign,
    alpha: 0.55,
    duration: 90,
    hold: 60,
    yoyo: true,
    repeat: -1,
    repeatDelay: 2600,
  })
  addText(scene, 121, 259, 'NOTAUFNAHME', 4.6, { color: '#ffb367', spacing: 0.7 }).setOrigin(0.5)
  addText(scene, 406, 280.5, 'Kein Notfall?', 3.6, { color: '#b8c6e0', bold: false }).setOrigin(0.5)
  addText(scene, 406, 285.5, '116 117', 4.6, { color: '#ffd75e' }).setOrigin(0.5)
  // Unter dem QR-Plakat, nicht darüber: auf Höhe 262 läuft die Steuerungs-
  // legende der AttractScene durchs Bild.
  addText(scene, 237, 288, 'E-REZEPT', 3.8, { color: '#4de3ff', bold: false }).setOrigin(0.5)
  addText(scene, 328, 150, 'KIM', 5, { color: '#8fd6c8', spacing: 0.8 }).setOrigin(0.5)
  addText(scene, 100, 147.5, 'OP 1', 4.2, { color: '#9fb0cc', bold: false }).setOrigin(0.5)
  addText(scene, 434, 221, 'TIM', 4.4, { color: '#8fd6c8', spacing: 0.6 }).setOrigin(0.5)
  addText(scene, 245, 330, 'VAU', 6.5, { color: '#4de3ff', spacing: 1 }).setOrigin(0.5)
  // Als Unterschrift unter dem Kasten: rechts daneben hält alle 18 s der
  // Rettungswagen und würde ein dort stehendes Label verdecken.
  addText(scene, 118, 345.5, 'KONNEKTOR', 4, { color: '#9fb0cc', spacing: 0.5, bold: false }).setOrigin(0.5)
  // Direkt unter der Kellerdecke — auf 331 käme die Footer-Zeile zu nah.
  addText(scene, 345, 326.5, 'FACHDIENST ePA', 4, { color: '#9fb0cc', spacing: 0.3, bold: false }).setOrigin(0.5)
  addText(scene, 570, 267, 'APOTHEKE', 5.5, { color: '#ffd75e', spacing: 1.2 }).setOrigin(0.5)
  // Rechts neben dem QR-Plakat in der freien Fensterfläche — mittig läge
  // das Neon hinter Regalreihe und Plakat.
  const neon = addText(scene, 564, 304, 'E-REZEPT', 4.4, { color: '#4de3ff', spacing: 0.5 }).setOrigin(0.5)
  scene.tweens.add({ targets: neon, alpha: 0.35, duration: 750, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' })

  // ---------------------------------------------------------------- Lichter
  addGlow(scene, 140, 126, accent, 24, { alpha: 0.12 })
  addGlow(scene, 204, 252, 0xcfe4ff, 20, { alpha: 0.1 })
  addGlow(scene, 121, 264, WARM_OFFEN, 16, { alpha: 0.09 })
  addGlow(scene, 245, 338, K, 18, { alpha: 0.13 })
  addGlow(scene, 335, 338, K, 12, { alpha: 0.07 })
  addGlow(scene, 570, 270, accent, 16, { alpha: 0.09 })
  addGlow(scene, 564, 304, K, 11, { alpha: 0.1 })
  addGlow(scene, 76, 281, 0xffd9a0, 13, { alpha: 0.15 })
  addGlow(scene, 629, 281, 0xffd9a0, 13, { alpha: 0.15 })
  addGlow(scene, 138, 152, 0xffffff, 13, { alpha: 0.08 })

  // Dampf aus der Dachlüftung: drei Schwaden im Versatz
  for (let i = 0; i < 3; i++) {
    const puff = scene.add
      .image(252, 126, 'fx-mote')
      .setTint(0xcfd8e8)
      .setAlpha(0)
      .setScale(0.5)
      .setDepth(0)
    scene.tweens.add({
      targets: puff,
      y: 106 - i * 4,
      x: 252 + 6 + i * 3,
      alpha: { from: 0.22, to: 0 },
      scale: 1.6,
      duration: 2600,
      repeat: -1,
      delay: i * 900,
      ease: 'Sine.easeOut',
    })
  }

  // ---------------------------------------------------------------- Aufzugsplan
  // Kabinen-Oberkante je Halt; hoch und wieder runter, mit Wartezeit.
  const halte = [288, 224, 186, 148, 186, 224]
  const WARTE = 2.2
  const TEMPO = 34
  const fahrplan: { t0: number; t1: number; von: number; nach: number }[] = []
  let zeit = 0
  for (let i = 0; i < halte.length; i++) {
    const von = halte[i]
    const nach = halte[(i + 1) % halte.length]
    zeit += WARTE
    const dauer = Math.abs(nach - von) / TEMPO
    fahrplan.push({ t0: zeit, t1: zeit + dauer, von, nach })
    zeit += dauer
  }
  const fahrplanDauer = zeit
  const aufzugY = (t: number): number => {
    const u = t % fahrplanDauer
    let y = halte[0]
    for (const f of fahrplan) {
      if (u >= f.t1) y = f.nach
      else if (u >= f.t0) {
        const k = (u - f.t0) / (f.t1 - f.t0)
        return f.von + (f.nach - f.von) * (0.5 - Math.cos(k * Math.PI) / 2)
      }
    }
    return y
  }

  // ---------------------------------------------------------------- Leben
  const leben = scene.add.graphics().setDepth(0)

  // Flur-Läufer (1. OG unten): Ärztin, Pfleger, Patient, Rollstuhl-Duo
  const LAEUFER: { xa: number; xb: number; tempo: number; off: number; p: Person; schrittHz: number }[] = [
    { xa: 100, xb: 430, tempo: 26, off: 0, p: P_AERZTIN, schrittHz: 2.6 },
    { xa: 130, xb: 440, tempo: 21, off: 7, p: P_PFLEGE, schrittHz: 2.3 },
    { xa: 140, xb: 380, tempo: 9, off: 3, p: P_PATIENT, schrittHz: 1.3 },
  ]

  const malLeben = (t: number): void => {
    const l = leben
    l.clear()

    // ---- Aufzug: Kabine mit Licht, Seil, winziger Fahrgast ----
    const ay = aufzugY(t)
    l.fillStyle(0x39445e, 1)
    l.fillRect(SCHACHT.links + 1, 142, 1, ay - 142)
    l.fillStyle(0xffe9b8, 0.22)
    l.fillRect(SCHACHT.links + 1, ay, SCHACHT.rechts - SCHACHT.links - 2, 28)
    l.fillStyle(0x2f3a52, 1)
    l.fillRect(SCHACHT.links + 1, ay, SCHACHT.rechts - SCHACHT.links - 2, 1.6)
    l.fillRect(SCHACHT.links + 1, ay + 26.4, SCHACHT.rechts - SCHACHT.links - 2, 1.6)
    malFigur(l, SCHACHT.links + 12, ay + 26.4, P_BESUCH, 0, -1)

    // ---- Flur-Läufer + Rollstuhl-Gespann ----
    for (const w of LAEUFER) {
      const pos = pendel(t, w.xa, w.xb, w.tempo, w.off)
      malFigur(l, pos.x, FUSS.f1, w.p, t * w.schrittHz * 0.5, pos.dir)
    }
    {
      const pos = pendel(t, 150, 400, 13, 11)
      const vor = pos.dir
      // Rollstuhl vor dem Schieber
      const rx = pos.x + vor * 6
      l.lineStyle(0.9, 0x8fa2c4, 0.95)
      l.strokeCircle(rx, 248.5, 3.4)
      l.strokeCircle(rx + vor * 4.6, 250.4, 1.5)
      l.fillStyle(0x2f3a52, 1)
      l.fillRect(rx - 3.4, 241.5, 6.8, 1.8)
      l.fillRect(rx - vor * 3.4 - 0.8, 236, 1.6, 7)
      malSitzend(l, rx, 243, P_PATIENT)
      malFigur(l, pos.x - vor * 3, FUSS.f1, P_PFLEGE, t * 1.9 * 0.5, vor)
    }
    // TIM-Ecke: Arzt tippt am Telefon, Sprechblasen wechseln sich ab
    {
      const bob = Math.sin(t * 2.1) * 0.4
      malFigur(l, 430, FUSS.f1, P_ARZT, 0, -1)
      l.fillStyle(K, 0.9)
      l.fillRect(426.4, 243.6 + bob * 0.2, 1.6, 2.6)
      const wer = Math.sin(t * 1.85)
      l.fillStyle(0xe9eef8, wer > 0 ? 0.85 : 0.2)
      l.fillRoundedRect(418, 228, 8, 5, 1.5)
      l.fillStyle(0x8fd6c8, wer > 0 ? 0.2 : 0.85)
      l.fillRoundedRect(428, 231.5, 8, 5, 1.5)
    }
    // Wanduhr im Flur: echte Minuten, die Stunde steht. Links über der
    // Rolltrage — die Bildmitte gehört dem „Drück LEERTASTE!"-Text.
    l.lineStyle(0.7, 0xd8e0f0, 0.9)
    l.strokeCircle(107, 228, 3)
    l.beginPath()
    l.moveTo(107, 228)
    l.lineTo(107 + Math.sin(t * 0.105) * 2.4, 228 - Math.cos(t * 0.105) * 2.4)
    l.moveTo(107, 228)
    l.lineTo(108.6, 227)
    l.strokePath()

    // ---- 1. OG: Betten atmen, Monitore laufen, Visite, TV flimmert ----
    malBett(l, 104, FUSS.f2, 0x5c7ba8, HAUT[1], t, 0)
    malMonitor(l, 132, FUSS.f2, t, 0.1)
    malBett(l, 204, FUSS.f2, 0x8a5f9e, HAUT[0], t, 2.1)
    malBett(l, 300, FUSS.f2, 0x4d8a70, HAUT[2], t, 4.2)
    malMonitor(l, 328, FUSS.f2, t, 0.55)
    {
      // Visite in Zimmer 1: Ärztin mit Klemmbrett, leichtes Nicken
      const nick = Math.sin(t * 1.6) * 0.5
      malFigur(l, 150, FUSS.f2, P_ARZT, 0, -1)
      l.fillStyle(0xf2f5fb, 0.95)
      l.fillRect(145.2, 205.6 + nick * 0.3, 3, 4)
    }
    // Infusion: Tropfen fällt, dann kleiner Blip
    {
      const u = (t % 1.6) / 1.6
      if (u < 0.75) {
        l.fillStyle(0xffd75e, 0.9 - u)
        l.fillRect(95.6, 198 + u * 12, 1, 1.6)
      }
    }
    // TV-Flimmern in Zimmer 2
    l.fillStyle(0xcfe4ff, 0.1 + Math.abs(Math.sin(t * 2.7) * Math.sin(t * 1.3)) * 0.12)
    l.fillRect(263, 187, 12, 6)
    // Stationszimmer: Schwester schreibt, Kaffeemaschine blinkt
    malSitzend(l, 404, 202, P_PFLEGE)
    l.fillStyle(0x7fd07f, Math.sin(t * 2.4) > 0 ? 0.9 : 0.25)
    l.fillRect(429, 198, 1.4, 1.4)

    // ---- 2. OG: OP läuft, Labor blubbert, KIM pingt, Röntgen flackert ----
    {
      const b1 = Math.sin(t * 1.5) * 0.5
      const b2 = Math.sin(t * 1.5 + 1.7) * 0.5
      malFigur(l, 124, FUSS.f3 + b1 * 0, P_OP, 0, 1)
      malFigur(l, 156, FUSS.f3 + b2 * 0, P_OP, 0, -1)
      // gebeugte Köpfe: kleine Zusatzbewegung über den Tisch
      l.fillStyle(HAUT[0], 1)
      l.fillRect(127 + b1, 164.5, 2, 1.4)
      l.fillRect(151 - b2, 164.5, 2, 1.4)
      // Patient auf dem Tisch
      l.fillStyle(0x69b894, 1)
      l.fillRect(124, 165.4, 22, 2.6)
      l.fillStyle(HAUT[2], 1)
      l.fillRect(146, 164.8, 3, 2.6)
      malEkg(l, 168, 158, 8, 2, t, 0.8)
    }
    {
      const pos = pendel(t, 210, 262, 8, 5)
      malFigur(l, pos.x, FUSS.f3, P_TECHNIK, t * 1.2 * 0.5, pos.dir)
      // Blubbern im Kolben
      for (let i = 0; i < 3; i++) {
        const u = ((t * 0.7 + i * 0.33) % 1)
        l.fillStyle(0x7fd07f, 0.7 - u * 0.6)
        l.fillCircle(229.5, 162 - u * 7, 0.8)
      }
    }
    {
      // KIM: Umschlag pingt alle paar Sekunden über dem Monitor
      malSitzend(l, 312, 166, P_PFLEGE)
      const u = (t % 4.5) / 4.5
      const pop = u < 0.18 ? Math.sin((u / 0.18) * Math.PI) : 0
      const ex = 301.5
      const ey = 152 - pop * 2.5
      l.fillStyle(0x8fd6c8, 0.55 + pop * 0.45)
      l.fillRect(ex - 3, ey - 2, 6, 4)
      l.lineStyle(0.5, 0x0a1220, 0.9)
      l.beginPath()
      l.moveTo(ex - 3, ey - 2)
      l.lineTo(ex, ey + 0.5)
      l.lineTo(ex + 3, ey - 2)
      l.strokePath()
    }
    l.fillStyle(0xcfe4ff, 0.03 + Math.abs(Math.sin(t * 3.1)) * 0.04)
    l.fillRect(380, 146, 36, 24)
    {
      const pos = pendel(t, 424, 432, 3, 1)
      malFigur(l, pos.x, FUSS.f3, P_TECHNIK, 0, pos.dir)
    }

    // ---- EG: Empfang, Wartende, Putzroboter (REZIs Cousin), Türen ----
    {
      // Empfangskraft hinter dem Tresen: nur Oberkörper, tippt
      const bob = Math.sin(t * 2.3) * 0.4
      l.fillStyle(0x5fc4b8, 1)
      l.fillRect(291.4, 291.5 + bob * 0.3, 5.2, 6.5)
      l.fillStyle(HAUT[2], 1)
      l.fillRect(292.2, 287.6 + bob * 0.4, 3.6, 3.8)
      l.fillStyle(0x14101a, 1)
      l.fillRect(292.2, 287.6 + bob * 0.4, 3.6, 1.3)
      // Patientin davor hält die eGK hoch — sie glänzt
      malFigur(l, 250, FUSS.eg, P_BESUCH, 0, 1)
      l.fillStyle(0x7fd07f, 1)
      l.fillRect(253.4, 302.5, 3.2, 2.2)
      l.fillStyle(0xffffff, 0.4 + Math.sin(t * 3.4) * 0.35)
      l.fillRect(253.9, 303, 1, 0.8)
    }
    // Wartende: Erwachsener liest, Kind lässt die Beine baumeln
    malSitzend(l, 346, 306, P_BESUCH)
    malSitzend(l, 362, 306, { haut: HAUT[0], oben: 0xd06a6a, unten: 0x3d5a74, haar: 0x8a5a33 }, Math.sin(t * 3.2) * 1.4)
    // Putzroboter patrouilliert durch die Halle — REZI lässt grüßen
    {
      const pos = pendel(t, 168, 420, 9, 4)
      l.fillStyle(0x2f3a52, 1)
      l.fillRoundedRect(pos.x - 4, FUSS.eg - 4.6, 8, 4, 1.6)
      l.fillStyle(K, Math.sin(t * 2.8) > 0 ? 0.95 : 0.4)
      l.fillRect(pos.x - 1, FUSS.eg - 6, 2, 1.6)
      l.fillStyle(0xffffff, 0.14)
      l.fillRect(pos.x - pos.dir * 7, FUSS.eg - 1.4, 4, 0.7)
    }
    // Besucher kommt von links, die Schiebetür öffnet sich
    let tuerAuf = 0
    {
      const P = 14
      const u = (t % P)
      if (u < 4.4) {
        const x = 30 + (204 - 30) * (u / 4.4)
        malFigur(l, x, FUSS.strasse, P_BESUCH, t * 2.2 * 0.5, 1)
        tuerAuf = Math.max(tuerAuf, Phaser.Math.Clamp((32 - Math.abs(x - 204)) / 32, 0, 1))
      } else if (u < 5) {
        const k = (u - 4.4) / 0.6
        l.setAlpha(1 - k)
        malFigur(l, 204, FUSS.strasse - k * 2, P_BESUCH, 0, 1)
        l.setAlpha(1)
        tuerAuf = 1
      }
    }
    // Entlassener Patient läuft mit dem E-Rezept am Handy zur Apotheke
    {
      const P = 30
      const u = ((t + 17) % P)
      if (u < 0.8) tuerAuf = 1
      if (u < 12.6) {
        const k = Phaser.Math.Clamp(u / 12, 0, 1)
        const x = 204 + (596 - 204) * k
        const a = u < 0.8 ? u / 0.8 : u > 12 ? 1 - (u - 12) / 0.6 : 1
        l.setAlpha(Phaser.Math.Clamp(a, 0, 1))
        malFigur(l, x, FUSS.strasse, P_PATIENT, t * 2 * 0.5, 1)
        l.fillStyle(K, 0.95) // Handy leuchtet türkis: das Rezept ist schon da
        l.fillRect(x + 3, FUSS.strasse - 7.6, 1.6, 2.6)
        l.setAlpha(1)
        if (u < 1.2) tuerAuf = Math.max(tuerAuf, 1 - (u - 0.8) / 0.4)
      }
    }
    // Schiebetürflügel
    {
      const o = tuerAuf * 7
      l.fillStyle(0x9fc4e8, 0.3)
      l.fillRect(196 - o, 262, 8, 54)
      l.fillRect(204 + o, 262, 8, 54)
      l.fillStyle(0xd8e0f0, 0.8)
      l.fillRect(196 - o + 7, 262, 1, 54)
      l.fillRect(204 + o, 262, 1, 54)
    }
    // Zwei Passanten auf dem Gehweg
    {
      const a = pendel(t, 12, 620, 15, 40)
      malFigur(l, a.x, FUSS.strasse, { haut: HAUT[1], oben: 0x6a8f4d, unten: 0x2e3a50, haar: 0x2b2530 }, t * 2.1 * 0.5, a.dir)
      const b = pendel(t, 30, 600, 19, 140)
      malFigur(l, b.x, FUSS.strasse, { haut: HAUT[2], oben: 0xd0a04a, unten: 0x33405c, haar: 0x14101a }, t * 2.4 * 0.5, b.dir)
    }

    // ---- Keller: Konnektor-LEDs, VAU-Arbeit, Rack-Lichter, Pulse, Maus ----
    {
      // Konnektor: grüne LEDs — und alle ~12 s hängt er kurz (rote LED),
      // dann läuft er wieder. Wer den Alltag kennt, lacht hier.
      const haengt = (t % 12) > 8.4 && (t % 12) < 9.9
      for (let i = 0; i < 4; i++) {
        const an = Math.sin(t * 2.2 + i * 1.9) > -0.2
        l.fillStyle(haengt ? 0x333c4e : 0x7fd07f, an && !haengt ? 0.95 : 0.25)
        l.fillRect(111 + i * 3.6, 331, 1.8, 1.8)
      }
      l.fillStyle(0xff5050, haengt ? 0.95 : 0)
      l.fillRect(111, 335, 1.8, 1.8)
    }
    {
      // VAU: Admin tippt, Bildschirme wabern türkis
      malSitzend(l, 256, 346, P_TECHNIK)
      l.fillStyle(K, 0.25 + Math.abs(Math.sin(t * 1.7)) * 0.25)
      l.fillRect(243, 334, 6, 4.4)
      l.fillStyle(K, 0.25 + Math.abs(Math.sin(t * 1.7 + 1.2)) * 0.25)
      l.fillRect(253, 334, 6, 4.4)
    }
    for (const [ri, rx] of [308, 328, 348].entries()) {
      for (let reihe = 0; reihe < 6; reihe++)
        for (let sp = 0; sp < 3; sp++) {
          const an = (ri * 7 + reihe * 13 + sp * 5 + Math.floor(t * 2.5) * 29) % 11 < 4
          l.fillStyle(an ? K : 0x333c4e, an ? 0.9 : 0.3)
          l.fillRect(rx + 2.5 + sp * 3.6, 330.5 + reihe * 3, 1.6, 1.2)
        }
    }
    for (let k = 0; k < 3; k++) {
      const [pxA, pyA] = pfadPunkt(leitungA, (t / 6 + k / 3) % 1)
      l.fillStyle(K, 0.25)
      l.fillCircle(pxA, pyA, 1.8)
      l.fillStyle(0xffffff, 0.9)
      l.fillCircle(pxA, pyA, 0.7)
      const [pxB, pyB] = pfadPunkt(leitungB, (t / 5 + k / 3 + 0.15) % 1)
      l.fillStyle(K, 0.25)
      l.fillCircle(pxB, pyB, 1.8)
      l.fillStyle(0xffffff, 0.9)
      l.fillCircle(pxB, pyB, 0.7)
    }
    {
      // Archiv-Maus: huscht alle ~23 s einmal durchs Bild
      const u = (t % 23)
      if (u < 1.1) {
        const x = 460 - (u / 1.1) * 62
        l.fillStyle(0x8a8fa0, 0.95)
        l.fillRect(x, 348.6, 3, 1.6)
        l.fillCircle(x - 0.4, 348.8, 0.8)
        l.lineStyle(0.5, 0x8a8fa0, 0.8)
        l.beginPath()
        l.moveTo(x + 3, 349.4)
        l.lineTo(x + 5.5, 348.6 + Math.sin(t * 30) * 0.6)
        l.strokePath()
      }
    }

    // ---- Helipad-Randlichter + Antennen-Beacon (2 Hz, unter der 3-Hz-Grenze) ----
    for (let i = 0; i < 4; i++) {
      const an = Math.sin(t * Math.PI * 2 * 1 + i * 1.57) > 0.2
      l.fillStyle(0x7fd07f, an ? 0.9 : 0.15)
      l.fillRect(381 + i * 25.4, 127, 1.6, 1.6)
    }
    l.fillStyle(0xff5050, Math.sin(t * Math.PI * 2 * 1) > 0.5 ? 0.95 : 0.1)
    l.fillCircle(467, 94.5, 1.1)
    // Tauben auf der Dachkante: hüpfen ab und zu
    for (let i = 0; i < 3; i++) {
      const ph = (t * 0.42 + i * 2.3) % 7
      const hop = ph < 0.3 ? Math.sin((ph / 0.3) * Math.PI) * 2 : 0
      const px = 300 + i * 17 + (ph < 0.3 ? 1 : 0)
      l.fillStyle(0x8a92a8, 1)
      l.fillRect(px, 133.4 - hop, 3, 2)
      l.fillCircle(px + 3.2, 133.4 - hop, 1)
    }
    // Katzenschwanz auf dem Apotheken-Dach
    l.lineStyle(0.9, 0x1c2536, 1)
    l.beginPath()
    l.moveTo(596.4, 258)
    l.lineTo(593.4, 256.6 + Math.sin(t * 1.4) * 1.4)
    l.strokePath()
    // Hund am Park schaut zu, Schwanz wedelt
    l.fillStyle(0x6b4326, 1)
    l.fillRect(66, 315.4, 5, 2.6)
    l.fillRect(70.4, 313.6, 2.6, 2.6)
    l.fillRect(66.6, 318, 1, 2)
    l.fillRect(69.6, 318, 1, 2)
    l.lineStyle(0.8, 0x6b4326, 1)
    l.beginPath()
    l.moveTo(66, 316)
    l.lineTo(63.8, 314.4 + Math.sin(t * 6) * 1)
    l.strokePath()

    // ---- Rettungswagen: kommt, hält an der Notaufnahme, fährt weiter ----
    {
      // Haltepunkt x=185 (vor Zebrastreifen/Eingang): Weiter rechts stünde
      // der Wagen genau vor dem VAU-Schild im Keller-Schnitt.
      const P = 18
      const u = ((t + 6) % P)
      let x = -999
      let fahrend = false
      if (u < 3.2) {
        x = 700 - (700 - 185) * (u / 3.2)
        fahrend = true
      } else if (u < 8) {
        x = 185
      } else if (u < 11) {
        x = 185 - (185 + 90) * ((u - 8) / 3)
        fahrend = true
      }
      if (x > -900) {
        const y = 326
        l.fillStyle(0xdfe6f0, 1)
        l.fillRect(x - 20, y, 40, 12)
        l.fillStyle(0xdfe6f0, 1)
        l.fillRect(x - 27, y + 3, 8, 9)
        l.fillStyle(0x0d1a2c, 0.9)
        l.fillRect(x - 25.6, y + 4, 5, 3.6)
        l.fillStyle(WARM_OFFEN, 0.9)
        l.fillRect(x - 20, y + 7.6, 40, 2.2)
        malEkg(l, x - 12, y + 4, 22, 1.6, 0.35, 0.3)
        l.fillStyle(0x11182a, 1)
        l.fillCircle(x - 20, y + 13, 2.6)
        l.fillCircle(x + 12, y + 13, 2.6)
        l.fillStyle(0x39445e, 1)
        l.fillCircle(x - 20, y + 13, 1)
        l.fillCircle(x + 12, y + 13, 1)
        // Blaulicht: zwei Leuchten im Wechsel (2,5 Hz)
        const blau = Math.sin(t * Math.PI * 2 * 1.25) > 0
        l.fillStyle(0x66aaff, blau ? 0.95 : 0.2)
        l.fillRect(x - 24, y - 2, 3, 2)
        l.fillStyle(0x66aaff, blau ? 0.2 : 0.95)
        l.fillRect(x + 14, y - 2, 3, 2)
        l.fillStyle(0x66aaff, 0.12)
        l.fillCircle(x - 22.5, y - 1, blau ? 5 : 2)
        l.fillCircle(x + 15.5, y - 1, blau ? 2 : 5)
        if (fahrend) {
          l.fillStyle(0xfff2c8, 0.1)
          l.fillTriangle(x - 27, y + 6, x - 44, y + 3, x - 44, y + 11)
        }
        // Beim Halt: Sanitäter läuft zur Notaufnahme
        if (u >= 4 && u < 7.2) {
          const k = (u - 4) / 3.2
          malFigur(l, 176 - k * 56, FUSS.strasse, P_PFLEGE, t * 2.6 * 0.5, -1)
        }
      }
    }

    // ---- Hubschrauber: Anflug, Landung, Trage zur Dachtür, Abflug ----
    {
      const P = 26
      const u = t % P
      let hx = -999
      let hy = 0
      let rotor = 1 // 1 = volle Drehzahl, 0 = steht
      if (u < 5) {
        const k = Math.sin(((u / 5) * Math.PI) / 2)
        hx = -60 + (419 + 60) * k
        hy = 66 + (112 - 66) * k
      } else if (u < 7) {
        hx = 419
        hy = 112 + (125 - 112) * ((u - 5) / 2)
      } else if (u < 15) {
        hx = 419
        hy = 125
        rotor = Math.max(0.12, 1 - (u - 7) / 3)
      } else if (u < 18) {
        hx = 419
        hy = 125
        rotor = Math.min(1, 0.12 + (u - 15) / 2.4)
      } else if (u < 23) {
        const k = (u - 18) / 5
        hx = 419 + (720 - 419) * k * k
        hy = 125 - 82 * k
      }
      if (hx > -900) {
        l.fillStyle(0xd8e0f0, 1)
        l.fillRoundedRect(hx - 9, hy - 7, 18, 7, 3)
        l.fillStyle(0x0d1a2c, 0.9)
        l.fillRect(hx + 3.5, hy - 6, 4.5, 3)
        l.fillStyle(0xd8e0f0, 1)
        l.fillRect(hx - 22, hy - 5, 14, 2)
        l.fillRect(hx - 24, hy - 9, 2.6, 6)
        malEkg(l, hx - 7, hy - 3.4, 12, 1.2, 0.35, 0.6)
        l.fillStyle(0x39445e, 1)
        l.fillRect(hx - 8, hy + 0.6, 1.2, 2)
        l.fillRect(hx + 6, hy + 0.6, 1.2, 2)
        l.fillRect(hx - 10, hy + 2.6, 21, 1)
        // Rotor: schnell = Wischscheibe, langsam = einzelne Blätter
        if (rotor > 0.5) {
          l.fillStyle(0xcfd8e8, 0.3)
          l.fillEllipse(hx, hy - 8.6, 34, 1.6)
        } else {
          const a = t * (2 + rotor * 26)
          l.lineStyle(0.8, 0xcfd8e8, 0.85)
          l.beginPath()
          l.moveTo(hx - Math.cos(a) * 16, hy - 8.6)
          l.lineTo(hx + Math.cos(a) * 16, hy - 8.6)
          l.strokePath()
        }
        l.fillStyle(0xff5050, Math.sin(t * Math.PI * 2 * 1) > 0.4 ? 0.9 : 0.1)
        l.fillCircle(hx - 23, hy - 10, 0.9)
        // Übergabe: zwei Sanitäter tragen die Trage zur Dachtür
        if (u >= 8 && u < 13.5) {
          const k = (u - 8) / 5.5
          const sx = 428 + (SCHACHT.links + 4 - 428) * k
          malFigur(l, sx - 5, 137.5, P_PFLEGE, t * 2 * 0.5, 1)
          malFigur(l, sx + 7, 137.5, P_PFLEGE, t * 2 * 0.5, 1)
          l.fillStyle(0xcfd6e6, 1)
          l.fillRect(sx - 4, 130.4, 10, 1.4)
          l.fillStyle(0xe9eef8, 0.95)
          l.fillRect(sx - 2, 128.8, 6, 1.6)
        }
      }
    }
  }

  const onUpdate = (): void => {
    malLeben(scene.time.now / 1000)
  }
  scene.events.on(Phaser.Scenes.Events.UPDATE, onUpdate)
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, onUpdate)
  })
  malLeben(scene.time.now / 1000)
}
