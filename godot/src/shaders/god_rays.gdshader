shader_type canvas_item;
render_mode blend_add, unshaded;
// LICHTSTRAHLEN (God Rays) — schlanke eigene Fassung, angelehnt an die Idee
// von „God Rays 2D" (godotshaders.com): Rauschen entlang des Winkels zur
// Lichtquelle, radial ausgeblendet, langsam atmend.
//   mode 0 = Sonne: Strahlen radial vom Punkt `source` (lokale Pixel).
//   mode 1 = Deckenlampen: nahezu parallele Bündel von oben, periodisch alle
//            `lamp_gap` Pixel, nach unten breiter werdend.
// Rechnet im LOKALEN Raum des Rechtecks (rect_origin + UV * rect_size), damit
// die Strahlen mit ihrer Parallax-Ebene wandern und immer von der gezeichneten
// Sonne ausgehen. Additiv und klein: Strahlen hellen auf, sie glühen nicht
// (alle Werte bleiben deutlich unter der HDR-Glüh-Schwelle 1,35).

uniform int mode = 0;
uniform vec2 rect_origin = vec2(-200.0, -200.0);
uniform vec2 rect_size = vec2(3000.0, 1700.0);
uniform vec2 source = vec2(1344.0, 259.0);
uniform vec4 ray_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float strength : hint_range(0.0, 0.6) = 0.16;
uniform float density1 = 9.0;
uniform float density2 = 23.0;
uniform float speed = 0.05;
uniform float fade_start = 90.0;
uniform float fade_end = 1700.0;
uniform float ground_y = 960.0;
uniform float lamp_gap = 640.0;
uniform float lamp_width = 150.0;

float hash1(float n) {
	return fract(sin(n) * 43758.5453123);
}

// weiches 1-D-Wertrauschen
float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), f);
}

void fragment() {
	vec2 p = rect_origin + UV * rect_size;
	float ray = 0.0;
	float shape = 0.0;
	if (mode == 0) {
		vec2 d = p - source;
		float dist = length(d);
		float ang = atan(d.y, d.x);
		// zwei Rauschlagen, die langsam gegeneinander driften → Strahlen "wandern"
		float a1 = noise1(ang * density1 + TIME * speed);
		float a2 = noise1(ang * density2 - TIME * speed * 1.7 + 7.0);
		ray = smoothstep(0.38, 0.95, a1 * 0.65 + a2 * 0.35);
		// nach unten kräftiger als in den Himmel hinein
		float dn = d.y / max(dist, 1.0);
		float down = 0.30 + 0.70 * smoothstep(-0.35, 0.45, dn);
		shape = smoothstep(fade_start, fade_start + 260.0, dist)
			* (1.0 - smoothstep(fade_end * 0.40, fade_end, dist)) * down;
	} else {
		float depth = clamp((p.y - rect_origin.y) / max(ground_y - rect_origin.y, 1.0), 0.0, 1.0);
		float lx = mod(p.x + lamp_gap * 0.5, lamp_gap) - lamp_gap * 0.5;
		float w = lamp_width * (0.55 + depth * 0.95);
		float beam = 1.0 - smoothstep(0.0, w, abs(lx));
		beam *= beam;
		// feine Streifen im Bündel (Staub, Luftbewegung), sehr langsam treibend
		float s1 = noise1(p.x * 0.045 + TIME * speed * 3.0);
		float s2 = noise1(p.x * 0.012 - TIME * speed * 1.3 + 3.0);
		ray = beam * (0.55 + 0.45 * (s1 * 0.5 + s2 * 0.5));
		shape = 1.0 - depth * 0.8;
	}
	float below = 1.0 - smoothstep(ground_y - 240.0, ground_y + 40.0, p.y);
	float breath = 0.86 + 0.14 * sin(TIME * 0.33);
	float v = ray * shape * below * breath * strength;
	COLOR = vec4(ray_color.rgb * v, 1.0);
}
