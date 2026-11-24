extends "res://tests/testfall.gd"
## Physik-Interpolation: Paul wird zwischen zwei Physikschritten gezeichnet, damit er
## an 120/144-Hz-Monitoren nicht in 0-/9-px-Sprüngen läuft (Messung: tests/taktprobe.gd).
## Hier wird geprüft, dass die Verdrahtung stimmt: nur Paul interpoliert, die Kamera
## folgt seiner Bildposition, und Versetzen (Fahne, Start) springt statt zu gleiten.

var main: Node


func aufraeumen() -> void:
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


func test_nur_paul_wird_interpoliert() -> void:
	pruefe(bool(ProjectSettings.get_setting("physics/common/physics_interpolation")), "Physik-Interpolation im Projekt an")
	var lvl: Node = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var p: Player = lvl.player
	pruefe(p.is_physics_interpolated_and_enabled(), "Paul wird interpoliert")
	pruefe(not p.visual.is_physics_interpolated_and_enabled(), "PaulVisual nicht (Streckung im Bildtakt)")
	pruefe(not lvl.is_physics_interpolated_and_enabled(), "der Level nicht (Bausteine bewegen sich im Bildtakt)")
	pruefe(not lvl.camera.is_physics_interpolated_and_enabled(), "die Kamera nicht (folgt im Bildtakt)")
	pruefe(not lvl.rezi.is_physics_interpolated_and_enabled(), "REZI nicht")
	gleich(baum.root.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF, "Wurzel aus: auch Autoload-Overlays bleiben uninterpoliert")


func test_kamera_folgt_der_bildposition() -> void:
	var lvl: Node = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var p: Player = lvl.player
	var cam: GameCamera = lvl.camera
	p.autopilot = true
	p.auto_axis = 1.0
	await frames(20)
	var bild := p.render_position()
	pruefe(cam._ziel().is_equal_approx(bild), "Kamera-Ziel ist Pauls Bildposition (%s / %s)" % [cam._ziel(), bild])
	# Die Bildposition liegt auf der Strecke des letzten Physikschritts
	pruefe(bild.distance_to(p.global_position) <= absf(p.velocity.x) / 60.0 + 1.0,
		"Bildposition höchstens einen Physikschritt hinter der Physik (Abstand %.1f px)" % bild.distance_to(p.global_position))


func test_fahne_springt_statt_zu_gleiten() -> void:
	var lvl: Node = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var p: Player = lvl.player
	p.autopilot = true
	p.auto_axis = 1.0
	await frames(30)
	p.set_respawn(p.global_position + Vector2(-20.0 * Game.TILE, 0.0))
	p.respawn()
	pruefe(p.render_position().is_equal_approx(p.global_position), "nach dem Zurücksetzen sofort an der Fahne gezeichnet")


func test_versetzen_von_aussen_springt() -> void:
	var lvl: Node = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var p: Player = lvl.player
	await frames(5)
	# wie Kiosk-Prüflauf und Intro: Position außerhalb des Physiktakts gesetzt. Geprüft
	# wird im selben Bild, nach dem Abgleich der Transformationen und vor dem nächsten
	# Physikschritt (Timer laufen danach ab) — genau dann würde gezeichnet.
	p.global_position += Vector2(30.0 * Game.TILE, 0.0)
	await baum.create_timer(0.0).timeout
	pruefe(p.render_position().is_equal_approx(p.global_position),
		"außerhalb der Physik versetzt: Paul gleitet nicht quer durchs Bild (Abstand %.0f px)" % p.render_position().distance_to(p.global_position))
