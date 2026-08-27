# Der ePA-Wissenspfad — Lehrsequenzen zur „ePA für alle"

**Stand der Fakten: August 2026.** Die ePA entwickelt sich weiter (KAPSEL:
Erklärinhalte mit Versionsdatum versehen) — vor Messen gegen
gematik.de/anwendungen/epa-fuer-alle gegenprüfen.

## Was es ist

Vier animierte Lehrsequenzen (`src/gfx/wissen.ts`, Szene `Wissen`) ersetzen
vor den vier ePA-Stationen den City-Lauf. Machart wie das Zeitreise-Intro:
statische Bühne, Leben als Funktion der Zeit, Schrittzeilen im Takt,
Mindest-Anzeigedauer. Ziel: Wer das Spiel durchspielt, kennt die Grundzüge
der ePA-für-alle-Architektur — nicht als Text, sondern als Bilder.

| Vor Station | Sequenz | Kernbotschaft |
|---|---|---|
| 13 E-Rezept | `epa-konto` | Opt-out: jeder bekommt die Akte automatisch, Widerspruch jederzeit; die Akte liegt im Aktensystem (Rechenzentrum), die eGK ist nur der Schlüssel |
| 14 Die VAU | `epa-medikation` | E-Rezept-Daten fließen automatisch in die Medikationsliste — die einzige Automatik; Nutzen: AMTS/Wechselwirkungen |
| 19 Berechtigungen | `epa-befugnis` | Kartenstecken erteilt Befugnis auf Zeit: Praxis 90 Tage, Apotheke 3 Tage (Standard); die ePA-App verlängert, verkürzt, entzieht |
| 20 Souveränität | `epa-souveraen` | Zugriffsprotokoll (3 Jahre einsehbar); Dokumente verbergen/löschen, ohne dass das Fehlen erkennbar ist; Widerspruch → Kasse löscht alles |

## Fachliche Belege

- **Opt-out seit 15.01.2025** (DigiG): Kassen legen automatisch an,
  6-wöchige Widerspruchsfrist im Anschreiben, Widerspruch jederzeit auch
  später (App oder Ombudsstelle der Kasse); bei Widerspruch löscht die
  Kasse Akte samt Daten. — gematik FAQ ePA für alle; docs/KAPSEL.md F.
- **Aktensystem/VAU**: Die ePA ist ein reines Backend („Aktensystem") in
  gesicherten Rechenzentren; sämtliche Ver-/Entschlüsselung geschieht in
  der VAU — weder Betreiber noch Kasse können mitlesen (Attestierung von
  VAU-Software und -Hardware gegen das HSM). — gematik Fachkonzept
  ePA für alle; Fraunhofer-SIT-Prüfung des Sicherheitskonzepts.
- **Befugnisse**: Behandlungskontext durch Stecken der eGK; Standard
  90 Tage für Praxen/Krankenhäuser, 3 Kalendertage für Apotheken
  (Stecktag + 2); per ePA-App verkürz-, verlänger- (bis unbegrenzt) und
  entziehbar. — gematik „ePA für alle" Praxen-Folien; KBV; DKG-Umsetzungshinweise.
- **Medikationsliste (eML)**: wird automatisch aus E-Rezept-Verordnungs-
  und Dispensier-Daten befüllt — laut gematik die einzige automatische
  Befüllung der Akte; alles andere stellen Behandelnde ein. — gematik;
  KAPSEL 1.4 („eGK speichert Befunde nicht", „ePA-Rechte korrekt darstellen").
- **Protokoll & Granularität**: jeder Zugriff wird protokolliert, drei
  Jahre einsehbar; Dokumente lassen sich verbergen/wieder einblenden/
  löschen — für Praxen ist nicht erkennbar, dass etwas verborgen wurde;
  Abrechnungsdaten der Kasse sind separat widerspruchsfähig; Vertreter
  können benannt werden. — gematik Widerspruchs-FAQ; KBV; vdek-FAQ.

## Leitplanken (dürfen nie verletzt werden)

Zusätzlich zu den drei Hülle-Leitplanken aus CLAUDE.md:
1. Die eGK ist Schlüssel, kein Speicher — die Akte liegt NIE „auf der Karte".
2. Nichts lädt automatisch hoch — einzige Ausnahme: E-Rezept-Daten → eML.
3. Verbergen ist unsichtbar — Praxen sehen nicht, DASS etwas fehlt.
4. Widerspruch ist vollständig und folgenlos darstellbar — keine Angstbilder,
   keine Abwertung der Entscheidung („Deine Wahl").

## Einbau-Regeln

- Zuordnung Station → Sequenz: `WISSEN_VOR_LEVEL` in `src/gfx/wissen.ts`.
  Übergänge ohne Eintrag behalten den City-Lauf (Blau-Knopf-Übung!).
- Jede Sequenz: EINE Kernbotschaft, vier Schrittzeilen, 20–22 s Zyklus,
  Mindestdauer 13–15 s, kein Blinken über 3 Hz (Barrierefreiheit).
- Neue Sequenz = neuer Eintrag in `VIGNETTEN` + `WISSEN_SPERRE` +
  `WISSEN_VOR_LEVEL`; Szene und Gerüst bleiben unverändert.
