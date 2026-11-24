extends SceneTree
## FRAME-MESSUNG — CPU-Zeit je Frame in einer Station, ohne Profiler-GUI:
##
##   godot --headless --path godot --fixed-fps 60 --script res://tests/frame_messung.gd -- --level=15-kontextschluessel
##
## Startet die Hauptszene, setzt Paul nacheinander an mehrere Stellen der Station
## (bei VAU-Feldern direkt hinein) und misst je Stelle 120 Frames: Mittelwert,
## 95-%-Wert und Maximum der Echtzeit pro Frame. Ohne Fenster misst das den Anteil
## von Skripten, _draw und Physik — nicht die GPU. Vorher/nachher vergleichen.

var _main: Node
var _level_id := "15-kontextschluessel"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--level="):
			_level_id = str(a).get_slice("=", 1)
	process_frame.connect(_los, CONNECT_ONE_SHOT)


func _warte(n: int) -> void:
	for i in n:
		await process_frame


func _messe(n: int) -> Dictionary:
	var werte: Array[float] = []
	var t := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var jetzt := Time.get_ticks_usec()
		werte.append((jetzt - t) / 1000.0)
		t = jetzt
	werte.sort()
	var summe := 0.0
	for w in werte:
		summe += w
	return {"mittel": summe / n, "p95": werte[int(n * 0.95)], "max": werte[n - 1]}


func _los() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _warte(5)
	# Autoloads sind im Hauptskript (--script) nicht als Bezeichner bekannt → über den Baum
	var game := root.get_node("Game")
	var kiosk := root.get_node("Kiosk")
	var tile: float = game.TILE
	var idx: int = maxi(0, (game.playlist as Array).find(_level_id))
	_main._start_level(idx)
	await _warte(40)
	var lvl = _main.level
	var stellen: Array = []
	for f in [0.1, 0.42, 0.66, 0.86]:
		stellen.append(["%d %%" % int(f * 100), Vector2(lvl.data.width * f * tile, lvl.data.world_height() - 3.0 * tile - 2.0)])
	for m in lvl.mechanics:
		if is_instance_valid(m) and m.type == "vau-feld":
			stellen.append(["VAU tx=%d" % int(m.rect.position.x / tile), Vector2(m.rect.get_center().x, m.rect.end.y - 4.0)])
	print("Station %s · %d Bausteine" % [_level_id, lvl.mechanics.size()])
	print("%-14s %8s %8s %8s" % ["Stelle", "Mittel", "95 %", "Max"])
	var gesamt := 0.0
	for s in stellen:
		kiosk.note_input()
		lvl.player.global_position = s[1]
		lvl.player.velocity = Vector2.ZERO
		await _warte(30)
		var r := await _messe(120)
		gesamt += float(r["mittel"])
		print("%-14s %6.2f ms %6.2f ms %6.2f ms" % [s[0], r["mittel"], r["p95"], r["max"]])
	print("Mittel über alle Stellen: %.2f ms/Frame" % (gesamt / stellen.size()))
	quit(0)
