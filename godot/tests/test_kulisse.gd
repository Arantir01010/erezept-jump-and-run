extends "res://tests/testfall.gd"
## KULISSE RUHIG: Das Leben der Kulisse läuft in Spielzeit (steht in der Pause,
## folgt der Zeitlupe, beginnt mit jeder Station bei 0), keine Wanduhr und keine
## eigene Web-Abfrage in der Kulisse (Weichzeichner über Grafik), und Bildschirmbild
## speichert, was der Bildschirm zeigt (linear → sRGB).
## Testlauf mit --fixed-fps 60 (lauf.gd): ein Bild = 1/60 s Spielzeit.

const SCHRITT := 1.0 / 60.0

var knoten: Node


func aufraeumen() -> void:
	baum.paused = false
	Engine.time_scale = 1.0
	Grafik.setze_stufe(-1)
	if is_instance_valid(knoten):
		knoten.queue_free()
	await frames(2)


func _leben(kind: String) -> KulisseLeben:
	knoten = Node.new()
	baum.root.add_child(knoten)
	var l := KulisseLeben.new()
	l.kind = kind
	l.pal = Palette.for_world("praxis-morgen")
	l.build("test-kulisse")
	knoten.add_child(l)
	return l


func test_kulisse_laeuft_in_spielzeit_und_beginnt_bei_null() -> void:
	var l := _leben("wolken")
	nahe(l.zeit, 0.0, 0.0, "neue Ebene beginnt bei 0")
	await frames(1)
	var z0 := l.zeit
	await frames(30)
	nahe(l.zeit - z0, 30.0 * SCHRITT, 1e-6, "30 Bilder = 0,5 s Spielzeit")


func test_kulisse_steht_in_der_pause() -> void:
	var l := _leben("fog")
	await frames(3)
	baum.paused = true
	var z0 := l.zeit
	await frames(20)
	nahe(l.zeit, z0, 0.0, "Pause: Kulisse steht")
	baum.paused = false
	await frames(1)
	var z1 := l.zeit
	await frames(12)
	nahe(l.zeit - z1, 12.0 * SCHRITT, 1e-6, "nach der Pause weiter ohne Sprung")
	nahe(z1 - z0, SCHRITT, 1e-6, "erstes Bild nach der Pause: ein Schritt, kein Nachholen")


func test_kulisse_folgt_der_zeitlupe() -> void:
	var l := _leben("mid")
	await frames(2)
	Engine.time_scale = 0.25
	await frames(1)
	var z0 := l.zeit
	await frames(40)
	nahe(l.zeit - z0, 40.0 * SCHRITT * 0.25, 1e-6, "Zeitlupe 0,25: Kulisse ein Viertel so schnell")
	Engine.time_scale = 1.0


func test_kulisse_ohne_wanduhr_und_ohne_eigene_web_abfrage() -> void:
	var dateien_kulisse := dateien("res://src/world/backdrop/", ".gd")
	dateien_kulisse.append("res://src/world/Backdrop.gd")
	pruefe(dateien_kulisse.size() >= 6, "Kulissendateien gefunden (%d)" % dateien_kulisse.size())
	for f in dateien_kulisse:
		var text := FileAccess.get_file_as_string(f)
		for verboten: String in ["Time.get_ticks", "Time.get_unix_time", "OS.has_feature"]:
			pruefe(not text.contains(verboten), "%s nutzt %s (Spielzeit bzw. Grafik.gd nehmen)" % [f, verboten])


func test_weichzeichner_der_kulisse_folgt_der_grafikstufe() -> void:
	# Stufe 2: Wolken, ferne und mittlere Stadt, Vordergrund je in einer Blur-Gruppe;
	# Stufe 0 (Browser): Wolken und Vordergrund scharf, die Stadt bleibt weich.
	var soll := {0: 2, 1: 4, 2: 4}
	for s: int in soll:
		Grafik.setze_stufe(s)
		knoten = Node.new()
		baum.root.add_child(knoten)
		var b := Backdrop.new()
		b.build(Palette.for_world("praxis-morgen"), 4000.0, 1104.0, "test-kulisse")
		knoten.add_child(b)
		var gruppen := b.find_children("*", "CanvasGroup", true, false).size()
		gleich(gruppen, soll[s], "Stufe %d: Blur-Gruppen der Kulisse" % s)
		var vorn_weich := b.foreground.get_child_count() > 0 and b.foreground.get_child(0) is CanvasGroup
		gleich(vorn_weich, s != 0, "Stufe %d: Vordergrund weich" % s)
		knoten.queue_free()
		await frames(1)


func test_bildschirmbild_wandelt_linear_in_srgb() -> void:
	# lineare Werte → erwartete sRGB-Bytes (Formel der Ausgabe, über 1 begrenzt)
	var paare := [[0.0, 0], [0.001, 3], [0.05126, 64], [0.215861, 128], [0.577581, 200], [1.0, 255], [3.0, 255]]
	var img := Image.create_empty(paare.size(), 1, false, Image.FORMAT_RGBAH)
	for i in paare.size():
		var v: float = paare[i][0]
		img.set_pixel(i, 0, Color(v, v * 0.5, 0.0, 1.0))
	var aus := Bildschirmbild.srgb(img)
	gleich(aus.get_format(), Image.FORMAT_RGBA8, "Ergebnis ist 8 Bit")
	gleich(img.get_format(), Image.FORMAT_RGBAH, "Eingabe bleibt unverändert")
	for i in paare.size():
		var v: float = paare[i][0]
		var soll_r: int = paare[i][1]
		var c := aus.get_pixel(i, 0)
		gleich(c.r8, soll_r, "linear %.5f → sRGB" % v)
		nahe(float(c.g8), float(Bildschirmbild.srgb_byte(v * 0.5)), 1.0, "linear %.5f (G) → sRGB" % (v * 0.5))
		gleich(c.b8, 0, "Schwarz bleibt Schwarz")
		gleich(c.a8, 255, "deckend")
	# 8-Bit-Bilder (Browser, Compatibility, ohne hdr_2d) sind schon sRGB
	var acht := Image.create_empty(2, 1, false, Image.FORMAT_RGBA8)
	acht.set_pixel(0, 0, Color8(127, 64, 191, 255))
	pruefe(Bildschirmbild.srgb(acht) == acht, "8-Bit-Bild kommt unverändert zurück")


func test_bildwerkzeuge_speichern_srgb() -> void:
	for f: String in ["res://tests/standbild.gd", "res://tests/kartenbild.gd", "res://tests/briefingbild.gd"]:
		var text := FileAccess.get_file_as_string(f)
		pruefe(text.contains("Bildschirmbild.von(root)"), "%s speichert über Bildschirmbild (sRGB)" % f)
		pruefe(not text.contains("root.get_texture().get_image()"), "%s liest das lineare Viewport-Bild direkt" % f)
