/**
 * ZUGRIFFSPROTOKOLL-AUSWERTUNG (KAPSEL 2.7 / 3.2).
 *
 * Das Protokoll sammelt Vorfälle (src/state/Protokoll.ts). Hier wird daraus die
 * Bilanz für den Endscreen: pro Station drei unabhängige Siegel plus Summe.
 *
 * „Unabhängig" ist Absicht (KAPSEL 2.7, Anti-Fleißarbeit): Wer alle Prüfsummen
 * verpasst, kann trotzdem das Siegel „Lückenloses Protokoll" holen. Kein
 * Alles-oder-nichts.
 *
 * Phaser-frei und uhrenfrei → unter Node testbar.
 */
import type { Protokoll, Siegel } from './Protokoll'

export interface LevelBilanz {
  levelId: string
  /** Anzeigename der Station (aus dem Level-JSON). */
  name: string
  siegel: Siegel
  /** Anzahl erreichter Siegel dieser Station (0..3). */
  erreicht: number
}

export interface ProtokollBilanz {
  zeilen: LevelBilanz[]
  /** Erreichte Siegel gesamt. */
  siegelErreicht: number
  /** Maximal möglich (3 pro bewerteter Station). */
  siegelMoeglich: number
  /** Wurde der Spieler im ganzen Durchlauf nie gesehen? */
  lueckenlos: boolean
}

export interface BilanzEingabe {
  levelId: string
  name: string
  /** In DIESEM Level gesammelte Prüfsummen. */
  bits: number
  bitsRequired: number
}

/**
 * Bilanz über die gespielten Stationen bilden.
 * `eingaben` kommt aus der Playlist + den pro Level gemerkten Bit-Ständen.
 */
export function bildeBilanz(protokoll: Protokoll, eingaben: BilanzEingabe[]): ProtokollBilanz {
  const zeilen: LevelBilanz[] = eingaben.map((e) => {
    const siegel = protokoll.siegel(e.levelId, { bits: e.bits, bitsRequired: e.bitsRequired })
    const erreicht =
      (siegel.durchgespielt ? 1 : 0) +
      (siegel.allePruefsummen ? 1 : 0) +
      (siegel.lueckenlosesProtokoll ? 1 : 0)
    return { levelId: e.levelId, name: e.name, siegel, erreicht }
  })
  return {
    zeilen,
    siegelErreicht: zeilen.reduce((s, z) => s + z.erreicht, 0),
    siegelMoeglich: zeilen.length * 3,
    lueckenlos: protokoll.lueckenlosGesamt,
  }
}

/** Eine Zeile fürs HUD/Endscreen: „VSDM  ●●○". */
export function formatZeile(zeile: LevelBilanz): string {
  const punkte =
    (zeile.siegel.durchgespielt ? '●' : '○') +
    (zeile.siegel.allePruefsummen ? '●' : '○') +
    (zeile.siegel.lueckenlosesProtokoll ? '●' : '○')
  return `${zeile.name}  ${punkte}`
}

/** Kopfzeile des Endscreens. */
export function formatSumme(bilanz: ProtokollBilanz): string {
  const kern = `Siegel ${bilanz.siegelErreicht}/${bilanz.siegelMoeglich}`
  return bilanz.lueckenlos ? `${kern}  ·  Lückenloses Protokoll!` : kern
}
