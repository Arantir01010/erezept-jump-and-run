extends "res://tests/testfall.gd"
## HERKUNFT (assets/HERKUNFT.json): Jede Nicht-Code-Datei unter assets/ und brand/ hat
## einen Eintrag mit Quelle, Urheber, Lizenz und Werkzeug; jeder Eintrag (außer „lokal“
## = gitignoriertes Brand-Paket) trifft mindestens eine Datei. Einträge mit „ki“: true
## brauchen für jede Datei eine Zeile im Erzeugungsprotokoll (docs/erzeugungsprotokoll.jsonl,
## tools/erzeugung_protokoll.py) mit gleicher SHA-256; das Protokoll enthält keine
## Geheimnisse. GEGENPROBE: neue Datei ohne Eintrag, Eintrag ohne Datei, unvollständige
## Einträge, „lokal“ außerhalb der gitignorierten Ordner, KI-Datei ohne oder mit
## veraltetem Protokoll, Geheimnisse — alles wird gemeldet; die Musik-Muster halten den
## Wechsel MP3 ⇄ OGG aus.

const LISTE := "res://assets/HERKUNFT.json"
const PROTOKOLL := "res://docs/erzeugungsprotokoll.jsonl"
const PROTOKOLL_WERKZEUG := "res://tools/erzeugung_protokoll.py"
const WURZELN: Array[String] = ["assets", "brand"]
const FELDER: Array[String] = ["muster", "quelle", "autor", "lizenz", "abgerufen", "erzeugt_von", "hinweis"]
const OPTIONAL: Array[String] = ["lokal", "ki"]
const LIZENZ_FELDER: Array[String] = ["name", "link", "kurzfassung"]
const MUSIK: Array[String] = ["title", "level", "level2", "reward"]


# ------------------------------------------------------------------ Liste und Bestand

static func liste() -> Dictionary:
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(LISTE)) != OK or not j.data is Dictionary:
		return {}
	var d: Dictionary = j.data
	return d


static func eintraege() -> Array:
	var e: Variant = liste().get("eintraege", [])
	if e is Array:
		var a: Array = e
		return a
	return []


## Regeln aus godot/.gitignore (ohne Kommentare). „x/“ = Ordner; mit „/“ davor oder in
## der Mitte an godot/ gebunden, sonst in jeder Tiefe (wie git).
static func ignorier_regeln() -> Array[String]:
	var out: Array[String] = []
	for zeile: String in FileAccess.get_file_as_string("res://.gitignore").split("\n"):
		var z := zeile.strip_edges()
		if z != "" and not z.begins_with("#"):
			out.append(z)
	return out


## Pfad relativ zu godot/ (Ordner mit „/“ am Ende, auch ein Glob-Muster) liegt in einem
## gitignorierten Bereich.
static func ist_ignoriert(pfad: String, regeln: Array[String]) -> bool:
	for regel: String in regeln:
		var r := regel.trim_prefix("/")
		if r.ends_with("/"):
			if r.trim_suffix("/").contains("/") or regel.begins_with("/"):
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
	for w: String in WURZELN:
		_sammeln(w, regeln, out)
	out.sort()
	return out


static func _sammeln(rel: String, regeln: Array[String], out: Array[String]) -> void:
	var d := DirAccess.open("res://" + rel)
	if d == null:
		return
	d.include_hidden = true
	for f: String in d.get_files():
		var p := rel.path_join(f)
		if not (f.ends_with(".import") or f.ends_with(".uid") or ist_ignoriert(p, regeln)):
			out.append(p)
	for sub: String in d.get_directories():
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


static func muster_von(e: Variant) -> Array[String]:
	var out: Array[String] = []
	if not e is Dictionary:
		return out
	var d: Dictionary = e
	var m: Variant = d.get("muster", [])
	if m is String:
		out.append(str(m))
	elif m is Array:
		var liste_m: Array = m
		for x: Variant in liste_m:
			if x is String:
				out.append(str(x))
	return out


static func _trifft(e: Variant, pfad: String) -> bool:
	for m: String in muster_von(e):
		if passt(m, pfad):
			return true
	return false


static func _ist(e: Variant, feld: String) -> bool:
	if not e is Dictionary:
		return false
	var d: Dictionary = e
	var v: Variant = d.get(feld, false)
	return v is bool and v == true


## Dateien, zu denen kein Eintrag passt.
static func ungedeckt(liste_: Array, pfade: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for p: String in pfade:
		if not liste_.any(func(e: Variant) -> bool: return _trifft(e, p)):
			out.append(p)
	return out


## Einträge ohne „lokal“, die keine einzige Datei treffen.
static func unbenutzt(liste_: Array, pfade: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for e: Variant in liste_:
		if _ist(e, "lokal"):
			continue
		if not pfade.any(func(p: String) -> bool: return _trifft(e, p)):
			out.append(str(muster_von(e)))
	return out


## Formfehler eines Eintrags (leer = in Ordnung).
static func eintrag_fehler(e: Variant, regeln: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if not e is Dictionary:
		out.append("kein Objekt")
		return out
	var d: Dictionary = e
	for f: String in FELDER:
		if not d.has(f):
			out.append("Feld „%s“ fehlt" % f)
	for f: Variant in d:
		if not (str(f) in FELDER or str(f) in OPTIONAL):
			out.append("unbekanntes Feld „%s“" % str(f))
	var muster := muster_von(d)
	if muster.is_empty():
		out.append("muster fehlt")
	for m: String in muster:
		if m == "" or m.begins_with("/") or m.contains("://") or m.contains(".."):
			out.append("muster „%s“ ist kein Pfad relativ zu godot/" % m)
	for f: String in FELDER:
		if f != "muster" and f != "lizenz" and d.has(f) and not d[f] is String:
			out.append("%s ist kein Text" % f)
	for f: String in ["quelle", "autor"]:
		if d.get(f) is String and str(d[f]).strip_edges() == "":
			out.append("%s ist leer" % f)
	var liz: Variant = d.get("lizenz")
	if not liz is Dictionary:
		out.append("lizenz braucht {name, link}")
	else:
		var lz: Dictionary = liz
		for f: Variant in lz:
			if not str(f) in LIZENZ_FELDER:
				out.append("lizenz: unbekanntes Feld „%s“" % str(f))
		if not (lz.get("name") is String and str(lz["name"]).strip_edges() != ""):
			out.append("lizenz.name fehlt")
		if not lz.get("link") is String:
			out.append("lizenz.link fehlt")
		elif str(lz["link"]) == "" and str(d.get("quelle", "")).contains("://"):
			out.append("lizenz.link leer, obwohl die Quelle extern ist")
	var tag := str(d.get("abgerufen", ""))
	if tag != "" and RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$").search(tag) == null:
		out.append("abgerufen „%s“ ist kein Datum JJJJ-MM-TT" % tag)
	for f: String in OPTIONAL:
		if d.has(f) and not d[f] is bool:
			out.append("%s ist kein Wahrheitswert" % f)
	if _ist(d, "lokal"):
		for m: String in muster:
			if not ist_ignoriert(m, regeln):
				out.append("lokal, aber „%s“ liegt in keinem gitignorierten Ordner" % m)
	if _ist(d, "ki") and str(d.get("erzeugt_von", "")).strip_edges() == "":
		out.append("ki: erzeugt_von muss Dienst und Modell nennen")
	return out


# ------------------------------------------------------------------ Erzeugungsprotokoll

## Inhalt einer Datei; fehlt sie (noch kein Protokoll), ein leerer Text.
static func lesen(pfad: String) -> String:
	return FileAccess.get_file_as_string(pfad) if FileAccess.file_exists(pfad) else ""


## Zeilen des Protokolls (JSONL). Kaputte Zeilen landen in `kaputt` („Zeile n: …“).
static func protokoll_zeilen(text: String, kaputt: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := 0
	for zeile: String in text.split("\n"):
		n += 1
		if zeile.strip_edges() == "":
			continue
		var j := JSON.new()
		if j.parse(zeile) != OK or not j.data is Dictionary:
			kaputt.append("Zeile %d: kein JSON-Objekt" % n)
			continue
		var d: Dictionary = j.data
		out.append(d)
	return out


## SHA-256 aller Ausgaben im Protokoll.
static func protokoll_hashes(zeilen: Array[Dictionary]) -> Dictionary:
	var out := {}
	for z: Dictionary in zeilen:
		var a: Variant = z.get("ausgabe")
		if a is Dictionary:
			var ad: Dictionary = a
			out[str(ad.get("sha256", ""))] = true
	return out


## KI-Dateien (Eintrag mit „ki“: true), deren SHA-256 in keiner Protokollzeile steht.
static func ohne_protokoll(liste_: Array, pfade: Array[String], hash_von: Dictionary,
		zeilen: Array[Dictionary]) -> Array[String]:
	var bekannt := protokoll_hashes(zeilen)
	var out: Array[String] = []
	for p: String in pfade:
		var ki := liste_.any(func(e: Variant) -> bool: return _ist(e, "ki") and _trifft(e, p))
		if ki and not bekannt.has(str(hash_von.get(p, ""))):
			out.append(p)
	return out


static func hashes(pfade: Array[String]) -> Dictionary:
	var out := {}
	for p: String in pfade:
		out[p] = FileAccess.get_sha256("res://" + p)
	return out


## Die Geheimnis-Muster aus tools/erzeugung_protokoll.py (Liste GEHEIM, ein r"…" je Zeile) —
## eine Quelle für Werkzeug und Test.
static func geheim_muster() -> Array[RegEx]:
	var out: Array[RegEx] = []
	var text := lesen(PROTOKOLL_WERKZEUG)
	var a := text.find("\nGEHEIM = [")
	if a < 0:
		return out
	var block := text.substr(a, text.find("\n]", a) - a)
	for m: RegExMatch in RegEx.create_from_string("(?m)^\\s*r\"([^\"]*)\",").search_all(block):
		var r := RegEx.create_from_string(m.get_string(1))
		if r != null and r.is_valid():
			out.append(r)
	return out


static func geheimnisse(text: String, muster: Array[RegEx]) -> Array[String]:
	var out: Array[String] = []
	for r: RegEx in muster:
		var m := r.search(text)
		if m != null:
			out.append(m.get_string())
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
	pruefe(str(d.get("zweck", "")) != "", "zweck beschrieben")
	gleich(typeof(d.get("regeln")), TYPE_ARRAY, "regeln als Liste")
	var e := eintraege()
	pruefe(e.size() >= 10, "mindestens zehn Einträge (sind %d)" % e.size())
	var regeln := ignorier_regeln()
	for i: int in e.size():
		for f: String in eintrag_fehler(e[i], regeln):
			pruefe(false, "Eintrag %d %s: %s" % [i, str(muster_von(e[i])), f])


func test_jede_datei_hat_eine_herkunft() -> void:
	var pfade := bestand(ignorier_regeln())
	# Die Suche selbst ist nicht leer (sonst wäre der Test wertlos)
	pruefe(pfade.size() >= 25, "Bestand gefunden (%d Dateien)" % pfade.size())
	for p: String in ["assets/audio/jump.wav", "assets/audio/music_title.ogg", "assets/qr/reward.png",
			"assets/i18n/OFL.txt", "assets/HERKUNFT.json", "brand/README.md", "brand/.gdignore"]:
		pruefe(p in pfade, "%s im Bestand" % p)
	for p: String in ungedeckt(eintraege(), pfade):
		pruefe(false, "%s: kein Eintrag in assets/HERKUNFT.json" % p)


func test_jeder_eintrag_trifft_eine_datei() -> void:
	var pfade := bestand(ignorier_regeln())
	for m: String in unbenutzt(eintraege(), pfade):
		pruefe(false, "Eintrag %s trifft keine Datei (veraltet? sonst „lokal“: true)" % m)
	var lokal := eintraege().filter(func(e: Variant) -> bool: return _ist(e, "lokal"))
	pruefe(lokal.size() >= 3, "Brand-Paket (Schriften, Piktogramme, Lizenzen) als lokal geführt")


func test_gitignorierte_ordner_und_technikdateien_bleiben_draussen() -> void:
	var regeln := ignorier_regeln()
	for o: String in ["assets/fonts/", "assets/brand/", "brand/lizenz/"]:
		pruefe(o in regeln, "%s steht in godot/.gitignore" % o)
		pruefe(ist_ignoriert(o + "Datei.ttf", regeln), "%s… gilt als ignoriert" % o)
	pruefe(not ist_ignoriert("assets/audio/jump.wav", regeln), "assets/audio/ ist nicht ignoriert")
	pruefe(ist_ignoriert("assets/qr/Thumbs.db", regeln), "Dateiregeln (Thumbs.db) greifen in jeder Tiefe")
	for p: String in bestand(regeln):
		pruefe(not (p.ends_with(".import") or p.ends_with(".uid")), "%s: .import/.uid gehören nicht in den Bestand" % p)
		pruefe(not ist_ignoriert(p, regeln), "%s: gitignoriert, gehört nicht in den Bestand" % p)


func test_ki_dateien_stehen_im_protokoll() -> void:
	var kaputt: Array[String] = []
	var text := lesen(PROTOKOLL)
	var zeilen := protokoll_zeilen(text, kaputt)
	for k: String in kaputt:
		pruefe(false, "docs/erzeugungsprotokoll.jsonl %s" % k)
	var pfade := bestand(ignorier_regeln())
	for p: String in ohne_protokoll(eintraege(), pfade, hashes(pfade), zeilen):
		pruefe(false, "%s: KI-Datei ohne Protokollzeile mit gleicher SHA-256 (tools/erzeugung_protokoll.py --neu)" % p)
	var muster := geheim_muster()
	pruefe(muster.size() >= 10, "Geheimnis-Muster aus tools/erzeugung_protokoll.py gelesen (%d)" % muster.size())
	for g: String in geheimnisse(text, muster):
		pruefe(false, "docs/erzeugungsprotokoll.jsonl enthält etwas wie ein Geheimnis: „%s…“" % g.left(12))


func test_gegenprobe_neue_datei_ohne_eintrag() -> void:
	var neu: Array[String] = ["assets/sprites/paul.png", "brand/logo.svg", "assets/audio/music_neu.ogg"]
	var alle := bestand(ignorier_regeln())
	alle.append_array(neu)
	gleich(ungedeckt(eintraege(), alle), neu, "neue Dateien ohne Eintrag werden gemeldet")


func test_gegenprobe_eintrag_ohne_datei() -> void:
	var regeln := ignorier_regeln()
	var pfade := bestand(regeln)
	var tot := _eintrag("assets/sfx/*.wav")
	var soll: Array[String] = ["[\"assets/sfx/*.wav\"]"]
	gleich(unbenutzt(eintraege() + [tot], pfade), soll, "Eintrag ohne Datei wird gemeldet")
	var lokal_ok := _eintrag("assets/fonts/Neu-*.ttf")
	lokal_ok["lokal"] = true
	gleich(unbenutzt([lokal_ok], pfade).size(), 0, "lokal: fehlende Datei ist erlaubt")
	gleich(eintrag_fehler(lokal_ok, regeln).size(), 0, "lokal im gitignorierten Ordner ist in Ordnung")
	var lokal_falsch := _eintrag("assets/sfx/*.wav")
	lokal_falsch["lokal"] = true
	gleich(unbenutzt([lokal_falsch], pfade).size(), 0, "lokal wird beim Treffer-Test übergangen …")
	var f := eintrag_fehler(lokal_falsch, regeln)
	pruefe(f.any(func(t: String) -> bool: return t.contains("gitignorierten")),
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
	e = _eintrag("assets/x.png")
	e["ki"] = true
	e["erzeugt_von"] = ""
	faelle["ki: erzeugt_von"] = e
	for grund: String in faelle:
		var f := eintrag_fehler(faelle[grund], regeln)
		pruefe(f.any(func(t: String) -> bool: return t.contains(grund)), "„%s“ wird gemeldet (gemeldet: %s)" % [grund, f])
	gleich(eintrag_fehler(_eintrag("assets/x.png"), regeln).size(), 0, "Kontrolle: vollständiger Eintrag ohne Fehler")


func test_gegenprobe_ki_datei_ohne_passendes_protokoll() -> void:
	var ki := _eintrag("assets/ki/*.png")
	ki["ki"] = true
	ki["erzeugt_von"] = "Higgsfield, Modell beispiel-bild-2 (docs/erzeugungsprotokoll.jsonl)"
	gleich(eintrag_fehler(ki, ignorier_regeln()).size(), 0, "KI-Eintrag ist wohlgeformt")
	var liste_ := eintraege() + [ki]
	var pfade: Array[String] = ["assets/ki/held.png", "assets/audio/jump.wav"]
	var hash_von := {"assets/ki/held.png": "a".repeat(64), "assets/audio/jump.wav": "c".repeat(64)}
	var zeile := {"nr": 1, "ausgabe": {"datei": "assets/ki/held.png", "sha256": "a".repeat(64), "bytes": 1}}
	var leer: Array[Dictionary] = []
	var nur_held: Array[String] = ["assets/ki/held.png"]
	gleich(ohne_protokoll(liste_, pfade, hash_von, leer), nur_held,
		"KI-Datei ohne Protokollzeile wird gemeldet (die synthetische WAV nicht)")
	var passend: Array[Dictionary] = [zeile]
	gleich(ohne_protokoll(liste_, pfade, hash_von, passend).size(), 0, "Protokollzeile mit gleicher SHA-256 genügt")
	hash_von["assets/ki/held.png"] = "b".repeat(64)
	gleich(ohne_protokoll(liste_, pfade, hash_von, passend), nur_held,
		"nachträglich geänderte Datei (andere SHA-256) wird gemeldet")
	var kaputt: Array[String] = []
	var zeilen := protokoll_zeilen("{\"nr\": 1}\n\nkein json\n[1, 2]\n", kaputt)
	gleich(zeilen.size(), 1, "gültige Zeile gelesen, Leerzeile übergangen")
	var soll: Array[String] = ["Zeile 3: kein JSON-Objekt", "Zeile 4: kein JSON-Objekt"]
	gleich(kaputt, soll, "kaputte Zeilen gemeldet")


func test_gegenprobe_geheimnisse_im_protokoll() -> void:
	var muster := geheim_muster()
	for text: String in ["https://b.s3.amazonaws.com/x.png?X-Amz-Signature=abc",
			"https://x.blob.core.windows.net/a?sv=1&sig=abcdef", "Authorization: Bearer abcdefghijklmnop",
			"sk-abcdefghijklmnopqrstu", "AKIAABCDEFGHIJKLMNOP", "Rückfragen an max.muster@example.org",
			"-----BEGIN RSA PRIVATE KEY-----", "user_ABCDEFGHIJKLMNOP"]:
		pruefe(not geheimnisse(text, muster).is_empty(), "Geheimnis erkannt: %s" % text.left(24))
	var sauber := "{\"prompt\": \"Paul im Lauf, flache Vektorgrafik\", \"ausgabe\": {\"datei\": \"assets/ki/held.png\"}}"
	gleich(geheimnisse(sauber, muster).size(), 0, "Kontrolle: saubere Zeile ohne Fund")


func test_musik_muster_halten_den_formatwechsel() -> void:
	var e := eintraege()
	for stueck: String in MUSIK:
		for endung: String in ["ogg", "mp3"]:
			var p := "assets/audio/music_%s.%s" % [stueck, endung]
			var wer := e.filter(func(x: Variant) -> bool: return _trifft(x, p))
			var lizenz := ""
			if wer.size() == 1 and wer[0] is Dictionary:
				var w: Dictionary = wer[0]
				var lz: Variant = w.get("lizenz")
				if lz is Dictionary:
					var lzd: Dictionary = lz
					lizenz = str(lzd.get("name", ""))
			pruefe(wer.size() == 1 and lizenz == "Pixabay Content License", "%s gehört genau zum Pixabay-Eintrag" % p)
	# Eine von gen_assets.py neu erzeugte WAV-Schleife ist synthetisch, nicht Pixabay
	var wav := e.filter(func(x: Variant) -> bool: return _trifft(x, "assets/audio/music_title.wav"))
	var werkzeug := ""
	if wav.size() == 1 and wav[0] is Dictionary:
		var w: Dictionary = wav[0]
		werkzeug = str(w.get("erzeugt_von", ""))
	pruefe(wav.size() == 1 and werkzeug.contains("gen_assets.py"), "music_title.wav fiele unter den Synthese-Eintrag")


func test_glob_bleibt_im_ordner() -> void:
	pruefe(passt("assets/*.json", "assets/HERKUNFT.json"), "* im selben Ordner")
	pruefe(not passt("assets/*.json", "assets/audio/x.json"), "* springt nicht über „/“")
	pruefe(passt("assets/**.json", "assets/audio/x.json"), "** geht über Ordner")
	pruefe(not passt("assets/audio/music_title.ogg", "assets/audio/music_title_ogg"), "„.“ ist ein Punkt")
	pruefe(passt("brand/lizenz/*", "brand/lizenz/HelveticaNeue_Trademark.pdf"), "Ordner-Muster")
	pruefe(not passt("assets/audio/*.wav", "assets/audio/jump.wav.import"), "Endung muss passen")
