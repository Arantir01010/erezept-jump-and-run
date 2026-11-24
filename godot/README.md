# Paul & REZI — Godot-Fassung

Neuaufbau des e-Rezept-Jump-'n'-Runs mit **Godot 4.7.2** (GDScript, Forward+-Renderer,
HDR-2D-Glühen). Das fachliche Setting, die Hülle-Mechanik, die Stationen und die
Markenregeln (nie kämpfen, „ZUGRIFF VERWEIGERT", VAU ist ein Raum) bleiben erhalten —
Spielgefühl, Leveldesign, Grafik und Wiederspielwert sind neu.

Bewertung, Recherche und Konzept: [`docs/ANALYSE-UND-KONZEPT.md`](docs/ANALYSE-UND-KONZEPT.md).
Besucher-Umfrage zur Bewertung des Spiels (Fragebogen, Erfassung, Auswertung mit Formeln): [`docs/Umfrage-Paul-und-REZI.xlsx`](docs/Umfrage-Paul-und-REZI.xlsx).

## Starten

Godot liegt portabel im Repo unter `.tools/`. Aus dem Repo-Stammverzeichnis:

```bash
.tools/Godot_v4.7.2-stable_win64_console.exe --path godot
```

| Schalter (nach `--`) | Wirkung |
|---|---|
| `--kiosk` | Vollbild, Cursor aus, Idle-Reset nach `idleResetSeconds`; F11/F12/Alt+F4 gesperrt, Musik/Töne-Wahl gilt nur bis zum Idle-Reset |
| `--lautstaerke=<0–100>` | Gesamtlautstärke (sonst der gespeicherte Wert, Strg+F9/F10) |
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

**Bedienungswahl im Hauptmenü:** Ein Segment-Schalter oben mittig, „TASTATUR · ARCADE" und
„TOUCH" (Feldbreiten folgen dem übersetzten Text). Links/Rechts (Pfeile, WASD, Joystick) wechseln, Leertaste/roter Knopf startet mit
der markierten Bedienung; ein Fingertipp auf ein Feld startet direkt damit, ein Tipp
irgendwo sonst startet mit Touch, ein Mausklick nur auf ein Feld. Rechts wählt Touch nur, wenn
es etwas zu tippen gibt (Touchscreen erkannt oder schon berührt) — am Arcade-Kiosk bleibt
der Stick nach rechts wirkungslos statt alle Hinweise auf TIPPEN umzustellen. Die Wahl (`Kiosk.input_mode`)
steuert Bildschirm-Knüppel, Knopfnamen und Hinweistexte im ganzen Durchlauf; nach dem
Idle-Reset zeigt das Menü die zuletzt gewählte Bedienung vor, sonst Touch auf Touchscreens.

Tasten: Pfeile/WASD laufen & ducken · LEERTASTE springen (in der Luft nochmal = REZI-Schub) ·
E TI-Aktion · SHIFT/Q/Pfeil hoch Hülle wechseln (Pfeil/Stick nur senkrecht hoch, schräg hoch-rechts bleibt ein Sprung) · ESC/P Pause · F2 Sprache · F3 Musik ·
F4 Töne · F11 Vollbild · F12 Screenshot (beide nicht im `--kiosk`).

**Standpersonal:** Strg+F9 leiser, Strg+F10 lauter (10-%-Stufen, gespeichert in
`user://einstellungen.cfg`, gilt auch im Kiosk) · Strg+Umschalt+F12 beendet den Kiosk
(Exit-Code 7, `Messe-Kiosk.bat` startet dann nicht neu) · **Betreiber-Menü** mit Strg+Umschalt+F10
oder SPRUNG + AKTION zusammen 5 s halten (`src/ui/Betrieb.gd`): Tagesstatistik je Station,
Lautstärke, Tages-Bestenliste löschen (zweimal bestätigen), Spiel beenden. Ton: Busse „Musik" und „SFX" unter
Master, auf Master ein harter Begrenzer bei −1 dB (zur Laufzeit in `Sfx._build_buses`). Alle
Klänge und die Musik werden beim Start geladen (kein Ruckler beim ersten Abspielen).

**Pause und Klang:** ESC, P, der START-Knopf am Gamepad oder der runde Pause-Knopf oben im
HUD (Finger/Maus) halten das Level an. Das Pausenmenü (`src/ui/PauseMenu.gd`) bietet
Weiter, **Station neu starten** (dieselbe Station ohne Briefing, Spielstand zurück auf den
Stationsbeginn), **Steuerung** (Tastentafel der erkannten Bedienung), Musik an/aus,
Töne an/aus und Zum Hauptmenü — Hoch/Runter + Sprung/Aktion, Tipp oder Klick. Weist die
Tür Paul zum dritten Mal ab, nennt REZI diesen Ausweg; reichen die Prüfsummen, die noch
in der Station liegen, nicht mehr für das Ziel, öffnet die Tür von selbst. Musik und Töne lassen sich auch im Hauptmenü oben links umschalten
(zwei Pillen, F3/F4); die Wahl liegt in `user://einstellungen.cfg` und überlebt den Neustart —
außer im `--kiosk`: dort gilt sie nur für den laufenden Besucher und ist nach dem Idle-Reset
wieder an (sonst bliebe der Stand stumm, wenn jemand „Musik aus" tippt). In der Pause läuft der Idle-Reset weiter (Messe: wer weggeht, landet
wieder im Hauptmenü). `--test-eingabe=-,-,-,-,ESC,-,F12,DOWN,DOWN,SPACE,-,F12,ESC` prüft
den Weg Taste → Pause → Menü.
Arcade-Encoder: Belegung aus `config/input-bindings.json` (identisch zur Phaser-Fassung).

**Statistik (anonym):** `src/core/Statistik.gd` zählt je Station erreicht, geschafft, Zeit,
Treffer, Stürze, Neustarts und Abbrüche (Idle/Hauptmenü), je Durchlauf Sprache, Bedienung und
Gesamtzeit — keine Namen, nichts verlässt den Rechner. Je Tag `user://statistik/tag-*.json`
(Summe fürs Betreiber-Menü) und `ereignisse-*.jsonl` (eine Zeile je Ereignis, zufällige
Lauf-ID). Auswertung: `python godot/tools/statistik_auswerten.py [ordner] [--csv x.csv]`
(Standard: `%APPDATA%/Godot/app_userdata/Paul & REZI/statistik`). Testläufe (`--script`,
`--headless`, `--shots`) zählen getrennt in `user://statistik-test/`.

**Schneller ins Spiel:** In der Zeitreise überspringt Halten (1,2 s) FRÜHER **und** HEUTE und
führt direkt zum Probelauf; `"zeitreise": false` in `config/game-config.json` lässt sie ganz
weg. Im Probelauf wartet Paul in der ersten Runde auf den Spieler (TI-Aktion, loslaufen,
springen — „Du bist dran"); wer nichts drückt, sieht nach 6 s die Vorführung.

**Feststecken:** Nach 18 s ohne Fortschritt gibt REZI einen Tipp, ab `stuckGuideSeconds` (30)
zeigt ein ruhiger Pfeil über Paul zum nächsten Ziel (fehlende Prüfsumme, offene Station, Tür).
Wer an einer offenen Station wartet (Schleuse, Stempel …), gilt nicht als festgefahren.

**Vorführung (Attract):** Steht im `--kiosk` der Titel `attractSeconds` (25) unberührt, spielt
Paul den Probelauf allein vor; jeder Druck holt den Titel zurück. Kaputte Leveldaten
(Datei fehlt, JSON defekt) überspringen die Station statt ein leeres Level zu zeigen.

**Wissensabfrage und Info-QR:** Vor dem Abschluss fragt das Spiel zwei bis drei Fragen
(links/rechts, Fragen in `config/wissensfragen.json`, abschaltbar mit `"wissensabfrage": false`).
Alle richtig = vierte Medaille „WISSEN“. Die Fragen sind ein **Entwurf** fürs gematik-Review;
solange dort `"entwurf": true` steht, zeigt das Quiz einen kleinen Vermerk. Neben dem Gewinn-QR
für den Automaten steht ein kleiner Info-QR (`ending.infoLink`, erzeugt mit
`python godot/tools/gen_assets.py --nur-qr`). Medaille LÜCKENLOS gibt es nur in Stationen mit Lauschern.

## Sprachen

Sechs Sprachen, umschaltbar über die Flaggen oben rechts im Hauptmenü (Klick oder
Fingertipp; F2 oder Stick/Pfeil hoch/runter blättert; im Browser startet das Spiel in der Browsersprache, falls vorhanden): Deutsch, Englisch, Französisch, Spanisch, Chinesisch, Hindi.
Das Menü baut sich mit der neuen Sprache neu auf, alles danach (Zeitreise, Probelauf,
ePA-Wissen, Briefings, HUD, Hinweise im Level, Stationskarte, Reward) folgt ihr. Beim
Idle-Reset gilt wieder die Standardsprache (`language` in `config/game-config.json`).

- **Übersetzungen** liegen in `i18n/*.json` (`ui`, `intro`, `briefing`, `levels`, `wissen`): Schlüssel
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
| Pause | `src/ui/PauseMenu.gd` | Overlay über dem Level (Baum angehalten): Weiter, Station neu starten, Steuerung, Musik an/aus, Töne an/aus, Zum Hauptmenü; Idle-Reset läuft weiter (nur `--kiosk`). |
| Stations-Briefing | `src/ui/Briefing.gd` + `src/ui/BriefingDaten.gd` | Vor jeder der zehn Stationen: was in der Wirklichkeit passiert, 4–5 laienverständliche Zeilen im Takt, animierte Mini-Szene der Mechanik, „Das tust du" mit den Knopfnamen der gewählten Bedienung, Leiste aller Bausteine des Levels (aus `level.json` + `layout.txt`). Oben die Reiseroute der zehn Stationen (Haken für geschaffte, die aktuelle pulsiert), Bühnenlicht auf der Szene, die Bausteine treten nacheinander hervor. Inhalte in `BriefingDaten.STATIONEN`; Prüfschalter `--shots=<dir> --shots-briefings` fotografiert alle zehn. |

**Erzählband:** Alle Erzählzeilen (FRÜHER, HEUTE, ePA-Wissen, Briefings) stehen in einem
dunklen Textband unter der Überschrift — Schrift 11 statt 9,5 Design-px, weiß auf dunklem
Grund, mehrzeilig, REZI als Erzähler mit Sprechwellen, Aufbau Zeichen für Zeichen,
Zeilenpunkte, leiser Tick je Zeile (`Vignette.story_line`, Takt über `story_cycle`).
Jeder Screen gleitet beim Öffnen ein (`Vignette._entrance`); zwischen den Screens fährt
eine schräge Blende mit orangefarbenem Saum durchs Bild (`src/shaders/wipe.gdshader`,
`Main._fade_out` / `_fade_in`). Die Stationskarte nach jedem Level (`src/ui/LevelCard.gd`)
folgt `brand/DESIGN-PROMPT.md` statt dem früheren Look aus Farbverlauf, drehendem
Strahlenkranz, drei Sternkarten und Funkenregen: ruhige Fläche in der Farbe der Zone, links
die Route der Stationen, Eyebrow, Stationsname in Charter und der Merksatz, rechts eine
Ergebnis-Tafel mit drei Zeilen (Zeit, Prüfsummen, Lückenlos) und den Punkten, darunter der
Weiter-Knopf in PwC-Orange, links unten die Zone als Fußnote. Die Zeilen bekommen
nacheinander ihren Prüfvermerk (gelb mit Haken = geschafft, Strichring = offen), bei drei
von drei landet ein „GEPRÜFT“-Stempel; nach 2,4 s steht das Bild still. Lange Namen werden
passend gesetzt, zweizeilige Sätze ausgeglichen umbrochen. `tests/test_stationskarte.gd`
prüft das in allen Stationen und Sprachen, `tests/kartenbild.gd` macht Bilder der Karte
ohne Durchspielen (Xvfb).

| Screen | Datei | Inhalt |
|---|---|---|
| Hauptmenü | `src/ui/Title.gd` | Das Klinikum im Puppenhaus-Schnitt (OP, Stationen, Flur, Empfang; im Keller Konnektor → VAU → Fachdienst ePA), Aufzug, Heli, Passanten, Datenpulse; Paul & REZI auf dem Apotheken-Dach; Steuerungstafel, Tages-Bestenliste. 1:1-Port des Web-Hauptmenüs. |
| FRÜHER / HEUTE | `src/ui/Intro.gd` (Phase 1, 2) | Die Zeitreise: dieselbe Straße, zwei Zeiten. Papier, Boten, Fax, Warteschlangen — dann die TI als Lehrstück in fünf Schritten (Sprechzimmer, Konnektor legt die Hülle an, TI-Gateway, VAU schreibt die Akte, Abruf in App und beim nächsten Arzt). **Das ist die Erklärung, was sich mit ePA und TI geändert hat.** |
| SO SPIELST DU | `src/ui/Intro.gd` (Phase 3) | Probelauf: zuerst drückt Paul am Terminal die TI-Aktion (Tafel „TI-AKTION“ mit Taste E / Knopf BLAU / AKTION), dann läuft der echte Paul im Autopilot über eine Grube, sammelt ein Datenbit, schaltet die Hülle — Popups mit Tastenkappen (Tastatur, Arcade-Knöpfe oder Touch-Knöpfe, je nach erkannter Hardware). |
| ePA-Wissen | `src/ui/Wissen.gd` | Vier Lehrsequenzen („Deine Akte", „Die Medikationsliste", „Befugnis auf Zeit", „Deine Regeln") vor den vier ePA-Stationen, Zuordnung in `Wissen.VOR_LEVEL`. |

Alle Info-Screens erben von `src/ui/Vignette.gd`: Bühne im 640×360-Design-Raum der
Web-Fassung (Node2D ×3 → 1920×1080, Koordinaten der Originale gelten unverändert),
Schriften unskaliert als Label. **Erzählzeilen blättert der Spieler selbst** (Team-Feedback
9/2026): jeder Knopf zeigt erst die ganze Zeile, dann die nächste; ← / Steuerkreuz links
blättert zurück; Knopf 1,2 s halten überspringt den Screen; Finger/Maus im linken Drittel
zurück, sonst vor. Screens ohne Erzählzeilen und der Prüflauf (`--shots`) laufen weiter nach
der Uhr mit Mindestdauer. Die Stationskarte wartet auf Knopf, Tipp oder Klick. REZIs
Sprechblasen stehen nach Textlänge (2,5–9 s); neue Sätze warten kurz, statt laufende zu
überschreiben. Stationstexte nennen Knöpfe über Platzhalter (`{action}`, `{toggle}` …,
eingesetzt von `BriefingDaten.tasten`), über TI-Stationen schwebt eine Tastenkappe.
Zeichen-Vokabular in `src/ui/Pen.gd`. Kein Blinken über 3 Hz.

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
(≈ 40 MB Godot-Laufzeit), `index.pck` (das Spiel, ≈ 6 MB), Audio-Worklets, Icons, dazu
`Start im Browser.bat`, `serve_web.py` und `LIESMICH.txt`. Das PCK ist für Web und Windows
gleich groß: 5 949 456 Bytes, davon 4,6 MB Musik (gemessen am 24.11.2026 mit `--export-pack`,
ohne Markenschriften). Mit den lokal eingelegten Markenschriften kommt knapp 1 MB dazu.
Ein Web-Build läuft nicht per Doppelklick auf `index.html` (Browser laden `.wasm`/`.pck`
nur über HTTP), deshalb der
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
| `Messe-Kiosk.bat` | **Für den Messestand:** Kiosk mit Neustart-Schleife — nach Absturz oder Beenden startet das Spiel nach 3 s neu (Protokoll `kiosk-neustarts.log`); nur Strg+Umschalt+F12 beendet wirklich. Vorher am Messe-PC Energiesparen/Bildschirmschoner, Windows-Updates und Benachrichtigungen (Fokusassistent) abschalten; für Autostart die Datei in `shell:startup` verknüpfen. |
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
| `python godot/tools/build_levels.py` | **alle zehn Level** aus dem Generator bauen (Geometrie + Objekte) und die Erreichbarkeit prüfen (Sprung 3 hoch / 5 weit, in Hülle-Leveln 4; Bonus per REZI-Schub, Sprungfedern). Mit `--sprungweiten` zeigt er je Level den breitesten Pflichtsprung und schreibt nichts |
| `python3 godot/tools/pruefen.py` | alle Prüfstufen vor dem Push (siehe „Prüfen vor dem Commit") |
| `python godot/tools/erzeugung_protokoll.py --neu …` | eine Erzeugung mit einem KI-Dienst festhalten (Prompt, Modell, Kosten, SHA-256); `--pruefen` prüft das Protokoll, `--liste` zeigt die Kosten |
| `python godot/tools/gen_assets.py` | Klänge (WAV) und QR-Code erzeugen (`assets/`); braucht `numpy`, `qrcode`, `Pillow`. Die Musik kommt als OGG (Pixabay, aus MP3 umgewandelt), siehe `assets/audio/CREDITS.md` |
| `powershell -ExecutionPolicy Bypass -File godot\tools\build.ps1` | Auslieferungspaket in `build/` (PCK + signierte Laufzeit + Verknüpfungen + EXE) |
| `Godot … --headless --import` | Projekt-Cache aufbauen, Skriptfehler sehen (`SCRIPT ERROR`) |
| `Godot --headless --path godot --fixed-fps 60 --script res://tests/lauf.gd` | **Testlauf** ohne Fenster (siehe „Tests"); `-- --nur=huelle` nur passende Dateien |
| `Godot --headless --path godot --fixed-fps 60 --script res://tests/frame_messung.gd -- --level=<id>` | CPU-Zeit je Frame an mehreren Stellen einer Station (vorher/nachher vergleichen) |
| `Godot --path godot --script res://tests/standbild.gd -- --level=<id> --an=vau-feld,0.42,pause --ziel=<ordner>` | Screenshots an gezielten Stellen (Baustein-Typ, Anteil der Breite, Pausemenü) |
| `Godot … --headless --export-release "Windows" build/PaulUndRezi.exe` | Windows-Build (Preset in `export_presets.cfg`) |
| `Godot … --quit-after 3600 -- --shots=<abs. Ordner>` | Screenshot-Prüflauf ohne Menschen am Rechner |
| `Godot … --headless --export-release Web build-web/index.html` | Browser-Fassung nach `build-web/` (Preset „Web") |
| `python godot/tools/serve_web.py [port]` | lokaler Server für die Browser-Fassung, öffnet den Browser |
| `python godot/tools/gen_i18n_fonts.py` | Schrift-Untermengen für Chinesisch/Hindi aus den Übersetzungen neu bauen (`assets/i18n/`) |
| `python godot/tools/deploy_web.py` | Web-Export neu bauen und als Branch `web` nach GitHub pushen — GitHub Pages veröffentlicht daraus: https://arantir01010.github.io/erezept-jump-and-run/ (`--no-export` nimmt `build-web/`, `--no-push` nur lokal) |

### Tests

`tests/lauf.gd` findet alle `tests/test_*.gd` und ruft jede Methode `test_*` auf. Gewertet
werden die Prüfungen UND jede Fehlermeldung der Engine währenddessen (`tests/fehlerzaehler.gd`
hängt sich als Logger an) — ein `SCRIPT ERROR` in einem Baustein lässt den Test durchfallen,
auch wenn alle Prüfungen grün sind. Letzte Zeile: „N Tests, M fehlgeschlagen", Exit-Code 0/1.
`--fixed-fps 60` macht die Spielzeit unabhängig vom Rechner. Inhalt: Hülle-Mechanik (Port der
Phaser-Tests), Spielstand (Treffer kostet nur Bits dieser Station), Leveldaten aller Stationen,
Übersetzungen (alle Sprachen, gleiche Platzhalter, jeder `tr("…")`-Text übersetzt), Kiosk
(Idle-Reset nur mit `--kiosk`), Level-Mechanik (verstreute Prüfsummen, Zeichen-Culling), ein
Rauchtest, der jede Station über die echte Hauptszene startet, spielt und abschließt,
Bedienung (`test_bedienung.gd`: Pausemenü, Neustart, Tür-Sicherheitsnetz, Tastenkappe,
Blättern, Stationskarte, REZI-Lesezeit), Lesbarkeit (`test_lesbarkeit.gd`: HUD im Bild,
Störfelder ruhig, Lauscher-Warnung, nichts blinkt über 3 Hz) und Messebetrieb (`test_messe.gd`:
Bedienwahl ohne Touchscreen, Ton im Kiosk, Busse/Begrenzer, Lautstärke, Vorladen, Sturz →
Fahne mit Blende und Kamera, Fahnen höchstens 35 Kacheln auseinander, kaputte Bestenliste,
Abschluss-Badges, Zeitreise überspringen, Mitmach-Probelauf, Leitpfeil, Statistik,
Betreiber-Menü). `test_texte.gd` prüft außerdem
Knopf-Platzhalter je Sprache und dass Chinesisch/Hindi nur Zeichen nutzen, die die
Untermengen-Schriften in `assets/i18n/` haben (sonst Kästchen). Gewartet wird in Spielzeit,
nicht in Echtzeit (siehe „Flüssig an schnellen Monitoren“).
`tests/` wird nicht exportiert. Ein fertiger GitHub-Workflow liegt in `tools/ci/godot-tests.yml`
(Aktivieren nur durch Menschen: `.github/` gehört zum versiegelten Phaser-Kern).

### Prüfen vor dem Commit

`godot/tools/pruefen.py` prüft die Godot-Fassung von billig nach teuer. Es braucht Python 3.8+
und Godot 4.7.2 aus `PATH`, `GODOT` oder `--godot <pfad>`:

```bash
python3 godot/tools/pruefen.py            # Stufen 0–5: Dateien, Level-Generator, Import, Typwarnungen, Tests, Exportprobe
python3 godot/tools/pruefen.py --schnell  # nur 0 und 1, ~2 s, ohne Godot
python3 godot/tools/pruefen.py --bilder   # zusätzlich Bildprobe (Linux: xvfb-run, mehrere Minuten)
```

Jede Stufe schreibt eine Zeile `STUFE n Name: …`. Die letzte lautet
`N Stufen, M fehlgeschlagen, K übersprungen`. Rückgabe 0 heißt sauber, 1 Fehler, 2 etwas
übersprungen. Die Logs liegen in `godot/.pruefen/`. Mehr Typwarnungen als in
`godot/tools/grenzwerte.json` lassen Stufe 3 scheitern. Die Grenzen zieht man nur bewusst nach:
`--nur 3 --grenzen-nachziehen`.

Der Commit-Haken wird einmal je Klon eingeschaltet und gilt für alle Arbeitskopien:
`git config core.hooksPath godot/tools/githooks`. Dann läuft `--schnell` vor jedem Commit mit
Dateien unter `godot/`. Abschalten: `git config --unset core.hooksPath`. Einmal umgehen:
`git commit --no-verify`.

### Herkunft der Dateien

Alle Grafiken sind prozedural (Vektorzeichnung zur Laufzeit), die kurzen Klänge synthetisiert
(`tools/gen_assets.py`). Fremd sind die vier Musikstücke (Pixabay Content License) und die
Noto-Schriften (SIL OFL 1.1). Die Markenschriften und Piktogramme sind lizenziert und nicht im
Repository. Die Herkunft jeder Datei steht in `assets/HERKUNFT.json`, `tests/test_herkunft.gd`
prüft, dass keine fehlt.

**Offen:** Pixabay untersagt die Weitergabe der Stücke als eigenständige Dateien. Im
öffentlichen Repository liegen sie aber einzeln, aus dem Web-Paket lassen sie sich herauslösen.
Die Entscheidung steht aus.

Dateien von einem KI-Dienst bekommen in `HERKUNFT.json` das Feld `"ki": true`. Jede Erzeugung
kommt als eine Zeile nach `docs/erzeugungsprotokoll.jsonl`, mit Prompt, Modell, Datum, Kosten
und SHA-256 der Datei (`python godot/tools/erzeugung_protokoll.py --neu …`). Der Test verlangt
zu jeder KI-Datei eine Zeile mit derselben SHA-256. Zugangsdaten, signierte Adressen und
E-Mail-Adressen lehnt das Werkzeug ab. `docs/` wird nicht exportiert, Prompts und Kosten
landen also nie im Spiel.

Wer gezeichnete Kunst einbauen will, ersetzt die `_draw()`-Methoden von `PaulVisual`, `Rezi`,
`Terrain`, `Backdrop` durch Sprites.

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
(3 Kacheln hoch, 5 Kacheln weit, in Hülle-Leveln 4) lösbar sein — der Schub ist für Bonuswege.

`LevelData` lädt streng. Jedes Feld wird gegen das Schema in `src/core/LevelData.gd` geprüft.
Tippfehler, fehlende Pflichtfelder, Kommazahlen in Ganzzahlfeldern und falsche Typen werden
zu Befunden, je eine Zeile `<datei>: <feld>: <grund>`. Im Spiel erscheinen sie nur als
Warnung, das Level läuft weiter. `tests/test_leveldaten_streng.gd` wertet sie als Fehler.

Alle zehn Level in `levels/<id>/` entstehen aus `tools/build_levels.py` (Kishōtenketsu:
Einführung → Entwicklung → Wendung mit Weggabelung → Abschluss). Seit 03.09.2026 sind sie
30–50 % länger und fordernder: Plattformketten mit wechselnden Höhen, Sprungfedern,
Pendel-Plattformen über Gruben, schmale Podeste über Störfeldern, Wandsprung-Schächte
(nur für Bonuswege), Lauscher an Ausstiegen; Station 01 bleibt sanft. Der Generator prüft
per BFS, dass Pflichtwege ohne Treffer, ohne REZI-Schub und ohne Wandsprung lösbar sind
(Hülle-Level mit kürzeren Sprungweiten), leitet Par-Zeit und Sammelziel ab und stellt
sicher, dass die Prüflauf-Positionen 42/66/86 % freier Boden sind. Seit 24.11.2026 prüft er
auch Hindernisse zwischen Absprung und Landung (kein „Sprung" mehr über einen 4 Kacheln hohen
Turm) und **Einbahnstraßen**: Wo es keinen Rückweg zum Start gibt, müssen danach noch so viele
Prüfsummen erreichbar sein, wie die Tür verlangt — sonst lehnt er das Level als Softlock ab
(so entstand der Softlock am Kistenturm in Station 04). Wer ein Level ändern
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

### Grafikstufen und Glühen

Wie aufwendig gezeichnet wird, entscheidet eine Stelle: `src/core/Grafik.gd`. Stufen ändern nur
die Bildqualität, nie Ort, Größe oder Zeitpunkt.

| Stufe | Wann | Was |
|---|---|---|
| 0 „Browser" | Web-Build, `--webfx` | Glüh-Sprites statt HDR-Glühen, CPU-Partikel |
| 1 „Mitte" | `--grafik=1` | HDR-Glühen bleibt, CPU- statt GPU-Partikel, 2D-MSAA höchstens 2× |
| 2 „Voll" | Desktop-Vorgabe | HDR-Glühen, GPU-Partikel mit Sub-Emittern, MSAA 8× |

`--grafik=0|1|2` übersteuert die Wahl, auch `--webfx`. Für das Glühen gibt es zwei Varianten.
`--glow=a` ist die Vorgabe mit den bisherigen Werten. `--glow=b` nutzt den Modus Screen mit
Schwelle 2,0, Stärke 0,3 und Entbänderung. `--glow=aus` ist nur zum Messen gedacht. F7 wechselt
zwischen A und B und blendet kurz ein, welche Variante läuft. Das geht nur mit `--vergleich`
oder im Debug-Build ohne `--kiosk`. Beim Start wärmt `Grafik.vorwaermen` Shader und Partikel
unter der Blende vor, `--ohne-vorwaermen` schaltet das ab. Bilder vergleichen:
`python godot/tools/bildvergleich.py vorher/ nachher/ --aus vergleich/ --md`.

**Lesbarkeit (Team-Feedback 9/2026):** Das HUD hat keine eigene Rand-Vignette mehr (die
gestufte zeichnete ein Streifenraster); die Zähler hängen in einer Spalte an der rechten
Bildkante, die Zeit ist unter Par PwC-Gelb. Störfelder sind deckend rot mit dunkler Kontur,
rot-dunkel schraffiertem Sockel und rotem Bodenschein, der ruhig mit 1,2 Hz atmet — kein
Orange, denn warm heißt „Klartext". Der Lauscher-Kegel ist nur warm mit Kontur, solange Paul
im Klartext lesbar ist; verschlüsselt oder in der VAU wird er blass und neutral. Paul blinkt
nach einem Treffer mit 2 Hz.

### Flüssig an schnellen Monitoren

Die Physik tickt mit 60 Hz. Paul wird zwischen zwei Physikschritten gezeichnet
(Physik-Interpolation, nur für ihn). Wer Paul im Bild folgt, also Kamera, Nachbilder und
Leitpfeil, nimmt `Player.render_position()` und nicht `global_position`. Messen:
`godot --headless --path godot --fixed-fps 144 --script res://tests/taktprobe.gd`.

Spiellogik mit Zeitbezug (Kombo-Fenster, Laufzeit, Schonzeit, Sprungfenster) zählt Spielzeit
(`Game.spielzeit`), nicht die Wanduhr. Sie steht in der Pause und folgt der Zeitlupe. Titel,
Intro und Briefings rechnen ebenfalls aus `delta`. Tests warten deshalb mit `sekunden()` oder
`frames()`. Echte Zeit messen die Messe-Statistik und der Kiosk-Leerlauf. Ebenfalls nach der
Uhr, aber ohne Einfluss auf Punkte, laufen die Abstände zwischen REZIs Tipps und das
Kulissen-Leben.

## Marke (PwC)

Schrift und Bedienelemente folgen dem PwC-Erscheinungsbild, die Spielgrafik nicht:
Helvetica Neue für alles Lesbare, ITC Charter Bold für große Überschriften, UI-Flächen in
PwC-Grau mit Tangerine/Orange für Aufforderungen und Yellow für Erfolg. Alles sitzt in
[`src/core/Brand.gd`](src/core/Brand.gd); Regeln, Herkunft der Dateien und der
Lizenz-Hinweis (Desktop-EULA, App-Einbettung klären) stehen in
[`brand/README.md`](brand/README.md). Fehlen die Schriftdateien, läuft das Spiel mit der
Godot-Standardschrift weiter.

## Bausteine und Regeln

Jeder Stationsbaustein (Kartenleser, Lauscher, VAU-Feld …) steht in einer eigenen Datei unter
`src/mechanics/stationen/`. `src/mechanics/Stations.gd` ist nur das Verzeichnis:
`Stations.REGISTRY` ordnet jedem Typ aus `level.json` sein Skript zu. Die alten Namen wie
`Stations.Kartenleser` gelten weiter. Ein neuer Baustein braucht eine eigene Datei und einen
Eintrag in `Stations.gd`, die `.uid` wird mit committet. Seine Felder gehören ins Schema
`LevelData.BAUSTEINE`, sonst schlägt `tests/test_leveldaten_streng.gd` an.

`src/state/` enthält reine Regelklassen. Sie erben von `RefCounted` und halten Zustand und
Regeln ohne Szene. Die Zeit kommt als Argument, Änderungen gehen per Signal hinaus. So laufen
sie im Test ohne Level (Beispiele: `Huelle`, `SprungFenster`). Knoten, Zeichnen, Dateien, Uhr,
Eingabe, Autoloads und Klassen der äußeren Ordner sind dort tabu. Das prüft
`python godot/tools/schichten_pruefen.py` (Schlusszeile `N Dateien, M Brüche`).

## Struktur

```
godot/
├── project.godot, export_presets.cfg
├── scenes/Main.tscn                 einzige Szene — alles Weitere entsteht im Code
├── src/
│   ├── Main.gd                      Ablauf: Hauptmenü → Zeitreise → Probelauf → Level → Karte → (Wissen) → … → Reward
│   ├── autoload/  Game.gd (Zustand, Punkte, Medaillen, Highscore) · Sfx.gd (Klang) · Kiosk.gd (Eingabe, Messe, Prüflauf)
│   ├── core/      LevelData.gd (Level-Parser mit Schema) · Palette.gd (Materialsystem) · Brand.gd (PwC-Schrift, UI-Farben)
│   │              · Grafik.gd (Grafikstufen, Glühen) · Komfort.gd (Bewegung reduzieren) · Statistik.gd (anonyme Zählung)
│   ├── player/    Player.gd (Controller) · PaulVisual.gd (Figur)
│   ├── actors/    Rezi.gd
│   ├── world/     Level.gd · Terrain.gd + terrain/ (Blocktexturen, Wind-Flora, Pfützen, Bodennebel)
│   │              · Backdrop.gd + backdrop/ (Ebenen, Leben, Vordergrund, Partikel, Lichtstrahlen) · GameCamera.gd
│   ├── shaders/   wind · puddle · ground_fog · kulisse_blur · god_rays · hall_rays · vau_gitter (.gdshader)
│   ├── mechanics/ Mechanic.gd · Basics.gd · KartenFx.gd · Stations.gd (Verzeichnis) · stationen/ (ein Baustein je Datei)
│   ├── state/     Huelle.gd (Kernmechanik) · SprungFenster.gd — reine Regelklassen ohne Szene
│   ├── fx/        Fx.gd (Partikel, Lichter, Hitstop, Stempel, Browser-Fallback) · PostFx.gd (Grading je Welt) · Weather.gd (Regen, Blitz)
│   └── ui/        Vignette.gd + Pen.gd (Info-Screen-Basis) · Title.gd (Hauptmenü/Klinikum) · Intro.gd (Zeitreise + Probelauf)
│                  · Wissen.gd (ePA-Sequenzen) · Quiz.gd (Wissensabfrage) · TouchControls.gd · HUD.gd · LevelCard.gd · Reward.gd
├── levels/        Godot-eigene Level; _import/ = Sync aus design/
├── config/        Sync aus public/config/
├── assets/        audio/ (Klänge generiert, Musik von Pixabay) · qr/ · i18n/ (Noto-Untermengen) · HERKUNFT.json
│                  · fonts/ + brand/ (Marke, lizenziert, nicht im Repo)
├── brand/         Marken-README + Lizenzdokumente
├── docs/          Bewertung, Recherche, Konzept, Umfrage (Excel)
│                  · erzeugungsprotokoll.jsonl (KI-Erzeugungen, entsteht mit dem ersten Eintrag)
├── i18n/          Übersetzungen (ui, intro, briefing, levels, wissen) — Schlüssel = deutscher Text, Spalten en/fr/es/zh/hi
├── tests/         lauf.gd (Testlauf) · test_*.gd · frame_messung.gd · standbild.gd — nicht im Export
├── tools/         sync_levels.py, gen_assets.py, build_levels.py, gen_i18n_fonts.py, build.ps1, serve_web.py, deploy_web.py, aufraeumen.py
│                  · pruefen.py + grenzwerte.json (Prüfstufen) · schichten_pruefen.py · bildvergleich.py
│                  · erzeugung_protokoll.py (KI-Protokoll) · statistik_auswerten.py · githooks/ (Commit-Haken)
│                  · ci/godot-tests.yml (vorbereiteter GitHub-Workflow, nicht aktiv)
├── build/         Windows-Paket (generiert)      · build-web/  Browser-Fassung (generiert)
└── shots/         Screenshot-Prüfläufe (generiert)
```

## Bekannte Grenzen (Stand 02.09.2026)

- Kein Android-/iOS-Export (Templates nachladen bzw. Xcode); für Tablets reicht die
  Browser-Fassung.
- Im Browser kein HDR-Glühen und kein 2D-MSAA (Compatibility-Renderer).
- Die Tages-Bestenliste im Hauptmenü erscheint erst, wenn an diesem Tag gespielt wurde.
