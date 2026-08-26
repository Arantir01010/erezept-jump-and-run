import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { materialien, type Material, LICHT, WARM_OFFEN, KUEHL_GESCHUETZT } from './material'
import { darken } from './atmos'

/**
 * VEKTOR-OBJEKTE — dieselbe Idee wie bei Paul und REZI, für alles andere.
 *
 * Die Pixel-Textur bleibt vollständig erhalten und wird nur unsichtbar
 * geschaltet. Gezeichnet wird eine Vektorform an ihrer Stelle. Damit bleiben
 * Physik-Körper, Kollisionen, `setDisplaySize`, Animationen, Tweens und
 * Tönungen unangetastet — die Bausteine in `src/mechanics/` merken davon
 * nichts außer einer einzigen zusätzlichen Zeile.
 *
 * Die Form richtet sich nach `displayWidth`/`displayHeight` der Sprite, nicht
 * nach festen Maßen: Tore und Plattformen werden im Level gestreckt, und die
 * Zeichnung muss mitwachsen.
 */

/** Die Farbwelt, in der gerade gezeichnet wird — die Szene setzt sie beim Aufbau. */
let aktuellesTheme: Theme | null = null
let aktuelleMaterialien: Record<string, Material> | null = null

export function setzeZeichenTheme(theme: Theme): void {
  aktuellesTheme = theme
  aktuelleMaterialien = materialien(theme)
}

export interface ZeichenKontext {
  g: Phaser.GameObjects.Graphics
  /** Breite/Höhe der Sprite in Design-Pixeln (berücksichtigt setDisplaySize). */
  w: number
  h: number
  /** Sekunden seit Spielstart — für ruhige Eigenbewegung. */
  t: number
  sprite: Phaser.GameObjects.Components.Transform & { texture?: Phaser.Textures.Texture }
  key: string
  frame: number
  mat: Record<string, Material>
  theme: Theme
}

type Zeichner = (k: ZeichenKontext) => void

// ---------------------------------------------------------------- Hilfsformen

/** Weicher Hof — der zentrale Baustein für Eigenlicht ohne Textur. */
function hof(k: ZeichenKontext, x: number, y: number, r: number, farbe: number, alpha: number): void {
  const { g } = k
  for (let i = 3; i >= 1; i--) {
    g.fillStyle(farbe, (alpha * (4 - i)) / 9)
    g.fillCircle(x, y, (r * i) / 2)
  }
}

/** Ring mit Strichstärke — häufigste Form bei Datenobjekten. */
function ring(k: ZeichenKontext, x: number, y: number, r: number, dicke: number, farbe: number, alpha: number): void {
  k.g.lineStyle(dicke, farbe, alpha)
  k.g.strokeCircle(x, y, r)
}

// ---------------------------------------------------------------- Zeichner

const ZEICHNER: Record<string, Zeichner> = {
  // Das Sammelobjekt: kommt hundertfach vor und trägt deshalb am meisten.
  // Kern, zwei Ringe, langsam gegenläufig — liest sich als Datenpaket.
  datenbit: (k) => {
    const c = KUEHL_GESCHUETZT
    hof(k, 0, 0, 7, c, LICHT.signal * 0.7)
    ring(k, 0, 0, 3.6, 1.1, c, 0.95)
    const puls = 5.2 + Math.sin(k.t * 2.2) * 0.6
    ring(k, 0, 0, puls, 0.55, c, 0.4)
    k.g.fillStyle(0xffffff, 1)
    k.g.fillCircle(0, 0, 1.5)
  },

  // Wegmarke: schlanker Mast mit Wimpel. Aktiv wird sie über die Deckkraft
  // der Sprite gesteuert — die Mechanik setzt sie von 0,6 auf 1.
  checkpoint: (k) => {
    const h = k.h
    const c = 0x7fe8a0
    k.g.fillStyle(darken('#7fe8a0', 0.55), 1)
    k.g.fillRoundedRect(-0.8, -h / 2, 1.6, h, 0.8)
    k.g.fillStyle(c, 0.9)
    k.g.fillRoundedRect(-0.8, -h / 2, 1.6, 2.4, 0.8)
    const flatter = Math.sin(k.t * 2.4) * 0.8
    k.g.fillStyle(c, 0.85)
    k.g.fillTriangle(0.8, -h / 2 + 0.5, 7 + flatter, -h / 2 + 3, 0.8, -h / 2 + 6)
    hof(k, 0, -h / 2 + 3, 5, c, LICHT.ambient)
  },

  // Levelausgang: eine Nische mit leuchtendem Rahmen. Die Tiefe entsteht aus
  // dem dunklen Inneren — ein flaches Rechteck wäre nur ein Kasten.
  door: (k) => {
    const { w, h, g } = k
    const rahmen = k.mat.metall
    const c = k.mat.signal.kante
    g.fillStyle(rahmen.flaeche, 1)
    g.fillRoundedRect(-w / 2, -h / 2, w, h, 2)
    g.fillStyle(darken(k.theme.skyTop, 0.7), 1)
    g.fillRoundedRect(-w / 2 + 2, -h / 2 + 2, w - 4, h - 3, { tl: w / 2 - 2, tr: w / 2 - 2, bl: 0, br: 0 })
    g.lineStyle(1, c, 0.85)
    g.strokeRoundedRect(-w / 2 + 2, -h / 2 + 2, w - 4, h - 3, { tl: w / 2 - 2, tr: w / 2 - 2, bl: 0, br: 0 })
    // Schwelle: der Streifen, über den man tritt
    g.fillStyle(c, 0.8)
    g.fillRect(-w / 2 + 2, h / 2 - 1.6, w - 4, 1.2)
    hof(k, 0, 0, w * 0.9, c, LICHT.signal * 0.5)
  },

  // Tor: gestapelte Riegel. Wird im Level auf Höhe gestreckt, deshalb
  // Segmente statt fester Zeichnung.
  gate: (k) => {
    const { w, h, g } = k
    const m = k.mat.metall
    g.fillStyle(m.flaeche, 1)
    g.fillRoundedRect(-w / 2, -h / 2, w, h, 1.2)
    g.lineStyle(0.6, m.kante, 0.8)
    g.strokeRoundedRect(-w / 2, -h / 2, w, h, 1.2)
    const segmente = Math.max(2, Math.round(h / 7))
    for (let i = 1; i < segmente; i++) {
      const y = -h / 2 + (h / segmente) * i
      g.fillStyle(0x000000, 0.35)
      g.fillRect(-w / 2 + 0.6, y - 0.4, w - 1.2, 0.8)
      g.fillStyle(0xffffff, 0.1)
      g.fillRect(-w / 2 + 0.6, y + 0.4, w - 1.2, 0.4)
    }
  },

  // Plattform/Podest: wie das Gelände — dunkle Masse, Licht auf der Oberkante.
  podest: (k) => {
    const { w, h, g } = k
    const m = k.mat.fels
    g.fillStyle(m.flaeche, 1)
    g.fillRoundedRect(-w / 2, -h / 2, w, h, Math.min(2.5, h / 2))
    g.fillStyle(m.kante, 1)
    g.fillRect(-w / 2 + 0.6, -h / 2, w - 1.2, 1.1)
    g.fillStyle(0xffffff, 0.5)
    g.fillRect(-w / 2 + 0.6, -h / 2, w - 1.2, 0.45)
    hof(k, 0, -h / 2, w * 0.7, m.licht, LICHT.ambient * 1.2)
  },

  // Verschlüsselungs-Dusche: Kopf plus fallende Lichtfäden.
  dusche: (k) => {
    const { w, g } = k
    const c = KUEHL_GESCHUETZT
    g.fillStyle(k.mat.metall.flaeche, 1)
    g.fillRoundedRect(-w / 2, -4, w, 5, 2)
    g.fillStyle(c, 0.85)
    g.fillRoundedRect(-w / 2 + 1, 0.4, w - 2, 1, 0.5)
    for (let i = 0; i < 5; i++) {
      const x = -w / 2 + 2 + (i * (w - 4)) / 4
      const phase = (k.t * 26 + i * 5) % 14
      g.fillStyle(c, 0.5 - phase / 40)
      g.fillRoundedRect(x - 0.3, 2 + phase, 0.6, 3.5, 0.3)
    }
    hof(k, 0, 2, w * 0.8, c, LICHT.signal * 0.4)
  },

  // Signatur-Stempel: Griff und Fuß. Warm, weil er etwas VERBINDLICH macht.
  stempel: (k) => {
    const { w, h, g } = k
    const c = k.mat.signal.kante
    g.fillStyle(k.mat.metall.flaeche, 1)
    g.fillRoundedRect(-1.6, -h / 2, 3.2, h * 0.45, 1.4)
    g.fillStyle(k.mat.signal.flaeche, 1)
    g.fillRoundedRect(-w / 2, -h / 2 + h * 0.42, w, h * 0.5, 2)
    g.fillStyle(c, 1)
    g.fillRect(-w / 2 + 1, -h / 2 + h * 0.42, w - 2, 1)
    g.fillStyle(c, 0.95)
    g.fillRect(-w / 2 + 1.4, h / 2 - 2.6, w - 2.8, 1.4)
    hof(k, 0, h / 2 - 2, w * 0.8, c, LICHT.signal * 0.5)
  },

  // Kartenleser: Gehäuse mit Schlitz und Statuslicht.
  kartenleser: (k) => {
    const { w, h, g } = k
    const m = k.mat.metall
    g.fillStyle(m.flaeche, 1)
    g.fillRoundedRect(-w / 2, -h / 2, w, h, 2.4)
    g.lineStyle(0.7, m.kante, 0.9)
    g.strokeRoundedRect(-w / 2, -h / 2, w, h, 2.4)
    // Schlitz
    g.fillStyle(0x000000, 0.7)
    g.fillRoundedRect(-w / 2 + 2, -h / 2 + 3, w - 4, 1.8, 0.9)
    // Statuslicht: atmet, damit das Terminal „wartet" statt tot zu sein
    const puls = 0.55 + Math.sin(k.t * 3) * 0.3
    const c = k.mat.signal.kante
    g.fillStyle(c, puls)
    g.fillCircle(0, h / 2 - 3, 1.3)
    hof(k, 0, h / 2 - 3, 6, c, LICHT.signal * 0.5 * puls)
  },

  // Lauscher: das mitlesende Auge. WARM — offen, sichtbar, mitlesbar.
  // Der Blinzler kommt aus der laufenden Animation (Frame 2).
  lauscher: (k) => {
    const { w, h, g } = k
    const c = WARM_OFFEN
    const zu = k.frame === 2
    hof(k, 0, 0, w * 0.75, c, LICHT.signal * 0.8)
    g.fillStyle(darken('#ff8a3a', 0.6), 1)
    g.fillEllipse(0, 0, w, h)
    g.lineStyle(1, c, 0.95)
    g.strokeEllipse(0, 0, w - 1, h - 1)
    if (zu) {
      g.fillStyle(c, 0.9)
      g.fillRoundedRect(-w / 2 + 1.5, -0.7, w - 3, 1.4, 0.7)
      return
    }
    g.fillStyle(0xffe9c8, 0.95)
    g.fillEllipse(0, 0, w * 0.62, h * 0.62)
    g.fillStyle(0x1b1208, 1)
    g.fillCircle(0, 0, h * 0.2)
    g.fillStyle(0xffffff, 0.8)
    g.fillCircle(-h * 0.09, -h * 0.09, h * 0.06)
  },

  // Datenkrake: Silhouette mit schwingenden Armen. Sie kommt nie durchs Glas —
  // deshalb bedrohlich in der Form, aber ohne Angriffsgeste.
  krake: (k) => {
    const { w, h, g } = k
    const c = 0x9a7ae8
    hof(k, 0, 0, w * 0.6, c, LICHT.ambient * 1.4)
    g.fillStyle(darken('#7a4fd0', 0.35), 1)
    g.fillEllipse(0, -h * 0.1, w * 0.9, h * 0.85)
    g.fillStyle(c, 0.9)
    g.fillCircle(-w * 0.18, -h * 0.15, 1.2)
    g.fillCircle(w * 0.18, -h * 0.15, 1.2)
    g.fillStyle(darken('#7a4fd0', 0.45), 1)
    for (let i = 0; i < 5; i++) {
      const x = -w * 0.32 + (i * w * 0.64) / 4
      const schwung = Math.sin(k.t * 1.8 + i * 1.1) * 1.6
      g.beginPath()
      g.moveTo(x - 0.9, h * 0.18)
      g.lineTo(x + 0.9, h * 0.18)
      g.lineTo(x + schwung + 0.5, h * 0.62)
      g.lineTo(x + schwung - 0.5, h * 0.62)
      g.closePath()
      g.fillPath()
    }
  },

  // Skimming-Kralle: zwei Backen, die sich schließen. Der Zustand steckt im
  // Texturnamen — die Mechanik schaltet ihn, wir lesen ihn nur ab.
  kralle: (k) => {
    const { w, h, g } = k
    const offen = k.key.endsWith('open')
    const spalt = offen ? h * 0.3 : h * 0.06
    const m = k.mat.metall
    g.fillStyle(m.flaeche, 1)
    g.fillRoundedRect(-w / 2, -1, w * 0.34, 2, 1)
    const backe = (oben: boolean): void => {
      const s = oben ? -1 : 1
      g.fillStyle(m.flaeche, 1)
      g.beginPath()
      g.moveTo(-w * 0.16, s * spalt)
      g.lineTo(w * 0.3, s * (spalt + h * 0.22))
      g.lineTo(w * 0.5, s * (spalt + h * 0.06))
      g.lineTo(w * 0.12, s * (spalt * 0.4))
      g.closePath()
      g.fillPath()
      g.lineStyle(0.6, m.kante, 0.85)
      g.strokePath()
    }
    backe(true)
    backe(false)
    g.fillStyle(0xff5050, offen ? 0.5 : 0.95)
    g.fillCircle(-w * 0.34, 0, 1.1)
  },

  // Portal: konzentrische Ringe, gegenläufig. Der Blickfang am Levelende.
  portal: (k) => {
    const { w, g } = k
    const a = KUEHL_GESCHUETZT
    const b = 0x9a7ae8
    hof(k, 0, 0, w * 0.8, a, LICHT.signal * 0.9)
    for (let i = 0; i < 3; i++) {
      const r = w * 0.42 - i * (w * 0.11)
      const dreh = k.t * (i % 2 === 0 ? 1.1 : -1.4) + i
      g.lineStyle(1.1, i % 2 === 0 ? a : b, 0.9 - i * 0.12)
      g.beginPath()
      g.arc(0, 0, r, dreh, dreh + Math.PI * 1.45)
      g.strokePath()
    }
    const puls = 1.6 + Math.sin(k.t * 3) * 0.35
    g.fillStyle(0xffffff, 0.95)
    g.fillCircle(0, 0, puls)
  },
}

/** Kartenfarben: eine Karte pro Rolle, klar unterscheidbar. */
const KARTEN_FARBE: Record<string, number> = {
  egk: 0x7fd07f,
  hba: 0x4de3ff,
  smcb: 0xffd75e,
}

ZEICHNER['karte'] = (k) => {
  const { w, h, g } = k
  const rolle = k.key.split('-')[1] ?? 'egk'
  const c = KARTEN_FARBE[rolle] ?? 0xffd75e
  hof(k, 0, 0, w * 0.7, c, LICHT.signal * 0.5)
  g.fillStyle(darken('#ffffff', 0.86), 1)
  g.fillRoundedRect(-w / 2, -h / 2, w, h, 2)
  g.lineStyle(0.8, c, 0.95)
  g.strokeRoundedRect(-w / 2, -h / 2, w, h, 2)
  // Chip
  g.fillStyle(c, 0.95)
  g.fillRoundedRect(-w / 2 + 1.6, -h / 2 + 1.6, w * 0.3, h * 0.34, 0.8)
  g.fillStyle(0x0a1520, 0.75)
  g.fillRect(-w / 2 + 2.2, -h / 2 + 2.6, w * 0.18, 0.5)
  // Datenzeilen
  g.fillStyle(c, 0.45)
  g.fillRect(-w / 2 + 1.6, h / 2 - 3.4, w * 0.62, 0.7)
  g.fillRect(-w / 2 + 1.6, h / 2 - 2.1, w * 0.42, 0.7)
}


/** Siegelfarben: jede Station bekommt ihre eigene, wiedererkennbare Marke. */
const SIEGEL: Record<string, { farbe: number; glyph: 'haken' | 'schloss' | 'karte' | 'stern' }> = {
  egk: { farbe: 0x7fd07f, glyph: 'karte' },
  vpn: { farbe: 0x4de3ff, glyph: 'schloss' },
  vsdm: { farbe: 0x4a9b7d, glyph: 'haken' },
  generic: { farbe: 0xffd75e, glyph: 'stern' },
}

ZEICHNER['seal'] = (k) => {
  const { w, h, g } = k
  const art = SIEGEL[k.key.split('-')[1] ?? 'generic'] ?? SIEGEL.generic
  const r = Math.min(w, h) / 2
  hof(k, 0, 0, r * 1.6, art.farbe, LICHT.ambient * 1.6)
  g.fillStyle(darken('#0a1520', 0.1), 1)
  g.fillCircle(0, 0, r)
  g.lineStyle(Math.max(0.8, r * 0.16), art.farbe, 0.95)
  g.strokeCircle(0, 0, r * 0.88)
  g.fillStyle(art.farbe, 1)
  const u = r * 0.42
  switch (art.glyph) {
    case 'haken':
      g.fillPoints(
        [
          new Phaser.Geom.Point(-u, 0),
          new Phaser.Geom.Point(-u * 0.3, u * 0.7),
          new Phaser.Geom.Point(u, -u * 0.8),
          new Phaser.Geom.Point(u * 0.75, -u * 1.25),
          new Phaser.Geom.Point(-u * 0.3, -u * 0.1),
          new Phaser.Geom.Point(-u * 0.65, -u * 0.5),
        ],
        true,
      )
      break
    case 'schloss':
      g.fillRoundedRect(-u * 0.85, -u * 0.15, u * 1.7, u * 1.3, u * 0.3)
      g.lineStyle(Math.max(0.6, r * 0.13), art.farbe, 1)
      g.beginPath()
      g.arc(0, -u * 0.2, u * 0.55, Math.PI, 0)
      g.strokePath()
      break
    case 'karte':
      g.fillRoundedRect(-u, -u * 0.7, u * 2, u * 1.4, u * 0.3)
      g.fillStyle(darken('#0a1520', 0.1), 1)
      g.fillRoundedRect(-u * 0.7, -u * 0.4, u * 0.7, u * 0.6, u * 0.15)
      break
    default:
      for (let i = 0; i < 4; i++) {
        const a = (i * Math.PI) / 2
        g.fillTriangle(
          Math.cos(a) * u * 1.15,
          Math.sin(a) * u * 1.15,
          Math.cos(a + 0.7) * u * 0.4,
          Math.sin(a + 0.7) * u * 0.4,
          Math.cos(a - 0.7) * u * 0.4,
          Math.sin(a - 0.7) * u * 0.4,
        )
      }
  }
}

/** Avatar-Grundfarben für den Tages-Highscore (keine Personendaten). */
const AVATAR_FARBEN = [
  0xe0574a, 0x4a8ae8, 0x7fd07f, 0xffd75e, 0x9a7ae8, 0x5fe0ff,
  0xe88ab6, 0xe8934a, 0x4a9b7d, 0x9fb3c8, 0xc9a53a, 0x9ff0d8,
]

ZEICHNER['avatar'] = (k) => {
  const { w, h, g } = k
  const i = Number(k.key.split('-')[1] ?? 0) % AVATAR_FARBEN.length
  const c = AVATAR_FARBEN[i]
  const r = Math.min(w, h) / 2
  hof(k, 0, 0, r * 1.5, c, LICHT.ambient)
  g.fillStyle(c, 1)
  g.fillCircle(0, 0, r * 0.92)
  g.fillStyle(0xffffff, 0.22)
  g.fillEllipse(0, -r * 0.35, r * 1.3, r * 0.7)
  g.fillStyle(0x101822, 1)
  const ey = -r * 0.12
  if (i % 2 === 0) {
    g.fillCircle(-r * 0.32, ey, r * 0.14)
    g.fillCircle(r * 0.32, ey, r * 0.14)
  } else {
    g.fillRoundedRect(-r * 0.46, ey - r * 0.08, r * 0.28, r * 0.16, r * 0.08)
    g.fillRoundedRect(r * 0.18, ey - r * 0.08, r * 0.28, r * 0.16, r * 0.08)
  }
  const m = i % 3
  if (m === 0) g.fillRoundedRect(-r * 0.3, r * 0.3, r * 0.6, r * 0.14, r * 0.07)
  else if (m === 1) g.fillCircle(0, r * 0.36, r * 0.12)
  else {
    g.fillCircle(-r * 0.26, r * 0.32, r * 0.09)
    g.fillCircle(r * 0.26, r * 0.32, r * 0.09)
  }
}

/** Texturschlüssel → Zeichner. Suffixe (`-0`, `-open`, `-egk`) fallen weg. */
function zeichnerFuer(key: string): Zeichner | undefined {
  if (ZEICHNER[key]) return ZEICHNER[key]
  const stamm = key.split('-')[0]
  return ZEICHNER[stamm]
}

/**
 * Hängt die Vektorform an eine Sprite. Ohne passenden Zeichner passiert
 * nichts — der Aufruf ist also überall gefahrlos.
 */
export function veredele(
  scene: Phaser.Scene,
  sprite: Phaser.GameObjects.Sprite | Phaser.GameObjects.Image | Phaser.Physics.Arcade.Image,
): void {
  const theme = aktuellesTheme
  const mat = aktuelleMaterialien
  if (!theme || !mat) return
  const key = sprite.texture.key
  const zeichner = zeichnerFuer(key)
  if (!zeichner) return

  const w = sprite.displayWidth
  const h = sprite.displayHeight
  sprite.setVisible(false)
  const g = scene.add.graphics().setDepth(sprite.depth)

  const zeichnen = (): void => {
    if (!sprite.active) {
      g.destroy()
      scene.events.off(Phaser.Scenes.Events.UPDATE, zeichnen)
      return
    }
    g.clear()
    g.setPosition(sprite.x, sprite.y)
    g.setAlpha(sprite.alpha)
    g.setDepth(sprite.depth)
    g.setScale((sprite.flipX ? -1 : 1) * 1, 1)
    zeichner({
      g,
      w: sprite.displayWidth || w,
      h: sprite.displayHeight || h,
      t: scene.time.now / 1000,
      sprite,
      key: sprite.texture.key,
      frame: (sprite as Phaser.GameObjects.Sprite).anims?.currentFrame?.index ?? 1,
      mat,
      theme,
    })
  }

  scene.events.on(Phaser.Scenes.Events.UPDATE, zeichnen)
  const aufraeumen = (): void => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, zeichnen)
    g.destroy()
  }
  sprite.once(Phaser.GameObjects.Events.DESTROY, aufraeumen)
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, aufraeumen)
  zeichnen()
}

/**
 * Wie `veredele`, aber für Kinder eines Containers (REZIs Siegel).
 *
 * Der Unterschied ist die Koordinatenwelt: Ein Container-Kind lebt in lokalen
 * Koordinaten. Eine Graphics daneben in die Welt zu setzen würde beim ersten
 * Schweben von REZI auseinanderlaufen — sie muss in denselben Container.
 */
export function veredeleImContainer(
  scene: Phaser.Scene,
  container: Phaser.GameObjects.Container,
  kind: Phaser.GameObjects.Image | Phaser.GameObjects.Sprite,
): void {
  const mat = aktuelleMaterialien
  const theme = aktuellesTheme
  if (!mat || !theme) return
  const zeichner = zeichnerFuer(kind.texture.key)
  if (!zeichner) return

  kind.setVisible(false)
  const g = scene.add.graphics()
  container.add(g)

  const zeichnen = (): void => {
    if (!kind.active) {
      g.destroy()
      scene.events.off(Phaser.Scenes.Events.UPDATE, zeichnen)
      return
    }
    g.clear()
    g.setPosition(kind.x, kind.y)
    g.setAlpha(kind.alpha)
    zeichner({
      g,
      w: kind.displayWidth,
      h: kind.displayHeight,
      t: scene.time.now / 1000,
      sprite: kind,
      key: kind.texture.key,
      frame: 1,
      mat,
      theme,
    })
  }
  scene.events.on(Phaser.Scenes.Events.UPDATE, zeichnen)
  const weg = (): void => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, zeichnen)
    g.destroy()
  }
  kind.once(Phaser.GameObjects.Events.DESTROY, weg)
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, weg)
  zeichnen()
}
