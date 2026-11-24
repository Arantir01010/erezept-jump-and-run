extends "res://tests/testfall.gd"
## Lesbarkeit (Optik-Analyse und Team-Feedback 9/2026, Paket 3): HUD-Spalte im
## Bild, Zeit in PwC-Farbe, Störfelder deckend und ruhig, Lauscher-Kegel warnt nur
## im Klartext, nichts blinkt schneller als 3 Hz (KAPSEL-Leitplanke).

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


func _baustein(lvl: Node, klasse: Variant) -> Node:
	for m in lvl.mechanics:
		if is_instance_of(m, klasse):
			return m
	return null


## Wechsel pro Sekunde einer Größe, die um `mitte` schwingt (zwei Wechsel = eine Periode).
static func _hz(werte: Array, mitte: float, dauer_s: float) -> float:
	var wechsel := 0
	for i in range(1, werte.size()):
		if (float(werte[i - 1]) - mitte) * (float(werte[i]) - mitte) < 0.0:
			wechsel += 1
	return wechsel / 2.0 / dauer_s


func test_hud_spalte_bleibt_im_bild() -> void:
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var hud: HUD = main.hud
	await frames(2)
	var bild := Rect2(0, 0, 1920, 1080)
	var pillen := {"Prüfsummen": hud.bits_label.get_parent(), "Punkte": hud.score_label.get_parent(), "Zeit": hud.time_label.get_parent()}
	for name in pillen:
		var r: Rect2 = (pillen[name] as Control).get_global_rect()
		pruefe(bild.encloses(r) and r.end.x <= 1920.0 - 20.0, "%s-Pille im Bild (%s)" % [name, r])
	var bits: Rect2 = (pillen["Prüfsummen"] as Control).get_global_rect()
	var punkte: Rect2 = (pillen["Punkte"] as Control).get_global_rect()
	pruefe(not bits.intersects(punkte), "Prüfsummen- und Punkte-Pille überlappen nicht")
	pruefe(not hud.pause_btn.get_global_rect().intersects(bits), "Pause-Knopf überlappt die Zähler nicht")
	# langer Text wächst nach links, nicht aus dem Bild
	hud.score_label.text = "1 234 567 890 P"
	await frames(2)
	pruefe((pillen["Punkte"] as Control).get_global_rect().end.x <= 1920.0, "lange Punktzahl bleibt im Bild")
	# Zeit unter Par in PwC-Gelb
	var farbe: Color = hud.time_label.get_theme_color("font_color")
	pruefe(farbe.is_equal_approx(Brand.UI_HIGHLIGHT), "Zeit unter Par in PwC-Gelb (ist %s)" % farbe)


func test_stoerfeld_ruhig_und_deckend() -> void:
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var spike = _baustein(lvl, Basics.Spike)
	if not pruefe(spike != null, "Station 01 hat Störfelder"):
		return
	pruefe(spike._schraffur.size() >= 3, "Sockel mit Warnschraffur")
	var werte: Array = []
	for i in 180:            # 3 s Spielzeit
		werte.append(spike._puls)
		await baum.process_frame
	var lo: float = werte.min()
	var hi: float = werte.max()
	pruefe(lo >= 0.849 and hi <= 1.151, "Puls höchstens ±15 %% (%.2f … %.2f)" % [lo, hi])
	var hz := _hz(werte, 1.0, 3.0)
	pruefe(hz <= 2.0, "Puls langsam: %.1f Hz (≤ 2 Hz, Grenze 3 Hz)" % hz)


func test_paul_blinkt_unter_3_hz() -> void:
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var vis = lvl.player.visual
	vis.blink_left = 5.0
	# Das Blinken läuft in Spielzeit — 2 s Spielzeit beobachten (120 Frames bei --fixed-fps 60)
	var werte: Array = []
	for i in 120:
		werte.append(vis.modulate.a)
		await baum.process_frame
	vis.blink_left = 0.0
	var hz := _hz(werte, 0.7, 2.0)
	pruefe(hz > 0.5, "Paul blinkt nach einem Treffer (%.1f Hz)" % hz)
	pruefe(hz <= 3.0, "Blinken höchstens 3 Hz (ist %.1f Hz)" % hz)


func test_lauscher_warnt_nur_im_klartext() -> void:
	var lvl = await _station("04-die-huelle")
	if not pruefe(lvl != null, "Station 04 startet"):
		return
	var lauscher = _baustein(lvl, Stations.Lauscher)
	if not pruefe(lauscher != null, "Station 04 hat Lauscher"):
		return
	var huelle: Huelle = lvl.player.huelle
	gleich(huelle.state, Huelle.KLARTEXT, "Paul startet im Klartext")
	await frames(30)
	pruefe(lauscher._warn >= 0.99, "im Klartext: Kegel warnt (warm, mit Kontur)")
	pruefe(await warte_bis(func(): return huelle.toggle(), 2.0), "Hülle an")
	pruefe(await warte_bis(func(): return lauscher._warn <= 0.01, 1.0), "verschlüsselt: Kegel blass und neutral")
	var licht: Color = lauscher._cone_light.color
	pruefe(licht.is_equal_approx(Stations.Lauscher.NEUTRAL), "Kegellicht neutral statt warm (ist %s)" % licht)
	pruefe(await warte_bis(func(): return huelle.toggle(), 2.0), "Hülle aus")
	pruefe(await warte_bis(func(): return lauscher._warn >= 0.99, 1.0), "zurück im Klartext: Kegel warnt wieder")
