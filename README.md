# Paul & REZI — Das e-Rezept Jump 'n' Run

Ein Pixel-Art-Messespiel über den Weg des **e-Rezepts** durch die **Telematikinfrastruktur (TI)**:
Paul begleitet sein e-Rezept **REZI** vom Arztbesuch bis zur Apotheke — und an jeder Station
legt die TI sichtbar einen neuen Schutz an. Angreifer werden nie bekämpft: Sie scheitern
komisch an Signatur, Verschlüsselung und Zugriffskontrolle. **„ZUGRIFF VERWEIGERT."**

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
| `npm test` | Engine-Logik: 353 Tests (Hülle, Sicht, Eingabe, Compiler, Recht, Telemetrie, Verdrahtung) |
| `npm run playtest:report` | Playtest-Dateien auswerten → Quote + Handlungsempfehlung |
| `npm run build` | Offline-fähiger Produktions-Build nach `dist/` (inkl. Level-Build) |
| `npm run neues-level -- 04-name` | Neues Level aus der Vorlage anlegen |
| `npm run build:levels` | Level kompilieren `design/` → `public/` + alle Prüfungen |
| `npm run validate` | Komplett-Prüfung: Configs, Level, Erreichbarkeit, Kern-Schutz |
| `npm run guard` | Nur Kern-Schutz prüfen (`guard:update` schreibt das Manifest neu) |
| `level-build.bat` | Level bauen + prüfen per Doppelklick (Redaktion, ohne Terminal) |
| `start-messe.bat` | Messestart: lokaler Server + Chrome-Kiosk (`?kiosk=1`) |

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

## Playtest & Wirkungsmessung

Das Konzept nennt ein **Abbruchkriterium**: Verstehen weniger als 80 % der
Tester „sichtbar vs. sicher" ohne Text, wird die Mechanik überarbeitet — nicht
weiterer Content gebaut. Dafür ist alles vorbereitet:

- **Telemetrie** zählt mit, ob die Hülle **freiwillig und rechtzeitig** genutzt
  wird. Entscheidend ist die Reihenfolge: Wer verschlüsselt, *bevor* ein Lauscher
  ihn erwischt, hat die Regel aus der Situation gelesen (*proaktiv*). Wer erst
  danach reagiert, hat die Strafe gebraucht (*reaktiv*).
- **F9 im Spiel** zeigt die Quote gegen die 80-%-Schwelle und exportiert die
  Rohdaten als Datei.
- **`npm run playtest:report`** führt mehrere Exportdateien zusammen (auch von
  verschiedenen Rechnern) und liefert eine **Ableitung**: Bei verfehltem Ziel
  unterscheidet es, ob die Tester die Regel *zu spät* anwandten (dann ist die
  Einführung zu leise) oder *gar nicht erkannten* (dann muss die Mechanik selbst
  überarbeitet werden). Das sind völlig verschiedene Maßnahmen.
- **Fragebogen** (7 Fragen) prüft das Wissen vor und nach dem Spielen. Jede Frage
  hängt an einem der Vereinfachungsfehler, die das Konzept benennt — ein Test
  erzwingt, dass keiner davon aus dem Bogen verschwindet.

Anleitung für die Durchführung: **[`docs/PLAYTEST.md`](docs/PLAYTEST.md)**

**Datenschutz:** Die Telemetrie erfasst keine Personendaten — kein Name, keine
Kennung, keine IP, kein Datum, nur Millisekunden seit Sitzungsbeginn. Nichts wird
übertragen; die Daten bleiben im Browser, bis jemand F9 drückt. Abschaltbar über
`"telemetrie": false` in `public/config/game-config.json`. Das Spiel erklärt
Vertraulichkeit — es hält sich selbst daran.

## Tests

```bash
npm test        # Engine-Logik (232 Tests, ohne Browser)
npm run validate  # Configs, Level, Erreichbarkeit, Kern-Schutz
```

Bewusst ohne Test-Framework: Das Harness (`tools/test/harness.ts`) hat keine
Abhängigkeiten, `npm test` läuft damit auch auf einem frisch aufgesetzten
Messe-PC. Geprüft wird u. a. Zustandslogik, Sichtkegel, Toggle-Belegung auf
2-Button-Hardware, alle Compiler-Regeln, die Baustein-Registry und die
Verdrahtung der Szenen.

## Tech-Stack

Phaser 3 · TypeScript · Vite · zod · qrcode · Tiled-JSON-Tilemaps.
Alle Pixel-Grafiken werden prozedural zur Laufzeit erzeugt (keine Binär-Assets) —
Custom-Art ersetzt später nur Texturen, siehe `src/gfx/TextureFactory.ts`.
