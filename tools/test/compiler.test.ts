/**
 * Tests des Level-Compilers (tools/lib/compile.ts).
 * Wichtigste Zusicherung: Ein kaputtes Level darf NIE ins Spiel gelangen.
 */
import { suite, test, assertEqual, assertTrue, assertSome, assertNone } from './harness'
import {
  compileLevel,
  MAX_DX_FOR_RISE,
  MAX_DX_FOR_RISE_SLOW,
  MAX_DX_DROP,
  MAX_DX_DROP_SLOW,
} from '../lib/compile'
import { GRID_HEIGHT } from '../lib/catalog'
import { SLOWEST_SPEED_FACTOR } from '../../src/state/HuelleState'

const THEMES = { city: {}, stammdaten: {} } as Record<string, unknown>

/**
 * Gültiges Testlayout: GRID_HEIGHT Zeilen, unten 3 Reihen Boden, Spawn links,
 * Tür rechts, drei Datenbits auf Bodenhöhe.
 * `extras` überschreibt Zeilen zeichenweise (' ' = unverändert lassen).
 */
function layout(opts: { width?: number; extras?: Record<number, string> } = {}): string {
  const width = opts.width ?? 60
  const rows: string[] = []
  for (let y = 0; y < GRID_HEIGHT; y++) {
    rows.push(y >= GRID_HEIGHT - 3 ? '#'.repeat(width) : '.'.repeat(width))
  }
  const groundRow = GRID_HEIGHT - 4
  const chars = rows[groundRow].split('')
  chars[3] = 'P'
  chars[width - 8] = 'D'
  chars[10] = 'o'
  chars[14] = 'o'
  chars[18] = 'o'
  rows[groundRow] = chars.join('')
  for (const [y, content] of Object.entries(opts.extras ?? {})) {
    const row = rows[Number(y)].split('')
    for (let i = 0; i < content.length && i < row.length; i++) {
      if (content[i] !== ' ') row[i] = content[i]
    }
    rows[Number(y)] = row.join('')
  }
  return rows.join('\n') + '\n'
}

const L = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
  station: {
    name: { de: 'T' }, portalText: { de: 'T' }, reziText: { de: 'T' },
    stampText: { de: 'T' }, badge: 'T',
  },
  siegelIcon: 'seal-generic',
  cityAnchor: { facade: 'praxis', label: { de: 'T' } },
  cameraMode: 'horizontal',
  theme: 'city',
  enemySkin: 'datenkrake',
  collectible: { type: 'datenbit', countRequired: 3, label: { de: 'Bits' } },
  mechanics: {},
  parTimeSeconds: 30,
  objects: [],
  ...over,
})

/** Kurzform: kompilieren und Fehler/Warnungen zurückgeben. */
const compile = (level: Record<string, unknown>, lay = layout()) =>
  compileLevel('01-test', lay, level, THEMES)

/**
 * Zwei Plateaus gleicher Höhe, dazwischen ein Abgrund von `gap` Spalten.
 *
 * Wichtig: Ein waagerechtes Loch im BODEN wäre nutzlos — der Kartenrand unten
 * ist immer solide, man läuft einfach hindurch. Deshalb liegen die Plateaus
 * hoch (Reihe 10) und der Wiederaufstieg von unten ist mit 8 Kacheln unmöglich.
 * Die Tür ist damit ausschließlich über den Weitsprung erreichbar.
 */
function towers(gap: number): string {
  const width = 60
  const TOP = 10
  const rows: string[][] = []
  for (let y = 0; y < GRID_HEIGHT; y++) {
    rows.push(Array<string>(width).fill(y >= GRID_HEIGHT - 1 ? '#' : '.'))
  }
  const fill = (x0: number, x1: number): void => {
    for (let x = x0; x <= x1; x++) for (let y = TOP; y < GRID_HEIGHT; y++) rows[y][x] = '#'
  }
  const aStart = 18
  const aEnd = 26
  const bStart = aEnd + 1 + gap
  fill(aStart, aEnd)
  fill(bStart, bStart + 8)
  rows[TOP - 1][aStart + 2] = 'P'
  rows[TOP - 1][aStart + 4] = 'o'
  rows[TOP - 1][aStart + 5] = 'o'
  rows[TOP - 1][aStart + 6] = 'o'
  rows[TOP - 1][bStart + 3] = 'D'
  return rows.map((r) => r.join('')).join('\n') + '\n'
}

/** Level mit eingeschalteter Hülle (ein Lauscher, damit keine Warnung entsteht). */
const mitHuelle = (over: Record<string, unknown> = {}) =>
  L({ huelle: { enabled: true }, objects: [{ type: 'lauscher', tx: 20, ty: 8 }], ...over })

export function run(): void {
  suite('Compiler — Grundlagen', () => {
    test('gültiges Level kompiliert fehlerfrei', () => {
      const r = compile(L())
      assertEqual(r.errors.length, 0, `unerwartete Fehler: ${r.errors.join(' | ')}`)
      assertTrue(r.tmj !== undefined, 'tmj erzeugt')
      assertTrue(r.levelJson !== undefined, 'levelJson erzeugt')
    })

    test('falsche Zeilenzahl wird gemeldet', () => {
      assertSome(compile(L(), '####\n####\n').errors, `${GRID_HEIGHT} Zeilen erwartet`)
    })

    test('unbekanntes Zeichen wird gemeldet', () => {
      assertSome(compile(L(), layout({ extras: { 5: '....§' } })).errors, 'unbekanntes Zeichen')
    })

    test('fehlender Spawn wird gemeldet', () => {
      assertSome(compile(L(), layout().replace('P', '.')).errors, 'Spawn-Marker')
    })

    test('fehlender Ausgang wird gemeldet', () => {
      assertSome(compile(L(), layout().replace('D', '.')).errors, 'Kein Levelausgang')
    })

    test('unerfüllbares Sammelziel wird gemeldet', () => {
      assertSome(
        compile(L({ collectible: { type: 'datenbit', countRequired: 20, label: { de: 'B' } } })).errors,
        'unschaffbar',
      )
    })

    test('unbekanntes Theme wird gemeldet', () => {
      assertSome(compile(L({ theme: 'gibtsnicht' })).errors, 'Theme "gibtsnicht"')
    })

    test('unbekannter Objekt-Typ bekommt einen Vorschlag', () => {
      assertSome(compile(L({ objects: [{ type: 'lauscherr', tx: 20, ty: 18 }] })).errors, 'meintest du "lauscher"')
    })
  })

  suite('Compiler — Rückwärtskompatibilität', () => {
    test('Level ohne huelle-Block bekommt einen Default-Block (Hülle AUS)', () => {
      const h = (compile(L()).levelJson as { huelle?: Record<string, unknown> }).huelle
      assertTrue(h !== undefined, 'huelle-Block fehlt')
      assertEqual(h?.enabled, false, 'Messe-Level bleiben unverändert spielbar')
      assertEqual(h?.start, 'klartext')
      assertEqual(h?.toggleCooldownMs, 150)
    })

    test('Alt-Level erzeugt keine Hülle-Warnungen', () => {
      assertNone(compile(L()).warnings, 'huelle')
    })

    test('Tore/Öffner-Logik ist unverändert: Tor ohne Öffner = Fehler', () => {
      assertSome(compile(L({ objects: [{ type: 'gate', name: 'tor-a', tx: 30, ty: 14 }] })).errors, 'KEINEN Öffner')
    })

    test('Öffner mit falschem Tornamen = Fehler', () => {
      assertSome(
        compile(L({ objects: [{ type: 'krypto-dusche', tx: 20, ty: 14, gate: 'tippfehler' }] })).errors,
        'unbekanntes Tor',
      )
    })

    test('Tor mit Öffner ist gültig', () => {
      const r = compile(L({
        objects: [
          { type: 'krypto-dusche', tx: 20, ty: 14, gate: 'tor-a' },
          { type: 'gate', name: 'tor-a', tx: 30, ty: 14 },
        ],
      }))
      assertEqual(r.errors.length, 0, r.errors.join(' | '))
    })
  })

  suite('Compiler — Hülle: Softlock-Schutz', () => {
    test('Hülle-Objekt ohne huelle.enabled ist ein FEHLER', () => {
      const r = compile(L({ objects: [{ type: 'lauscher', tx: 20, ty: 18 }] }))
      assertSome(r.errors, 'nicht eingeschaltet')
      assertSome(r.errors, '"huelle": { "enabled": true }', 'Meldung nennt die Lösung')
    })

    test('die Fehlermeldung listet alle betroffenen Typen', () => {
      const r = compile(L({
        objects: [
          { type: 'lauscher', tx: 20, ty: 18 },
          { type: 'vau-feld', tx: 30, ty: 15 },
        ],
      }))
      assertSome(r.errors, 'lauscher')
      assertSome(r.errors, 'vau-feld')
    })

    test('mit huelle.enabled ist der Lauscher gültig', () => {
      const r = compile(L({
        huelle: { enabled: true },
        objects: [{ type: 'lauscher', tx: 20, ty: 18, patrol: 40 }],
      }))
      assertEqual(r.errors.length, 0, r.errors.join(' | '))
      assertEqual((r.levelJson as { huelle?: { enabled?: boolean } }).huelle?.enabled, true)
    })

    test('huelle.enabled ohne Hülle-Objekt warnt (kein Fehler)', () => {
      const r = compile(L({ huelle: { enabled: true } }))
      assertEqual(r.errors.length, 0)
      assertSome(r.warnings, 'kein Hülle-Objekt')
    })

    test('start-Zustand landet in der Ausgabe', () => {
      const r = compile(L({
        huelle: { enabled: true, start: 'verschluesselt' },
        objects: [{ type: 'lauscher', tx: 20, ty: 18 }],
      }))
      assertEqual(r.errors.length, 0, r.errors.join(' | '))
      assertEqual((r.levelJson as { huelle?: { start?: string } }).huelle?.start, 'verschluesselt')
    })
  })

  suite('Compiler — Hülle: VAU-Durchquerbarkeit', () => {
    test('zu breites VAU-Feld mit kurzer Sitzung ist ein FEHLER', () => {
      const r = compile(
        L({ huelle: { enabled: true }, objects: [{ type: 'vau-feld', tx: 20, ty: 15, tw: 30, th: 4, ttlMs: 500 }] }),
        layout({ width: 80 }),
      )
      assertSome(r.errors, 'nie durchqueren')
      assertSome(r.errors, 'kontext-anker', 'Meldung nennt Lösungswege')
    })

    test('passendes VAU-Feld ist gültig', () => {
      const r = compile(
        L({ huelle: { enabled: true }, objects: [{ type: 'vau-feld', tx: 20, ty: 15, tw: 6, th: 4, ttlMs: 4000 }] }),
        layout({ width: 80 }),
      )
      assertEqual(r.errors.length, 0, r.errors.join(' | '))
    })

    test('VAU-Feld ohne ttlMs wird nie als unpassierbar gemeldet', () => {
      const r = compile(
        L({ huelle: { enabled: true }, objects: [{ type: 'vau-feld', tx: 10, ty: 15, tw: 40, th: 4 }] }),
        layout({ width: 80 }),
      )
      assertNone(r.errors, 'nie durchqueren', 'unbegrenzte Sitzung = keine Zeitgrenze')
    })

    test('die Grenze wird mit dem LANGSAMEN Tempo gerechnet', () => {
      // 130 px/s * 0,8 = 104 px/s = 6,5 Kacheln/s. Bei 1000 ms → ~6,5 Kacheln.
      const feld = (tw: number) =>
        compile(
          L({ huelle: { enabled: true }, objects: [{ type: 'vau-feld', tx: 20, ty: 15, tw, th: 4, ttlMs: 1000 }] }),
          layout({ width: 80 }),
        )
      assertEqual(feld(6).errors.length, 0, '6 Kacheln müssen passen')
      assertSome(feld(8).errors, 'nie durchqueren', '8 Kacheln sind zu weit')
    })

    test('kontext-anker ohne ablaufendes Feld warnt', () => {
      assertSome(
        compile(L({
          huelle: { enabled: true },
          objects: [
            { type: 'vau-feld', tx: 20, ty: 15, tw: 5, th: 4 },
            { type: 'kontext-anker', tx: 22, ty: 18 },
          ],
        })).warnings,
        'nichts aufzufrischen',
      )
    })

    test('kontext-anker MIT ablaufendem Feld warnt nicht', () => {
      assertNone(
        compile(L({
          huelle: { enabled: true },
          objects: [
            { type: 'vau-feld', tx: 20, ty: 15, tw: 5, th: 4, ttlMs: 3000 },
            { type: 'kontext-anker', tx: 22, ty: 18 },
          ],
        })).warnings,
        'nichts aufzufrischen',
      )
    })
  })

  suite('Compiler — Hülle: Lesbarkeits-Hinweise', () => {
    test('zwei Lauscher direkt übereinander warnen', () => {
      assertSome(
        compile(L({
          huelle: { enabled: true },
          objects: [
            { type: 'lauscher', tx: 20, ty: 18 },
            { type: 'lauscher', tx: 21, ty: 18 },
          ],
        })).warnings,
        '2 Kacheln Abstand',
      )
    })

    test('genug Abstand → keine Warnung', () => {
      assertNone(
        compile(L({
          huelle: { enabled: true },
          objects: [
            { type: 'lauscher', tx: 20, ty: 18 },
            { type: 'lauscher', tx: 30, ty: 18 },
          ],
        })).warnings,
        '2 Kacheln Abstand',
      )
    })

    test('andock-plattform bei Start "verschluesselt" warnt', () => {
      assertSome(
        compile(L({
          huelle: { enabled: true, start: 'verschluesselt' },
          objects: [{ type: 'andock-plattform', tx: 20, ty: 17 }],
        })).warnings,
        'tragen erst',
      )
    })

    test('bei Start "klartext" keine solche Warnung', () => {
      assertNone(
        compile(L({
          huelle: { enabled: true, start: 'klartext' },
          objects: [{ type: 'andock-plattform', tx: 20, ty: 17 }],
        })).warnings,
        'tragen erst',
      )
    })

    test('mechanics-Abschnitt lauscher wird streng geprüft', () => {
      assertSome(
        compile(L({
          huelle: { enabled: true },
          mechanics: { lauscher: { reach: 100, quatsch: 1 } },
          objects: [{ type: 'lauscher', tx: 20, ty: 18 }],
        })).errors,
        'gibt es hier nicht',
      )
    })

    test('Tippfehler an lauscher-Parametern bekommt Vorschlag', () => {
      assertSome(
        compile(L({ huelle: { enabled: true }, objects: [{ type: 'lauscher', tx: 20, ty: 18, reachh: 100 }] })).errors,
        'meintest du "reach"',
      )
    })
  })

  suite('Compiler — Ausgabe (.tmj)', () => {
    test('Tilemap hat Terrain- und Objektlayer in fester Reihenfolge', () => {
      const tmj = compile(L()).tmj as { layers: { name: string; type: string }[]; height: number }
      assertEqual(tmj.layers[0].name, 'terrain')
      assertEqual(tmj.layers[0].type, 'tilelayer')
      assertEqual(tmj.layers[1].name, 'objects')
      assertEqual(tmj.height, GRID_HEIGHT)
    })

    test('Kachelanzahl passt exakt zu Breite × Höhe', () => {
      const tmj = compile(L(), layout({ width: 64 })).tmj as {
        layers: { data?: number[] }[]; width: number; height: number
      }
      assertEqual(tmj.layers[0].data?.length, tmj.width * tmj.height)
    })

    test('Kompilieren ist deterministisch (Golden-File-Fähigkeit)', () => {
      const a = compile(L())
      const b = compile(L())
      assertEqual(JSON.stringify(a.tmj), JSON.stringify(b.tmj))
      assertEqual(JSON.stringify(a.levelJson), JSON.stringify(b.levelJson))
    })

    test('Marker landen als Objekte in der Tilemap', () => {
      const tmj = compile(L()).tmj as { layers: { objects?: { type: string }[] }[] }
      const types = (tmj.layers[1].objects ?? []).map((o) => o.type)
      assertTrue(types.includes('spawn'), 'spawn fehlt')
      assertTrue(types.includes('door-exit'), 'door-exit fehlt')
      assertEqual(types.filter((t) => t === 'collectible').length, 3)
    })

    test('Hülle-Objekte landen mit Parametern in der Tilemap', () => {
      const tmj = compile(L({
        huelle: { enabled: true },
        objects: [{ type: 'lauscher', tx: 20, ty: 18, reach: 90, patrol: 32 }],
      })).tmj as { layers: { objects?: { type: string; properties: { name: string; value: unknown }[] }[] }[] }
      const l = (tmj.layers[1].objects ?? []).find((o) => o.type === 'lauscher')
      assertTrue(l !== undefined, 'lauscher fehlt in der Tilemap')
      const props = Object.fromEntries((l?.properties ?? []).map((p) => [p.name, p.value]))
      assertEqual(props.reach, 90)
      assertEqual(props.patrol, 32)
    })

    test('bei Fehlern wird KEINE Ausgabe erzeugt', () => {
      const r = compile(L({ theme: 'weg' }))
      assertTrue(r.errors.length > 0)
      assertEqual(r.tmj, undefined, 'kaputtes Level darf nichts ausgeben')
      assertEqual(r.levelJson, undefined)
    })

    test('verbotene Typen (Stubs/Marker) werden abgelehnt', () => {
      for (const type of ['pruef-scanner', 'spawn', 'collectible', 'tube-scroll']) {
        assertTrue(compile(L({ objects: [{ type, tx: 20, ty: 18 }] })).errors.length > 0, `${type} müsste abgelehnt werden`)
      }
    })

    test('hazard bleibt in Tube-Leveln verboten (Markenregel)', () => {
      assertSome(compile(L({ cameraMode: 'tube', objects: [{ type: 'hazard', tx: 20, ty: 18 }] })).errors, 'VERBOTEN')
    })
  })

  suite('Compiler — Sprungweiten im langsamen Zustand', () => {
    test('die langsame Tabelle ist korrekt abgeleitet', () => {
      for (const rise of Object.keys(MAX_DX_FOR_RISE)) {
        const fast = MAX_DX_FOR_RISE[Number(rise)]
        const slow = MAX_DX_FOR_RISE_SLOW[Number(rise)]
        assertEqual(slow, Math.max(1, Math.floor(fast * SLOWEST_SPEED_FACTOR)), `Steighöhe ${rise}`)
      }
      assertEqual(MAX_DX_DROP_SLOW, Math.max(1, Math.floor(MAX_DX_DROP * SLOWEST_SPEED_FACTOR)))
    })

    test('langsam springt nie weiter als schnell, aber immer mindestens 1 Kachel', () => {
      for (const rise of Object.keys(MAX_DX_FOR_RISE_SLOW)) {
        const slow = MAX_DX_FOR_RISE_SLOW[Number(rise)]
        assertTrue(slow >= 1, `Steighöhe ${rise}: mindestens 1 Kachel, sonst kein Sprung möglich`)
        assertTrue(slow <= MAX_DX_FOR_RISE[Number(rise)], `Steighöhe ${rise}: darf nicht weiter sein`)
      }
      assertTrue(MAX_DX_DROP_SLOW >= 1 && MAX_DX_DROP_SLOW <= MAX_DX_DROP)
    })

    test('4er-Abgrund: ohne Hülle machbar, MIT Hülle unerreichbar', () => {
      const map = towers(4)
      const ohne = compile(L(), map)
      const mit = compile(mitHuelle(), map)
      assertEqual(ohne.errors.length, 0, `ohne Hülle muss es gehen: ${ohne.errors.join(' | ')}`)
      assertSome(mit.errors, 'NICHT erreichbar', 'Hülle-Level müssen den langsamen Zustand einrechnen')
    })

    test('die Meldung erklärt, warum strenger gerechnet wird', () => {
      assertSome(compile(mitHuelle(), towers(4)).errors, 'LANGSAMEN Zustand')
    })

    test('5er-Abgrund ist mit Hülle ebenfalls unerreichbar', () => {
      assertSome(compile(mitHuelle(), towers(5)).errors, 'NICHT erreichbar')
    })

    test('3er-Abgrund ist in BEIDEN Zuständen machbar', () => {
      const map = towers(3)
      assertEqual(compile(L(), map).errors.length, 0, 'ohne Hülle')
      const mit = compile(mitHuelle(), map)
      assertEqual(mit.errors.length, 0, `mit Hülle: ${mit.errors.join(' | ')}`)
    })

    test('6er-Abgrund ist auch ohne Hülle zu weit (Grundmetrik unverändert)', () => {
      assertSome(compile(L(), towers(6)).errors, 'NICHT erreichbar')
    })

    test('ohne Hülle steht der Hinweis auf den langsamen Zustand NICHT in der Meldung', () => {
      assertNone(compile(L(), towers(6)).errors, 'LANGSAMEN Zustand')
    })
  })
}
