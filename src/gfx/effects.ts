import Phaser from 'phaser'
import { addText } from './text'

// ---------------------------------------------------------------- Licht & Atmosphäre

export interface GlowOpts {
  alpha?: number
  pulse?: boolean
  depth?: number
}

/**
 * Weiches Punktlicht (ADD-Blend) hinter/über Objekten — der zentrale Baustein
 * des Licht-Looks. `radius` in Design-Pixeln; sanftes Pulsieren per Default.
 */
export function addGlow(
  scene: Phaser.Scene,
  x: number,
  y: number,
  color: number,
  radius: number,
  opts: GlowOpts = {},
): Phaser.GameObjects.Image {
  const alpha = opts.alpha ?? 0.3
  const img = scene.add
    .image(x, y, 'fx-glow')
    .setBlendMode(Phaser.BlendModes.ADD)
    .setTint(color)
    .setAlpha(alpha)
    .setDepth(opts.depth ?? 2)
  img.setDisplaySize(radius * 2, radius * 2)
  if (opts.pulse !== false) {
    scene.tweens.add({
      targets: img,
      alpha: alpha * 0.55,
      duration: 900 + Math.random() * 700,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    })
  }
  return img
}

/** Glow inkl. laufender Tweens entsorgen (z. B. beim Einsammeln). */
export function destroyGlow(scene: Phaser.Scene, glow?: Phaser.GameObjects.Image): void {
  if (!glow) return
  scene.tweens.killTweensOf(glow)
  glow.destroy()
}

/** Staubwölkchen an den Füßen: Landung & Laufschritte (Game-Feel, rein visuell). */
export function dustPuff(scene: Phaser.Scene, x: number, y: number, count = 3): void {
  for (let i = 0; i < count; i++) {
    const dust = scene.add
      .image(x + (Math.random() * 10 - 5), y - Math.random() * 2, 'fx-mote')
      .setDepth(9)
      .setTint(0xc9d2e4)
      .setAlpha(0.5 + Math.random() * 0.25)
      .setScale(0.4 + Math.random() * 0.4)
    scene.tweens.add({
      targets: dust,
      x: dust.x + (Math.random() * 16 - 8),
      y: dust.y - (2 + Math.random() * 6),
      alpha: 0,
      scale: dust.scale * 1.8,
      duration: 260 + Math.random() * 180,
      ease: 'Cubic.easeOut',
      onComplete: () => dust.destroy(),
    })
  }
}

/**
 * Tempo-Streifen für Tube-Level: dünne Lichtlinien ziehen nach links durchs
 * Bild und verkaufen die Tunnel-Geschwindigkeit. Screen-relativ umgesetzt
 * (folgen der Kamera), Wrap am linken Rand. Aufräumen übernimmt der Scene-Shutdown.
 */
export function addSpeedStreaks(scene: Phaser.Scene, color: number, count = 12): void {
  const cam = scene.cameras.main
  interface Streak {
    img: Phaser.GameObjects.Image
    ox: number
    oy: number
    speed: number
  }
  const streaks: Streak[] = []
  for (let i = 0; i < count; i++) {
    const img = scene.add
      .image(0, 0, 'fx-mote')
      .setBlendMode(Phaser.BlendModes.ADD)
      .setTint(i % 3 === 0 ? 0xffffff : color)
      .setAlpha(0.05 + Math.random() * 0.09)
      .setDepth(2)
    img.setScale(2.2 + Math.random() * 3.4, 0.1 + Math.random() * 0.08)
    streaks.push({
      img,
      ox: Math.random() * 800,
      oy: 24 + Math.random() * 250,
      speed: 120 + Math.random() * 160,
    })
  }
  const onUpdate = (_t: number, delta: number): void => {
    const view = cam.worldView
    if (view.width === 0) return
    for (const s of streaks) {
      s.ox -= (s.speed * delta) / 1000
      if (s.ox < -30) {
        s.ox = view.width + 20
        s.oy = 24 + Math.random() * (view.height - 60)
      }
      s.img.setPosition(view.x + s.ox, view.y + s.oy)
    }
  }
  scene.events.on(Phaser.Scenes.Events.UPDATE, onUpdate)
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, onUpdate)
  })
}

/** Vignette über den Bildrändern — billige Tiefe, Fokus auf die Mitte. */
export function addVignette(scene: Phaser.Scene, W: number, H: number, alpha = 0.85): Phaser.GameObjects.Image {
  const v = scene.add.image(W / 2, H / 2, 'fx-vignette').setDepth(900).setAlpha(alpha)
  v.setDisplaySize(W, H)
  return v
}

/**
 * Der Marken-Gag des Spiels: Ein Angreifer scheitert sichtbar an der TI —
 * roter Stempel + Comic-Sterne. Wird von jedem Deny-Moment wiederverwendet.
 * Barrierefreiheit: keine Blitzeffekte > 3 Hz (nur einmalige Pop-Animation).
 */
export function showDenyStamp(scene: Phaser.Scene, x: number, y: number, text: string): void {
  const label = addText(scene, 0, 0, text, 11, {
    color: '#ff4040',
    bg: '#fff0f0',
    padding: { x: 5, y: 3 },
  }).setOrigin(0.5)
  const container = scene.add.container(x, y, [label]).setDepth(70).setAngle(-12).setScale(0.2)

  const stars: Phaser.GameObjects.Text[] = []
  for (let i = 0; i < 4; i++) {
    const star = addText(scene, x, y, '✶', 11, { color: '#ffd75e' }).setOrigin(0.5).setDepth(69)
    stars.push(star)
    const angle = (i / 4) * Math.PI * 2 + 0.5
    scene.tweens.add({
      targets: star,
      x: x + Math.cos(angle) * 26,
      y: y + Math.sin(angle) * 18,
      alpha: 0,
      angle: 180,
      duration: 700,
      ease: 'Cubic.easeOut',
      onComplete: () => star.destroy(),
    })
  }

  scene.tweens.add({
    targets: container,
    scale: 1,
    duration: 220,
    ease: 'Back.easeOut',
  })
  scene.time.delayedCall(1500, () => {
    scene.tweens.add({ targets: container, alpha: 0, duration: 300, onComplete: () => container.destroy() })
  })
}

/** Datenbits spritzen weg (Sonic-Prinzip) — rein visuell, Zählung macht GameState. */
export function bitScatter(scene: Phaser.Scene, x: number, y: number, count: number): void {
  for (let i = 0; i < count; i++) {
    const bit = scene.add.image(x, y, 'datenbit').setDepth(65)
    const angle = Math.random() * Math.PI - Math.PI // nach oben fächern
    const dist = 20 + Math.random() * 30
    scene.tweens.add({
      targets: bit,
      x: x + Math.cos(angle) * dist,
      y: y + Math.sin(angle) * dist + 10,
      alpha: 0,
      duration: 600 + Math.random() * 300,
      ease: 'Cubic.easeOut',
      onComplete: () => bit.destroy(),
    })
  }
}

/** Kurzer Einsammel-Glitzer für Collectibles. */
export function collectSparkle(scene: Phaser.Scene, x: number, y: number): void {
  const spark = scene.add.image(x, y, 'datenbit').setDepth(65).setScale(1)
  scene.tweens.add({
    targets: spark,
    scale: 2.2,
    alpha: 0,
    duration: 250,
    onComplete: () => spark.destroy(),
  })
}

/**
 * Hitstop: die Physik friert für einen Wimpernschlag ein — verkauft Wucht
 * (Treffer, Signatur-Stempel), ohne das Bild zu rütteln. Passt zur
 * dokumentierten Anti-Shake-Entscheidung (Playtest: „rüttelt, mega nervig").
 * Tweens und Szenen-Timer laufen weiter — nur Körper stehen still.
 */
export function hitstop(scene: Phaser.Scene, dauerMs: number): void {
  const welt = scene.physics.world
  if (welt.isPaused) return // laufender Hitstop wird nicht verlängert
  welt.pause()
  scene.time.delayedCall(dauerMs, () => {
    if (welt.isPaused) welt.resume()
  })
}
