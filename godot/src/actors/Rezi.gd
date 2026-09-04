class_name Rezi
extends Node2D
## REZI — das e-Rezept als Begleiter. Schwebt federnd hinter Paul, leuchtet
## (Leitlicht der Szene), spricht die Lernsätze und trägt die Siegel sichtbar.
## Beim REZI-Schub (Doppelsprung) macht REZI einen Schwung unter Paul hindurch.
##
## Ausdruck (ruhig — REZI ist Licht und Begleiter, kein Feuerwerk):
##   • Squash beim Swoop, Streckung entlang der Flugrichtung, leichtes Banken
##   • Augen schauen zu Paul (und ein wenig in die eigene Bewegungsrichtung)
##   • Antenne als Feder: wippt gegen die Bewegung, hängt beim Schreck
##   • Freude: Lach-Augen, Hüpfer, hellere Antenne · Schreck: weite Augen, „o",
##     ein einziger Rückzucker (kein Zittern)
##   • Datenspur: Funken plus ein weiches Lichtband aus den letzten Positionen,
##     das nur bei Tempo Länge und Deckkraft bekommt (in _draw, hinter dem Körper)
## Partikel bleiben CPUParticles2D (läuft im Web-Build ohne Sonderfall).

var target: Node2D
var seals: Array[String] = []
var encrypted := false
var mood := 0.0        # >0 = fröhlich (hüpft), <0 = erschrocken
var light: PointLight2D
var trail: CPUParticles2D
var bubble: PanelContainer
var base_energy := 0.6
var bubble_label: Label
var _vel := Vector2.ZERO
var _bob := 0.0
var _blink := 0.0
var _blink_timer := 3.0
var _bubble_until := 0.0
var _look := Vector2.ZERO
var _swoop := 0.0
var _color := Palette.COOL
var _sq := Vector2.ONE       # Impuls-Squash (Swoop, Schreck, Freude)
var _stretch := Vector2.ONE  # Streckung aus dem Tempo
var _tilt := 0.0             # Banken in Flugrichtung
var _ant := 0.0              # Antennenwinkel (Feder)
var _ant_v := 0.0
var _ribbon_a := 0.0
var _ribbon_pts := PackedVector2Array()  # Weltpositionen, neueste zuerst


func _ready() -> void:
	z_index = 12
	# Leitlicht der Szene — wirft weiche Schatten von Plattformen und Wänden
	light = Fx.light(self, Vector2.ZERO, Color(0.75, 0.92, 1.0), 720.0, 1.05, true)
	# Datenspur: kleine Funken hinter REZI, sobald sie sich bewegt (etwas dichter als früher)
	trail = CPUParticles2D.new()
	trail.amount = 40
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.spread = 25.0
	trail.direction = Vector2(-1, 0)
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 40.0
	trail.gravity = Vector2(0, -30)
	trail.scale_amount_min = 1.5
	trail.scale_amount_max = 3.5
	trail.color = Palette.glow(Color(0.55, 0.9, 1.0, 0.7), 1.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.9, 1.0, 0.7))
	ramp.set_color(1, Color(0.55, 0.9, 1.0, 0.0))
	trail.color_ramp = ramp
	trail.emitting = false
	trail.z_index = -1
	add_child(trail)
	# Sprechblase (Control im Weltraum, oberhalb von REZI)
	bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.13, 0.86)
	sb.border_color = Color(0.55, 0.85, 1.0, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("panel", sb)
	bubble_label = Label.new()
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.custom_minimum_size = Vector2(300, 0)
	bubble_label.add_theme_font_size_override("font_size", 22)
	bubble_label.add_theme_color_override("font_color", Palette.WHITE)
	bubble.add_child(bubble_label)
	bubble.visible = false
	bubble.z_index = 60
	add_child(bubble)


static func _radial_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func follow(t: Node2D) -> void:
	target = t
	if t:
		global_position = t.global_position + Vector2(-40, -80)
	_ribbon_pts = PackedVector2Array()


func _process(delta: float) -> void:
	_bob += delta
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.12
		_blink_timer = randf_range(2.5, 5.0)
	_blink = maxf(0.0, _blink - delta)
	mood = move_toward(mood, 0.0, delta * 1.4)
	_swoop = maxf(0.0, _swoop - delta * 2.4)
	_sq = _sq.lerp(Vector2.ONE, 1.0 - exp(-9.0 * delta))
	var facing: float = 1.0
	if target:
		if target is Player:
			facing = float((target as Player).facing)
		var goal: Vector2 = target.global_position + Vector2(-facing * 52.0, -92.0 + sin(_bob * 2.6) * 6.0)
		if _swoop > 0.0:
			goal = target.global_position + Vector2(0, 26.0 - 80.0 * (1.0 - _swoop))
		# Federung: weiches Nachziehen mit etwas Überschwingen
		var to := goal - global_position
		_vel += to * 34.0 * delta
		_vel *= exp(-7.5 * delta)
		global_position += _vel * delta
		# Blick: vor allem zu Paul (Kopfhöhe), ein wenig in die eigene Flugrichtung
		var to_paul := target.global_position + Vector2(0, -40.0) - global_position
		var look_paul := Vector2(clampf(to_paul.x / 90.0, -1, 1), clampf(to_paul.y / 90.0, -1, 1))
		var look_move := Vector2(clampf(to.x / 80.0, -1, 1), clampf(to.y / 80.0, -1, 1))
		var look_goal := look_paul * 0.65 + look_move * 0.35
		_look = _look.lerp(look_goal, 1.0 - exp(-6 * delta))
		trail.emitting = _vel.length() > 120.0
		# Licht atmet leicht und flackert beim Schub
		light.energy = base_energy + 0.06 * sin(_bob * 3.0) + _swoop * 0.6 + maxf(mood, 0.0) * 0.3
	# Tempo → Streckung entlang der Bewegung und leichtes Banken
	var sp := _vel.length()
	var s := clampf((sp - 150.0) / 1100.0, 0.0, 0.2)
	var n := _vel / maxf(sp, 1.0)
	var st_goal := Vector2(1.0 + s * absf(n.x) - s * 0.5 * absf(n.y), 1.0 + s * absf(n.y) - s * 0.5 * absf(n.x))
	_stretch = _stretch.lerp(st_goal, 1.0 - exp(-10.0 * delta))
	_tilt = lerpf(_tilt, clampf(_vel.x / 900.0, -1.0, 1.0) * 0.22, 1.0 - exp(-8.0 * delta))
	# Antenne: Feder, die gegen die Bewegung wippt; hängt beim Schreck, steht bei Freude
	var ant_goal := clampf(-_vel.x / 700.0, -1.0, 1.0) * 0.8 + sin(_bob * 2.6) * 0.05
	if mood < -0.3:
		ant_goal += -facing * 0.5 * minf(1.0, -mood)
	_ant_v += (ant_goal - _ant) * 140.0 * delta
	_ant_v *= exp(-9.0 * delta)
	_ant += _ant_v * delta
	# Lichtband: neueste Position vorn; ohne Tempo fallen die Punkte zusammen
	_ribbon_pts.insert(0, global_position)
	while _ribbon_pts.size() > 12:
		_ribbon_pts.remove_at(_ribbon_pts.size() - 1)
	_ribbon_a = lerpf(_ribbon_a, clampf((sp - 160.0) / 320.0, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	if bubble.visible:
		bubble.position = Vector2(-bubble.size.x * 0.5 + 10.0, -bubble.size.y - 48.0)
		if Time.get_ticks_msec() / 1000.0 > _bubble_until:
			var tw := create_tween()
			tw.tween_property(bubble, "modulate:a", 0.0, 0.25)
			tw.tween_callback(func(): bubble.visible = false)
			_bubble_until = INF
	queue_redraw()


func say(text: String, hold := 3.0) -> void:
	bubble_label.text = text
	bubble.visible = true
	bubble.modulate.a = 1.0
	bubble.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_until = Time.get_ticks_msec() / 1000.0 + hold
	Sfx.play("ui", 1.1, -8.0)


func add_seal(seal_id: String) -> void:
	seals.append(seal_id)
	mood = 1.5
	_sq = Vector2(1.14, 0.88)


func set_encrypted(on: bool) -> void:
	encrypted = on
	_color = Palette.COOL if not on else Color(0.62, 0.95, 1.0)


func swoop() -> void:
	_swoop = 1.0
	mood = 0.8
	# Anlauf-Squash: breit und flach, federt in der Bewegung wieder aus
	_sq = Vector2(1.28, 0.76)


func happy() -> void:
	mood = maxf(mood, 0.8)
	_sq = Vector2(1.1, 0.9)


func scared() -> void:
	mood = minf(mood, -0.8)
	# Ein einziger Rückzucker: schmal und lang, kleiner Satz nach hinten-oben
	_sq = Vector2(0.84, 1.18)
	var away := 1.0
	if target is Player:
		away = -float((target as Player).facing)
	_vel += Vector2(away * 220.0, -260.0)


func _draw() -> void:
	var s := 1.0 + maxf(mood, 0.0) * 0.12 * absf(sin(_bob * 9.0))
	var squeeze := 1.0 + minf(mood, 0.0) * 0.15
	var w := 40.0 * s * (1.0 / squeeze)
	var h := 44.0 * s * squeeze
	var body := Rect2(-w / 2.0, -h / 2.0, w, h)
	# Lichtband hinter dem Körper: breit und zart plus schmaler Kern, läuft nach hinten aus
	if _ribbon_a > 0.02 and _ribbon_pts.size() >= 2:
		var n := _ribbon_pts.size()
		var loc := PackedVector2Array()
		var soft := PackedColorArray()
		var core := PackedColorArray()
		for i in n:
			loc.append(_ribbon_pts[i] - global_position)
			var k := 1.0 - float(i) / float(n - 1)
			soft.append(Color(_color.r, _color.g, _color.b, 0.18 * k * _ribbon_a))
			core.append(Color(0.86, 0.97, 1.0, 0.30 * k * _ribbon_a))
		draw_polyline_colors(loc, soft, 12.0, true)
		draw_polyline_colors(loc, core, 4.0, true)
	# Squash/Stretch und Banken gelten für den ganzen Körper
	draw_set_transform(Vector2.ZERO, _tilt, _sq * _stretch)
	# Leuchtender Hof (die eine echte Lichtquelle im Bild)
	draw_circle(Vector2.ZERO, w * 0.9, Color(_color.r, _color.g, _color.b, 0.12))
	# Antenne hinter dem Körper: Stab mit leuchtender Spitze, wippt als Feder
	var ant_base := Vector2(0.0, -h / 2.0 + 2.0)
	var ant_dir := Vector2(sin(_ant), -cos(_ant))
	var ant_tip := ant_base + ant_dir * 13.0
	draw_line(ant_base, ant_tip, Color(0.12, 0.20, 0.27), 4.5, true)
	draw_line(ant_base, ant_tip, Color(0.86, 0.97, 1.0), 2.0, true)
	draw_circle(ant_tip, 4.2, Color(0.12, 0.20, 0.27))
	draw_circle(ant_tip, 3.0, Palette.glow(_color, 1.5 + maxf(mood, 0.0) * 0.4))
	# Körper: helle Kapsel mit dunkler Kontur und leuchtendem Innenrand
	var ob := StyleBoxFlat.new()
	ob.bg_color = Color(0.12, 0.20, 0.27)
	ob.set_corner_radius_all(15)
	ob.anti_aliasing = true
	draw_style_box(ob, Rect2(body.position - Vector2(3, 3), body.size + Vector2(6, 6)))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.97, 1.0)
	sb.set_corner_radius_all(13)
	sb.border_color = Palette.glow(_color, 1.5)
	sb.set_border_width_all(3)
	sb.anti_aliasing = true
	draw_style_box(sb, body)
	# Schattenseite (Licht von oben links)
	draw_rect(Rect2(body.position.x + body.size.x * 0.55, body.position.y + 4, body.size.x * 0.45 - 4, body.size.y - 8), Color(0.55, 0.78, 0.88, 0.35))
	# Verschlüsselt: Hex-Muster statt Klartext
	if encrypted:
		for i in 3:
			for j in 3:
				var p := Vector2(-11 + i * 11, -13 + j * 11)
				_hex(p, 3.5, Color(_color.r, _color.g, _color.b, 0.35))
	# Rezept-Zettel statt Kreuz (KAPSEL: kein rotes Kreuz — geschütztes Zeichen):
	# ein kleines Dokument mit Kopfzeile in Rezept-Rosa und drei Textzeilen
	var cx := 0.0
	var cy := 8.0
	var blatt := Rect2(cx - 7.0, cy - 8.5, 14.0, 17.0)
	var sbz := StyleBoxFlat.new()
	sbz.bg_color = Color(0.99, 0.98, 0.96)
	sbz.set_corner_radius_all(2)
	sbz.border_color = Color(0.55, 0.62, 0.72, 0.9)
	sbz.set_border_width_all(1)
	sbz.anti_aliasing = true
	draw_style_box(sbz, blatt)
	draw_rect(Rect2(cx - 5.5, cy - 7.0, 11.0, 3.2), Color(0.93, 0.45, 0.55))
	for i in 3:
		draw_rect(Rect2(cx - 5.0, cy - 2.2 + i * 3.0, 10.0 - (3.0 if i == 2 else 0.0), 1.4), Color(0.45, 0.52, 0.62))
	# Augen (schauen zu Paul), Freude = Lach-Augen, Schreck = weit offen
	var ex := _look.x * 3.0
	var ey := -8.0 + _look.y * 2.0
	var open := 0.15 if _blink > 0.0 else 1.0
	var ink := Color(0.12, 0.16, 0.24)
	var joy := mood > 0.3
	var fear := mood < -0.3
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 9.0 + ex, ey)
		if joy and open > 0.5:
			# Lach-Augen: Bögen nach oben
			draw_arc(c + Vector2(0, 2.5), 4.5, 1.15 * PI, 1.85 * PI, 10, ink, 2.5, true)
		elif fear and open > 0.5:
			draw_rect(Rect2(c.x - 5.0, c.y - 6.5, 10.0, 13.0), ink)
			draw_circle(c + Vector2(-1.0, -1.0), 2.4, Color(1, 1, 1, 0.95))
		else:
			draw_rect(Rect2(c.x - 4.0, c.y - 5.0 * open, 8.0, 10.0 * open), ink)
			if open > 0.5:
				draw_circle(c + Vector2(-1.2, -1.5), 1.6, Color(1, 1, 1, 0.9))
	if joy:
		draw_arc(Vector2(ex * 0.5, 0.0), 6.0, 0.15 * PI, 0.85 * PI, 10, ink, 2.0, true)
	elif fear:
		draw_circle(Vector2(ex * 0.5, 1.5), 2.6, ink)
	else:
		draw_line(Vector2(ex * 0.5 - 3.0, 0.5), Vector2(ex * 0.5 + 3.0, 0.5), ink, 2.0, true)
	# Siegel als kleine goldene Marken unter dem Körper
	for i in seals.size():
		var p := Vector2(-(seals.size() - 1) * 6.0 + i * 12.0, h / 2.0 + 8.0)
		draw_circle(p, 5.0, Color(0.12, 0.16, 0.24))
		draw_circle(p, 3.6, Palette.GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hex(center: Vector2, radius: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(center + Vector2(radius, 0).rotated(k * PI / 3.0 + PI / 6.0))
	pts.append(pts[0])
	draw_polyline(pts, c, 1.0, true)
