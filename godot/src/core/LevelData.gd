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

const SOLID_CHARS := "#=GA~%"
const MARKERS := {"P": "spawn", "o": "collectible", "C": "checkpoint", "D": "door-exit",
	"*": "bonus", "^": "spring", "x": "spike"}

## Standardgrößen in Kacheln (tools/lib/catalog.ts).
const DEFAULTS := {
	"gate": [0.5, 6], "timing-gate": [8, 5], "stillstand-podest": [3, 0.4],
	"krypto-dusche": [5, 6], "deny-enemy": [1.4, 0.4], "stamp-exit": [6, 6],
	"letzte-tuer": [3, 6], "info-sign": [2.5, 4], "moving-platform": [2, 0.4],
	"hazard": [1, 1], "lauscher": [1, 1], "andock-plattform": [3, 0.4],
	"vau-feld": [6, 5], "kontext-anker": [1, 1.5], "karte": [1.2, 0.8],
	"kartenleser": [3, 3], "deco": [1.5, 1.5],
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


static func level_dir(level_id: String) -> String:
	for base in ["res://levels/", "res://levels/_import/"]:
		if FileAccess.file_exists(base + level_id + "/layout.txt"):
			return base + level_id + "/"
	return ""


static func load_level(level_id: String) -> LevelData:
	var data := LevelData.new()
	data.id = level_id
	var dir := level_dir(level_id)
	if dir == "":
		data.errors.append("Level %s nicht gefunden" % level_id)
		return data
	data._parse_layout(FileAccess.get_file_as_string(dir + "layout.txt"))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir + "level.json"))
	if parsed is Dictionary:
		data._parse_json(parsed)
	else:
		data.errors.append("level.json von %s ist kein gültiges JSON" % level_id)
	return data


func _parse_layout(text: String) -> void:
	var lines := text.replace("\r", "").split("\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	height = lines.size()
	if height != Game.GRID_HEIGHT:
		errors.append("layout.txt hat %d Zeilen (erwartet %d)" % [height, Game.GRID_HEIGHT])
	width = 0
	for l in lines:
		width = maxi(width, l.length())
	rows.clear()
	for y in lines.size():
		var line := lines[y]
		var row := ""
		for x in width:
			var ch := line[x] if x < line.length() else "."
			if MARKERS.has(ch):
				markers.append({"type": MARKERS[ch], "tx": x, "ty": y})
				if ch == "o" or ch == "*":
					bits_total += 1
				row += "."
			elif ch == " ":
				row += "."
			else:
				row += ch
		rows.append(row)


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
		var o: Dictionary = raw.duplicate()
		var t := str(o["type"])
		var def: Array = DEFAULTS.get(t, [1, 1])
		if not o.has("tw"):
			o["tw"] = def[0]
		if not o.has("th"):
			o["th"] = def[1]
		objects.append(o)


## Parameter eines Objekts: erst am Objekt, dann level-weit unter mechanics[typ].
func param(obj: Dictionary, key: String, fallback: Variant) -> Variant:
	if obj.has(key):
		return obj[key]
	var m: Dictionary = mechanics.get(str(obj.get("type", "")), {})
	if m.has(key):
		return m[key]
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
