# LEVELBAU — Anleitung für KI-Assistenten (und Menschen)

**Du willst ein neues Level bauen oder ein Level ändern? Dann ist diese Datei alles,
was du lesen musst. Lies sie komplett, bevor du die erste Datei anfasst.**

Das Spiel ist ein Baukasten: Die Engine (Physik, Kamera, Mechaniken, Grafik) ist fertig
und **geschützt**. Ein Level besteht nur aus zwei kleinen Dateien, die du schreibst —
alles Technische erzeugt der Compiler daraus. Er prüft dabei jede Regel dieser Anleitung
automatisch und lehnt kaputte Level mit klaren Fehlermeldungen ab. **Du kannst also
nichts kaputt machen, solange du dich an Abschnitt 1 hältst.**

---

## 1. Die drei goldenen Regeln

**Regel 1 — Du darfst NUR diese Dateien anlegen oder ändern:**

| Datei | Zweck |
|---|---|
| `design/levels/<deine-level-id>/layout.txt` | Gelände deines Levels (ASCII-Zeichnung) |
| `design/levels/<deine-level-id>/level.json` | Texte, Objekte, Parameter deines Levels |
| `design/playlist.json` | Reihenfolge der Level im Spiel |
| `public/config/themes.json` | NUR um einen neuen Farbwelt-Eintrag zu ERGÄNZEN |

**Regel 2 — Alles andere ist tabu.** Insbesondere: `src/`, `tools/`, `docs/`,
`design/levels/_vorlage/`, `index.html`, `package.json`, `vite.config.ts`,
`tsconfig.json`, die Startskripte — und auch `public/config/levels/` und
`public/assets/` (die werden aus deinen design-Dateien GENERIERT; Handänderungen
dort gehen verloren und lassen `npm run validate` fehlschlagen).
Der Kern ist zusätzlich durch ein Hash-Manifest gesichert: Jede Änderung an
geschützten Dateien wird von `npm run validate` gemeldet. Wenn dir eine Fähigkeit
fehlt (neue Mechanik, neue Grafik, neuer Kameramodus): **STOPP — Abschnitt 8.**

**Regel 3 — Nach jeder Änderung bauen und prüfen:**

```bash
npm run build:levels   # kompiliert + prüft ALLES; schreibt nur bei 0 Fehlern
npm run validate       # Komplett-Prüfung inkl. Kern-Schutz (muss ✓ sein, bevor du fertig bist)
```

Jede Fehlermeldung nennt Datei, Stelle und Lösung. Fehler beheben, erneut bauen,
bis alle Level ✓ zeigen. Ein Level, das nicht fehlerfrei baut, existiert im Spiel nicht.

---

## 2. Rezept: In sechs Schritten zum Level

```bash
npm run neues-level -- 04-fachdienst     # 1. Ordner aus der Vorlage + Playlist-Eintrag
```

2. `design/levels/04-fachdienst/layout.txt` zeichnen (Abschnitt 3).
3. `design/levels/04-fachdienst/level.json` ausfüllen (Abschnitt 4).
4. `npm run build:levels` — Fehler lesen und beheben, bis ✓.
5. `npm run validate` — muss komplett grün sein.
6. Anschauen: `npm run dev` → im Browser `http://localhost:5173` (dein Level kommt
   an der Position, an der es in `design/playlist.json` steht).

Die Level-ID folgt immer dem Muster `NN-kleinbuchstaben` (z. B. `04-fachdienst`).
Ordnername = Level-ID. Die Playlist bestimmt die Spielreihenfolge.

---

## 3. layout.txt — das Gelände

Eine reine Textdatei: **genau 23 Zeilen** (das Spielfeld ist immer 23 Kacheln hoch),
alle Zeilen gleich lang, **40–240 Zeichen breit** (1 Zeichen = 1 Kachel = 16 px).
Oben ist oben. Es gibt keine Kommentare — nur diese Zeichen:

**Gelände (solide = Paul steht darauf / stößt dagegen):**

| Zeichen | Bedeutung | solide? |
|---|---|---|
| `.` oder Leerzeichen | Luft | nein |
| `#` | Boden/Wand (die hübsche Oberkante entsteht automatisch) | ja |
| `=` | Plattform (dünnes Datenfeld) | ja |
| `G` | Gold-Pad (markiert Aktions-Stellen: Terminals, Kontaktflächen) | ja |
| `A` | Akzentblock (Kisten, Stufen, Gehäuse) | ja |
| `~` | Glas (Tunnelwand in Tube-Leveln) | ja |
| `%` | Dunkle Füllung (Außenraum hinter Glas) | ja |
| `\|` | Deko-Strebe im Hintergrund | **nein** |

**Marker (Spielelemente — genau EIN Zeichen pro Element, auf einer Luft-Zelle):**

| Zeichen | Bedeutung | Regeln |
|---|---|---|
| `P` | Startpunkt von Paul | genau EINER pro Level; unter ihm muss Boden sein |
| `o` | Datenbit / Sammelobjekt | max. ~3 Kacheln über einer Standfläche, sonst unerreichbar |
| `C` | Checkpoint | auf die Luft-Kachel DIREKT über dem Boden stellen |
| `D` | Tür-Levelausgang | auf die Luft-Kachel DIREKT über dem Boden; öffnet erst, wenn genug Bits gesammelt sind |

**Sprungphysik (fest verdrahtet — der Compiler prüft die Erreichbarkeit!):**

- Paul springt maximal **3 Kacheln hoch**. Eine Stufe von 4 ist unmöglich → Treppen bauen.
- Sprungweite (von Standkante zu Standkante): bei gleicher Höhe **bis ~6 Kacheln**,
  bei 1–2 Kacheln Steigung **bis ~6**, bei 3 Kacheln Steigung **bis ~5**.
  Runter geht immer (kein Fallschaden).
- Paul ist 21 px hoch (geduckt 13 px): Durchgänge mindestens **2 Kacheln hoch**,
  Duck-Passagen 1 Kachel.

**Mini-Beispiel** (Ausschnitt — echte Dateien haben 23 Zeilen):

```
............................
.......o..o.................
......=====........o........
..P.............A..=====..D.
######....######A#########.#
######....######A#########.#
```

Vollständige, funktionierende Beispiele: `design/levels/01-stammdaten/` (einfaches
Tutorial), `02-kartenterminal/` (horizontal, Gegner + PIN-Schleuse),
`03-kov-gateway/` (Auto-Scroll-Glastunnel).

---

## 4. level.json — Texte, Objekte, Parameter

Alle Texte sind Objekte `{ "de": "…", "en": "…" }` — **de ist Pflicht**, en optional.
Unbekannte Felder lehnt der Compiler ab (mit „meintest du …?"-Vorschlag).

| Feld | Typ / Werte | Bedeutung |
|---|---|---|
| `station.name` | Text | Stationsname (HUD, Portal) |
| `station.portalText` | Text | 1 Satz beim Abtauchen in die Station |
| `station.reziText` | Text | 1 Satz, den REZI im Kern-Moment sagt |
| `station.stampText` | Text | 1 Satz auf dem Erfolgs-Stempel („✓ …") |
| `station.badge` | String | Fachbegriff-Chip, z. B. `"VSDM"` oder `"VPN · E2E"` |
| `siegelIcon` | `seal-vsdm` · `seal-egk` · `seal-vpn` · `seal-generic` | Siegel in Streckenkarte/REZI |
| `cityAnchor` | `{ facade, label }` | Gebäude-Beschriftung in der Stadt |
| `cameraMode` | `horizontal` oder `tube` | Kamera folgt bzw. Auto-Scroll-Tunnel |
| `theme` | Schlüssel aus `public/config/themes.json` | Farbwelt (neues Theme = 6 Hex-Farben dort ergänzen) |
| `enemySkin` | String | kosmetische Kennung (z. B. `datenkrake`) |
| `collectible.countRequired` | Zahl 0–40 | so viele Bits verlangt der Tür-Ausgang `D` |
| `collectible.label` | Text | Anzeigename der Bits (z. B. „Daten-Kacheln") |
| `mechanics` | Objekt | Parameter/Hinweistexte je Objekt-Typ (siehe unten) |
| `parTimeSeconds` | Zahl 10–120 | Zielzeit für den Tempo-Bonus (Level ~25–35 s) |
| `stuckHint` | Text, optional | REZI-Tipp, wenn jemand 18 s nicht vorankommt |
| `objects` | Liste | die Spielelemente unten |

### Objekte (`objects`-Liste)

Position/Größe immer in Kacheln: `tx`/`ty` = obere linke Ecke (Kommazahlen erlaubt),
`tw`/`th` = Breite/Höhe (haben sinnvolle Standardwerte). **Reihenfolge im Level:
Öffner-Mechanik steht in Laufrichtung LINKS vor ihrem Tor.**

**`gate` — benanntes Tor** (Pflicht: `name`)
```json
{ "type": "gate", "name": "tor-scan", "tx": 56, "ty": 14 }
```
Blockiert den Weg (Standard 6 hoch, bis zum Boden setzen!), bis eine Mechanik mit
`"gate": "tor-scan"` es öffnet. **Jedes Tor braucht genau so einen Öffner — sonst
Fehler (Softlock).**

**`timing-gate` — PIN-/Rhythmus-Schleuse** (Pflicht: `gate`; optional `steps` 2–8, `stepMs` 300–3000)
```json
{ "type": "timing-gate", "tx": 46, "ty": 15, "gate": "tor-scan", "steps": 4, "stepMs": 900 }
```
Zone (Standard 8×5), in der der Spieler im Takt der Lichter den blauen Knopf drückt.

**`stillstand-podest` — Prüf-Scan im Stillstand** (Pflicht: `gate`; optional `scanMs` 400–4000)
```json
{ "type": "stillstand-podest", "tx": 26, "ty": 17.6, "gate": "tor-scan-1" }
```
Schwebendes Podest (Standard 3×0.4): stillstehen, bis der Scan durchläuft.

**`krypto-dusche` — Verschlüsselung anlegen** (Pflicht: `gate`)
```json
{ "type": "krypto-dusche", "tx": 58, "ty": 13, "gate": "tor-krypto" }
```
Ein blauer Knopfdruck in der Zone (Standard 5×6). Nur einmal pro Spieldurchlauf
sinnvoll (die Schutz-Optik bleibt an) — gehört erzählerisch zum KOV Gateway.

**`deny-enemy` — Skimming-Kralle** (optional: `fromRight` bool, `reach` 8–120,
`grabsBeforeBlock` 1–5, `activationRange` 60–600, `idleMs` 400–4000)
```json
{ "type": "deny-enemy", "tx": 48.1, "ty": 18.55, "fromRight": true, "reach": 42 }
```
Greift rhythmisch auf Kopfhöhe — Spieler duckt sich; nach N Griffen blockt die TI
sichtbar („ZUGRIFF VERWEIGERT"). **Markenregel: Gegner werden NIE bekämpft.**

**`stamp-exit` — Signatur-Stempel als Levelausgang** (keine Pflichtfelder, Standard 6×6)
```json
{ "type": "stamp-exit", "tx": 89, "ty": 14 }
```
Setpiece-Alternative zur Tür `D`: blauer Knopf, wenn der Stempel oben wartet.

**`info-sign` — REZI-Hinweis-Zone** (Pflicht: `textDe`; optional `textEn`)
```json
{ "type": "info-sign", "tx": 43.5, "ty": 16, "textDe": "Vorsicht, Kralle — duck dich!" }
```

**`moving-platform` — Pendel-Plattform** (optional: `range` 16–200 px, `speed` 10–120 px/s)
```json
{ "type": "moving-platform", "tx": 30, "ty": 15, "range": 64, "speed": 40 }
```

**`hazard` — Schadenszone** — kostet Bits, nie Leben. **In Tube-Leveln verboten.**

**`deco` — Kulisse ohne Physik** (optional: `sprite` aus `krake-0/krake-1/kralle-open/kralle-closed/lauscher-0/lauscher-1`, `anim` = `krake-swim` oder `lauscher-blink`, `drift` 0–20)
```json
{ "type": "deco", "tx": 18, "ty": 0.4, "sprite": "krake-0", "anim": "krake-swim", "drift": 4 }
```


---

### Hülle-Mechanik: Klartext ⇄ Verschlüsselt ⇄ VAU

Die Hülle ist die Kernmechanik der Lern-Level (nicht der Messe-Level). Sie wird
**pro Level eingeschaltet** — ohne diesen Block verhält sich alles wie bisher:

```json
"huelle": { "enabled": true, "start": "klartext" }
```

| Feld | Werte | Bedeutung |
|---|---|---|
| `enabled` | `true`/`false` (Pflicht) | Mechanik an/aus |
| `start` | `klartext` \| `verschluesselt` | Startzustand (Standard `klartext`) |
| `toggleCooldownMs` | 0–1000 | Anti-Prellen am Arcade-Joystick (Standard 150) |

`start: "vau"` gibt es **nicht** — die VAU betritt man nur über ein `vau-feld`.

**Was die drei Zustände tun** (Spieler schaltet mit Joystick HOCH bzw. Shift/Q):

| Zustand | Tempo | Lauscher sehen dich? | Andock-Plattform trägt? |
|---|---|---|---|
| Klartext | 100 % | **ja** | ja |
| Verschlüsselt | 80 % | nein | **nein** |
| VAU (nur im Feld) | 100 % | nein | ja |

Daraus entsteht der Zielkonflikt, der die Level trägt: Sichtbar bist du schnell und
kannst andocken — unsichtbar bist du langsam und wirst von Andock-Plattformen nicht
getragen.

**`lauscher` — sieht NUR Klartext** (optional: `patrol` -240…240 px, `speed` 5–120,
`reach` 24–240, `spread` 6–60, `pauseMs` 0–4000)
```json
{ "type": "lauscher", "tx": 30, "ty": 18, "patrol": 48, "reach": 110 }
```
Patrouilliert zwischen Startpunkt und `tx + patrol` (negativ = nach links). Erwischt
er unverschlüsselte Daten, kostet das Bits und der Vorfall steht im Zugriffsprotokoll.
Verschlüsselt oder in der VAU bist du unsichtbar. **Mindestens 2 Kacheln Abstand
zwischen zwei Lauschern**, sonst wird der Sichtkegel unlesbar (Warnung).

**`andock-plattform` — trägt nur im Klartext (oder in der VAU)**
```json
{ "type": "andock-plattform", "tx": 40, "ty": 15, "tw": 4 }
```
Der Spieler muss sich sichtbar machen, um weiterzukommen — die spannendste Stelle
jedes Hülle-Levels. Bei `start: "verschluesselt"` gibt es eine Warnung, weil die
Plattform dann erst nach dem Umschalten trägt.

**`vau-feld` — Klartext-Tempo UND unsichtbar** (optional: `ttlMs` 0–30000)
```json
{ "type": "vau-feld", "tx": 60, "ty": 14, "tw": 8, "th": 5, "ttlMs": 4000 }
```
`ttlMs: 0` (Standard) = Sitzung läuft nie ab. `ttlMs > 0` = Kontextschlüssel: Nach
Ablauf fällt der Spieler in den **Klartext** zurück (also sichtbar!) — genau das ist
die Lernpointe. Der Compiler rechnet nach, ob das Feld in der Sitzungszeit
durchquerbar ist, und lehnt zu breite Felder ab.

**`kontext-anker` — frischt die Sitzung auf**
```json
{ "type": "kontext-anker", "tx": 64, "ty": 17 }
```
Nur sinnvoll in einem `vau-feld` mit `ttlMs > 0` (sonst Warnung).

**Fachlich wichtig (bitte nicht verfälschen):**
- Die VAU ist **kein Tunnel**, sondern ein Raum, in dem im Klartext gearbeitet wird,
  ohne dass Betreiber mitlesen. Deshalb innen schnell UND unsichtbar.
- **Verschlüsselung ≠ Signatur.** Die Hülle signiert nichts; dafür gibt es
  `stamp-exit`.
- Eine abgelaufene Sitzung schützt **nicht** — sie fällt in den Klartext.

**Sprungweiten in Hülle-Leveln:** Weil verschlüsselt langsamer gelaufen wird, prüft
der Compiler die Erreichbarkeit strenger — statt ~5 nur noch **~4 Kacheln
Sprungweite**. Halte Pflichtsprünge in Hülle-Leveln also kürzer, sonst kommt
„NICHT erreichbar … LANGSAMEN Zustand".

### `mechanics` — Feintuning & REZI-Texte pro Typ

Für die Hülle-Bausteine gibt es zusätzlich:
`lauscher` (`speed`, `reach`, `spread`, `pauseMs`, `seenText`, `akteur`, `huelleHint`),
`vau-feld` (`ttlMs`, `hint`), `kontext-anker` (`hint`), `andock-plattform` (`hint`).


Gleiche Parameter wie am Objekt (Level-weit statt pro Objekt; das Objekt gewinnt)
plus Hinweistexte. Alle Texte optional — ohne sie greifen gute eingebaute Standards:

```json
"mechanics": {
  "timing-gate":       { "steps": 4, "stepMs": 900, "hint": {"de": "…"}, "failHint": {"de": "…"}, "gateHint": {"de": "…"} },
  "stamp-exit":        { "hint": {"de": "…"}, "failHint": {"de": "…"} },
  "stillstand-podest": { "scanMs": 1200, "hint": {"de": "…"}, "stillHint": {"de": "…"}, "gateHint": {"de": "…"}, "denyText": {"de": "ZUGRIFF VERWEIGERT"} },
  "krypto-dusche":     { "hint": {"de": "…"}, "gateHint": {"de": "…"} },
  "deny-enemy":        { "grabsBeforeBlock": 2, "denyText": {"de": "ZUGRIFF VERWEIGERT"}, "duckHint": {"de": "…"} },
  "tube-scroll":       { "speed": 55 },
  "gate":              { "bumpHint": {"de": "…"} }
}
```

`hint` = beim ersten Betreten · `failHint`/`stillHint`/`duckHint` = ab dem 2. Fehlversuch ·
`gateHint` = wenn jemand gegen das zugehörige verschlossene Tor drückt.

---

## 5. Spielregeln für gutes Leveldesign

1. **Immer schaffbar:** Der Compiler simuliert die Erreichbarkeit — aber baue trotzdem
   großzügig: verzeihende Sprünge, Checkpoint `C` vor jeder kniffligen Stelle.
2. **Tore:** Öffner links vom Tor; Tor bis zum Boden (`ty` so wählen, dass unten keine
   Lücke bleibt, Standardhöhe 6). Ein Tor ohne Öffner ist ein Fehler.
3. **Bits:** Mindestens `countRequired` + 5 Bits platzieren, wenn es Schadensquellen
   gibt (ein Treffer verstreut bis zu 5). Bits maximal ~3 Kacheln über Standflächen.
4. **Tube-Level** (`cameraMode: "tube"`): keine `hazard`-Zonen (der Tunnel ist die
   sichere Zone — Markenregel), Ausgang ganz rechts, `mechanics["tube-scroll"].speed`
   setzen (30–90), Öffner-Mechaniken halten den Scroll automatisch an.
5. **Länge:** ~25–35 Sekunden pro Level (Messebetrieb!). Breite 80–140 Kacheln ist
   ein guter Rahmen.
6. **Ton & Marke:** Angreifer scheitern komisch an der TI („ZUGRIFF VERWEIGERT") —
   nie Kampf, nie Tod, nie erhobener Zeigefinger. Jedes Level beantwortet spielbar
   die Frage: *„Was schützt hier meine Daten?"* Fachliche Leitplanken: `docs/KONZEPT.md`.
7. **Texte:** kurz, aktiv, jugendfrei; `de` Pflicht, `en` wenn möglich. Keine echten
   Personendaten, keine Klartext-Gesundheitsdaten — Icons/Metaphern statt Diagnosen.

---

## 6. Wenn der Build meckert

So liest du die Meldungen von `npm run build:levels` / `npm run validate`:

| Meldung enthält … | Das tust du |
|---|---|
| `unbekanntes Zeichen` | Tippfehler im layout.txt — nur Zeichen aus Abschnitt 3 verwenden |
| `genau 23 Zeilen` | layout.txt hat zu viele/wenige Zeilen |
| `genau EIN Spawn-Marker` | `P` fehlt oder ist doppelt |
| `Kein Levelausgang` | `D` ins Layout oder `stamp-exit` in die objects |
| `hat KEINEN Öffner` | Mechanik mit `"gate": "<name>"` ergänzen (links vom Tor) |
| `verweist auf unbekanntes Tor` | Tor-`name` und `gate`-Verweis müssen exakt gleich sein |
| `NICHT erreichbar` | Sprünge zu hoch/weit — Abschnitt 3 Physik; Treppen/Plattformen ergänzen |
| `countRequired … unschaffbar` | mehr `o` platzieren oder `countRequired` senken |
| `Feld "…" gibt es … nicht` | Tippfeld im JSON — der Vorschlag in der Meldung stimmt fast immer |
| `veraltet … build:levels` | einfach `npm run build:levels` ausführen |
| `geschützte Kern-Datei` | Du hast Regel 2 verletzt → Änderung an der Kern-Datei rückgängig machen |

Der Compiler schreibt erst, wenn ALLES fehlerfrei ist — ein halb kaputtes Level kann
nicht im Spiel landen. Warnungen (⚠) blockieren nicht, sollen aber behoben werden.

---

## 7. Referenz: die drei vorhandenen Level

| Level | Zeigt dir … |
|---|---|
| `01-stammdaten` | das einfachste vollständige Level: Marker, ein Tor + timing-gate, Tutorial-Texte |
| `02-kartenterminal` | Gegner (deny-enemy), PIN-Schleuse, stamp-exit als Setpiece-Ausgang |
| `03-kov-gateway` | Tube-Modus: Glastunnel (`~`/`%`), Podeste, krypto-dusche, Deko-Kraken |

Kopiere dir Muster aus diesen Ordnern — sie werden von derselben Pipeline gebaut wie
dein Level.

---

## 8. Deine Grenzen (wichtig!)

Wenn die Aufgabe etwas verlangt, das der Baukasten nicht hergibt — neue Mechanik,
neue Grafik/Sprites, neuer Kameramodus (`vertical`/`chamber`/`sprint`), Änderungen an
Physik, HUD, Punktesystem oder Engine: **Baue es NICHT selbst.** Schreibe stattdessen
ans Ende deiner Antwort einen kurzen Abschnitt „Benötigt Engine-Arbeit (Mensch/
Senior-KI)" mit dem Wunsch. Alles, was du im Rahmen dieser Anleitung tust, ist sicher —
alles außerhalb ist gesperrt und fällt im `npm run validate` auf.
