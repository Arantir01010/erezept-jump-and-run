class_name Palette
extends RefCounted
## PALETTE — Farbwelten der Godot-Fassung, gegen den „KI-Look" gebaut.
##
## Regeln aus der Recherche (Celeste-Tilesets, Medeiros/Pixel-Parmesan-Farblehre):
##   • pro Welt eine begrenzte Palette: 1 Grundfarbe, 1–2 Akzente (10–20 %), Rest Nebenfarben
##   • Wertehierarchie: Vordergrund dunkel und satt, Kulisse hell und entsättigt (Luftperspektive)
##   • Hue-Shift: Schatten kühler (blau/violett), Lichter wärmer (gelb/orange)
##   • Licht von oben: helle Kappe auf jeder Standfläche, dunkler Fuß, dunkle (nicht schwarze) Kontur
##   • Glühen nur für echte Lichtquellen — nie für Kanten
##
## Fachlich fest (KAPSEL 2.2): warm = offen/sichtbar, kühl = verschlüsselt, violett = VAU.

# Funktionsfarben: Werte aus dem PwC Digital Colour System (Brand.gd).
const WARM := Color("#FF9F00")    # Tangerine 500 — Klartext, offen, sichtbar
const COOL := Color("#356FEC")    # Blue 400 — verschlüsselt (leuchtet mit Faktor 1,5 zu Blue 300 auf)
const VAU := Color("#9470F5")     # Violett — einzige Farbe außerhalb des Farbsystems (KAPSEL 2.2)
const VAU_HELL := Color("#C9BBFA")
const VAU_TIEF := Color("#5B3FB8")
const VAU_NACHT := Color("#2A1F5C")
const DENY := Color("#ED4242")    # Red 400 (Error)
const OK := Color("#18AE80")      # Success 400
const GOLD := Color("#FFC21B")    # Tangerine 400
const WHITE := Color("#F5F7F8")   # Grey 50 (Text Primary)

## Die Welten — jede Farbe ist eine Stufe des PwC-Farbsystems (11/2026).
## Bauprinzip: Grey trägt die Struktur (Gelände, Berge, Nebel), der Himmel kommt
## aus Blue, Orange und Tangerine, der eine Akzent je Welt aus Orange, Tangerine
## oder Blue, Pflanzen aus Success. Die Stimmung (Morgen, Abend, Regen, Halle,
## Archiv) entsteht aus der Stufenwahl und der Farbstimmung im Post-Effekt.
## sun_pos in Bildschirmanteilen (x rechts, y unten), Energie 0–1.
## sun_drift: Verschiebung des Sonnenstands je weiterer Station derselben Welt
## (Morgen: steigt und wandert; Abend: sinkt). grade_*: Farbstimmung im Post-Effekt —
## Tönung (RGB-Faktoren um 1,0) für Schatten/Mitten/Lichter, Kontrast, Sättigung,
## Farbe und Stärke der Vignette. Regel: Schatten kühl, Lichter warm, Paletten bleiben.
const WORLDS := {
	"praxis-morgen": {
		"sky_top": "#A9C8FC", "sky_bottom": "#FFE8D4", "sun": "#FFF4C6", "sun_pos": [0.70, 0.24],
		"far": "#DCE7FD", "mid": "#A9C8FC", "near": "#787E8A",
		"fill": "#4C5056", "fill_dark": "#303236", "cap": "#8E95A2", "cap_light": "#EEEFF1",
		"shadow": "#202124", "outline": "#111113", "accent": "#FE7C39", "detail": "#18AE80",
		"fog": "#F5F7F8", "plant": "#4FD3A1", "plant_dark": "#07966A", "lamp": "#FFD646",
		"sun_drift": [0.06, -0.035],
		"grade_shadows": [0.86, 0.90, 1.04], "grade_mids": [1.0, 1.0, 1.0], "grade_lights": [1.03, 1.0, 0.94],
		"grade_contrast": 1.04, "grade_saturation": 1.06, "grade_vignette": [0.60, 0.66, 0.80], "grade_vignette_strength": 0.30,
		"ambient": "#FFFFFF", "rezi_energy": 0.55, "sun_energy": 0.42, "sun_shadow": 0.22, "weather": "klar",
	},
	"praxis-abend": {
		"sky_top": "#A1A8B3", "sky_bottom": "#FFCDA8", "sun": "#FFE8D4", "sun_pos": [0.2, 0.3],
		"far": "#FFE8D4", "mid": "#8E95A2", "near": "#626771",
		"fill": "#4C5056", "fill_dark": "#303236", "cap": "#787E8A", "cap_light": "#FFE8D4",
		"shadow": "#202124", "outline": "#111113", "accent": "#FF9F00", "detail": "#FE7C39",
		"fog": "#FFE8D4", "plant": "#18AE80", "plant_dark": "#067C59", "lamp": "#FFCDA8",
		"sun_drift": [-0.06, 0.04],
		"grade_shadows": [0.90, 0.86, 1.02], "grade_mids": [1.0, 0.99, 0.98], "grade_lights": [1.05, 0.98, 0.90],
		"grade_contrast": 1.05, "grade_saturation": 1.04, "grade_vignette": [0.62, 0.54, 0.68], "grade_vignette_strength": 0.32,
		"ambient": "#FFF5ED", "rezi_energy": 0.7, "sun_energy": 0.5, "sun_shadow": 0.25, "weather": "klar",
	},
	"netz-regen": {
		"sky_top": "#626771", "sky_bottom": "#B5BCC4", "sun": "#DFE3E6", "sun_pos": [0.5, 0.08],
		"far": "#A1A8B3", "mid": "#787E8A", "near": "#4C5056",
		"fill": "#303236", "fill_dark": "#202124", "cap": "#787E8A", "cap_light": "#CBD1D6",
		"shadow": "#111113", "outline": "#111113", "accent": "#6797FF", "detail": "#A9C8FC",
		"fog": "#CBD1D6", "plant": "#07966A", "plant_dark": "#086B4F", "lamp": "#DCE7FD",
		"sun_drift": [0.06, 0.0],
		"grade_shadows": [0.84, 0.90, 1.05], "grade_mids": [0.97, 1.0, 1.04], "grade_lights": [0.98, 1.0, 1.02],
		"grade_contrast": 1.03, "grade_saturation": 0.96, "grade_vignette": [0.50, 0.56, 0.68], "grade_vignette_strength": 0.42,
		"ambient": "#EEEFF1", "rezi_energy": 0.9, "sun_energy": 0.15, "sun_shadow": 0.12, "weather": "regen",
	},
	"rz-hell": {
		"sky_top": "#DFE3E6", "sky_bottom": "#F5F7F8", "sun": "#FFFFFF", "sun_pos": [0.5, 0.0],
		"far": "#CBD1D6", "mid": "#B5BCC4", "near": "#8E95A2",
		"fill": "#4C5056", "fill_dark": "#303236", "cap": "#787E8A", "cap_light": "#F5F7F8",
		"shadow": "#202124", "outline": "#111113", "accent": "#356FEC", "detail": "#4FD3A1",
		"fog": "#EEEFF1", "plant": "#18AE80", "plant_dark": "#067C59", "lamp": "#DCE7FD",
		"sun_drift": [0.06, 0.0],
		"grade_shadows": [0.90, 0.94, 1.02], "grade_mids": [1.0, 1.0, 1.0], "grade_lights": [1.0, 1.0, 1.0],
		"grade_contrast": 1.03, "grade_saturation": 1.02, "grade_vignette": [0.74, 0.80, 0.88], "grade_vignette_strength": 0.22,
		"ambient": "#FFFFFF", "rezi_energy": 0.5, "sun_energy": 0.32, "sun_shadow": 0.16, "weather": "innen",
	},
	"archiv-abend": {
		"sky_top": "#FFAA72", "sky_bottom": "#FFE8D4", "sun": "#FFF4C6", "sun_pos": [0.15, 0.25],
		"far": "#FFE8D4", "mid": "#8E95A2", "near": "#626771",
		"fill": "#4C5056", "fill_dark": "#303236", "cap": "#8E95A2", "cap_light": "#FFE8D4",
		"shadow": "#202124", "outline": "#111113", "accent": "#FFC21B", "detail": "#FF9F00",
		"fog": "#FFE8D4", "plant": "#18AE80", "plant_dark": "#067C59", "lamp": "#FFD646",
		"sun_drift": [-0.06, 0.04],
		"grade_shadows": [0.92, 0.86, 0.97], "grade_mids": [1.0, 0.99, 0.97], "grade_lights": [1.03, 1.0, 0.93],
		"grade_contrast": 1.05, "grade_saturation": 1.04, "grade_vignette": [0.66, 0.55, 0.50], "grade_vignette_strength": 0.32,
		"ambient": "#FFF5ED", "rezi_energy": 0.75, "sun_energy": 0.45, "sun_shadow": 0.25, "weather": "klar",
	},
}

## themes.json-Name → Welt
const THEME_TO_WORLD := {
	"city": "praxis-morgen", "stammdaten": "praxis-morgen", "praxis": "praxis-morgen",
	"kartenterminal": "praxis-abend", "baustelle": "praxis-abend",
	"kov-gateway": "netz-regen", "zugang": "netz-regen",
	"zentrale-zone": "rz-hell", "akte": "archiv-abend",
}

var world_name := "praxis-morgen"
var sky_top: Color
var sky_bottom: Color
var sun: Color
var sun_pos := Vector2(0.78, 0.18)
var far: Color
var mid: Color
var near: Color
var fill: Color
var fill_dark: Color
var cap: Color
var cap_light: Color
var shadow: Color
var outline: Color
var accent: Color
var detail: Color
var fog: Color
var plant: Color
var plant_dark: Color
var lamp: Color
var ambient: Color
var rezi_energy := 0.6
var sun_energy := 0.4
var sun_shadow := 0.2
var weather := "klar"
var sun_drift := Vector2(0.06, 0.0)
var grade_shadows := Color(0.86, 0.90, 1.02)
var grade_mids := Color(1.0, 1.0, 1.0)
var grade_lights := Color(1.03, 1.0, 0.94)
var grade_contrast := 1.04
var grade_saturation := 1.06
var grade_vignette := Color(0.631, 0.659, 0.702)
var grade_vignette_strength := 0.28
var motiv := "praxis"
var zone_name := ""
var zone_fact := ""

# Kompatibilitätsnamen (Bausteine)
var fels: Color
var fels_edge: Color
var glas: Color
var metall: Color
var signal_color: Color
var ground: Color
var ground_top: Color
var text: Color
var text_dim: Color


static func from_theme(theme: Dictionary, theme_name := "") -> Palette:
	var p := Palette.new()
	var wn: String = THEME_TO_WORLD.get(theme_name, "")
	if wn == "":
		var m := str(theme.get("motiv", "praxis"))
		wn = {"netz": "netz-regen", "rechenzentrum": "rz-hell", "archiv": "archiv-abend"}.get(m, "praxis-morgen")
	p.apply_world(wn)
	p.motiv = str(theme.get("motiv", "praxis"))
	var z: Dictionary = theme.get("zone", {})
	p.zone_name = Game.t(z.get("name", ""))
	p.zone_fact = Game.t(z.get("fakt", ""))
	return p


static func for_world(name: String) -> Palette:
	var p := Palette.new()
	p.apply_world(name)
	return p


func apply_world(name: String) -> void:
	var w: Dictionary = WORLDS.get(name, WORLDS["praxis-morgen"])
	world_name = name
	sky_top = Color.html(w["sky_top"])
	sky_bottom = Color.html(w["sky_bottom"])
	sun = Color.html(w["sun"])
	sun_pos = Vector2(float(w["sun_pos"][0]), float(w["sun_pos"][1]))
	far = Color.html(w["far"])
	mid = Color.html(w["mid"])
	near = Color.html(w["near"])
	fill = Color.html(w["fill"])
	fill_dark = Color.html(w["fill_dark"])
	cap = Color.html(w["cap"])
	cap_light = Color.html(w["cap_light"])
	shadow = Color.html(w["shadow"])
	outline = Color.html(w["outline"])
	accent = Color.html(w["accent"])
	detail = Color.html(w["detail"])
	fog = Color.html(w["fog"])
	plant = Color.html(w["plant"])
	plant_dark = Color.html(w["plant_dark"])
	lamp = Color.html(w["lamp"])
	ambient = Color.html(w["ambient"])
	rezi_energy = float(w["rezi_energy"])
	sun_energy = float(w["sun_energy"])
	sun_shadow = float(w["sun_shadow"])
	weather = str(w["weather"])
	sun_drift = _vec2(w, "sun_drift", sun_drift)
	grade_shadows = _rgb(w, "grade_shadows", grade_shadows)
	grade_mids = _rgb(w, "grade_mids", grade_mids)
	grade_lights = _rgb(w, "grade_lights", grade_lights)
	grade_contrast = float(w.get("grade_contrast", grade_contrast))
	grade_saturation = float(w.get("grade_saturation", grade_saturation))
	grade_vignette = _rgb(w, "grade_vignette", grade_vignette)
	grade_vignette_strength = float(w.get("grade_vignette_strength", grade_vignette_strength))
	fels = fill
	fels_edge = cap_light
	glas = cap_light
	metall = cap
	signal_color = accent
	ground = near
	ground_top = cap
	text = WHITE
	text_dim = Color("#CBD1D6")   # Grey 300 (Text Secondary)


## HDR-Leuchtfarbe: nur für echte Lichtquellen (Prüfsummen, REZI, Lampen, VAU).
static func glow(c: Color, strength := 1.6) -> Color:
	return Color(c.r * strength, c.g * strength, c.b * strength, c.a)


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Hue-Shift-Schatten: dunkler UND kühler (Richtung Blau), leicht entsättigt.
static func shade(c: Color, amount := 0.25) -> Color:
	var h := c.h
	var s := c.s
	var v := c.v
	h = fmod(h + (0.62 - h) * amount * 0.35 + 1.0, 1.0)
	return Color.from_hsv(h, minf(1.0, s * (1.0 + amount * 0.3)), v * (1.0 - amount), c.a)


## Hue-Shift-Licht: heller UND wärmer (Richtung Gelb), leicht entsättigt.
static func tint(c: Color, amount := 0.25) -> Color:
	var h := c.h
	var s := c.s
	var v := c.v
	h = fmod(h + (0.13 - h) * amount * 0.35 + 1.0, 1.0)
	return Color.from_hsv(h, s * (1.0 - amount * 0.5), minf(1.0, v + (1.0 - v) * amount), c.a)


static func _vec2(w: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var v = w.get(key, null)
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


## RGB-Faktoren (dürfen über 1,0 liegen) aus [r, g, b].
static func _rgb(w: Dictionary, key: String, fallback: Color) -> Color:
	var v = w.get(key, null)
	if v is Array and v.size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]))
	return fallback


## Schattenfarbe für die Lichter dieser Welt (Sonne, REZI, Lauscher-Kegel):
## aus pal.shadow, deutlich kühler (Hue-Shift Richtung Blau/Violett) und etwas
## heller als die Kontur, damit die Färbung im Schatten sichtbar bleibt.
## alpha = Schattenstärke des Lichts. Gegenstück: Lichter bleiben warm.
func shadow_for_light(alpha := 0.42) -> Color:
	var c := Palette.shade(shadow, 0.5)
	var s := maxf(c.s, 0.42)
	var v := clampf(c.v * 1.6 + 0.08, 0.14, 0.38)
	var out := Color.from_hsv(c.h, s, v)
	return Color(out.r, out.g, out.b, alpha)
