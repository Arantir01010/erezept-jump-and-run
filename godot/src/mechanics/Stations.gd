## STATIONS-BAUSTEINE: die Sicherheits-Mechaniken der TI.
##   timing-gate        PIN-Schleuse (blauer Knopf im Takt)
##   lauscher           sieht NUR Klartext (Hülle-Kernmechanik)
##   andock-plattform   trägt nur Klartext oder VAU
##   vau-feld           Klartext-schnell UND unsichtbar; ttlMs = Kontextschlüssel
##   kontext-anker      frischt die VAU-Sitzung auf
##   stamp-exit         Signatur-Stempel als Levelausgang (QES)
##   deny-enemy         Skimming-Kralle — die TI blockt sie
##   stillstand-podest  Scan im Stillstand
##   krypto-dusche      Verschlüsselung anlegen
##   karte / kartenleser  Identität: eGK / HBA / SMC-B
##   letzte-tuer        das Finale: die Tür, die nicht der Spieler öffnet
## Markenregel überall: Es wird nie gekämpft — die Architektur schützt.
class_name Stations

const REGISTRY := {
	"timing-gate": TimingGate, "lauscher": Lauscher, "andock-plattform": AndockPlattform,
	"vau-feld": VauFeld, "kontext-anker": KontextAnker, "stamp-exit": StampExit,
	"deny-enemy": DenyEnemy, "stillstand-podest": StillstandPodest, "krypto-dusche": KryptoDusche,
	"karte": Karte, "kartenleser": Kartenleser, "letzte-tuer": LetzteTuer,
}

## Kürzel, Name, Rolle, Farbe je Karte — Wahrheit liegt in KartenFx.INFO.
const CARD_INFO := KartenFx.INFO


# ---------------------------------------------------------------- PIN-Schleuse

class TimingGate extends Mechanic:
	var steps := 4
	var step_s := 0.9
	var window_ratio := 0.45
	var progress := 0
	var running := false
	var done := false
	var _step_start := 0.0
	var _fail_until := 0.0
	var _hint := false
	var _last_tip := -100.0
	var _t := 0.0
	var _flash := []
	var _light: PointLight2D

	func spawn() -> void:
		z_index = 5
		steps = int(param("steps", 4))
		step_s = float(param("stepMs", 900)) / 1000.0
		for i in steps:
			_flash.append(0.0)
		_light = Fx.light(self, Vector2(0, _light_y()), pal.accent, 160.0, 0.0)
		var g = linked_gate()
		if g:
			g.open_hint = ltext("gateHint", {"de": "Das Tor ist zu! Schaff erst die PIN-Schleuse: im Takt der pulsierenden Lichter drücken.",
				"en": "The gate is locked! Pass the PIN check first: press on the beat of the pulsing lights."})

	var _slow: float:
		get: return step_s * Game.assist_slowdown("timing-" + str(rect.position.x))

	func tick(delta: float) -> void:
		_t += delta
		for i in steps:
			_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)
		var win := running and (_t - _step_start) < _slow * window_ratio and _t >= _fail_until
		_light.color = Palette.OK if done else (Palette.DENY if _t < _fail_until else pal.accent)
		_light.position.x = _light_x(mini(progress, steps - 1))
		_light.energy = move_toward(_light.energy, (0.9 if win or done else (0.25 if running else 0.0)), delta * 6.0)
		queue_redraw()
		if done or _t < _fail_until:
			return
		var inside := player_in_rect(rect)
		if not running and inside:
			running = true
			progress = 0
			_step_start = _t
			Sfx.play("tick", 0.8, -6.0)
			if not _hint:
				_hint = true
				var h = param("hint", null)
				if h != null:
					say(Game.t(h))
		if not running:
			return
		if not inside:
			running = false
			return
		var elapsed := _t - _step_start
		var in_window := elapsed < _slow * window_ratio
		if elapsed >= _slow:
			_step_start = _t
			Sfx.play("tick", 1.0, -6.0)
		if Input.is_action_just_pressed("action"):
			if in_window:
				_flash[progress] = 1.0
				progress += 1
				Sfx.play("ok", 1.0 + progress * 0.08)
				Fx.sparkle(level, global_position + Vector2(_light_x(progress - 1), _light_y()), Palette.OK, 6, 120.0)
				if progress >= steps:
					_succeed()
				else:
					_step_start = _t
			else:
				_fail()

	func _fail() -> void:
		var key := "timing-" + str(rect.position.x)
		Game.assist_fail(key)
		progress = 0
		_fail_until = _t + 0.45
		_step_start = _t + 0.45
		Sfx.play("deny", 1.2, -4.0)
		Fx.float_text(level, global_position + Vector2(0, -60), "PRÜFUNG WIEDERHOLEN", Palette.DENY, 22)
		if Game.assist_fail_count(key) >= 2 and _t - _last_tip > 6.0:
			_last_tip = _t
			say(ltext("failHint", {"de": "Tipp: Drück %s genau dann, wenn das gelbe Licht groß aufleuchtet!" % Kiosk.label_action(),
				"en": "Tip: press the action right when the yellow light glows big!"}))

	func _succeed() -> void:
		done = true
		running = false
		if Game.assist_clean("timing-" + str(rect.position.x)):
			Game.add_security_bonus()
			Fx.float_text(level, global_position + Vector2(0, -70), "+250 SICHERHEITS-BONUS", Palette.GOLD, 22)
		var g = linked_gate()
		if g:
			g.open()
		Fx.ring(level, global_position, Palette.OK, 120.0)
		Sfx.play("gate")

	func _light_x(i: int) -> float:
		return -((steps - 1) * 44.0) / 2.0 + i * 44.0

	func _light_y() -> float:
		return -rect.size.y / 2.0 - 30.0

	func _draw() -> void:
		var r := local_rect()
		# Terminal-Sockel
		var base := Rect2(-70, r.end.y - 70, 140, 70)
		draw_panel(base, pal.metall, pal.detail, 8, 0.4)
		draw_rect(Rect2(-56, r.end.y - 58, 112, 30), Color(0.02, 0.05, 0.08, 0.9))
		var txt := "PIN" if not done else "OK"
		draw_string(ThemeDB.fallback_font, Vector2(-56, r.end.y - 36), txt, HORIZONTAL_ALIGNMENT_CENTER, 112, 22, Palette.glow(Palette.OK if done else pal.accent, 1.3))
		# Lichter
		var elapsed := _t - _step_start
		var in_window := running and elapsed < _slow * window_ratio and _t >= _fail_until
		for i in steps:
			var p := Vector2(_light_x(i), _light_y())
			var c := Color(0.25, 0.28, 0.35)
			var rad := 11.0
			if _t < _fail_until:
				c = Palette.DENY
			elif i < progress:
				c = Palette.OK
			elif i == progress and in_window:
				c = pal.accent
				rad = 16.0  # größer, nicht nur andersfarbig
			draw_circle(p, rad + 4.0, Color(0.02, 0.04, 0.08, 0.8))
			draw_circle(p, rad, Palette.glow(c, 1.6 if (i == progress and in_window) or i < progress else 1.0))
			if _flash[i] > 0.0:
				draw_arc(p, rad + 8.0 + (1.0 - _flash[i]) * 14.0, 0, TAU, 20, Color(1, 1, 1, _flash[i]), 2.0, true)
		# Takt-Balken unter den Lichtern
		if running and _t >= _fail_until:
			var frac := clampf(elapsed / _slow, 0.0, 1.0)
			var w := (steps - 1) * 44.0 + 32.0
			draw_rect(Rect2(-w / 2.0, _light_y() + 26, w, 4), Color(1, 1, 1, 0.15))
			draw_rect(Rect2(-w / 2.0, _light_y() + 26, w * (1.0 - frac), 4), Palette.glow(pal.accent, 1.3))


# ---------------------------------------------------------------- Lauscher

class Lauscher extends Mechanic:
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

	func spawn() -> void:
		z_index = 6
		base_x = position.x
		speed = float(param("speed", 30)) * 3.0
		reach = float(param("reach", 110)) * 3.0
		spread = float(param("spread", 22)) * 3.0
		pause = float(param("pauseMs", 600)) / 1000.0
		patrol_to = base_x + float(param("patrol", 0)) * 3.0
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
		_cone_light.scale = Vector2(float(dir), 1.0)
		_cone_light.color = Palette.DENY if gesehen else Palette.WARM
		_cone_light.energy = (1.1 if gesehen else 0.65) + 0.08 * sin(_t * 7.0)
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
		Fx.float_text(level, player.global_position + Vector2(0, -90), "−%d Bits" % lost, Palette.DENY, 22)
		if lost <= 0:
			return
		_hits += 1
		if _hits >= 2 and _t - _last_tip > 6.0:
			_last_tip = _t
			say(ltext("huelleHint", {"de": "Tipp: %s = verschlüsseln — dann kann dich niemand mitlesen!" % Kiosk.label_toggle(),
				"en": "Tip: encrypt — then nobody can read you!"}))

	func _draw() -> void:
		# Sichtkegel: gestaffeltes Volumen, warm; beim Erfassen rot und dichter
		var c := Palette.DENY if _seen else Palette.WARM
		var base_a := 0.30 if _seen else 0.12
		for k in 3:
			var frac := 1.0 - k * 0.28
			var pts := PackedVector2Array([Vector2.ZERO, Vector2(dir * reach * frac, -spread * frac), Vector2(dir * reach * frac, spread * frac)])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, base_a * (0.5 + k * 0.25)))
		# Scan-Linien im Kegel
		for i in 4:
			var f := fmod(_t * 0.5 + i * 0.25, 1.0)
			var x := dir * reach * f
			draw_line(Vector2(x, -spread * f), Vector2(x, spread * f), Color(c.r, c.g, c.b, (1.0 - f) * 0.35), 2.0, true)
		# Das Auge
		draw_circle(Vector2.ZERO, 30.0, Color(c.r, c.g, c.b, 0.15))
		draw_circle(Vector2.ZERO, 22.0, Color(0.12, 0.09, 0.14))
		var open := 0.12 if _blink > 0.0 else 1.0
		var sclera := Rect2(-18, -12 * open, 36, 24 * open)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.97, 0.95, 0.92)
		sb.set_corner_radius_all(12)
		sb.anti_aliasing = true
		draw_style_box(sb, sclera)
		if open > 0.5:
			draw_circle(_eye, 8.0, Palette.glow(c, 1.4))
			draw_circle(_eye, 4.0, Color(0.05, 0.04, 0.06))
			draw_circle(_eye + Vector2(-2, -2), 1.5, Color(1, 1, 1, 0.9))
		# Antenne
		draw_line(Vector2(0, -22), Vector2(0, -36), Color(0.3, 0.25, 0.32), 3.0, true)
		draw_circle(Vector2(0, -38), 4.0, Palette.glow(c, 1.6 if _seen else 1.0))


# ---------------------------------------------------------------- Andock-Plattform

class AndockPlattform extends Mechanic:
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


# ---------------------------------------------------------------- VAU-Feld

class VauFeld extends Mechanic:
	var ttl := 0.0
	var inside := false
	var _hint := false
	var _t := 0.0
	var _light: PointLight2D
	var _ring_tex: GradientTexture2D
	var _ring_ratio := -1.0

	func spawn() -> void:
		z_index = 3
		ttl = float(param("ttlMs", 0)) / 1000.0
		make_sensor(rect, _enter, _exit)
		_light = Fx.light(self, Vector2.ZERO, Palette.VAU, maxf(rect.size.x, rect.size.y) * 0.9, 0.35)
		if ttl > 0.0:
			_ring_tex = _make_ring_texture()

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
		queue_redraw()

	func _draw() -> void:
		var r := local_rect()
		var c := Palette.VAU
		var a := 0.22 if inside else 0.13
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c.r, c.g, c.b, a)
		sb.border_color = Palette.glow(Color(c.r, c.g, c.b, 0.9), 1.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		# Hex-Gitter (Raum, kein Tunnel)
		var y := r.position.y + 14
		var row := 0
		while y < r.end.y - 8:
			var x := r.position.x + 14 + (10 if row % 2 else 0)
			while x < r.end.x - 8:
				var pts := PackedVector2Array()
				for k in 6:
					pts.append(Vector2(x, y) + Vector2(6, 0).rotated(k * PI / 3.0 + PI / 6.0))
				pts.append(pts[0])
				draw_polyline(pts, Color(c.r, c.g, c.b, 0.13 + 0.08 * sin(_t * 2.0 + x * 0.05 + y * 0.03)), 1.0, true)
				x += 20
			y += 18
			row += 1
		# Schild
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y - 8), "VAU", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Palette.glow(c, 1.3))
		# Sitzungsfrische: konischer Ring über dem Schild — voll, solange niemand drin
		# ist; läuft ab, sobald Paul in der VAU arbeitet (Kontextschlüssel).
		if ttl > 0.0:
			var draining := inside and player.huelle.vau_expires
			var ratio := player.huelle.vau_ratio if draining else 1.0
			var center := Vector2(r.get_center().x, r.position.y - 50)
			var alpha := 1.0 if draining else 0.55
			var warn := draining and ratio < 0.3
			# Grundscheibe und Restring (unter 30 %: rot, langsam pulsierend — 2 Hz)
			draw_circle(center, 20.0, Color(0.04, 0.05, 0.10, 0.40 * alpha))
			var back := Color(0.06, 0.07, 0.14, 0.55)
			if warn:
				back = Color(Palette.DENY.r, Palette.DENY.g, Palette.DENY.b, 0.3 + 0.15 * sin(_t * TAU * 2.0))
			draw_arc(center, 17.0, 0, TAU, 40, back, 5.0, true)
			if _ring_tex:
				_set_ring_ratio(ratio)
				draw_texture_rect(_ring_tex, Rect2(center - Vector2(16, 16), Vector2(32, 32)), false, Color(1, 1, 1, alpha))
			if ratio > 0.005:
				var a0 := -PI / 2.0
				draw_arc(center, 17.0, a0, a0 + TAU * ratio, maxi(4, int(40 * ratio) + 2), Palette.glow(Color(c.r, c.g, c.b, alpha), 1.4), 5.0, true)
			# Schlüsselmarke in der Mitte: das ist der Kontextschlüssel
			draw_circle(center, 3.5, Palette.glow(Color(c.r, c.g, c.b, alpha), 1.3))


# ---------------------------------------------------------------- Kontext-Anker

class KontextAnker extends Mechanic:
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


# ---------------------------------------------------------------- Signatur-Stempel

class StampExit extends Mechanic:
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


# ---------------------------------------------------------------- Skimming-Kralle

class DenyEnemy extends Mechanic:
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
						say(ltext("duckHint", {"de": "Tipp: Nach UNTEN drücken zum Ducken — die Kralle greift über dich hinweg!",
							"en": "Tip: press DOWN to duck — the claw grabs right over you!"}))
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
			Fx.deny_stamp(level, global_position + Vector2(_dir * 40, -70), ltext("denyText", {"de": "ZUGRIFF VERWEIGERT", "en": "ACCESS DENIED"}))
			level.camera.kick(Vector2(0, 30))
			Fx.dust(level, global_position, 6, 1.2))

	func _draw() -> void:
		var sx := sin(_t * 70.0) * 3.0 * _shake
		var c := Color(0.55, 0.5, 0.6) if not blocked else Color(0.45, 0.45, 0.55)
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
		draw_panel(Rect2(-_dir * 20 - 22 + sx, -22, 44, 44), Color(0.2, 0.16, 0.2), c, 6)
		draw_rect(Rect2(-_dir * 20 - 12 + sx, -6, 24, 4), Palette.DENY if not blocked else Color(0.3, 0.3, 0.3))
		# gematik-Siegel-Blende: fährt herunter und klemmt die Kralle ein
		if _blende_y > -900.0:
			var b := Rect2(-_dir * 20 - 34, _blende_y - 60, 68, 60)
			draw_panel(b, Color(0.05, 0.12, 0.10), Palette.OK, 6, 0.8, 3)
			draw_string(ThemeDB.fallback_font, Vector2(b.position.x, b.position.y + 26), "ZUGELASSEN", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 12, Palette.glow(Palette.OK, 1.3))
			draw_arc(Vector2(b.get_center().x, b.position.y + 42), 9.0, 0, TAU, 16, Palette.glow(Palette.OK, 1.4), 2.0, true)
			draw_line(Vector2(b.get_center().x - 5, b.position.y + 42), Vector2(b.get_center().x - 1, b.position.y + 46), Palette.OK, 2.0, true)
			draw_line(Vector2(b.get_center().x - 1, b.position.y + 46), Vector2(b.get_center().x + 6, b.position.y + 38), Palette.OK, 2.0, true)


# ---------------------------------------------------------------- Stillstand-Podest

class StillstandPodest extends Mechanic:
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
		Fx.float_text(level, global_position + Vector2(0, -110), "GEPRÜFT ✓", Palette.OK, 26)
		# Der Gag: Die Datenkrake hinter Paul bekommt das Tor vor die Nase
		get_tree().create_timer(0.8).timeout.connect(func():
			if g and is_inside_tree():
				Fx.deny_stamp(level, g.global_position + Vector2(-90, -120), ltext("denyText", {"de": "ZUGRIFF VERWEIGERT", "en": "ACCESS DENIED"})))

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
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y - 34), "SCAN" if not done else "OK", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Palette.glow(c, 1.2))


# ---------------------------------------------------------------- Krypto-Dusche

class KryptoDusche extends Mechanic:
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
			g.open_hint = ltext("gateHint", {"de": "Erst verschlüsseln: In der Krypto-Dusche %s drücken." % Kiosk.label_action(),
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


# ---------------------------------------------------------------- Karte

## Ausweis zum Aufsammeln. Schwebt, der Chip fängt Licht, Name als Bildunterschrift.
## Beim Aufnehmen fliegt die Karte in ihr HUD-Fach (KartenFx.fly_to_hud).
## Fachlich: Identität, keine Währung — zählt nirgends mit, öffnet keine Tür D.
class Karte extends Mechanic:
	var card := "egk"
	var taken := false
	var _t := 0.0
	var _ground := INF         # Bodenhöhe (lokal) für den Schatten; INF = kein Boden gefunden
	var _light: PointLight2D
	var _glow: Sprite2D

	func spawn() -> void:
		z_index = 6
		card = str(obj.get("karte", "egk")).to_lower()
		_t = randf() * TAU
		make_sensor(Rect2(rect.position - Vector2(10, 30), rect.size + Vector2(20, 40)), _enter)
		var c := KartenFx.color_of(card)
		_light = Fx.light(self, Vector2(0, -8), c, 110.0, 0.3)
		if Fx.web_fallback():
			_glow = Fx.glow_sprite(self, c, 40.0, 0.6)
			_glow.position = Vector2(0, -8)
		# Boden unter der Karte suchen: Der Schatten verankert das Schweben
		var tx := int(floor(rect.get_center().x / Game.TILE))
		var ty := int(floor(rect.end.y / Game.TILE))
		for i in 6:
			if ty + i >= data.height:
				break
			if data.is_solid(tx, ty + i):
				_ground = float(ty + i) * Game.TILE - position.y
				break

	func _bob() -> float:
		return sin(_t * 2.0) * 5.0

	func _enter(_p: Player) -> void:
		if taken:
			return
		taken = true
		Game.add_card(card)   # Spiellogik sofort — die Animation läuft darüber
		var c := KartenFx.color_of(card)
		var inf := KartenFx.info(card)
		var at := global_position + Vector2(0, _bob() - 8.0)
		Sfx.play("bonus", 0.95)
		Fx.sparkle(level, at, c, 12, 200.0)
		Fx.ring(level, at, c, 64.0)
		Fx.light_burst(level, at, c, 180.0, 1.0, 0.35)
		rezi.happy()
		if _light:
			_light.queue_free()
			_light = null
		if _glow:
			_glow.queue_free()
			_glow = null
		# Flug ins HUD-Fach; ohne HUD (Tests) bleibt der Schwebetext
		if not KartenFx.fly_to_hud(level, at, card, func(): Sfx.play("ui", 1.35, -6.0)):
			Fx.float_text(level, global_position + Vector2(0, -40), str(inf["kurz"]) + " ✓", c, 26)
		var h = obj.get("hint", null)
		if h != null:
			say(Game.t(h), 3.5)
		queue_free()

	func tick(delta: float) -> void:
		if taken:
			return
		_t += delta
		if _light:
			_light.energy = 0.28 + 0.08 * sin(_t * 2.0)
		if _glow:
			Fx.set_glow(_glow, KartenFx.color_of(card), 0.55 + 0.15 * sin(_t * 2.0))
		queue_redraw()

	func _draw() -> void:
		if taken:
			return
		var c := KartenFx.color_of(card)
		var bob := _bob()
		var tilt := sin(_t * 1.3 + 0.7) * 0.05
		# Bodenschatten: kleiner und blasser, je höher die Karte gerade schwebt
		if _ground < INF:
			var k := 1.0 - (bob + 5.0) / 10.0 * 0.35
			draw_set_transform(Vector2(0, _ground - 2.0), 0.0, Vector2(k, 0.28 * k))
			draw_circle(Vector2.ZERO, 30.0, Color(0.05, 0.05, 0.08, 0.22 * k))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# leiser Hof: Fundstück im Abendlicht
		draw_circle(Vector2(0, bob - 8.0), 46.0, Color(c.r, c.g, c.b, 0.08))
		draw_set_transform(Vector2(0, bob - 8.0), tilt, Vector2.ONE)
		KartenFx.draw_card(self, Rect2(-KartenFx.BASE / 2.0, KartenFx.BASE), card, "voll", KartenFx.glint_phase(_t), 1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Bildunterschrift: der Name der Karte, lesbar
		var inf := KartenFx.info(card)
		var nc := Palette.tint(c, 0.45)
		var y := bob + 34.0
		draw_string_outline(Brand.sans("medium"), Vector2(-80, y), str(inf["name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, 4, Color(0.05, 0.06, 0.09, 0.85))
		draw_string(Brand.sans("medium"), Vector2(-80, y), str(inf["name"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 13, nc)


# ---------------------------------------------------------------- Kartenleser

## Das Terminal: Display mit der erwarteten Karte (Umriss in Kartenfarbe) und
## einer Statuszeile, Schlitz mit atmendem Licht, LED rot → gelb → grün.
## Beim Stecken gleitet die Karte sichtbar hinein (0,15 s Anflug + 0,35 s Gleiten,
## reine Funktion von _anim_t) und bleibt sichtbar stecken. Falsche Karte: Rempler,
## Karte springt wieder heraus, Stempel. Belegt: Kopfschütteln.
## Spiellogik (Game.insert_card, Tor) bleibt sofort — die Animation läuft darüber.
## Fachlich: Die Karte öffnet, sie liefert keine Daten (Zugriff freigegeben).
class Kartenleser extends Mechanic:
	## Säule: Display, LED und Schlitz liegen über Kopf- und REZI-Höhe (REZI schwebt
	## bei etwa −92 px, Oberkante ≈ −120), damit Paul davor nichts verdeckt.
	const W := 104.0
	const H := 184.0
	const CARD := Vector2(56, 36)
	## Schlitz etwas rechts der Mitte: REZI schwebt links über Paul und würde eine
	## mittige Karte anschneiden.
	const SLOT_X := 12.0
	const STATUS := {
		"stecken": {"de": "Karte stecken", "en": "Insert card"},
		"prueft": {"de": "Prüfe Karte …", "en": "Checking card …"},
		"frei": {"de": "Freigegeben ✓", "en": "Released ✓"},
		"abgelehnt": {"de": "Abgelehnt ✗", "en": "Rejected ✗"},
		"keine": {"de": "Keine Karte", "en": "No card"},
		"belegt": {"de": "Steckt woanders", "en": "In another slot"},
	}
	var accepted: Array = []
	var terminal_id := ""
	var inserted := ""
	var opened := false
	var _hint := false
	var _t := 0.0
	var _flash := 0.0
	var _light: PointLight2D
	var _glow: Sprite2D
	# Karten-Animation als reine Funktion von _anim_t (0..1): Art, Karte, Startpunkt
	var _anim_kind := ""       # "rein" | "raus" | "abgelehnt"
	var _anim_card := ""
	var _anim_t := 0.0
	var _anim_from := Vector2.ZERO
	var _anim_tw: Tween
	var _beat := false         # Abweis-Beat (Stempel, Rempler) schon gefeuert?
	var _seated := ""          # Karte, die sichtbar im Schlitz steckt
	var _led := "rot"          # rot | gelb | gruen
	var _led_until := 0.0
	var _shake := 0.0          # Rempler (falsche Karte)
	var _nod := 0.0            # Kopfschütteln (belegt)
	var _status := "stecken"
	var _status_color := Palette.WHITE
	var _status_until := 0.0
	var _say_pending := false

	func spawn() -> void:
		z_index = 5
		var raw = obj.get("karten", ["egk"])
		if raw is String:
			for s in str(raw).split(","):
				accepted.append(s.strip_edges().to_lower())
		else:
			for s in raw:
				accepted.append(str(s).to_lower())
		if accepted.is_empty():
			accepted.append("egk")
		terminal_id = "leser-%s" % str(rect.position.x)
		make_sensor(rect, _enter, _exit)
		# LED-Licht klein und im Ruhe-Rot schwach: Es soll die Säule nicht rot tönen
		# (in hellen Welten wirkte das wie Alarm) — erst grün darf es leuchten.
		_light = Fx.light(self, _led_pos(), Palette.DENY, 80.0, 0.12)
		if Fx.web_fallback():
			_glow = Fx.glow_sprite(self, Palette.DENY, 18.0, 0.35)
			_glow.position = _led_pos()
		var g = linked_gate()
		if g:
			g.open_hint = ltext("gateHint", {"de": "Dieses Tor öffnet nur eine Karte — steck sie am Terminal links.",
				"en": "Only a card opens this gate — insert it at the terminal on the left."})

	# --- Geometrie (lokal) ---

	func _body() -> Rect2:
		var r := local_rect()
		return Rect2(-W / 2.0, r.end.y - H, W, H)

	## LED sitzt oben rechts im Display
	func _led_pos() -> Vector2:
		return Vector2(36, _body().position.y + 22.0)

	func _slot_y() -> float:
		return _body().position.y + 96.0

	## Karten-Ecke oben links, wenn sie vor dem Schlitz schwebt
	func _mouth() -> Vector2:
		return Vector2(SLOT_X - CARD.x / 2.0, _body().position.y + 44.0)

	## Karten-Ecke oben links, wenn sie steckt (oberes Drittel bleibt sichtbar)
	func _seat() -> Vector2:
		return Vector2(SLOT_X - CARD.x / 2.0, _body().position.y + 74.0)

	## Über der Säule: Schwebetexte und Stempel
	func _above() -> Vector2:
		return global_position + Vector2(0, local_rect().end.y - H - 22.0)

	# --- Sensor ---

	func _enter(_p: Player) -> void:
		if not _hint:
			_hint = true
			say(ltext("hint", {"de": "Karte stecken: %s drücken." % Kiosk.label_action(), "en": "Insert your card: press the action."}))

	## Wer weggeht, nimmt seinen Ausweis mit — die Karte gleitet wieder heraus.
	func _exit(_p: Player) -> void:
		if inserted != "":
			Game.remove_card_from(terminal_id)
			inserted = ""
		_say_pending = false
		if _seated != "" or _anim_kind == "rein":
			var card := _seated if _seated != "" else _anim_card
			_seated = ""
			_play("raus", card, Vector2.ZERO, 0.3)
			Sfx.play("tick", 0.9, -8.0)
		_led = "rot"
		_led_until = 0.0
		_set_status("stecken", Palette.WHITE, 0.0)

	# --- Ablauf ---

	func tick(delta: float) -> void:
		_t += delta
		_flash = maxf(0.0, _flash - delta * 2.0)
		_shake = maxf(0.0, _shake - delta * 3.0)
		_nod = maxf(0.0, _nod - delta * 2.2)
		if _led_until > 0.0 and _t >= _led_until:
			_led_until = 0.0
			_led = "gruen" if _seated != "" else "rot"
		if _status_until > 0.0 and _t >= _status_until:
			_status_until = 0.0
			if _seated != "":
				_set_status("frei", Palette.OK, 0.0)
			else:
				_set_status("stecken", Palette.WHITE, 0.0)
		if _anim_kind == "abgelehnt" and not _beat and _anim_t >= 0.5:
			_beat = true
			_reject_beat()
		var lc := _led_color()
		_light.color = lc
		var breathe := 0.03 * sin(_t * PI) if _led != "gruen" else 0.0   # 0,5 Hz
		var base_e := 0.12
		match _led:
			"gruen":
				base_e = 0.55
			"gelb":
				base_e = 0.3
			_:
				base_e = 0.25 if _led_until > 0.0 else 0.12
		_light.energy = base_e + _flash * 0.6 + breathe
		if _glow:
			Fx.set_glow(_glow, lc, (0.9 if _led == "gruen" else 0.35) + _flash * 0.6)
		queue_redraw()
		if not player_in_rect(rect):
			return
		if Input.is_action_just_pressed("action") and inserted == "" and _anim_kind == "":
			_versuch()

	func _versuch() -> void:
		var res := Game.insert_card(accepted, terminal_id)   # Spiellogik sofort
		var from := to_local(player.global_position + Vector2(0, -44.0))
		match str(res["result"]):
			"ok":
				inserted = str(res["card"])
				_led = "gelb"
				_led_until = 0.0
				_set_status("prueft", Palette.WARM, 0.0)
				Sfx.play("tick", 1.15, -6.0)
				_play("rein", inserted, from, 0.5)
				var g = linked_gate()
				if g and not opened:
					opened = true
					g.open()
					Game.add_security_bonus()
					_say_pending = true
			"falsche-karte":
				_led = "gelb"
				_set_status("prueft", Palette.WARM, 0.0)
				Sfx.play("tick", 1.15, -6.0)
				var wrong := str(Game.cards[0]) if Game.cards.size() > 0 else "egk"
				_play("abgelehnt", wrong, from, 0.7)
			"nicht-dabei":
				Sfx.play("deny", 1.5, -8.0)
				_set_status("keine", Palette.WARM, 2.4)
				say(ltext("nicht-dabeiHint", {"de": "Die passende Karte hast du noch nicht — such sie unterwegs!",
					"en": "You do not have the right card yet — find it along the way!"}))
			"belegt":
				Sfx.play("deny", 1.5, -8.0)
				_nod = 1.0
				_led = "gelb"
				_led_until = _t + 1.2
				_set_status("belegt", Palette.WARM, 2.6)
				say(ltext("belegtHint", {"de": "Deine Karte steckt noch woanders — hol sie erst dort ab.",
					"en": "Your card is still in another slot — pick it up there first."}))

	## Der Abweis-Moment (falsche Karte): Rempler, LED rot betont, Stempel — nur
	## die echte Zurückweisung durch die TI bekommt den Stempel.
	func _reject_beat() -> void:
		_shake = 1.0
		_flash = 1.0
		_led = "rot"
		_led_until = _t + 1.4
		_set_status("abgelehnt", Palette.DENY, 2.6)
		Fx.deny_stamp(level, _above(), ltext("denyText", {"de": "ZUGRIFF VERWEIGERT", "en": "ACCESS DENIED"}))
		# REZIs Hinweis erst, wenn der Stempel verblasst — sonst überlagern sich beide
		var hint := ltext("falsche-karteHint", {"de": "ZUGRIFF VERWEIGERT — diese Karte gehört hier nicht hin.",
			"en": "ACCESS DENIED — this card does not belong here."})
		get_tree().create_timer(1.3).timeout.connect(func():
			if is_inside_tree():
				say(hint, 3.5))

	func _set_status(key: String, color: Color, hold: float) -> void:
		_status = key
		_status_color = color
		_status_until = _t + hold if hold > 0.0 else 0.0

	func _led_color() -> Color:
		match _led:
			"gruen":
				return Palette.OK
			"gelb":
				return Palette.WARM
		return Palette.DENY

	# --- Karten-Animation ---

	func _play(kind: String, card: String, from: Vector2, seconds: float) -> void:
		if _anim_tw:
			_anim_tw.kill()
		_anim_kind = kind
		_anim_card = card
		_anim_from = from
		_anim_t = 0.0
		_beat = false
		_anim_tw = create_tween()
		_anim_tw.tween_property(self, "_anim_t", 1.0, seconds)
		_anim_tw.tween_callback(_anim_done)

	## Karte sitzt: LED grün, Ring, Funken, Klang, Display, Schwebetext, HUD-Pop.
	func _anim_done() -> void:
		var kind := _anim_kind
		_anim_kind = ""
		if kind != "rein":
			return
		_seated = _anim_card
		_led = "gruen"
		_led_until = 0.0
		_flash = 1.0
		var c := KartenFx.color_of(_seated)
		var at := to_global(Vector2(SLOT_X, _slot_y()))
		Sfx.play("ok", 1.1)
		Fx.ring(level, at, Palette.OK, 76.0)
		Fx.sparkle(level, at, c, 10, 170.0)
		Fx.light_burst(level, at, Palette.OK, 200.0, 1.1, 0.4)
		_set_status("frei", Palette.OK, 0.0)
		var inf := KartenFx.info(_seated)
		Fx.float_text(level, _above(), "%s ✓ · %s" % [inf["kurz"],
			Game.t({"de": "Zugriff freigegeben", "en": "access granted"})], c, 22)
		KartenFx.hud_pop(level, _seated)
		if _say_pending:
			_say_pending = false
			say(Game.t(data.station.get("reziText", "")), 3.5)

	## Lage der animierten Karte (Ecke oben links, Drehung, Deckkraft) —
	## reine Funktion von Art und Fortschritt t.
	func _card_pose(kind: String, t: float) -> Dictionary:
		var mouth := _mouth()
		var seat := _seat()
		var pos := seat
		var rot := 0.0
		var alpha := 1.0
		match kind:
			"rein":
				if t < 0.3:
					var u := smoothstep(0.0, 1.0, t / 0.3)
					pos = _anim_from.lerp(mouth, u) + Vector2(0, -sin(u * PI) * 26.0)
					rot = lerpf(-0.35, 0.0, u)
				else:
					var u := 1.0 - pow(1.0 - (t - 0.3) / 0.7, 3.0)
					pos = mouth.lerp(seat, u)
			"raus":
				var u := 1.0 - pow(1.0 - t, 3.0)
				pos = seat.lerp(mouth + Vector2(0, -14.0), u)
				rot = lerpf(0.0, -0.18, u)
				alpha = 1.0 - smoothstep(0.55, 1.0, t)
			"abgelehnt":
				var halb := mouth.lerp(seat, 0.45)
				if t < 0.25:
					var u := smoothstep(0.0, 1.0, t / 0.25)
					pos = _anim_from.lerp(mouth, u) + Vector2(0, -sin(u * PI) * 26.0)
					rot = lerpf(-0.35, 0.0, u)
				elif t < 0.5:
					var u := 1.0 - pow(1.0 - (t - 0.25) / 0.25, 3.0)
					pos = mouth.lerp(halb, u)
				else:
					var v := (t - 0.5) / 0.5
					var u := 1.0 - pow(1.0 - v, 2.0)
					pos = halb.lerp(mouth + Vector2(30.0, -46.0), u)
					rot = lerpf(0.0, 0.4, u)
					alpha = 1.0 - smoothstep(0.5, 1.0, v)
		return {"pos": pos, "rot": rot, "alpha": alpha}

	static func _fit_font(font: Font, text: String, max_w: float, size: int) -> int:
		var s := size
		while s > 7 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
			s -= 1
		return s

	# --- Zeichnung ---

	func _draw() -> void:
		var body := _body()
		var by := body.position.y
		# Rempler (falsche Karte) und Kopfschütteln (belegt): Bewegung um den Fuß, ≤ 3 Hz
		var sx := sin(_t * 18.0) * 4.0 * _shake
		var rot := sin(_t * 16.0) * 0.045 * _nod
		var pivot := Vector2(sx, body.end.y)
		var o := Vector2(0, -body.end.y)
		draw_set_transform(pivot, rot, Vector2.ONE)
		# Gehäuse
		var shell := Rect2(body.position + o, body.size)
		draw_panel(shell, pal.metall, pal.detail, 8, 0.25)
		# Display: dunkel, erwartete Karte(n) als Umriss, darunter die Statuszeile
		var disp := Rect2(-44, by + 8 + o.y, 88, 48)
		draw_rect(disp, Color(0.02, 0.05, 0.08, 0.93))
		draw_rect(disp, Color(pal.detail.r, pal.detail.g, pal.detail.b, 0.45), false, 1.0)
		var gx := -40.0
		for a in accepted:
			KartenFx.draw_card(self, Rect2(gx, disp.position.y + 6.0, 26, 17), str(a), "umriss")
			gx += 30.0
		var st: Dictionary = STATUS.get(_status, STATUS["stecken"])
		var txt := Game.t(st)
		var fs := _fit_font(Brand.sans("medium"), txt, 80.0, 11)
		draw_string(Brand.sans("medium"), Vector2(disp.position.x + 4, disp.end.y - 8), txt, HORIZONTAL_ALIGNMENT_CENTER, disp.size.x - 8, fs, _status_color)
		# Karte (animiert oder gesteckt) — vor dem Display, hinter der Front
		var card := ""
		var pose := {}
		if _anim_kind != "":
			card = _anim_card
			pose = _card_pose(_anim_kind, _anim_t)
		elif _seated != "":
			card = _seated
			pose = {"pos": _seat(), "rot": 0.0, "alpha": 1.0}
		if card != "":
			var p: Vector2 = pose["pos"]
			var pr: float = pose["rot"]
			var pa: float = pose["alpha"]
			var center_q := p + CARD / 2.0 + o
			draw_set_transform(pivot + center_q.rotated(rot), rot + pr, Vector2.ONE)
			KartenFx.draw_card(self, Rect2(-CARD / 2.0, CARD), card, "voll", -1.0, pa)
			draw_set_transform(pivot, rot, Vector2.ONE)
		# Front unter dem Schlitz: verdeckt den Kartenkörper (oben eckig, unten rund)
		var sy := _slot_y() + o.y
		var front := Rect2(shell.position.x, sy, shell.size.x, shell.end.y - sy)
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = pal.metall
		fsb.border_color = pal.detail
		fsb.set_border_width_all(2)
		fsb.corner_radius_bottom_left = 8
		fsb.corner_radius_bottom_right = 8
		fsb.anti_aliasing = true
		draw_style_box(fsb, front)
		draw_rect(Rect2(front.position.x + 6, front.end.y - 6, front.size.x - 12, 4), Palette.shade(pal.metall, 0.35))
		# Schlitz mit Licht: atmet in der Farbe der erwarteten Karte, gesteckt = grün
		draw_rect(Rect2(SLOT_X - 34, sy - 2, 68, 7), Color(0.02, 0.04, 0.08))
		var slot_c := KartenFx.color_of(str(accepted[0]))
		var slot_a := 0.45 + 0.25 * sin(_t * PI)   # 0,5 Hz
		if _seated != "":
			slot_c = Palette.OK
			slot_a = 0.9
		draw_rect(Rect2(SLOT_X - 32, sy + 0.5, 64, 2), Color(slot_c.r, slot_c.g, slot_c.b, slot_a))
		# LED mit Fassung: rot (zu), gelb (prüft/belegt), grün (freigegeben); atmet mit 0,5 Hz
		var lp := _led_pos() + o
		var lc := _led_color()
		var k := 1.0
		match _led:
			"gruen":
				k = 1.6
			"gelb":
				k = 1.5
			_:
				k = 1.5 if _led_until > 0.0 else 1.0
		k *= 0.86 + 0.14 * sin(_t * PI)
		draw_circle(lp, 9.5, Color(0.03, 0.05, 0.08, 0.95))
		var led_draw := Palette.glow(lc, k) if not Fx.web_fallback() else lc.lightened(clampf(0.25 * (k - 1.0), 0.0, 0.3))
		draw_circle(lp, 6.5 + _flash * 3.0, led_draw)
		draw_circle(lp + Vector2(-2, -2), 1.8, Color(1, 1, 1, 0.35))
		# Säulenfront unter dem Schlitz: vertiefte Blende mit Lüftungsrillen
		var vent := Rect2(-36, sy + 22.0, 72, front.size.y - 40.0)
		draw_panel(vent, Palette.shade(pal.metall, 0.25), Palette.shade(pal.detail, 0.3), 5, 0.0, 1)
		for i in 3:
			var vy := vent.position.y + 12.0 + i * 12.0
			draw_line(Vector2(vent.position.x + 10, vy), Vector2(vent.end.x - 10, vy), Palette.shade(pal.metall, 0.45), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- Die letzte Tür

## Die Tür ohne Öffner: Der Spieler kann sie nicht öffnen (Vorhängeschloss, Knopf
## wird abgewiesen). Das Zugriffsprotokoll erscheint, dann öffnet die Person, der
## die Akte gehört: Bügel springt auf, die Protokollzeile wird grün, die Tür hebt.
## Fachlich: Datensouveränität — die Tür gehört nicht dem Datensatz, sondern der Person.
class LetzteTuer extends Mechanic:
	var body: StaticBody2D
	var _cs: CollisionShape2D
	var phase := "wartet"      # wartet → protokoll → freigabe → offen
	var _rise := 0.0
	var _lock := 0.0           # 0 = Bügel zu, 1 = offen
	var _ok_t := 0.0           # Einblendung der grünen Freigabezeile
	var _t := 0.0
	var _hint := false
	var _last_deny := -100.0
	var _lines: Array = []
	var _ok_line := ""
	var _completed := false
	var _light: PointLight2D
	var _glow: Sprite2D

	func spawn() -> void:
		z_index = 5
		_light = Fx.light(self, Vector2(0, -rect.size.y / 2.0 + 20.0), Palette.GOLD, 260.0, 0.0)
		if Fx.web_fallback():
			_glow = Fx.glow_sprite(self, Palette.GOLD, 60.0, 0.0)
			_glow.position = _lock_local()
		body = StaticBody2D.new()
		body.collision_layer = 1
		_cs = CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(24.0, rect.size.y)
		_cs.shape = s
		body.add_child(_cs)
		add_child(body)
		make_sensor(Rect2(rect.position.x - 260, rect.position.y - 40, 260, rect.size.y + 40), _arrive)
		make_sensor(Rect2(rect.end.x + 20, rect.position.y, 120, rect.size.y), _through)

	func _lock_local() -> Vector2:
		return Vector2(0, 6.0 - (rect.size.y - 10.0) * _rise)

	func _arrive(_p: Player) -> void:
		if _hint:
			return
		_hint = true
		say(ltext("warteText", {"de": "Hier endet mein Weg. Jetzt entscheidet sie.", "en": "This is where my path ends. Now she decides."}), 4.0)
		get_tree().create_timer(2.2).timeout.connect(_start_protokoll)

	func _through(_p: Player) -> void:
		if phase == "offen" and not _completed:
			_completed = true
			level.complete_level()

	func tick(delta: float) -> void:
		_t += delta
		if _glow:
			_glow.position = _lock_local()
		queue_redraw()
		if phase != "offen" and player_in_rect(Rect2(rect.position.x - 120, rect.position.y, 120, rect.size.y)) and Input.is_action_just_pressed("action"):
			if _t - _last_deny > 2.0:
				_last_deny = _t
				Sfx.play("deny", 1.1, -6.0)
				say(ltext("denyText", {"de": "Kein Schlüssel öffnet diese Tür. Sie gehört nicht dir.", "en": "No key opens this door. It is not yours."}), 3.0)

	func _start_protokoll() -> void:
		if phase != "wartet" or not is_inside_tree():
			return
		phase = "protokoll"
		var entries := Game.protokoll.duplicate()
		var lines: Array = []
		lines.append("ZUGRIFFSPROTOKOLL")
		if entries.is_empty():
			lines.append("— keine Einträge —")
		for e in entries.slice(0, 6):
			lines.append("gesehen · %s · %s" % [e["actor"], e["level_id"]])
		if entries.size() > 6:
			lines.append("… und %d weitere" % (entries.size() - 6))
		var i := 0
		for l in lines:
			get_tree().create_timer(0.55 * i).timeout.connect(func():
				if is_inside_tree():
					_lines.append(l)
					Sfx.play("tick", 1.2, -10.0))
			i += 1
		var wait := 0.55 * lines.size() + 1.8
		get_tree().create_timer(wait).timeout.connect(_freigabe.bind(entries.is_empty()))

	## Der Freigabe-Beat: Bügel springt auf, die Freigabezeile wird grün — erst
	## dann hebt die Tür. Sie öffnet nicht der Spieler, sondern die Inhaberin.
	func _freigabe(lueckenlos: bool) -> void:
		if not is_inside_tree() or phase != "protokoll":
			return
		phase = "freigabe"
		_ok_line = ltext("freigabeZeile", {"de": "✓ FREIGABE · durch die Inhaberin der Akte", "en": "✓ RELEASED · by the owner of the record"})
		Sfx.play("ok", 0.9)
		var tw := create_tween()
		tw.tween_property(self, "_lock", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "_ok_t", 1.0, 0.4)
		tw.tween_callback(func():
			if is_inside_tree():
				var at := to_global(_lock_local())
				Fx.sparkle(level, at, Palette.GOLD, 10, 160.0)
				Fx.ring(level, at, Palette.OK, 64.0)
				Sfx.play("checkpoint", 1.2, -6.0))
		tw.tween_interval(0.35)
		tw.tween_callback(_oeffnen.bind(lueckenlos))

	func _oeffnen(lueckenlos: bool) -> void:
		if not is_inside_tree():
			return
		phase = "offen"
		if lueckenlos:
			say(ltext("lueckenlosText", {"de": "Sie sieht: Niemand hat mitgelesen.", "en": "She sees: nobody read along."}), 3.0)
			get_tree().create_timer(2.2).timeout.connect(func():
				if is_inside_tree():
					say(ltext("freigabeText", {"de": "Freigegeben — von ihr.", "en": "Released — by her."}), 3.0))
		else:
			say(ltext("freigabeText", {"de": "Freigegeben — von ihr.", "en": "Released — by her."}), 3.0)
		Sfx.play("gate", 0.8)
		Sfx.play("seal", 1.0, -8.0)
		_cs.set_deferred("disabled", true)
		var tw := create_tween()
		tw.tween_property(self, "_rise", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_light, "energy", 1.0, 0.9)
		if _glow:
			Fx.set_glow(_glow, Palette.GOLD, 1.0)
		Fx.ring(level, global_position, Palette.GOLD, 160.0)
		Fx.flash(Color(1, 0.95, 0.85), 0.25)

	func _draw() -> void:
		var h := rect.size.y
		var lift := (h - 10.0) * _rise
		var door := Rect2(-24, -h / 2.0 - lift, 48, h)
		var open := phase == "offen"
		var edge := pal.detail.lerp(Palette.GOLD, maxf(_lock, 1.0 if open else 0.0))
		draw_panel(door, pal.fels.lightened(0.05), edge, 8, 0.8 if open else 0.15 + 0.5 * _lock, 3)
		# Rahmen
		draw_rect(Rect2(-30, -h / 2.0 - 8, 6, h + 8), pal.fels)
		draw_rect(Rect2(24, -h / 2.0 - 8, 6, h + 8), pal.fels)
		# Schild auf der Tür: wessen Akte
		draw_string(Brand.spaced(Brand.sans("medium"), 1), Vector2(-24, door.position.y + 30), ltext("tuerSchild", {"de": "AKTE", "en": "RECORD"}),
			HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.6))
		# Vorhängeschloss: Körper, Bügel (hebt und schwenkt beim Öffnen), Schlüsselloch → Haken
		var lp := Vector2(0, 6.0 - lift)
		var lc := pal.detail.lerp(Palette.GOLD, _lock)
		var lcg := Palette.glow(lc, 1.0 + 0.5 * _lock) if not Fx.web_fallback() else lc
		var lb := Rect2(lp.x - 11, lp.y - 2, 22, 18)
		var pivot := Vector2(lb.position.x + 5, lb.position.y)
		draw_set_transform(pivot + Vector2(0, -9.0 * _lock), -0.55 * _lock, Vector2.ONE)
		draw_arc(Vector2(6, 0), 6.0, PI, TAU, 14, lcg, 3.0, true)
		draw_line(Vector2(0, 0), Vector2(0, 3), lcg, 3.0)
		draw_line(Vector2(12, 0), Vector2(12, 3), lcg, 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_panel(lb, Palette.shade(pal.metall, 0.2), lcg, 4, 0.6 * _lock, 2)
		if _lock < 0.5:
			draw_circle(lp + Vector2(0, 6), 2.5, Color(0.05, 0.05, 0.08))
			draw_rect(Rect2(lp.x - 1, lp.y + 6, 2, 6), Color(0.05, 0.05, 0.08))
		else:
			draw_polyline(PackedVector2Array([lp + Vector2(-5, 7), lp + Vector2(-1.5, 10.5), lp + Vector2(5, 3)]), Palette.OK, 2.5, true)
		# Zugriffsprotokoll über der Tür: Panel, Kopfzeile, Einträge (warm = offen
		# gelesen), Freigabezeile grün
		var n := _lines.size() + (1 if _ok_line != "" else 0)
		if n > 0:
			var row := 24.0
			var y0 := -h / 2.0 - 46.0 - n * row
			var panel := Rect2(-236, y0 - 20, 472, n * row + 30)
			var pe := Color(Palette.WARM.r, Palette.WARM.g, Palette.WARM.b, 0.55).lerp(Palette.OK, _ok_t)
			draw_panel(panel, Color(0.03, 0.05, 0.08, 0.80), pe, 8, 0.5 * _ok_t, 2)
			for i in _lines.size():
				var yy := y0 + i * row
				if i == 0:
					draw_string(Brand.spaced(Brand.sans("heavy"), 2), Vector2(-220, yy), str(_lines[i]), HORIZONTAL_ALIGNMENT_CENTER, 440, 17, Palette.WHITE)
				else:
					draw_string(Brand.sans("medium"), Vector2(-220, yy), str(_lines[i]), HORIZONTAL_ALIGNMENT_CENTER, 440, 16, Palette.WARM)
			if _ok_line != "":
				var yy := y0 + _lines.size() * row
				draw_line(Vector2(-200, yy - 17), Vector2(200, yy - 17), Color(pe.r, pe.g, pe.b, 0.5 * _ok_t), 1.0)
				draw_string(Brand.sans("heavy"), Vector2(-220 - (1.0 - _ok_t) * 16.0, yy), _ok_line, HORIZONTAL_ALIGNMENT_CENTER, 440, 16,
					Color(Palette.OK.r, Palette.OK.g, Palette.OK.b, _ok_t))
