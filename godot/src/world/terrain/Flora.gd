class_name TerrainFlora
extends Node2D
## FLORA — Gras, Moos und Ranken auf dem Gelände als Polygone mit Wind-Shader.
## Wird genau einmal gezeichnet (kein Redraw pro Frame). Die Bewegung kommt aus
## dem Vertex-Shader (src/shaders/wind.gdshader): Wind als reine Funktion der
## Zeit, Paul biegt Halme im Umkreis von ±40 px und sie federn nach.
## Kodierung je Vertex: UV.x = Büschel-Index + Phase, UV.y = Abstand zur Wurzel (px).
## Büschel 0 ist der ruhende Eintrag (Wurzel weit weg) für Moos, das nur atmet.

const SHADER := preload("res://src/shaders/wind.gdshader")
const MAX_CLUSTERS := 128
const PUSH_RADIUS := 40.0

var pal: Palette
var mat: ShaderMaterial
var wind_strength := 0.5
var _clusters := PackedFloat32Array()   # 4 Floats je Büschel: x, y, kick_t, kick_dir
var _inside := PackedByteArray()
var _count := 0
var _polys: Array = []   # {p: PackedVector2Array, c: PackedColorArray, u: PackedVector2Array}
var _rng: RandomNumberGenerator


## Windstärke je Welt: Regen stark, Morgen leicht, Rechenzentrum fast null, Archiv null.
static func wind_for(p: Palette) -> float:
	match p.world_name:
		"netz-regen": return 1.0
		"praxis-morgen": return 0.5
		"praxis-abend": return 0.4
		"rz-hell": return 0.06
		"archiv-abend": return 0.0
	return 0.4


## Abstand der Grasbüschel auf Standflächen (px) — Innenwelten fast kahl.
static func spacing_for(p: Palette) -> float:
	match p.world_name:
		"netz-regen": return 95.0
		"praxis-morgen": return 105.0
		"praxis-abend": return 115.0
		"rz-hell": return 360.0
		"archiv-abend": return 250.0
	return 120.0


func build(palette: Palette, cap_edges: Array, rects: Array, rng: RandomNumberGenerator) -> void:
	pal = palette
	_rng = rng
	wind_strength = wind_for(pal)
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("push_radius", PUSH_RADIUS)
	material = mat
	_clusters.resize(MAX_CLUSTERS * 4)
	_clusters.fill(0.0)
	_inside.resize(MAX_CLUSTERS)
	_inside.fill(0)
	# Büschel 0: ruhend, weit außerhalb — für Moos ohne Paul-Kontakt
	_clusters[0] = -100000.0
	_clusters[1] = -100000.0
	_clusters[2] = -1000.0
	_count = 1
	var outdoor := pal.weather != "innen"
	var spacing := spacing_for(pal)
	# Grasbüschel und kleine Sträucher auf Standflächen
	for e in cap_edges:
		var er: Rect2 = e["rect"]
		if e["ch"] != "#" or er.size.x < Game.TILE * 2:
			continue
		var x := er.position.x + _rng.randf_range(16.0, spacing * 0.6)
		while x < er.end.x - 14.0:
			var roll := _rng.randf()
			if roll < 0.62:
				_add_tuft(Vector2(x, er.position.y), _rng.randf_range(0.75, 1.3))
			elif roll < 0.78 and outdoor:
				_add_shrub(Vector2(x, er.position.y), _rng.randf_range(0.8, 1.15))
			x += spacing * _rng.randf_range(0.55, 1.45)
	# Moos an Blockflächen (unter der Kappe und verstreut) — nur draußen
	if outdoor:
		for r in rects:
			if r["ch"] != "#":
				continue
			var rect: Rect2 = r["rect"]
			var n := mini(int(rect.get_area() / (Game.TILE * Game.TILE * 12.0)), 6)
			for i in n:
				var p := rect.position + Vector2(_rng.randf_range(16.0, maxf(17.0, rect.size.x - 16.0)),
					_rng.randf_range(24.0, maxf(25.0, rect.size.y - 12.0)))
				_add_moss(p, _rng.randf_range(0.7, 1.2))
		# Ranken unter Plattformen (sparsam)
		for r in rects:
			if r["ch"] != "=" or _rng.randf() > 0.3:
				continue
			var rect: Rect2 = r["rect"]
			var x := rect.position.x + _rng.randf_range(14.0, maxf(15.0, rect.size.x - 14.0))
			_add_vine(Vector2(x, rect.position.y + 18.0), _rng.randf_range(0.8, 1.2))
	mat.set_shader_parameter("clusters", _clusters)
	queue_redraw()


## Pro Frame: Zeit und Paul-Position an den Shader; Kick beim Verlassen des Umkreises.
func tick(t: float, player: Node2D) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("t", t)
	if player == null:
		return
	var p := player.global_position
	mat.set_shader_parameter("player_pos", p)
	var dirty := false
	for i in range(1, _count):
		var cx: float = _clusters[i * 4]
		var cy: float = _clusters[i * 4 + 1]
		var inside := absf(p.x - cx) < PUSH_RADIUS + 4.0 and absf(p.y - cy) < 70.0
		if _inside[i] == 1 and not inside:
			_clusters[i * 4 + 2] = t
			_clusters[i * 4 + 3] = 1.0 if p.x > cx else -1.0
			dirty = true
		_inside[i] = 1 if inside else 0
	if dirty:
		mat.set_shader_parameter("clusters", _clusters)


func _draw() -> void:
	for q in _polys:
		draw_polygon(q["p"], q["c"], q["u"])


# ------------------------------------------------------------------ Pflanzen

func _new_cluster(root: Vector2) -> int:
	if _count >= MAX_CLUSTERS:
		return -1
	var i := _count
	_clusters[i * 4] = root.x
	_clusters[i * 4 + 1] = root.y
	_clusters[i * 4 + 2] = -1000.0
	_clusters[i * 4 + 3] = 0.0
	_count += 1
	return i


## Halm als schmales Trapez: breit an der Wurzel, spitz oben. Zwei Lagen
## (dunkel breit, hell schmal) wie die alte Linienzeichnung.
func _blade(idx: int, ph: float, base: Vector2, tip: Vector2, half_w: float, col_base: Color, col_tip: Color) -> void:
	var len := base.distance_to(tip)
	var code := float(idx) + clampf(ph, 0.02, 0.98)
	var pts := PackedVector2Array([base + Vector2(-half_w, 0), base + Vector2(half_w, 0),
		tip + Vector2(half_w * 0.22, 0), tip + Vector2(-half_w * 0.22, 0)])
	var uvs := PackedVector2Array([Vector2(code, 0), Vector2(code, 0), Vector2(code, len), Vector2(code, len)])
	var cols := PackedColorArray([col_base, col_base, col_tip, col_tip])
	_polys.append({"p": pts, "c": cols, "u": uvs})


## Blatt als kleines Dreieck an einer Spitze; die Fläche bewegt sich wie die Spitze.
func _leaf(idx: int, ph: float, tip: Vector2, h: float, dir: float, size: float, col: Color) -> void:
	var code := float(idx) + clampf(ph, 0.02, 0.98)
	var pts := PackedVector2Array([tip, tip + Vector2(dir * size, -size * 0.35), tip + Vector2(dir * size * 0.55, size * 0.45)])
	var uvs := PackedVector2Array([Vector2(code, h), Vector2(code, h + size * 0.5), Vector2(code, h + size * 0.3)])
	var cols := PackedColorArray([col, Palette.tint(col, 0.25), col])
	_polys.append({"p": pts, "c": cols, "u": uvs})


func _add_tuft(root: Vector2, s: float) -> void:
	var idx := _new_cluster(root)
	if idx < 0:
		return
	var n := 5 + _rng.randi() % 3
	var lean_dir := _rng.randf_range(-1.0, 1.0)
	for i in n:
		var f := float(i) - (n - 1) * 0.5
		var bx := root.x + f * 3.2 * s + _rng.randf_range(-0.8, 0.8)
		var len := (13.0 + _rng.randf_range(0.0, 7.0)) * s * (1.0 - 0.14 * absf(f))
		var lean := f * 2.4 * s + lean_dir * 2.0 + _rng.randf_range(-1.5, 1.5)
		var ph := _rng.randf()
		var base := Vector2(bx, root.y + 1.0)
		var tip := Vector2(bx + lean, root.y - len)
		_blade(idx, ph, base, tip, 1.5 * s, pal.plant_dark, pal.plant_dark)
		_blade(idx, ph, base, tip, 0.75 * s, pal.plant_dark.lerp(pal.plant, 0.5), Palette.tint(pal.plant, 0.3))


## Kleiner Strauch: drei bis vier Stängel mit Blättern an den Spitzen.
func _add_shrub(root: Vector2, s: float) -> void:
	var idx := _new_cluster(root)
	if idx < 0:
		return
	var n := 3 + _rng.randi() % 2
	for i in n:
		var f := float(i) - (n - 1) * 0.5
		var bx := root.x + f * 2.5 * s
		var len := (16.0 + _rng.randf_range(0.0, 9.0)) * s * (1.0 - 0.1 * absf(f))
		var lean := f * 5.0 * s + _rng.randf_range(-2.0, 2.0)
		var ph := _rng.randf()
		var base := Vector2(bx, root.y + 1.0)
		var tip := Vector2(bx + lean, root.y - len)
		_blade(idx, ph, base, tip, 1.2 * s, Palette.shade(pal.plant_dark, 0.15), pal.plant_dark)
		var leaf_col := pal.plant if i % 2 == 0 else pal.plant_dark.lerp(pal.plant, 0.6)
		_leaf(idx, ph, tip, len, 1.0 if f >= 0.0 else -1.0, 6.5 * s, leaf_col)
		_leaf(idx, ph, tip + Vector2(0, 5.0 * s), len - 5.0 * s, -1.0 if f >= 0.0 else 1.0, 5.0 * s, leaf_col)


## Moosfleck: zwei weiche Blobs, kaum Bewegung (nur der obere Rand atmet).
func _add_moss(p: Vector2, s: float) -> void:
	var code := 0.0 + _rng.randf_range(0.05, 0.95)
	for k in 2:
		var r := (6.5 if k == 0 else 4.0) * s
		var c := Vector2(p.x + (0.0 if k == 0 else _rng.randf_range(-5.0, 5.0) * s), p.y + (0.0 if k == 0 else -2.0 * s))
		var col := Color(pal.plant_dark.r, pal.plant_dark.g, pal.plant_dark.b, 0.55) if k == 0 else Color(pal.plant.r, pal.plant.g, pal.plant.b, 0.4)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 9:
			var a := TAU * i / 9.0
			var rr := r * (0.85 + 0.15 * sin(a * 3.0 + s * 7.0))
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
			# Höhe über dem unteren Rand → obere Punkte bewegen sich minimal
			uvs.append(Vector2(code, maxf(0.0, r - sin(a) * rr) * 0.5))
			cols.append(col)
		_polys.append({"p": pts, "c": cols, "u": uvs})


## Ranke unter einer Plattform: hängt herab, die Spitze schwingt.
func _add_vine(root: Vector2, s: float) -> void:
	var idx := _new_cluster(root)
	if idx < 0:
		return
	var n := 2 + _rng.randi() % 2
	for i in n:
		var f := float(i) - (n - 1) * 0.5
		var bx := root.x + f * 4.0 * s
		var len := (14.0 + _rng.randf_range(0.0, 12.0)) * s
		var ph := _rng.randf()
		var base := Vector2(bx, root.y - 1.0)
		var tip := Vector2(bx + f * 2.0 + _rng.randf_range(-2.0, 2.0), root.y + len)
		_blade(idx, ph, base, tip, 1.1 * s, pal.plant_dark, pal.plant_dark.lerp(pal.plant, 0.5))
		_leaf(idx, ph, tip, len, 1.0 if i % 2 == 0 else -1.0, 4.5 * s, pal.plant)
