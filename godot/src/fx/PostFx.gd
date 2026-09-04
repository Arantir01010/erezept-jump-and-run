class_name PostFx
extends CanvasLayer
## POST-EFFEKTE — Vollbild-Shader über dem Spielfeld (unter dem HUD).
## Parametrisches Farbgrading je Welt (Palette.grade_*): Tönung getrennt für
## Schatten / Mitten / Lichter nach Malerregel (Schatten kühl, Lichter warm),
## Kontrast, Sättigung und eine farbige Vignette (Ränder dunkler UND kühler,
## nie schwarz). Dazu feines Papierkorn und drei Impulse:
##   aberrate(a)         — chromatische Aberration, klingt ab (Aufprall, Treffer)
##   flash(c, a)         — Farbblitz, klingt ab (Siegel, Treffer, Tor)
##   lightning(c, a, n)  — Gewitterblitz: n Frames hell (Standard 2), dann aus
## Läuft im Compatibility-Renderer: nur Screen-Textur, kein sampler3D.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.28;
uniform vec3 vignette_tint = vec3(0.60, 0.66, 0.80);
uniform float grain = 0.030;
uniform float aberration = 0.0;
uniform vec4 flash_color = vec4(1.0);
uniform float flash = 0.0;
uniform vec4 bolt_color = vec4(0.86, 0.91, 1.0, 1.0);
uniform float bolt = 0.0;
uniform float saturation = 1.06;
uniform float contrast = 1.04;
uniform vec3 shadow_tint = vec3(0.86, 0.90, 1.02);
uniform vec3 mid_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 light_tint = vec3(1.03, 1.0, 0.94);
uniform float grade = 0.8;
uniform float time = 0.0;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float r = length(d);
	vec2 off = d * aberration * 0.016;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	// Drei-Wege-Tönung: Gewichte nach Helligkeit, Summe 1 — Farbwerte bleiben
	float l = luma(col);
	float ws = 1.0 - smoothstep(0.08, 0.50, l);
	float wl = smoothstep(0.50, 0.92, l);
	float wm = max(0.0, 1.0 - ws - wl);
	vec3 tint = shadow_tint * ws + mid_tint * wm + light_tint * wl;
	col *= mix(vec3(1.0), tint, grade);
	// Sättigung und Kontrast um die Bildmitte (0,5), Helligkeit bleibt erhalten
	col = mix(vec3(luma(col)), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	// Farbige Vignette: Ränder dunkler und kühler, nie schwarz
	float v = smoothstep(0.45, 1.05, r * 1.3);
	col *= mix(vec3(1.0), vignette_tint, v * vignette);
	col += (rnd(uv * vec2(1920.0, 1080.0) + vec2(time)) - 0.5) * grain;
	col = mix(col, flash_color.rgb, flash * flash_color.a);
	col = mix(col, bolt_color.rgb, bolt);
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial
var _aberr := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _bolt_frames := 0
var _bolt_amount := 0.0
var _bolt_color := Color(0.86, 0.91, 1.0)
var _t := 0.0


func _ready() -> void:
	layer = 15
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)


func _process(delta: float) -> void:
	_t += delta
	_aberr = move_toward(_aberr, 0.0, delta * 3.2)
	_flash = move_toward(_flash, 0.0, delta * 2.4)
	# Blitz: Frame 1 voll, Frame 2 halb, dann aus — kein Nachleuchten
	var b := 0.0
	if _bolt_frames > 0:
		b = _bolt_amount * (1.0 if _bolt_frames > 1 else 0.5)
		_bolt_frames -= 1
	mat.set_shader_parameter("time", fmod(_t, 100.0))
	mat.set_shader_parameter("aberration", _aberr)
	mat.set_shader_parameter("flash", _flash)
	mat.set_shader_parameter("flash_color", _flash_color)
	mat.set_shader_parameter("bolt", b)
	mat.set_shader_parameter("bolt_color", _bolt_color)


func aberrate(amount: float) -> void:
	_aberr = maxf(_aberr, clampf(amount, 0.0, 1.5))


func flash(color: Color, amount: float) -> void:
	_flash_color = color
	_flash = maxf(_flash, clampf(amount, 0.0, 0.8))


## Gewitterblitz: `frames` Frames hell (Standard 2), Helligkeit moderat (≤ 0,35).
func lightning(color: Color, amount: float, frames := 2) -> void:
	_bolt_color = color
	_bolt_amount = clampf(amount, 0.0, 0.35)
	_bolt_frames = maxi(1, frames)


## Grading an die Welt anpassen (Palette.grade_*: Tönungen, Kontrast, Sättigung, Vignette).
func grade_for(p: Palette) -> void:
	mat.set_shader_parameter("shadow_tint", Vector3(p.grade_shadows.r, p.grade_shadows.g, p.grade_shadows.b))
	mat.set_shader_parameter("mid_tint", Vector3(p.grade_mids.r, p.grade_mids.g, p.grade_mids.b))
	mat.set_shader_parameter("light_tint", Vector3(p.grade_lights.r, p.grade_lights.g, p.grade_lights.b))
	mat.set_shader_parameter("contrast", p.grade_contrast)
	mat.set_shader_parameter("saturation", p.grade_saturation)
	mat.set_shader_parameter("vignette_tint", Vector3(p.grade_vignette.r, p.grade_vignette.g, p.grade_vignette.b))
	mat.set_shader_parameter("vignette", p.grade_vignette_strength)


## Neutrales Grading (Menüs, Karten) — falls ein Screen es braucht.
func grade_neutral() -> void:
	mat.set_shader_parameter("shadow_tint", Vector3(0.86, 0.90, 1.02))
	mat.set_shader_parameter("mid_tint", Vector3(1.0, 1.0, 1.0))
	mat.set_shader_parameter("light_tint", Vector3(1.03, 1.0, 0.94))
	mat.set_shader_parameter("contrast", 1.04)
	mat.set_shader_parameter("saturation", 1.06)
	mat.set_shader_parameter("vignette_tint", Vector3(0.60, 0.66, 0.80))
	mat.set_shader_parameter("vignette", 0.28)
