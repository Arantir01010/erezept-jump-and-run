extends SceneTree
## STANDBILD — Screenshots einer Station an gezielten Stellen, für Vorher/Nachher-
## Vergleiche ohne Menschen am Rechner (braucht ein Fenster, z. B. unter Xvfb):
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-method gl_compatibility \
##     --resolution 1920x1080 --script res://tests/standbild.gd -- --windowed --webfx \
##     --level=15-kontextschluessel --an=vau-feld,lauscher,spike,0.42 --ziel=/tmp/bilder
##
## --an: Baustein-Typen (Paul steht am ersten Baustein dieses Typs) oder Anteile der
## Levelbreite. Zusätzlich: „pause" (Pausemenü öffnen). Dateien: <level>-<stelle>.png.

var _main: Node
var _ziel := "user://standbild"
var _level := "15-kontextschluessel"
var _stellen: Array[String] = ["0.42"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--level="):
			_level = s.get_slice("=", 1)
		elif s.begins_with("--an="):
			_stellen.assign(s.get_slice("=", 1).split(","))
		elif s.begins_with("--ziel="):
			_ziel = s.get_slice("=", 1)
	process_frame.connect(_los, CONNECT_ONE_SHOT)


func _warte(n: int) -> void:
	for i in n:
		await process_frame




func _bild(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_ziel)
	var pfad := _ziel.path_join("%s-%s.png" % [_level, name])
	img.save_png(pfad)
	print("[bild] ", pfad)


func _los() -> void:
	# Autoloads sind im Hauptskript (--script) nicht als Bezeichner bekannt → über den Baum
	var game := root.get_node("Game")
	var kiosk := root.get_node("Kiosk")
	var tile: float = game.TILE
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _warte(5)
	print("[bild] Station ", _level)
	_main._start_level(maxi(0, (game.playlist as Array).find(_level)))
	# In Frames warten, nicht in Sekunden: Unter Xvfb (Software-OpenGL, ~1 Bild/s)
	# rückt die Spielzeit je Frame nur um höchstens 8 Physikschritte vor.
	await _warte(34)   # Titel-Einblendung abwarten
	var lvl = _main.level
	for stelle in _stellen:
		kiosk.note_input()
		if stelle == "pause":
			_main.toggle_pause()
			await _warte(6)
			await _bild("pause")
			_main.toggle_pause()
			await _warte(5)
			continue
		var ziel := Vector2.ZERO
		if stelle.is_valid_float():
			ziel = Vector2(lvl.data.width * float(stelle) * tile, lvl.data.world_height() - 3.0 * tile - 2.0)
		else:
			# der am weitesten links liegende Baustein dieses Typs (Reihenfolge stabil)
			var beste_x := INF
			for m in lvl.mechanics:
				if is_instance_valid(m) and m.type == stelle and m.rect.position.x < beste_x:
					beste_x = m.rect.position.x
					ziel = Vector2(m.rect.get_center().x - 2.0 * tile, m.rect.end.y - 2.0)
			if ziel == Vector2.ZERO:
				print("[bild] kein Baustein '%s' in %s" % [stelle, _level])
				continue
		lvl.player.global_position = ziel
		lvl.player.set_respawn(ziel)
		lvl.player.velocity = Vector2.ZERO
		await _warte(16)   # Kamera zieht weich nach
		await _bild(stelle)
	quit(0)
