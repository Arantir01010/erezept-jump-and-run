extends "res://tests/testfall.gd"
## ZIELZEILE im HUD (Team-Feedback 9/2026, F15: „nicht immer klar, was als
## Nächstes kommt“): Unter dem Stationsnamen steht, was hier zu tun ist und was
## danach kommt — aus den Leveldaten (Sammelziel, Art des Ausgangs) und dem
## Zustand der Tür. Jede Station hat eine, sie bleibt in allen Sprachen im Bild,
## und beim Schrittwechsel hellt sie einmal auf statt zu blinken.

const SPRACHEN := ["de", "en", "fr", "es", "zh", "hi"]

var main: Node


func _station(id: String) -> Node:
	if not is_instance_valid(main):
		main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		baum.root.add_child(main)
		await frames(3)
	Kiosk.note_input()
	# Erst weiter, wenn die NEUE Station läuft (dieselbe Station noch einmal: die
	# alte bleibt bis nach der Blende stehen und wird dann freigegeben).
	# (Instanz-ID statt Knoten merken: ein freigegebener Knoten im Lambda meldet Fehler.)
	var alt: int = main.level.get_instance_id() if is_instance_valid(main.level) else 0
	main._start_level(maxi(0, Game.playlist.find(id)))
	var neu := func() -> bool: return main.screen == main.Screen.LEVEL and is_instance_valid(main.level) and main.level.get_instance_id() != alt and main.level._started and main.level.data.id == id
	await warte_bis(neu, 3.0)
	return main.level if neu.call() else null


func aufraeumen() -> void:
	Game.set_lang(Game.default_lang)
	baum.paused = false
	if is_instance_valid(main):
		main.queue_free()
	main = null
	await frames(3)


func test_regeln_der_zielzeile() -> void:
	var z := HUD.ziel(["door-exit", "gate"], 4, false, "Daten-Kacheln", "Taste E")
	gleich(z.schritt, "sammeln", "Tür zu: sammeln")
	pruefe("4" in str(z.text) and "Daten-Kacheln" in str(z.text) and "Ausgang" in str(z.text), "nennt, wie viele noch fehlen und was danach kommt: %s" % z.text)
	gleich(HUD.ziel(["door-exit"], 0, false, "x", "E").schritt, "tuer-offen", "Ziel erreicht: Ausgang offen")
	gleich(HUD.ziel(["door-exit"], 3, true, "x", "E").schritt, "tuer-offen", "Sicherheitsnetz der Tür: auch dann offen")
	var s := HUD.ziel(["stamp-exit", "gate"], 0, false, "x", "Taste E")
	pruefe(s.schritt == "stempel" and "Taste E" in str(s.text), "Stempel-Station nennt die Taste: %s" % s.text)
	gleich(HUD.ziel(["door-exit", "letzte-tuer"], 5, false, "x", "E").schritt, "letzte-tuer", "letzte Tür geht vor")
	gleich(HUD.ziel(["gate"], 0, false, "x", "E").text, "", "ohne Ausgang keine Zeile")


func test_jede_station_hat_ein_ziel() -> void:
	var erwartet := {"02-kartenterminal": "stempel", "20-souveraenitaet": "letzte-tuer"}
	for id in Game.playlist:
		var lvl = await _station(str(id))
		if not pruefe(lvl != null, "%s startet" % id):
			continue
		var hud: HUD = main.hud
		await frames(2)
		pruefe(hud.ziel_box.visible and hud.ziel_label.text != "", "%s: Zielzeile sichtbar („%s“)" % [id, hud.ziel_label.text])
		gleich(hud._ziel_schritt, erwartet.get(str(id), "sammeln"), "%s: Schritt" % id)
		if not erwartet.has(str(id)):
			var fehlt: int = lvl.data.count_required - Game.bits_this_level()
			pruefe(str(fehlt) in hud.ziel_label.text, "%s: nennt die fehlenden %d" % [id, fehlt])


func test_tuer_offen_wechselt_den_schritt_ohne_blinken() -> void:
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var hud: HUD = main.hud
	await frames(2)
	var vorher := hud.ziel_label.text
	Game.add_bits(1)
	await frames(1)
	pruefe(hud.ziel_label.text != vorher, "Zähler läuft mit: „%s“ → „%s“" % [vorher, hud.ziel_label.text])
	gleich(hud.ziel_box.modulate, Color.WHITE, "eine Prüfsumme mehr ist kein neuer Schritt (kein Aufhellen)")
	Game.add_bits(lvl.data.count_required)
	await frames(1)
	gleich(hud._ziel_schritt, "tuer-offen", "genug gesammelt: Ausgang offen")
	pruefe(hud.ziel_box.modulate.r > 1.1, "beim Schrittwechsel hellt die Zeile auf (%.2f)" % hud.ziel_box.modulate.r)
	# einmal hell, dann ruhig zurück — kein Hin und Her
	var werte: Array = []
	for i in 45:
		await frames(1)
		werte.append(hud.ziel_box.modulate.r)
	var steigt := false
	for i in range(1, werte.size()):
		if float(werte[i]) > float(werte[i - 1]) + 0.001:
			steigt = true
	pruefe(not steigt, "Aufhellen klingt nur ab, flackert nicht")
	nahe(float(werte[-1]), 1.0, 0.01, "nach 0,75 s wieder normal")


func test_zielzeile_bleibt_im_bild_in_allen_sprachen() -> void:
	var bild := Rect2(20, 10, 1920 - 40, 1080 - 20)
	for id in ["01-stammdaten", "02-kartenterminal", "20-souveraenitaet", "05-identitaet"]:
		for sprache in SPRACHEN:
			Game.set_lang(sprache)
			var lvl = await _station(id)
			if lvl == null:
				pruefe(false, "%s startet" % id)
				continue
			var hud: HUD = main.hud
			await frames(2)
			var r := hud.ziel_box.get_global_rect()
			var wo := "%s/%s" % [sprache, id]
			pruefe(bild.encloses(r), "%s: Zielzeile im Bild %s" % [wo, r])
			pruefe(r.end.x < 1400.0, "%s: Zielzeile bleibt links der Zähler-Spalte (%d)" % [wo, r.end.x])
			var name_r := (hud.station.get_parent() as Control).get_global_rect()
			pruefe(r.position.y >= name_r.end.y + 4.0, "%s: Zielzeile unter dem Stationsnamen" % wo)
			for p in [hud.bits_label.get_parent(), hud.time_label.get_parent()]:
				pruefe(not r.intersects((p as Control).get_global_rect()), "%s: überdeckt keine Zähler-Pille" % wo)
