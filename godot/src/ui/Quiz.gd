class_name Quiz
extends Control
## QUIZ — kurze Wissensabfrage vor dem Abschluss (Messe-Paket 3, Punkt 16).
## Zwei bis drei Fragen mit je zwei Antworten: Stick/Pfeil links oder rechts,
## am Touchscreen die linke oder rechte Bildhälfte. Nach jeder Antwort kommt die
## Auflösung mit einem Satz Erklärung, dann die nächste Frage. Alle richtig =
## vierte Medaille „WISSEN“ (Game.wissen_abschliessen).
##
## Inhalt: config/wissensfragen.json. Die Fragen sind ein ENTWURF, solange dort
## "entwurf": true steht — dann zeigt das Quiz einen kleinen Vermerk. Abschalten
## mit "wissensabfrage": false in game-config.json.

signal done

const PFAD := "res://config/wissensfragen.json"
const AUFLOESUNG_MIN := 1.2     # so lange zählt kein Druck nach der Antwort
const AUFLOESUNG_MAX := 7.0     # danach geht es von selbst weiter

var fragen: Array = []
var entwurf := false
var index := 0
var richtig := 0
var _antwort := ""              # "" = wartet auf Antwort, sonst "links"/"rechts"
var _seit := 0.0
var _fertig := false

var _kopf: Label
var _frage: Label
var _karten := {}               # "links"/"rechts" → PanelContainer
var _texte := {}                # "links"/"rechts" → Label
var _urteil: Label
var _erklaerung: Label
var _weiter: Label


static func lade() -> Dictionary:
	if not FileAccess.file_exists(PFAD):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PFAD))
	return d if d is Dictionary else {}


## Gültige Fragen (frage, links, rechts, richtig ∈ links/rechts), höchstens drei.
static func gueltige_fragen(d: Dictionary) -> Array:
	var out := []
	var roh = d.get("fragen", [])
	if not (roh is Array):
		return out
	for f in roh:
		if f is Dictionary and str(f.get("frage", "")) != "" and str(f.get("links", "")) != "" \
				and str(f.get("rechts", "")) != "" and str(f.get("richtig", "")) in ["links", "rechts"]:
			out.append(f)
	return out.slice(0, 3)


## Soll vor dem Abschluss gefragt werden?
static func aktiv() -> bool:
	return bool(Game.config.get("wissensabfrage", true)) and not gueltige_fragen(lade()).is_empty()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var d := lade()
	fragen = gueltige_fragen(d)
	entwurf = bool(d.get("entwurf", false))
	var pal := Palette.from_theme(Game.theme("city"), "city")
	var bg := ColorRect.new()
	bg.color = pal.fill_dark
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_kopf = _label("", 24, Vector2(0, 120), Brand.UI_EYEBROW, Brand.spaced(Brand.sans("medium"), 4))
	_frage = _label("", 58, Vector2(160, 190), Palette.WHITE, Brand.headline(), 1600)
	for seite in ["links", "rechts"]:
		var karte := PanelContainer.new()
		karte.position = Vector2(160 if seite == "links" else 1000, 420)
		karte.custom_minimum_size = Vector2(760, 260)
		karte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(karte)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 14)
		karte.add_child(box)
		var pfeil := Label.new()
		pfeil.text = "◀" if seite == "links" else "▶"
		pfeil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pfeil.add_theme_font_size_override("font_size", 40)
		pfeil.add_theme_color_override("font_color", Brand.UI_HIGHLIGHT)
		box.add_child(pfeil)
		var t := Label.new()
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(680, 0)
		t.add_theme_font_size_override("font_size", 40)
		t.add_theme_font_override("font", Brand.sans("medium"))
		box.add_child(t)
		_karten[seite] = karte
		_texte[seite] = t
	_urteil = _label("", 44, Vector2(0, 730), Palette.WHITE, Brand.sans("bold"))
	_erklaerung = _label("", 32, Vector2(260, 800), Brand.UI_TEXT_DIM, null, 1400)
	_weiter = _label("", 24, Vector2(0, 960), Brand.UI_TEXT_DIM)
	if entwurf:
		_label(tr("Entwurf — Fachreview ausstehend"), 18, Vector2(0, 1040), Brand.UI_TEXT_MUTED)
	_zeige_frage()


func _label(text: String, groesse: int, pos: Vector2, farbe: Color, font: Font = null, breite := 1920.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(breite, groesse + 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if breite < 1920.0 else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	if font:
		l.add_theme_font_override("font", font)
	add_child(l)
	return l


func _karte_stil(seite: String, zustand: String) -> void:
	var rand := Brand.UI_BORDER
	var grund := Brand.UI_PANEL
	match zustand:
		"richtig":
			rand = Palette.OK
			grund = Color(Palette.OK.r, Palette.OK.g, Palette.OK.b, 0.28)
		"falsch":
			rand = Palette.DENY
			grund = Color(Palette.DENY.r, Palette.DENY.g, Palette.DENY.b, 0.22)
		"aus":
			grund = Color(Brand.UI_PANEL.r, Brand.UI_PANEL.g, Brand.UI_PANEL.b, 0.4)
	var stil := Brand.panel_style(Brand.UI_RADIUS, grund, rand, 3 if zustand in ["richtig", "falsch"] else 1, 40, 30)
	(_karten[seite] as PanelContainer).add_theme_stylebox_override("panel", stil)
	(_karten[seite] as PanelContainer).modulate.a = 0.55 if zustand == "aus" else 1.0


func _zeige_frage() -> void:
	var f: Dictionary = fragen[index]
	_antwort = ""
	_seit = 0.0
	_kopf.text = tr("Wissen · Frage %d / %d") % [index + 1, fragen.size()]
	_frage.text = tr(str(f["frage"]))
	for seite in ["links", "rechts"]:
		(_texte[seite] as Label).text = tr(str(f[seite]))
		_karte_stil(seite, "")
	_urteil.text = ""
	_erklaerung.text = ""
	_weiter.text = ""


## Antwort geben: "links" oder "rechts". Öffentlich für Tests.
func antworten(seite: String) -> void:
	if _fertig or _antwort != "" or not (seite in ["links", "rechts"]):
		return
	var f: Dictionary = fragen[index]
	_antwort = seite
	_seit = 0.0
	var ok := seite == str(f["richtig"])
	if ok:
		richtig += 1
	var andere := "rechts" if seite == "links" else "links"
	_karte_stil(seite, "richtig" if ok else "falsch")
	_karte_stil(andere, "richtig" if not ok else "aus")
	_urteil.text = tr("Richtig!") if ok else tr("Nicht ganz.")
	_urteil.add_theme_color_override("font_color", Palette.OK if ok else Palette.DENY)
	_erklaerung.text = tr(str(f.get("erklaerung", "")))
	Sfx.play("ok" if ok else "deny")


## Nach der Auflösung: nächste Frage oder fertig.
func weiter() -> void:
	if _fertig or _antwort == "":
		return
	index += 1
	if index >= fragen.size():
		_fertig = true
		Game.wissen_abschliessen(richtig, fragen.size())
		Statistik.wissen(richtig, fragen.size())
		done.emit()
		return
	_zeige_frage()


func _process(delta: float) -> void:
	if _antwort == "":
		return
	_seit += delta
	if _seit >= AUFLOESUNG_MIN:
		_weiter.text = tr("%s: weiter") % Kiosk.label_confirm()
	if _seit >= AUFLOESUNG_MAX:
		weiter()


func _unhandled_input(event: InputEvent) -> void:
	if _fertig:
		return
	var tipp_x := -1.0
	if event is InputEventScreenTouch and event.pressed:
		tipp_x = event.position.x
	elif event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		tipp_x = event.position.x
	if _antwort == "":
		if event.is_action_pressed("move_left") or (tipp_x >= 0.0 and tipp_x < 960.0):
			get_viewport().set_input_as_handled()
			antworten("links")
		elif event.is_action_pressed("move_right") or tipp_x >= 960.0:
			get_viewport().set_input_as_handled()
			antworten("rechts")
		return
	if _seit < AUFLOESUNG_MIN:
		return
	if tipp_x >= 0.0 or event.is_action_pressed("jump") or event.is_action_pressed("action") \
			or event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		weiter()
