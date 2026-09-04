class_name Intro
extends Vignette
## INTRO — drei Screens vor dem Spielstart (Port von zeitreise.ts + tutorial.ts):
##
##  Phase 1 „FRÜHER":  Papier regiert. Boten und Patienten pendeln mit Akten-
##                     stapeln von Tür zu Tür, Blätter gehen verloren, das Fax
##                     spuckt ohne Pause, die Uhr rast.
##  Phase 2 „HEUTE":   Die TI als Lehrstück in fünf Schritten — Sprechzimmer,
##                     Konnektor legt die Hülle an, TI-Gateway, VAU schreibt die
##                     Akte (Hülle öffnet sich im geschützten Raum), Abruf in App
##                     und beim nächsten Arzt. Das ist die Erklärung, was sich
##                     mit der ePA geändert hat.
##  Phase 3 „SO SPIELST DU": Paul führt die Steuerung vor — laufen, springen,
##                     Datenbit, Hülle. Der echte Player läuft im Autopilot.
##
## Jede Phase hat eine Mindest-Anzeigedauer (die Botschaft lässt sich nicht
## wegdrücken); danach blättert jeder Knopf weiter. Kein Blinken über 3 Hz.
## Die Erzählzeilen laufen im Erzählband der Vignette (REZI erzählt).

const ZEITREISE_SPERRE := {1: 7.5, 2: 10.5}
const TUTORIAL_SPERRE := 4.0
const FRUEHER_TAKT := 3.75
const FRUEHER_ZEILEN := [
	"Ein Rezept? Gibt es in der Praxis — auf Papier, versteht sich.",
	"Befunde reisen per Bote, per Fax, per Fußweg.",
	"Der nächste Arzt? Fängt ohne deine Unterlagen von vorn an.",
	"Zettel gehen verloren — und mit ihnen Zeit.",
]
const SCHRITTE := [
	"1 · Im Sprechzimmer: Der Arzt tippt Diagnose und Rezept ins Praxissystem.",
	"2 · Der Konnektor legt die Hülle an — verschlüsselt geht es in die TI.",
	"3 · Durchs TI-Gateway: den bewachten Zugang zur Telematikinfrastruktur.",
	"4 · Fachdienst ePA: In der VAU wird die Akte geschrieben — niemand liest mit.",
	"5 · Sofort da: auf den Handys der Versicherten und beim nächsten Arzt.",
]
const FENSTER := [[0.4, 7.2], [7.2, 10.6], [10.6, 14.4], [14.4, 20.0], [20.0, 28.0]]
const HAEUSER := {
	"praxis": {"x0": 36.0, "x1": 146.0, "dach": 214.0, "tuer": 92.0},
	"facharzt": {"x0": 176.0, "x1": 286.0, "dach": 192.0, "tuer": 232.0},
	"klinik": {"x0": 316.0, "x1": 466.0, "dach": 138.0, "tuer": 392.0},
	"apotheke": {"x0": 496.0, "x1": 606.0, "dach": 226.0, "tuer": 571.0},
}
const BODEN := 320.0
const NETZ_Y := 351.0
const ZYKLUS_HEUTE := 30.0
# Probelauf
const RUNDE := 13.0
const POPUP_FENSTER := [[0.4, 3.1], [3.1, 4.6], [4.6, 6.2], [6.2, 9.4]]
const TOGGLE_ZEITEN := [6.6, 7.8, 8.6, 9.4]
const FUSS_Y := 290.0
const LAUF := 0.6

var phase := 1
var popups: Array = []
var player: Player
var rezi: Rezi
var _last_td := 0.0
var _jumped1 := false
var _jumped2 := false
var _jump_t := -10.0
var _bit_taken := false
var _bit_t := -10.0
var _toggles := [false, false, false, false]


func _init(p := 1) -> void:
	phase = p
	sperre = TUTORIAL_SPERRE if p == 3 else float(ZEITREISE_SPERRE[p])
	var kn := Kiosk.label_confirm()
	weiter_text = tr(["%s: Und heute?", "%s: Zum Probelauf!", "%s: Los geht's!"][p - 1]) % kn
	dots = [p == 1, p == 2, p == 3]


func _build() -> void:
	if phase == 3:
		_build_tutorial()
		return
	header("FRÜHER" if phase == 1 else "HEUTE",
		"Rezepte auf Papier: jeder Weg zu Fuß, Zettel für Zettel." if phase == 1 else "So arbeitet die Telematikinfrastruktur — Schritt für Schritt.")
	for key in ["praxis", "facharzt", "klinik", "apotheke"]:
		var h: Dictionary = HAEUSER[key]
		var schild: String = {"praxis": "HAUSARZT", "facharzt": "FACHARZT", "klinik": "KLINIKUM", "apotheke": "APOTHEKE"}[key]
		label((h.x0 + h.x1) / 2, h.dach + 11, schild, 5.5, {"color": Pen.hex(0xffd75e) if key == "apotheke" else Pen.hex(0xdfe6f0), "spacing": 1.0})
	label(160.5, 288.4, "TEL", 3.2, {"color": Pen.hex(0x3a2f08), "spacing": 0.5})
	if phase == 1:
		label(56, 300, "FAX", 4, {"color": Pen.hex(0x9fb0cc), "bold": false})
		story_cycle = FRUEHER_TAKT * FRUEHER_ZEILEN.size()
		for i in FRUEHER_ZEILEN.size():
			story_line(str(FRUEHER_ZEILEN[i]), i * FRUEHER_TAKT + (0.2 if i == 0 else 0.0), (i + 1) * FRUEHER_TAKT, {"color": Pen.hex(0xffe6c8)})
	else:
		label(310, 349.5, "TI-GATEWAY", 3.8, {"color": Pen.hex(0x4de3ff), "spacing": 0.4})
		label(424, 336.5, "RECHENZENTRUM", 3.8, {"color": Pen.hex(0x9fb0cc), "spacing": 0.5, "bold": false})
		label(391, 352.2, "VAU", 3.8, {"color": Pen.hex(0x4de3ff), "spacing": 0.6})
		label(443, 344.5, "ePA", 3.5, {"color": Pen.hex(0x4de3ff), "spacing": 0.3})
		story_cycle = ZYKLUS_HEUTE
		for i in SCHRITTE.size():
			story_line(str(SCHRITTE[i]), float(FENSTER[i][0]), float(FENSTER[i][1]))


func _tick(_delta: float) -> void:
	if phase == 3:
		_tick_tutorial()


func _draw_static(c: CanvasItem) -> void:
	if phase == 3:
		_draw_tutorial_static(c)
	else:
		_draw_zeitreise_static(c)


func _draw_glow(c: CanvasItem) -> void:
	var accent: Color = theme["accent"]
	var detail: Color = theme["detail"]
	if phase == 3:
		Pen.glow(c, 245, 290, detail, 30, 0.06)
		Pen.glow(c, 455, 290, detail, 26, 0.06)
		for lx in [96.0, 560.0]:
			Pen.glow(c, lx + 1, 276, Pen.hex(0xffd9a0), 12, 0.14)
		return
	var KL: Dictionary = HAEUSER["klinik"]
	var A: Dictionary = HAEUSER["apotheke"]
	Pen.glow(c, KL.x1 - 23.1, KL.dach - 31, Pen.hex(0xff5050), 7, 0.25)
	Pen.glow(c, 369, 297.5, Pen.hex(0x4d8dff), 10, 0.18)
	Pen.glow(c, A.x0 - 0.5, 265, accent, 11, 0.25)
	for lx in [16.0, 356.0, 628.0]:
		Pen.glow(c, lx + 1, 280, Pen.hex(0xffd9a0), 12, 0.14)
	if phase == 2:
		Pen.glow(c, 310, 349, Pen.K, 10, 0.10)
		Pen.glow(c, 399, 348, Pen.K, 12, 0.12)


func _draw_life(c: CanvasItem) -> void:
	if phase == 3:
		_draw_tutorial_life(c)
	else:
		_draw_zeitreise_life(c)


# ================================================================ Zeitreise

func _rumpf(c: CanvasItem, x0: float, x1: float, dach_y: float, tuer_mitte: float, tuer_breite: float, tonung: float) -> void:
	var sky_top: Color = theme["sky_top"]
	var detail: Color = theme["detail"]
	var accent: Color = theme["accent"]
	var wand := Pen.darken(sky_top, 0.32)
	var fenster_warm := Pen.hex(0xffd9a0)
	var fenster_kalt := Pen.mix(theme["sky_bottom"], theme["fog"], 0.5)
	var wand_ton := wand if tonung == 0.0 else Pen.mix(wand, Pen.hex(0x2c3850) if tonung > 0 else Pen.hex(0x101825), absf(tonung))
	var sockel := Pen.darken(sky_top, 0.58)
	Pen.rect(c, x0, dach_y, x1 - x0, BODEN - dach_y, wand_ton)
	Pen.rect(c, x0 - 3, BODEN - 30, x1 - x0 + 6, 30, sockel)
	Pen.rect(c, x0 - 3, BODEN - 30, x1 - x0 + 6, 1, Pen.alpha(detail, 0.3))
	Pen.rect(c, x0 - 2, dach_y - 3, x1 - x0 + 4, 3.5, Pen.darken(sky_top, 0.6))
	Pen.rect(c, x0 - 2, dach_y - 3, x1 - x0 + 4, 1, Pen.alpha(detail, 0.75))
	var fy := dach_y + 11
	while fy < BODEN - 40:
		var fx := x0 + 10
		while fx < x1 - 12:
			if absf(fx + 4 - tuer_mitte) >= tuer_breite:
				var an := int(round(fx * 7 + fy * 13)) % 5 < 2
				Pen.rect(c, fx - 0.8, fy - 0.8, 9.6, 11.6, Pen.darken(sky_top, 0.62))
				Pen.rect(c, fx, fy, 8, 10, Pen.alpha(fenster_warm if an else fenster_kalt, 0.85 if an else 0.5))
				Pen.rect(c, fx, fy, 8, 1, Pen.hex(0xfff3da, 0.5) if an else Color(1, 1, 1, 0.12))
				Pen.rect(c, fx + 3.6, fy, 0.8, 10, Pen.alpha(Pen.darken(sky_top, 0.5), 0.55 if an else 0.8))
				Pen.rect(c, fx - 1.4, fy + 10.8, 10.8, 0.9, Pen.hex(0xd9e2f2, 0.25))
			fx += 16
		fy += 22
	Pen.rect(c, tuer_mitte - tuer_breite / 2, BODEN - 26, tuer_breite, 26, Pen.hex(0x0d1a2c))
	Pen.srect(c, tuer_mitte - tuer_breite / 2, BODEN - 26, tuer_breite, 26, Pen.alpha(detail, 0.8), 0.8)
	Pen.rect(c, tuer_mitte - tuer_breite / 2 + 1.5, BODEN - 24.5, tuer_breite - 3, 1, Pen.hex(0xffd9a0, 0.5))
	Pen.circle(c, tuer_mitte + tuer_breite / 2 - 3, BODEN - 13, 0.8, Pen.alpha(accent, 0.7))
	Pen.rect(c, tuer_mitte - tuer_breite / 2 - 4, BODEN - 29, tuer_breite + 8, 2.6, Pen.darken(sky_top, 0.65))
	Pen.rect(c, tuer_mitte - tuer_breite / 2 - 4, BODEN - 29, tuer_breite + 8, 0.8, Pen.alpha(detail, 0.5))
	Pen.bodenschein(c, tuer_mitte, BODEN + 1, tuer_breite + 16, 0.1)


func _draw_zeitreise_static(c: CanvasItem) -> void:
	var sky_top: Color = theme["sky_top"]
	var sky_bottom: Color = theme["sky_bottom"]
	var fog: Color = theme["fog"]
	var accent: Color = theme["accent"]
	var detail: Color = theme["detail"]
	var K := Pen.K
	var wand_dunkel := Pen.darken(sky_top, 0.5)
	var fenster_kalt := Pen.mix(sky_bottom, fog, 0.5)
	var strasse := Pen.darken(theme["ground"], 0.45)
	var gehweg := Pen.darken(theme["ground_top"], 0.3)

	# ---- Mittelgrund: nähere Häuserzeile ----
	var mittelgrund := Pen.mix(Pen.darken(sky_top, 0.18), fog, 0.45)
	var mittel_fenster := Pen.mix(Pen.hex(0xffd9a0), fog, 0.62)
	for m in [[0.0, 52.0, 176.0], [88.0, 40.0, 200.0], [150.0, 58.0, 168.0], [268.0, 46.0, 190.0], [402.0, 54.0, 172.0], [472.0, 40.0, 198.0], [558.0, 46.0, 182.0], [616.0, 30.0, 204.0]]:
		var mx0: float = m[0]
		var mb: float = m[1]
		var mdach: float = m[2]
		Pen.rect(c, mx0, mdach, mb, BODEN - 2 - mdach, mittelgrund)
		Pen.rect(c, mx0 + 4, mdach - 7, 8, 7, mittelgrund)
		var fy := mdach + 10
		while fy < BODEN - 20:
			var fx := mx0 + 6
			while fx < mx0 + mb - 8:
				if int(round(fx * 5 + fy * 11)) % 7 < 2:
					Pen.rect(c, fx, fy, 4.5, 6, Pen.alpha(mittel_fenster, 0.5))
				fx += 13
			fy += 20

	# ---- Straße ----
	Pen.rect(c, 0, BODEN - 2, W, 8, gehweg)
	Pen.rect(c, 0, BODEN - 2, W, 0.8, Color(1, 1, 1, 0.08))
	Pen.rect(c, 0, BODEN + 6, W, 40, strasse)
	var sx := 4.0
	while sx < W:
		Pen.rect(c, sx, 339, 7, 1.2, Pen.alpha(detail, 0.35))
		sx += 16
	for i in 5:
		Pen.rect(c, 374 + i * 8, 328, 5, 30, Pen.hex(0xd8e0f0, 0.22))
	for gx in [140.0, 530.0]:
		Pen.circle(c, gx, 330, 3.4, Pen.darken(theme["ground"], 0.6))
		Pen.scircle(c, gx, 330, 3.4, Color(1, 1, 1, 0.12), 0.5)

	# ---- Häuser ----
	var P: Dictionary = HAEUSER["praxis"]
	var F: Dictionary = HAEUSER["facharzt"]
	var KL: Dictionary = HAEUSER["klinik"]
	var A: Dictionary = HAEUSER["apotheke"]
	_rumpf(c, P.x0, P.x1, P.dach, P.tuer, 20, 0.3)
	_rumpf(c, F.x0, F.x1, F.dach, F.tuer, 20, -0.25)
	_rumpf(c, KL.x0, KL.x1, KL.dach, KL.tuer, 28, 0.0)
	_rumpf(c, A.x0, A.x1, A.dach, A.tuer, 20, 0.22)
	for key in ["praxis", "facharzt", "klinik", "apotheke"]:
		var h: Dictionary = HAEUSER[key]
		var mitte: float = (h.x0 + h.x1) / 2
		Pen.rect(c, mitte - 32, h.dach + 5, 64, 12, Pen.hex(0x0e1a2c, 0.92))
		Pen.srect(c, mitte - 32, h.dach + 5, 64, 12, Pen.alpha(detail, 0.8), 0.7)

	# ---- Dachzone ----
	Pen.rect(c, P.x0 + 18, P.dach - 14, 7, 12, Pen.darken(sky_top, 0.55))
	Pen.rect(c, P.x0 + 18, P.dach - 14, 7, 1, Pen.alpha(detail, 0.4))
	Pen.rect(c, F.x1 - 26, F.dach - 22, 1.6, 20, Pen.hex(0x39445e))
	Pen.rect(c, F.x1 - 30, F.dach - 18, 9.6, 1, Pen.hex(0x39445e))
	Pen.rect(c, F.x1 - 28.5, F.dach - 13, 6.6, 1, Pen.hex(0x39445e))
	Pen.rect(c, KL.tuer - 34, KL.dach - 10, 34, 8, Pen.darken(sky_top, 0.52))
	Pen.rect(c, KL.tuer - 34, KL.dach - 10, 34, 1, Pen.alpha(detail, 0.45))
	Pen.rect(c, KL.x1 - 24, KL.dach - 30, 1.8, 28, Pen.hex(0x39445e))
	Pen.rect(c, KL.x1 - 28, KL.dach - 24, 10, 1, Pen.hex(0x39445e))
	Pen.circle(c, KL.x1 - 23.1, KL.dach - 31, 1.3, Pen.hex(0xff5050, 0.95))
	Pen.rect(c, A.x0 + 14, A.dach - 8, 16, 6, Pen.darken(sky_top, 0.55))
	for i in 3:
		Pen.rect(c, A.x0 + 16 + i * 5, A.dach - 7, 2.6, 4, Pen.hex(0x39445e))

	# ---- Straßenmöbel: Telefonzelle, Briefkasten ----
	Pen.rect(c, 154, 286, 13, 34, Pen.hex(0x8a6a12))
	Pen.rect(c, 155.2, 287.2, 10.6, 2.2, Pen.hex(0xffd75e, 0.9))
	Pen.rect(c, 156.4, 291, 8.2, 22, Pen.hex(0xfff2c8, 0.55))
	Pen.rect(c, 159.8, 291, 1.2, 22, Pen.hex(0x8a6a12))
	Pen.bodenschein(c, 160.5, BODEN + 1, 24, 0.08)
	Pen.rect(c, 484, 302, 10, 12, Pen.hex(0xc99a1a))
	Pen.rect(c, 485, 305, 8, 1.2, Pen.hex(0x8a6a12))
	Pen.rect(c, 487.6, 314, 2.8, 6, Pen.hex(0x8a6a12))

	# Klinik: weißes H auf Blau + EKG-Linie
	Pen.rect(c, 362, 292, 14, 11, Pen.hex(0x1d4f9c))
	Pen.rect(c, 364.5, 294, 2.2, 7, Color(1, 1, 1, 0.95))
	Pen.rect(c, 371.3, 294, 2.2, 7, Color(1, 1, 1, 0.95))
	Pen.rect(c, 364.5, 296.6, 9, 1.8, Color(1, 1, 1, 0.95))
	Pen.ekg(c, 380, 290, 60, 2.4, 0.35, 0)
	# Apotheken-A
	Pen.rect(c, A.x0, 258, 5, 1.6, Pen.hex(0x39445e))
	Pen.rect(c, A.x0 - 6, 259.6, 11, 11, Pen.hex(0x0d2440, 0.95))
	Pen.polyline(c, PackedVector2Array([Vector2(A.x0 - 4, 268.6), Vector2(A.x0 - 0.5, 261.6), Vector2(A.x0 + 3, 268.6)]), Pen.alpha(accent, 0.95), 1.1)
	Pen.line(c, A.x0 - 2.4, 266, A.x0 + 1.4, 266, Pen.alpha(accent, 0.95), 1.1)
	# Schaufenster der Apotheke
	Pen.rect(c, A.tuer + 14, BODEN - 26, 26, 22, Pen.darken(sky_top, 0.62))
	Pen.rect(c, A.tuer + 15, BODEN - 25, 24, 20, Pen.hex(0xffd9a0, 0.28))
	var farben := [0x7fd07f, 0x4de3ff, 0xffd75e, 0xb9a6ff, 0xff8f8d]
	for reihe in 3:
		Pen.rect(c, A.tuer + 16, BODEN - 20.5 + reihe * 5.4, 22, 0.8, Pen.hex(0x39445e))
		for i in 6:
			Pen.rect(c, A.tuer + 17 + i * 3.5, BODEN - 23.4 + reihe * 5.4, 2.2, 2.6, Pen.hex(farben[(reihe * 5 + i * 3) % 5], 0.9))
	Pen.bodenschein(c, A.tuer + 27, BODEN + 1, 34, 0.1)
	# Praxis: Fax nur FRÜHER
	if phase == 1:
		Pen.rect(c, 46, 296, 20, 16, wand_dunkel)
		Pen.rect(c, 47, 297, 18, 14, Pen.hex(0xffd9a0, 0.16))
		Pen.rect(c, 50, 303, 12, 6, Pen.hex(0x39445e))
		Pen.rect(c, 51.2, 304.2, 1.2, 1.2, Pen.hex(0x7fd07f, 0.9))
	# Klinik: Treppenhaus-Fensterband
	var fy: float = KL.dach + 16
	while fy < BODEN - 48:
		Pen.rect(c, KL.tuer - 3.8, fy - 0.8, 7.6, 15.6, Pen.darken(sky_top, 0.62))
		Pen.rect(c, KL.tuer - 3, fy, 6, 14, Pen.alpha(fenster_kalt, 0.6))
		Pen.rect(c, KL.tuer - 3, fy, 6, 0.9, Color(1, 1, 1, 0.12))
		fy += 22
	# Straßenuhr
	Pen.rect(c, 304, 266, 2.2, 54, Pen.hex(0x39445e))
	Pen.circle(c, 305, 258, 9, Pen.hex(0x0e1a2c))
	Pen.scircle(c, 305, 258, 9, Pen.alpha(detail, 0.9), 1.0)
	# Laternen
	for lx in [16.0, 356.0, 628.0]:
		Pen.rect(c, lx, 282, 1.6, 38, Pen.hex(0x39445e))
		Pen.rect(c, lx - 1, 281.4, 3.6, 1, Pen.hex(0x39445e))
		Pen.rect(c, lx - 1.4, 278, 4.4, 3.6, Pen.hex(0xffd9a0, 0.95))
		Pen.bodenschein(c, lx + 1, BODEN + 1, 34, 0.09)

	# ---- Phase 1: liegengebliebene Blätter ----
	if phase == 1:
		for m in [[122.0, 323.0, 0.3], [208.0, 331.0, -0.25], [262.0, 344.0, 0.12], [341.0, 336.0, 0.5], [428.0, 324.0, -0.4], [468.0, 342.0, 0.2], [522.0, 330.0, -0.15]]:
			_blatt(c, m[0], m[1], m[2], 0.5)

	# ---- Phase 2: die TI zum Anfassen ----
	if phase == 2:
		var raum := Pen.darken(sky_bottom, 0.62)
		Pen.line(c, 73.5, NETZ_Y, 590, NETZ_Y, Pen.alpha(K, 0.3), 0.7)
		Pen.line(c, 73.5, 278, 73.5, NETZ_Y, Pen.alpha(K, 0.22), 0.5)
		Pen.line(c, 262, 296, 262, NETZ_Y, Pen.alpha(K, 0.22), 0.5)
		for hx in [348.0, 473.0]:
			var dy := NETZ_Y - 4
			while dy > 314:
				Pen.circle(c, hx, dy, 0.5, Pen.alpha(K, 0.35))
				dy -= 4
		Pen.rect(c, 569.5, NETZ_Y - 1.5, 3, 3, Pen.alpha(K, 0.5))
		# TI-Gateway
		Pen.rect(c, 292, 343, 36, 13, Pen.hex(0x141c2e))
		Pen.srect(c, 292, 343, 36, 13, Pen.alpha(detail, 0.7), 0.7)
		# Rechenzentrum
		Pen.rect(c, 378, 332, 92, 26, Pen.hex(0x0a1220))
		Pen.srect(c, 378, 332, 92, 26, Pen.alpha(detail, 0.7), 0.8)
		Pen.rect(c, 383, 340, 32, 16, Pen.alpha(K, 0.07))
		Pen.srect(c, 383, 340, 32, 16, Pen.alpha(K, 0.5), 0.6)
		for rx in [421.0, 437.0, 453.0]:
			Pen.rect(c, rx, 340, 12, 16, Pen.hex(0x141c2e))
			Pen.srect(c, rx, 340, 12, 16, Pen.alpha(detail, 0.6), 0.6)
		# Sprechzimmer in der Praxis
		Pen.rect(c, 44, 268, 36, 48, raum)
		Pen.srect(c, 44, 268, 36, 48, Pen.alpha(detail, 0.6), 0.8)
		for sx2 in [49.0, 75.0]:
			Pen.rect(c, sx2 - 3, 302, 6, 1.4, Pen.hex(0x39445e))
			Pen.rect(c, sx2 - 2.6, 303.4, 1.2, 12.6, Pen.hex(0x39445e))
			Pen.rect(c, sx2 + 1.4, 303.4, 1.2, 12.6, Pen.hex(0x39445e))
		Pen.rect(c, 56, 296, 14, 2, Pen.hex(0x2f3a52))
		Pen.rect(c, 58, 298, 1.6, 18, Pen.hex(0x2f3a52))
		Pen.rect(c, 66, 298, 1.6, 18, Pen.hex(0x2f3a52))
		Pen.rect(c, 57, 287, 8, 8, Pen.hex(0x0a1220))
		Pen.srect(c, 57, 287, 8, 8, Pen.hex(0x39445e), 0.5)
		Pen.rect(c, 69, 271, 9, 7, Pen.hex(0x3a4358))
		Pen.srect(c, 69, 271, 9, 7, Pen.alpha(detail, 0.8), 0.5)
		Pen.rect(c, 77.2, 275, 2, 1.4, Pen.hex(0xffd75e, 0.95))
		# Facharzt-Zimmer
		Pen.rect(c, 246, 272, 34, 44, raum)
		Pen.srect(c, 246, 272, 34, 44, Pen.alpha(detail, 0.6), 0.8)
		Pen.rect(c, 247, 302, 6, 1.4, Pen.hex(0x39445e))
		Pen.rect(c, 247.4, 303.4, 1.2, 12.6, Pen.hex(0x39445e))
		Pen.rect(c, 251.4, 303.4, 1.2, 12.6, Pen.hex(0x39445e))
		Pen.rect(c, 256, 296, 14, 2, Pen.hex(0x2f3a52))
		Pen.rect(c, 258, 298, 1.6, 18, Pen.hex(0x2f3a52))
		Pen.rect(c, 266, 298, 1.6, 18, Pen.hex(0x2f3a52))
		Pen.rect(c, 258, 287, 8, 8, Pen.hex(0x0a1220))
		Pen.srect(c, 258, 287, 8, 8, Pen.hex(0x39445e), 0.5)


## Einzelnes Blatt Papier, um `winkel` gedreht.
func _blatt(c: CanvasItem, x: float, y: float, winkel: float, a := 1.0, w := 4.6, h := 6.0) -> void:
	var cs := cos(winkel)
	var sn := sin(winkel)
	var pts := PackedVector2Array()
	for e in [[-w / 2, -h / 2], [w / 2, -h / 2], [w / 2, h / 2], [-w / 2, h / 2]]:
		pts.append(Vector2(x + e[0] * cs - e[1] * sn, y + e[0] * sn + e[1] * cs))
	Pen.poly(c, pts, Pen.hex(0xeef2f8, a))
	var pts2 := PackedVector2Array()
	for e in [[-w / 2 + 0.8, -h / 2 + 1.2], [w / 2 - 0.8, -h / 2 + 1.2], [w / 2 - 0.8, -h / 2 + 1.8], [-w / 2 + 0.8, -h / 2 + 1.8]]:
		pts2.append(Vector2(x + e[0] * cs - e[1] * sn, y + e[0] * sn + e[1] * cs))
	Pen.poly(c, pts2, Pen.hex(0x9aa6bc, a * 0.6))


## Aktenstapel auf den Armen einer Figur — schwankt oben stärker als unten.
func _stapel(c: CanvasItem, x: float, y_fuss: float, n: int, ph: float) -> void:
	var y_arm := y_fuss - 7.2
	for i in n:
		var sway := sin(t * 2.6 + ph + i * 0.8) * (0.25 + i * 0.22)
		Pen.rect(c, x - 3.5 + sway, y_arm - 1.3 * (i + 1), 7, 1.1, Pen.hex(0xeef2f8))
		Pen.rect(c, x - 3.5 + sway, y_arm - 1.3 * (i + 1) + 0.8, 7, 0.25, Pen.hex(0x9aa6bc, 0.5))


func _draw_zeitreise_life(c: CanvasItem) -> void:
	var K := Pen.K
	var P: Dictionary = HAEUSER["praxis"]
	var F: Dictionary = HAEUSER["facharzt"]
	var KL: Dictionary = HAEUSER["klinik"]
	var A: Dictionary = HAEUSER["apotheke"]

	# Uhr: FRÜHER rast der Minutenzeiger, HEUTE tickt er gemütlich
	var mA := t * (2.4 if phase == 1 else 0.06)
	Pen.line(c, 305, 258, 305 + sin(mA) * 6.5, 258 - cos(mA) * 6.5, Pen.hex(0xd8e0f0, 0.95), 1.0)
	Pen.line(c, 305, 258, 305 + sin(mA / 12 + 0.8) * 4, 258 - cos(mA / 12 + 0.8) * 4, Pen.hex(0xd8e0f0, 0.95), 1.0)
	# Vögel
	for v in [[0.0, 126.0], [2.6, 140.0], [5.4, 114.0]]:
		var vx := fmod(t * 9 + v[0] * 95, W + 60) - 30
		var schlag := sin(t * 2.4 + v[0] * 3) * 1.5
		Pen.polyline(c, PackedVector2Array([Vector2(vx - 2.8, v[1] - schlag), Vector2(vx, v[1] + 1), Vector2(vx + 2.8, v[1] - schlag)]), Pen.hex(0x9fb3c8, 0.45), 0.8)

	if phase == 1:
		var boten := [
			[P.tuer, F.tuer, 22.0, 0.0, Pen.P_BESUCH, 2], [KL.tuer, A.tuer, 17.0, 5.0, Pen.P_BOTE, 6],
			[F.tuer, KL.tuer, 26.0, 2.0, Pen.P_AERZTIN, 4], [P.tuer, A.tuer, 9.0, 9.0, Pen.P_OMA, 1],
			[P.tuer, KL.tuer, 33.0, 12.0, Pen.P_TECHNIK, 5], [F.tuer, A.tuer, 15.0, 7.0, Pen.P_PFLEGE, 3],
		]
		for b in boten:
			var xa: float = minf(b[0], b[1])
			var xb: float = maxf(b[0], b[1])
			var pos := Pen.pendel(t, xa, xb, b[2], b[3])
			Pen.figur(c, pos[0], BODEN, b[4], t * (b[2] / 14.0), pos[1])
			_stapel(c, pos[0] + pos[1] * 2.5, BODEN, b[5], b[3])
		for q in [[P.tuer + 16, Pen.P_PATIENT], [P.tuer + 24, Pen.P_BESUCH], [P.tuer + 32, Pen.P_OMA], [A.tuer + 16, Pen.P_PATIENT], [A.tuer + 24, Pen.P_TECHNIK]]:
			Pen.figur(c, q[0], BODEN, q[1], 0, -1)
		for e in [[300.0, 0.0], [478.0, 2.2], [162.0, 4.1]]:
			var u := fmod(t + e[1], 6.0) / 6.0
			if u < 0.2:
				var k := u / 0.2
				_blatt(c, e[0] + sin(k * 9) * 4, 300 + k * 17, k * 2.4, 0.95)
			elif u < 0.85:
				_blatt(c, e[0] + sin(9.0) * 4, 317.5, 0.18, 0.85)
			else:
				_blatt(c, e[0] + sin(9.0) * 4, 317.5, 0.18, 0.85 * (1 - (u - 0.85) / 0.15))
		var uw := fmod(t, 9.0) / 9.0
		_blatt(c, -10 + uw * 660, 314 - absf(sin(uw * 18)) * 4, uw * 30, 0.9)
		var fax := (fmod(t, 3.2) / 3.2) * 8
		Pen.rect(c, 56, 261, 2.8, fax, Pen.hex(0xeef2f8, 0.95))
	else:
		var u := fmod(tz, ZYKLUS_HEUTE)
		# --- Schritt 1: Gespräch, dann tippt der Arzt ---
		Pen.sitzend(c, 49, 302, Pen.P_PATIENT)
		Pen.sitzend(c, 75, 302, Pen.P_ARZT)
		if u < 4.2:
			var wer := sin(t * 1.6) > 0
			Pen.rrect(c, 44, 283, 8, 5, 1.5, Pen.hex(0xe9eef8, 0.9 if wer else 0.25))
			Pen.rrect(c, 72, 281, 8, 5, 1.5, Pen.hex(0x8fd6c8, 0.25 if wer else 0.9))
		var tippen := clampf((u - 4.2) / 2.6, 0, 1)
		if u >= 4.2 and u < 7.2:
			Pen.rect(c, 69, 292.6 + sin(t * 14) * 0.5, 3.4, 1, Pen.hex(Pen.P_ARZT["haut"]))
		for i in 3:
			var zeile := clampf(tippen * 3 - i, 0, 1)
			if zeile > 0:
				Pen.rect(c, 58, 288.5 + i * 2.2, 6 * zeile, 0.9, Pen.hex(0x8fd6c8, 0.85))
		# --- Der Eintrag als Datenfunke ---
		var orb := _orb_pos(u)
		if orb != Vector2.INF:
			var zu := u >= 8.8 and u < 15.6
			if not zu:
				Pen.circle(c, orb.x, orb.y, 3, Pen.alpha(Pen.WARM, 0.3))
			else:
				Pen.circle(c, orb.x, orb.y, 3.4, Pen.alpha(K, 0.16))
			if u >= 8 and u < 8.8:
				Pen.scircle(c, orb.x, orb.y, 6 - 3.6 * ((u - 8) / 0.8), Pen.alpha(K, 0.9), 0.8)
			elif zu:
				Pen.scircle(c, orb.x, orb.y, 2.4, Pen.alpha(K, 0.9), 0.8)
			elif u >= 15.6 and u < 16.4:
				Pen.scircle(c, orb.x, orb.y, 2.4 + 4 * ((u - 15.6) / 0.8), Pen.alpha(K, 0.9 * (1 - (u - 15.6) / 0.8)), 0.8)
			Pen.circle(c, orb.x, orb.y, 1.1, Color(1, 1, 1, 0.95))
		# Konnektor-LEDs
		for i in 2:
			var an := sin(t * (9.0 if (u >= 8 and u < 9.6) else 2.2) + i * 1.9) > -0.2
			Pen.rect(c, 70.5 + i * 3, 272.5, 1.6, 1.6, Pen.hex(0x7fd07f, 0.95 if an else 0.25))
		# Gateway: Scanlinie, grüner Haken
		if u >= 12.2 and u < 13.2:
			Pen.rect(c, 294 + 30 * (u - 12.2), 344.5, 1.2, 10, Pen.alpha(K, 0.35))
		if u >= 13 and u < 14.2:
			Pen.polyline(c, PackedVector2Array([Vector2(320.5, 346.5), Vector2(322, 348), Vector2(325, 344.5)]), Pen.hex(0x7fd07f, 0.95), 1.0)
		# Rack-LEDs
		var racks := [421.0, 437.0, 453.0]
		for ri in 3:
			for reihe in 4:
				var an := (ri * 7 + reihe * 13 + int(floor(t * 2.5)) * 29) % 11 < 4
				var col := Pen.alpha(K, 0.9) if an else Pen.hex(0x333c4e, 0.3)
				Pen.rect(c, racks[ri] + 2.5, 342.5 + reihe * 3.2, 1.6, 1.2, col)
				Pen.rect(c, racks[ri] + 6.5, 342.5 + reihe * 3.2, 1.6, 1.2, col)
		# --- Schritt 4: Die Akte bekommt ihren Eintrag ---
		Pen.rect(c, 400, 342, 9, 11, Pen.hex(0xeef2f8, 0.92))
		for i in 3:
			Pen.rect(c, 401.2, 344 + i * 2.2, 6.6, 0.8, Pen.hex(0x9aa6bc, 0.8))
		var schreiben := clampf((u - 16.4) / 1.8, 0, 1)
		if schreiben > 0:
			Pen.rect(c, 401.2, 350.6, 6.6 * schreiben, 0.9, Pen.hex(0x2fa88c, 0.95))
			if schreiben < 1 and sin(t * 10) > 0:
				Pen.rect(c, 401.2 + 6.6 * schreiben + 0.4, 350.2, 0.8, 1.6, Pen.hex(0x2fa88c, 0.95))
		if u >= 18.6 and u < 19.6:
			Pen.scircle(c, 404.5, 347.5, 3 + 5 * (u - 18.6), Pen.hex(0x7fd07f, 0.9 * (1 - (u - 18.6))), 0.8)
		# --- Schritt 5: Abruf ---
		var pulse: Array = []
		if u >= 20 and u < 23:
			var k := (u - 20) / 3
			pulse.append(Vector2(399 + (473 - 399) * (k / 0.6), NETZ_Y) if k < 0.6 else Vector2(473, NETZ_Y - (NETZ_Y - 313) * ((k - 0.6) / 0.4)))
		if u >= 21 and u < 24.6:
			var k := (u - 21) / 3.6
			pulse.append(Vector2(399 - (399 - 262) * (k / 0.7), NETZ_Y) if k < 0.7 else Vector2(262, NETZ_Y - (NETZ_Y - 293) * ((k - 0.7) / 0.3)))
		if u >= 21.8 and u < 24.4:
			var k := (u - 21.8) / 2.6
			pulse.append(Vector2(399 - (399 - 348) * (k / 0.55), NETZ_Y) if k < 0.55 else Vector2(348, NETZ_Y - (NETZ_Y - 313) * ((k - 0.55) / 0.45)))
		for p in pulse:
			Pen.circle(c, p.x, p.y, 2.6, Pen.alpha(K, 0.2))
			Pen.scircle(c, p.x, p.y, 1.9, Pen.alpha(K, 0.9), 0.7)
			Pen.circle(c, p.x, p.y, 0.8, Color(1, 1, 1, 0.95))
		var abklang := clampf(28.5 - u, 0, 1) if u > 27.5 else 1.0
		_handy_mensch(c, 470, Pen.P_BESUCH, u >= 23 and u < 28.5, u - 23, abklang)
		_handy_mensch(c, 345, Pen.P_GRUEN, u >= 24.4 and u < 28.5, u - 24.4, abklang)
		# Facharzt: dieselben Zeilen auf seinem Monitor
		Pen.sitzend(c, 250, 302, Pen.P_AERZTIN)
		if u >= 24.6 and u < 28.5:
			Pen.circle(c, 262, 291, 7, Pen.alpha(K, 0.1 * abklang))
			var lesen := clampf((u - 24.6) / 1.2, 0, 1)
			var bl := 1 - (u - 27.5) if u > 27.5 else 1.0
			for i in 3:
				var zeile := clampf(lesen * 3 - i, 0, 1)
				if zeile > 0:
					Pen.rect(c, 259, 288.3 + i * 1.8, 6 * zeile, 0.8, Pen.hex(0x8fd6c8, 0.85 * bl))
			if lesen >= 1:
				Pen.rect(c, 259, 288.3 + 3 * 1.8, 6, 0.8, Pen.hex(0x2fa88c, 0.9 * bl))
		# Hintergrundleben
		var s1 := Pen.pendel(t, 310, 620, 11, 20)
		Pen.figur(c, s1[0], BODEN, Pen.P_OMA, t * 0.8, s1[1])
		Pen.figur(c, KL.tuer + 22, BODEN, Pen.P_BOTE, 0, -1)
		Pen.rect(c, KL.tuer + 17.5, BODEN - 7.8, 1.8, 2.2, Pen.hex(0xd8e0f0, 0.95))

	# Phasen-Stimmung: warmer bzw. kühler Schleier
	Pen.rect(c, 0, 0, W, H, Pen.hex(0xc08a4a, 0.07) if phase == 1 else Pen.hex(0x4de3ff, 0.04))


func _orb_pos(u: float) -> Vector2:
	if u < 7.2:
		return Vector2.INF
	if u < 8:
		var k := (u - 7.2) / 0.8
		return Vector2(61 + 12.5 * k, 291 - 16.5 * k)
	if u < 9.6:
		return Vector2(73.5, 274.5)
	if u < 10.6:
		return Vector2(73.5, 274.5 + (NETZ_Y - 274.5) * (u - 9.6))
	if u < 12.2:
		return Vector2(73.5 + (310 - 73.5) * ((u - 10.6) / 1.6), NETZ_Y)
	if u < 13.2:
		return Vector2(310, NETZ_Y - 1.5)
	if u < 14.4:
		return Vector2(310 + (399 - 310) * ((u - 13.2) / 1.2), NETZ_Y)
	if u < 15.4:
		return Vector2(399, NETZ_Y - 4 * (u - 14.4))
	if u < 18.6:
		return Vector2(399, 347)
	return Vector2.INF


func _handy_mensch(c: CanvasItem, fx: float, p: Dictionary, an: bool, seit: float, abklang: float) -> void:
	var K := Pen.K
	Pen.figur(c, fx, BODEN, p, 0, 1)
	if an:
		Pen.circle(c, fx + 3.8, BODEN - 6.3, 4, Pen.alpha(K, 0.22 * abklang))
	Pen.rect(c, fx + 3, BODEN - 7.6, 1.6, 2.6, Pen.alpha(K, 0.95 if an else 0.35))
	if an:
		var k := fmod(fmod(seit, 1.6) + 1.6, 1.6) / 1.6
		Pen.scircle(c, fx + 3.8, BODEN - 6.4, 2 + 5 * k, Pen.alpha(K, 0.7 * (1 - k) * abklang), 0.6)
		# Benachrichtigungs-Karte über dem Kopf
		var pop := clampf(seit / 0.35, 0, 1)
		var oy := BODEN - 22 - 4 * pop
		var x := fx + 3.8
		Pen.rrect(c, x - 4.5, oy, 10, 8.5, 1.2, Pen.hex(0xeef2f8, 0.95 * abklang))
		Pen.tri(c, x - 0.5, oy + 8.5, x + 1.8, oy + 8.5, x + 0.6, oy + 10.2, Pen.hex(0xeef2f8, 0.95 * abklang))
		Pen.rect(c, x - 3, oy + 1.6, 7, 1.1, Pen.hex(0x2fa88c, 0.95 * abklang))
		Pen.rect(c, x - 3, oy + 3.6, 7, 1, Pen.hex(0x9aa6bc, 0.85 * abklang))
		Pen.rect(c, x - 3, oy + 5.6, 4.6, 1, Pen.hex(0x9aa6bc, 0.85 * abklang))


# ================================================================ Probelauf

func _build_tutorial() -> void:
	header("SO SPIELST DU", "Ein kurzer Probelauf — gleich bist du dran.")
	# Popups mit Tastenkappen — Beschriftung je nach Hardware
	var lauf: Array
	var sprung: Array
	var aktion: Array
	var lauf_hint: String
	if Kiosk.touch_seen or Kiosk.touch_forced:
		lauf = ["KNÜPPEL"]
		sprung = ["SPRUNG"]
		aktion = ["HÜLLE"]
		lauf_hint = "links am Bildschirm — nach unten: ducken"
	elif Kiosk.has_gamepad():
		lauf = ["JOYSTICK"]
		sprung = ["ROT"]
		aktion = ["HOCH"]
		lauf_hint = "nach unten: ducken"
	else:
		lauf = ["←", "→"]
		sprung = ["LEERTASTE"]
		aktion = ["SHIFT"]
		lauf_hint = "oder A / D — auch am Joystick"
	popups = [
		_popup("LAUFEN", lauf, lauf_hint),
		_popup("SPRINGEN", sprung, "trägt dich über jede Lücke — 2× drücken: REZI-Schub"),
		_popup("DATENBITS", [], "einfach durchlaufen — sie zählen für dein Rezept"),
		_popup("HÜLLE", aktion, "an & aus — verschlüsselt bist du geschützt"),
	]
	# Bühne: echter Grund, echte Grube
	for r in [[0.0, 350.0, 316.0], [390.0, W, 316.0], [140.0, 350.0, 290.0], [390.0, 520.0, 290.0]]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var x0: float = r[0]
		var x1: float = r[1]
		var oben: float = r[2]
		shape.size = Vector2((x1 - x0) * S, (H - oben) * S)
		cs.shape = shape
		cs.position = Vector2((x0 + x1) * 0.5 * S, (oben + H) * 0.5 * S)
		body.add_child(cs)
		add_child(body)
	player = Player.new()
	player.global_position = Vector2(160 * S, FUSS_Y * S)
	player.autopilot = true
	player.huelle_enabled = true
	player.world_bottom = H * S + 60
	player.set_respawn(Vector2(160 * S, FUSS_Y * S))
	add_child(player)
	rezi = Rezi.new()
	add_child(rezi)
	rezi.follow(player)
	rezi.base_energy = 0.7
	player.huelle.changed.connect(func(_from: String, to: String, _reason: String):
		rezi.set_encrypted(to == Huelle.VERSCHLUESSELT))


func _popup(titel: String, tasten: Array, hinweis: String) -> Node2D:
	var p := _Popup.new()
	p.titel = titel
	p.tasten = tasten
	p.hinweis = hinweis
	p.position = Vector2(W / 2 * S, 158 * S)
	p.modulate.a = 0.0
	add_child(p)
	return p


func _tick_tutorial() -> void:
	var td := fmod(tz, RUNDE)
	var px := player.global_position.x / S
	if td < _last_td:
		# Neue Runde: Choreografie zurücksetzen, Paul notfalls an den Start
		_jumped1 = false
		_jumped2 = false
		_bit_taken = false
		_toggles = [false, false, false, false]
		if absf(px - 160) > 40 or player.global_position.y > FUSS_Y * S + 20:
			player.global_position = Vector2(160 * S, FUSS_Y * S)
			player.velocity = Vector2.ZERO
	_last_td = td
	# Popups folgen den Ereignissen: LAUFEN bis zum Absprung, SPRINGEN ab dem
	# Absprung, DATENBITS nach dem Einsammeln, HÜLLE im Stand
	var j1 := _jump_t if _jumped1 else 3.1
	var b1 := maxf(_bit_t if _bit_taken else 4.6, j1 + 1.6)
	var fenster := [[0.4, j1], [j1, j1 + 1.6], [b1, b1 + 1.6], [6.2, 9.4]]
	for i in popups.size():
		popups[i].modulate.a = Pen.blende(td, fenster[i][0], fenster[i][1], 0.4)
	if td < 1.0:
		player.auto_axis = 0.0
	elif td < 9.4:
		if not _jumped1:
			player.auto_axis = LAUF
			if px >= 330:
				player.auto_jump = true
				_jumped1 = true
				_jump_t = td
		else:
			player.auto_axis = LAUF if px < 470 else 0.0
		if not _bit_taken and px >= 447:
			_bit_taken = true
			_bit_t = td
			Sfx.play("collect")
			rezi.happy()
		for i in TOGGLE_ZEITEN.size():
			if td >= TOGGLE_ZEITEN[i] and not _toggles[i]:
				_toggles[i] = true
				player.try_toggle_huelle()
	elif td < 12.6:
		if not _jumped2:
			player.auto_axis = -LAUF
			if px <= 410:
				player.auto_jump = true
				_jumped2 = true
				_jump_t = td
		else:
			player.auto_axis = -LAUF if px > 160 else 0.0
	else:
		player.auto_axis = 0.0
	# Sprungtaste nach dem Absprung 0,3 s halten → volle Sprunghöhe
	player.auto_jump_held = _jump_t >= 0.0 and td >= _jump_t and td < _jump_t + 0.3
	if player.huelle.state != Huelle.KLARTEXT and (td < 6.6 or td >= 9.4):
		player.try_toggle_huelle()


func _draw_tutorial_static(c: CanvasItem) -> void:
	var sky_top: Color = theme["sky_top"]
	var fog: Color = theme["fog"]
	var detail: Color = theme["detail"]
	var fels := Pen.darken(sky_top, 0.5)
	var silhouette := Pen.mix(Pen.darken(sky_top, 0.2), fog, 0.5)
	var sil_fenster := Pen.mix(Pen.hex(0xffd9a0), fog, 0.65)
	for s in [[24.0, 66.0, 196.0], [118.0, 48.0, 222.0], [400.0, 56.0, 210.0], [488.0, 70.0, 188.0], [586.0, 44.0, 216.0]]:
		var sx: float = s[0]
		var sb: float = s[1]
		var sdach: float = s[2]
		Pen.rect(c, sx, sdach, sb, 316 - sdach, silhouette)
		Pen.rect(c, sx + 6, sdach - 7, 9, 7, silhouette)
		var fy := sdach + 10
		while fy < 300:
			var fx := sx + 7
			while fx < sx + sb - 8:
				if int(round(fx * 5 + fy * 11)) % 7 < 2:
					Pen.rect(c, fx, fy, 4.5, 6, Pen.alpha(sil_fenster, 0.45))
				fx += 14
			fy += 20
	for r in [[0.0, 350.0, 316.0], [390.0, W, 316.0], [140.0, 350.0, 290.0], [390.0, 520.0, 290.0]]:
		var x0: float = r[0]
		var x1: float = r[1]
		var oben: float = r[2]
		Pen.rect(c, x0, oben, x1 - x0, 360 - oben, fels)
		Pen.rect(c, x0 + 1, oben, x1 - x0 - 2, 1.4, detail)
		Pen.rect(c, x0 + 1, oben, x1 - x0 - 2, 0.5, Color(1, 1, 1, 0.5))
		var kx := x0 + 6
		while kx < x1 - 8:
			Pen.rect(c, kx, oben + 8, 10, 1, Pen.darken(sky_top, 0.62))
			kx += 26
	Pen.rect(c, 350, 316, 40, 44, Pen.hex(0x040810, 0.9))
	for lx in [96.0, 560.0]:
		Pen.rect(c, lx, 278, 1.6, 38, Pen.hex(0x39445e))
		Pen.rect(c, lx - 1, 277.4, 3.6, 1, Pen.hex(0x39445e))
		Pen.rect(c, lx - 1.4, 274, 4.4, 3.6, Pen.hex(0xffd9a0, 0.95))
		Pen.ellipse(c, lx + 1, 317, 58, 6, Pen.hex(0xffd9a0, 0.055))
		Pen.ellipse(c, lx + 1, 317, 34, 4, Pen.hex(0xffd9a0, 0.09))


func _draw_tutorial_life(c: CanvasItem) -> void:
	var K := Pen.K
	var td := fmod(tz, RUNDE)
	# Datenbit auf Podest B — wird im Vorbeilaufen eingesammelt
	if not _bit_taken:
		var puls := 4.5 + sin(t * 2.4) * 0.5
		Pen.circle(c, 450, 268, 7, Pen.alpha(K, 0.16))
		Pen.scircle(c, 450, 268, 3.4, Pen.alpha(K, 0.95), 1.0)
		Pen.scircle(c, 450, 268, puls, Pen.alpha(K, 0.4), 0.5)
		Pen.circle(c, 450, 268, 1.4, Color.WHITE)
	elif td < _bit_t + 0.55:
		var k := (td - _bit_t) / 0.55
		Pen.scircle(c, 450, 268, 4 + 10 * k, Pen.alpha(K, 0.9 * (1 - k)), 0.8)
		for i in 4:
			var a := (i / 4.0) * TAU + 0.6
			Pen.circle(c, 450 + cos(a) * 9 * k, 268 + sin(a) * 7 * k, 1, Color(1, 1, 1, 0.9 * (1 - k)))


class _Popup extends Node2D:
	var titel := ""
	var tasten: Array = []
	var hinweis := ""
	const S := 3.0

	func _ready() -> void:
		var hoehe := 62.0 if tasten.size() > 0 else 46.0
		_lbl(0, -hoehe / 2 + 2, titel, 11, Pen.hex(0xffd75e), 1.4, true)
		if tasten.size() > 0:
			var breiten: Array = []
			var gesamt := 0.0
			for tst in tasten:
				var b: float = 12 + str(tst).length() * 5.2 if str(tst).length() > 2 else 16.0
				breiten.append(b)
				gesamt += b
			gesamt += (tasten.size() - 1) * 6
			var x := -gesamt / 2
			for i in tasten.size():
				_lbl(x + breiten[i] / 2, -0.5, str(tasten[i]), 8, Pen.hex(0x16233a), 0.4, true)
				x += breiten[i] + 6
			_lbl(0, 14.5, hinweis, 8, Pen.hex(0xb8c6e0), 0.0, false)
		else:
			_lbl(0, 1, hinweis, 9, Pen.hex(0xb8c6e0), 0.0, false)

	func _lbl(x: float, y: float, text: String, size: float, color: Color, spacing: float, bold: bool) -> void:
		var l := Label.new()
		l.text = text
		var ls := LabelSettings.new()
		ls.font = Vignette.font(bold, spacing)
		ls.font_size = roundi(size * S)
		ls.font_color = color
		l.label_settings = ls
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		l.reset_size()
		l.position = (Vector2(x, y) * S - l.size * 0.5).round()

	func _draw() -> void:
		var hoehe := 62.0 if tasten.size() > 0 else 46.0
		Pen.rrect(self, -130 * S, (-hoehe / 2 - 8) * S, 260 * S, hoehe * S, 7 * S, Pen.hex(0x060d16, 0.78))
		Pen.srrect(self, -130 * S, (-hoehe / 2 - 8) * S, 260 * S, hoehe * S, 7 * S, Color(1, 1, 1, 0.16), 2.4)
		Pen.rect(self, -124 * S, (-hoehe / 2 - 7.6) * S, 248 * S, 0.6 * S, Color(1, 1, 1, 0.2))
		if tasten.size() > 0:
			var gesamt := 0.0
			var breiten: Array = []
			for tst in tasten:
				var b: float = 12 + str(tst).length() * 5.2 if str(tst).length() > 2 else 16.0
				breiten.append(b)
				gesamt += b
			gesamt += (tasten.size() - 1) * 6
			var x := -gesamt / 2
			for i in tasten.size():
				Pen.rrect(self, x * S, -6 * S, breiten[i] * S, 15 * S, 3 * S, Pen.hex(0x1b2438, 0.9))
				Pen.rrect(self, x * S, -7.5 * S, breiten[i] * S, 14 * S, 3 * S, Pen.hex(0xdfe6f0, 0.95))
				x += breiten[i] + 6
