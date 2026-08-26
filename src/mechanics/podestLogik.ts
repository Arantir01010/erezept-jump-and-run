/**
 * STILLSTAND-PODEST — die Fortschrittsregel, Phaser-frei und uhrenfrei.
 *
 * Warum als eigenes Modul: Das hier sind die Zahlen, an denen sich das Podest
 * „zäh" oder „fair" anfühlt. Genau solche Regeln werden nachjustiert — und was
 * nachjustiert wird, muss prüfbar sein, sonst merkt niemand, wenn eine spätere
 * Änderung die Balance kippt. Dasselbe Vorgehen wie bei sicht.ts und
 * lauscherLogik.ts.
 *
 * Die Regel in einem Satz: Stillstehen füllt, Bewegen leert — aber erst nach
 * einer kurzen Nachsicht und nur so schnell, wie es sich füllt.
 */

/**
 * So lange darf gestört werden, ohne dass der Balken zurückläuft.
 *
 * Ohne dieses Fenster setzt schon ein einzelner Frame mit Eingabe den
 * Rückwärtsgang in Gang — und das passiert beim Loslassen des Joysticks fast
 * immer, weil die Hand nachfedert. Der Spieler erlebt das als „der Scan bricht
 * grundlos ab", nicht als eigenen Fehler.
 */
export const NACHSICHT_MS = 220

/**
 * Wie schnell sich der Balken leert, gemessen am Fülltempo.
 *
 * Vorher stand hier 2 — doppelt so schnell leeren wie füllen. Das ist die
 * Ursache des Eindrucks „schleppend": Wer nach 600 ms einmal zuckt, hat nach
 * 300 ms alles verloren und fängt bei null an. Bei 1 kostet ein Wackler genau
 * so viel, wie er gedauert hat. Das ist die faire Rechnung und trotzdem eine
 * echte Konsequenz — Stillstehen bleibt die einzige Art voranzukommen.
 */
export const LEER_FAKTOR = 1

export interface PodestFortschritt {
  /** Bisher gesammelte Scan-Zeit in Millisekunden. */
  progressMs: number
  /** Wie lange die Störung schon andauert (0, solange gescannt wird). */
  stoerungMs: number
}

export interface PodestSchritt extends PodestFortschritt {
  /** Scan in diesem Schritt fertig geworden? */
  fertig: boolean
  /** Fortschritt in diesem Schritt auf null gefallen? (füttert den Assist) */
  abgebrochen: boolean
}

/**
 * Einen Frame weiterrechnen.
 *
 * @param stand    bisheriger Fortschritt
 * @param scanning steht der Spieler auf dem Podest UND ist die Eingabe neutral?
 * @param delta    vergangene Millisekunden seit dem letzten Frame
 * @param scanMs   Gesamtdauer des Scans (aus dem Level, vom Assist verkürzt)
 */
export function podestSchritt(
  stand: PodestFortschritt,
  scanning: boolean,
  delta: number,
  scanMs: number,
): PodestSchritt {
  if (scanning) {
    const progressMs = stand.progressMs + delta
    return { progressMs, stoerungMs: 0, fertig: progressMs >= scanMs, abgebrochen: false }
  }

  if (stand.progressMs <= 0) {
    return { progressMs: 0, stoerungMs: stand.stoerungMs, fertig: false, abgebrochen: false }
  }

  const stoerungMs = stand.stoerungMs + delta
  // Innerhalb der Nachsicht bleibt der Fortschritt unangetastet.
  if (stoerungMs < NACHSICHT_MS) {
    return { progressMs: stand.progressMs, stoerungMs, fertig: false, abgebrochen: false }
  }

  const progressMs = Math.max(0, stand.progressMs - delta * LEER_FAKTOR)
  return { progressMs, stoerungMs, fertig: false, abgebrochen: progressMs === 0 }
}

/** Balkenfüllung 0…1 für die Anzeige. */
export function podestAnteil(progressMs: number, scanMs: number): number {
  if (scanMs <= 0) return 1
  return Math.min(1, Math.max(0, progressMs / scanMs))
}
