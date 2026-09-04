class_name KulisseStrahlen
extends TextureRect
## LICHTSTRAHLEN — ein Rechteck mit Shader: Sonnenstrahlen in der Morgenwelt
## (god_rays.gdshader, additiv, vom sun_pos der Palette) und Deckenlampen-
## Bündel im Rechenzentrum (hall_rays.gdshader, Mix: Lücken kühl abgedunkelt,
## Bündel leicht aufgehellt). Langsam atmend über TIME im Shader — keine
## Skript-Arbeit pro Frame. Werte bleiben unter der Glüh-Schwelle: Strahlen
## hellen die Luft auf, sie leuchten nicht.

const SHADER_PATH := "res://src/shaders/god_rays.gdshader"
const HALL_SHADER_PATH := "res://src/shaders/hall_rays.gdshader"

static var _white: ImageTexture


static func _white_tex() -> ImageTexture:
	if _white == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		_white = ImageTexture.create_from_image(img)
	return _white


## Sonnenstrahlen: `sun_local` in den Koordinaten der Ebene, in der das Rechteck liegt.
static func sun_rays(pal: Palette, origin: Vector2, size: Vector2, sun_local: Vector2, ground_y: float) -> KulisseStrahlen:
	var r := _make(origin, size)
	var m := r.material as ShaderMaterial
	m.set_shader_parameter("mode", 0)
	m.set_shader_parameter("source", sun_local)
	m.set_shader_parameter("ray_color", Color(pal.sun.r, pal.sun.g, pal.sun.b, 1.0))
	m.set_shader_parameter("strength", 0.15)
	m.set_shader_parameter("density1", 9.0)
	m.set_shader_parameter("density2", 23.0)
	m.set_shader_parameter("speed", 0.05)
	m.set_shader_parameter("fade_start", 110.0)
	m.set_shader_parameter("fade_end", 1900.0)
	m.set_shader_parameter("ground_y", ground_y)
	return r


## Deckenlampen-Bündel in der hellen Halle: periodisch alle `gap` Pixel, von oben
## bis zur Bodenlinie. Eigener Mix-Shader (hall_rays): auf fast weißer Luft
## zeigt additives Licht nichts — die Lücken werden hauchdünn kühl abgedunkelt,
## die Bündel minimal aufgehellt. Nichts glüht.
static func lamp_rays(pal: Palette, origin: Vector2, size: Vector2, gap: float, ground_y: float) -> KulisseStrahlen:
	var r := _make(origin, size, HALL_SHADER_PATH)
	var m := r.material as ShaderMaterial
	m.set_shader_parameter("lamp_color", Color(pal.lamp.r, pal.lamp.g, pal.lamp.b, 1.0))
	var sh := Palette.shade(pal.shadow, 0.2)
	m.set_shader_parameter("shade_color", Color(sh.r, sh.g, sh.b, 1.0))
	m.set_shader_parameter("strength", 0.10)
	m.set_shader_parameter("gap_dark", 0.075)
	m.set_shader_parameter("speed", 0.04)
	m.set_shader_parameter("lamp_gap", gap)
	m.set_shader_parameter("lamp_width", 150.0)
	m.set_shader_parameter("ground_y", ground_y)
	return r


static func _make(origin: Vector2, size: Vector2, shader_path := SHADER_PATH) -> KulisseStrahlen:
	var r := KulisseStrahlen.new()
	r.texture = _white_tex()
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = origin
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.light_mask = 2
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	m.set_shader_parameter("rect_origin", origin)
	m.set_shader_parameter("rect_size", size)
	r.material = m
	return r
