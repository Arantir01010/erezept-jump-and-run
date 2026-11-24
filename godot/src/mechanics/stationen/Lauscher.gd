extends Mechanic
## LAUSCHER (Baustein „lauscher“) — sieht NUR Klartext (Hülle-Kernmechanik).

var base_x := 0.0
var patrol_to := 0.0
var speed := 90.0
var reach := 330.0
var spread := 66.0
var pause := 0.6
var dir := 1
var _t := 0.0
var _seen := false
var _last_hit := -100.0
var _hits := 0
var _last_tip := -100.0
var _blink := 0.0
var _blink_timer := 2.0
var _eye := Vector2.ZERO
var _cone_light: PointLight2D
## 1 = Paul ist im Klartext (lesbar): Kegel warm mit Kontur — 0 = verschlüsselt
## oder in der VAU: Kegel blass und neutral, der Lauscher scheitert (Feedback 9/2026:
## „Gefahren schlecht zu sehen"). Weicher Übergang, kein Blinken.
var _warn := 1.0
const NEUTRAL := Color(0.74, 0.78, 0.86)
static var _sclera_sb: StyleBoxFlat

func spawn() -> void:
	z_index = 6
	base_x = position.x
	speed = float(param("speed", 30)) * 3.0
	reach = float(param("reach", 110)) * 3.0
	spread = float(param("spread", 22)) * 3.0
	pause = float(param("pauseMs", 600)) / 1000.0
	patrol_to = base_x + float(param("patrol", 0)) * 3.0
	draw_reach = Vector2(reach + 40.0, spread + 40.0)
	_t = randf() * 3.0
	# Der Blick als echtes Licht: Kegeltextur, in Blickrichtung gedreht
	_cone_light = PointLight2D.new()
	_cone_light.texture = Fx.cone_texture()
	_cone_light.offset = Vector2(128.0 - 24.0, 0)
	_cone_light.texture_scale = reach / 232.0
	_cone_light.color = Palette.WARM
	_cone_light.energy = 0.7
	_cone_light.range_item_cull_mask = 1
	_cone_light.shadow_enabled = true
	_cone_light.shadow_color = pal.shadow_for_light(0.6)
	_cone_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	add_child(_cone_light)

func tick(delta: float) -> void:
	_t += delta
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.12
		_blink_timer = randf_range(1.5, 4.0)
	_blink = maxf(0.0, _blink - delta)
	if absf(patrol_to - base_x) >= 1.0:
		var p := _patrol(_t)
		position.x = p[0]
		dir = p[1]
	var target := player.global_position + Vector2(0, -30)
	var gesehen := _sees(target)
	if gesehen and not _seen:
		rezi.scared()
	_seen = gesehen
	_eye = _eye.lerp(((target - global_position).normalized() * 5.0) if gesehen else Vector2(dir * 3.0, 0), 1.0 - exp(-8 * delta))
	if gesehen and _t - _last_hit >= 0.9:
		_last_hit = _t
		_erwischt()
	_warn = move_toward(_warn, 1.0 if player.is_sichtbar else 0.0, delta * 4.0)
	_cone_light.scale = Vector2(float(dir), 1.0)
	_cone_light.color = Palette.DENY if gesehen else NEUTRAL.lerp(Palette.WARM, _warn)
	_cone_light.energy = (1.1 if gesehen else lerpf(0.3, 0.7, _warn)) + 0.08 * sin(_t * 7.0)
	queue_redraw()

## Patrouille als reine Funktion der Zeit (deterministisch, lernbar).
func _patrol(t: float) -> Array:
	var span := absf(patrol_to - base_x)
	var travel := span / maxf(speed, 1.0)
	var leg := travel + pause
	var cycle := leg * 2.0
	var tt := fmod(t, cycle)
	var forward := tt < leg
	var local := tt if forward else tt - leg
	var prog := minf(1.0, local / travel)
	var a := base_x if forward else patrol_to
	var b := patrol_to if forward else base_x
	return [a + (b - a) * prog, 1 if b >= a else -1]

func _in_cone(p: Vector2) -> bool:
	var dx := (p.x - global_position.x) * dir
	if dx < 0.0 or dx > reach:
		return false
	var ratio := dx / reach
	var half := maxf(6.0, spread * ratio)
	return absf(p.y - global_position.y) <= half

func _sees(p: Vector2) -> bool:
	if not player.is_sichtbar:
		return false
	if not _in_cone(p):
		return false
	# Sichtlinie durch Gelände blockiert?
	var d := global_position.distance_to(p)
	var n := maxi(1, int(d / 14.0))
	for i in range(1, n):
		var s := global_position.lerp(p, float(i) / n)
		for r in level.terrain.rects:
			if r["ch"] != "|" and (r["rect"] as Rect2).has_point(s):
				return false
	return true

func _erwischt() -> void:
	var lost := player.hurt(global_position.x)
	Game.mark_seen(data.id, ltext("akteur", {"de": "Lauscher", "en": "Eavesdropper"}))
	Fx.deny_stamp(level, global_position + Vector2(0, -60), ltext("seenText", {"de": "MITGELESEN!", "en": "READ!"}))
	if lost <= 0:
		return
	Fx.float_text(level, player.global_position + Vector2(0, -90), tr("−%d Bits") % lost, Palette.DENY, 22)
	_hits += 1
	if _hits >= 2 and _t - _last_tip > 6.0:
		_last_tip = _t
		say(ltext("huelleHint", {"de": "Tipp: %s = verschlüsseln — dann kann dich niemand mitlesen!" % Kiosk.label_toggle(),
			"en": "Tip: encrypt — then nobody can read you!"}))

func _draw() -> void:
	# Sichtkegel: gestaffeltes Volumen. Klartext: warm und dichter, mit Kontur an
	# den Rändern; verschlüsselt/VAU: blass und neutral; beim Erfassen rot
	var c := Palette.DENY if _seen else NEUTRAL.lerp(Palette.WARM, _warn)
	var base_a := 0.30 if _seen else lerpf(0.06, 0.17, _warn)
	for k in 3:
		var frac := 1.0 - k * 0.28
		var pts := PackedVector2Array([Vector2.ZERO, Vector2(dir * reach * frac, -spread * frac), Vector2(dir * reach * frac, spread * frac)])
		draw_colored_polygon(pts, Color(c.r, c.g, c.b, base_a * (0.5 + k * 0.25)))
	var kontur := 0.7 if _seen else 0.6 * _warn
	if kontur > 0.01:
		for s in [-1.0, 1.0]:
			draw_line(Vector2(dir * 26.0, s * spread * 26.0 / reach), Vector2(dir * reach, s * spread),
				Color(c.r, c.g, c.b, kontur), 3.0, true)
		draw_line(Vector2(dir * reach, -spread), Vector2(dir * reach, spread), Color(c.r, c.g, c.b, kontur * 0.45), 2.0, true)
	# Scan-Linien im Kegel
	var scan_a := 0.35 if _seen else lerpf(0.12, 0.4, _warn)
	for i in 4:
		var f := fmod(_t * 0.5 + i * 0.25, 1.0)
		var x := dir * reach * f
		draw_line(Vector2(x, -spread * f), Vector2(x, spread * f), Color(c.r, c.g, c.b, (1.0 - f) * scan_a), 2.0, true)
	# Das Auge
	draw_circle(Vector2.ZERO, 30.0, Color(c.r, c.g, c.b, 0.15))
	draw_circle(Vector2.ZERO, 22.0, Color(0.12, 0.09, 0.14))
	var open := 0.12 if _blink > 0.0 else 1.0
	var sclera := Rect2(-18, -12 * open, 36, 24 * open)
	if _sclera_sb == null:
		_sclera_sb = StyleBoxFlat.new()
		_sclera_sb.bg_color = Color(0.97, 0.95, 0.92)
		_sclera_sb.set_corner_radius_all(12)
		_sclera_sb.anti_aliasing = true
	draw_style_box(_sclera_sb, sclera)
	if open > 0.5:
		draw_circle(_eye, 8.0, Palette.glow(c, 1.4))
		draw_circle(_eye, 4.0, Color(0.05, 0.04, 0.06))
		draw_circle(_eye + Vector2(-2, -2), 1.5, Color(1, 1, 1, 0.9))
	# Antenne
	draw_line(Vector2(0, -22), Vector2(0, -36), Color(0.3, 0.25, 0.32), 3.0, true)
	draw_circle(Vector2(0, -38), 4.0, Palette.glow(c, 1.6 if _seen else 1.0))
