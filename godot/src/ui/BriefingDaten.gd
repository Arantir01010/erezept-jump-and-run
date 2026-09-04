class_name BriefingDaten
## BRIEFINGDATEN — Inhalte der Stations-Briefings, getrennt vom Code (Briefing.gd):
## Untertitel, Erklärzeilen, Handgriffe, Schilder und Rufe der Mini-Szene sowie
## die Namen der Bausteine. Fachliche Leitplanken: KAPSEL 1.4, KONZEPT 10.4,
## EPA-WISSENSPFAD — VAU = Raum, Verschlüsselung ≠ Signatur, abgelaufene Sitzung
## fällt in den Klartext, die eGK speichert nichts, Angreifer scheitern immer.
##
## Platzhalter in Texten: {lauf} {jump} {action} {toggle} {duck} {hoch} — werden je
## nach erkannter Hardware (Tastatur / Arcade / Touch) aus Kiosk.label_*() ersetzt.
##
## Koordinaten der Schilder/Rufe liegen im 640×360-Design-Raum; der Bühnenboden
## der Mini-Szene ist y = 250 (Briefing.GY).
##   schilder: [x, y, text, größe, farbe, buchstabenabstand]      — dauerhaft
##   rufe:     [x, y, text, größe, farbe, von, bis]               — im Szenen-Takt

const TAKT := 4.6

const WEISS := 0xeef2f8
const GRUEN := 0x7fd07f
const ROT := 0xff6b5e
const GOLD := 0xffd75e
const KUEHL := 0x4de3ff
const VIOLETT := 0xb9a6ff
const WARM := 0xffb070
const MATT := 0x9fb0cc
const SMCB := 0x8ca6f2

## Reihenfolge der Bausteine in der Leiste (Kernmechanik zuerst, Grundbausteine zuletzt).
const REIHENFOLGE := [
	"huelle", "lauscher", "andock-plattform", "vau-feld", "kontext-anker",
	"karte", "kartenleser", "timing-gate", "stillstand-podest", "krypto-dusche",
	"deny-enemy", "stamp-exit", "letzte-tuer", "gate", "tube-scroll",
	"moving-platform", "spring", "spike", "hazard", "collectible", "bonus",
	"checkpoint", "door-exit",
]

const BAUSTEINE := {
	"huelle": "Hülle", "lauscher": "Lauscher", "andock-plattform": "Andock-Plattform",
	"vau-feld": "VAU-Feld", "kontext-anker": "Kontext-Anker", "karte": "Karte",
	"kartenleser": "Kartenleser", "timing-gate": "PIN-Schleuse", "stillstand-podest": "Prüf-Podest",
	"krypto-dusche": "Krypto-Dusche", "deny-enemy": "Kralle", "stamp-exit": "Stempel",
	"letzte-tuer": "Letzte Tür", "gate": "Tor", "tube-scroll": "Tunnel-Fahrt",
	"moving-platform": "Pendel-Plattform", "spring": "Feder", "spike": "Störfeld",
	"hazard": "Schadenszone", "collectible": "Prüfsumme", "bonus": "Bonus",
	"checkpoint": "Fahne", "door-exit": "Tür-Ausgang",
}

const STATIONEN := {
	"01-stammdaten": {
		"key": "01", "szene": 14.6,
		"untertitel": "Beim Arzt wird deine Gesundheitskarte online bei der Kasse geprüft.",
		"zeilen": [
			"Du steckst die eGK ins Terminal — die TI fragt online bei der Kasse: gültig? aktuell?",
			"Erst dann schreibt der Arzt dein E-Rezept — digital im Praxissystem, nie auf der Karte.",
			"Im Spiel: {lauf} laufen, {jump} springen, leuchtende Prüfsummen einsammeln.",
			"Am Terminal {action} im Takt der Lichter drücken — dann öffnet das Tor.",
			"Feder = hoch hinaus · rotes Störfeld = kostet nur Bits · Fahne = dein Rücksetzpunkt.",
		],
		"tust": "{lauf} laufen · {jump} springen (2× = REZI-Schub) · {action} im Takt am Terminal · Tür öffnet ab 8 Prüfsummen",
		"schilder": [
			[520, 177, "KRANKENKASSE", 5, WEISS, 0.8],
			[150, 229, "ANMELDUNG", 3.6, MATT, 0.5],
		],
		"rufe": [
			[520, 208, "KASSE PRÜFT", 3.8, KUEHL, 4.2, 5.9],
			[178, 200, "DATEN AKTUELL", 4.6, GRUEN, 7.3, 10.4],
			[445, 214, "FAHNE = RÜCKSETZPUNKT", 3.4, GRUEN, 12.9, 14.4],
		],
	},
	"02-kartenterminal": {
		"key": "02", "szene": 16.4,
		"untertitel": "Der Arzt unterschreibt dein Rezept digital — mit Ausweis und PIN.",
		"zeilen": [
			"Der Arzt steckt seinen Heilberufsausweis (HBA) und tippt seine PIN: Besitz plus Wissen.",
			"Das ergibt die qualifizierte Signatur: Beweis der Echtheit — nicht Verschlüsselung.",
			"Im Spiel: {action} im Takt der Lichter = PIN-Prüfung. Zu früh? Einfach wiederholen.",
			"Die Kralle greift auf Kopfhöhe: {duck} = ducken. Die TI sperrt den Fake-Leser aus.",
			"Zum Schluss der Stempel: warten, bis er OBEN kurz steht — dann {action}. Signiert!",
		],
		"tust": "{duck} ducken unter der Kralle · {action} im Takt der PIN-Lichter · unter dem Stempel warten, oben: {action}",
		"schilder": [
			[143, 217, "KRIECHGANG", 3.4, MATT, 0.5],
			[290, 205, "ARZT-PIN", 3.8, MATT, 0.6],
			[318, 229, "DR. PIXEL", 3.4, MATT, 0.4],
			[440, 196, "SIGNATUR-STEMPEL", 3.8, GOLD, 0.6],
		],
		"rufe": [
			[196, 219, "ZUGELASSEN", 3.4, GRUEN, 4.9, 7.6],
			[160, 205, "ZUGRIFF VERWEIGERT", 4.4, ROT, 5.1, 7.4],
			[290, 196, "PIN OK", 4.6, GRUEN, 10.9, 12.8],
			[440, 184, "SIGNIERT", 6, GOLD, 13.9, 16.2],
		],
	},
	"03-kov-gateway": {
		"key": "03", "szene": 16.0,
		"untertitel": "Der Weg von der Praxis in die TI führt durch ein bewachtes Tor.",
		"zeilen": [
			"Die Praxis hängt nicht am offenen Internet: Der TI-Zugang prüft, wer hinein will.",
			"Nur ausgewiesene Einrichtungen kommen durch — dahinter reist alles verschlüsselt.",
			"Im Spiel: Auf dem Podest stillstehen, bis der Scan durch ist. Die Krake bleibt draußen.",
			"In der Krypto-Dusche {action}: Verschlüsselung anlegen. Ab jetzt liest niemand mit.",
			"Im Tunnel fährt es von selbst — {hoch} lenkt. Drinnen kann dir nichts passieren.",
		],
		"tust": "Podest: {lauf} loslassen und warten · Krypto-Dusche: {action} · Tunnel: {hoch} · Prüfsummen sammeln",
		"schilder": [
			[190, 203, "TI-ZUGANG", 4, KUEHL, 0.8],
			[270, 203, "KRYPTO-DUSCHE", 3.6, KUEHL, 0.5],
			[445, 203, "VPN-TUNNEL", 4, KUEHL, 0.8],
		],
		"rufe": [
			[150, 226, "GEPRÜFT", 4, GRUEN, 2.7, 4.4],
			[128, 211, "ZUGRIFF VERWEIGERT", 4.2, ROT, 4.0, 6.2],
			[270, 195, "VERSCHLÜSSELT", 4.6, KUEHL, 5.7, 7.8],
		],
	},
	"04-die-huelle": {
		"key": "04", "szene": 18.0,
		"untertitel": "Unverschlüsselt liest jeder mit — verschlüsselt sieht man nur Zeichensalat.",
		"zeilen": [
			"Unterwegs im Netz gilt: Was unverschlüsselt reist, kann jeder Lauscher lesen.",
			"Verschlüsselt sieht er das Paket zwar — aber nur Zeichensalat. Er scheitert.",
			"{toggle} = Hülle wechseln. Klartext: schnell, sichtbar. Verschlüsselt: langsam, unsichtbar.",
			"Die goldene Andock-Plattform trägt nur Klartext: kurz sichtbar werden, schnell rüber.",
			"Violettes VAU-Feld: drinnen Klartext UND unsichtbar. Der Anker hält die Sitzung frisch.",
		],
		"tust": "{toggle} Hülle an/aus · vor dem Lauscher verschlüsseln · auf der Plattform Klartext · {jump} springen",
		"schilder": [
			[466, 207, "VAU", 5.5, VIOLETT, 1.0],
			[355, 253.5, "ANDOCK-PLATTFORM", 3.2, GOLD, 0.4],
		],
		"rufe": [
			[172, 206, "MITGELESEN!", 4.8, ROT, 1.1, 2.6],
			[210, 205, "?", 6, WEISS, 2.7, 3.9],
			[315, 205, "?", 6, WEISS, 4.0, 5.2],
			[355, 224, "TRÄGT NUR KLARTEXT", 3.4, GOLD, 5.3, 6.1],
			[475, 199, "SITZUNG FRISCH", 4, VIOLETT, 9.7, 11.0],
			[560, 205, "?", 6, WEISS, 10.6, 11.8],
		],
	},
	"05-identitaet": {
		"key": "05", "szene": 15.0,
		"untertitel": "Drei Karten, drei Rollen — und jede öffnet nur ihre eigene Tür.",
		"zeilen": [
			"eGK = du als Versicherte:r. HBA = der Arzt als Person. SMC-B = die Praxis als Einrichtung.",
			"Die eGK weist dich aus — mehr nicht. Dein Rezept und deine Akte liegen nie auf ihr.",
			"Im Spiel: Karten liegen am Weg. Einfach durchlaufen — sie bleiben bei dir.",
			"Am Terminal {action}: Das Spiel steckt die passende Karte. Falsche Karte? Nur ein Nein.",
			"Dazwischen Lauscher: {toggle} verschlüsselt dich. Die Andock-Plattform will Klartext.",
		],
		"tust": "Karten einsammeln: durchlaufen · Terminal: {action} · {toggle} Hülle · {jump} springen",
		"schilder": [
			[150, 233.5, "eGK", 3.2, GRUEN, 0.3],
			[330, 233.5, "SMC-B", 3.0, SMCB, 0.2],
			[290, 211, "PRAXIS", 3.4, MATT, 0.5],
		],
		"rufe": [
			[110, 226, "eGK ✓", 4.2, GRUEN, 1.2, 2.6],
			[150, 200, "eGK GESTECKT", 4.2, GRUEN, 2.5, 4.0],
			[250, 205, "?", 6, WEISS, 4.8, 6.2],
			[330, 198, "ZUGRIFF VERWEIGERT", 4.6, ROT, 6.9, 8.6],
			[330, 206, "die eGK weist DICH aus — nicht die Praxis", 3.4, MATT, 7.2, 8.8],
			[290, 203, "SMC-B ✓", 4.2, SMCB, 10.2, 11.4],
			[330, 198, "SMC-B GESTECKT", 4.2, SMCB, 11.5, 13.0],
		],
	},
	"13-e-rezept": {
		"key": "13", "szene": 18.0,
		"untertitel": "In der Apotheke gibt deine Karte den Zugriff frei — das Rezept liegt im Fachdienst.",
		"zeilen": [
			"Apotheke: Du steckst die eGK. Das Rezept liegt im Fachdienst der TI — nie auf der Karte.",
			"Die Karte gibt nur frei: Die Apotheke holt das Rezept, der Eintrag landet in deiner ePA.",
			"Im Spiel: eGK aufsammeln, am ECHTEN Terminal {action} — das Tor zur Apotheke öffnet.",
			"Der falsche Leser hat eine Kralle: {duck} = ducken. Die TI lässt nur echte Geräte zu.",
			"Lauscher unterwegs: {toggle} verschlüsselt. Die Andock-Plattform trägt nur Klartext.",
		],
		"tust": "eGK einsammeln · echtes Terminal: {action} · Kralle: {duck} · {toggle} Hülle",
		"schilder": [
			[140, 217, "FAKE-LESER", 3.4, ROT, 0.5],
			[290, 233.5, "eGK", 3.2, GRUEN, 0.3],
			[390, 181, "APOTHEKE", 5, GOLD, 1.0],
			[480, 197, "E-REZEPT-FACHDIENST", 3.4, KUEHL, 0.4],
			[548, 197, "DEINE ePA", 3.8, KUEHL, 0.5],
		],
		"rufe": [
			[100, 226, "eGK ✓", 4.2, GRUEN, 1.0, 2.4],
			[150, 205, "ZUGRIFF VERWEIGERT", 4.4, ROT, 5.0, 6.8],
			[235, 205, "?", 6, WEISS, 5.4, 6.4],
			[290, 200, "eGK GESTECKT", 4.2, GRUEN, 6.9, 8.4],
			[480, 190, "GIBT FREI", 3.6, GRUEN, 8.4, 9.6],
			[390, 173, "REZEPT ABGERUFEN", 4.2, GRUEN, 10.9, 12.6],
			[548, 190, "EINTRAG IN DER ePA", 3.8, GRUEN, 13.6, 16.4],
		],
	},
	"14-die-vau": {
		"key": "14", "szene": 18.0,
		"untertitel": "Ein versiegelter Raum im Rechenzentrum — kein Tunnel.",
		"zeilen": [
			"Die VAU ist ein versiegelter Raum im Rechenzentrum. Drinnen wird im Klartext gearbeitet.",
			"Trotzdem sieht niemand hinein — auch nicht der Betreiber des Rechenzentrums.",
			"Im Spiel: Das violette Feld betreten. Drinnen bist du schnell UND unsichtbar.",
			"Zwischen den Feldern zählt deine eigene Hülle: {toggle}. Lauscher sehen nur Klartext.",
			"Feld mit Uhr? Läuft sie ab, bist du wieder Klartext. Der Anker frischt die Sitzung auf.",
		],
		"tust": "VAU-Feld einfach betreten · draußen {toggle} Hülle · Anker berühren · {jump} springen",
		"schilder": [
			[360, 171, "RECHENZENTRUM", 4.6, MATT, 0.8],
			[360, 188, "VAU", 5.5, VIOLETT, 1.2],
			[278, 222, "BETREIBER", 3.2, MATT, 0.4],
		],
		"rufe": [
			[150, 205, "?", 6, WEISS, 2.0, 3.0],
			[360, 160, "DRINNEN KLARTEXT — NIEMAND SIEHT HINEIN", 3.8, VIOLETT, 4.6, 7.6],
			[278, 199, "?", 6, WEISS, 5.0, 6.6],
			[565, 205, "?", 6, WEISS, 10.8, 11.8],
		],
	},
	"15-kontextschluessel": {
		"key": "15", "szene": 20.0,
		"untertitel": "Schutz gilt nicht ewig — eine abgelaufene Sitzung fällt in den Klartext.",
		"zeilen": [
			"Jede VAU-Sitzung bekommt einen eigenen Kontextschlüssel. Am Ende wird er gelöscht.",
			"Abgelaufen heißt nicht geschützt: Ohne Schlüssel bist du wieder Klartext — also sichtbar.",
			"Im Spiel: Die Uhr über dem Feld läuft, sobald du drin bist. Unter 30 % wird sie rot.",
			"Der Schlüssel-Anker im Feld frischt die Sitzung auf — berühren, dann rechtzeitig raus.",
			"Draußen wie gewohnt: {toggle} verschlüsselt. Die Andock-Plattform trägt nur Klartext.",
		],
		"tust": "im Feld den Anker berühren · Uhr im Blick · rechtzeitig raus · {toggle} Hülle · {jump} springen",
		"schilder": [
			[236, 194, "VAU", 4.4, VIOLETT, 1.0],
		],
		"rufe": [
			[150, 205, "?", 6, WEISS, 2.0, 3.0],
			[320, 170, "SITZUNG ABGELAUFEN", 4.6, WARM, 6.4, 8.4],
			[450, 206, "MITGELESEN!", 4.8, ROT, 7.1, 8.4],
			[150, 205, "?", 6, WEISS, 11.4, 12.4],
			[330, 170, "SITZUNG AUFGEFRISCHT", 4.6, VIOLETT, 14.9, 16.6],
			[470, 205, "?", 6, WEISS, 17.0, 18.2],
		],
	},
	"19-berechtigungen": {
		"key": "19", "szene": 16.4,
		"untertitel": "Deine Akte öffnet nur deine Karte — und du kannst es zurücknehmen.",
		"zeilen": [
			"Diese Türen öffnet nur deine Gesundheitskarte — kein Praxisausweis, nichts anderes.",
			"Karte gesteckt = Befugnis auf Zeit. In der ePA-App verlängerst oder entziehst du sie.",
			"Im Spiel: eGK aufsammeln, an jedem Terminal {action}. Drei Tore, dreimal dein Ja.",
			"Falsche Karte? ZUGRIFF VERWEIGERT — ohne Schaden. Lauscher: {toggle} verschlüsselt dich.",
		],
		"tust": "eGK einsammeln · an jedem Terminal {action} · {toggle} Hülle · Andock-Plattform im Klartext",
		"schilder": [
			[330, 196, "AKTENSYSTEM", 4.6, MATT, 0.8],
			[200, 212, "TÜR 1", 3.4, MATT, 0.5],
			[330, 212, "TÜR 2", 3.4, MATT, 0.5],
			[460, 212, "TÜR 3", 3.4, MATT, 0.5],
			[172, 233.5, "eGK", 3.0, GRUEN, 0.2],
			[302, 233.5, "eGK", 3.0, GRUEN, 0.2],
			[432, 233.5, "eGK", 3.0, GRUEN, 0.2],
		],
		"rufe": [
			[100, 226, "eGK ✓", 4.2, GRUEN, 1.0, 2.4],
			[286, 229, "SMC-B", 3.0, SMCB, 1.6, 2.8],
			[302, 204, "ZUGRIFF VERWEIGERT", 4.2, ROT, 2.7, 4.6],
			[200, 204, "DEINE KARTE", 4, GRUEN, 3.0, 4.6],
			[265, 205, "?", 6, WEISS, 5.0, 6.0],
			[330, 204, "NUR DEINE KARTE", 4, GRUEN, 6.9, 8.4],
			[540, 196, "ePA-APP", 3.6, KUEHL, 12.2, 15.4],
			[460, 204, "BEFUGNIS ENTZOGEN", 4.2, ROT, 13.2, 15.4],
		],
	},
	"20-souveraenitaet": {
		"key": "20", "szene": 20.0,
		"untertitel": "Am Ende entscheidet nicht das System, sondern du.",
		"zeilen": [
			"Kein Lauscher mehr, kein Tor. Nur noch der Weg — und am Ende eine Tür.",
			"Diese Tür öffnet kein Schlüssel im Spiel. Sie gehört der Person, deren Akte das ist.",
			"Im Spiel: Ruhig nach rechts, Prüfsummen sammeln, durch das VAU-Feld.",
			"An der Tür warten: Dein Zugriffsprotokoll erscheint — dann öffnet sie. Nicht du.",
		],
		"tust": "{lauf} laufen · {jump} springen · an der Tür warten — die Versicherte öffnet sie für dich",
		"schilder": [
			[430, 202, "DEINE AKTE", 5, GOLD, 1.0],
			[480, 228, "DIE VERSICHERTE", 3.2, MATT, 0.4],
			[225, 209, "VAU", 4.4, VIOLETT, 1.0],
			[104, 192, "ARCHIV", 3.4, MATT, 0.6],
		],
		"rufe": [
			[430, 188, "SIE GEHÖRT NICHT DIR", 4, MATT, 7.3, 9.4],
			[430, 170, "ZUGRIFFSPROTOKOLL", 4, WEISS, 9.6, 13.4],
			[430, 188, "FREIGEGEBEN — VON IHR", 4.6, GOLD, 13.4, 17.4],
		],
	},
}

const FALLBACK := {
	"key": "", "szene": 10.0,
	"untertitel": "Gleich geht es weiter — Paul und REZI sind bereit.",
	"zeilen": ["Lauf nach rechts, sammle Prüfsummen und lass dich von der TI schützen."],
	"tust": "{lauf} laufen · {jump} springen · {action} TI-Aktion · {toggle} Hülle",
	"schilder": [], "rufe": [],
}


static func fuer(level_id: String) -> Dictionary:
	if STATIONEN.has(level_id):
		return STATIONEN[level_id]
	return FALLBACK


static func name_of(typ: String) -> String:
	return _tr(str(BAUSTEINE.get(typ, typ)))


static func _tr(s: String) -> String:
	return str(TranslationServer.translate(s))


## Knopfnamen je nach Hardware — Quelle sind die Kiosk-Beschriftungen.
static func tokens() -> Dictionary:
	if Kiosk.touch_seen or Kiosk.touch_forced:
		return {"lauf": _tr("Knüppel"), "jump": _tr("SPRUNG"), "action": _tr("AKTION"), "toggle": _tr("HÜLLE"),
			"duck": _tr("Knüppel runter"), "hoch": _tr("Knüppel hoch/runter")}
	if Kiosk.has_gamepad():
		return {"lauf": _tr("Joystick"), "jump": _tr("Knopf %s") % Kiosk.label_jump(), "action": _tr("Knopf %s") % Kiosk.label_action(),
			"toggle": Kiosk.label_toggle(), "duck": _tr("Joystick RUNTER"), "hoch": _tr("Joystick HOCH/RUNTER")}
	return {"lauf": _tr("Pfeiltasten"), "jump": Kiosk.label_jump(), "action": _tr("Taste %s") % Kiosk.label_action(),
		"toggle": Kiosk.label_toggle(), "duck": _tr("Pfeil RUNTER"), "hoch": _tr("Pfeil HOCH/RUNTER")}


static func text(s: String) -> String:
	var tk := tokens()
	var out := _tr(s)
	for k in tk:
		out = out.replace("{%s}" % k, str(tk[k]))
	return out


## Bausteine eines Levels: Marker aus layout.txt (Prüfsumme, Bonus, Feder, Störfeld,
## Fahne, Tür) plus Objekte aus level.json plus Hülle/Tunnel als Levelmodus.
## Kulisse und Hinweiszonen zählen nicht — sie sind nichts, womit man spielt.
static func inventar(data: LevelData) -> Array:
	var found := {}
	if data.huelle_enabled:
		found["huelle"] = true
	if data.camera_mode == "tube":
		found["tube-scroll"] = true
	for m in data.markers:
		var t := str(m["type"])
		if t != "spawn":
			found[t] = true
	for o in data.objects:
		var t := str(o.get("type", ""))
		if t == "info-sign" or t == "deco" or t == "":
			continue
		found[t] = true
	var out: Array = []
	for t in REIHENFOLGE:
		if found.has(t):
			out.append(t)
	return out
