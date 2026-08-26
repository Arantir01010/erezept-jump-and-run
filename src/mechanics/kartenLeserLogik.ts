/**
 * KARTENLESER — die Entscheidungen, die kein Phaser brauchen (Paket B2).
 *
 * Der Baustein selbst (Karten.ts) zeichnet und hört auf Knöpfe. Alles, worüber
 * man sich streiten kann, liegt hier: Welche Karten akzeptiert ein Terminal?
 * Was sagt REZI bei welchem Ergebnis? Diese Datei ist Phaser-frei und uhrenfrei
 * und damit unter Node vollständig testbar — dasselbe Vorgehen wie bei
 * sicht.ts und lauscherLogik.ts.
 *
 * FACHLICHE LEITPLANKE (KAPSEL 1.4): Ein Terminal prüft IDENTITÄT, nicht Inhalt.
 * Deshalb entscheidet hier ausschließlich, WELCHE Karte steckt — nie, was auf
 * ihr steht. Auf einer Karte steht nämlich nichts (siehe KartenState.ts).
 */
import { ALLE_KARTEN, Karte, KARTEN_INFO } from '../state/KartenState'
import type { SteckResultat } from '../state/KartenState'
import type { LText } from '../i18n'

/**
 * Erlaubte Karten eines Terminals aus einem Level-Parameter lesen.
 *
 * Der Wert kommt aus zwei Welten und muss beide vertragen: aus `level.json`
 * als Liste (`["egk", "hba"]`), aus einer Tiled-Objekt-Property als flacher
 * String (`"egk,hba"`) — Tiled kennt keine Listen.
 *
 * Unbekannte Einträge werden still verworfen; der Compiler meldet sie später
 * mit einem Tippfehler-Vorschlag (Paket B3). Die Reihenfolge ist immer die
 * feste aus ALLE_KARTEN, damit `steckePassende()` vorhersehbar wählt —
 * Leveldesign darf sich nicht auf Schreibreihenfolge verlassen.
 */
export function parseKarten(roh: unknown): Karte[] {
  const teile: string[] =
    typeof roh === 'string'
      ? roh.split(',')
      : Array.isArray(roh)
        ? roh.map((x) => String(x))
        : []
  const gewuenscht = new Set(teile.map((s) => s.trim().toLowerCase()).filter(Boolean))
  return ALLE_KARTEN.filter((k) => gewuenscht.has(k))
}

/** Kurzliste der akzeptierten Karten für Hinweistexte („eGK oder SMC-B"). */
export function kartenListe(karten: readonly Karte[], oder = 'oder'): string {
  const namen = karten.map((k) => KARTEN_INFO[k].kurz)
  if (namen.length === 0) return ''
  if (namen.length === 1) return namen[0]
  return `${namen.slice(0, -1).join(', ')} ${oder} ${namen[namen.length - 1]}`
}

/**
 * Was REZI sagt, wenn ein Steckversuch nicht klappt.
 *
 * Vier Ergebnisse, vier verschiedene Sätze — das ist der Kern von Paket B1:
 * „du hast sie noch nicht" ist etwas völlig anderes als „die passt hier nicht".
 * Ein Einheitssatz („geht nicht") würde dem Spieler die Information nehmen,
 * die er zum Weiterkommen braucht.
 *
 * `ok` steht bewusst NICHT hier: Der Erfolgssatz gehört dem Level
 * (station.reziText), weil er die fachliche Aussage der Station trägt.
 */
export const STECK_MELDUNG: Record<Exclude<SteckResultat, 'ok'>, LText> = {
  'nicht-dabei': {
    de: 'Die passende Karte hast du noch nicht — such sie unterwegs!',
    en: 'You do not have the right card yet — find it along the way!',
  },
  'falsche-karte': {
    de: 'ZUGRIFF VERWEIGERT — diese Karte gehört hier nicht hin.',
    en: 'ACCESS DENIED — this card does not belong here.',
  },
  belegt: {
    de: 'Deine Karte steckt noch woanders — hol sie erst dort ab.',
    en: 'Your card is still in another slot — pick it up there first.',
  },
}

/**
 * Nur `falsche-karte` ist eine Zurückweisung durch die TI und verdient den
 * sichtbaren „ZUGRIFF VERWEIGERT"-Stempel (Markenregel: Angreifer und
 * Fehlversuche scheitern sichtbar, aber es wird nie gekämpft).
 *
 * `nicht-dabei` und `belegt` sind KEINE Zurückweisungen, sondern Zustände des
 * Spielers. Ein Stempel dafür würde ihm Schuld zuschieben, wo er nur noch
 * nicht so weit ist.
 */
export function istZurueckweisung(resultat: SteckResultat): boolean {
  return resultat === 'falsche-karte'
}

/**
 * Terminal-Kennung aus dem Tiled-Objekt. `steckePassende()` braucht sie, um
 * „ein Terminal hat genau einen Schlitz" durchzusetzen — zwei Leser dürfen
 * deshalb nie dieselbe Kennung tragen.
 */
export function terminalId(name: string | undefined, id: number | undefined): string {
  return name && name.trim() ? name.trim() : `kartenleser-${id ?? 0}`
}
