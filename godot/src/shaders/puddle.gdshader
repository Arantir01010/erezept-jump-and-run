shader_type canvas_item;
render_mode blend_mix;

// PFÜTZEN (Regenwelt) — schmaler Streifen auf Standflächen, der das Bild darüber
// vertikal gespiegelt zeigt (Screen-Texture), leicht verwellt durch Rauschen.
// Läuft im Compatibility-Renderer (hint_screen_texture ist dort erlaubt).
// Vertex-Kodierung (src/world/terrain/Puddles.gd):
//   UV.x = Position entlang der Pfütze in px, UV.y = Tiefe unter der Wasserlinie in px,
//   COLOR.a = weiche Ränder der Pfütze.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float uv_per_px = 0.001;   // Screen-UV je Welt-Pixel (vertikal), pro Frame aus der Kamera
uniform float t = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.25;
uniform float depth_px = 8.0;
// Gestauchter Spiegel: der schmale Streifen zeigt die mirror_scale-fache Höhe
// darüber (Wet-Floor-Trick) — so erscheint Paul, nicht nur seine Schuhsohlen.
uniform float mirror_scale = 5.0;
uniform vec4 tint : source_color = vec4(0.75, 0.82, 0.92, 1.0);

varying vec2 v_uv;
varying vec4 v_color;

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float smooth_noise(float x) {
	float i = floor(x);
	float f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), f) - 0.5;
}

void vertex() {
	v_uv = UV;
	v_color = COLOR;
}

void fragment() {
	float depth = v_uv.y;
	// Wellen: zwei langsame Sinus über x und Zeit plus weiches Rauschen (Welt-px)
	float ripple = sin(v_uv.x * 0.11 + t * 1.9) * 0.8
		+ sin(v_uv.x * 0.043 - t * 1.1 + depth * 0.5) * 0.6
		+ smooth_noise(v_uv.x * 0.08 + t * 0.7) * 1.2;
	vec2 suv = SCREEN_UV;
	suv.y -= (depth + depth * mirror_scale) * uv_per_px;   // Spiegelung an der Wasserlinie, gestaucht
	suv.x += ripple * uv_per_px * 0.7;
	suv.y += ripple * uv_per_px * 0.5;
	vec3 scr = texture(screen_tex, suv).rgb;
	float fade = 1.0 - smoothstep(0.3, 1.0, depth / depth_px);   // unten weicher
	float a = v_color.a * strength * (0.5 + 0.5 * fade);
	COLOR = vec4(mix(scr, tint.rgb, 0.18), a);
}
