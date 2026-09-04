class_name KartenFx
extends RefCounted
## KARTEN-FX — gemeinsame Zeichnung und Animation der Ausweise (eGK, HBA, SMC-B).
## Eine Karte ist Schlüssel und Identität, kein Speicher: Sie trägt Kürzel, Namen
## und Chip — sonst nichts. Genutzt von der liegenden Karte (Welt), vom
## Kartenleser (gesteckt), vom HUD (Fächer) und vom Flug Welt → HUD.
##
## Bewegtes ist reine Funktion der Zeit (Glanz, Schweben). Zustand hält nur der
## Flug-Knoten (Start, Ziel, Fortschritt). Kein Glühen auf Kanten: Der Chip
## fängt kurz Licht (Glanzband), mehr nicht.

## Die Wahrheit für alle Anzeigen: Kürzel, Name, Rolle, Farbe.
const INFO := {
	"egk": {"kurz": "eGK", "name": "Gesundheitskarte", "rolle": "Versicherte", "color": Color(0.35, 0.80, 0.55)},
	"hba": {"kurz": "HBA", "name": "Heilberufsausweis", "rolle": "Heilberuf", "color": Color(0.85, 0.55, 0.30)},
	"smcb": {"kurz": "SMC-B", "name": "Praxisausweis", "rolle": "Einrichtung", "color": Color(0.55, 0.65, 0.95)},
}

## Grundmaß der Karte in der Welt (Seitenverhältnis wie eine Chipkarte, ~1,58).
const BASE := Vector2(72, 46)
## Der Chip fängt alle 2,6 s Licht (0,38 Hz — weit unter 3 Hz).
const GLINT_PERIOD := 2.6
const GLINT_SHARE := 0.32


static func info(card: String) -> Dictionary:
	return INFO.get(card, INFO["egk"])


static func color_of(card: String) -> Color:
	return info(card)["color"]


## Glanzlage 0..1 während des Lichtfangs, sonst -1 (reine Funktion der Zeit).
static func glint_phase(t: float) -> float:
	var ph := fmod(t, GLINT_PERIOD) / GLINT_PERIOD
	return ph / GLINT_SHARE if ph < GLINT_SHARE else -1.0


## Karte in ein Rechteck zeichnen.
##   mode: "voll" (dabei), "umriss" (leer / erwartet), "gesteckt" (voll + Haken)
##   glint: 0..1 = Lage des Glanzbandes, < 0 = keins
##   with_name: Name als zweite Zeile (erst ab ~40 px Höhe lesbar)
static func draw_card(ci: CanvasItem, r: Rect2, card: String, mode := "voll", glint := -1.0, alpha := 1.0, with_name := false) -> void:
	var inf := info(card)
	var c: Color = inf["color"]
	var w := r.size.x
	var h := r.size.y
	var radius := int(maxf(3.0, h * 0.16))
	var kurz := str(inf["kurz"])
	if mode == "umriss":
		var sbo := StyleBoxFlat.new()
		sbo.bg_color = Color(c.r, c.g, c.b, 0.07 * alpha)
		sbo.border_color = Color(c.r, c.g, c.b, 0.60 * alpha)
		sbo.set_border_width_all(maxi(1, int(round(h * 0.06))))
		sbo.set_corner_radius_all(radius)
		sbo.anti_aliasing = true
		ci.draw_style_box(sbo, r)
		# Chip nur als Umriss, Kürzel gedämpft
		var chip_o := Rect2(r.position.x + w * 0.11, r.position.y + h * 0.30, w * 0.20, h * 0.30)
		ci.draw_rect(chip_o, Color(c.r, c.g, c.b, 0.45 * alpha), false, 1.0)
		var xo := chip_o.end.x + w * 0.04
		var two := r.end.x - w * 0.06 - xo
		var fso := fit_font(Brand.sans("heavy"), kurz, two, maxi(7, int(h * 0.36)))
		ci.draw_string(Brand.sans("heavy"), Vector2(xo, r.position.y + h * 0.5 + fso * 0.36), kurz,
			HORIZONTAL_ALIGNMENT_CENTER, two, fso, Color(c.r, c.g, c.b, 0.75 * alpha))
		return
	# Kontur (dunkel, nicht schwarz) und Körper: Kartenfarbe dunkel und kühl, Kappe oben hell
	var outline := Color(0.08, 0.10, 0.14, 0.9 * alpha)
	var body := Palette.shade(c, 0.48)
	body.a = alpha
	var sb := StyleBoxFlat.new()
	sb.bg_color = body
	sb.border_color = Color(c.r, c.g, c.b, 0.95 * alpha)
	sb.set_border_width_all(maxi(1, int(round(h * 0.055))))
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	var so := StyleBoxFlat.new()
	so.bg_color = outline
	so.set_corner_radius_all(radius + 1)
	so.anti_aliasing = true
	ci.draw_style_box(so, Rect2(r.position - Vector2(1.5, 1.5), r.size + Vector2(3, 3)))
	ci.draw_style_box(sb, r)
	# Lichtkappe oben (Licht von oben), leicht wärmer
	var cap := Palette.tint(c, 0.35)
	var cap_r := Rect2(r.position.x + w * 0.08, r.position.y + h * 0.10, w * 0.84, h * 0.16)
	ci.draw_rect(cap_r, Color(cap.r, cap.g, cap.b, 0.16 * alpha))
	# Unterschriftsband unten
	ci.draw_rect(Rect2(r.position.x + w * 0.11, r.end.y - h * 0.21, w * 0.78, h * 0.055), Color(cap.r, cap.g, cap.b, 0.28 * alpha))
	# Chip: Gold, mit Kontaktlinien — beim Lichtfang heller
	var chip := Rect2(r.position.x + w * 0.11, r.position.y + h * 0.30, w * 0.20, h * 0.30)
	var peak := 0.0
	if glint >= 0.0:
		peak = sin(clampf(glint, 0.0, 1.0) * PI)
	var gold := Color(0.86, 0.66, 0.26, alpha)
	var gold_dark := Color(0.55, 0.40, 0.14, alpha)
	var chip_c := gold.lerp(Palette.tint(gold, 0.6), peak * 0.8)
	if peak > 0.0 and not Fx.web_fallback():
		chip_c = Palette.glow(chip_c, 1.0 + 0.5 * peak)
	var sbc := StyleBoxFlat.new()
	sbc.bg_color = chip_c
	sbc.set_corner_radius_all(maxi(1, int(h * 0.05)))
	sbc.anti_aliasing = true
	ci.draw_style_box(sbc, chip)
	var lw := maxf(1.0, h * 0.025)
	ci.draw_line(Vector2(chip.position.x, chip.position.y + chip.size.y * 0.36), Vector2(chip.end.x, chip.position.y + chip.size.y * 0.36), gold_dark, lw)
	ci.draw_line(Vector2(chip.position.x, chip.position.y + chip.size.y * 0.68), Vector2(chip.end.x, chip.position.y + chip.size.y * 0.68), gold_dark, lw)
	ci.draw_line(Vector2(chip.position.x + chip.size.x * 0.5, chip.position.y), Vector2(chip.position.x + chip.size.x * 0.5, chip.end.y), gold_dark, lw)
	# Kürzel (rechts vom Chip), darunter optional der Name
	var x0 := chip.end.x + w * 0.05
	var tw := r.end.x - w * 0.07 - x0
	var fs := fit_font(Brand.sans("heavy"), kurz, tw, maxi(7, int(h * (0.30 if with_name else 0.36))))
	var ty := r.position.y + (h * 0.42 if with_name else h * 0.5) + fs * 0.36
	var white := Color(0.98, 0.98, 1.0, alpha)
	ci.draw_string_outline(Brand.sans("heavy"), Vector2(x0, ty), kurz, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, maxi(1, int(fs * 0.18)), Color(0.05, 0.07, 0.10, 0.7 * alpha))
	ci.draw_string(Brand.sans("heavy"), Vector2(x0, ty), kurz, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, white)
	if with_name:
		var fn := maxi(6, int(h * 0.15))
		var name_c := Palette.tint(c, 0.55)
		ci.draw_string(Brand.sans("medium"), Vector2(r.position.x + w * 0.11, r.end.y - h * 0.26), str(inf["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, w * 0.80, fn, Color(name_c.r, name_c.g, name_c.b, 0.95 * alpha))
	# Glanzband: schräg, läuft einmal über die Karte, innerhalb der Kante
	if peak > 0.0:
		var g := clampf(glint, 0.0, 1.0)
		var xa := r.position.x + (g * 1.7 - 0.35) * w
		var a := Vector2(xa, r.position.y + 2.0)
		var b := Vector2(xa - h * 0.55, r.end.y - 2.0)
		_clipped_line(ci, a, b, r.position.x + radius * 0.6, r.end.x - radius * 0.6, Color(1, 1, 1, 0.22 * peak * alpha), h * 0.16)
		_clipped_line(ci, a + Vector2(h * 0.14, 0), b + Vector2(h * 0.14, 0), r.position.x + radius * 0.6, r.end.x - radius * 0.6, Color(1, 1, 1, 0.10 * peak * alpha), h * 0.06)
	# Haken: gesteckt
	if mode == "gesteckt":
		var bc := Vector2(r.end.x - h * 0.16, r.position.y + h * 0.16)
		var br := h * 0.22
		ci.draw_circle(bc, br + 1.5, outline)
		ci.draw_circle(bc, br, Color(Palette.OK.r, Palette.OK.g, Palette.OK.b, alpha))
		var pts := PackedVector2Array([bc + Vector2(-br * 0.45, 0.0), bc + Vector2(-br * 0.1, br * 0.38), bc + Vector2(br * 0.5, -br * 0.4)])
		ci.draw_polyline(pts, white, maxf(1.5, br * 0.28), true)


## Schriftgröße so weit verkleinern, dass der Text in max_w passt (SMC-B auf kleinen Karten).
static func fit_font(font: Font, text: String, max_w: float, size: int) -> int:
	var s := size
	while s > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 1
	return s


## Linie auf einen x-Bereich beschneiden (Glanzband bleibt in der Karte).
static func _clipped_line(ci: CanvasItem, a: Vector2, b: Vector2, x_min: float, x_max: float, color: Color, width: float) -> void:
	var dx := b.x - a.x
	var t0 := 0.0
	var t1 := 1.0
	if absf(dx) < 0.001:
		if a.x < x_min or a.x > x_max:
			return
	else:
		var ta := (x_min - a.x) / dx
		var tb := (x_max - a.x) / dx
		t0 = maxf(0.0, minf(ta, tb))
		t1 = minf(1.0, maxf(ta, tb))
		if t1 <= t0:
			return
	ci.draw_line(a.lerp(b, t0), a.lerp(b, t1), color, width, true)


# ------------------------------------------------------------------ HUD-Anbindung

## Das HUD (Gruppe "hud"), bewusst untypisiert (kein Klassen-Zyklus).
static func find_hud(from: Node):
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group("hud")


## Pop im HUD-Fach (beim Aufnehmen/Stecken), wenn es das HUD gibt.
static func hud_pop(from: Node, card: String) -> void:
	var hud = find_hud(from)
	if hud != null and hud.has_method("card_pop"):
		hud.card_pop(card)


## Karte fliegt in einem Bogen von einer Weltposition in ihr HUD-Fach.
## Weltposition → Bildschirm über die Kamera-Transformation des Viewports;
## der Flug ist ein eigener Knoten im HUD-Layer. false, wenn es kein HUD gibt.
static func fly_to_hud(from: Node, world_pos: Vector2, card: String, on_arrive := Callable()) -> bool:
	var hud = find_hud(from)
	if hud == null or not hud.has_method("card_slot_screen_pos"):
		return false
	var vp := from.get_viewport()
	if vp == null:
		return false
	var start: Vector2 = vp.get_canvas_transform() * world_pos
	var goal: Vector2 = hud.card_slot_screen_pos(card)
	var zoom := 1.0
	var cam := vp.get_camera_2d()
	if cam:
		zoom = cam.zoom.x
	var f := Flight.new()
	f.card = card
	f.start = start
	f.goal = goal
	# Bogen: Scheitel oberhalb beider Punkte, etwas zum Ziel hin
	var lift := clampf(start.distance_to(goal) * 0.30, 90.0, 240.0)
	f.ctrl = Vector2(lerpf(start.x, goal.x, 0.45), minf(start.y, goal.y) - lift)
	f.start_scale = zoom
	var icon: Vector2 = hud.card_icon_size() if hud.has_method("card_icon_size") else Vector2(50, 32)
	f.end_scale = icon.x / BASE.x
	f.on_arrive = on_arrive
	f.hud = hud
	if hud.has_method("card_flight_started"):
		hud.card_flight_started(card)
	hud.add_child(f)
	return true


## Der Flug: quadratische Bézier-Kurve, weich beschleunigt und gebremst,
## Karte schrumpft von Weltgröße (× Kamerazoom) auf Fachgröße, dreht sich gerade.
class Flight extends Node2D:
	var card := "egk"
	var start := Vector2.ZERO
	var goal := Vector2.ZERO
	var ctrl := Vector2.ZERO
	var start_scale := 1.2
	var end_scale := 0.7
	var duration := 0.62
	var on_arrive := Callable()
	var hud = null
	var _t := 0.0

	func _ready() -> void:
		z_index = 60
		position = start
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta / duration
		if _t >= 1.0:
			_finish()
			return
		position = _pos(_t)
		queue_redraw()

	func _ease(u: float) -> float:
		var v := clampf(u, 0.0, 1.0)
		return v * v * (3.0 - 2.0 * v)

	func _pos(u: float) -> Vector2:
		var e := _ease(u)
		var m := 1.0 - e
		return m * m * start + 2.0 * m * e * ctrl + e * e * goal

	func _scale_at(u: float) -> float:
		return lerpf(start_scale, end_scale, _ease(u))

	func _rot_at(u: float) -> float:
		var e := _ease(u)
		return lerpf(-0.28, 0.0, e) + sin(e * PI) * 0.12

	func _draw() -> void:
		# Nachzieher: zwei blasse Kopien kurz hinter der Karte
		for i in 2:
			var k := 2 - i
			var ug := _t - 0.055 * float(k)
			if ug <= 0.0:
				continue
			var s := _scale_at(ug)
			draw_set_transform(_pos(ug) - position, _rot_at(ug), Vector2(s, s))
			KartenFx.draw_card(self, Rect2(-KartenFx.BASE / 2.0, KartenFx.BASE), card, "voll", -1.0, 0.16 * float(3 - k))
		var sc := _scale_at(_t)
		draw_set_transform(Vector2.ZERO, _rot_at(_t), Vector2(sc, sc))
		KartenFx.draw_card(self, Rect2(-KartenFx.BASE / 2.0, KartenFx.BASE), card, "voll", -1.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _finish() -> void:
		if hud != null and is_instance_valid(hud) and hud.has_method("card_pop"):
			hud.card_pop(card)
		if on_arrive.is_valid():
			on_arrive.call()
		queue_free()
