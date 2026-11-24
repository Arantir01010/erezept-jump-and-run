extends "res://tests/testfall.gd"
## HERKUNFT (assets/HERKUNFT.json): Jede Nicht-Code-Datei unter assets/ und brand/ hat
## einen Eintrag mit Quelle, Urheber, Lizenz und Werkzeug; jeder Eintrag (außer „lokal“
## = gitignoriertes Brand-Paket) trifft mindestens eine Datei. GEGENPROBE: eine neue Datei
## ohne Eintrag, ein Eintrag ohne Datei, unvollständige Einträge und „lokal“ außerhalb der
## gitignorierten Ordner werden gemeldet; die Musik-Muster halten den Wechsel MP3 ⇄ OGG aus.

const LISTE := "res://assets/HERKUNFT.json"
const WURZELN := ["assets", "brand"]
const FELDER := ["muster", "quelle", "autor", "lizenz", "abgerufen", "erzeugt_von", "hinweis"]
const OPTIONAL := ["lokal"]
const LIZENZ_FELDER := ["name", "link", "kurzfassung"]
const MUSIK := ["title", "level", "level2", "reward"]


# ------------------------------------------------------------------ Werkzeuge

static func liste() -> Dictionary:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(LISTE)) != OK or not j.data is Dictionary:
		return {}
	return j.data


static func eintraege() -> Array:
	var e = liste().get("eintraege", [])
	return e if e is Array else []


## Regeln aus godot/.gitignore (ohne Kommentare). „x/“ = Ordner; mit „/“ davor oder in
## der Mitte an godot/ gebunden, sonst in jeder Tiefe (wie git).
static func ignorier_regeln() -> Array[String]:
	var out: Array[String] = []
	for zeile in FileAccess.get_file_as_string("res://.gitignore").split("\n"):
		var z := zeile.strip_edges()
		if z != "" and not z.begins_with("#"):
			out.append(z)
	return out


## Pfad relativ zu godot/ (Ordner mit „/“ am Ende, auch ein Glob-Muster) liegt in einem
## gitignorierten Bereich.
static func ist_ignoriert(pfad: String, regeln: Array[String]) -> bool:
	for regel in regeln:
		var r := regel.trim_prefix("/")
		if r.ends_with("/"):
			var kern := r.trim_suffix("/")
			if kern.contains("/") or regel.begins_with("/"):
				if pfad.begins_with(r):
					return true
			elif ("/" + pfad).contains("/" + r):
				return true
		elif pfad.get_file().match(r) or pfad.match(r):
			return true
	return false


## Alle Dateien unter assets/ und brand/ (relativ zu godot/), ohne .import/.uid und ohne
## gitignorierte Pfade. Versteckte Dateien zählen mit (brand/.gdignore).
static func bestand(regeln: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for w in WURZELN:
		_sammeln(w, regeln, out)
	out.sort()
	return out


static func _sammeln(rel: String, regeln: Array[String], out: Array[String]) -> void:
	var d := DirAccess.open("res://" + rel)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		var p := rel.path_join(f)
		if not (f.ends_with(".import") or f.ends_with(".uid") or ist_ignoriert(p, regeln)):
			out.append(p)
	for sub in d.get_directories():
		var p := rel.path_join(sub)
		if not ist_ignoriert(p + "/", regeln):
			_sammeln(p, regeln, out)


## Glob wie in HERKUNFT.json: * und ? bleiben in einem Ordner, ** geht über Ordner hinweg.
static func passt(muster: String, pfad: String) -> bool:
	var r := "^"
	var i := 0
	while i < muster.length():
		var c := muster[i]
		if c == "*" and i + 1 < muster.length() and muster[i + 1] == "*":
			r += ".*"
			i += 1
		elif c == "*":
			r += "[^/]*"
		elif c == "?":
			r += "[^/]"
		elif ".+()^$|[]{}\\".contains(c):
			r += "\\" + c
		else:
			r += c
		i += 1
	return RegEx.create_from_string(r + "$").search(pfad) != null


static func muster_von(e: Variant) -> Array:
	if not e is Dictionary:
		return []
	var m = e.get("muster", [])
	if m is String:
		return [m]
	return m if m is Array else []


static func _trifft(e: Variant, pfad: String) -> bool:
	for m in muster_von(e):
		if m is String and passt(m, pfad):
			return true
	return false


## Dateien, zu denen kein Eintrag passt.
static func ungedeckt(liste_: Array, dateien: Array) -> Array[String]:
	var out: Array[String] = []
	for p in dateien:
		if not liste_.any(func(e): return _trifft(e, p)):
			out.append(p)
	return out


## Einträge ohne „lokal“, die keine einzige Datei treffen.
static func unbenutzt(liste_: Array, dateien: Array) -> Array[String]:
	var out: Array[String] = []
	for e in liste_:
		if e is Dictionary and e.get("lokal", false) == true:
			continue
		if not dateien.any(func(p): return _trifft(e, p)):
			out.append(str(muster_von(e)))
	return out


## Formfehler eines Eintrags (leer = in Ordnung).
static func eintrag_fehler(e: Variant, regeln: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if not e is Dictionary:
		return ["kein Objekt"]
	for f in FELDER:
		if not e.has(f):
			out.append("Feld „%s“ fehlt" % f)
	for f in e:
		if not (f in FELDER or f in OPTIONAL):
			out.append("unbekanntes Feld „%s“" % f)
	var muster := muster_von(e)
	if muster.is_empty():
		out.append("muster fehlt")
	for m in muster:
		if not m is String or m == "" or m.begins_with("/") or m.contains("://") or m.contains(".."):
			out.append("muster „%s“ ist kein Pfad relativ zu godot/" % str(m))
	for f in FELDER:
		if f != "muster" and f != "lizenz" and e.has(f) and not e[f] is String:
			out.append("%s ist kein Text" % f)
	for f in ["quelle", "autor"]:
		if e.get(f) is String and str(e[f]).strip_edges() == "":
			out.append("%s ist leer" % f)
	var liz = e.get("lizenz")
	if not liz is Dictionary:
		out.append("lizenz braucht {name, link}")
	else:
		for f in liz:
			if not f in LIZENZ_FELDER:
				out.append("lizenz: unbekanntes Feld „%s“" % f)
		if not (liz.get("name") is String and str(liz["name"]).strip_edges() != ""):
			out.append("lizenz.name fehlt")
		if not liz.get("link") is String:
			out.append("lizenz.link fehlt")
		elif str(liz["link"]) == "" and str(e.get("quelle", "")).contains("://"):
			out.append("lizenz.link leer, obwohl die Quelle extern ist")
	var tag = e.get("abgerufen", "")
	if tag is String and tag != "" and RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$").search(tag) == null:
		out.append("abgerufen „%s“ ist kein Datum JJJJ-MM-TT" % tag)
	if e.has("lokal") and not e["lokal"] is bool:
		out.append("lokal ist kein Wahrheitswert")
	elif e.get("lokal", false) == true:
		for m in muster:
			if m is String and not ist_ignoriert(m, regeln):
				out.append("lokal, aber „%s“ liegt in keinem gitignorierten Ordner" % m)
	return out


## Ein vollständiger Eintrag für die Gegenproben.
static func _eintrag(muster: Variant) -> Dictionary:
	return {"muster": muster, "quelle": "eigene Erzeugung", "autor": "Projektteam",
		"lizenz": {"name": "eigenes Werk", "link": ""}, "abgerufen": "", "erzeugt_von": "von Hand",
		"hinweis": ""}


# ------------------------------------------------------------------ Tests

func test_liste_ist_vollstaendig_und_wohlgeformt() -> void:
	var d := liste()
	pruefe(not d.is_empty(), "assets/HERKUNFT.json ist gültiges JSON mit Objekt als Wurzel")
	pruefe(d.get("zweck", "") is String and str(d.get("zweck", "")) != "", "zweck beschrieben")
	gleich(typeof(d.get("regeln")), TYPE_ARRAY, "regeln als Liste")
	var e := eintraege()
	pruefe(e.size() >= 10, "mindestens zehn Einträge (sind %d)" % e.size())
	var regeln := ignorier_regeln()
	for i in e.size():
		for f in eintrag_fehler(e[i], regeln):
			pruefe(false, "Eintrag %d %s: %s" % [i, str(muster_von(e[i])), f])


func test_jede_datei_hat_eine_herkunft() -> void:
	var dateien := bestand(ignorier_regeln())
	# Die Suche selbst ist nicht leer (sonst wäre der Test wertlos)
	pruefe(dateien.size() >= 25, "Bestand gefunden (%d Dateien)" % dateien.size())
	for p in ["assets/audio/jump.wav", "assets/audio/music_title.ogg", "assets/qr/reward.png",
			"assets/i18n/OFL.txt", "assets/HERKUNFT.json", "brand/README.md", "brand/.gdignore"]:
		pruefe(p in dateien, "%s im Bestand" % p)
	for p in ungedeckt(eintraege(), dateien):
		pruefe(false, "%s: kein Eintrag in assets/HERKUNFT.json" % p)


func test_jeder_eintrag_trifft_eine_datei() -> void:
	var dateien := bestand(ignorier_regeln())
	for m in unbenutzt(eintraege(), dateien):
		pruefe(false, "Eintrag %s trifft keine Datei (veraltet? sonst „lokal“: true)" % m)
	var lokal := eintraege().filter(func(e): return e is Dictionary and e.get("lokal", false) == true)
	pruefe(lokal.size() >= 3, "Brand-Paket (Schriften, Piktogramme, Lizenzen) als lokal geführt")


func test_gitignorierte_ordner_und_technikdateien_bleiben_draussen() -> void:
	var regeln := ignorier_regeln()
	for o in ["assets/fonts/", "assets/brand/", "brand/lizenz/"]:
		pruefe(o in regeln, "%s steht in godot/.gitignore" % o)
		pruefe(ist_ignoriert(o + "Datei.ttf", regeln), "%s… gilt als ignoriert" % o)
	pruefe(not ist_ignoriert("assets/audio/jump.wav", regeln), "assets/audio/ ist nicht ignoriert")
	pruefe(ist_ignoriert("assets/qr/Thumbs.db", regeln), "Dateiregeln (Thumbs.db) greifen in jeder Tiefe")
	for p in bestand(regeln):
		pruefe(not (p.ends_with(".import") or p.ends_with(".uid")), "%s: .import/.uid gehören nicht in den Bestand" % p)
		pruefe(not ist_ignoriert(p, regeln), "%s: gitignoriert, gehört nicht in den Bestand" % p)


func test_gegenprobe_neue_datei_ohne_eintrag() -> void:
	var dateien := bestand(ignorier_regeln())
	var neu := ["assets/sprites/paul.png", "brand/logo.svg", "assets/audio/music_neu.ogg"]
	gleich(ungedeckt(eintraege(), dateien + neu), neu, "neue Dateien ohne Eintrag werden gemeldet")


func test_gegenprobe_eintrag_ohne_datei() -> void:
	var dateien := bestand(ignorier_regeln())
	var regeln := ignorier_regeln()
	var tot := _eintrag("assets/sfx/*.wav")
	gleich(unbenutzt(eintraege() + [tot], dateien), ["[\"assets/sfx/*.wav\"]"], "Eintrag ohne Datei wird gemeldet")
	var lokal_ok := _eintrag("assets/fonts/Neu-*.ttf")
	lokal_ok["lokal"] = true
	gleich(unbenutzt([lokal_ok], dateien), [], "lokal: fehlende Datei ist erlaubt")
	gleich(eintrag_fehler(lokal_ok, regeln), [], "lokal im gitignorierten Ordner ist in Ordnung")
	var lokal_falsch := _eintrag("assets/sfx/*.wav")
	lokal_falsch["lokal"] = true
	gleich(unbenutzt([lokal_falsch], dateien), [], "lokal wird beim Treffer-Test übergangen …")
	pruefe(eintrag_fehler(lokal_falsch, regeln).any(func(f): return f.contains("gitignorierten")),
		"… darf aber nichts Eingechecktes verstecken")


func test_gegenprobe_unvollstaendige_eintraege() -> void:
	var regeln := ignorier_regeln()
	var faelle := {}
	var e := _eintrag("assets/x.png")
	e.erase("lizenz")
	faelle["Feld „lizenz“ fehlt"] = e
	e = _eintrag("assets/x.png")
	e["lizenz"] = "CC0"
	faelle["lizenz braucht"] = e
	e = _eintrag("assets/x.png")
	e["lizens"] = {"name": "CC0", "link": ""}
	faelle["unbekanntes Feld „lizens“"] = e
	e = _eintrag("assets/x.png")
	e["quelle"] = "https://example.org/x.png"
	faelle["lizenz.link leer"] = e
	e = _eintrag("assets/x.png")
	e["abgerufen"] = "4.9.2026"
	faelle["kein Datum"] = e
	e = _eintrag("res://assets/x.png")
	faelle["kein Pfad relativ"] = e
	e = _eintrag([])
	faelle["muster fehlt"] = e
	e = _eintrag("assets/x.png")
	e["autor"] = "  "
	faelle["autor ist leer"] = e
	e = _eintrag("assets/x.png")
	e["lokal"] = "ja"
	faelle["lokal ist kein Wahrheitswert"] = e
	for grund in faelle:
		var f := eintrag_fehler(faelle[grund], regeln)
		pruefe(f.any(func(t): return t.contains(grund)), "„%s“ wird gemeldet (gemeldet: %s)" % [grund, f])
	gleich(eintrag_fehler(_eintrag("assets/x.png"), regeln), [], "Kontrolle: vollständiger Eintrag ohne Fehler")


func test_musik_muster_halten_den_formatwechsel() -> void:
	var e := eintraege()
	for stueck in MUSIK:
		for endung in ["ogg", "mp3"]:
			var p := "assets/audio/music_%s.%s" % [stueck, endung]
			var wer := e.filter(func(x): return _trifft(x, p))
			pruefe(wer.size() == 1 and wer[0]["lizenz"]["name"] == "Pixabay Content License",
				"%s gehört genau zum Pixabay-Eintrag" % p)
	# Eine von gen_assets.py neu erzeugte WAV-Schleife ist synthetisch, nicht Pixabay
	var wav := e.filter(func(x): return _trifft(x, "assets/audio/music_title.wav"))
	pruefe(wav.size() == 1 and str(wav[0]["erzeugt_von"]).contains("gen_assets.py"),
		"music_title.wav fiele unter den Synthese-Eintrag")


func test_glob_bleibt_im_ordner() -> void:
	pruefe(passt("assets/*.json", "assets/HERKUNFT.json"), "* im selben Ordner")
	pruefe(not passt("assets/*.json", "assets/audio/x.json"), "* springt nicht über „/“")
	pruefe(passt("assets/**.json", "assets/audio/x.json"), "** geht über Ordner")
	pruefe(not passt("assets/audio/music_title.ogg", "assets/audio/music_title_ogg"), "„.“ ist ein Punkt")
	pruefe(passt("brand/lizenz/*", "brand/lizenz/HelveticaNeue_Trademark.pdf"), "Ordner-Muster")
	pruefe(not passt("assets/audio/*.wav", "assets/audio/jump.wav.import"), "Endung muss passen")
