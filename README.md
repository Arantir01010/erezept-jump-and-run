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

Beide Eingaben funktionieren immer parallel — ein USB-Arcade-Encoder wird ohne
Konfiguration erkannt (Button-Belegung in `public/config/input-bindings.json`,
Kalibrier-Overlay im Spiel: **F8**).

## Prototyp-Inhalt

- **Level „Kartenterminal"** (horizontal): Kontaktpad-Parcours, Skimming-Kralle
  (ducken!), PIN-Schleuse als Timing-Gate (Dr. Pixel signiert mit eHBA + Arzt-PIN),
  Signatur-Stempel-Finale
- **Level „KOV Gateway"** (Auto-Scroll-Glastunnel): Prüf-Podeste (stillstehen!),
  Verschlüsselungs-Dusche, Datenkraken machtlos außen am Glas
- Stadt-Band mit Portal-Dive zwischen den Stationen, HUD mit TI-Streckenkarte,
  Reward-Screen mit Offline-QR-Code, Tages-Highscore (Avatar-Icons, keine Personendaten),
  Kiosk-Modus (Attract, Idle-Reset, CrashGuard)
- Automatische REZI-Tipps, wenn jemand nicht weiterkommt (wiederholtes Scheitern,
  geschlossene Tore, kein Fortschritt) — Texte anpassbar, siehe [docs/LEVEL-EDITING.md](docs/LEVEL-EDITING.md)
- Rendering intern in 1920×1080: Pixel-Art bleibt stilecht blockig (Kamera-Zoom 3×),
  Schrift und QR-Code sind nativ scharf — auf dem Messe-TV wie im Browserfenster

## Neue Level bauen: der Baukasten (auch für KIs)

Level entstehen als **ASCII-Karten + Metadaten** in `levels-src/<id>.level.json` —
bewusst so einfach, dass auch schwächere KI-Modelle sicher damit arbeiten können.
`npm run levels` prüft Spielbarkeit (Sprungphysik, Erreichbarkeit, Tor-Verknüpfung)
und generiert daraus die Runtime-Dateien; kaputte Level werden abgelehnt, der
Spielkern bleibt unangetastet. **Die komplette Anleitung:**
[levels-src/ANLEITUNG.md](levels-src/ANLEITUNG.md) · Leitplanken für KI-Agenten:
[CLAUDE.md](CLAUDE.md)

## Für Redakteur:innen: Alles ist Daten

Stationen umbenennen, umsortieren, Texte ändern — **ohne Rebuild** in `public/config/`
(JSON, zod-validiert mit lesbaren Fehlermeldungen).
Anleitung: [docs/LEVEL-EDITING.md](docs/LEVEL-EDITING.md) · Gesamtkonzept inkl.
Leveldesign aller 6 Stationen, TI-Fachlichkeit und Messebetrieb: [docs/KONZEPT.md](docs/KONZEPT.md)

## Befehle

| Befehl | Zweck |
|---|---|
| `npm run dev` | Entwicklung (Vite, HMR) |
| `npm run build` | Offline-fähiger Produktions-Build nach `dist/` |
| `npm run validate` | Alle Konfigurationen + Tilemaps + Baukasten-Synchronität prüfen (CI-tauglich) |
| `npm run levels` | Level-Quellen aus `levels-src/` kompilieren (mit Spielbarkeits-Prüfung) |
| `start-messe.bat` | Messestart: lokaler Server + Chrome-Kiosk (`?kiosk=1`) |

URL-Parameter: `?debug=1` FPS-Anzeige · `?debug=2` Physik-Debug · `?kiosk=1` Kiosk-Härtung (Cursor aus, CrashGuard) · `?renderer=canvas` 2D-Fallback für Rechner ohne brauchbares WebGL.

## Tech-Stack

Phaser 3 · TypeScript · Vite · zod · qrcode · Tiled-JSON-Tilemaps.
Alle Pixel-Grafiken werden prozedural zur Laufzeit erzeugt (keine Binär-Assets) —
Custom-Art ersetzt später nur Texturen, siehe `src/gfx/TextureFactory.ts`.
