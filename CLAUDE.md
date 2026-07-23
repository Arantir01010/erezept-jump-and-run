# Regeln für KI-Agenten in diesem Repository

Dieses Projekt ist ein fertiges Messespiel mit einem **gekapselten
Level-Baukasten**. Der Spielkern ist getestet und wird NICHT angefasst.

## Aufgabe = neues Level? → NUR der Baukasten

Lies **`levels-src/ANLEITUNG.md`** — das ist die vollständige, einzige
Anleitung. Kurzfassung:

1. `levels-src/_VORLAGE.level.json` kopieren → `levels-src/<nn-name>.level.json`
2. Ausfüllen (Texte + ASCII-Karte)
3. `npm run levels` — der Compiler prüft Spielbarkeit und generiert alles
4. Level-ID in `public/config/game-config.json` → `levelOrder` eintragen
5. `npm run validate` muss grün sein

## Verbotene Zonen (niemals ändern)

| Pfad | Warum |
|---|---|
| `src/**` | Spielkern (Physik, Szenen, Mechaniken, Rendering) — getestet, Messe-kritisch |
| `tools/**` | Compiler & Prüfwerkzeuge — sie SIND die Leitplanken |
| `public/assets/tilemaps/**` | GENERIERT aus levels-src (npm run levels) |
| `public/config/levels/**` | GENERIERT aus levels-src (npm run levels) |
| `dist/**`, `.github/**`, `package.json`, `tsconfig.json`, `vite.config.ts` | Build & Deploy |

Erlaubte Änderungen außerhalb von `levels-src/`: **eine Zeile** in
`game-config.json` (`levelOrder`) und **additiv** neue Einträge in
`themes.json`. Sonst nichts.

Wenn eine Aufgabe scheinbar Änderungen am Spielkern erfordert: **STOPP** —
nicht umbauen, sondern dem Menschen melden, was fehlt.

## Prüfen statt hoffen

- `npm run levels` — kompiliert alle Level-Quellen, lehnt Unspielbares ab
  (Sprungphysik, Erreichbarkeit, Tor-Verknüpfung, Sammel-Margen)
- `npm run validate` — Gesamtprüfung aller Konfigurationen
- Beide Kommandos müssen fehlerfrei sein, bevor irgendetwas committet wird

## Kontext

Spiel: „Paul & REZI" — e-Rezept-Jump'n'Run für den Messestand
(Phaser 3, alle Grafiken prozedural). Konzept: `docs/KONZEPT.md`.
Redaktions-Doku: `docs/LEVEL-EDITING.md`. Das Spiel deployt bei jedem
Push auf `main` automatisch auf GitHub Pages.
