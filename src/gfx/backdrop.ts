import Phaser from 'phaser'
import type { Theme } from '../level/schema'

export interface BackdropOpts {
  /** Weiche Lichtkegel von oben (digitale Level) — Stadt/Attract lassen das aus. */
  lightShafts?: boolean
}

/**
 * Hintergrund pro Level: Farbverlauf + zwei Silhouetten-Ebenen + Sterne/
 * Datenfunken + optionale Lichtkegel. Alles prozedural aus dem Theme —
 * Custom-Art ersetzt das später 1:1.
 *
 * Zoom-fest umgesetzt: Der Verlauf ist ein Weltobjekt in voller Weltbreite,
 * die Parallax-Ebenen folgen der Kamera per Update-Hook (Faktor f bedeutet:
 * Ebene wandert mit f·Kamera mit → wirkt wie scrollFactor 1−f).
 * scrollFactor < 1 säße unter Kamera-Zoom versetzt — deshalb dieser Weg.
 */
export function drawBackdrop(
  scene: Phaser.Scene,
  theme: Theme,
  worldWidth: number,
  worldHeight: number,
  opts: BackdropOpts = {},
): void {
  const cam = scene.cameras.main
  const viewW = cam.displayWidth
  const viewH = cam.displayHeight
  const accent = Phaser.Display.Color.HexStringToColor(theme.accent).color

  // --- Farbverlauf (horizontal uniform → braucht kein Parallax) ---
  const g = scene.add.graphics().setDepth(0)
  const gradW = Math.max(worldWidth, viewW)
  const gradH = Math.max(worldHeight, viewH)
  const top = Phaser.Display.Color.HexStringToColor(theme.skyTop)
  const bottom = Phaser.Display.Color.HexStringToColor(theme.skyBottom)
  if (scene.game.renderer.type === Phaser.WEBGL) {
    g.fillGradientStyle(top.color, top.color, bottom.color, bottom.color, 1)
    g.fillRect(0, 0, gradW, gradH)
  } else {
    // Canvas-Fallback (?renderer=canvas): fillGradientStyle ist WebGL-only —
    // 24 interpolierte Streifen sehen praktisch identisch aus.
    const STEPS = 24
    for (let s = 0; s < STEPS; s++) {
      const c = Phaser.Display.Color.Interpolate.ColorWithColor(top, bottom, STEPS - 1, s)
      g.fillStyle(Phaser.Display.Color.GetColor(c.r, c.g, c.b), 1)
      g.fillRect(0, (gradH / STEPS) * s, gradW, gradH / STEPS + 1)
    }
  }

  // --- Sterne / Datenfunken (sehr fern, Faktor 0,9 — glimmen asynchron) ---
  const stars = scene.add.container(0, 0).setDepth(0)
  const starSpan = worldWidth * 0.1 + viewW + 60
  const starCount = Math.round(26 + viewW / 40)
  for (let i = 0; i < starCount; i++) {
    const star = scene.add
      .image(Math.random() * starSpan, Math.random() * worldHeight * 0.72, 'fx-mote')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(i % 3 === 0 ? accent : 0xffffff)
      .setScale(0.14 + Math.random() * 0.22)
      .setAlpha(0.12 + Math.random() * 0.5)
    scene.tweens.add({
      targets: star,
      alpha: 0.08 + Math.random() * 0.2,
      duration: 900 + Math.random() * 1800,
      yoyo: true,
      repeat: -1,
      delay: Math.random() * 1500,
      ease: 'Sine.easeInOut',
    })
    stars.add(star)
  }

  // --- Ferne Silhouetten-Ebene (Faktor 0,85 — klein, dunstig) ---
  const farSil = scene.add.graphics().setDepth(0)
  const farColor = Phaser.Display.Color.HexStringToColor(theme.skyBottom).color
  const farSpan = worldWidth * 0.15 + viewW + 80
  {
    let x = -20
    let i = 0
    while (x < farSpan) {
      const w = 18 + ((i * 29) % 26)
      const h = 34 + ((i * 41) % 64)
      farSil.fillStyle(farColor, 0.4)
      farSil.fillRect(x, worldHeight - h - 40, w, h + 40)
      // Antennenlicht auf jedem 3. Turm
      if (i % 3 === 0) {
        farSil.fillStyle(accent, 0.35)
        farSil.fillRect(x + Math.floor(w / 2), worldHeight - h - 43, 1, 3)
      }
      x += w + 10 + ((i * 13) % 16)
      i += 1
    }
  }

  // --- Nahe Silhouetten-Ebene (Faktor 0,75 — die bisherigen Blöcke) ---
  const sil = scene.add.graphics().setDepth(0)
  const color = Phaser.Display.Color.HexStringToColor(theme.skyBottom).color
  const detail = Phaser.Display.Color.HexStringToColor(theme.detail).color
  const span = Math.max(worldWidth * 0.3 + viewW, viewW * 2)
  {
    let x = 0
    let i = 0
    while (x < span) {
      const w = 30 + ((i * 37) % 50)
      const h = 60 + ((i * 53) % 120)
      sil.fillStyle(color, 0.55)
      sil.fillRect(x, worldHeight - h - 40, w, h + 40)
      sil.fillStyle(detail, 0.25)
      for (let wy = 0; wy < 3; wy++) {
        sil.fillRect(x + 6, worldHeight - h - 30 + wy * 24, 4, 4)
        sil.fillRect(x + w - 10, worldHeight - h - 18 + wy * 24, 4, 4)
      }
      // vereinzelt „bewohnte" Fenster (Akzentlicht statt grauem Punkt)
      if (i % 4 === 1) {
        sil.fillStyle(accent, 0.5)
        sil.fillRect(x + 6, worldHeight - h - 6, 4, 4)
      }
      x += w + 14 + ((i * 17) % 22)
      i += 1
    }
  }

  // --- Lichtkegel (optional, Faktor 0,8): weiche Beams, langsam atmend ---
  const shafts = scene.add.container(0, 0).setDepth(0)
  if (opts.lightShafts) {
    const shaftSpan = worldWidth * 0.2 + viewW
    const count = Math.max(3, Math.round(shaftSpan / 220))
    for (let i = 0; i < count; i++) {
      const sx = (shaftSpan / count) * i + 60 + ((i * 71) % 90)
      const beam = scene.add
        .image(sx, viewH * 0.34, 'fx-glow')
        .setBlendMode(Phaser.BlendModes.ADD)
        .setTint(accent)
        .setAlpha(0.05 + (i % 3) * 0.015)
        .setAngle(i % 2 === 0 ? 9 : -7)
      beam.setDisplaySize(46 + ((i * 23) % 30), viewH * 1.5)
      scene.tweens.add({
        targets: beam,
        alpha: 0.02,
        duration: 3800 + ((i * 997) % 2600),
        yoyo: true,
        repeat: -1,
        ease: 'Sine.easeInOut',
        delay: i * 700,
      })
      shafts.add(beam)
    }
  }

  // --- Parallax: Ebenen folgen der Kamera mit ihrem Faktor ---
  const onUpdate = (): void => {
    const wx = cam.worldView.x
    stars.x = wx * 0.9
    farSil.x = wx * 0.85
    shafts.x = wx * 0.8
    sil.x = wx * 0.75
  }
  scene.events.on(Phaser.Scenes.Events.UPDATE, onUpdate)
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, onUpdate)
  })
}
