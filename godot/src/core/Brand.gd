class_name Brand
extends RefCounted
## BRAND — PwC-Erscheinungsbild: Farbsystem und Schriften an einer Stelle.
##
## Markenkonform sind die Schriften (Helvetica Neue für alles Lesbare, ITC
## Charter für die großen Überschriften), die UI-Bausteine (Pillen, Karten,
## Aufforderungen, Bestenliste, Touch-Knöpfe) und seit 11/2026 auch die
## Spielgrafik: Welten, Kulissen, Bausteine und Info-Screens nehmen ihre Farben
## aus dem PwC Digital Colour System (Palette.gd, Pen.hex-Werte der Screens).
## Geschrieben wird in normaler Groß-/Kleinschreibung — keine Versalien
## (Abkürzungen wie TI, VAU, eGK, SMC-B bleiben, was sie sind).
## Einzige Farbe außerhalb des Systems: das Violett der VAU (Palette.VAU,
## fachliche Kodierung aus KAPSEL 2.2, das Farbsystem kennt kein Violett).
##
## Die Schriftdateien liegen in res://assets/fonts/ (lizenziert, nicht im
## öffentlichen Repository, siehe brand/README.md). Fehlen sie, fällt alles
## sauber auf die Godot-Standardschrift zurück — das Spiel läuft trotzdem.

# ---- PwC Digital Colour System (brand.pwc.com › Colour system) ----
# Stufen wie im Farbsystem: 50 (hell) … 1000 (dunkel). Werte, die die Referenz-
# Präsentationen als Token führen, sind von dort übernommen; die übrigen Stufen
# sind aus der Farbsystem-Übersicht abgelesen (±1–2 je Kanal, vor einer
# Druck-/Styleguide-Abnahme gegen brand.pwc.com prüfen).
const ORANGE_50 := Color("#FFF5ED")
const ORANGE_100 := Color("#FFE8D4")
const ORANGE_200 := Color("#FFCDA8")
const ORANGE_300 := Color("#FFAA72")     # Brand Variant (Dark mode)
const ORANGE_400 := Color("#FE7C39")
const ORANGE_500 := Color("#FD5108")     # Brand
const ORANGE_600 := Color("#EE3D08")
const ORANGE_700 := Color("#C52A08")
const ORANGE_800 := Color("#9C220F")
const ORANGE_900 := Color("#691203")
const ORANGE_950 := Color("#440C06")
const ORANGE_1000 := Color("#1F0606")
const WHITE := Color("#FFFFFF")
const GREY_50 := Color("#F5F7F8")        # Text Primary (Dark mode)
const GREY_100 := Color("#EEEFF1")
const GREY_200 := Color("#DFE3E6")
const GREY_300 := Color("#CBD1D6")       # Text Secondary
const GREY_400 := Color("#B5BCC4")       # Border Strong
const GREY_500 := Color("#A1A8B3")
const GREY_600 := Color("#8E95A2")       # Foreground Disabled
const GREY_700 := Color("#787E8A")       # Border Subtle
const GREY_750 := Color("#626771")
const GREY_800 := Color("#4C5056")       # Background Disabled
const GREY_950 := Color("#303236")       # Background Layer 2
const GREY_975 := Color("#202124")       # Background Layer 1
const GREY_1000 := Color("#111113")      # Background Base
const BLACK := Color("#000000")
const BLUE_50 := Color("#EFF6FF")
const BLUE_100 := Color("#DCE7FD")
const BLUE_200 := Color("#A9C8FC")
const BLUE_300 := Color("#6797FF")       # Info (Dark mode)
const BLUE_400 := Color("#356FEC")
const BLUE_500 := Color("#2563EB")       # Info (Light mode)
const BLUE_600 := Color("#185DDF")
const BLUE_700 := Color("#1450D5")
const BLUE_800 := Color("#0F43B3")
const BLUE_900 := Color("#1E3B8B")
const BLUE_950 := Color("#0A245F")
const BLUE_1000 := Color("#04163A")
const SUCCESS_50 := Color("#ECFDF5")
const SUCCESS_100 := Color("#D4FDEB")
const SUCCESS_200 := Color("#8BF1CA")
const SUCCESS_300 := Color("#4FD3A1")
const SUCCESS_400 := Color("#18AE80")    # Success
const SUCCESS_500 := Color("#07966A")
const SUCCESS_600 := Color("#067C59")
const SUCCESS_700 := Color("#086B4F")
const SUCCESS_800 := Color("#064D3B")
const SUCCESS_900 := Color("#022C1E")
const SUCCESS_950 := Color("#012116")
const SUCCESS_1000 := Color("#001C10")
const WARNING_50 := Color("#FCFAEB")
const WARNING_100 := Color("#FDF1BF")
const WARNING_200 := Color("#F6D169")
const WARNING_300 := Color("#E9B01F")    # Warning
const WARNING_400 := Color("#D5981B")
const WARNING_500 := Color("#B37814")
const WARNING_600 := Color("#9F6010")
const WARNING_700 := Color("#7C460A")
const WARNING_800 := Color("#6A3718")
const WARNING_900 := Color("#482102")
const WARNING_950 := Color("#2A1A01")
const WARNING_1000 := Color("#0D0900")
const RED_50 := Color("#FEF2F2")
const RED_100 := Color("#FEE0E0")
const RED_200 := Color("#F6A2A2")
const RED_300 := Color("#F56F70")
const RED_400 := Color("#ED4242")        # Error
const RED_500 := Color("#D62223")
const RED_600 := Color("#D1211F")
const RED_700 := Color("#BA221D")
const RED_800 := Color("#9F2224")
const RED_900 := Color("#7F1D1C")
const RED_950 := Color("#5A0F0E")
const RED_1000 := Color("#35090A")
const TANGERINE_50 := Color("#FFFCE9")
const TANGERINE_100 := Color("#FFF4C6")
const TANGERINE_200 := Color("#FFE986")
const TANGERINE_300 := Color("#FFD646")
const TANGERINE_400 := Color("#FFC21B")
const TANGERINE_500 := Color("#FF9F00")  # Sekundärfarbe (Illustration, Piktogramme)
const TANGERINE_600 := Color("#E17701")
const TANGERINE_700 := Color("#BC5F02")
const TANGERINE_800 := Color("#854505")
const TANGERINE_900 := Color("#623E00")
const TANGERINE_950 := Color("#3E2600")
const TANGERINE_1000 := Color("#251601")

# Kurznamen für die Kernfarben
const ORANGE := ORANGE_500
const TANGERINE := TANGERINE_500
const BLUE := BLUE_300
const SUCCESS := SUCCESS_400
const WARNING := WARNING_300
const RED := RED_400

# ---- Rollen im Spiel-UI: Dark mode des Farbsystems (Namen wie brand/DESIGN-PROMPT.md) ----
#   Brand            ORANGE_500   Primäraktion, Fortschritt, gefüllte Flächen (Text darauf: Weiß)
#   Brand Variant    ORANGE_300   kleine orange Schrift und Linien auf dunklem Grund, Aufforderung, Eyebrow
#   Sekundär         TANGERINE    Auszeichnung, Medaille, Bestwert
#   Status           BLUE_300 Info · SUCCESS_400 · WARNING_300 · RED_400 (Text darauf: Grey 1000)
#   Flächen          Grey 1000 (Base) / 975 (Layer 1) / 950 (Layer 2), Kante Grey 700
#   Text             Grey 50 (Primary) / Grey 300 (Secondary) / Grey 600 (Disabled)
const UI_ACCENT := ORANGE_300         # Aufforderungen, Hervorhebungen (Brand Variant)
const UI_ACCENT_STRONG := ORANGE_500  # Primärknopf, Fortschrittsbalken (Brand)
const UI_ON_BRAND := WHITE            # Text auf ORANGE_500
const UI_HIGHLIGHT := TANGERINE_400   # Medaillen, Bestwert, Auszeichnung
const UI_EYEBROW := ORANGE_300        # Eyebrow-Zeilen über Überschriften
const UI_DANGER := RED_400            # Fehler, verweigert
const UI_SUCCESS := SUCCESS_400
const UI_INFO := BLUE_300
const UI_WARNING := WARNING_300
const UI_ON_STATUS := GREY_1000       # Text auf Statusflächen
const UI_PANEL := Color(0.1255, 0.1294, 0.1412, 0.88)        # Grey 975 (Layer 1), leicht durchscheinend
const UI_PANEL_SOLID := Color(0.1255, 0.1294, 0.1412, 0.97)
const UI_PANEL_2 := GREY_950          # Layer 2: Fläche in der Fläche
const UI_BORDER := Color(0.4706, 0.4941, 0.5412, 0.55)       # Grey 700 (Border Subtle)
const UI_BORDER_STRONG := GREY_400
const UI_TEXT := GREY_50
const UI_TEXT_DIM := GREY_300
const UI_TEXT_MUTED := GREY_600
const UI_RADIUS := 2                  # das Farbsystem zeichnet eckig; 2 px nehmen nur die Härte

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


## Schrift mit Buchstabenabstand (Eyebrows, kleine Schilder). Seit der Text
## in normaler Groß-/Kleinschreibung steht, wird nur noch leicht gesperrt:
## Versalien vertragen weite Sperrung, gemischte Schreibung nicht. Aufrufer
## geben weiter den alten Versalien-Wert an; hier wird er gedämpft (höchstens 2 px).
const SPERRUNG := 0.35

static func spaced(base: Font, spacing_px: int) -> Font:
	spacing_px = clampi(roundi(float(spacing_px) * SPERRUNG), 0, 2)
	if spacing_px == 0:
		return base
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
