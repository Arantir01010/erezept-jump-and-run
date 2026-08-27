/**
 * Tests der Sprungkurve und Kanten-Korrektur (src/player/sprungphysik.ts) —
 * und die DECKUNGSPRÜFUNG: Die reale Flugbahn (inkl. asymmetrischem Fallen)
 * muss die Erreichbarkeits-Konstanten des Level-Compilers weiterhin tragen.
 * Diese Suite ist das Scharnier, das PlayerConfig und compile.ts synchron
 * hält — reißt es, ist entweder der Fall-Faktor zu groß oder eine
 * MAX_DX-Konstante zu optimistisch.
 */
import { suite, test, assertTrue, assertEqual } from './harness'
import { gravitationsFaktor, eckKorrektur, maxSprungweitePx } from '../../src/player/sprungphysik'
import { PLAYER_TUNING as T } from '../../src/player/PlayerConfig'
import { SLOWEST_SPEED_FACTOR } from '../../src/state/HuelleState'
import {
  MAX_RISE_TILES,
  MAX_DX_FOR_RISE,
  MAX_DX_DROP,
  MAX_DX_FOR_RISE_SLOW,
  MAX_DX_DROP_SLOW,
} from '../lib/compile'

const TILE = 16

/** Reale Weite in Kachelmitten (Kante-zu-Kante-px + 1 Kachel Mittenversatz). */
function weiteInKacheln(steigHoehePx: number, speed: number): number {
  return (
    maxSprungweitePx(steigHoehePx, speed, T.jumpVelocity, T.gravityY, T.fallGravityFactor, T.coyoteMs) / TILE + 1
  )
}

export function run(): void {
  suite('Sprungkurve — Gravitationsfaktor', () => {
    test('am Boden immer 1 (keine Modifikation)', () => {
      assertEqual(gravitationsFaktor(0, true, true, T), 1)
      assertEqual(gravitationsFaktor(0, false, true, T), 1)
    })

    test('Steigen mit gehaltener Taste = voller Sprung (Faktor 1)', () => {
      assertEqual(gravitationsFaktor(-300, true, false, T), 1)
    })

    test('Loslassen im Steigen kürzt den Sprung (variable Höhe)', () => {
      assertEqual(gravitationsFaktor(-300, false, false, T), T.lowJumpGravityFactor)
    })

    test('Scheitel-Schweben nur bei gehaltener Taste', () => {
      assertEqual(gravitationsFaktor(-20, true, false, T), T.apexGravityFactor)
      assertEqual(gravitationsFaktor(20, true, false, T), T.apexGravityFactor)
      assertEqual(gravitationsFaktor(-20, false, false, T), T.lowJumpGravityFactor)
    })

    test('Fallen ist schwerer als Steigen', () => {
      assertEqual(gravitationsFaktor(200, false, false, T), T.fallGravityFactor)
      assertEqual(gravitationsFaktor(200, true, false, T), T.fallGravityFactor)
      assertTrue(T.fallGravityFactor > 1, 'sonst ist die Mechanik wirkungslos')
    })
  })

  suite('Kanten-Korrektur', () => {
    test('linke Kopfecke knapp in der Kachel → nach rechts schieben', () => {
      // Kopf 13..23, Kachelkante bei 16 → 3 px Überlapp
      const schub = eckKorrektur(13, 23, TILE, true, false, 5)
      assertTrue(schub > 3 && schub <= 4, `erwartet ~3.5, war ${schub}`)
    })

    test('rechte Kopfecke knapp in der Kachel → nach links schieben', () => {
      // Kopf 9..19, Kachelkante bei 16 → 3 px Überlapp
      const schub = eckKorrektur(9, 19, TILE, false, true, 5)
      assertTrue(schub < -3 && schub >= -4, `erwartet ~-3.5, war ${schub}`)
    })

    test('zu tief in der Kachel → keine Korrektur (ehrlicher Bonk)', () => {
      assertEqual(eckKorrektur(6, 16, TILE, true, false, 5), 0) // 10 px Überlapp
    })

    test('beide Ecken gedeckt oder beide frei → keine Korrektur', () => {
      assertEqual(eckKorrektur(13, 23, TILE, true, true, 5), 0)
      assertEqual(eckKorrektur(13, 23, TILE, false, false, 5), 0)
    })
  })

  suite('Deckung: reale Flugbahn trägt die Compiler-Konstanten', () => {
    test('maximale Steighöhe bleibt 3 Kacheln', () => {
      assertEqual(MAX_RISE_TILES, 3)
    })

    test('MAX_DX_FOR_RISE ist bei jeder Steighöhe physikalisch gedeckt', () => {
      for (const [rise, dx] of Object.entries(MAX_DX_FOR_RISE)) {
        const real = weiteInKacheln(Number(rise) * TILE, T.runSpeed)
        assertTrue(real >= dx, `Steigung ${rise}: Konstante ${dx}, real nur ${real.toFixed(2)} Kacheln`)
      }
    })

    test('MAX_DX_DROP ist gedeckt (1-Kachel-Drop als knappster Fall)', () => {
      const real = weiteInKacheln(-TILE, T.runSpeed)
      assertTrue(real >= MAX_DX_DROP, `Konstante ${MAX_DX_DROP}, real nur ${real.toFixed(2)}`)
    })

    test('Hülle-Konstanten sind mit verschlüsseltem Tempo gedeckt', () => {
      const langsam = T.runSpeed * SLOWEST_SPEED_FACTOR
      for (const [rise, dx] of Object.entries(MAX_DX_FOR_RISE_SLOW)) {
        const real = weiteInKacheln(Number(rise) * TILE, langsam)
        assertTrue(real >= dx, `Hülle, Steigung ${rise}: Konstante ${dx}, real nur ${real.toFixed(2)}`)
      }
      assertTrue(weiteInKacheln(-TILE, langsam) >= MAX_DX_DROP_SLOW)
    })

    test('höher als der Scheitel ist unerreichbar (Formel-Grenzfall)', () => {
      assertEqual(maxSprungweitePx(999, T.runSpeed, T.jumpVelocity, T.gravityY, T.fallGravityFactor, T.coyoteMs), 0)
    })
  })
}
