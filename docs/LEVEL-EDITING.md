# Level bearbeiten — Anleitung für Redakteur:innen (ohne Programmierung)

Alles Inhaltliche liegt in `public/` als JSON. Änderungen dort brauchen **keinen Rebuild** —
Datei speichern, Browser neu laden (F5), fertig. Nach Änderungen bitte einmal prüfen:

```bash
npm run validate
```

## 1. Stationen umbenennen, umsortieren, austauschen

**Reihenfolge & Auswahl** der Stationen: `public/config/game-config.json` → `levelOrder`.

```json
"levelOrder": ["02-kartenterminal", "03-kov-gateway"]
```

Einträge tauschen, entfernen oder ergänzen — jede ID braucht eine Datei
`public/config/levels/<id>.json`. Die TI-Streckenkarte im HUD passt sich automatisch an.

**Namen und Texte** einer Station: in der jeweiligen Level-Datei unter `station`:

| Feld | Bedeutung |
|---|---|
| `name` | Stationsname (HUD + Portal-Einblendung) |
| `portalText` | 1 Satz beim Abtauchen in die Station |
| `reziText` | 1 Satz, den REZI im Kern-Moment sagt |
| `stampText` | 1 Satz auf dem Auftauch-Stempel danach |
| `badge` | Fachbegriff-Chip (z. B. `"VPN · E2E-Verschlüsselung"`) |

Alle Texte sind Objekte mit `de` (Pflicht) und `en` (optional): `{ "de": "…", "en": "…" }`.

## 2. Wichtige Level-Felder

| Feld | Werte | Wirkung |
|---|---|---|
| `cameraMode` | `horizontal`, `tube` (weitere in Ausbaustufe) | Kamera folgt bzw. Auto-Scroll-Tunnel |
| `theme` | Schlüssel aus `config/themes.json` | Farbwelt/Tileset des Levels |
| `collectible.countRequired` | Zahl | Wie viele Datenbits der Ausgang verlangt |
| `mechanics` | Objekt | Parameter je Mechanik-Typ (z. B. `stepMs`, `scanMs`, Hinweistexte) |
| `parTimeSeconds` | Zahl | Zielzeit (Tempo-Bonus) |

Neues Theme = neuer Eintrag in `config/themes.json` (6 Hex-Farben) — kein Code.

## 3. Level-Geometrie (Tilemaps)

Die `.tmj`-Dateien in `public/assets/tilemaps/` sind **normale Tiled-Dateien**
([Tiled Map Editor](https://www.mapeditor.org/), kostenlos). Konventionen:

- Tile-Layer **`terrain`**: die Plattform-Geometrie (GID 8 = Deko, nicht solide; alles andere solide)
- Objekt-Layer **`objects`**: Spielelemente über das Feld **Typ/Klasse**, z. B.
  `spawn`, `collectible`, `checkpoint`, `gate` (mit Namen), `timing-gate`, `deny-enemy`,
  `stillstand-podest`, `krypto-dusche`, `stamp-exit`, `door-exit`, `deco`, `info-sign`
- Tore verknüpfen: dem Sicherheits-Objekt die Property `gate` = Name des Tor-Objekts geben
- Jedes Level braucht genau einen `spawn` und einen Ausgang (`door-exit` oder `stamp-exit`)

Für die Prototyp-Level gibt es zusätzlich einen Generator (`npm run gen:maps`,
Quellen in `tools/generate-tilemaps.ts`) — Tiled-Bearbeitung überschreibt er nur bei erneutem Aufruf.

## 4. Tipps bei Hängern (automatisch)

REZI hilft von selbst, wenn jemand nicht weiterkommt — alle Texte sind optional
per JSON überschreibbar (`{ "de": "…", "en": "…" }`); ohne Eintrag greifen
eingebaute Standardtexte, die sich automatisch an Tastatur/Arcade anpassen:

| Wo | Schlüssel | Wann |
|---|---|---|
| Level-Datei (oberste Ebene) | `stuckHint` | 18 s kein Streckenfortschritt trotz Eingaben |
| `mechanics.timing-gate` | `failHint` | ab dem 2. Druck im falschen Takt |
| `mechanics.stamp-exit` | `failHint` | ab dem 2. Druck im falschen Takt |
| `mechanics.stillstand-podest` | `stillHint` | ab dem 2. abgebrochenen Scan |
| `mechanics.deny-enemy` | `duckHint` | ab dem 2. Treffer durch die Kralle |
| `mechanics.timing-gate` / `stillstand-podest` / `krypto-dusche` | `gateHint` | Spieler drückt ~2 s gegen das zugehörige geschlossene Tor (das Tor wackelt sofort) |

Komplett inaktive Spieler behandelt weiterhin der Idle-Reset (`idleResetSeconds`).

## 5. Endscreen / QR-Code

`public/config/game-config.json` → `ending`:

- `staticPayload`: Inhalt des QR-Codes (Variante A, für alle gleich)
- `rewardScreenSeconds`: automatischer Rücksprung zum Startbildschirm
- `minQrSeconds`: so lange ist Überspringen gesperrt (Handy-Scan-Garantie)

## 6. Wenn etwas schiefgeht

- Beim Start erscheint eine **rote Fehlermeldung** mit Dateiname und Feld → dort korrigieren, F5.
- `npm run validate` findet dieselben Fehler (und fehlende Dateien) ohne Browser.
- Unbekannte Objekt-Typen in Maps werden im Spiel übersprungen und in der Konsole geloggt — die Messe crasht nie.
