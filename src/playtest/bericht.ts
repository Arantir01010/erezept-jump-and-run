/**
 * PLAYTEST-BERICHT (KAPSEL 4.4) — Auswertung der exportierten Durchläufe.
 *
 * F9 im Spiel zeigt die Quote sofort. Diese Datei ist für danach: mehrere
 * Exportdateien (auch von verschiedenen Rechnern) zusammenführen, auswerten und
 * daraus eine ABLEITUNG formulieren — was ist laut KAPSEL 4.1 jetzt zu tun?
 *
 * Genau diese Ableitung ist der Grund, warum das Code ist und kein Merkzettel:
 * „< 80 %" allein hilft nicht. Ob viele Tester REAKTIV oder PASSIV waren, führt
 * zu völlig unterschiedlichen Konsequenzen — und diese Unterscheidung soll nicht
 * von der Tagesform der auswertenden Person abhängen.
 *
 * Phaser-frei, dateisystemfrei → unter Node vollständig prüfbar.
 */
import type { TelemetrieEvent } from '../telemetry/events'
import {
  sitzungKennzahlen,
  benchmark,
  BENCHMARK_PROZENT,
  type SitzungKennzahlen,
  type Benchmark,
} from '../telemetry/kennzahlen'

/** Ein Durchlauf, wie er in der Exportdatei steht. */
export interface RohSitzung {
  sitzung: string
  version?: number
  events: TelemetrieEvent[]
}

/**
 * Durchläufe aus beliebigen Dateiinhalten einsammeln.
 *
 * Absichtlich nachsichtig: Am Messetag entstehen Dateien in verschiedenen Formen
 * (Export-Objekt `{ sitzungen: [...] }`, bloßes Array, einzelner Durchlauf). Eine
 * kaputte Datei darf die Auswertung der anderen nicht verhindern.
 *
 * Doppelte Durchläufe (dieselbe Kennung in zwei Dateien) werden EINMAL gezählt —
 * sonst verfälscht ein doppelter Export die Quote.
 */
export function sammleSitzungen(inhalte: unknown[]): RohSitzung[] {
  const raus: RohSitzung[] = []
  const bekannt = new Set<string>()

  const nimm = (kandidat: unknown): void => {
    if (!kandidat || typeof kandidat !== 'object') return
    const s = kandidat as RohSitzung
    if (typeof s.sitzung !== 'string' || !Array.isArray(s.events)) return
    if (s.events.length === 0) return // leerer Durchlauf sagt nichts aus
    if (bekannt.has(s.sitzung)) return
    bekannt.add(s.sitzung)
    raus.push(s)
  }

  for (const inhalt of inhalte) {
    if (Array.isArray(inhalt)) {
      for (const s of inhalt) nimm(s)
      continue
    }
    if (inhalt && typeof inhalt === 'object') {
      const wrapper = inhalt as { sitzungen?: unknown }
      if (Array.isArray(wrapper.sitzungen)) {
        for (const s of wrapper.sitzungen) nimm(s)
        continue
      }
      nimm(inhalt)
    }
  }
  return raus
}

/** Auffälligkeiten je Level — wo hakt es? */
export interface LevelAuffaelligkeit {
  levelId: string
  /** Wie oft hier abgebrochen wurde (Idle-Reset mitten im Level). */
  abbrueche: number
  /** Wie oft REZI helfen musste. */
  tipps: number
  /** Wie oft ein Lauscher Klartext erwischt hat. */
  gesehen: number
  /** Durchschnittliche Spielzeit in Sekunden (nur beendete Läufe). */
  dauerSchnitt: number
}

export type Ableitung =
  | 'keine-daten'
  | 'zu-wenige'
  | 'erfuellt'
  | 'zu-spaet'
  | 'nicht-erkannt'

export interface Bericht {
  n: number
  benchmark: Benchmark
  sitzungen: SitzungKennzahlen[]
  auffaellig: LevelAuffaelligkeit[]
  ableitung: Ableitung
  /** Klartext-Empfehlung für den Bericht. */
  empfehlung: string
}

/** KAPSEL 4.1 nennt 3–5 Laien für Phase 0 — darunter ist keine Aussage möglich. */
export const MINDEST_DURCHLAEUFE = 3

const EMPFEHLUNG: Record<Ableitung, string> = {
  'keine-daten':
    'Keine auswertbaren Durchläufe gefunden. Wurde vor dem Test localStorage geleert und danach F9 gedrückt?',
  'zu-wenige': `Weniger als ${MINDEST_DURCHLAEUFE} Durchläufe — die Quote ist noch keine Aussage. Weiter testen.`,
  erfuellt: `Kriterium erfüllt (≥ ${BENCHMARK_PROZENT} %). Die Hülle-Mechanik trägt — Welt 2 (Kartenstecken) kann gebaut werden.`,
  'zu-spaet':
    'Kriterium verfehlt, aber die Mehrheit hat die Regel verstanden — nur zu spät. Die Mechanik ist richtig, ' +
    'die EINFÜHRUNG ist zu leise: Lauscher früher sichtbar machen, Sichtkegel deutlicher, erste Zone entschärfen. ' +
    'HUELLE_TUNING nicht anfassen.',
  'nicht-erkannt':
    'Kriterium verfehlt, und die Mehrheit hat den Zusammenhang gar nicht erkannt. Das ist der Fall, für den ' +
    'KAPSEL 4.1 den Pivot vorsieht: HUELLE_TUNING überarbeiten (Kontrast der Zustände erhöhen) und die ' +
    'Konsequenz spürbarer machen — KEINEN weiteren Content produzieren.',
}

/** Auffälligkeiten aus allen Durchläufen aufsummieren. */
function auffaelligkeiten(sitzungen: SitzungKennzahlen[]): LevelAuffaelligkeit[] {
  const acc = new Map<string, { a: number; t: number; g: number; dauern: number[] }>()
  for (const s of sitzungen) {
    for (const l of s.level) {
      const e = acc.get(l.levelId) ?? { a: 0, t: 0, g: 0, dauern: [] }
      if (l.abgebrochen) e.a += 1
      e.t += l.tipps
      e.g += l.gesehen
      if (l.beendet && l.dauerSek > 0) e.dauern.push(l.dauerSek)
      acc.set(l.levelId, e)
    }
  }
  return [...acc.entries()]
    .map(([levelId, e]) => ({
      levelId,
      abbrueche: e.a,
      tipps: e.t,
      gesehen: e.g,
      dauerSchnitt:
        e.dauern.length > 0
          ? Math.round((e.dauern.reduce((x, y) => x + y, 0) / e.dauern.length) * 10) / 10
          : 0,
    }))
    // Die problematischsten zuerst: viele Abbrüche, dann viele Tipps
    .sort((x, y) => y.abbrueche - x.abbrueche || y.tipps - x.tipps)
}

/**
 * Ableitung nach KAPSEL 4.1. Die Reihenfolge der Prüfungen ist die Aussage:
 * erst „genug Daten?", dann „erfüllt?", und nur bei Misserfolg die Frage,
 * WORAN es liegt.
 */
export function bestimmeAbleitung(b: Benchmark): Ableitung {
  if (b.n === 0) return 'keine-daten'
  if (b.n < MINDEST_DURCHLAEUFE) return 'zu-wenige'
  if (b.erfuellt) return 'erfuellt'
  return b.reaktiv >= b.passiv ? 'zu-spaet' : 'nicht-erkannt'
}

export function erstelleBericht(rohe: RohSitzung[], huelleLevel: string[] = []): Bericht {
  const sitzungen = rohe.map((s) => sitzungKennzahlen(s.sitzung, s.events, huelleLevel))
  const b = benchmark(sitzungen)
  const ableitung = bestimmeAbleitung(b)
  return {
    n: sitzungen.length,
    benchmark: b,
    sitzungen,
    auffaellig: auffaelligkeiten(sitzungen),
    ableitung,
    empfehlung: EMPFEHLUNG[ableitung],
  }
}

/** Textbericht für die Konsole / zum Kopieren in ein Protokoll. */
export function formatBericht(bericht: Bericht): string {
  const z: string[] = []
  z.push('PLAYTEST-BERICHT (Wirkungsmessung nach KAPSEL 4.4)')
  z.push('')
  z.push(`Auswertbare Durchläufe: ${bericht.n}`)
  z.push('')
  z.push('Nutzung der Hülle-Mechanik')
  z.push(`  verstanden (proaktiv):  ${bericht.benchmark.proaktiv}`)
  z.push(`  erst nach Treffer:      ${bericht.benchmark.reaktiv}`)
  z.push(`  nie verschlüsselt:      ${bericht.benchmark.passiv}`)
  z.push('')
  z.push(
    `  Quote: ${bericht.benchmark.quote} %   Ziel: ${BENCHMARK_PROZENT} %   ` +
      `${bericht.benchmark.erfuellt ? 'ERREICHT' : 'NICHT ERREICHT'}`,
  )
  if (bericht.auffaellig.length > 0) {
    z.push('')
    z.push('Auffälligkeiten je Station')
    z.push('  Station                  Abbrüche  Tipps  Treffer  Zeit')
    for (const a of bericht.auffaellig) {
      z.push(
        `  ${a.levelId.padEnd(24)}${String(a.abbrueche).padStart(8)}` +
          `${String(a.tipps).padStart(7)}${String(a.gesehen).padStart(9)}` +
          `${(a.dauerSchnitt > 0 ? a.dauerSchnitt + 's' : '—').padStart(7)}`,
      )
    }
  }
  z.push('')
  z.push('Ableitung')
  for (const teil of bericht.empfehlung.split(' ').reduce<string[]>((zeilen, wort) => {
    const letzte = zeilen[zeilen.length - 1] ?? ''
    if (letzte.length + wort.length + 1 <= 76) zeilen[zeilen.length - 1] = `${letzte} ${wort}`.trim()
    else zeilen.push(wort)
    return zeilen
  }, [''])) {
    z.push(`  ${teil}`)
  }
  return z.join('\n')
}
