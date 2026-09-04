class_name KulisseLeben
extends Node2D
## KULISSEN-LEBEN — alles Bewegte einer Ebene als REINE FUNKTION DER ZEIT
## (kein Zustand, wie in Title.gd): Wolkenzug, Bodennebel, schwankende Bäume
## und Kübelpflanzen, Vogelschwärme (Flügelschlag 1,9 Hz), ferne Fahrzeug-
## lichter, blinkende Antennen (0,5 Hz), Fenster mit Innenleben am Abend,
## Server-LEDs (≤ 2,5 Hz, gedämpft) und schwebender Papierstaub im Archiv.
## Nur dieser Knoten ruft queue_redraw() — die statische Ebene bleibt statisch.
## Sparsam und ruhig: nichts hier darf den Blick von der Spielfläche ziehen.

const FLAP_HZ := 1.9        # Flügelschlag — unter 3 Hz (Barrierefreiheit)
const ANTENNA_HZ := 0.5
const LED_MAX_HZ := 2.4

var kind := "far"           # far | mid | near | wolken | fog
var pal: Palette
var source: KulisseEbene    # statische Ebene (Bäume, Fenster, Antennen, Racks)
var pattern_w := 3840.0
var level_h := 1104.0
var copies := 3
var clouds: Array = []
var birds: Array = []       # Schwärme {y, v, off, s, dir, n, ph}
var vehicles: Array = []    # {v, off, dir, ph}
var inhabitants: Array = [] # {p, ph, ph2}
var leds: Array = []        # {p, hz, ph, c}
var specks: Array = []      # {p, ph, r}
var fog_tex: ImageTexture
var _ox := 0.0


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func ground_y() -> float:
	return level_h - 3 * Game.TILE


func build(seed_text: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text + "leben")
	var ground := ground_y()
	var outdoor := pal.weather != "innen"
	var evening := pal.weather == "regen" or pal.world_name.ends_with("abend")
	match kind:
		"wolken":
			var n := 7 if pal.weather != "regen" else 12
			for i in n:
				clouds.append({"p": Vector2(rng.randf_range(0, pattern_w), rng.randf_range(60, 420)),
					"s": rng.randf_range(0.7, 1.6), "v": rng.randf_range(4, 12), "ph": rng.randf_range(0, TAU)})
		"fog":
			var n := FastNoiseLite.new()
			n.seed = int(rng.randi())
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.012
			n.fractal_octaves = 3
			fog_tex = ImageTexture.create_from_image(n.get_seamless_image(512, 256))
		"far", "mid":
			# Vogelschwärme: draußen, nicht im Regen; fern klein, mittel etwas größer
			if outdoor and pal.weather != "regen":
				var flocks := 2 if kind == "far" else 1
				for i in flocks:
					birds.append({"y": rng.randf_range(120, 380) if kind == "far" else rng.randf_range(80, 300),
						"v": rng.randf_range(22, 40), "off": rng.randf_range(0, pattern_w),
						"s": rng.randf_range(6, 9) if kind == "far" else rng.randf_range(10, 14),
						"dir": 1.0 if rng.randf() < 0.5 else -1.0, "n": 3 + rng.randi() % 3, "ph": rng.randf_range(0, TAU)})
			# Ferne Fahrzeuglichter am Abend und im Regen — nur auf der mittleren Ebene,
			# knapp über der Bodenlinie (sie ziehen hinter den Plattformen vorbei)
			if evening and outdoor and kind == "mid":
				for i in 2:
					vehicles.append({"v": rng.randf_range(90, 150), "off": rng.randf_range(0, pattern_w),
						"dir": 1.0 if i == 0 else -1.0, "ph": rng.randf_range(0, TAU)})
			# Fenster mit Innenleben (Abend/Regen): ein Fünftel der beleuchteten Fenster
			if evening and source and kind == "mid":
				for w in source.windows:
					if w["lit"] and rng.randf() < 0.2:
						inhabitants.append({"p": w["p"], "ph": rng.randf_range(0, TAU), "ph2": rng.randf_range(0, TAU)})
			# Server-LEDs im Rechenzentrum: pro Rack-Säule bis zu sechs, gedämpft
			if source and pal.motiv == "rechenzentrum" and kind == "mid":
				for rk in source.racks:
					var n := mini(6, int(float(rk["h"]) / 36.0))
					for i in n:
						leds.append({"p": Vector2(float(rk["x"]) + 10, float(rk["top"]) + 40 + i * 36.0),
							"hz": rng.randf_range(0.3, LED_MAX_HZ), "ph": rng.randf_range(0, TAU),
							"c": pal.detail if rng.randf() < 0.6 else pal.accent})
			# Papierstaub im Archiv: wenige große, langsam schwebende Flocken
			if pal.motiv == "archiv":
				for i in 10:
					specks.append({"p": Vector2(rng.randf_range(0, pattern_w), rng.randf_range(ground - 700, ground - 60)),
						"ph": rng.randf_range(0, TAU), "r": rng.randf_range(2.0, 4.5) if kind == "mid" else rng.randf_range(3.0, 6.0)})


func _process(_delta: float) -> void:
	queue_redraw()


## Sichtbarer Bereich in lokalen Koordinaten (für das Culling der Kopien).
func _visible_local() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(-1e9, -1e9, 2e9, 2e9)
	return get_global_transform_with_canvas().affine_inverse() * vp.get_visible_rect()


func _draw() -> void:
	var t := now()
	var ground := ground_y()
	if kind == "fog":
		if fog_tex:
			var off := fmod(t * 14.0, 512.0)
			draw_texture_rect(fog_tex, Rect2(-off, ground - 220, pattern_w + 512, 300), true, Color(pal.fog.r, pal.fog.g, pal.fog.b, 0.16))
			draw_texture_rect(fog_tex, Rect2(-512 + fmod(t * 7.0, 512.0), ground - 110, pattern_w + 512, 200), true, Color(pal.fog.r, pal.fog.g, pal.fog.b, 0.12))
		return
	var vis := _visible_local()
	for k in copies:
		_ox = float(k) * pattern_w
		if copies > 1 and (_ox + pattern_w + 500 < vis.position.x or _ox - 500 > vis.end.x):
			continue
		draw_set_transform(Vector2(_ox, 0), 0.0, Vector2.ONE)
		_paint(t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint(t: float) -> void:
	var ground := ground_y()
	match kind:
		"wolken":
			for c in clouds:
				var p: Vector2 = c["p"] + Vector2(0, sin(t * 0.2 + float(c["ph"])) * 6.0)
				p.x = fmod(p.x + t * float(c["v"]), pattern_w)
				_cloud(p, float(c["s"]))
		"far":
			_birds(t)
			_antennas(t)
			_specks(t)
		"mid":
			if source:
				for tr in source.trees:
					_tree(tr, 0.75, t)
				for pr in source.props:
					if pr["k"] == "kuebel":
						_plant(pr, t)
			_vehicles(t, ground)
			_inhabitants(t)
			_leds(t)
			_birds(t)
			_antennas(t)
			_specks(t)
		"near":
			if source:
				for tr in source.trees:
					_tree(tr, 1.0, t)
				for pr in source.props:
					if pr["k"] == "kuebel":
						_plant(pr, t)


# ------------------------------------------------------------------ Motive

func _cloud(p: Vector2, s: float) -> void:
	var c := Color(1, 1, 1, 0.80) if pal.weather != "regen" else Color(pal.far.r, pal.far.g, pal.far.b, 0.9)
	var sh := Color(pal.fog.r, pal.fog.g, pal.fog.b, 0.6)
	var blobs := [Vector2(0, 0), Vector2(-70, 14), Vector2(64, 10), Vector2(-28, -26), Vector2(30, -22), Vector2(110, 20), Vector2(-120, 22)]
	var radii := [46.0, 34.0, 38.0, 30.0, 34.0, 26.0, 24.0]
	for i in blobs.size():
		draw_circle(p + blobs[i] * s + Vector2(0, 8 * s), radii[i] * s, sh)
	for i in blobs.size():
		draw_circle(p + blobs[i] * s, radii[i] * s, c)


## Vogelschwarm: kleine „V", Flügelschlag < 3 Hz, zieht langsam über das Muster.
func _birds(t: float) -> void:
	var col := Color(Palette.shade(pal.far if kind == "far" else pal.mid, 0.5), 0.75)
	for f in birds:
		var dir: float = f["dir"]
		var s: float = f["s"]
		var travel := fmod(float(f["off"]) + t * float(f["v"]), pattern_w + 800.0) - 400.0
		var x := travel if dir > 0 else pattern_w - travel
		var y: float = float(f["y"]) + sin(t * 0.35 + float(f["ph"])) * 12.0
		var n: int = f["n"]
		for i in n:
			var bp := Vector2(x - dir * i * s * 2.6, y + absf(float(i) - float(n - 1) * 0.5) * s * 1.1 + sin(t * 0.9 + i) * 2.0)
			var flap := sin(t * TAU * FLAP_HZ + float(f["ph"]) + i * 0.7)
			var lift := -flap * s * 0.55
			draw_line(bp, bp + Vector2(-s, lift), col, 1.6, true)
			draw_line(bp, bp + Vector2(s, lift), col, 1.6, true)


## Blinkende Antennenspitzen (0,5 Hz, weich) — Netz-Motiv.
func _antennas(t: float) -> void:
	if source == null or source.antennas.is_empty():
		return
	var i := 0
	for a in source.antennas:
		var ph := float(i) * 1.37
		var k := smoothstep(0.55, 0.95, sin(t * TAU * ANTENNA_HZ + ph))
		var al := 0.15 + 0.7 * k
		draw_circle(a, 4.5, Color(pal.accent.r, pal.accent.g, pal.accent.b, al))
		i += 1


## Ferne Fahrzeuglichter: zwei warme Punkte vorn, zwei Akzentpunkte hinten,
## dazwischen eine kaum sichtbare Karosserie.
func _vehicles(t: float, ground: float) -> void:
	var body := Color(Palette.shade(pal.mid, 0.45), 0.35)
	var head := Color(pal.lamp.r, pal.lamp.g, pal.lamp.b, 0.85)
	var tail := Color(pal.accent.r, pal.accent.g, pal.accent.b, 0.7)
	for v in vehicles:
		var dir: float = v["dir"]
		var travel := fmod(float(v["off"]) + t * float(v["v"]), pattern_w + 600.0) - 300.0
		var x := travel if dir > 0 else pattern_w - travel
		var y := ground - 14.0 + sin(t * 3.0 + float(v["ph"])) * 0.6
		draw_rect(Rect2(x - 24, y - 8, 48, 12), body)
		draw_circle(Vector2(x + dir * 22, y), 2.6, head)
		draw_circle(Vector2(x + dir * 22, y - 4), 2.0, head)
		draw_circle(Vector2(x - dir * 22, y), 1.8, tail)


## Fenster mit Innenleben: eine Silhouette, die langsam auftaucht, sich bewegt
## und wieder verschwindet (Perioden 35–60 s).
func _inhabitants(t: float) -> void:
	var col := Palette.shade(pal.mid, 0.6)
	for h in inhabitants:
		var p: Vector2 = h["p"]
		var presence := smoothstep(0.05, 0.6, sin(t * 0.14 + float(h["ph2"])))
		if presence <= 0.01:
			continue
		var dx := sin(t * 0.21 + float(h["ph"])) * 3.0
		var c := Color(col, 0.65 * presence)
		draw_circle(Vector2(p.x + 7 + dx, p.y + 8), 3.2, c)
		draw_rect(Rect2(p.x + 2.5 + dx, p.y + 11, 9, 7), c)


## Server-LEDs: langsam und gedämpft, jede mit eigener Rate ≤ 2,4 Hz.
func _leds(t: float) -> void:
	for l in leds:
		var p: Vector2 = l["p"]
		var c: Color = l["c"]
		var k := smoothstep(0.1, 0.7, sin(t * TAU * float(l["hz"]) + float(l["ph"])))
		draw_rect(Rect2(p.x, p.y, 4, 3), Color(c.r, c.g, c.b, 0.16 + 0.34 * k))


## Papierstaub: wenige Flocken, die sehr langsam aufsteigen und seitlich driften.
func _specks(t: float) -> void:
	var col := Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.38)
	for s in specks:
		var p: Vector2 = s["p"]
		var ph := float(s["ph"])
		var y := p.y - fmod(t * 3.5 + ph * 60.0, 420.0) + 210.0
		var x := p.x + sin(t * 0.22 + ph) * 34.0
		var a := col
		a.a *= 0.5 + 0.5 * sin(t * 0.6 + ph * 2.0)
		draw_circle(Vector2(x, y), float(s["r"]), a)


func _tree(tr: Dictionary, k: float, t: float) -> void:
	var p: Vector2 = tr["p"]
	var s: float = tr["s"] * k
	var sway := sin(t * 0.9 + float(tr["ph"])) * 3.0 * s
	var trunk := Palette.shade(pal.near, 0.3)
	draw_rect(Rect2(p.x - 7 * s, p.y - 70 * s, 14 * s, 72 * s), trunk)
	var pc := pal.plant if k >= 1.0 else pal.plant.lerp(pal.mid, 0.4)
	var pd := pal.plant_dark if k >= 1.0 else pal.plant_dark.lerp(pal.mid, 0.4)
	var c := Vector2(p.x + sway, p.y - 110 * s)
	if tr["shape"] == 0:
		draw_circle(c + Vector2(4, 6) * s, 46 * s, pd)
		draw_circle(c, 44 * s, pc)
		draw_circle(c + Vector2(-34, 12) * s, 30 * s, pc)
		draw_circle(c + Vector2(32, 14) * s, 28 * s, pc)
		draw_circle(c + Vector2(-14, -16) * s, 22 * s, Palette.tint(pc, 0.25))
	else:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-48, 40) * s, c + Vector2(0, -70) * s, c + Vector2(48, 40) * s]), pd)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-40, 30) * s, c + Vector2(-4, -60) * s, c + Vector2(30, 30) * s]), pc)
	# Schatten am Fuß (Transform danach auf die aktuelle Kopie zurücksetzen)
	draw_set_transform(Vector2(_ox + p.x + 10 * s, p.y + 2), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 40 * s, Color(pal.shadow.r, pal.shadow.g, pal.shadow.b, 0.18))
	draw_set_transform(Vector2(_ox, 0), 0.0, Vector2.ONE)


## Pflanze im Kübel (der Kübel selbst ist statisch).
func _plant(pr: Dictionary, t: float) -> void:
	var p: Vector2 = pr["p"]
	var sway := sin(t * 1.3 + float(pr["ph"])) * 2.0
	for i in 5:
		var bx := p.x - 14 + i * 7.0
		var tip := Vector2(bx + sway + (i - 2) * 2.0, p.y - 46 - absf(2 - i) * -4.0)
		draw_line(Vector2(bx, p.y - 28), tip, pal.plant_dark, 3.0, true)
		draw_circle(tip, 5.0, pal.plant if i % 2 == 0 else pal.accent)
