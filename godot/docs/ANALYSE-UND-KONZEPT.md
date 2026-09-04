# Paul & REZI — Bewertung der Phaser-Fassung und Konzept für den Godot-Neuaufbau

*Stand: 2. September 2026 (zweite Fassung: helle Bildsprache, Celeste-Physik, alle zehn Level neu). Grundlage: vollständige Sichtung von Konzept (KONZEPT.md, KAPSEL.md),
Level-Baukasten (LEVELBAU.md), Quellcode (src/, tools/), aller zehn Level, Grafik- und Playtest-Docs,
eigene Spielsitzungen im Browser sowie Recherche zu aktuellem Plattformer-Design.*

---

## 1. Kurzfassung

Das fachliche Fundament ist ausgezeichnet und bleibt. Das Spiel selbst macht keinen Spaß, weil es
kein Bewegungsspiel ist: Man läuft nach rechts über einen flachen Boden, drückt an vier Stellen eine
Taste und ist nach 25 Sekunden durch. Es gibt nichts zu meistern, nichts zu entdecken, nichts, worauf
man stolz sein könnte, und deshalb auch keinen Grund, es ein zweites Mal zu spielen.

Die Godot-Fassung unter `godot/` behebt genau das, ohne die Fachlichkeit anzutasten:

| Säule | Phaser heute | Godot neu |
|---|---|---|
| Bewegung | Laufen, Springen, Ducken; Ziel nur „rechts" | Beschleunigung mit Momentum, REZI-Schub (Doppelsprung), Wandsprung, Kanten-Korrektur, Sprungfedern |
| Leveldesign | flacher Boden, 2–5 schwebende Blöcke, Objekte in Reihe | Kishōtenketsu-Aufbau, Höhe, Weggabelungen, Bonuspfade, Rhythmus aus Sprüngen |
| Game Feel | gut (Coyote, Buffer, variable Höhe) — aber ohne Anlass | dieselben Feel-Regeln plus Partikel, Hitstop, Kamera-Vorlauf, Klang für jede Aktion, Musik |
| Wiederspielwert | keiner (Score ohne Bedeutung, ein Weg) | drei Medaillen pro Station (Zeit / Prüfsummen / Lückenlos), Kombos, Bonus-Prüfsummen, Bestenliste |
| Grafik | dunkle Silhouetten, 6 % Bildhöhe für Paul, alles glüht ein bisschen | lesbare Ebenen (Gelände dunkel, Kulisse hell), Materialsystem, Paul und REZI als animierte Vektorfiguren, HDR-Glühen nur für Spielrelevantes |

Die Godot-Fassung ist spielbar, alle zehn Level sind nach den neuen Regeln neu gebaut und geprüft,
das Auslieferungspaket liegt unter `godot/build/` (Start über „Paul und REZI.lnk", läuft auch unter
Windows Smart App Control).

---

## 2. Was gut ist und bleibt

1. **Die Fachlichkeit.** Zonen der TI, VAU als Raum statt Tunnel, Verschlüsselung ≠ Signatur,
   eGK als Schlüssel statt Speicher, abgelaufene Sitzung fällt in den Klartext — das ist sauber
   recherchiert, mit Quellen belegt (KAPSEL Teil 1) und in Mechaniken übersetzt, die die Aussage
   *spielen* statt erklären. Das ist selten und wertvoll.
2. **Die Hülle-Mechanik als Idee.** Ein Zustandswechsel mit mehreren gleichzeitigen Konsequenzen
   (Tempo, Sichtbarkeit, Andockfähigkeit) ist genau die Ikaruga/Outland-Lehre, die KAPSEL 2.1 nennt.
   Sie trägt — sobald die Level sie fordern.
3. **Die Markenregeln.** Nie kämpfen, Angreifer scheitern komisch an der TI, „ZUGRIFF VERWEIGERT",
   kein Tod, kein erhobener Zeigefinger, Barrierefreiheit als Designregel. Das ist ein klarer
   Ton, den Godot übernimmt.
4. **Die Sprungphysik.** Coyote-Time, Jump-Buffer, variable Sprunghöhe, Scheitel-Schweben,
   asymmetrisches Fallen, Kanten-Korrektur — handwerklich richtig und getestet
   (`src/player/sprungphysik.ts`). Die Godot-Fassung übernimmt die Werte 1:1 (×3 für die Auflösung).
5. **Der Level-Baukasten.** Zwei Textdateien pro Level, Compiler mit Erreichbarkeitsprüfung,
   Softlock-Schutz, klare Fehlermeldungen. Godot liest dasselbe Format — die Inhalte bleiben,
   die Engine wird getauscht.
6. **Messe-Härtung.** Kiosk, Idle-Reset, CrashGuard, Arcade-Encoder parallel zur Tastatur,
   QR-Reward, Tages-Highscore ohne Personendaten, Telemetrie ohne Personendaten. Übernommen.
7. **Das Titelbild.** Das Klinik-Querschnitt-Bild im Attract-Mode ist das beste Bild des Spiels.

---

## 3. Warum es keinen Spaß macht

### 3.1 Es gibt keine Bewegungsaufgabe

Alle zehn Level teilen dieselbe Silhouette: drei Reihen Boden, darauf ein bis zwei Reihen mit ein
paar `=`-Plattformen, der Rest Luft. In Level 1 (84 Kacheln breit) stehen genau **fünf** Sprünge
im Weg, keiner davon nötig. Die Lern-Level 13–20 sind buchstäblich dieselbe Zeile: Boden, alle
20 Kacheln ein Checkpoint, drei Lauscher, eine Plattform. Der Spieler hält „rechts" gedrückt.

Ein Plattformer lebt vom Sprung als Entscheidung: Wo lande ich, wann springe ich ab, welchen Weg
nehme ich. Diese Entscheidung kommt im aktuellen Spiel nicht vor.

### 3.2 Die Mechaniken sind Warte-Mechaniken

Timing-Gate (auf den Takt drücken), Stillstand-Podest (nichts tun), Krypto-Dusche (einmal drücken),
Kartenleser (einmal drücken), Stempel (auf den richtigen Moment warten). Fachlich alle richtig —
aber keine davon verlangt Bewegung, Timing im Lauf oder Risiko. Sie unterbrechen den Fluss, statt
ihn zu tragen. Selbst die Hülle ist in der Praxis „Shift drücken, durchlaufen": Die Lauscher stehen
auf flachem Boden, man sieht sie 400 Pixel vorher, es gibt keinen Grund, sichtbar zu bleiben, außer
der einen Andock-Plattform pro Level.

### 3.3 Nichts steht auf dem Spiel, nichts wird belohnt

Treffer kosten Bits, Bits sind wieder einsammelbar, Bits sind das einzige Ziel. Punkte werden
angezeigt, bedeuten aber nichts: keine Zeitwertung, keine Medaille, kein Vergleich, kein Rang mit
Konsequenz. Der Reward-Screen zeigt „0 Punkte · Gut geschützt", egal was man tut. Der Konzept-
Wiederspielwert (KAPSEL 2.7: Siegel, Bestzeiten, versteckte Ausgänge, Kompendium) ist nicht gebaut.

### 3.4 Das Bild ist nicht lesbar

Der „atmosphärische" Umbau hat das Spielfeld verschluckt. Auf dem Monitor ist das Level fast
schwarz (siehe Bild 1), Paul ist eine 21-Pixel-Silhouette auf 360 Pixel Designhöhe (6 % — Mario
im NES-Original hat 7 %, moderne Plattformer 8–12 %), Plattformen und Kulisse haben dieselbe
Helligkeit. Die eigene Grafik-Analyse (GRAFIK-PLAN.md, Punkt 3) sagt es selbst: „Alles glüht ein
bisschen, also glüht nichts." Eine Messehalle ist hell; dieses Bild verliert dort.

### 3.5 Keine Musik, sieben Piepser

Sieben synthetische Signale, keine Musik, kein Rhythmus. Für ein Spiel, dessen Kernmechanik an
mehreren Stellen „im Takt" verlangt, fehlt ausgerechnet der Takt.

### 3.6 Die Dramaturgie ist Text

Portal-Einblendung, REZI-Satz, Stempel-Satz, Info-Zonen alle 15 Kacheln, dazu drei Intro-Phasen
und vier Lehrsequenzen mit Mindest-Anzeigedauer. Der Lern-Dreiklang ist als Idee gut; im Spiel ist
er die Hauptbeschäftigung, weil das Spielen dazwischen so dünn ist.

---

## 4. Recherche: Was ein gutes Jump 'n' Run ausmacht

Fünf Befunde, die die Godot-Fassung als Regeln übernimmt.

**A. Die Bewegung ist das Spiel.** „In a 2D platforming game of any kind, how you design the jump
defines a tremendous amount of how the game is going to feel" (Game Developer, *Designing a 2D
Jump*). Empfehlungen daraus: parabolische Bahn, variable Sprunghöhe, mittlere Luftkontrolle mit
Momentum, hohe Schwerkraft (8× Erde und mehr fühlt sich richtig an). Coyote-Time 70–140 ms und
Jump-Buffer 100–150 ms sind „the single biggest upgrade you can make to platformer feel"
(Indie Game Academy / Gamine AI). Moderne Plattformer haben darüber hinaus **eine zweite Bewegung
mit Tiefe** — Celestes Dash, Marios Wandsprung, Oris Doppelsprung — die Level erst vertikal und
Wege erst optional macht.

**B. Jedes Level erzählt eine Idee in vier Schritten.** Nintendos Kishōtenketsu
(Koichi Hayashida, Super Mario 3D Land/World): *Ki* — die Mechanik gefahrlos zeigen; *Shō* — sie
steigern; *Ten* — sie mit etwas Unerwartetem verbinden; *Ketsu* — Meisterschaft zeigen, Belohnung.
Dazu die „Regel der Drei" und: neue Gefahr erst vorführen, dann fordern (KAPSEL 2.2 nennt das
bereits, die Level setzen es nicht um).

**C. Wege statt Strecke.** Celeste füllt seine Räume mit „branching pathways, secret areas, and
challenge rooms for more ambitious players" — möglich, weil die Hauptrichtung immer klar ist.
„Multi-threading, the placement of interconnected alternative paths through a level, is a crucial
strategy for making a level dynamic and replayable" (Game Design Skills). Sammelobjekte gehören
auf den riskanteren Pfad, nicht in die Laufbahn.

**D. Juice ist Rückmeldung, nicht Deko.** Squash & Stretch, Partikel, Hitstop (60–80 ms), Kamera-
Kick, ein Klang pro Aktion: „a layer of polish … turns each interaction into something satisfying"
(Vlambeer, *The Art of Screenshake*; Game Developer, *Squeezing more juice*). Screenshake sparsam —
das Playtest-Feedback der Phaser-Fassung („rüttelt, mega nervig") bestätigt es.

**E. Wiederspielwert entsteht aus Bewertung und Alternativen.** Kurze Sessions mit Meisterschafts-
kurve, sichtbare Medaillen/Ränge, Bestenlisten, Zeitziele, versteckte Wege (Game Design Skills,
*Arcade Game Design*; JSLegend, *The Trick to Designing Highly Replayable Arcade Games*). Für einen
Messestand heißt das: Wer zusieht, muss sehen, dass der Spieler gerade etwas *besser* machen könnte.

**F. Aktuelle Optik.** 2024/25 dominieren zwei Richtungen: Pixel-Art mit moderner Beleuchtung
(Layer, Parallaxe, Shader, Bloom — z. B. *REPLACED*) und handgemalte/painterly Welten (Hollow
Knight, Ori). Gemeinsam ist beiden: klare Figur mit Persönlichkeit und Animation, lesbare
Vordergrund/Hintergrund-Trennung, Licht als Gestaltungsmittel, kein Einheitsgrau.

Quellen: siehe Abschnitt 9.

---

## 4b. Nachrecherche: den „KI-Look" vermeiden

**Befund.** Die erste Godot-Fassung sah nach generierter Grafik aus, obwohl sie handgeschrieben war —
und zwar aus denselben Gründen, aus denen generierte Spielgrafik generisch wirkt: schwarzer Grund,
Neon-Cyan/Magenta-Glühen auf allem, glatte Geometrie ohne Struktur, gleichmäßige Sättigung, keine
Wertehierarchie. Das ist der Synthwave/Tron-Look, der inzwischen selbst als Klischee gilt
(Rolling Stone, PC Gamer zur Synthwave-Ästhetik in Indie-Spielen).

**Was die Vorbilder anders machen** (Celeste-Tileset-Analyse, Medeiros/Pixel-Parmesan-Farblehre,
Mario Wonder, Rayman Legends, Ori):
1. **Begrenzte Palette pro Welt:** 3–5 Farben pro Material, eine Grundfarbe, Akzente auf 10–20 %.
2. **Wertehierarchie:** Vordergrund dunkel und satt, Kulisse hell und entsättigt (Luftperspektive).
   Fast alle erfolgreichen Plattformer sind *hell*.
3. **Hue-Shift:** Schatten kühler (Blau/Violett), Lichter wärmer (Gelb/Orange); Sättigung in
   den Mitteltönen, nicht in den Extremen.
4. **Licht von oben, sichtbar:** helle Kappe auf jeder Standfläche, dunkler Fuß, dunkle (nie
   schwarze) Kontur.
5. **Kanten nie ganz gerade, Varianten statt Wiederholung:** „start with rectangles and round off
   the corners"; zufällige Kantenvarianten, hand-platzierte Requisiten (Celeste).
6. **Figur komplementär zur Umgebung** (Mario-Regel): warme Figur vor kühler Welt.
7. **Glühen nur für echte Lichtquellen.**

**Umsetzung in Godot.** Fünf Farbwelten (Morgen, Abend, Regen, Rechenzentrum, Archiv) in
`Palette.gd`; Sonne als `DirectionalLight2D` (Mischlicht, wirft Schatten von Plattformen); Kappen
mit generierter Normal-Map (`CanvasTexture`), damit Sonne und REZI-Licht sie wirklich schattieren;
Gelände mit Rausch-Struktur, Fugen, Nieten, Gittern, Moos und gewellten Kanten; Kulisse mit Sonne,
Wolken, Bäumen, Laternen, Kübeln, Nebelverläufen; Regen als Strichpartikel; Punktlichter an allen
Bausteinen, der Lauscher-Blick als Kegellicht; Post-Effekt mit Split-Toning (Schatten kühl, Lichter
warm), Papierkorn, weicher Vignette; Glühen erst ab HDR-Schwelle 1,35. Paul trägt Orange-Rot vor
den blauen Welten.

**Physik nach Celeste.** Die dokumentierten Konstanten aus Player.cs (MaxRun 90, RunAccel 1000,
AirMult 0,65, Gravity 900, MaxFall 160, FastMaxFall 240, JumpSpeed 105, JumpHBoost 40, VarJumpTime
0,2 s, HalfGravThreshold 40, JumpGraceTime 0,1 s) sind mit Faktor 6 auf 48-px-Kacheln skaliert.
Ergebnis: Sprunghöhe ≈ 3,4 Kacheln, Weite ≈ 6,3 Kacheln, Schnellfall mit „runter" — die Grenzen
des Level-Baukastens bleiben gültig.

---

## 5. Konzept der Godot-Fassung

### 5.1 Warum Godot

KAPSEL 4.2 empfahl es bereits: Godot 4 (MIT, kostenlos) bringt 2D-Editor, Physik, Partikel,
2D-Licht und HDR-Glühen, Parallaxe, Audio-Busse, Gamepad-Support und native Exporte mit. Ein
nativer Windows-Build ist für einen Messe-PC robuster als Chrome im Kiosk-Modus (kein Browser,
kein WebGL-Fallback, kein Service Worker). Web-Export bleibt möglich (Templates nachladen).

### 5.2 Bewegung: Pauls Vokabular

| Eingabe | Wirkung | Warum |
|---|---|---|
| Joystick | Laufen mit Beschleunigung (0,08 s bis Vollgas), Abbremsen am Boden schnell, in der Luft träge | Momentum macht Sprünge zu Entscheidungen |
| Rot | Springen: Coyote 100 ms, Buffer 140 ms, variable Höhe, Scheitel-Schweben, schwereres Fallen, Kanten-Korrektur | unverändert aus der Phaser-Fassung, dort richtig |
| Rot in der Luft | **REZI-Schub**: REZI schwingt unter Paul hindurch und trägt ihn ein zweites Mal hoch | die zweite Bewegung mit Tiefe; fiktional „die TI trägt dich"; öffnet Bonuswege, ohne Pflichtwege zu ändern |
| Rot an der Wand | Wandsprung (beim Rutschen an einer Wand, in die man drückt) | Vertikalität, Retten verpatzter Sprünge |
| Runter | Ducken (eigene Hitbox) | Kralle, niedrige Durchgänge |
| Blau | TI-Aktion | unverändert: „der Spieler beauftragt, die TI führt aus" |
| Hoch / Shift | Hülle wechseln | unverändert, 2-Button-Hardware |

Pflichtwege bleiben mit einem Sprung lösbar (3 Kacheln hoch, ~5 weit). Doppelsprung, Wandsprung
und Sprungfedern führen zu Bonus-Prüfsummen und Abkürzungen — nicht zum Ziel. Damit bleibt der
Erreichbarkeits-Check des Baukastens gültig.

### 5.3 Leveldesign-Regeln (neu)

1. Jedes Level folgt Ki–Shō–Ten–Ketsu mit **einer** Idee. Level 1: Springen → Höhe → Weggabelung
   (Feder nach oben zu Bonus-Kacheln oder unten durch Störfelder) → Abstieg zum Portal.
2. Höhe ist Pflicht: mindestens drei Ebenen, Plattformen von unten durchspringbar.
3. Pro Level ein optionaler Pfad, der Können verlangt und Bonus-Prüfsummen (`*`) bezahlt.
4. Prüfsummen leiten (Bogen über die Sprungbahn) und locken (Nebenpfad), nie nur „auf dem Boden".
5. Gefahren erst zeigen, dann fordern; Checkpoint vor jeder Wendung.
6. 30–60 Sekunden für Normalspieler, 20 für Könner — die Par-Zeit ist die Medaille.
7. Hülle-Level: Lauscher so setzen, dass Klartext *gebraucht* wird (Andock-Plattformen, Tempo-
   Passagen), sonst ist Verschlüsseln keine Entscheidung.

Drei neue Layout-Zeichen: `*` Bonus-Prüfsumme, `^` Sprungfeder, `x` Störfeld. Alles andere ist
das bestehende Format.

### 5.4 Game Feel

Squash & Stretch (Absprung, Landung, Hülle-Wechsel), Staub beim Laufen und Landen, Funken und
Ring beim Sammeln mit steigender Tonhöhe je Kombo, Hitstop 70 ms bei Treffer und Siegel, Kamera-
Vorlauf in Laufrichtung mit vertikaler Totzone, Kamera-Kick nur bei Toren, Siegel und Stempel,
schwebende Texte („−4 Bits", „SIGNIERT", „PRÜFUNG WIEDERHOLEN"), „ZUGRIFF VERWEIGERT"-Stempel
mit Sternen. Klang für jede Aktion, Musikschleife im Level (124 BPM — der Takt, den die
PIN-Schleuse braucht), ruhige Schleife im Titel.

### 5.5 Wiederspielwert

- **Drei Medaillen je Station:** Zeit (unter Par), Prüfsummen (alle, inklusive Bonus), Lückenlos
  (nie mitgelesen). Die Stationskarte nach jedem Level zeigt sie groß — Zuschauer sehen, was
  fehlte.
- **Kombo:** Prüfsummen in schneller Folge vervielfachen die Punkte (×1,25 je Stufe). Belohnt
  flüssiges Spielen, nicht Sammeln an sich.
- **Bonus-Prüfsummen** auf den Nebenpfaden, Sicherheits-Bonus für fehlerfreie TI-Aktionen.
- **Tages-Bestenliste** mit Avatar-Symbolen, sichtbar im Titel und im Reward.
- Später: Speedrun-Anzeige pro Station, versteckte Ausgänge, Kompendium (KAPSEL 2.7).

### 5.6 Grafik

Ziel: „aktueller Plattformer" ohne gezeichnete Assets (kein Budget, keine Lizenzfragen, alles im
Repo reproduzierbar). Mittel:

- **Materialsystem** (Palette.gd): sechs Grundfarben je Farbwelt, alles abgeleitet. Regeln:
  warm = offen/sichtbar, kühl = verschlüsselt, violett = VAU.
- **Helligkeitsordnung:** Gelände am dunkelsten mit leuchtender Oberkante (Gameplay-Information),
  Kulisse in drei helleren Parallax-Ebenen mit Fenstern, Dächern, Leuchtschildern je Motiv
  (Praxis-Kreuze, Antennen, Rack-Reihen, Archivregale), Lichtschächte, Nebel, Staub.
- **HDR-Glühen** nur für Spielrelevantes: Prüfsummen, Kanten, Lichter, Hülle-Schale.
- **Paul** als Vektorfigur mit Zwei-Knochen-IK-Beinen, Laufzyklus aus der Geschwindigkeit,
  Sprung-/Fall-/Duck-/Wandposen, Blinzeln, Kapuzenpulli mit Farbe statt Silhouette.
- **REZI** als leuchtende Kapsel mit Augen, die in Bewegungsrichtung schauen, Stimmungen
  (fröhlich beim Sammeln, erschrocken im Sichtkegel), Lichtquelle der Szene, Siegel als Ringe.
- Kamera-Zoom 1,2: Paul hat 8 % Bildhöhe.

Wenn später gezeichnete Kunst kommt, ersetzt sie nur die `_draw()`-Methoden — Level, Logik und
Baukasten bleiben.

### 5.7 Messe

Unverändert: Kiosk-Schalter, Idle-Reset, Arcade-Belegung aus JSON, QR-Reward mit Mindestanzeige,
Tages-Wipe der Bestenliste, Disclaimer. Neu: nativer Windows-Build, F11 Vollbild, automatischer
Prüflauf mit Screenshots für Reviews ohne Menschen am Rechner.

---

## 6. Stand der Umsetzung

Gebaut und geprüft (Screenshot-Prüflauf, Windows-Export, Phaser-Tests weiterhin 476/476 grün,
Kern-Guard unverändert):

- Ablauf Titel → Level → Stationskarte → … → Reward mit QR, Bestenliste und Avatar-Wahl
- Spieler-Controller mit allen Feel-Regeln, REZI-Schub, Wandsprung, Ducken, Hitstop, Kanten-Korrektur
- Hülle-Zustandsmaschine (Port), HUD dreifach codiert (Farbe, Form, Text), VAU-Sitzungsanzeige
- Alle Bausteine des Baukastens: Prüfsumme, Bonus, Checkpoint, Tür, Sprungfeder, Störfeld,
  Hinweiszone, Pendel-Plattform, Schadenszone, Tor, Kulisse, PIN-Schleuse, Lauscher mit Sichtkegel
  und Sichtlinie, Andock-Plattform, VAU-Feld mit Kontextschlüssel, Kontext-Anker, Signatur-Stempel,
  Skimming-Kralle mit Siegel-Blende, Stillstand-Podest, Krypto-Dusche, Karte/Kartenleser
  (eGK/HBA/SMC-B mit den vier Ergebnissen), Die letzte Tür mit Zugriffsprotokoll
- Kameramodi horizontal und tube (Auto-Scroll mit Scroll-Locks)
- Alle zehn Level neu gebaut (`tools/build_levels.py`): Kishōtenketsu, Plattformketten 17/14/11,
  Bonuswege, Kriechgang mit Kralle, Feder, Störfelder; Generator prüft die Erreichbarkeit jeder
  Prüfsumme, jedes Bonus, jeder Station und des Ausgangs (alle zehn grün)
- Klang: 19 Signale + 2 Musikschleifen, synthetisiert; QR-Code offline
- Auslieferung: `tools/build.ps1` baut PCK + signierte Godot-Laufzeit + Verknüpfungen (läuft unter
  Windows Smart App Control) sowie eine selbstsignierte Einzel-EXE für Rechner ohne SAC
- Godot-Prüflauf: `--shots=` spielt automatisch und speichert Bilder (siehe `godot/shots/`)

Noch nicht portiert: Telemetrie-Export (F9), F8-Kalibrier-Overlay.

### 6b. Dritte Fassung (02.09.2026): Hauptmenü, Zeitreise, Probelauf, ePA-Wissen, Touch

Das Hauptmenü der Web-Fassung ist zurück: das Klinikum im Puppenhaus-Schnitt
(`src/ui/Title.gd`, Port von `src/gfx/krankenhaus.ts`) mit OP, Stationen, Flur, Empfang
und dem Keller, in dem Konnektor, VAU und Fachdienst ePA wohnen; Aufzug, Heli, Passanten,
Datenpulse. Paul und REZI stehen auf dem Apotheken-Dach. Davor die drei Screens der
Web-Fassung (`src/ui/Intro.gd`): **FRÜHER** (Papier, Boten, Fax), **HEUTE** (die TI in
fünf Schritten: Sprechzimmer → Konnektor legt die Hülle an → TI-Gateway → VAU schreibt die
Akte → Abruf in App und beim nächsten Arzt) und **SO SPIELST DU** (Probelauf: der echte
Paul läuft im Autopilot, Popups mit Tastenkappen je nach Hardware). Vor den vier
ePA-Stationen laufen die Lehrsequenzen aus `src/gfx/wissen.ts` (`src/ui/Wissen.gd`).

Alle Info-Screens erben von `src/ui/Vignette.gd`: Bühne im 640×360-Design-Raum, dreifach
skaliert, Schriften unskaliert, Mindest-Anzeigedauer mit Zeitbalken, danach blättert jeder
Knopf oder Tipp weiter. Zeichen-Vokabular in `src/ui/Pen.gd`.

Touch (`src/ui/TouchControls.gd`): Knüppel links (8 Richtungen, Finger darf irgendwo links
aufsetzen), SPRUNG rechts groß und rot, dazu AKTION und HÜLLE; Multitouch; alles über die
InputMap. Erscheint mit der ersten echten Berührung, sobald ein Level läuft; `--touch`
erzwingt sie zum Test am PC. Der Prüflauf (`--shots=`) fotografiert jetzt auch Menü,
Intro und Wissen; das Auslieferungspaket wurde neu gebaut und mit der signierten Laufzeit
durchgespielt.

---

## 7. Nächste Schritte

1. **Spielen.** Den Windows-Build am Zielgerät mit Arcade-Encoder anfassen; Sprunggefühl und
   Zoom feinjustieren (alle Werte in `Player.gd` / `GameCamera.gd`).
2. **Level feinschleifen** — alle zehn sind neu gebaut und geprüft; jetzt zählt Spielgefühl am
   Gerät: Lauscher-Timing, Par-Zeiten, Bonuswege.
3. **Intro und Lehrsequenzen** als kurze animierte Karten nachziehen (max. 8 s, überspringbar).
4. **Playtest** nach docs/PLAYTEST.md mit dem 80-%-Kriterium — die Telemetrie-Ereignisse gibt es
   in Game.gd bereits (Protokoll, Medaillen); Export nachrüsten.
5. **Art-Pass** (optional): gezeichnete Kulissen/Figur gegen die prozeduralen Zeichnungen tauschen.
6. **Web-Export** nur, wenn ein Browser-Deployment gebraucht wird.

---

## 8. Offene Entscheidungen

- Code-Signing-Zertifikat einer Zertifizierungsstelle kaufen (ca. 100–400 €/Jahr, OV mit
  Firmenprüfung)? Nur dann läuft die Einzel-EXE unter Smart App Control; die PCK-Variante mit der
  signierten Godot-Laufzeit läuft ohne.

- Bleibt die Phaser-Fassung als Fallback oder wird sie eingefroren? (Empfehlung: einfrieren,
  Level-Quellen wandern nach `godot/levels/`.)
- Sollen Bonuswege am Messestand sichtbar bleiben oder nur für Rückkehrer? (Empfehlung: sichtbar —
  Zuschauer-Sog.)
- Welche zehn Stationen bleiben bei ~4 Minuten Durchlaufzeit? Die neuen Level sind länger als 25 s.
  (Empfehlung: 6 Stationen à 40 s.)

---

## 9. Quellen

- Game Developer, *Designing a 2D Jump* — https://www.gamedeveloper.com/design/designing-a-2d-jump
- Indie Game Academy, *Smooth Movement System for a 2D Platformer in Godot* — https://indiegameacademy.com/how-to-make-a-smooth-movement-system-for-a-2d-platformer-in-godot/
- Gamine AI, *Input Buffering and Coyote Time in 2D* — https://gamineai.com/blog/input-buffering-and-coyote-time-in-2d-a-godot-4-and-unity-friendly-timing-primer
- Timmy Kokke, *Kishōtenketsu in Video Game Design* — https://timmykokke.com/blog/2023/2023-05-17-kishotenketsu/
- Joseph Diamond, *The Award-Winning Level Design in Celeste* — https://medium.com/@josephdiamond115/the-award-winning-level-design-in-celeste-c2acb315bf79
- Tadeas Jun, *How to Design Breathtaking 2D Platformer Levels* — https://www.tadeasjun.com/blog/2d-level-design/
- Game Design Skills, *Platformer Game Design* — https://gamedesignskills.com/game-design/platformer/
- Game Design Skills, *Arcade Game Design* — https://gamedesignskills.com/game-design/arcade/
- Game Developer, *Squeezing more juice out of your game design* — https://www.gamedeveloper.com/design/squeezing-more-juice-out-of-your-game-design-
- Valdemir D., *Game feel on the web: squash, shake, and the art of juice* — https://valdemird.com/blog/game-feel-on-the-web/
- JSLegend, *The Trick to Designing Highly Replayable Arcade and Linear Games* — https://jslegenddev.substack.com/p/the-trick-to-designing-highly-replayable
- Soulbound, *Top 10 Pixel Art Games of 2024–2025* — https://soulbound.game/blog/top-10-pixel-art-games-of-2024-2025-pc-edition/
- Rocketbrush, *7 Best Indie Game Art Styles* — https://rocketbrush.com/blog/mastering-indie-game-art-exploring-styles-and-techniques-for-impactful-visuals
- Godot Engine, *2D Parallax* (4.7) — https://docs.godotengine.org/en/4.7/tutorials/2d/2d_parallax.html
- Godot Engine, *Godot 4.7 Release* — https://godotengine.org/releases/4.7/
- Godot Lab, *2D Lights and Shadows* — https://godotlab.org/en/tutorials/2d-lights-and-shadows
- Aran P. Ink, *Celeste Tilesets, Step-by-Step* — https://aran.ink/posts/celeste-tilesets
- Pixel Parmesan, *Color Theory for Pixel Artists: It's All Relative* — https://pixelparmesan.com/blog/color-theory-for-pixel-artists-its-all-relative
- Pedro Medeiros, *How to start making pixel art #6: Basic Color Theory* — https://medium.com/pixel-grimoire/how-to-start-making-pixel-art-6-a74f562a4056
- DeepWiki, *NoelFB/Celeste: Player Movement and Physics* — https://deepwiki.com/NoelFB/Celeste/2.3-player-movement-and-physics
- Godot Docs, *2D lights and shadows* — https://github.com/godotengine/godot-docs/blob/master/tutorials/2d/2d_lights_and_shadows.rst
- GoNintendo, *Super Mario Bros. Wonder's art direction* — https://www.gonintendo.com/contents/26960-super-mario-bros-wonder-s-art-direction-inspired-by-past-entries-and-retro-hardware
- Rolling Stone, *How Games Are Resurrecting the Eighties, One Neon Sunset at a Time* — https://www.rollingstone.com/culture/culture-news/how-games-are-resurrecting-the-eighties-one-neon-sunset-at-a-time-118826/
- PC Gamer, *How synthwave music inspired games* — https://www.pcgamer.com/how-synthwave-music-inspired-games-to-explore-a-past-that-never-existed/
- Game Developer, *The tools used to design Rayman Legends* — https://www.gamedeveloper.com/design/video-the-tools-used-to-design-i-rayman-legends-i-
