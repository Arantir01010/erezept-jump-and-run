class_name Terrain
extends Node2D
## GELÄNDE — aus dem ASCII-Raster werden zusammengefasste Rechtecke:
## Kollision (StaticBody2D), Lichtverdecker (LightOccluder2D für Sonnen- und
## REZI-Schatten, mit SDF für den Bodennebel) und Bild nach den Celeste-Regeln:
##   helle Kappe oben (Licht von oben) · Grundfarbe als Masse · dunkler Fuß ·
##   dunkle (nicht schwarze) Kontur · Kanten nie ganz gerade · zufällige
##   Varianten (Nieten, Fugen, Lüfter) · kein Glühen.
## Licht ist Material: Kappe UND Blockkörper tragen Normal-Maps (CanvasTexture,
## siehe terrain/BlockTexture.gd) — Sonne und REZI-Licht erzeugen Kantenlicht.
## Das Gelände selbst wird einmal gezeichnet; alles Lebendige sind eigene Kinder:
##   terrain/Flora.gd     Gras, Moos, Ranken im Wind (Paul biegt Halme)
##   terrain/GroundFog.gd Bodennebel über die 2D-SDF
##   terrain/Puddles.gd   Pfützen mit Screen-Spiegelung (nur Regen)
##   `#` Boden/Wand   `=` Plattform (von unten durchspringbar)   `G` Gold-Pad
##   `A` Akzentblock  `~` Glas   `%` Dunkelraum   `|` Deko-Strebe (keine Kollision)

const CAP_H := 20.0
const BEVEL := 7.0

var data: LevelData
var pal: Palette
var rects: Array = []
var struts: Array = []
var top_edges: Array = []
var _time := 0.0
var _details: Array = []
var _cap_tex: CanvasTexture
var _block_tex: CanvasTexture
var _edge_tex := {}
var _cap_edges: Array = []   # {rect, pts: PackedVector2Array} unregelmäßige Kappen
var _rng := RandomNumberGenerator.new()
var _flora: TerrainFlora
var _fog: GroundFog
var _puddles: TerrainPuddles
var _glass: _GlassSheen


func build(level_data: LevelData, palette: Palette) -> void:
	data = level_data
	pal = palette
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rng.seed = hash(data.id)
	_make_cap_texture()
	_block_tex = BlockTexture.for_palette(pal)
	_edge_tex = BlockTexture.edge_textures(pal)
	_merge_rects()
	for r in rects:
		var ch: String = r["ch"]
		var rect: Rect2 = r["rect"]
		if ch == "|":
			continue
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var occ_rect := rect
		if ch == "=":
			var thick := 18.0
			shape.size = Vector2(rect.size.x, thick)
			cs.position = rect.position + Vector2(rect.size.x / 2.0, thick / 2.0)
			cs.one_way_collision = true
			cs.one_way_collision_margin = 10.0
			occ_rect = Rect2(rect.position, Vector2(rect.size.x, thick))
		else:
			shape.size = rect.size
			cs.position = rect.get_center()
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
		if ch != "~":
			_add_occluder(occ_rect)
	_collect_edges()
	_make_details()
	z_index = 2
	_make_children()


## Kappenstreifen 64×20: Diffuse (hell oben → Kappenfarbe) + Normal-Map (obere
## Reihen zeigen nach oben, Rest flach). Godot-2D-Normalen: +Y = oben.
## Regen: nasse Kappe — Specular deutlich stärker, Glanzlichter von REZI und Sonne.
func _make_cap_texture() -> void:
	var w := 64
	var h := 20
	var diff := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var norm := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = hash(data.id) + 7
	n.frequency = 0.15
	for x in w:
		var jitter := n.get_noise_2d(x, 0.0) * 1.5
		for y in h:
			var t := clampf((y + jitter) / float(h), 0.0, 1.0)
			var c: Color
			if t < 0.16:
				c = pal.cap_light
			elif t < 0.30:
				c = pal.cap_light.lerp(pal.cap, (t - 0.16) / 0.14)
			else:
				c = pal.cap.lerp(Palette.shade(pal.cap, 0.18), (t - 0.30) / 0.70)
			c = c.lerp(c * (1.0 + n.get_noise_2d(x * 2.0, y * 2.0) * 0.08), 1.0)
			diff.set_pixel(x, y, c)
			var nv := Vector3(0, 0, 1)
			if t < 0.22:
				nv = Vector3(0.0, 0.85, 0.53)
			elif t < 0.40:
				nv = Vector3(0.0, 0.35, 0.94)
			norm.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	_cap_tex = CanvasTexture.new()
	_cap_tex.diffuse_texture = ImageTexture.create_from_image(diff)
	_cap_tex.normal_texture = ImageTexture.create_from_image(norm)
	if pal.weather == "regen":
		_cap_tex.specular_color = Color(1.0, 1.0, 1.0)
		_cap_tex.specular_shininess = 0.85
	else:
		_cap_tex.specular_color = Color(0.9, 0.85, 0.7)
		_cap_tex.specular_shininess = 0.35


func _add_occluder(r: Rect2) -> void:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = poly
	occ.occluder_light_mask = 1
	occ.sdf_collision = true   # Bodennebel liest die SDF (terrain/GroundFog.gd)
	add_child(occ)


func _merge_rects() -> void:
	var w := data.width
	var h := data.height
	var used := []
	for y in h:
		used.append([])
		for x in w:
			used[y].append(false)
	for y in h:
		for x in w:
			if used[y][x]:
				continue
			var ch := data.char_at(x, y)
			if ch == ".":
				continue
			if ch == "|":
				used[y][x] = true
				struts.append(Vector2((x + 0.5) * Game.TILE, y * Game.TILE))
				continue
			var x2 := x
			while x2 + 1 < w and not used[y][x2 + 1] and data.char_at(x2 + 1, y) == ch:
				x2 += 1
			var y2 := y
			if ch == "#" or ch == "%":
				var grow := true
				while grow and y2 + 1 < h:
					for xx in range(x, x2 + 1):
						if used[y2 + 1][xx] or data.char_at(xx, y2 + 1) != ch:
							grow = false
							break
					if grow:
						y2 += 1
			for yy in range(y, y2 + 1):
				for xx in range(x, x2 + 1):
					used[yy][xx] = true
			rects.append({"ch": ch, "rect": Rect2(x * Game.TILE, y * Game.TILE,
				(x2 - x + 1) * Game.TILE, (y2 - y + 1) * Game.TILE)})


func _collect_edges() -> void:
	for y in data.height:
		var x := 0
		while x < data.width:
			if data.is_solid(x, y) and not data.is_solid(x, y - 1) and data.char_at(x, y) != "%":
				var x2 := x
				while x2 + 1 < data.width and data.is_solid(x2 + 1, y) and not data.is_solid(x2 + 1, y - 1) and data.char_at(x2 + 1, y) == data.char_at(x, y):
					x2 += 1
				var er := Rect2(x * Game.TILE, y * Game.TILE, (x2 - x + 1) * Game.TILE, 4.0)
				top_edges.append({"rect": er, "ch": data.char_at(x, y)})
				# Unregelmäßige Kappenkante: leicht gewellte Oberlinie
				var pts := PackedVector2Array()
				var n := int(er.size.x / 16.0) + 1
				for i in n + 1:
					var px := er.position.x + minf(i * 16.0, er.size.x)
					var dy := _rng.randf_range(-2.5, 1.5) if i > 0 and i < n else 0.0
					pts.append(Vector2(px, er.position.y + dy))
				_cap_edges.append({"rect": er, "pts": pts, "ch": data.char_at(x, y)})
				x = x2 + 1
			else:
				x += 1


## Große Details (Fugen, Nieten, Gitter, Kanäle, Risse) — sparsam, weil die
## Blocktextur selbst schon Paneele und Korn trägt. Gras und Moos macht Flora.
func _make_details() -> void:
	for r in rects:
		var ch: String = r["ch"]
		var rect: Rect2 = r["rect"]
		if ch != "#":
			continue
		if rect.size.x >= Game.TILE * 4:
			var x := rect.position.x + _rng.randf_range(80, 160)
			while x < rect.end.x - 40:
				_details.append({"k": "fuge", "a": Vector2(x, rect.position.y + 22), "b": Vector2(x, rect.end.y - 6)})
				x += _rng.randf_range(140, 300)
		if rect.size.x >= Game.TILE * 2 and rect.size.y >= Game.TILE * 2:
			for p in [rect.position + Vector2(12, 26), Vector2(rect.end.x - 12, rect.position.y + 26)]:
				_details.append({"k": "niete", "a": p, "b": p})
		var n := int(rect.get_area() / (Game.TILE * Game.TILE * 12))
		for i in mini(n, 10):
			var p := rect.position + Vector2(_rng.randf_range(24, maxf(25.0, rect.size.x - 60)), _rng.randf_range(30, maxf(31.0, rect.size.y - 24)))
			var kind: String = ["gitter", "kanal", "riss"][_rng.randi() % 3]
			_details.append({"k": kind, "a": p, "b": p + Vector2(_rng.randf_range(30, 70), 0), "ph": _rng.randf()})


## Lebendige Kinder: Flora (Wind), Bodennebel (SDF), Pfützen (Regen), Glas-Sheen.
func _make_children() -> void:
	_flora = TerrainFlora.new()
	_flora.build(pal, _cap_edges, rects, _rng)
	add_child(_flora)
	var fog_strength := GroundFog.strength_for(pal)
	if fog_strength > 0.0:
		_fog = GroundFog.new()
		_fog.build(pal, Rect2(0, 0, data.world_width(), data.world_height()), fog_strength)
		add_child(_fog)
	if pal.weather == "regen":
		_puddles = TerrainPuddles.new()
		_puddles.build(pal, _cap_edges, _rng)
		add_child(_puddles)
	var glass: Array = []
	for r in rects:
		if r["ch"] == "~":
			glass.append(r["rect"])
	if not glass.is_empty():
		_glass = _GlassSheen.new()
		_glass.glass = glass
		add_child(_glass)


func _process(delta: float) -> void:
	_time += delta
	var lvl = get_parent()
	var player = null
	if lvl != null and lvl.get("player") != null:
		player = lvl.player
	if _flora:
		_flora.tick(_time, player)
	if _fog:
		_fog.tick(_time)
	if _puddles:
		_puddles.tick(_time)


func _draw() -> void:
	for s in struts:
		draw_line(s, s + Vector2(0, Game.TILE), Color(pal.near.r, pal.near.g, pal.near.b, 0.08), 3.0, true)
	for r in rects:
		var ch: String = r["ch"]
		var rect: Rect2 = r["rect"]
		match ch:
			"#": _draw_block(rect, Color.WHITE, true)
			"%": draw_rect(rect, pal.fill_dark)
			"~": _draw_glass(rect)
			"=": _draw_platform(rect)
			"G": _draw_block(rect, _modulate_for(pal.fill.lerp(Palette.GOLD, 0.22)), true)
			"A": _draw_crate(rect)
	for d in _details:
		_draw_detail(d)
	# Kappen: normal-gemappter Streifen + gewellte helle Oberlinie
	for e in _cap_edges:
		var er: Rect2 = e["rect"]
		var ch: String = e["ch"]
		if ch == "=":
			continue
		var cap_r := Rect2(er.position.x + 1, er.position.y, er.size.x - 2, CAP_H)
		draw_texture_rect(_cap_tex, cap_r, true)
		if ch == "G":
			draw_rect(cap_r, Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.35))
		var pts: PackedVector2Array = e["pts"]
		draw_polyline(pts, pal.cap_light, 3.0, true)
		draw_polyline(pts, Color(1, 1, 1, 0.35), 1.0, true)
		# Kontur der Kappe
		var o := PackedVector2Array()
		for p in pts:
			o.append(p + Vector2(0, -1.5))
		draw_polyline(o, pal.outline, 1.5, true)


## Modulation, mit der die (in pal.fill gebackene) Blocktextur eine Zielfarbe trifft.
func _modulate_for(target: Color) -> Color:
	return Color(clampf(target.r / maxf(pal.fill.r, 0.02), 0.0, 2.0),
		clampf(target.g / maxf(pal.fill.g, 0.02), 0.0, 2.0),
		clampf(target.b / maxf(pal.fill.b, 0.02), 0.0, 2.0))


func _draw_block(rect: Rect2, mod: Color, structured: bool) -> void:
	# Kontur (dunkel, nie schwarz)
	draw_rect(Rect2(rect.position - Vector2(2, 2), rect.size + Vector2(4, 4)), pal.outline)
	# Masse: kachelbare Blocktextur mit Normal-Map, in Weltkoordinaten gekachelt,
	# damit benachbarte Rechtecke nahtlos aneinanderschließen
	if structured and _block_tex:
		draw_texture_rect_region(_block_tex, rect, Rect2(rect.position, rect.size), mod, false, false)
	else:
		draw_rect(rect, pal.fill * mod)
	# Fuß: dunkler, kühler (Hue-Shift) — impliziertes Licht von oben
	var foot := minf(rect.size.y * 0.35, 60.0)
	for k in 4:
		var f := k / 4.0
		draw_rect(Rect2(rect.position.x, rect.end.y - foot * (1.0 - f), rect.size.x, foot / 4.0 + 1),
			Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, 0.18 + f * 0.16))
	# Außenkanten mit gekippten Normalen: links, rechts, unten (oben übernimmt die Kappe)
	var top := rect.position.y + CAP_H - 2.0
	var side_h := rect.size.y - CAP_H + 2.0
	if side_h > 2.0 and not _edge_tex.is_empty():
		draw_texture_rect(_edge_tex["l"], Rect2(rect.position.x, top, BEVEL, side_h), false)
		draw_texture_rect(_edge_tex["r"], Rect2(rect.end.x - BEVEL, top, BEVEL, side_h), false)
		draw_texture_rect(_edge_tex["b"], Rect2(rect.position.x, rect.end.y - BEVEL, rect.size.x, BEVEL), false)


func _draw_platform(rect: Rect2) -> void:
	var slab := Rect2(rect.position.x, rect.position.y, rect.size.x, 18.0)
	# Schlagschatten darunter
	for k in 3:
		draw_rect(Rect2(slab.position.x + 3 + k * 3, slab.end.y + k * 4, slab.size.x - 6 - k * 6, 4), Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, 0.16 - k * 0.04))
	draw_rect(Rect2(slab.position - Vector2(2, 2), slab.size + Vector2(4, 4)), pal.outline)
	draw_rect(slab, pal.cap)
	draw_texture_rect(_cap_tex, Rect2(slab.position, Vector2(slab.size.x, 18.0)), true)
	draw_rect(Rect2(slab.position.x + 2, slab.position.y, slab.size.x - 4, 3), pal.cap_light)
	# Kanten der Platte: unten und seitlich abgeschrägt (Normal-Map)
	if not _edge_tex.is_empty():
		draw_texture_rect(_edge_tex["b"], Rect2(slab.position.x, slab.end.y - 5.0, slab.size.x, 5.0), false)
		draw_texture_rect(_edge_tex["l"], Rect2(slab.position.x, slab.position.y + 3.0, 5.0, slab.size.y - 3.0), false)
		draw_texture_rect(_edge_tex["r"], Rect2(slab.end.x - 5.0, slab.position.y + 3.0, 5.0, slab.size.y - 3.0), false)
	# Halterungen: kleine Konsolen unter der Platte
	var n := int(rect.size.x / 48.0)
	for i in n:
		var x := rect.position.x + 24 + i * 48.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, slab.end.y), Vector2(x + 8, slab.end.y), Vector2(x, slab.end.y + 10)]), pal.shadow)


func _draw_glass(rect: Rect2) -> void:
	draw_rect(rect, Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.22))
	draw_rect(rect, pal.outline, false, 2.0)
	draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6, rect.size.x - 12, 3), Color(1, 1, 1, 0.35))


func _draw_crate(rect: Rect2) -> void:
	_draw_block(rect, _modulate_for(Palette.tint(pal.fill, 0.12)), true)
	var c := Color(pal.outline.r, pal.outline.g, pal.outline.b, 0.55)
	draw_line(rect.position + Vector2(8, 8), rect.end - Vector2(8, 8), c, 3.0, true)
	draw_line(Vector2(rect.end.x - 8, rect.position.y + 8), Vector2(rect.position.x + 8, rect.end.y - 8), c, 3.0, true)
	draw_rect(Rect2(rect.position.x + 6, rect.position.y + 6, rect.size.x - 12, 4), Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.5))


func _draw_detail(d: Dictionary) -> void:
	var a: Vector2 = d["a"]
	var b: Vector2 = d["b"]
	match d["k"]:
		"fuge":
			draw_line(a, b, Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, 0.45), 2.0, true)
			draw_line(a + Vector2(2, 0), b + Vector2(2, 0), Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.10), 1.0, true)
		"niete":
			draw_circle(a, 3.5, pal.shadow)
			draw_circle(a + Vector2(-0.7, -0.7), 2.2, Palette.tint(pal.cap, 0.2))
		"gitter":
			var w := b.x - a.x
			draw_rect(Rect2(a.x, a.y, w, 16), Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, 0.5))
			for i in int(w / 6.0):
				draw_line(Vector2(a.x + 3 + i * 6, a.y + 2), Vector2(a.x + 3 + i * 6, a.y + 14), Color(pal.cap.r, pal.cap.g, pal.cap.b, 0.5), 1.5)
		"kanal":
			draw_rect(Rect2(a.x, a.y, b.x - a.x, 8), Palette.shade(pal.fill, 0.15))
			draw_rect(Rect2(a.x, a.y, b.x - a.x, 2), Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.25))
		"riss":
			var pts := PackedVector2Array([a, a + Vector2(9, 7), a + Vector2(6, 16), a + Vector2(14, 26)])
			draw_polyline(pts, Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, 0.6), 1.5, true)


## Glas-Lichtstreifen: das einzige, was am Gelände selbst pro Frame läuft —
## deshalb ein eigener kleiner Knoten, das Gelände bleibt statisch.
class _GlassSheen extends Node2D:
	var glass: Array = []
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var f := fmod(_t * 0.10, 1.0)
		for rect in glass:
			var r: Rect2 = rect
			var x := r.position.x + r.size.x * f
			draw_rect(Rect2(x, r.position.y + 2, minf(46.0, r.end.x - 2 - x), r.size.y - 4), Color(1, 1, 1, 0.08))
