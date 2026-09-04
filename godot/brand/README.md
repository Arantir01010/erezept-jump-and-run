# Marke: PwC-Erscheinungsbild im Spiel

Das Spiel bleibt inhaltlich das gematik-/TI-Lernspiel „Paul & REZI". **Markenkonform
werden Schrift und Bedienelemente** — nicht die Spielgrafik (Welten, Paul, REZI, Klinikum)
und nicht die fachlichen Farben der Hülle (warm = offen, kühl = verschlüsselt, violett = VAU).

Alles Marken-Wissen sitzt an einer Stelle: [`src/core/Brand.gd`](../src/core/Brand.gd).

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
| Große Überschriften | **ITC Charter Bold** | Titel „Das e-Rezept", Screen-Header (FRÜHER, HEUTE, SO SPIELST DU, ePA-Wissen), Stationsname beim Levelstart und auf der Stationskarte, „Dein e-Rezept ist da!" |
| Alles Lesbare | **Helvetica Neue Roman** | Fließtext, Erzählzeilen, Hinweise, Sprechblasen |
| Betonung, Schilder, Pillen | **Helvetica Neue Medium** | HUD-Pillen, Eyebrows („STATION 3 / 10", „TAGES-BESTENLISTE"), Tastenkappen, Schilder der Kulisse |
| Stempel, Knöpfe | **Helvetica Neue Bold / Heavy** | „ZUGRIFF VERWEIGERT", Hülle-Anzeige, Touch-Knöpfe, Kombo |

Die Info-Screens (`src/ui/Vignette.gd`) bilden das Original der Web-Fassung nach, das mit
Schriftgewicht 600 lief — deshalb steht dort „bold" für Helvetica Neue *Medium*, nicht Bold.

## Farben (UI-Rollen)

PwC-Palette in `Brand.gd`: Orange `#D04A02`, Tangerine `#EB8C00`, Yellow `#FFB600`,
Red `#E0301E`, Rose `#D93954`, Maroon `#822720`, Schwarz, Graustufen `#2D2D2D`, `#464646`,
`#7D7D7D`, `#DEDEDE`, `#F2F2F2`, Weiß.

| Rolle | Farbe |
|---|---|
| Aufforderung / Hervorhebung (`UI_ACCENT`) | Tangerine — auf dunklem Grund lesbarer als Orange |
| Primär / Fortschritt (`UI_ACCENT_STRONG`) | Orange |
| Erfolg, Medaillen, Bestwert (`UI_HIGHLIGHT`) | Yellow |
| Flächen (`UI_PANEL`) | Dunkelgrau `#2D2D2D` mit 86 % Deckung, feine weiße Kante, Rundung 6 px |
| Text | Weiß, gedämpft `#DEDEDE`, stumm `#7D7D7D` |

Nicht angetastet: Hülle-Farben (`Palette.WARM/COOL/VAU`), Welten-Paletten, das
Nacht-Blau des Hauptmenüs, Gold der Prüfsummen/Siegel im Spielfeld.

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
