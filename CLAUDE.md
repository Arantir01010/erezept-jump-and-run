# Regeln für KI-Assistenten in diesem Projekt

Dieses Repository ist das Messespiel **„Paul & REZI — Das e-Rezept Jump 'n' Run"**
(Phaser 3 + TypeScript). Es ist als **geschützter Baukasten** aufgebaut: Die Engine
ist fertig und versiegelt — Inhalte (Level) werden ausschließlich datengetrieben
über `design/` gebaut.

## Wenn deine Aufgabe „Level" ist (neu bauen, ändern, Texte anpassen)

1. **Lies zuerst `design/LEVELBAU.md` — vollständig.** Dort steht alles: Dateiformat,
   erlaubte Zeichen, Objektkatalog, Designregeln, Befehle, Fehlermeldungen.
2. Du änderst NUR: `design/levels/<level-id>/**`, `design/playlist.json` und
   (nur für neue Farbwelten) `public/config/themes.json`.
3. Nach jeder Änderung: `npm run build:levels`, zum Abschluss `npm run validate`
   UND `npm test` — alle drei müssen fehlerfrei (✓) sein. Erst dann ist deine
   Aufgabe erledigt.

## Absolute Tabuzonen (für Level-Aufgaben)

- `src/`, `tools/`, `docs/`, `design/levels/_vorlage/`, `index.html`,
  `package.json`, `package-lock.json`, `vite.config.ts`, `tsconfig.json`,
  `start-*.bat`, `public/config/input-bindings.json`, `CLAUDE.md`, `AGENTS.md`,
  `design/LEVELBAU.md`
- `public/config/levels/**`, `public/assets/**` und der `levelOrder` in
  `public/config/game-config.json` sind **generiert** — niemals von Hand editieren,
  sie entstehen aus `design/` via `npm run build:levels`.
- Der Kern ist per SHA-256-Manifest gesichert (`npm run guard`, Teil von
  `npm run validate`). Jede Abweichung wird gemeldet und gilt als Fehler.
  `npm run guard:update` ist Menschen vorbehalten.

## Hülle-Level (Klartext ⇄ Verschlüsselt ⇄ VAU)

Der Baukasten kann die Kernmechanik der Lern-Level. Einschalten pro Level mit
`"huelle": { "enabled": true }`; danach stehen `lauscher`, `andock-plattform`,
`vau-feld` und `kontext-anker` zur Verfügung. **Alle Regeln dazu stehen in
`design/LEVELBAU.md`, Abschnitt „Hülle-Mechanik".**

Drei Dinge, die du fachlich NICHT verfälschen darfst:
- Die VAU ist kein Tunnel, sondern ein Raum, in dem im Klartext gearbeitet wird,
  ohne dass Betreiber mitlesen.
- Verschlüsselung ist nicht Signatur (signiert wird per `stamp-exit`).
- Eine abgelaufene Sitzung schützt nicht — sie fällt in den Klartext zurück.

In Hülle-Leveln prüft der Compiler Sprungweiten strenger (~4 statt ~5 Kacheln),
weil verschlüsselt langsamer gelaufen wird. Halte Pflichtsprünge kürzer.

## Wenn die Aufgabe mehr verlangt als der Baukasten kann

Neue Mechanik, neue Grafik, neuer Kameramodus, Engine-/Physik-Änderungen:
**nicht selbst umsetzen.** Erledige den machbaren Level-Teil und liste den Rest am
Ende deiner Antwort unter „Benötigt Engine-Arbeit (Mensch/Senior-KI)" auf.

## Nützliche Befehle

| Befehl | Zweck |
|---|---|
| `npm test` | Engine-Logik prüfen (Hülle, Sicht, Eingabe, Compiler, Verdrahtung) |
| `npm run neues-level -- 05-name` | neues Level aus der Vorlage anlegen |
| `npm run build:levels` | design/ → Spieldateien kompilieren + prüfen |
| `npm run validate` | Komplett-Prüfung (Configs, Level, Erreichbarkeit, Kern-Schutz) |
| `npm run dev` | Spiel lokal starten (http://localhost:5173) |
| `npm run build` | Produktions-Build nach `dist/` (inkl. build:levels) |
