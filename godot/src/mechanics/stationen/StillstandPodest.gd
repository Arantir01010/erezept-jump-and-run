extends Mechanic
## STILLSTAND-PODEST (Baustein „stillstand-podest“) — Scan im Stillstand.

var scan_s := 1.2
var progress := 0.0
var disturb := 0.0
var done := false
var _hint := false
var _aborts := 0
var _last_tip := -100.0
var _t := 0.0
var _scanning := false
var _light: PointLight2D

func spawn() -> void:
	z_index = 4
	scan_s = float(param("scanMs", 1200)) / 1000.0
	_light = Fx.light(self, Vector2(0, -40), Palette.COOL, 170.0, 0.2)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(rect.size.x, 18.0)
	cs.shape = s
	cs.position = Vector2(0, -rect.size.y / 2.0 + 9.0)
	cs.one_way_collision = true
	body.add_child(cs)
	add_child(body)
	level.register_scroll_lock(func(): return not done and player.global_position.x > global_position.x - 500.0)
	var g = linked_gate()
	if g:
		g.open_hint = ltext("gateHint", {"de": "Das Tor prüft dich erst auf dem Podest: draufstellen, Joystick loslassen, Scan abwarten.",
			"en": "The gate checks you on the pedestal first: stand on it, release the stick, wait for the scan."})

func _on_podest() -> bool:
	var top := global_position.y - rect.size.y / 2.0
	return player.is_on_floor() and absf(player.global_position.y - top) < 6.0 and absf(player.global_position.x - global_position.x) < rect.size.x / 2.0 + 10.0

func tick(delta: float) -> void:
	_t += delta
	_light.color = Palette.OK if done else Palette.COOL
	_light.energy = move_toward(_light.energy, 0.8 if (_scanning or done) else 0.2, delta * 4.0)
	queue_redraw()
	if done:
		return
	var on := _on_podest()
	if on and not _hint:
		_hint = true
		var h = param("hint", null)
		if h != null:
			say(Game.t(h))
	var neutral := absf(Input.get_axis("move_left", "move_right")) < 0.2 and absf(player.velocity.x) < 20.0
	_scanning = on and neutral
	var slow := scan_s * Game.assist_slowdown("podest-" + str(rect.position.x))
	if _scanning:
		progress += delta
		disturb = 0.0
		if progress >= slow:
			_succeed()
	elif progress > 0.0:
		disturb += delta
		if disturb >= 0.22:
			progress = maxf(0.0, progress - delta)
			if progress == 0.0:
				_aborts += 1
				Game.assist_fail("podest-" + str(rect.position.x))
				if _aborts >= 2 and _t - _last_tip > 6.0:
					_last_tip = _t
					say(ltext("stillHint", {"de": "Tipp: Joystick ganz loslassen — der Scan läuft nur im Stillstand.",
						"en": "Tip: release the stick completely — the scan only runs while you stand still."}))

func _succeed() -> void:
	done = true
	if Game.assist_clean("podest-" + str(rect.position.x)):
		Game.add_security_bonus()
	var g = linked_gate()
	if g:
		g.open()
	Fx.ring(level, global_position, Palette.OK, 100.0)
	Fx.float_text(level, global_position + Vector2(0, -110), "Geprüft ✓", Palette.OK, 26)
	# Der Gag: Die Datenkrake hinter Paul bekommt das Tor vor die Nase
	get_tree().create_timer(0.8).timeout.connect(func():
		if g and is_inside_tree():
			Fx.deny_stamp(level, g.global_position + Vector2(-90, -120), ltext("denyText", {"de": "Zugriff verweigert", "en": "Access denied"})))

func _draw() -> void:
	var r := Rect2(-rect.size.x / 2.0, -rect.size.y / 2.0, rect.size.x, 18.0)
	var c := Palette.OK if done else (Palette.COOL if _scanning else pal.detail)
	draw_panel(r, pal.metall, c, 6, 0.8 if _scanning or done else 0.2)
	var frac := clampf(progress / maxf(scan_s * Game.assist_slowdown("podest-" + str(rect.position.x)), 0.01), 0.0, 1.0)
	# Scan-Balken über dem Podest
	var bar := Rect2(r.position.x + 8, r.position.y - 26, r.size.x - 16, 10)
	draw_rect(bar, Color(0, 0, 0, 0.5))
	draw_rect(bar, Color(c.r, c.g, c.b, 0.8), false, 1.5)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Palette.glow(c, 1.5))
	if _scanning and not done:
		var y := r.position.y - 90 + fmod(_t * 160.0, 90.0)
		draw_rect(Rect2(r.position.x, y, r.size.x, 3), Palette.glow(Color(c.r, c.g, c.b, 0.7), 1.6))
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y - 34), "Scan" if not done else "OK", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Palette.glow(c, 1.2))
