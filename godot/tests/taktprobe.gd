extends SceneTree
## TAKTPROBE — Läuft Paul bei hoher Bildwiederholrate gleichmäßig?
##
##   godot --headless --path godot --fixed-fps 144 --script res://tests/taktprobe.gd
##   (Gegenprobe ohne Physik-Interpolation: -- --ohne-interpolation)
##
## Mit echtem Renderer (prüft, dass Godot Paul wirklich so zeichnet, wie hier
## gerechnet wird — braucht ein Fenster, z. B. unter Xvfb):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-method gl_compatibility \
##     --fixed-fps 144 --script res://tests/taktprobe.gd -- --bild
## Dann trägt Paul eine magentafarbene Marke; gemessen wird ihre Lage im fertigen Bild.
##
## Die Physik tickt mit 60 Hz, Monitore zeigen 60, 120 oder 144 Bilder/s, Browser
## so viele, wie der Monitor kann. Ohne Interpolation rückt Paul dann in ungleichen
## Sprüngen vor (bei 144 Hz: 0 / 9 / 0 / 9 px …), während die Kamera gleichmäßig
## gleitet — er ruckelt gegen den Hintergrund.
##
## Aufbau: ein langer flacher Boden, der echte Player und die echte GameCamera;
## Paul läuft per Autopilot mit voller Geschwindigkeit nach rechts. Gemessen wird je
## Bild, NACH allen _process-Aufrufen, Pauls Bildposition: so, wie der Renderer ihn
## zeichnet (Player.render_position(): mit Interpolation zwischen den letzten beiden
## Physikschritten), in der Welt und auf dem Schirm (relativ zur Kamera).
##
## Kennzahl „Unruhe": Effektivwert der zweiten Differenz der Position (px je Bild²).
## 0 heißt vollkommen gleichmäßig. Schlusszeile (Rückgabecode 1, wenn Paul mit
## Interpolation nicht gleichmäßig läuft):
##   TAKT [(Bild)] <fps> Hz, Interpolation an|aus: Welt-Unruhe x.xx px, Schirm-Unruhe x.xx px, Schritt a … b px
##
## Gemessen am 24.11.2026 (Welt-/Schirm-Unruhe, ohne → mit Interpolation):
##   60 Hz: 0,00 / 0,00 → 0,00 / 0,00 · 120 Hz: 9,00 / 10,29 → 0,00 / 1,13
##   144 Hz: 8,21 / 9,60 → 0,00 / 0,72 · im echten Bild (Xvfb, 144 Hz): 8,20 / 9,59 → 0,71 / 1,05
## Die verbleibende Schirm-Unruhe stammt vom Runden der Kamera auf ganze Pixel.

const BILDER := 288          # Messdauer in Bildern (bei 144 Hz: 2 s)
const VORLAUF := 150         # Bilder bis volle Geschwindigkeit und ruhige Kamera

const MARKE := Vector2(-6.0, -150.0)   # lokale Lage der Marke an Paul (--bild)

var _player: Node2D
var _cam: Camera2D
var _bild := false
var _marke_alt := Vector2(-1.0, -1.0)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--ohne-interpolation" in args:
		physics_interpolation = false
	_bild = "--bild" in args
	process_frame.connect(_los, CONNECT_ONE_SHOT)


## Paul in Weltkoordinaten, abgelesen am fertigen Bild (Mitte der Marke).
func _aus_dem_bild() -> Vector2:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var bereich := Rect2i(0, 0, w, h)
	var schritt := 3
	if _marke_alt.x >= 0.0:
		bereich = Rect2i(int(_marke_alt.x) - 60, int(_marke_alt.y) - 60, 120, 120).intersection(bereich)
		schritt = 1
	var summe := Vector2.ZERO
	var n := 0
	for y in range(bereich.position.y, bereich.end.y, schritt):
		for x in range(bereich.position.x, bereich.end.x, schritt):
			var c := img.get_pixel(x, y)
			if c.r > 0.85 and c.g < 0.2 and c.b > 0.85:
				summe += Vector2(x + 0.5, y + 0.5)
				n += 1
	if n == 0:
		_marke_alt = Vector2(-1.0, -1.0)
		return Vector2.INF
	var mitte := summe / n
	if schritt > 1:   # grob gefunden: im nächsten Bild genau
		_marke_alt = mitte
		return await _aus_dem_bild()
	_marke_alt = mitte
	var xf := root.get_final_transform() * root.get_canvas_transform()
	return xf.affine_inverse() * mitte - MARKE - Vector2(6.0, 6.0)


func _nach_process() -> void:
	# Timer laufen nach allen _process-Aufrufen des Bildes ab (SceneTree::process):
	# hier stehen Paul und Kamera so, wie sie gleich gezeichnet werden.
	await process_frame
	await create_timer(0.0).timeout


func _bildposition() -> Vector2:
	if _player.has_method("render_position"):
		return _player.call("render_position")
	return _player.global_position


func _los() -> void:
	var welt := Node2D.new()
	welt.name = "Takt"
	# wie Main.tscn: von sich aus nichts interpolieren, nur was es ausdrücklich will
	welt.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(welt)
	var boden := StaticBody2D.new()
	boden.collision_layer = 1
	var form := CollisionShape2D.new()
	var rechteck := RectangleShape2D.new()
	rechteck.size = Vector2(400000.0, 96.0)
	form.shape = rechteck
	boden.add_child(form)
	boden.position = Vector2(200000.0, 1048.0)
	welt.add_child(boden)

	_player = load("res://src/player/Player.gd").new()
	_player.global_position = Vector2(600.0, 1000.0)
	welt.add_child(_player)
	_cam = load("res://src/world/GameCamera.gd").new()
	welt.add_child(_cam)
	_cam.call("setup", _player, 400000.0, 1200.0)
	_player.set("autopilot", true)
	_player.set("auto_axis", 1.0)
	if _bild:
		var marke := ColorRect.new()
		marke.color = Color(1, 0, 1)
		marke.size = Vector2(12, 12)
		marke.position = MARKE
		marke.z_index = 100
		_player.add_child(marke)   # erbt Pauls Interpolation

	for i in VORLAUF:
		await _nach_process()
	var welt_x: Array[float] = []
	var schirm_x: Array[float] = []
	var am_boden := true
	var bilder := BILDER / 2 if _bild else BILDER
	for i in bilder:
		var p := Vector2.ZERO
		var cam_x := 0.0
		if _bild:
			p = await _aus_dem_bild()
			if p == Vector2.INF:
				print("TAKT: Marke nicht im Bild gefunden")
				quit(1)
				return
			cam_x = (root.get_canvas_transform().affine_inverse() * (root.get_visible_rect().size / 2.0)).x
		else:
			await _nach_process()
			p = _bildposition()
			cam_x = _cam.global_position.x
		welt_x.append(p.x)
		schirm_x.append((p.x - cam_x) * _cam.zoom.x)
		am_boden = am_boden and (_player as CharacterBody2D).is_on_floor()
	var schritte: Array[float] = []
	for i in range(1, welt_x.size()):
		schritte.append(welt_x[i] - welt_x[i - 1])
	var hz := roundi(1.0 / maxf(root.get_process_delta_time(), 0.0001))
	print("TAKT%s %d Hz, Interpolation %s: Welt-Unruhe %.2f px, Schirm-Unruhe %.2f px, Schritt %.1f … %.1f px%s" % [
		" (Bild)" if _bild else "", hz, "an" if physics_interpolation else "aus",
		_unruhe(welt_x), _unruhe(schirm_x), schritte.min(), schritte.max(),
		"" if am_boden else " (WARNUNG: Paul war nicht immer am Boden)"])
	# Rückgabecode für Prüfstufen: Mit Interpolation muss Paul gleichmäßig laufen
	# (gemessen 0,00 px rechnerisch, 0,71 px im echten Bild wegen ganzer Pixel).
	var ok := not physics_interpolation or (_unruhe(welt_x) < 1.5 and am_boden)
	quit(0 if ok else 1)


## Effektivwert der zweiten Differenz: wie stark das Tempo von Bild zu Bild springt.
static func _unruhe(x: Array[float]) -> float:
	var summe := 0.0
	var n := 0
	for i in range(1, x.size() - 1):
		var d2 := x[i + 1] - 2.0 * x[i] + x[i - 1]
		summe += d2 * d2
		n += 1
	return sqrt(summe / maxf(1.0, n))
