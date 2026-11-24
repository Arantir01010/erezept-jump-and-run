extends SceneTree
## KARTENBILD — Bilder der Stationskarte (Screen nach einem Level) mit festen Werten,
## für Vorher/Nachher-Vergleiche ohne Durchspielen. Braucht ein Fenster (z. B. Xvfb):
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-method gl_compatibility \
##     --resolution 1920x1080 --script res://tests/kartenbild.gd -- --windowed \
##     --level=04-die-huelle --medaillen=zeit,bits,lueckenlos --ziel=/tmp/bilder
##
## --medaillen: welche der drei Medaillen geschafft sind (zeit, bits, lueckenlos; leer = keine).
## --nach: Sekunden nach dem Öffnen, zu denen ein Bild entsteht (Standard 2.4,5).
## --sprache: z. B. en, zh, hi (Standard: Deutsch). --touch: Knopfnamen wie auf Touch-Geräten.
## Dateien: karte-<level>-<anzahl>m-<sekunden>s.png (mit --sprache: …-<sprache>.png)

var _ziel := "user://kartenbild"
var _level := "01-stammdaten"
var _medaillen: Array[String] = ["zeit", "lueckenlos"]
var _nach: Array[float] = [2.4, 5.0]
var _sprache := ""
var _touch := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--level="):
			_level = s.get_slice("=", 1)
		elif s.begins_with("--medaillen="):
			_medaillen.clear()
			for m in s.get_slice("=", 1).split(",", false):
				_medaillen.append(m)
		elif s.begins_with("--nach="):
			_nach.clear()
			for t in s.get_slice("=", 1).split(",", false):
				_nach.append(float(t))
		elif s.begins_with("--ziel="):
			_ziel = s.get_slice("=", 1)
		elif s.begins_with("--sprache="):
			_sprache = s.get_slice("=", 1)
		elif s == "--touch":
			_touch = true
	process_frame.connect(_los, CONNECT_ONE_SHOT)


func _los() -> void:
	# Autoloads sind im Hauptskript (--script) nicht als Bezeichner bekannt. Darum hier
	# nichts mit class_name direkt nennen (LevelData, LevelCard nutzen Game): Diese
	# Skripte werden erst zur Laufzeit geladen, wenn die Autoloads stehen.
	var game := root.get_node("Game")
	if _sprache != "":
		game.set_lang(_sprache)
	if _touch:
		root.get_node("Kiosk").touch_forced = true
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var idx := maxi(0, (game.playlist as Array).find(_level))
	game.level_index = idx
	game.score = 4280
	var data = load("res://src/core/LevelData.gd").load_level(_level)
	var total: int = maxi(1, data.bits_total)
	var medals := {"zeit": "zeit" in _medaillen, "bits": "bits" in _medaillen, "lueckenlos": "lueckenlos" in _medaillen}
	var result := {
		"level_id": _level, "time": data.par_time * (0.82 if medals.zeit else 1.31), "par": data.par_time,
		"bits": total if medals.bits else maxi(0, total - 3), "bits_total": total,
		"seen": 0 if medals.lueckenlos else 2, "medals": medals,
	}
	# wie Main._on_level_completed: Titel weg, Karte in die Overlay-Ebene
	main._clear()
	main._set_screen(main.Screen.CARD)
	var card: Control = load("res://src/ui/LevelCard.gd").new()
	main.overlay.add_child(card)
	card.setup(data, result, idx + 1 < (game.playlist as Array).size())
	main._current = card
	print("[bild] Karte ", _level, " ", medals)
	var start := Time.get_ticks_msec()
	for t in _nach:
		while Time.get_ticks_msec() - start < int(t * 1000.0):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(_ziel)
		var name := "karte-%s-%dm-%ss" % [_level, _medaillen.size(), str(t)]
		if _sprache != "":
			name += "-" + _sprache
		var pfad := _ziel.path_join(name + ".png")
		img.save_png(pfad)
		print("[bild] ", pfad)
	quit(0)
