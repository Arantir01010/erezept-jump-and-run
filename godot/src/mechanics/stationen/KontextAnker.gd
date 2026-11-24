extends Mechanic
## KONTEXT-ANKER (Baustein „kontext-anker“) — frischt die VAU-Sitzung auf.

var _last := -100.0
var _t := 0.0
var _pulse := 0.0
var _light: PointLight2D

func spawn() -> void:
	z_index = 5
	_light = Fx.light(self, Vector2.ZERO, Palette.VAU, 110.0, 0.5)
	make_sensor(Rect2(rect.position - Vector2(10, 10), rect.size + Vector2(20, 20)), _enter)

func _enter(p: Player) -> void:
	if not p.huelle.vau_expires:
		return
	if _t - _last < 0.4:
		return
	if not p.huelle.refresh_session():
		return
	_last = _t
	_pulse = 1.0
	Sfx.play("checkpoint", 1.3)
	Fx.ring(level, global_position, Palette.VAU, 60.0)
	var h = param("hint", null)
	if h != null:
		say(Game.t(h))
	Game.hud_changed.emit()

func tick(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 2.0)
	queue_redraw()

func _draw() -> void:
	var c := Palette.VAU
	var r := 14.0 + _pulse * 10.0
	draw_circle(Vector2.ZERO, r * 1.8, Color(c.r, c.g, c.b, 0.12))
	draw_arc(Vector2.ZERO, r, 0, TAU, 24, Palette.glow(c, 1.5), 3.0, true)
	# Schlüssel-Symbol
	draw_circle(Vector2(0, -4), 5.0, Palette.glow(c, 1.4))
	draw_rect(Rect2(-2, 0, 4, 12), Palette.glow(c, 1.4))
	draw_rect(Rect2(2, 6, 4, 3), Palette.glow(c, 1.4))
