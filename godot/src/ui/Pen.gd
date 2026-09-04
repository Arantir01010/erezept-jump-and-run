class_name Pen
## PEN — Zeichen-Vokabular für die Info-Screens (Hauptmenü, Zeitreise, Probelauf,
## ePA-Wissen). Alle Screens leben im 640×360-Design-Raum der Web-Fassung und
## werden als Node2D mit Skalierung 3 auf 1920×1080 gebracht — die Koordinaten
## der Originale gelten deshalb unverändert. Farben sind Integer-Hex wie im
## Original (0xRRGGBB), Alpha kommt als eigener Parameter.

const K := Color(0.302, 0.890, 1.0)        # KUEHL_GESCHUETZT 0x4de3ff
const WARM := Color(1.0, 0.541, 0.227)     # WARM_OFFEN 0xff8a3a
const DUNST_AUFHELLUNG := 0.34

# ---------------------------------------------------------------- Farben

static func hex(v: int, a := 1.0) -> Color:
	return Color(((v >> 16) & 255) / 255.0, ((v >> 8) & 255) / 255.0, (v & 255) / 255.0, a)


static func html(s: String, a := 1.0) -> Color:
	var c := Color.html(s)
	c.a = a
	return c


static func darken(c: Color, t: float) -> Color:
	var k := 1.0 - clampf(t, 0.0, 1.0)
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func mix(a: Color, b: Color, t: float) -> Color:
	var m := a.lerp(b, clampf(t, 0.0, 1.0))
	m.a = a.a
	return m


static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Dunstfarbe der Farbwelt: Horizont Richtung Weiß aufgehellt.
static func fog_of(sky_bottom: Color) -> Color:
	return sky_bottom.lerp(Color.WHITE, DUNST_AUFHELLUNG)


# ---------------------------------------------------------------- Flächen

static func rect(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(x, y, w, h), col)


static func srect(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color, width := 1.0) -> void:
	c.draw_rect(Rect2(x, y, w, h), col, false, width)


static func rrect(c: CanvasItem, x: float, y: float, w: float, h: float, r: float, col: Color) -> void:
	c.draw_colored_polygon(_rrect_points(x, y, w, h, r), col)


static func srrect(c: CanvasItem, x: float, y: float, w: float, h: float, r: float, col: Color, width := 1.0) -> void:
	var pts := _rrect_points(x, y, w, h, r)
	pts.append(pts[0])
	c.draw_polyline(pts, col, width, true)


static func _rrect_points(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = minf(r, minf(w, h) * 0.5)
	var pts := PackedVector2Array()
	var corners := [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	for i in 4:
		var a0 := -PI * 0.5 + i * PI * 0.5
		for s in 5:
			var a := a0 + s * (PI * 0.5) / 4.0
			pts.append(corners[i] + Vector2(cos(a), sin(a)) * r)
	return pts


static func circle(c: CanvasItem, x: float, y: float, r: float, col: Color) -> void:
	c.draw_circle(Vector2(x, y), r, col)


static func scircle(c: CanvasItem, x: float, y: float, r: float, col: Color, width := 1.0) -> void:
	c.draw_arc(Vector2(x, y), r, 0.0, TAU, 40, col, width, true)


static func arc(c: CanvasItem, x: float, y: float, r: float, a0: float, a1: float, col: Color, width := 1.0) -> void:
	c.draw_arc(Vector2(x, y), r, a0, a1, 32, col, width, true)


## Ellipse wie Phasers fillEllipse: Mittelpunkt + GESAMTE Breite/Höhe.
static func ellipse(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_colored_polygon(_ellipse_points(x, y, w, h), col)


static func sellipse(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color, width := 1.0) -> void:
	var pts := _ellipse_points(x, y, w, h)
	pts.append(pts[0])
	c.draw_polyline(pts, col, width, true)


static func _ellipse_points(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a := i * TAU / 28.0
		pts.append(Vector2(x + cos(a) * w * 0.5, y + sin(a) * h * 0.5))
	return pts


static func tri(c: CanvasItem, x0: float, y0: float, x1: float, y1: float, x2: float, y2: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1), Vector2(x2, y2)]), col)


static func poly(c: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	c.draw_colored_polygon(pts, col)


static func line(c: CanvasItem, x0: float, y0: float, x1: float, y1: float, col: Color, width := 1.0) -> void:
	c.draw_line(Vector2(x0, y0), Vector2(x1, y1), col, width, true)


static func polyline(c: CanvasItem, pts: PackedVector2Array, col: Color, width := 1.0) -> void:
	c.draw_polyline(pts, col, width, true)


## Vertikaler Farbverlauf (oben → unten).
static func vgradient(c: CanvasItem, x: float, y: float, w: float, h: float, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	var cols := PackedColorArray([top, top, bottom, bottom])
	c.draw_polygon(pts, cols)


## Weicher Lichtfleck (radiale Textur) — auf einem additiven Layer zeichnen.
static func glow(c: CanvasItem, x: float, y: float, col: Color, radius: float, a: float) -> void:
	c.draw_texture_rect(Fx.radial_texture(), Rect2(x - radius, y - radius, radius * 2.0, radius * 2.0), false, Color(col.r, col.g, col.b, a))


## Flacher Lichtschein am Boden: zwei gestufte Ellipsen (statt schwebendem Ball).
static func bodenschein(c: CanvasItem, x: float, y: float, breite: float, a := 0.09) -> void:
	ellipse(c, x, y, breite * 1.7, breite * 0.16, hex(0xffd9a0, a * 0.6))
	ellipse(c, x, y, breite, breite * 0.11, hex(0xffd9a0, a))


# ---------------------------------------------------------------- Menschen
# Figuren-Paletten aus krankenhaus.ts — dieselben Gesichter auf allen Screens.

const HAUT := [0xeec39a, 0xc98850, 0x8a5a3b]
const P_ARZT := {"haut": 0xeec39a, "oben": 0x5c7ba8, "unten": 0x33405c, "haar": 0x2b2530, "kittel": true}
const P_AERZTIN := {"haut": 0x8a5a3b, "oben": 0x8a5f9e, "unten": 0x33405c, "haar": 0x14101a, "kittel": true}
const P_PFLEGE := {"haut": 0xc98850, "oben": 0x5fc4b8, "unten": 0x3d5a74, "haar": 0x6b4326}
const P_OP := {"haut": 0xeec39a, "oben": 0x69b894, "unten": 0x4d8a70, "haar": 0x69b894}
const P_PATIENT := {"haut": 0xc98850, "oben": 0xa9b9d6, "unten": 0xa9b9d6, "haar": 0xcfd4de}
const P_BESUCH := {"haut": 0xeec39a, "oben": 0xc07a4f, "unten": 0x2e3a50, "haar": 0x8a5a33}
const P_TECHNIK := {"haut": 0x8a5a3b, "oben": 0x4d6a8f, "unten": 0x2e3a50, "haar": 0x2b2530}
const P_BOTE := {"haut": 0x8a5a3b, "oben": 0xa0764d, "unten": 0x2e3a50, "haar": 0x14101a}
const P_OMA := {"haut": 0xeec39a, "oben": 0x8a5f9e, "unten": 0x4a3a5c, "haar": 0xcfd4de}
const P_GRUEN := {"haut": 0xc98850, "oben": 0x6a8f4d, "unten": 0x2e3a50, "haar": 0x2b2530}
const P_GELB := {"haut": 0x8a5a3b, "oben": 0xd0a04a, "unten": 0x33405c, "haar": 0x14101a}
const P_KIND := {"haut": 0xeec39a, "oben": 0xd06a6a, "unten": 0x3d5a74, "haar": 0x8a5a33}


## Pixel-Figur, ~13 px hoch, Füße auf (x, y_fuss). `schritt` = Laufzyklus
## (0 = stehen), `dir` = Blickrichtung. `a` = Gesamt-Alpha (Ein-/Ausblenden).
static func figur(c: CanvasItem, x: float, y_fuss: float, p: Dictionary, schritt := 0.0, dir := 1, a := 1.0) -> void:
	var bob := 0.0 if schritt == 0.0 else absf(sin(schritt * TAU)) * 0.6
	var bein := 0.0 if schritt == 0.0 else sin(schritt * TAU) * 1.7
	var y := y_fuss - bob
	var kittel: bool = p.get("kittel", false)
	var unten := hex(p["unten"], a)
	var oben := hex(0xe9eef8 if kittel else p["oben"], a)
	rect(c, x - 2 + bein, y - 4, 1.8, 4 + bob, unten)
	rect(c, x + 0.2 - bein, y - 4, 1.8, 4 + bob, unten)
	rect(c, x - 2.6, y - 9.2, 5.2, 5.4, oben)
	if kittel:
		rect(c, x - 0.7, y - 9.2, 1.4, 5.4, hex(p["oben"], a))
	rect(c, x - 3.4 - bein * 0.4, y - 8.8, 1, 3.6, oben)
	rect(c, x + 2.4 + bein * 0.4, y - 8.8, 1, 3.6, oben)
	rect(c, x - 1.8, y - 13, 3.6, 3.8, hex(p["haut"], a))
	var haar := hex(p["haar"], a)
	rect(c, x - 1.8, y - 13, 3.6, 1.3, haar)
	if dir == 1:
		rect(c, x - 1.8, y - 13, 1, 2.6, haar)
	else:
		rect(c, x + 0.8, y - 13, 1, 2.6, haar)


## Sitzende Figur auf Sitzhöhe `y_sitz`; `bein_schwung` lässt Beine baumeln.
static func sitzend(c: CanvasItem, x: float, y_sitz: float, p: Dictionary, bein_schwung := 0.0, a := 1.0) -> void:
	var kittel: bool = p.get("kittel", false)
	var unten := hex(p["unten"], a)
	rect(c, x - 2.4, y_sitz - 1.6, 4.6, 1.6, unten)
	rect(c, x + 1 + bein_schwung, y_sitz, 1.6, 3.4, unten)
	rect(c, x - 1.6 - bein_schwung, y_sitz, 1.6, 3.4, unten)
	rect(c, x - 2.4, y_sitz - 6.8, 4.8, 5.2, hex(0xe9eef8 if kittel else p["oben"], a))
	rect(c, x - 1.7, y_sitz - 10.4, 3.4, 3.6, hex(p["haut"], a))
	rect(c, x - 1.7, y_sitz - 10.4, 3.4, 1.2, hex(p["haar"], a))


## Hin- und herlaufende Figur zwischen xa und xb (Dreieckswelle über t).
## Rückgabe: [x, dir]
static func pendel(t: float, xa: float, xb: float, tempo: float, versatz: float) -> Array:
	var dauer := (xb - xa) / tempo
	var u := fmod((t + versatz) / dauer, 2.0)
	if u < 1.0:
		return [xa + (xb - xa) * u, 1]
	return [xb - (xb - xa) * (u - 1.0), -1]


# ---------------------------------------------------------------- EKG & Wege

static func ekg_puls(u: float) -> float:
	if u < 0.55:
		return 0.0
	if u < 0.62:
		return -0.25
	if u < 0.68:
		return 1.0
	if u < 0.74:
		return -0.55
	if u < 0.84:
		return 0.18
	return 0.0


static func ekg(c: CanvasItem, x: float, y_mitte: float, w: float, amp: float, t: float, phase: float, col := K, width := 0.6) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var u := float(i) / n
		var v := ekg_puls(fmod(u * 1.15 + t * 0.55 + phase, 1.0))
		pts.append(Vector2(x + u * w, y_mitte - v * amp))
	c.draw_polyline(pts, alpha(col, 0.9), width, true)


## Polylinien-Pfad: Punkt bei Anteil u (0..1) der Gesamtlänge.
static func pfad_punkt(pts: Array, u: float) -> Vector2:
	var gesamt := 0.0
	for i in pts.size() - 1:
		gesamt += (pts[i + 1] as Vector2).distance_to(pts[i])
	var rest := clampf(u, 0.0, 1.0) * gesamt
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var l := a.distance_to(b)
		if rest <= l:
			return a.lerp(b, 0.0 if l == 0.0 else rest / l)
		rest -= l
	return pts[pts.size() - 1]


static func pfad_linie(c: CanvasItem, pts: Array, col: Color, width := 0.6) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(v)
	c.draw_polyline(p, col, width, true)


## Weiche Blende: 0 → 1 in 0,5 s ab `von`, 1 → 0 in 0,5 s vor `bis`.
static func blende(u: float, von: float, bis: float, rampe := 0.5) -> float:
	return clampf(minf(minf((u - von) / rampe, (bis - u) / rampe), 1.0), 0.0, 1.0)


# ---------------------------------------------------------------- Paul & REZI
# Ergänzungen für die Stations-Briefings (Briefing.gd): Paul als Pixel-Figur mit
# Kapuzenpulli, REZI als kleine leuchtende Kapsel, die Hülle als Ring um die Figur.
# Fachliche Farben bleiben: kühl = verschlüsselt, violett = VAU, Klartext = kein Ring.

const P_PAUL := {"haut": 0xf5cca8, "oben": 0xeb6142, "unten": 0x3d4769, "haar": 0x52332b}
const KAPUZE := 0xad3d37
const VAU_COL := Color(0.58, 0.44, 0.96)    # Palette.VAU
const DENY_COL := Color(0.93, 0.31, 0.26)   # Palette.DENY
const OK_COL := Color(0.30, 0.74, 0.42)     # Palette.OK
const GOLD_COL := Color(1.0, 0.78, 0.30)    # Palette.GOLD


## Paul (~13 px hoch, Füße auf y_fuss). `duck` = geduckt: kompakter Ball, Kopf vorn (~10 px).
static func paul(c: CanvasItem, x: float, y_fuss: float, schritt := 0.0, dir := 1, a := 1.0, duck := false) -> void:
	if duck:
		var unten := hex(P_PAUL["unten"], a)
		var oben := hex(P_PAUL["oben"], a)
		rect(c, x - 2.8, y_fuss - 2.4, 2.0, 2.4, unten)
		rect(c, x + 0.8, y_fuss - 2.4, 2.0, 2.4, unten)
		rect(c, x - 3.2, y_fuss - 6.6, 6.4, 4.4, oben)
		rect(c, x - 3.2 - dir * 0.9, y_fuss - 6.6, 1.4, 4.4, hex(KAPUZE, a))
		var hx := x - 1.8 + dir * 1.6
		rect(c, hx, y_fuss - 9.8, 3.6, 3.4, hex(P_PAUL["haut"], a))
		rect(c, hx, y_fuss - 9.8, 3.6, 1.2, hex(P_PAUL["haar"], a))
		return
	figur(c, x, y_fuss, P_PAUL, schritt, dir, a)
	# Kapuze hinter dem Kopf (Rückseite) mit hellem Bommel
	var bob := 0.0 if schritt == 0.0 else absf(sin(schritt * TAU)) * 0.6
	var y := y_fuss - bob
	var kx := x - 2.8 if dir == 1 else x + 1.8
	rect(c, kx, y - 13.2, 1.0, 4.2, hex(KAPUZE, a))
	rect(c, kx - (0.5 if dir == 1 else -0.5), y - 9.2, 1.0, 1.0, hex(0xeef2f8, 0.9 * a))


## Hülle als Ring um die Figur (Füße auf y_fuss): kühl = verschlüsselt, violett = VAU.
## Klartext zeichnet nichts — sichtbar heißt ungeschützt.
static func huelle_ring(c: CanvasItem, x: float, y_fuss: float, zustand: String, a := 1.0, t := 0.0) -> void:
	if zustand != "verschluesselt" and zustand != "vau":
		return
	var col := VAU_COL if zustand == "vau" else K
	var puls := 0.75 + 0.25 * sin(t * 4.0)
	ellipse(c, x, y_fuss - 6.4, 12.0, 16.5, alpha(col, 0.10 * a))
	sellipse(c, x, y_fuss - 6.4, 12.0, 16.5, alpha(col, 0.85 * puls * a), 0.8)


## REZI: leuchtende Kapsel mit Knopfaugen und Antenne. `s` = Größe,
## `verschluesselt` = kühler Ring, `siegel` = goldener Ring (Signatur erhalten).
static func rezi(c: CanvasItem, x: float, y: float, a := 1.0, s := 1.0, verschluesselt := false, siegel := false) -> void:
	var col := K
	circle(c, x, y, 6.5 * s, alpha(col, 0.16 * a))
	rrect(c, x - 4.5 * s, y - 3.0 * s, 9.0 * s, 6.0 * s, 3.0 * s, alpha(col, 0.95 * a))
	rect(c, x - 3.0 * s, y - 3.0 * s, 6.0 * s, 1.0 * s, Color(1, 1, 1, 0.25 * a))
	rect(c, x - 2.7 * s, y - 1.7 * s, 1.7 * s, 2.0 * s, Color(1, 1, 1, 0.95 * a))
	rect(c, x + 0.9 * s, y - 1.7 * s, 1.7 * s, 2.0 * s, Color(1, 1, 1, 0.95 * a))
	rect(c, x - 2.0 * s, y - 1.2 * s, 0.8 * s, 1.1 * s, hex(0x0a1220, a))
	rect(c, x + 1.6 * s, y - 1.2 * s, 0.8 * s, 1.1 * s, hex(0x0a1220, a))
	line(c, x, y - 3.0 * s, x + 0.8 * s, y - 5.6 * s, alpha(col, 0.9 * a), 0.7)
	circle(c, x + 0.9 * s, y - 5.9 * s, 0.9 * s, Color(1, 1, 1, 0.95 * a))
	if verschluesselt:
		scircle(c, x, y, 6.8 * s, alpha(col, 0.8 * a), 0.7)
	if siegel:
		scircle(c, x, y, 6.0 * s, alpha(GOLD_COL, 0.95 * a), 1.0)
