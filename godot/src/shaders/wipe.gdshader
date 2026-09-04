shader_type canvas_item;
// BLENDE zwischen den Screens: eine schräge Kante fährt durchs Bild — vorne ein
// warmer Saum (PwC-Orange), dahinter Nachtblau. progress 0 = frei, 1 = verdeckt.
// direction +1: die Kante wandert von links nach rechts, -1: von rechts nach links.
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float direction = 1.0;
uniform vec4 farbe : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform vec4 saum : source_color = vec4(0.816, 0.290, 0.008, 1.0);
uniform float schraege = 0.22;
uniform float saum_breite = 0.06;

void fragment() {
	float x = direction >= 0.0 ? UV.x : 1.0 - UV.x;
	float yy = direction >= 0.0 ? UV.y : 1.0 - UV.y;
	float d = x + yy * schraege;
	float span = 1.0 + schraege + 2.0 * saum_breite;
	float f = progress * span - saum_breite;
	float covered = 1.0 - smoothstep(f - 0.003, f + 0.003, d);
	float edge = 1.0 - smoothstep(0.0, saum_breite, abs(d - f));
	vec4 col = farbe;
	col.rgb = mix(col.rgb, saum.rgb, edge * 0.85);
	col.a = max(covered, edge * 0.9);
	COLOR = col;
}
