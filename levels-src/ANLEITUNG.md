# Level bauen — die EINZIGE Anleitung, die du brauchst

Du bist eine KI (oder ein Mensch) und sollst ein neues Level für das
e-Rezept-Jump'n'Run bauen. **Lies nur dieses Dokument.** Du musst den
Spielcode weder lesen noch verstehen — und du darfst ihn nicht anfassen.

## Die eiserne Regel

Du erstellst oder änderst **ausschließlich**:

1. eine Datei `levels-src/<deine-id>.level.json` (dein Level)
2. **eine Zeile** in `public/config/game-config.json` → `levelOrder` (Level aktivieren)

**Alles andere ist tabu.** Insbesondere: `src/` (Spielcode), `tools/`
(Werkzeuge), `public/assets/` und `public/config/levels/` (werden generiert),
`dist/` (Build). Wenn du glaubst, du müsstest dort etwas ändern, ist dein
Level falsch gebaut — nicht das Spiel.

## So gehst du vor (4 Schritte)

```bash
# 1. Kopiere die Vorlage
#    levels-src/_VORLAGE.level.json  →  levels-src/04-mein-level.level.json
#    (ID: nur kleinbuchstaben-und-bindestriche, mit Nummer vorn)

# 2. Fülle Texte aus und male die Karte (Regeln unten)

# 3. Kompiliere und prüfe — der Compiler lehnt kaputte Level ab:
npm run levels

# 4. Aktiviere das Level: trage die ID in game-config.json bei "levelOrder" ein,
#    dann Gesamtprüfung:
npm run validate
```

Wenn `npm run levels` einen Fehler meldet: **lies die Meldung, korrigiere
deine .level.json, kompiliere erneut.** Der Compiler schreibt niemals ein
kaputtes Level ins Spiel — solange er meckert, ist nichts beschädigt.

## Die Datei im Überblick

```jsonc
{
  "id": "04-fachdienst",
  "station": {
    "name":       { "de": "Fachdienst", "en": "Specialist service" },
    "portalText": { "de": "Station: … — ein Satz beim Eintauchen.", "en": "…" },
    "reziText":   { "de": "Ein Satz, den REZI im Erfolgsmoment sagt.", "en": "…" },
    "stampText":  { "de": "✓ Ein Satz auf dem Erfolgs-Stempel.", "en": "…" },
    "badge": "Fachbegriff · Chip"
  },
  "siegelIcon": "seal-generic",          // vorhandene: seal-egk, seal-vpn, seal-generic
  "cityAnchor": { "facade": "generic", "label": { "de": "Gebäudename in der Stadt" } },
  "cameraMode": "horizontal",            // "horizontal" (Kamera folgt) oder "tube" (Auto-Scroll)
  "theme": "kartenterminal",             // Schlüssel aus public/config/themes.json
  "enemySkin": "skimming-kralle",
  "collectibleCountRequired": 0,         // nur relevant bei Tür-Ausgang "D"
  "parTimeSeconds": 30,
  "mechanics": {},                       // optional, siehe „Feineinstellungen"
  "infoSchilder": [],                    // ein Text pro "i" in der Karte, von links nach rechts
  "map": [ /* exakt 23 Zeilen ASCII, alle gleich lang */ ]
}
```

Texte: `de` ist Pflicht, `en` optional. Ein Satz pro Text, kindertauglich,
positiv formuliert (die TI schützt — nie „du bist schlecht").

## Die Karte: 23 Zeilen ASCII

Jedes Zeichen = eine Kachel von 16×16 Pixeln. **Exakt 23 Zeilen** (eine
Bildschirmhöhe), Breite 40–220 Zeichen, alle Zeilen gleich lang.
Der Bildschirm zeigt 40 Spalten gleichzeitig.

### Gelände (solide, außer `|`)

| Zeichen | Bedeutung |
|---|---|
| `#` | Boden/Wand (Oberkante wird automatisch hübsch) |
| `=` | schwebende Plattform |
| `G` | Gold-Kontaktpad (wie `#`, nur golden) |
| `A` | Akzentblock |
| `~` | Glas (solide Tunnelwand, halbtransparent) |
| `-` | dunkle Füllung (solide, für Decken/Ränder) |
| `\|` | Deko-Strebe (NICHT solide, reine Optik) |
| `.` oder Leerzeichen | Luft |

### Objekte (je ein Zeichen in die Karte malen)

| Zeichen | Bedeutung | Regeln |
|---|---|---|
| `P` | Startpunkt | **genau 1× Pflicht**, braucht Boden darunter |
| `S` | Stempel-Ausgang (Signatur-Finale) | genau EIN Ausgang pro Level: `S` **oder** `D` |
| `D` | Tür-Ausgang (öffnet ab `collectibleCountRequired` Bits) | dito |
| `b` | Datenbit (Sammelobjekt) | bei Tür-Ausgang: **mind. 2 mehr erreichbar als verlangt** |
| `c` | Checkpoint | braucht Boden darunter |
| `i` | Info-Schild (REZI spricht) | pro `i` ein Eintrag in `infoSchilder` |
| `t` | Timing-Gate „PIN-Schleuse" (Takt-Drücken) | max. 1×, auf den Boden setzen |
| `p` | Stillstand-Podest (Scan durch Stillstehen) | schwebt auf Marker-Höhe |
| `Q` | Krypto-Dusche (Verschlüsselung per Knopf) | max. 1×, auf den Boden setzen |
| `1` `2` `3` `4` | Tor (blockiert den Weg) | als **senkrechte Linie** malen, z. B. drei `1` übereinander |
| `K` | Skimming-Kralle (Gegner — drunter ducken!) | flach über dem Boden platzieren |
| `H` | Gefahrenzone (kostet Bits, nie tödlich) | 1 Kachel |
| `M` | bewegliche Plattform | Startposition |
| `x` | Deko-Datenkrake (harmlos) | reine Optik |

### Tore und ihre Öffner — automatisch verknüpft

Jedes Tor (`1`–`4`) wird automatisch mit der **nächsten Sicherheits-Mechanik
links davon** verknüpft (`t`, `p` oder `Q`, jede öffnet genau ein Tor).
Du malst also: erst die Mechanik, dann rechts davon das Tor. Beispiel:

```
............1..
....t.......1..
############1##
```

→ Timing-Gate schaffen öffnet Tor 1. Fehlt ein Öffner links vom Tor,
lehnt der Compiler das Level ab (sonst wäre es unlösbar).

## Physik-Grenzen (hart geprüft — dagegen bauen bringt nichts)

Paul springt **3 Kacheln hoch** und **4 Kacheln weit**. Daraus folgt:

- Stufen nach oben: **max. 3 Kacheln** pro Sprung
- Lücken im Boden: **max. 4 Kacheln** breit
- Der Compiler simuliert den Weg vom Start zum Ausgang (inkl. Tore) —
  ist etwas unerreichbar, bekommst du einen Fehler mit Koordinate
- Bits dürfen in der Luft hängen (werden im Sprung gegriffen)

## Level-Design-Regeln (aus dem Konzept)

- **Länge:** 60–140 Spalten ≈ 25–35 Sekunden Spielzeit
- **Rhythmus:** laufen/springen → Sicherheits-Moment (t/p/Q + Tor) →
  laufen → Finale (`S` oder `D` ganz rechts)
- **Boden:** unterste 2 Zeilen fast durchgehend `#` — Löcher nur als
  bewusste, schmale Sprunglücken
- **Tube-Level** (`cameraMode: "tube"`): oben und unten durchgehend Rand
  (`-`/`~`), KEINE Rücklauf-Passagen — die Kamera schiebt nur vorwärts
- Kein Tod, keine Blitzeffekte, Gegner werden nie bekämpft — Angreifer
  scheitern sichtbar an der TI (das erledigt die Mechanik von selbst)

## Feineinstellungen (optional, `mechanics`)

```jsonc
"mechanics": {
  "timing-gate":       { "steps": 4, "stepMs": 900, "hint": { "de": "…" } },
  "stillstand-podest": { "scanMs": 1200, "hint": { "de": "…" } },
  "krypto-dusche":     { "hint": { "de": "…" } },
  "deny-enemy":        { "grabsBeforeBlock": 2, "denyText": { "de": "ZUGRIFF VERWEIGERT" } },
  "tube-scroll":       { "speed": 55 }          // nur bei cameraMode "tube"
}
```

Alles optional — ohne Angaben gelten erprobte Standardwerte inklusive
automatischer Hilfe-Tipps, wenn Spieler nicht weiterkommen.

## Neues Farbschema? (optional)

Ein neues `theme` = 6 Hex-Farben in `public/config/themes.json` ergänzen
(skyTop, skyBottom, ground, groundTop, accent, detail). Das ist die einzige
erlaubte Ausnahme außerhalb der eisernen Regel — und nur ADDITIV (nie
bestehende Themes ändern).

## Checkliste vor dem Fertigmelden

- [ ] `npm run levels` läuft ohne Fehler durch
- [ ] Level-ID in `game-config.json` → `levelOrder` eingetragen
- [ ] `npm run validate` meldet „Alle Konfigurationen sind gültig."
- [ ] Karte hat: 1× `P`, 1× Ausgang, jede Tor-Ziffer hat einen Öffner links
- [ ] Alle Texte einzeilig, deutsch (en optional), positiv formuliert
