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

const WARM := Color(1.0, 0.60, 0.22)
const COOL := Color(0.16, 0.74, 0.88)
const VAU := Color(0.58, 0.44, 0.96)
const DENY := Color(0.93, 0.31, 0.26)
const OK := Color(0.30, 0.74, 0.42)
const GOLD := Color(1.0, 0.78, 0.30)
const WHITE := Color(0.98, 0.98, 1.0)

## Die Welten. sun_pos in Bildschirmanteilen (x rechts, y unten), Energie 0–1.
## sun_drift: Verschiebung des Sonnenstands je weiterer Station derselben Welt
## (Morgen: steigt und wandert; Abend: sinkt). grade_*: Farbstimmung im Post-Effekt —
## Tönung (RGB-Faktoren um 1,0) für Schatten/Mitten/Lichter, Kontrast, Sättigung,
## Farbe und Stärke der Vignette. Regel: Schatten kühl, Lichter warm, Paletten bleiben.
const WORLDS := {
	"praxis-morgen": {
		"sky_top": "#8ec1e6", "sky_bottom": "#f3e3cb", "sun": "#fff1c9", "sun_pos": [0.70, 0.24],
		"far": "#c2d3e2", "mid": "#93adc4", "near": "#5c7b95",
		"fill": "#45566b", "fill_dark": "#34435a", "cap": "#7c96a6", "cap_light": "#d9e8ea",
		"shadow": "#2b3547", "outline": "#202b3a", "accent": "#ff9d3b", "detail": "#22b3a3",
		"fog": "#e6edf3", "plant": "#63b56f", "plant_dark": "#3f8f52", "lamp": "#ffd88a",
		"sun_drift": [0.06, -0.035],
		"grade_shadows": [0.86, 0.90, 1.02], "grade_mids": [1.0, 1.0, 1.0], "grade_lights": [1.03, 1.0, 0.94],
		"grade_contrast": 1.04, "grade_saturation": 1.06, "grade_vignette": [0.60, 0.66, 0.80], "grade_vignette_strength": 0.30,
		"ambient": "#ffffff", "rezi_energy": 0.55, "sun_energy": 0.42, "sun_shadow": 0.22, "weather": "klar",
	},
	"praxis-abend": {
		"sky_top": "#7f9ec8", "sky_bottom": "#ffd6a8", "sun": "#ffe0a0", "sun_pos": [0.2, 0.3],
		"far": "#d3b9c4", "mid": "#a58ba0", "near": "#6b5670",
		"fill": "#4a3f52", "fill_dark": "#352c3d", "cap": "#8d7a8a", "cap_light": "#f1d9c6",
		"shadow": "#2c2434", "outline": "#211b28", "accent": "#ffb347", "detail": "#e0705a",
		"fog": "#f3dccb", "plant": "#6fae64", "plant_dark": "#48804a", "lamp": "#ffc97a",
		"sun_drift": [-0.06, 0.04],
		"grade_shadows": [0.88, 0.85, 1.0], "grade_mids": [1.0, 0.99, 0.98], "grade_lights": [1.05, 0.98, 0.90],
		"grade_contrast": 1.05, "grade_saturation": 1.08, "grade_vignette": [0.62, 0.54, 0.68], "grade_vignette_strength": 0.32,
		"ambient": "#fff4ea", "rezi_energy": 0.7, "sun_energy": 0.5, "sun_shadow": 0.25, "weather": "klar",
	},
	"netz-regen": {
		"sky_top": "#5d6f8a", "sky_bottom": "#b0bccb", "sun": "#dfe8f2", "sun_pos": [0.5, 0.08],
		"far": "#9daabb", "mid": "#71829a", "near": "#4a5a72",
		"fill": "#333f52", "fill_dark": "#262f3f", "cap": "#6d8199", "cap_light": "#c5d3df",
		"shadow": "#1f2735", "outline": "#171d29", "accent": "#4fd3ff", "detail": "#86a0c0",
		"fog": "#c9d3de", "plant": "#4f8a70", "plant_dark": "#356650", "lamp": "#cfe6ff",
		"sun_drift": [0.06, 0.0],
		"grade_shadows": [0.84, 0.90, 1.03], "grade_mids": [0.97, 1.0, 1.03], "grade_lights": [0.98, 1.0, 1.02],
		"grade_contrast": 1.03, "grade_saturation": 0.94, "grade_vignette": [0.50, 0.56, 0.68], "grade_vignette_strength": 0.42,
		"ambient": "#e8edf5", "rezi_energy": 0.9, "sun_energy": 0.15, "sun_shadow": 0.12, "weather": "regen",
	},
	"rz-hell": {
		"sky_top": "#dfe8f0", "sky_bottom": "#f6f8fb", "sun": "#ffffff", "sun_pos": [0.5, 0.0],
		"far": "#c9d6e1", "mid": "#a8bccb", "near": "#7f97a8",
		"fill": "#3f4d5c", "fill_dark": "#2f3a47", "cap": "#6e8493", "cap_light": "#e5f2f5",
		"shadow": "#26303b", "outline": "#1c2530", "accent": "#1fb1c9", "detail": "#5fd0ae",
		"fog": "#eef3f7", "plant": "#58b39a", "plant_dark": "#3a8a75", "lamp": "#d8f4ff",
		"sun_drift": [0.06, 0.0],
		"grade_shadows": [0.90, 0.94, 1.0], "grade_mids": [1.0, 1.0, 1.0], "grade_lights": [1.0, 1.0, 1.0],
		"grade_contrast": 1.03, "grade_saturation": 1.02, "grade_vignette": [0.74, 0.80, 0.88], "grade_vignette_strength": 0.22,
		"ambient": "#ffffff", "rezi_energy": 0.5, "sun_energy": 0.32, "sun_shadow": 0.16, "weather": "innen",
	},
	"archiv-abend": {
		"sky_top": "#b98a7a", "sky_bottom": "#f2cfa6", "sun": "#ffd9a3", "sun_pos": [0.15, 0.25],
		"far": "#c9a894", "mid": "#9c7d70", "near": "#5f4a45",
		"fill": "#4a3b3a", "fill_dark": "#37292a", "cap": "#8b7167", "cap_light": "#f0d6b8",
		"shadow": "#2b2021", "outline": "#221a1a", "accent": "#ffb86b", "detail": "#d9a066",
		"fog": "#efd8c1", "plant": "#7fa86a", "plant_dark": "#557a48", "lamp": "#ffcf8c",
		"sun_drift": [-0.06, 0.04],
		"grade_shadows": [0.90, 0.86, 0.97], "grade_mids": [1.0, 0.99, 0.97], "grade_lights": [1.03, 1.0, 0.93],
		"grade_contrast": 1.05, "grade_saturation": 1.06, "grade_vignette": [0.66, 0.55, 0.50], "grade_vignette_strength": 0.32,
		"ambient": "#fff2e6", "rezi_energy": 0.75, "sun_energy": 0.45, "sun_shadow": 0.25, "weather": "klar",
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
var grade_vignette := Color(0.60, 0.66, 0.80)
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
	text_dim = Color(0.80, 0.85, 0.94)


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
