/**
 * Kiosk-Robustheit: Ein unbehandelter Fehler lädt die Seite neu (zurück in den
 * Attract-Mode) statt weiß zu bleiben. Reload-Schleifen werden erkannt und
 * enden in einer Standpersonal-Meldung. Nur im Kiosk-Modus aktiv (?kiosk=1) —
 * in der Entwicklung sollen Fehler sichtbar bleiben.
 */
const KEY = 'erezept-crash-guard'
const MAX_RELOADS = 3
const WINDOW_MS = 90_000

export function installCrashGuard(): void {
  if (new URLSearchParams(location.search).get('kiosk') !== '1') return

  const onFatal = (): void => {
    try {
      const raw = sessionStorage.getItem(KEY)
      const rec = raw ? (JSON.parse(raw) as { n: number; t: number }) : { n: 0, t: 0 }
      const now = Date.now()
      const n = now - rec.t < WINDOW_MS ? rec.n + 1 : 1
      sessionStorage.setItem(KEY, JSON.stringify({ n, t: now }))
      if (n <= MAX_RELOADS) {
        location.reload()
      } else {
        document.body.innerHTML =
          '<div style="color:#fff;background:#06090f;height:100vh;display:flex;align-items:center;' +
          'justify-content:center;font-family:monospace;font-size:20px;text-align:center">' +
          'Kurze Pause — das Standpersonal hilft gleich weiter.</div>'
      }
    } catch {
      location.reload()
    }
  }

  window.addEventListener('error', onFatal)
  window.addEventListener('unhandledrejection', onFatal)
}
