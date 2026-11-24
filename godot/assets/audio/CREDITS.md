# Klänge und Musik

## Musik (OGG Vorbis, lizenzfrei — Pixabay Content License)

Alle vier Stücke stammen von Pixabay (https://pixabay.com/service/license-summary/):
Nutzung in eigenen Projekten, auch kommerziell, ohne Namensnennung erlaubt; nicht
erlaubt ist die Weitergabe der Stücke als eigenständige Dateien. Lautheit mit
`ffmpeg loudnorm` auf −16 LUFS angeglichen. Seit 11/2026 als OGG Vorbis (`ffmpeg -c:a libvorbis -q:a 2`,
~85 kbit/s) statt MP3 128 kbit/s: 4,4 statt 6,7 MB, spürbar kürzerer Download der Web-Fassung.

| Datei | Stück | Urheber | Quelle | Einsatz |
|---|---|---|---|---|
| `music_title.ogg` | Chill/Calming Chiptune Loop | Reganati | https://pixabay.com/music/electronic-chillcalming-chiptune-loop-527182/ | Hauptmenü, Zeitreise, Wissen, Briefings (Schleife) |
| `music_level.ogg` | 8Bit theme Loop – Chiptune Symphony | MusicInMedia | https://pixabay.com/music/video-games-8bit-theme-loop-chiptune-symphony-387749/ | Stationen 01–05 (Praxis, Kartenterminal, Zugang, Hülle, Identität) |
| `music_level2.ogg` | Game Level Pixel Quest Loop | alex-morgan | https://pixabay.com/music/synthwave-game-level-pixel-quest-loop-578505/ | Stationen 13–20 (Rechenzentrum, Archiv); Anfangsstille (0,4 s) entfernt |
| `music_reward.ogg` | That Game Arcade | moodmode | https://pixabay.com/music/upbeat-that-game-arcade-236111/ | Reward-Screen, einmalig mit eigenem Schluss |

Auswahl: Stücke mit „Loop" im Titel und ohne Stille an den Enden (Schleife ohne Bruch);
die Zuordnung Stück → Welt steht in `src/world/Level.gd`, Reward in `src/Main.gd`.
Austausch: neue OGG (oder MP3) unter gleichem Namen ablegen; `Sfx._stream()` nimmt OGG vor MP3 vor WAV.

## Klänge (WAV)

Alle kurzen Klänge (Sprung, Sammeln, Tor, Siegel, Treffer …) sind synthetisch und werden
von `tools/gen_assets.py` erzeugt — keine Fremdquellen. Die früher ebenfalls erzeugten
`music_title.wav` / `music_level.wav` sind durch die Pixabay-Stücke ersetzt und aus dem Repository
entfernt (gen_assets.py legt sie bei Bedarf wieder an; OGG/MP3 hat trotzdem Vorrang).

## Nicht verwendet

The Sounds Resource (sounds.spriters-resource.com) enthält aus kommerziellen Spielen
extrahierte Klänge ohne Nutzungsrecht — für dieses Projekt tabu.
