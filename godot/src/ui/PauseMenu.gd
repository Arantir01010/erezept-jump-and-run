class_name PauseMenu
extends CanvasLayer
## PAUSE — Overlay über dem Level (Layer 50, läuft bei angehaltenem Baum weiter):
## dunkelt ab, zeigt „PAUSE", den Stationsnamen und sieben Zeilen — Weiter, Station
## neu starten, Steuerung, Musik an/aus, Töne an/aus, Bewegung reduzieren an/aus
## (keine Kamerastöße, Komfort.gd), Zum Hauptmenü. Bedienung:
## Hoch/Runter + Bestätigen (Sprung/Aktion), Fingertipp oder Mausklick auf eine
## Zeile; ESC, P oder START setzen fort. Im Messe-Modus gilt der Idle-Reset auch
## hier: wer weggeht, landet im Hauptmenü.
##
## Team-Feedback 9/2026: Wer in einer Station festhing, konnte nur ins Hauptmenü
## (alles von vorn) — jetzt gibt es „Station neu starten". „Steuerung" zeigt die
## Tasten der erkannten Bedienung; die Taste E (TI-Aktion) kannte niemand.

signal resumed
signal restart_requested
signal quit_to_title

const ROWS := ["weiter", "neustart", "steuerung", "musik", "toene", "bewegung", "menue"]

var index := 0
var station_name := ""
var zeigt_steuerung := false
var _rows: Array = []
var _panel: PanelContainer
var _hint: Label
var _steuerung: VBoxContainer
var _armed := false
var _t := 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_root_input)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.067, 0.067, 0.075, 0.64)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Brand.panel_style(Brand.UI_RADIUS, Brand.UI_PANEL_SOLID, Brand.UI_BORDER, 1, 64, 40))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.gui_input.connect(_on_root_input)
	root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(col)

	var titel := Label.new()
	titel.text = "Pause"
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titel.label_settings = Brand.label_settings(64, Palette.WHITE, Brand.headline())
	col.add_child(titel)
	var sub := Label.new()
	sub.text = station_name
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.label_settings = Brand.label_settings(24, Brand.UI_TEXT_DIM, Brand.sans("roman"))
	col.add_child(sub)
	var abstand := Control.new()
	abstand.custom_minimum_size = Vector2(0, 10)
	col.add_child(abstand)

	for i in ROWS.size():
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(560, 58)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_font_override("font", Brand.sans("medium"))
		l.gui_input.connect(_on_row_input.bind(i))
		col.add_child(l)
		_rows.append(l)

	_steuerung = _baue_steuerung()
	_steuerung.visible = false
	col.add_child(_steuerung)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.label_settings = Brand.label_settings(19, Brand.UI_TEXT_MUTED, Brand.sans("roman"))
	col.add_child(_hint)
	_refresh()


## Tastentafel zur erkannten Bedienung: [Taste, was sie tut].
static func steuerung_zeilen() -> Array:
	if Kiosk.touch_seen or Kiosk.touch_forced:
		return [[tr_s("Knüppel"), tr_s("laufen & ducken")], [tr_s("Sprung"), tr_s("springen · 2× Rezi-Schub")],
			[tr_s("Aktion"), tr_s("TI-Aktion an Terminal, Kartenleser und Stempel")], [tr_s("Hülle"), tr_s("Hülle an / aus")],
			["❚❚", tr_s("Pause")]]
	if Kiosk.has_gamepad():
		return [[tr_s("Joystick"), tr_s("laufen & ducken")], [tr_s("Rot"), tr_s("springen · 2× Rezi-Schub")],
			[tr_s("Blau"), tr_s("TI-Aktion an Terminal, Kartenleser und Stempel")], [tr_s("Hoch"), tr_s("Hülle an / aus")],
			["Start", tr_s("Pause")]]
	return [[tr_s("Pfeile / WASD"), tr_s("laufen & ducken")], [tr_s("Leertaste"), tr_s("springen · 2× Rezi-Schub")],
		["E", tr_s("TI-Aktion an Terminal, Kartenleser und Stempel")], ["Shift", tr_s("Hülle an / aus")],
		["Esc / P", tr_s("Pause")]]


static func tr_s(s: String) -> String:
	return str(TranslationServer.translate(s))


func _baue_steuerung() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	var kopf := Label.new()
	kopf.text = tr("Steuerung")
	kopf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kopf.label_settings = Brand.label_settings(30, Brand.UI_ACCENT, Brand.sans("medium"))
	box.add_child(kopf)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 14)
	for z in steuerung_zeilen():
		var taste := Label.new()
		taste.text = str(z[0])
		taste.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		taste.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		taste.custom_minimum_size = Vector2(190, 48)
		taste.add_theme_font_size_override("font_size", 24)
		taste.add_theme_font_override("font", Brand.sans("medium"))
		taste.add_theme_color_override("font_color", Color(0.125, 0.129, 0.141))
		# Tastenkappe: hell, dunkle Unterkante — wie die Kappen im Probelauf
		var kappe := Brand.panel_style(8, Color(0.875, 0.89, 0.902, 0.95), Color(0.125, 0.129, 0.141, 0.9), 0, 14, 4)
		kappe.border_width_bottom = 4
		taste.add_theme_stylebox_override("normal", kappe)
		grid.add_child(taste)
		var was := Label.new()
		was.text = str(z[1])
		was.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		was.custom_minimum_size = Vector2(0, 48)
		was.add_theme_font_size_override("font_size", 24)
		was.add_theme_font_override("font", Brand.sans("roman"))
		was.add_theme_color_override("font_color", Palette.WHITE)
		grid.add_child(was)
	box.add_child(grid)
	return box


func _refresh() -> void:
	var texte := [
		tr("Weiter"),
		tr("Station neu starten"),
		tr("Steuerung"),
		tr("Musik: an") if Sfx.music_on else tr("Musik: aus"),
		tr("Töne: an") if Sfx.sound_on else tr("Töne: aus"),
		tr("Bewegung reduzieren: an") if Komfort.bewegung_reduziert() else tr("Bewegung reduzieren: aus"),
		tr("Zum Hauptmenü"),
	]
	for i in _rows.size():
		var l: Label = _rows[i]
		l.visible = not zeigt_steuerung
		l.text = str(texte[i])
		var an := i == index
		l.add_theme_color_override("font_color", Brand.UI_ACCENT if an else Brand.UI_TEXT_DIM)
		l.add_theme_stylebox_override("normal", Brand.panel_style(Brand.UI_RADIUS,
			Color(1, 1, 1, 0.07) if an else Color(0, 0, 0, 0), Brand.UI_ACCENT if an else Color(0, 0, 0, 0), 1, 18, 6))
	_steuerung.visible = zeigt_steuerung
	if zeigt_steuerung:
		_hint.text = tr("%s oder Esc: zurück") % Kiosk.label_confirm()
	else:
		var nav := tr("Knüppel") if (Kiosk.touch_seen or Kiosk.touch_forced) else (tr("Joystick") if Kiosk.has_gamepad() else tr("Pfeiltasten"))
		_hint.text = tr("%s: wählen · %s: bestätigen · Esc: weiter") % [nav, Kiosk.label_confirm()]


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.3:
		_armed = true
	# Messe: niemand mehr da → zurück zum Hauptmenü, auch aus der Pause (nur --kiosk)
	if Kiosk.consume_idle_reset():
		quit_to_title.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	if zeigt_steuerung:
		# Tafel schließen: Bestätigen, ESC/P/START oder Abbrechen — zurück ins Menü
		if event.is_action_pressed("confirm") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_steuerung_zeigen(false)
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resumed.emit()
		return
	if event.is_action_pressed("move_down"):
		index = (index + 1) % ROWS.size()
		Sfx.play("tick")
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		index = (index + ROWS.size() - 1) % ROWS.size()
		Sfx.play("tick")
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_activate(index)


func _on_row_input(event: InputEvent, i: int) -> void:
	if zeigt_steuerung:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		index = i
		_refresh()
		_activate(i)


## Klick oder Fingertipp irgendwo schließt die Steuerungstafel.
func _on_root_input(event: InputEvent) -> void:
	if zeigt_steuerung and _armed and event is InputEventMouseButton and event.pressed:
		_steuerung_zeigen(false)


func _steuerung_zeigen(an: bool) -> void:
	zeigt_steuerung = an
	Sfx.play("tick")
	_refresh()


func _activate(i: int) -> void:
	match ROWS[i]:
		"weiter":
			resumed.emit()
		"neustart":
			restart_requested.emit()
		"steuerung":
			_steuerung_zeigen(true)
		"musik":
			Sfx.set_music(not Sfx.music_on)
			Sfx.play("tick")
			_refresh()
		"toene":
			Sfx.set_sound(not Sfx.sound_on)
			Sfx.play("tick")
			_refresh()
		"bewegung":
			Komfort.setze_bewegung_reduziert(not Komfort.bewegung_reduziert())
			Sfx.play("tick")
			_refresh()
		"menue":
			quit_to_title.emit()
