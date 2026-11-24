extends Mechanic
## KRYPTO-DUSCHE (Baustein „krypto-dusche“) — Verschlüsselung anlegen.

var done := false
var _hint := false
var _t := 0.0
var _rain: CPUParticles2D
var _light: PointLight2D

func spawn() -> void:
	z_index = 5
	_light = Fx.light(self, Vector2(0, -rect.size.y / 2.0 + 30.0), Palette.COOL, 220.0, 0.5)
	level.register_scroll_lock(func(): return not done and player.global_position.x > global_position.x - 500.0)
	var g = linked_gate()
	if g:
		g.open_hint = ltext("gateHint", {"de": tr("Erst verschlüsseln: In der Krypto-Dusche %s drücken.") % Kiosk.label_action(),
			"en": "Encrypt first: press the action inside the crypto shower."})
	_rain = CPUParticles2D.new()
	_rain.amount = 40
	_rain.lifetime = 1.2
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(rect.size.x / 2.0 - 10, 4)
	_rain.position = Vector2(0, -rect.size.y / 2.0 + 10)
	_rain.direction = Vector2(0, 1)
	_rain.spread = 8.0
	_rain.initial_velocity_min = 120.0
	_rain.initial_velocity_max = 220.0
	_rain.gravity = Vector2(0, 80)
	_rain.scale_amount_min = 1.5
	_rain.scale_amount_max = 3.0
	_rain.color = Palette.glow(Palette.COOL, 1.4)
	_rain.emitting = true
	add_child(_rain)

func tick(delta: float) -> void:
	_t += delta
	kappe(Vector2(0, -rect.size.y / 2.0 - 52.0), not done and player_in_rect(rect), delta)
	queue_redraw()
	if done or not player_in_rect(rect):
		return
	if not _hint:
		_hint = true
		var h = param("hint", null)
		if h != null:
			say(Game.t(h))
	if Input.is_action_just_pressed("action"):
		done = true
		Game.encrypted = true
		rezi.set_encrypted(true)
		player.visual.flash = 1.0
		Sfx.play("toggle_on")
		Fx.ring(level, player.global_position + Vector2(0, -32), Palette.COOL, 140.0)
		Fx.sparkle(level, player.global_position + Vector2(0, -32), Palette.COOL, 30, 320.0)
		Fx.float_text(level, player.global_position + Vector2(0, -100), "VERSCHLÜSSELT", Palette.COOL, 30)
		_rain.emitting = false
		say(Game.t(data.station.get("reziText", "")), 3.5)
		var g = linked_gate()
		if g:
			g.open()
		Game.add_security_bonus()

func _draw() -> void:
	var r := local_rect()
	var c := Palette.COOL
	# Duschkopf oben
	draw_panel(Rect2(r.position.x + 6, r.position.y, r.size.x - 12, 22), pal.metall, c, 6, 0.6)
	for i in int((r.size.x - 20) / 14.0):
		draw_circle(Vector2(r.position.x + 16 + i * 14, r.position.y + 22), 2.0, Palette.glow(c, 1.3))
	# Zone
	var a := 0.05 + 0.03 * sin(_t * 2.0)
	draw_rect(Rect2(r.position.x + 6, r.position.y + 22, r.size.x - 12, r.size.y - 22), Color(c.r, c.g, c.b, a if not done else 0.02))
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y - 6), "KRYPTO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Palette.glow(c, 1.2))
