extends Node
## KIOSK — Eingabe-Belegung aus config/input-bindings.json, Messe-Härtung
## (Idle-Watchdog, Vollbild), Kommandozeilen-Schalter und der automatische
## Prüflauf, der Screenshots speichert (für Reviews ohne Menschen am Rechner).
##
## Schalter (nach `--` an Godot übergeben, z. B. `godot --path godot -- --kiosk`):
##   --kiosk            Vollbild, Cursor aus, Idle-Reset aktiv
##   --fullscreen       nur Vollbild
##   --level=<id>       direkt in ein Level springen (Entwicklung)
##   --shots=<ordner>   Prüflauf: spielt automatisch, speichert PNGs, beendet sich
##   --shots-level=<id> Level für den Prüflauf (Standard: erstes Level der Playlist)
##   --lang=<code>      Sprache de/en/fr/es/zh/hi (im Browser: ?lang=fr)

signal any_input

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "action", "toggle"]
const KEY_NAMES := {
	"LEFT": KEY_LEFT, "RIGHT": KEY_RIGHT, "UP": KEY_UP, "DOWN": KEY_DOWN,
	"SPACE": KEY_SPACE, "ENTER": KEY_ENTER, "SHIFT": KEY_SHIFT, "ESC": KEY_ESCAPE,
	"A": KEY_A, "B": KEY_B, "C": KEY_C, "D": KEY_D, "E": KEY_E, "F": KEY_F, "G": KEY_G,
	"H": KEY_H, "I": KEY_I, "J": KEY_J, "K": KEY_K, "L": KEY_L, "M": KEY_M, "N": KEY_N,
	"O": KEY_O, "P": KEY_P, "Q": KEY_Q, "R": KEY_R, "S": KEY_S, "T": KEY_T, "U": KEY_U,
	"V": KEY_V, "W": KEY_W, "X": KEY_X, "Y": KEY_Y, "Z": KEY_Z, "CTRL": KEY_CTRL, "F2": KEY_F2, "F3": KEY_F3, "F4": KEY_F4,
}

var kiosk_mode := false
var idle_reset_seconds := 60.0
var last_input_ms := 0
var gamepad_seen := false
## Touch: `--touch` erzwingt die Bildschirm-Steuerung; `touch_seen` wird mit
## der ersten echten Berührung wahr (Tablet erkannt).
var touch_forced := false
var touch_seen := false
## Bedienung, im Hauptmenü gewählt: "" (noch nicht gewählt), "keyboard" (Tastatur/Arcade)
## oder "touch". Die Wahl steuert Bildschirm-Knüppel, Knopfnamen und Hinweistexte.
var input_mode := ""
var start_level_id := ""
var shots_dir := ""
var shots_level := ""
var debug := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	_build_input_map()
	idle_reset_seconds = float(Game.config.get("idleResetSeconds", 60))
	last_input_ms = Time.get_ticks_msec()
	# Im Browser darf Vollbild nur auf eine Nutzeraktion hin angefordert werden
	# (F11 / Vollbild-Knopf); beim Start bleibt die Seite im Fenster.
	if OS.has_feature("web"):
		pass
	elif kiosk_mode or "--fullscreen" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif shots_dir == "" and not "--windowed" in OS.get_cmdline_user_args() and not OS.has_feature("editor"):
		# Ausgelieferter Build: bildschirmfüllend in nativer Auflösung
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if kiosk_mode:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Input.joy_connection_changed.connect(func(_id, connected):
		if connected:
			gamepad_seen = true)
	if Input.get_connected_joypads().size() > 0:
		gamepad_seen = true


func _parse_args() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	# Web-Build: dieselben Schalter aus der URL, z. B. index.html?touch=1&level=04-die-huelle
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for part in query.trim_prefix("?").split("&"):
			if part == "":
				continue
			var key := part.get_slice("=", 0)
			var val := part.get_slice("=", 1) if "=" in part else "1"
			if val == "0" or val == "false":
				continue
			args.append("--%s" % key if val == "1" or val == "true" else "--%s=%s" % [key, val])
	for a in args:
		if a == "--kiosk":
			kiosk_mode = true
		elif a.begins_with("--level="):
			start_level_id = a.get_slice("=", 1)
		elif a.begins_with("--shots="):
			shots_dir = a.get_slice("=", 1)
		elif a.begins_with("--shots-level="):
			shots_level = a.get_slice("=", 1)
		elif a == "--debug":
			debug = true
		elif a.begins_with("--lang="):
			Game.set_lang(a.get_slice("=", 1))
		elif a == "--touch":
			touch_forced = true
			touch_seen = true


## Eingabe-Belegung aus JSON: Tastatur UND Arcade-Encoder laufen immer parallel.
func _build_input_map() -> void:
	var kb: Dictionary = Game.bindings.get("keyboard", {})
	var gp: Dictionary = Game.bindings.get("gamepad", {})
	var deadzone := float(gp.get("axisDeadzone", 0.4))
	var key_map := {
		"move_left": kb.get("left", ["LEFT", "A"]), "move_right": kb.get("right", ["RIGHT", "D"]),
		"move_up": kb.get("up", ["UP", "W"]), "move_down": kb.get("down", ["DOWN", "S"]),
		"jump": kb.get("jump", ["SPACE"]), "action": kb.get("action", ["E", "ENTER"]),
		"toggle": kb.get("toggle", ["SHIFT", "Q"]),
	}
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, deadzone)
		for k in key_map[action]:
			var code: Key = KEY_NAMES.get(str(k).to_upper(), KEY_NONE)
			if code != KEY_NONE:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				InputMap.action_add_event(action, ev)
	# Joystick hoch wechselt die Hülle (2-Button-Hardware, siehe README)
	if bool(gp.get("toggleOnUp", true)):
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_UP
		InputMap.action_add_event("toggle", ev)
	# Gamepad-Buttons
	for b in gp.get("jumpButtons", [0, 2]):
		_add_joy_button("jump", int(b))
	for b in gp.get("actionButtons", [1, 3]):
		_add_joy_button("action", int(b))
	for b in gp.get("toggleButtons", [4, 5]):
		_add_joy_button("toggle", int(b))
	if bool(gp.get("useDpad", true)):
		_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
		_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
		_add_joy_button("move_up", JOY_BUTTON_DPAD_UP)
		_add_joy_button("move_down", JOY_BUTTON_DPAD_DOWN)
		if bool(gp.get("toggleOnUp", true)):
			_add_joy_button("toggle", JOY_BUTTON_DPAD_UP)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	if bool(gp.get("toggleOnUp", true)):
		_add_joy_axis("toggle", JOY_AXIS_LEFT_Y, -1.0)
	# Bestätigen im Menü: Sprung ODER Aktion
	if not InputMap.has_action("confirm"):
		InputMap.add_action("confirm")
	for ev in InputMap.action_get_events("jump"):
		InputMap.action_add_event("confirm", ev)
	for ev in InputMap.action_get_events("action"):
		InputMap.action_add_event("confirm", ev)
	# Pause im Level: ESC, P, Gamepad START/BACK
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", esc)
	var pk := InputEventKey.new()
	pk.physical_keycode = KEY_P
	InputMap.action_add_event("pause", pk)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_button("pause", JOY_BUTTON_BACK)


static func _add_joy_button(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button as JoyButton
	InputMap.action_add_event(action, ev)


static func _add_joy_axis(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.3:
			return
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			gamepad_seen = true
		last_input_ms = Time.get_ticks_msec()
		any_input.emit()
	elif event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouseButton and event.pressed):
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			last_input_ms = Time.get_ticks_msec()
			any_input.emit()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.physical_keycode == KEY_F12:
			save_screenshot("user://screenshot-%d.png" % Time.get_ticks_msec())


func idle_seconds() -> float:
	return (Time.get_ticks_msec() - last_input_ms) / 1000.0


func note_input() -> void:
	last_input_ms = Time.get_ticks_msec()


## Bedienung festlegen (Hauptmenü): "keyboard" oder "touch".
func set_input_mode(mode: String) -> void:
	input_mode = mode
	touch_forced = mode == "touch"
	touch_seen = mode == "touch"


## Vorschlag fürs Hauptmenü: Touch, wenn schon berührt wurde oder ein Touchscreen da ist.
func suggested_input_mode() -> String:
	if input_mode != "":
		return input_mode
	if touch_seen or touch_forced or DisplayServer.is_touchscreen_available():
		return "touch"
	return "keyboard"


## „Weiter"-Knopf je nach Bedienung: Tippen, roter Knopf oder Leertaste.
func label_confirm() -> String:
	if touch_seen or touch_forced:
		return tr("TIPPEN")
	return tr("ROT") if has_gamepad() else tr("LEERTASTE")


func label_press_start() -> String:
	var cfg: Dictionary = Game.config.get("titleScreen", {})
	if touch_seen or touch_forced:
		return tr("Tippe zum Start!")
	if has_gamepad():
		return Game.t(cfg.get("pressStart", {"de": "Drück den roten Knopf!"}))
	return Game.t(cfg.get("pressStartKeyboard", {"de": "Drück LEERTASTE!"}))


func has_gamepad() -> bool:
	return gamepad_seen or Input.get_connected_joypads().size() > 0


## Beschriftung der Knöpfe je nach erkannter Hardware.
func label_jump() -> String:
	if touch_seen or touch_forced:
		return tr("SPRUNG")
	return tr("ROT") if has_gamepad() else tr("LEERTASTE")


func label_action() -> String:
	if touch_seen or touch_forced:
		return tr("AKTION")
	return tr("BLAU") if has_gamepad() else "E"


func label_toggle() -> String:
	if touch_seen or touch_forced:
		return tr("HÜLLE")
	return tr("Joystick HOCH") if has_gamepad() else "SHIFT"


func save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := path.get_base_dir()
	if dir != "" and not dir.begins_with("user://") and not dir.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(path)
	print("[shot] ", path)


# ------------------------------------------------------------------ Prüflauf

## Spielt automatisch und speichert Screenshots — für Reviews ohne Menschen.
func run_shots(main) -> void:
	var dir := shots_dir
	await get_tree().create_timer(1.4).timeout
	await save_screenshot(dir.path_join("01-titel.png"))
	# Intro-Screens: Zeitreise FRÜHER / HEUTE und Probelauf
	main.show_intro(1)
	# Blende (Runde 3): zwei Bilder mitten im Übergang — Kante fährt zu, dann auf
	await get_tree().create_timer(0.2).timeout
	await save_screenshot(dir.path_join("01a-blende-zu.png"))
	await get_tree().create_timer(0.3).timeout
	await save_screenshot(dir.path_join("01a2-blende-auf.png"))
	await get_tree().create_timer(2.9).timeout
	await save_screenshot(dir.path_join("01b-frueher.png"))
	main.show_intro(2)
	await get_tree().create_timer(11.8).timeout
	await save_screenshot(dir.path_join("01c-heute.png"))
	main.show_intro(3)
	await get_tree().create_timer(4.4).timeout
	await save_screenshot(dir.path_join("01d-probelauf.png"))
	await get_tree().create_timer(3.4).timeout
	await save_screenshot(dir.path_join("01d2-probelauf-huelle.png"))
	var level_id := shots_level if shots_level != "" else str(Game.playlist[0])
	var idx: int = maxi(0, Game.playlist.find(level_id))
	Game.reset_run()
	# `--shots-briefings`: alle zehn Stations-Briefings nacheinander (zwei Bilder je
	# Briefing, früh und spät im Szenen-Takt), danach Schluss — für Text- und Bildreview.
	if "--shots-briefings" in Array(OS.get_cmdline_user_args()):
		for i in Game.playlist.size():
			main.show_briefing(i)
			await get_tree().create_timer(4.6).timeout
			await save_screenshot(dir.path_join("b%02d-%s-a.png" % [i + 1, str(Game.playlist[i])]))
			await get_tree().create_timer(6.6).timeout
			await save_screenshot(dir.path_join("b%02d-%s-b.png" % [i + 1, str(Game.playlist[i])]))
		print("[shots] Briefings fertig → ", dir)
		get_tree().quit()
		return
	if Wissen.VOR_LEVEL.has(level_id):
		main.show_wissen(str(Wissen.VOR_LEVEL[level_id]), idx)
		await get_tree().create_timer(6.0).timeout
		await save_screenshot(dir.path_join("01e-wissen.png"))
	# Stations-Briefing (steht vor jedem Level; Mindestdauer 6 s)
	main.show_briefing(idx)
	await get_tree().create_timer(7.0).timeout
	await save_screenshot(dir.path_join("01f-briefing.png"))
	main._start_level(idx)
	await get_tree().create_timer(0.9).timeout
	await save_screenshot(dir.path_join("02-levelstart.png"))
	# Loslaufen, springen, Hülle wechseln — ein kleiner Probelauf
	Input.action_press("move_right")
	await get_tree().create_timer(1.1).timeout
	_tap("jump", 0.22)
	await get_tree().create_timer(0.35).timeout
	await save_screenshot(dir.path_join("03-sprung.png"))
	await get_tree().create_timer(0.9).timeout
	_tap("jump", 0.25)
	await get_tree().create_timer(0.25).timeout
	_tap("jump", 0.2)
	await get_tree().create_timer(0.3).timeout
	await save_screenshot(dir.path_join("04-doppelsprung.png"))
	await get_tree().create_timer(1.4).timeout
	_tap("toggle", 0.1)
	await get_tree().create_timer(0.6).timeout
	await save_screenshot(dir.path_join("05-huelle.png"))
	await get_tree().create_timer(2.0).timeout
	await save_screenshot(dir.path_join("06-weiter.png"))
	Input.action_release("move_right")
	await get_tree().create_timer(0.5).timeout
	await save_screenshot(dir.path_join("07-stand.png"))
	# Tunnel-Level: Paul bleibt stehen, die Kamera fährt weiter — sie muss an ihm warten
	if main.get("level") != null and is_instance_valid(main.level) and main.level.data.camera_mode == "tube":
		await get_tree().create_timer(5.0).timeout
		await save_screenshot(dir.path_join("07z-tunnel-wartet.png"))
	# Stationen weiter hinten im Level: Paul wird versetzt, Kamera zieht nach
	if main.get("level") != null and is_instance_valid(main.level) and main.level.player:
		var lvl = main.level
		var xs := [0.42, 0.66, 0.86]
		for i in xs.size():
			var tx: float = lvl.data.width * float(xs[i])
			lvl.player.global_position = Vector2(tx * Game.TILE, lvl.data.world_height() - 3 * Game.TILE - 2)
			lvl.player.velocity = Vector2.ZERO
			await get_tree().create_timer(1.3).timeout
			await save_screenshot(dir.path_join("07%s-position.png" % ["a", "b", "c"][i]))
	if main.has_method("debug_finish_level"):
		main.debug_finish_level()
		await get_tree().create_timer(1.0).timeout
		await save_screenshot(dir.path_join("08-siegel.png"))
		await get_tree().create_timer(3.4).timeout
		await save_screenshot(dir.path_join("08b-karte.png"))
	if main.has_method("show_reward"):
		main.show_reward()
		await get_tree().create_timer(1.2).timeout
		await save_screenshot(dir.path_join("09-reward.png"))
	print("[shots] fertig → ", dir)
	get_tree().quit()


func _tap(action: String, hold: float) -> void:
	Input.action_press(action)
	get_tree().create_timer(hold).timeout.connect(func(): Input.action_release(action))
