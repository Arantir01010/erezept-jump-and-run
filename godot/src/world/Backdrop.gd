class_name Backdrop
extends Node2D
## KULISSE — helle Welt mit Luftperspektive und echter TIEFE: Tiefe entsteht
## durch Ebenen, Nebel, Unschärfe und Bewegung, nicht durch mehr Detail.
##
## Aufbau (von hinten nach vorn, alles auf Licht-Ebene 2 — Spiellichter mit
## range_item_cull_mask = 1 treffen die Kulisse nicht):
##   Himmel (fest) · Sonne + Horizontschleier (0,03) · Wolken (0,10, weich) ·
##   ferne Stadt (0,22, Blur ≈ 3 px) · Sonnenstrahlen (Morgen) · mittlere Stadt
##   (0,45, Blur ≈ 1 px) · Lampenbündel + Staub (RZ) · nahe Ebene (0,72, scharf) ·
##   Bodennebel (0,88) · Umgebungspartikel je Welt · VORDERGRUND (1,2, vor Paul
##   und Gelände, z 15, nur an den Bildrändern, Blur ≈ 1,6 px).
##
## Jede Ebene = statische Zeichnung (KulisseEbene, einmal) + „Leben"
## (KulisseLeben, reine Funktion der Zeit). Tiefenschärfe: Fern-, Mittel- und
## Wolkenebene liegen je in einer CanvasGroup mit Blur-Shader — ein Pass pro
## Ebene, nicht pro Objekt. Fällt der Gruppen-Blur aus (BLUR_ENABLED = false),
## wird die ferne Ebene stattdessen mit zwei versetzten, transparenten Kopien
## weich gezeichnet.

const BLUR_SHADER := "res://src/shaders/kulisse_blur.gdshader"
const BLUR_ENABLED := true
const FAR_BLUR := 3.0
const MID_BLUR := 1.0
const CLOUD_BLUR := 2.0
const FRONT_BLUR := 1.6
const FRONT_Z := 15            # über Paul (10), REZI (12), Gelände (2), Bausteinen (≤ 7);
                               # unter Funken/Ringen (20), Regen (30), Sprechblase (60)
const PATTERN_W := 3840.0

var pal: Palette
var level_w := 4000.0
var level_h := 1104.0
var lamps: Array = []   # Weltpositionen der Laternen (Level setzt dort Lichter)
var foreground: Parallax2D
var _blur_shader: Shader
var _web := false


func build(palette: Palette, width: float, height: float, seed_text: String) -> void:
	pal = palette
	level_w = width
	level_h = height
	z_index = -10
	light_mask = 2
	_web = OS.has_feature("web")
	if BLUR_ENABLED:
		_blur_shader = load(BLUR_SHADER)
	var ground := level_h - 3 * Game.TILE

	_sky()

	# Sonne und Horizontschleier — fast fest am Bild
	var sun_p := _parallax(0.03, true)
	sun_p.add_child(_ebene("sonne", seed_text + "sun", 1))

	# Wolken: eigenes Leben, weich
	_layer("wolken", 0.10, CLOUD_BLUR if not _web else 0.0, seed_text + "wolken")
	# Ferne Stadt: stark weich
	_layer("far", 0.22, FAR_BLUR, seed_text + "far")

	# Sonnenstrahlen (Morgenwelt): in derselben Parallaxe wie die Sonne, damit
	# sie immer von der gezeichneten Sonne ausgehen — gezeichnet über der Ferne
	if pal.world_name == "praxis-morgen":
		# ein einziges additives Rechteck — kein Engine-Repeat (Kopien würden sich addieren)
		var rp := _parallax(0.03, false)
		var sun_local := Vector2(pal.sun_pos.x * 1920.0, pal.sun_pos.y * 1080.0)
		rp.add_child(KulisseStrahlen.sun_rays(pal, Vector2(-200, -200), Vector2(PATTERN_W + 2200, 1700), sun_local, ground))

	# Mittlere Stadt: leicht weich
	_layer("mid", 0.45, MID_BLUR, seed_text + "mid")

	# Rechenzentrum: Lampenbündel von oben mit Staubkörnern darin
	if pal.weather == "innen":
		# Sichtbar ist lokal x ∈ [160, W+1760]: ein Rechteck ohne Engine-Repeat
		# (additive Kopien würden sich sonst überlagern), Staub-Emitter je Lampe
		var lp := _parallax(0.25, false)
		var gap := 640.0
		lp.add_child(KulisseStrahlen.lamp_rays(pal, Vector2(-200, -200), Vector2(PATTERN_W + 2200, 1500), gap, ground))
		var x := gap * 0.5
		while x < PATTERN_W + 1800.0:
			lp.add_child(KulissePartikel.beam_dust(pal, x, -60.0, ground))
			x += gap

	# Nahe Ebene: scharf (Engine-Repeat)
	_layer("near", 0.72, 0.0, seed_text + "near")
	# Bodennebel
	_layer("fog", 0.88, 0.0, seed_text + "fog")

	_particles(ground)
	_foreground(seed_text)


# ------------------------------------------------------------------ Aufbau

func _sky() -> void:
	var sky := Parallax2D.new()
	sky.scroll_scale = Vector2(0, 0)
	var sky_rect := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, pal.sky_top)
	g.set_color(1, pal.sky_bottom)
	g.add_point(0.55, pal.sky_top.lerp(pal.sky_bottom, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 16
	tex.height = 256
	sky_rect.texture = tex
	sky_rect.position = Vector2(-200, -200)
	sky_rect.size = Vector2(2400, 1500)
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_rect.light_mask = 2
	sky.add_child(sky_rect)
	add_child(sky)


## Parallax2D mit Musterbreite. `engine_repeat`: Engine zeichnet drei Kopien
## (für Ebenen ohne CanvasGroup); sonst zeichnen die Ebenen ihre Kopien selbst
## und die Parallaxe wickelt nur die Position.
func _parallax(scale_: float, engine_repeat: bool) -> Parallax2D:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scale_, scale_ * 0.6 + 0.4)
	p.repeat_size = Vector2(PATTERN_W, 0)
	p.repeat_times = 3 if engine_repeat else 1
	p.light_mask = 2
	add_child(p)
	return p


func _ebene(kind: String, seed_text: String, copies: int) -> KulisseEbene:
	var e := KulisseEbene.new()
	e.kind = kind
	e.pal = pal
	e.pattern_w = PATTERN_W
	e.level_h = level_h
	e.copies = copies
	e.light_mask = 2
	e.build(seed_text)
	return e


func _leben(kind: String, seed_text: String, copies: int, source: KulisseEbene) -> KulisseLeben:
	var l := KulisseLeben.new()
	l.kind = kind
	l.pal = pal
	l.source = source
	l.pattern_w = PATTERN_W
	l.level_h = level_h
	l.copies = copies
	l.light_mask = 2
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.build(seed_text)
	return l


## CanvasGroup mit Blur-Material: ein Weichzeichner-Pass für die ganze Ebene.
func _group(radius: float) -> CanvasGroup:
	var g := CanvasGroup.new()
	g.fit_margin = 12.0
	g.clear_margin = maxf(8.0, radius + 4.0)
	g.light_mask = 2
	var m := ShaderMaterial.new()
	m.shader = _blur_shader
	m.set_shader_parameter("radius_px", radius)
	g.material = m
	return g


## Eine Kulissenebene: Statik + Leben, optional in einer Blur-Gruppe.
func _layer(kind: String, scale_: float, blur: float, seed_text: String) -> void:
	var use_group := BLUR_ENABLED and blur > 0.0 and _blur_shader != null
	var p := _parallax(scale_, not use_group)
	var copies := 3 if use_group else 1
	var statik: KulisseEbene = null
	if kind in ["far", "mid", "near"]:
		statik = _ebene(kind, seed_text, copies)
	var leben := _leben(kind, seed_text, copies, statik)
	var holder: Node2D = p
	if use_group:
		holder = _group(blur)
		p.add_child(holder)
	elif blur >= 2.0 and statik:
		# Ersatz ohne Gruppen-Blur: zwei versetzte, transparente Kopien der Statik
		for off in [Vector2(-2, 0), Vector2(2, 1)]:
			var ghost := _ebene(kind, seed_text, copies)
			ghost.position = off
			ghost.modulate.a = 0.35
			holder.add_child(ghost)
	if statik:
		holder.add_child(statik)
	holder.add_child(leben)


## Umgebungspartikel je Welt (Regen gehört zum Wetter, nicht hierher).
func _particles(ground: float) -> void:
	var emitter: CPUParticles2D = null
	var scale_ := 0.6
	match pal.world_name:
		"praxis-morgen":
			emitter = KulissePartikel.pollen(pal, PATTERN_W, ground)
		"praxis-abend":
			emitter = KulissePartikel.fireflies(pal, PATTERN_W, ground)
			scale_ = 0.72
		"archiv-abend":
			emitter = KulissePartikel.paper_dust(pal, PATTERN_W, ground)
	if emitter == null:
		return
	var p := _parallax(scale_, true)
	p.add_child(emitter)


## Vordergrund: schneller als die Kamera, VOR Spieler und Gelände, nur Ränder.
func _foreground(seed_text: String) -> void:
	foreground = Parallax2D.new()
	# vertikal fast fest, damit die Randsilhouetten bei jeder Kamerahöhe am Rand bleiben
	foreground.scroll_scale = Vector2(1.2, 0.1)
	foreground.repeat_size = Vector2(PATTERN_W, 0)
	foreground.repeat_times = 1
	foreground.z_as_relative = false
	foreground.z_index = FRONT_Z
	foreground.light_mask = 2
	add_child(foreground)
	var v := KulisseVordergrund.new()
	v.pal = pal
	v.pattern_w = PATTERN_W
	v.copies = 3
	v.light_mask = 2
	v.build(seed_text)
	var use_group := BLUR_ENABLED and _blur_shader != null and not _web
	if use_group:
		var g := _group(FRONT_BLUR)
		g.add_child(v)
		foreground.add_child(g)
	else:
		foreground.add_child(v)
