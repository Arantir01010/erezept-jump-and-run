shader_type canvas_item;
render_mode blend_mix;

// VAU-WABENGITTER — das Gitter im VAU-Feld (Raum, kein Tunnel) wird EINMAL als
// Linienliste gezeichnet (Stations.gd, VauFeld._Gitter); die ruhige Helligkeits-
// welle läuft hier im Shader. Früher entstand jede Wabe in jedem Frame neu per
// _draw — bei vier Feldern in Station 15 der Grund für das Ruckeln.
// Gleiche Formel wie vorher: 0,13 + 0,08 · sin(2t + 0,05x + 0,03y), also etwa
// 0,3 Hz — weit unter der 3-Hz-Grenze für Blinken.
// `t` setzt das Feld (läuft mit der Spielzeit, steht in der Pause).

uniform float t = 0.0;

varying vec2 ort;

void vertex() {
	ort = VERTEX;
}

void fragment() {
	float a = 0.13 + 0.08 * sin(t * 2.0 + ort.x * 0.05 + ort.y * 0.03);
	COLOR.a *= a;
}
