class_name Bildschirmbild
extends RefCounted
## BILDSCHIRMBILD — Aufnahme eines Viewports so, wie der Bildschirm sie zeigt.
##
## Mit hdr_2d (Desktop, Forward+) rechnet Godot das 2D-Bild linear in Gleitkomma
## (RGBAH); erst der letzte Schritt zum Bildschirm wandelt linear → sRGB. Wer
## get_texture().get_image() direkt als PNG speichert, bekommt das lineare Bild:
## viel zu dunkel (Mittelgrau 127 → 54). Image.linear_to_srgb() hilft nicht — es
## nimmt nur RGB8/RGBA8, und vorher auf 8 Bit zu gehen hieße, die dunklen Töne
## linear in 256 Stufen zu pressen (Bänder in Nacht und Regen).
##
## Darum: Gleitkomma → Tabelle mit 65 536 Stufen → sRGB 8 Bit, über 1 begrenzt
## wie die Ausgabe. Linear ist das Bild nur mit hdr_2d in Forward+: Der
## Compatibility-Renderer legt mit hdr_2d zwar einen Gleitkommapuffer an, rechnet
## aber in sRGB — dort wird nur auf 0…1 begrenzt und gerundet, sonst würde das
## Bild ausgewaschen. 8-Bit-Bilder (Browser, ohne hdr_2d) kommen
## unverändert zurück. Nicht nachgebildet: das ±1-Stufen-Rauschen der
## Entbänderung (Viewport.use_debanding, nur beim Ausgeben auf den Schirm).
## Keine Abhängigkeit von Autoloads — auch Hauptskripte (--script) nutzen es.

const STUFEN := 65536

static var _tabelle_linear := PackedByteArray()
static var _tabelle_srgb := PackedByteArray()


## Bild des Viewports im Zustand dieses Bilds (vorher RenderingServer.frame_post_draw abwarten).
static func von(vp: Viewport) -> Image:
	return srgb(vp.get_texture().get_image(), linear(vp))


## Umrechnungstabelle schon im Hauptthread anlegen. Wer srgb() auf einem
## Hintergrund-Thread aufruft (Kiosk.save_screenshot), liest sie dann nur noch.
static func vorbereiten(ist_linear := true) -> void:
	_tabelle_holen(ist_linear)


## Liegt das Viewport-Bild linear vor? Nur mit hdr_2d außerhalb von Compatibility.
static func linear(vp: Viewport) -> bool:
	return vp.use_hdr_2d and RenderingServer.get_current_rendering_method() != "gl_compatibility"


## Gleitkommabild → sRGB RGBA8 (deckend). `ist_linear`: Werte linear (Forward+ mit
## hdr_2d) → Formel der Ausgabe; sonst schon sRGB → nur auf 0…1 begrenzt.
## 8-Bit-Bilder kommen unverändert zurück.
static func srgb(img: Image, ist_linear := true) -> Image:
	if img == null or img.is_empty():
		return img
	var f := img.get_format()
	if not f in [Image.FORMAT_RGBAH, Image.FORMAT_RGBAF, Image.FORMAT_RGBH, Image.FORMAT_RGBF]:
		return img
	var t := _tabelle_holen(ist_linear)
	var lin := img.duplicate() as Image
	lin.convert(Image.FORMAT_RGBAF)
	var werte := lin.get_data().to_float32_array()
	var n := img.get_width() * img.get_height()
	var aus := PackedByteArray()
	aus.resize(n * 4)
	var oben := STUFEN - 1
	for i in n:
		var j := i * 4
		aus[j] = t[clampi(int(werte[j] * oben + 0.5), 0, oben)]
		aus[j + 1] = t[clampi(int(werte[j + 1] * oben + 0.5), 0, oben)]
		aus[j + 2] = t[clampi(int(werte[j + 2] * oben + 0.5), 0, oben)]
		aus[j + 3] = 255
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, aus)


## Ein linearer Wert 0…1 als sRGB-Byte (die Formel der Ausgabe).
static func srgb_byte(wert: float) -> int:
	var c := clampf(wert, 0.0, 1.0)
	var s := c * 12.92 if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055
	return clampi(roundi(s * 255.0), 0, 255)


## Wert 0…1 → Byte, gerundet wie die Ausgabe: linear über die sRGB-Formel, sonst
## nur gerundet (Image.convert schnitte ab und läge eine Stufe daneben).
static func _tabelle_holen(ist_linear: bool) -> PackedByteArray:
	var t := _tabelle_linear if ist_linear else _tabelle_srgb
	if t.size() != STUFEN:
		t = PackedByteArray()
		t.resize(STUFEN)
		for i in STUFEN:
			var v := float(i) / float(STUFEN - 1)
			t[i] = srgb_byte(v) if ist_linear else clampi(roundi(v * 255.0), 0, 255)
		if ist_linear:
			_tabelle_linear = t
		else:
			_tabelle_srgb = t
	return t
