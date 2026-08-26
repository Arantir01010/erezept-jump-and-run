# Paket B1 — Kartenstecken: der Kern
(enthält alle vorherigen Pakete · 384/384 Tests grün)

Erstes von mehreren kleinen Paketen für Zusatzmechanik 1 aus KAPSEL 2.1:
„eGK/SMC-B als Schalter, der Tore/Sessions öffnet — verbindet Bewegung mit
Identität."

Bewusst NUR die Zustandsmaschine. Kein Phaser, keine Grafik, keine Level —
erst wenn das Modell fachlich und logisch stimmt, wird es verdrahtet. Dasselbe
Vorgehen wie bei der Hülle (Paket 1) und der Eingabe (Paket 2), und es hat sich
beide Male bewährt.

## Neu
| Datei | Inhalt |
|---|---|
| `src/state/KartenState.ts` | Besitz, Stecken, Ziehen, Ereignisse |
| `tools/test/karten.test.ts` | 31 Tests |

## Die drei Karten (KAPSEL 1.1)
| Karte | Wer | Rolle im Spiel |
|---|---|---|
| **eGK** | Versicherte | Schlüssel, der den Zugriff freigibt |
| **HBA** | Heilberuf | persönliche Identität eines Menschen |
| **SMC-B** | Einrichtung | authentisiert die Praxis/Apotheke |

Gerätekarten (gSMC-KT/gSMC-K) fehlen absichtlich: Sie stecken in der Wirklichkeit
dauerhaft im Gerät und wären als Spielobjekt sinnlos.

## Die fachlichen Leitplanken sind im Modell verankert
KAPSEL 1.4 nennt „eGK speichert Befunde nicht" als Vereinfachungsfehler. Das ist
hier keine Kommentarzeile, sondern eine Eigenschaft des Modells:

- **Die Karte kennt keine Inhalte.** Eine Karte hat `kurz` und `wer` — Identität,
  keine Daten. Ein Test schlägt an, wenn jemand später ein Inhaltsfeld ergänzt.
- **Ziehen beendet den Zugriff sofort.** Kein Nachlauf, kein Restzugriff. Es kann
  nichts zurückbleiben, weil nie etwas auf der Karte lag.
- **Keine Rolle ersetzt eine andere.** Die eGK öffnet die Apotheke, aber nicht den
  Praxiszugang. Zwei Rollen, zwei Karten.
- **Dieses Modul signiert nichts.** Ein Test prüft, dass keine Methode nach
  Signatur/QES/Stempel heißt — signiert wird per `stamp-exit`
  (Verschlüsselung ≠ Signatur).

## Vier Entscheidungen aus dem Spielgefühl
1. **Vier klar unterschiedene Ergebnisse** statt „geht/geht nicht":
   `ok` · `nicht-dabei` (Karte fehlt) · `falsche-karte` (ZUGRIFF VERWEIGERT) ·
   `belegt` (anderes Terminal aktiv). Jedes verlangt einen anderen REZI-Tipp —
   „du hast sie noch nicht" ist etwas anderes als „die passt hier nicht".
2. **Ein Terminal hat einen Schlitz.** Wer woanders stecken will, muss erst
   ziehen. Das macht die Sitzung körperlich spürbar.
3. **Mehrfaches Drücken bestraft nicht.** Dieselbe Karte am selben Terminal
   erneut zu stecken ergibt `ok`. Am Arcade-Automaten wird gehämmert.
4. **`steckePassende()` wählt automatisch.** Am Terminal steht sinngemäß „Karte
   stecken", nicht „wähle Karte 2 von 3". Bei mehreren Möglichkeiten gewinnt die
   erste vom Terminal erlaubte — vorhersehbar fürs Leveldesign.

## Abnahme
| Prüfung | Ergebnis |
|---|---|
| Tests, 17 Suiten | 384/384 grün |
| Level-Pipeline, 4 Level | 0 Fehler, 0 Warnungen, 0 veraltet |
| Spielkern-Guard | konsistent |
| TS-Parser über alle Dateien | 0 Syntaxfehler |

## Als Nächstes
- **B2**: Kartenleser-Baustein + Karten-Sammelobjekt (Phaser) + Textur
- **B3**: Katalog + Compiler-Regeln (Terminal ohne passende Karte im Level = Fehler)
- **B4**: HUD-Anzeige der Karten, Telemetrie-Ereignisse
- **B5**: Level „Das Kartenterminal" (KAPSEL Level 4, Welt 1 Twist)
