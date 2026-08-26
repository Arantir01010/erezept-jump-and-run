/**
 * REGISTRY-TEST — schließt die letzte Lücke zwischen Katalog und Spiel.
 *
 * Der Katalog (tools/lib/catalog.ts) sagt, WAS ein Level bauen darf.
 * typeIds.ts sagt, welche IDs die Engine kennt.
 * Aber erst die Registry (src/mechanics/registry.ts) entscheidet, ob zu einer ID
 * auch wirklich eine Klasse gehört. Fehlt sie, überspringt das Spiel das Objekt
 * mit einer Konsolen-Warnung — der Build wäre grün, das Level im Spiel leer.
 *
 * Dieser Test lädt den Baukasten mit einem minimalen Phaser-Ersatz und prüft,
 * dass jeder baubare Typ eine registrierte Klasse hat.
 */
import { createRequire } from 'node:module'
import { suite, test, assertEqual, assertTrue, assertFalse } from './harness'
import { OBJECT_TYPES, MARKER_CHARS, FORBIDDEN_TYPES } from '../lib/catalog'
import { MECHANIC_TYPE_IDS, isKnownMechanicType } from '../../src/mechanics/typeIds'

/**
 * Die Mechanik-Module importieren Phaser. Unter Node gibt es kein WebGL und kein
 * `window`, deshalb liegt ein schlanker Ersatz im Modul-Cache, BEVOR der
 * Baukasten geladen wird. Wir rufen keine Phaser-Funktion auf — wir wollen nur
 * wissen, welche Typen sich registriert haben.
 *
 * Das Paket ist ESM (`"type": "module"` in package.json), dort gibt es kein
 * globales `require`. Der CJS-Zugang kommt deshalb über `createRequire` —
 * NICHT über `eval('require')`, das unter ESM zur Laufzeit abstürzt und den
 * ganzen Testlauf beendet.
 */
function ladeBaukasten(): Map<string, unknown> {
  const stub: Record<string, unknown> = new Proxy(
    function () {
      /* aufrufbar, damit `extends` funktioniert */
    } as unknown as Record<string, unknown>,
    {
      get: (_t, prop) => {
        if (prop === 'default') return stub
        if (prop === Symbol.toPrimitive) return () => 'PhaserStub'
        return stub
      },
      construct: () => Object.create(null) as object,
      apply: () => stub,
    },
  )

  const req = createRequire(import.meta.url)
  const cache = req.cache as Record<string, unknown> | undefined
  const Module = req('module') as { _load: (...a: unknown[]) => unknown }
  const original = Module._load
  Module._load = function (request: unknown, ...rest: unknown[]): unknown {
    if (request === 'phaser') return stub
    return original.call(this, request, ...rest)
  }
  try {
    // Frisch laden, damit die Side-Effect-Registrierung sicher läuft
    if (cache) {
      for (const key of Object.keys(cache)) {
        if (key.includes('mechanic') || key.includes('registry')) delete cache[key]
      }
    }
    req('../../src/mechanics/index')
    const registry = req('../../src/mechanics/registry') as {
      registryFuerTests?: Map<string, unknown>
    }
    return registry.registryFuerTests ?? new Map()
  } finally {
    Module._load = original
  }
}

export function run(): void {
  const registry = ladeBaukasten()

  suite('Registry — jeder baubare Typ hat eine Klasse', () => {
    test('der Baukasten hat sich überhaupt registriert', () => {
      assertTrue(registry.size > 0, 'Registry ist leer — Baukasten nicht geladen?')
    })

    test('alle vier Hülle-Bausteine sind registriert', () => {
      for (const type of ['lauscher', 'andock-plattform', 'vau-feld', 'kontext-anker']) {
        assertTrue(registry.has(type), `${type} fehlt in der Registry (src/mechanics/index.ts)`)
      }
    })

    test('jeder Objekt-Typ aus dem Katalog ist registriert', () => {
      for (const type of Object.keys(OBJECT_TYPES)) {
        assertTrue(
          registry.has(type),
          `Katalog erlaubt "${type}", aber keine Klasse registriert — das Spiel würde es überspringen`,
        )
      }
    })

    test('Marker-Typen (außer spawn) sind registriert', () => {
      for (const type of Object.values(MARKER_CHARS)) {
        if (type === 'spawn') continue // behandelt die Szene selbst
        assertTrue(registry.has(type), `Marker-Typ "${type}" fehlt in der Registry`)
      }
    })

    test('gesperrte Ausbaustufen sind als Stub registriert (loggen statt crashen)', () => {
      for (const type of ['pruef-scanner', 'rechte-tueren', 'finale-sprint', 'vervollstaendigen']) {
        assertTrue(registry.has(type), `${type} braucht einen Stub, sonst Warnung im Kiosk`)
        assertTrue(FORBIDDEN_TYPES[type] !== undefined, `${type} muss im Baukasten gesperrt bleiben`)
      }
    })

    test('tube-scroll ist bewusst KEIN Baustein (gehört der Kamera)', () => {
      assertFalse(registry.has('tube-scroll'), 'tube-scroll wird von der GameScene gelesen')
      assertTrue(isKnownMechanicType('tube-scroll'), 'als ID muss es bekannt sein')
    })

    test('keine Registry-Einträge ohne bekannte Typ-ID', () => {
      for (const type of registry.keys()) {
        assertTrue(
          (MECHANIC_TYPE_IDS as readonly string[]).includes(type),
          `Registry kennt "${type}", typeIds.ts nicht — spawnMechanic würde es abweisen`,
        )
      }
    })

    test('Anzahl passt: alle IDs außer spawn und tube-scroll', () => {
      const erwartet = MECHANIC_TYPE_IDS.filter((t) => t !== 'spawn' && t !== 'tube-scroll')
      assertEqual(registry.size, erwartet.length, `registriert: ${[...registry.keys()].sort().join(', ')}`)
    })
  })
}
