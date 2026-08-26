/**
 * KENNZAHLEN aus den Telemetrie-Ereignissen (KAPSEL 4.4) — Phaser-frei.
 *
 * Der Kern dieser Datei ist die Antwort auf EINE Frage aus KAPSEL 4.1:
 * „Wechseln ≥ 80 % der Tester den Zustand freiwillig sinnvoll?"
 *
 * Das lässt sich messen, ohne zu fragen. Entscheidend ist die Reihenfolge:
 *
 *   PROAKTIV — der Spieler verschlüsselt, BEVOR ihn ein Lauscher erwischt.
 *              Er hat die Regel aus der Situation gelesen.
 *   REAKTIV  — er verschlüsselt erst, NACHDEM er erwischt wurde.
 *              Er hat die Strafe gebraucht.
 *   PASSIV   — er verschlüsselt nie.
 *
 * Nur PROAKTIV zählt als „verstanden". Das ist strenger als eine Abfrage und
 * kommt ohne Text aus — genau das fordert das Konzept.
 */
import type { TelemetrieEvent } from './events'

export type Verstehen = 'proaktiv' | 'reaktiv' | 'passiv'

export interface LevelKennzahlen {
  levelId: string
  /** Spielzeit im Level in Sekunden (0, wenn nicht beendet). */
  dauerSek: number
  /** Wie oft die Hülle gewechselt wurde. */
  wechsel: number
  wechselProMinute: number
  /** Wie oft ein Lauscher Klartext erwischt hat. */
  gesehen: number
  /** Wie oft REZI helfen musste — hoher Wert = Verständnisproblem. */
  tipps: number
  gesammelt: number
  checkpoints: number
  vauBetreten: number
  vauAbgelaufen: number
  beendet: boolean
  abgebrochen: boolean
  /** Die Kernfrage: freiwillig und sinnvoll gewechselt? */
  verstehen: Verstehen
}

const sek = (ms: number): number => Math.round((ms / 1000) * 10) / 10

/** Kennzahlen eines Levels aus seinen Ereignissen ableiten. */
export function levelKennzahlen(levelId: string, events: TelemetrieEvent[]): LevelKennzahlen {
  const eigene = events.filter((e) => e.levelId === levelId)
  const ersterMit = (typ: string, wert?: string): number | undefined =>
    eigene.find((e) => e.typ === typ && (wert === undefined || e.wert === wert))?.tMs

  const start = ersterMit('level-start') ?? eigene[0]?.tMs ?? 0
  const ende = ersterMit('level-ende')
  const abbruch = ersterMit('level-abbruch')
  const schluss = ende ?? abbruch
  const wechsel = eigene.filter((e) => e.typ === 'huelle-wechsel').length
  const dauerSek = schluss !== undefined ? sek(schluss - start) : 0

  // --- die Kernfrage ---
  const ersterSchutz = ersterMit('huelle-wechsel', 'verschluesselt')
  const erstesGesehen = ersterMit('gesehen')
  let verstehen: Verstehen = 'passiv'
  if (ersterSchutz !== undefined) {
    verstehen = erstesGesehen === undefined || ersterSchutz < erstesGesehen ? 'proaktiv' : 'reaktiv'
  }

  return {
    levelId,
    dauerSek,
    wechsel,
    wechselProMinute: dauerSek > 0 ? Math.round((wechsel / dauerSek) * 60 * 10) / 10 : 0,
    gesehen: eigene.filter((e) => e.typ === 'gesehen').length,
    tipps: eigene.filter((e) => e.typ === 'tipp').length,
    gesammelt: eigene.filter((e) => e.typ === 'gesammelt').length,
    checkpoints: eigene.filter((e) => e.typ === 'checkpoint').length,
    vauBetreten: eigene.filter((e) => e.typ === 'vau-betreten').length,
    vauAbgelaufen: eigene.filter((e) => e.typ === 'vau-abgelaufen').length,
    beendet: ende !== undefined,
    abgebrochen: abbruch !== undefined && ende === undefined,
    verstehen,
  }
}

/** Alle Level, die in den Ereignissen vorkommen — in Auftrittsreihenfolge. */
export function beteiligteLevel(events: TelemetrieEvent[]): string[] {
  const gesehen: string[] = []
  for (const e of events) {
    if (e.levelId && !gesehen.includes(e.levelId)) gesehen.push(e.levelId)
  }
  return gesehen
}

export interface SitzungKennzahlen {
  sitzung: string
  level: LevelKennzahlen[]
  /** Wo der Durchlauf abgebrochen wurde ('' = durchgespielt). */
  abbruchIn: string
  /** Verstehen im ERSTEN Hülle-Level — das ist die Lernstufe, die zählt. */
  verstehen: Verstehen
}

/**
 * Bilanz eines Durchlaufs. `huelleLevel` sind die Level, in denen die Mechanik
 * aktiv ist — nur dort ist „verstehen" überhaupt aussagekräftig.
 */
export function sitzungKennzahlen(
  sitzung: string,
  events: TelemetrieEvent[],
  huelleLevel: string[] = [],
): SitzungKennzahlen {
  const level = beteiligteLevel(events).map((id) => levelKennzahlen(id, events))
  const abbruch = level.find((l) => l.abgebrochen)
  const relevant = level.filter((l) => huelleLevel.length === 0 || huelleLevel.includes(l.levelId))
  return {
    sitzung,
    level,
    abbruchIn: abbruch?.levelId ?? '',
    verstehen: relevant[0]?.verstehen ?? 'passiv',
  }
}

export interface Benchmark {
  /** Auswertbare Durchläufe. */
  n: number
  proaktiv: number
  reaktiv: number
  passiv: number
  /** Anteil proaktiver Durchläufe in Prozent. */
  quote: number
  /** KAPSEL 4.1: ≥ 80 % → weiterbauen, sonst Mechanik überarbeiten. */
  erfuellt: boolean
}

/** Die Schwelle aus KAPSEL 4.1 (Abbruch-/Pivot-Kriterium). */
export const BENCHMARK_PROZENT = 80

/** Mehrere Durchläufe gegen das 80-%-Kriterium auswerten. */
export function benchmark(sitzungen: SitzungKennzahlen[]): Benchmark {
  const n = sitzungen.length
  const zaehle = (v: Verstehen): number => sitzungen.filter((s) => s.verstehen === v).length
  const proaktiv = zaehle('proaktiv')
  const quote = n > 0 ? Math.round((proaktiv / n) * 1000) / 10 : 0
  return {
    n,
    proaktiv,
    reaktiv: zaehle('reaktiv'),
    passiv: zaehle('passiv'),
    quote,
    erfuellt: n > 0 && quote >= BENCHMARK_PROZENT,
  }
}
