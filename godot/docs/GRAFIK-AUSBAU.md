# Grafik-Ausbau: Recherche und Plan (3. September 2026)

Ergebnis der Recherche „Wie könnten wir die Grafik noch verbessern?" — abgeglichen mit dem,
was die Godot-Fassung heute schon tut. Die HTML-Fassung mit Bildern liegt als Artefakt vor
(siehe Chat); dieses Dokument ist die Kurzform zum Weiterarbeiten.

## 1. Was heute schon drin ist

- Sonne als `DirectionalLight2D` mit weichen Schatten (PCF13, gefärbte Schatten je Welt),
  REZI als Punktlicht mit Schatten, Lauscher mit Kegellicht.
- Standflächen mit Normal-Map und Specular (`CanvasTexture`), gewellte helle Kappen,
  dunkle Konturen, Details (Fugen, Gras, Moos, Risse).
- Sechs Parallax-Ebenen (Sonne, Wolken, fern, mittel, nah, Nebel) mit Nebelbändern und
  Tiefenfarbe (Luftperspektive), Schwebepartikel, Regen als Partikel.
- HDR-2D-Glühen nur für echte Lichtquellen (Schwelle 1,35) — Windows-Fassung.
- Post-Effekt: Split-Toning (Schatten kühl, Lichter warm), Korn, Vignette, chromatische
  Aberration bei Treffern, Blitz.
- Game Feel: Squash/Stretch, Lehnen, Kontaktschatten, Hitstop, Slow-Motion beim Siegel,
  Kamera-Kick und -Punch, Staub, Funken, Ringe, REZI-Spur.
- Fünf Farbwelten mit begrenzter Palette; das Hauptmenü zeigt, wie lebendig eine Kulisse
  mit vielen kleinen Bewegungen wird.

## 2. Was die Recherche ergibt (Kernaussagen)

1. **Tiefe entsteht durch Ebenen, Nebel und Unschärfe — nicht durch mehr Detail.**
   Hollow Knight schichtet Kulisse / Nebel / Felsen, ferne Ebenen sind entsättigt und
   unscharf; Ori nutzt eine eigene Nebelkurve und Tiefenschärfe. Uns fehlt vor allem die
   **Vordergrund-Ebene** vor der Kamera und die **Unschärfe** der fernen Ebenen.
2. **Licht als Material.** UbiArt (Rayman Legends) erzeugt seinen 2,5-D-Look mit
   Normal-Maps auf allen Sprites (Kantenlicht). Bei uns tragen nur die Kappen Normal-Maps;
   Blöcke, Requisiten und Figuren nicht.
3. **Bewegung in der Welt.** Wind in Gras und Bäumen, Umgebungspartikel je Welt
   (Pollen, Glühwürmchen, Staub im Lichtstrahl, Regenspritzer), Lichtstrahlen. Alles
   günstig als Canvas-Shader oder Partikel.
4. **Figur: Silhouette und Sekundärbewegung.** Ori setzt auf lesbare Silhouetten und
   Anhängsel (Schwanz), Celeste auf die Haare als Kettensimulation. Paul hat weder Schal
   noch Kapuzenbewegung — das ist der größte Sprung fürs Spielgefühl.
5. **Juice mit benannten Konstanten.** Squash-Feder, Shake-Abfall, Hitstop 0,08 s,
   Zoom-Punch, Kombo-Tonhöhe — das meiste haben wir; es fehlen Geisterspur beim
   REZI-Schub und Musik-Ducking bei Treffern.

## 3. Godot-4.7-Werkzeuge, die wir noch nicht nutzen

| Werkzeug | Wofür |
|---|---|
| `CanvasGroup` + Blur-Shader | Tiefenschärfe je Parallax-Ebene (fern unscharf) |
| `Parallax2D` mit `scroll_scale > 1` | Vordergrund-Ebene vor der Kamera (Geländer, Blätter, Kabel) |
| `GPUParticles2D` (Trails, Sub-Emitter, Kollision mit `LightOccluder2D`) | Regenspritzer am Boden, Funken beim Siegel, REZI-Spur als echtes Band |
| `LightOccluder2D.sdf_collision` | Signed-Distance-Field fürs Gelände: Nebel, der am Boden klebt; Kontaktglühen |
| `CanvasTexture.specular_*` auf Blöcken | nasser Look in der Regenwelt |
| Wind-Sway-Canvas-Shader | Gras, Pflanzen, Bäume, Kabel |
| `DrawableTexture2D` (neu in 4.7) | Laufzeit-Decals: Fußspuren im Regen, Hülle-Spuren |
| `GradientTexture2D` konisch (neu in 4.7) | VAU-Ring als ablaufender Kreis statt Balken |
| Scene Paint Mode (neu in 4.7) | Requisiten im Editor malen, wenn Level dekoriert werden |
| `Skeleton2D` + `Polygon2D` | Art-Pass für Paul/REZI mit gezeichneten Texturen |
| Shader Baker (seit 4.5) | Ruckelfreier Start im Paket |

## 4. Der Plan

**A — Schnelle Gewinne (je ≤ ½ Tag)**

1. Vordergrund-Ebene (`scroll_scale` 1,15–1,3): dunkle, leicht unscharfe Silhouetten.
2. Fern-/Mittel-Ebene per `CanvasGroup` + Blur weichzeichnen (Tiefenschärfe).
3. Wind-Shader für Gras/Pflanzen/Bäume; Paul biegt Gras beim Vorbeilaufen.
4. Umgebungspartikel je Welt: Pollen (Morgen), Glühwürmchen (Abend), Regenspritzer
   (Regen, Sub-Emitter bei Kollision), Staub im Lichtstrahl (RZ), Papierstaub (Archiv).
5. Lichtstrahlen (God Rays) von der Sonne und von Deckenlampen im Rechenzentrum.
6. Geisterspur beim REZI-Schub (Silhouetten-Nachbilder), Musik-Ducking bei Treffern.
7. VAU-Zeit als konischer Ring, Siegel-Burst mit Sub-Emitter.
8. Schattenfarben je Welt feinjustieren (Sonne UND REZI-Licht, kühl statt schwarz).
9. Browser: HDR 2D im Compatibility-Renderer wurde am 3.9. getestet — kein Glühen,
   dafür ausgewaschene Farben; bleibt aus (`viewport/hdr_2d.web=false`). Stattdessen
   additive Leuchtsprites an Prüfsummen, REZI und Lampen (`OS.has_feature("web")`),
   optional ein Blur-Pass im Post-Effekt; `antialiased`-Flags beim Zeichnen setzen.

**B — Mittel (1–3 Tage)**

10. Pfützen und nasser Boden in der Regenwelt (Screen-Texture-Spiegelung + Specular).
11. Paul: Kapuze/Schal als Kettensimulation (Celeste-Haare), Anlauf-Ducken vor dem Sprung,
    Streckung beim schnellen Fall, Atem und Blick.
12. Kulissen-Leben je Welt wie im Hauptmenü: Vögel, ferne Fahrzeuge, blinkende Antennen,
    beleuchtete Fenster mit Innenleben am Abend, Server-LEDs im RZ.
13. Material-Pass Gelände: Normal-Maps auch für Blöcke und Requisiten, Kantenlicht.
14. Wetter und Tageszeit: Sonnenstand driftet über die Stationen, seltener Blitz im Regen
    (unter 3 Hz), Nebel dichter in Bodennähe (SDF).
15. Post-Effekt: Farb-LUT je Welt (3-D-Textur) für stärkere Stimmung ohne Inhaltsänderung.

**C — Art-Pass (Wochen, mit Zeichner:in)**

16. Gezeichnete Texturen auf den bestehenden Vektorformen (UbiArt-Prinzip), Paul/REZI
    auf `Skeleton2D` mit IK, Requisiten als Szenen für den Scene-Paint-Workflow, Stilguide
    aus `Palette.gd`.

## Stand 03.09.2026: Stufen A und B sind umgesetzt

Vier parallele Arbeitspakete (Kulisse · Gelände · Figur · Licht/Wetter/Post), jedes in
eigener Arbeitskopie geprüft, dann zusammengeführt und über alle fünf Welten, den
Probelauf-Screen, den Compatibility-Renderer und die Browser-Fassung getestet.

| Paket | Dateien | Umgesetzt |
|---|---|---|
| Kulisse & Tiefe | `src/world/Backdrop.gd`, `src/world/backdrop/*`, `src/shaders/kulisse_blur|god_rays|hall_rays.gdshader` | Vordergrund-Ebene je Welt (Parallax2D 1,2, nur Bildränder), Tiefenschärfe über CanvasGroup-Blur (fern 3 px, mittel 1 px), Kulissen-Leben (Vögel, Fahrzeuglichter, Antennen ≤ 1 Hz, Fenster mit Silhouetten, Server-LEDs), Partikel je Welt (Pollen, Glühwürmchen, Staub in Lichtbündeln, Papierstaub), Sonnenstrahlen (Morgen) und Hallenlicht (RZ) |
| Gelände & Material | `src/world/Terrain.gd`, `src/world/terrain/*`, `src/shaders/wind|puddle|ground_fog.gdshader` | Blockkörper mit welt-eigener Diffuse+Normal-Textur (Putz, Metall, Rack, Stein) und Bevel-Kanten → Kantenlicht von Sonne und REZI; Gras/Moos/Sträucher/Ranken im Wind-Vertex-Shader, Paul biegt Gras (federt < 3 Hz nach); Pfützen-Spiegelung und starkes Specular im Regen; Bodennebel über das Gelände-SDF; Gelände zeichnet nur noch einmal |
| Figur & Game Feel | `src/player/Player.gd`, `src/player/PaulVisual.gd`, `src/actors/Rezi.gd` | Kapuzenzipfel als Verlet-Kette mit hellem Bommel, Streckung im Aufstieg, Schmierstreckung im Schnellfall, Landungs-Squash nach Aufprall, Lehnen (Vorzeichenfehler behoben), Atmen, Blick, Ducken als Ball; Geisterspur beim REZI-Schub (5 Nachbilder, neutral hell); REZI mit Squash, Blick zu Paul, Antenne, Lach-/Schreck-Gesicht, Lichtband; Musik-Ducking bei Treffern |
| Licht, Wetter, Post | `src/world/Level.gd`, `src/fx/Fx.gd`, `src/fx/PostFx.gd`, `src/fx/Weather.gd`, `src/core/Palette.gd`, `src/mechanics/Basics.gd`, `src/mechanics/Stations.gd` | Gefärbte Schatten für Sonne, REZI und Lauscher (`Palette.shadow_for_light`); Regen als GPU-Partikel mit Spritzern an der Geländekante (SDF-Kollision, Sub-Emitter), seltener Blitz (2 Frames, ≤ 1/s); Sonnendrift je Station (`sun_drift`); parametrisches Grading je Welt (`grade_*`-Schlüssel, farbige Vignette), Menüs neutral; VAU-Restzeit als konischer Ring; Siegel-Burst mit Nachfunken; Landungsstaub nach Aufprall; Browser-Fallback `Fx.glow_sprite` an Prüfsummen, Tür, Tor, Checkpoint, REZI |

Neue Schalter (nach `--`): `--webfx` (Browser-Pfad am Desktop testen), `--blitz` (Blitz alle
4 s zum Prüfen), `--start-at=<baustein-typ>` (Paul auf den ersten Baustein dieses Typs
setzen, z. B. `vau-feld`). Windows-Export mit Shader Baker. Framezeit in beiden Renderern
bei 60 fps (Vsync).

Offen bleibt Stufe C (Art-Pass mit Zeichner:in) und der Donner-Klang (spielt automatisch,
sobald `assets/audio/donner.wav` existiert).

## Runde 2 (03.09.2026, abends): Erklären, Level, Figur, Karten, Bedienung

Wieder vier parallele Pakete in eigenen Arbeitskopien, danach zusammengeführt und über die
Welten 01/04/14/19/20, alle zehn Briefings, den Touch-Modus und den Browser-Pfad geprüft.

| Paket | Dateien | Umgesetzt |
|---|---|---|
| Stations-Briefings | `src/ui/Briefing.gd`, `src/ui/BriefingDaten.gd`, `src/Main.gd`, `src/autoload/Kiosk.gd`, `src/ui/Pen.gd` | Vor jeder der zehn Stationen ein Erklärscreen: Eyebrow, Stationsname (ITC Charter), ein Satz zur Wirklichkeit, 4–5 laienverständliche Zeilen im Takt, animierte Mini-Szene der Mechanik, „Das tust du" mit den Knopfnamen der gewählten Bedienung, Leiste aller Bausteine des Levels. Jeder Baustein, der in einem Level vorkommt, hat mindestens eine Erklärzeile. Fachliche Leitplanken aus KAPSEL eingehalten. Prüfschalter `--shots-briefings`. |
| Level | `tools/build_levels.py`, `levels/*` | Alle zehn Level 30–50 % breiter, Plattformketten mit wechselnden Höhen, Federn, Pendel-Plattformen über Gruben, schmale Podeste über Störfeldern, Wandsprung-Schächte (Bonus), Lauscher an Ausstiegen, Randwände; steigende Kurve ab Station 02; BFS-Checker mit Hülle-Weiten, Feder, Pendel-Endlagen, Schacht nur für Bonus, Par-Zeit und Sammelziel abgeleitet, Prüflauf-Positionen frei. |
| Laufrichtung | `src/player/Player.gd`, `src/player/PaulVisual.gd` | Diagnose: Beinzyklus lief in beide Richtungen rückwärts, Knie und Ellbogen knickten falsch, Blick folgte nur der Eingabe. Jetzt: Schrittphase mit Vorzeichen, korrekte Gelenke, Blick am Boden = Bewegungsrichtung, Bremspose beim Umdrehen mit Abdruck-Squash, Wandsprung und Treffer mit passender Blickrichtung, keine Eingabe-Latenz. |
| Karten | `src/mechanics/KartenFx.gd`, `src/mechanics/Stations.gd`, `src/ui/HUD.gd` | Karte schwebt mit Chip-Glanz und Namen, fliegt beim Aufnehmen im Bogen ins HUD; Kartenleser als Säule mit Display (erwartete Karte, Status), LED rot → gelb → grün, Karte gleitet sichtbar in den Schlitz und bleibt stecken; falsche Karte wackelt, „belegt" schüttelt; HUD-Fächer als Kartensymbole (leer / dabei / gesteckt); letzte Tür mit Vorhängeschloss und grüner Protokoll-Freigabe. |
| Bedienungswahl | `src/ui/Title.gd`, `src/ui/TouchControls.gd`, `src/autoload/Kiosk.gd` | Im Hauptmenü „TASTATUR · ARCADE" oder „TOUCH" wählen (Links/Rechts + Start, Tipp auf ein Feld); die Wahl steuert Overlay, Knopfnamen und Hinweise im ganzen Durchlauf. Prüfschalter `--test-eingabe=…` spielt echte Tastenereignisse ein. |

Dazu: REZI trägt statt des roten Kreuzes einen Rezept-Zettel (KAPSEL: kein rotes Kreuz).

## Runde 3 (03.09.2026, spät): Erzähltext, Zwischensequenzen, Schwierigkeit

Auftrag: Level etwas schwieriger, Zwischensequenzen aufwendiger, Erzähltext sichtbarer.
Diesmal ohne Sub-Agenten, ein zusammenhängender Umbau mit gemeinsamer Basis.

| Thema | Dateien | Umgesetzt |
|---|---|---|
| Erzählband | `src/ui/Vignette.gd`, `src/ui/Intro.gd`, `src/ui/Wissen.gd`, `src/ui/Briefing.gd` | Erzählzeilen in einem dunklen Band unter der Überschrift (Schrift 11 statt 9,5 Design-px, weiß auf 88 % Dunkel, mehrzeilig mit gemessener Bandhöhe), REZI als Erzähler mit Sprechwellen, Aufbau Zeichen für Zeichen (`visible_ratio`), Zeilenpunkte, leiser Tick je Zeile. Ein gemeinsamer Mechanismus (`story_line`, `story_cycle`, `story_u`) statt drei Kopien der Alpha-Schleife. |
| Zwischensequenzen | `src/ui/Vignette.gd`, `src/ui/Briefing.gd`, `src/ui/Wissen.gd`, `src/Main.gd`, `src/shaders/wipe.gdshader`, `src/ui/LevelCard.gd` | Entrance je Screen (Schilder gleiten gestaffelt von oben ein, Bühne/Leuchten/Leben blenden auf; Title behält seine eigene Choreografie); schräge Blende mit PwC-orangem Saum zwischen allen Screens statt Schwarzblende (zu: von links, auf: dieselbe Kante zieht weiter); Briefing mit Reiseroute der zehn Stationen (Haken, pulsierende aktuelle), Bühnenlicht und Bodenschein, Bausteine treten alle 1,5 s nacheinander hervor; ePA-Wissen mit „TEIL n / 4" und Fortschrittspunkten; Stationskarte mit Zonen-Farbverlauf, drehendem Strahlenkranz, Stempel-Einschlag des Stationsnamens (Siegel-Klang, Ring) und Funkenregen bei drei Medaillen. |
| Level | `tools/build_levels.py`, `levels/*` | Ketten-Lücken um eine Kachel weiter, letztes Podest je Podest-Reihe eine Kachel breit, zusätzliche Störfelder, Pendel-Plattformen schneller (58) und meist weiter (48 px), ein Rücksetzpunkt weniger je Level, Lauscher 12 % schneller (`LAUSCHER_TEMPO`), Sammelziel 14 statt 12 (Tunnel 18). Station 1 nur Lücken und Störfelder. Checker grün, Prüflauf-Positionen 42/66/86 % frei (in Station 04 dafür Störfelder und Pendelweite verschoben). |

Prüfung: Parser-Check, Prüfläufe 13 (ePA-Wissen, Briefing, Level) und 04 (mit zwei
Bildern mitten in der Blende: `01a-blende-zu.png`, `01a2-blende-auf.png`), alle zehn
Briefings (`--shots-briefings`), `npm run validate` grün, Browser-Fassung und Windows-PCK
neu gebaut.

## Runde 4 (04.09.2026): Sechs Sprachen

Flaggen oben rechts im Hauptmenü (DE EN FR ES ZH HI, Klick/Tipp, F2 blättert), das Menü
baut sich neu auf, die gesamte Oberfläche folgt: Zeitreise, Probelauf, ePA-Wissen, alle
zehn Briefings, HUD, Hinweise und Schilder im Level, Stationskarte, Reward. 429
Übersetzungsschlüssel in `i18n/*.json` (Schlüssel = deutscher Text), Godot-eigene
Mechanik (TranslationServer, auto_translate der Labels, `tr()` für formatierte Texte,
`Game.t()` für Level-Inhalte). Für Chinesisch und Hindi Noto-Sans-Untermengen (OFL) als
Schrift-Fallback, erzeugt aus den Übersetzungen (`tools/gen_i18n_fonts.py`). Geprüft mit
Prüfläufen in zh, hi und fr über den ganzen Ablauf und einem F2-Tastentest.

## Runde 5 (04.09.2026): Pause, Musik und Töne

Pause im Level (ESC/P, START am Gamepad, Pause-Knopf im HUD für Finger und Maus) mit
Menü Weiter / Musik / Töne / Hauptmenü (`src/ui/PauseMenu.gd`, Baum angehalten, Musik
geduckt, Idle-Reset läuft weiter). Musik und Töne getrennt schaltbar, auch oben links im
Hauptmenü (F3/F4), gespeichert in `user://einstellungen.cfg` (`Sfx.set_music/set_sound`).
Geprüft mit Tastentests (F3/F4 im Menü; ESC → Menü → Töne aus → ESC im Level).

Dazu ein Fund aus dem Spieltest: Im Tunnel-Level (KOV Gateway) zog die Auto-Scroll-Kamera
Paul am linken Rand per Teleport mit — mitten in Wände und aus dem Bild. Die Tunnel-Kamera
ist jetzt elastisch (Level._update_tube): sie fährt von selbst, wartet aber, sobald Paul
150 px vom linken Rand steht (Prüf-Podest, Krypto-Dusche), und eilt ihm nie davon; der
rechte Rand bleibt eine weiche Grenze. Prüflauf-Bild 07z-tunnel-wartet.png.

## 5. Nicht tun

Neon auf Kanten, Glühen für alles, mehr Sättigung, dunklere Paletten, KI-generierte Assets
ohne Lizenzprüfung, Blinken über 3 Hz (Barrierefreiheit), fachliche Farben der Hülle ändern.

## Quellen

- Godot-Doku: Renderer-Vergleich, 2D-Lichter und Schatten, Parallax2D, CanvasGroup,
  GradientTexture2D (konisch, 4.7), DrawableTexture2D (4.7)
- godot-docs Issue #10896: HDR 2D wirkt seit PR #87360 auch im Compatibility-Renderer
- Godot Shaders: 2D Wind Sway, God Rays 2D, Variable Blur (Parallax), Simple Blur
  (CanvasGroup), Rain Puddles / 2D Reflective Water, 2D Glow Screen
- GDC 2015 „Animating Ori and the Blind Forest" (Mitschrift), Polycount-Artdump Ori,
  UbiArt Framework (RayWiki, GDC Vault), „The Art of Hollow Knight"
- Coding Quests: Game Juice in Godot 4; Celeste-Quellcode (Player.cs, Hair)
