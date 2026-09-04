extends Node
## GAME — Zustand eines Spieldurchlaufs, Konfiguration, Zugriffsprotokoll,
## Medaillen und Tages-Highscore. Autoload, überall als `Game` erreichbar.
##
## Bewusst ohne Persistenz außer dem Tages-Highscore (user://highscore.json,
## nur Avatar-Index + Punkte — keine Personendaten).

signal hud_changed
signal bits_changed(delta: int)
signal combo_changed(combo: int)

## Eine Kachel im Godot-Raum. Die Level sind in 16-px-Kacheln gezeichnet
## (design/), gerendert wird 3× so groß: 1920×1080 zeigt 40×22,5 Kacheln.
const TILE := 48.0
const GRID_HEIGHT := 23

const POINTS_PER_BIT := 10
const POINTS_PER_BONUS := 50
const POINTS_PER_SEAL := 1000
const SECURITY_BONUS := 250
const MEDAL_BONUS := 300
const COMBO_WINDOW := 1.1

var config := {}
var themes := {}
var bindings := {}
var playlist: Array = []
var lang := "de"

# --- Durchlauf ---
var level_index := 0
var bits := 0
var score := 0
var seals: Array = []
var encrypted := false
var clean_interactions := 0
var run_start_ms := 0
var level_results: Array = []
var protokoll: Array = []
var combo := 0
var combo_until := 0.0
var _level_start_bits := 0
var _bits_per_level := {}

# --- Karten (Identität, keine Währung) ---
var cards: Array = []
var card_slots := {}

# --- Hilfen ---
var assist_fails := {}


func _ready() -> void:
	load_config()
	reset_run()


func load_config() -> void:
	config = _read_json("res://config/game-config.json")
	themes = _read_json("res://config/themes.json")
	bindings = _read_json("res://config/input-bindings.json")
	var pl = _read_json("res://config/playlist.json")
	playlist = pl if pl is Array else []
	lang = str(config.get("language", "de"))


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Konfiguration fehlt: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("JSON kaputt: %s" % path)
		return {}
	return parsed


## Lokalisierter Text: {de, en} → String. Strings gehen unverändert durch.
func t(ltext: Variant, fallback := "") -> String:
	if ltext is String:
		return ltext
	if ltext is Dictionary:
		if ltext.has(lang) and str(ltext[lang]) != "":
			return str(ltext[lang])
		if ltext.has("de"):
			return str(ltext["de"])
		for k in ltext:
			return str(ltext[k])
	return fallback


func theme(name: String) -> Dictionary:
	if themes.has(name):
		return themes[name]
	if themes.has("city"):
		return themes["city"]
	return {}


# ------------------------------------------------------------------ Durchlauf

func reset_run() -> void:
	level_index = 0
	bits = 0
	score = 0
	seals = []
	encrypted = false
	clean_interactions = 0
	run_start_ms = Time.get_ticks_msec()
	level_results = []
	protokoll = []
	combo = 0
	combo_until = 0.0
	_level_start_bits = 0
	_bits_per_level = {}
	cards = []
	card_slots = {}
	assist_fails = {}
	hud_changed.emit()


func mark_level_start() -> void:
	_level_start_bits = bits
	combo = 0
	hud_changed.emit()


func bits_this_level() -> int:
	return maxi(0, bits - _level_start_bits)


func add_bits(n: int, bonus := false) -> void:
	bits += n
	var now := Time.get_ticks_msec() / 1000.0
	if now <= combo_until:
		combo += 1
	else:
		combo = 1
	combo_until = now + COMBO_WINDOW
	var mult := 1 + mini(combo - 1, 9) * 0.25
	score += int(round((POINTS_PER_BONUS if bonus else POINTS_PER_BIT) * n * mult))
	bits_changed.emit(n)
	combo_changed.emit(combo)
	hud_changed.emit()


## Sonic-Prinzip: Treffer kostet ein paar Bits, nie den Fortschritt.
func lose_bits(max_loss: int) -> int:
	var lost := mini(bits, max_loss)
	bits -= lost
	combo = 0
	combo_until = 0.0
	if lost > 0:
		bits_changed.emit(-lost)
	hud_changed.emit()
	return lost


func add_seal(seal_id: String, level_id: String) -> void:
	seals.append({"seal_id": seal_id, "level_id": level_id})
	_bits_per_level[level_id] = bits_this_level()
	score += POINTS_PER_SEAL
	hud_changed.emit()


func add_security_bonus() -> void:
	clean_interactions += 1
	score += SECURITY_BONUS
	hud_changed.emit()


func elapsed_seconds() -> float:
	return (Time.get_ticks_msec() - run_start_ms) / 1000.0


## Endscreen-Rang als Sicherheitsstufe.
func rank() -> Dictionary:
	if clean_interactions >= 3 and bits >= 12:
		return {"key": "gold", "label": {"de": "TI-zertifiziert", "en": "TI certified"}}
	if clean_interactions >= 1:
		return {"key": "silber", "label": {"de": "Stark verschlüsselt", "en": "Strongly encrypted"}}
	return {"key": "bronze", "label": {"de": "Gut geschützt", "en": "Well protected"}}


## Zugriffsprotokoll: „gesehen" (Lauscher) — die Währung des Siegels „Lückenlos".
func mark_seen(level_id: String, actor: String) -> void:
	protokoll.append({"level_id": level_id, "t": elapsed_seconds(), "actor": actor})


func seen_in(level_id: String) -> int:
	var n := 0
	for e in protokoll:
		if e["level_id"] == level_id:
			n += 1
	return n


## Level abgeschlossen: Medaillen (Zeit / Prüfsummen / Lückenlos) und Punkte.
func finish_level(level_id: String, time_s: float, par_s: float, bits_total: int) -> Dictionary:
	var got := bits_this_level()
	var seen := seen_in(level_id)
	var medals := {
		"zeit": time_s <= par_s,
		"bits": bits_total > 0 and got >= bits_total,
		"lueckenlos": seen == 0,
	}
	var medal_count := 0
	for k in medals:
		if medals[k]:
			medal_count += 1
	score += medal_count * MEDAL_BONUS
	var result := {
		"level_id": level_id, "time": time_s, "par": par_s,
		"bits": got, "bits_total": bits_total, "seen": seen,
		"medals": medals, "medal_count": medal_count,
	}
	level_results.append(result)
	hud_changed.emit()
	return result


# ------------------------------------------------------------------ Karten

func has_card(card: String) -> bool:
	return cards.has(card)


func add_card(card: String) -> void:
	if not cards.has(card):
		cards.append(card)
	hud_changed.emit()


## Terminal steckt die erste passende Karte. Ergebnisse: ok | nicht-dabei |
## falsche-karte | belegt (siehe KAPSEL 2.1, Paket B1).
func insert_card(accepted: Array, terminal_id: String) -> Dictionary:
	var matching: Array = []
	for c in cards:
		if accepted.has(c):
			matching.append(c)
	if matching.is_empty():
		return {"result": "falsche-karte" if cards.size() > 0 else "nicht-dabei", "card": ""}
	for c in matching:
		var slot = card_slots.get(c, "")
		if slot == "" or slot == terminal_id:
			card_slots[c] = terminal_id
			hud_changed.emit()
			return {"result": "ok", "card": c}
	return {"result": "belegt", "card": matching[0]}


func remove_card_from(terminal_id: String) -> void:
	for c in card_slots.keys():
		if card_slots[c] == terminal_id:
			card_slots.erase(c)
	hud_changed.emit()


# ------------------------------------------------------------------ Assist

func assist_fail(key: String) -> void:
	assist_fails[key] = int(assist_fails.get(key, 0)) + 1


func assist_fail_count(key: String) -> int:
	return int(assist_fails.get(key, 0))


## Verlangsamung nach Fehlversuchen (×1,3 / ×1,6), Framing: „die TI sichert dich ab".
func assist_slowdown(key: String) -> float:
	var n := assist_fail_count(key)
	if n >= 2:
		return 1.6
	if n == 1:
		return 1.3
	return 1.0


func assist_clean(key: String) -> bool:
	return assist_fail_count(key) == 0


# ------------------------------------------------------------------ Highscore

const HIGHSCORE_PATH := "user://highscore.json"


func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func highscores() -> Array:
	var data = _read_json_user(HIGHSCORE_PATH)
	if not (data is Dictionary) or data.get("date", "") != _today():
		return []
	var entries = data.get("entries", [])
	return entries if entries is Array else []


func qualifies(points: int) -> bool:
	var hs := highscores()
	return points > 0 and (hs.size() < 5 or int(hs[hs.size() - 1]["score"]) < points)


func add_highscore(avatar: int, points: int) -> void:
	var hs := highscores()
	hs.append({"avatar": avatar, "score": points})
	hs.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if hs.size() > 5:
		hs.resize(5)
	var f := FileAccess.open(HIGHSCORE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"date": _today(), "entries": hs}))


static func _read_json_user(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
