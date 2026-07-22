import Phaser from 'phaser'

/**
 * Der Marken-Gag des Spiels: Ein Angreifer scheitert sichtbar an der TI —
 * roter Stempel + Comic-Sterne. Wird von jedem Deny-Moment wiederverwendet.
 * Barrierefreiheit: keine Blitzeffekte > 3 Hz (nur einmalige Pop-Animation).
 */
export function showDenyStamp(scene: Phaser.Scene, x: number, y: number, text: string): void {
  const label = scene.add
    .text(0, 0, text, {
      fontFamily: 'Courier New, monospace',
      fontSize: '10px',
      fontStyle: 'bold',
      color: '#ff4040',
      backgroundColor: '#fff0f0',
      padding: { x: 4, y: 2 },
    })
    .setResolution(3)
    .setOrigin(0.5)
  const container = scene.add.container(x, y, [label]).setDepth(70).setAngle(-12).setScale(0.2)

  const stars: Phaser.GameObjects.Text[] = []
  for (let i = 0; i < 4; i++) {
    const star = scene.add
      .text(x, y, '✶', { fontFamily: 'monospace', fontSize: '10px', color: '#ffd75e' })
      .setResolution(3)
      .setOrigin(0.5)
      .setDepth(69)
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
