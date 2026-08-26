# Geparkte Level — nicht im Spiel

Ordner, die mit `_` beginnen, überspringt die Level-Pipeline vollständig
(`tools/lib/pipeline.ts`). Hier liegen fertig gebaute Level, die bewusst **nicht**
in `design/playlist.json` stehen.

## Warum diese zwei hier liegen

`04-fachdienst` und `05-epa` waren in Commit „Zwei neue Gefahren-/Sicherheits-Level"
aktiv. Für die Wirkungsmessung nach KAPSEL 4.1 wurde die Playlist danach auf **ein**
Hülle-Level verkürzt (`04-die-huelle`) — erst messen, dann skalieren, siehe
`docs/PLAYTEST.md`. Die beiden Level sind nicht verworfen, nur geparkt.

## Achtung beim Reaktivieren

Mit den Leveln wurden auch ihre Farbwelten aus `public/config/themes.json` entfernt.
Wer sie zurückholt, braucht **beides**:

1. Ordner zurück nach `design/levels/<id>/` verschieben und in `design/playlist.json`
   eintragen.
2. Die Themes `fachdienst` und `akte` in `public/config/themes.json` wieder ergänzen —
   sonst bricht `npm run build:levels` mit „unbekanntes Theme" ab.

Die Farbwerte stehen in der Git-Historie: `git show 63aa845 -- public/config/themes.json`
