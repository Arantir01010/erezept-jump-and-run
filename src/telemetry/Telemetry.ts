/**
 * TELEMETRIE-SAMMLER (KAPSEL 4.4) — Phaser-frei und uhrenfrei.
 *
 * Alle Zeiten kommen von außen herein (die Szenen kennen `scene.time.now`),
 * damit dieses Modul unter Node vollständig prüfbar ist.
 *
 * Kiosk-Sicherheit: Die Liste ist gedeckelt. Ein Messetag mit hunderten
 * Durchläufen darf den Speicher nicht volllaufen lassen.
 */
import { istTelemetrieTyp, type TelemetrieEvent, type TelemetrieTyp } from './events'

/** Mehr Ereignisse braucht kein Durchlauf — ältere fallen heraus. */
export const MAX_EVENTS = 500

export class Telemetry {
  private events: TelemetrieEvent[] = []
  private aktivesLevel = ''
  /** Zufällige, nicht personenbezogene Kennung EINES Durchlaufs. */
  sitzung = ''
  /** Abschaltbar (Messebetrieb ohne Auswertung). */
  aktiv = true

  constructor(aktiv = true) {
    this.aktiv = aktiv
    this.neueSitzung()
  }

  /** Neuer Durchlauf: leere Liste, neue Zufallskennung. */
  neueSitzung(): void {
    this.events = []
    this.aktivesLevel = ''
    this.sitzung = Math.random().toString(36).slice(2, 10)
  }

  get anzahl(): number {
    return this.events.length
  }

  /** Kopie aller Ereignisse (älteste zuerst). */
  alle(): TelemetrieEvent[] {
    return [...this.events]
  }

  /** Merkt das laufende Level, damit Aufrufer es nicht mitschleppen müssen. */
  setLevel(levelId: string): void {
    this.aktivesLevel = levelId
  }

  /**
   * Ereignis erfassen. Unbekannte Typen werden verworfen (statt zu werfen):
   * Telemetrie darf im Messebetrieb NIE ein Spiel abbrechen.
   */
  note(typ: TelemetrieTyp, tMs: number, wert?: string, levelId?: string): void {
    if (!this.aktiv) return
    if (!istTelemetrieTyp(typ)) return
    const event: TelemetrieEvent = { typ, levelId: levelId ?? this.aktivesLevel, tMs }
    if (wert !== undefined) event.wert = wert
    this.events.push(event)
    if (this.events.length > MAX_EVENTS) {
      this.events.splice(0, this.events.length - MAX_EVENTS)
    }
  }

  /** Ereignisse eines Levels (für die Kennzahlen). */
  imLevel(levelId: string): TelemetrieEvent[] {
    return this.events.filter((e) => e.levelId === levelId)
  }

  zaehle(typ: TelemetrieTyp, levelId?: string): number {
    return this.events.filter((e) => e.typ === typ && (levelId === undefined || e.levelId === levelId)).length
  }

  /** Exportformat: flach, selbsterklärend, ohne Personenbezug. */
  toJSON(): { sitzung: string; version: number; events: TelemetrieEvent[] } {
    return { sitzung: this.sitzung, version: 1, events: this.alle() }
  }
}

export const telemetry = new Telemetry()
