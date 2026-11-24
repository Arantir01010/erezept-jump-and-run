class_name LevelData
extends RefCounted
## LEVELDATA — liest ein Level des Baukastens (layout.txt + level.json) und
## stellt Gelände, Marker und Objekte bereit. Dasselbe Format wie design/
## (siehe design/LEVELBAU.md), plus drei Godot-Erweiterungen im Layout:
##
##   `*`  Bonus-Prüfsumme (zählt für die Medaille „alle Prüfsummen", 50 Punkte)
##   `^`  Sprungfeder (Datenschub)
##   `x`  Störfeld — eine Kachel Schaden (kostet Bits, nie Leben)
##
## Suchreihenfolge: res://levels/<id>/ (Godot-eigen) vor res://levels/_import/<id>/.
##
## STRENGE PRÜFUNG: Beim Laden wird jedes Feld gegen das Schema unten geprüft
## (LEVEL_FELDER, BAUSTEINE, MECHANIK_EXTRA). Was nicht passt, steht als Befund in
## `befunde` — genau eine Zeile „<datei>: <datensatz/feld>: <grund>“:
##   • unbekannte Felder und Tippfehler (mit „meintest du …?“), unbekannte Bausteine,
##     Sprachen, Tor-Namen und Layout-Zeichen,
##   • fehlende Pflichtfelder,
##   • falsche Typen (Zahl als Text, Text statt Wahrheitswert …) und Werte außerhalb
##     der Grenzen des Baukastens (tools/lib/catalog.ts),
##   • Kommazahlen in Ganzzahlfeldern. JSON liefert jede Zahl als float (Stolperstein
##     P99: str(1.0) = „1.0“) — Ganzzahlfelder kommen hier als int heraus,
##   • Kommas vor } oder ] (Godots JSON nimmt sie hin, RFC 8259 und Python nicht),
##   • zwei Bausteine, die sich eine Liste oder Tabelle teilen (P65).
## Ein Befund hält das Spiel NICHT an: load_level meldet ihn per push_warning (einmal
## je Sitzung) und lädt weiter wie bisher; Werte mit unbrauchbarem Typ fallen weg, dann
## gilt der Standardwert des Bausteins — die Messe crasht nie. Tests werten Befunde als
## Fehler (tests/test_leveldaten_streng.gd).
##
## Jeder Baustein bekommt eigene Daten: Objekte werden mit duplicate(true) kopiert,
## param() gibt level-weite Listen/Tabellen (mechanics[typ]) als Kopie heraus.

const SOLID_CHARS := "#=GA~%"
const MARKERS := {"P": "spawn", "o": "collectible", "C": "checkpoint", "D": "door-exit",
	"*": "bonus", "^": "spring", "x": "spike"}
## Weitere erlaubte Layout-Zeichen: Luft (`.` und Leerzeichen) und die Deko-Strebe `|`
## (nicht solide, Terrain.gd).
const LUFT_CHARS := ". |"

## Standardgrößen in Kacheln (tools/lib/catalog.ts).
const DEFAULTS := {
	"gate": [0.5, 6], "timing-gate": [8, 5], "stillstand-podest": [3, 0.4],
	"krypto-dusche": [5, 6], "deny-enemy": [1.4, 0.4], "stamp-exit": [6, 6],
	"letzte-tuer": [3, 6], "info-sign": [2.5, 4], "moving-platform": [2, 0.4],
	"hazard": [1, 1], "lauscher": [1, 1], "andock-plattform": [3, 0.4],
	"vau-feld": [6, 5], "kontext-anker": [1, 1.5], "karte": [1.2, 0.8],
	"kartenleser": [3, 3], "deco": [1.5, 1.5],
}

# ------------------------------------------------------------------ Schema
# Abgeleitet aus den zehn level.json, diesem Lader, den Bausteinen (param()/ltext()/
# obj.get() in src/mechanics/*.gd), tools/build_levels.py (DEFAULTS) und dem Katalog
# des Phaser-Baukastens (tools/lib/catalog.ts: Pflichtfelder, Grenzen).
# Feldtypen: text · name (Tor-Name: a–z, 0–9, -) · ganz (Ganzzahl) · zahl · wahr (bool)
# · ltext (Text oder {de, en, fr, es, zh, hi}, de Pflicht) · wahl (einer der „werte“)
# · karte / karten (Ausweis-Kennungen) · thema (Schlüssel aus config/themes.json)
# · objekt (eigene „felder“) · objekte (Bausteinliste) · mechanik (mechanics-Tabelle).
# tests/test_leveldaten_streng.gd hält das Schema mit den Bausteinen synchron.

const SPRACHEN := ["de", "en", "fr", "es", "zh", "hi"]
const KARTEN := ["egk", "hba", "smcb"]
const SIEGEL := ["seal-vsdm", "seal-egk", "seal-vpn", "seal-generic"]
const DECO_SPRITES := ["krake-0", "krake-1", "kralle-open", "kralle-closed", "lauscher-0", "lauscher-1"]
const DECO_ANIMS := ["krake-swim", "lauscher-blink"]
## Bausteine, die nur mit eingeschalteter Hülle (huelle.enabled) Sinn ergeben.
const HUELLE_TYPEN := ["lauscher", "andock-plattform", "vau-feld", "kontext-anker"]

const LT := {"typ": "ltext"}
const LT_PFLICHT := {"typ": "ltext", "pflicht": true}
const TOR := {"typ": "name", "pflicht": true}

## Felder jedes Objekts in objects[].
const GRUNDFELDER := {
	"type": {"typ": "text", "pflicht": true},
	"tx": {"typ": "zahl", "pflicht": true, "min": 0},
	"ty": {"typ": "zahl", "pflicht": true, "min": 0, "max": 23},
	"tw": {"typ": "zahl", "min": 0.1, "max": 60},
	"th": {"typ": "zahl", "min": 0.1, "max": 23},
}

## Felder je Baustein. "param": über param()/ltext() gelesen — am Objekt ODER level-weit
## unter mechanics[typ]. "objekt": nur am Objekt (obj.get). "eins_von": mindestens eines
## davon (am Objekt oder unter mechanics[typ]).
const BAUSTEINE := {
	"gate": {"objekt": {"name": TOR}, "param": {"bumpHint": LT}},
	"timing-gate": {"objekt": {"gate": TOR}, "param": {
		"steps": {"typ": "ganz", "min": 2, "max": 8},
		"stepMs": {"typ": "ganz", "min": 300, "max": 3000},
		"hint": LT, "failHint": LT, "gateHint": LT}},
	"stillstand-podest": {"objekt": {"gate": TOR}, "param": {
		"scanMs": {"typ": "ganz", "min": 400, "max": 4000},
		"hint": LT, "stillHint": LT, "gateHint": LT, "denyText": LT}},
	"krypto-dusche": {"objekt": {"gate": TOR}, "param": {"hint": LT, "gateHint": LT}},
	"deny-enemy": {"param": {
		"fromRight": {"typ": "wahr"},
		"reach": {"typ": "zahl", "min": 8, "max": 120},
		"grabsBeforeBlock": {"typ": "ganz", "min": 1, "max": 5},
		"activationRange": {"typ": "zahl", "min": 60, "max": 600},
		"idleMs": {"typ": "ganz", "min": 400, "max": 4000},
		"denyText": LT, "duckHint": LT}},
	"stamp-exit": {"param": {"hint": LT, "failHint": LT}},
	"letzte-tuer": {"param": {"warteText": LT, "denyText": LT, "freigabeText": LT,
		"lueckenlosText": LT, "freigabeZeile": LT, "tuerSchild": LT}},
	"info-sign": {"objekt": {"textDe": {"typ": "text"}, "textEn": {"typ": "text"}},
		"param": {"text": LT}, "eins_von": ["textDe", "text"]},
	"moving-platform": {"param": {
		"range": {"typ": "zahl", "min": 16, "max": 200},
		"speed": {"typ": "zahl", "min": 10, "max": 120}}},
	"hazard": {},
	"lauscher": {"param": {
		"patrol": {"typ": "zahl", "min": -240, "max": 240},
		"speed": {"typ": "zahl", "min": 5, "max": 120},
		"reach": {"typ": "zahl", "min": 24, "max": 240},
		"spread": {"typ": "zahl", "min": 6, "max": 60},
		"pauseMs": {"typ": "ganz", "min": 0, "max": 4000},
		"seenText": LT, "akteur": LT, "huelleHint": LT}},
	"andock-plattform": {"param": {"hint": LT}},
	"vau-feld": {"param": {"ttlMs": {"typ": "ganz", "min": 0, "max": 30000}, "hint": LT}},
	"kontext-anker": {"param": {"hint": LT}},
	"karte": {"objekt": {"karte": {"typ": "karte", "pflicht": true}, "hint": LT}},
	"kartenleser": {"objekt": {"karten": {"typ": "karten", "pflicht": true}, "gate": {"typ": "name"}},
		"param": {"hint": LT, "gateHint": LT, "denyText": LT, "nicht-dabeiHint": LT,
			"falsche-karteHint": LT, "belegtHint": LT}},
	"deco": {"objekt": {"anim": {"typ": "wahl", "werte": DECO_ANIMS}},
		"param": {"sprite": {"typ": "wahl", "werte": DECO_SPRITES},
			"drift": {"typ": "zahl", "min": 0, "max": 20}}},
	# Marker-Bausteine: eigentlich Zeichen im Layout; als Objekt nur mit Grundfeldern.
	"collectible": {}, "bonus": {}, "checkpoint": {}, "door-exit": {}, "spring": {}, "spike": {},
}

## Level-weite Parameter, die kein Baustein sind (Level.gd liest sie selbst).
const MECHANIK_EXTRA := {"tube-scroll": {"speed": {"typ": "zahl", "min": 30, "max": 90}}}

## Felder der level.json (oberste Ebene). Pflicht wie im Baukasten-Format.
const LEVEL_FELDER := {
	"station": {"typ": "objekt", "pflicht": true, "felder": {
		"name": LT_PFLICHT, "portalText": LT_PFLICHT, "reziText": LT_PFLICHT,
		"stampText": LT_PFLICHT, "badge": {"typ": "text", "pflicht": true}}},
	"siegelIcon": {"typ": "wahl", "pflicht": true, "werte": SIEGEL},
	"cityAnchor": {"typ": "objekt", "pflicht": true, "felder": {
		"facade": {"typ": "text", "pflicht": true}, "label": LT_PFLICHT}},
	"cameraMode": {"typ": "wahl", "pflicht": true, "werte": ["horizontal", "tube"]},
	"theme": {"typ": "thema", "pflicht": true},
	"enemySkin": {"typ": "text", "pflicht": true},
	"collectible": {"typ": "objekt", "pflicht": true, "felder": {
		"type": {"typ": "wahl", "pflicht": true, "werte": ["datenbit"]},
		"countRequired": {"typ": "ganz", "pflicht": true, "min": 0, "max": 60},
		"label": LT_PFLICHT}},
	"mechanics": {"typ": "mechanik"},
	"huelle": {"typ": "objekt", "felder": {
		"enabled": {"typ": "wahr", "pflicht": true},
		"start": {"typ": "wahl", "werte": ["klartext", "verschluesselt"]},
		"toggleCooldownMs": {"typ": "ganz", "min": 0, "max": 1000}}},
	"parTimeSeconds": {"typ": "zahl", "pflicht": true, "min": 10, "max": 120},
	"stuckHint": LT,
	"objects": {"typ": "objekte"},
}

var id := ""
var width := 0
var height := Game.GRID_HEIGHT
var rows: Array[String] = []
var markers: Array = []
var objects: Array = []
var json := {}
var station := {}
var theme_name := "city"
var camera_mode := "horizontal"
var huelle_enabled := false
var huelle_start := "klartext"
var huelle_cooldown_ms := 150
var count_required := 0
var collect_label := {}
var mechanics := {}
var par_time := 30.0
var stuck_hint = null
var seal_icon := "seal-generic"
var enemy_skin := ""
var bits_total := 0
var errors: Array[String] = []
## Befunde der strengen Prüfung, je eine Zeile „<datei>: <datensatz/feld>: <grund>“.
var befunde: Array[String] = []

var _datei_layout := "layout.txt"
var _datei_json := "level.json"
static var _gemeldet := {}
static var _felder_cache := {}


static func level_dir(level_id: String) -> String:
	for base in ["res://levels/", "res://levels/_import/"]:
		if FileAccess.file_exists(base + level_id + "/layout.txt"):
			return base + level_id + "/"
	return ""


static func load_level(level_id: String) -> LevelData:
	var dir := level_dir(level_id)
	var data: LevelData
	if dir == "":
		data = LevelData.new()
		data.id = level_id
		data.errors.append("Level %s nicht gefunden" % level_id)
		data._befund("res://levels/%s/" % level_id, "layout.txt", "Level nicht gefunden (weder levels/ noch levels/_import/)")
	else:
		data = aus_texten(level_id, FileAccess.get_file_as_string(dir + "layout.txt"),
			FileAccess.get_file_as_string(dir + "level.json"), dir)
	_melden(data)
	return data


## Liest und prüft ein Level aus Texten, ohne zu melden (Tests, Werkzeuge).
## `ordner` steht in den Befunden vor dem Dateinamen (z. B. „res://levels/01-x/“).
static func aus_texten(level_id: String, layout_text: String, json_text: String, ordner := "") -> LevelData:
	var data := _neu(level_id, layout_text, ordner)
	var j := JSON.new()
	if j.parse(json_text) != OK:
		data.errors.append("level.json von %s ist kein gültiges JSON" % level_id)
		data._befund(data._datei_json, "Zeile %d" % (j.get_error_line() + 1), "kein gültiges JSON: %s" % j.get_error_message())
	elif not (j.data is Dictionary):
		data.errors.append("level.json von %s ist kein gültiges JSON" % level_id)
		data._befund(data._datei_json, "(Wurzel)", "erwartet ein Objekt { … }, ist %s" % _typname(j.data))
	else:
		data._kommas_pruefen(json_text)
		data._uebernehmen(j.data)
	return data


## Wie aus_texten, aber mit schon gelesenen Daten (Tests: geteilte Listen lassen sich
## in JSON-Text nicht ausdrücken).
static func aus_daten(level_id: String, layout_text: String, daten: Dictionary, ordner := "") -> LevelData:
	var data := _neu(level_id, layout_text, ordner)
	data._uebernehmen(daten)
	return data


static func _neu(level_id: String, layout_text: String, ordner: String) -> LevelData:
	var data := LevelData.new()
	data.id = level_id
	data._datei_layout = ordner + "layout.txt"
	data._datei_json = ordner + "level.json"
	data._parse_layout(layout_text)
	return data


func _uebernehmen(roh: Dictionary) -> void:
	_parse_json(_streng(roh))
	_verweise_pruefen()
	for b in geteilte_container(objects):
		_befund(_datei_json, b[0], b[1])


## Befunde am Messestand: Warnung ins Log (je Befund einmal je Sitzung), das Spiel läuft
## weiter. push_error wäre falsch — der Testlauf und Main werten Fehler anders.
static func _melden(data: LevelData) -> void:
	for b in data.befunde:
		if not _gemeldet.has(b):
			_gemeldet[b] = true
			push_warning(b)


func _parse_layout(text: String) -> void:
	var lines := text.replace("\r", "").split("\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	height = lines.size()
	if height != Game.GRID_HEIGHT:
		errors.append("layout.txt hat %d Zeilen (erwartet %d)" % [height, Game.GRID_HEIGHT])
		_befund(_datei_layout, "Zeilen", "%d statt %d" % [height, Game.GRID_HEIGHT])
	width = 0
	for l in lines:
		width = maxi(width, l.length())
	rows.clear()
	var starts := 0
	var fremd := {}   # Zeichen → [Anzahl, erste Stelle]
	for y in lines.size():
		var line := lines[y]
		if line.length() < width:
			_befund(_datei_layout, "ty %d" % y, "Zeile hat %d statt %d Zeichen — der Rest wird Luft" % [line.length(), width])
		var row := ""
		for x in width:
			var ch := line[x] if x < line.length() else "."
			if MARKERS.has(ch):
				markers.append({"type": MARKERS[ch], "tx": x, "ty": y})
				if ch == "o" or ch == "*":
					bits_total += 1
				if ch == "P":
					starts += 1
				row += "."
			elif ch == " ":
				row += "."
			else:
				if not (SOLID_CHARS.contains(ch) or LUFT_CHARS.contains(ch)):
					if fremd.has(ch):
						fremd[ch][0] += 1
					else:
						fremd[ch] = [1, "ty %d/tx %d" % [y, x]]
				row += ch
		rows.append(row)
	for ch in fremd:
		_befund(_datei_layout, fremd[ch][1], "unbekanntes Zeichen „%s“ (%d×; erlaubt: %s %s %s)"
			% [ch, fremd[ch][0], SOLID_CHARS, "".join(MARKERS.keys()), LUFT_CHARS.replace(" ", "")])
	if starts != 1:
		_befund(_datei_layout, "P", "kein Startpunkt" if starts == 0 else "%d Startpunkte, erlaubt ist einer" % starts)


func _parse_json(d: Dictionary) -> void:
	json = d
	station = d.get("station", {})
	theme_name = str(d.get("theme", "city"))
	camera_mode = str(d.get("cameraMode", "horizontal"))
	var h: Dictionary = d.get("huelle", {})
	huelle_enabled = bool(h.get("enabled", false))
	huelle_start = str(h.get("start", "klartext"))
	huelle_cooldown_ms = int(h.get("toggleCooldownMs", 150))
	var c: Dictionary = d.get("collectible", {})
	count_required = int(c.get("countRequired", 0))
	collect_label = c.get("label", {"de": "Prüfsummen", "en": "checksums"})
	mechanics = d.get("mechanics", {})
	par_time = float(d.get("parTimeSeconds", 30))
	stuck_hint = d.get("stuckHint", null)
	seal_icon = str(d.get("siegelIcon", "seal-generic"))
	enemy_skin = str(d.get("enemySkin", ""))
	for raw in d.get("objects", []):
		if not (raw is Dictionary) or not raw.has("type"):
			continue
		# Jeder Baustein bekommt eigene Daten — auch verschachtelte Listen (P65)
		var o: Dictionary = raw.duplicate(true)
		var t := str(o["type"])
		var def: Array = DEFAULTS.get(t, [1, 1])
		if not o.has("tw"):
			o["tw"] = def[0]
		if not o.has("th"):
			o["th"] = def[1]
		objects.append(o)


## Parameter eines Objekts: erst am Objekt, dann level-weit unter mechanics[typ].
## Level-weite Listen/Tabellen teilen sich alle Bausteine eines Typs — sie kommen
## darum als eigene Kopie heraus (P65).
func param(obj: Dictionary, key: String, fallback: Variant) -> Variant:
	if obj.has(key):
		return obj[key]
	var m: Dictionary = mechanics.get(str(obj.get("type", "")), {})
	if m.has(key):
		var v: Variant = m[key]
		if v is Array or v is Dictionary:
			return v.duplicate(true)
		return v
	return fallback


func char_at(tx: int, ty: int) -> String:
	if ty < 0 or ty >= rows.size() or tx < 0 or tx >= width:
		return "#" if ty >= rows.size() else "."
	return rows[ty][tx]


func is_solid(tx: int, ty: int) -> bool:
	return SOLID_CHARS.contains(char_at(tx, ty))


func world_width() -> float:
	return width * Game.TILE


func world_height() -> float:
	return height * Game.TILE


func spawn_point() -> Vector2:
	for m in markers:
		if m["type"] == "spawn":
			return Vector2((m["tx"] + 0.5) * Game.TILE, (m["ty"] + 1) * Game.TILE - 2)
	return Vector2(2 * Game.TILE, world_height() - 3 * Game.TILE)


func name_text() -> String:
	return Game.t(station.get("name", {}), id)


# ------------------------------------------------------------------ Strenge Prüfung

## Gemeinsame Listen/Tabellen zweier Bausteine (Stolperstein P65): Ändert einer „seine“
## Liste, ändert sich die des anderen mit. Liefert [[datensatz/feld, grund], …].
static func geteilte_container(objekte: Array) -> Array:
	var gesehen: Array = []   # [[container, ort], …] der vorigen Objekte
	var aus: Array = []
	for i in objekte.size():
		var o: Variant = objekte[i]
		if not (o is Dictionary):
			continue
		var eigene: Array = []
		_container_sammeln(o, "objects[%d](%s)" % [i, str((o as Dictionary).get("type", "?"))], eigene)
		for c in eigene:
			for g in gesehen:
				if is_same(c[0], g[0]):
					aus.append([c[1], "dieselbe %s wie %s — jeder Baustein braucht eine eigene Kopie (duplicate(true))"
						% ["Liste" if c[0] is Array else "Tabelle", g[1]]])
					break
		gesehen.append_array(eigene)
	return aus


static func _container_sammeln(v: Variant, ort: String, aus: Array) -> void:
	if v is Dictionary:
		aus.append([v, ort])
		for k in v:
			_container_sammeln(v[k], ort + "/" + str(k), aus)
	elif v is Array:
		aus.append([v, ort])
		for i in (v as Array).size():
			_container_sammeln(v[i], "%s[%d]" % [ort, i], aus)


func _befund(datei: String, wo: String, grund: String) -> void:
	befunde.append("%s: %s: %s" % [datei, _einzeilig(wo), _einzeilig(grund)])


static func _einzeilig(s: String) -> String:
	return s.replace("\r\n", " ").replace("\n", " ").replace("\r", " ").replace("\t", " ")


## Prüft die ganze level.json und liefert eine bereinigte, tiefe Kopie: Ganzzahlfelder
## als int, Zahlen/Wahrheitswerte aus Text umgewandelt, Werte mit unbrauchbarem Typ
## entfernt (dann gilt der Standardwert). Unbekannte Felder bleiben erhalten.
func _streng(d: Dictionary) -> Dictionary:
	return _objekt(d, LEVEL_FELDER, "")


func _objekt(d: Dictionary, felder: Dictionary, pfad: String) -> Dictionary:
	var aus := {}
	for k in d:
		var key := str(k)
		var wo := _p(pfad, key)
		if not felder.has(key):
			_befund(_datei_json, wo, "unbekanntes Feld" + _vorschlag(key, felder.keys()))
			aus[key] = _kopie(d[k])
			continue
		var r := _feld(felder[key], d[k], wo)
		if not r.is_empty():
			aus[key] = r[0]
	for key in felder:
		if (felder[key] as Dictionary).get("pflicht", false) and not d.has(key):
			_befund(_datei_json, _p(pfad, key), "Pflichtfeld fehlt")
	return aus


## Ein Feldwert: [bereinigter Wert] oder [] (Typ unbrauchbar → Feld fällt weg).
func _feld(spec: Dictionary, v: Variant, wo: String) -> Array:
	match str(spec["typ"]):
		"text":
			return _text(v, wo)
		"name":
			var r := _text(v, wo)
			if not r.is_empty() and not _ist_name(str(r[0])):
				_befund(_datei_json, wo, "„%s“: Tor-Namen nur aus Kleinbuchstaben, Ziffern und Bindestrichen" % r[0])
			return r
		"ganz":
			return _zahl(spec, v, wo, true)
		"zahl":
			return _zahl(spec, v, wo, false)
		"wahr":
			return _wahr(v, wo)
		"ltext":
			return _ltext(v, wo)
		"wahl":
			return _wahl(v, wo, spec["werte"])
		"karte":
			return _wahl(v, wo, KARTEN)
		"karten":
			return _karten(v, wo)
		"thema":
			var r := _text(v, wo)
			var themen: Dictionary = Game.themes
			if not r.is_empty() and not themen.is_empty() and not themen.has(r[0]):
				_befund(_datei_json, wo, "Thema „%s“ steht nicht in config/themes.json%s" % [r[0], _vorschlag(str(r[0]), themen.keys())])
			return r
		"objekt":
			if not (v is Dictionary):
				_befund(_datei_json, wo, "erwartet ein Objekt { … }, ist %s" % _typname(v))
				return []
			return [_objekt(v, spec["felder"], wo)]
		"objekte":
			return [_objekte(v, wo)]
		"mechanik":
			return [_mechanik(v, wo)]
	return [_kopie(v)]


func _text(v: Variant, wo: String) -> Array:
	if v is String:
		return [v]
	if v is float or v is int:
		# P99: str(1.0) ist „1.0“ — ganze Zahlen ohne Nachkomma, damit Namen passen
		var t := _zahltext(float(v))
		_befund(_datei_json, wo, "Zahl %s statt Text — in Anführungszeichen schreiben" % t)
		return [t]
	_befund(_datei_json, wo, "erwartet Text, ist %s" % _typname(v))
	return []


func _zahl(spec: Dictionary, v: Variant, wo: String, ganz: bool) -> Array:
	var f := 0.0
	if v is float or v is int:
		f = float(v)
	elif v is String and (v as String).strip_edges().is_valid_float():
		_befund(_datei_json, wo, "Zahl als Text „%s“ — ohne Anführungszeichen schreiben" % v)
		f = (v as String).strip_edges().to_float()
	else:
		_befund(_datei_json, wo, "erwartet eine Zahl, ist %s" % _typname(v))
		return []
	var wert: Variant = f
	if ganz:
		if f != floorf(f):
			# Wert bleibt wie er ist — das Spiel rundet selbst, wie bisher
			_befund(_datei_json, wo, "Kommazahl %s in einem Ganzzahlfeld" % _zahltext(f))
		else:
			wert = int(f)
	if spec.has("min") and f < float(spec["min"]) or spec.has("max") and f > float(spec["max"]):
		_befund(_datei_json, wo, "%s liegt außerhalb %s … %s" % [_zahltext(f),
			_zahltext(float(spec.get("min", -INF))), _zahltext(float(spec.get("max", INF)))])
	return [wert]


func _wahr(v: Variant, wo: String) -> Array:
	if v is bool:
		return [v]
	# P123b: aus Text- oder Tabellenwerkzeugen kommt „true“ oft als Text — bool("true")
	# gibt es in GDScript nicht (Skriptfehler), darum hier umwandeln
	if v is String and (v as String).strip_edges().to_lower() in ["true", "false"]:
		_befund(_datei_json, wo, "Wahrheitswert als Text „%s“ — true/false ohne Anführungszeichen" % v)
		return [(v as String).strip_edges().to_lower() == "true"]
	_befund(_datei_json, wo, "erwartet true oder false, ist %s" % _typname(v))
	if v is float or v is int:
		return [v]
	return []


func _ltext(v: Variant, wo: String) -> Array:
	if v is String:
		return [v]
	if not (v is Dictionary):
		_befund(_datei_json, wo, "erwartet Text oder {\"de\": …, \"en\": …}, ist %s" % _typname(v))
		return []
	var aus := {}
	for k in v:
		var sprache := str(k)
		if not SPRACHEN.has(sprache):
			_befund(_datei_json, _p(wo, sprache), "unbekannte Sprache%s" % _vorschlag(sprache, SPRACHEN))
		var r := _text(v[k], _p(wo, sprache))
		if not r.is_empty():
			aus[sprache] = r[0]
	if not (v as Dictionary).has("de"):
		_befund(_datei_json, _p(wo, "de"), "Pflichtfeld fehlt (Deutsch ist der Schlüssel jeder Übersetzung)")
	return [aus]


func _wahl(v: Variant, wo: String, werte: Array) -> Array:
	var r := _text(v, wo)
	if not r.is_empty() and not werte.has(r[0]):
		_befund(_datei_json, wo, "„%s“ ist keiner der Werte %s%s" % [r[0], ", ".join(werte), _vorschlag(str(r[0]), werte)])
	return r


## karten: Liste ["egk", …] oder Komma-Text "egk, hba" (Tiled kennt keine Listen).
func _karten(v: Variant, wo: String) -> Array:
	var teile: Array = []
	if v is Array:
		for i in (v as Array).size():
			var r := _text(v[i], "%s[%d]" % [wo, i])
			if not r.is_empty():
				teile.append(r[0])
	elif v is String:
		for s in (v as String).split(","):
			teile.append(s.strip_edges())
	else:
		_befund(_datei_json, wo, "erwartet eine Liste [\"egk\", …] oder Text, ist %s" % _typname(v))
		return []
	if teile.is_empty():
		_befund(_datei_json, wo, "keine Karte — ein Leser ohne Karte ist eine Sackgasse")
	for t in teile:
		if not KARTEN.has(str(t).to_lower()):
			_befund(_datei_json, wo, "unbekannte Karte „%s“ (bekannt: %s)%s" % [t, ", ".join(KARTEN), _vorschlag(str(t), KARTEN)])
	return [_kopie(v)]


func _objekte(v: Variant, wo: String) -> Array:
	if not (v is Array):
		_befund(_datei_json, wo, "erwartet eine Liste [ … ], ist %s" % _typname(v))
		return []
	var aus: Array = []
	for i in (v as Array).size():
		var roh: Variant = v[i]
		if not (roh is Dictionary):
			_befund(_datei_json, "%s[%d]" % [wo, i], "erwartet ein Objekt { … }, ist %s" % _typname(roh))
			aus.append(_kopie(roh))   # bleibt stehen, damit die Nummern der Befunde stimmen
			continue
		var typ := str((roh as Dictionary).get("type", ""))
		var ort := "%s[%d](%s)" % [wo, i, typ]
		if not BAUSTEINE.has(typ):
			if (roh as Dictionary).has("type"):
				_befund(_datei_json, _p(ort, "type"), "unbekannter Baustein „%s“%s" % [typ, _vorschlag(typ, BAUSTEINE.keys())])
			else:
				_befund(_datei_json, _p(ort, "type"), "Pflichtfeld fehlt")
			aus.append(_kopie(roh))
			continue
		aus.append(_objekt(roh, felder_von(typ), ort))
	return aus


func _mechanik(v: Variant, wo: String) -> Dictionary:
	if not (v is Dictionary):
		_befund(_datei_json, wo, "erwartet ein Objekt { … }, ist %s" % _typname(v))
		return {}
	var aus := {}
	for k in v:
		var typ := str(k)
		var ort := _p(wo, typ)
		var felder: Variant = param_von(typ)
		if felder == null:
			_befund(_datei_json, ort, "unbekannter Baustein%s" % _vorschlag(typ, BAUSTEINE.keys() + MECHANIK_EXTRA.keys()))
			if v[k] is Dictionary:
				aus[typ] = _kopie(v[k])
			continue
		if not (v[k] is Dictionary):
			# fiele sonst in param() auf eine typisierte Variable (Skriptfehler)
			_befund(_datei_json, ort, "erwartet ein Objekt { … }, ist %s" % _typname(v[k]))
			continue
		aus[typ] = _objekt(v[k], felder, ort)
	return aus


## Alle Felder, die ein Objekt dieses Typs tragen darf.
static func felder_von(typ: String) -> Dictionary:
	if not _felder_cache.has(typ):
		var b: Dictionary = BAUSTEINE[typ]
		var f := GRUNDFELDER.duplicate()
		f.merge(b.get("objekt", {}))
		f.merge(b.get("param", {}))
		_felder_cache[typ] = f
	return _felder_cache[typ]


## Felder, die level-weit unter mechanics[typ] stehen dürfen (null = kein bekannter Typ).
static func param_von(typ: String) -> Variant:
	if BAUSTEINE.has(typ):
		return (BAUSTEINE[typ] as Dictionary).get("param", {})
	return MECHANIK_EXTRA.get(typ, null)


## Querbezüge nach dem Lesen: Tor-Namen, Öffner, Pflicht „eins von“, Hülle, Lage.
func _verweise_pruefen() -> void:
	var tore := {}
	var oeffner := {}
	var roh: Array = json.get("objects", []) if json.get("objects", []) is Array else []
	for i in roh.size():
		var o: Variant = roh[i]
		if not (o is Dictionary) or not BAUSTEINE.has(str(o.get("type", ""))):
			continue
		var typ := str(o["type"])
		var ort := "objects[%d](%s)" % [i, typ]
		if typ == "gate" and o.get("name") is String:
			if tore.has(o["name"]):
				_befund(_datei_json, _p(ort, "name"), "Tor „%s“ gibt es schon (%s)" % [o["name"], tore[o["name"]]])
			else:
				tore[o["name"]] = ort
		elif o.get("gate") is String:
			oeffner[ort] = o["gate"]
		var eins: Array = (BAUSTEINE[typ] as Dictionary).get("eins_von", [])
		if not eins.is_empty() and not eins.any(func(f): return o.has(f) or (mechanics.get(typ, {}) as Dictionary).has(f)):
			_befund(_datei_json, _p(ort, eins[0]), "Pflichtfeld fehlt (oder %s)" % " / ".join(eins.slice(1)))
		if typ in HUELLE_TYPEN and not huelle_enabled:
			_befund(_datei_json, ort, "braucht \"huelle\": {\"enabled\": true}")
		if (o.get("tx") is float or o.get("tx") is int) and width > 0 and float(o["tx"]) >= width:
			_befund(_datei_json, _p(ort, "tx"), "%s liegt rechts außerhalb des Levels (Breite %d)" % [_zahltext(float(o["tx"])), width])
	for ort in oeffner:
		if not tore.has(oeffner[ort]):
			_befund(_datei_json, _p(ort, "gate"), "kein Tor „%s“ im Level%s" % [oeffner[ort], _vorschlag(str(oeffner[ort]), tore.keys())])
	var geoeffnet := oeffner.values()
	for n in tore:
		if not geoeffnet.has(n):
			_befund(_datei_json, tore[n], "Tor „%s“ hat keinen Öffner — es bliebe für immer zu" % n)


## RFC 8259 verbietet Kommas vor } und ] — Godots JSON nimmt sie hin, Python
## (tools/build_levels.py) und der Phaser-Baukasten nicht.
func _kommas_pruefen(text: String) -> void:
	var zeile := 1
	var im_text := false
	var i := 0
	var n := text.length()
	while i < n:
		var ch := text[i]
		if ch == "\n":
			zeile += 1
		elif im_text:
			if ch == "\\":
				i += 1
			elif ch == "\"":
				im_text = false
		elif ch == "\"":
			im_text = true
		elif ch == ",":
			var k := i + 1
			while k < n and text[k] in [" ", "\t", "\r", "\n"]:
				k += 1
			if k < n and text[k] in ["}", "]"]:
				_befund(_datei_json, "Zeile %d" % zeile, "Komma vor „%s“ — in JSON nicht erlaubt" % text[k])
		i += 1


static func _p(pfad: String, feld: String) -> String:
	return feld if pfad == "" else pfad + "/" + feld


static func _ist_name(s: String) -> bool:
	if s.is_empty():
		return false
	for ch in s:
		if not (ch >= "a" and ch <= "z" or ch >= "0" and ch <= "9" or ch == "-"):
			return false
	return true


static func _kopie(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v


static func _zahltext(f: float) -> String:
	if is_inf(f):
		return "∞" if f > 0 else "−∞"
	if f == floorf(f) and absf(f) < 1e15:
		return str(int(f))
	return str(f)


static func _typname(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "Wahrheitswert"
		TYPE_INT, TYPE_FLOAT:
			return "Zahl"
		TYPE_STRING:
			return "Text"
		TYPE_ARRAY:
			return "Liste [ … ]"
		TYPE_DICTIONARY:
			return "Objekt { … }"
	return type_string(typeof(v))


## „meintest du …?“ für Tippfehler: nächster bekannter Begriff nach Editierdistanz,
## nur wenn er plausibel nah ist (wie suggest() im Phaser-Katalog).
static func _vorschlag(wort: String, bekannte: Array) -> String:
	var best := ""
	var best_d := 1 << 30
	for b in bekannte:
		var d := _abstand(wort.to_lower(), str(b).to_lower())
		if d < best_d:
			best_d = d
			best = str(b)
	if best != "" and best_d <= maxi(2, int(wort.length() / 3.0)):
		return " — meintest du „%s“?" % best
	return ""


static func _abstand(a: String, b: String) -> int:
	var vorher: Array[int] = []
	for j in b.length() + 1:
		vorher.append(j)
	for i in range(1, a.length() + 1):
		var jetzt: Array[int] = [i]
		for j in range(1, b.length() + 1):
			var kosten := 0 if a[i - 1] == b[j - 1] else 1
			jetzt.append(mini(mini(vorher[j] + 1, jetzt[j - 1] + 1), vorher[j - 1] + kosten))
		vorher = jetzt
	return vorher[b.length()]
