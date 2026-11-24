extends SceneTree
## BRIEFINGBILD — Bilder eines Stations-Briefings zu festen Szenenzeiten, für
## Vorher/Nachher-Vergleiche ohne Durchklicken. Braucht ein Fenster (z. B. Xvfb):
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-method gl_compatibility \
##     --resolution 1920x1080 --script res://tests/briefingbild.gd -- --windowed \
##     --station=05-identitaet --bei=0.5,11.8 --ziel=/tmp/bilder
##
## --station statt --level: --level= würde Kiosk sofort ins Level springen lassen.
## --bei: Szenenzeiten in Sekunden seit dem Öffnen (die Mini-Szene läuft im Takt
## ihres Zyklus, BriefingDaten „szene"). Sonst läuft ein Briefing nach der Wanduhr
## (Vignette._process); hier steht die Uhr, und das Werkzeug setzt die Zeit je Bild
## selbst. Die Schwebeteilchen (Staub) sind ausgeblendet, das Filmkorn der
## Nachbearbeitung (PostFx) steht auf Zeit 0. So ergeben zwei Läufe derselben
## Codebasis dieselben Pixel.
## --sprache: z. B. en (Standard: Deutsch). Dateien: briefing-<station>-<sekunden>s.png

var _ziel := "user://briefingbild"
var _station := "05-identitaet"
var _bei: Array[float] = [0.5, 11.8]
var _sprache := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--station="):
			_station = s.get_slice("=", 1)
		elif s.begins_with("--bei="):
			_bei.clear()
			for t in s.get_slice("=", 1).split(",", false):
				_bei.append(float(t))
		elif s.begins_with("--ziel="):
			_ziel = s.get_slice("=", 1)
		elif s.begins_with("--sprache="):
			_sprache = s.get_slice("=", 1)
	process_frame.connect(_los, CONNECT_ONE_SHOT)


func _los() -> void:
	# Autoloads sind im Hauptskript (--script) nicht als Bezeichner bekannt → über den
	# Baum; Briefing.gd wird erst zur Laufzeit geladen (es nutzt Game, Kiosk).
	var game := root.get_node("Game")
	var kiosk := root.get_node("Kiosk")
	if _sprache != "":
		game.set_lang(_sprache)
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	# Erst umschalten, wenn show_title() durch ist (sonst räumt es das Briefing gleich
	# wieder ab); dann die Blende anhalten und offen lassen.
	for i in 120:
		await process_frame
		if main._current != null:
			break
	for tw in get_processed_tweens():
		tw.kill()
	main._wipe.set_shader_parameter("progress", 0.0)
	var idx := maxi(0, (game.playlist as Array).find(_station))
	# wie Main.show_briefing, ohne Blende
	main._clear()
	main._set_screen(main.Screen.BRIEFING)
	var b: Node2D = load("res://src/ui/Briefing.gd").new(idx)
	main.overlay.add_child(b)
	main._current = b
	b.set_process(false)   # Wanduhr aus: die Zeit setzt das Werkzeug
	# Nachbearbeitung (PostFx): Filmkorn läuft nach der Uhr — anhalten, feste Zeit
	for n in main.get_children():
		if n is CanvasLayer and n.get("mat") is ShaderMaterial:
			n.set_process(false)
			(n.get("mat") as ShaderMaterial).set_shader_parameter("time", 0.0)
	# Schwebeteilchen (Staub): Zufall und Uhr der Partikel lassen sich von außen nicht
	# festnageln (fester Startwert half nicht) — für den Vergleich ausgeblendet
	for n in b.stage.get_children():
		if n is CPUParticles2D:
			(n as CPUParticles2D).visible = false
	print("[bild] Briefing ", _station)
	for bei in _bei:
		kiosk.note_input()
		b.tz = bei
		b.t = bei
		if b.paging():
			b._seite_t = 2.0     # erste Erzählzeile ganz aufgebaut, wie nach dem Lesen
			b._blaettern_tick(0.0)
		b._entrance_tick()
		b._tick(0.0)
		b._story_tick()
		b.leben.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var img := Bildschirmbild.von(root)   # sRGB wie am Bildschirm (Forward+: linear)
		DirAccess.make_dir_recursive_absolute(_ziel)
		var name := "briefing-%s-%ss" % [_station, str(bei)]
		if _sprache != "":
			name += "-" + _sprache
		var pfad := _ziel.path_join(name + ".png")
		img.save_png(pfad)
		print("[bild] ", pfad)
	quit(0)
