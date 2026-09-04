shader_type canvas_item;
// TIEFENSCHÄRFE FÜR EINE KULISSENEBENE — Material einer CanvasGroup.
// Die Kinder der Gruppe landen zuerst im Backbuffer (vormultipliziertes Alpha),
// hier wird die ganze Ebene in EINEM Durchgang weichgezeichnet: Mitte + zwei
// Ringe (17 Abtastungen), Gewichte ungefähr gaussisch. Bewusst ohne Mipmaps
// (textureLod), damit derselbe Shader im Compatibility-Renderer (WebGL 2) läuft.
// radius_px: Bildschirm-Pixel; 0 = scharf (Durchreichen).

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float radius_px : hint_range(0.0, 12.0) = 3.0;

void fragment() {
	vec4 c;
	if (radius_px < 0.05) {
		c = texture(screen_tex, SCREEN_UV);
	} else {
		vec2 r = SCREEN_PIXEL_SIZE * radius_px;
		vec2 h = r * 0.5;
		// Mitte
		c = texture(screen_tex, SCREEN_UV) * 0.16;
		// innerer Ring (halber Radius, um 22,5° gedreht), 8 × 0,065
		c += texture(screen_tex, SCREEN_UV + vec2( 0.9239,  0.3827) * h) * 0.065;
		c += texture(screen_tex, SCREEN_UV + vec2( 0.3827,  0.9239) * h) * 0.065;
		c += texture(screen_tex, SCREEN_UV + vec2(-0.3827,  0.9239) * h) * 0.065;
		c += texture(screen_tex, SCREEN_UV + vec2(-0.9239,  0.3827) * h) * 0.065;
		c += texture(screen_tex, SCREEN_UV + vec2(-0.9239, -0.3827) * h) * 0.065;
		c += texture(screen_tex, SCREEN_UV + vec2(-0.3827, -0.9239) * h) * 0.065;
		c += texture(screen_tex, SCREEN_UV + vec2( 0.3827, -0.9239) * h) * 0.065;
		c += texture(screen_tex, SCREEN_UV + vec2( 0.9239, -0.3827) * h) * 0.065;
		// äußerer Ring (voller Radius), 8 × 0,04
		c += texture(screen_tex, SCREEN_UV + vec2( 1.0,  0.0) * r) * 0.04;
		c += texture(screen_tex, SCREEN_UV + vec2( 0.7071,  0.7071) * r) * 0.04;
		c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  1.0) * r) * 0.04;
		c += texture(screen_tex, SCREEN_UV + vec2(-0.7071,  0.7071) * r) * 0.04;
		c += texture(screen_tex, SCREEN_UV + vec2(-1.0,  0.0) * r) * 0.04;
		c += texture(screen_tex, SCREEN_UV + vec2(-0.7071, -0.7071) * r) * 0.04;
		c += texture(screen_tex, SCREEN_UV + vec2( 0.0, -1.0) * r) * 0.04;
		c += texture(screen_tex, SCREEN_UV + vec2( 0.7071, -0.7071) * r) * 0.04;
	}
	// Backbuffer ist vormultipliziert → zurückrechnen, dann normal mischen
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	COLOR *= c;
}
