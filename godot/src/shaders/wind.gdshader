shader_type canvas_item;
render_mode blend_mix;

// WIND — Halme, Moos und Ranken biegen sich im Wind und weichen Paul aus.
// Vertex-Kodierung (src/world/terrain/Flora.gd):
//   UV.x = Büschel-Index + Phase (Nachkommaanteil, 0..1 → 0..2π)
//   UV.y = Abstand zur Wurzel in px (0 an der Wurzel → die Wurzel bleibt fest)
//   clusters[i] = (Wurzel-x, Wurzel-y, Kick-Zeit, Kick-Richtung) in Weltkoordinaten
// Alles ist eine reine Funktion der Zeit `t` — der Shader hält keinen Zustand.
// Andere Pakete können denselben Shader nutzen: nur `wind_strength`, `t` und
// `player_pos` setzen; clusters[0] bleibt der „ruhende" Eintrag (Wurzel weit weg).

uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;
uniform float t = 0.0;
uniform vec2 player_pos = vec2(-100000.0, -100000.0);
uniform float push_radius = 40.0;
uniform vec4 clusters[128];

varying vec4 v_color;

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Weiches Rauschen: glatt zwischen zwei Zufallswerten — nie Sprünge, nie Flackern
float smooth_noise(float x, float seed) {
	float i = floor(x);
	float f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i + seed), hash1(i + 1.0 + seed), f) - 0.5;
}

void vertex() {
	int idx = int(floor(UV.x + 0.001));
	float ph = fract(UV.x) * 6.2831853;
	float h = UV.y;
	vec4 c = clusters[idx];
	// Wind: langsame Grundwelle + kleine Böen + Rauschen; läuft als Front über x
	float wave = sin(t * 1.3 - c.x * 0.010 + ph) * 0.55
		+ sin(t * 2.7 - c.x * 0.027 + ph * 1.9) * 0.22
		+ sin(t * 0.31 - c.x * 0.003) * 0.35
		+ smooth_noise(t * 1.6 + float(idx) * 3.1, float(idx)) * 0.5;
	float bend = wave * wind_strength * 5.0 + wind_strength * 1.5;
	// Paul: Halme im Umkreis weichen aus — nur, wenn seine Füße auf Wurzelhöhe sind
	vec2 d = c.xy - player_pos;
	float near = (1.0 - smoothstep(6.0, push_radius, abs(d.x))) * (1.0 - smoothstep(24.0, 70.0, abs(d.y)));
	float push = (d.x >= 0.0 ? 1.0 : -1.0) * near * 11.0;
	// Nachfedern nach dem Vorbeilaufen: gedämpfte Schwingung ab der Kick-Zeit (≈1,7 Hz)
	float dt = t - c.z;
	float spring = c.w * exp(-3.2 * dt) * sin(10.5 * dt) * 6.0 * step(0.0, dt) * (1.0 - near);
	// Verschiebung wächst mit dem Quadrat der Höhe: Wurzel fest, Spitze frei
	float k = h * h / 600.0;
	float disp = (bend + push + spring) * k;
	VERTEX.x += disp;
	VERTEX.y += abs(disp) * 0.16;
	v_color = COLOR;
}

void fragment() {
	COLOR = v_color;
}
