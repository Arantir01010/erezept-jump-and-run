extends Mechanic
## SIGNATUR-STEMPEL (Baustein „stamp-exit“) — Levelausgang mit Signatur (QES).

var _t := 0.0
var _y := 0.0
var done := false
var _hint := false
var _last_tip := -100.0
var top_y := 0.0
var bottom_y := 0.0
var _cycle: Tween
var _light: PointLight2D

func spawn() -> void:
	z_index = 6
	top_y = -rect.size.y / 2.0 - 30.0
	bottom_y = rect.size.y / 2.0 - 40.0
	_y = top_y
	_light = Fx.light(self, Vector2(0, top_y), Palette.GOLD, 180.0, 0.5)
	_start_cycle()

func _start_cycle() -> void:
	var hold := 0.7 * Game.assist_slowdown("stamp")
	_cycle = create_tween()
	_cycle.tween_interval(hold)
	_cycle.tween_property(self, "_y", bottom_y, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_cycle.tween_callback(func():
		Fx.dust(level, Vector2(global_position.x, global_position.y + rect.size.y / 2.0), 5, 1.0)
		level.camera.kick(Vector2(0, 20)))
	_cycle.tween_interval(0.2)
	_cycle.tween_property(self, "_y", top_y, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cycle.tween_callback(func():
		if not done:
			_start_cycle())

var stamp_up: bool:
	get: return _y <= top_y + (bottom_y - top_y) * 0.35

func tick(delta: float) -> void:
	_t += delta
	kappe(Vector2(100, rect.size.y / 2.0 - 130.0), not done and player_in_rect(rect), delta)
	_light.position.y = _y - 10.0
	_light.energy = (0.75 if stamp_up and not done else 0.3) + 0.1 * sin(_t * 5.0)
	queue_redraw()
	if done or not player_in_rect(rect):
		return
	if not _hint:
		_hint = true
		var h = param("hint", null)
		if h != null:
			say(Game.t(h))
	if Input.is_action_just_pressed("action"):
		if stamp_up:
			_succeed()
		else:
			Game.assist_fail("stamp")
			level.camera.kick(Vector2(12, 0))
			Sfx.play("deny", 1.4, -8.0)
			if Game.assist_fail_count("stamp") >= 2 and _t - _last_tip > 6.0:
				_last_tip = _t
				say(ltext("failHint", {"de": "Tipp: Warte, bis der Stempel OBEN kurz stehen bleibt — dann %s!" % Kiosk.label_action(),
					"en": "Tip: wait until the stamp rests at the TOP — then press the action!"}))

func _succeed() -> void:
	done = true
	if _cycle:
		_cycle.kill()
	player.controls_locked = true
	player.velocity.x = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_y", bottom_y, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Fx.hitstop(get_tree(), 0.09)
		level.camera.kick(Vector2(0, 70))
		Fx.sparkle(level, Vector2(global_position.x, global_position.y + rect.size.y / 2.0 - 20), Palette.GOLD, 26, 340.0)
		Fx.ring(level, Vector2(global_position.x, global_position.y + rect.size.y / 2.0 - 20), Palette.GOLD, 120.0)
		Fx.float_text(level, global_position + Vector2(0, -90), "SIGNIERT", Palette.GOLD, 36)
		if Game.assist_clean("stamp"):
			Game.add_security_bonus()
		player.visual.squash = Vector2(1.3, 0.7))
	tw.tween_interval(0.5)
	tw.tween_property(self, "_y", top_y, 0.4)
	tw.tween_callback(level.complete_level)

func _draw() -> void:
	var c := Palette.GOLD
	# Führung
	draw_rect(Rect2(-6, top_y - 40, 12, bottom_y - top_y + 60), Color(pal.metall.r, pal.metall.g, pal.metall.b, 0.7))
	# Podest unten
	draw_panel(Rect2(-60, rect.size.y / 2.0 - 12, 120, 12), pal.metall, pal.detail, 4)
	# Stempel
	var glow_amt := 1.2 if stamp_up and not done else 0.3
	draw_panel(Rect2(-14, _y - 60, 28, 40), pal.metall, pal.detail, 6)
	draw_panel(Rect2(-40, _y - 22, 80, 30), pal.fels, Color(c.r, c.g, c.b, 0.9), 8, glow_amt, 3)
	draw_string(ThemeDB.fallback_font, Vector2(-40, _y), "QES", HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Palette.glow(c, 1.4))
	if stamp_up and not done:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(Vector2(0, _y - 8), 50.0 + pulse * 6.0, 0, TAU, 32, Color(c.r, c.g, c.b, 0.35 + pulse * 0.3), 2.0, true)
