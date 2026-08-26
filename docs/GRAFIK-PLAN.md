# Grafik-Plan — vom Prototyp zum fertigen Bild

Stand nach dem Umbau auf den atmosphärischen Look. Dieses Dokument ist die
Arbeitsliste für alles, was noch nicht konvertiert ist — sortiert nach
Wirkung pro Aufwand, nicht nach Reihenfolge im Code.

## Wo wir stehen

Umgestellt auf Vektorgrafik (scharf bei jedem Zoom, keine Quellpixel):

| Bereich | Datei |
|---|---|
| Renderer, Antialiasing | `src/main.ts` |
| Dunst, Tiefenmischung, Post-FX, Laterne | `src/gfx/atmos.ts` |
| Hintergrund: Türme, Nebelbänder, Lichtschächte | `src/gfx/backdrop.ts` |
| Gelände als Silhouette mit Kantenlicht | `src/gfx/TerrainRenderer.ts` |
| Paul: Silhouette, Lauf-IK, Sprungpose | `src/gfx/PaulSilhouette.ts` |
| REZI: leuchtende Karte | `src/gfx/ReziBody.ts` |

Noch Pixel-Art (`src/gfx/TextureFactory.ts`), und damit sichtbarer Stilbruch:

Lauscher · Krake · Kralle · Portal · Kartenleser · eGK/HBA/SMC-B · Stempel ·
Datenbit · Tür · Gate · Podest · Krypto-Dusche · Checkpoint · Siegel (4) ·
Avatare (12) · Stadt-Fassaden (`CityScene`) · HUD und Schrift (`UIScene`,
`src/gfx/text.ts`) · Sprechblase · Reward-Screen.

---

## 1. Materialsystem — der Hebel, der alles andere billiger macht

**Problem.** Jedes Objekt wählt heute seine Farben selbst. Deshalb sieht das
Bild zusammengetragen aus statt entworfen, und jede Konvertierung ist eine
neue Einzelentscheidung.

**Lösung.** Eine kleine Datei `src/gfx/material.ts` mit benannten Materialien,
die sich aus dem Theme ableiten:

| Material | Bedeutung | Aussehen |
|---|---|---|
| `fels` | tragende Masse | dunkelste Fläche, Kantenlicht oben |
| `glas` | durchlässig, aber Grenze | 13 % Füllung, kräftige Kontur, Reflex |
| `metall` | Technik, unbeweglich | mittlere Fläche, harte Kante, kein Glühen |
| `signal` | Interaktion möglich | Akzentfarbe, pulsierendes Glühen |
| `gefahr` | warm, offen, gesehen | Orange-Rot, hartes Licht |
| `schutz` | kühl, verschlüsselt | Cyan-Mint, weiches Licht |

Die letzten beiden sind **keine Geschmacksfrage**: Die Farbregel
„warm = offen/sichtbar, kühl = geschützt" steht im Konzept und zieht sich
durch alle Lern-Level. Sie gehört ins Materialsystem, damit sie niemand
versehentlich bricht.

Danach ist jedes weitere Objekt eine Formfrage, keine Farbfrage mehr.

**Aufwand:** ein halber Tag. **Wirkung:** halbiert den Aufwand von Punkt 2.

---

## 2. Die 25 Objekte konvertieren — der große Brocken

Jedes Objekt nach demselben Rezept: **Silhouette + Kantenlicht + genau eine
Signalfarbe.** Keine Binnenzeichnung, keine dritte Farbe.

Reihenfolge nach Sichtbarkeit im Spiel:

1. **Datenbit** — kommt hundertfach vor, ist heute ein Pixelkreuz. Als
   leuchtender Kern mit zwei Ringen sofort ein anderes Bild.
2. **Lauscher** — der Gegner der Kernmechanik. Auge als Silhouette, der
   Sichtkegel als weicher Lichtkegel statt flacher Dreiecksfläche.
3. **Portal / Tür** — Levelziel, das den Blick ziehen muss.
4. **Kartenleser, eGK/HBA/SMC-B, Stempel** — die Fachobjekte. Hier lohnt
   Sorgfalt: Sie tragen die Lehre.
5. **Krake, Kralle** — seltener, aber Bewegung zieht Blicke.
6. **Podest, Gate, Dusche, Checkpoint** — Leveltechnik, darf zurücktreten.
7. **Siegel, Avatare** — nur im HUD und im Highscore.

**Aufwand:** 2–4 Tage. Das ist der eigentliche Weg zum fertigen Bild.

---

## 3. Licht als System statt als Deko

Heute setzt jedes Objekt sein eigenes `addGlow`. Das Ergebnis sieht man im
Level „Die Hülle": Alles glüht ein bisschen, also glüht nichts.

Drei Stufen einführen und einhalten:

- **Leitlicht** — genau EINES pro Bild. Das ist REZI. Nichts darf heller sein.
- **Signallicht** — Dinge, mit denen man interagieren kann. Deutlich schwächer,
  aber pulsierend, damit der Blick sie findet.
- **Ambientlicht** — Fenster, Funken, Kantenlicht. Nur Textur, nie Blickfang.

**Aufwand:** ein Tag, verteilt über Punkt 2.

---

## 4. Typografie und HUD

Der letzte Rest, der aus einem anderen Spiel stammt.

- **Courier ersetzen.** Eine Groteske signalisiert „heute" stärker als jedes
  Sprite. `src/gfx/text.ts` ist die einzige Stelle.
- **Level-Einblendung** als weich ein- und ausblendender Titel über der Szene
  statt als Kasten mit Rahmen.
- **HUD** als dünne Glas-Pillen am Rand.
- **Hülle-Anzeige** bleibt dreifach codiert (Farbe UND Form UND Text) — das
  ist eine Barrierefreiheits-Zusage aus der README, keine Stilfrage.
- **Sprechblase** mit weicher Spitze, halbtransparent, ohne harten Rahmen.

**Aufwand:** ein Tag. **Wirkung:** überproportional, weil Schrift in jedem
Bild zu sehen ist.

---

## 5. Lesbarkeit am Messestand — die Gegenprobe

Der dunkle Stil hat einen Preis, und den muss man einplanen: **Eine Halle ist
hell.** Was am Entwickler-Monitor stimmungsvoll aussieht, ist auf einem TV bei
Hallenlicht schwarz.

Vier Maßnahmen:

1. **Helligkeitsordnung festschreiben und prüfen.** Gelände am dunkelsten,
   dann nahe, mittlere, ferne Türme. Kippt diese Ordnung, wirkt der
   Hintergrund näher als das Spielfeld. Ein Test könnte die Leuchtdichte der
   Ebenen vergleichen und bei falscher Reihenfolge fehlschlagen.
2. **Kantenlicht ist Gameplay, nicht Deko.** Jede begehbare Oberkante muss
   leuchten. Auch das ist automatisch prüfbar.
3. **`?hell=1`** — ein Messe-Modus, der `brightness` in `applyAtmosphere`
   anhebt und die Vignette abschaltet. Zwei Zeilen, rettet den Stand, wenn
   die Beleuchtung nicht mitspielt.
4. **Auf dem echten TV testen**, nicht auf dem Laptop. Kein Ersatz dafür.

**Aufwand:** halber Tag.

---

## 6. Bewegung — billiger als Grafik, wirkt fast so stark

- **Kamera:** Vorausschauen in Laufrichtung (Offset in Blickrichtung), weiches
  Nachziehen, minimaler Stoß bei Landung und Treffer.
- **Übergänge:** Kreuzblende mit Lichtwisch statt hartem Schnitt.
- **Einsammeln:** kurzer Partikelblitz und ein Funke, der zu REZI fliegt —
  verbindet Sammelobjekt und Begleiter erzählerisch.
- **Türen und Tore:** öffnen mit Licht, nicht mit Verschwinden.

**Aufwand:** ein Tag.

---

## Nicht anfassen

- **Der QR-Code im Reward-Screen.** Er muss von Handykameras gelesen werden.
  Harte Schwarz-Weiß-Kanten, ruhige Fläche drumherum, kein Bloom, kein Glühen,
  keine Vignette darüber. Das ist eine Funktion, keine Grafik.
- **Die dreifache Codierung der Hülle-Anzeige** (siehe Punkt 4).
- **Die Farbregel warm/kühl** (siehe Punkt 1).
- **`design/`, der Level-Compiler, die Erreichbarkeitsprüfung.** Der ganze
  Umbau kommt ohne sie aus — das soll so bleiben.

---

## Der offene Grundsatzpunkt: prozedural oder gezeichnet

Alles bisher ist prozedural: kein einziges Binär-Asset, der Build läuft
offline, es gibt keine Asset-Pipeline. Das ist ein echter Vorteil für einen
Messe-PC und für die Wartung.

Die Grenze davon ist erreicht, sobald Kulissen mehr sein sollen als
Silhouetten — gemalte Ebenen mit Struktur, wie in den Vorbildern, entstehen
nicht aus `fillRoundedRect`. Der Wechsel wäre: gezeichnete Ebenen als PNG,
eine Ladepipeline, ein Ordner mit Bildern, den jemand pflegen muss.

Vorschlag: **erst die Punkte 1 bis 6 abarbeiten.** Sie holen das Meiste aus
dem prozeduralen Weg heraus, ohne die Offline-Eigenschaft aufzugeben. Wenn
danach immer noch etwas fehlt, ist die Antwort gezeichnete Hintergründe —
und dann weiß man auch genau, welche.

---

## Reihenfolge und Aufwand

| Schritt | Aufwand | Warum an dieser Stelle |
|---|---|---|
| 1. Materialsystem | 0,5 T | macht alles Folgende billiger |
| 4. Typografie und HUD | 1 T | größter sichtbarer Sprung pro Stunde |
| 2. Objekte konvertieren | 2–4 T | der eigentliche Weg zum fertigen Bild |
| 3. Lichtsystem | 1 T | läuft in Schritt 2 mit |
| 6. Bewegung | 1 T | poliert, was dann steht |
| 5. Lesbarkeitsprüfung | 0,5 T | zum Schluss, gegen den echten TV |

Nach jedem Schritt: `npm test`, `npm run validate`, und weil der Kern
angefasst wird, am Ende `npm run guard:update` — von Hand, siehe `CLAUDE.md`.
