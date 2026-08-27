import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { darken } from './atmos'
import { addGlow } from './effects'
import { addText } from './text'
import { KUEHL_GESCHUETZT, WARM_OFFEN } from './material'

/**
 * WISSEN — animierte Lehrsequenzen zur „ePA für alle" zwischen den Stationen.
 *
 * Dieselbe Machart wie die Zeitreise (zeitreise.ts): statische Bühne einmal,
 * „Leben" jeden Frame als reine Funktion der Zeit, Schrittzeilen im Takt,
 * Mindest-Anzeigedauer mit Zeitbalken, Weiterblättern mit jedem Knopf.
 * Sie ERSETZEN vor den vier ePA-Stationen den City-Lauf: Erst verstehen,
 * dann spielen.
 *
 * Fachliche Quellen (Stand 2025/2026, siehe docs/EPA-WISSENSPFAD.md):
 *  - ePA für alle: Opt-out seit 15.01.2025; Widerspruch jederzeit, dann
 *    löscht die Kasse die Akte vollständig (gematik, DigiG).
 *  - Die Akte liegt im Aktensystem (Rechenzentrum), NICHT auf der eGK —
 *    die Karte ist Schlüssel, kein Speicher (KAPSEL 1.4).
 *  - Befugnis durch Kartenstecken: Praxis/Klinik standardmäßig 90 Tage,
 *    Apotheke 3 Tage — in der ePA-App änderbar oder entziehbar (gematik/KBV).
 *  - Medikationsliste: E-Rezept-Daten fließen automatisch ein — die EINZIGE
 *    Automatik der ePA; sonst stellt nur ein, wer behandelt (gematik).
 *  - Zugriffsprotokoll: jeder Zugriff wird erfasst, drei Jahre einsehbar;
 *    Dokumente lassen sich verbergen/löschen, ohne dass Praxen das Fehlen
 *    erkennen (gematik/KBV).
 */

export type WissenId = 'epa-konto' | 'epa-medikation' | 'epa-befugnis' | 'epa-souveraen'

/** Welche Lehrsequenz VOR welcher Station läuft (statt des City-Laufs). */
export const WISSEN_VOR_LEVEL: Record<string, WissenId> = {
  '13-e-rezept': 'epa-konto',
  '14-die-vau': 'epa-medikation',
  '19-berechtigungen': 'epa-befugnis',
  '20-souveraenitaet': 'epa-souveraen',
}

/** Mindest-Anzeigedauer in Sekunden (wie ZEITREISE_SPERRE). */
export const WISSEN_SPERRE: Record<WissenId, number> = {
  'epa-konto': 13,
  'epa-medikation': 13,
  'epa-befugnis': 15,
  'epa-souveraen': 15,
}

interface Vignette {
  titel: string
  untertitel: string
  /** Schrittzeilen mit Zeitfenster [von, bis) in Sekunden des Zyklus. */
  zeilen: { von: number; bis: number; text: string }[]
  zyklus: number
  /** Statische Bühne zeichnen. */
  statik(g: Phaser.GameObjects.Graphics, scene: Phaser.Scene, theme: Theme, W: number): void
  /** Bewegtes pro Frame (u = Zyklussekunde, t = absolute Sekunde). */
  leben(l: Phaser.GameObjects.Graphics, u: number, t: number): void
}

const K = KUEHL_GESCHUETZT

// ------------------------------------------------------------ Bau-Vokabular

/** ePA-Akte: Karte mit Kreuz und Dokumentzeilen — das wiederkehrende Symbol. */
function malAkte(g: Phaser.GameObjects.Graphics, x: number, y: number, s = 1, alpha = 1): void {
  g.fillStyle(0x0d1a2c, alpha)
  g.fillRoundedRect(x - 11 * s, y - 14 * s, 22 * s, 28 * s, 3 * s)
  g.lineStyle(1, K, 0.85 * alpha)
  g.strokeRoundedRect(x - 11 * s, y - 14 * s, 22 * s, 28 * s, 3 * s)
  g.fillStyle(0x2fa88c, 0.95 * alpha)
  g.fillRect(x - 1.4 * s, y - 10 * s, 2.8 * s, 7 * s)
  g.fillRect(x - 3.5 * s, y - 7.9 * s, 7 * s, 2.8 * s)
  g.fillStyle(0x9aa6bc, 0.8 * alpha)
  for (let i = 0; i < 3; i++) g.fillRect(x - 7 * s, y + 2 * s + i * 3.4 * s, 14 * s, 1.1 * s)
}

/** eGK: die grüne Gesundheitskarte mit Chip — Schlüssel, kein Speicher. */
function malKarte(g: Phaser.GameObjects.Graphics, x: number, y: number, s = 1, alpha = 1): void {
  g.fillStyle(0x2c7a52, alpha)
  g.fillRoundedRect(x - 8 * s, y - 5 * s, 16 * s, 10 * s, 1.6 * s)
  g.fillStyle(0xffd75e, 0.95 * alpha)
  g.fillRoundedRect(x - 5.5 * s, y - 2.4 * s, 3.6 * s, 4.4 * s, 0.8 * s)
  g.fillStyle(0xffffff, 0.2 * alpha)
  g.fillRect(x - 8 * s, y - 5 * s, 16 * s, 1 * s)
}

/** Smartphone mit ePA-App — die Schaltzentrale der Versicherten. */
function malHandy(g: Phaser.GameObjects.Graphics, x: number, y: number, h = 34): void {
  const w = h * 0.52
  g.fillStyle(0x0a1220, 1)
  g.fillRoundedRect(x - w / 2, y - h / 2, w, h, 3)
  g.lineStyle(1, 0x9fb3c8, 0.8)
  g.strokeRoundedRect(x - w / 2, y - h / 2, w, h, 3)
  g.fillStyle(0x9fb3c8, 0.7)
  g.fillRect(x - 2.4, y - h / 2 + 1.6, 4.8, 0.9)
}

/** Kleines beschriftetes Gebäude (Kasse, Praxis, Apotheke …). */
function malHaus(
  g: Phaser.GameObjects.Graphics,
  scene: Phaser.Scene,
  theme: Theme,
  x: number,
  y: number,
  w: number,
  h: number,
  label: string,
  labelFarbe = '#dfe6f0',
): void {
  g.fillStyle(darken(theme.skyTop, 0.4), 1)
  g.fillRect(x - w / 2, y - h, w, h)
  g.fillStyle(Phaser.Display.Color.HexStringToColor(theme.detail).color, 0.7)
  g.fillRect(x - w / 2 - 2, y - h - 2, w + 4, 2)
  for (let fy = y - h + 8; fy < y - 12; fy += 14) {
    for (let fx = x - w / 2 + 7; fx < x + w / 2 - 8; fx += 13) {
      const an = (Math.round(fx * 7 + fy * 13) % 4) < 2
      g.fillStyle(an ? 0xffd9a0 : darken(theme.skyBottom, 0.3), an ? 0.8 : 0.5)
      g.fillRect(fx, fy, 6, 8)
    }
  }
  g.fillStyle(0x0d1a2c, 1)
  g.fillRect(x - 7, y - 16, 14, 16)
  addText(scene, x, y - h - 9, label, 5, { color: labelFarbe, spacing: 0.8 }).setOrigin(0.5)
}

/** Zeitschaltuhr-Badge („90 TAGE" / „3 TAGE") mit ablaufendem Ring. */
function malUhr(
  g: Phaser.GameObjects.Graphics,
  x: number,
  y: number,
  anteil: number,
  farbe: number,
): void {
  g.fillStyle(0x0e1a2c, 0.95)
  g.fillCircle(x, y, 8)
  g.lineStyle(1, 0x9fb3c8, 0.6)
  g.strokeCircle(x, y, 8)
  g.lineStyle(2, farbe, 0.95)
  g.beginPath()
  g.arc(x, y, 5.6, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.02, anteil), false)
  g.strokePath()
}

const blende = (u: number, von: number, bis: number): number =>
  Phaser.Math.Clamp(Math.min((u - von) / 0.5, (bis - u) / 0.5, 1), 0, 1)

// ------------------------------------------------------------- Die Vignetten

const VIGNETTEN: Record<WissenId, Vignette> = {
  // ---------------------------------------------------- 1 · Dein Konto
  'epa-konto': {
    titel: 'DEINE AKTE',
    untertitel: 'Die ePA für alle — seit 2025 hat sie jeder. Außer, du willst nicht.',
    zyklus: 20,
    zeilen: [
      { von: 0.4, bis: 5, text: 'Die Krankenkasse legt für jeden automatisch eine ePA an — die „ePA für alle“.' },
      { von: 5, bis: 10, text: 'Wer nicht will, widerspricht einfach — dann gibt es keine Akte. Deine Wahl.' },
      { von: 10, bis: 15, text: 'Die Akte liegt geschützt im Rechenzentrum — NICHT auf deiner Karte.' },
      { von: 15, bis: 19.5, text: 'Die eGK ist nur der Schlüssel dazu. Gleich holst du dein E-Rezept — es landet genau hier.' },
    ],
    statik(g, scene, theme, W) {
      malHaus(g, scene, theme, 100, 300, 84, 96, 'KRANKENKASSE')
      for (const hx of [238, 306, 374]) {
        g.fillStyle(darken(theme.skyTop, 0.35), 1)
        g.fillRect(hx - 20, 262, 40, 38)
        g.fillTriangle(hx - 24, 262, hx + 24, 262, hx, 244)
        g.fillStyle(0xffd9a0, 0.75)
        g.fillRect(hx - 6, 278, 9, 10)
      }
      // Aktensystem: drei Konten-Slots im Rechenzentrum
      g.fillStyle(0x0a1220, 1)
      g.fillRect(452, 224, 132, 76)
      g.lineStyle(1, Phaser.Display.Color.HexStringToColor(theme.detail).color, 0.8)
      g.strokeRect(452, 224, 132, 76)
      addText(scene, 518, 232, 'AKTENSYSTEM', 5.5, { color: '#4de3ff', spacing: 1 }).setOrigin(0.5)
      addText(scene, 518, 308, 'im gesicherten Rechenzentrum', 5, { color: '#9fb0cc', bold: false }).setOrigin(0.5)
      addGlow(scene, 518, 262, K, 26, { alpha: 0.1 })
      g.fillStyle(darken(theme.ground, 0.35), 1)
      g.fillRect(0, 300, W, 4)
    },
    leben(l, u, t) {
      // Briefe fliegen von der Kasse zu den Häusern
      for (const [i, hx] of [238, 306, 374].entries()) {
        const k = Phaser.Math.Clamp((u - 0.8 - i * 0.7) / 2, 0, 1)
        if (k > 0 && k < 1) {
          const bx = 130 + (hx - 130) * k
          const by = 250 - Math.sin(k * Math.PI) * 34
          l.fillStyle(0xeef2f8, 0.95)
          l.fillRect(bx - 3.6, by - 2.4, 7.2, 4.8)
          l.lineStyle(0.5, 0x9aa6bc, 0.9)
          l.strokeRect(bx - 3.6, by - 2.4, 7.2, 4.8)
        }
      }
      // Haus 2 widerspricht: Sprechblase + sein Slot bleibt leer
      const wider = blende(u, 5.5, 10)
      if (wider > 0) {
        l.fillStyle(0xeef2f8, 0.95 * wider)
        l.fillRoundedRect(292, 216, 30, 13, 3)
        l.fillTriangle(303, 229, 309, 229, 305, 234)
        l.fillStyle(0xb3403e, 0.95 * wider)
        l.fillRect(297, 220, 20, 1.6)
        l.fillRect(297, 224, 14, 1.6)
      }
      // Konten-Slots: 1 und 3 füllen sich, Slot 2 bleibt bewusst leer
      for (const [i, sx] of [478, 518, 558].entries()) {
        const da = i !== 1
        const auf = da ? Phaser.Math.Clamp((u - 2.6 - i * 0.5) / 1.2, 0, 1) : 0
        if (auf > 0) malAkte(l, sx, 268, 0.9, auf)
        else {
          l.lineStyle(0.7, 0x39445e, 0.8)
          l.strokeRoundedRect(sx - 10, 255, 20, 26, 3)
          if (i === 1 && u > 7) {
            l.lineStyle(1, 0xb3403e, 0.5 * blende(u, 7, 19))
            l.beginPath()
            l.moveTo(sx - 5, 262)
            l.lineTo(sx + 5, 274)
            l.moveTo(sx + 5, 262)
            l.lineTo(sx - 5, 274)
            l.strokePath()
          }
        }
      }
      // Die eGK reist vom Haus zum Konto — und bleibt Schlüssel
      const reise = Phaser.Math.Clamp((u - 10.5) / 3, 0, 1)
      if (reise > 0) {
        const kx = 238 + (478 - 238) * reise
        const ky = 282 - Math.sin(reise * Math.PI) * 40
        malKarte(l, kx, ky, 1)
        if (reise >= 1) {
          const puls = 1 + Math.sin(t * 3) * 0.1
          l.lineStyle(1, 0xffd75e, 0.9)
          l.strokeCircle(478, 268, 15 * puls)
        }
      }
    },
  },

  // ---------------------------------------------- 2 · Die Medikationsliste
  'epa-medikation': {
    titel: 'DIE MEDIKATIONSLISTE',
    untertitel: 'Ein Teil der Akte führt sich von selbst.',
    zyklus: 20,
    zeilen: [
      { von: 0.4, bis: 5, text: 'In der Apotheke löst du dein E-Rezept ein — wie eben im Spiel.' },
      { von: 5, bis: 10, text: 'Der Eintrag wandert AUTOMATISCH in deine Medikationsliste. Die einzige Automatik der ePA.' },
      { von: 10, bis: 15, text: 'Die nächste Ärztin sieht sofort, was du nimmst — und erkennt Wechselwirkungen.' },
      { von: 15, bis: 19.5, text: 'Alles andere stellt nur ein, wer dich behandelt. Nichts lädt heimlich hoch.' },
    ],
    statik(g, scene, theme, W) {
      malHaus(g, scene, theme, 96, 300, 88, 84, 'APOTHEKE', '#ffd75e')
      malHaus(g, scene, theme, 540, 300, 88, 84, 'PRAXIS')
      // Die Liste in der Mitte: Akte im Großformat
      g.fillStyle(0x0d1a2c, 1)
      g.fillRoundedRect(272, 216, 96, 84, 5)
      g.lineStyle(1.2, K, 0.9)
      g.strokeRoundedRect(272, 216, 96, 84, 5)
      addText(scene, 320, 226, 'MEDIKATIONSLISTE', 5, { color: '#4de3ff', spacing: 0.6 }).setOrigin(0.5)
      addGlow(scene, 320, 258, K, 30, { alpha: 0.1 })
      // Praxis-Monitor
      g.fillStyle(0x0a1220, 1)
      g.fillRect(508, 236, 26, 20)
      g.lineStyle(0.8, 0x39445e, 1)
      g.strokeRect(508, 236, 26, 20)
      g.fillStyle(darken(theme.ground, 0.35), 1)
      g.fillRect(0, 300, W, 4)
    },
    leben(l, u, t) {
      // E-Rezept-Orb kommt zur Apotheke, Pille geht über die Theke
      const ankunft = Phaser.Math.Clamp(u / 2.4, 0, 1)
      if (ankunft < 1) {
        const ox = -12 + (96 - -12) * ankunft
        l.fillStyle(WARM_OFFEN, 0.35)
        l.fillCircle(ox, 262, 4)
        l.fillStyle(0xffffff, 0.95)
        l.fillCircle(ox, 262, 1.4)
      } else if (u < 5) {
        l.fillStyle(0xeef2f8, 0.95)
        l.fillRoundedRect(104 + Math.sin(t * 2) * 1.5, 270, 7, 3.4, 1.6)
        l.fillStyle(0xb3403e, 0.9)
        l.fillRect(104 + Math.sin(t * 2) * 1.5, 270, 3.5, 3.4)
      }
      // Der Eintrag fliegt in die Liste, eine Zeile tippt sich
      const flug = Phaser.Math.Clamp((u - 5.2) / 1.8, 0, 1)
      if (flug > 0 && flug < 1) {
        const fx = 120 + (300 - 120) * flug
        l.fillStyle(K, 0.25)
        l.fillCircle(fx, 268 - Math.sin(flug * Math.PI) * 30, 3.4)
        l.fillStyle(0xffffff, 0.95)
        l.fillCircle(fx, 268 - Math.sin(flug * Math.PI) * 30, 1.1)
      }
      const zeilen = [0, 1, 2].map((i) => (i < 2 ? 1 : Phaser.Math.Clamp((u - 7) / 1.4, 0, 1)))
      for (const [i, voll] of zeilen.entries()) {
        if (voll <= 0) continue
        l.fillStyle(i === 2 ? 0x2fa88c : 0x9aa6bc, i === 2 ? 0.95 : 0.75)
        l.fillRect(282, 240 + i * 12, 66 * voll, 2.4)
        if (i === 2 && voll < 1 && Math.sin(t * 10) > 0) {
          l.fillRect(282 + 66 * voll + 1, 238.8, 1.4, 5)
        }
      }
      // Abruf in der Praxis: Liste erscheint, Wechselwirkung blinkt, Haken
      const lesen = Phaser.Math.Clamp((u - 10.5) / 1.4, 0, 1)
      if (lesen > 0) {
        for (let i = 0; i < 3; i++) {
          const voll = Phaser.Math.Clamp(lesen * 3 - i, 0, 1)
          if (voll > 0) {
            l.fillStyle(0x8fd6c8, 0.85)
            l.fillRect(511, 240 + i * 4.4, 20 * voll, 1.6)
          }
        }
        if (u > 12.4 && u < 14.6) {
          const warn = Math.sin(t * 2.6) > 0 ? 0.95 : 0.35 // < 3 Hz
          l.lineStyle(1, 0xffb347, warn)
          l.strokeRect(509.5, 243.2, 23, 5.6)
        }
        if (u >= 14.6) {
          l.lineStyle(1.2, 0x7fd07f, 0.95)
          l.beginPath()
          l.moveTo(512, 250)
          l.lineTo(515, 253)
          l.lineTo(521, 245)
          l.strokePath()
        }
      }
    },
  },

  // ------------------------------------------------- 3 · Befugnis auf Zeit
  'epa-befugnis': {
    titel: 'BEFUGNIS AUF ZEIT',
    untertitel: 'Deine Karte öffnet Türen — aber nie für immer.',
    zyklus: 22,
    zeilen: [
      { von: 0.4, bis: 5.5, text: 'Karte gesteckt = Befugnis erteilt: Die Praxis darf 90 Tage in deine Akte.' },
      { von: 5.5, bis: 10.5, text: 'Die Apotheke bekommt standardmäßig nur 3 Tage — keine Dauerkarte.' },
      { von: 10.5, bis: 16, text: 'In der ePA-App regelst du alles: verlängern, verkürzen — oder sofort entziehen.' },
      { von: 16, bis: 21.5, text: 'Ohne Befugnis bleibt jede Tür zu. Genau das spielst du in dieser Station.' },
    ],
    statik(g, scene, theme, W) {
      malHaus(g, scene, theme, 96, 300, 84, 80, 'PRAXIS')
      malHaus(g, scene, theme, 544, 300, 84, 80, 'APOTHEKE', '#ffd75e')
      // Die Akte hinter zwei Toren (dieselbe Bildsprache wie die Spiel-Gates)
      malAkte(g, 320, 252, 1.4)
      addGlow(scene, 320, 252, K, 26, { alpha: 0.12 })
      for (const gx of [268, 372]) {
        g.fillStyle(0x39445e, 1)
        g.fillRect(gx - 2, 216, 4, 84)
      }
      // Kartenterminals
      for (const tx of [150, 490]) {
        g.fillStyle(0x2f3a52, 1)
        g.fillRect(tx - 8, 272, 16, 28)
        g.fillStyle(0x0a1220, 1)
        g.fillRect(tx - 5.5, 277, 11, 8)
        g.fillStyle(0x1b2438, 1)
        g.fillRect(tx - 6, 289, 12, 2.4)
      }
      g.fillStyle(darken(theme.ground, 0.35), 1)
      g.fillRect(0, 300, W, 4)
    },
    leben(l, u, t) {
      // Tor-Balken: links öffnet ab 1,5 s, rechts ab 6 s — rechts schließt bei 13 s
      const torL = Phaser.Math.Clamp((u - 1.5) / 1, 0, 1)
      const zu = Phaser.Math.Clamp((u - 13) / 0.8, 0, 1)
      const torR = Phaser.Math.Clamp((u - 6) / 1, 0, 1) * (1 - zu)
      for (const [gx, auf] of [
        [268, torL],
        [372, torR],
      ] as const) {
        const offen = 40 * auf
        l.fillStyle(0x7fe8ff, 0.85)
        l.fillRect(gx - 1.4, 216, 2.8, Math.max(2, 42 - offen))
        l.fillRect(gx - 1.4, 258 + offen, 2.8, Math.max(2, 42 - offen))
      }
      // Karten stecken in den Terminals
      const steckL = Phaser.Math.Clamp(u / 1.4, 0, 1)
      if (steckL > 0) malKarte(l, 150, 291 - 6 * (1 - steckL), 0.8)
      const steckR = Phaser.Math.Clamp((u - 5) / 1.4, 0, 1)
      if (steckR > 0 && zu < 1) malKarte(l, 490, 291 - 6 * (1 - steckR), 0.8, 1 - zu)
      // Zeitschaltuhren
      if (u > 2.2) {
        malUhr(l, 150, 250, 1 - (u % 22) / 60, 0x7fd07f)
        l.fillStyle(0xdfe6f0, 0.95)
      }
      if (u > 6.8 && zu < 1) malUhr(l, 490, 250, Math.max(0, 1 - (u - 6.8) / 7), 0xffb347)
      // Die App entzieht der Apotheke die Befugnis
      const app = blende(u, 11, 16.6)
      if (app > 0) {
        malHandy(l, 430, 200, 38)
        l.fillStyle(0x9aa6bc, 0.85 * app)
        l.fillRect(422, 192, 16, 1.8)
        // Schieberegler kippt auf AUS
        const kipp = Phaser.Math.Clamp((u - 12.2) / 0.8, 0, 1)
        l.fillStyle(kipp > 0.5 ? 0xb3403e : 0x2fa88c, 0.95 * app)
        l.fillRoundedRect(422, 198, 16, 6, 3)
        l.fillStyle(0xeef2f8, 0.95 * app)
        l.fillCircle(426 + 8 * kipp, 201, 2.4)
        if (kipp >= 1) {
          l.lineStyle(0.8, 0xb3403e, 0.9 * app)
          l.strokeCircle(490, 250, 10 + Math.sin(t * 3) * 1)
        }
      }
    },
  },

  // ------------------------------------------------------ 4 · Deine Regeln
  'epa-souveraen': {
    titel: 'DEINE REGELN',
    untertitel: 'Die ganze Architektur hat ein Ziel: Du behältst die Kontrolle.',
    zyklus: 22,
    zeilen: [
      { von: 0.4, bis: 5.5, text: 'Jeder Zugriff hinterlässt eine Spur: dein Protokoll, drei Jahre einsehbar.' },
      { von: 5.5, bis: 11, text: 'Einzelne Dokumente kannst du verbergen oder löschen — niemand sieht, DASS etwas fehlt.' },
      { von: 11, bis: 16.5, text: 'Und ganz grundsätzlich: Widerspruch genügt — die Kasse löscht die Akte vollständig.' },
      { von: 16.5, bis: 21.5, text: 'Zum Finale: Die letzte Tür öffnet nicht der Held — sondern die, der die Akte gehört.' },
    ],
    statik(g, scene, theme, W) {
      // Protokoll-Panel links
      g.fillStyle(0x0a1220, 1)
      g.fillRoundedRect(56, 212, 150, 92, 5)
      g.lineStyle(1, Phaser.Display.Color.HexStringToColor(theme.detail).color, 0.8)
      g.strokeRoundedRect(56, 212, 150, 92, 5)
      addText(scene, 131, 222, 'ZUGRIFFSPROTOKOLL', 5, { color: '#4de3ff', spacing: 0.6 }).setOrigin(0.5)
      // Akte mit drei Dokumenten in der Mitte
      g.fillStyle(0x0d1a2c, 1)
      g.fillRoundedRect(276, 210, 92, 96, 5)
      g.lineStyle(1.2, K, 0.9)
      g.strokeRoundedRect(276, 210, 92, 96, 5)
      addText(scene, 322, 220, 'DEINE ePA', 5.5, { color: '#4de3ff', spacing: 1 }).setOrigin(0.5)
      addGlow(scene, 322, 256, K, 30, { alpha: 0.1 })
      g.fillStyle(darken(theme.ground, 0.35), 1)
      g.fillRect(0, 300, W, 4)
    },
    leben(l, u, t) {
      // Protokollzeilen tickern herein
      const eintraege = ['PRAXIS · GESTERN · GELESEN', 'APOTHEKE · MO · EINGETRAGEN', 'KLINIK · 12.08. · GELESEN', 'DU · HEUTE · GEPRÜFT']
      for (let i = 0; i < eintraege.length; i++) {
        const auf = Phaser.Math.Clamp((u - 0.6 - i * 0.9) / 0.5, 0, 1)
        if (auf <= 0) continue
        l.fillStyle(i === 3 ? 0x8fd6c8 : 0x9aa6bc, (i === 3 ? 0.95 : 0.7) * auf)
        l.fillRect(66, 234 + i * 15, (i === 3 ? 96 : 118) * auf, 2.2)
        l.fillStyle(0x39445e, 0.8 * auf)
        l.fillRect(66, 240 + i * 15, 128, 0.8)
      }
      // Drei Dokumente; das mittlere wird per App verborgen
      const verborgen = Phaser.Math.Clamp((u - 6.5) / 1, 0, 1)
      const zerfall = Phaser.Math.Clamp((u - 12.5) / 1.6, 0, 1)
      const wieder = Phaser.Math.Clamp((u - 17.5) / 1.4, 0, 1)
      const akteDa = 1 - zerfall + wieder * zerfall
      for (let i = 0; i < 3; i++) {
        const alpha = (i === 1 ? 1 - verborgen * 0.82 : 1) * akteDa
        if (alpha <= 0.02) continue
        l.fillStyle(0xeef2f8, 0.9 * alpha)
        l.fillRect(288, 232 + i * 22, 68, 15)
        l.fillStyle(0x9aa6bc, 0.75 * alpha)
        l.fillRect(292, 236 + i * 22, 44, 1.6)
        l.fillRect(292, 240 + i * 22, 56, 1.6)
        if (i === 1 && verborgen > 0.4 && zerfall < 0.5) {
          l.lineStyle(0.8, 0x9fb3c8, 0.7 * akteDa)
          l.strokeRect(288, 232 + i * 22, 68, 15)
        }
      }
      // Widerspruch: Schalter kippt, die Akte löst sich in Funken auf
      const schalter = blende(u, 11.5, 17)
      if (schalter > 0) {
        malHandy(l, 440, 236, 40)
        l.fillStyle(0x9aa6bc, 0.85 * schalter)
        l.fillRect(431, 226, 18, 2)
        const kipp = Phaser.Math.Clamp((u - 12.3) / 0.7, 0, 1)
        l.fillStyle(kipp > 0.5 ? 0xb3403e : 0x39445e, 0.95 * schalter)
        l.fillRoundedRect(431, 232, 18, 7, 3.4)
        l.fillStyle(0xeef2f8, 0.95 * schalter)
        l.fillCircle(435 + 10 * kipp, 235.5, 2.6)
      }
      if (zerfall > 0 && zerfall < 1 && wieder <= 0) {
        for (let i = 0; i < 10; i++) {
          const a = (i / 10) * Math.PI * 2 + i
          l.fillStyle(K, 0.7 * (1 - zerfall))
          l.fillCircle(322 + Math.cos(a) * 40 * zerfall, 256 + Math.sin(a) * 34 * zerfall, 1.4)
        }
      }
      void t
    },
  },
}

// ------------------------------------------------------------------ Gerüst

export function zeichneWissen(
  scene: Phaser.Scene,
  theme: Theme,
  W: number,
  H: number,
  id: WissenId,
): void {
  void H
  const v = VIGNETTEN[id]

  const statik = scene.add.graphics().setDepth(0)
  v.statik(statik, scene, theme, W)

  addText(scene, W / 2, 44, v.titel, 26, { stroke: '#0a1730', strokeThickness: 1.2, spacing: 1.2 }).setOrigin(0.5)
  addText(scene, W / 2, 72, v.untertitel, 10.5, {
    color: '#cfe0ff',
    bold: false,
    stroke: '#0a1730',
    strokeThickness: 1,
  }).setOrigin(0.5)

  const zeilenTexte = v.zeilen.map((z) =>
    addText(scene, W / 2, 96, z.text, 9.5, { color: '#8fd6c8', bold: false, stroke: '#0a1730', strokeThickness: 1 })
      .setOrigin(0.5)
      .setAlpha(0),
  )

  const weiter = addText(scene, W - 12, 340, 'LEERTASTE: Weiter!', 12, { color: '#ffd591', spacing: 0.5 })
    .setOrigin(1, 0.5)
    .setDepth(3)
    .setAlpha(0)

  const leben = scene.add.graphics().setDepth(1)
  // Anker erst im ersten Update — nur EINE Uhr (Szenen-Uhr). Ein Mix mit
  // game.loop.time driftet nach Drosselung/Standby auseinander.
  let t0 = -1

  const malLeben = (t: number): void => {
    if (t0 < 0) t0 = t
    // Nie negativ: Springt die Uhr rückwärts (Tab-Suspend, Test-Treiber),
    // würde der Sperr-Balken sonst mit negativer Breite zeichnen.
    const tz = Math.max(0, t - t0)
    const u = tz % v.zyklus
    leben.clear()

    const frei = WISSEN_SPERRE[id]
    if (tz < frei) {
      weiter.setAlpha(0)
      leben.fillStyle(0xffd591, 0.2)
      leben.fillRect(W - 72, 339, 60, 1.6)
      leben.fillStyle(0xffd591, 0.6)
      leben.fillRect(W - 72, 339, (60 * tz) / frei, 1.6)
    } else {
      weiter.setAlpha(0.65 + 0.35 * Math.sin(tz * 4))
    }

    for (let i = 0; i < v.zeilen.length; i++) {
      zeilenTexte[i].setAlpha(blende(u, v.zeilen[i].von, v.zeilen[i].bis))
    }
    v.leben(leben, u, t)
  }

  const onUpdate = (): void => malLeben(scene.time.now / 1000)
  scene.events.on(Phaser.Scenes.Events.UPDATE, onUpdate)
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, onUpdate)
  })
  // Kein Initial-Render: Der würde t0 auf einer anderen Uhr ankern.
  // Der erste UPDATE kommt einen Frame später — das fadeIn deckt ihn.
}
