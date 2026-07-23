# Level bearbeiten — Anleitung für Redakteur:innen

**Die Quelle der Wahrheit für alle Level ist der Ordner `design/`.** Dort liegt pro
Level ein Ordner mit zwei kleinen Dateien; ein Compiler erzeugt daraus die
technischen Spieldateien und prüft dabei automatisch, dass nichts kaputtgehen kann
(Erreichbarkeit, verschlossene Tore, Sammelziele, Tippfehler …).

> **Die komplette Referenz** (alle Zeichen, Objekte, Parameter, Regeln) steht in
> **[`design/LEVELBAU.md`](../design/LEVELBAU.md)** — geschrieben so, dass auch
> KI-Assistenten damit selbstständig sichere Level bauen können. Diese Seite hier
> ist die Kurzfassung für redaktionelle Änderungen.

## Texte ändern (Stationsnamen, REZI-Sätze, Tipps)

1. `design/levels/<level-id>/level.json` öffnen — die Texte stehen unter `station`:

| Feld | Bedeutung |
|---|---|
| `name` | Stationsname (HUD + Portal-Einblendung) |
| `portalText` | 1 Satz beim Abtauchen in die Station |
| `reziText` | 1 Satz, den REZI im Kern-Moment sagt |
| `stampText` | 1 Satz auf dem Auftauch-Stempel danach |
| `badge` | Fachbegriff-Chip (z. B. `"VPN · E2E-Verschlüsselung"`) |

   Alle Texte sind `{ "de": "…", "en": "…" }` — `de` Pflicht, `en` optional.
   REZI-Hilfetipps stehen im selben File unter `mechanics` (`hint`, `failHint`,
   `gateHint`, …) und `stuckHint`.

2. Danach einmal bauen + prüfen — wahlweise:
   - **Doppelklick auf `level-build.bat`** (nutzt das mitgelieferte Node, kein Setup), oder
   - im Terminal: `npm run build:levels` und `npm run validate`.

3. Spiel neu laden (F5) bzw. für den Messe-Build einmal `npm run build`.

## Stationen umsortieren / austauschen

Reihenfolge = `design/playlist.json`, z. B.:

```json
["01-stammdaten", "02-kartenterminal", "03-kov-gateway"]
```

Einträge tauschen oder entfernen, dann `level-build.bat`. Die TI-Streckenkarte im
HUD passt sich automatisch an. Neues Level anlegen: `npm run neues-level -- 04-name`.

## Geometrie ändern (Plattformen, Bits, Tore)

`design/levels/<level-id>/layout.txt` ist eine ASCII-Zeichnung des Levels
(`#` Boden, `=` Plattform, `o` Datenbit, `P` Start, `D` Tür …) — Legende und
Sprungregeln in `design/LEVELBAU.md`, Abschnitt 3. Nach jeder Änderung
`level-build.bat` ausführen: Der Compiler weist unspielbare Änderungen mit klarer
Meldung ab (z. B. „Tür nicht erreichbar", „Tor ohne Öffner").

## Farbwelten (Themes)

Neues Theme = neuer Eintrag mit 6 Hex-Farben in `public/config/themes.json`,
dann im Level `"theme": "<name>"` setzen. Kein Code nötig.

## Endscreen / QR-Code / Kioskzeiten

Wie bisher direkt in `public/config/game-config.json` (`ending.staticPayload`,
`rewardScreenSeconds`, `idleResetSeconds` …). **Ausnahme:** `levelOrder` dort wird
aus `design/playlist.json` generiert — nie von Hand ändern.

## Wichtig: Diese Dateien nie von Hand bearbeiten

`public/config/levels/**` und `public/assets/tilemaps/**` werden vom Compiler
erzeugt und beim nächsten Build überschrieben. Änderungen gehören immer nach
`design/`. Der Spielkern (`src/`, `tools/` …) ist zusätzlich per Prüfsumme
geschützt — `npm run validate` meldet jede versehentliche Änderung.

## Wenn etwas schiefgeht

- `level-build.bat` / `npm run validate` nennen Datei, Stelle und Lösung für jedes
  Problem — Meldung lesen, beheben, erneut ausführen.
- Beim Spielstart erscheint bei kaputter Konfiguration eine rote Fehlermeldung mit
  Dateiname und Feld.
- Unbekannte Objekt-Typen in Maps werden im Spiel übersprungen und in der Konsole
  geloggt — die Messe crasht nie.
