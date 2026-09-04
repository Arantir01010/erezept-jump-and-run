class_name Briefing
extends Vignette
## BRIEFING — Erklärscreen VOR jeder Station: Was passiert in der Wirklichkeit,
## was ist die Mechanik des Levels, was tust du (mit den Knopfnamen der erkannten
## Hardware) und welche Bausteine warten. In der Bühnenmitte eine animierte
## Mini-Szene (reine Funktion der Zeit, Pen-Vokabular), darunter die Handgriffe
## und die Bausteine-Leiste. Inhalte: BriefingDaten.gd. Ablauf (Main.gd):
## Karte → [ePA-Wissen] → Briefing → Level. Mindestdauer 6 s, danach jeder Knopf.
## Runde 3: Erzählzeilen im Erzählband (Vignette), Reiseroute der zehn Stationen
## oben, Bühnenlicht auf der Szene, die Bausteine treten nacheinander hervor.
##
## Fachliche Leitplanken (KAPSEL): VAU = Raum, kein Tunnel · Verschlüsselung ≠
## Signatur · abgelaufene Sitzung fällt in den Klartext · die eGK speichert nichts ·
## Angreifer werden nie bekämpft, sie scheitern · kein Blinken über 3 Hz ·
## warm/kühl/violett nur in ihrer Bedeutung (offen / verschlüsselt / VAU).

const GY := 250.0          # Bühnenboden der Mini-Szene (Design-Raum 640×360)
const SZ := 1.25           # Szene wird um die Bühnenmitte (320, GY) vergrößert
const PANEL_Y := 264.0
const PANEL_H := 68.0
const LEISTE_X := 96.0
const LEISTE_W := 520.0

# Wege der Datenpulse durch den Bühnensockel
const PFAD_01 := [Vector2(178, 250), Vector2(178, 257), Vector2(520, 257), Vector2(520, 250)]
const PFAD_13 := [Vector2(290, 250), Vector2(290, 257), Vector2(480, 257), Vector2(480, 250)]
const PFAD_13B := [Vector2(480, 250), Vector2(480, 257), Vector2(390, 257), Vector2(390, 250)]
# Tunnel-Prüfsummen (x, Bahn 0..2) in Station 03
const TUNNEL_ORBS := [[350.0, 0], [380.0, 1], [410.0, 2], [440.0, 1], [470.0, 0], [500.0, 2], [530.0, 1]]

var index := 0
var id := ""
var titel := ""
var key := ""
var daten := {}
var rufe: Array = []
var bausteine: Array = []
var baustein_labels: Array = []
var szene_zyklus := 16.0
var text_zyklus := 20.0


func _init(idx := 0) -> void:
	index = idx
	if idx >= 0 and idx < Game.playlist.size():
		id = str(Game.playlist[idx])
	daten = BriefingDaten.fuer(id)
	key = str(daten.get("key", ""))
	szene_zyklus = float(daten.get("szene", 16.0))
	var n: int = (daten.get("zeilen", []) as Array).size()
	text_zyklus = maxf(BriefingDaten.TAKT, n * BriefingDaten.TAKT)
	sperre = 6.0
	weiter_text = "%s: Los geht's!" % Kiosk.label_confirm()
	dots = []
	titel = id.to_upper()
	if id != "":
		var ld := LevelData.load_level(id)
		titel = ld.name_text().to_upper()
		bausteine = BriefingDaten.inventar(ld)


func _build() -> void:
	var stroke := Pen.hex(0x0a1730)
	label(W / 2, 22, "STATION %d / %d" % [index + 1, Game.playlist.size()], 5.5,
		{"color": Pen.hex(0xffd591), "spacing": 1.6, "stroke": stroke, "stroke_w": 1.0})
	header(titel, str(daten.get("untertitel", "")))
	story_cycle = text_zyklus
	var zl: Array = daten.get("zeilen", [])
	for i in zl.size():
		story_line(BriefingDaten.text(str(zl[i])), i * BriefingDaten.TAKT + (0.3 if i == 0 else 0.0), (i + 1) * BriefingDaten.TAKT)
	for s in daten.get("schilder", []):
		var arr: Array = s
		var sp := 0.0
		if arr.size() > 5:
			sp = float(arr[5])
		label(_sx(float(arr[0])), _sy(float(arr[1])), str(arr[2]), float(arr[3]),
			{"color": Pen.hex(int(arr[4])), "spacing": sp, "stroke": stroke, "stroke_w": 0.8})
	for r in daten.get("rufe", []):
		var arr: Array = r
		var l := label(_sx(float(arr[0])), _sy(float(arr[1])), str(arr[2]), float(arr[3]),
			{"color": Pen.hex(int(arr[4])), "spacing": 0.4, "stroke": stroke, "stroke_w": 0.9, "alpha": 0.0})
		rufe.append([l, float(arr[5]), float(arr[6])])
	# Tafel: Handgriffe und Bausteine dieses Levels
	label(20, 276, "DAS TUST DU", 5, {"color": Pen.hex(0xffd591), "spacing": 1.0, "origin": Vector2(0, 0.5)})
	label(LEISTE_X, 276, BriefingDaten.text(str(daten.get("tust", ""))), 7.2,
		{"color": Pen.hex(0xeef2f8), "bold": false, "origin": Vector2(0, 0.5)})
	label(20, 306, "BAUSTEINE", 5, {"color": Pen.hex(0xffd591), "spacing": 1.0, "origin": Vector2(0, 0.5)})
	for i in bausteine.size():
		baustein_labels.append(label(_leiste_x(i), 318, BriefingDaten.name_of(str(bausteine[i])), 4.4, {"color": Pen.hex(0xcfd6e6), "bold": false}))


func _leiste_x(i: int) -> float:
	var n := maxi(1, bausteine.size())
	var step := minf(58.0, LEISTE_W / n)
	return LEISTE_X + step * (i + 0.5)


## Szenen-Koordinaten (Bühnenraum um 320/GY) → Bildschirm-Design-Raum.
func _sx(x: float) -> float:
	return 320.0 + (x - 320.0) * SZ


func _sy(y: float) -> float:
	return GY + (y - GY) * SZ


## Zeichentransformation der Szene: alles Folgende wird um (320, GY) skaliert.
func _szene_an(c: CanvasItem) -> void:
	c.draw_set_transform(Vector2(320.0 * (1.0 - SZ), GY * (1.0 - SZ)), 0.0, Vector2(SZ, SZ))


func _szene_aus(c: CanvasItem) -> void:
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tick(_delta: float) -> void:
	# Bausteine-Leiste: ein Baustein nach dem anderen tritt hervor (nach dem Entrance)
	if tz > 1.2:
		var hi := _baustein_aktiv()
		for i in baustein_labels.size():
			var l: Label = baustein_labels[i]
			l.modulate = Color(1, 1, 1, 1) if i == hi else Color(0.82, 0.86, 0.92, 0.8)
	var u := fmod(tz, szene_zyklus)
	for r in rufe:
		var arr: Array = r
		var l: Label = arr[0]
		l.modulate.a = Pen.blende(u, float(arr[1]), float(arr[2]), 0.3)


# ------------------------------------------------------------------- Ebenen

func _draw_static(c: CanvasItem) -> void:
	_buehne(c)
	_panel(c)
	for i in bausteine.size():
		_icon(c, str(bausteine[i]), _leiste_x(i), 300)
	_szene_an(c)
	match key:
		"01": _statik_01(c)
		"02": _statik_02(c)
		"03": _statik_03(c)
		"04": _statik_04(c)
		"05": _statik_05(c)
		"13": _statik_13(c)
		"14": _statik_14(c)
		"15": _statik_15(c)
		"19": _statik_19(c)
		"20": _statik_20(c)
	_szene_aus(c)


func _draw_glow(c: CanvasItem) -> void:
	var K := Pen.K
	# Bühnenlicht: weicher Kegel von oben auf die Szene, warmer Schein am Sockel
	var accent: Color = theme["accent"]
	c.draw_polygon(PackedVector2Array([Vector2(250, 134), Vector2(390, 134), Vector2(640, GY + 2), Vector2(0, GY + 2)]),
		PackedColorArray([Pen.alpha(accent, 0.035), Pen.alpha(accent, 0.035), Pen.alpha(accent, 0.0), Pen.alpha(accent, 0.0)]))
	c.draw_polygon(PackedVector2Array([Vector2(296, 134), Vector2(344, 134), Vector2(560, GY + 2), Vector2(80, GY + 2)]),
		PackedColorArray([Pen.alpha(accent, 0.06), Pen.alpha(accent, 0.06), Pen.alpha(accent, 0.0), Pen.alpha(accent, 0.0)]))
	Pen.bodenschein(c, 320, GY + 1, 440, 0.07)
	_szene_an(c)
	match key:
		"01":
			Pen.glow(c, 520, 236, Pen.hex(0xffd9a0), 22, 0.10)
		"02":
			Pen.glow(c, 440, 220, Pen.GOLD_COL, 22, 0.10)
		"03":
			Pen.glow(c, 445, 226, K, 60, 0.07)
			Pen.glow(c, 270, 218, K, 18, 0.10)
		"04":
			Pen.glow(c, 466, 232, Pen.VAU_COL, 30, 0.12)
			Pen.glow(c, 355, 242, Pen.GOLD_COL, 18, 0.08)
		"05":
			Pen.glow(c, 150, 236, Pen.hex(0xffd9a0), 12, 0.08)
			Pen.glow(c, 330, 236, Pen.hex(0xffd9a0), 12, 0.08)
		"13":
			Pen.glow(c, 390, 230, Pen.hex(0xffd9a0), 22, 0.10)
			Pen.glow(c, 480, 228, K, 22, 0.08)
		"14":
			Pen.glow(c, 360, 222, Pen.VAU_COL, 46, 0.12)
		"15":
			Pen.glow(c, 320, 224, Pen.VAU_COL, 60, 0.11)
		"19":
			for gx in [200.0, 330.0, 460.0]:
				Pen.glow(c, gx, 232, Pen.hex(0xffd9a0), 14, 0.07)
		"20":
			Pen.glow(c, 430, 226, Pen.GOLD_COL, 30, 0.10)
			Pen.glow(c, 225, 234, Pen.VAU_COL, 22, 0.10)
	_szene_aus(c)


func _draw_life(c: CanvasItem) -> void:
	_route(c)
	_leiste_licht(c)
	var u := fmod(tz, szene_zyklus)
	_szene_an(c)
	match key:
		"01": _leben_01(c, u)
		"02": _leben_02(c, u)
		"03": _leben_03(c, u)
		"04": _leben_04(c, u)
		"05": _leben_05(c, u)
		"13": _leben_13(c, u)
		"14": _leben_14(c, u)
		"15": _leben_15(c, u)
		"19": _leben_19(c, u)
		"20": _leben_20(c, u)
	_szene_aus(c)


# ------------------------------------------------------------------- Rahmen

## Reiseroute oben: alle Stationen als Kette, geschaffte mit Haken, die
## aktuelle pulsiert. Reihenfolge trägt hier Information (der Weg durchs Spiel).
func _route(c: CanvasItem) -> void:
	var n := Game.playlist.size()
	if n <= 1:
		return
	var step := 20.0
	var x0 := 320.0 - (n - 1) * step * 0.5
	var y := 11.0
	Pen.rect(c, x0, y - 0.4, (n - 1) * step, 0.8, Color(1, 1, 1, 0.14))
	if index > 0:
		Pen.rect(c, x0, y - 0.5, index * step, 1.0, Pen.hex(BAND_ACCENT, 0.7))
	for i in n:
		var x := x0 + i * step
		if i < index:
			Pen.circle(c, x, y, 2.3, Pen.hex(BAND_ACCENT, 0.95))
			Pen.polyline(c, PackedVector2Array([Vector2(x - 1.1, y), Vector2(x - 0.2, y + 0.9), Vector2(x + 1.2, y - 1.0)]), Pen.hex(0x0a1730, 0.9), 0.5)
		elif i == index:
			var puls := 0.5 + 0.5 * sin(t * 3.0)
			Pen.circle(c, x, y, 4.4 + puls * 1.2, Pen.hex(BAND_ACCENT, 0.18))
			Pen.circle(c, x, y, 3.0, Pen.hex(BAND_ACCENT, 0.95))
			Pen.circle(c, x, y, 1.2, Pen.hex(0x0a1730, 0.9))
		else:
			Pen.circle(c, x, y, 2.0, Pen.hex(0x0e1a2c, 0.95))
			Pen.scircle(c, x, y, 2.0, Color(1, 1, 1, 0.35), 0.6)


## Welcher Baustein der Leiste gerade hervortritt (alle 1,5 s der nächste).
func _baustein_aktiv() -> int:
	if bausteine.is_empty() or tz <= 1.2:
		return -1
	return int(floor(tz / 1.5)) % bausteine.size()


## Lichtring um den hervortretenden Baustein.
func _leiste_licht(c: CanvasItem) -> void:
	var hi := _baustein_aktiv()
	if hi < 0:
		return
	var hx := _leiste_x(hi)
	var puls := 0.5 + 0.5 * sin(t * 4.0)
	Pen.circle(c, hx, 300, 9.5, Pen.hex(BAND_ACCENT, 0.07))
	Pen.scircle(c, hx, 300, 9.5 + puls * 0.8, Pen.hex(BAND_ACCENT, 0.5 + puls * 0.35), 0.8)


## Bühnensockel: der Boden, auf dem die Mini-Szene spielt (volle Breite).
func _buehne(c: CanvasItem) -> void:
	var sky_top: Color = theme["sky_top"]
	var detail: Color = theme["detail"]
	var fels := Pen.darken(sky_top, 0.45)
	Pen.rect(c, 0, GY, W, 12, fels)
	Pen.rect(c, 0, GY, W, 1.4, detail)
	Pen.rect(c, 0, GY, W, 0.5, Color(1, 1, 1, 0.5))
	var kx := 6.0
	while kx < W - 8.0:
		Pen.rect(c, kx, GY + 7, 10, 1, Pen.darken(sky_top, 0.6))
		kx += 26.0


## Massiver Block der Szene (Kriechgang, Wand): Fels mit heller Kappe.
func _block(c: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	var sky_top: Color = theme["sky_top"]
	var detail: Color = theme["detail"]
	Pen.rect(c, x, y, w, h, Pen.darken(sky_top, 0.36))
	Pen.rect(c, x, y, w, 1.2, detail)
	Pen.rect(c, x, y, w, 0.5, Color(1, 1, 1, 0.4))
	Pen.rect(c, x, y + h - 0.8, w, 0.8, Pen.darken(sky_top, 0.6))
	var kx := x + 5
	while kx < x + w - 8:
		Pen.rect(c, kx, y + h * 0.5, 8, 0.9, Pen.darken(sky_top, 0.55))
		kx += 20


## Tafel unter der Bühne: Handgriffe und Bausteine.
func _panel(c: CanvasItem) -> void:
	Pen.rrect(c, 12, PANEL_Y, 616, PANEL_H, 4, Pen.hex(0x060d16, 0.82))
	Pen.srrect(c, 12, PANEL_Y, 616, PANEL_H, 4, Color(1, 1, 1, 0.16), 0.7)
	Pen.rect(c, 18, PANEL_Y + 25, 604, 0.6, Color(1, 1, 1, 0.14))


## Mini-Symbol eines Bausteins (14×14 um x, y).
func _icon(c: CanvasItem, typ: String, x: float, y: float) -> void:
	var K := Pen.K
	var detail: Color = theme["detail"]
	var metall := Pen.hex(0x39445e)
	match typ:
		"collectible":
			Pen.circle(c, x, y, 5.5, Pen.alpha(K, 0.15))
			Pen.circle(c, x, y, 3.4, Pen.hex(0x1f2a3c))
			Pen.circle(c, x, y, 2.6, K)
			Pen.circle(c, x - 0.9, y - 0.9, 0.8, Color(1, 1, 1, 0.9))
		"bonus":
			Pen.circle(c, x, y, 3.4, Pen.hex(0x1f2a3c))
			Pen.circle(c, x, y, 2.6, Pen.GOLD_COL)
			Pen.circle(c, x - 0.9, y - 0.9, 0.8, Color(1, 1, 1, 0.9))
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(Vector2(x, y) + Vector2(5.6, 0).rotated(k * PI / 3.0))
			Pen.polyline(c, pts, Pen.alpha(Pen.GOLD_COL, 0.7), 0.7)
		"checkpoint":
			Pen.rect(c, x - 3, y - 7, 1.2, 14, metall)
			Pen.tri(c, x - 1.8, y - 7, x + 5, y - 4.5, x - 1.8, y - 2, Pen.OK_COL)
		"door-exit":
			Pen.rrect(c, x - 4, y - 7, 8, 14, 1.5, Pen.hex(0x1b2438))
			Pen.srrect(c, x - 4, y - 7, 8, 14, 1.5, Pen.GOLD_COL, 0.7)
			Pen.rect(c, x - 2.4, y - 5.4, 4.8, 11, Pen.alpha(Pen.GOLD_COL, 0.3))
		"spring":
			Pen.rect(c, x - 5, y + 4, 10, 2, metall)
			Pen.line(c, x - 3.5, y + 3, x + 3.5, y + 1.5, Pen.hex(0x6f7d99), 0.9)
			Pen.line(c, x - 3.5, y, x + 3.5, y - 1.5, Pen.hex(0x6f7d99), 0.9)
			Pen.rect(c, x - 5.5, y - 5, 11, 2.4, Pen.hex(0xff9d3b))
		"spike":
			Pen.rect(c, x - 6, y + 3, 12, 2, metall)
			for i in 3:
				var sx := x - 4 + i * 4
				Pen.tri(c, sx - 1.8, y + 3, sx + 1.8, y + 3, sx, y - 4, Pen.DENY_COL)
		"gate":
			Pen.rect(c, x - 5, y - 7, 1.6, 14, metall)
			Pen.rect(c, x + 3.4, y - 7, 1.6, 14, metall)
			Pen.rect(c, x - 2.2, y - 7, 4.4, 14, Pen.hex(0x1b2438))
			Pen.circle(c, x, y - 4, 1.5, Pen.DENY_COL)
		"timing-gate":
			Pen.rrect(c, x - 6, y + 1, 12, 5, 1, metall)
			var cols := [Pen.OK_COL, Pen.hex(0xffd75e), Pen.hex(0x4a5468)]
			for i in 3:
				var lx := x - 4 + i * 4
				Pen.circle(c, lx, y - 2.5, 2.6 if i == 1 else 1.7, cols[i])
		"stamp-exit":
			Pen.rect(c, x - 1.2, y - 7, 2.4, 6, metall)
			Pen.rrect(c, x - 6, y - 1.5, 12, 5, 1.5, Pen.GOLD_COL)
			Pen.rect(c, x - 5, y + 5, 10, 1.6, metall)
		"deny-enemy":
			var grau := Pen.hex(0x8a80a0)
			Pen.rect(c, x - 7, y - 1.2, 8, 2.4, grau)
			Pen.circle(c, x + 1, y, 2.2, grau)
			Pen.line(c, x + 1, y, x + 6, y - 3.5, grau, 1.4)
			Pen.line(c, x + 1, y, x + 6, y + 3.5, grau, 1.4)
			Pen.circle(c, x + 6, y - 3.5, 1, Pen.DENY_COL)
			Pen.circle(c, x + 6, y + 3.5, 1, Pen.DENY_COL)
		"stillstand-podest":
			Pen.rrect(c, x - 6.5, y + 1, 13, 3, 1, metall)
			Pen.srect(c, x - 5, y - 5, 10, 2.6, Pen.alpha(Palette.COOL, 0.9), 0.6)
			Pen.rect(c, x - 5, y - 5, 6, 2.6, Palette.COOL)
		"krypto-dusche":
			Pen.rrect(c, x - 6, y - 7, 12, 3, 1, metall)
			for i in 3:
				var dx := x - 4 + i * 4
				Pen.rect(c, dx - 0.5, y - 3 + (i % 2) * 2, 1, 4, Pen.alpha(K, 0.9))
			Pen.rect(c, x - 5, y + 4, 10, 1.4, Pen.alpha(K, 0.4))
		"tube-scroll":
			Pen.srrect(c, x - 7, y - 4, 14, 8, 3.5, Pen.alpha(K, 0.8), 0.7)
			Pen.line(c, x - 3, y, x + 3, y, Pen.alpha(K, 0.9), 1.0)
			Pen.tri(c, x + 2, y - 2.4, x + 5, y, x + 2, y + 2.4, Pen.alpha(K, 0.9))
		"huelle":
			Pen.rrect(c, x - 6, y - 3.5, 6, 7, 3, Pen.WARM)
			Pen.rrect(c, x, y - 3.5, 6, 7, 3, K)
			Pen.sellipse(c, x, y, 16, 11, Pen.alpha(K, 0.8), 0.7)
		"lauscher":
			Pen.tri(c, x - 2, y, x + 8, y - 4.5, x + 8, y + 4.5, Pen.alpha(Pen.WARM, 0.25))
			Pen.circle(c, x - 2, y, 4.2, Pen.hex(0x1f1724))
			Pen.ellipse(c, x - 2, y, 6.4, 4, Pen.hex(0xf7f2eb))
			Pen.circle(c, x - 1, y, 1.5, Pen.WARM)
			Pen.circle(c, x - 1, y, 0.7, Pen.hex(0x0d0a0f))
		"andock-plattform":
			Pen.rrect(c, x - 7, y + 1, 14, 3.4, 1, Pen.hex(0x5a4a2c))
			Pen.rect(c, x - 6, y + 0.4, 12, 1, Pen.GOLD_COL)
			Pen.scircle(c, x, y - 4, 2.6, Pen.alpha(Pen.GOLD_COL, 0.9), 0.8)
		"vau-feld":
			Pen.rrect(c, x - 7, y - 6, 14, 12, 2, Pen.alpha(Pen.VAU_COL, 0.2))
			Pen.srrect(c, x - 7, y - 6, 14, 12, 2, Pen.alpha(Pen.VAU_COL, 0.9), 0.7)
			var hp := PackedVector2Array()
			for k in 7:
				hp.append(Vector2(x, y) + Vector2(3.2, 0).rotated(k * PI / 3.0 + PI / 6.0))
			Pen.polyline(c, hp, Pen.alpha(Pen.VAU_COL, 0.8), 0.7)
		"kontext-anker":
			Pen.circle(c, x, y - 3, 2.8, Pen.VAU_COL)
			Pen.circle(c, x, y - 3, 1.1, Pen.hex(0x0a1220))
			Pen.rect(c, x - 1, y - 1, 2, 7, Pen.VAU_COL)
			Pen.rect(c, x + 1, y + 3, 2.4, 1.6, Pen.VAU_COL)
		"karte":
			Pen.rrect(c, x - 7, y - 4.5, 14, 9, 1.4, Pen.hex(0x2c7a52))
			Pen.rrect(c, x - 4.8, y - 2.2, 3.2, 4, 0.7, Pen.hex(0xffd75e))
			Pen.rect(c, x - 7, y - 4.5, 14, 0.9, Color(1, 1, 1, 0.2))
		"kartenleser":
			Pen.rrect(c, x - 5, y - 7, 10, 14, 1.2, Pen.hex(0x2f3a52))
			Pen.srrect(c, x - 5, y - 7, 10, 14, 1.2, Pen.alpha(detail, 0.8), 0.6)
			Pen.rect(c, x - 3.4, y - 5.4, 6.8, 3.6, Pen.hex(0x0a1220))
			Pen.rect(c, x - 3.4, y + 0.4, 6.8, 1.2, Pen.hex(0x0a1220))
			Pen.circle(c, x, y + 4.4, 1.2, Pen.OK_COL)
		"letzte-tuer":
			Pen.rrect(c, x - 4.5, y - 7, 9, 14, 1.5, Pen.hex(0x2a2a3a))
			Pen.srrect(c, x - 4.5, y - 7, 9, 14, 1.5, Pen.GOLD_COL, 0.8)
			Pen.circle(c, x + 2, y + 0.5, 1.1, Pen.GOLD_COL)
		"moving-platform":
			Pen.rrect(c, x - 6, y - 1, 12, 3.4, 1, metall)
			Pen.rect(c, x - 5, y - 1.6, 10, 1, Pen.hex(0x9fb0cc))
			Pen.tri(c, x - 7, y + 5, x - 4, y + 3, x - 4, y + 7, Pen.hex(0x9fb0cc))
			Pen.tri(c, x + 7, y + 5, x + 4, y + 3, x + 4, y + 7, Pen.hex(0x9fb0cc))
		"hazard":
			Pen.rect(c, x - 6, y - 5, 12, 10, Pen.alpha(Pen.DENY_COL, 0.25))
			Pen.srect(c, x - 6, y - 5, 12, 10, Pen.DENY_COL, 0.8)
			for i in 3:
				Pen.line(c, x - 6 + i * 4, y + 5, x - 2 + i * 4, y - 5, Pen.alpha(Pen.DENY_COL, 0.6), 0.6)
		_:
			Pen.circle(c, x, y, 4, Pen.hex(0x39445e))


# ------------------------------------------------------------ Bau-Vokabular

func _terminal(c: CanvasItem, x: float, y_basis: float, w: float, h: float, licht: Color, a := 1.0) -> void:
	var detail: Color = theme["detail"]
	Pen.rrect(c, x - w / 2, y_basis - h, w, h, 1.5, Pen.hex(0x2f3a52, a))
	Pen.srrect(c, x - w / 2, y_basis - h, w, h, 1.5, Pen.alpha(detail, 0.8 * a), 0.6)
	Pen.rect(c, x - w / 2 + 2, y_basis - h + 2.5, w - 4, 6, Pen.hex(0x0a1220, a))
	Pen.rect(c, x - w / 2 + 2.5, y_basis - h + 11.5, w - 5, 1.5, Pen.hex(0x0a1220, a))
	Pen.circle(c, x, y_basis - 3.2, 1.4, Pen.alpha(licht, a))


## Takt-Lichter der PIN-Schleuse: grün = geschafft, groß gelb = jetzt drücken.
func _takt(c: CanvasItem, x: float, y: float, n: int, progress: int, aktiv: int, frac := -1.0) -> void:
	for i in n:
		var lx := x - (n - 1) * 4.5 + i * 9
		var col := Pen.hex(0x4a5468)
		var r := 1.9
		if i < progress:
			col = Pen.hex(0x7fd07f)
		elif i == aktiv:
			col = Pen.hex(0xffd75e)
			r = 3.2
		Pen.circle(c, lx, y, r + 0.8, Pen.hex(0x0a1220, 0.85))
		Pen.circle(c, lx, y, r, col)
	if frac >= 0.0:
		var w := (n - 1) * 9.0 + 8.0
		Pen.rect(c, x - w / 2, y + 5, w, 1.2, Color(1, 1, 1, 0.15))
		Pen.rect(c, x - w / 2, y + 5, w * (1.0 - frac), 1.2, Pen.hex(0xffd75e, 0.9))


## Tor auf dem Boden: rot = zu, grün = offen; der Balken fährt hoch.
func _tor(c: CanvasItem, x: float, h: float, offen: float, a := 1.0) -> void:
	var detail: Color = theme["detail"]
	Pen.rect(c, x - 5, GY - h - 3, 2.2, h + 3, Pen.hex(0x39445e, a))
	Pen.rect(c, x + 2.8, GY - h - 3, 2.2, h + 3, Pen.hex(0x39445e, a))
	var lift := (h - 3) * clampf(offen, 0.0, 1.0)
	Pen.rect(c, x - 2.4, GY - h - lift, 4.8, h, Pen.hex(0x1b2438, a))
	Pen.rect(c, x - 2.4, GY - h - lift, 4.8, 1, Pen.alpha(detail, 0.6 * a))
	var lc := Pen.OK_COL if offen >= 0.999 else Pen.DENY_COL
	Pen.circle(c, x, GY - h - lift + 3.2, 1.6, Pen.alpha(lc, a))


## Lauscher-Auge mit Sichtkegel: warm = sucht, rot = liest gerade mit.
func _lauscher(c: CanvasItem, x: float, y: float, dir: int, reach: float, spread: float, sieht: bool, a := 1.0) -> void:
	var col := Pen.DENY_COL if sieht else Pen.WARM
	var base_a := 0.30 if sieht else 0.13
	for k in 3:
		var frac := 1.0 - k * 0.28
		Pen.poly(c, PackedVector2Array([Vector2(x, y), Vector2(x + dir * reach * frac, y - spread * frac), Vector2(x + dir * reach * frac, y + spread * frac)]),
			Pen.alpha(col, base_a * (0.5 + k * 0.25) * a))
	for i in 3:
		var f := fmod(t * 0.5 + i / 3.0, 1.0)
		var sx := x + dir * reach * f
		Pen.line(c, sx, y - spread * f, sx, y + spread * f, Pen.alpha(col, (1.0 - f) * 0.35 * a), 0.7)
	Pen.circle(c, x, y, 7, Pen.alpha(col, 0.15 * a))
	Pen.circle(c, x, y, 5, Pen.hex(0x1f1724, a))
	var blink := fmod(t * 0.37 + x * 0.013, 1.0) < 0.05
	if blink:
		Pen.rect(c, x - 3.5, y - 0.5, 7, 1, Pen.hex(0xf7f2eb, a))
	else:
		Pen.ellipse(c, x, y, 8, 5.2, Pen.hex(0xf7f2eb, a))
		var ex := x + dir * 1.6
		Pen.circle(c, ex, y, 1.9, Pen.alpha(col, a))
		Pen.circle(c, ex, y, 0.9, Pen.hex(0x0d0a0f, a))
	Pen.line(c, x, y - 5, x, y - 8.5, Pen.hex(0x4d4052, a), 0.8)
	Pen.circle(c, x, y - 9, 1.1, Pen.alpha(col, a))


## Sitzungsuhr (Kontextschlüssel): Ring läuft ab, unter 30 % rot (Puls 2 Hz).
func _uhr(c: CanvasItem, x: float, y: float, anteil: float, a := 1.0) -> void:
	var warn := anteil < 0.3
	var farbe := Pen.VAU_COL
	if warn:
		farbe = Pen.alpha(Pen.DENY_COL, 0.7 + 0.3 * sin(t * TAU * 2.0))
	Pen.circle(c, x, y, 8, Pen.hex(0x0e1a2c, 0.95 * a))
	Pen.scircle(c, x, y, 8, Pen.hex(0x9fb3c8, 0.6 * a), 1.0)
	Pen.arc(c, x, y, 5.6, -PI / 2, -PI / 2 + TAU * maxf(0.02, anteil), Pen.alpha(farbe, 0.95 * a), 2.0)
	Pen.circle(c, x, y, 1.4, Pen.alpha(Pen.VAU_COL, a))


## Kleines Gebäude (Kasse, Apotheke …); das Schild kommt aus BriefingDaten.
func _haus(c: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	var sky_top: Color = theme["sky_top"]
	var detail: Color = theme["detail"]
	Pen.rect(c, x - w / 2, y - h, w, h, Pen.darken(sky_top, 0.4))
	Pen.rect(c, x - w / 2 - 2, y - h - 2, w + 4, 2, Pen.alpha(detail, 0.7))
	var fy := y - h + 8
	while fy < y - 14:
		var fx := x - w / 2 + 7
		while fx < x + w / 2 - 8:
			var an := int(round(fx * 7 + fy * 13)) % 4 < 2
			Pen.rect(c, fx, fy, 6, 8, Pen.hex(0xffd9a0, 0.8) if an else Pen.alpha(Pen.darken(theme["sky_bottom"], 0.3), 0.5))
			fx += 13
		fy += 14
	Pen.rect(c, x - 7, y - 16, 14, 16, Pen.hex(0x0d1a2c))
	Pen.rect(c, x - 5.5, y - 14.5, 11, 1, Pen.hex(0xffd9a0, 0.5))


## ePA-Akte: Karte mit Kreuz und Dokumentzeilen; `voll` = neue Zeile eingetragen.
func _akte(c: CanvasItem, x: float, y: float, s := 1.0, a := 1.0, voll := 0.0) -> void:
	Pen.rrect(c, x - 11 * s, y - 14 * s, 22 * s, 28 * s, 3 * s, Pen.hex(0x0d1a2c, a))
	Pen.srrect(c, x - 11 * s, y - 14 * s, 22 * s, 28 * s, 3 * s, Pen.alpha(Pen.K, 0.85 * a), 1.0)
	Pen.rect(c, x - 1.4 * s, y - 10 * s, 2.8 * s, 7 * s, Pen.hex(0x2fa88c, 0.95 * a))
	Pen.rect(c, x - 3.5 * s, y - 7.9 * s, 7 * s, 2.8 * s, Pen.hex(0x2fa88c, 0.95 * a))
	for i in 3:
		Pen.rect(c, x - 7 * s, y + 2 * s + i * 3.4 * s, 14 * s, 1.1 * s, Pen.hex(0x9aa6bc, 0.8 * a))
	if voll > 0.0:
		Pen.rect(c, x - 7 * s, y + 2 * s + 3 * 3.4 * s, 14 * s * voll, 1.1 * s, Pen.hex(0x7fd07f, 0.95 * a))


## Ausweis: eGK grün, HBA orange, SMC-B blau — immer mit goldenem Chip.
func _karte(c: CanvasItem, x: float, y: float, typ := "egk", s := 1.0, a := 1.0) -> void:
	var col := 0x2c7a52
	if typ == "hba":
		col = 0xb8703a
	elif typ == "smcb":
		col = 0x4d6aa8
	Pen.rrect(c, x - 8 * s, y - 5 * s, 16 * s, 10 * s, 1.6 * s, Pen.hex(col, a))
	Pen.rrect(c, x - 5.5 * s, y - 2.4 * s, 3.6 * s, 4.4 * s, 0.8 * s, Pen.hex(0xffd75e, 0.95 * a))
	Pen.rect(c, x - 8 * s, y - 5 * s, 16 * s, 1 * s, Color(1, 1, 1, 0.2 * a))


## Prüfsumme (kühl) oder Bonus (gold, mit Sechseck-Ring).
func _orb(c: CanvasItem, x: float, y: float, bonus := false, a := 1.0) -> void:
	var col := Pen.GOLD_COL if bonus else Pen.K
	var r := 3.2 if bonus else 2.6
	Pen.circle(c, x, y, r * 2.2, Pen.alpha(col, 0.12 * a))
	Pen.circle(c, x, y, r + 0.9, Pen.hex(0x1f2a3c, a))
	Pen.circle(c, x, y, r, Pen.alpha(col, a))
	Pen.circle(c, x - r * 0.3, y - r * 0.35, r * 0.35, Color(1, 1, 1, 0.9 * a))
	if bonus:
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(Vector2(x, y) + Vector2(r + 2.8, 0).rotated(t * 1.2 + k * PI / 3.0))
		Pen.polyline(c, pts, Pen.alpha(col, 0.7 * a), 0.7)


## Sprungfeder auf dem Boden; `press` 0..1 drückt sie zusammen.
func _feder(c: CanvasItem, x: float, press := 0.0) -> void:
	var comp := 3.5 * press
	Pen.rect(c, x - 6, GY - 2.4, 12, 2.4, Pen.hex(0x39445e))
	for i in 3:
		var y := GY - 3.4 - i * (2.2 - comp / 3.0)
		Pen.line(c, x - 4.5, y, x + 4.5, y - 1, Pen.hex(0x6f7d99), 0.9)
	Pen.rect(c, x - 7, GY - 10 + comp, 14, 2.6, Pen.hex(0xff9d3b))
	Pen.rect(c, x - 6, GY - 10 + comp, 12, 0.7, Pen.hex(0xffd1a0, 0.7))


## Störfeld: rote Zacken, weiches Flackern (deutlich unter 3 Hz).
func _stoer(c: CanvasItem, x0: float, x1: float) -> void:
	Pen.rect(c, x0, GY - 2.4, x1 - x0, 2.4, Pen.hex(0x39445e))
	var n := int((x1 - x0) / 5.5)
	for i in n:
		var sx := x0 + 2.75 + i * 5.5
		var flick := 0.65 + 0.35 * sin(t * 2.6 + i * 1.7)
		Pen.tri(c, sx - 2.2, GY - 2.4, sx + 2.2, GY - 2.4, sx, GY - 8, Pen.hex(0x1f2a3c))
		Pen.tri(c, sx - 1.4, GY - 3, sx + 1.4, GY - 3, sx, GY - 7, Pen.alpha(Pen.DENY_COL, flick))


## Fahne (Rücksetzpunkt): grün und wehend, sobald sie aktiv ist.
func _fahne(c: CanvasItem, x: float, aktiv: bool) -> void:
	Pen.rect(c, x - 0.8, GY - 22, 1.6, 22, Pen.hex(0x39445e))
	var wave := sin(t * 5.0) * 1.2 if aktiv else sin(t * 1.5) * 0.5
	var col := Pen.OK_COL if aktiv else Pen.hex(0xff9d3b)
	Pen.tri(c, x + 0.8, GY - 22, x + 9 + wave, GY - 18.5, x + 0.8, GY - 15, col)
	Pen.circle(c, x, GY, 2, Pen.hex(0x39445e))


## Prüf-Podest: Plattform mit Scan-Balken; `frac` = Fortschritt des Scans.
func _podest(c: CanvasItem, x: float, w: float, frac: float, scanning: bool, done: bool) -> void:
	var col: Color = Pen.OK_COL if done else (Palette.COOL if scanning else theme["detail"])
	Pen.rect(c, x - 1.2, GY - 6, 2.4, 6, Pen.hex(0x39445e))
	Pen.rrect(c, x - w / 2, GY - 8, w, 3.4, 1, Pen.hex(0x39445e))
	Pen.rect(c, x - w / 2 + 1, GY - 8.4, w - 2, 1, Pen.alpha(col, 0.9))
	Pen.rect(c, x - w / 2 + 2, GY - 16, w - 4, 3, Color(0, 0, 0, 0.5))
	Pen.srect(c, x - w / 2 + 2, GY - 16, w - 4, 3, Pen.alpha(col, 0.8), 0.5)
	Pen.rect(c, x - w / 2 + 2, GY - 16, (w - 4) * clampf(frac, 0.0, 1.0), 3, Pen.alpha(col, 0.95))
	if scanning and not done:
		var sy := GY - 36 + fmod(t * 55.0, 28.0)
		Pen.rect(c, x - w / 2, sy, w, 1.2, Pen.alpha(col, 0.7))


## Krypto-Dusche: Duschkopf, Regen aus kühlen Tropfen, solange sie aktiv ist.
func _dusche(c: CanvasItem, x: float, w: float, aktiv: bool) -> void:
	var K := Pen.K
	Pen.rrect(c, x - w / 2, GY - 40, w, 6, 1.5, Pen.hex(0x39445e))
	Pen.srrect(c, x - w / 2, GY - 40, w, 6, 1.5, Pen.alpha(K, 0.7), 0.6)
	for i in int((w - 6) / 4.4):
		Pen.circle(c, x - w / 2 + 5 + i * 4.4, GY - 34, 0.8, Pen.alpha(K, 0.9))
	Pen.rect(c, x - w / 2 + 2, GY - 34, w - 4, 34, Pen.alpha(K, 0.05 + (0.02 * sin(t * 2.0) if aktiv else -0.02)))
	if aktiv:
		for i in int((w - 6) / 4.4):
			var dx := x - w / 2 + 5 + i * 4.4
			var dy := GY - 33 + fmod(t * 42.0 + i * 9.0, 32.0)
			Pen.rect(c, dx - 0.5, dy, 1.0, 3.2, Pen.alpha(K, 0.75))


## Signatur-Stempel: Führung, Podest, Stempelkopf auf Höhe `sy` (gold, wenn er oben wartet).
func _stempel(c: CanvasItem, x: float, sy: float, oben: bool, done: bool) -> void:
	Pen.rect(c, x - 2, GY - 48, 4, 44, Pen.hex(0x39445e, 0.8))
	Pen.rrect(c, x - 14, GY - 4, 28, 4, 1, Pen.hex(0x39445e))
	Pen.rect(c, x - 3, sy - 14, 6, 10, Pen.hex(0x39445e))
	var col := Pen.GOLD_COL
	Pen.rrect(c, x - 12, sy - 6, 24, 8, 2, Pen.hex(0x2a2a3a))
	Pen.srrect(c, x - 12, sy - 6, 24, 8, 2, Pen.alpha(col, 0.95 if (oben or done) else 0.5), 0.9)
	Pen.rect(c, x - 6, sy - 3, 12, 1.4, Pen.alpha(col, 0.95))
	if oben and not done:
		var puls := 0.5 + 0.5 * sin(t * 4.0)
		Pen.scircle(c, x, sy - 2, 15 + puls * 2, Pen.alpha(col, 0.35 + puls * 0.3), 0.7)


## Skimming-Kralle: Fake-Leser-Gehäuse, Teleskoparm, zwei Zangen. Nach der
## Sperre grau und eingeklemmt. `dir` = Greifrichtung.
func _kralle(c: CanvasItem, x: float, y: float, ext: float, open: bool, blocked: bool, shake: float, dir: int) -> void:
	var sx := sin(t * 60.0) * 1.0 * shake
	var col := Pen.hex(0x8a80a0) if not blocked else Pen.hex(0x707588)
	Pen.rrect(c, x - 6 + sx, y - 6, 12, 12, 1.5, Pen.hex(0x332a3a))
	Pen.srrect(c, x - 6 + sx, y - 6, 12, 12, 1.5, col, 0.6)
	Pen.rect(c, x - 3 + sx, y + 2, 6, 1.4, Pen.DENY_COL if not blocked else Pen.hex(0x4a4a55))
	var kx := x + dir * (6 + ext) + sx
	Pen.line(c, x + dir * 5 + sx, y, kx, y, col.darkened(0.2), 3.2)
	Pen.line(c, x + dir * 5 + sx, y, x + dir * (6 + ext * 0.6) + sx, y, col, 4.2)
	var spread := 4.5 if open else 1.6
	Pen.circle(c, kx, y, 3, col)
	Pen.line(c, kx, y, kx + dir * 5.5, y - spread, col, 1.6)
	Pen.line(c, kx, y, kx + dir * 5.5, y + spread, col, 1.6)
	var tip := Pen.DENY_COL if not blocked else col
	Pen.circle(c, kx + dir * 5.5, y - spread, 1, tip)
	Pen.circle(c, kx + dir * 5.5, y + spread, 1, tip)


## Zulassungs-Blende: fährt herunter und klemmt die Kralle ein (Text: Rufe).
func _blende(c: CanvasItem, x: float, y: float, a := 1.0) -> void:
	Pen.rrect(c, x - 9, y - 12, 18, 12, 1.5, Pen.hex(0x0d1f1a, a))
	Pen.srrect(c, x - 9, y - 12, 18, 12, 1.5, Pen.alpha(Pen.OK_COL, 0.9 * a), 0.8)
	Pen.scircle(c, x, y - 6, 2.6, Pen.alpha(Pen.OK_COL, a), 0.7)
	Pen.polyline(c, PackedVector2Array([Vector2(x - 1.4, y - 6), Vector2(x - 0.3, y - 4.8), Vector2(x + 1.6, y - 7.4)]), Pen.alpha(Pen.OK_COL, a), 0.8)


## VAU-Feld: violetter Raum mit Sechseck-Gitter (Raum, kein Tunnel).
func _vau(c: CanvasItem, x0: float, y0: float, w: float, h: float, aktiv: bool, a := 1.0) -> void:
	var col := Pen.VAU_COL
	Pen.rrect(c, x0, y0, w, h, 3, Pen.alpha(col, (0.22 if aktiv else 0.13) * a))
	Pen.srrect(c, x0, y0, w, h, 3, Pen.alpha(col, 0.9 * a), 0.8)
	var y := y0 + 6
	var row := 0
	while y < y0 + h - 4:
		var x := x0 + 6 + (4 if row % 2 else 0)
		while x < x0 + w - 4:
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(Vector2(x, y) + Vector2(2.6, 0).rotated(k * PI / 3.0 + PI / 6.0))
			Pen.polyline(c, pts, Pen.alpha(col, (0.16 + 0.08 * sin(t * 2.0 + x * 0.15 + y * 0.1)) * a), 0.5)
			x += 8
		y += 7
		row += 1


## Kontext-Anker: Schlüsselmarke, die die Sitzung auffrischt.
func _anker(c: CanvasItem, x: float, y: float, puls := 0.0) -> void:
	var col := Pen.VAU_COL
	var r := 5.0 + puls * 4.0
	Pen.circle(c, x, y, r * 1.6, Pen.alpha(col, 0.12))
	Pen.scircle(c, x, y, r, Pen.alpha(col, 0.95), 1.0)
	Pen.circle(c, x, y - 1.6, 1.8, col)
	Pen.rect(c, x - 0.7, y - 0.4, 1.4, 4.2, col)
	Pen.rect(c, x + 0.7, y + 2.2, 1.4, 1.1, col)


## Server-Rack (statisch); die LEDs kommen aus _rack_leds.
func _rack(c: CanvasItem, x: float, y_top: float, w: float, h: float) -> void:
	var detail: Color = theme["detail"]
	Pen.rect(c, x - w / 2, y_top, w, h, Pen.hex(0x141c2e))
	Pen.srect(c, x - w / 2, y_top, w, h, Pen.alpha(detail, 0.7), 0.6)
	var y := y_top + 4
	while y < y_top + h - 3:
		Pen.rect(c, x - w / 2 + 1.5, y, w - 3, 0.5, Pen.alpha(detail, 0.25))
		y += 4


func _rack_leds(c: CanvasItem, x: float, y_top: float, w: float, h: float, tempo := 2.5) -> void:
	var reihen := int((h - 6) / 4.0)
	for reihe in reihen:
		for sp in 2:
			var an := (reihe * 13 + sp * 5 + int(floor(t * tempo)) * 29) % 11 < 4
			Pen.rect(c, x - w / 2 + 2.5 + sp * 3.4, y_top + 5 + reihe * 4.0, 1.6, 1.2, Pen.alpha(Pen.K, 0.9) if an else Pen.hex(0x333c4e, 0.3))


## Die letzte Tür: hebt sich um `rise` (0..1); gold, wenn sie freigegeben ist.
func _tuer(c: CanvasItem, x: float, h: float, rise: float, gold: bool) -> void:
	var detail: Color = theme["detail"]
	var col := Pen.GOLD_COL if gold else Pen.alpha(detail, 0.9)
	Pen.rect(c, x - 10, GY - h - 3, 3, h + 3, Pen.hex(0x2a2a3a))
	Pen.rect(c, x + 7, GY - h - 3, 3, h + 3, Pen.hex(0x2a2a3a))
	Pen.rect(c, x - 10, GY - h - 3, 20, 3, Pen.hex(0x2a2a3a))
	var lift := (h - 4) * clampf(rise, 0.0, 1.0)
	Pen.rrect(c, x - 7, GY - h - lift, 14, h, 2, Pen.hex(0x1b1a26))
	Pen.srrect(c, x - 7, GY - h - lift, 14, h, 2, col, 0.9)
	Pen.circle(c, x + 3, GY - h / 2 - lift, 1.4, col)
	if rise > 0.0:
		Pen.rect(c, x - 6, GY - h + 1, 12, h - 1, Pen.alpha(Pen.GOLD_COL, 0.10 * rise))


## Datenkrake: purpurner Kopf, Knopfaugen, wedelnde Arme — will greifen, scheitert.
func _krake(c: CanvasItem, x: float, y: float, s := 1.0, a := 1.0) -> void:
	var body := Pen.hex(0x8a4d9e, a)
	for i in 5:
		var pts := PackedVector2Array()
		for k in 6:
			var f := k / 5.0
			pts.append(Vector2(x + (-6 + i * 3) * s + sin(t * 2.5 + i + f * 3.0) * 2.5 * s * f, y + 3 * s + f * 9 * s))
		Pen.polyline(c, pts, Pen.hex(0x5a2f6a, a), 1.6 * s)
	Pen.circle(c, x, y, 6.5 * s, Pen.hex(0x3a2144, a))
	Pen.circle(c, x, y, 5.6 * s, body)
	Pen.circle(c, x - 2 * s, y - 1 * s, 1.6 * s, Color(0.97, 0.95, 1.0, a))
	Pen.circle(c, x + 2 * s, y - 1 * s, 1.6 * s, Color(0.97, 0.95, 1.0, a))
	Pen.circle(c, x - 1.6 * s, y - 0.8 * s, 0.7 * s, Pen.hex(0x1a1020, a))
	Pen.circle(c, x + 2.4 * s, y - 0.8 * s, 0.7 * s, Pen.hex(0x1a1020, a))


## Datenpuls auf einer Leitung.
func _puls(c: CanvasItem, p: Vector2, col: Color, a := 1.0) -> void:
	Pen.circle(c, p.x, p.y, 3.0, Pen.alpha(col, 0.22 * a))
	Pen.scircle(c, p.x, p.y, 1.9, Pen.alpha(col, 0.9 * a), 0.7)
	Pen.circle(c, p.x, p.y, 0.8, Color(1, 1, 1, 0.95 * a))


## Aufblühender Ring (k 0..1) — Einsammeln, Umschalten, Freigabe.
func _ring(c: CanvasItem, x: float, y: float, k: float, col: Color) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	Pen.scircle(c, x, y, 3 + 11 * k, Pen.alpha(col, 0.9 * (1.0 - k)), 0.9)


## Comic-Sterne: der Angreifer prallt ab.
func _sterne(c: CanvasItem, x: float, y: float, k: float) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	for i in 4:
		var ang := i * TAU / 4.0 + k * 2.0
		var px := x + cos(ang) * (4 + 6 * k)
		var py := y + sin(ang) * (3 + 4 * k)
		Pen.circle(c, px, py, 1.0, Pen.hex(0xffd75e, 0.95 * (1.0 - k)))


## Smartphone mit Schalter (ePA-App): `kipp` 0 = grün/an, 1 = rot/aus.
func _handy(c: CanvasItem, x: float, y: float, h: float, a: float, kipp: float) -> void:
	var w := h * 0.52
	Pen.rrect(c, x - w / 2, y - h / 2, w, h, 2.5, Pen.hex(0x0a1220, a))
	Pen.srrect(c, x - w / 2, y - h / 2, w, h, 2.5, Pen.hex(0x9fb3c8, 0.8 * a), 0.8)
	Pen.rect(c, x - 2, y - h / 2 + 1.4, 4, 0.8, Pen.hex(0x9fb3c8, 0.7 * a))
	Pen.rect(c, x - w / 2 + 2, y - 5, w - 4, 1.2, Pen.hex(0x9aa6bc, 0.85 * a))
	Pen.rrect(c, x - 5, y - 1, 10, 4.4, 2.2, Pen.hex(0xb3403e if kipp > 0.5 else 0x2fa88c, 0.95 * a))
	Pen.circle(c, x - 2.6 + 5.2 * kipp, y + 1.2, 1.7, Pen.hex(0xeef2f8, 0.95 * a))


## Paul mit Hülle (Ring hinter der Figur); Füße auf y_fuss.
func _paul(c: CanvasItem, x: float, y_fuss: float, schritt: float, dir: int, zustand: String, a := 1.0, duck := false) -> void:
	if a <= 0.01:
		return
	Pen.huelle_ring(c, x, y_fuss, zustand, a, t)
	Pen.paul(c, x, y_fuss, schritt, dir, a, duck)


## Dokument (Rezept/Befund): weißes Blatt, Zeilen, optional grüner Eintrag.
func _doc(c: CanvasItem, x: float, y: float, a := 1.0, zeile := 0.0, rot := false) -> void:
	Pen.rect(c, x - 4, y - 5, 8, 10, Pen.hex(0xeef2f8, 0.95 * a))
	Pen.rect(c, x - 2.8, y - 3.2, 5.6, 0.8, Pen.hex(0x9aa6bc, 0.8 * a))
	Pen.rect(c, x - 2.8, y - 1.2, 4, 0.8, Pen.hex(0x9aa6bc, 0.8 * a))
	if rot:
		Pen.rect(c, x - 2.8, y + 1.2, 3, 1.4, Pen.hex(0xb3403e, 0.9 * a))
	if zeile > 0.0:
		Pen.rect(c, x - 2.8, y + 2.6, 5.6 * clampf(zeile, 0.0, 1.0), 0.9, Pen.hex(0x2fa88c, 0.95 * a))


# ================================================================ 01 Stammdaten
# Paul steckt die eGK am Terminal der Anmeldung; die TI prüft online bei der
# Kasse; danach die PIN-Schleuse (Takt) — das Tor öffnet, Prüfsummen, Feder,
# Störfeld, Fahne. REZI wird geboren, sobald die Daten stimmen.

func _statik_01(c: CanvasItem) -> void:
	Pen.rect(c, 130, GY - 14, 70, 14, Pen.hex(0x2f3a52))
	Pen.rect(c, 128, GY - 15.5, 74, 2, Pen.hex(0x39445e))
	Pen.rect(c, 128, GY - 15.5, 74, 0.6, Color(1, 1, 1, 0.12))
	Pen.pfad_linie(c, PFAD_01, Pen.alpha(Pen.K, 0.22), 0.6)
	_haus(c, 520, GY, 72, 64)
	# Prüf-Display der Kasse über der Tür (mit Platz für das Schild)
	Pen.rect(c, 503, GY - 48, 34, 30, Pen.hex(0x0a1220))
	Pen.srect(c, 503, GY - 48, 34, 30, Pen.alpha(theme["detail"], 0.7), 0.6)
	# Bonus außer Reichweite: die goldene Kachel oben lockt zum Sprung
	Pen.rect(c, 300, GY - 62, 40, 2.4, Pen.hex(0x39445e))


func _leben_01(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	var G := Pen.hex(0x7fd07f)
	# Paul
	var px := 96.0
	var schritt := 0.0
	var jy := 0.0
	var a := 1.0
	if u < 1.6:
		px = 96 + 68 * (u / 1.6)
		schritt = t * 2.0
	elif u < 10.6:
		px = 164
	elif u < 13.6:
		var k := (u - 10.6) / 3.0
		px = 164 + 392 * k
		schritt = t * 2.4
		if px > 380 and px < 432:
			jy = -26 * sin(PI * (px - 380) / 52)
		if u > 13.0:
			a = 1 - (u - 13.0) / 0.6
	else:
		a = 0.0
	# Terminal auf dem Tresen, Licht je nach Phase
	var licht := Pen.hex(0x4a5468)
	if u >= 7.3:
		licht = G
	elif u >= 2.5:
		licht = Pen.alpha(K, 0.6 + 0.4 * sin(t * 3.0))
	_terminal(c, 178, GY - 15.5, 12, 14, licht)
	# Karte gleitet in den Schlitz
	if u >= 1.6 and u < 2.5:
		var k := (u - 1.6) / 0.9
		_karte(c, 170 + 8 * k, GY - 30 + 4.5 * k, "egk", 0.7, 1 - k * 0.5)
	# Puls zur Kasse, Prüfung, grüner Puls zurück
	if u >= 2.6 and u < 4.2:
		_puls(c, Pen.pfad_punkt(PFAD_01, (u - 2.6) / 1.6), K)
	if u >= 4.2 and u < 5.9:
		var k := (u - 4.2) / 1.7
		Pen.rect(c, 506 + 28 * fmod(k * 3.0, 1.0), GY - 34, 1.2, 13, Pen.alpha(K, 0.6))
		for i in 3:
			Pen.rect(c, 509 + i * 8, GY - 30 + (i % 2) * 4, 5, 1.2, Pen.alpha(K, 0.55 if sin(t * 6.0 + i) > 0 else 0.2))
	if u >= 5.6 and u < 7.6:
		Pen.polyline(c, PackedVector2Array([Vector2(514, GY - 27), Vector2(518, GY - 23), Vector2(526, GY - 31)]), G, 1.2)
	if u >= 5.9 and u < 7.3:
		_puls(c, Pen.pfad_punkt(PFAD_01, 1.0 - (u - 5.9) / 1.4), G)
	# PIN-Schleuse: zwei Takt-Lichter über dem Terminal
	if u >= 7.5 and u < 12.6:
		var progress := 0
		if u >= 8.5:
			progress = 1
		if u >= 10.3:
			progress = 2
		var aktiv := -1
		var frac := -1.0
		if u >= 7.6 and u < 8.5:
			aktiv = 0
			frac = (u - 7.6) / 0.9
		elif u >= 9.4 and u < 10.3:
			aktiv = 1
			frac = (u - 9.4) / 0.9
		_takt(c, 178, GY - 40, 2, progress, aktiv, frac)
		for i in 2:
			var tp := 8.5 + i * 1.8
			_ring(c, 173.5 + i * 9, GY - 40, (u - tp) / 0.5, G)
	# Tor
	var offen := 0.0
	if u >= 10.4:
		offen = clampf((u - 10.4) / 0.6, 0.0, 1.0)
	_tor(c, 240, 28, offen)
	# Prüfsummen auf dem Weg (werden im Vorbeilaufen eingesammelt), Bonus oben
	var orbs := [[290.0, GY - 30], [320.0, GY - 44], [350.0, GY - 30]]
	for i in orbs.size():
		var o: Array = orbs[i]
		var ox: float = o[0]
		var oy: float = o[1]
		var t_hit := 10.6 + 3.0 * (ox - 164) / 392
		if u < t_hit or u >= 13.8:
			_orb(c, ox, oy + sin(t * 2.4 + i) * 1.5, false, 1.0)
		else:
			_ring(c, ox, oy, (u - t_hit) / 0.4, K)
	_orb(c, 320, GY - 70 + sin(t * 2.0) * 1.5, true, 1.0)
	# Feder, Störfeld, Fahne
	var press := 0.0
	if u >= 10.6 and u < 13.6:
		press = clampf(1.0 - absf(px - 386) / 8.0, 0.0, 1.0)
	_feder(c, 386, press)
	_stoer(c, 405, 421)
	_fahne(c, 445, u >= 12.75 and u < 14.4)
	# REZI: Geburt am Terminal, dann hinter Paul
	if u >= 7.3:
		var rx := px - 10
		var ry := GY - 16 + sin(t * 3.0) * 1.5 + jy * 0.8
		if u < 7.9:
			var k := (u - 7.3) / 0.6
			rx = 178 - 8 * k
			ry = GY - 22 - 8 * k
			_ring(c, 178, GY - 24, k, K)
		elif u < 10.6:
			rx = 170
			ry = GY - 30 + sin(t * 3.0) * 1.5
		Pen.rezi(c, rx, ry, a, 1.0, false, false)
	_paul(c, px, GY + jy, schritt, 1, "", a)


# ================================================================ 02 Kartenterminal
# Kriechgang mit Skimming-Kralle (ducken, dann klemmt die Zulassung sie ein),
# Dr. Pixel steckt den HBA und tippt die PIN im Takt, zum Schluss der QES-Stempel.

func _statik_02(c: CanvasItem) -> void:
	_block(c, 96, GY - 30, 94, 18)
	Pen.rect(c, 198, GY - 22, 2.4, 22, Pen.hex(0x39445e))


func _leben_02(c: CanvasItem, u: float) -> void:
	var G := Pen.hex(0x7fd07f)
	# Paul: Weg und Haltung
	var px := 60.0
	var schritt := 0.0
	var duck := false
	var a := 1.0
	if u < 1.3:
		px = 60 + 58 * (u / 1.3)
		schritt = t * 2.0
	elif u < 4.8:
		px = 118 + 64 * ((u - 1.3) / 3.5)
		duck = true
		schritt = t * 1.2
	elif u < 6.4:
		px = 182 + 108 * ((u - 4.8) / 1.6)
		schritt = t * 2.2
	elif u < 11.4:
		px = 290
	elif u < 13.0:
		px = 290 + 150 * ((u - 11.4) / 1.6)
		schritt = t * 2.2
	elif u < 16.0:
		px = 440
	else:
		a = 1 - (u - 16.0) / 0.4
	# Kralle: zwei Griffe, dann klemmt die Zulassung sie ein
	var ext := 0.0
	var open := true
	var shake := 0.0
	var blocked := u >= 4.6
	var g1 := clampf((u - 1.5) / 0.4, 0.0, 1.0) * (1.0 - clampf((u - 2.3) / 0.5, 0.0, 1.0))
	var g2 := clampf((u - 3.3) / 0.4, 0.0, 1.0) * (1.0 - clampf((u - 4.1) / 0.5, 0.0, 1.0))
	if u >= 1.2 and u < 1.5:
		shake = 1.0
	if u >= 3.0 and u < 3.3:
		shake = 1.0
	if not blocked:
		ext = 42 * maxf(g1, g2)
		open = not ((u >= 1.9 and u < 2.3) or (u >= 3.7 and u < 4.1))
	else:
		ext = 6
		open = false
	_kralle(c, 196, GY - 11, ext, open, blocked, shake, -1)
	if blocked:
		var k := clampf((u - 4.6) / 0.4, 0.0, 1.0)
		var by := GY - 44 + 28 * (1.0 - pow(1.0 - k, 2))
		_blende(c, 196, by)
		_sterne(c, 176, GY - 22, (u - 4.9) / 1.0)
	# PIN-Terminal mit Dr. Pixel
	var licht := Pen.hex(0x4a5468)
	if u >= 10.9:
		licht = G
	elif u >= 7.2:
		licht = Pen.alpha(Pen.hex(0xffd75e), 0.6 + 0.4 * sin(t * 3.0))
	_terminal(c, 290, GY, 14, 22, licht)
	if u >= 6.4 and u < 7.2:
		var k := (u - 6.4) / 0.8
		_karte(c, 304 - 10 * k, GY - 20 - 2 * k, "hba", 0.7, 1 - k * 0.5)
	elif u >= 7.2:
		Pen.rrect(c, 285, GY - 12.5, 10, 2.4, 0.8, Pen.hex(0xb8703a))
	if u >= 7.2 and u < 12.8:
		var progress := 0
		var aktiv := -1
		var frac := -1.0
		for i in 4:
			var t0 := 7.4 + i * 1.0
			if u >= t0 + 0.5:
				progress = i + 1
			elif u >= t0:
				aktiv = i
				frac = (u - t0) / 0.5
		_takt(c, 290, GY - 34, 4, progress, aktiv, frac)
		for i in 4:
			_ring(c, 276.5 + i * 9, GY - 34, (u - (7.9 + i * 1.0)) / 0.45, G)
	# Tor nach der PIN-Prüfung
	var offen := 0.0
	if u >= 11.0:
		offen = clampf((u - 11.0) / 0.6, 0.0, 1.0)
	_tor(c, 330, 26, offen)
	# Dr. Pixel: erst am Terminal, dann zum Stempel
	var dx := 312.0
	var ddir := -1
	var dschritt := 0.0
	if u >= 11.4 and u < 13.0:
		dx = 312 + 154 * ((u - 11.4) / 1.6)
		ddir = 1
		dschritt = t * 2.2
	elif u >= 13.0:
		dx = 466
	Pen.figur(c, dx, GY, Pen.P_ARZT, dschritt, ddir, a)
	# Signatur-Stempel: wartet oben, fährt im Takt herunter; Signatur bei u = 13,6
	var top := GY - 40.0
	var bot := GY - 12.0
	var sy := top
	var done := u >= 13.85
	if u < 13.85:
		var p := fmod(u, 1.8)
		if p < 1.0:
			sy = top
		elif p < 1.25:
			var k := (p - 1.0) / 0.25
			sy = top + (bot - top) * k * k
		elif p < 1.45:
			sy = bot
		else:
			sy = bot + (top - bot) * ((p - 1.45) / 0.35)
	else:
		sy = bot if u < 14.6 else bot + (top - bot) * clampf((u - 14.6) / 0.6, 0.0, 1.0)
	_stempel(c, 440, sy, sy <= top + 2 and u >= 13.0, done)
	if done:
		_ring(c, 440, GY - 10, (u - 13.85) / 0.6, Pen.GOLD_COL)
		_sterne(c, 440, GY - 14, (u - 13.9) / 0.9)
	# REZI hinter Paul (im Kriechgang tief), nach dem Stempel mit Siegel
	var rx := px - 9
	var ry := GY - 17 + sin(t * 3.0) * 1.5
	if duck:
		ry = GY - 8
	Pen.rezi(c, rx, ry, a, 1.0, false, done)
	_paul(c, px, GY, schritt, 1, "", a, duck)


# ================================================================ 03 KOV Gateway
# Prüf-Podest (stillstehen), das Tor öffnet — die Datenkrake bleibt draußen;
# Krypto-Dusche (blauer Knopf) legt die Verschlüsselung an; Tunnel-Fahrt.

func _statik_03(c: CanvasItem) -> void:
	var K := Pen.K
	_block(c, 180, GY - 40, 20, 14)
	Pen.rrect(c, 330, GY - 40, 230, 32, 10, Pen.alpha(K, 0.06))
	Pen.srrect(c, 330, GY - 40, 230, 32, 10, Pen.alpha(K, 0.5), 0.8)
	for ly in [GY - 31, GY - 24, GY - 17]:
		Pen.line(c, 338, ly, 552, ly, Pen.alpha(K, 0.12), 0.5)


func _leben_03(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	# Paul
	var px := 70.0
	var py := GY
	var schritt := 0.0
	var zustand := ""
	var a := 1.0
	if u < 1.4:
		px = 70 + 80 * (u / 1.4)
		schritt = t * 2.0
	elif u < 2.9:
		px = 150
		py = GY - 8
	elif u < 4.4:
		var k := (u - 2.9) / 1.5
		px = 150 + 85 * k
		py = GY - 8 * (1.0 - clampf(k * 4.0, 0.0, 1.0))
		schritt = t * 2.2
	elif u < 5.0:
		px = 235 + 35 * ((u - 4.4) / 0.6)
		schritt = t * 2.0
	elif u < 6.4:
		px = 270
		zustand = "verschluesselt" if u >= 5.6 else ""
	elif u < 7.4:
		px = 270 + 60 * ((u - 6.4) / 1.0)
		schritt = t * 1.7
		zustand = "verschluesselt"
	elif u < 13.4:
		var k := (u - 7.4) / 6.0
		px = 330 + 230 * k
		py = _tunnel_y(px)
		zustand = "verschluesselt"
	else:
		px = 560
		py = _tunnel_y(560)
		zustand = "verschluesselt"
		a = 1 - clampf((u - 13.4) / 0.8, 0.0, 1.0)
	# Prüf-Podest und Tor
	var frac := clampf((u - 1.5) / 1.2, 0.0, 1.0)
	_podest(c, 150, 26, frac, u >= 1.5 and u < 2.7, u >= 2.7)
	var offen := 0.0
	if u >= 2.8:
		offen = clampf((u - 2.8) / 0.6, 0.0, 1.0)
	_tor(c, 190, 26, offen)
	# Datenkrake schleicht hinterher — und bekommt das Tor vor die Nase
	var kx := maxf(60.0, px - 44)
	var ka := 1.0
	if u >= 3.4:
		kx = 176 + (3.0 * sin(t * 40.0) if (u >= 3.8 and u < 4.2) else 0.0)
	if u >= 7.0:
		ka = 1 - clampf((u - 7.0) / 1.0, 0.0, 1.0)
	if ka > 0.0:
		_krake(c, kx, GY - 16 + sin(t * 2.0) * 1.5, 0.9, ka)
	_sterne(c, 184, GY - 28, (u - 3.9) / 1.0)
	# Krypto-Dusche
	_dusche(c, 270, 30, u < 5.6)
	if u >= 5.6:
		_ring(c, 270, GY - 8, (u - 5.6) / 0.6, K)
	# Tunnel: Prüfsummen in drei Bahnen, Krake hämmert außen wirkungslos
	for i in TUNNEL_ORBS.size():
		var o: Array = TUNNEL_ORBS[i]
		var ox: float = o[0]
		var lane: int = o[1]
		var oy := GY - 31 + lane * 7
		var t_hit := 7.4 + 6.0 * (ox - 330) / 230
		if u < t_hit or u >= 14.2:
			_orb(c, ox, oy, false, 0.95)
		else:
			_ring(c, ox, oy, (u - t_hit) / 0.4, K)
	_krake(c, 470, GY - 54 + sin(t * 1.6) * 1.2, 1.0, 1.0)
	var hammer := fmod(t, 1.4)
	if hammer < 0.12:
		_sterne(c, 470, GY - 41, hammer / 0.12 * 0.9)
	# Tempo-Linien in der Röhre
	if u >= 7.4 and u < 13.8:
		for i in 3:
			var lx := px - 10 - i * 5
			Pen.line(c, lx, py - 8 + i * 3, lx - 5, py - 8 + i * 3, Pen.alpha(K, 0.35 * a), 0.6)
	Pen.rezi(c, px - 9 if u < 7.4 else px + 9, py - 17 + sin(t * 3.0) * 1.5, a, 1.0, zustand == "verschluesselt", false)
	_paul(c, px, py, schritt, 1, zustand, a)


## Bahn der Tunnelfahrt: Paul steuert zur nächsten Prüfsumme.
func _tunnel_y(px: float) -> float:
	var prev_x := 330.0
	var prev_lane := 1.0
	for i in TUNNEL_ORBS.size():
		var o: Array = TUNNEL_ORBS[i]
		var ox: float = o[0]
		var lane := float(o[1])
		if px <= ox:
			var k := clampf((px - prev_x) / maxf(1.0, ox - prev_x), 0.0, 1.0)
			return GY - 31 + lerpf(prev_lane, lane, k) * 7 + 8
		prev_x = ox
		prev_lane = lane
	return GY - 31 + prev_lane * 7 + 8


# ================================================================ 04 Die Hülle
# Der Lauscher liest Klartext mit; verschlüsselt ist Paul unsichtbar. Die
# Andock-Plattform trägt nur Klartext; im VAU-Feld schnell und unsichtbar,
# der Anker frischt die Sitzung auf.

func _statik_04(c: CanvasItem) -> void:
	Pen.rect(c, 330, GY - 1, 50, 14, Pen.hex(0x040810, 0.92))
	Pen.rrect(c, 333, GY - 9, 44, 3.4, 1, Pen.hex(0x5a4a2c))


func _leben_04(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	var px := 90.0
	var st := ""
	var a := 1.0
	var schritt := 0.0
	var jy := 0.0
	if u < 2.0:
		px = 90 + 85 * (u / 2.0)
		schritt = t * 2.2
	elif u < 2.6:
		px = 175
		if u >= 2.3:
			st = "verschluesselt"
	elif u < 5.2:
		px = 175 + 150 * ((u - 2.6) / 2.6)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 6.0:
		px = 325
		st = "verschluesselt" if u < 5.8 else ""
	elif u < 7.2:
		px = 325 + 60 * ((u - 6.0) / 1.2)
		schritt = t * 2.2
	elif u < 7.6:
		px = 385
		st = "" if u < 7.4 else "verschluesselt"
	elif u < 8.8:
		px = 385 + 47 * ((u - 7.6) / 1.2)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 10.2:
		px = 432 + 68 * ((u - 8.8) / 1.4)
		schritt = t * 2.2
		st = "vau"
	elif u < 12.0:
		px = 500 + 70 * ((u - 10.2) / 1.8)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 13.0:
		px = 570
		st = "verschluesselt"
		a = 1 - (u - 12.0)
	else:
		a = 0.0
	if px > 326 and px < 384:
		jy = -8.0
	var sichtbar := st == "" and a > 0.0
	# Lauscher: sehen nur Klartext
	var l1 := sichtbar and px >= 130 and px <= 210
	var l3 := sichtbar and px >= 500 and px <= 560
	_lauscher(c, 210, GY - 28, -1, 80, 16, l1)
	_lauscher(c, 315, GY - 28, -1, 70, 15, sichtbar and px >= 245 and px <= 315)
	_lauscher(c, 560, GY - 28, -1, 60, 14, l3)
	# Bits fliegen davon, wenn mitgelesen wurde
	if u >= 1.1 and u < 1.9:
		var k := (u - 1.1) / 0.8
		for i in 3:
			Pen.circle(c, 150 - 12 * k - i * 5, GY - 14 - 18 * k + i * 4, 1.2, Pen.alpha(K, 0.9 * (1.0 - k)))
	# Umschalt-Ringe
	for tt in [2.3, 5.8, 7.4]:
		_ring(c, px, GY - 7 + jy, (u - float(tt)) / 0.5, K)
	# Andock-Plattform: trägt nur Klartext (schraffiert, wenn verschlüsselt)
	var carries := st != "verschluesselt" or a <= 0.0
	var pa := 1.0 if carries else 0.35
	Pen.rect(c, 334, GY - 9.6, 42, 1, Pen.alpha(Pen.GOLD_COL, pa))
	var puls := 0.6 + 0.4 * sin(t * 3.0)
	Pen.scircle(c, 355, GY - 15, 2.6, Pen.alpha(Pen.GOLD_COL, pa * puls), 0.8)
	if not carries:
		for i in 5:
			Pen.line(c, 335 + i * 8.5, GY - 5.6, 340 + i * 8.5, GY - 9, Pen.alpha(Pen.GOLD_COL, 0.35), 0.6)
	# VAU-Feld mit Anker
	_vau(c, 432, GY - 36, 68, 34, st == "vau")
	var ap := 0.0
	if u >= 9.6 and u < 10.1:
		ap = 1.0 - (u - 9.6) / 0.5
	_anker(c, 475, GY - 12, ap)
	_ring(c, 475, GY - 12, (u - 9.6) / 0.6, Pen.VAU_COL)
	Pen.rezi(c, px - 9, GY - 17 + jy + sin(t * 3.0) * 1.5, a, 1.0, st == "verschluesselt", false)
	_paul(c, px, GY + jy, schritt, 1, st, a)


# ================================================================ 05 Identität
# eGK aufsammeln, am Terminal stecken (Tor öffnet); am zweiten Terminal wird die
# eGK abgewiesen — hier zählt die SMC-B der Einrichtung. Karten sind Schlüssel.

func _statik_05(c: CanvasItem) -> void:
	Pen.rrect(c, 278, GY - 24, 24, 3, 1, Pen.hex(0x39445e))
	Pen.rect(c, 279, GY - 24.4, 22, 1, Pen.alpha(theme["detail"], 0.8))


func _leben_05(c: CanvasItem, u: float) -> void:
	var G := Pen.hex(0x7fd07f)
	var S := Pen.hex(0x8ca6f2)
	var px := 70.0
	var jy := 0.0
	var dir := 1
	var schritt := 0.0
	var st := ""
	var a := 1.0
	if u < 1.2:
		px = 70 + 40 * (u / 1.2)
		schritt = t * 2.0
	elif u < 2.2:
		px = 110 + 40 * ((u - 1.2) / 1.0)
		schritt = t * 2.0
	elif u < 3.2:
		px = 150
	elif u < 4.0:
		px = 150 + 50 * ((u - 3.2) / 0.8)
		schritt = t * 2.2
	elif u < 6.4:
		px = 200 + 130 * ((u - 4.0) / 2.4)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 8.6:
		px = 330
	elif u < 9.6:
		px = 330 - 30 * ((u - 8.6) / 1.0)
		dir = -1
		schritt = t * 2.0
	elif u < 10.4:
		var k := (u - 9.6) / 0.8
		px = 300 - 10 * k
		jy = -24 * sin(PI * k * 0.5)
		dir = -1
	elif u < 11.2:
		var k := (u - 10.4) / 0.8
		px = 290 + 40 * k
		jy = -24 * (1.0 - k * k)
	elif u < 12.2:
		px = 330
	elif u < 14.0:
		px = 330 + 140 * ((u - 12.2) / 1.8)
		schritt = t * 2.2
	elif u < 15.0:
		px = 470
		a = 1 - (u - 14.0)
	# Karten am Weg
	if u < 1.0:
		_karte(c, 110, GY - 6 + sin(t * 2.5) * 1.2, "egk", 0.8)
	else:
		_ring(c, 110, GY - 6, (u - 1.0) / 0.5, G)
	if u < 10.2:
		_karte(c, 290, GY - 30 + sin(t * 2.5) * 1.2, "smcb", 0.8)
	else:
		_ring(c, 290, GY - 30, (u - 10.2) / 0.5, S)
	# Terminal A (eGK) und Tor
	var lichtA := G if u >= 2.4 else Pen.hex(0x4a5468)
	_terminal(c, 150, GY, 14, 22, lichtA)
	if u >= 2.4:
		Pen.rrect(c, 145, GY - 12.5, 10, 2.4, 0.8, Pen.hex(0x2c7a52))
	var offenA := 0.0
	if u >= 2.6:
		offenA = clampf((u - 2.6) / 0.6, 0.0, 1.0)
	_tor(c, 178, 26, offenA)
	# Lauscher zwischen den Terminals
	var sichtbar := st == "" and a > 0.0
	_lauscher(c, 250, GY - 28, -1, 50, 13, sichtbar and px >= 200 and px <= 250)
	_ring(c, px, GY - 7, (u - 4.0) / 0.5, Pen.K)
	# Terminal B (SMC-B): erst Abweisung der eGK, dann Erfolg mit der SMC-B
	var lichtB := Pen.hex(0x4a5468)
	if u >= 11.4:
		lichtB = G
	elif u >= 6.8 and u < 7.8:
		lichtB = Pen.alpha(Pen.DENY_COL, 0.6 + 0.4 * sin(t * 6.0))
	_terminal(c, 330, GY, 14, 22, lichtB)
	if u >= 6.8 and u < 7.8:
		Pen.srrect(c, 322, GY - 23, 16, 24, 1.5, Pen.alpha(Pen.DENY_COL, 0.8 * (1.0 - (u - 6.8))), 0.8)
	if u >= 11.4:
		Pen.rrect(c, 325, GY - 12.5, 10, 2.4, 0.8, Pen.hex(0x4d6aa8))
	var offenB := 0.0
	if u >= 11.6:
		offenB = clampf((u - 11.6) / 0.6, 0.0, 1.0)
	_tor(c, 358, 26, offenB)
	# REZI: nach der Abweisung ein kurzer Kopfschüttler
	var rx := px - 9 * dir
	if u >= 6.9 and u < 7.5:
		rx += sin(t * 30.0) * 1.5
	Pen.rezi(c, rx, GY - 17 + jy + sin(t * 3.0) * 1.5, a, 1.0, st == "verschluesselt", false)
	_paul(c, px, GY + jy, schritt, dir, st, a)


# ================================================================ 13 E-Rezept
# eGK aufsammeln, unter der Kralle des falschen Lesers durch, am echten Terminal
# stecken: Der Fachdienst gibt das Rezept frei — die Apotheke holt es ab, der
# Eintrag landet in der ePA. Nichts davon lag je auf der Karte.

func _statik_13(c: CanvasItem) -> void:
	var accent: Color = theme["accent"]
	_block(c, 104, GY - 30, 66, 18)
	Pen.rect(c, 178, GY - 22, 2.4, 22, Pen.hex(0x39445e))
	Pen.pfad_linie(c, PFAD_13, Pen.alpha(Pen.K, 0.22), 0.6)
	_haus(c, 390, GY, 64, 60)
	Pen.rect(c, 362, GY - 46, 5, 1.6, Pen.hex(0x39445e))
	Pen.rect(c, 356, GY - 44.4, 11, 11, Pen.hex(0x0d2440, 0.95))
	Pen.polyline(c, PackedVector2Array([Vector2(358, GY - 35.4), Vector2(361.5, GY - 42.4), Vector2(365, GY - 35.4)]), Pen.alpha(accent, 0.95), 1.1)
	Pen.line(c, 359.6, GY - 38, 363.4, GY - 38, Pen.alpha(accent, 0.95), 1.1)
	_rack(c, 480, GY - 44, 36, 44)


func _leben_13(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	var G := Pen.hex(0x7fd07f)
	var px := 60.0
	var schritt := 0.0
	var duck := false
	var st := ""
	var a := 1.0
	if u < 1.6:
		px = 60 + 50 * (u / 1.6)
		schritt = t * 2.0
	elif u < 4.4:
		px = 110 + 80 * ((u - 1.6) / 2.8)
		duck = true
		schritt = t * 1.2
	elif u < 5.0:
		px = 190
	elif u < 6.6:
		px = 190 + 100 * ((u - 5.0) / 1.6)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 11.6:
		px = 290
		st = "verschluesselt"
	elif u < 13.2:
		px = 290 + 90 * ((u - 11.6) / 1.6)
		schritt = t * 2.2
		st = "verschluesselt"
		if u > 12.6:
			a = 1 - (u - 12.6) / 0.6
	else:
		a = 0.0
	# eGK am Weg
	if u < 1.0:
		_karte(c, 100, GY - 6 + sin(t * 2.5) * 1.2, "egk", 0.8)
	else:
		_ring(c, 100, GY - 6, (u - 1.0) / 0.5, G)
	# Fake-Leser mit Kralle
	var blocked := u >= 4.6
	var g1 := clampf((u - 2.0) / 0.4, 0.0, 1.0) * (1.0 - clampf((u - 2.7) / 0.5, 0.0, 1.0))
	var g2 := clampf((u - 3.4) / 0.4, 0.0, 1.0) * (1.0 - clampf((u - 4.1) / 0.5, 0.0, 1.0))
	var shake := 1.0 if ((u >= 1.7 and u < 2.0) or (u >= 3.1 and u < 3.4)) else 0.0
	var ext := 6.0
	var open := false
	if not blocked:
		ext = 42 * maxf(g1, g2)
		open = not ((u >= 2.4 and u < 2.7) or (u >= 3.8 and u < 4.1))
	_kralle(c, 176, GY - 11, ext, open, blocked, shake, -1)
	if blocked:
		var k := clampf((u - 4.6) / 0.4, 0.0, 1.0)
		_blende(c, 176, GY - 44 + 28 * (1.0 - pow(1.0 - k, 2)))
		_sterne(c, 156, GY - 22, (u - 4.9) / 1.0)
	# Lauscher vor dem Terminal
	_lauscher(c, 235, GY - 28, -1, 40, 11, st == "" and a > 0.0 and px >= 195 and px <= 235)
	_ring(c, px, GY - 7, (u - 5.0) / 0.5, K)
	# Echtes Terminal, Tor zur Apotheke
	var licht := G if u >= 6.8 else Pen.hex(0x4a5468)
	_terminal(c, 290, GY, 14, 22, licht)
	if u >= 6.8:
		Pen.rrect(c, 285, GY - 12.5, 10, 2.4, 0.8, Pen.hex(0x2c7a52))
	var offen := 0.0
	if u >= 10.8:
		offen = clampf((u - 10.8) / 0.6, 0.0, 1.0)
	_tor(c, 318, 26, offen)
	# Freigabe zum Fachdienst, Rezept zurück zur Apotheke
	if u >= 7.0 and u < 8.4:
		_puls(c, Pen.pfad_punkt(PFAD_13, (u - 7.0) / 1.4), K)
	_rack_leds(c, 480, GY - 44, 36, 44, 9.0 if (u >= 8.4 and u < 9.4) else 2.5)
	if u >= 9.4 and u < 10.8:
		var p := Pen.pfad_punkt(PFAD_13B, (u - 9.4) / 1.4)
		_doc(c, p.x, p.y - 6, 1.0, 0.0, true)
	elif u >= 10.8 and u < 12.8:
		_doc(c, 390, GY - 24 + sin(t * 2.0) * 1.0, 1.0, 0.0, true)
	# Eintrag in die ePA (Medikationsliste) — die einzige Automatik
	var voll := 0.0
	if u >= 12.8 and u < 14.4:
		var k := (u - 12.8) / 1.6
		var ex := 390 + (548 - 390) * k
		var ey := GY - 24 - sin(k * PI) * 30 + (GY - 26 - (GY - 24)) * k
		Pen.circle(c, ex, ey, 2.6, Pen.alpha(G, 0.3))
		Pen.circle(c, ex, ey, 1.0, Color(1, 1, 1, 0.95))
	if u >= 14.4:
		voll = clampf((u - 14.4) / 0.8, 0.0, 1.0)
	_akte(c, 548, GY - 22, 1.2, 1.0, voll)
	if u >= 14.4:
		_ring(c, 548, GY - 22, (u - 14.4) / 0.6, G)
	var ry := GY - 17 + sin(t * 3.0) * 1.5
	if duck:
		ry = GY - 8
	Pen.rezi(c, px - 9, ry, a, 1.0, st == "verschluesselt", false)
	_paul(c, px, GY, schritt, 1, st, a, duck)


# ================================================================ 14 Die VAU
# Verschlüsselt ins Rechenzentrum, im VAU-Raum wird im Klartext gearbeitet — das
# Betreiber-Auge sieht nicht hinein. Draußen zählt wieder die eigene Hülle.

func _statik_14(c: CanvasItem) -> void:
	var sky_top: Color = theme["sky_top"]
	var detail: Color = theme["detail"]
	Pen.rect(c, 250, GY - 70, 220, 70, Pen.darken(sky_top, 0.45))
	Pen.srect(c, 250, GY - 70, 220, 70, Pen.alpha(detail, 0.7), 0.8)
	Pen.rect(c, 248, GY - 72, 224, 2, Pen.alpha(detail, 0.7))
	Pen.rect(c, 250, GY - 16, 8, 16, Pen.hex(0x0d1a2c))
	Pen.rect(c, 462, GY - 16, 8, 16, Pen.hex(0x0d1a2c))
	_rack(c, 434, GY - 46, 12, 42)
	_rack(c, 450, GY - 46, 12, 42)


func _leben_14(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	var px := 70.0
	var schritt := 0.0
	var st := ""
	var a := 1.0
	if u < 1.2:
		px = 70 + 40 * (u / 1.2)
		schritt = t * 2.0
	elif u < 3.4:
		px = 110 + 145 * ((u - 1.2) / 2.2)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 4.2:
		px = 255 + 45 * ((u - 3.4) / 0.8)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 7.4:
		px = 300 + 115 * ((u - 4.2) / 3.2)
		schritt = t * 2.2
		st = "vau"
	elif u < 8.0:
		px = 415 + 10 * ((u - 7.4) / 0.6)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 10.0:
		px = 425 + 45 * ((u - 8.0) / 2.0)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 12.0:
		px = 470 + 90 * ((u - 10.0) / 2.0)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 13.0:
		px = 560
		st = "verschluesselt"
		a = 1 - (u - 12.0)
	else:
		a = 0.0
	var sichtbar := st == "" and a > 0.0
	_lauscher(c, 150, GY - 28, 1, 70, 15, sichtbar and px >= 150 and px <= 220)
	_ring(c, px, GY - 7, (u - 1.2) / 0.5, K)
	# Der VAU-Raum im Rechenzentrum; das Betreiber-Auge endet an der Wand
	_vau(c, 300, GY - 56, 120, 54, st == "vau")
	_lauscher(c, 278, GY - 40, 1, 20, 6, false)
	_rack_leds(c, 434, GY - 46, 12, 42, 2.5)
	_rack_leds(c, 450, GY - 46, 12, 42, 2.1)
	_ring(c, 300, GY - 7, (u - 4.2) / 0.6, Pen.VAU_COL)
	_ring(c, 420, GY - 7, (u - 7.4) / 0.6, K)
	# Drinnen wird die Akte im Klartext geschrieben
	if u >= 4.6 and u < 7.4:
		var da := Pen.blende(u, 4.6, 7.4, 0.4)
		var zeile := clampf((u - 5.0) / 1.4, 0.0, 1.0)
		_doc(c, px - 9, GY - 32 + sin(t * 2.0) * 1.0, da, zeile, false)
		if u >= 6.6:
			Pen.polyline(c, PackedVector2Array([Vector2(px - 5, GY - 30), Vector2(px - 3.5, GY - 28.5), Vector2(px - 1, GY - 32)]), Pen.hex(0x7fd07f, 0.95 * da), 0.9)
	_lauscher(c, 565, GY - 28, -1, 60, 14, sichtbar and px >= 505 and px <= 565)
	Pen.rezi(c, px - 9, GY - 17 + sin(t * 3.0) * 1.5, a, 1.0, st == "verschluesselt", false)
	_paul(c, px, GY, schritt, 1, st, a)


# ================================================================ 15 Kontextschlüssel
# Erster Durchgang: die Sitzung läuft ab, Paul fällt in den Klartext — und wird
# gesehen. Zweiter Durchgang: der Anker frischt die Sitzung auf, rechtzeitig raus.

func _statik_15(c: CanvasItem) -> void:
	pass


func _leben_15(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	var px := 70.0
	var schritt := 0.0
	var st := ""
	var a := 1.0
	var dir := 1
	var uhr := -1.0
	if u < 1.0:
		px = 70 + 30 * u
		schritt = t * 2.0
	elif u < 3.4:
		px = 100 + 120 * ((u - 1.0) / 2.4)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 6.4:
		px = 220 + 170 * ((u - 3.4) / 3.0)
		schritt = t * 2.2
		st = "vau"
		uhr = 1.0 - (u - 3.4) / 3.0
	elif u < 7.4:
		px = 390 + 50 * ((u - 6.4) / 1.0)
		schritt = t * 2.2
	elif u < 8.6:
		px = 440
	elif u < 9.6:
		px = 440
		a = 1 - (u - 8.6)
	elif u < 10.4:
		px = 100
		a = (u - 9.6) / 0.8
	elif u < 13.0:
		px = 100 + 120 * ((u - 10.4) / 2.6)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 14.8:
		px = 220 + 110 * ((u - 13.0) / 1.8)
		schritt = t * 2.2
		st = "vau"
		uhr = 1.0 - (u - 13.0) / 3.0
	elif u < 16.4:
		px = 330 + 90 * ((u - 14.8) / 1.6)
		schritt = t * 2.2
		st = "vau"
		uhr = 1.0 - (u - 14.8) / 3.0
	elif u < 18.6:
		px = 420 + 100 * ((u - 16.4) / 2.2)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 19.6:
		px = 520
		st = "verschluesselt"
		a = 1 - (u - 18.6)
	else:
		a = 0.0
	var sichtbar := st == "" and a > 0.0
	_lauscher(c, 150, GY - 28, 1, 60, 14, sichtbar and px >= 150 and px <= 210)
	_vau(c, 220, GY - 50, 200, 48, st == "vau")
	if uhr >= 0.0:
		_uhr(c, 320, GY - 64, clampf(uhr, 0.0, 1.0))
	var ap := 0.0
	if u >= 14.8 and u < 15.3:
		ap = 1.0 - (u - 14.8) / 0.5
	_anker(c, 330, GY - 12, ap)
	_ring(c, 330, GY - 12, (u - 14.8) / 0.6, Pen.VAU_COL)
	# Sitzung abgelaufen: warmer Ring, Paul ist Klartext — und wird gesehen
	_ring(c, px, GY - 7, (u - 6.4) / 0.6, Pen.WARM)
	var l2 := sichtbar and px >= 426 and px <= 470
	_lauscher(c, 470, GY - 28, -1, 44, 12, l2)
	if u >= 7.1 and u < 7.9:
		var k := (u - 7.1) / 0.8
		for i in 3:
			Pen.circle(c, 438 - 10 * k - i * 5, GY - 14 - 18 * k + i * 4, 1.2, Pen.alpha(K, 0.9 * (1.0 - k)))
	for tt in [1.0, 10.4]:
		_ring(c, px, GY - 7, (u - float(tt)) / 0.5, K)
	for tt in [3.4, 13.0]:
		_ring(c, 220, GY - 7, (u - float(tt)) / 0.6, Pen.VAU_COL)
	_ring(c, 420, GY - 7, (u - 16.4) / 0.6, K)
	Pen.rezi(c, px - 9, GY - 17 + sin(t * 3.0) * 1.5, a, 1.0, st == "verschluesselt", false)
	_paul(c, px, GY, schritt, dir, st, a)


# ================================================================ 19 Berechtigungen
# Drei Tore, alle öffnet nur die eGK; die Praxis mit ihrer SMC-B wird abgewiesen.
# Am Ende entzieht die ePA-App die Befugnis: das Tor schließt sich wieder.

func _statik_19(c: CanvasItem) -> void:
	var detail: Color = theme["detail"]
	for sx in [100.0, 548.0]:
		Pen.rect(c, sx - 22, GY - 50, 44, 50, Pen.hex(0x141c2e))
		Pen.srect(c, sx - 22, GY - 50, 44, 50, Pen.alpha(detail, 0.5), 0.6)
		for i in 4:
			Pen.rect(c, sx - 19, GY - 44 + i * 11, 38, 0.8, Pen.alpha(detail, 0.35))
			for j in 6:
				Pen.rect(c, sx - 18 + j * 6.2, GY - 51 + i * 11 + 4, 4.4, 6, Pen.hex(0x2a3550 if (i + j) % 3 != 0 else 0x3a4a6a))


func _leben_19(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	var G := Pen.hex(0x7fd07f)
	var px := 60.0
	var schritt := 0.0
	var st := ""
	var a := 1.0
	var dir := 1
	if u < 1.2:
		px = 60 + 40 * (u / 1.2)
		schritt = t * 2.0
	elif u < 2.6:
		px = 100 + 72 * ((u - 1.2) / 1.4)
		schritt = t * 2.0
	elif u < 3.6:
		px = 172
	elif u < 4.2:
		px = 172 + 43 * ((u - 3.6) / 0.6)
		schritt = t * 2.2
	elif u < 6.4:
		px = 215 + 87 * ((u - 4.2) / 2.2)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 7.4:
		px = 302
		st = "verschluesselt"
	elif u < 8.0:
		px = 302 + 43 * ((u - 7.4) / 0.6)
		schritt = t * 1.7
		st = "verschluesselt"
	elif u < 9.4:
		px = 345 + 87 * ((u - 8.0) / 1.4)
		schritt = t * 2.2
	elif u < 10.4:
		px = 432
	elif u < 12.0:
		px = 432 + 88 * ((u - 10.4) / 1.6)
		schritt = t * 2.2
	elif u < 15.4:
		px = 520
		dir = -1
	elif u < 16.4:
		px = 520
		dir = -1
		a = 1 - (u - 15.4)
	else:
		a = 0.0
	# eGK am Weg
	if u < 1.0:
		_karte(c, 100, GY - 6 + sin(t * 2.5) * 1.2, "egk", 0.8)
	else:
		_ring(c, 100, GY - 6, (u - 1.0) / 0.5, G)
	# Drei Terminals, drei Tore
	var pressed := [2.8, 6.6, 9.6]
	var terminals := [172.0, 302.0, 432.0]
	var tore := [200.0, 330.0, 460.0]
	for i in 3:
		var tx: float = terminals[i]
		var tp: float = pressed[i]
		var licht := G if u >= tp else Pen.hex(0x4a5468)
		if i == 1 and u >= 2.6 and u < 3.6:
			licht = Pen.alpha(Pen.DENY_COL, 0.6 + 0.4 * sin(t * 6.0))
		_terminal(c, tx, GY, 14, 22, licht)
		if u >= tp and (i < 2 or u < 13.4):
			Pen.rrect(c, tx - 5, GY - 12.5, 10, 2.4, 0.8, Pen.hex(0x2c7a52))
		var offen := 0.0
		if u >= tp + 0.2:
			offen = clampf((u - tp - 0.2) / 0.6, 0.0, 1.0)
		if i == 2 and u >= 13.0:
			offen = 1.0 - clampf((u - 13.0) / 0.6, 0.0, 1.0)
		_tor(c, tore[i], 30, offen)
	if u >= 2.6 and u < 3.6:
		Pen.srrect(c, 294, GY - 23, 16, 24, 1.5, Pen.alpha(Pen.DENY_COL, 0.8 * (1.0 - (u - 2.6))), 0.8)
	# Die Praxis versucht es mit der SMC-B — und wird abgewiesen
	var pa := 1.0
	if u >= 4.8:
		pa = 1 - clampf((u - 4.8) / 0.8, 0.0, 1.0)
	if pa > 0.0:
		Pen.figur(c, 288, GY, Pen.P_PFLEGE, 0, 1, pa)
		if u >= 1.6 and u < 2.6:
			var k := (u - 1.6) / 1.0
			_karte(c, 292 + 6 * k, GY - 20 - 2 * k, "smcb", 0.65, pa)
	# Lauscher zwischen Tür 1 und Terminal 2
	var sichtbar := st == "" and a > 0.0
	_lauscher(c, 265, GY - 28, -1, 40, 11, sichtbar and px >= 225 and px <= 265)
	_ring(c, px, GY - 7, (u - 4.2) / 0.5, K)
	_ring(c, px, GY - 7, (u - 8.0) / 0.5, K)
	# ePA-App: Befugnis entziehen — Tor 3 schließt sich hinter Paul
	if u >= 12.0 and u < 15.6:
		var ha := Pen.blende(u, 12.0, 15.6, 0.5)
		var kipp := clampf((u - 12.8) / 0.4, 0.0, 1.0)
		_handy(c, 540, GY - 38, 24, ha, kipp)
	Pen.rezi(c, px - 9 * dir, GY - 17 + sin(t * 3.0) * 1.5, a, 1.0, st == "verschluesselt", false)
	_paul(c, px, GY, schritt, dir, st, a)


# ================================================================ 20 Souveränität
# Kein Lauscher, kein Tor: nur der Weg, ein VAU-Feld, Prüfsummen — und die
# letzte Tür, die nicht Paul öffnet, sondern die Person, der die Akte gehört.

func _statik_20(c: CanvasItem) -> void:
	var detail: Color = theme["detail"]
	for sx in [90.0, 118.0]:
		Pen.rect(c, sx - 12, GY - 46, 24, 46, Pen.hex(0x141c2e))
		Pen.srect(c, sx - 12, GY - 46, 24, 46, Pen.alpha(detail, 0.5), 0.6)
		for i in 4:
			Pen.rect(c, sx - 10, GY - 40 + i * 10, 20, 0.8, Pen.alpha(detail, 0.35))
			for j in 3:
				Pen.rect(c, sx - 9 + j * 6.4, GY - 46 + i * 10 + 3, 4.6, 6, Pen.hex(0x2a3550 if (i + j) % 2 != 0 else 0x3a4a6a))


func _leben_20(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	var px := 60.0
	var schritt := 0.0
	var st := ""
	var a := 1.0
	if u < 3.0:
		px = 60 + 140 * (u / 3.0)
		schritt = t * 2.0
	elif u < 4.2:
		px = 200 + 60 * ((u - 3.0) / 1.2)
		schritt = t * 2.2
		st = "vau"
	elif u < 7.0:
		px = 260 + 135 * ((u - 4.2) / 2.8)
		schritt = t * 2.0
	elif u < 14.0:
		px = 395
	elif u < 16.4:
		px = 395 + 125 * ((u - 14.0) / 2.4)
		schritt = t * 2.0
	elif u < 17.4:
		px = 520
		a = 1 - (u - 16.4)
	else:
		a = 0.0
	# Prüfsummen auf dem Weg
	var orbs := [[130.0, GY - 26], [160.0, GY - 38], [300.0, GY - 28]]
	for i in orbs.size():
		var o: Array = orbs[i]
		var ox: float = o[0]
		var oy: float = o[1]
		var t_hit := (ox - 60) / 140 * 3.0 if ox < 200 else 4.2 + (ox - 260) / 135 * 2.8
		if u < t_hit or u >= 17.6:
			_orb(c, ox, oy + sin(t * 2.4 + i) * 1.5, false, 1.0)
		else:
			_ring(c, ox, oy, (u - t_hit) / 0.4, K)
	_vau(c, 190, GY - 34, 70, 32, st == "vau")
	_ring(c, 200, GY - 7, (u - 3.0) / 0.6, Pen.VAU_COL)
	# Die letzte Tür: Abweisung, Protokoll, Freigabe durch die Versicherte
	var rise := 0.0
	if u >= 13.4:
		rise = clampf((u - 13.4) / 0.6, 0.0, 1.0)
	_tuer(c, 430, 40, rise, u >= 13.4)
	if u >= 7.2 and u < 7.8:
		Pen.scircle(c, 430, GY - 20, 8 + 6 * (u - 7.2), Pen.hex(0x9fb0cc, 0.8 * (1.0 - (u - 7.2) / 0.6)), 0.8)
	if u >= 9.6 and u < 13.4:
		for i in 3:
			var von := 10.2 + i * 0.6
			if u >= von:
				var la := clampf((u - von) / 0.3, 0.0, 1.0) * Pen.blende(u, 9.6, 13.4, 0.3)
				var w: float = [40.0, 30.0, 36.0][i]
				Pen.rect(c, 430 - w / 2, GY - 71 + i * 4.4, w, 1.4, Pen.hex(0xffb070 if i == 1 else 0x9aa6bc, 0.85 * la))
	if u >= 13.4:
		_ring(c, 430, GY - 20, (u - 13.4) / 0.8, Pen.GOLD_COL)
		Pen.glow(c, 430, GY - 22, Pen.GOLD_COL, 26, 0.10 * rise)
	# Die Versicherte mit ihrer ePA-App entscheidet
	Pen.figur(c, 480, GY, Pen.P_GELB, 0, -1)
	var kipp := 1.0
	if u >= 13.0:
		kipp = 1.0 - clampf((u - 13.0) / 0.4, 0.0, 1.0)
	if u >= 12.4:
		var ha := clampf((u - 12.4) / 0.5, 0.0, 1.0)
		_handy(c, 494, GY - 30, 20, ha, kipp)
	Pen.rezi(c, px - 9, GY - 17 + sin(t * 3.0) * 1.5, a, 1.0, false, false)
	_paul(c, px, GY, schritt, 1, st, a)
