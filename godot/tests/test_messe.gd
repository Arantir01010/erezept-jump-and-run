extends "res://tests/testfall.gd"
## Messe-Paket (11/2026): Bedienwahl im Titel, Ton im Kiosk, Busse/Limiter,
## Lautstärke, Rücksetzen nach Sturz, Fahnen-Abstände, Bestenliste, Abschluss-Badges.

const HS := "user://highscore.json"

var main: Node
var _hs_alt := ""
var _hs_da := false
var _seals_alt: Array = []
var _vol_alt := 1.0


func aufraeumen() -> void:
	Kiosk.kiosk_mode = false
	Kiosk.touch_seen = false
	Kiosk.touch_forced = false
	Kiosk.note_input()
	Sfx.reset_visitor_choices()
	baum.paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


func _station(id: String) -> Node:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await frames(3)
	Kiosk.note_input()
	main._start_level(maxi(0, Game.playlist.find(id)))
	await warte_bis(func(): return main.screen == main.Screen.LEVEL and is_instance_valid(main.level) and main.level._started, 3.0)
	return main.level


# ---------------------------------------------------------------- Bedienwahl

func test_ohne_touchscreen_kein_touch_per_stick() -> void:
	Kiosk.touch_seen = false
	Kiosk.touch_forced = false
	pruefe(not Kiosk.touch_possible(), "ohne Berührung/Touchscreen ist Touch nicht wählbar")
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await frames(5)
	await warte_bis(func(): return main._current is Title, 3.0)
	var title: Node = main._current
	if not pruefe(title != null and is_instance_valid(title), "Titel ist da"):
		return
	title.mode = "keyboard"
	var ev := InputEventAction.new()
	ev.action = "move_right"
	ev.pressed = true
	title._unhandled_input(ev)
	gleich(str(title.mode), "keyboard", "Stick nach rechts lässt Tastatur/Arcade stehen")
	Kiosk.touch_seen = true
	title._unhandled_input(ev)
	gleich(str(title.mode), "touch", "mit Touchscreen wählt rechts weiterhin Touch")


# ---------------------------------------------------------------- Ton

func test_busse_und_begrenzer() -> void:
	pruefe(AudioServer.get_bus_index("Musik") > 0, "Bus Musik existiert")
	pruefe(AudioServer.get_bus_index("SFX") > 0, "Bus SFX existiert")
	var master := AudioServer.get_bus_index("Master")
	var lim := false
	for i in AudioServer.get_bus_effect_count(master):
		lim = lim or AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter
	pruefe(lim, "Master hat einen Begrenzer")
	gleich(Sfx._music.bus, &"Musik", "Musik läuft über den Musik-Bus")
	gleich(Sfx._pool[0].bus, &"SFX", "Klänge laufen über den SFX-Bus")


func test_klaenge_sind_vorgeladen() -> void:
	for n in Sfx.PRELOAD:
		pruefe(Sfx._streams.has(n), "Klang vorgeladen: " + n)
	pruefe(Sfx._streams.has("music_level@loop"), "Level-Musik vorgeladen (Schleife)")
	pruefe(Sfx._stream("music_title", true) is AudioStreamOggVorbis, "Musik kommt als OGG")


func test_lautstaerke_in_stufen() -> void:
	_vol_alt = Sfx.volume
	Sfx.volume = 0.5
	nahe(Sfx.change_volume(-0.1), 0.4, 0.001, "Strg+F9: 10 % leiser")
	for i in 12:
		Sfx.change_volume(0.1)
	nahe(Sfx.volume, 1.0, 0.001, "höchstens 100 %")
	Sfx.volume = _vol_alt
	Sfx.change_volume(0.0)


func test_kiosk_besucher_kann_nicht_dauerhaft_stumm_schalten() -> void:
	Kiosk.kiosk_mode = true
	pruefe(not Sfx._persist_visitor_choices(), "im Kiosk wird die Besucherwahl nicht gespeichert")
	Sfx.set_sound(false)
	Sfx.set_music(false)
	Kiosk.last_input_ms = Time.get_ticks_msec() - int((Kiosk.idle_reset_seconds + 30.0) * 1000.0)
	pruefe(Kiosk.consume_idle_reset(), "Idle-Reset fällig")
	pruefe(Sfx.sound_on and Sfx.music_on, "nach dem Idle-Reset sind Musik und Töne wieder an")
	Kiosk.kiosk_mode = false
	pruefe(Sfx._persist_visitor_choices(), "am PC/Browser bleibt die Wahl gespeichert")


func test_voller_pool_ueberschreibt_den_aeltesten() -> void:
	if not Sfx.enabled:
		return
	var alt := Sfx.sound_on
	Sfx.sound_on = true
	for i in Sfx.POOL_SIZE:
		Sfx.play("seal", 1.0, -60.0)
	var alle_laufen := Sfx._pool.all(func(p): return p.playing)
	if alle_laufen:
		var spaet := Time.get_ticks_msec() + 100000
		for i in Sfx.POOL_SIZE:
			Sfx._started_ms[i] = spaet   # künstliche Startzeiten: Platz 3 ist der älteste
		Sfx._started_ms[3] = 0
		Sfx.play("tick", 1.0, -60.0)
		pruefe(Sfx._started_ms[3] != 0, "der am längsten laufende Klang (Platz 3) wurde ersetzt")
		pruefe(Sfx._started_ms[0] == spaet, "Platz 0 bleibt, wenn er nicht der älteste ist")
	for p in Sfx._pool:
		p.stop()
	Sfx.sound_on = alt


func test_kiosk_sperrt_f11_f12() -> void:
	Kiosk.kiosk_mode = true
	var vorher := DirAccess.get_files_at("user://").size()
	var k := InputEventKey.new()
	k.physical_keycode = KEY_F12
	k.pressed = true
	Kiosk._handle_operator_key(k)
	gleich(DirAccess.get_files_at("user://").size(), vorher, "F12 legt im Kiosk keinen Screenshot an")


# ---------------------------------------------------------------- Rücksetzen

func test_sturz_blendet_auf_und_kamera_sitzt_sofort() -> void:
	var lvl: Node = await _station("14-die-vau")
	if not pruefe(lvl != null, "Station 14 läuft"):
		return
	var p: Player = lvl.player
	var cp := Vector2(10 * Game.TILE, p.global_position.y)
	p.set_respawn(cp)
	p.global_position = Vector2(150 * Game.TILE, p.world_bottom + 400.0)
	await frames(2)
	nahe(p.global_position.x, cp.x, 1.0, "Paul steht wieder an der Fahne")
	pruefe(p.is_invulnerable, "kurze Schonzeit nach dem Zurücksetzen")
	var cam: Camera2D = lvl.camera
	pruefe(absf(cam.global_position.x - p.global_position.x) < 400.0,
		"Kamera sitzt sofort bei Paul (Abstand %.0f px)" % absf(cam.global_position.x - p.global_position.x))


func test_fahnen_hoechstens_35_kacheln_auseinander() -> void:
	for id in Game.playlist:
		var data := LevelData.load_level(str(id))
		var xs: Array[int] = []
		for y in data.rows.size():
			var row := str(data.rows[y])
			for x in row.length():
				if row[x] in ["P", "C", "D"]:
					if not xs.has(x):
						xs.append(x)
		xs.sort()
		var groesste := 0
		for i in range(1, xs.size()):
			groesste = maxi(groesste, xs[i] - xs[i - 1])
		pruefe(groesste <= 35, "%s: größter Fahnen-Abstand %d Kacheln" % [id, groesste])


# ---------------------------------------------------------------- Bestenliste

func _hs_sichern() -> void:
	_hs_da = FileAccess.file_exists(HS)
	_hs_alt = FileAccess.get_file_as_string(HS) if _hs_da else ""


func _hs_zurueck() -> void:
	if _hs_da:
		var f := FileAccess.open(HS, FileAccess.WRITE)
		f.store_string(_hs_alt)
	elif FileAccess.file_exists(HS):
		DirAccess.remove_absolute(HS)


func test_kaputte_bestenliste_bricht_nichts_ab() -> void:
	_hs_sichern()
	var f := FileAccess.open(HS, FileAccess.WRITE)
	f.store_string(JSON.stringify({"date": Game._today(), "entries": [
		{"avatar": 2, "score": 50}, {"score": "viel"}, "Unsinn", {"avatar": 1}, {"avatar": -4, "score": 90},
	]}))
	f.close()
	var hs := Game.highscores()
	gleich(hs.size(), 2, "nur gültige Einträge")
	gleich(int(hs[0]["score"]), 90, "sortiert nach Punkten")
	pruefe(Game.qualifies(10), "qualifies stürzt nicht ab")
	Game.add_highscore(3, 70)
	gleich(Game.highscores().size(), 3, "Eintrag hinzugefügt")
	pruefe(not FileAccess.file_exists(HS + ".tmp"), "keine Zwischendatei übrig")
	_hs_zurueck()


# ---------------------------------------------------------------- Abschluss

func test_abschluss_zeigt_badges() -> void:
	_seals_alt = Game.seals.duplicate(true)
	Game.seals = [
		{"seal_id": "a", "level_id": "01-stammdaten"},
		{"seal_id": "b", "level_id": "04-die-huelle"},
		{"seal_id": "c", "level_id": "20-souveraenitaet"},
	]
	var b := Reward.seal_badges()
	pruefe(b.has(TranslationServer.translate("VSDM")), "Badge Station 01")
	pruefe(b.has(TranslationServer.translate("Vertraulichkeit")), "Badge Station 04")
	gleich(b.size(), 2, "reines Welt-Etikett der Station 20 bleibt weg")
	Game.seals = _seals_alt
