extends Mechanic
## ANDOCK-PLATTFORM (Baustein „andock-plattform“) — trägt nur Klartext oder VAU.

var body: StaticBody2D
var _cs: CollisionShape2D
var carries := true
var _hint := false
var _t := 0.0
var _fade := 1.0
var _light: PointLight2D

func spawn() -> void:
	z_index = 4
	_light = Fx.light(self, Vector2(0, -rect.size.y / 2.0), Palette.GOLD, rect.size.x * 0.9, 0.4)
	body = StaticBody2D.new()
	body.collision_layer = 1
	_cs = CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(rect.size.x, 18.0)
	_cs.shape = s
	_cs.position = Vector2(0, -rect.size.y / 2.0 + 9.0)
	_cs.one_way_collision = true
	body.add_child(_cs)
	add_child(body)

func tick(delta: float) -> void:
	_t += delta
	var soll := player.is_andockfaehig
	if soll != carries:
		carries = soll
		_cs.set_deferred("disabled", not soll)
		if not soll and not _hint and absf(player.global_position.x - global_position.x) < rect.size.x:
			_hint = true
			say(ltext("hint", {"de": "Diese Plattform trägt nur Klartext — kurz entschlüsseln und schnell sein!",
				"en": "This platform only carries plain text — decrypt briefly and be quick!"}))
	_fade = move_toward(_fade, 1.0 if carries else 0.25, delta * 4.0)
	_light.energy = 0.45 * _fade + 0.08 * sin(_t * 3.0)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(-rect.size.x / 2.0, -rect.size.y / 2.0, rect.size.x, 18.0)
	var c := Palette.GOLD
	draw_panel(r, pal.metall.lerp(c, 0.15 * _fade), Color(c.r, c.g, c.b, _fade), 6, _fade * 1.0)
	draw_rect(Rect2(r.position.x + 4, r.position.y - 2, r.size.x - 8, 3), Palette.glow(Color(c.r, c.g, c.b, _fade), 1.6))
	# Symbol: „Klartext" als offener Kreis
	var pulse := 0.6 + 0.4 * sin(_t * 3.0)
	draw_arc(Vector2(0, r.position.y - 14), 7.0, 0, TAU, 16, Color(c.r, c.g, c.b, _fade * pulse), 2.0, true)
	if not carries:
		for i in int(r.size.x / 16.0):
			draw_line(Vector2(r.position.x + i * 16, r.end.y), Vector2(r.position.x + i * 16 + 8, r.position.y), Color(c.r, c.g, c.b, 0.25), 1.5, true)
