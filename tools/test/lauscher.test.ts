/** Tests der Lauscher-Sichtlogik (src/mechanics/sicht.ts). */
import { suite, test, assertTrue, assertFalse, assertEqual, assertClose } from './harness'
import { imSichtkegel, sichtlinieFrei, wirdGesehen, patrouille, rectsOverlap } from '../../src/mechanics/sicht'
import type { Blick } from '../../src/mechanics/sicht'
import {
  LauscherLogik,
  HIT_COOLDOWN_MS,
  TIPP_AB_TREFFER,
  TIPP_COOLDOWN_MS,
} from '../../src/mechanics/lauscherLogik'

const blick = (over: Partial<Blick> = {}): Blick => ({
  x: 100,
  y: 100,
  dir: 1,
  reach: 120,
  spread: 24,
  ...over,
})

export function run(): void {
  suite('Sichtkegel', () => {
    test('sieht nach vorne, nicht nach hinten', () => {
      assertTrue(imSichtkegel(blick(), 180, 100), 'vor dem Auge')
      assertFalse(imSichtkegel(blick(), 20, 100), 'hinter dem Auge')
    })

    test('Blickrichtung links spiegelt den Kegel', () => {
      const b = blick({ dir: -1 })
      assertTrue(imSichtkegel(b, 20, 100))
      assertFalse(imSichtkegel(b, 180, 100))
    })

    test('endet an der Reichweite', () => {
      assertTrue(imSichtkegel(blick(), 219, 100))
      assertFalse(imSichtkegel(blick(), 221, 100), 'jenseits reach')
    })

    test('öffnet sich mit der Entfernung — Ducken hilft weiter weg', () => {
      assertTrue(imSichtkegel(blick(), 200, 119), 'knapp innerhalb')
      assertFalse(imSichtkegel(blick(), 200, 125), 'knapp darunter = ungesehen')
      assertFalse(imSichtkegel(blick(), 104, 115), 'nah dran und tief = nicht im Kegel')
    })
  })

  suite('Sichtlinie', () => {
    test('ohne Hindernis frei', () => {
      assertTrue(sichtlinieFrei(blick(), 200, 100, []))
    })

    test('eine Wand dazwischen blockt', () => {
      assertFalse(sichtlinieFrei(blick(), 200, 100, [{ x: 140, y: 60, w: 16, h: 80 }]))
    })

    test('Hindernis hinter dem Ziel blockt nicht', () => {
      assertTrue(sichtlinieFrei(blick(), 200, 100, [{ x: 240, y: 60, w: 16, h: 80 }]))
    })

    test('rectsOverlap erkennt Überdeckung und Trennung', () => {
      assertTrue(rectsOverlap({ x: 0, y: 0, w: 10, h: 10 }, { x: 5, y: 5, w: 10, h: 10 }))
      assertFalse(rectsOverlap({ x: 0, y: 0, w: 10, h: 10 }, { x: 20, y: 0, w: 10, h: 10 }))
    })
  })

  suite('wirdGesehen — die Kernlehre', () => {
    test('Klartext im Kegel wird gesehen', () => {
      assertTrue(wirdGesehen(blick(), { x: 180, y: 100, sichtbar: true }))
    })

    test('verschlüsselt bleibt unsichtbar, selbst direkt vor dem Auge', () => {
      assertFalse(wirdGesehen(blick(), { x: 110, y: 100, sichtbar: false }))
    })

    test('Hülle sticht Geometrie: unsichtbar schlägt Kegel UND Sichtlinie', () => {
      assertFalse(wirdGesehen(blick(), { x: 180, y: 100, sichtbar: false }, []))
    })

    test('Klartext hinter einer Wand bleibt ungesehen', () => {
      assertFalse(wirdGesehen(blick(), { x: 180, y: 100, sichtbar: true }, [{ x: 140, y: 60, w: 16, h: 80 }]))
    })
  })

  suite('Patrouille (deterministisch)', () => {
    test('startet am Anfangspunkt und läuft nach rechts', () => {
      const p = patrouille(0, 100, 200, 50)
      assertClose(p.x, 100, 1e-6)
      assertEqual(p.dir, 1)
    })

    test('erreicht das Ziel nach der Laufzeit', () => {
      assertClose(patrouille(2000, 100, 200, 50).x, 200, 1e-6)
    })

    test('pausiert am Ende (Spieler kann das Timing lernen)', () => {
      assertClose(patrouille(2300, 100, 200, 50, 600).x, 200, 1e-6, 'wartet am Wendepunkt')
    })

    test('kehrt um und blickt nach links', () => {
      const p = patrouille(2600 + 1000, 100, 200, 50, 600)
      assertEqual(p.dir, -1)
      assertClose(p.x, 150, 1e-6)
    })

    test('ist zyklisch — gleicher Zeitpunkt, gleiche Position', () => {
      const cycle = (2000 + 600) * 2
      const a = patrouille(1234, 100, 200, 50, 600)
      const b = patrouille(1234 + cycle * 3, 100, 200, 50, 600)
      assertClose(a.x, b.x, 1e-6)
      assertEqual(a.dir, b.dir)
    })

    test('negative Zeit stürzt nicht ab', () => {
      const p = patrouille(-500, 100, 200, 50, 600)
      assertTrue(p.x >= 100 && p.x <= 200)
    })

    test('entartete Strecke bleibt stehen', () => {
      assertClose(patrouille(999, 100, 100, 50).x, 100, 1e-6)
      assertClose(patrouille(999, 100, 200, 0).x, 100, 1e-6)
    })
  })

  suite('Lauscher — Treffer-Buchhaltung', () => {
    test('ungesehen löst nie einen Treffer aus', () => {
      const l = new LauscherLogik()
      assertFalse(l.pruefe(0, false))
      assertFalse(l.pruefe(99999, false))
      assertEqual(l.treffer, 0)
    })

    test('erster Treffer geht sofort durch', () => {
      assertTrue(new LauscherLogik().pruefe(0, true))
    })

    test('Abklingzeit verhindert Dauerschaden', () => {
      const l = new LauscherLogik()
      assertTrue(l.pruefe(1000, true))
      assertFalse(l.pruefe(1000 + HIT_COOLDOWN_MS - 1, true), 'zu früh')
      assertTrue(l.pruefe(1000 + HIT_COOLDOWN_MS, true), 'nach Ablauf wieder')
    })

    test('Treffer ohne Bitverlust zählen nicht (Unverwundbarkeit)', () => {
      const l = new LauscherLogik()
      l.pruefe(0, true)
      assertFalse(l.melde(0, 0), 'kein Tipp')
      assertEqual(l.treffer, 0, 'zählt nicht als Lernerfahrung')
    })

    test('erster echter Treffer gibt noch keinen Tipp (Spieler darf rätseln)', () => {
      const l = new LauscherLogik()
      l.pruefe(0, true)
      assertFalse(l.melde(0, 5))
      assertEqual(l.treffer, 1)
    })

    test(`ab dem ${TIPP_AB_TREFFER}. Treffer erklärt REZI die Hülle`, () => {
      const l = new LauscherLogik()
      l.pruefe(0, true)
      l.melde(0, 5)
      l.pruefe(HIT_COOLDOWN_MS, true)
      assertTrue(l.melde(HIT_COOLDOWN_MS, 5), 'jetzt muss der Tipp kommen')
      assertEqual(l.treffer, 2)
    })

    test('der Tipp wiederholt sich nicht sofort', () => {
      const l = new LauscherLogik()
      let t = 0
      l.pruefe(t, true); l.melde(t, 5)
      t += HIT_COOLDOWN_MS
      l.pruefe(t, true)
      assertTrue(l.melde(t, 5), 'erster Tipp')
      t += HIT_COOLDOWN_MS
      l.pruefe(t, true)
      assertFalse(l.melde(t, 5), 'Sperrfrist läuft noch')
      t += TIPP_COOLDOWN_MS
      l.pruefe(t, true)
      assertTrue(l.melde(t, 5), 'nach der Sperrfrist wieder')
    })

    test('reset stellt den Ausgangszustand her', () => {
      const l = new LauscherLogik()
      l.pruefe(0, true)
      l.melde(0, 5)
      l.reset()
      assertEqual(l.treffer, 0)
      assertTrue(l.pruefe(0, true), 'Abklingzeit ist zurückgesetzt')
    })

    test('Zusammenspiel: verschlüsselt laufen kostet nie Bits', () => {
      const l = new LauscherLogik()
      const auge: Blick = { x: 100, y: 100, dir: 1, reach: 120, spread: 24 }
      let treffer = 0
      // 60 Frames unsichtbar direkt vor dem Auge
      for (let f = 0; f < 60; f++) {
        const gesehen = wirdGesehen(auge, { x: 140, y: 100, sichtbar: false })
        if (l.pruefe(f * 16, gesehen)) treffer += 1
      }
      assertEqual(treffer, 0, 'die Hülle schützt zuverlässig')
    })

    test('Zusammenspiel: im Klartext trifft es genau im Takt der Abklingzeit', () => {
      const l = new LauscherLogik()
      const auge: Blick = { x: 100, y: 100, dir: 1, reach: 120, spread: 24 }
      let treffer = 0
      // 3 Sekunden bei 60 fps sichtbar im Kegel
      for (let f = 0; f < 180; f++) {
        const gesehen = wirdGesehen(auge, { x: 140, y: 100, sichtbar: true })
        if (l.pruefe(f * 16, gesehen)) treffer += 1
      }
      // 2880 ms / 900 ms -> 4 Treffer (erster bei t=0)
      assertEqual(treffer, 4, 'kein Dauerschaden, sondern getaktet')
    })
  })
}
