/** Tests der Kernmechanik „Hülle" (src/state/HuelleState.ts). */
import { suite, test, assertEqual, assertTrue, assertFalse, assertClose, assertDeepEqual } from './harness'
import {
  HuelleState,
  Huelle,
  HUELLE_TUNING,
  HUELLE_STATES,
  SLOWEST_SPEED_FACTOR,
  type HuelleChange,
} from '../../src/state/HuelleState'

export function run(): void {
  suite('Hülle — Grundzustände', () => {
    test('startet im Klartext: schnell, sichtbar, andockfähig', () => {
      const h = new HuelleState()
      assertEqual(h.state, Huelle.Klartext)
      assertEqual(h.speedFactor, 1)
      assertTrue(h.sichtbar, 'Klartext muss sichtbar sein')
      assertTrue(h.andockfaehig, 'Klartext muss andocken können')
    })

    test('jeder Zustand hat eine eigene Wirkungs-Signatur (Ikaruga-Lehre)', () => {
      const sig = (s: Huelle): string => {
        const e = HUELLE_TUNING[s]
        return `${e.speedFactor}|${e.sichtbar}|${e.andockfaehig}`
      }
      const seen = new Set(HUELLE_STATES.map(sig))
      assertEqual(seen.size, HUELLE_STATES.length, 'Zustände müssen unterscheidbar sein')
    })

    test('Verschlüsselt: langsamer, unsichtbar, NICHT andockfähig (Zielkonflikt)', () => {
      const e = HUELLE_TUNING[Huelle.Verschluesselt]
      assertTrue(e.speedFactor < 1, 'muss langsamer sein als Klartext')
      assertFalse(e.sichtbar)
      assertFalse(e.andockfaehig)
    })

    test('VAU: Klartext-Tempo UND unsichtbar UND andockfähig (kein Tunnel!)', () => {
      const vau = HUELLE_TUNING[Huelle.Vau]
      const klar = HUELLE_TUNING[Huelle.Klartext]
      assertEqual(vau.speedFactor, klar.speedFactor, 'in der VAU arbeitet man wie im Klartext')
      assertFalse(vau.sichtbar, 'Betreiber sieht in der VAU nichts')
      assertTrue(vau.andockfaehig)
    })

    test('SLOWEST_SPEED_FACTOR passt zum Tuning (Level-Validierung hängt daran)', () => {
      const min = Math.min(...HUELLE_STATES.map((s) => HUELLE_TUNING[s].speedFactor))
      assertEqual(SLOWEST_SPEED_FACTOR, min)
      assertTrue(SLOWEST_SPEED_FACTOR > 0, 'kein Zustand darf Bewegung unmöglich machen')
    })
  })

  suite('Hülle — Umschalten', () => {
    test('Toggle wechselt Klartext ⇄ Verschlüsselt', () => {
      const h = new HuelleState(0)
      assertTrue(h.toggle(0).ok)
      assertEqual(h.state, Huelle.Verschluesselt)
      assertTrue(h.toggle(1).ok)
      assertEqual(h.state, Huelle.Klartext)
    })

    test('Cooldown verhindert Arcade-Prellen', () => {
      const h = new HuelleState(150)
      h.reset(Huelle.Klartext, 1000)
      assertTrue(h.toggle(1000).ok, 'erster Wechsel direkt erlaubt')
      const blocked = h.toggle(1050)
      assertFalse(blocked.ok)
      assertEqual(blocked.blocked, 'cooldown')
      assertEqual(h.state, Huelle.Verschluesselt, 'Zustand bleibt bei blockiertem Toggle')
      assertTrue(h.toggle(1150).ok, 'nach Ablauf wieder erlaubt')
    })

    test('gesperrt (Setpiece): Toggle wirkungslos, Grund wird gemeldet', () => {
      const h = new HuelleState(0)
      h.locked = true
      const r = h.toggle(0)
      assertFalse(r.ok)
      assertEqual(r.blocked, 'locked')
      assertEqual(h.state, Huelle.Klartext)
    })

    test('canToggle spiegelt Cooldown, Sperre und VAU', () => {
      const h = new HuelleState(100)
      h.reset(Huelle.Klartext, 0)
      assertTrue(h.canToggle(0))
      h.toggle(0)
      assertFalse(h.canToggle(50), 'Cooldown')
      assertTrue(h.canToggle(100))
      h.enterVau(100)
      assertFalse(h.canToggle(500), 'in der VAU nicht umschaltbar')
    })
  })

  suite('Hülle — VAU', () => {
    test('Betreten überschreibt die Hülle, Verlassen stellt sie wieder her', () => {
      const h = new HuelleState(0)
      h.toggle(0)
      assertTrue(h.enterVau(10))
      assertEqual(h.state, Huelle.Vau)
      assertTrue(h.leaveVau(20))
      assertEqual(h.state, Huelle.Verschluesselt, 'alte Hülle kommt zurück')
    })

    test('Toggle in der VAU ist wirkungslos (Grund: vau)', () => {
      const h = new HuelleState(0)
      h.enterVau(0)
      const r = h.toggle(1)
      assertFalse(r.ok)
      assertEqual(r.blocked, 'vau')
      assertEqual(h.state, Huelle.Vau)
    })

    test('ohne TTL läuft die Sitzung nie ab', () => {
      const h = new HuelleState(0)
      h.enterVau(0, 0)
      assertFalse(h.vauExpires)
      h.tick(60_000)
      assertEqual(h.state, Huelle.Vau, 'Level 14: VAU ohne Ablauf')
      assertEqual(h.vauRatio, 1)
    })

    test('mit TTL: Ablauf wirft in den KLARTEXT zurück (sichtbar!)', () => {
      const h = new HuelleState(0)
      h.toggle(0)
      h.enterVau(0, 1000)
      assertTrue(h.vauExpires)
      h.tick(400)
      assertClose(h.vauRatio, 0.6, 1e-9)
      h.tick(600)
      assertEqual(h.state, Huelle.Klartext, 'Kontextschlüssel verfallen → sichtbar')
      assertTrue(h.sichtbar, 'die Lehre: abgelaufene Sitzung schützt nicht')
      assertEqual(h.vauMsLeft, 0)
    })

    test('refreshSession hält die Sitzung frisch (Kontext-Anker)', () => {
      const h = new HuelleState(0)
      h.enterVau(0, 1000)
      h.tick(900)
      assertTrue(h.refreshSession(900))
      assertEqual(h.vauMsLeft, 1000)
      h.tick(900)
      assertEqual(h.state, Huelle.Vau, 'aufgefrischt → noch drin')
    })

    test('refreshSession greift nur bei laufender Sitzung', () => {
      const h = new HuelleState(0)
      assertFalse(h.refreshSession(0), 'außerhalb der VAU')
      h.enterVau(0, 0)
      assertFalse(h.refreshSession(0), 'ohne TTL nichts aufzufrischen')
    })

    test('erneutes Betreten frischt auf, feuert aber kein zweites Event', () => {
      const h = new HuelleState(0)
      const seen: HuelleChange[] = []
      h.onChange((c) => seen.push(c))
      assertTrue(h.enterVau(0, 1000))
      h.tick(500)
      assertFalse(h.enterVau(500, 1000), 'kein erneuter Eintritt')
      assertEqual(h.vauMsLeft, 1000, 'aber Sitzung ist frisch')
      assertEqual(seen.filter((c) => c.reason === 'enter-vau').length, 1)
    })

    test('leaveVau außerhalb der VAU ist ein No-Op', () => {
      const h = new HuelleState(0)
      assertFalse(h.leaveVau(0))
      assertEqual(h.state, Huelle.Klartext)
    })

    test('tick ohne VAU verändert nichts', () => {
      const h = new HuelleState(0)
      h.toggle(0)
      h.tick(10_000)
      assertEqual(h.state, Huelle.Verschluesselt)
    })
  })

  suite('Hülle — Events & Reset', () => {
    test('jeder Wechsel meldet from/to/reason', () => {
      const h = new HuelleState(0)
      const seen: string[] = []
      h.onChange((c: HuelleChange) => seen.push(`${c.from}->${c.to}:${c.reason}`))
      h.toggle(0)
      h.enterVau(1, 500)
      h.tick(500)
      assertDeepEqual(seen, [
        'klartext->verschluesselt:toggle',
        'verschluesselt->vau:enter-vau',
        'vau->klartext:session-expired',
      ])
    })

    test('Abmelden stoppt die Benachrichtigung', () => {
      const h = new HuelleState(0)
      let n = 0
      const off = h.onChange(() => (n += 1))
      h.toggle(0)
      off()
      h.toggle(1)
      assertEqual(n, 1)
    })

    test('reset räumt Sitzung, Sperre und Cooldown auf', () => {
      const h = new HuelleState(150)
      h.enterVau(0, 1000)
      h.locked = true
      h.reset(Huelle.Klartext, 5000)
      assertEqual(h.state, Huelle.Klartext)
      assertFalse(h.locked)
      assertFalse(h.vauExpires)
      assertTrue(h.canToggle(5000), 'nach reset sofort wieder umschaltbar')
    })
  })
}
