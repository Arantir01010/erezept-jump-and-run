class_name GameCamera
extends Camera2D
## KAMERA — vorausschauend in Laufrichtung, weich, mit vertikaler Totzone.
## Der häufigste Grund für unfaire Treffer ist eine Kamera, die den Spieler
## mittig festhält; hier verschiebt sie sich in Blickrichtung. „Kick" nur bei
## großen Momenten, nie im Sekundentakt.

var target: Node2D
var lookahead := 210.0
var manual := false
var base_zoom := 1.2
var _look := 0.0
var _kick := Vector2.ZERO
var _kick_vel := Vector2.ZERO
var _pos := Vector2.ZERO
var _y_goal := 0.0
var _zoom_extra := 0.0


func setup(t: Node2D, world_w: float, world_h: float) -> void:
	target = t
	limit_left = 0
	limit_top = 0
	limit_right = int(world_w)
	limit_bottom = int(world_h)
	position_smoothing_enabled = false
	# Etwas näher dran: Paul bekommt Präsenz, das Bild wirkt weniger leer.
	zoom = Vector2(base_zoom, base_zoom)
	_pos = t.global_position + Vector2(0, -120)
	_y_goal = _pos.y
	global_position = _pos
	make_current()


func kick(v: Vector2) -> void:
	_kick_vel += v


## Zoom-Stoß für große Momente (Siegel): kurz näher ran, weich zurück.
func punch(amount: float) -> void:
	_zoom_extra = maxf(_zoom_extra, amount)


func _process(delta: float) -> void:
	_zoom_extra = lerpf(_zoom_extra, 0.0, 1.0 - exp(-3.5 * delta))
	zoom = Vector2.ONE * base_zoom * (1.0 + _zoom_extra)
	if manual or target == null:
		return
	var vx := 0.0
	var on_floor := true
	var body := target as CharacterBody2D
	if body:
		vx = body.velocity.x
		on_floor = body.is_on_floor()
	var want := clampf(vx / Player.T.run_speed, -1.0, 1.0) * lookahead
	_look = lerpf(_look, want, 1.0 - exp(-2.4 * delta))
	var goal := target.global_position + Vector2(_look, -140.0)
	# vertikal: Totzone, damit kleine Sprünge das Bild nicht schaukeln
	var dy := goal.y - _y_goal
	if absf(dy) > 110.0:
		_y_goal += dy - signf(dy) * 110.0
	var ky := 6.0 if on_floor else 3.2
	_pos.x = lerpf(_pos.x, goal.x, 1.0 - exp(-7.0 * delta))
	_pos.y = lerpf(_pos.y, _y_goal, 1.0 - exp(-ky * delta))
	# Kick: gedämpfte Feder
	_kick_vel += -_kick * 300.0 * delta
	_kick_vel *= exp(-9.0 * delta)
	_kick += _kick_vel * delta
	global_position = (_pos + _kick).round()
