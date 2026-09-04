class_name TerrainPuddles
extends Node2D
## PFÜTZEN — Regenwelt: schmale Streifen auf Standflächen spiegeln das Bild darüber
## (Screen-Texture, vertikal gespiegelt, leicht verwellt). Liegt über Paul (z 11),
## damit er sich spiegelt; der Streifen ist nur 8 px hoch und alpha ≈ 0,25.
## Vertex-Kodierung: UV.x = Position entlang der Pfütze (px), UV.y = Tiefe (px),
## COLOR.a = weiche Ränder. Gezeichnet wird einmal; pro Frame nur zwei Uniforms.

const SHADER := preload("res://src/shaders/puddle.gdshader")
const DEPTH := 10.0

var mat: ShaderMaterial
var _polys: Array = []


func build(pal: Palette, cap_edges: Array, rng: RandomNumberGenerator) -> void:
	z_as_relative = false
	z_index = 11
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tint", pal.sky_top.lerp(pal.cap_light, 0.35))
	mat.set_shader_parameter("strength", 0.30)
	mat.set_shader_parameter("depth_px", DEPTH)
	mat.set_shader_parameter("mirror_scale", 5.0)
	material = mat
	for e in cap_edges:
		if e["ch"] == "~":
			continue
		var er: Rect2 = e["rect"]
		# Pfützen sammeln sich in Senken: Abschnitte von 70–230 px mit weichen Enden
		var x := er.position.x + rng.randf_range(8.0, 70.0)
		while x < er.end.x - 44.0:
			var w := minf(rng.randf_range(70.0, 230.0), er.end.x - 6.0 - x)
			if w > 40.0 and rng.randf() < 0.8:
				_add_strip(x, er.position.y + 2.0, w)
			x += w + rng.randf_range(50.0, 240.0)
	queue_redraw()


## Pro Frame: Zeit und Screen-UV je Welt-Pixel (Kamera-Zoom) an den Shader.
func tick(t: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("t", t)
	var vp := get_viewport()
	if vp:
		var scale_y := vp.get_canvas_transform().get_scale().y
		var vis_h := maxf(1.0, vp.get_visible_rect().size.y)
		mat.set_shader_parameter("uv_per_px", scale_y / vis_h)


func _add_strip(x0: float, y0: float, w: float) -> void:
	var x1 := x0 + w * 0.22
	var x2 := x0 + w * 0.78
	var x3 := x0 + w
	var pts := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x2, y0), Vector2(x3, y0),
		Vector2(x3, y0 + DEPTH), Vector2(x2, y0 + DEPTH), Vector2(x1, y0 + DEPTH), Vector2(x0, y0 + DEPTH)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(x1 - x0, 0), Vector2(x2 - x0, 0), Vector2(w, 0),
		Vector2(w, DEPTH), Vector2(x2 - x0, DEPTH), Vector2(x1 - x0, DEPTH), Vector2(0, DEPTH)])
	var c0 := Color(1, 1, 1, 0)
	var c1 := Color(1, 1, 1, 1)
	var cols := PackedColorArray([c0, c1, c1, c0, c0, c1, c1, c0])
	_polys.append({"p": pts, "c": cols, "u": uvs})


func _draw() -> void:
	for q in _polys:
		draw_polygon(q["p"], q["c"], q["u"])
