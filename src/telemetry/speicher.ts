/**
 * TELEMETRIE-ABLAGE (Browser-Teil, KAPSEL 4.4).
 *
 * Kein Netzwerk, keine Übertragung: Die Durchläufe liegen in localStorage, bis
 * das Standpersonal sie bewusst als Datei exportiert (F9 im Spiel). Das passt
 * zum Messebetrieb (offline) und zur Botschaft des Spiels.
 *
 * Alles hier ist gegen Ausfälle abgesichert: Ist localStorage voll oder
 * gesperrt, läuft das Spiel unverändert weiter — Telemetrie ist verzichtbar,
 * der Messebetrieb nicht.
 */
import type { TelemetrieEvent } from './events'

const KEY = 'erezept-telemetrie'
/** Ältere Durchläufe fallen heraus — ein Messetag muss reichen. */
const MAX_SITZUNGEN = 200

export interface GespeicherteSitzung {
  sitzung: string
  version: number
  events: TelemetrieEvent[]
}

export function ladeSitzungen(): GespeicherteSitzung[] {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as GespeicherteSitzung[]
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return [] // korrupter Eintrag: verwerfen, nicht crashen
  }
}

/** Durchlauf anhängen (ersetzt einen gleichnamigen — Reload-sicher). */
export function speichereSitzung(s: GespeicherteSitzung): void {
  if (s.events.length === 0) return
  try {
    const alle = ladeSitzungen().filter((x) => x.sitzung !== s.sitzung)
    alle.push(s)
    while (alle.length > MAX_SITZUNGEN) alle.shift()
    localStorage.setItem(KEY, JSON.stringify(alle))
  } catch {
    // voll oder gesperrt: Telemetrie ist verzichtbar
  }
}

export function loescheSitzungen(): void {
  try {
    localStorage.removeItem(KEY)
  } catch {
    /* egal */
  }
}

/**
 * Alle Durchläufe als Datei herunterladen. Wird von der UIScene per F9
 * ausgelöst; der Dateiname enthält bewusst nur Datum und Uhrzeit des Exports,
 * keine Kennung eines Menschen.
 */
export function exportiereDatei(): number {
  const alle = ladeSitzungen()
  const text = JSON.stringify({ exportiert: new Date().toISOString(), sitzungen: alle }, null, 2)
  try {
    const blob = new Blob([text], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `telemetrie-${new Date().toISOString().slice(0, 16).replace(/[:T]/g, '-')}.json`
    a.click()
    URL.revokeObjectURL(url)
  } catch {
    // Kiosk ohne Download-Recht: wenigstens in die Konsole
    console.info('[telemetrie]', text)
  }
  return alle.length
}
