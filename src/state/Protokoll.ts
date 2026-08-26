/**
 * ZUGRIFFSPROTOKOLL (KAPSEL 2.7 / 3.2) — das fachliche Motiv als Meta-Schicht.
 *
 * Die ePA protokolliert JEDEN Zugriff (Akteur, Zeitpunkt, Art). Genau das ist
 * hier der Level-Abschluss-Screen: Der Spieler sieht seinen eigenen Weg als
 * Protokoll — und ob er dabei unbeobachtet blieb.
 *
 * Drei Siegel pro Level (unabhängig erreichbar, kein Alles-oder-nichts):
 *   durchgespielt         — Level beendet
 *   allePruefsummen       — Sammelziel voll erfüllt
 *   lueckenlosesProtokoll — kein einziges Mal von einem Lauscher gesehen
 *
 * Phaser-frei und uhrenfrei → vollständig unter Node testbar.
 */

export interface ProtokollEintrag {
  levelId: string
  /** Wer zugegriffen hat, in-fiction (z. B. „Lauscher", „Prüfpforte"). */
  akteur: string
  /** Was passiert ist (z. B. „hat dich gesehen"). */
  aktion: string
  tMs: number
}

export interface Siegel {
  durchgespielt: boolean
  allePruefsummen: boolean
  lueckenlosesProtokoll: boolean
}

/** Kiosk-Betrieb: Das Protokoll darf nie unbegrenzt wachsen. */
export const MAX_EINTRAEGE = 200

export class Protokoll {
  private eintraege: ProtokollEintrag[] = []
  private gesehenIn = new Set<string>()
  private abgeschlossen = new Set<string>()

  reset(): void {
    this.eintraege = []
    this.gesehenIn.clear()
    this.abgeschlossen.clear()
  }

  /** Kopie der Einträge (älteste zuerst). */
  get entries(): ProtokollEintrag[] {
    return [...this.eintraege]
  }

  get length(): number {
    return this.eintraege.length
  }

  note(levelId: string, akteur: string, aktion: string, tMs: number): void {
    this.eintraege.push({ levelId, akteur, aktion, tMs })
    if (this.eintraege.length > MAX_EINTRAEGE) {
      this.eintraege.splice(0, this.eintraege.length - MAX_EINTRAEGE)
    }
  }

  /** Ein Lauscher hat den Spieler im Klartext erwischt. */
  markGesehen(levelId: string, tMs: number, akteur = 'Lauscher'): void {
    this.gesehenIn.add(levelId)
    this.note(levelId, akteur, 'hat dich im Klartext gesehen', tMs)
  }

  wasGesehen(levelId: string): boolean {
    return this.gesehenIn.has(levelId)
  }

  /** Wurde der Spieler im ganzen Durchlauf nie gesehen? */
  get lueckenlosGesamt(): boolean {
    return this.gesehenIn.size === 0
  }

  markAbgeschlossen(levelId: string, tMs: number): void {
    this.abgeschlossen.add(levelId)
    this.note(levelId, 'du', 'hast die Station abgeschlossen', tMs)
  }

  /** Siegel eines Levels. `bits`/`bitsRequired` kommen aus dem GameState. */
  siegel(levelId: string, opts: { bits: number; bitsRequired: number }): Siegel {
    return {
      durchgespielt: this.abgeschlossen.has(levelId),
      allePruefsummen: opts.bitsRequired > 0 && opts.bits >= opts.bitsRequired,
      lueckenlosesProtokoll: this.abgeschlossen.has(levelId) && !this.gesehenIn.has(levelId),
    }
  }

  /** Anzahl erreichter Siegel über alle bewerteten Level. */
  static zaehle(siegel: Siegel[]): number {
    let n = 0
    for (const s of siegel) {
      if (s.durchgespielt) n += 1
      if (s.allePruefsummen) n += 1
      if (s.lueckenlosesProtokoll) n += 1
    }
    return n
  }
}

export const protokoll = new Protokoll()
