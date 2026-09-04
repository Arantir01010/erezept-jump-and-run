class_name KulisseEbene
extends Node2D
## STATISCHE KULISSENEBENE — wird genau EINMAL gezeichnet und nie neu:
## Sonne und Horizontschleier, Gebäude (Fassadenlicht, Dachkante, Fenster,
## Schilder), Laternenmasten und Pflanzkübel. Alles Bewegte dieser Ebene
## (Bäume, Kübelpflanzen, Vögel, LEDs, Fensterleben …) malt KulisseLeben
## in einem eigenen Knoten darüber.
##
## `copies` = 3: die Ebene zeichnet sich bei 0, +W und +2W selbst, damit eine
## Parallax2D mit repeat_size (Position wird per fposmod gewickelt; sichtbar
## ist lokal x ∈ [160, W+1760]) ohne Engine-Repeat auskommt — so braucht die
## Tiefenschärfe (CanvasGroup) nur EINEN Blur-Pass je Ebene.
## `copies` = 1 für Ebenen, die den Engine-Repeat nutzen.

var kind := "far"          # sonne | far | mid | near
var pal: Palette
var pattern_w := 3840.0
var level_h := 1104.0
var copies := 3
var buildings: Array = []
var windows: Array = []
var trees: Array = []      # gezeichnet von KulisseLeben (schwanken)
var props: Array = []
var antennas: Array = []   # Vector2 — Antennenspitzen (Netz-Motiv)
var racks: Array = []      # {x, top, h} — Rack-Säulen (Rechenzentrum)
var _ox := 0.0


func ground_y() -> float:
	return level_h - 3 * Game.TILE


func build(seed_text: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var ground := ground_y()
	match kind:
		"far", "mid", "near":
			var x := 0.0
			var scale_h: float = {"far": 1.0, "mid": 0.70, "near": 0.30}[kind]
			var gap: float = {"far": 40.0, "mid": 140.0, "near": 900.0}[kind]
			while x < pattern_w:
				var w := rng.randf_range(170, 360) * (1.3 if kind == "near" else 1.0)
				var h: float = rng.randf_range(240, 760) * scale_h
				var roof := rng.randi() % 4
				buildings.append({"rect": Rect2(x, ground - h, w, h + 400), "roof": roof,
					"sign": rng.randf() < 0.14 and kind == "mid", "hue": rng.randf_range(-0.03, 0.03)})
				if kind != "far":
					var cols := int(w / 46.0)
					var rows := int(h / 54.0)
					for cx in cols:
						for cy in rows:
							if rng.randf() < 0.55:
								windows.append({"p": Vector2(x + 16 + cx * 46.0, ground - h + 24 + cy * 54.0),
									"lit": rng.randf() < 0.35, "ph": rng.randf_range(0, TAU)})
				x += w + gap + rng.randf_range(0, gap)
			# Bäume und Straßenmöbel auf der nahen und mittleren Ebene
			if kind == "near" or kind == "mid":
				var tx := rng.randf_range(0, 300)
				while tx < pattern_w:
					var kindp := rng.randi() % 5
					if kindp < 3:
						trees.append({"p": Vector2(tx, ground), "s": rng.randf_range(0.8, 1.35) * (1.0 if kind == "near" else 0.6), "ph": rng.randf_range(0, TAU), "shape": rng.randi() % 2})
					elif kindp == 3 and kind == "near":
						props.append({"k": "laterne", "p": Vector2(tx, ground)})
					else:
						props.append({"k": "kuebel", "p": Vector2(tx, ground), "ph": rng.randf_range(0, TAU)})
					tx += rng.randf_range(260, 620) * (1.0 if kind == "near" else 0.8)
			# Positionen für das Leben: Antennenspitzen, Rack-Säulen
			var detail: float = {"far": 0.0, "mid": 1.0, "near": 1.4}[kind]
			for b in buildings:
				var r: Rect2 = b["rect"]
				if pal.motiv == "netz" and kind != "near":
					antennas.append(Vector2(r.get_center().x, r.position.y - 70 * detail))
				elif pal.motiv == "rechenzentrum" and kind == "mid":
					for i in int(r.size.x / 40.0):
						racks.append({"x": r.position.x + 8 + i * 40, "top": r.position.y + 30, "h": r.size.y - 460})


func _draw() -> void:
	for k in copies:
		_ox = float(k) * pattern_w
		draw_set_transform(Vector2(_ox, 0), 0.0, Vector2.ONE)
		_paint()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint() -> void:
	var ground := ground_y()
	match kind:
		"sonne":
			if pal.weather == "klar":
				var p := Vector2(pal.sun_pos.x * 1920.0, pal.sun_pos.y * 1080.0)
				for i in 8:
					draw_circle(p, 90.0 + i * 60.0, Color(pal.sun.r, pal.sun.g, pal.sun.b, 0.10 - i * 0.011))
				draw_circle(p, 74.0, Color(pal.sun.r, pal.sun.g, pal.sun.b, 0.9))
				draw_circle(p, 62.0, Color(1, 1, 1, 0.9))
			# Horizontschleier (im Rechenzentrum: helle Hallenluft)
			for i in 6:
				draw_rect(Rect2(-200, ground - 520 + i * 80, pattern_w + 400, 80), Color(pal.fog.r, pal.fog.g, pal.fog.b, 0.04 + i * 0.05))
		"far":
			for b in buildings:
				_building(b, pal.far, 0.0, false)
			_fog_band(ground - 700, 1100, 0.26)
		"mid":
			for b in buildings:
				_building(b, pal.mid, 1.0, true)
			for pr in props:
				_prop(pr, 0.75)
			_fog_band(ground - 520, 900, 0.14)
		"near":
			for b in buildings:
				_building(b, pal.near, 1.4, true)
			for pr in props:
				_prop(pr, 1.0)


## Weicher Nebelverlauf: oben null, unten volle Stärke — nie eine harte Kante
func _fog_band(y_top: float, height: float, alpha: float) -> void:
	var steps := 14
	var h := height / steps
	for i in steps:
		var t := float(i + 1) / steps
		draw_rect(Rect2(-200, y_top + i * h, pattern_w + 400, h + 1), Color(pal.fog.r, pal.fog.g, pal.fog.b, alpha * t * t))


func _building(b: Dictionary, base: Color, detail: float, with_windows: bool) -> void:
	var r: Rect2 = b["rect"]
	var c := base
	c = Color.from_hsv(fmod(c.h + float(b["hue"]) + 1.0, 1.0), c.s, c.v)
	draw_rect(r, c)
	var top := r.position.y
	# Fassadenlicht: links sonnig, rechts im Schatten
	draw_rect(Rect2(r.position.x, top, r.size.x * 0.5, r.size.y), Color(1, 1, 1, 0.06))
	draw_rect(Rect2(r.position.x + r.size.x * 0.82, top, r.size.x * 0.18, r.size.y), Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, 0.12))
	match pal.motiv:
		"netz":
			draw_line(Vector2(r.get_center().x, top), Vector2(r.get_center().x, top - 70 * detail), Palette.shade(c, 0.1), 4.0)
			draw_circle(Vector2(r.get_center().x, top - 70 * detail), 5.0, Color(pal.accent.r, pal.accent.g, pal.accent.b, 0.35))
		"rechenzentrum":
			for i in int(r.size.x / 40.0):
				draw_rect(Rect2(r.position.x + 8 + i * 40, top + 30, 24, r.size.y - 460), Palette.shade(c, 0.12))
		"archiv":
			for i in int(r.size.y / 90.0):
				draw_rect(Rect2(r.position.x + 10, top + 20 + i * 90, r.size.x - 20, 6), Palette.tint(c, 0.15))
		_:
			if b["roof"] == 1:
				draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, top), Vector2(r.get_center().x, top - 60 * detail), Vector2(r.end.x, top)]), Palette.shade(c, 0.12))
			elif b["roof"] == 2 and detail > 0.5:
				draw_rect(Rect2(r.position.x + r.size.x * 0.3, top - 30, r.size.x * 0.4, 30), c)
	# Dachkante hell (Licht von oben)
	draw_rect(Rect2(r.position.x, top, r.size.x, 4), Palette.tint(c, 0.35))
	if with_windows:
		var evening := pal.weather == "regen" or pal.world_name.ends_with("abend")
		for w in windows:
			var wp: Vector2 = w["p"]
			if wp.x < r.position.x or wp.x > r.end.x or wp.y < r.position.y:
				continue
			if w["lit"] and evening:
				draw_rect(Rect2(wp, Vector2(14, 18)), Color(pal.lamp.r, pal.lamp.g, pal.lamp.b, 0.82))
			else:
				draw_rect(Rect2(wp, Vector2(14, 18)), Palette.shade(c, 0.28))
				draw_rect(Rect2(wp + Vector2(2, 2), Vector2(10, 6)), Color(pal.sky_top.r, pal.sky_top.g, pal.sky_top.b, 0.5))
	if b.get("sign", false):
		_sign(r)


func _sign(r: Rect2) -> void:
	var p := Vector2(r.get_center().x, r.position.y + 64)
	match pal.motiv:
		"praxis":
			draw_rect(Rect2(p.x - 26, p.y - 26, 52, 52), Color(1, 1, 1, 0.9))
			draw_rect(Rect2(p.x - 6, p.y - 20, 12, 40), Palette.OK)
			draw_rect(Rect2(p.x - 20, p.y - 6, 40, 12), Palette.OK)
		"netz":
			for i in 3:
				draw_arc(p, 12.0 + i * 12.0, PI * 1.2, PI * 1.8, 12, pal.accent, 3.5, true)
		"archiv":
			draw_rect(Rect2(p.x - 28, p.y - 14, 56, 28), Palette.shade(pal.mid, 0.3))
			draw_rect(Rect2(p.x - 22, p.y - 8, 44, 16), pal.accent)
		_:
			draw_rect(Rect2(p.x - 22, p.y - 12, 44, 24), pal.accent)


## Statische Straßenmöbel: Laternenmast (mit Lampe) und Pflanzkübel (ohne Pflanze).
func _prop(pr: Dictionary, _k: float) -> void:
	var p: Vector2 = pr["p"]
	match pr["k"]:
		"laterne":
			var c := Palette.shade(pal.near, 0.35)
			draw_rect(Rect2(p.x - 4, p.y - 150, 8, 150), c)
			draw_rect(Rect2(p.x - 12, p.y - 4, 24, 6), c)
			draw_rect(Rect2(p.x - 4, p.y - 156, 34, 6), c)
			var lit := pal.weather == "regen" or pal.world_name.ends_with("abend")
			var lc := pal.lamp if lit else Palette.tint(pal.mid, 0.4)
			draw_rect(Rect2(p.x + 20, p.y - 176, 18, 22), lc if not lit else Palette.glow(lc, 1.3))
			draw_rect(Rect2(p.x + 18, p.y - 178, 22, 4), c)
		"kuebel":
			var c := Palette.shade(pal.near, 0.2)
			draw_rect(Rect2(p.x - 22, p.y - 26, 44, 26), c)
			draw_rect(Rect2(p.x - 24, p.y - 30, 48, 6), Palette.tint(c, 0.2))
