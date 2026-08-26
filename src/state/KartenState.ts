/**
 * KARTEN STECKEN — Zusatzmechanik 1 (KAPSEL 2.1, ab Welt 2).
 *
 * „eGK/SMC-B als Schalter, der Tore/Sessions öffnet — verbindet Bewegung mit
 * Identität." Der Spieler sammelt Karten und steckt sie an Terminals; das
 * passende Terminal öffnet ein Tor.
 *
 * FACHLICHE LEITPLANKEN (KAPSEL 1.4) — hier ist die wichtigste dieses Moduls:
 *
 *   Die eGK ist ein SCHLÜSSEL, kein Datenspeicher. Sie „trägt" keine Befunde.
 *   Deshalb kennt dieses Modul bewusst KEINE Daten auf der Karte — nur Identität
 *   und Zugriff. Und daraus folgt die zweite Konsequenz: Zieht man die Karte,
 *   endet der Zugriff SOFORT. Es bleibt nichts zurück, weil nie etwas auf der
 *   Karte lag. Genau das prüfen die Tests.
 *
 *   Verschlüsselung ≠ Signatur: Der HBA kann fachlich signieren (QES), aber das
 *   ist eine EIGENE Aktion (stamp-exit). Dieses Modul öffnet nur Zugänge.
 *
 * Phaser-frei und uhrenfrei → unter Node vollständig testbar.
 */

/**
 * Die drei Identitäten aus KAPSEL 1.1, die sich spielerisch unterscheiden.
 * Bewusst nur diese drei: Gerätekarten (gSMC-KT/gSMC-K) stecken in der
 * Wirklichkeit dauerhaft im Gerät und wären als Spielobjekt sinnlos.
 */
export enum Karte {
  /** elektronische Gesundheitskarte — Versicherte, Schlüssel für den Zugriff */
  EGK = 'egk',
  /** Heilberufsausweis — persönliche Identität eines Menschen */
  HBA = 'hba',
  /** Institutionskarte (Praxisausweis) — authentisiert die Einrichtung */
  SMCB = 'smcb',
}

export const ALLE_KARTEN: readonly Karte[] = [Karte.EGK, Karte.HBA, Karte.SMCB]

/** Anzeigename und Kurzbeschreibung — für HUD und Fehlermeldungen. */
export const KARTEN_INFO: Record<Karte, { kurz: string; wer: string }> = {
  [Karte.EGK]: { kurz: 'eGK', wer: 'Versicherte' },
  [Karte.HBA]: { kurz: 'HBA', wer: 'Heilberuf' },
  [Karte.SMCB]: { kurz: 'SMC-B', wer: 'Einrichtung' },
}

/** Warum ein Steckversuch nicht geklappt hat (für REZI-Tipps und HUD). */
export type SteckResultat =
  | 'ok'
  /** Der Spieler hat diese Karte noch nicht gefunden. */
  | 'nicht-dabei'
  /** Das Terminal akzeptiert diese Karte nicht (ZUGRIFF VERWEIGERT). */
  | 'falsche-karte'
  /** Es steckt schon eine Karte — ein Terminal hat genau einen Schlitz. */
  | 'belegt'

export type KartenChangeReason = 'reset' | 'gefunden' | 'gesteckt' | 'gezogen' | 'abgelehnt'

export interface KartenChange {
  reason: KartenChangeReason
  karte?: Karte
  /** Terminal, an dem es passierte (bei 'gesteckt' / 'gezogen' / 'abgelehnt'). */
  terminalId?: string
}

export class KartenState {
  /** Gefundene Karten. Karten werden nie verbraucht — ein Ausweis bleibt beim Besitzer. */
  private besitz = new Set<Karte>()
  private gesteckteKarte: Karte | null = null
  private gesteckesTerminal = ''
  private listeners: ((c: KartenChange) => void)[] = []

  // ------------------------------------------------------------------ Lesen

  hat(karte: Karte): boolean {
    return this.besitz.has(karte)
  }

  /** Alle gefundenen Karten in fester Reihenfolge (HUD-Anzeige). */
  get gefunden(): Karte[] {
    return ALLE_KARTEN.filter((k) => this.besitz.has(k))
  }

  get anzahl(): number {
    return this.besitz.size
  }

  /** Welche Karte steckt gerade? `null` = keine. */
  get gesteckt(): Karte | null {
    return this.gesteckteKarte
  }

  /** Steckt an DIESEM Terminal eine Karte? */
  istGestecktAn(terminalId: string): boolean {
    return this.gesteckteKarte !== null && this.gesteckesTerminal === terminalId
  }

  /** Läuft irgendwo eine Sitzung? (Die Karte hält sie offen.) */
  get sitzungOffen(): boolean {
    return this.gesteckteKarte !== null
  }

  // ------------------------------------------------------------------ Ändern

  reset(): void {
    this.besitz.clear()
    this.gesteckteKarte = null
    this.gesteckesTerminal = ''
    this.emit({ reason: 'reset' })
  }

  /** Karte aufsammeln. `false`, wenn der Spieler sie schon hatte. */
  nimm(karte: Karte): boolean {
    if (this.besitz.has(karte)) return false
    this.besitz.add(karte)
    this.emit({ reason: 'gefunden', karte })
    return true
  }

  /**
   * Karte an einem Terminal stecken.
   *
   * `erlaubt` sind die Kartenarten, die dieses Terminal akzeptiert — sie kommen
   * aus dem Level, nie aus dem Code. Ein Terminal, das nur die SMC-B akzeptiert,
   * lehnt die eGK ab: „ZUGRIFF VERWEIGERT". Das ist die Lehre, nicht die Strafe.
   */
  stecke(karte: Karte, terminalId: string, erlaubt: readonly Karte[]): SteckResultat {
    if (this.gesteckteKarte !== null) {
      // Dieselbe Karte am selben Terminal erneut zu stecken ist kein Fehler …
      if (this.gesteckteKarte === karte && this.gesteckesTerminal === terminalId) return 'ok'
      return 'belegt'
    }
    if (!this.besitz.has(karte)) {
      this.emit({ reason: 'abgelehnt', karte, terminalId })
      return 'nicht-dabei'
    }
    if (!erlaubt.includes(karte)) {
      this.emit({ reason: 'abgelehnt', karte, terminalId })
      return 'falsche-karte'
    }
    this.gesteckteKarte = karte
    this.gesteckesTerminal = terminalId
    this.emit({ reason: 'gesteckt', karte, terminalId })
    return 'ok'
  }

  /**
   * Erste passende Karte aus dem Besitz stecken (Komfort für die Spielfigur:
   * am Terminal steht sinngemäß „Karte stecken", nicht „wähle Karte 2 von 3").
   * Liefert das Resultat des Versuchs — bei leerem Besitz 'nicht-dabei'.
   */
  steckePassende(terminalId: string, erlaubt: readonly Karte[]): SteckResultat {
    if (this.gesteckteKarte !== null) {
      return this.gesteckesTerminal === terminalId && erlaubt.includes(this.gesteckteKarte) ? 'ok' : 'belegt'
    }
    const passend = erlaubt.find((k) => this.besitz.has(k))
    if (passend !== undefined) return this.stecke(passend, terminalId, erlaubt)
    // Nichts Passendes dabei: Wenn der Spieler überhaupt keine Karte hat, ist
    // das 'nicht-dabei'; hat er Karten, passt nur keine → 'falsche-karte'.
    const ergebnis: SteckResultat = this.besitz.size === 0 ? 'nicht-dabei' : 'falsche-karte'
    this.emit({ reason: 'abgelehnt', terminalId })
    return ergebnis
  }

  /**
   * Karte ziehen. Der Zugriff endet SOFORT — die Karte war ein Schlüssel, kein
   * Speicher, es bleibt also nichts zurück (KAPSEL 1.4). `false`, wenn keine
   * Karte steckte.
   */
  zieh(): boolean {
    if (this.gesteckteKarte === null) return false
    const karte = this.gesteckteKarte
    const terminalId = this.gesteckesTerminal
    this.gesteckteKarte = null
    this.gesteckesTerminal = ''
    this.emit({ reason: 'gezogen', karte, terminalId })
    return true
  }

  // ------------------------------------------------------------------ Events

  onChange(listener: (c: KartenChange) => void): () => void {
    this.listeners.push(listener)
    return () => {
      this.listeners = this.listeners.filter((l) => l !== listener)
    }
  }

  private emit(change: KartenChange): void {
    for (const l of [...this.listeners]) l(change)
  }
}

export const kartenState = new KartenState()
