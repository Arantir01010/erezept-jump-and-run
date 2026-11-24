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
var default_lang := "de"
const LANGS := ["de", "en", "fr", "es", "zh", "hi"]
const LANG_NAMES := {"de": "Deutsch", "en": "English", "fr": "Français", "es": "Español", "zh": "中文", "hi": "हिन्दी"}
signal lang_changed(code)

# --- Durchlauf ---
var level_index := 0
var bits := 0
var score := 0
var seals: Array = []
var encrypted := false
var clean_interactions := 0
var lauf_start := 0.0          # Spielzeit beim Laufbeginn (s), siehe spielzeit
var level_results: Array = []
## Wissensabfrage am Ende (Quiz.gd): -1 = noch nicht gefragt.
var wissen_richtig := -1
var wissen_fragen := 0
var protokoll: Array = []
var combo := 0
var combo_until := 0.0
var _level_start_bits := 0
var _bits_per_level := {}
## Stand bei Stationsbeginn — Ziel von „Station neu starten" (Pausemenü).
var _start_stand := {}

# --- Karten (Identität, keine Währung) ---
var cards: Array = []
var card_slots := {}

# --- Hilfen ---
var assist_fails := {}


## Spielzeit in Sekunden: zählt im Physiktakt, steht in der Pause und folgt der
## Zeitlupe (Fx). Kombo-Fenster und Laufzeit hängen daran statt an der Wanduhr: Die
## Pause bricht keine Kombo mehr ab, und ein Durchspiel mit --fixed-fps ergibt jedes
## Mal dieselben Punkte. Messe-Statistik und Kiosk-Leerlauf messen bewusst echte Zeit.
var spielzeit := 0.0


func _ready() -> void:
	load_config()
	reset_run()


func _physics_process(delta: float) -> void:
	spielzeit += delta


func load_config() -> void:
	config = _read_json("res://config/game-config.json")
	themes = _read_json("res://config/themes.json")
	bindings = _read_json("res://config/input-bindings.json")
	var pl = _read_json("res://config/playlist.json")
	playlist = pl if pl is Array else []
	default_lang = str(config.get("language", "de"))
	# Browser-Fassung: mit der Sprache des Browsers starten, wenn wir sie haben
	# (Messe-Paket 3). Am Messe-PC bleibt es bei „language" aus der Konfiguration.
	if OS.has_feature("web") and LANGS.has(OS.get_locale_language()):
		default_lang = OS.get_locale_language()
	_load_translations()
	set_lang(default_lang)


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


## Lokalisierter Text: {de, en} → String. Hat der Eintrag die Sprache nicht, wird der
## deutsche Text über die Übersetzungstabelle (i18n/*.json) übersetzt; Strings ebenso.
func t(ltext: Variant, fallback := "") -> String:
	if ltext is String:
		return str(TranslationServer.translate(ltext))
	if ltext is Dictionary:
		if ltext.has(lang) and str(ltext[lang]) != "":
			return str(ltext[lang])
		if ltext.has("de") and str(ltext["de"]) != "":
			return str(TranslationServer.translate(str(ltext["de"])))
		for k in ltext:
			return str(ltext[k])
	return fallback


## Übersetzungen aus i18n/*.json: {deutscher Text: {en: …, fr: …, es: …, zh: …, hi: …}}
## → eine Translation je Sprache im TranslationServer. Deutsch ist der Schlüssel selbst.
func _load_translations() -> void:
	var dir := DirAccess.open("res://i18n")
	if dir == null:
		push_warning("i18n/ fehlt — nur Deutsch verfügbar")
		return
	var by_lang := {}
	for lc in LANGS:
		var tl := Translation.new()
		tl.locale = lc
		by_lang[lc] = tl
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var d = _read_json("res://i18n/" + fname)
			if d is Dictionary:
				for key in d:
					if str(key).begins_with("_"):
						continue
					var row = d[key]
					if row is Dictionary:
						# Deutsch = der Schlüssel selbst; ohne diesen Eintrag griffe Godots
						# Fallback-Sprache (en) und Deutsch erschiene englisch.
						(by_lang["de"] as Translation).add_message(str(key), str(key))
						for lc in row:
							if by_lang.has(lc) and str(row[lc]) != "":
								(by_lang[lc] as Translation).add_message(str(key), str(row[lc]))
		fname = dir.get_next()
	dir.list_dir_end()
	for lc in by_lang:
		TranslationServer.add_translation(by_lang[lc])


## Sprache umschalten: Labels übersetzen sich selbst (auto_translate), formatierte
## Texte holen sich tr() beim nächsten Aufbau. Unbekannte Codes → Deutsch.
func set_lang(code: String) -> void:
	if not LANGS.has(code):
		code = "de"
	lang = code
	TranslationServer.set_locale(code)
	lang_changed.emit(code)


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
	lauf_start = spielzeit
	level_results = []
	wissen_richtig = -1
	wissen_fragen = 0
	protokoll = []
	combo = 0
	combo_until = 0.0
	_level_start_bits = 0
	_bits_per_level = {}
	cards = []
	card_slots = {}
	assist_fails = {}
	_start_stand = {}
	hud_changed.emit()


## Stationsbeginn (Level.setup): Zählstand für die Tür merken und den ganzen
## Stand sichern, auf den „Station neu starten" zurückspringt.
func mark_level_start() -> void:
	_level_start_bits = bits
	combo = 0
	combo_until = 0.0
	_start_stand = {
		"bits": bits, "score": score, "encrypted": encrypted,
		"clean_interactions": clean_interactions, "protokoll": protokoll.duplicate(true),
		"cards": cards.duplicate(), "card_slots": card_slots.duplicate(),
		"seals": seals.duplicate(true), "level_results": level_results.duplicate(true),
		"bits_per_level": _bits_per_level.duplicate(),
	}
	hud_changed.emit()


## „Station neu starten" (Pausemenü, Team-Feedback 9/2026): Alles, was in dieser
## Station gesammelt, verloren, gesteckt oder protokolliert wurde, springt auf den
## Stand bei Stationsbeginn zurück. Die Hilfen (assist_fails) bleiben bewusst:
## Wer an einem Terminal festhing, bekommt die Verlangsamung auch im neuen Versuch.
func restore_level_start() -> void:
	if _start_stand.is_empty():
		return
	var s := _start_stand
	bits = int(s["bits"])
	score = int(s["score"])
	encrypted = bool(s["encrypted"])
	clean_interactions = int(s["clean_interactions"])
	protokoll = (s["protokoll"] as Array).duplicate(true)
	cards = (s["cards"] as Array).duplicate()
	card_slots = (s["card_slots"] as Dictionary).duplicate()
	seals = (s["seals"] as Array).duplicate(true)
	level_results = (s["level_results"] as Array).duplicate(true)
	_bits_per_level = (s["bits_per_level"] as Dictionary).duplicate()
	_level_start_bits = bits
	combo = 0
	combo_until = 0.0
	hud_changed.emit()


func bits_this_level() -> int:
	return maxi(0, bits - _level_start_bits)


func add_bits(n: int, bonus := false) -> void:
	bits += n
	var now := spielzeit
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
## Abgezogen wird nur, was in DIESER Station gesammelt wurde: Die Tür zählt
## bits_this_level(). Früher ging der Abzug vom Gesamtkonto — wer zu Beginn
## getroffen wurde, sah weiter 0, und die nächsten Prüfsummen zählten unsichtbar
## nicht mit (Team-Feedback 9/2026).
func lose_bits(max_loss: int) -> int:
	var lost := mini(bits_this_level(), max_loss)
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


## Laufzeit in Spielzeit (ohne Pausen), für Abschluss und Zugriffsprotokoll.
func elapsed_seconds() -> float:
	return spielzeit - lauf_start


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


## Quiz vorbei: alle richtig = vierte Medaille „WISSEN“ (Punkte wie jede Medaille).
func wissen_abschliessen(richtig: int, gesamt: int) -> void:
	wissen_richtig = richtig
	wissen_fragen = gesamt
	if gesamt > 0 and richtig >= gesamt:
		score += MEDAL_BONUS
	hud_changed.emit()


func wissen_medaille() -> bool:
	return wissen_fragen > 0 and wissen_richtig >= wissen_fragen


## Level abgeschlossen: Medaillen (Zeit / Prüfsummen / Lückenlos) und Punkte.
## mit_lauschern = false: LÜCKENLOS zählt nicht (Station ohne Lauscher, Messe-Paket 3).
func finish_level(level_id: String, time_s: float, par_s: float, bits_total: int, mit_lauschern := true) -> Dictionary:
	var got := bits_this_level()
	var seen := seen_in(level_id)
	var medals := {
		"zeit": time_s <= par_s,
		"bits": bits_total > 0 and got >= bits_total,
		"lueckenlos": mit_lauschern and seen == 0,
	}
	var medal_count := 0
	for k in medals:
		if medals[k]:
			medal_count += 1
	score += medal_count * MEDAL_BONUS
	var result := {
		"level_id": level_id, "time": time_s, "par": par_s,
		"bits": got, "bits_total": bits_total, "seen": seen,
		"medals": medals, "medal_count": medal_count, "mit_lauschern": mit_lauschern,
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
	if not (entries is Array):
		return []
	# Nur gültige Einträge: eine halb geschriebene oder von Hand bearbeitete Datei
	# darf weder den Titel noch den Abschluss-Bildschirm abbrechen.
	var ok: Array = []
	for e in entries:
		if e is Dictionary and (e.get("score") is float or e.get("score") is int):
			ok.append({"avatar": absi(int(e.get("avatar", 0))), "score": int(e["score"])})
	ok.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	return ok


func qualifies(points: int) -> bool:
	var hs := highscores()
	return points > 0 and (hs.size() < 5 or int(hs[hs.size() - 1]["score"]) < points)


func add_highscore(avatar: int, points: int) -> void:
	var hs := highscores()
	hs.append({"avatar": avatar, "score": points})
	hs.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if hs.size() > 5:
		hs.resize(5)
	_write_json_atomic(HIGHSCORE_PATH, {"date": _today(), "entries": hs})


## Erst in eine Nachbardatei schreiben, dann umbenennen: Stromausfall oder Absturz
## mitten im Schreiben hinterlässt so die alte, heile Bestenliste statt einer halben.
static func _write_json_atomic(path: String, data: Variant) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK


static func _read_json_user(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
