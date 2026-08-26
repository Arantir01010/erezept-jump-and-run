import type { ProtokollEintrag } from '../state/Protokoll'

/**
 * DAS FINALE — was die letzte Tür zeigt (Phaser-frei, KAPSEL v0.1 Welt 5).
 *
 * Die Pointe des Spiels wird GESPIELT, nicht erzählt: Der Spieler steht vor
 * der Akte und kann nichts tun. Kein Schlüssel passt, kein Sprung hilft.
 * Stattdessen läuft sein eigenes Zugriffsprotokoll über den Bildschirm —
 * jeder Moment, in dem er sich gezeigt hat. Die Versicherte hat die ganze
 * Zeit zugesehen. Dann entscheidet sie, und die Tür geht auf.
 *
 * Dieses Modul entscheidet, WAS gezeigt wird. Es ist bewusst uhren- und
 * Phaser-frei, damit die Regeln testbar sind:
 *
 * - Wenige Zeilen (Messebetrieb!): höchstens MAX_ZEILEN Einträge, der Rest
 *   wird zu einer Summenzeile zusammengefasst. Die NEUESTEN Einträge zählen —
 *   sie sind dem Spieler noch präsent.
 * - Ein lückenloses Protokoll ist der Sonderfall, der die Mechanik adelt:
 *   Wer nie gesehen wurde, bekommt keine leere Liste, sondern die stärkste
 *   Zeile des Spiels.
 */

/** Mehr Zeilen liest am Stand niemand — die Sequenz muss unter ~8 s bleiben. */
export const MAX_ZEILEN = 5

export interface FinaleAnzeige {
  /** Protokollzeilen in Anzeige-Reihenfolge (älteste zuerst). */
  zeilen: string[]
  /** Wurde der Spieler den ganzen Durchlauf über nie gesehen? */
  lueckenlos: boolean
}

/**
 * Anzeige aus den Protokolleinträgen bauen.
 *
 * `levelName` übersetzt eine Level-ID in den Stationsnamen — als Funktion
 * hereingereicht, damit dieses Modul den ConfigService nicht kennen muss.
 */
export function baueFinaleAnzeige(
  eintraege: ProtokollEintrag[],
  levelName: (levelId: string) => string,
): FinaleAnzeige {
  if (eintraege.length === 0) {
    return {
      zeilen: ['Zugriffsprotokoll: keine Einträge.', 'Niemand hat mitgelesen.'],
      lueckenlos: true,
    }
  }

  const zeile = (e: ProtokollEintrag): string => `• ${e.akteur} — ${e.aktion} (${levelName(e.levelId)})`

  if (eintraege.length <= MAX_ZEILEN) {
    return { zeilen: eintraege.map(zeile), lueckenlos: false }
  }

  const rest = eintraege.length - (MAX_ZEILEN - 1)
  const neueste = eintraege.slice(-(MAX_ZEILEN - 1))
  return {
    zeilen: [`… ${rest} frühere Einträge`, ...neueste.map(zeile)],
    lueckenlos: false,
  }
}
