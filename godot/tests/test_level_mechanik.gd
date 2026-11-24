extends "res://tests/testfall.gd"
## Verhalten im laufenden Level: verstreute Prüfsummen, Zeichen-Culling,
## Sammelziel der Station 04 (Team-Feedback 9/2026).

var main: Node


func _station(id: String) -> Node:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await frames(3)
	Kiosk.note_input()
	main._start_level(maxi(0, Game.playlist.find(id)))
	await warte_bis(func(): return main.screen == main.Screen.LEVEL and is_instance_valid(main.level) and main.level._started, 3.0)
	return main.level


func aufraeumen() -> void:
	baum.paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


func _verstreute(lvl: Node) -> Array:
	return lvl.get_children().filter(func(c): return c is Level.ScatteredBit)


func test_verstreute_pruefsummen_fallen_nicht_aus_der_welt() -> void:
	var lvl = await _station("04-die-huelle")
	if not pruefe(lvl != null, "Station 04 startet"):
		return
	# erste Grube (Boden fehlt) rechts vom Start suchen
	var grube := -1
	for x in range(8, lvl.data.width):
		if not lvl.data.is_solid(x, 20) and not lvl.data.is_solid(x, 22):
			grube = x
			break
	if not pruefe(grube > 0, "Station 04 hat eine Grube"):
		return
	var konto: int = Game.bits
	lvl._scatter_bits(Vector2((grube + 0.5) * Game.TILE, 17 * Game.TILE), 4)
	await frames(2)
	gleich(_verstreute(lvl).size(), 4, "vier verstreute Prüfsummen")
	await sekunden(3.0)
	var bits := _verstreute(lvl)
	# Wer am Rücksetzpunkt steht, sammelt die zurückgelegten gleich wieder ein
	gleich(bits.size() + (Game.bits - konto), 4, "keine geht verloren (liegend + wieder eingesammelt)")
	for b in bits:
		pruefe(b.global_position.y < lvl.data.world_height(),
			"verstreute Prüfsumme liegt in der Welt (y=%.0f)" % b.global_position.y)


func test_bausteine_ausserhalb_des_bildes_zeichnen_nicht() -> void:
	var lvl = await _station("15-kontextschluessel")
	if not pruefe(lvl != null, "Station 15 startet"):
		return
	await frames(5)
	var sicht: Rect2 = lvl.view_rect()
	var aus := 0
	for m in lvl.mechanics:
		if m.cull_rect().intersects(sicht):
			pruefe(m.visible, "%s bei x=%.0f ist im Bild, aber unsichtbar" % [m.type, m.global_position.x])
		elif not m.visible:
			aus += 1
	pruefe(aus > 10, "weit entfernte Bausteine zeichnen nicht (%d unsichtbar)" % aus)
	# ans Ende versetzen: jetzt muss das Ende sichtbar sein, der Anfang nicht
	lvl.player.global_position = Vector2((lvl.data.width - 8) * Game.TILE, lvl.data.world_height() - 3.0 * Game.TILE - 2.0)
	lvl.player.velocity = Vector2.ZERO
	await sekunden(1.0)
	sicht = lvl.view_rect()
	for m in lvl.mechanics:
		if m.cull_rect().intersects(sicht):
			pruefe(m.visible, "%s am Levelende im Bild, aber unsichtbar" % m.type)
		if m.global_position.x < 30 * Game.TILE:
			pruefe(not m.visible, "%s am Levelanfang zeichnet noch" % m.type)


func test_station_04_kein_softlock_mehr() -> void:
	var d := LevelData.load_level("04-die-huelle")
	gleich(d.count_required, 10, "Station 04 verlangt 10 Prüfsummen (vorher 14)")
	# Kein Podest am Ende höher als 3 Kacheln über dem Boden (Paul springt ~3,4)
	for x in range(140, d.width):
		var hoehe := 0
		for y in range(19, 0, -1):
			if d.char_at(x, y) == "A":
				hoehe += 1
			else:
				break
		pruefe(hoehe <= 3, "Podest bei x=%d ist %d Kacheln hoch" % [x, hoehe])
