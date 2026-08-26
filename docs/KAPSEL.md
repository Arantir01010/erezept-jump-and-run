# KAPSEL 2.0 — Vertiefte Ausarbeitung eines 2D-Jump-'n'-Run zur Vermittlung der Telematikinfrastruktur (TI)

*Hinweis zur Kennzeichnung: **[TI-Fakt]** = belegter Fakt aus gematik-/Fachquellen (Quelle im Fließtext genannt); **[Design]** = Designvorschlag des Autors. Zukunftsangaben (geplante Termine) sind als solche markiert.*

## TL;DR
- Die "Hülle"-Mechanik (Klartext/Verschlüsselt/VAU) ist als zentrales Motiv fachlich tragfähig und spielerisch bewährt (Polaritätswechsel wie in Ikaruga/Outland), trägt aber über 20–30 Level **nicht allein** — es braucht 2–3 zusätzliche, gestaffelt eingeführte Mechaniken (Karten-/Identitätsstecken, Signatur-Stempel, Berechtigungs-/Zero-Trust-Pforten). **[Design]**
- Die TI lässt sich sauber in fünf Welten als Makro-Kishotenketsu abbilden; die belegten gematik-Abläufe (ePA-Einstellen über die VAU, E-Rezept-Einlösung per eGK als "Schlüssel", KIM-Ende-zu-Ende, Zero Trust/TI 2.0) liefern echte, nicht erfundene Level-Logik. **[TI-Fakt/Design]**
- Empfehlung: **Godot 4** (installationsfreier Web-Export möglich) als Engine; Scope realistisch für ein kleines Team in ~6–9 Monaten nach dem Prinzip "vertikale Scheibe zuerst"; die größten Reputationsrisiken sind fachliche Vereinfachungsfehler (VAU = bloßer Tunnel, Zero Trust = "kein Schutz", Verschlüsselung ≠ Signatur), die aktiv vermieden werden müssen. **[Design]**

---

## Key Findings

**Fachlich (TI):**
1. Die TI ist in **Zonen** gegliedert: dezentrale Zone in der Einrichtung, Zugangszone, zentrale Zone/zentrales Netz (MPLS-Weitverkehrsnetz zwischen den Rechenzentren) — laut gematik-Architekturkonzept und Whitepaper Datenschutz. Ideal als Welten-/Abschnittsgliederung.
2. Der **Konnektor** ist heute der "Gatekeeper" (VPN-Aufbau, Kartenzugriff, Signatur/Verschlüsselung als Fachlogik). Mit **TI 2.0** soll die dezentrale Hardware schrittweise entfallen; **TI-Gateway + Highspeed-Konnektor (HSK)** verlagern die Konnektor-Funktion ins Rechenzentrum (gematik-FAQ, fachportal.gematik.de).
3. Die **VAU** (Vertrauenswürdige Ausführungsumgebung) ist **kein bloßer Tunnel**: Sie erlaubt laut gematik-Faktencheck und medatixx die Klartext-Verarbeitung von Daten auf einem Server, ohne dass Betreiber oder Aktenanbieter Zugriff haben — der isolierte dritte Spielzustand.
4. **Zero Trust / TI 2.0** ("Vertraue niemandem, prüfe alles", mTLS): produktiver Start mit **VSDM 2.0 ab Juli 2026**; gematik hat den Zuschlag an die **EY Consulting GmbH** vergeben, erste **ZETA-Kernkomponenten wurden am 15.12.2025 als Open Source auf GitHub** veröffentlicht; "bis 2029 ist geplant, alle TI-Dienste umzustellen" (gematik-Newsroom).
5. **RSA→ECC-Migration**: Laut fachportal.gematik.de wird "die RSA-Infrastruktur ab 29.06.2026 schrittweise abgeschaltet". Fristen: RSA-only-Konnektoren bis 31.12.2025 (seit 1.1.2026 kein TI-Zugang mehr), HBA/SMC-B G2.0 bis 30.06.2026, gSMC-KT bis 31.12.2026; Grundlage BSI TR-02102-1/SOG-IS (RSA <3000 Bit ab 1.1.2026 unzulässig).
6. **ePA für alle**: Opt-out-Start am **15.01.2025** (zunächst in Modellregionen Hamburg/Franken und den KV-Testregionen Nordrhein/Westfalen-Lippe; Rechtsgrundlage Digital-Gesetz/DigiG); Ausbaustufen 3.0 (elektronische Medikationsliste), 3.1 (eMP, AMTS, EU-Zugriff, Forschungsdatenausleitung ab 15.07.2025); Zugriffsprotokoll, Ombudsstelle. Die Schlusspointe (Datensouveränität) ist gesetzlich real.

**Design:**
7. Zwei-Zustands-Mechaniken tragen nur mit Kombinationstiefe (Lehre aus Ikaruga/Outland/Giana Sisters/Guacamelee: der Wechsel muss offensiv UND defensiv zugleich wirken).
8. Nintendos 4-Schritte-Methode (Kishotenketsu) — von Director **Koichi Hayashida** (Super Mario 3D Land, Gamasutra 2012) beschrieben, für Level-Design popularisiert durch Mark Browns "Game Maker's Toolkit" — strukturiert jedes Level.
9. Godot vs. Phaser: Für reines Web-2D ist Phaser technisch leichter/schneller, Godot bietet 2D-Editor + Web-Export + Wachstumspfad zu Desktop/Mobile.

---

## Details

### TEIL 1 — SYSTEMATISCHE ANALYSE DER TI

#### 1.1 Inventarliste der TI

**Zonen** *(Quelle: gematik-Architekturkonzept TI-Plattform, gematik-Whitepaper Datenschutz 2025, § 306/307 SGB V)* **[TI-Fakt]**

| Element | Erklärung (eigene Worte) | Wer nutzt es / Ziel | Wenn es fehlt/falsch konfiguriert |
|---|---|---|---|
| Dezentrale Zone | Alles physisch in der Einrichtung (Praxis/Klinik/Apotheke): Primärsystem, Kartenterminal, Konnektor. gematik trägt hier datenschutzrechtliche Mitverantwortung neben der Einrichtung (§ 307 SGB V). | Leistungserbringer | Fehlkonfiguration = lokales Einfallstor; Verantwortung teils bei Einrichtung |
| Zugangszone | Übergang dezentral→zentral: VPN-Zugangsdienst bzw. künftig TI-Gateway. | LEI, Dienstleister vor Ort (DVO) | Ohne Zugang keine TI-Nutzung |
| Zentrale Zone / zentrales Netz | MPLS-Weitverkehrsnetz, verbindet die Rechenzentren mit den Fachdiensten; gematik allein datenschutzrechtlich verantwortlich. | gematik, Anbieter | Ausfall = bundesweite Störung |

**Dezentrale Komponenten** *(Quelle: fachportal.gematik.de – Konnektor, eHealth-Kartenterminal, mobiles Kartenterminal, Highspeed-Konnektor)* **[TI-Fakt]**

| Element | Erklärung | Ziel | Fehlerfall |
|---|---|---|---|
| Primärsystem (PVS/AVS/KIS) | Lokale Verwaltungssoftware (Praxis/Apotheke/Klinik), Ausgangspunkt aller TI-Vorgänge; Datenhaushalt je Mandant abgegrenzt. | Versorgung/Doku | Ohne Update keine TI-Anwendung |
| eHealth-Kartenterminal (stationär) | Liest eGK/HBA/SMC-B, sichert PIN-Eingabe; TLS-gesichert. | Identifikation, PIN-Eingabe | Ohne KT keine Kartenfunktion (z. B. QES) |
| Mobiles Kartenterminal (mobKT) | Für Hausbesuche; speichert Versichertenstammdaten verschlüsselt zwischen, interner Log-Container; Freischaltung per HBA/SMC-B+PIN. | mobile Versorgung | Verlust = Datenschutzrisiko |
| Konnektor | "Gatekeeper": VPN-Verbindung in die TI, Kartenzugriff, Fachlogik (VSDM, QES, eMP, NFDM), Firewall/Applicationgateway. | Sicherer Zugang | RSA-only-Konnektoren ab 1.1.2026 unbrauchbar; darf nicht in den Hausmüll |
| Highspeed-Konnektor (HSK) | Serverbasierter Konnektor im Rechenzentrum, ersetzt eine Vielzahl von Einbox-Konnektoren, nutzt virtuelle Geräteidentitäten (keine gSMC-K mehr nötig); gematik-zugelassen. | Skalierung, RZ-Betrieb | — |
| TI-Gateway / virtueller Konnektor (vKON) | Dienst, der einen HSK im RZ für viele Einrichtungen nutzbar macht; Praxis braucht keinen eigenen Konnektor. Betriebs-/Datenschutzverantwortung beim Anbieter. | niedrigschwelliger Zugang | — |

**Zentrale Sicherheit / Kryptografie** *(Quelle: gematik-Newsroom Zero Trust, gemSpec_ZETA, gemSpec_TSL/gemKPT_PKI_TIP, gematik-Faktencheck VAU, medatixx)* **[TI-Fakt]**

| Element | Erklärung | Ziel | Fehlerfall |
|---|---|---|---|
| VPN-Zugangsdienst | Verschlüsselter Tunnel dezentral→zentral, abgeschirmt vom offenen Internet. | Transportsicherheit | — |
| TI 2.0 / Zero Trust / mTLS | "Vertraue niemandem, prüfe alles"; jeder Zugriff wird geprüft, unabhängig vom Ort; mTLS zwischen allen Zero-Trust-Komponenten (Policy Enforcement/Decision Point). Start VSDM 2.0 ab Juli 2026, vollständig geplant bis 2029. | ortsunabhängige, sichere Nutzung | Fehlkonfiguration = abgelehnte Zugriffe |
| PKI der TI / TSL / TSP / Zertifikate / CRL | Vertrauensraum über die Trust-Service Status List (TSL); Trust Service Provider (TSP) geben X.509-Zertifikate aus, gematik beantragt Einträge, Anbieter des TSL-Dienstes pflegt die Liste; Sperrung über CRL/OCSP. | Vertrauen/Echtheit | Abgelaufene/gesperrte Zertifikate = kein Zugriff |
| RSA→ECC-Migration | Umstellung von RSA auf Elliptic Curve Cryptography (kürzere Schlüssel, höheres Sicherheitsniveau); zwei Vertrauensräume TSL(RSA) und TSL(ECC-RSA); RSA-Abschaltung ab 29.06.2026. | moderne Krypto/Performance | RSA-only ab Stichtag gesperrt |
| VAU (Vertrauenswürdige Ausführungsumgebung) | Isolierte Umgebung, in der Daten im **Klartext verarbeitet** werden, ohne dass Betreiber/Aktenanbieter Zugriff haben; je Sitzung eigene, aus schreibgeschützter Kopie frisch gestartete Instanz; niemand hat Vollzugriff auf alle Akten. | Vertraulichkeit trotz Cloud | — |
| HSM / Attestierung / Kontext-/Datenablageschlüssel | HSM speichert private Schlüssel; Kontextschlüssel wird beim Sitzungsstart in die VAU eingebracht und beim Sitzungsende aus dem Arbeitsspeicher gelöscht; Aktenschlüssel versichertenindividuell. | Schlüsselsicherheit | — |

**Identitäten / Smartcards** *(Quelle: fachportal.gematik.de – Identitäten/Identitäts- und Kartenherausgabe, gemSpec_IDP_Dienst/_Sek, gematik-Whitepaper Datenschutz)* **[TI-Fakt]**

| Element | Erklärung | Wer |
|---|---|---|
| eGK | Elektronische Gesundheitskarte; identifiziert Versicherte, dient als "Schlüssel" (z. B. E-Rezept-Einlösung), speichert Befunde nicht selbst. | Versicherte |
| HBA (eHBA) | Heilberufsausweis: persönliche digitale Identität + qualifizierte elektronische Signatur (QES), 4 logische Kanäle. | Ärzte/Heilberufe |
| SMC-B | Institutionskarte (Praxisausweis); authentisiert die Einrichtung gegenüber der TI. | Praxis/Klinik/Apotheke/Organisation |
| gSMC-KT / gSMC-K | Gerätekarten für Kartenterminal (steckt dauerhaft) bzw. fest verbauter Konnektor; für TLS-Verbindungen. | Geräte |
| GesundheitsID | Digitale Versicherten-Identität, token-basiert (OIDC), ohne ständige eGK-PIN nutzbar; künftig auch für Leistungserbringer. | Versicherte (künftig auch LE) |
| Sektoraler IDP / zentraler IDP-Dienst / Föderation / Federation Master | Identity Provider je Sektor (z. B. Kassen für Versicherte) auf Basis OIDC/OAuth2; Federation Master verwaltet den Vertrauensraum, nur registrierte Teilnehmer dürfen mitmachen. | alle |

**Anwendungen (Fachdienste)** *(Quelle: gematik.de/fachportal.gematik.de – E-Rezept, ePA für alle, KIM, TI-Messenger, VSDM/NFDM/eMP/QES, MyHealth@EU, DiPag; Ärzteblatt/KBV/DKG)* **[TI-Fakt]**

| Element | Erklärung | Ziel |
|---|---|---|
| ePA für alle | Cloudbasierter Dokumentenspeicher im Medizinnetz; alle Ver-/Entschlüsselung in der VAU; Opt-out seit 15.01.2025; Ausbaustufe 3.0 (eML), 3.1 (eMP, AMTS-rZI, EU-Zugriff, Forschungsdatenausleitung); dokumentenbasiert (IHE-XDS) + datenbasiert (FHIR/Medication Service). | Datensouveränität, bessere Versorgung |
| Zugriffsprotokoll / Ombudsstelle | Aktensystem protokolliert Akteur, Zeitpunkt, Art des Zugriffs und Dokument; Ombudsstelle der Kasse unterstützt bei Rechten/Widerspruch. | Transparenz, Patientenrechte |
| E-Rezept | Zentraler Fachdienst; eGK-Stecken in der Apotheke autorisiert den Zugriff (Karte = Schlüssel, speichert Rezept nicht); QES durch HBA (auch Komfortsignatur); VAU-geschützt; drei Einlösewege (eGK, App/Token, Ausdruck). | digitale Verordnung |
| KIM (Kommunikation im Medizinwesen) | Sichere E-Mail; jede Nachricht Ende-zu-Ende verschlüsselt + signiert; Client-Modul im PVS; Adressierung ausschließlich über den Verzeichnisdienst (VZD). | sicherer Dokumentversand (eArztbrief, eAU) |
| TI-Messenger (TI-M Pro/ePA/Connect) | Matrix-basiert, föderiert, E2EE; VZD-FHIR-Directory für Suche und Föderationsliste; gematik ist Silver Member der Matrix Foundation. | interoperabler Echtzeit-Chat |
| VSDM / NFDM / eMP / QES | Versichertenstammdaten-Abgleich (1×/Quartal, Onlineprüfung; VSDM 2.0 ab Sept. 2026 im Parallelbetrieb); Notfalldaten auf eGK; elektronischer Medikationsplan; qualifizierte Signatur. | Versorgung/Recht |
| MyHealth@EU / NCPeH | Grenzüberschreitender Austausch (Patient Summary, ePrescription u. a.); NCPeH als Gateway TI↔EU, spezifiziert von gematik, **betrieben von der DVKA** (§ 219d SGB V); EHDS-VO seit 26.03.2025 in Kraft. | EU-weite Versorgung |
| DiPag (Digitale Patientenrechnung) | TI-2.0-Anwendung nach § 359a SGB V: standardisierte, sichere Übermittlung von Patientenrechnungen zwischen Leistungserbringern, Versicherten und Kostenträgern; Zero-Trust/ZETA; **Produktivstart für Ende 2026 geplant** (Zukunftsangabe). | digitaler Rechnungsprozess |
| Verzeichnisdienst (VZD) | Zentrales, geprüftes Adressbuch der TI (u. a. KIM-Adressen), gepflegt über KVen/Kammern/DKG. | Adressierung |
| RU/TU/PU | Referenz-, Test- und Produktivumgebung; PU darf nicht zu Testzwecken genutzt werden. | Qualitätssicherung/Zulassung |

#### 1.2 End-to-End-Abläufe (werden zu Leveln) **[TI-Fakt, vereinfacht]**

**A) Befund aus der Praxis in die ePA:** Primärsystem erzeugt Dokument → SMC-B/HBA authentisiert → VAU-Kanal wird aufgebaut → Autor + Ziel-KVNR authentifiziert → Schreiben autorisiert → verschlüsselte Ablage; Zugriff wird protokolliert.

**B) LEI-Zugriff auf die ePA:** eGK stecken → Berechtigung/Session → VAU-Kanal → Kontextschlüssel in der VAU → Lesen/Schreiben → Sitzungsende löscht den Kontextschlüssel.

**C) E-Rezept ausstellen und einlösen:** Arzt signiert (QES/Komfortsignatur via HBA) → Rezept liegt im E-Rezept-Fachdienst → Versicherter steckt eGK in der Apotheke (= Schlüssel) → Apotheke greift auf offene Rezepte zu → Dispensierung → Statusübergang + Protokoll.

**D) KIM senden/empfangen:** Nachricht im PVS → Client-Modul verschlüsselt + signiert → Adressierung über VZD → Transport → nur der Empfänger entschlüsselt.

**E) TI-M über Föderationsgrenze:** Suche im VZD-FHIR-Directory → Einladung → Messenger-Proxy prüft die Föderationsliste → E2EE-Chat.

**F) Widerspruch/Berechtigungen (ePA-App):** Versicherter verwaltet Zugriffsrechte, widerspricht (App oder Ombudsstelle); bei Widerspruch löscht die Kasse die Akte samt Daten.

#### 1.3 Übersetzbarkeit in Platformer-Mechaniken **[Design]**

| TI-Element | Eignung | Begründung |
|---|---|---|
| Klartext/Verschlüsselt/VAU | **sehr gut** | Klarer Zustandswechsel, sofort lesbar, kernmechanikfähig |
| eGK/HBA/SMC-B stecken | **gut** | "Schlüssel/Schalter"-Metapher, natürliche Gate-Mechanik |
| Signatur (QES) | **gut** | "Stempel"-Aktion, klar von Verschlüsselung trennbar |
| Berechtigung/Zugriffsprotokoll | **gut** | Türen/Schalter + Endscreen als Protokoll |
| Zero Trust / mTLS | **mittel** | Als "Prüfpforten, die jeden Schritt kontrollieren" darstellbar |
| Konnektor/Gateway/HSK | **mittel** | Als Umbau-Kulisse (Welt 4) gut, als Mechanik eher Hintergrund |
| PKI/TSL/CRL/Föderation | **schlecht** | Zu abstrakt, nur als Umgebungsdetail/Kompendium |
| RSA→ECC | **mittel** | Als Twist "alte schwere vs. neue leichte Schlüssel" |
| VSDM/NFDM/eMP/DiPag/MyHealth@EU | **schlecht–mittel** | Überfrachten den Kern; besser als Sammelkarten/Kompendium/Nebenlevel |

**Bewusst weglassen bzw. nur ins Kompendium:** PKI-Details, TSL/CRL, DiPag, MyHealth@EU/NCPeH, VSDM-Quartalslogik, Föderationsprotokolle (OIDC/OAuth). Sie lassen sich nur als Text vermitteln und würden das Spiel überfrachten.

#### 1.4 Warnung vor Vereinfachungsfehlern **[TI-Fakt/Design]**
- **VAU ist kein bloßer Tunnel.** Sie ist eine Verarbeitungsumgebung, in der Klartext-Verarbeitung ohne Betreiberzugriff möglich ist (gematik-Faktencheck/medatixx). Falsch wäre "VAU = sicherer Schlauch"; richtig ist "sicherer Raum, in dem sogar im Klartext gearbeitet werden kann, ohne dass jemand mitliest".
- **Zero Trust heißt nicht "kein Schutz".** Es heißt "prüfe jeden Zugriff einzeln, unabhängig vom Ort" — mehr, nicht weniger Prüfung.
- **Verschlüsselung ≠ Signatur.** Verschlüsselung schützt Vertraulichkeit; die (qualifizierte) Signatur belegt Echtheit/Urheberschaft. Im Spiel als zwei getrennte Aktionen darstellen.
- **ePA-Rechte korrekt darstellen:** Versicherte haben die Datenhoheit; Dokumente werden **nicht** automatisch hochgeladen — einzige Ausnahme laut gematik sind E-Rezept-Daten für die Medikationsliste; Zugriffe werden protokolliert.
- **eGK speichert Befunde nicht** — sie ist Schlüssel/Identität, kein Datenspeicher der Akte.
- **Der Konnektor verschwindet nicht "ersatzlos"** in TI 2.0 — die Funktion wandert (TI-Gateway/HSK, später Zero-Trust-Clients mit sicherem Internetzugang; erste Stufe VSDM 2.0 stationär, zweite Stufe mobiler Zugang für Versicherte).

---

### TEIL 2 — VERTIEFUNG DES GAME DESIGNS

#### 2.1 Kernmechanik-Kritik **[Design, gestützt auf Genre-Analyse]**
Ein reiner Zwei-Zustands-Toggle ermüdet über 20+ Level. Die Lehren aus dem Genre sind eindeutig: **Outland** und **Ikaruga** funktionieren, weil der Farb-/Polaritätswechsel *offensiv und defensiv zugleich* wirkt (gleiche Farbe absorbiert Beschuss, Gegenfarbe schadet) — hohe Bedeutungsdichte pro Knopfdruck. Bezeichnend: Housemarque berichtet im Postmortem, dass Outland ohne die nachträglich eingebaute Ikaruga-Mechanik "vielleicht nie fertig geworden wäre" — der Zustandswechsel wurde erst durch echte Konsequenzen tragfähig. **Giana Sisters: Twisted Dreams** koppelt den Wechsel an eine Welt-Transformation, **Guacamelee** an zwei Ebenen mit je eigenen Gegnern. Fazit: Der Toggle braucht **mehrere gleichzeitige Konsequenzen** (Tempo, Sichtbarkeit für "Lauscher", Andockfähigkeit, Gewicht) und muss **mit anderen Systemen kombinierbar** sein.

**Drei Zusatzmechaniken (gestaffelt eingeführt):**
1. **Karte stecken (ab Welt 2):** eGK/SMC-B als Schalter, der Tore/Sessions öffnet — verbindet Bewegung mit Identität.
2. **Signatur-Stempel (ab Welt 3):** eine Aktion, die Objekte "echt/gültig" macht (z. B. Plattformen aktiviert) — bewusst getrennt von der Hülle, um Verschlüsselung ≠ Signatur zu vermitteln.
3. **Berechtigungs-/Zero-Trust-Pforten (ab Welt 4):** Prüfpunkte, die Zustand *und* Identität *und* Frische der Sitzung (Kontextschlüssel) gleichzeitig prüfen.

#### 2.2 Level-Design-Handwerk **[Design, gestützt auf Level Design Book / GDC-Praxis]**
- **Character Metrics zuerst:** Figurgröße, Sprunghöhe/-weite in Kacheln als Grundmaß festlegen (Vorschlag: Figur 1×2 Kacheln, Sprunghöhe 4 Kacheln, Sprungweite 5 Kacheln). Faustregel: nie eine Pflichtlücke über die maximale Reichweite; präzise ("hard metrics") Platformer erfordern strenge Einhaltung, "soft metrics" (großzügiges Klettern) toleranter.
- **Tile-Grid + Greybox/Blockout:** erst graue Kästen, Metriken im "Gym"/Testraum prüfen, dann Art — spart Zeit und deckt unspielbare Sprünge früh auf.
- **Regel der Drei:** ein Motiv max. drei Mal pro Sequenz.
- **Gegnerplatzierung als Lehrmittel:** neue Bedrohung erst gefahrlos zeigen (Introduce), dann fordern.
- **Kamera/Sichtlinien/Lesbarkeit:** Gefahr immer im Bild; konsistente Farb-/Formsprache (Klartext = warm/hell, Verschlüsselt = kühl/dunkel + eigenes Muster, VAU = markanter dritter Farbton).
- **Checkpointdichte:** großzügig (Celeste/Super-Meat-Boy-Prinzip: schnelle Retrys), gegen Levelende sparsamer.
- **Schwierigkeitskurve über das Gesamtspiel** als Sägezahn: jede neue Welt startet leichter und steigert sich.

#### 2.3 Levelliste (26 Level + 4 Nebenlevel) **[Design]**
*Jede Welt folgt der 4-Schritte-Methode; Mechanik-Progression additiv.*

**Welt 1 — Die Praxis (Makro-Introduce; Palette warm)**
| Nr | Titel | Mechanik | Kernidee / TI-Lernziel | Dauer | Schw. |
|---|---|---|---|---|---|
| 1 | Erster Befund | Bewegung/Sprung | Ein Befund entsteht im Primärsystem | 3 Min | sehr leicht |
| 2 | Die Hülle | Toggle Klartext/Verschlüsselt | Vertraulichkeit vs. Tempo | 4 Min | leicht |
| 3 | Lauscher | Toggle + Gegner, die nur Klartext "sehen" | Sichtbarkeit unverschlüsselter Daten | 5 Min | leicht |
| 4 | Das Kartenterminal (Twist) | Toggle + erstes Kartenstecken | Identifikation per Karte | 5 Min | mittel |
| 5 | Raus aus der Praxis (Concl.) | alles kombiniert | Weg in die Zugangszone | 5 Min | mittel |

**Welt 2 — Der Zugang (Makro-Develop; Palette kühler)**
| 6 | Der Konnektor | Karte stecken vertieft | Gatekeeper/VPN | 5 Min | mittel |
| 7 | VPN-Tunnel | Hülle im Tunnel | Transportsicherheit | 5 Min | mittel |
| 8 | SMC-B | Institutionsidentität | Einrichtung authentisiert sich | 5 Min | mittel |
| 9 | Verzeichnisdienst (Twist) | Adress-Suche schaltet Wege | VZD als Adressbuch | 6 Min | mittel |
| 10 | KIM | Verschlüsselt + Signatur-Vorschau | E2EE + signiert | 6 Min | mittel+ |
| 11 | Ankunft zentrale Zone (Concl.) | Kombi | Übergang ins zentrale Netz | 6 Min | mittel+ |

**Welt 3 — Die zentrale Zone (Develop → Twist-Vorstufe; Palette Cloud/hell-technisch)**
| 12 | Der Fachdienst | Signatur-Stempel neu | Echtheit von Objekten | 6 Min | mittel+ |
| 13 | E-Rezept | eGK als Schlüssel in der Apotheke | Einlösung | 6 Min | mittel+ |
| 14 | Die VAU | dritter Zustand | Klartext und trotzdem sicher | 7 Min | schwer- |
| 15 | Kontextschlüssel (Twist) | Zustand + Session-Frische | VAU ist sitzungsgebunden | 7 Min | schwer- |
| 16 | TI-Messenger | Föderationsgrenzen | Matrix/E2EE-Föderation | 7 Min | schwer- |
| 17 | Zugriffsprotokoll (Concl.) | "Lückenloses Protokoll" | Transparenz/Nachvollziehbarkeit | 7 Min | schwer |

**Welt 4 — Der Umbau: TI 2.0 (Makro-Twist der ganzen Story; Palette Baustelle)**
| 18 | Baustelle | Kulissenwechsel | TI-Gateway/HSK verlagern den Konnektor | 6 Min | mittel |
| 19 | Zero Trust | Prüfpforten (Zustand+ID+Frische) | "Prüfe alles" | 8 Min | schwer |
| 20 | mTLS | beidseitige Prüfung | gegenseitige Authentisierung | 8 Min | schwer |
| 21 | RSA→ECC (Twist) | schwere alte vs. leichte neue Schlüssel | Krypto-Migration | 8 Min | schwer |
| 22 | Der Konnektor verschwindet (Concl.) | Kombi | Hardware entfällt, Funktion bleibt | 8 Min | schwer |

**Welt 5 — Die Akte (Makro-Conclusion/Auflösung; Palette ruhig, warm-hell)**
| 23 | Das Aktensystem | alles kombiniert | ePA als geschützter Speicher | 7 Min | schwer- |
| 24 | Berechtigungen | Türen, die nur die Versicherte öffnet | Berechtigungsmanagement | 8 Min | mittel+ |
| 25 | Die letzte Tür (Twist) | Perspektivumkehr | Die Versicherte entscheidet (Opt-out/Datenhoheit) | 8 Min | mittel |
| 26 | Souveränität (Concl.) | ruhiges Finale | Datensouveränität | 6 Min | leicht |

**Nebenlevel:** N1 Notfalldaten (NFDM), N2 Medikationsliste (eML), N3 Europa (MyHealth@EU), N4 Das Protokoll (Speedrun/Archiv).

#### 2.4 Beat-Sheets (drei Schlüssellevel) **[Design]**

**Level 2 "Die Hülle" (Anfang) — Introduce**
- **0:00–0:20 Ki:** sichere Fläche, Toggle-Prompt erscheint; Spieler probiert Klartext (schnell/leicht) ↔ Verschlüsselt (schwer/langsam), kein Risiko.
- **0:20–1:30 Shō:** erste "Lauscher"-Zone: als Klartext gesehen = zurück zum Checkpoint (kein Tod, sofortiger Retry); ein hohes Hindernis erzwingt zugleich die Leichtigkeit des Klartext-Zustands — erster Zielkonflikt.
- **1:30–2:30 Ten:** eine bewegliche Andockplattform akzeptiert **nur** Klartext — der Spieler muss riskant sichtbar werden und das Timing mit dem Lauscher-Blick treffen.
- **2:30–3:30 Ketsu:** Kombiraum, beide Zustände in Folge; Checkpoint direkt vor dem Ausgang; erste "Prüfsumme" versteckt hinter einer Verschlüsselt-Passage.
- **Pacing:** ruhig → fordernd → Spitze bei ~2:00 → Entlastung. **Checkpoints:** 0:20, 1:30, 2:30.

**Level 14 "Die VAU" (Mitte) — Develop**
- **0:00–0:30 Ki:** VAU-Feld eingeführt (markanter dritter Farbton): innen ist man Klartext-schnell **und** unsichtbar.
- **0:30–2:00 Shō:** Ketten von VAU-Feldern mit Lücken, in denen man wieder zwischen Klartext/Verschlüsselt wählen muss; lehrt: VAU ist lokal/begrenzt, nicht überall.
- **2:00–3:30 Ten:** ein VAU-Feld erlischt nach Zeit (Kontextschlüssel-Metapher) — der Spieler muss die Sitzung "frisch" halten, indem er Anker/Checkpoints trifft.
- **3:30–5:00 Ketsu:** Kombination aus Stecken + VAU + Signatur; zwei versteckte Ausgänge.
- **Gegner:** "Betreiber-Augen", die außerhalb der VAU sehen, innerhalb nicht (vermittelt: Betreiber hat keinen Zugriff auf VAU-Inhalte). **Checkpoints:** 0:30, 2:00, 3:30.

**Level 21 "RSA→ECC" (Twist-Akt) — Twist**
- **0:00–0:30 Ki:** Der Spieler trägt einen "schweren RSA-Schlüssel" (verlangsamt Sprung/Weite).
- **0:30–2:00 Shō:** Passagen, die mit dem schweren Schlüssel gerade so machbar sind; Frust bewusst dosiert.
- **2:00–3:00 Ten:** eine Umbaustation tauscht auf den "leichten ECC-Schlüssel" — dieselben Passagen jetzt elegant; ein Stichtags-Gate (Motiv 29.06.2026) schließt hinter dem Spieler.
- **3:00–4:30 Ketsu:** neue Beweglichkeit meistern; eine Zero-Trust-Pforte am Ende prüft Zustand + ID + ECC.
- **Lernziel bewusst über Körpergefühl** (leicht vs. schwer) statt Text. **Checkpoints:** 0:30, 2:00, 3:00.

#### 2.5 Weltfinale (prüfen die Lernidee, nicht nur Reflexe) **[Design]**
- **W1 "Lauscher-König":** muss im richtigen Zustand passiert werden — prüft, ob "sichtbar vs. sicher" verstanden ist.
- **W2 Gatekeeper-Konnektor:** nur mit korrekter Karte + aufgebautem Tunnel passierbar.
- **W3 VAU-Wächter:** der Spieler muss beweisen, dass Klartext *innen* sicher ist (Betreiber-Augen ausmanövrieren).
- **W4 Migrations-Boss:** wechselt zwischen RSA/ECC-Phasen; der Spieler muss den Schlüsseltausch timen.
- **W5:** kein klassischer Boss — die Versicherte öffnet die Tür; der "Kampf" ist eine Entscheidung.

#### 2.6 Erzählstruktur ohne Textwände **[Design]**
Environmental Storytelling durch die Kulissenreise (Praxis → Netz → Cloud → Baustelle → Akte), Farbdramaturgie (jede Welt eigene Palette), ein wiederkehrendes Motiv (der Befund-Charakter wird zunehmend "souveräner", z. B. aufrechtere Haltung/Farbe), und Musik, die in Welt 5 zur Ruhe kommt. Die Schlusspointe (Datensouveränität) trägt, weil das Spiel die Perspektive umkehrt: Der Spieler war die ganze Zeit ein *Datenpaket*, das durch fremde Systeme gereicht wurde — am Ende entscheidet nicht das System, sondern die Versicherte, ob und wer die letzte Tür öffnet. Vorbilder für eine tragende Perspektivumkehr am Ende sind Spiele, die die Deutungs-/Kontrollhoheit im Finale umdrehen; wichtig ist, die Pointe *zeigen statt erklären* (die Tür-Interaktion selbst ist die Botschaft), damit sie nicht belehrend wirkt.

#### 2.7 Wiederspielwert / Meta-Progression **[Design]**
- **Siegel/Ränge:** pro Level bis zu 3 Siegel im "Zugriffsprotokoll" (durchgespielt / alle Prüfsummen / "Lückenloses Protokoll" = nie gesehen worden).
- **Zeitziele:** optionale Bestzeiten je Level, getrennte Bestenliste (Speedrun-Schicht).
- **Versteckte Ausgänge / Nebenlevel:** je Welt ein Geheimausgang, der ein Nebenlevel freischaltet.
- **Archiv/Kompendium:** jede gesammelte Prüfsumme schaltet eine fachlich korrekte, quellenbelegte Erklärkarte frei — hier lebt der "trockene" Stoff (PKI, DiPag, MyHealth@EU, Föderation), ohne die Level zu überfrachten.
- **Assist-Modus:** langsamere Spielzeit, mehr Checkpoints, "unsichtbar bleiben" optional deaktivierbar.
- **Anti-Fleißarbeit:** Sammelziele sind *sinntragend* (jede Prüfsumme = ein Wissensbaustein), kein 100-Münzen-Grind; das Kompendium ist auch ohne 100 % nutzbar, und Siegel sind unabhängig voneinander erreichbar (kein "alles-oder-nichts").

---

### TEIL 3 — UX UND ONBOARDING

#### 3.1 UX-Ablauf (Beat für Beat) **[Design]**
- **Erste 5 Sek:** kein Menü-Wall — direkt ein spielbarer Befund auf sicherer Fläche (senkt Einstiegshürde, erzeugt sofort Spielgefühl).
- **Erste Minute:** Bewegung + Toggle intrinsisch gelernt (kein Texttutorial; Lernen durch Tun — intrinsische Integration nach Habgood & Ainsworth, vermeidet "chocolate-covered broccoli").
- **Erste 10 Min:** Welt 1 abgeschlossen, erstes "Zugriffsprotokoll", erstes Aha ("ich war sichtbar").
- **Ende Session 1:** Weltkarte zeigt Welt 2 offen + erste Kompendiumkarte als Belohnung.
- **Session 2/3:** Rückkehr über Weltkarte, neue Mechanik als Pull; Bestzeiten/Siegel motivieren Wiederholung.

#### 3.2 UI-Screens **[Design]**
- **Titel/Start:** ruhiges Bild, ein Button "Start"; Disclaimer/Impressum klein am Rand. Zweck: kein Overhead. Prinzip: eine primäre Aktion.
- **Weltkarte:** die fünf Zonen als Reise dargestellt, Fortschritt/Siegel sichtbar. Zweck: Orientierung + Progression. Prinzip: räumliche Metapher = TI-Struktur.
- **In-Game-HUD (minimal):** nur Zustandsanzeige (Klartext/Verschlüsselt/VAU, zusätzlich über Form/Muster) + Prüfsummen-Zähler; **keine Lebensleiste** (Retry-Modell). Zweck: Fokus aufs Spielfeld.
- **Pausenmenü:** Fortsetzen / Optionen / Level neustarten. Prinzip: schnell weg und zurück.
- **Level-Abschluss "Zugriffsprotokoll":** wer hat wann worauf zugegriffen (in-fiction), erreichte Siegel, Zeit. Zweck: Belohnung + fachliches Motiv (echtes ePA-Zugriffsprotokoll).
- **Archiv/Kompendium:** freigeschaltete Erklärkarten mit Quellenverweis. Prinzip: optionale Tiefe.
- **Optionen/Assist:** Remapping, Farbmodi, reduzierte Bewegung, Untertitel, Schwierigkeit.
- **Bestenliste:** pro Level und gesamt.

#### 3.3 Steuerung & Barrierefreiheit **[Design]**
- **Desktop/Tastatur:** Pfeile/WASD Bewegung, Space/Up Sprung (variable Höhe, Coyote Time, Input Buffering), Umschalt/Shift Toggle, E Aktion.
- **Gamepad:** A Sprung, X Toggle, B Aktion, Stick/Steuerkreuz Bewegung.
- **Touch/Mobile:** linke Bildschirmhälfte Bewegung, rechte Sprung/Toggle/Aktion; großzügige Trefferflächen.
- **Barrierefreiheit:** Zustände zusätzlich über **Form/Muster** (nicht nur Farbe) für Farbfehlsichtigkeit; vollständiges Remapping; "reduzierte Bewegung" (weniger Screenshake/Parallaxe); Untertitel für Audio-Hinweise; Assist-Schwierigkeit (mehr Checkpoints, Zeitlupe).

#### 3.4 Die ersten fünf Sekunden **[Design]**
Kurze Schwarzblende → der Befund-Charakter materialisiert im Klartext-Zustand auf einer sicheren Fläche in der Praxis-Kulisse; ein sanft pulsierender Toggle-Hinweis blinkt. **Warum:** sofortiges Spielgefühl statt Menü, Neugier auf den Zustandswechsel, keine kognitive Last durch Text — die erste Handlung des Spielers ist bereits die Kernmechanik.

---

### TEIL 4 — PRODUKTION UND VALIDIERUNG

#### 4.1 Scope/Aufwand (kleines Team) **[Design]**
- **Phase 0 – Vertikale Scheibe (4–6 Wochen):** Welt 1 komplett spielbar, Kernmechanik + eine Zusatzmechanik, Game Feel poliert. **Abbruch-/Pivot-Kriterium:** Wenn der Toggle im Laien-Playtest nicht "klickt" (<80 % verstehen "sichtbar vs. sicher"), Mechanik überarbeiten, bevor irgendetwas skaliert wird.
- **Phase 1 – Prototyp aller Mechaniken (2–3 Monate):** je ein Level pro Mechanik, Progression prüfen.
- **Phase 2 – Content (2–3 Monate):** restliche Level, Art-Pass, Audio.
- **Phase 3 – Politur/Playtest/Barrierefreiheit (1–2 Monate).**
- **Pivot bei Zeitdruck:** Levelzahl von 26 auf ~15 kürzen (je Welt 3 Level: Introduce/Twist/Conclusion), Nebenlevel streichen, Kompendium behalten (billig, hoher Lernwert).

#### 4.2 Engine-Empfehlung **[Design]**
- **Empfehlung: Godot 4** (MIT-Lizenz, kostenlos). Starker 2D-Editor, **HTML5/WebAssembly-Export → installationsfreie Verteilung im Browser** möglich, Wachstumspfad zu Desktop/Mobile. Passt zur Nebenbedingung "browserbasiert, ohne Installation".
- **Phaser** (JS/HTML5): für **reines Web-2D** technisch leichter, kleinere/schnellere Builds, ideal zur Einbettung in eine bestehende Firmen-Web-App (React/Vue etc.). Alternative, wenn Verteilung ausschließlich im Browser und Integration in vorhandene Web-Frontends gefordert ist.
- **Unity:** mächtig, aber schwerere WebGL-Builds — für dieses 2D-Projekt Overhead. **GDevelop:** sehr schnell/no-code, aber weniger tief bei feinem Game Feel.
- **Entscheidungsregel:** Muss es zwingend in eine bestehende Web-App eingebettet werden? → **Phaser.** Soll es eigenständig laufen und evtl. später nativ? → **Godot.**

#### 4.3 Asset-/Audio-Strategie bei kleinem Budget **[Design]**
- Konsequenter Tile-/Modul-Kit-Ansatz (wenige Sprites, hohe Wiederverwendung — wie klassisch NES-Levels).
- Flat-/Silhouetten-Stil (wie Outland) kaschiert kleines Budget und maximiert Lesbarkeit der Zustände.
- Lizenzfreie/CC-Musik oder Chiptune; ein wiedererkennbares Leitmotiv pro Welt; Sounddesign priorisiert (billig, hoher Game-Feel-Effekt).

#### 4.4 Playtesting & Wirkungsmessung **[Design, gestützt auf Serious-Games-Forschung]**
- **Wann/wer:** Phase 0 mit 3–5 TI-Laien (Verständlichkeit) + 2 TI-Experten (fachliche Korrektheit); ab Phase 2 breiter (10–20 Personen der Zielgruppe).
- **Verständnis messen:** **Pre-/Post-Test** mit Multiple-Choice; Lernerfolg = Differenz Post − Pre; idealerweise **Kontrollgruppe** (klassische Folien/Text) vs. Spielgruppe. Belegte Praxis (z. B. Serious-Game-Studie zur zahnmedizinischen Ausbildung, BMC Medical Education 2023): signifikante Pre-/Post-Verbesserung in beiden Gruppen, Lerneffekt oft *ähnlich* wie klassisches Lernen, aber **höhere Motivation und längere Beschäftigung mit dem Stoff** — das ist der realistische Zielnutzen, nicht "spielerisch mehr Wissen als Frontalunterricht".
- **Beobachtungsprotokoll:** wo entsteht Frust, wo das Aha; laut denken lassen (Think-Aloud).
- **Telemetrie:** Retry-Zahl pro Abschnitt, Toggle-Häufigkeit, Abbruchpunkte, Kompendium-Öffnungen, Level-Zeit; standardisierbar über Experience-API-artige Lern-Analytics (Serious-Games-Literatur zeigt: Post-Test-Wissen lässt sich aus solchen Interaktionsdaten vorhersagen).
- **Verständnisfragen direkt an Lernziele koppeln**, z. B.: "Kann der Betreiber die Daten in der VAU lesen?" (Antwort: nein), "Wozu dient die eGK beim E-Rezept?" (Schlüssel, nicht Speicher), "Was bedeutet Zero Trust?" (jeder Zugriff wird geprüft).

#### 4.5 Recht & Marke **[TI-Fakt, Quelle: gematik Impressum, Markenleitfaden E-Rezept, Mediathek, GitHub]**
- **gematik-Texte/Fotos sind urheberrechtlich geschützt:** "Das Kopieren dieser Dateien und ihre evtl. Veränderung sind daher ohne Genehmigung des Rechteinhabers … nicht gestattet." (gematik.de/impressum). Ausnahme: Pressemitteilungen sind frei weiterverwendbar.
- **"E-Rezept" ist eine Produktmarke der gematik:** unveränderte Nutzung zur Aufklärung ist ohne Genehmigung erlaubt, aber "eine Veränderung oder Nachahmung der Marke (bspw. Form oder Farben) ist nicht gestattet"; **werbliche Nutzung nur mit vorheriger schriftlicher Genehmigung** (gematik-Markenleitfaden E-Rezept, Stand 02/2025). Für "KIM" existiert kein eigener Markenleitfaden (KIM = Anwendung "Kommunikation im Medizinwesen"); bei "GesundheitsID" ist die Markenanmeldung laut gematik noch nicht abgeschlossen.
- **Logo:** redaktionelle Nutzung nicht für kommerzielle/Werbezwecke; Quellenvermerk "gematik GmbH" erforderlich (gematik-Mediathek).
- **Spezifikationen/Code auf GitHub** überwiegend **Apache License 2.0** ("Copyright … gematik GmbH · Apache License, Version 2.0") → für ein Lernspiel als fachliche Referenz nutzbar, Lizenzbedingungen (Namensnennung, Haftungsausschluss) beachten. Kontakt für OSS-Fragen: ospo@gematik.de.
- **Empfehlung:** Das Spiel als **eigenständiges, klar als inoffiziell gekennzeichnetes Werk** aufsetzen ("Kein Produkt der gematik; dient der Wissensvermittlung"), **keine gematik-Logos oder geschützten Produktmarken im Branding**, TI-Begriffe generisch/erklärend verwenden. Vor öffentlicher Veröffentlichung Rücksprache mit gematik und ein DPMA-Markencheck zu den verwendeten Begriffen.

---

## Recommendations
1. **Zuerst die vertikale Scheibe (Welt 1) bauen** und die Hülle-Mechanik im Laien-Playtest verifizieren. **Benchmark:** ≥ 80 % der Tester verstehen "sichtbar vs. sicher" ohne Text und wechseln den Zustand freiwillig sinnvoll. Wird das verfehlt → Mechanik überarbeiten, nicht Content produzieren.
2. **Fachreview früh ansetzen:** mit 2 TI-Experten die vier Vereinfachungsfehler (VAU-Tunnel, Zero Trust, Verschlüsselung/Signatur, ePA-Rechte) prüfen, **bevor** Content skaliert. Änderungskosten steigen mit jedem gebauten Level.
3. **Engine-Entscheidung an die Verteilung koppeln:** zwingende Einbettung in eine Firmen-Web-App → Phaser; sonst → Godot 4 (Web-Export + Wachstumspfad).
4. **Kompendium als Fakten-Anker** nutzen: der belegte, "trockene" Stoff (PKI, DiPag, MyHealth@EU, Föderation, RU/TU/PU) lebt dort korrekt und quellenbelegt, ohne die Level zu überfrachten.
5. **Wirkung sauber messen:** Pre-/Post-Test mit Kontrollgruppe; realistisches Ziel ist **signifikanter Wissenszuwachs bei deutlich höherer Motivation** gegenüber Folien — nicht "das Spiel schlägt jeden anderen Lernweg".
6. **Rechtssicher auftreten:** Disclaimer "inoffiziell", keine geschützten Marken/Logos im Branding, vor Publikation gematik-Rücksprache + DPMA-Check.
7. **Scope diszipliniert halten:** bei Terminrisiko auf ~15 Kernlevel (je Welt Introduce/Twist/Conclusion) reduzieren, statt Qualität/Game Feel zu opfern.

**Offene Entscheidungen, die der Nutzer treffen muss:**
- Zielplattform: reine Browser-Einbettung (→ Phaser) oder eigenständig/nativ-fähig (→ Godot)?
- Zielgruppe primär interne Schulung (Berater/IT) oder öffentliche Awareness (Versicherte)? Das verschiebt Ton, Tiefe und Marken-Risiko.
- Verbindlicher Umfang: 26 Level (Vollversion) vs. 15 Level (schlanker Kern)?
- Offizieller Kontakt zur gematik anstreben (Kooperation/Freigabe) oder bewusst inoffiziell bleiben?
- Budget für Audio/Art: eigenes Sounddesign vs. reine CC-Assets?

## Caveats
- **Zukunftsangaben (geplant, nicht abgeschlossen):** VSDM 2.0 / Zero-Trust-Produktivstart ab Juli 2026 (Parallelbetrieb VSDM1/VSDM2 ab Sept. 2026), vollständige TI-Umstellung bis 2029; RSA-Abschaltung ab 29.06.2026; DiPag-Produktivstart "für Ende 2026 geplant"; ePrescription "Country A" 2026. Im Spiel/Kompendium als Planung kennzeichnen.
- **ePA entwickelt sich weiter** (3.0/3.1/3.1.3); Detailfunktionen (Zugriffs-Benachrichtigungen, Forschungsdatenausleitung ans FDZ Gesundheit) kommen gestaffelt — Erklärkarten mit Versionsdatum versehen.
- **Marken-/DPMA-Status** einzelner Begriffe (z. B. GesundheitsID) ist teils noch offen; vor Veröffentlichung prüfen.
- **Betroffenheitszahlen** der RSA→ECC-Migration variieren je Sektor (laut ABDA z. B. allein in Apotheken rund 7.500 HBA und 2.500 SMC-B) — als Größenordnung, nicht als Gesamtzahl verstehen.
- **Alle Level-, Scope-, Zeit- und Metrikangaben** sind Designvorschläge des Autors, keine belegten Fakten; sie sind im Playtest zu validieren.
- Einzelne Sekundärquellen (Fachpresse, KV-Seiten) wurden zur verständlichen Einordnung genutzt; im Zweifel gilt die jeweils primäre gematik-Quelle.