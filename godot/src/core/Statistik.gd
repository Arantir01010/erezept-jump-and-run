class_name Statistik
extends RefCounted
## STATISTIK — anonyme Zählung für den Messebetrieb und Playtests (Messe-Paket 2,
## 11/2026). Keine Namen, keine Eingaben, nichts verlässt den Rechner.
##
## Zwei Dateien je Tag unter user://statistik/:
##   tag-JJJJ-MM-TT.json         Tagessumme (Betreiber-Menü, schneller Überblick)
##   ereignisse-JJJJ-MM-TT.jsonl eine Zeile je Ereignis mit zufälliger Lauf-ID —
##                                daraus wertet tools/statistik_auswerten.py
##                                Abbruchstellen, Zeiten (Median) und Quoten aus.
## Ereignisse: lauf_start, station_start, station_ende, neustart, lauf_ende
## (grund: geschafft | idle | hauptmenue). Treffer und Stürze zählen je Station
## und stehen in station_ende/neustart/lauf_ende.
##
## Testläufe (--script, --headless, Prüflauf --shots) schreiben nach
## user://statistik-test/, damit sie die echte Messestatistik nie fortschreiben.

const ZEITEN_MAX := 2000

static var _lauf_id := ""
static var _lauf_start_ms := 0
static var _station := ""
static var _station_start_ms := 0
static var _treffer := 0
static var _stuerze := 0
static var ordner_override := ""


static func ordner() -> String:
	if ordner_override != "":
		return ordner_override
	return "user://statistik-test" if ist_testlauf() else "user://statistik"


static func ist_testlauf() -> bool:
	var ml := Engine.get_main_loop()
	if ml != null and ml.get_script() != null:
		return true    # --script (Testlauf, Standbild)
	if DisplayServer.get_name() == "headless":
		return true
	var k = ml.root.get_node_or_null("Kiosk") if ml is SceneTree else null
	return k != null and str(k.get("shots_dir")) != ""


static func _heute() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func lauf_aktiv() -> bool:
	return _lauf_id != ""


static func station_aktiv() -> String:
	return _station


# ------------------------------------------------------------------ Ereignisse

## Neuer Durchlauf (Spieler startet nach Zeitreise/Probelauf mit Station 1).
static func lauf_start(sprache: String, bedienung: String) -> void:
	if lauf_aktiv():
		lauf_ende("abgebrochen")
	_lauf_id = "%08x" % (randi() & 0x7fffffff)
	_lauf_start_ms = Time.get_ticks_msec()
	_ereignis("lauf_start", {"sprache": sprache, "bedienung": bedienung})
	var s := _summe()
	s["laeufe"] = int(s.get("laeufe", 0)) + 1
	_zaehle(s, "sprachen", sprache)
	_zaehle(s, "bedienung", bedienung)
	_speichern(s)


static func station_start(id: String) -> void:
	_station = id
	_station_start_ms = Time.get_ticks_msec()
	_treffer = 0
	_stuerze = 0
	_ereignis("station_start", {"station": id})
	var s := _summe()
	_st(s, id)["erreicht"] += 1
	_speichern(s)


static func treffer() -> void:
	_treffer += 1


static func sturz() -> void:
	_stuerze += 1


static func station_ende(sekunden: float) -> void:
	if _station == "":
		return
	var id := _station
	_ereignis("station_ende", {"station": id, "sekunden": snappedf(sekunden, 0.1), "treffer": _treffer, "stuerze": _stuerze})
	var s := _summe()
	var st := _st(s, id)
	st["geschafft"] += 1
	st["treffer"] += _treffer
	st["stuerze"] += _stuerze
	var z: Array = st["zeiten"]
	if z.size() < ZEITEN_MAX:
		z.append(snappedf(sekunden, 0.1))
	_speichern(s)
	_station = ""


## „Station neu starten" (Pausemenü): Versuch zählt, Station läuft neu an.
static func neustart() -> void:
	if _station == "":
		return
	var id := _station
	_ereignis("neustart", {"station": id, "sekunden": _seit(_station_start_ms), "treffer": _treffer, "stuerze": _stuerze})
	var s := _summe()
	var st := _st(s, id)
	st["neustarts"] += 1
	st["treffer"] += _treffer
	st["stuerze"] += _stuerze
	_speichern(s)
	_station_start_ms = Time.get_ticks_msec()
	_treffer = 0
	_stuerze = 0


## Durchlauf vorbei. grund: "geschafft", "idle" (Idle-Reset im Kiosk),
## "hauptmenue" (Pausemenü → Hauptmenü) oder "abgebrochen".
static func lauf_ende(grund: String) -> void:
	if not lauf_aktiv():
		return
	var daten := {"grund": grund, "sekunden": _seit(_lauf_start_ms)}
	if _station != "":
		daten["station"] = _station
		daten["treffer"] = _treffer
		daten["stuerze"] = _stuerze
	_ereignis("lauf_ende", daten)
	var s := _summe()
	if grund == "geschafft":
		s["laeufe_fertig"] = int(s.get("laeufe_fertig", 0)) + 1
		var z: Array = s.get("gesamtzeiten", [])
		if z.size() < ZEITEN_MAX:
			z.append(_seit(_lauf_start_ms))
		s["gesamtzeiten"] = z
	elif _station != "":
		var st := _st(s, _station)
		st["abbrueche"] += 1
		if grund == "idle":
			st["idle"] += 1
		st["treffer"] += _treffer
		st["stuerze"] += _stuerze
	_speichern(s)
	_lauf_id = ""
	_station = ""


# ------------------------------------------------------------------ Auswertung

## Tagessumme (für das Betreiber-Menü).
static func summe(tag := "") -> Dictionary:
	return _summe(tag)


static func median(werte: Array) -> float:
	if werte.is_empty():
		return 0.0
	var w := werte.duplicate()
	w.sort()
	var n := w.size()
	return float(w[n / 2]) if n % 2 == 1 else (float(w[n / 2 - 1]) + float(w[n / 2])) / 2.0


# ------------------------------------------------------------------ intern

static func _seit(ms: int) -> float:
	return snappedf((Time.get_ticks_msec() - ms) / 1000.0, 0.1)


static func _pfad(name: String, tag := "") -> String:
	return ordner().path_join("%s-%s" % [name, tag if tag != "" else _heute()])


static func _ereignis(art: String, daten: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ordner())
	var pfad := _pfad("ereignisse") + ".jsonl"
	var f := FileAccess.open(pfad, FileAccess.READ_WRITE if FileAccess.file_exists(pfad) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var zeile := {"zeit": Time.get_datetime_string_from_system(), "lauf": _lauf_id, "art": art}
	zeile.merge(daten)
	f.store_line(JSON.stringify(zeile))


static func _summe(tag := "") -> Dictionary:
	var pfad := _pfad("tag", tag) + ".json"
	var s = null
	if FileAccess.file_exists(pfad):
		s = JSON.parse_string(FileAccess.get_file_as_string(pfad))
	if not (s is Dictionary):
		s = {}
	s["datum"] = tag if tag != "" else _heute()
	if not (s.get("stationen") is Dictionary):
		s["stationen"] = {}
	return s


static func _st(s: Dictionary, id: String) -> Dictionary:
	var stn: Dictionary = s["stationen"]
	var st = stn.get(id)
	if not (st is Dictionary):
		st = {}
	for k in ["erreicht", "geschafft", "treffer", "stuerze", "neustarts", "abbrueche", "idle"]:
		st[k] = int(st.get(k, 0))
	if not (st.get("zeiten") is Array):
		st["zeiten"] = []
	stn[id] = st
	return st


static func _zaehle(s: Dictionary, feld: String, wert: String) -> void:
	var d = s.get(feld)
	if not (d is Dictionary):
		d = {}
	d[wert] = int(d.get(wert, 0)) + 1
	s[feld] = d


static func _speichern(s: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ordner())
	Game._write_json_atomic(_pfad("tag") + ".json", s)

