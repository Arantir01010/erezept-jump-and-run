import Phaser from 'phaser'

/**
 * LICHT — echte Lichtquellen statt aufgeklebter Glow-Bilder.
 *
 * Ein `addGlow` ist eine leuchtende Scheibe. Eine Lichtquelle hier ist mehr:
 *
 *  - **Abfall in drei Schichten.** Kern, Streuung, Hof. Ein einzelner
 *    Radialverlauf sieht immer nach Aufkleber aus; drei gestapelte mit
 *    unterschiedlicher Größe und Deckkraft ergeben eine glaubhafte Kurve.
 *  - **Lichtpfütze am Boden.** Die Quelle sucht den Boden unter sich und legt
 *    dort eine flache Ellipse ab. Das ist der Unterschied zwischen „etwas
 *    leuchtet" und „etwas beleuchtet den Raum".
 *  - **Ruhiges Atmen oder Flackern.** Statisches Licht wirkt tot.
 *
 * Der Bodenfinder kommt vom TerrainRenderer — er ist der Einzige, der die
 * Kachelkarte kennt. Ohne ihn entfällt einfach die Pfütze.
 */

type BodenFinder = (x: number, y: number) => number | null
let bodenFinder: BodenFinder | null = null

export function setzeBodenFinder(fn: BodenFinder | null): void {
  bodenFinder = fn
}

export interface LichtOpts {
  x?: number
  y?: number
  /** Folgt einem Objekt (REZI, Spieler, bewegliche Plattform). */
  ziel?: Phaser.GameObjects.Components.Transform
  farbe: number
  /** Reichweite in Design-Pixeln. */
  radius: number
  /** 0…1. Über 1 nur für das eine Leitlicht der Szene. */
  staerke?: number
  /** 0 = ruhig, 1 = Kerze. */
  flackern?: number
  /** Legt eine Lichtpfütze auf den Boden darunter (Default: ja). */
  pfuetze?: boolean
  depth?: number
}

export interface LichtHandle {
  setStaerke(v: number): void
  setFarbe(c: number): void
  destroy(): void
}

/** Eine Lichtquelle anlegen. Rückgabe zum Nachsteuern und Aufräumen. */
export function licht(scene: Phaser.Scene, opts: LichtOpts): LichtHandle {
  const staerke = opts.staerke ?? 0.5
  const depth = opts.depth ?? 6
  const r = opts.radius

  // Drei Schichten mit unterschiedlichem Abfall — das macht die Kurve
  const schichten = [
    { f: 0.42, a: 0.55 },
    { f: 1.0, a: 0.3 },
    { f: 2.0, a: 0.14 },
  ].map(({ f, a }) => {
    const img = scene.add
      .image(opts.x ?? 0, opts.y ?? 0, 'fx-glow')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(opts.farbe)
      .setAlpha(a * staerke)
      .setDepth(depth)
    img.setDisplaySize(r * 2 * f, r * 2 * f)
    return { img, a }
  })

  // Lichtpfütze: flache Ellipse auf dem Boden darunter
  const pfuetze =
    opts.pfuetze === false
      ? null
      : scene.add
          .image(opts.x ?? 0, opts.y ?? 0, 'fx-glow')
          .setBlendMode(Phaser.BlendModes.ADD)
          .setTint(opts.farbe)
          .setAlpha(0)
          .setDepth(depth)

  let phase = Math.random() * Math.PI * 2
  let aktStaerke = staerke

  const update = (_t: number, dt: number): void => {
    const x = opts.ziel ? opts.ziel.x : (opts.x ?? 0)
    const y = opts.ziel ? opts.ziel.y : (opts.y ?? 0)
    phase += (dt / 1000) * 2.1
    // Atmen (immer) plus optionales Flackern
    const atem = 1 + Math.sin(phase) * 0.1
    const flack = opts.flackern ? 1 - Math.random() * opts.flackern * 0.35 : 1
    const f = aktStaerke * atem * flack
    for (const s of schichten) {
      s.img.setPosition(x, y)
      s.img.setAlpha(s.a * f)
    }
    if (pfuetze) {
      const boden = bodenFinder?.(x, y)
      if (boden == null || boden - y > r * 1.3) {
        pfuetze.setAlpha(0)
      } else {
        const hoehe = Math.max(1, boden - y)
        // Je höher die Quelle, desto größer und schwächer die Pfütze
        const breite = r * (1.1 + hoehe / r)
        pfuetze.setPosition(x, boden - 1)
        pfuetze.setDisplaySize(breite * 2, Math.max(8, r * 0.45))
        pfuetze.setAlpha(0.3 * f * Math.max(0.15, 1 - hoehe / (r * 1.4)))
      }
    }
  }

  scene.events.on(Phaser.Scenes.Events.UPDATE, update)
  const destroy = (): void => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, update)
    for (const s of schichten) s.img.destroy()
    pfuetze?.destroy()
  }
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, destroy)
  update(0, 16)

  return {
    setStaerke: (v) => {
      aktStaerke = v
    },
    setFarbe: (c) => {
      for (const s of schichten) s.img.setTint(c)
      pfuetze?.setTint(c)
    },
    destroy,
  }
}

/**
 * Lichtschacht: ein Kegel von oben, aufgebaut aus mehreren schmalen Keilen mit
 * unterschiedlicher Deckkraft. Ein einzelnes Dreieck hat harte Kanten und sieht
 * nach Pappe aus — gestaffelte Keile ergeben den weichen Rand, den Staub in
 * der Luft erzeugen würde.
 *
 * Dazu Staubkörner, die IM Schacht driften: Sie machen das Licht körperlich.
 */
export function lichtschacht(
  scene: Phaser.Scene,
  x: number,
  hoehe: number,
  breiteOben: number,
  breiteUnten: number,
  farbe: number,
  staerke = 0.12,
  depth = 4,
): Phaser.GameObjects.Container {
  const c = scene.add.container(0, 0).setDepth(depth)
  const g = scene.add.graphics().setBlendMode(Phaser.BlendModes.ADD)
  const KEILE = 5
  const SCHEIBEN = 14
  // Waagerechter Abfall (Keile) MAL senkrechter Abfall (Scheiben).
  // Der senkrechte Teil ist der eigentliche Unterschied zum flachen Dreieck:
  // Licht wird nach unten hin schwächer, weil weniger Staub übrig ist — und
  // oben darf es nicht als harte Kante beginnen.
  const senkrecht = (t: number): number => {
    const anlauf = Math.min(1, t / 0.14) // weicher Beginn statt Kante
    const abfall = 1 - t * 0.82
    return anlauf * Math.max(0.08, abfall)
  }
  for (let i = KEILE; i >= 1; i--) {
    const f = i / KEILE
    const grund = staerke * (0.3 + 0.7 * (1 - f))
    for (let sN = 0; sN < SCHEIBEN; sN++) {
      const t0 = sN / SCHEIBEN
      const t1 = (sN + 1) / SCHEIBEN
      const b0 = (breiteOben + (breiteUnten - breiteOben) * t0) * f
      const b1 = (breiteOben + (breiteUnten - breiteOben) * t1) * f
      const a = grund * senkrecht((t0 + t1) / 2)
      if (a < 0.004) continue
      g.fillStyle(farbe, a)
      g.fillPoints(
        [
          new Phaser.Geom.Point(x - b0 / 2, hoehe * t0),
          new Phaser.Geom.Point(x + b0 / 2, hoehe * t0),
          new Phaser.Geom.Point(x + b1 / 2, hoehe * t1),
          new Phaser.Geom.Point(x - b1 / 2, hoehe * t1),
        ],
        true,
      )
    }
  }
  c.add(g)
  scene.tweens.add({
    targets: g,
    alpha: 0.45,
    duration: 4200 + Math.random() * 2600,
    yoyo: true,
    repeat: -1,
    ease: 'Sine.easeInOut',
  })

  // Staub im Schacht: langsam fallend, heller als der Staub daneben
  const koerner = Math.max(4, Math.round(breiteUnten / 9))
  for (let i = 0; i < koerner; i++) {
    const kx = x + (Math.random() - 0.5) * breiteUnten * 0.8
    const ky = Math.random() * hoehe
    const korn = scene.add
      .image(kx, ky, 'fx-mote')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(farbe)
      .setAlpha(0.18 + Math.random() * 0.35)
      .setScale(0.18 + Math.random() * 0.3)
    scene.tweens.add({
      targets: korn,
      y: ky + hoehe * 0.5,
      x: kx + (Math.random() - 0.5) * 14,
      alpha: 0,
      duration: 6000 + Math.random() * 6000,
      repeat: -1,
      delay: Math.random() * 5000,
      ease: 'Linear',
    })
    c.add(korn)
  }
  return c
}

/**
 * Sichtkegel (Lauscher): derselbe Aufbau wie der Lichtschacht, aber waagerecht
 * und an ein Objekt gebunden. Er ist Spielinformation — deshalb deutlich
 * sichtbar, aber ohne harte Kante, damit er nicht wie eine Wand wirkt.
 */
export interface SichtkegelHandle {
  zeichne(
    x: number,
    y: number,
    laenge: number,
    oeffnung: number,
    richtung: number,
    staerke: number,
    farbe: number,
  ): void
  destroy(): void
}

export function sichtkegel(scene: Phaser.Scene, depth = 5): SichtkegelHandle {
  const g = scene.add.graphics().setBlendMode(Phaser.BlendModes.ADD).setDepth(depth)
  return {
    zeichne(x, y, laenge, oeffnung, richtung, staerke, farbe) {
      g.clear()
      const KEILE = 5
      for (let i = KEILE; i >= 1; i--) {
        const f = i / KEILE
        const halb = (oeffnung / 2) * f
        g.fillStyle(farbe, staerke * (0.32 + 0.68 * (1 - f)))
        g.fillTriangle(x, y, x + richtung * laenge, y - halb, x + richtung * laenge, y + halb)
      }
    },
    destroy() {
      g.destroy()
    },
  }
}

/**
 * Lichtwisch: ein heller Streifen, der einmal quer durchs Bild zieht.
 *
 * Ersetzt den harten Schnitt zwischen den Szenen. Ein Fade allein sagt „Bild
 * weg"; ein Wisch sagt „es geht weiter" — und passt zum Thema, weil das
 * e-Rezept als Lichtimpuls durch die Infrastruktur reist.
 */
export function lichtwisch(
  scene: Phaser.Scene,
  farbe = 0xbfe9ff,
  dauer = 520,
  richtung: 1 | -1 = 1,
): void {
  const cam = scene.cameras.main
  const w = cam.displayWidth
  const h = cam.displayHeight
  const start = cam.worldView.x + (richtung > 0 ? -w * 0.35 : w * 1.35)
  const ziel = cam.worldView.x + (richtung > 0 ? w * 1.35 : -w * 0.35)
  const y = cam.worldView.y + h / 2

  const g = scene.add.graphics().setBlendMode(Phaser.BlendModes.ADD).setDepth(80)
  // Der Streifen ist selbst ein Verlauf: harte Kante vorn, langer Schweif
  const BAHNEN = 10
  for (let i = 0; i < BAHNEN; i++) {
    const f = i / BAHNEN
    g.fillStyle(farbe, 0.16 * (1 - f))
    g.fillRect(-richtung * f * w * 0.22 - 2, -h, 3 + f * 10, h * 2)
  }
  g.setPosition(start, y)
  scene.tweens.add({
    targets: g,
    x: ziel,
    duration: dauer,
    ease: 'Cubic.easeInOut',
    onComplete: () => g.destroy(),
  })
}
