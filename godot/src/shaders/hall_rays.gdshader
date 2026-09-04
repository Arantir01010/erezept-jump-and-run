shader_type canvas_item;
render_mode blend_mix, unshaded;
// LAMPENBÜNDEL IN EINER HELLEN HALLE (Rechenzentrum). Additives Licht ist auf
// fast weißer Hallenluft unsichtbar — Lichtschächte entstehen hier über den
// Kontrast: die Lücken zwischen den Bündeln werden hauchdünn kühl abgedunkelt
// (gap_dark), die Bündel selbst minimal in Lampenfarbe aufgehellt (strength).
// Nichts glüht, nichts überschreitet 1,0. Periodisch alle `lamp_gap` Pixel,
// nach unten breiter, Richtung Boden ausgeblendet; feine Streifen treiben
// langsam (TIME), das Ganze atmet mit ~0,05 Hz.

uniform vec2 rect_origin = vec2(-200.0, -200.0);
uniform vec2 rect_size = vec2(6000.0, 1500.0);
uniform vec4 lamp_color : source_color = vec4(0.85, 0.96, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.15, 0.19, 0.23, 1.0);
uniform float strength : hint_range(0.0, 0.5) = 0.10;
uniform float gap_dark : hint_range(0.0, 0.3) = 0.075;
uniform float speed = 0.04;
uniform float ground_y = 960.0;
uniform float lamp_gap = 640.0;
uniform float lamp_width = 150.0;

float hash1(float n) {
	return fract(sin(n) * 43758.5453123);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), f);
}

void fragment() {
	vec2 p = rect_origin + UV * rect_size;
	float depth = clamp((p.y - rect_origin.y) / max(ground_y - rect_origin.y, 1.0), 0.0, 1.0);
	float lx = mod(p.x + lamp_gap * 0.5, lamp_gap) - lamp_gap * 0.5;
	float w = lamp_width * (0.55 + depth * 0.95);
	float beam = 1.0 - smoothstep(0.0, w, abs(lx));
	beam *= beam;
	float s1 = noise1(p.x * 0.045 + TIME * speed * 3.0);
	float s2 = noise1(p.x * 0.012 - TIME * speed * 1.3 + 3.0);
	float ray = beam * (0.6 + 0.4 * (s1 * 0.5 + s2 * 0.5));
	float below = 1.0 - smoothstep(ground_y - 260.0, ground_y + 40.0, p.y);
	float breath = 0.88 + 0.12 * sin(TIME * 0.33);
	float fade = below * breath * (1.0 - depth * 0.55);
	float a_light = ray * strength * fade;
	float a_dark = (1.0 - beam) * gap_dark * fade;
	COLOR = vec4(mix(shade_color.rgb, lamp_color.rgb, ray), mix(a_dark, a_light, ray));
}
