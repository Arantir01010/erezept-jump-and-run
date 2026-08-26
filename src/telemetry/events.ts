/**
 * TELEMETRIE-EREIGNISSE (KAPSEL 4.4).
 *
 * DATENSCHUTZ IST HIER KEIN NEBENSCHAUPLATZ: Dieses Spiel erklärt Vertraulichkeit —
 * es wäre peinlich, dabei selbst Personendaten zu sammeln. Deshalb gilt:
 *
 *   • KEINE Personendaten. Kein Name, keine Kennung, keine IP, kein Zeitstempel
 *     mit Datum. Nur Millisekunden SEIT Sitzungsbeginn.
 *   • Die Sitzungs-ID ist eine Zufallszahl, die nichts und niemanden identifiziert
 *     und beim nächsten Durchlauf verworfen wird.
 *   • Kein Netzwerk. Die Daten bleiben lokal, bis das Standpersonal sie bewusst
 *     exportiert (F9).
 *
 * Ein Test (tools/test/telemetrie.test.ts) hält fest, dass kein Ereignis ein
 * verdächtiges Feld bekommt.
 */

/**
 * Alle erfassten Ereignisarten. Bewusst knapp — jede muss eine Frage beantworten.
 *
 * Die drei Karten-Ereignisse beantworten dieselbe Art Frage wie
 * `huelle-wechsel` und `gesehen` bei der Hülle: Hat der Spieler die REGEL
 * verstanden oder nur herumprobiert? Viele `karte-abgelehnt` mit dem Grund
 * `falsche-karte` heißen: „Er glaubt, eine Karte ersetze die andere" — genau
 * der Vereinfachungsfehler, den KAPSEL 1.4 benennt. Der Grund steht deshalb
 * im `wert`, sonst wäre die Zahl nicht deutbar.
 */
export const TELEMETRIE_TYPEN = [
  'level-start',      // Station betreten
  'level-ende',       // Station geschafft
  'level-abbruch',    // Idle-Reset oder Rücksprung ins Attract (Abbruchpunkt!)
  'huelle-wechsel',   // Toggle-Häufigkeit + Richtung
  'gesehen',          // Lauscher hat Klartext erwischt
  'checkpoint',       // Fortschrittsmarke erreicht
  'gesammelt',        // Prüfsumme eingesammelt
  'tipp',             // REZI musste helfen -> Verständnisproblem
  'vau-betreten',     // dritter Zustand ausprobiert
  'vau-abgelaufen',   // Kontextschlüssel verfallen
  'karte-gefunden',   // Ausweis aufgesammelt (wert = egk|hba|smcb)
  'karte-gesteckt',   // Terminal hat die Identität akzeptiert
  'karte-abgelehnt',  // Steckversuch gescheitert (wert = Grund)
] as const

export type TelemetrieTyp = (typeof TELEMETRIE_TYPEN)[number]

/**
 * Ein Ereignis. `wert` ist ein knapper, nicht personenbezogener Zusatz
 * (z. B. der Zielzustand beim Wechsel oder die Kennung des Tipps).
 */
export interface TelemetrieEvent {
  typ: TelemetrieTyp
  /** Level-ID, in der es passierte ('' = außerhalb eines Levels). */
  levelId: string
  /** Millisekunden seit Sitzungsbeginn — bewusst KEIN Datum. */
  tMs: number
  wert?: string
}

/** Erlaubte Feldnamen eines Ereignisses (Datenschutz-Prüfung im Test). */
export const ERLAUBTE_FELDER = ['typ', 'levelId', 'tMs', 'wert'] as const

export function istTelemetrieTyp(t: string): t is TelemetrieTyp {
  return (TELEMETRIE_TYPEN as readonly string[]).includes(t)
}
