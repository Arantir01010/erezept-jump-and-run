extends Mechanic
## PIN-SCHLEUSE (Baustein „timing-gate“) — blauer Knopf im Takt.

var steps := 4
var step_s := 0.9
var window_ratio := 0.45
var progress := 0
var running := false
var done := false
var _step_start := 0.0
var _fail_until := 0.0
var _hint := false
var _last_tip := -100.0
var _t := 0.0
var _flash := []
var _light: PointLight2D

func spawn() -> void:
	z_index = 5
	steps = int(param("steps", 4))
	step_s = float(param("stepMs", 900)) / 1000.0
	for i in steps:
		_flash.append(0.0)
	_light = Fx.light(self, Vector2(0, _light_y()), pal.accent, 160.0, 0.0)
	var g = linked_gate()
	if g:
		g.open_hint = ltext("gateHint", {"de": "Das Tor ist zu! Schaff erst die PIN-Schleuse: im Takt der pulsierenden Lichter drücken.",
			"en": "The gate is locked! Pass the PIN check first: press on the beat of the pulsing lights."})

var _slow: float:
	get: return step_s * Game.assist_slowdown("timing-" + str(rect.position.x))

func tick(delta: float) -> void:
	_t += delta
	kappe(Vector2(0, _light_y() - 58.0), not done and player_in_rect(rect), delta)
	for i in steps:
		_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)
	var win := running and (_t - _step_start) < _slow * window_ratio and _t >= _fail_until
	_light.color = Palette.OK if done else (Palette.DENY if _t < _fail_until else pal.accent)
	_light.position.x = _light_x(mini(progress, steps - 1))
	_light.energy = move_toward(_light.energy, (0.9 if win or done else (0.25 if running else 0.0)), delta * 6.0)
	queue_redraw()
	if done or _t < _fail_until:
		return
	var inside := player_in_rect(rect)
	if not running and inside:
		running = true
		progress = 0
		_step_start = _t
		Sfx.play("tick", 0.8, -6.0)
		if not _hint:
			_hint = true
			var h = param("hint", null)
			if h != null:
				say(Game.t(h))
	if not running:
		return
	if not inside:
		running = false
		return
	var elapsed := _t - _step_start
	var in_window := elapsed < _slow * window_ratio
	if elapsed >= _slow:
		_step_start = _t
		Sfx.play("tick", 1.0, -6.0)
	if Input.is_action_just_pressed("action"):
		if in_window:
			_flash[progress] = 1.0
			progress += 1
			Sfx.play("ok", 1.0 + progress * 0.08)
			Fx.sparkle(level, global_position + Vector2(_light_x(progress - 1), _light_y()), Palette.OK, 6, 120.0)
			if progress >= steps:
				_succeed()
			else:
				_step_start = _t
		else:
			_fail()

func _fail() -> void:
	var key := "timing-" + str(rect.position.x)
	Game.assist_fail(key)
	progress = 0
	_fail_until = _t + 0.45
	_step_start = _t + 0.45
	Sfx.play("deny", 1.2, -4.0)
	Fx.float_text(level, global_position + Vector2(0, -60), "Prüfung wiederholen", Palette.DENY, 22)
	if Game.assist_fail_count(key) >= 2 and _t - _last_tip > 6.0:
		_last_tip = _t
		say(ltext("failHint", {"de": "Tipp: Drück %s genau dann, wenn das gelbe Licht groß aufleuchtet!" % Kiosk.label_action(),
			"en": "Tip: press the action right when the yellow light glows big!"}))

func _succeed() -> void:
	done = true
	running = false
	if Game.assist_clean("timing-" + str(rect.position.x)):
		Game.add_security_bonus()
		Fx.float_text(level, global_position + Vector2(0, -70), "+250 Sicherheits-Bonus", Palette.GOLD, 22)
	var g = linked_gate()
	if g:
		g.open()
	Fx.ring(level, global_position, Palette.OK, 120.0)
	Sfx.play("gate")

func _light_x(i: int) -> float:
	return -((steps - 1) * 44.0) / 2.0 + i * 44.0

func _light_y() -> float:
	return -rect.size.y / 2.0 - 30.0

func _draw() -> void:
	var r := local_rect()
	# Terminal-Sockel
	var base := Rect2(-70, r.end.y - 70, 140, 70)
	draw_panel(base, pal.metall, pal.detail, 8, 0.4)
	draw_rect(Rect2(-56, r.end.y - 58, 112, 30), Color(0.067, 0.067, 0.075, 0.9))
	var txt := "PIN" if not done else "OK"
	draw_string(ThemeDB.fallback_font, Vector2(-56, r.end.y - 36), txt, HORIZONTAL_ALIGNMENT_CENTER, 112, 22, Palette.glow(Palette.OK if done else pal.accent, 1.3))
	# Lichter
	var elapsed := _t - _step_start
	var in_window := running and elapsed < _slow * window_ratio and _t >= _fail_until
	for i in steps:
		var p := Vector2(_light_x(i), _light_y())
		var c := Color(0.298, 0.314, 0.337)
		var rad := 11.0
		if _t < _fail_until:
			c = Palette.DENY
		elif i < progress:
			c = Palette.OK
		elif i == progress and in_window:
			c = pal.accent
			rad = 16.0  # größer, nicht nur andersfarbig
		draw_circle(p, rad + 4.0, Color(0.067, 0.067, 0.075, 0.8))
		draw_circle(p, rad, Palette.glow(c, 1.6 if (i == progress and in_window) or i < progress else 1.0))
		if _flash[i] > 0.0:
			draw_arc(p, rad + 8.0 + (1.0 - _flash[i]) * 14.0, 0, TAU, 20, Color(1, 1, 1, _flash[i]), 2.0, true)
	# Takt-Balken unter den Lichtern
	if running and _t >= _fail_until:
		var frac := clampf(elapsed / _slow, 0.0, 1.0)
		var w := (steps - 1) * 44.0 + 32.0
		draw_rect(Rect2(-w / 2.0, _light_y() + 26, w, 4), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(-w / 2.0, _light_y() + 26, w * (1.0 - frac), 4), Palette.glow(pal.accent, 1.3))
