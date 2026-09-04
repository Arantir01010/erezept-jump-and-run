extends Node
## MAIN — Szenenfluss:
##   Hauptmenü → Zeitreise FRÜHER → HEUTE → Probelauf → Briefing 1 → Level 1 …
##   … Level → Stationskarte → (ePA-Wissen vor den vier ePA-Stationen) → Briefing → Level … → Reward.
## Vor JEDER Station steht ein Briefing (Briefing.gd): was in der Wirklichkeit
## passiert, welche Mechanik das Level hat, was zu tun ist.
## Dazu Glühen (WorldEnvironment), Blende, Touch-Steuerung und Idle-Reset.

enum Screen { TITLE, INTRO, WISSEN, BRIEFING, LEVEL, CARD, REWARD }

var screen: Screen = Screen.TITLE
var world: Node2D
var overlay: CanvasLayer
var hud: HUD
var touch: TouchControls
var fade: ColorRect
var _wipe: ShaderMaterial
var level: Level
var _current: Node
var _level_index := 0


func _ready() -> void:
	# Markenschrift für alle Controls (Helvetica Neue; Fallback: Godot-Standard)
	get_window().theme = Brand.theme()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	# Glühen nur für echte HDR-Lichtquellen (Prüfsummen, REZI, Lampen) — helle
	# Pastellflächen bleiben unter der Schwelle, sonst überstrahlt der Tag.
	e.glow_enabled = true
	e.glow_intensity = 0.65
	e.glow_strength = 1.0
	e.glow_bloom = 0.03
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.glow_hdr_threshold = 1.35
	e.glow_hdr_scale = 2.4
	# Mehrere Glühstufen: enger Kern plus weiter, weicher Hof
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 0.85)
	e.set_glow_level(2, 0.6)
	e.set_glow_level(3, 0.9)
	e.set_glow_level(4, 0.4)
	e.set_glow_level(5, 0.55)
	env.environment = e
	add_child(env)

	var post := PostFx.new()
	add_child(post)
	Fx.post = post

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	overlay = CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)

	hud = HUD.new()
	hud.layer = 20
	add_child(hud)
	hud.visible = false

	touch = TouchControls.new()
	add_child(touch)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	# Blende: schräge Kante mit warmem Saum (src/shaders/wipe.gdshader) statt Schwarzblende
	fade = ColorRect.new()
	fade.color = Color(1, 1, 1, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe = ShaderMaterial.new()
	_wipe.shader = load("res://src/shaders/wipe.gdshader")
	_wipe.set_shader_parameter("progress", 1.0)
	_wipe.set_shader_parameter("direction", 1.0)
	fade.material = _wipe
	fade_layer.add_child(fade)

	if Kiosk.shots_dir != "":
		show_title()
		Kiosk.run_shots(self)
	elif Kiosk.start_level_id != "":
		var idx: int = maxi(0, Game.playlist.find(Kiosk.start_level_id))
		Game.reset_run()
		_start_level(idx)
	else:
		show_title()


func _process(_delta: float) -> void:
	# Idle-Reset: niemand spielt → zurück zum Titel (Attract)
	if screen != Screen.TITLE and Kiosk.shots_dir == "" and Kiosk.idle_seconds() > Kiosk.idle_reset_seconds:
		show_title()


func _set_screen(s: Screen) -> void:
	screen = s
	hud.visible = s == Screen.LEVEL
	touch.set_active(s == Screen.LEVEL)
	# Farbstimmung der Welt gilt nur im Level; Menü, Intro, Karte und Reward neutral
	if s != Screen.LEVEL and Fx.post:
		Fx.post.grade_neutral()


func _clear() -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	_current = null
	if is_instance_valid(level):
		level.queue_free()
	level = null


## Blende zu: die Kante fährt von links nach rechts über das Bild.
func _fade_out(t := 0.35) -> void:
	_wipe.set_shader_parameter("direction", 1.0)
	var tw := create_tween()
	tw.tween_property(_wipe, "shader_parameter/progress", 1.0, t + 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished


## Blende auf: dieselbe Kante zieht weiter nach rechts und gibt das Neue frei.
func _fade_in(t := 0.45) -> void:
	_wipe.set_shader_parameter("direction", -1.0)
	var tw := create_tween()
	tw.tween_property(_wipe, "shader_parameter/progress", 0.0, t + 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Hauptmenü: das lebende Klinikum. Jeder Knopf → Zeitreise.
func show_title() -> void:
	await _fade_out(0.25)
	_clear()
	_set_screen(Screen.TITLE)
	Game.reset_run()
	var title := Title.new()
	title.start_requested.connect(func(): show_intro(1))
	overlay.add_child(title)
	_current = title
	Sfx.music("music_title")
	_fade_in()


## Intro-Phasen: 1 FRÜHER, 2 HEUTE (was sich mit der ePA/TI geändert hat),
## 3 Probelauf (wie das Spiel funktioniert). Danach Level 1.
func show_intro(phase: int) -> void:
	await _fade_out(0.25)
	_clear()
	_set_screen(Screen.INTRO)
	var intro := Intro.new(phase)
	intro.done.connect(func():
		if phase < 3:
			show_intro(phase + 1)
		else:
			start_run(0))
	overlay.add_child(intro)
	_current = intro
	_fade_in()


## ePA-Lehrsequenz vor einer Station (statt City-Lauf): erst verstehen, dann
## das Briefing der Station, dann spielen.
func show_wissen(wissen_id: String, to_index: int) -> void:
	await _fade_out(0.25)
	_clear()
	_set_screen(Screen.WISSEN)
	var w := Wissen.new(wissen_id)
	w.done.connect(func(): show_briefing(to_index))
	overlay.add_child(w)
	_current = w
	_fade_in()


## Stations-Briefing: Erklärscreen direkt vor dem Level (Mindestdauer 6 s).
func show_briefing(index: int) -> void:
	if index >= Game.playlist.size():
		show_reward()
		return
	await _fade_out(0.25)
	_clear()
	_set_screen(Screen.BRIEFING)
	var b := Briefing.new(index)
	b.done.connect(func(): _start_level(index))
	overlay.add_child(b)
	_current = b
	_fade_in()


func start_run(index := 0) -> void:
	Game.reset_run()
	go_level(index)


## Nächste Station — erst der Wissenspfad (wenn es einen gibt), dann das Briefing.
func go_level(index: int) -> void:
	if index >= Game.playlist.size():
		show_reward()
		return
	var id := str(Game.playlist[index])
	if Wissen.VOR_LEVEL.has(id):
		show_wissen(str(Wissen.VOR_LEVEL[id]), index)
	else:
		show_briefing(index)


func _start_level(index: int) -> void:
	await _fade_out(0.25)
	_clear()
	_set_screen(Screen.LEVEL)
	_level_index = index
	Game.level_index = index
	if index >= Game.playlist.size():
		show_reward()
		return
	var id := str(Game.playlist[index])
	var data := LevelData.load_level(id)
	if not data.errors.is_empty():
		push_error("Level %s: %s" % [id, ", ".join(data.errors)])
	level = Level.new()
	world.add_child(level)
	level.setup(data)
	level.completed.connect(_on_level_completed)
	hud.bind(level)
	_fade_in()


func _on_level_completed(result: Dictionary) -> void:
	await _fade_out(0.3)
	_set_screen(Screen.CARD)
	var card := LevelCard.new()
	card.done.connect(func(): go_level(_level_index + 1))
	overlay.add_child(card)
	card.setup(level.data, result, _level_index + 1 < Game.playlist.size())
	_current = card
	if is_instance_valid(level):
		level.queue_free()
		level = null
	_fade_in()


func show_reward() -> void:
	await _fade_out(0.3)
	_clear()
	_set_screen(Screen.REWARD)
	var r := Reward.new()
	r.done.connect(show_title)
	overlay.add_child(r)
	_current = r
	Sfx.music("music_title")
	_fade_in()


## Nur für den Prüflauf (Screenshots): Level sofort abschließen.
func debug_finish_level() -> void:
	if is_instance_valid(level):
		level.complete_level()
