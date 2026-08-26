import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { depthMix, fogColor } from './atmos'

export interface BackdropOpts {
  /** Weiche Lichtschächte von oben (digitale Level) — Stadt/Attract lassen das aus. */
  lightShafts?: boolean
  /** Schwebende Datenpartikel + Vordergrund-Bokeh (Default: an). */
  ambient?: boolean
}

/**
 * Hintergrund pro Level — atmosphärisch gestaffelt.
 *
 * Aufbau von hinten nach vorn: Farbverlauf, fernes Himmelslicht, drei
 * Silhouetten-Ebenen mit Türmen, zwei Nebelbänder dazwischen, Lichtschächte,
 * Schwebepartikel. Der eigentliche Effekt sind nicht die Türme, sondern die
 * NEBELBÄNDER und die Farbstaffelung: Jede Ebene weiter hinten wird per
 * `depthMix` in Richtung Horizontfarbe gezogen und verliert Kontrast.
 * Deshalb wirkt das Bild tief, obwohl jede Form eine simple Fläche ist.
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
  const fog = fogColor(theme)

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

  // --- „Daten-Kern": großes, ruhig atmendes Himmelslicht (Faktor 0,92) ---
  const core = scene.add.container(0, 0).setDepth(0)
  {
    const cx = viewW * 0.66
    const cy = viewH * 0.28
    const halo = scene.add
      .image(cx, cy, 'fx-glow')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(accent)
      .setAlpha(0.14)
    halo.setDisplaySize(viewH * 1.4, viewH * 1.4)
    const heart = scene.add
      .image(cx, cy, 'fx-glow')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(0xffffff)
      .setAlpha(0.16)
    heart.setDisplaySize(viewH * 0.55, viewH * 0.55)
    scene.tweens.add({
      targets: halo,
      alpha: 0.08,
      displayWidth: viewH * 1.55,
      displayHeight: viewH * 1.55,
      duration: 5200,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    })
    scene.tweens.add({ targets: heart, alpha: 0.09, duration: 3600, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' })
    core.add([halo, heart])
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

  /**
   * Eine Turm-Ebene. `dist` (0…1) ist die gefühlte Entfernung: Sie bestimmt
   * Farbe (Richtung Dunst), Deckkraft und ob überhaupt noch Fenster zu sehen
   * sind. Türme bekommen eine Spitze — eine Silhouette mit Dachkante liest
   * sich als Architektur, ein nacktes Rechteck als Klotz.
   */
  const towerLayer = (
    dist: number,
    baseHex: string,
    alpha: number,
    minW: number,
    maxW: number,
    minH: number,
    maxH: number,
    gap: number,
    seed: number,
    windows: boolean,
    span: number,
  ): Phaser.GameObjects.Graphics => {
    const layer = scene.add.graphics().setDepth(0)
    const body = depthMix(baseHex, fog, dist)
    const roof = depthMix(theme.detail, fog, Math.max(0, dist - 0.18))
    const lamp = depthMix(theme.accent, fog, dist * 0.55)
    const dark = depthMix(theme.skyTop, fog, dist)
    let x = -30
    let i = seed
    while (x < span) {
      const w = minW + ((i * 23) % Math.max(1, maxW - minW))
      const h = minH + ((i * 41) % Math.max(1, maxH - minH))
      const ty = worldHeight - 40 - h
      const spire = 8 + ((i * 13) % 16)
      layer.fillStyle(body, alpha)
      layer.fillRect(x, ty, w, h + 40)
      layer.fillTriangle(x - 2, ty + 1, x + w + 2, ty + 1, x + w / 2, ty - spire)
      layer.fillStyle(roof, alpha * 0.85)
      layer.fillRect(x - 3, ty, w + 6, 1.5)
      if (windows) {
        const cw = Math.max(2, Math.round(w * 0.13))
        for (let cy = ty + 14; cy < worldHeight - 46; cy += 15) {
          for (let k = 0; k < 2; k++) {
            const cx = Math.round(x + w * (0.28 + k * 0.44) - cw / 2)
            const lit = (i * 7 + cy * 3 + k) % 5 < 2
            layer.fillStyle(lit ? lamp : dark, lit ? alpha : alpha * 0.7)
            layer.fillRect(cx, cy + 2, cw, 5)
            layer.fillTriangle(cx, cy + 2, cx + cw, cy + 2, cx + cw / 2, cy - 1)
          }
        }
      }
      x += w + gap + ((i * 17) % 11)
      i += 1
    }
    return layer
  }

  /** Nebelband: nimmt einer Ebene den Kontrast und trennt sie von der nächsten. */
  const fogBand = (yTop: number, height: number, strength: number): Phaser.GameObjects.Graphics => {
    const band = scene.add.graphics().setDepth(0)
    const c = fog.color
    const width = Math.max(worldWidth, viewW) + viewW
    if (scene.game.renderer.type === Phaser.WEBGL) {
      band.fillGradientStyle(c, c, c, c, 0, 0, strength, strength)
      band.fillRect(-viewW / 2, yTop, width, height)
    } else {
      const STEPS = 10
      for (let s = 0; s < STEPS; s++) {
        band.fillStyle(c, (strength * s) / (STEPS - 1))
        band.fillRect(-viewW / 2, yTop + (height / STEPS) * s, width, height / STEPS + 1)
      }
    }
    return band
  }

  // --- Drei Turm-Ebenen mit Nebel dazwischen ---
  const farSil = towerLayer(0.72, theme.skyBottom, 0.55, 22, 40, 90, 170, 12, 2, false, worldWidth * 0.15 + viewW + 80)
  const fog1 = fogBand(worldHeight * 0.24, worldHeight * 0.62, 0.42)
  const midSil = towerLayer(0.45, theme.skyTop, 0.75, 32, 56, 110, 200, 16, 7, true, worldWidth * 0.25 + viewW + 80)
  const fog2 = fogBand(worldHeight * 0.42, worldHeight * 0.55, 0.3)
  const sil = towerLayer(0.18, theme.skyTop, 0.9, 42, 72, 130, 230, 20, 3, true, worldWidth * 0.3 + viewW + 80)

  // --- Lichtschächte (optional, Faktor 0,66): weiche Beams, langsam atmend ---
  const shafts = scene.add.container(0, 0).setDepth(0)
  if (opts.lightShafts) {
    const shaftSpan = worldWidth * 0.34 + viewW
    const count = Math.max(4, Math.round(shaftSpan / 190))
    for (let i = 0; i < count; i++) {
      const sx = (shaftSpan / count) * i + 60 + ((i * 71) % 90)
      const beam = scene.add
        .image(sx, viewH * 0.3, 'fx-glow')
        .setBlendMode(Phaser.BlendModes.ADD)
        .setTint(0xffffff)
        .setAlpha(0.05 + (i % 3) * 0.012)
        .setAngle(i % 2 === 0 ? 9 : -7)
      beam.setDisplaySize(52 + ((i * 23) % 34), viewH * 1.7)
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

  // --- Ambiente Datenpartikel: zwei Schwebe-Ebenen im Mittelgrund +
  //     wenige große Bokeh-Punkte VOR dem Spielfeld (Faktor negativ = näher
  //     als die Kamera-Ebene). Alles driftet langsam und schimmert asynchron. ---
  const midMotes = scene.add.container(0, 0).setDepth(2)
  const nearMotes = scene.add.container(0, 0).setDepth(2)
  const frontBokeh = scene.add.container(0, 0).setDepth(30)
  if (opts.ambient !== false) {
    const detailColor = Phaser.Display.Color.HexStringToColor(theme.detail).color
    const spawnMotes = (
      container: Phaser.GameObjects.Container,
      factor: number,
      count: number,
      scaleMin: number,
      scaleMax: number,
      alphaMax: number,
    ): void => {
      const span = worldWidth * (1 - factor) + viewW + 80
      for (let i = 0; i < count; i++) {
        const mote = scene.add
          .image(Math.random() * span, 20 + Math.random() * (worldHeight - 40), 'fx-mote')
          .setBlendMode(Phaser.BlendModes.ADD)
          .setTint(i % 4 === 0 ? accent : i % 4 === 1 ? detailColor : 0xffffff)
          .setScale(scaleMin + Math.random() * (scaleMax - scaleMin))
          .setAlpha(alphaMax * (0.35 + Math.random() * 0.65))
        // Langsame Schwebe-Drift (auf/ab + leicht seitlich) + Schimmern
        scene.tweens.add({
          targets: mote,
          y: mote.y - (8 + Math.random() * 18),
          x: mote.x + (Math.random() * 22 - 11),
          duration: 4200 + Math.random() * 4200,
          yoyo: true,
          repeat: -1,
          ease: 'Sine.easeInOut',
          delay: Math.random() * 3000,
        })
        scene.tweens.add({
          targets: mote,
          alpha: mote.alpha * 0.4,
          duration: 1400 + Math.random() * 2200,
          yoyo: true,
          repeat: -1,
          ease: 'Sine.easeInOut',
          delay: Math.random() * 2000,
        })
        container.add(mote)
      }
    }
    spawnMotes(midMotes, 0.6, Math.round(12 + worldWidth / 80), 0.22, 0.45, 0.55)
    spawnMotes(nearMotes, 0.35, Math.round(10 + worldWidth / 100), 0.35, 0.7, 0.45)
    // Vordergrund-Bokeh: groß, extrem transparent, zieht schneller vorbei
    spawnMotes(frontBokeh, -0.18, Math.max(4, Math.round(worldWidth / 260)), 1.6, 2.8, 0.09)
  }

  // --- Parallax: Ebenen folgen der Kamera mit ihrem Faktor ---
  const onUpdate = (): void => {
    const wx = cam.worldView.x
    core.x = wx * 0.92
    stars.x = wx * 0.9
    farSil.x = wx * 0.85
    fog1.x = wx * 0.82
    midSil.x = wx * 0.72
    fog2.x = wx * 0.6
    shafts.x = wx * 0.66
    sil.x = wx * 0.5
    midMotes.x = wx * 0.6
    nearMotes.x = wx * 0.35
    frontBokeh.x = wx * -0.18
  }
  scene.events.on(Phaser.Scenes.Events.UPDATE, onUpdate)
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, onUpdate)
  })
}
