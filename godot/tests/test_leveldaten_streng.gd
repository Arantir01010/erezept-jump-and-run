extends "res://tests/testfall.gd"
## STRENGE LEVELDATEN (LevelData.befunde): Jede Station lädt ohne Befund, Ganzzahl-
## felder kommen als int. GEGENPROBE mit absichtlich kaputten Daten: unbekanntes Feld
## (Tippfehler), Kommazahl in einem Ganzzahlfeld, fehlendes Pflichtfeld, eine Liste,
## die sich zwei Bausteine teilen — jedes wird gemeldet, jede Meldung ist genau eine
## Zeile „<datei>: <datensatz/feld>: <grund>“, und das Level läuft trotzdem (Messe).

const ORDNER := "probe/"
const DATEI := "probe/level.json"


## Kleines, gültiges Level: Boden, Start, Tür, ein PIN-Tor, zwei Kartenleser.
static func _layout(breite := 40) -> String:
	var zeilen: Array[String] = []
	for y in Game.GRID_HEIGHT:
		if y >= 20:
			zeilen.append("#".repeat(breite))
		elif y == 19:
			zeilen.append("..P" + ".".repeat(breite - 5) + "D.")
		else:
			zeilen.append(".".repeat(breite))
	return "\n".join(zeilen) + "\n"


static func _gut() -> Dictionary:
	return {
		"station": {"name": {"de": "Probe", "en": "Probe"}, "portalText": {"de": "Portal"},
			"reziText": {"de": "REZI"}, "stampText": {"de": "Stempel"}, "badge": "PROBE"},
		"siegelIcon": "seal-generic",
		"cityAnchor": {"facade": "praxis", "label": {"de": "Praxis"}},
		"cameraMode": "horizontal",
		"theme": "stammdaten",
		"enemySkin": "neugier-geist",
		"collectible": {"type": "datenbit", "countRequired": 0, "label": {"de": "Daten-Kacheln"}},
		"mechanics": {"timing-gate": {"steps": 2, "stepMs": 900}},
		"parTimeSeconds": 30,
		"objects": [
			{"type": "timing-gate", "tx": 6, "ty": 15, "tw": 6, "th": 5, "gate": "tor-probe"},
			{"type": "gate", "tx": 16, "ty": 14, "th": 6, "name": "tor-probe"},
			{"type": "kartenleser", "tx": 22, "ty": 17, "karten": ["egk"]},
			{"type": "kartenleser", "tx": 28, "ty": 17, "karten": ["egk"]},
		],
	}


## Die vier Fehlerarten der Gegenprobe auf einmal.
static func _kaputt() -> Dictionary:
	var d := _gut()
	d["objects"][0]["stepMS"] = 900             # Tippfehler (richtig: stepMs)
	d["objects"][0]["steps"] = 2.5              # Kommazahl im Ganzzahlfeld
	(d["objects"][1] as Dictionary).erase("name")   # Pflichtfeld des Tors fehlt
	(d["station"] as Dictionary).erase("name")     # Pflichtfeld der Station fehlt
	return d


## Über JSON-Text laden wie eine Datei: Zahlen kommen dann als float zurück (P99).
func _laden(d: Dictionary) -> LevelData:
	return LevelData.aus_texten("probe", _layout(), JSON.stringify(d, "  ", false), ORDNER)


## Befunde, die zu datensatz/feld passen (Anfang des mittleren Teils).
func _treffer(data: LevelData, wo: String, grund_teil := "") -> Array:
	return data.befunde.filter(func(b: String): return b.begins_with("%s: %s: " % [DATEI, wo]) and grund_teil in b)


func _format_ok(b: String, datei: String) -> bool:
	if "\n" in b or "\r" in b or not b.begins_with(datei + ": "):
		return false
	var rest := b.substr(datei.length() + 2).split(": ", true, 1)
	return rest.size() == 2 and rest[0].strip_edges() != "" and rest[1].strip_edges() != ""


# ------------------------------------------------------------------ echte Stationen

func test_alle_stationen_ohne_befund() -> void:
	gleich(Game.playlist.size(), 10, "zehn Stationen in der Playlist")
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		pruefe(d.errors.is_empty(), "%s: Ladefehler %s" % [id, d.errors])
		for b in d.befunde:
			pruefe(false, b)


func test_ganzzahlfelder_kommen_als_int() -> void:
	var geprueft := 0
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		var c: Dictionary = d.json["collectible"]
		gleich(typeof(c["countRequired"]), TYPE_INT, "%s: collectible.countRequired" % id)
		var h: Dictionary = d.json.get("huelle", {})
		if h.has("toggleCooldownMs"):
			gleich(typeof(h["toggleCooldownMs"]), TYPE_INT, "%s: huelle.toggleCooldownMs" % id)
			geprueft += 1
		for o in d.objects:
			var felder := LevelData.felder_von(str(o["type"]))
			for f in o:
				if felder.has(f) and felder[f]["typ"] == "ganz":
					gleich(typeof(o[f]), TYPE_INT, "%s: %s/%s" % [id, o["type"], f])
					geprueft += 1
			# Positionen bleiben Zahlen (Kommazahlen sind dort erlaubt)
			pruefe(typeof(o["tx"]) in [TYPE_FLOAT, TYPE_INT], "%s: %s/tx ist eine Zahl" % [id, o["type"]])
		for typ in d.mechanics:
			var felder: Dictionary = LevelData.param_von(str(typ))
			for f in d.mechanics[typ]:
				if felder.has(f) and felder[f]["typ"] == "ganz":
					gleich(typeof(d.mechanics[typ][f]), TYPE_INT, "%s: mechanics/%s/%s" % [id, typ, f])
					geprueft += 1
	pruefe(geprueft >= 15, "nur %d Ganzzahlfelder gefunden — Test prüft zu wenig" % geprueft)
	# param() reicht den int durch, so wie der Baustein ihn liest
	var d1 := LevelData.load_level("01-stammdaten")
	for o in d1.objects:
		if o["type"] == "timing-gate":
			gleich(typeof(d1.param(o, "steps", 4)), TYPE_INT, "param steps")
			gleich(d1.param(o, "stepMs", 0), 1100, "param stepMs aus mechanics")


# ------------------------------------------------------------------ Gegenprobe

func test_kontrolle_gutes_probelevel_ohne_befund() -> void:
	var d := _laden(_gut())
	gleich(d.befunde, [] as Array[String], "das Probelevel selbst ist sauber")
	gleich(d.objects.size(), 4, "vier Bausteine")


func test_gegenprobe_unbekanntes_feld_und_tippfehler() -> void:
	var g := _gut()
	g["objects"][0]["stepMS"] = 900
	g["parTimeSecond"] = 30
	g.erase("parTimeSeconds")
	g["mechanics"]["timing-gat"] = {"steps": 3}
	var d := _laden(g)
	pruefe(not _treffer(d, "objects[0](timing-gate)/stepMS", "meintest du „stepMs“").is_empty(),
		"Tippfehler am Objekt gemeldet: %s" % [d.befunde])
	pruefe(not _treffer(d, "parTimeSecond", "unbekanntes Feld").is_empty(), "Tippfehler oben gemeldet")
	pruefe(not _treffer(d, "parTimeSeconds", "Pflichtfeld fehlt").is_empty(), "dadurch fehlt das Pflichtfeld")
	pruefe(not _treffer(d, "mechanics/timing-gat", "meintest du „timing-gate“").is_empty(), "unbekannter Baustein unter mechanics")


func test_gegenprobe_kommazahl_in_ganzzahlfeld() -> void:
	var g := _gut()
	g["objects"][0]["steps"] = 2.5
	g["mechanics"]["timing-gate"]["stepMs"] = 900.5
	g["collectible"]["countRequired"] = 3.0      # ganze Zahl mit .0 ist in Ordnung
	var d := _laden(g)
	pruefe(not _treffer(d, "objects[0](timing-gate)/steps", "Kommazahl 2.5").is_empty(), "steps 2.5 gemeldet: %s" % [d.befunde])
	pruefe(not _treffer(d, "mechanics/timing-gate/stepMs", "Kommazahl 900.5").is_empty(), "stepMs 900.5 gemeldet")
	gleich(_treffer(d, "collectible/countRequired").size(), 0, "3.0 ist eine Ganzzahl")
	gleich(typeof(d.json["collectible"]["countRequired"]), TYPE_INT, "3.0 kommt als int")
	gleich(d.count_required, 3, "Sammelziel")
	# Das Spiel rechnet weiter wie bisher (int() im Baustein)
	gleich(int(d.param(d.objects[0], "steps", 4)), 2, "Baustein rundet selbst")


func test_gegenprobe_fehlendes_pflichtfeld() -> void:
	var g := _gut()
	(g["objects"][1] as Dictionary).erase("name")
	(g["station"] as Dictionary).erase("name")
	(g["objects"][2] as Dictionary).erase("karten")
	(g["objects"][3] as Dictionary).erase("tx")
	var d := _laden(g)
	pruefe(not _treffer(d, "objects[1](gate)/name", "Pflichtfeld fehlt").is_empty(), "Tor ohne Namen: %s" % [d.befunde])
	pruefe(not _treffer(d, "station/name", "Pflichtfeld fehlt").is_empty(), "Station ohne Namen")
	pruefe(not _treffer(d, "objects[2](kartenleser)/karten", "Pflichtfeld fehlt").is_empty(), "Kartenleser ohne Karten")
	pruefe(not _treffer(d, "objects[3](kartenleser)/tx", "Pflichtfeld fehlt").is_empty(), "Objekt ohne tx")
	pruefe(not _treffer(d, "objects[0](timing-gate)/gate", "kein Tor „tor-probe“").is_empty(), "Öffner zeigt ins Leere")


func test_gegenprobe_gemeinsame_liste_zweier_bausteine() -> void:
	# a) Die Prüfung erkennt eine geteilte Liste …
	var d := _laden(_gut())
	d.objects[3]["karten"] = d.objects[2]["karten"]
	var geteilt := LevelData.geteilte_container(d.objects)
	gleich(geteilt.size(), 1, "eine geteilte Liste")
	if geteilt.size() == 1:
		gleich(geteilt[0][0], "objects[3](kartenleser)/karten", "Ort")
		pruefe("dieselbe Liste wie objects[2](kartenleser)/karten" in geteilt[0][1], "Grund: %s" % geteilt[0][1])
	# … auch ein doppelt eingehängtes Objekt
	gleich(LevelData.geteilte_container([d.objects[0], d.objects[0]]).size(), 1, "dasselbe Objekt zweimal")
	# b) … und der Lader gibt jedem Baustein eine eigene Kopie, selbst wenn die
	# Eingangsdaten (aus Code, nicht aus JSON) eine Liste teilen
	var g := _gut()
	var liste := ["egk"]
	g["objects"][2]["karten"] = liste
	g["objects"][3]["karten"] = liste
	var d2 := LevelData.aus_daten("probe", _layout(), g, ORDNER)
	gleich(d2.befunde, [] as Array[String], "keine geteilte Liste nach dem Laden")
	pruefe(not is_same(d2.objects[2]["karten"], d2.objects[3]["karten"]), "eigene Liste je Kartenleser")
	(d2.objects[2]["karten"] as Array).append("hba")
	gleich(d2.objects[3]["karten"], ["egk"], "Änderung am einen Leser bleibt beim einen")
	gleich(liste, ["egk"], "Eingangsdaten bleiben unberührt")
	# c) level-weite Tabellen aus mechanics[typ] kommen je Baustein als Kopie
	var g3 := _gut()
	g3["mechanics"]["kartenleser"] = {"hint": {"de": "Karte stecken!"}}
	var d3 := _laden(g3)
	var h2: Dictionary = d3.param(d3.objects[2], "hint", {})
	var h3: Dictionary = d3.param(d3.objects[3], "hint", {})
	pruefe(not is_same(h2, h3), "param(): eigene Tabelle je Baustein")
	h2["de"] = "geändert"
	gleich(d3.param(d3.objects[3], "hint", {})["de"], "Karte stecken!", "der andere Baustein sieht die Änderung nicht")


func test_gegenprobe_falsche_typen_brechen_nichts() -> void:
	var g := _gut()
	g["huelle"] = {"enabled": "true"}                  # bool("true") wäre ein Skriptfehler
	g["collectible"]["countRequired"] = "3"
	g["mechanics"]["moving-platform"] = 5             # param() erwartet eine Tabelle
	g["objects"][1]["name"] = 7                       # str(7.0) wäre „7.0“ (P99)
	g["objects"][0]["gate"] = 7
	var d := _laden(g)
	pruefe(not _treffer(d, "huelle/enabled", "Wahrheitswert als Text").is_empty(), "„true“ als Text: %s" % [d.befunde])
	gleich(d.huelle_enabled, true, "trotzdem eingeschaltet")
	pruefe(not _treffer(d, "collectible/countRequired", "Zahl als Text").is_empty(), "„3“ als Text")
	gleich(d.count_required, 3, "trotzdem 3")
	pruefe(not _treffer(d, "mechanics/moving-platform", "erwartet ein Objekt").is_empty(), "mechanics-Eintrag ohne Tabelle")
	gleich(d.mechanics.has("moving-platform"), false, "unbrauchbarer Eintrag fällt weg")
	gleich(d.objects[1]["name"], "7", "Tor-Name als Text ohne „.0“")
	pruefe(_treffer(d, "objects[0](timing-gate)/gate", "kein Tor").is_empty(), "Öffner findet das Tor „7“")


func test_gegenprobe_layout_und_kommas() -> void:
	var layout := _layout().replace("..P", "..PP").replace("D.", "D")
	var boden := layout.find("####")            # erste Bodenzeile (ty 20)
	layout = layout.substr(0, boden + 2) + "?" + layout.substr(boden + 3)
	# „badge“ ist der letzte Schlüssel der Station: Komma davor → Komma vor }
	var text := JSON.stringify(_gut(), "  ", false).replace("\"PROBE\"", "\"PROBE\",")
	var d := LevelData.aus_texten("probe", layout, text, ORDNER)
	pruefe(d.befunde.any(func(b): return b.begins_with("probe/layout.txt: P: 2 Startpunkte")), "zwei Startpunkte: %s" % [d.befunde])
	pruefe(d.befunde.any(func(b): return b.begins_with("probe/layout.txt: ty 20/tx 2: unbekanntes Zeichen „?“")), "unbekanntes Zeichen")
	pruefe(d.befunde.any(func(b): return b.begins_with("probe/level.json: Zeile ") and "Komma vor „}“" in b), "Komma vor }")
	var kaputt := LevelData.aus_texten("probe", _layout(), "{\"station\": }", ORDNER)
	pruefe(not kaputt.errors.is_empty(), "kaputtes JSON ist ein Ladefehler")
	pruefe(kaputt.befunde.any(func(b): return b.begins_with("probe/level.json: Zeile 1: kein gültiges JSON")), "mit Zeile: %s" % [kaputt.befunde])


func test_meldungen_einzeilig_im_format() -> void:
	var d := _laden(_kaputt())
	pruefe(d.befunde.size() >= 4, "die vier Fehler sind gemeldet: %s" % [d.befunde])
	for b in d.befunde:
		pruefe(_format_ok(b, DATEI), "Format „<datei>: <datensatz/feld>: <grund>“: %s" % b)
	# auch Text mit Zeilenumbruch im Wert bleibt eine Zeile
	var g := _gut()
	g["objects"][0]["hint\nzwei"] = "x"
	for b in _laden(g).befunde:
		pruefe(_format_ok(b, DATEI), "einzeilig: %s" % b.c_escape())


func test_befunde_halten_das_spiel_nicht_an() -> void:
	var g := _kaputt()
	g["huelle"] = {"enabled": "true"}
	g["mechanics"]["moving-platform"] = 5
	var d := _laden(g)
	pruefe(not d.befunde.is_empty(), "kaputte Daten haben Befunde")
	gleich(d.errors, [] as Array[String], "Befunde sind keine Ladefehler (Main meldet errors per push_error)")
	gleich(d.objects.size(), 4, "alle Bausteine geladen")
	# Das Level läuft: aufbauen, ein paar Bilder laufen lassen — keine Fehlermeldung
	# der Engine (der Testlauf zählt jede mit)
	var lvl := Level.new()
	baum.root.add_child(lvl)
	lvl.setup(d)
	await frames(12)
	pruefe(lvl._started, "Level ist gestartet")
	gleich(lvl.mechanics.size(), 5, "Tür + vier Bausteine stehen")
	lvl.queue_free()
	await frames(2)


# ------------------------------------------------------------------ Schema synchron

func test_schema_kennt_alle_bausteine() -> void:
	var registry := {}
	for t in Level.REGISTRY:
		registry[t] = true
	for t in Stations.REGISTRY:
		registry[t] = true
	for t in registry:
		pruefe(LevelData.BAUSTEINE.has(t), "Schema kennt den Baustein „%s“ nicht" % t)
	for t in LevelData.BAUSTEINE:
		pruefe(registry.has(t), "Schema nennt „%s“, den es als Baustein nicht gibt" % t)
	for t in LevelData.DEFAULTS:
		pruefe(LevelData.BAUSTEINE.has(t), "Standardgröße für unbekannten Baustein „%s“" % t)
	gleich(LevelData.KARTEN, KartenFx.INFO.keys(), "Karten wie KartenFx.INFO")
	gleich(LevelData.SPRACHEN, Game.LANGS, "Sprachen wie Game.LANGS")


## Jeder Parameter, den ein Baustein liest (param/ltext/obj.get in src/mechanics/*.gd),
## steht im Schema seines Typs — sonst meldete der Lader ein echtes Feld als unbekannt.
func test_schema_kennt_jeden_gelesenen_parameter() -> void:
	var typen_von := {}   # Klassenname → [Bausteintypen]
	var re_reg := RegEx.create_from_string("\"([a-z-]+)\": (?:Basics\\.)?([A-Z][A-Za-z]+)")
	for datei in ["res://src/world/Level.gd", "res://src/mechanics/Stations.gd"]:
		var text := FileAccess.get_file_as_string(datei)
		var a := text.find("const REGISTRY := {")
		var block := text.substr(a, text.find("\n}", a) - a)
		for m in re_reg.search_all(block):
			if not typen_von.has(m.get_string(2)):
				typen_von[m.get_string(2)] = []
			typen_von[m.get_string(2)].append(m.get_string(1))
	pruefe(typen_von.size() >= 20, "REGISTRY gelesen (%d Klassen)" % typen_von.size())
	var re_klasse := RegEx.create_from_string("^class (\\w+) extends Mechanic")
	var re_param := RegEx.create_from_string("\\b(?:param|ltext)\\(\"([^\"]+)\"")
	var re_obj := RegEx.create_from_string("\\bobj\\.get\\(\"([^\"]+)\"")
	var gelesen := 0
	var quellen: Array = [["res://src/mechanics/Basics.gd", ""], ["res://src/mechanics/Stations.gd", ""]]
	# Seit der Aufteilung steht jeder Stationsbaustein in einer eigenen Datei
	# (src/mechanics/stationen/): Klasse = Dateiname, kein „class … extends Mechanic“.
	for f in DirAccess.get_files_at("res://src/mechanics/stationen"):
		if f.ends_with(".gd"):
			quellen.append(["res://src/mechanics/stationen/" + f, f.get_basename()])
	for q in quellen:
		var datei: String = q[0]
		var klasse: String = q[1]
		for zeile in FileAccess.get_file_as_string(datei).split("\n"):
			var k := re_klasse.search(zeile)
			if k:
				klasse = k.get_string(1)
			if klasse == "" or not typen_von.has(klasse):
				continue
			for typ in typen_von[klasse]:
				var b: Dictionary = LevelData.BAUSTEINE.get(typ, {})
				var param: Dictionary = b.get("param", {})
				var alle := LevelData.felder_von(typ) if LevelData.BAUSTEINE.has(typ) else {}
				for m in re_param.search_all(zeile):
					gelesen += 1
					pruefe(param.has(m.get_string(1)), "%s (%s) liest param „%s“ — fehlt im Schema" % [typ, klasse, m.get_string(1)])
				for m in re_obj.search_all(zeile):
					gelesen += 1
					pruefe(alle.has(m.get_string(1)), "%s (%s) liest obj „%s“ — fehlt im Schema" % [typ, klasse, m.get_string(1)])
				if "linked_gate()" in zeile:
					pruefe(alle.has("gate"), "%s (%s) nutzt linked_gate(), Schema kennt „gate“ nicht" % [typ, klasse])
	pruefe(gelesen >= 40, "nur %d Parameterzugriffe gefunden — Muster veraltet?" % gelesen)
