/**
 * TUBE-KAMERA — wohin der Auto-Scroll-Tunnel als Nächstes rückt.
 *
 * Phaser-frei und uhrenfrei, damit die Regel unter Node prüfbar ist.
 *
 * Der Kern in einem Satz: **Der Auto-Scroll ist die Untergrenze des Tempos,
 * nicht die Obergrenze.**
 *
 * Vorher war er die Obergrenze, und das war ein Fehler mit Ansage: Paul läuft
 * 130 px/s (PLAYER_TUNING.runSpeed), der Tunnel scrollte mit 55 px/s. Wer
 * einfach nach rechts lief — also jeder — rannte gegen die rechte Bildkante,
 * bekam dort seine Geschwindigkeit auf null gesetzt und musste auf die Kamera
 * warten. Das fühlt sich nicht nach Tunnel an, sondern nach Hängenbleiben.
 *
 * Die Untergrenze bleibt trotzdem wichtig: Wer trödelt, wird weitergeschoben.
 * Der Tunnel drängt, aber er bremst nicht mehr.
 */

/**
 * Wie weit vorn im Bild der Spieler laufen darf, bevor er die Kamera mitzieht.
 * 0.5 = Bildmitte. Weiter rechts hieße weniger Vorschau auf das, was kommt.
 */
export const TUBE_FUEHRUNG = 0.5

export interface TubeKameraEingabe {
  /** Bisherige linke Bildkante in Weltkoordinaten. */
  scrollX: number
  /** Grundtempo des Tunnels in px/s (level.mechanics['tube-scroll'].speed). */
  speed: number
  /** Vergangene Millisekunden seit dem letzten Frame. */
  deltaMs: number
  /** Aktuelle x-Position des Spielers. */
  playerX: number
  /** Sichtbare Breite im Design-Raum. */
  viewW: number
  /** Breite der Karte — weiter als bis zum Rand darf nie gescrollt werden. */
  mapWidth: number
  /** Hält gerade eine Mechanik den Scroll an (Podest, Dusche)? */
  held: boolean
}

/**
 * Neue linke Bildkante berechnen.
 *
 * Läuft nie rückwärts: Der Rückgabewert ist immer ≥ `scrollX`. Sonst könnte
 * ein zurücklaufender Spieler die Kamera mitziehen und bereits überwundene
 * Hindernisse noch einmal ins Bild holen.
 */
export function naechsterTubeScroll(e: TubeKameraEingabe): number {
  const maxScroll = Math.max(0, e.mapWidth - e.viewW)

  // Eine Mechanik prüft gerade etwas — der Tunnel wartet, das ist Absicht.
  if (e.held) return Math.min(e.scrollX, maxScroll)

  const grundtempo = e.scrollX + (e.speed * e.deltaMs) / 1000
  // Läuft der Spieler schneller als der Tunnel, zieht er die Kamera mit.
  const vomSpieler = e.playerX - e.viewW * TUBE_FUEHRUNG

  const ziel = Math.max(grundtempo, vomSpieler)
  // Nie rückwärts und nie über den Kartenrand hinaus.
  return Math.min(Math.max(ziel, e.scrollX), maxScroll)
}
