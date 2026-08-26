/**
 * TUBE-KAMERA — der Auto-Scroll darf den Spieler nicht ausbremsen.
 *
 * Anlass war eine Spielbeobachtung im KOV-Gateway: „Die Kamera muss sich besser
 * der Geschwindigkeit des Spielers anpassen, es kann nicht sein, dass der
 * Spieler auf die Kamera warten muss."
 *
 * Ursache: Paul läuft 130 px/s, der Tunnel scrollte mit 55 px/s, und die
 * GameScene klemmte den Spieler hart an die rechte Bildkante. Der Auto-Scroll
 * war als Obergrenze des Tempos gebaut — er gehört als Untergrenze gebaut.
 */
import { suite, test, assertEqual, assertTrue } from './harness'
import { naechsterTubeScroll, TUBE_FUEHRUNG } from '../../src/gfx/tubeKamera'

const VIEW_W = 640
const MAP_W = 1920
const SPEED = 55

/** Grundfall mit bequemen Vorgaben; einzelne Werte je Test überschreiben. */
const eingabe = (ueber: Partial<Parameters<typeof naechsterTubeScroll>[0]> = {}) =>
  naechsterTubeScroll({
    scrollX: 0,
    speed: SPEED,
    deltaMs: 16,
    playerX: 0,
    viewW: VIEW_W,
    mapWidth: MAP_W,
    held: false,
    ...ueber,
  })

export function run(): void {
  suite('Tube-Kamera — der Tunnel drängt', () => {
    test('ohne Spielerdruck rückt der Tunnel mit seinem Grundtempo vor', () => {
      // 55 px/s * 1000 ms = 55 px
      const next = eingabe({ deltaMs: 1000, playerX: 0 })
      assertEqual(Math.round(next), 55)
    })

    test('wer trödelt, wird trotzdem weitergeschoben', () => {
      const next = eingabe({ scrollX: 300, deltaMs: 1000, playerX: 310 })
      assertTrue(next > 300, 'der Tunnel bleibt nie stehen, nur weil der Spieler steht')
    })
  })

  suite('Tube-Kamera — der Spieler zieht mit', () => {
    test('läuft der Spieler vor, folgt die Kamera ihm statt ihn zu bremsen', () => {
      // Spieler bei 900 -> Kamera soll auf 900 - 320 = 580 nachziehen,
      // deutlich weiter als das Grundtempo (0 + ~0,9 px) erlaubt hätte.
      const next = eingabe({ scrollX: 0, deltaMs: 16, playerX: 900 })
      assertEqual(Math.round(next), Math.round(900 - VIEW_W * TUBE_FUEHRUNG))
    })

    test('das ist der eigentliche Fehler: schnell laufen darf die Kamera nicht abhängen', () => {
      // Eine Sekunde volles Tempo (130 px/s) gegen einen 55-px/s-Tunnel
      let scrollX = 0
      let playerX = 320 // startet in der Bildmitte
      for (let i = 0; i < 60; i++) {
        playerX += 130 / 60
        scrollX = naechsterTubeScroll({
          scrollX, speed: SPEED, deltaMs: 1000 / 60, playerX, viewW: VIEW_W, mapWidth: MAP_W, held: false,
        })
      }
      const abstandZurKante = scrollX + VIEW_W - playerX
      assertTrue(
        abstandZurKante > 100,
        `nach 1 s Vollgas darf der Spieler nicht an der Bildkante kleben (Abstand: ${Math.round(abstandZurKante)} px)`,
      )
    })

    test('der Spieler bleibt bei Führungsanteil im Bild stehen, nicht am Rand', () => {
      const playerX = 1000
      const next = eingabe({ scrollX: 0, playerX })
      const anteilImBild = (playerX - next) / VIEW_W
      assertEqual(Math.round(anteilImBild * 100) / 100, TUBE_FUEHRUNG)
    })
  })

  suite('Tube-Kamera — Grenzen', () => {
    test('die Kamera läuft nie rückwärts', () => {
      // Spieler rennt zurück nach links — der Tunnel darf nicht mitkommen
      const next = eingabe({ scrollX: 800, deltaMs: 0, playerX: 100 })
      assertEqual(next, 800, 'sonst kämen überwundene Hindernisse zurück ins Bild')
    })

    test('am Kartenende ist Schluss', () => {
      const next = eingabe({ scrollX: 1270, deltaMs: 1000, playerX: 1900 })
      assertEqual(next, MAP_W - VIEW_W)
    })

    test('eine schmale Karte scrollt gar nicht', () => {
      const next = eingabe({ scrollX: 0, deltaMs: 1000, playerX: 600, mapWidth: 400 })
      assertEqual(next, 0, 'mapWidth < viewW darf keinen negativen Scroll ergeben')
    })
  })

  suite('Tube-Kamera — Mechaniken halten den Tunnel an', () => {
    test('bei gehaltenem Scroll bleibt die Kamera stehen', () => {
      const next = eingabe({ scrollX: 500, deltaMs: 1000, playerX: 900, held: true })
      assertEqual(next, 500, 'das Podest prüft gerade — der Tunnel wartet, das ist Absicht')
    })

    test('auch ein vorlaufender Spieler zieht den gehaltenen Tunnel NICHT mit', () => {
      const next = eingabe({ scrollX: 500, deltaMs: 16, playerX: 1400, held: true })
      assertEqual(next, 500, 'sonst könnte man die Prüfung einfach weglaufen')
    })
  })
}
