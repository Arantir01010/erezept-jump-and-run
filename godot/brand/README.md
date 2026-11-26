# Marke: PwC-Erscheinungsbild im Spiel

Das Spiel bleibt inhaltlich das gematik-/TI-Lernspiel „Paul & Rezi". **Markenkonform sind
Schrift, Schreibweise und Farben** — seit 11/2026 auch die Spielgrafik (Welten, Kulissen,
Bausteine, Info-Screens). Grundlage: das PwC Digital Colour System (brand.pwc.com › Colour
system, Light/Dark mode und volle Palette) und die Referenz-Präsentationen im PwC-Stil.

Drei Regeln, die Tests absichern (`tests/test_marke.gd`):

1. **Jede feste Farbe ist eine Stufe des Farbsystems.** Einzige Ausnahme ist das Violett der
   VAU (`Palette.VAU…`): fachliche Kodierung, das Farbsystem kennt kein Violett. Zeilen mit
   Landesfarben (Sprachflaggen) tragen den Kommentar `# farbe-frei`.
2. **Kein Text in durchgehenden Großbuchstaben** — in keiner der sechs Sprachen. Abkürzungen
   bleiben, was sie sind (TI, VAU, PIN, SMC-B, eGK, ePA). Der Begleiter heißt im Text „Rezi".
3. **Zwei Schriftfamilien:** ITC Charter für Überschriften, Helvetica Neue für alles andere.

Alles Marken-Wissen sitzt an einer Stelle: [`src/core/Brand.gd`](../src/core/Brand.gd).

Prompt-Vorlage für KI-Werkzeuge im PwC-Look (Tokens, Schriften, Verbotsliste):
[`DESIGN-PROMPT.md`](DESIGN-PROMPT.md).

## Was aus dem Brand-Paket übernommen wurde

Das gelieferte Paket (`ITCCharter_Webfonts_July2024`, Helvetica Neue Desktop/Web, ITC Charter
Desktop/Web, PwC-Werte-Piktogramme) liegt vollständig in
`archive/brand-quelle_ITCCharter-HelveticaNeue-PwC-Piktogramme_July2024.zip`.
Ins Projekt übernommen sind nur die Dateien, die das Spiel braucht:

| Ziel | Inhalt |
|---|---|
| `assets/fonts/` | Helvetica Neue LT Pro: Light, Roman, Italic, Medium, Bold, Heavy · ITC Charter Com: Regular, Italic, Bold, Bold Italic (OpenType TTF) |
| `assets/brand/pictograms/` | die fünf PwC-Werte-Piktogramme in Weiß und Schwarz (`care`, `act-with-integrity`, `make-a-difference`, `work-together`, `reimagine-the-possible`) |
| `brand/lizenz/` | Monotype-EULAs, Trademark-Hinweise, Font-Listen, Metadaten |

Web-Font-Formate (woff/woff2/eot/svg) werden nicht gebraucht: Godot bettet die TTF in den
Build ein — auch in die Browser-Fassung.

## Typografie

| Rolle | Schrift | Wo |
|---|---|---|
| Große Überschriften | **ITC Charter Bold** | Titel „Das e-Rezept", Screen-Überschriften (Früher, Heute, So spielst du, ePA-Wissen), Stationsname beim Levelstart und auf der Stationskarte, „Dein e-Rezept ist da!" |
| Alles Lesbare | **Helvetica Neue Roman** | Fließtext, Erzählzeilen, Hinweise, Sprechblasen |
| Betonung, Schilder, Pillen | **Helvetica Neue Medium** | HUD-Pillen, Eyebrows („Station 3 / 10", „Tages-Bestenliste"), Tastenkappen, Schilder der Kulisse |
| Stempel, Knöpfe | **Helvetica Neue Bold / Heavy** | „Zugriff verweigert", Hülle-Anzeige, Touch-Knöpfe, Kombo |

Geschrieben wird in normaler Groß-/Kleinschreibung. Weil gemischte Schreibung keine weite
Sperrung verträgt, dämpft `Brand.spaced()` den Buchstabenabstand (höchstens 2 px).

Die Info-Screens (`src/ui/Vignette.gd`) bilden das Original der Web-Fassung nach, das mit
Schriftgewicht 600 lief — deshalb steht dort „bold" für Helvetica Neue *Medium*, nicht Bold.

## Farben

Die volle Palette steht in `Brand.gd` (Orange, Grey, Blue, Success, Warning, Red, Tangerine,
je Stufe 50–1000). Stufen, die die Referenz-Präsentationen als Token führen, sind von dort
übernommen; die übrigen sind aus der Farbsystem-Übersicht abgelesen (±1–2 je Farbkanal) und
sollten vor einer formalen Abnahme gegen brand.pwc.com geprüft werden.

**UI (Dark mode des Farbsystems)**

| Rolle | Farbe |
|---|---|
| Primär / Fortschritt (`UI_ACCENT_STRONG`) | Orange 500 `#FD5108`, Text darauf Weiß |
| Aufforderung / Hervorhebung / Eyebrow (`UI_ACCENT`) | Orange 300 `#FFAA72` (Brand Variant) |
| Auszeichnung, Medaillen, Bestwert (`UI_HIGHLIGHT`) | Tangerine 400 `#FFC21B` |
| Status | Info Blue 300 · Success 400 · Warning 300 · Error Red 400 |
| Flächen (`UI_PANEL`) | Grey 975 `#202124`, Kante Grey 700, Rundung 2 px |
| Text | Grey 50, gedämpft Grey 300, stumm Grey 600 |

**Spielwelt** (`src/core/Palette.gd`)

| Bedeutung | Farbe |
|---|---|
| Klartext, offen (`WARM`) | Tangerine 500 `#FF9F00` |
| Verschlüsselt (`COOL`), Prüfsummen, Rezi | Blue 400 `#356FEC` / Blue 300 |
| VAU | Violett `#9470F5` — die eine Ausnahme |
| Verweigert, Störfeld (`DENY`) | Red 400 `#ED4242` |
| Erlaubt, geprüft (`OK`) | Success 400 `#18AE80` |
| Bonus, Siegel (`GOLD`) | Tangerine 400 `#FFC21B` |
| Paul | Hoodie Orange 500 |

Bauprinzip der fünf Welten: **Grey trägt die Struktur** (Gelände, Häuser, Nebel), der Himmel
kommt aus Blue, Orange und Tangerine, je Welt gibt es einen Akzent. Die Stimmung (Morgen,
Abend, Regen, Halle, Archiv) entsteht aus der Stufenwahl und der Farbstimmung im Post-Effekt,
nicht aus freien Farbtönen. Die Info-Screens spielen in einer Nacht aus Grey 1000 → Blue 950.

## Piktogramme

Die Werte-Piktogramme sind über `Brand.pictogram("reimagine-the-possible")` abrufbar.
Genutzt wird derzeit die Glühbirne vor der Hinweiszeile im HUD. Sie stehen für weitere
UI-Stellen bereit (z. B. Karten, Reward), sind aber keine Spielinhalte.

## Fallback

Fehlen die Schriftdateien (frischer Checkout ohne Brand-Paket), meldet `Brand.gd` einmal
eine Warnung und nutzt die Godot-Standardschrift — das Spiel läuft unverändert. Zum
Nachrüsten: das Quellpaket aus `archive/` entpacken und
`python godot/tools/aufraeumen.py` laufen lassen, oder die TTF-Dateien von Hand nach
`assets/fonts/` kopieren (Dateinamen wie in `Brand.SANS`/`Brand.SERIF`).

## Lizenz — bitte vor der Auslieferung klären

Die beiliegenden Monotype-EULAs (`brand/lizenz/`) sind **Desktop-Lizenzen**: Sie erlauben
die Nutzung auf lizenzierten Arbeitsplätzen und das Einbetten in Dokumente, die kein
kommerzielles Produkt sind (Abschnitt 3 „Embedding"). Das Einbetten der Schriftdateien in
eine ausgelieferte **Anwendung** (Windows-EXE/PCK, Browser-Build) ist darin nicht
ausdrücklich abgedeckt — dafür gibt es bei Monotype eine App-/Game-Lizenz, die PwC über
seinen Unternehmensvertrag möglicherweise schon hat. Deshalb:

- Schriftdateien und Piktogramme sind per `.gitignore` **vom öffentlichen Repository
  ausgeschlossen** (`assets/fonts/`, `assets/brand/`, `brand/lizenz/`).
- Vor einer Weitergabe des Spiels an Dritte (Messebesucher, Download) die Einbettung mit
  dem Brand-/Lizenz-Team klären. Für interne Vorführungen auf PwC-Rechnern ist das
  Desktop-Recht ausreichend.
