# Paul & REZI — Sicher durch die digitale Stadt

## Konzeptdokument: e-Rezept Jump 'n' Run für den Messestand „Sichere Digitalisierung im Gesundheitswesen"

| | |
|---|---|
| **Projekt** | Messespiel e-Rezept / Telematikinfrastruktur (Arcade-Konsole + Medikamentenautomat) |
| **Auftraggeber** | PwC Deutschland, fachliche Begleitung: gematik |
| **Dokumentversion** | 1.0 |
| **Stand** | 22.07.2026 |
| **Status** | Zur Freigabe (PwC-Projektteam und gematik-Fachreview) |
| **Zielgruppe des Dokuments** | PwC-Projektteam, gematik-Fachreview, Entwicklungsteam |
| **Plattform** | Arcade-Konsole (Joystick, roter Button = Springen, blauer Button = Aktion), TV-Bildschirm, Browser im Kiosk-Modus, vollständig offline |
| **Claim** | „Einfach. Sicher. Digital." (Freigabe gematik erforderlich, siehe Abschnitt 9.4) |

---

## Inhaltsverzeichnis

1. [Executive Summary](#1-executive-summary)
2. [Das Standerlebnis](#2-das-standerlebnis)
3. [Spielkonzept „Paul & REZI — Sicher durch die digitale Stadt"](#3-spielkonzept-paul--rezi--sicher-durch-die-digitale-stadt)
4. [Die sechs Level im Detail](#4-die-sechs-level-im-detail)
5. [Durchgängige Systeme](#5-durchgängige-systeme)
6. [Spannungskurve und Dramaturgie](#6-spannungskurve-und-dramaturgie)
7. [Anpassbarkeit: Die Level-Schablone](#7-anpassbarkeit-die-level-schablone)
8. [Technische Architektur](#8-technische-architektur)
9. [Messebetrieb](#9-messebetrieb)
10. [Fachlicher Anhang](#10-fachlicher-anhang)
11. [Prototyp: Umfang und Abnahmekriterien](#11-prototyp-umfang-und-abnahmekriterien)
12. [Roadmap zur Messe](#12-roadmap-zur-messe)

---

# 1. Executive Summary

**Die Idee:** Besucher des Messestands spielen an einer Arcade-Konsole ein Pixel-Art Jump 'n' Run und begleiten dabei ein e-Rezept auf seinem echten Weg durch die Telematikinfrastruktur (TI) — von der Arztpraxis bis zur Apotheke. Der Spieler steuert **Pixel-Paul**, einen Patienten, der mit seinem frisch erstellten e-Rezept **REZI** (ein schwebendes Datenpäckchen mit Knopfaugen) um die Wette zur Apotheke läuft. Vor jeder TI-Station taucht Paul durch ein leuchtendes Daten-Portal in die digitale Ebene ab und erlebt dort körperlich, was die TI an dieser Station für ihn tut: Daten prüfen, Identität sichern, verschlüsseln, Signaturen kontrollieren, Zugriffe steuern, Einlösung schützen.

**Die Botschaft:** Hinter jedem realen Schritt im Gesundheitswesen arbeitet sichere digitale Infrastruktur — und sie arbeitet *für* den Patienten. Angreifer (Datenkraken, Lauscher, Fälscher) tauchen sichtbar auf, scheitern aber immer und komisch an einer TI-Funktion: **„ZUGRIFF VERWEIGERT"**. Es wird nie gekämpft. Nicht die Geschicklichkeit des Spielers schützt die Daten, sondern die Architektur der TI. Am Ende steht die Kernaussage des Auftraggebers als erlebtes Gefühl: **Einfach. Sicher. Digital.**

**Das Standerlebnis:** Ein Durchlauf dauert realistisch 3:30 bis 4:30 Minuten. Am Ende setzen sich die sechs gesammelten Sicherheits-Siegel auf dem Bildschirm zu einem echten QR-Code zusammen — dem „e-Rezept" des Besuchers, einlösbar am Medikamentenautomaten direkt neben der Konsole. Jeder Spieler erreicht garantiert das Ziel: Ein Assist-System („TI-Schutzschild") und ein Soft-Autopilot („Express-Zustellung") sorgen dafür, dass niemand den Stand ohne Erfolgserlebnis und Automaten-Belohnung verlässt. Ein Tages-Highscore mit Avatar-Icons erzeugt Wettbewerb, der Attract-Mode mit Auto-Demo zieht Laufpublikum an.

**Die Basis:** Technisch ist das Spiel ein vollständig offline lauffähiger Browser-Build (Phaser 3 + TypeScript + Vite) mit datengetriebenen Leveln: Stationen, Texte, Reihenfolge und Level-Silhouetten stehen in JSON-Dateien, die ein Redakteur ohne Programmierkenntnisse ändern kann. Für die nächste Messe mit anderen TI-Themen (ePA, KIM, GesundheitsID …) wird keine neue Software gebaut, sondern eine neue Stationsliste gesteckt.

---

# 2. Das Standerlebnis

## 2.1 Der Ablauf aus Besuchersicht

Das Spiel ist Teil einer Erlebniskette am Stand: **Anziehen → Spielen → Belohnen → Gespräch.**

| Phase | Dauer | Was passiert |
|---|---|---|
| **1. Attract** | laufend | Auf dem TV rotiert der Attract-Mode: Titelbild mit Paul & REZI, Tages-Highscore-Liste und eine Auto-Play-Demo von Level 3 — die Verschlüsselungs-Verwandlung und der spektakuläre VPN-Röhren-Ride, der visuell stärkste Moment des Spiels. Dazu rotierende Merksätze und blinkend: **„Drück den roten Knopf!"** Schon Vorbeigehende nehmen die Kernbotschaft mit. |
| **2. Start** | 3 s | Jeder Knopfdruck startet sofort. Kurzes Titelbild: „Paul & REZI — begleite dein e-Rezept sicher durch die Stadt!" |
| **3. Spiel** | 3:30–4:30 min | Sechs Stationen der TI-Streckenkarte (identisch zur Grafik am Stand), verbunden durch kurze Stadt-Zwischenläufe (je ≤ 5 Sekunden). Zuschauer sehen im 30-Sekunden-Takt neue Spielformen — Zuschauer sind die nächsten Spieler. |
| **4. Finale** | 15 s | Zieleinlauf in der Apotheke: Die sechs gesammelten Siegel fliegen ins Bildzentrum und setzen sich Pixel für Pixel zum QR-Code zusammen. Großtext: **„Dein e-Rezept ist da! Löse es am Automaten ein."** |
| **5. Reward-Screen** | 10–45 s | QR-Code, Punktzahl, Sicherheitsstufe (Bronze/Silber/Gold), ggf. Highscore-Eintrag per Avatar-Icon. Der QR-Code ist **mindestens 10 Sekunden garantiert sichtbar** (wer erst das Handy zückt, wird nicht überrascht); danach kann der rote Knopf den Screen für den nächsten Spieler überspringen. Nach 45 Sekunden automatische Rückkehr zum Attract-Mode. |
| **6. Automat** | 30 s | Der Besucher scannt den QR-Code am Medikamentenautomaten neben der Konsole und erhält seine „Medikation" (Giveaway). Der Moment schließt die Erzählung: Das e-Rezept wurde wirklich eingelöst. |
| **7. Gespräch** | offen | Die Sechs-Icon-Zeile des Weges auf dem Endscreen ist das natürliche Foto-Motiv und der Gesprächseinstieg für das Standpersonal: „Wissen Sie, was das VPN-Siegel bedeutet?" |

## 2.2 Die Hardware

- **Arcade-Konsole** mit Joystick (4 Richtungen), rotem Button (Springen) und blauem Button (Aktion). Keine weiteren Bedienelemente für Besucher.
- **TV-Bildschirm** (1080p oder 4K), Pixel-Art wird integer skaliert (gestochen scharf, siehe Abschnitt 8.5).
- **Standrechner** (Windows) im Chrome-Kiosk-Modus, vollständig offline, Autostart per Batch-Datei.
- **Medikamentenautomat** daneben — nimmt den QR-Code entgegen (Varianten A/B, siehe Abschnitt 8.7).
- Notfall-Bedienung: Eine Tastatur (im Standmöbel verstaut) steuert das Spiel parallel zum Joystick — fällt der USB-Encoder aus, läuft der Betrieb weiter.

## 2.3 Rolle des Standpersonals

- **Anmoderieren, nicht erklären:** Das Spiel erklärt sich selbst (Tutorial-Straße, Blau-Knopf-Vokabular). Das Personal lädt ein („Einmal Ihr e-Rezept abholen?") und fängt den Spieler am Automaten wieder auf.
- **Fachgespräch andocken:** Jedes der sechs Siegel ist ein Gesprächsaufhänger (VSDM, QES, VPN, Signaturprüfung, Zugriffsrechte, Einmal-Einlösung). Die Mapping-Tabelle in Abschnitt 10.2 ist zugleich der Spickzettel für das Standpersonal.
- **Betrieb:** Morgens Konsole einschalten (Autostart), abends ausschalten. Der Tages-Highscore leert sich automatisch. Kalibrierung des Joysticks bei Aufbau über das versteckte F8-Overlay (Abschnitt 8.4).

## 2.4 Warum das funktioniert

- **Niedrigste Einstiegshürde:** Zwei Knöpfe, ein Joystick, kein Menü. Jeder Knopfdruck im Attract startet das Spiel.
- **Garantierter Erfolg:** Kein Game Over, kein Tod, kein Zeit-Abbruch. Assist-System und Express-Zustellung bringen jeden zum QR-Code — der Automat darf niemandem verwehrt bleiben.
- **Zuschauer-Sog:** Der Formwechsel im 30-Sekunden-Takt (horizontal → Röhre → vertikal → Kammer → Sprint) gibt Umstehenden ständig Neues zu sehen; der Highscore erzeugt Rückkehrer.
- **Botschaft im Vorbeigehen:** Selbst wer nie spielt, sieht im Attract-Mode den VPN-Ride und liest „Verschlüsselt kann mich niemand mitlesen!"

---

# 3. Spielkonzept „Paul & REZI — Sicher durch die digitale Stadt"

## 3.1 Story-Rahmen

Pixel-Paul verlässt das Sprechzimmer und hört: **„Ihr e-Rezept ist schon unterwegs — schneller als Sie!"** Vor der Tür wartet REZI: sein frisch erstelltes e-Rezept — ein schwebendes Datenpäckchen mit Knopfaugen und Rezept-Symbol auf dem Bauch, geboren Sekunden zuvor in der Praxissoftware des Arztes. Paul nimmt die Wette an und begleitet REZI durch die Telematikinfrastruktur.

Vor jeder TI-Station in der Stadt steht ein leuchtendes **Daten-Portal**; per blauem Knopf löst sich Paul in Pixel auf und „taucht ab" in die digitale Ebene — Neon auf Dunkelblau, Platinen-Böden, Serverschrank-Türme. Draußen lauern Datenkraken, Lauscher und Fälscher — doch an jeder Station legt die TI REZI einen neuen Schutz an. Am Levelende taucht Paul in der Stadt wieder auf, sichtbar einen Häuserblock weiter Richtung Apotheke.

Am Ende ist REZI das sicherste Päckchen Deutschlands — und genau dann da, wenn Paul ankommt: **Einfach. Sicher. Digital.**

Das **Zwei-Welten-Prinzip** (Stadt → Digital-Dive → Stadt) schließt direkt an die bestehende Standgrafik mit Pixel-Charakter vor Stadtkulisse an und macht die Kernbotschaft körperlich erfahrbar: Hinter jedem realen Schritt arbeitet sichere digitale Infrastruktur.

## 3.2 Figuren

| Figur | Rolle | Beschreibung |
|---|---|---|
| **Pixel-Paul** | Spielbarer Avatar | Identisch mit der Figur der Standgrafik. Läuft (Joystick), duckt sich (Joystick runter), springt (roter Button), führt TI-Aktionen aus (blauer Button). |
| **REZI** | Begleiter & Schutzobjekt | Das e-Rezept selbst. Schwebt voraus, zeigt auf Interaktionspunkte, versteckt sich bei Gefahr hinter Paul, spricht die Lernsätze in Sprechblasen (max. 1 Satz, pausiert das Spiel nie). REZI ist das, was die Angreifer wollen — und was die TI sichtbar schützt. Sein Zustand visualisiert den Fortschritt: Er trägt die gesammelten Siegel sichtbar am Körper. |
| **Dr. Pixel** | NPC (Level 1 + 2) | Der Arzt. Erstellt REZI am PVS-Terminal (Level 1), steckt seinen Heilberufsausweis und signiert mit seinem großen QES-Stempel (Level 2). |
| **Apothekerin Pia** | NPC (Level 6) | Prüft am HV-Tisch die Signatur ein letztes Mal und löst den QR-Payoff aus. |
| **Datenkrake** | Angreifer-Ensemble | Große Tentakel-Kreatur, will REZI greifen — prallt an Toren, Tunneln und der Einmal-Einlösung ab. |
| **Lauscher-Auge** | Angreifer-Ensemble | Schwebende Augenpaare, wollen mitlesen — sehen nach der Verschlüsselung nur noch Störbild-Static. |
| **Skimming-Kralle** | Angreifer (Level 2) | Aufgeklebter Fake-Kartenleser mit Greifarm — wird vom gematik-Zertifikats-Siegel eingeklemmt. |
| **Manipulator-Bot** | Angreifer (Level 4) | Kleine Roboter mit Radiergummi-Köpfen, wollen Siegel überschreiben — das Integritäts-Prüffeld zappt sie in den Quarantäne-Schacht. |
| **Neugier-Geist** | Angreifer (Level 5) | Werbe-Datenkrake mit Blick-Scheinwerfer — sein Licht zeigt auf REZI nur Pixelrauschen. |
| **Glitch-Gremlin** | Angreifer-Reserve | Teil des geteilten Feindes-Sets für zukünftige Stationen (Abschnitt 7). |

Alle Angreifer teilen dasselbe Verhalten: *Sie wollen Daten abgreifen und scheitern sichtbar an der Stationsmechanik.*

## 3.3 Steuerungsvokabular

Das gesamte Spiel kommt mit einem Joystick und zwei Buttons aus. Jede Eingabe wird genau einmal eingeführt und danach konsequent gleich verwendet:

| Eingabe | Wirkung | Wird gelernt in |
|---|---|---|
| Joystick links/rechts | Laufen | Level 1, Tutorial-Straße |
| **Roter Button** | Springen | Level 1, Tutorial-Straße |
| **Blauer Button** | TI-Aktion (prüfen lassen, verschlüsseln, freigeben, entscheiden) | Level 1, Aktualisierungs-Terminal |
| Joystick runter | Ducken | Level 2, Skimming-Kralle |
| Joystick hoch/runter | Steigen/Sinken (im Auto-Scroll-Tunnel) | Level 3, VPN-Ride |
| Joystick loslassen | Stillstehen (Prüf-Podest) | Level 3, Firewall-Tore |
| Joystick + Blau | Auswahl bestätigen | Level 5 (Apothekenwahl), Highscore-Avatar |

**Der blaue Button ist immer die Sicherheitsaktion.** Das lernt der Besucher in Level 1 und wendet es danach intuitiv an.

## 3.4 Markenregeln (Styleguide, unverhandelbar)

Diese Regeln sichern die Auftraggeber-Botschaft in jeder Spielsekunde ab. Sie gelten für alle bestehenden und zukünftigen Level und sind Prüfkriterien im Fachreview:

1. **Es wird nie gekämpft.** Paul hat keine Waffe, keinen Stampf-Angriff, keine Offensive. Angreifer scheitern immer sichtbar und komisch an einer TI-Funktion — mit **„ZUGRIFF VERWEIGERT"**-Stempel und Comic-Sternen. Die TI gewinnt für den Spieler.
2. **Blau-Regel:** Der blaue Button bedeutet immer *„Der Spieler beauftragt die TI — die TI führt aus."* Der Spieler verschlüsselt nicht selbst, er löst die Verschlüsselung aus. Nicht Geschicklichkeit schützt die Daten, sondern die Architektur.
3. **Ein Fehlversuch ist nie ein Datenleck.** Misslingt eine Interaktion, zeigt das Spiel „Prüfung wiederholen" (rotes Blinken + X-Symbol) — niemals „Daten gestohlen", niemals ein Sicherheitsversagen. Sicherheit ist im Spiel kein Skill-Check, sondern Systemeigenschaft.
4. **In geschützten Zonen gibt es keine Schadensquellen.** Im VPN-Tunnel und überall, wo der TI-Schutz aktiv ist, kann dem Spieler nichts passieren — Angreifer hämmern wirkungslos gegen das Glas. Die Botschaft „im Tunnel bist du unantastbar" wird nie durch eine Spielmechanik dementiert (vollständiges Schadensmodell: Abschnitt 5.2).
5. **Show, don't tell.** Der Hauptlernkanal ist der wiederkehrende Gag *Angreifer versucht etwas → eine TI-Funktion blockt ihn sichtbar → „ZUGRIFF VERWEIGERT"*. Nach drei Leveln antizipiert der Spieler den Gag — das ist gelerntes Systemvertrauen. Text ist Zweitkanal: pro Level genau eine Kernbotschaft an genau drei Stellen (Lern-Dreiklang, Abschnitt 4), immer maximal ein Satz. NPCs sprechen maximal drei Wörter + Icon; nie Fließtext während des Spielens.
6. **Barrierefreiheit ist Designregel, nicht Nachrüstung:** keine Blitzeffekte über 3 Hz; Farbe ist nie alleiniger Informationsträger (immer zusätzlich Form/Symbol); das Spiel ist ohne Ton vollständig verständlich; alle Texte sind auf Zuschauer-Distanz lesbar (Details: Abschnitt 9.2).
7. **Fachliche Leitplanken:** Die neun fachlichen No-Gos (Abschnitt 10.5) sind bindend — insbesondere: Das Rezept liegt nie auf der Karte, reist nie offen durchs Netz, und kein Angreifer hat je ein Erfolgserlebnis.

---

# 4. Die sechs Level im Detail

Jedes Level folgt demselben Rhythmus: **Stadt → Portal-Dive → digitale Ebene (20–30 s) → Auftauch-Stempel → Stadt.** Die Stadt-Zwischenläufe sind auf maximal 5 Sekunden gedeckelt und per rotem Knopf überspringbar.

**Der Lern-Dreiklang** — pro Level genau eine Kernbotschaft an genau drei Stellen:

1. **Portal-Einblendung** (2 s beim Abtauchen, Stationsname groß) — verankert die Station der Standgrafik.
2. **REZI-Sprechblase im Spielmoment** (pausiert nie): erklärt immer etwas, das der Spieler 2 Sekunden vorher selbst getan hat — *erst erleben, dann benennen*.
3. **Auftauch-Stempel** (1 s zurück in der Stadt, Siegel fliegt in die HUD-Leiste), plus **Fachbegriff-Chip**: 2 s erscheint der Fachbegriff als Badge (VSDM, QES, VPN …) — wer es sich merken will, merkt es; wer nicht, spielt weiter.

Überblick:

| # | Station | Untertitel | Dauer | Silhouette | Siegel | Badge |
|---|---|---|---|---|---|---|
| 1 | Versichertenstammdaten | „Der Daten-Check" | ~25 s | Horizontal | Karten-Häkchen | VSDM |
| 2 | Kartenterminal | „Identität & Unterschrift" | ~30 s | Horizontal (Innenwelt) | Goldenes Signatur-Siegel | eHBA · QES |
| 3 | KOV Gateway¹ | „Das Tor zur TI" | ~30 s | Röhre | Schutzblasen-Siegel | VPN · E2E-Verschlüsselung |
| 4 | e-Rezept Fachdienst | „Das Hochsicherheits-Rechenzentrum" | ~30 s | **Vertikal** | Prüfstrahl-Siegel | Signaturprüfung |
| 5 | e-Rezept Akte¹ | „Deine Daten, deine Entscheidung" | ~25 s | Kammer | Schlüssel-Siegel | Zugriffsrechte |
| 6 | Apotheke | „Die Einlösung" | ~30 s | Sprint (Stadt) | Einlöse-Siegel | Einmal einlösbar |

¹ Die Stationsnamen „KOV Gateway" und „e-Rezept Akte" übernehmen bewusst die Beschriftung der bestehenden Standgrafik, damit Bildschirm und Stand dieselbe Sprache sprechen. Zur fachlichen Empfehlung an PwC/gematik siehe den Hinweiskasten in Abschnitt 10.3.

---

## Level 1 — Versichertenstammdaten *(„Der Daten-Check")* — ca. 25 s, Tutorial

| | |
|---|---|
| **Silhouette / cameraMode** | Horizontal |
| **Intensität** | 1/5 — Tutorial in Bewegung |
| **Gegner** | keine |
| **Schadensquellen** | keine (Tutorial ist straffrei) |
| **Siegel / Badge** | Karten-Häkchen / „VSDM" |

**Thema:** Start in der Stadt vor der Arztpraxis. Eine 5-Sekunden-Tutorial-Straße bringt Laufen und Springen bei (Gehwegkante, Blumenkübel). Am Empfangstresen steckt Paul seine elektronische Gesundheitskarte — kurze Animation, dann leuchtet das Daten-Portal im Wartezimmer. Die digitale Ebene: eine riesige, aufgeklappte Gesundheitskarte als begehbare Landschaft — der goldene Chip als Hügelkette, Datenfelder als Plattformen, rotierende Karteikarten im Hintergrund. Wichtig für das Bild: Die Karte ist die **Prüfwelt**, nicht die Rezeptquelle — das Rezept entsteht erst am Ende des Levels beim Arzt.

**Mechaniken:**

1. *Daten-Kacheln prüfen:* Drei leuchtende Daten-Kacheln (Name, Versichertennummer, Versichertenstatus — als Icons, nie als Klartext) müssen erhüpft werden; jede füllt die Prüf-Leiste am oberen Bildrand. Das Exit-Portal öffnet erst bei 3/3 — ein unvollständiger Datensatz verlässt die Prüfung nicht.
2. *Veraltete-Daten-Kacheln:* Grau flackernde Duplikate (sanftes Pulsieren unter 3 Hz, mit Riss-Symbol) liegen dazwischen; Berührung = kurzes „Brrzzt", die Kachel zerplatzt mit „VERALTET"-Stempel — folgenlos, reiner Lerneffekt. Am **Aktualisierungs-Terminal** tauscht der blaue Knopf sie gegen frische grüne Kacheln mit Häkchen-Symbol: die erste Blau-Knopf-Übung — der Spieler beauftragt, die TI aktualisiert.
3. *REZIs Geburt am PVS-Terminal (Setpiece, Levelausgang):* Bei 3/3 leuchtet groß **„DATEN VOLLSTÄNDIG & AKTUELL"** auf. Der Ausgang führt aus der Kartenlandschaft hinauf auf Dr. Pixels Schreibtisch: das Praxisverwaltungssystem. Dr. Pixel tippt, auf dem Monitor setzt sich Pixel für Pixel ein Datenpäckchen zusammen — Blau drücken, und **REZI hüpft mit Knopfaugen aus dem Bildschirm**. Das e-Rezept ist geboren — als strukturierter Datensatz in der Praxissoftware des Arztes, nicht auf der Karte.

**Fachbezug:** Versichertenstammdaten-Management (VSDM): Beim Praxisbesuch wird die eGK online bei der Krankenkasse geprüft — ist die Karte gültig, sind die Stammdaten aktuell? Erst auf dieser Grundlage erstellt der Arzt das e-Rezept digital im PVS. Die eGK ist der Schlüssel des Versicherten; das Rezept selbst entsteht und bleibt in der digitalen Infrastruktur.

**Lern-Dreiklang:**

> **Portal:** „Station 1: Versichertenstammdaten — deine Karte wird online geprüft."
> **REZI (bei seiner Geburt):** „Deine Daten stimmen — deshalb gibt es mich jetzt!"
> **Auftauch-Stempel:** „✓ Daten vollständig & aktuell." *(Badge „VSDM")*

---

## Level 2 — Kartenterminal *(„Identität & Unterschrift")* — ca. 30 s

| | |
|---|---|
| **Silhouette / cameraMode** | Horizontal (Geräte-Innenwelt) |
| **Intensität** | 2/5 — erster „Ich kann das!"-Moment |
| **Gegner** | Skimming-Kralle (erster „ZUGRIFF VERWEIGERT"-Gag) |
| **Schadensquellen** | Rempler an Kontaktfedern und Kralle = Datenbit-Verlust |
| **Siegel / Badge** | Goldenes Signatur-Siegel / „eHBA", „QES" |

**Thema:** Paul springt in den Kartenschlitz des eHealth-Kartenterminals. Innenwelt des Lesegeräts: Kontaktfedern als Trampoline, Leiterbahnen als Laufwege, goldene Kontaktpads als leuchtende Plattformen, oben pulsiert ein Terminal-Display.

**Mechaniken:**

1. *Kontakt-Rhythmus:* Das Terminal „taktet" — Kontaktfedern schnellen im Rhythmus hoch, Timing-Sprünge darüber. Klassisches Arcade-Gefühl, sofort verständlich.
2. *Die Skimming-Kralle:* Eine schmierige mechanische Kralle (ein aufgeklebter Fake-Kartenleser) greift zweimal durch einen Spalt — **Ducken** (Joystick runter, die dritte Eingabe wird hier gelernt) lässt sie ins Leere greifen. Payoff: Das **gematik-Zertifikats-Siegel** fährt als Blende herunter und klemmt die Kralle ein — „ZUGELASSENE HARDWARE ONLY", der erste „ZUGRIFF VERWEIGERT"-Gag. Nur zertifizierte, zugelassene Geräte dürfen in die TI.
3. *Die Arzt-PIN-Schleuse:* Am Terminal-Display erscheint **Dr. Pixel und steckt seinen elektronischen Heilberufsausweis (eHBA)**. Vier Prüffelder pulsieren nacheinander auf (grün gefüllter Kreis; bei Fehlversuch rotes X — Farbe nie allein, immer mit Symbol); der blaue Knopf bestätigt viermal im richtigen Moment den Prüfimpuls des Terminals. Das Framing ist eindeutig: **Dr. Pixel gibt seine Arzt-PIN ein** — der Spieler beauftragt das Terminal, die Prüfung laufen zu lassen. Keine echte PIN, keine Ziffern, kein Zahlenwissen. Fehlversuch: rotes Blinken + X, „PRÜFUNG WIEDERHOLEN", die Sequenz startet langsamer neu — nie als Leck oder Versagen inszeniert.
4. *Der Signatur-Stempel (Setpiece, Levelausgang):* Nach der PIN-Prüfung fährt Dr. Pixels großer **QES-Stempel** rhythmisch auf und ab. Timing-Sprung auf das Podest darunter, Blau zum „Annehmen" — **WUMM**, REZI trägt ein goldenes Siegel, Funkenregen. Verpasster Takt: einfach auf den nächsten Hub warten, keine Strafe. Die qualifizierte elektronische Signatur ist der Echtheitsbeweis, den am Ende die Apotheke prüft — ohne sie gibt es kein gültiges Rezept.

**Fachbezug:** Zwei Faktoren — Besitz und Wissen: Der Arzt signiert das e-Rezept mit seinem eHBA **und** dessen PIN (qualifizierte elektronische Signatur, rechtlich der Unterschrift auf Papier gleichgestellt). Der Patient braucht beim Stecken seiner eGK keine PIN — die Karte weist ihn aus. Und: Nur von der gematik zugelassene, zertifizierte Hardware darf Teil der TI sein.

**Lern-Dreiklang:**

> **Portal:** „Station 2: Kartenterminal — Identität geprüft, Rezept unterschrieben."
> **REZI (nach dem Stempel):** „Dr. Pixels digitale Unterschrift macht mich echt!"
> **Auftauch-Stempel:** „✓ Vom Arzt digital signiert." *(Badges „eHBA", „QES")*

---

## Level 3 — KOV Gateway *(„Das Tor zur TI")* — ca. 30 s, erster Adrenalin-Spike

| | |
|---|---|
| **Silhouette / cameraMode** | Röhre (mit Auto-Scroll-Finale) |
| **Intensität** | 4/5 — kognitiver Höhepunkt |
| **Gegner** | Datenkrake, Lauscher-Augen |
| **Schadensquellen** | Nur im Vorfeld (offenes Internet): Tentakel-Schläge = Datenbit-Verlust. **Ab der Verschlüsselungs-Dusche und in der VPN-Röhre: keine.** |
| **Siegel / Badge** | Schutzblasen-Siegel / „VPN", „E2E-Verschlüsselung" |

**Thema:** Harter Kontrast: Die Stadt wird am Portal dunkel und verregnet — Neon-Schatten, in denen Datenkraken-Tentakel und Lauscher-Augenpaare lauern („offenes Internet"). Dahinter das hell leuchtende Gateway-Tor in einer massiven Mauer, dann der VPN-Tunnel.

**Mechaniken:**

1. *Firewall-Tore mit Prüf-Podest:* Drei Scanner-Tore; der Spieler muss auf dem Podest kurz **stillstehen** (Joystick loslassen — ungewohnt, dadurch einprägsam), ein Scan-Balken läuft durch, das Tor öffnet. Wer durchrennt, prallt ab. Der Clou: Die hinter Paul herschleichende Datenkrake bekommt das Tor *jedes Mal* vor die Nase geknallt — „ZUGRIFF VERWEIGERT", Comic-Sterne. Nur geprüfte Teilnehmer kommen in die TI.
2. *Die Verschlüsselungs-Dusche:* An der Krypto-Station verwandelt der blaue Knopf REZI (und Paul) sichtbar in wirbelndes Zeichensalat-Pixelrauschen mit schimmernder Schutzblase — der Spieler beauftragt, die TI verschlüsselt. Ab jetzt zeigen die Sprechblasen aller Lauscher-Augen nur noch Störbild-Static: *Sie können dich sehen, aber nicht lesen.* Noch unverschlüsselte, matte Röhrenabschnitte saugen einen sanft zur letzten Station zurück — ohne Verschlüsselung geht es hier nicht weiter (kein Schaden, nur Rücksetzer).
3. *Der VPN-Röhren-Ride:* Auto-Scroll-Finale durch eine gläserne Leucht-Röhre — der schnellste, spektakulärste Moment des Spiels und das Motiv der Attract-Demo. Joystick hoch/runter steuert Steigen und Sinken, drei Bahnen voller Datenbits laden zum Sammeln ein. Draußen hämmern Kraken-Tentakel **wirkungslos** gegen das Glas — im Tunnel gibt es keinerlei Schadensquellen. Botschaft ohne ein Wort: **Im Tunnel bist du unantastbar.**

**Fachbezug:** Zugangskontrolle zur TI und verschlüsselter Transport: Der Übergang vom Praxisnetz in die Telematikinfrastruktur läuft über einen gesicherten Netzzugang mit VPN-Tunnel. Nur registrierte, mit Institutionskarte (SMC-B) ausgewiesene Einrichtungen kommen hinein; mitlesen kann niemand — Ende-zu-Ende-Verschlüsselung.

**Lern-Dreiklang:**

> **Portal:** „Station 3: KOV Gateway — dein sicherer Tunnel in die TI."
> **REZI (im Ride):** „Verschlüsselt kann mich niemand mitlesen!"
> **Auftauch-Stempel:** „✓ Verschlüsselt unterwegs." *(Badges „VPN", „E2E-Verschlüsselung")*

---

## Level 4 — e-Rezept Fachdienst *(„Das Hochsicherheits-Rechenzentrum")* — ca. 30 s, spielerischer Gipfel

| | |
|---|---|
| **Silhouette / cameraMode** | **Vertikal** — Serverturm von unten nach oben |
| **Intensität** | 5/5 — Geschicklichkeits-Peak |
| **Gegner** | Manipulator-Bots, Fake-Rezept (Requisite) |
| **Schadensquellen** | **Keine** — der Fachdienst ist geschützte Zone; die TI ist hier der sicherste Ort des Spiels. Lüfterblätter setzen auf die letzte Plattform zurück (Zeitverlust, kein Bit-Verlust); Bots werden vom Prüffeld gezappt, bevor sie etwas anrichten. Die Herausforderung ist Präzision, nicht Gefahr. |
| **Siegel / Badge** | Prüfstrahl-Siegel / „Signaturprüfung" |

**Thema:** Vertikal statt horizontal: ein Serverturm von unten nach oben — Server-Racks als Plattform-Etagen, Lüfter als Aufwind-Schächte, Kabelstränge, LEDs blinken im Takt der Musik, kühles Blaugrün — die „Kathedrale der TI".

**Mechaniken:**

1. *Rack-Kletterei:* Bewegliche Lastverteiler-Plattformen (Load Balancer) tragen Datenpakete in Bahnen nach oben; dazu Lüfter-Aufwinde mit rotierenden Blättern als Timing-Hindernis — die anspruchsvollste Plattform-Passage des Spiels.
2. *Manipulator-Bots:* Kleine Roboter mit Radiergummi-Köpfen wollen REZIs Siegel überschreiben. **Es wird nicht gestampft:** Der Spieler weicht aus oder duckt sich — und das Integritäts-Prüffeld der Etage zappt jeden Bot, der REZI zu nahe kommt, in den Quarantäne-Schacht („ZUGRIFF VERWEIGERT"-Gag Nr. 3: das System prüft, nicht der Spieler kämpft).
3. *Der Signatur-Scanner (Setpiece):* Auf halber Höhe ein Prüfstrahl, den alle Pakete passieren müssen. Neben REZI wartet ein **Fake-Rezept** — gleiche Form, aber schiefes, bröckelndes Siegel. Blauer Knopf im Strahl: REZIs goldenes Arzt-Siegel aus Level 2 leuchtet auf — **„SIGNATUR GÜLTIG"**, das Tor öffnet; das Fake-Rezept wird von einer Greifer-Klaue sanft aussortiert. Gefälschtes kommt nicht durch.
4. *Einbuchung:* Ganz oben springt REZI in seinen leuchtenden Speicher-Slot — Einrast-Feedback, und er erhält das **Rezept-Token** (glitzernder Schlüssel-Pixel, sichtbar im HUD): der Abholcode, aus dem am Ende der QR-Code wird. Das Rezept bleibt im Tresor — der Schlüssel geht mit.

**Fachbezug:** Der zentrale e-Rezept-Fachdienst prüft jede Signatur und die Unversehrtheit des Rezepts, speichert es verschlüsselt (Verarbeitung in der vertrauenswürdigen Ausführungsumgebung — selbst der Serverbetreiber kann nicht mitlesen) und vergibt den Zugriffs-Token. Das Rezept liegt **nicht** auf der eGK und nicht auf dem Handy — dort liegt nur der Schlüssel.

**Lern-Dreiklang:**

> **Portal:** „Station 4: e-Rezept Fachdienst — der sichere Speicher."
> **REZI (nach dem Scanner):** „Meine Signatur? Gültig!"
> **Auftauch-Stempel:** „✓ Geprüft und sicher gespeichert." *(Badge „Signaturprüfung")*

---

## Level 5 — e-Rezept Akte *(„Deine Daten, deine Entscheidung")* — ca. 25 s, bewusste Verschnaufpause

| | |
|---|---|
| **Silhouette / cameraMode** | Kammer |
| **Intensität** | 2/5 — Entscheidungs- statt Reaktionsdruck |
| **Gegner** | Neugier-Geist, Fragezeichen-Gestalt (an der Tür) |
| **Schadensquellen** | Keine — ruhiges Puzzle-Level; der Blick-Scheinwerfer „erwischt" nie etwas Lesbares |
| **Siegel / Badge** | Schlüssel-Siegel / „Zugriffsrechte" |

**Thema:** Ruhiger Kontrast nach dem Turm: eine warme Tresor-Bibliothek — Regale voller verschlossener Akten-Schubladen, sanftes Licht, Pauls eigene Akte leuchtet golden; im Hintergrund ein smartphone-großes Fenster mit der e-Rezept-App-Ansicht. Die Musik wird weicher.

**Mechaniken:**

1. *Rechte-Türen mit Gesichtern:* Türen tragen Icons (Arzt, Apotheke, zwielichtige Fragezeichen-Gestalt). Der blaue Knopf am Freigabe-Hebel öffnet nur Türen, bei denen REZIs Token aufleuchtet. Bei der Fragezeichen-Gestalt: Warnton + rotes X-Schild, die Tür knallt zu, REZI schüttelt den Kopf — *nur Berechtigte kommen an das Rezept*, egal wie oft man springt oder drückt.
2. *Der Neugier-Geist:* Ein schwebender Werbe-Datenkrake mit Blick-Scheinwerfer patrouilliert (Duck-/Timing-Passage). Pointe: Sein Lichtkegel trifft REZI — und zeigt nur Pixelrauschen. Die Verschlüsselung aus Level 3 wirkt fort; er zieht frustriert ab. Selbst bei „Entdeckung" wird nie etwas gelesen.
3. *Die Weichen-Entscheidung (Levelende):* Der Weg gabelt sich vor zwei Apotheken-Schildern („Stadt-Apotheke" / „Bären-Apotheke"). Joystick links/rechts + Blau = Wahl. Spielerisch folgenlos, inhaltlich der wichtigste Moment des Spiels: **DU entscheidest, wer dein Rezept einlösen darf.**

**Fachbezug:** Zugriffsrechte und Patientensouveränität: Der Versicherte allein steuert, wer seine Daten sieht und wo er einlöst — freie Apothekenwahl, Berechtigungssteuerung, Widerspruchsrechte. Niemand außer den Autorisierten sieht das Rezept.

**Lern-Dreiklang:**

> **Portal:** „Station 5: e-Rezept Akte — dein Daten-Safe."
> **REZI (nach der Tür-Szene):** „Nur DU entscheidest, wer mich sieht!"
> **Auftauch-Stempel:** „✓ Zugriff nur für Berechtigte." *(Badge „Zugriffsrechte")*

---

## Level 6 — Apotheke *(„Die Einlösung")* — ca. 30 s, Finale mit Payoff

| | |
|---|---|
| **Silhouette / cameraMode** | Sprint (Stadt, kein Dive mehr) |
| **Intensität** | 4/5 → Triumph |
| **Gegner** | Datenkrake (Fake-Boss mit Twist) |
| **Schadensquellen** | Stadt-Hindernisse = Stolperer (Datenbit-Verlust), fair gesetzt — der Sprint ist fast nicht verlierbar |
| **Siegel / Badge** | Einlöse-Siegel / „Einmal einlösbar" |

**Thema:** Auftauchen aus dem letzten Portal — bewusst **kein Dive mehr**: Die digitale Reise ist geschafft, jetzt zählt die reale Welt. Abendlicht, die in Level 5 gewählte Apotheke mit leuchtendem rotem A am Ende der Straße, Konfetti-Bits regnen, Apothekerin Pia am HV-Tisch.

**Mechaniken:**

1. *Zielsprint:* 15 Sekunden schneller, rhythmischer Lauf über Stadt-Hindernisse (Mülltonnen, Lieferrad) und Pillendosen-Stapel vor der Apotheke — Tempo hoch, Musik zieht an, faire Hindernisse, fast nicht verlierbar: Jeder endet auf einem Hoch.
2. *Der Rezept-Dieb (Fake-Boss-Twist):* An der Apothekentür schnappt eine letzte, große Datenkrake zu — und erwischt REZI scheinbar! Schrecksekunde — dann der Twist: Sie hält nur eine flackernde **Kopie**, die sofort mit **„UNGÜLTIG — BEREITS RESERVIERT"** zerbröselt, während der echte REZI weiterschwebt. Kein Kampf, kein Skill-Check: Die TI gewinnt diesen Moment für den Spieler. Gestohlene Kopien sind wertlos.
3. *Der Scan-Moment:* Finaler Sprung an den HV-Tisch, Blau drücken: Pia prüft die Signatur ein letztes Mal („GÜLTIG") — dann fliegen alle sechs gesammelten Siegel aus der HUD-Leiste ins Bildschirmzentrum und setzen sich Pixel für Pixel zum **echten QR-/Abholcode** zusammen. Großtext: „Dein e-Rezept ist da! Löse es am Automaten ein." Darunter die Sechs-Icon-Zeile des gesamten Wegs — das Foto-Motiv für Besucher.

**Fachbezug:** Die Apotheke ruft das signierte Original nur mit Autorisierung (Token/eGK) und eigener Institutionskarte sicher vom Fachdienst ab und prüft die Arztsignatur erneut; nach der Abgabe markiert der Fachdienst das Rezept als eingelöst — jedes e-Rezept ist nur einmal einlösbar.

**Lern-Dreiklang:**

> **REZI (nach dem Twist):** „Mich gibt's nur einmal — Kopien sind wertlos!"
> **Finaler Stempel:** „✓ Sicher eingelöst. Einfach. Sicher. Digital." *(Badge „Einmal einlösbar")*

---

# 5. Durchgängige Systeme

## 5.1 Sammelobjekte — zwei Ebenen

**Datenbits** (türkise Funken, ca. 20–40 pro Level) sind das „Münzen"-Äquivalent: Sie liegen auf dem Ideal-Pfad und lotsen unauffällig durchs Level; Nebenpfade belohnen Mutige. Der Levelausgang verlangt eine konfigurierbare Mindestzahl (`countRequired`).

**Sicherheits-Siegel** (genau eines pro Level, an die Kernmechanik gekoppelt, nicht verpassbar): Signatur → Identität → Verschlüsselung → Gültigkeit → Zugriffsrecht → Einlösung. Das HUD zeigt sie als **TI-Streckenkarte** — identisch zur Stationsgrafik am Messestand. Die Siegel-Icons sind zugleich **Fragmente des QR-Rahmens**, der sich im Finale zum echten Abholcode zusammensetzt: Die Meta-Progression IST die Belohnung und erklärt nebenbei, woraus ein sicheres e-Rezept „besteht". REZI trägt die gesammelten Siegel sichtbar am Körper.

## 5.2 Schadensmodell (einheitlich, messetauglich)

- **Kein Tod, keine Leben, keine Abgründe.** Wer fällt, landet auf einer tieferen Ebene.
- Treffer = Datenbits spritzen weg (Sonic-Prinzip: tut kurz weh, frustriert nie), kurzes Blinken, weiter.
- Checkpoints alle ~8 Sekunden Spielzeit, Respawn in 2–3 Sekunden.
- **In geschützten Zonen (VPN-Tunnel, hinter Verschlüsselung) gibt es KEINE Schadensquellen** — dort ist man unantastbar. Das ist fachliche Botschaft, kein Balancing-Detail.

## 5.3 Assist-Eskalation („TI-Schutzschild")

Scheitert eine Sicherheits-Interaktion wiederholt, hilft das System sichtbar — Framing immer: *„Die TI sichert dich zusätzlich ab"*, nie „du bist schlecht":

| Stufe | Auslöser | Wirkung |
|---|---|---|
| 1 | 1. Fehlversuch | Zeitfenster/Sequenz wird sichtbar langsamer (×1,3) |
| 2 | 2. Fehlversuch | Weitere Verlangsamung (×1,6) |
| 3 (Ausbaustufe) | 3. Fehlversuch | Leuchtender „TI-Schutzschild", REZI löst die Stelle halb mit |

**Soft-Autopilot:** Ab 4:00 Minuten trägt der „Express-Tunnel" Paul und REZI im Autopilot bis zum QR-Code („Express-Zustellung"). **Es gibt keinen harten Abbruch vor dem QR-Code** — der Automat darf niemandem verwehrt bleiben; Könner kommen schneller und punktereicher durch.

## 5.4 Punktesystem und Tages-Highscore

- Datenbit ×10 · Siegel ×1.000 · **Sicherheits-Bonus** ×250 pro fehlerfreier Interaktion · Unversehrt-/Tempo-Boni.
- Endscreen-Rang als **Sicherheitsstufe**: Bronze „Gut geschützt" / Silber „Stark verschlüsselt" / Gold „TI-zertifiziert".
- **Tages-Highscore Top 5:** Eintrag über eines von 12 Pixel-Avatar-Icons (Joystick wählt, Blau bestätigt) — arcade-schnell, **keine Namenseingabe, kein Personenbezug**. Persistenz: localStorage mit automatischem Tages-Wipe.

## 5.5 Attract-Mode

Läuft niemand, zeigt der Bildschirm rotierend: Titel mit Paul & REZI, „Drück den roten Knopf!"-Blinken (deutlich unter 3 Hz), Tages-Top-5 und Steuerungslegende. **Ausbaustufe:** Auto-Play-Demo von Level 3 (Verschlüsselungs-Verwandlung + VPN-Ride — der visuell stärkste Moment) mit rotierenden Merksätzen; die Demo läuft als aufgezeichnete, deterministische Eingabesequenz.

## 5.6 Lernvermittlung — der Dreiklang

Pro Level genau EINE Kernbotschaft an genau drei Stellen, immer max. 1 Satz, das Spiel pausiert nie:

1. **Portal-Einblendung** (2 s beim Abtauchen, Stationsname groß) — verankert die Station der Standgrafik.
2. **REZI-Sprechblase im Spielmoment** — erklärt immer etwas, das der Spieler 2 Sekunden vorher selbst getan hat: *erst erleben, dann benennen*.
3. **Auftauch-Stempel** (1–2 s in der Stadt, Siegel fliegt in die Leiste).

Dazu **Fachbegriff-Chips** (2-Sekunden-Badges: eGK, eHBA, QES, VPN, E2E) — wer's merken will, merkt's; wer nicht, spielt weiter. Hauptkanal bleibt *Show, don't tell*: der wiederkehrende Gag „Angreifer versucht etwas → eine TI-Funktion blockt ihn sichtbar und komisch → ZUGRIFF VERWEIGERT". Nach drei Leveln antizipiert der Spieler den Gag — das ist gelerntes Systemvertrauen.

---

# 6. Spannungskurve und Dramaturgie

Die Kurve lebt von **Mechanik- und Formwechsel statt Schwierigkeits-Grind** — kein Level fühlt sich an wie das vorige; zwei ansteigende Wellen statt einer Rampe:

| Level | Silhouette | Intensität | Mechanik-Typ | Dramaturgische Funktion |
|---|---|---|---|---|
| 1 Versichertenstammdaten | Horizontal | 1/5 | Sammeln + 1× Blau | Tutorial in Bewegung, REZI „entsteht" am PVS |
| 2 Kartenterminal | Horizontal (Innenwelt) | 2/5 | Timing/Rhythmus + Signatur-Setpiece | „Ich kann das!", erster Deny-Gag, QES-Moment |
| 3 KOV Gateway | Röhre | 4/5 | Neue Regel (verschlüsselt/sichtbar) + Speed-Ride | Bedrohung wird real — und der Schutz auch |
| 4 e-Rezept Fachdienst | **Vertikal** | 5/5 | Plattform-Skill + Prüf-Setpiece | Geschicklichkeits-Peak, „das System prüft alles" |
| 5 e-Rezept Akte | Kammer | 2/5 | Puzzle/Entscheidung | Durchatmen; Entscheidungs- statt Reaktionsdruck |
| 6 Apotheke | Sprint (Stadt) | 4/5 → Triumph | Sprint + Twist + Payoff | Jubel-Zieleinlauf, QR-Fanfare |

Die **emotionale Zweitkurve** des Bedrohungsgefühls: „die Welt ist freundlich" (L1–2) → „draußen ist es gefährlich, aber ich werde geschützt" (L3) → „das System prüft alles" (L4) → „ich habe die Kontrolle" (L5) → „selbst Diebstahl ist zwecklos" (L6). Das ist die Auftraggeber-Botschaft als Gefühl statt als Text. Der Formwechsel im 30-Sekunden-Takt gibt auch Zuschauern ständig Neues zu sehen — Zuschauer sind die nächsten Spieler.

---

# 7. Anpassbarkeit: Die Level-Schablone („Digital-Dive-Baukasten")

Jedes Stationslevel ist eine Instanz derselben Schablone mit **sieben austauschbaren Bausteinen** — neue Messe, neue Stationsliste, gleiche Engine. Die Stadt ist ein durchlaufendes Band; Stationen werden als Gebäude neu aufgereiht (4–8 Stationen möglich, Soft-Timer skaliert mit):

1. **Stadt-Anker:** Fassade in der Stadt-Ebene + Portal-Position (`cityAnchor`)
2. **Themen-Skin:** Farbwelt + Tileset (`theme` → `themes.json`)
3. **Level-Silhouette:** Horizontal / Vertikal / Röhre / Kammer / Sprint (`cameraMode`). Planungsregeln: nie zweimal dieselbe Form hintereinander; Position 1 = Tutorial (Horizontal); letzte Position = Sprint + Payoff; Peak „Vertikal" auf Position n−2
4. **Sicherheits-Mechanik-Modul** — das Herzstück, Leitfrage *„Was schützt hier meine Daten?"*:

| Modul | Spielprinzip | Passt zu |
|---|---|---|
| Vervollständigen | Objekte sammeln bis Ausgang öffnet | Stammdaten, Medikationsliste |
| Timing-Gate | Rhythmus-/Sequenz-Passage (blauer Knopf im Takt) | PIN/Signatur, Login, 2-Faktor |
| Tunnel-Ride | Geschützter Auto-Scroll | VPN, KIM-Versand |
| Prüf-Scanner | Setpiece: Echtes passiert, Fake wird aussortiert | Signaturprüfung, Virenscan |
| Rechte-Türen + Wahl | Schlüssel-Puzzle + Spielerentscheidung | ePA-Zugriffe, Einwilligungen |
| Finale-Sprint + Entwertung | Tempo + Kopie-Twist + Payoff | jede Endstation |

5. **Gegner-Skin** aus dem geteilten Feindes-Set (Datenkrake, Lauscher-Auge, Manipulator-Bot, Neugier-Geist, Glitch-Gremlin): Alle teilen dasselbe Verhalten — *sie wollen Daten abgreifen und scheitern sichtbar an der Stationsmechanik.*
6. **Stations-Siegel:** Icon + Slot in der Streckenkarte + QR-Fragment (`siegelIcon`)
7. **Drei Lernsätze:** Portal-/REZI-/Stempel-Satz — reine Textdaten (`portalText`, `reziText`, `stampText`)

**Beispiel-Rezepturen für neue Stationen:**

- **ePA:** Krankenhaus → Skin „Akten-Archiv" → Kammer → *Rechte-Türen + Wahl* → Neugier-Geist → „Du bestimmst, wer deine Akte liest."
- **KIM:** Praxis/Postamt → Skin „Rohrpost-Netz" → Röhre → *Tunnel-Ride* (REZI als versiegelter Briefumschlag) → „KIM verschickt Arztbriefe verschlüsselt von Praxis zu Praxis."
- **Krankenkassen-App / GesundheitsID:** Krankenkasse → Skin „Smartphone-Innenwelt" → Horizontal → *Timing-Gate* → „Zwei Faktoren, doppelt sicher."

**Fester Rahmen jeder Variante:** Stadt-Band, Paul + REZI, Portal-Dive, Bits, Siegel-Leiste, Punktesystem, Assist, Attract-Mode und das Finale (Sprint + Kopie-Twist + QR für den Automaten) bleiben identisch.

---

# 8. Technische Architektur

## 8.1 Tech-Stack

**Phaser 3 (≥3.90) + TypeScript + Vite** — ausgereiftestes Web-2D-Framework mit Arcade-Physik, nativem Tiled-Import, Kamera-System und Gamepad-/Keyboard-API; TypeScript sichert die Datenschemata zur Compile-Zeit, Vite produziert einen vollständig statischen, **offline-fähigen** Build. Ergänzt um `zod` (Laufzeit-Validierung der Redaktions-JSONs mit lesbaren Fehlermeldungen), `qrcode` (Offline-QR auf Canvas) und den Tiled Map Editor (kostenlos) für Geometrie. Verworfen: Kaplay/Kaboom (instabile API-Historie), Godot-HTML5 (>30 MB, COOP/COEP-Header, Szenen statt JSON), Vanilla Canvas (unnötiges Eigenbau-Risiko).

## 8.2 Datengetriebene Drei-Schichten-Trennung

Redakteur:innen editieren in `public/` **ohne Rebuild** (Datei speichern, F5):

1. **`config/game-config.json`** — die „Playlist": `levelOrder`, Titeltexte, `idleResetSeconds`, `ending`. Diese eine Datei wird für eine andere Messe ausgetauscht.
2. **`config/levels/<id>.json`** — pro Station: Name + Lern-Dreiklang (alle Texte als `{de, en}`), `badge`, `siegelIcon`, `cityAnchor`, **`cameraMode`**, `theme`, `enemySkin`, `mechanics`-Parameter, Tilemap-Referenz.
3. **`assets/tilemaps/*.tmj`** — Geometrie als Standard-Tiled-JSON; Objekte tragen nur eine Typ-ID, Verhalten kommt aus der Mechanik-Registry.

Beispiel (gekürzt, `03-kov-gateway.json`):

```json
{
  "id": "03-kov-gateway",
  "station": {
    "name": { "de": "KOV Gateway" },
    "portalText": { "de": "Station: KOV Gateway — dein sicherer Tunnel in die TI." },
    "reziText": { "de": "Verschlüsselt kann mich niemand mitlesen!" },
    "stampText": { "de": "✓ Verschlüsselt unterwegs im geschützten Netz." },
    "badge": "VPN · E2E-Verschlüsselung"
  },
  "siegelIcon": "seal-vpn",
  "cameraMode": "tube",
  "theme": "kov-gateway",
  "tilemap": "assets/tilemaps/03-kov-gateway.tmj",
  "collectible": { "type": "datenbit", "countRequired": 10, "label": { "de": "Datenbits" } },
  "mechanics": {
    "tube-scroll": { "speed": 55 },
    "stillstand-podest": { "scanMs": 1200, "hint": { "de": "Stillstehen: Das Gateway prüft dich!" } },
    "krypto-dusche": { "hint": { "de": "Blauer Knopf: Verschlüsselung anlegen!" } }
  }
}
```

## 8.3 Mechanik-Registry

Jeder Baustein ist eine TypeScript-Klasse in einer zentralen Registry; Tiled-Objekte referenzieren nur die Typ-ID. Unbekannte Typen werden im Kiosk-Betrieb **übersprungen und geloggt — die Messe crasht nie**. Implementiert im Prototyp: `gate`, `collectible`, `checkpoint`, `info-sign`, `door-exit`, `moving-platform`, `hazard`, `deco`, **`timing-gate`**, **`deny-enemy`** (Gegner-Framework mit „ZUGRIFF VERWEIGERT"-Stempel), **`stamp-exit`**, **`stillstand-podest`**, **`krypto-dusche`**. Als Schnittstellen-Stubs für die Ausbaustufe registriert: `pruef-scanner`, `rechte-tueren`, `finale-sprint`, `vervollstaendigen`.

## 8.4 Input-Layer — Arcade UND Tastatur

`InputManager` abstrahiert auf sechs `GameAction`s (Left/Right/Up/Down/Jump/Action). **Gamepad (USB-Arcade-Encoder) und Tastatur laufen immer parallel** (logisches ODER):

- **Messestand:** Joystick + roter/blauer Button (Button-Indizes in `config/input-bindings.json` ohne Rebuild anpassbar; verstecktes **F8-Kalibrier-Overlay** zeigt beim Aufbau live erkannte Indizes).
- **Ohne Joystick spielbar:** Pfeiltasten/WASD = laufen & ducken, **Leertaste = springen (rot)**, **E/Enter = TI-Aktion (blau)**. Die Steuerungslegende im Attract-Mode erkennt automatisch, ob ein Gamepad angeschlossen ist, und zeigt die passende Beschriftung — jede:r kann den Prototyp am Laptop ausprobieren.

## 8.5 Kiosk-Betrieb

Szenenfluss `Boot → Preload → Attract ⇄ City (Stadt-Band/Portal-Dive) ⇄ Game → Reward`. Dazu: **IdleWatchdog** (60 s ohne Eingabe → Warnhinweis → Attract), **CrashGuard** (unbehandelter Fehler → automatischer Reload, Schleifenerkennung → Personal-Hinweis; nur im `?kiosk=1`-Modus aktiv), Chrome-Kiosk-Start per `start-messe.bat` (portable Node + Mini-Static-Server + `chrome --kiosk`), interne Auflösung 640×360 mit `pixelArt` und Scale.FIT auf TV-1080p/4K, Ziel 60 fps (`?debug=1` blendet FPS ein).

## 8.6 QR-Code am Spielende

`RewardCodeProvider`-Interface mit zwei Varianten, umschaltbar per `game-config.json`:

- **Variante A — statischer Gewinn-Code** (Prototyp): identischer Code für alle, null Infrastruktur, Ausgabe auf Sicht. Bei Süßigkeiten ist fehlender Einmal-Charakter verschmerzbar.
- **Variante B — generierte Einmal-Codes** (Ausbaustufe): `ERX-{Datum}-{Laufnummer}-{Prüfziffer}` offline generiert; Automat/Personal-Tablet validiert mit derselben Prüfziffer-Formel, erkennt Doppel-Einlösung, liefert nebenbei Teilnahme-Statistik. Braucht Abstimmung mit dem Automaten-Gewerk.

QR wird mindestens 10 s angezeigt (Handy-Scan-Garantie), Reward-Screen ist per rotem Knopf überspringbar, Auto-Reset nach 45 s.

## 8.7 Projektstruktur & Asset-Pipeline

```
erezept-jump-and-run/
├── public/               ← Redaktionsebene (ohne Rebuild editierbar)
│   ├── config/           game-config, themes, input-bindings, levels/*.json
│   └── assets/tilemaps/  *.tmj (Standard-Tiled-Dateien)
├── src/
│   ├── scenes/           Boot, Preload, Attract, City, Game, UI, Reward
│   ├── mechanics/        Registry + Bausteine (+ typeIds.ts, Node-tauglich)
│   ├── input/ player/ actors/ gfx/ kiosk/ reward/ state/ level/
├── design/               LEVEL-QUELLEN: pro Level layout.txt + level.json, playlist.json, LEVELBAU.md
├── tools/                build-levels (Compiler+Prüfungen), validate-levels, check-core, new-level, serve.mjs
├── docs/                 KONZEPT.md, LEVEL-EDITING.md
└── start-messe.bat       Kiosk-Start (portable Node in .tools/)
```

**Asset-Pipeline:** Der Prototyp erzeugt alle Pixel-Grafiken **prozedural zur Laufzeit** (keine Binär-Assets, keine Lizenzfragen). Die Custom-Art im PwC/gematik-Look ersetzt später nur Texturen mit identischen Rastermaßen (Tileset 8×16 px-Kacheln, dokumentierte Sprite-Schlüssel in `src/gfx/TextureFactory.ts`) — Levels und Code bleiben unangetastet. `npm run validate` prüft als CI-Schritt Schemas, Datei-Referenzen und Objekt-Typen.

---

# 9. Messebetrieb

## 9.1 Durchsatz (realistisch gerechnet)

~165 s reine Levelzeit + Portal-/Stempel-Einblendungen + Stadt-Zwischenläufe + Fehlversuche/Assist ⇒ **3:30–4:30 pro Durchlauf**, mit Reward-Screen **~12–15 Spieler:innen/Stunde**. Gegenmaßnahmen (umgesetzt bzw. eingeplant): Stadt-Zwischenläufe ≤ 5 s und per Blau überspringbar, Reward per Rot überspringbar (QR min. 10 s), Soft-Autopilot ab 4:00, optional Erstmesse mit 5 statt 6 Stationen (nur `levelOrder` kürzen).

## 9.2 Barrierefreiheit

- **Photosensitivität:** keine Blitzeffekte über 3 Hz (Attract-Blinken 0,65-s-Zyklus; Deny-Stempel sind einmalige Pop-Animationen). Hinweisschild am Stand empfohlen.
- **Farbfehlsichtigkeit:** Farbe ist nie alleiniger Informationsträger — das aktive Timing-Licht ist zusätzlich **größer**, Scan-Balken haben Rahmen, Siegel unterscheiden sich in der Form.
- **Ohne Ton verständlich:** Messehallen sind laut — alle Informationen laufen über Bild und Text; Audio ist reines Ausbaustufen-Extra.
- Sprechblasen/HUD auf Zuschauer-Distanz lesbar (hochskalierte 640×360-Basis, kräftige Kontraste).

## 9.3 Mehrsprachigkeit

Alle Spieltexte liegen als `{de, en}`-Objekte in den JSONs; DE ist gefüllt, EN wird nach Prototyp-Freigabe übersetzt. Sprachwahl (Joystick im Attract) ist Ausbaustufe — die Datenhaltung ist vorbereitet.

## 9.4 Branding, Freigaben, Datenschutz

Checkliste vor Messebetrieb:

- [ ] Logo-Placement PwC/gematik im Attract- und Reward-Screen (Custom-Art-Phase)
- [ ] Freigabe des Claims „Einfach. Sicher. Digital." durch gematik
- [ ] **Fachliche Freigabe aller Lernsätze** (Portal-/REZI-/Stempel-Sätze, Badges) durch gematik-Review — Grundlage: Anhang 10
- [ ] Entscheidung Stationsnamen (siehe Hinweiskasten in 10.2)
- [ ] QR-Payload: offline halten oder Landingpage **ohne Tracking-Parameter**; Impressum am Stand
- [ ] **Es werden keinerlei Personendaten erhoben** — Highscore nur Avatar-Icon + Punkte, localStorage, Tages-Wipe

---

# 10. Fachlicher Anhang

*(Stand Juli 2026, gegen gematik-Quellen verifiziert — Quellenliste in 10.5.)*

## 10.1 Der reale Ablauf des e-Rezepts in 10 Schritten

1. **Karte stecken (Arztpraxis):** eGK ins eHealth-Kartenterminal — die Karte weist Identität und Versicherung nach.
2. **VSDM-Abgleich:** Über Konnektor/TI-Gateway wird online bei der Kasse geprüft, ob Karte und Stammdaten gültig/aktuell sind. *(VSDM 2.0/PoPP-Token im Rollout ab 2026 — die Spieldarstellung „Karte stecken → Daten werden geprüft" bleibt korrekt.)*
3. **Verordnung im PVS:** Die Ärztin erstellt das Rezept digital als strukturierten Datensatz.
4. **QES mit dem eHBA:** Signatur mit elektronischem Heilberufsausweis + **Arzt-PIN** — rechtlich der Unterschrift gleichgestellt. *(Deshalb gehört die PIN-Mechanik in Level 2 zu Dr. Pixel, nie zum Patienten.)*
5. **Verschlüsselt in die TI:** Konnektor bzw. TI-Gateway bauen über den VPN-Zugangsdienst einen verschlüsselten Tunnel ins geschlossene Gesundheitsnetz; nur SMC-B-authentifizierte Einrichtungen kommen hinein.
6. **Speicherung im e-Rezept-Fachdienst:** verschlüsselt, verarbeitet in der vertrauenswürdigen Ausführungsumgebung (VAU) — selbst der Betreiber kann nicht mitlesen. **Das Rezept liegt NICHT auf der eGK** — dort/im Token liegt nur der Zugangsschlüssel.
7. **Einlösewege des Patienten:** (a) eGK in der Apotheke stecken, (b) e-Rezept-App/Kassen-App (GesundheitsID), (c) Papierausdruck mit Rezeptcode, (d) CardLink (eGK ans NFC-Smartphone).
8. **Abruf durch die Apotheke:** mit Institutionskarte (SMC-B) und nur mit Autorisierung durch Token/eGK/App-Zuweisung; der Fachdienst prüft bei jedem Zugriff Identität und Berechtigung.
9. **Signaturprüfung & Abgabe:** Das Apothekensystem prüft die Arztsignatur, die Apothekerin prüft fachlich, der Fachdienst markiert das Rezept als eingelöst — **ein zweites Einlösen ist ausgeschlossen**; Quittung für die Abrechnung.
10. **Nachgelagert:** Verordnungs-/Abgabedaten fließen (widerspruchsbehaftet) in die elektronische Medikationsliste der ePA.

## 10.2 Mapping der sechs Spiel-Stationen

| Spiel-Station | Reale TI-Komponente | Kern-Sicherheitsfunktion | Lernsatz (laienverständlich) |
|---|---|---|---|
| Versichertenstammdaten | VSDM-Abgleich mit der Kasse | Authentifizierung/Gültigkeitsprüfung | „Deine Gesundheitskarte wird online bei deiner Krankenkasse geprüft." |
| Kartenterminal | eHealth-Kartenterminal (eGK/eHBA/SMC-B) | Chipkarte + PIN (Besitz + Wissen), zugelassene Hardware | „Nur mit echter Karte — und beim Arzt mit PIN — geht es weiter." |
| KOV Gateway ⚠ | Konnektor/TI-Gateway + VPN-Zugangsdienst | VPN-Verschlüsselung + Netzzugangskontrolle | „Durch einen verschlüsselten Tunnel ins geschützte Gesundheitsnetz — mitlesen kann niemand." |
| e-Rezept Fachdienst | Zentraler Fachdienst (VAU) | Verschlüsselte Speicherung + Zugriffskontrolle | „Dein Rezept liegt sicher verschlüsselt — nicht einmal der Betreiber kann es lesen." |
| e-Rezept Akte ⚠ | ePA mit elektronischer Medikationsliste | Zugriffskontrolle durch den Patienten | „Du selbst entscheidest, wer deine Daten sehen darf." |
| Apotheke | AVS mit SMC-B | Signaturprüfung + autorisierter, einmaliger Abruf | „Die Apotheke prüft die digitale Unterschrift — danach ist das Rezept verbraucht." |

> ### ⚠ Empfehlung an PwC/gematik: Stationsbezeichnungen
> **„KOV Gateway" ist kein etablierter gematik-Begriff** (kein Treffer in Fachportal, Spezifikationen, Glossaren). Fachlich gemeint ist der gesicherte TI-Zugang — offizieller Produktname: **„TI-Gateway"** (bzw. „Sicherer TI-Zugang / Konnektor & VPN"). **„e-Rezept Akte" ist ebenfalls kein Fachbegriff** — gemeint ist die **ePA mit Medikationsliste** (alternativ „e-Rezept-App", falls die Rezeptverwaltung des Patienten gemeint ist). Fachbesucher (Ärzte, Apotheker, Kassen) würden die aktuellen Begriffe nicht wiedererkennen.
> **Projektentscheidung:** Das Spiel behält die Namen der bestehenden Standgrafik (Konsistenz am Stand). Da Stationsnamen reine JSON-Daten sind, ist eine spätere Umbenennung eine Ein-Feld-Änderung ohne Entwicklungsaufwand.

## 10.3 Acht Zukunfts-Stationen (austauschbare Level)

1. **ePA** — Berechtigungs-/Widerspruchssystem: Der Versicherte kontrolliert Akten-Zugriffe.
2. **KIM** — der sichere „E-Mail-Dienst" der TI (eAU, Arztbriefe, Ende-zu-Ende verschlüsselt + signiert).
3. **TI-Messenger** — sicherer Echtzeit-Chat mit TI-geprüften Identitäten.
4. **GesundheitsID / sektoraler IDP** — kartenlose starke Authentifizierung für App-Logins.
5. **VPN-Zugangsdienst / TI-Gateway / Highspeed-Konnektor** — der bewachte Tunneleingang (2026 im Umstieg vom Einbox-Konnektor).
6. **eAU** — Krankschreibung signiert und verschlüsselt per KIM an die Kasse.
7. **NCPeH** — e-Rezept perspektivisch in EU-Apotheken (geprüfte nationale Kontaktpunkte).
8. **VSDM 2.0 / PoPP** — der neue Versichertennachweis per signiertem Token („Proof of Patient Presence").

## 10.4 Neun fachliche No-Gos

1. Das Rezept liegt **nicht auf der eGK** — Karte/Code sind nur der Schlüssel („Rezept in den Tresor, Schlüssel zum Patienten").
2. Das Rezept reist **nie ungeschützt** — kein Spielbild, in dem es offen durchs Netz fliegt und *gelesen* werden kann.
3. Die Apotheke kann **nicht frei auf Rezepte zugreifen** — nur mit Patient-Autorisierung + SMC-B.
4. **Ohne Arztsignatur (eHBA + PIN) kein gültiges Rezept** — die QES ist Pflicht, kein Extra.
5. Ein e-Rezept ist **nur einmal einlösbar** (28 Tage gültig zulasten der GKV) — Kopien sind wertlos.
6. **Der Patient behält die Kontrolle** — freie Apothekenwahl, Widerspruchsrechte; keine Zwangs-Datenflüsse darstellen.
7. Die TI ist **kein offenes Internet und keine Firmen-Blackbox** — gesetzlich reguliertes, geschlossenes Netz mit gematik-Zulassung und BSI-geprüften Komponenten.
8. **Keine veralteten Begriffe einfrieren** — Konnektor→TI-Gateway, VSDM 2.0, ECC-Kryptografie, CardLink: Begriffe bleiben als Daten austauschbar.
9. **Kein „Hacker-gewinnt"- und kein „Spieler-kämpft"-Bild** — die Architektur schützt (Karte+PIN, Signatur, Verschlüsselung, Zugriffskontrolle), nicht Glück oder Geschick des Patienten.

## 10.5 Quellen (Auswahl)

gematik: E-Rezept-Anwendungsseite + FAQ, Fachportal E-Rezept, TI-Gateway-Leitfaden, Spezifikationen gemSpec_FD_eRp und gemSpec_VSDM_2, Festlegung „Abruf der E-Rezepte in der Apotheke nach Autorisierung" · BMG: E-Rezept-FAQ · ABDA: E-Rezept-FAQ (Stand 07/2026), ePA-Rollout-FAQ · KBV: Medikationsliste/ePA · AOK Gesundheitspartner: E-Rezept für Arztpraxen. (Vollständige Linkliste im internen Rechercheprotokoll.)

---

# 11. Prototyp: Umfang und Abnahmekriterien

## 11.1 Im Prototyp enthalten (dieses Repository)

- Kompletter Stack (Phaser 3 + TS + Vite), offline-fähiger Build, `start-messe.bat` + Chrome-Kiosk
- Voller datengetriebener Pfad: `game-config`-Playlist → Level-JSON (zod-validiert, lesbare Redaktionsfehler) → Tiled-Tilemap → Mechanik-Registry
- **Zwei Level, zwei Silhouetten:** „Kartenterminal" (horizontal: Kontaktpad-Parcours, Skimming-Kralle mit Duck-Ausweichen und Siegel-Blende-Deny-Gag, PIN-Schleuse als Timing-Gate mit eHBA-Framing, Signatur-Stempel-Setpiece) und „KOV Gateway" (`cameraMode: tube`: Auto-Scroll-Glastunnel, Prüf-Podeste mit Stillstand-Scan + Kraken-Deny-Gag, Verschlüsselungs-Dusche, Datenkraken machtlos außen am Glas)
- Paul mit Duck-State/Coyote-Time/Jump-Buffering, REZI mit Sprechblasen + sichtbaren Siegeln, Stadt-Band mit Portal-Dive und Auftauch-Stempel
- Kiosk-Basis (Attract, IdleWatchdog, CrashGuard), HUD mit TI-Streckenkarte, Assist-Basisstufe, Reward-Screen mit Offline-QR (Variante A), Tages-Highscore mit Avatar-Icons
- Input: Arcade-Encoder UND Tastatur parallel, F8-Kalibrierung, automatische Steuerungslegende
- Tooling: `npm run build:levels` (Level-Compiler mit Spielbarkeits-Prüfung), `npm run validate`, `npm run guard` (Kern-Schutz), `design/LEVELBAU.md`

## 11.2 Abnahmekriterien

1. **Redakteurstest:** Station in JSON umbenennen, `levelOrder` umsortieren, einen Lernsatz ändern → läuft nach Neuladen korrekt, ohne Entwicklerhilfe.
2. **Silhouetten-Test:** Ein Level mit `cameraMode: tube` lädt und spielt korrekt (beweist die Datensteuerung über Theme-Wechsel hinaus).
3. Duck-, Hoch/Runter- und Blau-Aktionen am **echten USB-Encoder** getestet (F8-Overlay zur Zuordnung).
4. 30-Minuten-Dauerlauf Attract ⇄ Spiel ⇄ Reward ohne Eingriff; absichtlich kaputtes Level-JSON zeigt lesbare Fehlermeldung statt Weißbild.
5. 60 fps auf Standard-PC (`?debug=1`).

## 11.3 Ausbaustufe (nach Prototyp-Freigabe)

Restliche vier Level + Module (`pruef-scanner`, `rechte-tueren`, `finale-sprint`, `vervollstaendigen`, vertikale Silhouette), Attract-Demo-Replay, `GeneratedCodeProvider` (Variante B + Automaten-Abstimmung), Audio, Custom-Pixel-Art im PwC/gematik-Look, EN-Texte + Sprachwahl, TI-Schutzschild-Vollausbau + Express-Autopilot, 8-h-Härtetest.

---

# 12. Roadmap zur Messe

| Phase | Inhalt | Ergebnis |
|---|---|---|
| **1. Prototyp** *(dieses Repo)* | 2 Level, voller Datenpfad, Kiosk-Basis, QR Variante A | Spielbarer Proof of Concept für Stakeholder |
| **2. Freigaben** | gematik-Fachreview der Lernsätze, Stationsnamen-Entscheidung, Branding-Assets, Automaten-Gewerk (QR-Variante) | Abgenommene Inhalte |
| **3. Vollausbau** | 6 Level, alle Module, Audio, Custom-Art, EN, Attract-Demo | Feature-komplettes Spiel |
| **4. Härtetest** | 8-h-Dauerlauf, Encoder-Test am Zielgerät, Zweit-Hardware als Fallback, Durchsatz-Probe | Messefreigabe |

---

*Erstellt auf Basis eines mehrstufigen Design-Prozesses (zwei konkurrierende Leveldesign-Konzepte mit Jury-Konsolidierung, Technik-Architektur, fachliche Verifikation gegen gematik-Quellen, Vollständigkeits-Review mit 21 eingearbeiteten Korrekturen).*
