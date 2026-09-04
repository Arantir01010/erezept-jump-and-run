shader_type canvas_item;
render_mode blend_mix;

// BODENNEBEL — liegt nur nah am Gelände: liest die 2D-SDF, die Godot aus den
// LightOccluder2D-Knoten (sdf_collision) erzeugt. Dichter direkt über Standflächen,
// an Wänden schwach, oben nichts, im Block nichts. Sehr subtil (max_alpha ≤ 0.18).
// Treibt langsam mit der Zeit — reine Funktion von t, kein Zustand.

uniform vec4 fog_color : source_color = vec4(1.0);
uniform float max_alpha : hint_range(0.0, 0.3) = 0.16;
uniform float range_px = 110.0;     // Reichweite über dem Gelände in Screen-Pixeln
uniform float t = 0.0;
uniform float noise_scale = 0.012;

varying vec2 v_world;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world = VERTEX;
}

void fragment() {
	vec2 sp = screen_uv_to_sdf(SCREEN_UV);
	float d = texture_sdf(sp);
	vec2 n = texture_sdf_normal(sp);
	// Liegt Gelände unter dem Pixel? Die SDF-Normale zeigt vom Gelände weg; oben = -y
	float above = clamp(-n.y * 1.3 + 0.15, 0.0, 1.0);
	float inside = 1.0 - smoothstep(-5.0, 2.0, d);     // im Block: kein Nebel
	float near = 1.0 - smoothstep(0.0, range_px, max(d, 0.0));
	near = near * near;
	float drift = vnoise(v_world * noise_scale + vec2(t * 0.06, t * 0.015)) * 0.6
		+ vnoise(v_world * noise_scale * 2.7 + vec2(-t * 0.04, t * 0.01)) * 0.4;
	float a = max_alpha * near * (0.2 + 0.8 * above) * (0.45 + 0.9 * drift) * (1.0 - inside);
	COLOR = vec4(fog_color.rgb, clamp(a, 0.0, max_alpha));
}
