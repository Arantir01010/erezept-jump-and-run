/**
 * REGRESSIONSTEST auf den ECHTEN Leveln in design/.
 *
 * Die Unit-Tests prüfen den Compiler mit Kunstlayouts. Dieser Test prüft die
 * Wirklichkeit: Kompilieren alle Level der Playlist fehlerfrei, sind die
 * erzeugten Dateien in public/ aktuell und bleiben die drei Messe-Level
 * unverändert ohne Hülle spielbar?
 *
 * Läuft mit `npm test` und ist damit Teil jeder Abnahme.
 */
import { suite, test, assertEqual, assertTrue } from './harness'
import { runPipeline } from '../lib/pipeline'
import { MECHANIC_TYPE_IDS } from '../../src/mechanics/typeIds'
import { OBJECT_TYPES, MARKER_CHARS, FORBIDDEN_TYPES } from '../lib/catalog'

/** Einmal kompilieren, alle Tests lesen dasselbe Ergebnis (schnell + konsistent). */
const report = runPipeline({ write: false })

/** Die Messe-Level: laufen ohne Hülle und müssen unverändert bleiben. */
const MESSE_LEVEL = ['01-stammdaten', '02-kartenterminal', '03-kov-gateway']

/** Objekte eines kompilierten Levels flach auslesen. */
function objekte(level: (typeof report.levels)[number]): { type: string; x?: number }[] {
  const layers = (level.tmj as { layers?: { objects?: { type: string; x?: number }[] }[] }).layers ?? []
  return layers.flatMap((l) => l.objects ?? [])
}

export function run(): void {
  suite('Echte Level — Pipeline', () => {
    test('alle Level der Playlist kompilieren fehlerfrei', () => {
      assertEqual(report.errors.length, 0, `Fehler:\n  ${report.errors.join('\n  ')}`)
    })

    test('keine Warnungen (die Level sind sauber)', () => {
      assertEqual(report.warnings.length, 0, `Warnungen:\n  ${report.warnings.join('\n  ')}`)
    })

    test('erzeugte Dateien in public/ sind aktuell', () => {
      assertEqual(
        report.stale.length,
        0,
        `veraltet: ${report.stale.join(', ')} — "npm run build:levels" ausführen`,
      )
    })

    test('die drei Messe-Level sind vorhanden', () => {
      const ids = report.levels.map((l) => l.id)
      for (const id of ['01-stammdaten', '02-kartenterminal', '03-kov-gateway']) {
        assertTrue(ids.includes(id), `${id} fehlt in der Playlist`)
      }
    })

    test('jedes Level erzeugt Tilemap UND Level-JSON', () => {
      for (const l of report.levels) {
        assertTrue(l.tmj !== undefined, `${l.id}: keine Tilemap`)
        assertTrue(l.levelJson !== undefined, `${l.id}: kein Level-JSON`)
      }
    })
  })

  suite('Echte Level — Messebetrieb bleibt unverändert', () => {
    test('jedes Level hat einen huelle-Block', () => {
      for (const l of report.levels) {
        const h = (l.levelJson as { huelle?: Record<string, unknown> }).huelle
        assertTrue(h !== undefined, `${l.id}: huelle-Block fehlt`)
      }
    })

    test('die drei Messe-Level laufen weiterhin OHNE Hülle', () => {
      for (const id of MESSE_LEVEL) {
        const l = report.levels.find((x) => x.id === id)
        assertTrue(l !== undefined, `${id} fehlt`)
        const h = (l?.levelJson as { huelle?: { enabled?: boolean } }).huelle
        assertEqual(h?.enabled, false, `${id} darf die Hülle nicht einschalten`)
      }
    })

    test('kein Messe-Level benutzt Hülle-Objekte', () => {
      for (const id of MESSE_LEVEL) {
        const l = report.levels.find((x) => x.id === id)
        if (!l) continue
        for (const o of objekte(l)) {
          assertTrue(
            OBJECT_TYPES[o.type]?.needsHuelle !== true,
            `${id}: ${o.type} braucht die Hülle, das Level hat sie aber aus`,
          )
        }
      }
    })

    test('Hülle-Objekte gibt es nur in Leveln mit huelle.enabled', () => {
      // Gilt für ALLE Level, auch künftige: Wer Hülle-Bausteine setzt, muss die
      // Mechanik einschalten — sonst wäre das Level unspielbar.
      for (const l of report.levels) {
        const an = (l.levelJson as { huelle?: { enabled?: boolean } }).huelle?.enabled === true
        const nutzt = objekte(l).some((o) => OBJECT_TYPES[o.type]?.needsHuelle === true)
        if (nutzt) assertTrue(an, `${l.id}: nutzt Hülle-Objekte, aber huelle.enabled ist false`)
      }
    })
  })

  suite('Echte Level — Lernlevel „Die Hülle"', () => {
    const lern = report.levels.find((l) => l.id === '04-die-huelle')

    test('das Level existiert und steht in der Playlist', () => {
      assertTrue(lern !== undefined, '04-die-huelle fehlt')
    })

    test('die Hülle ist eingeschaltet und startet im Klartext', () => {
      const h = (lern?.levelJson as { huelle?: { enabled?: boolean; start?: string } }).huelle
      assertEqual(h?.enabled, true)
      assertEqual(h?.start, 'klartext', 'die erste Lernstufe beginnt sichtbar')
    })

    test('alle vier Hülle-Bausteine kommen vor (die Mechanik wird vollständig gelehrt)', () => {
      if (!lern) return
      const typen = new Set(objekte(lern).map((o) => o.type))
      for (const typ of ['lauscher', 'andock-plattform', 'vau-feld', 'kontext-anker']) {
        assertTrue(typen.has(typ), `${typ} fehlt im Lernlevel`)
      }
    })

    test('genug Puffer: deutlich mehr Prüfsummen als nötig', () => {
      if (!lern) return
      const cfg = lern.levelJson as { collectible: { countRequired: number } }
      const bits = objekte(lern).filter((o) => o.type === 'collectible').length
      assertTrue(
        bits >= cfg.collectible.countRequired + 5,
        `${bits} Bits bei Ziel ${cfg.collectible.countRequired} — ein Treffer kostet bis zu 5`,
      )
    })

    test('Checkpoints sind vorhanden (schnelle Retrys, KAPSEL 2.2)', () => {
      if (!lern) return
      const cps = objekte(lern).filter((o) => o.type === 'checkpoint').length
      assertTrue(cps >= 2, `nur ${cps} Checkpoint(s) — für ein Lernlevel zu wenig`)
    })

    test('führt mit Hinweistafeln ein (Lernen durch Tun statt Textblock)', () => {
      if (!lern) return
      const signs = objekte(lern).filter((o) => o.type === 'info-sign').length
      assertTrue(signs >= 3, `nur ${signs} Hinweise`)
    })

    test('keine Schadenszonen — die TI schützt, nicht der Reflex (Markenregel)', () => {
      if (!lern) return
      assertEqual(objekte(lern).filter((o) => o.type === 'hazard').length, 0)
    })

    test('der erste Abschnitt ist gefahrlos (Ki-Phase: Toggle ohne Risiko lernen)', () => {
      if (!lern) return
      const ersterLauscher = Math.min(
        ...objekte(lern).filter((o) => o.type === 'lauscher').map((o) => o.x ?? 0),
      )
      assertTrue(ersterLauscher >= 300, `erster Lauscher schon bei x=${ersterLauscher} — zu früh`)
    })
  })

  suite('Echte Level — Tilemap-Struktur', () => {
    test('Kachelanzahl passt bei jedem Level exakt', () => {
      for (const l of report.levels) {
        const tmj = l.tmj as { width: number; height: number; layers: { data?: number[] }[] }
        assertEqual(tmj.layers[0].data?.length, tmj.width * tmj.height, `${l.id}: Rasterfehler`)
      }
    })

    test('jedes Level hat genau einen Spawn', () => {
      for (const l of report.levels) {
        const objs = ((l.tmj as { layers?: { objects?: { type: string }[] }[] }).layers ?? [])
          .flatMap((layer) => layer.objects ?? [])
        assertEqual(objs.filter((o) => o.type === 'spawn').length, 1, `${l.id}`)
      }
    })

    test('jedes Level hat einen Ausgang (Tür oder Stempel-Finale)', () => {
      for (const l of report.levels) {
        const objs = ((l.tmj as { layers?: { objects?: { type: string }[] }[] }).layers ?? [])
          .flatMap((layer) => layer.objects ?? [])
        const exits = objs.filter((o) => o.type === 'door-exit' || o.type === 'stamp-exit' || o.type === 'letzte-tuer')
        assertTrue(exits.length >= 1, `${l.id}: kein Ausgang`)
      }
    })

    test('Sammelziel ist in jedem Level erfüllbar', () => {
      for (const l of report.levels) {
        const cfg = l.levelJson as { collectible: { countRequired: number } }
        const objs = ((l.tmj as { layers?: { objects?: { type: string }[] }[] }).layers ?? [])
          .flatMap((layer) => layer.objects ?? [])
        const bits = objs.filter((o) => o.type === 'collectible').length
        assertTrue(
          bits >= cfg.collectible.countRequired,
          `${l.id}: ${bits} Bits < ${cfg.collectible.countRequired} verlangt`,
        )
      }
    })

    test('alle verwendeten Objekt-Typen kennt die Engine', () => {
      for (const l of report.levels) {
        const objs = ((l.tmj as { layers?: { objects?: { type: string }[] }[] }).layers ?? [])
          .flatMap((layer) => layer.objects ?? [])
        for (const o of objs) {
          assertTrue(
            (MECHANIC_TYPE_IDS as readonly string[]).includes(o.type),
            `${l.id}: Engine kennt "${o.type}" nicht — src/mechanics/typeIds.ts ergänzen`,
          )
        }
      }
    })
  })

  suite('Katalog ↔ Engine bleiben synchron', () => {
    test('jeder baubare Objekt-Typ ist der Engine bekannt', () => {
      for (const type of Object.keys(OBJECT_TYPES)) {
        assertTrue(
          (MECHANIC_TYPE_IDS as readonly string[]).includes(type),
          `Katalog erlaubt "${type}", src/mechanics/typeIds.ts kennt ihn nicht`,
        )
      }
    })

    test('jeder Marker-Typ ist der Engine bekannt', () => {
      for (const type of Object.values(MARKER_CHARS)) {
        assertTrue((MECHANIC_TYPE_IDS as readonly string[]).includes(type), `Marker-Typ "${type}" fehlt der Engine`)
      }
    })

    test('gesperrte Stub-Typen kennt die Engine trotzdem (sie loggen nur)', () => {
      for (const type of ['pruef-scanner', 'rechte-tueren', 'finale-sprint', 'vervollstaendigen']) {
        assertTrue((MECHANIC_TYPE_IDS as readonly string[]).includes(type), `${type} fehlt in typeIds`)
        assertTrue(FORBIDDEN_TYPES[type] !== undefined, `${type} muss im Baukasten gesperrt bleiben`)
      }
    })
  })
}
