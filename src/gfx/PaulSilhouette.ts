import Phaser from 'phaser'
import type { Theme } from '../level/schema'
import { darken } from './atmos'

/**
 * PAUL ALS SILHOUETTE — mit echter Beinmechanik.
 *
 * Gezeichnet wird nicht die Pixel-Textur, sondern eine Vektorfigur: dunkle
 * Masse, Randlicht auf der Seite, aus der REZI leuchtet, zwei kalte Augen.
 * Bei Kamera-Zoom 3 bleibt das scharf, weil Formen pro Frame in die
 * Kameramatrix gerechnet werden — es gibt keine Quellpixel.
 *
 * Die Bewegung kommt NICHT aus den vier Lauf-Frames der Pixel-Animation,
 * sondern aus zwei Größen, die das Spiel ohnehin führt: Geschwindigkeit und
 * Bodenkontakt.
 *
 *  - Die Laufphase wird über die zurückgelegte STRECKE fortgeschrieben, nicht
 *    über die Zeit. Dadurch bleiben die Füße am Boden kleben, statt zu
 *    schlittern — auch beim Anlaufen, beim Bremsen und mit der Hülle
 *    (verschlüsselt läuft Paul 20 % langsamer, die Schritte werden von selbst
 *    seltener).
 *  - Knie und Ellbogen entstehen aus Zwei-Knochen-IK: Der Fuß bekommt eine
 *    Zielposition auf der Schrittbahn, das Knie ergibt sich daraus. Deshalb
 *    knickt das Bein beim Schwingen ein und streckt sich beim Aufsetzen.
 *  - In der Luft blendet die Pose über die Vertikalgeschwindigkeit: angezogene
 *    Beine im Steigen, gestreckte im Fallen, Arme entsprechend.
 *
 * Die Physik-Sprite bleibt vollständig erhalten und wird nur unsichtbar
 * geschaltet. Hitbox, Duck-Umschaltung, Coyote-Time, Squash & Stretch,
 * Treffer-Blinken und die Hülle-Tönung laufen unverändert weiter.
 */

/** Maße in Design-Pixeln, ausgerichtet an PLAYER_TUNING (Körper 10 × 21). */
// Exportiert: Wer Paul außerhalb der Physik positioniert (z. B. der
// Probelauf-Screen), braucht den Fußlinien-Versatz, um ihn sauber auf
// einem Podest stehen zu lassen — sonst nur per Augenmaß zu treffen.
export const FY = 11 // Fußlinie, relativ zum Sprite-Mittelpunkt
const TORSO_W = 7.4
const HEAD_W = 7
const HUEFTE_Y = FY - 9
const SCHULTER_Y = FY - 15
const KOPF_TOP = FY - 21.5

const OBERSCHENKEL = 4.7
const UNTERSCHENKEL = 4.7
const OBERARM = 3.6
const UNTERARM = 3.4

/** Wegstrecke für einen vollen Schrittzyklus (zwei Schritte), in Design-Pixeln. */
const SCHRITTZYKLUS = 34
/** Waagerechte Schrittweite eines Fußes um die Hüfte herum. */
const SCHRITTWEITE = 5.4
/** Wie hoch der Fuß in der Schwungphase abhebt. */
const FUSS_HUB = 4.4

type Pose = 'idle' | 'run' | 'jump' | 'fall' | 'duck' | 'hurt'

function poseAus(sprite: Phaser.GameObjects.Sprite): Pose {
  const key = sprite.anims?.currentAnim?.key ?? 'player-idle'
  if (key.endsWith('run')) return 'run'
  if (key.endsWith('jump')) return 'jump'
  if (key.endsWith('fall')) return 'fall'
  if (key.endsWith('duck')) return 'duck'
  if (key.endsWith('hurt')) return 'hurt'
  return 'idle'
}

interface Punkt {
  x: number
  y: number
}

/**
 * Zwei-Knochen-IK: Wo liegt das Gelenk, wenn Hüfte und Fuß feststehen?
 * `beuge` = +1 knickt nach vorn (Knie), −1 nach hinten (Ellbogen).
 */
function gelenk(a: Punkt, b: Punkt, l1: number, l2: number, beuge: number): Punkt {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let d = Math.hypot(dx, dy)
  const max = l1 + l2 - 0.02
  if (d > max) {
    // Ziel außer Reichweite: heranziehen, sonst wird die Wurzel unten negativ
    dx = (dx / d) * max
    dy = (dy / d) * max
    d = max
  }
  if (d < 0.01) return { x: a.x, y: a.y + l1 }
  const t = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
  const h = Math.sqrt(Math.max(0, l1 * l1 - t * t))
  const mx = a.x + (dx * t) / d
  const my = a.y + (dy * t) / d
  return { x: mx + (beuge * -dy * h) / d, y: my + (beuge * dx * h) / d }
}

export interface SilhouetteOpts {
  /** Lichtquelle (meist REZI). Bestimmt, auf welcher Seite das Randlicht sitzt. */
  light?: Phaser.GameObjects.Components.Transform
  /** Falls keine Lichtquelle: feste Seite (1 = rechts, -1 = links). */
  lightSide?: number
  /** Farbe des Randlichts. Default: theme.detail. */
  rim?: number
}

interface ArcadeArtig {
  body?: { velocity?: { x: number; y: number }; blocked?: { down: boolean } }
}

export function silhouettePaul(
  scene: Phaser.Scene,
  sprite: Phaser.GameObjects.Sprite,
  theme: Theme,
  opts: SilhouetteOpts = {},
): () => void {
  sprite.setVisible(false)

  const koerper = darken(theme.skyTop, 0.12)
  const rimFarbe = opts.rim ?? Phaser.Display.Color.HexStringToColor(theme.detail).color
  const augen = 0xdff4ff

  const g = scene.add.graphics().setDepth(sprite.depth)

  let phase = 0 // Laufphase in Umdrehungen (0…1)
  let letzteX = sprite.x
  let letzteY = sprite.y
  let vxGlatt = 0
  let vyGlatt = 0

  /** Ein Glied als gedrehtes Rundrechteck — Kappen entstehen aus dem Radius. */
  const glied = (a: Punkt, b: Punkt, dicke: number): void => {
    const laenge = Math.hypot(b.x - a.x, b.y - a.y)
    if (laenge < 0.05) return
    g.save()
    g.translateCanvas(a.x, a.y)
    g.rotateCanvas(Math.atan2(b.y - a.y, b.x - a.x))
    g.fillRoundedRect(0, -dicke / 2, laenge, dicke, dicke / 2)
    g.restore()
  }

  const zeichne = (dtMs: number): void => {
    const pose = poseAus(sprite)
    g.clear()

    // --- Bewegungsdaten: bevorzugt aus der Physik, sonst aus dem Weg ---
    const body = (sprite as unknown as ArcadeArtig).body
    const dt = Math.max(1, dtMs) / 1000
    let vx: number
    let vy: number
    if (body?.velocity) {
      vx = body.velocity.x
      vy = body.velocity.y
    } else {
      vx = (sprite.x - letzteX) / dt
      vy = (sprite.y - letzteY) / dt
    }
    letzteX = sprite.x
    letzteY = sprite.y
    // Glätten: rohe Arcade-Werte springen beim Wenden hart
    vxGlatt += (vx - vxGlatt) * Math.min(1, dt * 14)
    vyGlatt += (vy - vyGlatt) * Math.min(1, dt * 14)

    // --- Laufphase über die STRECKE, nicht über die Zeit ---
    // Genau das verhindert schlitternde Füße.
    if (pose === 'run') phase += (Math.abs(vx) * dt) / SCHRITTZYKLUS
    else if (pose === 'idle' || pose === 'duck') phase += dt * 0.28 // ruhiges Atmen
    phase %= 1
    const th = phase * Math.PI * 2

    // Randlicht-Seite in LOKALEN Koordinaten (Container wird bei flipX gespiegelt)
    let seite = opts.lightSide ?? 1
    if (opts.light) seite = opts.light.x >= sprite.x ? 1 : -1
    if (sprite.flipX) seite = -seite

    const duck = pose === 'duck'
    const stauch = duck ? 0.62 : 1
    // Tempo 0…1 — steuert Schrittweite, Neigung und Armschwung
    const tempo = Phaser.Math.Clamp(Math.abs(vxGlatt) / 130, 0, 1)

    // --- Rumpfversatz: Wippen, Neigung, Luftpose ---
    let bob = 0
    let neigung = 0
    if (pose === 'run') {
      // Doppelte Schrittfrequenz: tiefster Punkt beim Aufsetzen
      // Tiefster Punkt beim Aufsetzen, höchster in der Flugphase — der
      // Unterschied zwischen Gehen und Rennen steckt genau hier.
      bob = -Math.abs(Math.sin(th)) * 0.95 * tempo
      neigung = 0.2 * tempo
    } else if (pose === 'idle') {
      bob = Math.sin(th) * 0.22
    } else if (pose === 'jump' || pose === 'fall') {
      neigung = 0.09 * Math.sign(vxGlatt || 1) * (sprite.flipX ? -1 : 1) * tempo
    } else if (pose === 'hurt') {
      neigung = -0.22
    }

    const hueft: Punkt = { x: 0, y: HUEFTE_Y * stauch + bob }
    const schulterY = SCHULTER_Y * stauch + bob
    const kopfTop = KOPF_TOP * stauch + bob * 0.55 // Kopf wippt weniger — wirkt ruhiger
    const kopfBot = schulterY + 0.8

    // --- Fußziele bestimmen ---
    const fussZiel = (versatz: number): Punkt => {
      if (pose === 'run') {
        const a = th + versatz
        const schwung = Math.sin(a) // > 0 = Schwungphase (Fuß in der Luft)
        return {
          x: Math.cos(a) * SCHRITTWEITE * tempo,
          y: FY - Math.max(0, schwung) * FUSS_HUB * tempo,
        }
      }
      if (pose === 'jump') {
        // Steigen: vorderes Knie hoch nach vorn, hinteres Bein zieht nach
        const t = Phaser.Math.Clamp(-vyGlatt / 335, 0, 1)
        if (versatz === 0) return { x: 2.4 + 2.0 * t, y: FY - 6.0 * t }
        return { x: -1.0 - 1.6 * t, y: FY - 2.6 * t }
      }
      if (pose === 'fall') {
        // Fallen: vorderes Bein sucht den Boden, hinteres bleibt zurück
        const t = Phaser.Math.Clamp(vyGlatt / 320, 0, 1)
        if (versatz === 0) return { x: 1.6 + 1.8 * t, y: FY + 0.6 * t }
        return { x: -2.2 - 1.6 * t, y: FY - 1.4 + 1.0 * t }
      }
      if (duck) {
        const s = versatz === 0 ? 1 : -1
        return { x: s * 2.2, y: FY }
      }
      const s = versatz === 0 ? 1 : -1
      return { x: s * 1.4, y: FY }
    }

    const fussA = fussZiel(0)
    const fussB = fussZiel(Math.PI)
    const hueftA: Punkt = { x: hueft.x + 1.3, y: hueft.y }
    const hueftB: Punkt = { x: hueft.x - 1.3, y: hueft.y }
    const knieA = gelenk(hueftA, fussA, OBERSCHENKEL, UNTERSCHENKEL, 1)
    const knieB = gelenk(hueftB, fussB, OBERSCHENKEL, UNTERSCHENKEL, 1)

    // --- Handziele: gegenläufig zu den Beinen ---
    const handZiel = (versatz: number): Punkt => {
      const ruhe = { x: versatz === 0 ? 1.2 : -1.2, y: schulterY + 6.4 }
      if (pose === 'run') {
        // Angewinkelt und kräftig schwingend — hängende Arme lesen sich als Gehen
        const a = th + versatz + Math.PI // gegenläufig zu den Beinen
        return {
          x: Math.cos(a) * 3.8 * tempo + 0.5,
          y: schulterY + 3.6 - Math.sin(a) * 1.6 * tempo,
        }
      }
      if (pose === 'jump') {
        const t = Phaser.Math.Clamp(-vyGlatt / 335, 0, 1)
        if (versatz === 0) return { x: 2.6 + 1.0 * t, y: schulterY + 5.2 - 6.6 * t }
        return { x: -2.2 - 1.6 * t, y: schulterY + 5.6 - 1.2 * t }
      }
      if (pose === 'fall') {
        const t = Phaser.Math.Clamp(vyGlatt / 320, 0, 1)
        if (versatz === 0) return { x: 2.2 + 0.8 * t, y: schulterY + 4.6 - 4.6 * t }
        return { x: -2.6 - 1.0 * t, y: schulterY + 4.8 - 3.8 * t }
      }
      if (pose === 'hurt') return { x: ruhe.x - 1.8, y: schulterY + 2.6 }
      return { x: ruhe.x, y: ruhe.y + Math.sin(th) * 0.2 }
    }
    const handA = handZiel(0)
    const handB = handZiel(Math.PI)
    const schulterA: Punkt = { x: TORSO_W / 2 - 0.6, y: schulterY + 1.4 }
    const schulterB: Punkt = { x: -TORSO_W / 2 + 0.6, y: schulterY + 1.4 }
    const ellA = gelenk(schulterA, handA, OBERARM, UNTERARM, -1)
    const ellB = gelenk(schulterB, handB, OBERARM, UNTERARM, -1)

    // ---------------------------------------------------------------- zeichnen
    // Kontaktschatten zuerst: Er liegt auf dem Boden und darf die Neigung des
    // Körpers nicht mitmachen.
    if (pose === 'idle' || pose === 'run' || pose === 'duck') {
      const breite = 9.5 - Math.abs(Math.cos(th)) * 1.2 * (pose === 'run' ? tempo : 0)
      g.fillStyle(0x000000, 0.22)
      g.fillEllipse(0, FY + 0.4, breite, 2.2)
    }

    g.save()
    if (neigung !== 0) {
      // Um die Hüfte neigen, nicht um den Sprite-Mittelpunkt
      g.translateCanvas(0, hueft.y)
      g.rotateCanvas(neigung)
      g.translateCanvas(0, -hueft.y)
    }

    // Hinteres Bein + hinterer Arm zuerst (leicht dunkler = Tiefe)
    g.fillStyle(darken(theme.skyTop, 0.35), 1)
    glied(hueftB, knieB, 2.5)
    glied(knieB, fussB, 2.2)
    glied(schulterB, ellB, 1.7)
    glied(ellB, handB, 1.5)

    // Rumpf
    g.fillStyle(koerper, 1)
    g.fillRoundedRect(-TORSO_W / 2, schulterY, TORSO_W, hueft.y - schulterY + 0.5, 2.6)

    // Vorderes Bein
    glied(hueftA, knieA, 2.6)
    glied(knieA, fussA, 2.3)
    // Schuhe
    g.fillStyle(0x000000, 0.4)
    g.fillRoundedRect(fussA.x - 1.7, fussA.y - 1.6, 3.3, 1.6, 0.7)
    g.fillStyle(darken(theme.skyTop, 0.35), 1)
    g.fillRoundedRect(fussB.x - 1.7, fussB.y - 1.6, 3.3, 1.6, 0.7)

    // Kopf
    g.fillStyle(koerper, 1)
    g.fillRoundedRect(-HEAD_W / 2, kopfTop, HEAD_W, kopfBot - kopfTop + 0.4, 2.9)

    // Vorderer Arm zuletzt (liegt vor dem Rumpf)
    glied(schulterA, ellA, 1.8)
    glied(ellA, handA, 1.6)

    // --- Streiflicht über das äußere Drittel: verbindet Kante und Masse ---
    g.fillStyle(rimFarbe, 0.1)
    const wash = (breite: number, y: number, h: number, r: number): void => {
      const w = breite * 0.34
      g.fillRoundedRect(seite > 0 ? breite / 2 - w : -breite / 2, y, w, h, r)
    }
    wash(HEAD_W, kopfTop + 0.6, kopfBot - kopfTop - 0.6, 1.2)
    wash(TORSO_W, schulterY + 0.5, hueft.y - schulterY - 0.3, 1.2)

    // --- Randlicht: Kante auf der Lichtseite ---
    const rimA = pose === 'hurt' ? 0.5 : 0.95
    g.fillStyle(rimFarbe, rimA)
    const kante = (breite: number, y: number, h: number, dicke = 0.8): void => {
      g.fillRoundedRect(seite > 0 ? breite / 2 - dicke : -breite / 2, y, dicke, h, dicke / 2)
    }
    kante(HEAD_W, kopfTop + 0.8, kopfBot - kopfTop - 0.8)
    kante(TORSO_W, schulterY + 0.6, hueft.y - schulterY - 0.4)
    // Gliedmaßen bekommen ihr Randlicht als dünnes, seitlich versetztes Glied
    g.fillStyle(rimFarbe, rimA * 0.6)
    const rimGlied = (a: Punkt, b: Punkt, dicke: number): void => {
      const o = seite * (dicke / 2 - 0.28)
      glied({ x: a.x + o, y: a.y }, { x: b.x + o, y: b.y }, 0.55)
    }
    rimGlied(hueftA, knieA, 2.6)
    rimGlied(knieA, fussA, 2.3)
    rimGlied(schulterA, ellA, 1.8)
    rimGlied(ellA, handA, 1.6)

    // --- Himmelslicht: zarte Oberkante auf Kopf und Schultern ---
    g.fillStyle(0xffffff, 0.14)
    g.fillRoundedRect(-HEAD_W / 2 + 0.9, kopfTop + 0.35, HEAD_W - 1.8, 0.7, 0.35)
    g.fillRoundedRect(-TORSO_W / 2 + 1.2, schulterY + 0.3, TORSO_W - 2.4, 0.6, 0.3)

    // --- Augen: zwei kalte Punkte. Sie machen aus der Masse eine Figur. ---
    if (pose !== 'hurt') {
      const ey = kopfTop + (kopfBot - kopfTop) * 0.46
      g.fillStyle(augen, 0.95)
      g.fillCircle(-1.45, ey, 0.55)
      g.fillCircle(1.45, ey, 0.55)
    } else {
      const ey = kopfTop + (kopfBot - kopfTop) * 0.5
      g.fillStyle(0xff9a7a, 0.9)
      g.fillRect(-2.2, ey, 1.5, 0.6)
      g.fillRect(0.7, ey, 1.5, 0.6)
    }

    // --- Hülle-Zustand: die Sprite-Tönung wird als Kontur gespiegelt ---
    if (sprite.isTinted) {
      g.lineStyle(0.7, sprite.tintTopLeft, 0.85)
      g.strokeRoundedRect(-HEAD_W / 2, kopfTop, HEAD_W, kopfBot - kopfTop + 0.4, 2.9)
      g.strokeRoundedRect(-TORSO_W / 2, schulterY, TORSO_W, hueft.y - schulterY + 0.5, 2.6)
    }

    g.restore()
  }

  const folge = (): void => {
    g.setPosition(sprite.x, sprite.y)
    g.setScale((sprite.flipX ? -1 : 1) * sprite.scaleX, sprite.scaleY)
    g.setAlpha(sprite.alpha)
    g.setDepth(sprite.depth)
    zeichne(scene.game.loop.delta)
  }

  scene.events.on(Phaser.Scenes.Events.UPDATE, folge)
  const aufraeumen = (): void => {
    scene.events.off(Phaser.Scenes.Events.UPDATE, folge)
    g.destroy()
  }
  scene.events.once(Phaser.Scenes.Events.SHUTDOWN, aufraeumen)
  folge()
  return aufraeumen
}
