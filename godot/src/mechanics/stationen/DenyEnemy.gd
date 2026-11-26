extends Mechanic
## SKIMMING-KRALLE (Baustein „deny-enemy“) — die TI blockt sie.

var from_right := true
var reach := 126.0
var grabs := 0
var grabs_before_block := 2
var blocked := false
var grabbing := false
var started := false
var activation := 660.0
var idle := 1.3
var _claw_x := 0.0
var _open := true
var _hits := 0
var _last_tip := -100.0
var _blende_y := -1000.0
var _t := 0.0
var _shake := 0.0
var _light: PointLight2D

func spawn() -> void:
	z_index = 6
	from_right = bool(param("fromRight", true))
	reach = float(param("reach", 40)) * 3.0
	grabs_before_block = int(param("grabsBeforeBlock", 2))
	activation = float(param("activationRange", 220)) * 3.0
	idle = float(param("idleMs", 1300)) / 1000.0
	_light = Fx.light(self, Vector2.ZERO, Palette.DENY, 90.0, 0.3)

var _dir: float:
	get: return -1.0 if from_right else 1.0

func tick(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 6.0)
	_light.position.x = _claw_x
	_light.color = Palette.OK if blocked else Palette.DENY
	_light.energy = (0.6 if grabbing else 0.25) + _shake * 0.4
	if not started and not blocked and absf(player.global_position.x - global_position.x) <= activation:
		started = true
		_schedule()
	# Treffer nur beim Zugriff — geduckt greift die Kralle über den Kopf
	if grabbing and not blocked:
		var claw := Rect2(global_position.x + _claw_x - 30, global_position.y - 9, 60, 18)
		var head := player.global_position + Vector2(0, -(Player.T.duck_h if player.is_ducking else Player.T.body_h) + 6)
		var body := Rect2(player.global_position.x - 15, head.y, 30, player.global_position.y - head.y)
		if claw.intersects(body):
			var was_vulnerable := not player.is_invulnerable
			player.hurt(global_position.x)
			if was_vulnerable:
				_hits += 1
				if _hits >= 2 and _t - _last_tip > 7.0:
					_last_tip = _t
					say(ltext("duckHint", {"de": "Tipp: Nach unten drücken zum Ducken — die Kralle greift über dich hinweg!",
						"en": "Tip: press down to duck — the claw grabs right over you!"}))
	queue_redraw()

func _schedule() -> void:
	if blocked:
		return
	get_tree().create_timer(idle).timeout.connect(_telegraph)

func _telegraph() -> void:
	if blocked or not is_inside_tree():
		return
	_shake = 1.0
	Sfx.play("tick", 0.6, -4.0)
	get_tree().create_timer(0.45).timeout.connect(_extend)

func _extend() -> void:
	if blocked or not is_inside_tree():
		return
	grabbing = true
	_open = true
	var tw := create_tween()
	tw.tween_property(self, "_claw_x", _dir * reach, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_open = false
		grabs += 1)
	tw.tween_interval(0.22)
	tw.tween_callback(_retract)

func _retract() -> void:
	grabbing = false
	var tw := create_tween()
	tw.tween_property(self, "_claw_x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if grabs >= grabs_before_block:
			_block()
		else:
			_schedule())

## Der Payoff: Die zugelassene Hardware sperrt den Fremdleser aus.
func _block() -> void:
	blocked = true
	grabbing = false
	_blende_y = -240.0
	var tw := create_tween()
	tw.tween_property(self, "_blende_y", -6.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_open = false
		Fx.deny_stamp(level, global_position + Vector2(_dir * 40, -70), ltext("denyText", {"de": "Zugriff verweigert", "en": "Access denied"}))
		level.camera.kick(Vector2(0, 30))
		Fx.dust(level, global_position, 6, 1.2))

func _draw() -> void:
	var sx := sin(_t * 70.0) * 3.0 * _shake
	var c := Color(0.471, 0.494, 0.541) if not blocked else Color(0.471, 0.494, 0.541)
	# Arm (Teleskop)
	draw_line(Vector2(-_dir * 20 + sx, 0), Vector2(_claw_x + sx, 0), c.darkened(0.2), 12.0, true)
	draw_line(Vector2(-_dir * 20 + sx, 0), Vector2(_claw_x * 0.6 + sx, 0), c, 16.0, true)
	# Kralle
	var kx := _claw_x + sx
	var spread := 18.0 if _open else 6.0
	draw_circle(Vector2(kx, 0), 12.0, c)
	draw_line(Vector2(kx, 0), Vector2(kx + _dir * 22, -spread), c, 6.0, true)
	draw_line(Vector2(kx, 0), Vector2(kx + _dir * 22, spread), c, 6.0, true)
	draw_circle(Vector2(kx + _dir * 22, -spread), 3.5, Palette.DENY if not blocked else c)
	draw_circle(Vector2(kx + _dir * 22, spread), 3.5, Palette.DENY if not blocked else c)
	# Fake-Leser-Gehäuse
	draw_panel(Rect2(-_dir * 20 - 22 + sx, -22, 44, 44), Color(0.188, 0.196, 0.212), c, 6)
	draw_rect(Rect2(-_dir * 20 - 12 + sx, -6, 24, 4), Palette.DENY if not blocked else Color(0.298, 0.314, 0.337))
	# gematik-Siegel-Blende: fährt herunter und klemmt die Kralle ein
	if _blende_y > -900.0:
		var b := Rect2(-_dir * 20 - 34, _blende_y - 60, 68, 60)
		draw_panel(b, Color(0.004, 0.129, 0.086), Palette.OK, 6, 0.8, 3)
		draw_string(ThemeDB.fallback_font, Vector2(b.position.x, b.position.y + 26), "Zugelassen", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 12, Palette.glow(Palette.OK, 1.3))
		draw_arc(Vector2(b.get_center().x, b.position.y + 42), 9.0, 0, TAU, 16, Palette.glow(Palette.OK, 1.4), 2.0, true)
		draw_line(Vector2(b.get_center().x - 5, b.position.y + 42), Vector2(b.get_center().x - 1, b.position.y + 46), Palette.OK, 2.0, true)
		draw_line(Vector2(b.get_center().x - 1, b.position.y + 46), Vector2(b.get_center().x + 6, b.position.y + 38), Palette.OK, 2.0, true)
