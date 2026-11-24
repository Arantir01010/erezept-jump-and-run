extends "res://tests/testfall.gd"
## Texte und Übersetzungen (i18n/*.json): Deutsch ist der Schlüssel, jede Zeile
## braucht alle fünf Sprachen mit denselben Platzhaltern (%d, %s …) — sonst
## stürzt die Formatierung in einer Sprache ab oder zeigt Unsinn.
## Neue oder geänderte deutsche Texte ohne Übersetzung fallen hier auf.

const SPRACHEN := ["en", "fr", "es", "zh", "hi"]


func _tabellen() -> Dictionary:
	var alle := {}
	for f in DirAccess.get_files_at("res://i18n"):
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/" + f))
		if pruefe(d is Dictionary, "i18n/%s ist kein gültiges JSON-Objekt" % f):
			alle[f] = d
	return alle


func _schluessel() -> Dictionary:
	var k := {}
	var tabellen := _tabellen()
	for f in tabellen:
		for key in tabellen[f]:
			if not str(key).begins_with("_"):
				k[str(key)] = true
	return k


## Platzhalter für den %-Operator. Ohne Leerzeichen-Flag: „30 % se" (es) ist
## Fließtext, kein Platzhalter.
static func _platzhalter(s: String) -> Array:
	var re := RegEx.create_from_string("%[-+0-9.]*[dsfxX%]")
	var out: Array = []
	for m in re.search_all(s):
		out.append(m.get_string())
	out.sort()
	return out


func test_jede_zeile_hat_alle_sprachen() -> void:
	var tabellen := _tabellen()
	pruefe(tabellen.size() >= 1, "keine i18n-Tabellen gefunden")
	for f in tabellen:
		var d: Dictionary = tabellen[f]
		for key in d:
			if str(key).begins_with("_"):
				continue
			var zeile = d[key]
			if not pruefe(zeile is Dictionary, "%s: '%s' ist keine Zeile" % [f, key]):
				continue
			for lc in SPRACHEN:
				pruefe(str(zeile.get(lc, "")).strip_edges() != "", "%s: '%s' fehlt in %s" % [f, str(key).left(50), lc])


func test_platzhalter_stimmen_ueberein() -> void:
	var tabellen := _tabellen()
	for f in tabellen:
		var d: Dictionary = tabellen[f]
		for key in d:
			if str(key).begins_with("_") or not (d[key] is Dictionary):
				continue
			var soll := _platzhalter(str(key))
			for lc in SPRACHEN:
				var ist := _platzhalter(str(d[key].get(lc, "")))
				pruefe(ist == soll, "%s/%s: '%s' Platzhalter %s statt %s" % [f, lc, str(key).left(40), ist, soll])


func test_tr_texte_im_code_sind_uebersetzt() -> void:
	# Jeder feste Text in tr("…") / Game.t("…") muss in einer i18n-Tabelle stehen.
	var k := _schluessel()
	var re := RegEx.create_from_string("\\b(?:tr|Game\\.t)\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	for pfad in dateien("res://src", ".gd"):
		var text := FileAccess.get_file_as_string(pfad)
		for m in re.search_all(text):
			var s := m.get_string(1).c_unescape()
			pruefe(k.has(s), "%s: tr(\"%s\") ohne Übersetzung" % [pfad.get_file(), s.left(60)])


func test_stationstexte_sind_uebersetzt() -> void:
	# Stationsname, Portal- und REZI-Text, Schilder: {de: …} ohne fr/es/zh/hi wird
	# über die i18n-Tabelle übersetzt — der deutsche Text muss dort stehen.
	var k := _schluessel()
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		var texte: Array = []
		_sammle(d.json, texte)
		for o in d.objects:
			if o.has("textDe"):
				texte.append(str(o["textDe"]))
		for s in texte:
			pruefe(k.has(s), "%s: \"%s\" ohne Übersetzung" % [id, str(s).left(60)])


func _sammle(v: Variant, out: Array) -> void:
	if v is Dictionary:
		if v.has("de") and v["de"] is String and str(v["de"]) != "":
			var voll := true
			for lc in ["fr", "es", "zh", "hi"]:
				voll = voll and v.has(lc)
			if not voll:
				out.append(str(v["de"]))
		for key in v:
			_sammle(v[key], out)
	elif v is Array:
		for x in v:
			_sammle(x, out)

