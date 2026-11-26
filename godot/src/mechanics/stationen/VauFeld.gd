extends Mechanic
## VAU-FELD (Baustein „vau-feld“) — Klartext-schnell UND unsichtbar; ttlMs = Kontextschlüssel.

const GITTER_SHADER := preload("res://src/shaders/vau_gitter.gdshader")
var ttl := 0.0
var inside := false
var _hint := false
var _t := 0.0
var _light: PointLight2D
var _ring_tex: GradientTexture2D
var _ring_ratio := -1.0
var _gitter: _Gitter
var _gitter_mat: ShaderMaterial
var _feld_sb: StyleBoxFlat
var _gezeichnet := ""

func spawn() -> void:
	z_index = 3
	ttl = float(param("ttlMs", 0)) / 1000.0
	make_sensor(rect, _enter, _exit)
	_light = Fx.light(self, Vector2.ZERO, Palette.VAU, maxf(rect.size.x, rect.size.y) * 0.9, 0.35)
	if ttl > 0.0:
		_ring_tex = _make_ring_texture()
	var c := Palette.VAU
	_feld_sb = StyleBoxFlat.new()
	_feld_sb.border_color = Palette.glow(Color(c.r, c.g, c.b, 0.9), 1.4)
	_feld_sb.set_border_width_all(2)
	_feld_sb.set_corner_radius_all(10)
	_feld_sb.anti_aliasing = true
	# Wabengitter: eigener Knoten, EINMAL gezeichnet; die Welle macht der Shader
	_gitter = _Gitter.new()
	_gitter.feld = local_rect()
	_gitter_mat = ShaderMaterial.new()
	_gitter_mat.shader = GITTER_SHADER
	_gitter.material = _gitter_mat
	add_child(_gitter)

## Sitzungsuhr: konische Füllung (GradientTexture2D.FILL_CONIC, Godot 4.7) —
## eine violette Scheibe, die im Uhrzeigersinn leerläuft. Start oben (12 Uhr).
static func _make_ring_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.set_color(0, Color(Palette.VAU.r, Palette.VAU.g, Palette.VAU.b, 0.42))
	g.set_color(1, Color(Palette.VAU.r, Palette.VAU.g, Palette.VAU.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_CONIC
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 48
	tex.height = 48
	return tex

## Restanteil in die konische Füllung schreiben (nur bei Änderung, in 1-%-Schritten).
func _set_ring_ratio(ratio: float) -> void:
	var q := snappedf(ratio, 0.01)
	if is_equal_approx(q, _ring_ratio):
		return
	_ring_ratio = q
	_ring_tex.gradient.set_offset(1, clampf(q, 0.001, 1.0))

func _enter(p: Player) -> void:
	if not p.huelle_enabled:
		return
	inside = true
	p.huelle.enter_vau(ttl)
	Fx.ring(level, p.global_position + Vector2(0, -32), Palette.VAU, 90.0)
	if not _hint:
		_hint = true
		say(ltext("hint", {"de": "VAU: Hier arbeitest du im Klartext — und trotzdem sieht dich niemand!",
			"en": "VAU: here you work in plain text — and still nobody can see you!"}))

func _exit(p: Player) -> void:
	if not p.huelle_enabled:
		return
	inside = false
	p.huelle.leave_vau()

func tick(delta: float) -> void:
	_t += delta
	_light.energy = (0.7 if inside else 0.35) + 0.06 * sin(_t * 2.5)
	if not visible:
		return
	_gitter_mat.set_shader_parameter("t", _t)
	# Neu zeichnen nur, wenn sich etwas ändert: drinnen/draußen, laufende Sitzungsuhr
	var draining := ttl > 0.0 and inside and player.huelle.vau_expires
	var stand := "%s|%s" % [inside, draining]
	if draining or stand != _gezeichnet:
		_gezeichnet = stand
		queue_redraw()

func _draw() -> void:
	var r := local_rect()
	var c := Palette.VAU
	_feld_sb.bg_color = Color(c.r, c.g, c.b, 0.22 if inside else 0.13)
	draw_style_box(_feld_sb, r)
	# Schild
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y - 8), "VAU", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Palette.glow(c, 1.3))
	# Sitzungsfrische: konischer Ring über dem Schild — voll, solange niemand drin
	# ist; läuft ab, sobald Paul in der VAU arbeitet (Sitzung mit frischen Schlüsseln).
	if ttl > 0.0:
		var draining := inside and player.huelle.vau_expires
		var ratio := player.huelle.vau_ratio if draining else 1.0
		var center := Vector2(r.get_center().x, r.position.y - 50)
		var alpha := 1.0 if draining else 0.55
		var warn := draining and ratio < 0.3
		# Grundscheibe und Restring (unter 30 %: rot, langsam pulsierend — 2 Hz)
		draw_circle(center, 20.0, Color(0.067, 0.067, 0.075, 0.40 * alpha))
		var back := Color(0.067, 0.067, 0.075, 0.55)
		if warn:
			back = Color(Palette.DENY.r, Palette.DENY.g, Palette.DENY.b, 0.3 + 0.15 * sin(_t * TAU * 2.0))
		draw_arc(center, 17.0, 0, TAU, 40, back, 5.0, true)
		if _ring_tex:
			_set_ring_ratio(ratio)
			draw_texture_rect(_ring_tex, Rect2(center - Vector2(16, 16), Vector2(32, 32)), false, Color(1, 1, 1, alpha))
		if ratio > 0.005:
			var a0 := -PI / 2.0
			draw_arc(center, 17.0, a0, a0 + TAU * ratio, maxi(4, int(40 * ratio) + 2), Palette.glow(Color(c.r, c.g, c.b, alpha), 1.4), 5.0, true)
		# Marke in der Mitte: die Sitzung
		draw_circle(center, 3.5, Palette.glow(Color(c.r, c.g, c.b, alpha), 1.3))

## Das Wabengitter als EINE Linienliste (draw_multiline) — gezeichnet beim
## Erzeugen, danach nie wieder; Helligkeitswelle im Shader (vau_gitter.gdshader).
class _Gitter extends Node2D:
	var feld := Rect2()

	func _draw() -> void:
		var c := Palette.VAU
		var punkte := PackedVector2Array()
		var ecken: Array[Vector2] = []
		for k in 6:
			ecken.append(Vector2(6, 0).rotated(k * PI / 3.0 + PI / 6.0))
		var y := feld.position.y + 14
		var row := 0
		while y < feld.end.y - 8:
			var x := feld.position.x + 14 + (10 if row % 2 else 0)
			while x < feld.end.x - 8:
				var m := Vector2(x, y)
				for k in 6:
					punkte.append(m + ecken[k])
					punkte.append(m + ecken[(k + 1) % 6])
				x += 20
			y += 18
			row += 1
		if punkte.size() > 0:
			draw_multiline(punkte, Color(c.r, c.g, c.b, 1.0), 1.0, true)
