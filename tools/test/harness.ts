/**
 * MINI-TEST-HARNESS — abhängigkeitsfrei (läuft mit tsx, ohne vitest/jest).
 *
 * Bewusst ohne Test-Framework: Messe-PC und CI sollen `npm test` ohne
 * zusätzliche Netzwerk-Installation ausführen können. Das Harness kann alles,
 * was dieses Projekt braucht: Gruppen, Zusicherungen, Fehlerbilanz, Exit-Code.
 *
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */

export interface TestStats {
  passed: number
  failed: number
  failures: string[]
}

const stats: TestStats = { passed: 0, failed: 0, failures: [] }
let currentSuite = ''

export function suite(name: string, body: () => void): void {
  currentSuite = name
  console.log(`\n— ${name} —`)
  body()
  currentSuite = ''
}

export function test(name: string, body: () => void): void {
  const label = currentSuite ? `${currentSuite} › ${name}` : name
  try {
    body()
    stats.passed += 1
    console.log(`  ✓ ${name}`)
  } catch (e) {
    stats.failed += 1
    const msg = e instanceof Error ? e.message : String(e)
    stats.failures.push(`${label}: ${msg}`)
    console.error(`  ✗ ${name}\n      ${msg.split('\n').join('\n      ')}`)
  }
}

class AssertionError extends Error {}

function fail(msg: string): never {
  throw new AssertionError(msg)
}

function show(v: unknown): string {
  if (typeof v === 'string') return JSON.stringify(v)
  if (typeof v === 'bigint') return `${v}n`
  if (v instanceof Set) return `Set(${[...v].map(show).join(', ')})`
  if (v instanceof Map) return `Map(${[...v].map(([k, x]) => `${show(k)}=>${show(x)}`).join(', ')})`
  try {
    return JSON.stringify(v) ?? String(v)
  } catch {
    return String(v)
  }
}

export function assert(cond: unknown, msg = 'Zusicherung fehlgeschlagen'): void {
  if (!cond) fail(msg)
}

export function assertEqual<T>(actual: T, expected: T, msg = ''): void {
  if (!Object.is(actual, expected)) {
    fail(`${msg || 'Wert weicht ab'}\n  erwartet: ${show(expected)}\n  war:      ${show(actual)}`)
  }
}

export function assertDeepEqual(actual: unknown, expected: unknown, msg = ''): void {
  const a = JSON.stringify(actual)
  const b = JSON.stringify(expected)
  if (a !== b) fail(`${msg || 'Struktur weicht ab'}\n  erwartet: ${b}\n  war:      ${a}`)
}

export function assertClose(actual: number, expected: number, epsilon = 1e-9, msg = ''): void {
  if (!(Math.abs(actual - expected) <= epsilon)) {
    fail(`${msg || 'Zahl weicht ab'}\n  erwartet: ${expected} (±${epsilon})\n  war:      ${actual}`)
  }
}

export function assertTrue(v: unknown, msg = 'sollte true sein'): void {
  assertEqual(Boolean(v), true, msg)
}

export function assertFalse(v: unknown, msg = 'sollte false sein'): void {
  assertEqual(Boolean(v), false, msg)
}

/** Muss werfen; optional muss die Meldung `match` enthalten. */
export function assertThrows(body: () => unknown, match?: string | RegExp, msg = ''): void {
  let threw = false
  let text = ''
  try {
    body()
  } catch (e) {
    threw = true
    text = e instanceof Error ? e.message : String(e)
  }
  if (!threw) fail(`${msg || 'Aufruf hätte werfen müssen'} (kein Fehler geworfen)`)
  if (match !== undefined) {
    const hit = typeof match === 'string' ? text.includes(match) : match.test(text)
    if (!hit) fail(`${msg || 'Fehlermeldung passt nicht'}\n  erwartet enthält: ${match}\n  war: ${text}`)
  }
}

/** Mindestens ein Element der Liste enthält `needle`. */
export function assertSome(list: string[], needle: string | RegExp, msg = ''): void {
  const hit = list.some((s) => (typeof needle === 'string' ? s.includes(needle) : needle.test(s)))
  if (!hit) {
    fail(`${msg || 'Kein Eintrag passt'}\n  gesucht: ${needle}\n  Liste:\n    ${list.join('\n    ') || '(leer)'}`)
  }
}

/** Kein Element der Liste enthält `needle`. */
export function assertNone(list: string[], needle: string | RegExp, msg = ''): void {
  const hit = list.filter((s) => (typeof needle === 'string' ? s.includes(needle) : needle.test(s)))
  if (hit.length > 0) {
    fail(`${msg || 'Unerwarteter Eintrag'}\n  verboten: ${needle}\n  gefunden:\n    ${hit.join('\n    ')}`)
  }
}

export function summary(): TestStats {
  return { ...stats, failures: [...stats.failures] }
}

/** Am Ende des Runners aufrufen: Bilanz drucken und Exit-Code setzen. */
export function finish(): void {
  const total = stats.passed + stats.failed
  console.log('')
  if (stats.failed === 0) {
    console.log(`✓ Alle ${total} Zusicherungen erfüllt.`)
    return
  }
  console.error(`✗ ${stats.failed} von ${total} Tests fehlgeschlagen:`)
  for (const f of stats.failures) console.error(`  • ${f}`)
  process.exitCode = 1
}
