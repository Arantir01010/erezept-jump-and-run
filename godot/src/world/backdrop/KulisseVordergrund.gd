class_name KulisseVordergrund
extends Node2D
## VORDERGRUND — dunkle, unscharfe Silhouetten VOR Spieler und Gelände, nur an
## den Bildrändern (oben ≈ 12 %, unten ≈ 6 %, dazu vereinzelte schmale Masten
## mit geringem Alpha). Tiefe entsteht durch die schnellere Parallaxe (1,2),
## nicht durch Detail. Statisch gezeichnet; Bewegung nur über die Parallaxe.
##
## Koordinaten: Die Ebene läuft vertikal fast fest mit (scroll_scale.y = 0,1).
## Parallax2D setzt seine Position aus dem Kamera-Mittelpunkt minus der HALBEN
## Viewport-Größe (ohne Zoom): lokal y = Bildschirm-y + 90·(1−s) + s·Kamera-oben.
## Bei Zoom 1,2 und Kamera-oben ∈ [0, 204] ist das Bildschirm-y + 81…101 —
## hier fest OFF_Y = 91; alle Zeichenfunktionen rechnen in Bildschirm-y
## (0–900 sichtbar), die Ränder sind ±12 px überzeichnet.
## Motive je Welt: Blätter/Äste + Geländer (Morgen) · Laternen + Kabel (Abend) ·
## Kabel mit Tropfen + Fensterrahmen (Regen) · Kabeltrassen + Rack-Kanten (RZ) ·
## Regalenden + hängende Etiketten (Archiv).

const VIEW_H := 900.0      # sichtbare Höhe in Welt-Pixeln (1080 / Zoom 1,2)
const TOP := 108.0         # 12 %
const BOTTOM := 54.0       # 6 %
const OFF_Y := 91.0        # Bildschirm-y → lokal y (siehe oben)

var pal: Palette
var pattern_w := 3840.0
var copies := 3
var _ox := 0.0
var _rng := RandomNumberGenerator.new()
var _seed_text := ""


func build(seed_text: String) -> void:
	_seed_text = seed_text


func _draw() -> void:
	for k in copies:
		_ox = float(k) * pattern_w
		draw_set_transform(Vector2(_ox, OFF_Y), 0.0, Vector2.ONE)
		# je Kopie derselbe Zufall → nahtlos wiederholbar
		_rng.seed = hash(_seed_text + "vordergrund")
		_paint()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint() -> void:
	var base := Palette.shade(pal.outline, 0.3)
	var mass := Color(base, 0.46)
	var thin := Color(base, 0.20)
	match pal.world_name:
		"praxis-morgen":
			_morgen(mass, thin)
		"praxis-abend":
			_abend(mass, thin)
		"netz-regen":
			_regen(mass, thin)
		"rz-hell":
			_rz(mass, thin)
		_:
			_archiv(mass, thin)


# ------------------------------------------------------------------ Welten

## Morgen: Äste mit Blättern von oben, Geländer mit Pfosten unten, ein Mast.
func _morgen(mass: Color, thin: Color) -> void:
	var leaf := Color(mass, 0.42)
	for i in 2:
		var x0 := 300.0 + i * 1900.0 + _rng.randf_range(-200, 200)
		var dir := 1.0 if i == 0 else -1.0
		_branch(Vector2(x0, -50), Vector2(x0 + dir * 420, TOP - 10), 13.0, 5.0, mass, leaf)
		_branch(Vector2(x0 + dir * 120, -50), Vector2(x0 + dir * 560, TOP * 0.55), 8.0, 3.0, mass, leaf)
	# Geländer: Handlauf, Pfosten, Grasbüschel am unteren Rand
	var rail_y := VIEW_H - BOTTOM + 4
	draw_rect(Rect2(-100, rail_y, pattern_w + 200, 7), Color(mass, 0.40))
	draw_rect(Rect2(-100, rail_y + 22, pattern_w + 200, 4), Color(mass, 0.32))
	var px := _rng.randf_range(40, 200)
	while px < pattern_w:
		draw_rect(Rect2(px - 6, rail_y - 6, 12, 120), Color(mass, 0.40))
		px += _rng.randf_range(280, 420)
	_grass(VIEW_H - 4, Color(mass, 0.34))
	_mast(_rng.randf_range(900, 3000), thin)


## Abend: hängende Laternen und durchhängende Kabel oben, Mauerkante unten.
func _abend(mass: Color, thin: Color) -> void:
	for i in 3:
		var x0 := i * 1280.0 + _rng.randf_range(-300, 300)
		_cable(Vector2(x0, -30), Vector2(x0 + 1100, 20 + _rng.randf_range(-20, 30)), _rng.randf_range(40, 80), 3.5, Color(mass, 0.38))
	for i in 2:
		var x := 700.0 + i * 1900.0 + _rng.randf_range(-250, 250)
		_lantern(x, Color(mass, 0.44), true)
	# Mauerkante mit vereinzelten Pflanzen
	draw_rect(Rect2(-100, VIEW_H - BOTTOM + 10, pattern_w + 200, BOTTOM + 60), Color(mass, 0.36))
	draw_rect(Rect2(-100, VIEW_H - BOTTOM + 10, pattern_w + 200, 5), Color(mass, 0.30))
	_grass(VIEW_H - BOTTOM + 12, Color(mass, 0.34))
	var mx := _rng.randf_range(1200, 3200)
	_mast(mx, thin)
	# Lampenarm am Mast
	draw_rect(Rect2(mx, 54, 60, 5), thin)
	draw_rect(Rect2(mx + 48, 58, 18, 22), Color(thin, 0.30))


## Regen: Fensterrahmen (oberer Balken, Sims, Sprossen) und Kabel mit Tropfen.
func _regen(mass: Color, thin: Color) -> void:
	draw_rect(Rect2(-100, -60, pattern_w + 200, TOP * 0.42 + 60), Color(mass, 0.38))
	draw_rect(Rect2(-100, TOP * 0.42 - 6, pattern_w + 200, 6), Color(mass, 0.26))
	# Sims unten
	draw_rect(Rect2(-100, VIEW_H - BOTTOM + 8, pattern_w + 200, BOTTOM + 60), Color(mass, 0.42))
	draw_rect(Rect2(-100, VIEW_H - BOTTOM + 8, pattern_w + 200, 5), Color(mass, 0.28))
	# Sprossen: schmale Vertikale, sehr transparent
	for i in 2:
		var x := 640.0 + i * 1920.0 + _rng.randf_range(-300, 300)
		draw_rect(Rect2(x - 7, -60, 14, VIEW_H + 120), Color(thin, 0.17))
	# Kabel mit Tropfen unterhalb des Rahmens
	for i in 3:
		var x0 := i * 1280.0 + _rng.randf_range(-200, 200)
		var a := Vector2(x0, TOP * 0.45 + _rng.randf_range(0, 20))
		var b := Vector2(x0 + 1000, TOP * 0.45 + _rng.randf_range(0, 30))
		var sag := _rng.randf_range(30, 60)
		_cable(a, b, sag, 3.0, Color(mass, 0.40))
		_drops(a, b, sag, Color(mass, 0.36))


## Rechenzentrum: Kabeltrasse mit Hängern oben, Rack-Kanten, Doppelboden unten.
func _rz(mass: Color, thin: Color) -> void:
	var tray_y := 34.0
	draw_rect(Rect2(-100, tray_y, pattern_w + 200, 22), Color(mass, 0.42))
	draw_rect(Rect2(-100, tray_y - 4, pattern_w + 200, 4), Color(mass, 0.30))
	var hx := _rng.randf_range(0, 300)
	while hx < pattern_w:
		draw_rect(Rect2(hx - 4, -60, 8, tray_y + 60), Color(mass, 0.40))
		hx += _rng.randf_range(360, 520)
	# fünf Kabel unter der Trasse, leicht durchhängend zwischen den Hängern
	for i in 5:
		var y := tray_y + 30 + i * 7.0
		var x0 := -100.0
		while x0 < pattern_w + 100:
			var x1 := x0 + 440.0
			_cable(Vector2(x0, y), Vector2(x1, y), 8.0 + i * 2.0, 2.6, Color(mass, 0.34 - i * 0.03))
			x0 = x1
	# Rack-Kanten: zwei schmale Rahmen pro Muster
	for i in 2:
		var x := 900.0 + i * 1900.0 + _rng.randf_range(-350, 350)
		draw_rect(Rect2(x - 9, -60, 18, VIEW_H + 120), Color(thin, 0.18))
		draw_rect(Rect2(x - 3, -60, 6, VIEW_H + 120), Color(thin, 0.10))
		# wenige Montagelöcher statt Sprossen (sonst wirkt die Kante wie eine Leiter)
		var ly := 130.0
		while ly < VIEW_H:
			draw_rect(Rect2(x - 5, ly, 10, 4), Color(thin, 0.14))
			ly += 150.0
	# Doppelboden-Kante mit Fugen
	draw_rect(Rect2(-100, VIEW_H - BOTTOM + 12, pattern_w + 200, BOTTOM + 60), Color(mass, 0.40))
	draw_rect(Rect2(-100, VIEW_H - BOTTOM + 12, pattern_w + 200, 4), Color(mass, 0.26))
	var fx := 0.0
	while fx < pattern_w:
		draw_rect(Rect2(fx, VIEW_H - BOTTOM + 16, 3, BOTTOM + 60), Color(mass, 0.18))
		fx += 240.0


## Archiv: Regalbrett mit hängenden Etiketten oben, Regalwangen, Buchrücken unten.
func _archiv(mass: Color, thin: Color) -> void:
	draw_rect(Rect2(-100, -60, pattern_w + 200, 50 + 60), Color(mass, 0.44))
	draw_rect(Rect2(-100, 44, pattern_w + 200, 6), Color(mass, 0.30))
	var lx := _rng.randf_range(100, 500)
	while lx < pattern_w:
		var slen := _rng.randf_range(30, 70)
		draw_line(Vector2(lx, 50), Vector2(lx, 50 + slen), Color(mass, 0.40), 1.6, true)
		draw_rect(Rect2(lx - 11, 50 + slen, 22, 30), Color(mass, 0.42))
		draw_rect(Rect2(lx - 7, 50 + slen + 8, 14, 3), Color(mass, 0.22))
		draw_rect(Rect2(lx - 7, 50 + slen + 15, 10, 3), Color(mass, 0.22))
		lx += _rng.randf_range(520, 900)
	# Regalwangen
	for i in 2:
		var x := 1100.0 + i * 1700.0 + _rng.randf_range(-400, 400)
		draw_rect(Rect2(x - 11, -60, 22, VIEW_H + 120), Color(thin, 0.20))
		var by := 200.0
		while by < VIEW_H:
			draw_rect(Rect2(x - 16, by, 32, 4), Color(thin, 0.16))
			by += 230.0
	# Regalbrett unten mit Buchrücken davor
	var board_y := VIEW_H - BOTTOM + 14
	draw_rect(Rect2(-100, board_y, pattern_w + 200, BOTTOM + 60), Color(mass, 0.42))
	draw_rect(Rect2(-100, board_y, pattern_w + 200, 5), Color(mass, 0.26))
	var bx := _rng.randf_range(-40, 60)
	while bx < pattern_w:
		var w := _rng.randf_range(12, 30)
		var h := _rng.randf_range(10, 34)
		if _rng.randf() < 0.8:
			draw_rect(Rect2(bx, board_y - h, w, h + 2), Color(mass, 0.40))
			draw_rect(Rect2(bx + 2, board_y - h + 4, w - 4, 2), Color(mass, 0.18))
		bx += w + _rng.randf_range(1, 5)


# ---------------------------------------------------------------- Bausteine

## Schmaler Mast über die volle Höhe, sehr transparent — reine Tiefenmarke.
func _mast(x: float, thin: Color) -> void:
	draw_rect(Rect2(x - 6, -60, 12, VIEW_H + 120), Color(thin, 0.17))
	draw_rect(Rect2(x - 2, -60, 4, VIEW_H + 120), Color(thin, 0.10))


## Ast: leicht wackelnde Linie, sich verjüngend, mit Blättern an den Segmenten.
func _branch(from: Vector2, to: Vector2, w0: float, w1: float, col: Color, leaf: Color) -> void:
	var n := 6
	var pts: Array[Vector2] = []
	for i in n + 1:
		var t := float(i) / n
		var p := from.lerp(to, t)
		p += Vector2(0, sin(t * PI) * -26.0 + _rng.randf_range(-6, 6))
		pts.append(p)
	for i in n:
		var t := float(i) / n
		draw_line(pts[i], pts[i + 1], col, lerpf(w0, w1, t), true)
		if i >= 1:
			var dir: Vector2 = (pts[i + 1] - pts[i]).normalized()
			var side := Vector2(-dir.y, dir.x)
			for j in 3:
				var base: Vector2 = pts[i].lerp(pts[i + 1], _rng.randf_range(0.1, 0.9))
				var s := 1.0 if _rng.randf() < 0.5 else -1.0
				var ang := dir.angle() + s * _rng.randf_range(0.6, 1.3)
				_leaf(base + side * s * 4.0, ang, _rng.randf_range(26, 44), _rng.randf_range(11, 17), leaf)
	# Blattbüschel an der Spitze
	for j in 5:
		_leaf(to + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-16, 16)), _rng.randf_range(0, TAU), _rng.randf_range(26, 40), _rng.randf_range(11, 16), leaf)


## Blatt: spitze Ellipse (8 Punkte), gedreht.
func _leaf(p: Vector2, ang: float, length: float, width: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var shape := [Vector2(0, 0), Vector2(0.25, -0.5), Vector2(0.55, -0.42), Vector2(1, 0), Vector2(0.55, 0.42), Vector2(0.25, 0.5)]
	for s in shape:
		var v: Vector2 = s
		pts.append(p + Vector2(v.x * length, v.y * width).rotated(ang))
	draw_colored_polygon(pts, col)


## Durchhängendes Kabel (Parabel).
func _cable(a: Vector2, b: Vector2, sag: float, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + Vector2(0, sag * 4.0 * t * (1.0 - t)))
	draw_polyline(pts, col, w, true)


## Tropfen unter einem Kabel (statisch — Regen selbst gehört zum Wetter).
func _drops(a: Vector2, b: Vector2, sag: float, col: Color) -> void:
	var t := _rng.randf_range(0.05, 0.12)
	while t < 0.95:
		var p := a.lerp(b, t) + Vector2(0, sag * 4.0 * t * (1.0 - t))
		var r := _rng.randf_range(2.2, 3.6)
		draw_circle(p + Vector2(0, r + 1.5), r, col)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.7, r + 1), p, p + Vector2(r * 0.7, r + 1)]), col)
		t += _rng.randf_range(0.06, 0.16)


## Hängende Laterne: Stange von oben, Gehäuse, schwacher warmer Kern (kein HDR).
func _lantern(x: float, col: Color, warm: bool) -> void:
	var y := 26.0 + _rng.randf_range(0, 30)
	draw_rect(Rect2(x - 2.5, -60, 5, y + 60), col)
	draw_rect(Rect2(x - 14, y, 28, 6), col)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 17, y + 6), Vector2(x + 17, y + 6), Vector2(x + 13, y + 46), Vector2(x - 13, y + 46)]), col)
	draw_rect(Rect2(x - 15, y + 46, 30, 5), col)
	if warm:
		draw_rect(Rect2(x - 8, y + 14, 16, 26), Color(pal.lamp.r, pal.lamp.g, pal.lamp.b, 0.22))


## Grasbüschel entlang einer Kante.
func _grass(y: float, col: Color) -> void:
	var gx := _rng.randf_range(0, 80)
	while gx < pattern_w:
		var n := 3 + _rng.randi() % 4
		for i in n:
			var h := _rng.randf_range(10, 26)
			var dx := (i - n * 0.5) * 5.0
			draw_colored_polygon(PackedVector2Array([Vector2(gx + dx - 3, y + 8), Vector2(gx + dx + _rng.randf_range(-4, 4), y - h), Vector2(gx + dx + 3, y + 8)]), col)
		gx += _rng.randf_range(90, 260)
