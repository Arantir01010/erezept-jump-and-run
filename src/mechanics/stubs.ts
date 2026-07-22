import { Mechanic } from './Mechanic'
import { registerMechanic } from './registry'

/**
 * Module der Ausbaustufe: Schnittstelle steht, Umsetzung folgt nach
 * Prototyp-Freigabe (siehe docs/KONZEPT.md, Level-Schablone).
 * Ein Stub loggt einmalig und stört den Messebetrieb nie.
 */
class StubMechanic extends Mechanic {
  spawn(): void {
    console.warn(
      `[mechanics] Modul "${this.obj.type}" ist im Prototyp noch nicht enthalten (Level "${this.host.level.id}") — Objekt wird ignoriert`,
    )
  }
}

registerMechanic('pruef-scanner', StubMechanic) // Setpiece: Echtes passiert, Fake wird aussortiert (Fachdienst)
registerMechanic('rechte-tueren', StubMechanic) // Schlüssel-Puzzle + Spielerentscheidung (e-Rezept Akte / ePA)
registerMechanic('finale-sprint', StubMechanic) // Zielsprint + Kopie-Twist + QR-Payoff (Apotheke)
registerMechanic('vervollstaendigen', StubMechanic) // Objekte sammeln bis Ausgang öffnet (Versichertenstammdaten)
