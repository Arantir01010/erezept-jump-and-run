/** Tests des Zugriffsprotokolls und der Siegel (src/state/Protokoll.ts). */
import { suite, test, assertEqual, assertTrue, assertFalse } from './harness'
import { Protokoll, MAX_EINTRAEGE } from '../../src/state/Protokoll'

export function run(): void {
  suite('Protokoll — Einträge', () => {
    test('notiert Akteur, Aktion und Zeit', () => {
      const p = new Protokoll()
      p.note('01-x', 'Lauscher', 'hat geschaut', 1234)
      assertEqual(p.length, 1)
      const e = p.entries[0]
      assertEqual(e.akteur, 'Lauscher')
      assertEqual(e.aktion, 'hat geschaut')
      assertEqual(e.tMs, 1234)
    })

    test('Kiosk-Schutz: Protokoll wächst nicht unbegrenzt', () => {
      const p = new Protokoll()
      for (let i = 0; i < MAX_EINTRAEGE + 50; i++) p.note('01-x', 'a', `nr-${i}`, i)
      assertEqual(p.length, MAX_EINTRAEGE)
      assertEqual(p.entries[p.length - 1].aktion, `nr-${MAX_EINTRAEGE + 49}`, 'neueste bleiben')
    })

    test('reset leert alles', () => {
      const p = new Protokoll()
      p.markGesehen('01-x', 0)
      p.markAbgeschlossen('01-x', 1)
      p.reset()
      assertEqual(p.length, 0)
      assertFalse(p.wasGesehen('01-x'))
      assertTrue(p.lueckenlosGesamt)
    })
  })

  suite('Protokoll — Siegel', () => {
    test('drei Siegel sind unabhängig erreichbar (kein Alles-oder-nichts)', () => {
      const p = new Protokoll()
      p.markAbgeschlossen('01-x', 10)
      const s = p.siegel('01-x', { bits: 2, bitsRequired: 3 })
      assertTrue(s.durchgespielt)
      assertFalse(s.allePruefsummen, 'Sammelziel nicht erfüllt')
      assertTrue(s.lueckenlosesProtokoll, 'trotzdem unbeobachtet')
    })

    test('gesehen → kein lückenloses Protokoll', () => {
      const p = new Protokoll()
      p.markGesehen('01-x', 5)
      p.markAbgeschlossen('01-x', 10)
      const s = p.siegel('01-x', { bits: 3, bitsRequired: 3 })
      assertTrue(s.allePruefsummen)
      assertFalse(s.lueckenlosesProtokoll)
      assertFalse(p.lueckenlosGesamt)
    })

    test('nicht beendet → kein lückenloses Protokoll (nicht „geschenkt")', () => {
      const p = new Protokoll()
      const s = p.siegel('01-x', { bits: 3, bitsRequired: 3 })
      assertFalse(s.durchgespielt)
      assertFalse(s.lueckenlosesProtokoll)
    })

    test('countRequired 0 gibt kein Prüfsummen-Siegel', () => {
      const p = new Protokoll()
      p.markAbgeschlossen('01-x', 1)
      assertFalse(p.siegel('01-x', { bits: 0, bitsRequired: 0 }).allePruefsummen)
    })

    test('Siegel werden pro Level getrennt geführt', () => {
      const p = new Protokoll()
      p.markGesehen('01-a', 1)
      p.markAbgeschlossen('01-a', 2)
      p.markAbgeschlossen('02-b', 3)
      assertFalse(p.siegel('01-a', { bits: 0, bitsRequired: 0 }).lueckenlosesProtokoll)
      assertTrue(p.siegel('02-b', { bits: 0, bitsRequired: 0 }).lueckenlosesProtokoll)
    })

    test('zaehle summiert korrekt', () => {
      const p = new Protokoll()
      p.markAbgeschlossen('01-a', 1)
      p.markAbgeschlossen('02-b', 2)
      p.markGesehen('02-b', 3)
      const s = [
        p.siegel('01-a', { bits: 5, bitsRequired: 3 }),
        p.siegel('02-b', { bits: 1, bitsRequired: 3 }),
      ]
      assertEqual(Protokoll.zaehle(s), 4, '3 + 1')
    })
  })
}
