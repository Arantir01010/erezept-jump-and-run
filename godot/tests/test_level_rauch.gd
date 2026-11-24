extends "res://tests/testfall.gd"
## RAUCHTEST: Jede Station der Playlist läuft über die echte Hauptszene
## (Main.tscn): Start, laufen, springen, Hülle wechseln, TI-Aktion, Paul an vier
## Stellen absetzen (jeder Baustein kommt einmal ins Bild), Abschluss bis zur
## Stationskarte — ohne eine einzige Fehlermeldung der Engine oder der Skripte.

var main: Node


func _main_starten() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await frames(3)


func aufraeumen() -> void:
	for a in ["move_right", "move_left", "jump", "toggle", "action", "move_down"]:
		Input.action_release(a)
	baum.paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


func _tippe(aktion: String, n := 4) -> void:
	Input.action_press(aktion)
	await frames(n)
	Input.action_release(aktion)


func _im_level() -> bool:
	return main.screen == main.Screen.LEVEL and is_instance_valid(main.level) and main.level._started


func test_alle_stationen_laufen_fehlerfrei() -> void:
	await _main_starten()
	for i in Game.playlist.size():
		var id := str(Game.playlist[i])
		Kiosk.note_input()
		main._start_level(i)
		if not pruefe(await warte_bis(_im_level, 3.0), "%s: Level startet nicht" % id):
			continue
		var lvl = main.level
		var x0: float = lvl.player.global_position.x
		# Probelauf wie ein Besucher: loslaufen, springen, Doppelsprung, Hülle, Aktion
		Input.action_press("move_right")
		await sekunden(0.9)
		await _tippe("jump", 8)
		await sekunden(0.3)
		await _tippe("jump", 4)
		await frames(10)
		await _tippe("jump", 4)
		if lvl.data.huelle_enabled:
			await _tippe("toggle")
			await sekunden(0.4)
			await _tippe("toggle")
		await _tippe("action")
		await sekunden(0.6)
		Input.action_release("move_right")
		pruefe(lvl.player.global_position.x > x0 + 48.0, "%s: Paul kommt nicht vom Start weg" % id)
		# Absetzen an vier Stellen: alle Bausteine laufen einmal sichtbar
		for frac in [0.25, 0.42, 0.66, 0.86]:
			Kiosk.note_input()
			lvl.player.global_position = Vector2(lvl.data.width * frac * Game.TILE, lvl.data.world_height() - 3.0 * Game.TILE - 2.0)
			lvl.player.velocity = Vector2.ZERO
			await sekunden(0.45)
		# Abschluss → Siegel → Stationskarte
		main.debug_finish_level()
		pruefe(await warte_bis(func(): return main.screen == main.Screen.CARD, 5.0),
			"%s: nach dem Abschluss keine Stationskarte" % id)
		pruefe(Game.seals.size() >= 1, "%s: kein Siegel vergeben" % id)
