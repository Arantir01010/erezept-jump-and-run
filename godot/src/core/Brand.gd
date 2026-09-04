class_name Brand
extends RefCounted
## BRAND — PwC-Erscheinungsbild für Schrift und Bedienelemente.
##
## Was markenkonform wird: die Schriften (Helvetica Neue für alles Lesbare,
## ITC Charter für die großen Überschriften) und die UI-Bausteine (Pillen,
## Karten, Aufforderungen, Bestenliste, Touch-Knöpfe) — in der PwC-Palette.
## Was bewusst NICHT angefasst wird: die Spielgrafik (Welten, Paul, REZI,
## Klinikum) und die fachlichen Farben der Hülle (warm = offen, kühl =
## verschlüsselt, violett = VAU, siehe Palette.gd) — Inhalt bleibt Inhalt.
##
## Die Schriftdateien liegen in res://assets/fonts/ (lizenziert, nicht im
## öffentlichen Repository, siehe brand/README.md). Fehlen sie, fällt alles
## sauber auf die Godot-Standardschrift zurück — das Spiel läuft trotzdem.

# ---- PwC-Farbpalette (Brand Guidelines, RGB) ----
const ORANGE := Color("#D04A02")
const TANGERINE := Color("#EB8C00")
const YELLOW := Color("#FFB600")
const RED := Color("#E0301E")
const ROSE := Color("#D93954")
const MAROON := Color("#822720")
const BLACK := Color("#000000")
const GREY_DARK := Color("#2D2D2D")
const GREY := Color("#464646")
const GREY_MID := Color("#7D7D7D")
const GREY_LIGHT := Color("#DEDEDE")
const GREY_PALE := Color("#F2F2F2")
const WHITE := Color("#FFFFFF")

# ---- Rollen im Spiel-UI ----
const UI_ACCENT := TANGERINE          # Aufforderungen, Hervorhebungen (auf dunklem Grund lesbarer als Orange)
const UI_ACCENT_STRONG := ORANGE      # Primärknopf, Fortschrittsbalken
const UI_HIGHLIGHT := YELLOW          # Medaillen, Bestwert, Erfolg
const UI_PANEL := Color(0.176, 0.176, 0.176, 0.86)     # GREY_DARK mit Alpha
const UI_PANEL_SOLID := Color(0.176, 0.176, 0.176, 0.97)
const UI_BORDER := Color(1.0, 1.0, 1.0, 0.16)
const UI_TEXT := WHITE
const UI_TEXT_DIM := Color("#DEDEDE")
const UI_TEXT_MUTED := Color("#7D7D7D")
const UI_RADIUS := 6

const FONT_DIR := "res://assets/fonts/"
const SANS := {
	"light": "HelveticaNeueLTPro-Lt.ttf", "roman": "HelveticaNeueLTPro-Roman.ttf", "italic": "HelveticaNeueLTPro-It.ttf",
	"medium": "HelveticaNeueLTPro-Md.ttf", "bold": "HelveticaNeueLTPro-Bd.ttf", "heavy": "HelveticaNeueLTPro-Hv.ttf",
}
const SERIF := {
	"regular": "ITCCharterCom-Regular.ttf", "italic": "ITCCharterCom-Italic.ttf",
	"bold": "ITCCharterCom-Bold.ttf", "bolditalic": "ITCCharterCom-BoldItalic.ttf",
}
const PICTOGRAM_DIR := "res://assets/brand/pictograms/"

static var _cache := {}
static var _missing_reported := false
const I18N_DIR := "res://assets/i18n/"
static var _i18n: Array = []
static var _i18n_loaded := false


## Schrift-Fallbacks für Chinesisch und Hindi: Noto-Sans-Untermengen (OFL) aus
## tools/gen_i18n_fonts.py. Fehlen sie, zeigen diese Sprachen Kästchen.
static func i18n_fallbacks() -> Array:
	if not _i18n_loaded:
		_i18n_loaded = true
		for name in ["NotoSansSC-subset.otf", "NotoSansDevanagari-subset.ttf"]:
			var p: String = I18N_DIR + str(name)
			if ResourceLoader.exists(p):
				var f = load(p)
				if f is Font:
					_i18n.append(f)
	return _i18n


static func _with_fallbacks(f: Font) -> void:
	var fb := i18n_fallbacks()
	if fb.is_empty():
		return
	var arr: Array[Font] = []
	for x in fb:
		arr.append(x)
	f.fallbacks = arr


## Sind die Markenschriften vorhanden?
static func available() -> bool:
	return ResourceLoader.exists(FONT_DIR + SANS["roman"])


static func _load(name: String, fallback_bold: bool) -> Font:
	if _cache.has(name):
		return _cache[name]
	var path := FONT_DIR + name
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path)
		if f != null:
			_with_fallbacks(f)
	if f == null:
		if not _missing_reported:
			_missing_reported = true
			push_warning("Brand: Markenschriften fehlen in %s — Standardschrift wird verwendet (siehe brand/README.md)." % FONT_DIR)
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		if fallback_bold:
			fv.variation_embolden = 0.6
		_with_fallbacks(fv)
		f = fv
	_cache[name] = f
	return f


## Helvetica Neue: "light", "roman", "italic", "medium", "bold", "heavy".
static func sans(weight := "roman") -> Font:
	var name: String = SANS.get(weight, SANS["roman"])
	return _load(name, weight in ["medium", "bold", "heavy"])


## ITC Charter: "regular", "italic", "bold", "bolditalic".
static func serif(weight := "regular") -> Font:
	var name: String = SERIF.get(weight, SERIF["regular"])
	return _load(name, weight in ["bold", "bolditalic"])


## Große Überschriften (Titel, Screen-Header, Stationsname).
static func headline() -> Font:
	return serif("bold")


## Schrift mit Buchstabenabstand (Versalien, Eyebrows, kleine Schilder).
static func spaced(base: Font, spacing_px: int) -> Font:
	var key := "%s#%d" % [base.get_instance_id(), spacing_px]
	if _cache.has(key):
		return _cache[key]
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = spacing_px
	_cache[key] = fv
	return fv


## Theme für den Fensterbaum: alle Controls erben Helvetica Neue.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = sans("roman")
	t.default_font_size = 22
	t.set_color("font_color", "Label", UI_TEXT)
	t.set_font("font", "Label", sans("roman"))
	t.set_font("bold_font", "RichTextLabel", sans("bold"))
	t.set_font("italics_font", "RichTextLabel", sans("italic"))
	t.set_font("normal_font", "RichTextLabel", sans("roman"))
	t.set_stylebox("panel", "PanelContainer", panel_style())
	return t


## Flächen-Stil im PwC-Look: dunkles Grau, feine Kante, kleine Rundung.
static func panel_style(radius := UI_RADIUS, bg := UI_PANEL, border := UI_BORDER, border_w := 1, margin_h := 18, margin_v := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


## Betonte Fläche (Auszeichnung): Kante in Akzentfarbe, weicher Schein.
static func accent_style(color := UI_HIGHLIGHT, radius := UI_RADIUS, margin_h := 22, margin_v := 8, shadow := true) -> StyleBoxFlat:
	var sb := panel_style(radius, UI_PANEL_SOLID, color, 2, margin_h, margin_v)
	if shadow:
		sb.shadow_color = Color(color.r, color.g, color.b, 0.3)
		sb.shadow_size = 14
	return sb


## LabelSettings mit Markenschrift: fertig für Label.label_settings.
static func label_settings(size: int, color := UI_TEXT, font: Font = null, outline := 0, outline_color := Color(0.0, 0.0, 0.0, 0.85)) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font if font else sans("roman")
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = outline_color
	return ls


## PwC-Werte-Piktogramm (weiß oder schwarz), z. B. "reimagine-the-possible".
static func pictogram(name: String, white := true) -> Texture2D:
	var path := "%s%s_%s.png" % [PICTOGRAM_DIR, name, "white" if white else "black"]
	if ResourceLoader.exists(path):
		return load(path)
	return null
