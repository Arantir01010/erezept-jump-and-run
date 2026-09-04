class_name TouchControls
extends CanvasLayer
## TOUCH-STEUERUNG — Tablet-Bedienung ohne Tastatur.
##
##   links   Knüppel (8 Richtungen, tote Mitte, folgt dem Finger, federt zurück;
##           der Finger darf irgendwo in der linken Bildhälfte aufsetzen —
##           der Knüppel springt dorthin)
##   rechts  großer SPRUNG-Knopf (rot wie der Arcade-Knopf), dazu AKTION (blau)
##           und HÜLLE (türkis). Ein Tipp irgendwo rechts außerhalb der Knöpfe
##           springt ebenfalls — Sprung-Latenz ist tödlich fürs Spielgefühl.
##
## Alles mündet in die InputMap (Input.action_press/release), die Spiellogik
## bleibt unberührt. Multitouch: jeder Finger hat seinen Besitzer (Knüppel
## oder Knopf). Sichtbar nur, wenn Touch erkannt wurde (erste echte Berührung
## oder `--touch`) UND ein Level läuft; auf Menü-Screens bleibt das Bild frei —
## dort blättert ein Tipp weiter (Vignette.is_press).

var enabled := false
var active := false
var stick_home := Vector2(250, 830)
var stick_pos := Vector2(250, 830)
var stick_r := 110.0
var knob := Vector2.ZERO
var stick_finger := -1
var held := {"move_left": false, "move_right": false, "move_up": false, "move_down": false}
var buttons: Array = []
var _overlay: _Overlay
var _grip := 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS   # Testeinspielung läuft auch in der Pause
	buttons = [
		{"action": "jump", "label": "SPRUNG", "pos": Vector2(1700, 860), "r": 96.0, "color": Color(0.98, 0.36, 0.32), "finger": -1},
		{"action": "action", "label": "AKTION", "pos": Vector2(1470, 920), "r": 66.0, "color": Color(0.36, 0.64, 0.98), "finger": -1},
		{"action": "toggle", "label": "HÜLLE", "pos": Vector2(1740, 630), "r": 66.0, "color": Pen.K, "finger": -1},
	]
	enabled = Kiosk.touch_forced
	_overlay = _Overlay.new()
	_overlay.tc = self
	add_child(_overlay)
	visible = false


func set_active(on: bool) -> void:
	active = on
	_apply()


func _apply() -> void:
	# Im Hauptmenü gewählte Tastatur-/Arcade-Bedienung: kein Overlay, auch wenn jemand tippt
	var soll := enabled and active and Kiosk.input_mode != "keyboard"
	if soll == visible:
		return
	visible = soll
	if not visible:
		_release_all()


func _release_all() -> void:
	stick_finger = -1
	_neutral()
	for b in buttons:
		if b["finger"] >= 0:
			b["finger"] = -1
			Input.action_release(b["action"])


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return   # in der Pause gehören Tipps dem Pausenmenü
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if not enabled and Kiosk.input_mode != "keyboard":
			enabled = true
			Kiosk.touch_seen = true
			_apply()
		Kiosk.note_input()
		if not visible:
			return
		if event is InputEventScreenTouch:
			_touch(event.index, event.position, event.pressed)
		else:
			_drag(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif Kiosk.touch_forced and (event is InputEventMouseButton or event is InputEventMouseMotion):
		# Testbetrieb (--touch): die Maus spielt Finger 0
		if event.device == InputEvent.DEVICE_ID_EMULATION or not visible:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_touch(0, event.position, event.pressed)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_drag(0, event.position)
			get_viewport().set_input_as_handled()


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if stick_finger < 0 and pos.x < 1920.0 * 0.44 and pos.y > 1080.0 * 0.28:
			stick_finger = index
			stick_pos = Vector2(clampf(pos.x, 160.0, 720.0), clampf(pos.y, 380.0, 1080.0 - 160.0))
			_update_stick(pos)
			return
		for b in buttons:
			if b["finger"] < 0 and pos.distance_to(b["pos"]) <= b["r"] * 1.3:
				_press_button(b, index)
				return
		if pos.x > 1920.0 * 0.5:
			var jump: Dictionary = buttons[0]
			if jump["finger"] < 0:
				_press_button(jump, index)
	else:
		if index == stick_finger:
			stick_finger = -1
			_neutral()
		for b in buttons:
			if b["finger"] == index:
				b["finger"] = -1
				Input.action_release(b["action"])


func _press_button(b: Dictionary, index: int) -> void:
	b["finger"] = index
	Input.action_press(b["action"])


func _drag(index: int, pos: Vector2) -> void:
	if index == stick_finger:
		_update_stick(pos)


func _update_stick(pos: Vector2) -> void:
	var d := pos - stick_pos
	var tot := stick_r * 0.14
	var links := d.x < -tot and absf(d.x) >= absf(d.y) * 0.45
	var rechts := d.x > tot and absf(d.x) >= absf(d.y) * 0.45
	var oben := d.y < -tot and absf(d.y) >= absf(d.x) * 0.45
	var unten := d.y > tot and absf(d.y) >= absf(d.x) * 0.45
	_hold("move_left", links)
	_hold("move_right", rechts)
	_hold("move_up", oben)
	_hold("move_down", unten)
	knob = d.limit_length(stick_r * 0.62)


func _hold(action: String, on: bool) -> void:
	if held[action] == on:
		return
	held[action] = on
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _neutral() -> void:
	for a in held.keys():
		_hold(a, false)
	knob = Vector2.ZERO


## Prüfschalter `--test-eingabe=<folge>`: echte Tastenereignisse einspielen, z. B.
## `--test-eingabe=F12,RIGHT,F12,SPACE,F12` — eine Taste alle 0,7 s (F12 = Screenshot nach
## user://), danach beendet sich das Spiel. Prüft den Weg Taste → InputMap → Menü.
var _test_keys: PackedStringArray = []
var _test_t := 0.0
var _test_i := 0

func _ready_test() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test-eingabe="):
			_test_keys = a.get_slice("=", 1).split(",")


func _tick_test(delta: float) -> void:
	if _test_keys.is_empty():
		return
	_test_t += delta
	if _test_i >= _test_keys.size():
		if _test_t > 1.0:
			get_tree().quit()
		return
	if _test_t < 0.7:
		return
	_test_t = 0.0
	var name := _test_keys[_test_i]
	_test_i += 1
	var code: Key = Kiosk.KEY_NAMES.get(name, KEY_NONE)
	if name == "F12":
		code = KEY_F12
	if code == KEY_NONE:
		return
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _process(delta: float) -> void:
	if _test_i == 0 and _test_t == 0.0 and _test_keys.is_empty():
		_ready_test()
	_tick_test(delta)
	# Bedienung im Menü umgestellt? (Touch gewählt → Overlay an, Tastatur → aus)
	if Kiosk.input_mode == "touch" and not enabled:
		enabled = true
	if (enabled and active and Kiosk.input_mode != "keyboard") != visible:
		_apply()
	if not visible:
		return
	_grip = move_toward(_grip, 1.0 if stick_finger >= 0 else 0.0, delta * 8.0)
	if stick_finger < 0:
		stick_pos = stick_pos.lerp(stick_home, 1.0 - exp(-9.0 * delta))
	_overlay.queue_redraw()


class _Overlay extends Node2D:
	var tc: TouchControls
	const GLAS := Color(0.016, 0.035, 0.06, 0.42)
	const KANTE := Color(1, 1, 1, 0.14)
	const GRAU := Color(0.62, 0.70, 0.78)
	const AN := Color(0.5, 0.91, 1.0)

	func _draw() -> void:
		var font := Brand.sans("bold")
		# ---- Knüppel ----
		var p := tc.stick_pos
		var r := tc.stick_r
		var a := 0.55 + 0.4 * tc._grip
		draw_circle(p, r, Color(GLAS.r, GLAS.g, GLAS.b, GLAS.a * a))
		draw_arc(p, r, 0, TAU, 64, Color(1, 1, 1, KANTE.a * a), 2.0, true)
		var pfeile := [
			["move_up", Vector2(0, -1)], ["move_down", Vector2(0, 1)],
			["move_left", Vector2(-1, 0)], ["move_right", Vector2(1, 0)],
		]
		for pf in pfeile:
			var an: bool = tc.held[pf[0]]
			var dir: Vector2 = pf[1]
			var tip := p + dir * r * 0.86
			var base := p + dir * r * 0.66
			var side := Vector2(-dir.y, dir.x) * r * 0.11
			var col := AN if an else Color(GRAU.r, GRAU.g, GRAU.b, 0.45 * a)
			if an:
				draw_circle(tip - dir * r * 0.08, r * 0.16, Color(AN.r, AN.g, AN.b, 0.25))
			draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), col)
		var kn := p + tc.knob
		var kr := r * 0.44
		var aktiv := tc.held.values().has(true)
		draw_circle(kn, kr, Color(0.5, 0.91, 1.0, 0.22) if aktiv else Color(0.62, 0.70, 0.78, 0.14 * a))
		draw_arc(kn, kr, 0, TAU, 48, Color(0.5, 0.91, 1.0, 0.85) if aktiv else Color(0.62, 0.70, 0.78, 0.45 * a), 2.0, true)
		if aktiv:
			draw_arc(kn, kr + 5, 0, TAU, 48, Color(0.3, 0.89, 1.0, 0.25), 6.0, true)
		# ---- Knöpfe ----
		for b in tc.buttons:
			var bp: Vector2 = b["pos"]
			var br: float = b["r"]
			var bc: Color = b["color"]
			var down: bool = b["finger"] >= 0
			draw_circle(bp, br, Color(bc.r, bc.g, bc.b, 0.42) if down else GLAS)
			draw_arc(bp, br, 0, TAU, 64, Color(bc.r, bc.g, bc.b, 0.95 if down else 0.55), 3.0 if down else 2.0, true)
			if down:
				draw_arc(bp, br + 6, 0, TAU, 64, Color(bc.r, bc.g, bc.b, 0.3), 8.0, true)
			var ic := Color(1, 1, 1, 0.95 if down else 0.75)
			match str(b["action"]):
				"jump":
					var s := br * 0.36
					draw_polyline(PackedVector2Array([bp + Vector2(-s, s * 0.45), bp + Vector2(0, -s * 0.55), bp + Vector2(s, s * 0.45)]), ic, 7.0, true)
				"action":
					draw_string(font, bp + Vector2(-br, 12), "E", HORIZONTAL_ALIGNMENT_CENTER, br * 2, 40, ic)
				"toggle":
					var pts := PackedVector2Array()
					for i in 7:
						var ang := -PI * 0.5 + i * TAU / 6.0
						pts.append(bp + Vector2(cos(ang), sin(ang)) * br * 0.38)
					draw_polyline(pts, ic, 4.0, true)
			draw_string(font, bp + Vector2(-br * 1.5, br + 30), tr(str(b["label"])), HORIZONTAL_ALIGNMENT_CENTER, br * 3, 20, Color(1, 1, 1, 0.8 if down else 0.55))
