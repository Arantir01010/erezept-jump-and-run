class_name KulissePartikel
extends RefCounted
## UMGEBUNGSPARTIKEL je Welt (kein Regen — der gehört zum Wetter):
##   Morgen  → Pollen im Gegenlicht (weiche, warme Punkte, treiben mit dem Wind)
##   Abend   → Glühwürmchen (sanft pulsierend; nur der Kern knapp über der
##             Glüh-Schwelle 1,35, der Hof bleibt darunter)
##   RZ      → Staubkörner in den Lichtbündeln (je Lampe ein Emitter)
##   Archiv  → Papierstaub (kleine, langsam taumelnde Flocken)
## Alles CPUParticles2D — läuft auch im Browser. Alle Emitter liegen auf
## Licht-Ebene 2 (Spiellichter treffen sie nicht).

static var _soft: ImageTexture
static var _core: ImageTexture
static var _flake: ImageTexture


## Weicher Punkt (Pollen, Staub): Alpha fällt gaussisch nach außen ab.
static func soft_dot() -> ImageTexture:
	if _soft == null:
		var n := 32
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var r := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a := clampf(1.0 - r, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_soft = ImageTexture.create_from_image(img)
	return _soft


## Glühwürmchen: harter kleiner Kern (volle Farbe → HDR), weicher schwacher Hof.
static func core_dot() -> ImageTexture:
	if _core == null:
		var n := 24
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var r := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var halo := clampf(1.0 - r, 0.0, 1.0)
				var a := 0.30 * halo * halo
				if r < 0.16:
					a = 1.0
				elif r < 0.26:
					a = lerpf(1.0, 0.30 * halo * halo, (r - 0.16) / 0.10)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_core = ImageTexture.create_from_image(img)
	return _core


## Papierflocke: kleines abgerundetes Rechteck.
static func flake() -> ImageTexture:
	if _flake == null:
		var img := Image.create(10, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 10:
				var edge := x == 0 or x == 9 or y == 0 or y == 6
				var corner := (x == 0 or x == 9) and (y == 0 or y == 6)
				img.set_pixel(x, y, Color(1, 1, 1, 0.0 if corner else (0.55 if edge else 1.0)))
		_flake = ImageTexture.create_from_image(img)
	return _flake


static func _base(amount: int, lifetime: float, w: float, top: float, bottom: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(w * 0.5, (bottom - top) * 0.5)
	p.position = Vector2(w * 0.5, (top + bottom) * 0.5)
	p.gravity = Vector2.ZERO
	p.light_mask = 2
	return p


## Pollen im Gegenlicht (Morgen): warm, weich, treiben mit leichtem Wind.
static func pollen(pal: Palette, w: float, ground: float) -> CPUParticles2D:
	var p := _base(64, 11.0, w, 80.0, ground - 40.0)
	p.texture = soft_dot()
	p.direction = Vector2(1, -0.12)
	p.spread = 35.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 18.0
	p.scale_amount_min = 0.22
	p.scale_amount_max = 0.55
	var c := Palette.tint(pal.sun, 0.2)
	p.color = Color(c.r, c.g, c.b, 0.75)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 1.0))
	ramp.add_point(0.5, Color(1, 1, 1, 0.55))
	ramp.add_point(0.8, Color(1, 1, 1, 1.0))
	p.color_ramp = ramp
	return p


## Glühwürmchen (Abend): wenige, langsam, pulsieren ~0,45 Hz über die Lebensdauer.
static func fireflies(pal: Palette, w: float, ground: float) -> CPUParticles2D:
	var p := _base(20, 7.0, w, ground - 300.0, ground - 30.0)
	p.texture = core_dot()
	p.direction = Vector2(1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.tangential_accel_min = -4.0
	p.tangential_accel_max = 4.0
	p.damping_min = 0.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.0
	# Kern knapp über der Glüh-Schwelle (1,35) — nur er darf glühen
	p.color = Palette.glow(Color(pal.lamp.r, pal.lamp.g, pal.lamp.b, 1.0), 1.42)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.12, Color(1, 1, 1, 1.0))
	ramp.add_point(0.30, Color(1, 1, 1, 0.12))
	ramp.add_point(0.45, Color(1, 1, 1, 1.0))
	ramp.add_point(0.62, Color(1, 1, 1, 0.12))
	ramp.add_point(0.78, Color(1, 1, 1, 1.0))
	p.color_ramp = ramp
	return p


## Staub in einem Lichtbündel (Rechenzentrum): schmaler Emitter unter der Lampe.
static func beam_dust(pal: Palette, x_center: float, top: float, ground: float) -> CPUParticles2D:
	var p := _base(22, 14.0, 150.0, top, ground - 30.0)
	p.position = Vector2(x_center, (top + ground - 30.0) * 0.5)
	p.texture = soft_dot()
	p.direction = Vector2(0.12, 1)
	p.spread = 28.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.30
	# auf fast weißer Hallenluft sind helle Körner unsichtbar → gedeckter Kühlton
	var c := Palette.shade(pal.fog, 0.4)
	p.color = Color(c.r, c.g, c.b, 0.45)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.2, Color(1, 1, 1, 1.0))
	ramp.add_point(0.55, Color(1, 1, 1, 0.5))
	ramp.add_point(0.8, Color(1, 1, 1, 1.0))
	p.color_ramp = ramp
	return p


## Papierstaub (Archiv): taumelnde helle Flocken, sehr langsam.
static func paper_dust(pal: Palette, w: float, ground: float) -> CPUParticles2D:
	var p := _base(44, 12.0, w, 60.0, ground - 40.0)
	p.texture = flake()
	p.direction = Vector2(0.6, 0.3)
	p.spread = 60.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -25.0
	p.angular_velocity_max = 25.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.color = Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 1.0))
	ramp.add_point(0.85, Color(1, 1, 1, 1.0))
	p.color_ramp = ramp
	return p
