# Playtest-Anleitung — Wirkungsmessung (KAPSEL 4.4)

Diese Anleitung ist für die Person, die den Playtest **durchführt**. Sie braucht
keine Technikkenntnisse. Zeitbedarf pro Testperson: **rund 15 Minuten**.

---

## Warum dieser Test entscheidet

KAPSEL 4.1 nennt ein Abbruchkriterium, kein „nice to have":

> Wenn der Toggle im Laien-Playtest nicht „klickt" (< 80 % verstehen
> „sichtbar vs. sicher"), Mechanik überarbeiten, **bevor** irgendetwas skaliert wird.

Es gibt derzeit **ein** Hülle-Level (Station 4, „Die Hülle"). Das ist Absicht:
Erst messen, dann 22 weitere Level bauen. Fällt der Test durch, sind die
Stellschrauben an einer Stelle gebündelt (`src/state/HuelleState.ts`,
`HUELLE_TUNING`) — später wären es 22 Level Änderungsaufwand.

---

## Was gemessen wird — zwei getrennte Dinge

| | Frage | Wie |
|---|---|---|
| **Verhalten** | Nutzt die Person die Hülle **freiwillig und rechtzeitig**? | automatisch (Telemetrie) |
| **Wissen** | Kann sie die Aussagen hinterher **korrekt benennen**? | Fragebogen (unten) |

Beides ist nötig. Wer nur den Fragebogen macht, prüft Textverständnis. Wer nur
die Telemetrie liest, weiß nicht, ob die Person die *fachliche* Aussage
mitgenommen hat.

### Die drei Verhaltensklassen

Die Software unterscheidet nach der **Reihenfolge**:

- **proaktiv** — verschlüsselt, *bevor* ein Lauscher sie erwischt.
  → Sie hat die Regel aus der Situation gelesen. **Nur das zählt als verstanden.**
- **reaktiv** — verschlüsselt erst *nachdem* sie erwischt wurde.
  → Sie hat die Strafe gebraucht.
- **passiv** — verschlüsselt nie.

Diese Messung ist strenger als eine Abfrage und braucht keinen Text.

---

## Vorbereitung (einmalig)

```bash
npm install
npm run build:levels
npm run dev
```

In `public/config/game-config.json` muss stehen: `"telemetrie": true` (Standard).

**Wichtig:** Vor dem ersten Tester alte Daten löschen — sonst mischen sich
Entwicklungsläufe in die Statistik. In der Browser-Konsole:

```js
localStorage.removeItem('erezept-telemetrie')
```

---

## Ablauf pro Testperson

**1. Vorher-Fragebogen (3 Min).** Vor dem Spielen, ohne Erklärung. Wer schon
Bescheid weiß, zeigt später keinen Zuwachs — das ist eine Information, kein Fehler.

**2. Spielen (8 Min).** Nur ein Satz Anleitung:

> „Spiel einfach. Ich erkläre absichtlich nichts."

Das ist die Kernbedingung. Jede Hilfe macht die Messung unbrauchbar. Bleibt die
Person stecken, gilt: **beobachten, nicht helfen** — dafür gibt es REZI-Tipps
im Spiel, und deren Häufigkeit ist selbst eine Kennzahl.

**3. Nachher-Fragebogen (3 Min).** Dieselben Fragen, gleiche Reihenfolge.

**4. Kurz nachfragen (1 Min).** Laut denken lassen:
„Was hat der Wechsel bewirkt?" · „Wann hast du ihn benutzt?" ·
„Wo warst du unsicher?"

---

## Auswertung

**Im Spiel: F9 drücken.** Es erscheint:

```
Playtest-Auswertung  (5 Durchläufe)

verstanden (proaktiv):  4
erst nach Treffer:      1
nie verschlüsselt:      0

Quote: 80 %   Ziel: 80 %   ERREICHT
5 Durchläufe exportiert
```

Grün = erreicht, gelb = nicht erreicht. Gleichzeitig wird eine Datei
`telemetrie-JJJJ-MM-TT-HH-MM.json` gespeichert (Rohdaten für die Ablage).

**Fragebogen:** Lernzuwachs = richtige Antworten nachher − vorher.

### Auswertung am Rechner (mehrere Geräte, ein Bericht)

Wenn an mehreren Rechnern getestet wurde oder du den Bericht ablegen willst:

```bash
mkdir playtest-daten
# alle telemetrie-*.json dort hineinlegen
npm run playtest:report
```

Das Werkzeug führt die Dateien zusammen, zählt doppelt exportierte Durchläufe nur
einmal, überspringt beschädigte Dateien und druckt am Ende eine **Ableitung** —
also nicht nur die Quote, sondern was daraus folgt. Beispiel:

```
Auswertbare Durchläufe: 4

Nutzung der Hülle-Mechanik
  verstanden (proaktiv):  2
  erst nach Treffer:      1
  nie verschlüsselt:      1

  Quote: 50 %   Ziel: 80 %   NICHT ERREICHT

Auffälligkeiten je Station
  Station                  Abbrüche  Tipps  Treffer  Zeit
  04-die-huelle                  1      3        3    72s

Ableitung
  Kriterium verfehlt, aber die Mehrheit hat die Regel verstanden — nur zu
  spät. Die Mechanik ist richtig, die EINFÜHRUNG ist zu leise: Lauscher früher
  sichtbar machen, Sichtkegel deutlicher, erste Zone entschärfen.
  HUELLE_TUNING nicht anfassen.
```

Unter drei Durchläufen verweigert das Werkzeug bewusst eine Deutung — mit zwei
Testpersonen ist eine Prozentzahl keine Aussage.

Der Ordner `playtest-daten/` ist in `.gitignore`: Messdaten gehören nicht ins
Repository.

---

## Fragebogen (7 Fragen, richtige Antwort **fett**)

Die Fragen 1–5 prüfen genau die fünf Vereinfachungsfehler aus KAPSEL 1.4 — also
die Stellen, an denen ein Lernspiel fachlich Schaden anrichten könnte.

**1. Ein unverschlüsseltes Dokument ist auf dem Transportweg …**
- a) … nur für den Empfänger lesbar
- b) **… für Dritte mitlesbar**
- c) … automatisch gelöscht

**2. In der VAU (Vertrauenswürdige Ausführungsumgebung) …**
- a) … sind Daten nur verschlüsselt vorhanden
- b) **… wird im Klartext gearbeitet, ohne dass der Betreiber mitlesen kann**
- c) … kann der Rechenzentrumsbetreiber die Daten lesen

*Häufigster Irrtum: „VAU = sicherer Tunnel". Sie ist ein Verarbeitungsraum.*

**3. Verschlüsselung und Signatur …**
- a) … sind dasselbe
- b) **… sind zwei verschiedene Dinge: Vertraulichkeit vs. Echtheit**
- c) … schließen sich gegenseitig aus

**4. Wozu dient die elektronische Gesundheitskarte beim E-Rezept?**
- a) Sie speichert das Rezept
- b) **Sie ist der Schlüssel, der den Zugriff freigibt**
- c) Sie bezahlt das Medikament

**5. „Zero Trust" bedeutet …**
- a) … es gibt keinen Schutz
- b) **… jeder einzelne Zugriff wird geprüft, unabhängig vom Ort**
- c) … nur das interne Netz wird geprüft

**6. Wenn eine Sitzung in der VAU abläuft, …**
- a) … bleiben die Daten geschützt
- b) **… ist man wieder ungeschützt und sichtbar**
- c) … wird das Spiel beendet

**7. Wer entscheidet, wer in die elektronische Patientenakte sehen darf?**
- a) Die Krankenkasse
- b) Die Arztpraxis
- c) **Die versicherte Person**

---

## Beobachtungsbogen (pro Person mitschreiben)

```
Person Nr.:            Datum:
Vorkenntnisse TI:      keine / etwas / beruflich

Vorher richtig:   __ / 7
Nachher richtig:  __ / 7
Zuwachs:          __

Wo ist Frust entstanden?

Wo kam ein „Aha"?

Wörtliche Zitate:
```

---

## Wie die Ergebnisse zu lesen sind

| Beobachtung | Bedeutung | Konsequenz |
|---|---|---|
| Quote ≥ 80 % | Mechanik trägt | weiterbauen (Welt 2) |
| Quote < 80 %, viele **reaktiv** | Regel wird verstanden, aber zu spät | Lauscher früher sichtbar machen, Kegel deutlicher |
| Quote < 80 %, viele **passiv** | Zusammenhang wird nicht erkannt | Mechanik überarbeiten — nicht nur Level ändern |
| Viele Tipps (`tipp`) | REZI muss retten, was das Design nicht zeigt | Einführung überarbeiten |
| Abbrüche in Station 4 | Level zu schwer | Checkpoints, Lauscher-Tempo |
| Frage 2 nachher falsch | VAU-Aussage kommt nicht an | VAU-Feld deutlicher gestalten |
| Frage 3 nachher falsch | Verschlüsselung/Signatur verschwimmt | Signatur-Setpiece stärker trennen |

**Realistischer Zielnutzen** (KAPSEL 4.4): signifikanter Wissenszuwachs bei
**deutlich höherer Motivation** als Folien — nicht „das Spiel schlägt jeden
anderen Lernweg". Wer mehr verspricht, wird von der Messung widerlegt.

---

## Datenschutz

Die Telemetrie erfasst **keine** Personendaten: kein Name, keine Kennung, keine
IP, kein Datum. Nur Millisekunden seit Sitzungsbeginn und die Sitzungskennung
(Zufallszahl, verfällt mit dem Durchlauf). Nichts wird übertragen — die Daten
bleiben im Browser, bis F9 gedrückt wird.

Ein Test (`tools/test/telemetrie.test.ts`) prüft, dass kein Ereignis ein Feld
bekommt, das über `typ`, `levelId`, `tMs` und `wert` hinausgeht. Das Spiel
erklärt Vertraulichkeit — es soll sich selbst daran halten.

**Fragebögen** auf Papier ohne Namen, nur mit Nummer. Zuordnung Nummer ↔ Person
wird nach der Auswertung vernichtet.
