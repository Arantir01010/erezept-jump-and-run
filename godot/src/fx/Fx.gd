class_name Fx
extends RefCounted
## FX — Partikel, Lichter, Hitstop, Zeitlupe, Stempel, Schwebetexte. Alles kurz,
## alles lesbar. Kamera-Shake ist bewusst selten (Playtest: „rüttelt, mega
## nervig") — Gewicht kommt aus Squash, Staub, Hitstop, Licht und dem
## Post-Effekt-Impuls (Fx.post).
##
## Browser-Fallback: im Web-Build (Compatibility-Renderer) gibt es kein
## HDR-Glühen und keine Sub-Emitter. `web_fallback()` ist dort wahr (am Desktop
## zum Testen mit `--webfx`); dann ersetzen additive Glüh-Sprites
## (`glow_sprite`) das Glühen echter Lichtquellen, und Partikel laufen auf der CPU.

static var post: PostFx = null
static var _hitstop_active := false
static var _slowmo_active := false
static var _radial: GradientTexture2D
static var _cone: ImageTexture
static var _dot: ImageTexture
static var _webfx := -1


# ------------------------------------------------------------------ Umgebung

## Browser-Fallback aktiv? Web-Build oder Desktop-Test mit `--webfx`.
static func web_fallback() -> bool:
	if _webfx < 0:
		_webfx = 1 if (OS.has_feature("web") or "--webfx" in OS.get_cmdline_user_args()) else 0
	return _webfx == 1


## GPU-Partikel (Sub-Emitter, SDF-Kollision) nur außerhalb des Browser-Pfads.
static func gpu_particles_ok() -> bool:
	return not web_fallback()


# ------------------------------------------------------------------ Licht

## Weiche radiale Lichttextur (gecacht).
static func radial_texture() -> GradientTexture2D:
	if _radial:
		return _radial
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.55))
	g.add_point(0.65, Color(1, 1, 1, 0.15))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_radial = tex
	return tex


## Kegelförmige Lichttextur (Lauscher-Blick): Ursprung links-mittig, zeigt nach +x.
static func cone_texture() -> ImageTexture:
	if _cone:
		return _cone
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var origin := Vector2(24, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x, y) - origin
			var a := 0.0
			if d.x > 0.0:
				var ang := absf(atan2(d.y, d.x))
				var edge := 1.0 - smoothstep(0.30, 0.42, ang)
				var dist := d.x / (size - 24.0)
				var fall := 1.0 - smoothstep(0.35, 1.0, dist)
				var near := smoothstep(0.0, 0.08, dist)
				a = edge * fall * near
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_cone = ImageTexture.create_from_image(img)
	return _cone


## Weicher Punkt (8×8) für Funken und Spritzer (gecacht).
static func dot_texture() -> ImageTexture:
	if _dot:
		return _dot
	var size := 8
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - smoothstep(0.5, 1.0, d), 0.0, 1.0)))
	_dot = ImageTexture.create_from_image(img)
	return _dot


## Punktlicht anlegen. radius in px, energy 0–2. Schatten nur für Leitlichter (teuer).
## shadow_color: Schattenfarbe der Welt (pal.shadow_for_light) — Standard bleibt schwarz.
static func light(parent: Node, pos: Vector2, color: Color, radius: float, energy := 0.8, shadow := false, shadow_color := Color(0, 0, 0, 0.42)) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = radial_texture()
	l.texture_scale = maxf(0.05, radius / 128.0)
	l.color = color
	l.energy = energy
	l.position = pos
	l.range_item_cull_mask = 1
	l.blend_mode = Light2D.BLEND_MODE_ADD
	if shadow:
		l.shadow_enabled = true
		l.shadow_color = shadow_color
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF13
		l.shadow_filter_smooth = 6.0
	parent.add_child(l)
	return l


## Browser-Ersatz für HDR-Glühen: additives, weiches Radial-Sprite hinter einer
## echten Lichtquelle (Prüfsumme, Tür, Lampe, REZI). Unbeleuchtet (LIGHT_MODE_UNSHADED,
## light_mask 0), damit weder Sonne noch Schatten den Hof verändern.
## radius in px, energy 0–2. Nur einsetzen, wenn `web_fallback()` wahr ist.
static func glow_sprite(parent: Node, color: Color, radius: float, energy := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = radial_texture()
	s.scale = Vector2.ONE * maxf(0.02, radius * 2.0 / 256.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = m
	s.light_mask = 0
	s.z_index = -1
	set_glow(s, color, energy)
	parent.add_child(s)
	return s


## Farbe und Stärke eines Glüh-Sprites nachführen (Pulsieren, Auf-/Abblenden).
static func set_glow(s: Sprite2D, color: Color, energy: float) -> void:
	if s == null:
		return
	var e := clampf(energy, 0.0, 2.0)
	s.modulate = Color(color.r, color.g, color.b, clampf(e * 0.42, 0.0, 0.85))


# ------------------------------------------------------------------ Impulse

static func impact(strength: float) -> void:
	if post:
		post.aberrate(strength)


static func flash(color: Color, amount: float) -> void:
	if post:
		post.flash(color, amount)


## Gewitterblitz: kurzer, moderater Aufheller — höchstens `frames` Frames hell
## (Standard 2), danach sofort aus. Kein Nachleuchten, kein Flackern.
static func lightning(color: Color, amount: float, frames := 2) -> void:
	if post:
		post.lightning(color, amount, frames)


static func hitstop(tree: SceneTree, seconds: float) -> void:
	if _hitstop_active or _slowmo_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.02
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


## Kurze Zeitlupe für große Momente (Siegel): Physik und Partikel laufen langsam.
static func slowmo(tree: SceneTree, scale: float, seconds: float) -> void:
	if _slowmo_active:
		return
	_slowmo_active = true
	Engine.time_scale = scale
	await tree.create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_slowmo_active = false


# ------------------------------------------------------------------ Partikel

static func dust(parent: Node, pos: Vector2, count := 4, strength := 1.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = maxi(1, count)
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector2(0, -1)
	p.spread = 75.0
	p.initial_velocity_min = 40.0 * strength
	p.initial_velocity_max = 130.0 * strength
	p.gravity = Vector2(0, -70)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.5
	p.color = Color(0.8, 0.88, 1.0, 0.45)
	p.color_ramp = _fade_ramp(Color(0.8, 0.88, 1.0, 0.5))
	p.z_index = 9
	parent.add_child(p)
	p.emitting = true
	_auto_free(p, 0.9)


## Landungsstaub: rollt zu beiden Seiten von den Füßen weg; Menge, Weite und
## Größe wachsen mit der Aufprallstärke (0–1). Leichte Hüpfer bleiben fast still.
static func land_dust(parent: Node, pos: Vector2, impact: float) -> void:
	var k := clampf(impact, 0.0, 1.0)
	var count := 2 + int(k * 7.0)
	for side in [-1.0, 1.0]:
		var p := CPUParticles2D.new()
		p.position = pos
		p.amount = count
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 0.35 + 0.3 * k
		p.direction = Vector2(side, -0.35 - 0.3 * k)
		p.spread = 22.0 + 18.0 * k
		p.initial_velocity_min = 30.0 + 60.0 * k
		p.initial_velocity_max = 90.0 + 220.0 * k
		p.damping_min = 120.0
		p.damping_max = 260.0
		p.gravity = Vector2(0, -50)
		p.scale_amount_min = 2.0 + 1.5 * k
		p.scale_amount_max = 4.0 + 4.0 * k
		p.color = Color(0.8, 0.88, 1.0, 0.35 + 0.2 * k)
		p.color_ramp = _fade_ramp(Color(0.8, 0.88, 1.0, 0.4 + 0.2 * k))
		p.z_index = 9
		parent.add_child(p)
		p.emitting = true
		_auto_free(p, p.lifetime + 0.4)


static func sparkle(parent: Node, pos: Vector2, color: Color, count := 14, speed := 260.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 300.0
	p.damping_max = 500.0
	p.gravity = Vector2(0, 240)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Palette.glow(color, 1.7)
	p.color_ramp = _fade_ramp(Palette.glow(color, 1.7))
	p.z_index = 20
	parent.add_child(p)
	p.emitting = true
	_auto_free(p, 1.0)


## Funkenschauer mit Nachfunken (Siegel): GPU-Partikel, jeder Funke setzt am
## Lebensende über einen Sub-Emitter drei kleine Nachfunken. Im Browser-Pfad
## der CPU-Funkenregen (`sparkle`).
static func burst(parent: Node, pos: Vector2, color: Color, count := 30, speed := 400.0) -> void:
	if not gpu_particles_ok():
		sparkle(parent, pos, color, count, speed)
		return
	var c := Palette.glow(color, 1.7)
	var ramp := fade_ramp_texture(c)
	# Nachfunken: klein, kurz, fallen
	var sub := GPUParticles2D.new()
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3(0, -1, 0)
	sm.spread = 180.0
	sm.initial_velocity_min = 30.0
	sm.initial_velocity_max = 110.0
	sm.gravity = Vector3(0, 320, 0)
	sm.damping_min = 40.0
	sm.damping_max = 120.0
	sm.scale_min = 0.25
	sm.scale_max = 0.5
	sm.color = c
	sm.color_ramp = ramp
	sub.process_material = sm
	sub.texture = dot_texture()
	sub.amount = count * 4
	sub.lifetime = 0.4
	sub.local_coords = false
	sub.emitting = true
	sub.z_index = 20
	sub.position = pos
	sub.visibility_rect = Rect2(-800, -800, 1600, 1600)
	parent.add_child(sub)
	# Hauptfunken: explosiv, gebremst, leichte Schwerkraft
	var main := GPUParticles2D.new()
	var mm := ParticleProcessMaterial.new()
	mm.direction = Vector3(0, -1, 0)
	mm.spread = 180.0
	mm.initial_velocity_min = speed * 0.4
	mm.initial_velocity_max = speed
	mm.damping_min = 240.0
	mm.damping_max = 420.0
	mm.gravity = Vector3(0, 240, 0)
	mm.scale_min = 0.4
	mm.scale_max = 0.8
	mm.color = c
	mm.color_ramp = ramp
	mm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_END
	mm.sub_emitter_amount_at_end = 3
	mm.sub_emitter_keep_velocity = false
	main.process_material = mm
	main.texture = dot_texture()
	main.amount = count
	main.lifetime = 0.7
	main.one_shot = true
	main.explosiveness = 1.0
	main.local_coords = false
	main.z_index = 20
	main.position = pos
	main.visibility_rect = Rect2(-800, -800, 1600, 1600)
	parent.add_child(main)
	main.sub_emitter = main.get_path_to(sub)
	main.emitting = true
	_auto_free(main, 1.8)
	_auto_free(sub, 1.8)


static func ring(parent: Node, pos: Vector2, color: Color, radius := 60.0, width := 3.0) -> void:
	var r := _Ring.new()
	r.position = pos
	r.color = color
	r.max_radius = radius
	r.width = width
	r.z_index = 20
	parent.add_child(r)


## Lichtblitz an einer Stelle: ein Punktlicht, das schnell verglimmt.
static func light_burst(parent: Node, pos: Vector2, color: Color, radius := 240.0, energy := 1.6, seconds := 0.45) -> void:
	var l := light(parent, pos, color, radius, energy)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## Stempel „ZUGRIFF VERWEIGERT" (Markenregel: Angreifer scheitern sichtbar und komisch).
static func deny_stamp(parent: Node, pos: Vector2, text := "ZUGRIFF VERWEIGERT") -> void:
	var l := _stamp_label(text, Palette.DENY, 34)
	l.position = pos - Vector2(l.size.x / 2.0, 20.0)
	l.rotation = deg_to_rad(-8)
	l.scale = Vector2(2.2, 2.2)
	l.z_index = 70
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	Sfx.play("deny")
	sparkle(parent, pos, Palette.DENY, 10, 200.0)
	light_burst(parent, pos, Palette.DENY, 200.0, 1.2, 0.5)
	flash(Palette.DENY, 0.12)


static func float_text(parent: Node, pos: Vector2, text: String, color: Color, size := 26) -> void:
	var l := _stamp_label(text, color, size)
	l.position = pos - Vector2(l.size.x / 2.0, 0)
	l.z_index = 65
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 70.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


static func _stamp_label(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = Brand.sans("heavy")
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 8
	ls.outline_color = Color(0.03, 0.05, 0.08, 0.9)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(text.length() * size * 0.66 + 20, size + 12)
	l.pivot_offset = l.size / 2.0
	return l


static func _fade_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g


## Ausblend-Rampe als Textur (GPU-Partikel), HDR-fähig für Glühfarben > 1.
static func fade_ramp_texture(c: Color) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = _fade_ramp(c)
	t.width = 64
	t.use_hdr = true
	return t


static func _auto_free(n: Node, seconds: float) -> void:
	n.get_tree().create_timer(seconds).timeout.connect(n.queue_free)


class _Ring extends Node2D:
	var color := Color.WHITE
	var max_radius := 60.0
	var width := 3.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta * 2.6
		if t >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var r := max_radius * (0.2 + 0.8 * (1.0 - pow(1.0 - t, 2.0)))
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Palette.glow(Color(color.r, color.g, color.b, (1.0 - t) * 0.9), 1.3), width * (1.0 - t) + 1.0, true)
