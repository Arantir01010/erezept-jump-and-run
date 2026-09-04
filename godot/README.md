# Paul & REZI — Godot-Fassung

Neuaufbau des e-Rezept-Jump-'n'-Runs mit **Godot 4.7.2** (GDScript, Forward+-Renderer,
HDR-2D-Glühen). Das fachliche Setting, die Hülle-Mechanik, die Stationen und die
Markenregeln (nie kämpfen, „ZUGRIFF VERWEIGERT", VAU ist ein Raum) bleiben erhalten —
Spielgefühl, Leveldesign, Grafik und Wiederspielwert sind neu.

Bewertung, Recherche und Konzept: [`docs/ANALYSE-UND-KONZEPT.md`](docs/ANALYSE-UND-KONZEPT.md).

## Starten

Godot liegt portabel im Repo unter `.tools/`. Aus dem Repo-Stammverzeichnis:

```bash
.tools/Godot_v4.7.2-stable_win64_console.exe --path godot
```

| Schalter (nach `--`) | Wirkung |
|---|---|
| `--kiosk` | Vollbild, Cursor aus, Idle-Reset nach `idleResetSeconds` |
| `--fullscreen` | nur Vollbild |
| `--level=<id>` | direkt in ein Level springen, z. B. `--level=04-die-huelle` |
| `--shots=<ordner>` | automatischer Prüflauf: spielt selbst, speichert Screenshots (auch zwei Bilder mitten in der Blende), beendet sich |
| `--shots-level=<id>` | Level für den Prüflauf |
| `--touch` | Bildschirm-Steuerung sofort einblenden (Test am PC: die Maus spielt den Finger) |
| `--webfx` | Browser-Pfad am Desktop testen: Glüh-Sprites statt HDR-Glühen, CPU-Partikel |
| `--blitz` | Gewitterblitz alle 4 s (Prüfen der Blitz-Optik in Regenwelten) |
| `--start-at=<typ>` | Paul auf den ersten Baustein dieses Typs setzen, z. B. `--start-at=vau-feld` |
| `--lang=<code>` | Sprache de / en / fr / es / zh / hi (im Browser `?lang=fr`) |
| `--test-eingabe=F12,RIGHT,SPACE,-,F12` | echte Tastenereignisse alle 0,7 s einspielen (`-` = Pause, `F12` = Screenshot nach `user://`), danach Ende — prüft Menü und Bedienungswahl ohne Hand am Gerät |

**Bedienungswahl im Hauptmenü:** Zwei Felder über der Start-Zeile, „TASTATUR · ARCADE" und
„TOUCH". Links/Rechts (Pfeile, WASD, Joystick) wechseln, Leertaste/roter Knopf startet mit
der markierten Bedienung; ein Fingertipp auf ein Feld startet direkt damit, ein Tipp
irgendwo sonst startet mit Touch, ein Mausklick nur auf ein Feld. Die Wahl (`Kiosk.input_mode`)
steuert Bildschirm-Knüppel, Knopfnamen und Hinweistexte im ganzen Durchlauf; nach dem
Idle-Reset zeigt das Menü die zuletzt gewählte Bedienung vor, sonst Touch auf Touchscreens.

Tasten: Pfeile/WASD laufen & ducken · LEERTASTE springen (in der Luft nochmal = REZI-Schub) ·
E TI-Aktion · SHIFT/Q/Pfeil hoch Hülle wechseln · ESC/P Pause · F2 Sprache · F3 Musik ·
F4 Töne · F11 Vollbild · F12 Screenshot.

**Pause und Klang:** ESC, P, der START-Knopf am Gamepad oder der runde Pause-Knopf oben im
HUD (Finger/Maus) halten das Level an. Das Pausenmenü (`src/ui/PauseMenu.gd`) bietet
Weiter, Musik an/aus, Töne an/aus und Zum Hauptmenü — Hoch/Runter + Sprung/Aktion,
Tipp oder Klick. Musik und Töne lassen sich auch im Hauptmenü oben links umschalten
(zwei Pillen, F3/F4); die Wahl liegt in `user://einstellungen.cfg` und überlebt Neustart
und Idle-Reset. In der Pause läuft der Idle-Reset weiter (Messe: wer weggeht, landet
wieder im Hauptmenü). `--test-eingabe=-,-,-,-,ESC,-,F12,DOWN,DOWN,SPACE,-,F12,ESC` prüft
den Weg Taste → Pause → Menü.
Arcade-Encoder: Belegung aus `config/input-bindings.json` (identisch zur Phaser-Fassung).

## Sprachen

Sechs Sprachen, umschaltbar über die Flaggen oben rechts im Hauptmenü (Klick oder
Fingertipp; F2 blättert): Deutsch, Englisch, Französisch, Spanisch, Chinesisch, Hindi.
Das Menü baut sich mit der neuen Sprache neu auf, alles danach (Zeitreise, Probelauf,
ePA-Wissen, Briefings, HUD, Hinweise im Level, Stationskarte, Reward) folgt ihr. Beim
Idle-Reset gilt wieder die Standardsprache (`language` in `config/game-config.json`).

- **Übersetzungen** liegen in `i18n/*.json` (`ui`, `intro`, `briefing`, `levels`): Schlüssel
  ist der deutsche Text, genau wie er im Code oder in `levels/*/level.json` steht, Spalten
  `en fr es zh hi`. `Game._load_translations()` lädt sie in den TranslationServer; Labels
  übersetzen sich selbst (auto_translate), formatierte Texte holen `tr()`, Level-Texte
  (`{de, en}`) fallen für die übrigen Sprachen über `Game.t()` auf die Tabelle zurück.
  Neuer Text im Spiel = neue Zeile in der passenden Datei, sonst bleibt er deutsch.
  Platzhalter (`%s`, `%d`, `{action}`) müssen in jeder Sprache erhalten bleiben.
- **Schriften:** Helvetica Neue und Charter haben keine chinesischen und Devanagari-Glyphen.
  `assets/i18n/` enthält Noto-Sans-Untermengen (SIL OFL, nur die tatsächlich verwendeten
  Zeichen, zusammen unter 400 KB), die `Brand._with_fallbacks()` an alle Markenschriften
  hängt. Nach Änderungen an zh/hi-Texten: `python godot/tools/gen_i18n_fonts.py`
  (braucht `pip install fonttools` und die Quellschriften in `.tools/downloads/fonts/`,
  Bezugsquellen im Docstring).
- **Prüfen:** `--shots=<dir> --lang=zh` fotografiert den ganzen Ablauf in einer Sprache;
  `--test-eingabe=-,-,F12,F2,-,-,-,F12` blättert per F2 und fotografiert das Menü.

## Ablauf und Screens

```
Hauptmenü (Klinikum, Bedienungswahl)  →  FRÜHER  →  HEUTE  →  SO SPIELST DU  →  Briefing 1  →  Station 1 …
… Station → Stationskarte → [ePA-Wissen vor 13 / 14 / 19 / 20] → Briefing → nächste Station … → Reward
```

| Screen | Datei | Inhalt |
|---|---|---|
| Pause | `src/ui/PauseMenu.gd` | Overlay über dem Level (Baum angehalten): Weiter, Musik an/aus, Töne an/aus, Zum Hauptmenü; Idle-Reset läuft weiter. |
| Stations-Briefing | `src/ui/Briefing.gd` + `src/ui/BriefingDaten.gd` | Vor jeder der zehn Stationen: was in der Wirklichkeit passiert, 4–5 laienverständliche Zeilen im Takt, animierte Mini-Szene der Mechanik, „Das tust du" mit den Knopfnamen der gewählten Bedienung, Leiste aller Bausteine des Levels (aus `level.json` + `layout.txt`). Oben die Reiseroute der zehn Stationen (Haken für geschaffte, die aktuelle pulsiert), Bühnenlicht auf der Szene, die Bausteine treten nacheinander hervor. Inhalte in `BriefingDaten.STATIONEN`; Prüfschalter `--shots=<dir> --shots-briefings` fotografiert alle zehn. |

**Erzählband:** Alle Erzählzeilen (FRÜHER, HEUTE, ePA-Wissen, Briefings) stehen in einem
dunklen Textband unter der Überschrift — Schrift 11 statt 9,5 Design-px, weiß auf dunklem
Grund, mehrzeilig, REZI als Erzähler mit Sprechwellen, Aufbau Zeichen für Zeichen,
Zeilenpunkte, leiser Tick je Zeile (`Vignette.story_line`, Takt über `story_cycle`).
Jeder Screen gleitet beim Öffnen ein (`Vignette._entrance`); zwischen den Screens fährt
eine schräge Blende mit orangefarbenem Saum durchs Bild (`src/shaders/wipe.gdshader`,
`Main._fade_out` / `_fade_in`). Die Stationskarte nach jedem Level hat den Farbverlauf
der Zone, einen drehenden Strahlenkranz, den Stempel-Einschlag des Stationsnamens und
Funkenregen bei drei Medaillen (`src/ui/LevelCard.gd`).

| Screen | Datei | Inhalt |
|---|---|---|
| Hauptmenü | `src/ui/Title.gd` | Das Klinikum im Puppenhaus-Schnitt (OP, Stationen, Flur, Empfang; im Keller Konnektor → VAU → Fachdienst ePA), Aufzug, Heli, Passanten, Datenpulse; Paul & REZI auf dem Apotheken-Dach; Steuerungstafel, Tages-Bestenliste. 1:1-Port des Web-Hauptmenüs. |
| FRÜHER / HEUTE | `src/ui/Intro.gd` (Phase 1, 2) | Die Zeitreise: dieselbe Straße, zwei Zeiten. Papier, Boten, Fax, Warteschlangen — dann die TI als Lehrstück in fünf Schritten (Sprechzimmer, Konnektor legt die Hülle an, TI-Gateway, VAU schreibt die Akte, Abruf in App und beim nächsten Arzt). **Das ist die Erklärung, was sich mit ePA und TI geändert hat.** |
| SO SPIELST DU | `src/ui/Intro.gd` (Phase 3) | Probelauf: der echte Paul läuft im Autopilot über eine Grube, sammelt ein Datenbit, schaltet die Hülle — Popups mit Tastenkappen (Tastatur, Arcade-Knöpfe oder Touch-Knöpfe, je nach erkannter Hardware). |
| ePA-Wissen | `src/ui/Wissen.gd` | Vier Lehrsequenzen („Deine Akte", „Die Medikationsliste", „Befugnis auf Zeit", „Deine Regeln") vor den vier ePA-Stationen, Zuordnung in `Wissen.VOR_LEVEL`. |

Alle Info-Screens erben von `src/ui/Vignette.gd`: Bühne im 640×360-Design-Raum der
Web-Fassung (Node2D ×3 → 1920×1080, Koordinaten der Originale gelten unverändert),
Schriften unskaliert als Label, Mindest-Anzeigedauer mit Zeitbalken, danach blättert jeder
Knopf/Tipp weiter. Zeichen-Vokabular in `src/ui/Pen.gd`. Kein Blinken über 3 Hz.

## Touch-Steuerung (Tablet)

`src/ui/TouchControls.gd` — erscheint automatisch mit der ersten echten Berührung, sobald
ein Level läuft (Menü-Screens bleiben frei; dort blättert ein Tipp weiter):

- **links Knüppel** (8 Richtungen, tote Mitte; der Finger darf irgendwo in der linken
  Bildhälfte aufsetzen, der Knüppel springt dorthin und federt zurück)
- **rechts SPRUNG** (groß, rot wie der Arcade-Knopf; ein Tipp irgendwo rechts außerhalb
  der Knöpfe springt ebenfalls), dazu **AKTION** (blau, TI-Aktion) und **HÜLLE** (türkis)
- Multitouch: jeder Finger hat seinen Besitzer, laufen + springen gleichzeitig funktioniert.

Alles mündet in die InputMap — die Spiellogik kennt keine Touch-Sonderfälle. Windows-Tablets
liefern Touch direkt an die Windows-Auslieferung; Android/iPad bräuchten die jeweiligen
Export-Templates (Inhalt und Steuerung sind dafür fertig).

## Browser-Fassung (Web-Export)

```bash
.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path godot --export-release Web build-web/index.html
python godot/tools/serve_web.py            # http://localhost:8060/ — öffnet den Browser
```

`godot/build-web/` ist die komplette Browser-Fassung: `index.html`, `index.js`, `index.wasm`
(≈ 40 MB Godot-Laufzeit), `index.pck` (das Spiel, ≈ 1 MB), Audio-Worklets, Icons, dazu
`Start im Browser.bat`, `serve_web.py` und `LIESMICH.txt`. Ein Web-Build läuft nicht per
Doppelklick auf `index.html` (Browser laden `.wasm`/`.pck` nur über HTTP), deshalb der
kleine Server; für die Veröffentlichung reicht jeder statische Webspace mit HTTPS
(GitHub Pages, Netlify, itch.io …). Der Build ist **ohne Thread-Unterstützung** exportiert,
braucht also keine Cross-Origin-Isolation-Header.

**Veröffentlicht ist die Browser-Fassung auf GitHub Pages:**
https://arantir01010.github.io/erezept-jump-and-run/ — Pages zeigt den Branch `web`, der nur
die Export-Dateien enthält (kein Quelltext). Neue Fassung veröffentlichen:

```bash
python godot/tools/deploy_web.py
```

Das Skript exportiert, ersetzt den Inhalt des Branches `web` und pusht; Pages ist in
unter zwei Minuten aktuell. Aufruf-Schalter im Browser: `?touch=1`, `?level=<id>`, `?kiosk=1`.
Hinweis: Die PwC-Schriften stecken im PCK und sind damit öffentlich abrufbar — wer das nicht
will, exportiert ohne `assets/fonts/` (Brand.gd fällt dann auf die Godot-Schrift zurück).

| Adresse | Wirkung |
|---|---|
| `index.html?touch=1` | Touch-Steuerung sofort einblenden (Maus = Finger) |
| `index.html?level=04-die-huelle` | direkt in eine Station |
| `index.html?kiosk=1` | Messe-Modus (Idle-Reset) |

Technik: Preset „Web" in `export_presets.cfg`; im Browser läuft der Godot-Renderer
„Compatibility" (WebGL 2, `rendering_method.web="gl_compatibility"`). Damit entfallen HDR-Glühen
und 2D-MSAA der Windows-Fassung; Lichter, Schatten, Normal-Maps, Partikel und der
Post-Effekt sind gleich. Vollbild geht im Browser nur auf Nutzeraktion (F11 nach dem ersten
Klick), Musik startet mit der ersten Eingabe (Autoplay-Regel). Die Bestenliste liegt im
Browser-Speicher (IndexedDB). Die Web-Export-Templates liegen in
`%APPDATA%\Godot\export_templates\4.7.2.stable\web_*.zip` (aus dem offiziellen
`Godot_v4.7.2-stable_export_templates.tpz`, Kopie unter `.tools/downloads/`).

## Auslieferung und Zertifikat (Smart App Control)

`powershell -ExecutionPolicy Bypass -File godot\tools\build.ps1` baut `godot/build/`:

| Datei | Zweck |
|---|---|
| `Paul und REZI.lnk` / `.bat` | **Empfohlener Start.** Startet die offiziell signierte Godot-Laufzeit (Certum-Zertifikat) mit dem Spiel `PaulUndRezi.pck`. Läuft auch auf Windows 11 mit Smart App Control. |
| `Paul und REZI (Messe-Kiosk).lnk` | dasselbe mit `--kiosk` (Vollbild, Cursor aus, Idle-Reset) |
| `PaulUndRezi.exe` | Einzel-EXE mit eingebettetem Spiel, selbstsigniert. Wird von Smart App Control blockiert (SAC akzeptiert nur CA-Zertifikate); auf anderen Rechnern reicht „Trotzdem ausführen". |
| `PaulUndRezi-Zertifikat.cer` + `Zertifikat-vertrauen (optional).bat` | das selbstsignierte Zertifikat, optional in den Benutzerspeicher eintragen |
| `LIESMICH.txt` | dieselbe Erklärung für den Messestand |

Hintergrund: Der Godot-Export-Template ist unsigniert. Wer die Einzel-EXE unter Smart App
Control braucht, benötigt ein Code-Signing-Zertifikat einer Zertifizierungsstelle und ruft
`build.ps1 -Thumbprint <SHA1>` auf. Smart App Control abzuschalten ist endgültig — nicht
empfohlen.

## Werkzeuge

| Befehl | Zweck |
|---|---|
| `python godot/tools/sync_levels.py` | Level + Konfiguration aus `design/` und `public/config/` nach `godot/levels/_import/` und `godot/config/` kopieren |
| `python godot/tools/build_levels.py` | **alle zehn Level** aus dem Generator bauen (Geometrie + Objekte) und die Erreichbarkeit prüfen (Sprung 3 hoch / ~6 weit, Bonus per REZI-Schub, Sprungfedern) |
| `python godot/tools/gen_assets.py` | Klänge, Musik und QR-Code erzeugen (`assets/`); braucht `numpy`, `qrcode`, `Pillow` |
| `powershell -ExecutionPolicy Bypass -File godot\tools\build.ps1` | Auslieferungspaket in `build/` (PCK + signierte Laufzeit + Verknüpfungen + EXE) |
| `Godot … --headless --import` | Projekt-Cache aufbauen, Skriptfehler sehen (`SCRIPT ERROR`) |
| `Godot … --headless --export-release "Windows" build/PaulUndRezi.exe` | Windows-Build (Preset in `export_presets.cfg`) |
| `Godot … --quit-after 3600 -- --shots=<abs. Ordner>` | Screenshot-Prüflauf ohne Menschen am Rechner |
| `Godot … --headless --export-release Web build-web/index.html` | Browser-Fassung nach `build-web/` (Preset „Web") |
| `python godot/tools/serve_web.py [port]` | lokaler Server für die Browser-Fassung, öffnet den Browser |
| `python godot/tools/gen_i18n_fonts.py` | Schrift-Untermengen für Chinesisch/Hindi aus den Übersetzungen neu bauen (`assets/i18n/`) |
| `python godot/tools/deploy_web.py` | Web-Export neu bauen und als Branch `web` nach GitHub pushen — GitHub Pages veröffentlicht daraus: https://arantir01010.github.io/erezept-jump-and-run/ (`--no-export` nimmt `build-web/`, `--no-push` nur lokal) |

Alle Grafiken sind prozedural (Vektorzeichnung zur Laufzeit), alle Klänge synthetisiert —
es gibt keine Binär-Assets mit Lizenzfragen. Wer gezeichnete Kunst einbauen will, ersetzt
die `_draw()`-Methoden von `PaulVisual`, `Rezi`, `Terrain`, `Backdrop` durch Sprites.

## Level

Dasselbe Format wie im Phaser-Baukasten (`design/LEVELBAU.md`): `layout.txt` (ASCII)
+ `level.json`. Suchreihenfolge: `levels/<id>/` (Godot-eigen) vor `levels/_import/<id>/`.

Drei Godot-Erweiterungen im Layout:

| Zeichen | Bedeutung |
|---|---|
| `*` | Bonus-Prüfsumme (50 Punkte, zählt für die Medaille „Prüfsummen") |
| `^` | Sprungfeder |
| `x` | Störfeld — eine Kachel Schaden (kostet Bits, nie Leben) |

Plattformen `=` sind von unten durchspringbar. Paul hat zusätzlich den REZI-Schub
(Doppelsprung) und Wandsprung; Pflichtwege sollten trotzdem mit einem Sprung
(3 Kacheln hoch, ~5 Kacheln weit) lösbar sein — der Schub ist für Bonuswege.

Alle zehn Level in `levels/<id>/` entstehen aus `tools/build_levels.py` (Kishōtenketsu:
Einführung → Entwicklung → Wendung mit Weggabelung → Abschluss). Seit 03.09.2026 sind sie
30–50 % länger und fordernder: Plattformketten mit wechselnden Höhen, Sprungfedern,
Pendel-Plattformen über Gruben, schmale Podeste über Störfeldern, Wandsprung-Schächte
(nur für Bonuswege), Lauscher an Ausstiegen; Station 01 bleibt sanft. Der Generator prüft
per BFS, dass Pflichtwege ohne Treffer, ohne REZI-Schub und ohne Wandsprung lösbar sind
(Hülle-Level mit kürzeren Sprungweiten), leitet Par-Zeit und Sammelziel ab und stellt
sicher, dass die Prüflauf-Positionen 42/66/86 % freier Boden sind. Wer ein Level ändern
will, ändert die Bauanleitung im Generator und lässt ihn laufen — er lehnt unerreichbare
Ziele ab. Aufruf: `python godot/tools/build_levels.py`. Runde 3 („etwas schwieriger"):
Ketten-Lücken um eine Kachel weiter, das letzte Podest jeder Reihe eine Kachel breit,
zusätzliche Störfelder, Pendel-Plattformen schneller und meist weiter, ein Rücksetzpunkt
weniger je Level, Lauscher 12 % schneller (`LAUSCHER_TEMPO`), Sammelziel 14 statt 12
(Tunnel 18) — Station 1 bekommt nur Lücken und Störfelder.

## Bildsprache (gegen den „KI-Look")

Fünf Farbwelten in `src/core/Palette.gd` (Morgen, Abend, Regen, Rechenzentrum, Archiv),
je eine begrenzte Palette mit heller Kappe oben, dunklem Fuß, dunkler Kontur, Struktur,
gewellten Kanten; Sonne als `DirectionalLight2D` mit Schatten, Kappen mit Normal-Map,
Punktlichter nur an echten Lichtquellen, Glühen nur über HDR-Schwelle 1,35. Post-Effekt:
parametrisches Grading je Welt (Schatten kühl, Lichter warm, farbige Vignette), Papierkorn.
Physik nach Celeste (×6 skaliert, Werte in `Player.gd`).

Seit dem Grafik-Ausbau (03.09.2026, [docs/GRAFIK-AUSBAU.md](docs/GRAFIK-AUSBAU.md)) dazu:
Vordergrund-Ebene und Tiefenschärfe der Kulisse, Kulissen-Leben und Partikel je Welt,
Sonnenstrahlen, Blocktexturen mit Normal-Maps und Bevel-Kanten, Wind in Gras und Pflanzen
(Paul biegt Gras), Pfützen und Bodennebel im Regen, Regen mit Spritzern und seltenem Blitz,
gefärbte Schatten aller Lichter, Sonnendrift je Station, Paul mit Kapuzenzipfel
(Kettensimulation), Schmierstreckung und Geisterspur beim REZI-Schub, REZI mit Mimik,
VAU-Ring, Siegel-Burst. Im Browser ersetzen Glüh-Sprites das HDR-Glühen (`Fx.web_fallback`).

## Marke (PwC)

Schrift und Bedienelemente folgen dem PwC-Erscheinungsbild, die Spielgrafik nicht:
Helvetica Neue für alles Lesbare, ITC Charter Bold für große Überschriften, UI-Flächen in
PwC-Grau mit Tangerine/Orange für Aufforderungen und Yellow für Erfolg. Alles sitzt in
[`src/core/Brand.gd`](src/core/Brand.gd); Regeln, Herkunft der Dateien und der
Lizenz-Hinweis (Desktop-EULA, App-Einbettung klären) stehen in
[`brand/README.md`](brand/README.md). Fehlen die Schriftdateien, läuft das Spiel mit der
Godot-Standardschrift weiter.

## Struktur

```
godot/
├── project.godot, export_presets.cfg
├── scenes/Main.tscn                 einzige Szene — alles Weitere entsteht im Code
├── src/
│   ├── Main.gd                      Ablauf: Hauptmenü → Zeitreise → Probelauf → Level → Karte → (Wissen) → … → Reward
│   ├── autoload/  Game.gd (Zustand, Punkte, Medaillen, Highscore) · Sfx.gd (Klang) · Kiosk.gd (Eingabe, Messe, Prüflauf)
│   ├── core/      LevelData.gd (Level-Parser) · Palette.gd (Materialsystem) · Brand.gd (PwC-Schrift, UI-Farben)
│   ├── player/    Player.gd (Controller) · PaulVisual.gd (Figur)
│   ├── actors/    Rezi.gd
│   ├── world/     Level.gd · Terrain.gd + terrain/ (Blocktexturen, Wind-Flora, Pfützen, Bodennebel)
│   │              · Backdrop.gd + backdrop/ (Ebenen, Leben, Vordergrund, Partikel, Lichtstrahlen) · GameCamera.gd
│   ├── shaders/   wind · puddle · ground_fog · kulisse_blur · god_rays · hall_rays (.gdshader)
│   ├── mechanics/ Mechanic.gd · Basics.gd · Stations.gd (alle Bausteine)
│   ├── state/     Huelle.gd (Kernmechanik)
│   ├── fx/        Fx.gd (Partikel, Lichter, Hitstop, Stempel, Browser-Fallback) · PostFx.gd (Grading je Welt) · Weather.gd (Regen, Blitz)
│   └── ui/        Vignette.gd + Pen.gd (Info-Screen-Basis) · Title.gd (Hauptmenü/Klinikum) · Intro.gd (Zeitreise + Probelauf)
│                  · Wissen.gd (ePA-Sequenzen) · TouchControls.gd · HUD.gd · LevelCard.gd · Reward.gd
├── levels/        Godot-eigene Level; _import/ = Sync aus design/
├── config/        Sync aus public/config/
├── assets/        generiert (audio/, qr/) · fonts/ + brand/ (Marke, lizenziert, nicht im Repo)
├── brand/         Marken-README + Lizenzdokumente
├── docs/          Bewertung, Recherche, Konzept
├── i18n/          Übersetzungen (ui, intro, briefing, levels) — Schlüssel = deutscher Text, Spalten en/fr/es/zh/hi
├── tools/         sync_levels.py, gen_assets.py, build_levels.py, gen_i18n_fonts.py, build.ps1, serve_web.py, deploy_web.py, aufraeumen.py
├── build/         Windows-Paket (generiert)      · build-web/  Browser-Fassung (generiert)
└── shots/         Screenshot-Prüfläufe (generiert)
```

## Bekannte Grenzen (Stand 02.09.2026)

- Kein Android-/iOS-Export (Templates nachladen bzw. Xcode); für Tablets reicht die
  Browser-Fassung.
- Im Browser kein HDR-Glühen und kein 2D-MSAA (Compatibility-Renderer).
- Die Tages-Bestenliste im Hauptmenü erscheint erst, wenn an diesem Tag gespielt wurde.
