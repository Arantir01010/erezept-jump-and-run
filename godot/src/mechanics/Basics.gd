## BASISBAUSTEINE: Prüfsumme, Bonus, Checkpoint, Tür-Ausgang, Sprungfeder,
## Störfeld, Hinweiszone, Pendel-Plattform, Schadenszone, Tor, Kulisse.
## Bildregeln der hellen Welt: dunkle Kontur, Kappe oben hell, Fuß dunkel;
## Glühen und Punktlichter nur für echte Lichtquellen (Prüfsummen, Lichter an Toren).
## Browser (kein HDR-Glühen): Fx.glow_sprite als additiver Hof — nur wenn
## Fx.web_fallback() wahr ist, und nur an genau diesen Lichtquellen.
class_name Basics


# ---------------------------------------------------------------- Prüfsumme

class Collectible extends Mechanic:
	var bonus := false
	var taken := false
	var _t := 0.0
	var _magnet := false
	var _ph := 0.0
	var _light: PointLight2D
	var _glow: Sprite2D

	func spawn() -> void:
		z_index = 6
		_ph = randf() * TAU
		make_sensor(Rect2(rect.position - Vector2(14, 14), rect.size + Vector2(28, 28)), _on_enter)
		_light = Fx.light(self, Vector2.ZERO, Palette.GOLD if bonus else Palette.COOL, 90.0 if bonus else 70.0, 0.5)
		if Fx.web_fallback():
			_glow = Fx.glow_sprite(self, Palette.GOLD if bonus else Palette.COOL, 30.0 if bonus else 24.0, 0.9)

	func tick(delta: float) -> void:
		if taken:
			return
		_t += delta
		_light.energy = 0.45 + 0.15 * sin(_t * 3.0 + _ph)
		if _glow:
			Fx.set_glow(_glow, Palette.GOLD if bonus else Palette.COOL, 0.85 + 0.25 * sin(_t * 3.0 + _ph))
		var d := global_position.distance_to(player.global_position + Vector2(0, -30))
		if d < 150.0:
			_magnet = true
		if _magnet:
			global_position = global_position.lerp(player.global_position + Vector2(0, -30), 1.0 - exp(-14.0 * delta))
			if d < 22.0:
				_take()
		queue_redraw()

	func _on_enter(_p: Player) -> void:
		_take()

	func _take() -> void:
		if taken:
			return
		taken = true
		Game.add_bits(1, bonus)
		var c := Palette.GOLD if bonus else Palette.COOL
		Fx.sparkle(level, global_position, c, 16 if bonus else 10)
		Fx.ring(level, global_position, c, 40.0)
		Fx.light_burst(level, global_position, c, 200.0, 1.2, 0.35)
		var pitch := 1.0 + mini(Game.combo - 1, 8) * 0.06
		Sfx.play("bonus" if bonus else "collect", pitch)
		if Game.combo >= 3:
			Fx.float_text(level, global_position + Vector2(0, -20), "×%d" % Game.combo, c, 22)
		rezi.happy()
		level.on_collected(self)
		queue_free()

	func _draw() -> void:
		var bob := sin(_t * 2.4 + _ph) * 4.0
		var c := Palette.GOLD if bonus else Palette.COOL
		var r := 9.0 if bonus else 7.5
		var p := Vector2(0, bob)
		draw_circle(p, r * 2.4, Color(c.r, c.g, c.b, 0.12))
		draw_circle(p, r + 2.5, Color(0.12, 0.16, 0.24))
		draw_circle(p, r, Palette.glow(c, 1.5))
		draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.35, Color(1, 1, 1, 0.9))
		if bonus:
			var pts := PackedVector2Array()
			for k in 6:
				pts.append(p + Vector2(r + 8.0, 0).rotated(_t * 1.2 + k * PI / 3.0))
			pts.append(pts[0])
			draw_polyline(pts, Color(c.r, c.g, c.b, 0.7), 2.0, true)


# ---------------------------------------------------------------- Checkpoint

class Checkpoint extends Mechanic:
	var active := false
	var _t := 0.0
	var _light: PointLight2D

	func spawn() -> void:
		z_index = 3
		make_sensor(Rect2(rect.position.x - 10, rect.position.y - 60, rect.size.x + 20, rect.size.y + 60), _on_enter)

	func _on_enter(p: Player) -> void:
		if active:
			return
		active = true
		p.set_respawn(Vector2(global_position.x, rect.end.y - 2))
		Sfx.play("checkpoint")
		Fx.ring(level, global_position + Vector2(0, -50), Palette.OK, 70.0)
		Fx.sparkle(level, global_position + Vector2(0, -50), Palette.OK, 8, 160.0)
		_light = Fx.light(self, Vector2(0, -60), Palette.OK, 120.0, 0.6)
		if Fx.web_fallback():
			Fx.glow_sprite(self, Palette.OK, 40.0, 0.7).position = Vector2(0, -60)

	func tick(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var base := Vector2(0, rect.size.y / 2.0)
		var c := Palette.OK if active else pal.accent
		draw_line(base, base + Vector2(0, -80), pal.outline, 6.0, true)
		draw_line(base, base + Vector2(0, -80), Palette.tint(pal.cap, 0.2), 3.0, true)
		var wave := sin(_t * 5.0) * 3.0 if active else sin(_t * 1.5) * 1.5
		var flag := PackedVector2Array([base + Vector2(2, -80), base + Vector2(34 + wave, -68), base + Vector2(2, -54)])
		draw_colored_polygon(flag, c)
		draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), pal.outline, 2.0, true)
		draw_circle(base, 7.0, pal.outline)
		draw_circle(base, 5.0, Palette.tint(pal.cap, 0.2))


# ---------------------------------------------------------------- Tür-Ausgang

class DoorExit extends Mechanic:
	var _hint_at := -100.0
	var _done := false
	var _t := 0.0
	var _open_amount := 0.0
	var _light: PointLight2D
	var _glow: Sprite2D

	func spawn() -> void:
		z_index = 3
		make_sensor(Rect2(rect.position.x - 6, rect.position.y - 60, rect.size.x + 12, rect.size.y + 60), _on_enter)
		_light = Fx.light(self, Vector2(0, -20), Palette.GOLD, 220.0, 0.0)
		if Fx.web_fallback():
			_glow = Fx.glow_sprite(self, Palette.GOLD, 70.0, 0.0)
			_glow.position = Vector2(0, -30)

	var unlocked: bool:
		get: return Game.bits_this_level() >= data.count_required

	func _on_enter(_p: Player) -> void:
		if _done:
			return
		if unlocked:
			_done = true
			level.complete_level()
		else:
			var now := Time.get_ticks_msec() / 1000.0
			if now - _hint_at > 3.0:
				_hint_at = now
				var need := data.count_required - Game.bits_this_level()
				say("Noch %d %s sammeln!" % [need, Game.t(data.collect_label)])
				Sfx.play("deny", 1.3, -6.0)

	func tick(delta: float) -> void:
		_t += delta
		_open_amount = move_toward(_open_amount, 1.0 if unlocked else 0.0, delta * 2.0)
		_light.energy = _open_amount * (0.8 + 0.2 * sin(_t * 3.0))
		if _glow:
			Fx.set_glow(_glow, Palette.GOLD, _open_amount * (0.9 + 0.2 * sin(_t * 3.0)))
		queue_redraw()

	func _draw() -> void:
		var bottom := rect.size.y / 2.0
		var frame := Rect2(-32, bottom - 100, 64, 100)
		var c := Palette.GOLD if unlocked else pal.cap
		draw_panel(Rect2(frame.position - Vector2(2, 2), frame.size + Vector2(4, 4)), pal.outline, pal.outline, 9, 0.0, 0)
		draw_panel(frame, pal.fill, c, 8, _open_amount * 1.2, 3)
		var inner := Rect2(-22, bottom - 90, 44, 86)
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_rect(inner, Color(c.r, c.g, c.b, 0.15 + _open_amount * (0.35 + 0.2 * pulse)))
		if _open_amount > 0.0:
			for i in 5:
				var y := inner.end.y - fmod(_t * 60.0 + i * 20.0, inner.size.y)
				draw_rect(Rect2(inner.position.x + 4, y, inner.size.x - 8, 2), Palette.glow(Color(c.r, c.g, c.b, _open_amount * 0.7), 1.4))
		else:
			draw_arc(Vector2(0, bottom - 52), 8.0, PI, TAU, 10, c, 3.0, true)
			draw_rect(Rect2(-11, bottom - 52, 22, 16), c)
		var txt := "%d / %d" % [mini(Game.bits_this_level(), data.count_required), data.count_required]
		draw_string(ThemeDB.fallback_font, Vector2(-26, bottom - 110), txt, HORIZONTAL_ALIGNMENT_CENTER, 52, 18, pal.outline)
		draw_string(ThemeDB.fallback_font, Vector2(-27, bottom - 111), txt, HORIZONTAL_ALIGNMENT_CENTER, 52, 18, Palette.WHITE)


# ---------------------------------------------------------------- Sprungfeder

class Spring extends Mechanic:
	var _press := 0.0

	func spawn() -> void:
		z_index = 4
		make_sensor(Rect2(rect.position.x + 6, rect.end.y - 22, rect.size.x - 12, 22), _on_enter)

	func _on_enter(p: Player) -> void:
		if p.velocity.y < -50.0:
			return
		p.bounce(2100.0)
		_press = 1.0
		Sfx.play("spring")
		Fx.dust(level, Vector2(global_position.x, rect.end.y), 6, 1.2)
		Fx.ring(level, Vector2(global_position.x, rect.end.y - 10), pal.accent, 50.0)
		Fx.light_burst(level, Vector2(global_position.x, rect.end.y - 20), pal.accent, 200.0, 1.0, 0.3)
		level.camera.kick(Vector2(0, 40))

	func tick(delta: float) -> void:
		_press = maxf(0.0, _press - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var bottom := rect.size.y / 2.0
		var comp := 10.0 * _press
		draw_panel(Rect2(-20, bottom - 8, 40, 8), pal.cap, pal.outline, 3)
		for i in 3:
			var y := bottom - 10 - i * (6.0 - comp / 3.0)
			draw_line(Vector2(-14, y), Vector2(14, y - 3), pal.outline, 3.0, true)
		draw_panel(Rect2(-22, bottom - 30 + comp, 44, 8), pal.accent, pal.outline, 3, 0.0, 2)
		draw_rect(Rect2(-18, bottom - 30 + comp, 36, 2), Palette.tint(pal.accent, 0.5))


# ---------------------------------------------------------------- Störfeld

class Spike extends Mechanic:
	var _t := 0.0
	var _light: PointLight2D

	func spawn() -> void:
		z_index = 4
		make_sensor(Rect2(rect.position.x + 6, rect.position.y + 14, rect.size.x - 12, rect.size.y - 14), _on_enter)
		_light = Fx.light(self, Vector2(0, -10), Palette.DENY, 70.0, 0.35)

	func _on_enter(p: Player) -> void:
		p.hurt(global_position.x)

	func tick(delta: float) -> void:
		_t += delta
		_light.energy = 0.3 + 0.2 * absf(sin(_t * 9.0))
		queue_redraw()

	func _draw() -> void:
		var r := local_rect()
		var c := Palette.DENY
		draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), pal.outline)
		draw_rect(Rect2(r.position.x + 1, r.end.y - 7, r.size.x - 2, 6), pal.cap)
		for i in 3:
			var x := r.position.x + 8 + i * 16.0
			var flick := 0.7 + 0.3 * sin(_t * 12.0 + i * 2.0)
			var tri := PackedVector2Array([Vector2(x - 1, r.end.y - 6), Vector2(x + 5, r.position.y + 10), Vector2(x + 11, r.end.y - 6)])
			draw_colored_polygon(tri, pal.outline)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 1, r.end.y - 7), Vector2(x + 5, r.position.y + 13), Vector2(x + 9, r.end.y - 7)]), Palette.glow(Color(c.r, c.g, c.b, flick), 1.3))


# ---------------------------------------------------------------- Hinweiszone

class InfoSign extends Mechanic:
	var _last := -100.0

	func spawn() -> void:
		make_sensor(rect, _on_enter)

	func _on_enter(_p: Player) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last < 4.0:
			return
		_last = now
		var de = obj.get("textDe", null)
		var text := ""
		if de != null:
			text = Game.t({"de": str(de), "en": str(obj.get("textEn", de))})
		else:
			text = ltext("text", "")
		if text != "":
			say(text, 3.4)


# ---------------------------------------------------------------- Pendel-Plattform

class MovingPlatform extends Mechanic:
	var body: AnimatableBody2D
	var range_px := 64.0 * 3.0
	var speed := 40.0 * 3.0
	var _t := 0.0
	var _start := Vector2.ZERO

	func spawn() -> void:
		z_index = 4
		range_px = float(param("range", 64)) * 3.0
		speed = float(param("speed", 40)) * 3.0
		body = AnimatableBody2D.new()
		body.collision_layer = 1
		body.sync_to_physics = true
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(rect.size.x, 18.0)
		cs.shape = s
		cs.position = Vector2(0, -rect.size.y / 2.0 + 9.0)
		cs.one_way_collision = true
		body.add_child(cs)
		add_child(body)
		_start = Vector2.ZERO

	func _physics_process(delta: float) -> void:
		_t += delta
		var period := (range_px * 2.0) / maxf(speed, 1.0)
		var ph := fmod(_t, period) / period
		var x := range_px * (1.0 - absf(ph * 2.0 - 1.0))
		body.position = _start + Vector2(x, 0)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(body.position.x - rect.size.x / 2.0, -rect.size.y / 2.0, rect.size.x, 18.0)
		draw_line(Vector2(-rect.size.x / 2.0, r.get_center().y), Vector2(range_px + rect.size.x / 2.0, r.get_center().y), Color(pal.outline.r, pal.outline.g, pal.outline.b, 0.3), 3.0)
		draw_panel(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), pal.outline, pal.outline, 7, 0.0, 0)
		draw_panel(r, pal.cap, pal.cap, 6, 0.0, 0)
		draw_rect(Rect2(r.position.x + 3, r.position.y, r.size.x - 6, 3), pal.cap_light)


# ---------------------------------------------------------------- Schadenszone

class Hazard extends Mechanic:
	var _t := 0.0

	func spawn() -> void:
		z_index = 4
		make_sensor(Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), _on_enter)

	func _on_enter(p: Player) -> void:
		p.hurt(global_position.x)

	func tick(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := local_rect()
		var a := 0.22 + 0.1 * sin(_t * 6.0)
		draw_rect(r, Color(Palette.DENY.r, Palette.DENY.g, Palette.DENY.b, a))
		draw_rect(r, Palette.DENY, false, 3.0)


# ---------------------------------------------------------------- Tor

class Gate extends Mechanic:
	var body: StaticBody2D
	var is_open := false
	var open_hint := ""
	var _bump_start := -100.0
	var _last_bump := -100.0
	var _last_tip := -100.0
	var _shake := 0.0
	var _rise := 0.0
	var _t := 0.0
	var _cs: CollisionShape2D
	var _light: PointLight2D
	var _glow: Sprite2D

	func spawn() -> void:
		z_index = 5
		body = StaticBody2D.new()
		body.collision_layer = 1
		_cs = CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(maxf(rect.size.x, 24.0), rect.size.y)
		_cs.shape = s
		body.add_child(_cs)
		add_child(body)
		var n := str(obj.get("name", "gate-%d" % get_instance_id()))
		level.gates[n] = self
		make_sensor(Rect2(rect.position.x - 26, rect.position.y, rect.size.x + 52, rect.size.y), _on_bump)
		_light = Fx.light(self, Vector2(0, -rect.size.y / 2.0 + 10.0), Palette.DENY, 110.0, 0.55)
		if Fx.web_fallback():
			_glow = Fx.glow_sprite(self, Palette.DENY, 34.0, 0.7)
			_glow.position = Vector2(0, -rect.size.y / 2.0 + 10.0)

	func _on_bump(_p: Player) -> void:
		if is_open:
			return
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_bump > 0.6:
			_bump_start = now
		_last_bump = now
		_shake = 1.0
		Sfx.play("deny", 1.6, -12.0)

	func tick(delta: float) -> void:
		_t += delta
		_shake = maxf(0.0, _shake - delta * 4.0)
		if not is_open and player_in_rect(Rect2(rect.position.x - 26, rect.position.y, rect.size.x + 52, rect.size.y)):
			var now := Time.get_ticks_msec() / 1000.0
			if now - _bump_start > 1.6 and now - _last_tip > 7.0 and absf(player.velocity.x) > 20.0:
				_last_tip = now
				say(open_hint if open_hint != "" else ltext("bumpHint",
					{"de": "Zu! Eine TI-Prüfung in der Nähe öffnet dieses Tor — schau dich um.",
					"en": "Locked! A nearby TI check opens this gate — look around."}))
		queue_redraw()

	func open() -> void:
		if is_open:
			return
		is_open = true
		Sfx.play("gate")
		_cs.set_deferred("disabled", true)
		_light.color = Palette.OK
		var tw := create_tween()
		tw.tween_property(self, "_rise", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_light, "energy", 0.0, 1.4).set_delay(0.4)
		if _glow:
			Fx.set_glow(_glow, Palette.OK, 0.8)
			tw.parallel().tween_property(_glow, "modulate:a", 0.0, 1.4).set_delay(0.4)
		Fx.sparkle(level, Vector2(global_position.x, rect.position.y + 20), Palette.OK, 12, 200.0)
		Fx.light_burst(level, global_position, Palette.OK, 300.0, 1.4, 0.6)
		Fx.flash(Palette.OK, 0.10)
		level.camera.kick(Vector2(0, -60))

	func _draw() -> void:
		var w := maxf(rect.size.x, 24.0)
		var h := rect.size.y
		var lift := (h - 14.0) * _rise
		var sx := sin(_t * 60.0) * 3.0 * _shake
		var bar := Rect2(-w / 2.0 + sx, -h / 2.0 - lift, w, h)
		var c := Palette.OK if is_open else Palette.DENY
		draw_panel(Rect2(bar.position - Vector2(2, 2), bar.size + Vector2(4, 4)), pal.outline, pal.outline, 6, 0.0, 0)
		draw_panel(bar, pal.fill, pal.fill, 5, 0.0, 0)
		draw_rect(Rect2(bar.position.x + 2, bar.position.y + 2, w - 4, 3), pal.cap_light)
		for i in int(h / 40.0):
			draw_rect(Rect2(bar.position.x + 3, bar.position.y + 14 + i * 40, w - 6, 3), pal.cap)
		draw_circle(Vector2(sx, -h / 2.0 - lift + 10.0), 8.0, pal.outline)
		draw_circle(Vector2(sx, -h / 2.0 - lift + 10.0), 6.0, Palette.glow(c, 1.5))
		draw_rect(Rect2(-w / 2.0 - 8, -h / 2.0 - 6, 6, h + 6), pal.outline)
		draw_rect(Rect2(w / 2.0 + 2, -h / 2.0 - 6, 6, h + 6), pal.outline)
		draw_rect(Rect2(-w / 2.0 - 7, -h / 2.0 - 5, 4, h + 4), pal.cap)
		draw_rect(Rect2(w / 2.0 + 3, -h / 2.0 - 5, 4, h + 4), pal.cap)


# ---------------------------------------------------------------- Kulisse

class Deco extends Mechanic:
	var sprite := "krake-0"
	var drift := 4.0
	var _t := 0.0
	var _ph := 0.0

	func spawn() -> void:
		z_index = 1
		sprite = str(param("sprite", "krake-0"))
		drift = float(param("drift", 4)) * 3.0
		_ph = randf() * TAU

	func tick(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var off := Vector2(sin(_t * 0.7 + _ph) * drift, cos(_t * 0.5 + _ph) * drift * 0.6)
		if sprite.begins_with("krake"):
			_krake(off)
		elif sprite.begins_with("lauscher"):
			draw_circle(off, 14.0, pal.outline)
			draw_circle(off, 9.0, Palette.WARM)
			draw_circle(off + Vector2(2, 0), 4.0, pal.outline)
		else:
			draw_circle(off, 12.0, pal.cap)

	func _krake(off: Vector2) -> void:
		var body_c := Color(0.52, 0.30, 0.60)
		draw_circle(off, 29.0, pal.outline)
		draw_circle(off, 26.0, body_c)
		draw_circle(off + Vector2(-8, -4), 6.0, Color(0.97, 0.95, 1.0))
		draw_circle(off + Vector2(8, -4), 6.0, Color(0.97, 0.95, 1.0))
		draw_circle(off + Vector2(-7, -3), 2.5, pal.outline)
		draw_circle(off + Vector2(9, -3), 2.5, pal.outline)
		for i in 6:
			var pts := PackedVector2Array()
			for k in 8:
				var t := k / 7.0
				var p := off + Vector2(-22 + i * 9.0, 18.0) + Vector2(sin(_t * 2.5 + i + t * 3.0) * 8.0 * t, t * 40.0)
				pts.append(p)
			draw_polyline(pts, pal.outline, 6.0, true)
			draw_polyline(pts, Palette.shade(body_c, 0.1), 3.5, true)
