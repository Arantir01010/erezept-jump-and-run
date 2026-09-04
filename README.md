# Paul & REZI — Das e-Rezept Jump 'n' Run

Ein Lernspiel über den Weg des **e-Rezepts** durch die **Telematikinfrastruktur (TI)**:
Paul begleitet sein e-Rezept **REZI** vom Arztbesuch bis zur Apotheke — an jeder Station
legt die TI sichtbar einen neuen Schutz an. Angreifer werden nie bekämpft: Sie scheitern
komisch an Signatur, Verschlüsselung und Zugriffskontrolle. **„ZUGRIFF VERWEIGERT."**

Gebaut für einen Messestand (TV, Arcade-Joystick, zwei Knöpfe, QR-Code als Gewinn),
spielbar aber genauso am Laptop, im Browser und per Touch auf dem Tablet.

## Zwei Fassungen in einem Repository

| | **Godot-Fassung** (aktueller Stand) | **Phaser-Fassung** (Ursprung) |
|---|---|---|
| Ordner | [`godot/`](godot/) | Stammverzeichnis: `src/`, `design/`, `public/`, `tools/`, `docs/` |
| Stand | Neuaufbau seit 02.09.2026: neue Bewegung (Celeste-Physik), fünf Farbwelten, zehn neu gebaute Level, Hauptmenü-Klinikum, Zeitreise, Probelauf, ePA-Wissen, Touch, Windows- **und** Browser-Build, PwC-Erscheinungsbild; **live auf GitHub Pages** (Branch `web`) | Fertig und **versiegelt** (SHA-256-Kern-Guard); Level-Baukasten in `design/`, Playtest-Werkzeuge; der GitHub-Actions-Deploy ist deaktiviert (die Workflow-Datei bleibt, sie steht im Kern-Manifest) |
| Weiterarbeiten | **hier** — Inhalte, Grafik, Wissensvermittlung | nur Level-Inhalte über `design/` (siehe `CLAUDE.md`) |
| Start | `godot/build/Paul und REZI.lnk` · Browser: `godot/build-web/Start im Browser.bat` | `npm run dev` → http://localhost:5173 |
| Doku | [`godot/README.md`](godot/README.md), [`godot/docs/ANALYSE-UND-KONZEPT.md`](godot/docs/ANALYSE-UND-KONZEPT.md) | [`docs/KONZEPT.md`](docs/KONZEPT.md), [`design/LEVELBAU.md`](design/LEVELBAU.md) |

Die fachlichen Grundlagen gelten für beide Fassungen: [`docs/KONZEPT.md`](docs/KONZEPT.md)
(Stationen, TI-Fachlichkeit, Messebetrieb), [`docs/KAPSEL.md`](docs/KAPSEL.md)
(Regeln, die nicht verletzt werden dürfen), [`docs/EPA-WISSENSPFAD.md`](docs/EPA-WISSENSPFAD.md)
(die ePA-Lehrsequenzen mit Quellen), [`docs/PLAYTEST.md`](docs/PLAYTEST.md).

## Ordnerstruktur

```
├── godot/            Godot-4.7-Fassung (siehe godot/README.md)
│   ├── src/          Spiellogik (GDScript) · src/core/Brand.gd = PwC-Schrift und UI-Farben
│   ├── levels/       zehn Godot-eigene Level (layout.txt + level.json)
│   ├── assets/       generierte Klänge/QR · fonts/ und brand/ (lizenziert, nicht im Repo)
│   ├── brand/        Marken-Regeln (README) + Lizenzdokumente
│   ├── docs/         Bewertung, Recherche, Konzept der Godot-Fassung
│   ├── tools/        Level-Generator, Asset-Generator, Paketbau, Web-Server, Aufräumen
│   ├── build/        Windows-Auslieferung (generiert)      ─┐ nicht im Repo
│   ├── build-web/    Browser-Fassung (generiert)           ─┤
│   └── shots/        Screenshot-Prüfläufe (generiert)      ─┘
├── design/           Phaser-Level-Baukasten (layout.txt + level.json je Station)
├── src/, public/     Phaser-Engine und generierte Spieldateien (versiegelt)
├── tools/, docs/     Phaser-Werkzeuge und Fachdokumentation
├── archive/          Altdateien und Quellpakete als Zip (nicht im Repo, siehe archive/README.md)
└── .tools/           portable Werkzeuge: Godot 4.7.2, Node, texconv (nicht im Repo)
```

## Weiterarbeiten: wo was liegt

**Wissensvermittlung (TI, ePA, gematik)**

- Fachliche Leitplanken: [`docs/KAPSEL.md`](docs/KAPSEL.md) — VAU ist ein Raum, kein Tunnel;
  Verschlüsselung ist nicht Signatur; eine abgelaufene Sitzung fällt in den Klartext zurück;
  die eGK speichert nichts. Diese Sätze dürfen keine Fassung verfälschen.
- Zeitreise FRÜHER/HEUTE und Probelauf: [`godot/src/ui/Intro.gd`](godot/src/ui/Intro.gd)
  (Erzählzeilen `FRUEHER_ZEILEN`, TI-Schritte `SCHRITTE`).
- ePA-Lehrsequenzen vor den Stationen 13/14/19/20: [`godot/src/ui/Wissen.gd`](godot/src/ui/Wissen.gd)
  (`DATEN` = Titel, Untertitel, Zeilen mit Zeitfenstern; Quellen in `docs/EPA-WISSENSPFAD.md`).
- Stationstexte (Portal-Satz, Stempel, Fachbegriff, REZI-Tipps): `godot/levels/<id>/level.json`.
- Hauptmenü-Klinikum (Wimmelbild mit TI-Keller): [`godot/src/ui/Title.gd`](godot/src/ui/Title.gd).

**Grafik**

- Farbwelten, Material, Licht: [`godot/src/core/Palette.gd`](godot/src/core/Palette.gd)
  (fünf Welten, Regeln gegen den „KI-Look" im Kopf der Datei).
- Kulisse und Gelände: `godot/src/world/Backdrop.gd`, `Terrain.gd`; Figuren: `godot/src/player/PaulVisual.gd`,
  `godot/src/actors/Rezi.gd`; Effekte: `godot/src/fx/`.
- Info-Screens zeichnen im 640×360-Design-Raum mit `godot/src/ui/Pen.gd`.
- Marke (Schrift, UI-Farben, Piktogramme): [`godot/brand/README.md`](godot/brand/README.md).

**Prüfen und ausliefern (Godot)**

```bash
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path godot --import          # Skriptfehler sehen
.tools/Godot_v4.7.2-stable_win64_console.exe --path godot --quit-after 20000 -- --shots=<abs. Ordner>   # Screenshot-Prüflauf
powershell -ExecutionPolicy Bypass -File godot\tools\build.ps1                          # Windows-Paket
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path godot --export-release Web build-web/index.html
```

---

# Phaser-Fassung (Ursprung, versiegelt)

> Konzipiert für einen Messestand (TV + Arcade-Joystick + 2 Buttons + Medikamentenautomat,
> QR-Code als Gewinn) — aber **komplett ohne Joystick am Laptop spielbar**.

## Schnellstart (spielen ohne Joystick)

```bash
npm install
npm run dev
```

Dann `http://localhost:5173` öffnen. Die Steuerungsanzeige erkennt automatisch,
ob ein Gamepad angeschlossen ist:

| Aktion | Tastatur | Arcade-Konsole |
|---|---|---|
| Laufen / Ducken / Hoch | Pfeiltasten oder WASD | Joystick |
| Springen | **Leertaste** | roter Button |
| TI-Aktion (signieren, verschlüsseln, freigeben) | **E** oder Enter | blauer Button |
| Hülle wechseln (Klartext ⇄ Verschlüsselt) | **Shift**, **Q** oder Pfeil hoch | Joystick **hoch** |

Der Messestand hat nur zwei Knöpfe — deshalb liegt der Hülle-Wechsel auf
*Joystick hoch* (abschaltbar über `gamepad.toggleOnUp`).

Beide Eingaben funktionieren immer parallel — ein USB-Arcade-Encoder wird ohne
Konfiguration erkannt (Button-Belegung in `public/config/input-bindings.json`,
Kalibrier-Overlay im Spiel: **F8**).

## Prototyp-Inhalt

- **Level „Versichertenstammdaten"** (Tutorial, horizontal): Daten-Kacheln sammeln,
  Aktualisierungs-Terminal als erste Blau-Knopf-Übung, Portal öffnet bei 3/3
- **Level „Kartenterminal"** (horizontal): Kontaktpad-Parcours, Skimming-Kralle
  (ducken!), PIN-Schleuse als Timing-Gate (Dr. Pixel signiert mit eHBA + Arzt-PIN),
  Signatur-Stempel-Finale
- **Level „KOV Gateway"** (Auto-Scroll-Glastunnel): Prüf-Podeste (stillstehen!),
  Verschlüsselungs-Dusche, Datenkraken machtlos außen am Glas
- **Level „Die Hülle"** (Lernlevel zur Kernmechanik): Lauscher sehen nur
  unverschlüsselte Daten, Andock-Plattformen tragen nur Klartext, VAU-Feld mit
  ablaufendem Kontextschlüssel — Vertraulichkeit wird gespielt, nicht erklärt
- Stadt-Band mit Portal-Dive zwischen den Stationen, HUD mit TI-Streckenkarte,
  Reward-Screen mit Offline-QR-Code, Tages-Highscore (Avatar-Icons, keine Personendaten),
  Kiosk-Modus (Attract, Idle-Reset, CrashGuard)
- Automatische REZI-Tipps, wenn jemand nicht weiterkommt (wiederholtes Scheitern,
  geschlossene Tore, kein Fortschritt) — Texte anpassbar, siehe [docs/LEVEL-EDITING.md](docs/LEVEL-EDITING.md)
- Rendering intern in 1920×1080: Pixel-Art bleibt stilecht blockig (Kamera-Zoom 3×),
  Schrift und QR-Code sind nativ scharf — auf dem Messe-TV wie im Browserfenster

## Levelbau: geschützter Baukasten (auch für KI-Assistenten)

Alle Level entstehen aus zwei kleinen Dateien pro Level in **`design/`** —
ein ASCII-Geländeplan (`layout.txt`) + Texte/Objekte (`level.json`). Der Compiler
(`npm run build:levels`) erzeugt daraus die Spieldateien und **prüft jede Regel
automatisch**: Erreichbarkeit mit echter Sprungphysik, Tore-mit-Öffner (keine
Softlocks), Sammelziele, Vokabular mit „meintest du …?"-Vorschlägen. Kaputte Level
können gar nicht erst ins Spiel gelangen; der Engine-Kern ist per SHA-256-Manifest
versiegelt (`npm run guard`).

**Die eine Datei, die man dafür lesen muss: [`design/LEVELBAU.md`](design/LEVELBAU.md).**
Sie ist so geschrieben, dass auch schwächere KI-Assistenten damit selbstständig
sichere Level bauen (Regeln stehen zusätzlich in `CLAUDE.md`/`AGENTS.md`).
Redaktions-Kurzanleitung: [docs/LEVEL-EDITING.md](docs/LEVEL-EDITING.md) ·
Gesamtkonzept inkl. Leveldesign aller 6 Stationen, TI-Fachlichkeit und
Messebetrieb: [docs/KONZEPT.md](docs/KONZEPT.md)

## Befehle

| Befehl | Zweck |
|---|---|
| `npm run dev` | Entwicklung (Vite, HMR) |
| `npm test` | Engine-Logik: Tests (Hülle, Sicht, Eingabe, Compiler, Recht, Telemetrie, Verdrahtung) |
| `npm run playtest:report` | Playtest-Dateien auswerten → Quote + Handlungsempfehlung |
| `npm run build` | Offline-fähiger Produktions-Build nach `dist/` (inkl. Level-Build) |
| `npm run neues-level -- 04-name` | Neues Level aus der Vorlage anlegen |
| `npm run build:levels` | Level kompilieren `design/` → `public/` + alle Prüfungen |
| `npm run validate` | Komplett-Prüfung: Configs, Level, Erreichbarkeit, Kern-Schutz |
| `npm run guard` | Nur Kern-Schutz prüfen (`guard:update` schreibt das Manifest neu) |
| `level-build.bat` | Level bauen + prüfen per Doppelklick (Redaktion, ohne Terminal) |
| `start-messe.bat` | Messestart: lokaler Server + Chrome-Kiosk (`?kiosk=1`) |
| `push-to-github.bat` | Push nach GitHub. Der frühere Actions-Deploy von `dist/` (`deploy-pages.yml`) ist in den GitHub-Einstellungen deaktiviert; GitHub Pages zeigt die Godot-Browser-Fassung aus dem Branch `web` (`python godot/tools/deploy_web.py`). Ein reiner Prüf-Workflow (Tests, Lint, Validierung) braucht einen Menschen mit `npm run guard:update`, weil `.github/workflows/` zum geschützten Kern gehört |

URL-Parameter: `?debug=1` FPS-Anzeige · `?debug=2` Physik-Debug · `?kiosk=1` Kiosk-Härtung (Cursor aus, CrashGuard) · `?renderer=canvas` 2D-Fallback für Rechner ohne brauchbares WebGL.

## Die Hülle — die Kernmechanik der Lern-Level

Drei Zustände, die **gleichzeitig auf mehrere Dinge** wirken (die Lehre aus
Ikaruga/Outland: ein Toggle trägt nur mit echten Konsequenzen):

| Zustand | Tempo | Lauscher sehen dich? | Andock-Plattform trägt? |
|---|---|---|---|
| Klartext | 100 % | **ja** | ja |
| Verschlüsselt | 80 % | nein | **nein** |
| VAU (nur im Feld) | 100 % | nein | ja |

Daraus entsteht der Zielkonflikt: Sichtbar bist du schnell und kannst andocken —
unsichtbar bist du langsam und wirst nicht getragen. Der Zustand ist im HUD
**dreifach** codiert (Farbe, Form, Text), damit Farbfehlsichtigkeit ihn nie
verdeckt.

Fachlich sauber gehalten: Die VAU ist kein Tunnel, sondern ein Raum, in dem im
Klartext gearbeitet wird, ohne dass Betreiber mitlesen. Verschlüsselung ist nicht
Signatur. Eine abgelaufene Sitzung schützt nicht — sie fällt in den Klartext
zurück (und damit in die Sichtbarkeit).

Pro Level einschaltbar (`"huelle": { "enabled": true }`) — die drei Messe-Level
laufen unverändert ohne sie. Alle Regeln: [`design/LEVELBAU.md`](design/LEVELBAU.md).
Die Godot-Fassung übernimmt dieselbe Mechanik 1:1 (`godot/src/state/Huelle.gd`).

## Playtest & Wirkungsmessung

Das Konzept nennt ein **Abbruchkriterium**: Verstehen weniger als 80 % der
Tester „sichtbar vs. sicher" ohne Text, wird die Mechanik überarbeitet — nicht
weiterer Content gebaut. Dafür ist alles vorbereitet:

- **Telemetrie** zählt mit, ob die Hülle **freiwillig und rechtzeitig** genutzt
  wird. Wer verschlüsselt, *bevor* ein Lauscher ihn erwischt, hat die Regel aus der
  Situation gelesen (*proaktiv*). Wer erst danach reagiert, hat die Strafe gebraucht (*reaktiv*).
- **F9 im Spiel** zeigt die Quote gegen die 80-%-Schwelle und exportiert die
  Rohdaten als Datei.
- **`npm run playtest:report`** führt mehrere Exportdateien zusammen und liefert eine
  Ableitung: Regel *zu spät* angewandt (Einführung zu leise) oder *gar nicht erkannt*
  (Mechanik überarbeiten).
- **Fragebogen** (7 Fragen) prüft das Wissen vor und nach dem Spielen.

Anleitung für die Durchführung: **[`docs/PLAYTEST.md`](docs/PLAYTEST.md)**

**Datenschutz:** Die Telemetrie erfasst keine Personendaten — kein Name, keine
Kennung, keine IP, kein Datum, nur Millisekunden seit Sitzungsbeginn. Nichts wird
übertragen; die Daten bleiben im Browser, bis jemand F9 drückt. Abschaltbar über
`"telemetrie": false` in `public/config/game-config.json`.

## Tests

```bash
npm test          # Engine-Logik (ohne Browser)
npm run validate  # Configs, Level, Erreichbarkeit, Kern-Schutz
```

Bewusst ohne Test-Framework: Das Harness (`tools/test/harness.ts`) hat keine
Abhängigkeiten, `npm test` läuft damit auch auf einem frisch aufgesetzten Messe-PC.

## Tech-Stack

Phaser 3 · TypeScript · Vite · zod · qrcode · Tiled-JSON-Tilemaps. Alle Pixel-Grafiken
werden prozedural zur Laufzeit erzeugt (keine Binär-Assets).
Godot-Fassung: Godot 4.7.2 · GDScript · Forward+ (Windows) / Compatibility (Browser) ·
prozedurale Vektorgrafik · synthetisierte Klänge · Helvetica Neue / ITC Charter (Marke).
