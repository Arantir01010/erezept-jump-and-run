class_name Wissen
extends Vignette
## WISSEN — animierte Lehrsequenzen zur „ePA für alle" VOR den vier ePA-Stationen
## (Port von src/gfx/wissen.ts). Erst verstehen, dann spielen.
##
## Fachliche Quellen (Stand 2025/2026, siehe docs/EPA-WISSENSPFAD.md):
##  - ePA für alle: Opt-out seit 15.01.2025; Widerspruch jederzeit, dann löscht
##    die Kasse die Akte vollständig.
##  - Die Akte liegt im Aktensystem (Rechenzentrum), NICHT auf der eGK —
##    die Karte ist Schlüssel, kein Speicher.
##  - Befugnis durch Kartenstecken: Praxis/Klinik 90 Tage, Apotheke 3 Tage —
##    in der ePA-App änderbar oder entziehbar.
##  - Medikationsliste: E-Rezept-Daten fließen automatisch ein — die EINZIGE
##    Automatik der ePA.
##  - Zugriffsprotokoll: jeder Zugriff wird erfasst, drei Jahre einsehbar;
##    Dokumente lassen sich verbergen/löschen, ohne dass Praxen das Fehlen sehen.

const VOR_LEVEL := {
	"13-e-rezept": "epa-konto",
	"14-die-vau": "epa-medikation",
	"19-berechtigungen": "epa-befugnis",
	"20-souveraenitaet": "epa-souveraen",
}
const SPERRE := {"epa-konto": 13.0, "epa-medikation": 13.0, "epa-befugnis": 15.0, "epa-souveraen": 15.0}
const TEIL := {"epa-konto": 1, "epa-medikation": 2, "epa-befugnis": 3, "epa-souveraen": 4}
const DATEN := {
	"epa-konto": {
		"titel": "DEINE AKTE", "untertitel": "Die ePA für alle — seit 2025 hat sie jeder. Außer, du willst nicht.", "zyklus": 20.0,
		"zeilen": [
			[0.4, 5.0, "Die Krankenkasse legt für jeden automatisch eine ePA an — die „ePA für alle“."],
			[5.0, 10.0, "Wer nicht will, widerspricht einfach — dann gibt es keine Akte. Deine Wahl."],
			[10.0, 15.0, "Die Akte liegt geschützt im Rechenzentrum — NICHT auf deiner Karte."],
			[15.0, 19.5, "Die eGK ist nur der Schlüssel dazu. Gleich holst du dein E-Rezept — es landet genau hier."],
		]},
	"epa-medikation": {
		"titel": "DIE MEDIKATIONSLISTE", "untertitel": "Ein Teil der Akte führt sich von selbst.", "zyklus": 20.0,
		"zeilen": [
			[0.4, 5.0, "In der Apotheke löst du dein E-Rezept ein — wie eben im Spiel."],
			[5.0, 10.0, "Der Eintrag wandert AUTOMATISCH in deine Medikationsliste. Die einzige Automatik der ePA."],
			[10.0, 15.0, "Die nächste Ärztin sieht sofort, was du nimmst — und erkennt Wechselwirkungen."],
			[15.0, 19.5, "Alles andere stellt nur ein, wer dich behandelt. Nichts lädt heimlich hoch."],
		]},
	"epa-befugnis": {
		"titel": "BEFUGNIS AUF ZEIT", "untertitel": "Deine Karte öffnet Türen — aber nie für immer.", "zyklus": 22.0,
		"zeilen": [
			[0.4, 5.5, "Karte gesteckt = Befugnis erteilt: Die Praxis darf 90 Tage in deine Akte."],
			[5.5, 10.5, "Die Apotheke bekommt standardmäßig nur 3 Tage — keine Dauerkarte."],
			[10.5, 16.0, "In der ePA-App regelst du alles: verlängern, verkürzen — oder sofort entziehen."],
			[16.0, 21.5, "Ohne Befugnis bleibt jede Tür zu. Genau das spielst du in dieser Station."],
		]},
	"epa-souveraen": {
		"titel": "DEINE REGELN", "untertitel": "Die ganze Architektur hat ein Ziel: Du behältst die Kontrolle.", "zyklus": 22.0,
		"zeilen": [
			[0.4, 5.5, "Jeder Zugriff hinterlässt eine Spur: dein Protokoll, drei Jahre einsehbar."],
			[5.5, 11.0, "Einzelne Dokumente kannst du verbergen oder löschen — niemand sieht, DASS etwas fehlt."],
			[11.0, 16.5, "Und ganz grundsätzlich: Widerspruch genügt — die Kasse löscht die Akte vollständig."],
			[16.5, 21.5, "Zum Finale: Die letzte Tür öffnet nicht der Held — sondern die, der die Akte gehört."],
		]},
}

var id := "epa-konto"


func _init(wid := "epa-konto") -> void:
	id = wid if DATEN.has(wid) else "epa-konto"
	sperre = float(SPERRE[id])
	weiter_text = tr("%s: Weiter!") % Kiosk.label_confirm()
	dots = [false, false, false, false]
	dots[int(TEIL[id]) - 1] = true


func _build() -> void:
	var v: Dictionary = DATEN[id]
	label(W / 2, 22, tr("ePA-WISSEN · TEIL %d / 4") % int(TEIL[id]), 5.5,
		{"color": Pen.hex(0xffd591), "spacing": 1.6, "stroke": Pen.hex(0x0a1730), "stroke_w": 1.0})
	header(str(v["titel"]), str(v["untertitel"]))
	story_cycle = float(v["zyklus"])
	for z in v["zeilen"]:
		story_line(str(z[2]), float(z[0]), float(z[1]))
	match id:
		"epa-konto":
			_haus_label(100, 300, 96, "KRANKENKASSE")
			label(518, 232, "AKTENSYSTEM", 5.5, {"color": Pen.hex(0x4de3ff), "spacing": 1.0})
			label(518, 308, "im gesicherten Rechenzentrum", 5, {"color": Pen.hex(0x9fb0cc), "bold": false})
		"epa-medikation":
			_haus_label(96, 300, 84, "APOTHEKE", Pen.hex(0xffd75e))
			_haus_label(540, 300, 84, "PRAXIS")
			label(320, 226, "MEDIKATIONSLISTE", 5, {"color": Pen.hex(0x4de3ff), "spacing": 0.6})
		"epa-befugnis":
			_haus_label(96, 300, 80, "PRAXIS")
			_haus_label(544, 300, 80, "APOTHEKE", Pen.hex(0xffd75e))
		"epa-souveraen":
			label(131, 222, "ZUGRIFFSPROTOKOLL", 5, {"color": Pen.hex(0x4de3ff), "spacing": 0.6})
			label(322, 220, "DEINE ePA", 5.5, {"color": Pen.hex(0x4de3ff), "spacing": 1.0})


func _haus_label(x: float, y: float, h: float, text: String, farbe := Color(0.875, 0.902, 0.941)) -> void:
	label(x, y - h - 9, text, 5, {"color": farbe, "spacing": 0.8})


# ------------------------------------------------------------ Bau-Vokabular

## ePA-Akte: Karte mit Kreuz und Dokumentzeilen — das wiederkehrende Symbol.
func _akte(c: CanvasItem, x: float, y: float, s := 1.0, a := 1.0) -> void:
	Pen.rrect(c, x - 11 * s, y - 14 * s, 22 * s, 28 * s, 3 * s, Pen.hex(0x0d1a2c, a))
	Pen.srrect(c, x - 11 * s, y - 14 * s, 22 * s, 28 * s, 3 * s, Pen.alpha(Pen.K, 0.85 * a), 1.0)
	Pen.rect(c, x - 1.4 * s, y - 10 * s, 2.8 * s, 7 * s, Pen.hex(0x2fa88c, 0.95 * a))
	Pen.rect(c, x - 3.5 * s, y - 7.9 * s, 7 * s, 2.8 * s, Pen.hex(0x2fa88c, 0.95 * a))
	for i in 3:
		Pen.rect(c, x - 7 * s, y + 2 * s + i * 3.4 * s, 14 * s, 1.1 * s, Pen.hex(0x9aa6bc, 0.8 * a))


## eGK: die grüne Gesundheitskarte mit Chip — Schlüssel, kein Speicher.
func _karte(c: CanvasItem, x: float, y: float, s := 1.0, a := 1.0) -> void:
	Pen.rrect(c, x - 8 * s, y - 5 * s, 16 * s, 10 * s, 1.6 * s, Pen.hex(0x2c7a52, a))
	Pen.rrect(c, x - 5.5 * s, y - 2.4 * s, 3.6 * s, 4.4 * s, 0.8 * s, Pen.hex(0xffd75e, 0.95 * a))
	Pen.rect(c, x - 8 * s, y - 5 * s, 16 * s, 1 * s, Color(1, 1, 1, 0.2 * a))


## Smartphone mit ePA-App.
func _handy(c: CanvasItem, x: float, y: float, h := 34.0, a := 1.0) -> void:
	var w := h * 0.52
	Pen.rrect(c, x - w / 2, y - h / 2, w, h, 3, Pen.hex(0x0a1220, a))
	Pen.srrect(c, x - w / 2, y - h / 2, w, h, 3, Pen.hex(0x9fb3c8, 0.8 * a), 1.0)
	Pen.rect(c, x - 2.4, y - h / 2 + 1.6, 4.8, 0.9, Pen.hex(0x9fb3c8, 0.7 * a))


## Kleines Gebäude (Kasse, Praxis, Apotheke …) — das Label kommt aus _build.
func _haus(c: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	var sky_top: Color = theme["sky_top"]
	var detail: Color = theme["detail"]
	Pen.rect(c, x - w / 2, y - h, w, h, Pen.darken(sky_top, 0.4))
	Pen.rect(c, x - w / 2 - 2, y - h - 2, w + 4, 2, Pen.alpha(detail, 0.7))
	var fy := y - h + 8
	while fy < y - 12:
		var fx := x - w / 2 + 7
		while fx < x + w / 2 - 8:
			var an := int(round(fx * 7 + fy * 13)) % 4 < 2
			Pen.rect(c, fx, fy, 6, 8, Pen.hex(0xffd9a0, 0.8) if an else Pen.alpha(Pen.darken(theme["sky_bottom"], 0.3), 0.5))
			fx += 13
		fy += 14
	Pen.rect(c, x - 7, y - 16, 14, 16, Pen.hex(0x0d1a2c))


## Zeitschaltuhr-Badge mit ablaufendem Ring.
func _uhr(c: CanvasItem, x: float, y: float, anteil: float, farbe: Color) -> void:
	Pen.circle(c, x, y, 8, Pen.hex(0x0e1a2c, 0.95))
	Pen.scircle(c, x, y, 8, Pen.hex(0x9fb3c8, 0.6), 1.0)
	Pen.arc(c, x, y, 5.6, -PI / 2, -PI / 2 + TAU * maxf(0.02, anteil), Pen.alpha(farbe, 0.95), 2.0)


func _boden(c: CanvasItem) -> void:
	Pen.rect(c, 0, 300, W, 4, Pen.darken(theme["ground"], 0.35))


# ------------------------------------------------------------------- Statik

func _draw_static(c: CanvasItem) -> void:
	var detail: Color = theme["detail"]
	var sky_top: Color = theme["sky_top"]
	match id:
		"epa-konto":
			_haus(c, 100, 300, 84, 96)
			for hx in [238.0, 306.0, 374.0]:
				Pen.rect(c, hx - 20, 262, 40, 38, Pen.darken(sky_top, 0.35))
				Pen.tri(c, hx - 24, 262, hx + 24, 262, hx, 244, Pen.darken(sky_top, 0.35))
				Pen.rect(c, hx - 6, 278, 9, 10, Pen.hex(0xffd9a0, 0.75))
			Pen.rect(c, 452, 224, 132, 76, Pen.hex(0x0a1220))
			Pen.srect(c, 452, 224, 132, 76, Pen.alpha(detail, 0.8), 1.0)
			_boden(c)
		"epa-medikation":
			_haus(c, 96, 300, 88, 84)
			_haus(c, 540, 300, 88, 84)
			Pen.rrect(c, 272, 216, 96, 84, 5, Pen.hex(0x0d1a2c))
			Pen.srrect(c, 272, 216, 96, 84, 5, Pen.alpha(Pen.K, 0.9), 1.2)
			Pen.rect(c, 508, 236, 26, 20, Pen.hex(0x0a1220))
			Pen.srect(c, 508, 236, 26, 20, Pen.hex(0x39445e), 0.8)
			_boden(c)
		"epa-befugnis":
			_haus(c, 96, 300, 84, 80)
			_haus(c, 544, 300, 84, 80)
			_akte(c, 320, 252, 1.4)
			for gx in [268.0, 372.0]:
				Pen.rect(c, gx - 2, 216, 4, 84, Pen.hex(0x39445e))
			for tx in [150.0, 490.0]:
				Pen.rect(c, tx - 8, 272, 16, 28, Pen.hex(0x2f3a52))
				Pen.rect(c, tx - 5.5, 277, 11, 8, Pen.hex(0x0a1220))
				Pen.rect(c, tx - 6, 289, 12, 2.4, Pen.hex(0x1b2438))
			_boden(c)
		"epa-souveraen":
			Pen.rrect(c, 56, 212, 150, 92, 5, Pen.hex(0x0a1220))
			Pen.srrect(c, 56, 212, 150, 92, 5, Pen.alpha(detail, 0.8), 1.0)
			Pen.rrect(c, 276, 210, 92, 96, 5, Pen.hex(0x0d1a2c))
			Pen.srrect(c, 276, 210, 92, 96, 5, Pen.alpha(Pen.K, 0.9), 1.2)
			_boden(c)


func _draw_glow(c: CanvasItem) -> void:
	match id:
		"epa-konto":
			Pen.glow(c, 518, 262, Pen.K, 26, 0.10)
		"epa-medikation":
			Pen.glow(c, 320, 258, Pen.K, 30, 0.10)
		"epa-befugnis":
			Pen.glow(c, 320, 252, Pen.K, 26, 0.12)
		"epa-souveraen":
			Pen.glow(c, 322, 256, Pen.K, 30, 0.10)


# -------------------------------------------------------------------- Leben

func _draw_life(c: CanvasItem) -> void:
	var v: Dictionary = DATEN[id]
	var u := fmod(tz, float(v["zyklus"]))
	match id:
		"epa-konto":
			_leben_konto(c, u)
		"epa-medikation":
			_leben_medikation(c, u)
		"epa-befugnis":
			_leben_befugnis(c, u)
		"epa-souveraen":
			_leben_souveraen(c, u)


func _leben_konto(c: CanvasItem, u: float) -> void:
	# Briefe fliegen von der Kasse zu den Häusern
	var haeuser := [238.0, 306.0, 374.0]
	for i in 3:
		var k := clampf((u - 0.8 - i * 0.7) / 2, 0, 1)
		if k > 0 and k < 1:
			var bx: float = 130 + (haeuser[i] - 130) * k
			var by := 250 - sin(k * PI) * 34
			Pen.rect(c, bx - 3.6, by - 2.4, 7.2, 4.8, Pen.hex(0xeef2f8, 0.95))
			Pen.srect(c, bx - 3.6, by - 2.4, 7.2, 4.8, Pen.hex(0x9aa6bc, 0.9), 0.5)
	# Haus 2 widerspricht
	var wider := Pen.blende(u, 5.5, 10)
	if wider > 0:
		Pen.rrect(c, 292, 216, 30, 13, 3, Pen.hex(0xeef2f8, 0.95 * wider))
		Pen.tri(c, 303, 229, 309, 229, 305, 234, Pen.hex(0xeef2f8, 0.95 * wider))
		Pen.rect(c, 297, 220, 20, 1.6, Pen.hex(0xb3403e, 0.95 * wider))
		Pen.rect(c, 297, 224, 14, 1.6, Pen.hex(0xb3403e, 0.95 * wider))
	# Konten-Slots: 1 und 3 füllen sich, Slot 2 bleibt bewusst leer
	var slots := [478.0, 518.0, 558.0]
	for i in 3:
		var da := i != 1
		var auf := clampf((u - 2.6 - i * 0.5) / 1.2, 0, 1) if da else 0.0
		if auf > 0:
			_akte(c, slots[i], 268, 0.9, auf)
		else:
			Pen.srrect(c, slots[i] - 10, 255, 20, 26, 3, Pen.hex(0x39445e, 0.8), 0.7)
			if i == 1 and u > 7:
				var a := 0.5 * Pen.blende(u, 7, 19)
				Pen.line(c, slots[i] - 5, 262, slots[i] + 5, 274, Pen.hex(0xb3403e, a), 1.0)
				Pen.line(c, slots[i] + 5, 262, slots[i] - 5, 274, Pen.hex(0xb3403e, a), 1.0)
	# Die eGK reist vom Haus zum Konto — und bleibt Schlüssel
	var reise := clampf((u - 10.5) / 3, 0, 1)
	if reise > 0:
		var kx := 238 + (478 - 238) * reise
		var ky := 282 - sin(reise * PI) * 40
		_karte(c, kx, ky, 1)
		if reise >= 1:
			Pen.scircle(c, 478, 268, 15 * (1 + sin(t * 3) * 0.1), Pen.hex(0xffd75e, 0.9), 1.0)


func _leben_medikation(c: CanvasItem, u: float) -> void:
	var K := Pen.K
	var ankunft := clampf(u / 2.4, 0, 1)
	if ankunft < 1:
		var ox := -12 + (96 + 12) * ankunft
		Pen.circle(c, ox, 262, 4, Pen.alpha(Pen.WARM, 0.35))
		Pen.circle(c, ox, 262, 1.4, Color(1, 1, 1, 0.95))
	elif u < 5:
		var px := 104 + sin(t * 2) * 1.5
		Pen.rrect(c, px, 270, 7, 3.4, 1.6, Pen.hex(0xeef2f8, 0.95))
		Pen.rect(c, px, 270, 3.5, 3.4, Pen.hex(0xb3403e, 0.9))
	var flug := clampf((u - 5.2) / 1.8, 0, 1)
	if flug > 0 and flug < 1:
		var fx := 120 + (300 - 120) * flug
		var fy := 268 - sin(flug * PI) * 30
		Pen.circle(c, fx, fy, 3.4, Pen.alpha(K, 0.25))
		Pen.circle(c, fx, fy, 1.1, Color(1, 1, 1, 0.95))
	for i in 3:
		var voll := 1.0 if i < 2 else clampf((u - 7) / 1.4, 0, 1)
		if voll <= 0:
			continue
		Pen.rect(c, 282, 240 + i * 12, 66 * voll, 2.4, Pen.hex(0x2fa88c, 0.95) if i == 2 else Pen.hex(0x9aa6bc, 0.75))
		if i == 2 and voll < 1 and sin(t * 10) > 0:
			Pen.rect(c, 282 + 66 * voll + 1, 238.8, 1.4, 5, Pen.hex(0x2fa88c, 0.95))
	var lesen := clampf((u - 10.5) / 1.4, 0, 1)
	if lesen > 0:
		for i in 3:
			var voll := clampf(lesen * 3 - i, 0, 1)
			if voll > 0:
				Pen.rect(c, 511, 240 + i * 4.4, 20 * voll, 1.6, Pen.hex(0x8fd6c8, 0.85))
		if u > 12.4 and u < 14.6:
			Pen.srect(c, 509.5, 243.2, 23, 5.6, Pen.hex(0xffb347, 0.95 if sin(t * 2.6) > 0 else 0.35), 1.0)
		if u >= 14.6:
			Pen.polyline(c, PackedVector2Array([Vector2(512, 250), Vector2(515, 253), Vector2(521, 245)]), Pen.hex(0x7fd07f, 0.95), 1.2)


func _leben_befugnis(c: CanvasItem, u: float) -> void:
	var torL := clampf((u - 1.5) / 1, 0, 1)
	var zu := clampf((u - 13) / 0.8, 0, 1)
	var torR := clampf((u - 6) / 1, 0, 1) * (1 - zu)
	for g in [[268.0, torL], [372.0, torR]]:
		var gx: float = g[0]
		var offen: float = 40 * g[1]
		Pen.rect(c, gx - 1.4, 216, 2.8, maxf(2, 42 - offen), Pen.hex(0x7fe8ff, 0.85))
		Pen.rect(c, gx - 1.4, 258 + offen, 2.8, maxf(2, 42 - offen), Pen.hex(0x7fe8ff, 0.85))
	var steckL := clampf(u / 1.4, 0, 1)
	if steckL > 0:
		_karte(c, 150, 291 - 6 * (1 - steckL), 0.8)
	var steckR := clampf((u - 5) / 1.4, 0, 1)
	if steckR > 0 and zu < 1:
		_karte(c, 490, 291 - 6 * (1 - steckR), 0.8, 1 - zu)
	if u > 2.2:
		_uhr(c, 150, 250, 1 - fmod(u, 22.0) / 60, Pen.hex(0x7fd07f))
	if u > 6.8 and zu < 1:
		_uhr(c, 490, 250, maxf(0, 1 - (u - 6.8) / 7), Pen.hex(0xffb347))
	var app := Pen.blende(u, 11, 16.6)
	if app > 0:
		_handy(c, 430, 200, 38, app)
		Pen.rect(c, 422, 192, 16, 1.8, Pen.hex(0x9aa6bc, 0.85 * app))
		var kipp := clampf((u - 12.2) / 0.8, 0, 1)
		Pen.rrect(c, 422, 198, 16, 6, 3, Pen.hex(0xb3403e if kipp > 0.5 else 0x2fa88c, 0.95 * app))
		Pen.circle(c, 426 + 8 * kipp, 201, 2.4, Pen.hex(0xeef2f8, 0.95 * app))
		if kipp >= 1:
			Pen.scircle(c, 490, 250, 10 + sin(t * 3) * 1, Pen.hex(0xb3403e, 0.9 * app), 0.8)


func _leben_souveraen(c: CanvasItem, u: float) -> void:
	for i in 4:
		var auf := clampf((u - 0.6 - i * 0.9) / 0.5, 0, 1)
		if auf <= 0:
			continue
		Pen.rect(c, 66, 234 + i * 15, (96 if i == 3 else 118) * auf, 2.2, Pen.hex(0x8fd6c8 if i == 3 else 0x9aa6bc, (0.95 if i == 3 else 0.7) * auf))
		Pen.rect(c, 66, 240 + i * 15, 128, 0.8, Pen.hex(0x39445e, 0.8 * auf))
	var verborgen := clampf((u - 6.5) / 1, 0, 1)
	var zerfall := clampf((u - 12.5) / 1.6, 0, 1)
	var wieder := clampf((u - 17.5) / 1.4, 0, 1)
	var akte_da := 1 - zerfall + wieder * zerfall
	for i in 3:
		var a := (1 - verborgen * 0.82 if i == 1 else 1.0) * akte_da
		if a <= 0.02:
			continue
		Pen.rect(c, 288, 232 + i * 22, 68, 15, Pen.hex(0xeef2f8, 0.9 * a))
		Pen.rect(c, 292, 236 + i * 22, 44, 1.6, Pen.hex(0x9aa6bc, 0.75 * a))
		Pen.rect(c, 292, 240 + i * 22, 56, 1.6, Pen.hex(0x9aa6bc, 0.75 * a))
		if i == 1 and verborgen > 0.4 and zerfall < 0.5:
			Pen.srect(c, 288, 232 + i * 22, 68, 15, Pen.hex(0x9fb3c8, 0.7 * akte_da), 0.8)
	var schalter := Pen.blende(u, 11.5, 17)
	if schalter > 0:
		_handy(c, 440, 236, 40, schalter)
		Pen.rect(c, 431, 226, 18, 2, Pen.hex(0x9aa6bc, 0.85 * schalter))
		var kipp := clampf((u - 12.3) / 0.7, 0, 1)
		Pen.rrect(c, 431, 232, 18, 7, 3.4, Pen.hex(0xb3403e if kipp > 0.5 else 0x39445e, 0.95 * schalter))
		Pen.circle(c, 435 + 10 * kipp, 235.5, 2.6, Pen.hex(0xeef2f8, 0.95 * schalter))
	if zerfall > 0 and zerfall < 1 and wieder <= 0:
		for i in 10:
			var a := (i / 10.0) * TAU + i
			Pen.circle(c, 322 + cos(a) * 40 * zerfall, 256 + sin(a) * 34 * zerfall, 1.4, Pen.alpha(Pen.K, 0.7 * (1 - zerfall)))
