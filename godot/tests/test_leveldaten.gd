extends "res://tests/testfall.gd"
## Leveldaten (src/core/LevelData.gd + levels/<id>/): jede Station der Playlist
## lädt fehlerfrei, ist spielbar aufgebaut und kennt nur Bausteine, die es gibt.

const HUELLE_TYPEN := ["lauscher", "andock-plattform", "vau-feld", "kontext-anker"]


func test_playlist_ist_nicht_leer() -> void:
	pruefe(Game.playlist.size() >= 1, "config/playlist.json enthält Stationen")
	var doppelt := {}
	for id in Game.playlist:
		pruefe(not doppelt.has(id), "Station %s doppelt in der Playlist" % id)
		doppelt[id] = true


func test_jede_station_laedt_fehlerfrei() -> void:
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		pruefe(d.errors.is_empty(), "%s: %s" % [id, ", ".join(d.errors)])
		gleich(d.height, Game.GRID_HEIGHT, "%s: Zeilen im Layout" % id)
		pruefe(d.width >= 40, "%s: mindestens eine Bildschirmbreite" % id)
		pruefe(LevelData.level_dir(str(id)).begins_with("res://levels/%s" % id),
			"%s: Godot-eigene Fassung unter levels/ (nicht nur _import)" % id)
		pruefe(d.par_time > 0.0, "%s: Par-Zeit" % id)
		pruefe(str(d.station.get("name", {}).get("de", "")) != "", "%s: Stationsname (de)" % id)


func test_genau_ein_start_und_ein_ausgang() -> void:
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		var starts := 0
		var tueren := 0
		for m in d.markers:
			if m["type"] == "spawn":
				starts += 1
			elif m["type"] == "door-exit":
				tueren += 1
		for o in d.objects:
			if str(o["type"]) in ["stamp-exit", "letzte-tuer"]:
				tueren += 1
		gleich(starts, 1, "%s: Startpunkte" % id)
		pruefe(tueren >= 1, "%s: kein Ausgang (Tür, Stempel oder letzte Tür)" % id)


func test_sammelziel_ist_erreichbar() -> void:
	# Die Tür darf nie mehr verlangen, als im Level liegt — sonst Softlock.
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		pruefe(d.count_required <= d.bits_total,
			"%s: Tür verlangt %d, im Level liegen nur %d" % [id, d.count_required, d.bits_total])
		pruefe(d.count_required >= 0, "%s: Sammelziel negativ" % id)


func test_nur_bekannte_bausteine() -> void:
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		for o in d.objects:
			var t := str(o["type"])
			pruefe(Level.REGISTRY.has(t) or Stations.REGISTRY.has(t), "%s: unbekannter Baustein '%s'" % [id, t])


func test_huelle_bausteine_nur_in_huelle_leveln() -> void:
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		for o in d.objects:
			if str(o["type"]) in HUELLE_TYPEN:
				pruefe(d.huelle_enabled, "%s: '%s' ohne eingeschaltete Hülle" % [id, o["type"]])


func test_tore_haben_oeffner() -> void:
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		var tore := {}
		var oeffner := {}
		for o in d.objects:
			if str(o["type"]) == "gate":
				tore[str(o.get("name", ""))] = o
			elif o.has("gate"):
				oeffner[str(o["gate"])] = o
		for n in tore:
			pruefe(oeffner.has(n), "%s: Tor '%s' hat keinen Öffner" % [id, n])
