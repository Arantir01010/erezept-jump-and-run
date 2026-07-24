# Neue Level: Gefahren & Sicherheit — Entwurf zur Abstimmung

*Stand: Juli 2026 · Grundlage: `docs/KONZEPT.md` (gematik-verifizierter Anhang) + aktuelle BSI-/gematik-Quellen · noch nicht gebaut, erst dein OK*

Ziel dieses Dokuments: aufzeigen, **wie das e-Rezept real durch die TI reist**, **welche Gefahren an jeder
Station lauern**, **warum sie scheitern** (v. a. warum die ePA sicher ist) — und daraus **zwei neue,
gefahren-fokussierte Level** ableiten, die die bestehenden drei (Stammdaten, Kartenterminal, KOV Gateway)
ergänzen. Am Ende steht klar getrennt, was ich **sofort bauen kann** und was **Engine-Ausbau** bräuchte.

---

## 1. Der reale Weg — mit Gefahr und Schutz an jeder Station

Der Datensatz „REZI" entsteht in der Arztpraxis und reist verschlüsselt bis zur Apotheke. Wichtig fürs
Spiel: **das Rezept selbst fliegt nie offen durchs Netz** — es liegt im Tresor (Fachdienst), unterwegs ist
nur ein verschlüsselter Tunnel, und der Schlüssel bleibt beim Patienten.

| # | Station (real) | Was hier passiert | Gefahr an dieser Stelle | Warum die Gefahr scheitert |
|---|---|---|---|---|
| 1 | **Kasse / VSDM** | eGK wird online bei der Kasse geprüft | Gefälschte/veraltete Karte, fremde Identität | Nur gültige, aktuelle Karte besteht die Online-Prüfung |
| 2 | **Kartenterminal** | eGK + Arzt signiert mit eHBA + PIN (QES) | Skimming (Kartendaten abgreifen), Manipulation | Besitz **und** Wissen (Karte + PIN), zugelassene Hardware blockt Fremdleser |
| 3 | **TI-Gateway / VPN** | verschlüsselter Tunnel ins geschlossene Netz | Abhören, Man-in-the-Middle im „offenen Internet" | VPN-Verschlüsselung + Netzzugangskontrolle: nur SMC-B-Einrichtungen kommen rein |
| 4 | **e-Rezept-Fachdienst (VAU)** | verschlüsselte Speicherung im „Tresor" | **Malware/Viren im Rechenzentrum, Innentäter, Betreiber-Neugier** | Vertrauenswürdige Ausführungsumgebung (VAU): verarbeitet nur verschlüsselt — **selbst der Betreiber kann nicht mitlesen** |
| 5 | **ePA (Akte)** | Medikationsliste, Patient steuert Zugriffe | **Unbefugter Zugriff, neugierige Dritte, Datenabgriff** | **Zugriffskontrolle durch dich**: Ende-zu-Ende verschlüsselt, du vergibst/entziehst Rechte, jeder Zugriff wird protokolliert |
| 6 | **Apotheke** | Abruf mit SMC-B + Autorisierung, Abgabe | Rezept-Klau, Doppel-Einlösung, gefälschte Signatur | Abruf nur mit Berechtigung; Signaturprüfung; **einmal eingelöst = verbraucht**, Kopien wertlos |

Die Stationen 1–3 sind bereits als Level gebaut. **Die Gefahren-Höhepunkte liegen bei 4 (Fachdienst) und
5 (ePA)** — genau dort setzen die neuen Level an.

---

## 2. Warum die ePA sicher ist — spielerisch übersetzbar

Fünf reale Schutzsäulen (BSI/gematik) — jede lässt sich in eine sichtbare Spielmechanik übersetzen:

1. **Verschlüsselung.** Daten liegen verschlüsselt in zertifizierten deutschen Rechenzentren, Übertragung
   nur über verschlüsselte Kanäle. → *Spielbild:* Verschlüsselungs-Dusche; Lauscher sehen nur Zeichensalat.
2. **Zugriffskontrolle durch dich.** Du siehst, wer zugegriffen hat, kannst Rechte ändern und einzelnen
   Einrichtungen den Zugriff **verweigern**. → *Spielbild:* Tore, die nur DU öffnest; Neugierige prallen ab.
3. **Starke Authentifizierung.** Zugriff nur mit eGK/Ausweis **und** PIN (Besitz + Wissen). →
   *Spielbild:* Prüf-Podest/PIN-Takt als Schleuse vor der Akte.
4. **Protokollierung.** Jeder Zugriff wird nachvollziehbar geloggt. → *Spielbild:* einsammelbare
   „Zugriffsprotokoll"-Marken, die den Ausgang freischalten.
5. **Zertifizierte Hardware & geschlossenes Netz.** BSI-zertifizierte Konnektoren/Terminals/Smartcards,
   kein offenes Internet. → *Spielbild:* der gläserne Tunnel / der Tresor, Angreifer bleiben außen.

> **Ehrlich eingeordnet:** Sicherheitsforscher (u. a. CCC) haben früh Schwächen an e-Rezept/ePA benannt;
> gematik/BSI haben nachgebessert, bevor „ePA für alle" flächendeckend startete. Fürs Spiel gilt die
> **Architektur-Aussage** (Karte+PIN, Signatur, Verschlüsselung, Zugriffskontrolle schützen) — das ist die
> offizielle, aktuelle Linie und deckt sich mit No-Go #9: *kein „Hacker-gewinnt"-, kein „Spieler-kämpft"-Bild.*

---

## 3. Die Gefahren-Galerie (Markenregel: Angreifer scheitern komisch, es wird nie gekämpft)

Alle Angreifer teilen dasselbe Verhalten: **sie wollen Daten abgreifen und scheitern sichtbar an der TI**
(„ZUGRIFF VERWEIGERT"). Für die neuen Level schlage ich fünf Gefahren-Typen vor:

| Gefahr (Spielname) | Reale Entsprechung | Verhalten im Spiel | Scheitert an … |
|---|---|---|---|
| **Skimming-Kralle** *(vorhanden)* | Kartendaten-Diebstahl | greift auf Kopfhöhe, man duckt sich | zugelassene Hardware / Siegel |
| **Datenkrake** *(vorhanden)* | Lauscher im Netz | schleicht hinterher, drängelt ans Tor | Firewall-Tor / Verschlüsselung |
| **Lauscher-Auge** | Man-in-the-Middle | „liest mit", solange unverschlüsselt | Verschlüsselung (sieht nur Static) |
| **Virus / Glitch-Gremlin** | Malware im Rechenzentrum | zuckt/glitcht, will in den Tresor | VAU-Schleuse / Signaturprüfung |
| **Neugier-Geist** | unbefugter ePA-Zugriff | schwebt an die Akte, will „reingucken" | deine Zugriffskontrolle (Tor bleibt zu) |

---

## 4. Mechanik-Mapping: Was ich SOFORT bauen kann — und was Engine-Arbeit bräuchte

Der Baukasten (siehe `design/LEVELBAU.md`) trägt die Gefahren-Level bereits weitgehend:

**Sofort baubar (bestehende Bausteine):**

- **Datenabfangen** → `deny-enemy` (Angreifer greift, TI blockt nach N Versuchen) — beliebig oft platzierbar,
  das ist die zentrale Gefahren-Mechanik.
- **Verschlüsselung** → `krypto-dusche` (Schutz-Optik an, Lauscher sehen Static).
- **Zugriffskontrolle / Autorisierung** → `stillstand-podest` (Prüf-Scan) bzw. `timing-gate` (PIN-Takt) +
  benanntes `gate`, das nur nach bestandener Prüfung aufgeht.
- **Gefahrenzone** (nur außerhalb geschützter Bereiche!) → `hazard`.
- **Machtlose Angreifer als Kulisse** → `deco` (Kraken außen am Glas).
- **Protokoll-/Datensammeln** → Datenbits (`o`) + `collectible.countRequired` schalten den Ausgang frei.

**Nur mit Engine-Ausbau (heute Stubs — brauchen Mensch/Senior-KI):**

- **Virenscanner-Setpiece** (`pruef-scanner`): „Echtes passiert, Fake/Virus wird aussortiert" — ein
  Sortier-Minispiel. *Ersatz heute:* `stillstand-podest` als VAU-Schleuse + `deny-enemy`-Viren, die abprallen.
- **Rechte-Türen mit Wahl** (`rechte-tueren`): aktive Zugriffs-Entscheidung des Patienten. *Ersatz heute:*
  mehrere `gate`s, die nur nach Autorisierung öffnen; Neugier-Geister prallen ab.
- **Finale-Sprint + Kopie-Twist** (`finale-sprint`): Apotheken-Finale mit „Kopie wertlos". *Ersatz heute:*
  `stamp-exit` als Einlöse-Stempel.
- **Neue Gegner-Grafiken** (Virus-Sprite, Lauscher-Auge): heute über vorhandene Sprites (Krake/Kralle)
  darstellbar; eigene Pixel-Sprites wären Engine-Arbeit in `TextureFactory.ts`.

**Fazit:** Zwei vollwertige, gefahren-dichte Level sind **jetzt** baubar. Die „Königsklasse"-Setpieces
(Sortier-Scanner, Wahl-Türen, Kopie-Twist) hebe ich als optionalen Ausbau hervor — sie würden die Level
später von „sehr gut" auf „herausragend" heben.

---

## 5. Level-Entwurf A — „e-Rezept-Fachdienst: Der Tresor" *(Station 4)*

**Ein-Satz-Pitch:** REZI wird im Hochsicherheits-Rechenzentrum eingelagert — Viren und ein neugieriger
Betreiber-Bot wollen an die Daten, aber die vertrauenswürdige Ausführungsumgebung lässt niemanden mitlesen.

| | |
|---|---|
| **cameraMode** | `horizontal` |
| **Intensität** | 4/5 — der Gefahren-Höhepunkt |
| **Theme (neu)** | `fachdienst` — kühles Serverraum-Blau/Türkis mit goldenen Sicherungs-Akzenten |
| **Gegner-Skins** | `glitch-gremlin` (Virus), `manipulator-bot`, `datenkrake` |
| **Siegel / Badge** | `seal-generic` / „VAU · Ende-zu-Ende" |
| **parTime** | ~35 s |

**Dramaturgie & Aufbau (links → rechts):**

1. **Einlass-Schleuse.** Eine `stillstand-podest`-Prüfung („Zutritt nur verschlüsselt") öffnet das erste
   `gate`. Dahinter drängelt eine `datenkrake` — sie bekommt das Tor vor die Nase („ZUGRIFF VERWEIGERT").
2. **Virengang.** Zwei bis drei `deny-enemy` als **Viren/Glitch-Gremlins**, die aus Server-Schränken nach
   dem Rezept greifen — man duckt sich durch, die TI blockt sie nacheinander sichtbar. Dazwischen
   Datenbits (= abgesicherte Datenpakete).
3. **Die VAU (Herzstück).** Eine `krypto-dusche` legt die Ende-zu-Ende-Verschlüsselung an; ab hier sehen
   alle Lauscher nur Static. REZI-Satz: *„Hier drin bin ich verschlüsselt — nicht mal der Betreiber sieht,
   was drinsteht!"* Das öffnet das VAU-`gate`.
4. **Betreiber-Bot-Gag.** Ein `manipulator-bot` (`deny-enemy`) will als „Wartungszugriff" mitlesen — prallt
   am Siegel ab. Kernbotschaft: *Betreiber ≠ Zugriff.*
5. **Ausgang.** `door-exit`, freigeschaltet durch gesammelte Datenpakete (z. B. `countRequired: 6`).

**Lern-Dreiklang:**
> **Portal:** „Station 4: e-Rezept-Fachdienst — der Tresor der TI."
> **REZI (in der VAU):** „Ich liege verschlüsselt im Tresor — selbst der Betreiber kann mich nicht lesen!"
> **Stempel:** „✓ Sicher verschlüsselt gespeichert (VAU)."

**Fachbezug:** Zentraler Fachdienst mit vertrauenswürdiger Ausführungsumgebung; Verarbeitung nur
verschlüsselt; das Rezept liegt hier (nicht auf der Karte), der Schlüssel bleibt beim Patienten.

---

## 6. Level-Entwurf B — „Deine Akte, deine Entscheidung" *(Station 5, ePA)*

**Ein-Satz-Pitch:** In der elektronischen Patientenakte entscheidet Paul selbst, wer rein darf —
neugierige Geister prallen an Türen ab, die nur er öffnet, und jeder Zugriff wird protokolliert.

| | |
|---|---|
| **cameraMode** | `horizontal` |
| **Intensität** | 3/5 — bewusste Verschnaufpause mit klarer Kernbotschaft |
| **Theme (neu)** | `akte` — warmes Archiv-Violett/Bernstein, „Aktenschrank-Innenwelt" |
| **Gegner-Skins** | `neugier-geist`, `lauscher-auge` |
| **Siegel / Badge** | `seal-generic` / „ePA · Zugriffskontrolle" |
| **parTime** | ~30 s |

**Dramaturgie & Aufbau:**

1. **Protokoll sammeln.** Datenbits sind **Zugriffsprotokoll-Marken** („wer hat wann zugegriffen") —
   `collectible.label` = „Protokoll-Einträge". Sie schalten am Ende die Akte frei: *Transparenz ist Teil
   der Sicherheit.*
2. **Autorisierungs-Schleuse.** Ein `timing-gate` (als PIN/GesundheitsID-Takt) oder `stillstand-podest`
   öffnet das erste `gate` — *nur mit deiner starken Anmeldung.*
3. **Neugier-Geister.** Zwei `deny-enemy` als **Neugier-Geister**, die an verschlossene `gate`s schweben
   und abprallen („ZUGRIFF VERWEIGERT"). Kernbild: *Du hast die Tür zugelassen — sie kommen nicht rein.*
4. **Verweigern-Moment.** Ein `info-sign`/REZI-Moment: *„Diesen Zugriff verweigerst du — und schon ist die
   Tür zu."* (Als Vollausbau: echte Wahl-Tür `rechte-tueren`, siehe §4.)
5. **Ausgang.** `door-exit`, freigeschaltet durch die Protokoll-Marken.

**Lern-Dreiklang:**
> **Portal:** „Station 5: Deine elektronische Patientenakte."
> **REZI:** „Du entscheidest, wer meine Daten sehen darf — und siehst jeden Zugriff!"
> **Stempel:** „✓ Du hast die Kontrolle über deine Akte."

**Fachbezug:** ePA mit Medikationsliste; Ende-zu-Ende-Verschlüsselung, Zugriffssteuerung und
Protokollierung durch die/den Versicherten; Widerspruchs-/Verweigerungsrechte.

---

## 7. Empfehlung & nächste Schritte

- **Zuerst bauen: Level A (Fachdienst).** Es ist der Gefahren-Höhepunkt (Viren, Betreiber-Bot,
  Verschlüsselung) und zeigt am deutlichsten „warum sicher". Danach Level B (ePA) als ruhigerer,
  botschaftsstarker Kontrast.
- **Beide sind mit dem heutigen Baukasten voll spielbar** — inklusive Erreichbarkeits- und Softlock-Prüfung.
  Ich lege sie als `design/levels/04-fachdienst/` und `05-epa/` an und reihe sie hinter Station 3 in die
  Playlist.
- **Zwei neue Themes** (`fachdienst`, `akte`) ergänze ich in `public/config/themes.json` (je 6 Hex-Farben,
  erlaubt).
- **Optionaler Engine-Ausbau** (separat, durch Mensch/Senior-KI): Virenscanner-Sortierspiel
  (`pruef-scanner`), Wahl-Türen (`rechte-tueren`), Kopie-Twist-Finale (`finale-sprint`) und eigene
  Virus-/Lauscher-Sprites. Damit würden die Level von „sehr gut" auf „herausragend" gehoben.

**Offene Entscheidung für dich:** Baue ich beide Level jetzt (buildbare Version), starte ich mit einem der
beiden, oder soll ich zuerst noch eine dritte, reine „Gefahren-Galerie"-Station als Tutorial für die
Angreifer-Typen entwerfen?
