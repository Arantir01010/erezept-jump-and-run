extends "res://tests/testfall.gd"
## PwC-Marke: Farben und Schreibweise bleiben konform, auch wenn später jemand
## einen Screen oder Text ergänzt.
##   • Jede feste Farbe im Quelltext ist eine Stufe des PwC Digital Colour System
##     (Brand.gd) oder das VAU-Violett (Palette.gd, fachliche Kodierung).
##     Ausnahme je Zeile: Kommentar „# farbe-frei" (z. B. Landesflaggen).
##   • Kein Text in durchgehenden Großbuchstaben. Abkürzungen bleiben (TI, VAU,
##     PIN, SMC-B …), ebenso gemischte Schreibungen wie ePA, eGK.

## Abkürzungen und Tastennamen, die groß geschrieben richtig sind.
const ABKUERZUNGEN := ["TI", "VAU", "SMC", "PIN", "HBA", "KOV", "VPN", "QES", "VSDM", "KIM", "TIM", "QR", "LED",
	"EKG", "OK", "PC", "IK", "OP", "WASD", "ID", "KI", "TV", "RZ", "EG", "GP", "JJJJ", "MM", "TT", "JSON"]
const SPRACHFELDER := ["de", "en", "fr", "es", "zh", "hi", "textDe", "textEn"]
const TOLERANZ := 0.004     # Rundung der Gleitkomma-Schreibweise Color(r, g, b)

var _versalien := RegEx.create_from_string("(?<![\\p{L}])\\p{Lu}{2,}(?![\\p{Ll}])")


func _palette() -> Array[Color]:
	var farben: Array[Color] = []
	var konst: Dictionary = (load("res://src/core/Brand.gd") as Script).get_script_constant_map()
	for name: Variant in konst:
		if konst[name] is Color and not str(name).begins_with("UI_"):
			farben.append(konst[name])
	for c: Color in [Palette.VAU, Palette.VAU_HELL, Palette.VAU_TIEF, Palette.VAU_NACHT]:
		farben.append(c)
	return farben


func _in_palette(c: Color, palette: Array[Color]) -> bool:
	for p in palette:
		if absf(p.r - c.r) <= TOLERANZ and absf(p.g - c.g) <= TOLERANZ and absf(p.b - c.b) <= TOLERANZ:
			return true
	return false


func _skripte(ordner: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(ordner):
		if f.ends_with(".gd"):
			out.append(ordner.path_join(f))
	for d in DirAccess.get_directories_at(ordner):
		_skripte(ordner.path_join(d), out)


func test_palette_ist_vollstaendig() -> void:
	gleich(Brand.ORANGE, Color("#FD5108"), "Markenfarbe ist Orange 500")
	gleich(Brand.UI_ACCENT, Color("#FFAA72"), "Akzent auf dunklem Grund ist Orange 300 (Brand Variant)")
	gleich(Brand.UI_TEXT, Color("#F5F7F8"), "Text Primary ist Grey 50")
	pruefe(_palette().size() >= 85, "Farbsystem hat sieben Familien mit je 12–13 Stufen: %d Farben" % _palette().size())


func test_jede_feste_farbe_stammt_aus_dem_farbsystem() -> void:
	var palette := _palette()
	var hexa := RegEx.create_from_string("(?:0x|\"#)([0-9a-fA-F]{6})\\b")
	var gleit := RegEx.create_from_string("Color\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*[,)]")
	var skripte: Array[String] = []
	_skripte("res://src", skripte)
	var fremd: Array[String] = []
	for pfad in skripte:
		if pfad.ends_with("core/Brand.gd"):
			continue
		var nr := 0
		for zeile in FileAccess.get_file_as_string(pfad).split("\n"):
			nr += 1
			if zeile.contains("farbe-frei") or zeile.strip_edges().begins_with("#"):
				continue
			var code := zeile.get_slice("##", 0)
			for m in hexa.search_all(code):
				if not _in_palette(Color.html(m.get_string(1)), palette):
					fremd.append("%s:%d #%s" % [pfad.trim_prefix("res://"), nr, m.get_string(1)])
			for m in gleit.search_all(code):
				var c := Color(m.get_string(1).to_float(), m.get_string(2).to_float(), m.get_string(3).to_float())
				if maxf(c.r, maxf(c.g, c.b)) > 1.0:
					continue    # Faktor, keine Farbe (Farbstimmung, HDR-Leuchten)
				if not _in_palette(c, palette):
					fremd.append("%s:%d Color(%s, %s, %s)" % [pfad.trim_prefix("res://"), nr, m.get_string(1), m.get_string(2), m.get_string(3)])
	pruefe(fremd.is_empty(), "%d Farben außerhalb des PwC-Farbsystems: %s" % [fremd.size(), ", ".join(fremd.slice(0, 8))])


func _versalien_in(text: String) -> Array[String]:
	var out: Array[String] = []
	for m in _versalien.search_all(text):
		if not ABKUERZUNGEN.has(m.get_string()):
			out.append(m.get_string())
	return out


func _texte_aus(wert: Variant, feld: String, out: Array[String]) -> void:
	if wert is String:
		if SPRACHFELDER.has(feld):
			out.append(wert)
	elif wert is Array:
		for x: Variant in wert:
			_texte_aus(x, feld, out)
	elif wert is Dictionary:
		for k: Variant in wert:
			_texte_aus(wert[k], str(k), out)


func test_kein_text_in_versalien() -> void:
	var texte: Array[String] = []
	for f in DirAccess.get_files_at("res://i18n"):
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/" + f))
		if d is Dictionary:
			var woerter: Dictionary = d
			for key: Variant in woerter:
				if str(key).begins_with("_"):
					continue
				texte.append(str(key))
				_texte_aus(d[key], "", texte)
	for id in DirAccess.get_directories_at("res://levels"):
		if id.begins_with("_"):
			continue
		_texte_aus(JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s/level.json" % id)), "", texte)
	for f: String in ["game-config.json", "wissensfragen.json", "themes.json"]:
		_texte_aus(JSON.parse_string(FileAccess.get_file_as_string("res://config/" + f)), "", texte)
	pruefe(texte.size() > 500, "Texte gefunden: %d" % texte.size())
	var funde: Array[String] = []
	for t in texte:
		var v := _versalien_in(t)
		if not v.is_empty():
			funde.append("%s (in „%s“)" % [", ".join(v), t.left(40)])
	pruefe(funde.is_empty(), "%d Texte mit Versalien: %s" % [funde.size(), "; ".join(funde.slice(0, 6))])


## Texte, die nicht übersetzt werden (Schilder, Namen), stehen direkt im Quelltext
## der Screens und Bausteine.
func test_keine_versalien_in_screens_und_bausteinen() -> void:
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var skripte: Array[String] = []
	_skripte("res://src/ui", skripte)
	_skripte("res://src/mechanics", skripte)
	_skripte("res://src/actors", skripte)
	var funde: Array[String] = []
	for pfad in skripte:
		var nr := 0
		for zeile in FileAccess.get_file_as_string(pfad).split("\n"):
			nr += 1
			var code := zeile.get_slice("##", 0)
			if code.strip_edges().begins_with("#") or code.contains("push_warning") or code.contains("push_error"):
				continue
			for m in literal.search_all(code):
				var s := m.get_string(1)
				if s.contains("res://") or s.contains("_") or s.begins_with("#"):
					continue    # Pfade, Bezeichner, Farbwerte
				var v := _versalien_in(s)
				if not v.is_empty():
					funde.append("%s:%d %s" % [pfad.trim_prefix("res://"), nr, ", ".join(v)])
	pruefe(funde.is_empty(), "%d Stellen mit Versalien: %s" % [funde.size(), "; ".join(funde.slice(0, 8))])


func test_sperrung_ist_gedaempft() -> void:
	var basis := Brand.sans("medium")
	var weit := Brand.spaced(basis, 12)
	pruefe(weit is FontVariation and (weit as FontVariation).spacing_glyph <= 2, "Sperrung höchstens 2 px (gemischte Schreibung)")
	pruefe(Brand.spaced(basis, 1) == basis, "kleine Sperrung entfällt")
