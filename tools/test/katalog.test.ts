/**
 * Tests des Objektkatalogs (tools/lib/catalog.ts).
 *
 * Der Katalog ist die technische Durchsetzung von design/LEVELBAU.md: Was hier
 * nicht steht, darf ein Level nicht benutzen. Diese Tests prüfen die Schemas
 * isoliert — ohne Compiler, ohne Layout.
 */
import { suite, test, assertEqual, assertTrue, assertFalse, assertSome } from './harness'
import {
  OBJECT_TYPES,
  MECHANICS_SCHEMAS,
  MARKER_CHARS,
  TILE_CHARS,
  FORBIDDEN_TYPES,
  DesignLevelSchema,
  KNOWN_DECO_SPRITES,
  KNOWN_DECO_ANIMS,
  GATE_OPENER_TYPES,
  suggest,
  editDistance,
  GID,
} from '../lib/catalog'

const HUELLE_TYPES = ['lauscher', 'andock-plattform', 'vau-feld', 'kontext-anker']

/** Minimal gültiges Design-Level (zum Anreichern in einzelnen Tests). */
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

const issues = (raw: Record<string, unknown>): string[] => {
  const r = DesignLevelSchema.safeParse(raw)
  return r.success ? [] : r.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`)
}

export function run(): void {
  suite('Katalog — neue Hülle-Objekttypen', () => {
    test('alle vier Typen sind registriert', () => {
      for (const t of HUELLE_TYPES) {
        assertTrue(OBJECT_TYPES[t] !== undefined, `${t} fehlt im Katalog`)
      }
    })

    test('alle vier sind als needsHuelle markiert', () => {
      for (const t of HUELLE_TYPES) {
        assertTrue(OBJECT_TYPES[t].needsHuelle === true, `${t} braucht needsHuelle`)
      }
    })

    test('kein Alt-Typ ist versehentlich needsHuelle', () => {
      for (const [name, def] of Object.entries(OBJECT_TYPES)) {
        if (HUELLE_TYPES.includes(name)) continue
        assertFalse(def.needsHuelle, `${name} darf die Hülle nicht verlangen`)
      }
    })

    test('jeder Typ hat eine Doku-Zeile für Fehlermeldungen', () => {
      for (const [name, def] of Object.entries(OBJECT_TYPES)) {
        assertTrue(def.doc.length > 10, `${name} braucht eine sprechende doc`)
      }
    })

    test('andock-plattform ist eine Plattform (Erreichbarkeits-Check)', () => {
      assertTrue(OBJECT_TYPES['andock-plattform'].makesPlatform === true)
    })

    test('vau-feld verlangt betretbaren Boden in der Zone', () => {
      assertTrue(OBJECT_TYPES['vau-feld'].needsStandableInZone === true)
    })

    test('kein neuer Typ öffnet Tore (das bleibt den TI-Prüfungen vorbehalten)', () => {
      for (const t of HUELLE_TYPES) assertFalse(GATE_OPENER_TYPES.includes(t))
    })
  })

  suite('Katalog — Parameter-Prüfung der neuen Typen', () => {
    test('lauscher akzeptiert seine Parameter', () => {
      const r = OBJECT_TYPES.lauscher.schema.safeParse({
        type: 'lauscher', tx: 10, ty: 18, patrol: 40, speed: 30, reach: 110, spread: 22, pauseMs: 600,
      })
      assertTrue(r.success, 'gültige Parameter müssen durchgehen')
    })

    test('lauscher lehnt unbekannte Felder ab (Tippfehlerschutz)', () => {
      assertFalse(OBJECT_TYPES.lauscher.schema.safeParse({ type: 'lauscher', tx: 1, ty: 1, reachh: 90 }).success)
    })

    test('lauscher lehnt unsinnige Reichweiten ab', () => {
      assertFalse(OBJECT_TYPES.lauscher.schema.safeParse({ type: 'lauscher', tx: 1, ty: 1, reach: 5 }).success, 'zu klein')
      assertFalse(OBJECT_TYPES.lauscher.schema.safeParse({ type: 'lauscher', tx: 1, ty: 1, reach: 9999 }).success, 'zu groß')
    })

    test('patrol darf negativ sein (Lauscher blickt nach links)', () => {
      assertTrue(OBJECT_TYPES.lauscher.schema.safeParse({ type: 'lauscher', tx: 20, ty: 18, patrol: -40 }).success)
    })

    test('vau-feld: ttlMs 0 (unbegrenzt) und positiv sind erlaubt', () => {
      assertTrue(OBJECT_TYPES['vau-feld'].schema.safeParse({ type: 'vau-feld', tx: 1, ty: 1, ttlMs: 0 }).success)
      assertTrue(OBJECT_TYPES['vau-feld'].schema.safeParse({ type: 'vau-feld', tx: 1, ty: 1, ttlMs: 4000 }).success)
    })

    test('vau-feld lehnt negative und absurde ttlMs ab', () => {
      assertFalse(OBJECT_TYPES['vau-feld'].schema.safeParse({ type: 'vau-feld', tx: 1, ty: 1, ttlMs: -1 }).success)
      assertFalse(OBJECT_TYPES['vau-feld'].schema.safeParse({ type: 'vau-feld', tx: 1, ty: 1, ttlMs: 999999 }).success)
    })

    test('kontext-anker und andock-plattform haben keine Extra-Parameter', () => {
      assertFalse(OBJECT_TYPES['kontext-anker'].schema.safeParse({ type: 'kontext-anker', tx: 1, ty: 1, ttlMs: 100 }).success)
      assertFalse(OBJECT_TYPES['andock-plattform'].schema.safeParse({ type: 'andock-plattform', tx: 1, ty: 1, range: 40 }).success)
    })

    test('tx/ty bleiben Pflicht', () => {
      for (const t of HUELLE_TYPES) {
        assertFalse(OBJECT_TYPES[t].schema.safeParse({ type: t }).success, `${t} ohne Position`)
      }
    })
  })

  suite('Katalog — mechanics-Abschnitte', () => {
    test('für jeden neuen Typ existiert ein mechanics-Schema', () => {
      for (const t of HUELLE_TYPES) {
        assertTrue(MECHANICS_SCHEMAS[t] !== undefined, `mechanics-Schema für ${t} fehlt`)
      }
    })

    test('lauscher-Texte sind als {de,en} erlaubt', () => {
      const r = MECHANICS_SCHEMAS.lauscher.safeParse({
        seenText: { de: 'MITGELESEN!', en: 'READ!' },
        akteur: { de: 'Lauscher' },
        huelleHint: { de: 'Joystick hoch!' },
        reach: 100,
      })
      assertTrue(r.success, 'redaktionelle Texte müssen durchgehen')
    })

    test('unbekannte Felder im mechanics-Abschnitt fallen auf', () => {
      assertFalse(MECHANICS_SCHEMAS.lauscher.safeParse({ quatsch: 1 }).success)
    })

    test('Text ohne deutsche Fassung wird abgelehnt', () => {
      assertFalse(MECHANICS_SCHEMAS.lauscher.safeParse({ seenText: { en: 'only english' } }).success)
    })
  })

  suite('Katalog — huelle-Block im Level', () => {
    test('Level ohne huelle-Block bleibt gültig (Messe-Level unberührt)', () => {
      assertEqual(issues(L()).length, 0)
    })

    test('huelle.enabled ist Pflicht, wenn der Block da ist', () => {
      assertSome(issues(L({ huelle: {} })), 'enabled')
    })

    test('start akzeptiert klartext und verschluesselt', () => {
      assertEqual(issues(L({ huelle: { enabled: true, start: 'klartext' } })).length, 0)
      assertEqual(issues(L({ huelle: { enabled: true, start: 'verschluesselt' } })).length, 0)
    })

    test('start "vau" wird abgelehnt (VAU gibt es nur im Feld)', () => {
      assertTrue(issues(L({ huelle: { enabled: true, start: 'vau' } })).length > 0)
    })

    test('unbekanntes Feld im huelle-Block wird abgelehnt', () => {
      assertTrue(issues(L({ huelle: { enabled: true, tempo: 2 } })).length > 0)
    })

    test('toggleCooldownMs bleibt in sinnvollen Grenzen', () => {
      assertEqual(issues(L({ huelle: { enabled: true, toggleCooldownMs: 150 } })).length, 0)
      assertTrue(issues(L({ huelle: { enabled: true, toggleCooldownMs: -5 } })).length > 0)
      assertTrue(issues(L({ huelle: { enabled: true, toggleCooldownMs: 5000 } })).length > 0)
    })

    test('Sammelziel bis 60 möglich (Hülle-Level haben mehr Prüfsummen)', () => {
      assertEqual(issues(L({ collectible: { type: 'datenbit', countRequired: 60, label: { de: 'B' } } })).length, 0)
      assertTrue(issues(L({ collectible: { type: 'datenbit', countRequired: 61, label: { de: 'B' } } })).length > 0)
    })
  })

  suite('Katalog — Grundfesten bleiben unverändert', () => {
    test('Marker-Zeichen sind unverändert', () => {
      assertEqual(MARKER_CHARS.P, 'spawn')
      assertEqual(MARKER_CHARS.o, 'collectible')
      assertEqual(MARKER_CHARS.C, 'checkpoint')
      assertEqual(MARKER_CHARS.D, 'door-exit')
    })

    test('nur die Deko-Strebe ist nicht solide', () => {
      const nichtSolide = Object.entries(TILE_CHARS).filter(([, d]) => !d.solid).map(([c]) => c)
      assertTrue(nichtSolide.includes('|'), 'Strebe muss durchlässig bleiben')
      assertEqual(TILE_CHARS['|'].gid, GID.STREBE)
      assertTrue(TILE_CHARS['#'].solid && TILE_CHARS['='].solid)
    })

    test('Marker-Typen bleiben im objects-Array verboten', () => {
      for (const t of ['spawn', 'collectible', 'checkpoint', 'door-exit']) {
        assertTrue(FORBIDDEN_TYPES[t] !== undefined, `${t} muss gesperrt bleiben`)
      }
    })

    test('Ausbaustufen-Stubs bleiben gesperrt', () => {
      for (const t of ['pruef-scanner', 'rechte-tueren', 'finale-sprint', 'vervollstaendigen']) {
        assertTrue(FORBIDDEN_TYPES[t] !== undefined, `${t} darf nicht baubar sein`)
      }
    })

    test('kein Typ ist gleichzeitig erlaubt und verboten', () => {
      for (const t of Object.keys(OBJECT_TYPES)) {
        assertFalse(FORBIDDEN_TYPES[t] !== undefined, `${t} widersprüchlich`)
      }
    })

    test('Lauscher-Sprites sind als Deko nutzbar', () => {
      assertTrue(KNOWN_DECO_SPRITES.includes('lauscher-0'))
      assertTrue(KNOWN_DECO_ANIMS.includes('lauscher-blink'))
    })
  })

  suite('Katalog — Vorschlagshilfe', () => {
    test('erkennt Tippfehler in Objekt-Typen', () => {
      assertTrue(suggest('lauscherr', Object.keys(OBJECT_TYPES)).includes('lauscher'))
      assertTrue(suggest('vaufeld', Object.keys(OBJECT_TYPES)).includes('vau-feld'))
    })

    test('schweigt bei völlig fremden Begriffen', () => {
      assertEqual(suggest('xyzabc123', Object.keys(OBJECT_TYPES)), '')
    })

    test('editDistance rechnet korrekt', () => {
      assertEqual(editDistance('lauscher', 'lauscher'), 0)
      assertEqual(editDistance('lauscher', 'lauscherr'), 1)
      assertEqual(editDistance('', 'abc'), 3)
    })
  })
}
