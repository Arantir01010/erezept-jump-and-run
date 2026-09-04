class_name PauseMenu
extends CanvasLayer
## PAUSE — Overlay über dem Level (Layer 50, läuft bei angehaltenem Baum weiter):
## dunkelt ab, zeigt „PAUSE", den Stationsnamen und vier Zeilen — Weiter, Musik
## an/aus, Töne an/aus, Zum Hauptmenü. Bedienung: Hoch/Runter + Bestätigen
## (Sprung/Aktion), Fingertipp oder Mausklick auf eine Zeile; ESC, P oder START
## setzen fort. Der Idle-Reset gilt auch hier: wer weggeht, landet im Hauptmenü.

signal resumed
signal quit_to_title

const ROWS := ["weiter", "musik", "toene", "menue"]

var index := 0
var station_name := ""
var _rows: Array = []
var _panel: PanelContainer
var _hint: Label
var _armed := false
var _t := 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.64)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Brand.panel_style(Brand.UI_RADIUS, Brand.UI_PANEL_SOLID, Brand.UI_BORDER, 1, 64, 40))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(col)

	var titel := Label.new()
	titel.text = "PAUSE"
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

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.label_settings = Brand.label_settings(19, Brand.UI_TEXT_MUTED, Brand.sans("roman"))
	col.add_child(_hint)
	_refresh()


func _refresh() -> void:
	var texte := [
		tr("Weiter"),
		tr("Musik: an") if Sfx.music_on else tr("Musik: aus"),
		tr("Töne: an") if Sfx.sound_on else tr("Töne: aus"),
		tr("Zum Hauptmenü"),
	]
	for i in _rows.size():
		var l: Label = _rows[i]
		l.text = str(texte[i])
		var an := i == index
		l.add_theme_color_override("font_color", Brand.UI_ACCENT if an else Brand.UI_TEXT_DIM)
		l.add_theme_stylebox_override("normal", Brand.panel_style(Brand.UI_RADIUS,
			Color(1, 1, 1, 0.07) if an else Color(0, 0, 0, 0), Brand.UI_ACCENT if an else Color(0, 0, 0, 0), 1, 18, 6))
	var nav := tr("Knüppel") if (Kiosk.touch_seen or Kiosk.touch_forced) else (tr("Joystick") if Kiosk.has_gamepad() else tr("Pfeiltasten"))
	_hint.text = tr("%s: wählen · %s: bestätigen · ESC: weiter") % [nav, Kiosk.label_confirm()]


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.3:
		_armed = true
	# Messe: niemand mehr da → zurück zum Hauptmenü, auch aus der Pause
	if Kiosk.shots_dir == "" and Kiosk.idle_seconds() > Kiosk.idle_reset_seconds:
		quit_to_title.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		index = i
		_refresh()
		_activate(i)


func _activate(i: int) -> void:
	match ROWS[i]:
		"weiter":
			resumed.emit()
		"musik":
			Sfx.set_music(not Sfx.music_on)
			Sfx.play("tick")
			_refresh()
		"toene":
			Sfx.set_sound(not Sfx.sound_on)
			Sfx.play("tick")
			_refresh()
		"menue":
			quit_to_title.emit()
