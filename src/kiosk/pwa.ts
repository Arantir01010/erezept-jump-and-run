/**
 * PWA-Auslieferung: Service-Worker-Registrierung (public/sw.js).
 *
 * Nur im Produktions-Build: Im Dev-Modus würde der Cache Vite-HMR und frisch
 * gebaute Level (design/ → build:levels) verschleiern — genau die Sorte
 * „warum sehe ich meine Änderung nicht?"-Fehler, die Stunden kostet.
 *
 * BASE_URL statt fester Pfad: Der Build läuft mit base './' unter jedem
 * Unterpfad (GitHub Pages, Messe-Mini-Server, file-nahes Setup).
 */
export function registerPwa(): void {
  if (!import.meta.env.PROD) return
  if (!('serviceWorker' in navigator)) return
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register(`${import.meta.env.BASE_URL}sw.js`)
      .catch((err) => console.warn('[pwa] Service Worker nicht registriert:', err))
  })
}
