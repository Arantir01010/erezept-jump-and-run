# Geparkte Level — nicht im Spiel

Ordner, die mit `_` beginnen, überspringt die Level-Pipeline vollständig
(`tools/lib/pipeline.ts`). Hier liegen fertig gebaute, geprüfte Level, die
bewusst **nicht** in `design/playlist.json` stehen.

## Die schlanken zehn

Die Playlist ist bewusst auf **10 Level** begrenzt (~15 Minuten). KAPSEL 4.1
nennt genau das als Pivot bei Terminrisiko: lieber weniger Level in guter
Qualität als 26 mittelmäßige. Die Auswahl ist nicht willkürlich — jede der
fünf fachlichen Leitplanken aus KAPSEL 1.4 bleibt vertreten:

| Leitplanke | trägt |
|---|---|
| Vertraulichkeit ist sichtbar oder nicht | `04-die-huelle` |
| Keine Rolle ersetzt eine andere | `05-identitaet` |
| Verschlüsselung ≠ Signatur | `02-kartenterminal` (Signatur-Stempel) |
| Die eGK ist Schlüssel, kein Speicher | `13-e-rezept` |
| Die VAU ist ein Raum, kein Tunnel | `14-die-vau` |
| Abgelaufene Sitzung schützt nicht | `15-kontextschluessel` |
| Datenhoheit liegt bei der Versicherten | `19-berechtigungen`, `20-souveraenitaet` |

## Was hier liegt und warum

**Aus dem 20-Level-Ausbau herausgenommen** (alle kompilieren fehlerfrei, nur
aus Umfangsgründen geparkt): `06-raus-aus-der-praxis`, `07-der-konnektor`,
`08-vpn-tunnel`, `09-smc-b`, `10-kim`, `11-zentrale-zone`,
`12-der-fachdienst`, `16-zugriffsprotokoll`, `17-baustelle`,
`18-das-aktensystem`.

**Ältere Gefahren-Level**: `04-fachdienst` und `05-epa` waren vor der
Wirkungsmessung aktiv, siehe `docs/PLAYTEST.md`.

## Reaktivieren

1. Ordner nach `design/levels/<id>/` zurückschieben und in
   `design/playlist.json` eintragen.
2. `npm run build:levels` — erzeugt die Spieldateien neu.

Achtung bei `04-fachdienst` und `05-epa`: Mit ihnen wurden auch die Farbwelten
`fachdienst` und `akte` aus `public/config/themes.json` entfernt. `akte` gibt es
inzwischen wieder; `fachdienst` steht in der Historie:
`git show 63aa845 -- public/config/themes.json`

Die Farbwelten `praxis`, `zugang` und `baustelle` gehören zu den geparkten
Leveln und stehen weiter in `themes.json` bereit.
