class_name BlockTexture
extends RefCounted
## BLOCKTEXTUR — je Welt eine kachelbare Blocktextur (Diffuse + Normal-Map) aus
## einem prozeduralen Höhenfeld: Paneele mit abgeschrägten Kanten (Bevel), Fugen,
## Nieten, Lüfterschlitze, Risse, feines Korn. Die Normal-Map macht Sonne und
## REZI-Licht als Kantenlicht sichtbar (2,5-D wie Rayman Legends).
## Dazu drei Kantenstreifen (links/rechts/unten) mit stark gekippten Normalen für
## die Außenkanten jedes Blocks. Godot-2D-Normalen: +Y = oben.
## Die Texturen werden je Welt einmal gebaut und statisch gecacht.

const SIZE := 192

static var _cache := {}
static var _edge_cache := {}


static func for_palette(pal: Palette) -> CanvasTexture:
	var key: String = pal.world_name
	if _cache.has(key):
		return _cache[key]
	var tex := _make(pal)
	_cache[key] = tex
	return tex


## Kantenstreifen {l, r, b}: Alpha fällt von der Kante nach innen ab, die Normale
## kippt an der Kante zur Seite und richtet sich nach innen auf.
static func edge_textures(pal: Palette) -> Dictionary:
	var key: String = pal.world_name
	if _edge_cache.has(key):
		return _edge_cache[key]
	var wet := pal.weather == "regen"
	var d := {
		"l": _edge(Vector3(-0.76, 0.0, 0.65), Palette.tint(pal.fill, 0.22), 0.85, 0, wet),
		"r": _edge(Vector3(0.76, 0.0, 0.65), Palette.shade(pal.fill, 0.22), 0.85, 1, wet),
		"b": _edge(Vector3(0.0, -0.76, 0.65), Palette.shade(pal.fill, 0.32), 0.9, 2, wet),
	}
	_edge_cache[key] = d
	return d


static func _edge(n_edge: Vector3, col: Color, alpha: float, side: int, wet: bool) -> CanvasTexture:
	var s := 8
	var diff := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var norm := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d: float
			match side:
				0: d = (x + 0.5) / s
				1: d = 1.0 - (x + 0.5) / s
				_: d = 1.0 - (y + 0.5) / s
			var w := 1.0 - smoothstep(0.0, 1.0, d)
			diff.set_pixel(x, y, Color(col.r, col.g, col.b, alpha * w * w))
			var nv := n_edge.lerp(Vector3(0, 0, 1), 1.0 - w).normalized()
			norm.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	var t := CanvasTexture.new()
	t.diffuse_texture = ImageTexture.create_from_image(diff)
	t.normal_texture = ImageTexture.create_from_image(norm)
	t.specular_color = Color(0.95, 0.95, 1.0) if wet else Color(0.7, 0.7, 0.7)
	t.specular_shininess = 0.7 if wet else 0.35
	return t


static func _kind_for(pal: Palette) -> String:
	match pal.world_name:
		"netz-regen": return "metall"
		"rz-hell": return "rack"
		"archiv-abend": return "stein"
	return "putz"


static func _noise_img(seed: int, freq: float, octaves: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n.get_seamless_image(SIZE, SIZE)


static func _make(pal: Palette) -> CanvasTexture:
	var kind := _kind_for(pal)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pal.world_name)
	var S := SIZE
	var hf := PackedFloat32Array()
	hf.resize(S * S)
	hf.fill(0.5)
	var low := _noise_img(hash(pal.world_name) + 1, 0.05, 3)
	var fine := _noise_img(hash(pal.world_name) + 2, 0.35, 2)
	var panel_w: int = {"putz": 96, "metall": 96, "rack": 96, "stein": 96}[kind]
	var panel_h: int = {"putz": 96, "metall": 96, "rack": 48, "stein": 48}[kind]
	var joint: float = {"putz": 2.0, "metall": 3.0, "rack": 2.0, "stein": 3.0}[kind]
	var bevel: float = {"putz": 6.0, "metall": 5.0, "rack": 3.0, "stein": 5.0}[kind]
	var brick := kind == "stein"
	var half_w := int(panel_w / 2.0)
	var rough: float = {"putz": 0.10, "metall": 0.05, "rack": 0.04, "stein": 0.12}[kind]
	# Paneele: Fuge (tief), Bevel (Rampe), Fläche — plus Rauschen als Unebenheit und Korn
	for y in S:
		var row := int(y / float(panel_h))
		for x in S:
			var xx := x
			if brick and row % 2 == 1:
				xx = (x + half_w) % S
			var mx := xx % panel_w
			var my := y % panel_h
			var dx := minf(mx, panel_w - mx)
			var dy := minf(my, panel_h - my)
			var e := minf(dx, dy) - joint * 0.5
			var h := 0.5
			if e < 0.0:
				h = 0.22
			elif e < bevel:
				var f := e / bevel
				h = 0.30 + 0.20 * (f * f * (3.0 - 2.0 * f))
			var lowv := low.get_pixel(x, y).r
			var finev := fine.get_pixel(x, y).r
			h += (lowv - 0.5) * rough + (finev - 0.5) * 0.035
			hf[y * S + x] = h
	# Nieten an den Paneelecken (Metall) bzw. links/rechts der Einschübe (Rack)
	if kind == "metall":
		for j in int(S / float(panel_h)):
			for i in int(S / float(panel_w)):
				for c in [Vector2(10, 10), Vector2(panel_w - 10, 10), Vector2(10, panel_h - 10), Vector2(panel_w - 10, panel_h - 10)]:
					_dome(hf, i * panel_w + c.x, j * panel_h + c.y, 3.4, 0.30)
	elif kind == "rack":
		for j in int(S / float(panel_h)):
			for i in int(S / float(panel_w)):
				_dome(hf, i * panel_w + 8, j * panel_h + panel_h / 2.0, 2.8, 0.26)
				_dome(hf, i * panel_w + panel_w - 8, j * panel_h + panel_h / 2.0, 2.8, 0.26)
				if (i + j) % 3 == 1:
					for k in 5:
						_slot(hf, i * panel_w + 18, j * panel_h + 11 + k * 6, panel_w - 36, 3, 0.22)
				elif (i + j) % 3 == 2:
					_slot(hf, i * panel_w + 16, j * panel_h + 20, 28, 8, 0.16)
	# Risse nur im Stein, kurz und flach — alles Auffällige würde sich alle 192 px
	# wiederholen; die großen, zufälligen Risse zeichnet Terrain als Detail.
	if kind == "stein":
		for i in 3:
			_crack(hf, rng)
	# Normal-Map aus dem Höhenfeld, Diffuse aus Grundfarbe + Fuge + Korn
	var diff := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var norm := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var strength := 9.0
	var base := pal.fill
	for y in S:
		var row := int(y / float(panel_h))
		for x in S:
			var i := y * S + x
			var hl := hf[y * S + (x + S - 1) % S]
			var hr := hf[y * S + (x + 1) % S]
			var hu := hf[((y + S - 1) % S) * S + x]
			var hd := hf[((y + 1) % S) * S + x]
			var dhdx := (hr - hl) * 0.5 * strength
			var dhdy := (hd - hu) * 0.5 * strength
			var nv := Vector3(-dhdx, dhdy, 1.0).normalized()
			norm.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
			var h := hf[i]
			var c := base
			if brick:
				var xx := x
				if row % 2 == 1:
					xx = (x + half_w) % S
				var bi := hash(Vector2i(int(xx / float(panel_w)), row))
				var v := float(bi % 1000) / 1000.0 - 0.5
				c = Color.from_hsv(fmod(c.h + v * 0.02 + 1.0, 1.0), c.s, clampf(c.v * (1.0 + v * 0.10), 0.0, 1.0))
			# leicht eingebackenes Licht von oben links — den Rest macht das echte Licht
			var lit := clampf(1.0 + (h - 0.5) * 0.45 + (dhdx * 0.5 + dhdy * 0.6) * 0.45, 0.6, 1.3)
			c = Color(c.r * lit, c.g * lit, c.b * lit)
			if h < 0.26:
				c = c.lerp(pal.shadow, 0.7)
			elif h > 0.64:
				c = c.lerp(Palette.tint(pal.cap, 0.15), 0.35)
			var lowv := low.get_pixel(x, y).r
			var finev := fine.get_pixel(x, y).r
			var grain := 1.0 + (lowv - 0.5) * 0.16 + (finev - 0.5) * 0.10
			c = Color(clampf(c.r * grain, 0.0, 1.0), clampf(c.g * grain, 0.0, 1.0), clampf(c.b * grain, 0.0, 1.0))
			diff.set_pixel(x, y, c)
	var tex := CanvasTexture.new()
	tex.diffuse_texture = ImageTexture.create_from_image(diff)
	tex.normal_texture = ImageTexture.create_from_image(norm)
	match kind:
		"metall":
			tex.specular_color = Color(0.9, 0.95, 1.0)
			tex.specular_shininess = 0.6
		"rack":
			tex.specular_color = Color(0.75, 0.8, 0.85)
			tex.specular_shininess = 0.45
		"stein":
			tex.specular_color = Color(0.5, 0.45, 0.4)
			tex.specular_shininess = 0.15
		_:
			tex.specular_color = Color(0.6, 0.6, 0.6)
			tex.specular_shininess = 0.2
	return tex


## Nietenkopf: Halbkugel im Höhenfeld (kacheltauglich per Modulo).
static func _dome(hf: PackedFloat32Array, cx: float, cy: float, r: float, amp: float) -> void:
	var S := SIZE
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d < r:
				var i := ((y + S) % S) * S + (x + S) % S
				hf[i] += amp * sqrt(1.0 - (d / r) * (d / r))


## Schlitz: rechteckige Vertiefung.
static func _slot(hf: PackedFloat32Array, x0: int, y0: int, w: int, h: int, depth: float) -> void:
	var S := SIZE
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			hf[((y + S) % S) * S + (x + S) % S] -= depth


## Riss: kurze Zufalls-Polylinie als feine Rille.
static func _crack(hf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var S := SIZE
	var p := Vector2(rng.randf_range(0, S), rng.randf_range(0, S))
	var dir := Vector2.from_angle(rng.randf_range(0, TAU))
	var steps := rng.randi_range(10, 22)
	for k in steps:
		dir = dir.rotated(rng.randf_range(-0.6, 0.6))
		p += dir * 1.0
		var xi := int(floor(p.x))
		var yi := int(floor(p.y))
		hf[((yi + S) % S) * S + (xi + S) % S] -= 0.09
		if k % 3 == 0:
			hf[((yi + S) % S) * S + (xi + 1 + S) % S] -= 0.04
