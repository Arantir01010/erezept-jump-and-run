class_name GroundFog
extends Node2D
## BODENNEBEL — ein levelweiter Knoten, dessen Shader die 2D-SDF der Gelände-
## Occluder liest (LightOccluder2D.sdf_collision) und Nebel in pal.fog nur nah am
## Gelände legt: dicht direkt über Standflächen, oben nichts. Sehr subtil.
## Liegt als Terrain-Kind auf z 2 (über dem Gelände, unter Bausteinen ≥ 3, Paul 10).

const SHADER := preload("res://src/shaders/ground_fog.gdshader")

var mat: ShaderMaterial
var _rect := Rect2()


## Nebelstärke je Welt: Regen deutlich, Morgen leicht, Abend/Archiv ein Hauch, RZ nichts.
static func strength_for(p: Palette) -> float:
	match p.world_name:
		"netz-regen": return 0.17
		"praxis-morgen": return 0.09
		"praxis-abend": return 0.06
		"archiv-abend": return 0.05
	return 0.0


func build(pal: Palette, world_rect: Rect2, strength: float) -> void:
	_rect = world_rect.grow(240.0)
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("fog_color", pal.fog)
	mat.set_shader_parameter("max_alpha", clampf(strength, 0.0, 0.18))
	mat.set_shader_parameter("range_px", 110.0)
	material = mat
	queue_redraw()


## Pro Frame: Zeit und Reichweite in Screen-Pixeln (Zoom und Fensterskalierung).
func tick(t: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("t", t)
	var vp := get_viewport()
	var win := get_window()
	if vp and win:
		var zoom_s := vp.get_canvas_transform().get_scale().y
		var vis_h := maxf(1.0, vp.get_visible_rect().size.y)
		var px_scale := zoom_s * float(win.size.y) / vis_h
		mat.set_shader_parameter("range_px", 110.0 * px_scale)


func _draw() -> void:
	draw_rect(_rect, Color.WHITE)
