extends "res://tests/testfall.gd"
## Bedienung (Team-Feedback 9/2026, Paket 2): Pausemenü mit „Station neu starten"
## und „Steuerung", Knopfnamen statt „Blauer Knopf", Tastenkappe an den Stationen,
## Sicherheitsnetz der Tür, selbst blättern, Stationskarte ohne Automatik,
## REZI-Sprechblasen nach Lesezeit, Sammelziel im Briefing.
##
## Vignette, Intro und Tür rechnen mit der Uhr (Time.get_ticks_msec), nicht mit
## Frames — dafür gibt es echtzeit().

var main: Node
var extra: Array = []


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
	Input.action_release("confirm")
	Game.set_lang(Game.default_lang)
	for n in extra:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


## Echtzeit abwarten (mit --fixed-fps laufen Frames schneller als die Uhr).
func echtzeit(s: float) -> void:
	var ende := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < ende:
		await baum.process_frame


func _baustein(lvl: Node, klasse: Variant) -> Node:
	for m in lvl.mechanics:
		if is_instance_of(m, klasse):
			return m
	return null


static func _taste(code: Key, gedrueckt := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = gedrueckt
	return ev


static func _tr(s: String) -> String:
	return str(TranslationServer.translate(s))


# ------------------------------------------------------------------ Pausemenü

func test_pausemenue_hat_neustart_und_steuerung() -> void:
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	main.toggle_pause()
	await frames(2)
	var pm = main.pause_menu
	if not pruefe(pm != null, "Pausemenü offen"):
		return
	gleich(pm._rows[PauseMenu.ROWS.find("neustart")].text, _tr("Station neu starten"), "Zeile „Station neu starten“")
	gleich(pm._rows[PauseMenu.ROWS.find("steuerung")].text, _tr("Steuerung"), "Zeile „Steuerung“")
	pm._activate(PauseMenu.ROWS.find("steuerung"))
	pruefe(pm.zeigt_steuerung and pm._steuerung.visible, "Steuerungstafel offen")
	pruefe(not pm._rows[0].visible, "Menüzeilen ausgeblendet, solange die Tafel steht")
	await frames(30)      # Menü ist nach 0,3 s scharf
	var ok := InputEventAction.new()
	ok.action = "confirm"
	ok.pressed = true
	pm._unhandled_input(ok)
	pruefe(not pm.zeigt_steuerung and pm._rows[0].visible, "Bestätigen schließt die Tafel")
	gleich(main.pause_menu, pm, "zurück im Pausemenü, nicht im Spiel")
	pruefe(baum.paused, "Spiel bleibt angehalten")
	main.toggle_pause()
	await frames(2)
	pruefe(not baum.paused, "Weiter setzt fort")


func test_steuerung_nennt_die_tasten_der_bedienung() -> void:
	# Am PC (keine Berührung, kein Gamepad): die TI-Aktion ist Taste E
	var touch: bool = Kiosk.touch_seen
	var forced: bool = Kiosk.touch_forced
	Kiosk.touch_seen = false
	Kiosk.touch_forced = false
	var zeilen := PauseMenu.steuerung_zeilen()
	var ti := ""
	for z in zeilen:
		if str(z[1]) == _tr("TI-Aktion an Terminal, Kartenleser und Stempel"):
			ti = str(z[0])
	if not Kiosk.has_gamepad():
		gleich(ti, "E", "am PC: TI-Aktion auf Taste E")
		gleich(BriefingDaten.tasten("Karte stecken: {action} drücken."), "Karte stecken: Taste E drücken.", "Knopfname im Text")
	gleich(BriefingDaten.tasten("ohne Knopf"), "ohne Knopf", "Text ohne {…} bleibt unverändert")
	# am Touch-Gerät: AKTION
	Kiosk.touch_forced = true
	ti = ""
	for z in PauseMenu.steuerung_zeilen():
		if str(z[1]) == _tr("TI-Aktion an Terminal, Kartenleser und Stempel"):
			ti = str(z[0])
	gleich(ti, _tr("AKTION"), "am Touch-Gerät: AKTION")
	Kiosk.touch_seen = touch
	Kiosk.touch_forced = forced


func test_knopf_am_satzanfang_wird_gross() -> void:
	# fr: „touche E en rythme …" → „Touche E en rythme …"
	Game.set_lang("fr")
	var s := BriefingDaten.text("{action} im Takt: Dr. Pixel gibt seine Arzt-PIN ein!")
	if not Kiosk.has_gamepad() and not (Kiosk.touch_seen or Kiosk.touch_forced):
		pruefe(s.begins_with("Touche E"), "Satzanfang groß: „%s“" % s)
	pruefe(not "{" in s, "kein Platzhalter übrig: „%s“" % s)


func test_stationstexte_nennen_keinen_blauen_knopf_mehr() -> void:
	for id in Game.playlist:
		var d := LevelData.load_level(str(id))
		var s := JSON.stringify(d.json)
		for alt in ["Blauer Knopf", "blauer Knopf", "Blue button", "blue button"]:
			pruefe(not alt in s, "%s: „%s“ statt {action}" % [id, alt])


# ------------------------------------------------------------------ Neustart

func test_neustart_setzt_die_station_zurueck() -> void:
	Game.reset_run()
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var bits0: int = Game.bits
	var score0: int = Game.score
	var proto0: int = Game.protokoll.size()
	Game.add_bits(5)
	Game.mark_seen("01-stammdaten", "Lauscher")
	pruefe(Game.bits_this_level() == 5 and Game.protokoll.size() == proto0 + 1, "Spielstand hat sich verändert")
	main.toggle_pause()
	await frames(2)
	main.pause_menu._activate(PauseMenu.ROWS.find("neustart"))
	pruefe(main.pause_menu == null and not baum.paused, "Pause geschlossen, Baum läuft")
	gleich(lvl.process_mode, Node.PROCESS_MODE_DISABLED, "altes Level steht während der Blende still")
	main.toggle_pause()
	pruefe(main.pause_menu == null, "während der Blende öffnet kein neues Pausemenü")
	# Das alte Level wird freigegeben — der Lambda darf es nicht einfangen, nur seine ID
	var alt := lvl.get_instance_id()
	pruefe(await warte_bis(func(): return is_instance_valid(main.level) and main.level.get_instance_id() != alt and main.level._started, 5.0),
		"neues Level läuft")
	gleich(main.screen, main.Screen.LEVEL, "direkt ins Level, ohne Briefing")
	gleich(main._level_index, Game.playlist.find("01-stammdaten"), "dieselbe Station")
	gleich(Game.bits, bits0, "Prüfsummen wie bei Stationsbeginn")
	gleich(Game.score, score0, "Punkte wie bei Stationsbeginn")
	gleich(Game.protokoll.size(), proto0, "Protokoll wie bei Stationsbeginn")
	gleich(Game.bits_this_level(), 0, "Station beginnt bei 0")
	pruefe(not main._neustart, "Neustart abgeschlossen")
	var levels: Array = main.world.get_children().filter(func(c): return c is Level and not c.is_queued_for_deletion())
	gleich(levels.size(), 1, "genau ein Level im Baum")


func test_kein_neustart_nach_dem_ziel() -> void:
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	lvl.finished = true
	main.restart_level()
	pruefe(not main._neustart, "nach dem Ziel kein Neustart")
	gleich(lvl.process_mode, Node.PROCESS_MODE_INHERIT, "Level läuft weiter")
	gleich(main.level, lvl, "dasselbe Level")
	lvl.finished = false


# ------------------------------------------------------------------ Tür

func test_tuer_oeffnet_wenn_das_ziel_unerreichbar_wird() -> void:
	Game.reset_run()
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var tuer = _baustein(lvl, Basics.DoorExit)
	if not pruefe(tuer != null, "Station 01 hat eine Tür"):
		return
	var need: int = lvl.data.count_required
	var rest: int = lvl.remaining_bits()
	pruefe(rest >= need, "genug Prüfsummen in der Station (%d ≥ %d)" % [rest, need])
	pruefe(not tuer.unlocked, "Tür zu, solange das Ziel erreichbar ist")
	# Treffer: verlorene Prüfsummen zählen sofort mit, auch bevor sie verstreut sind
	Game.add_bits(3)
	var vorher: int = lvl.remaining_bits()
	var lost: int = lvl.player.hurt(lvl.player.global_position.x + 50.0)
	gleich(lost, 3, "Treffer kostet die drei dieser Station")
	gleich(lvl.remaining_bits(), vorher + 3, "unterwegs zählen sie schon")
	await frames(2)
	gleich(lvl.remaining_bits(), vorher + 3, "verstreut zählen sie weiter")
	pruefe(not tuer.unlocked, "nach dem Treffer bleibt die Tür zu (Ziel noch erreichbar)")
	# alle bis auf need − 1 verschwinden lassen (wie in Station 04 vor dem Fix)
	for c in lvl.get_children():
		if c is Level.ScatteredBit:
			c.free()
	var weg: int = lvl.remaining_bits() - (need - 1)
	for m in lvl.mechanics:
		if weg <= 0:
			break
		if m is Basics.Collectible and not m.taken:
			m.taken = true
			weg -= 1
	gleich(lvl.remaining_bits(), need - 1, "nur noch eine zu wenig in der Station")
	pruefe(tuer.unlocked, "Sicherheitsnetz: Ziel unerreichbar → Tür offen")


func test_tuer_nennt_nach_dem_dritten_mal_den_ausweg() -> void:
	Game.reset_run()
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var tuer = _baustein(lvl, Basics.DoorExit)
	if not pruefe(tuer != null, "Station 01 hat eine Tür"):
		return
	for i in 3:
		tuer._hint_at = -100.0
		tuer._on_enter(lvl.player)
	gleich(tuer._abgewiesen, 3, "dreimal abgewiesen")
	var ausweg := _tr("Hängst du fest? %s: Pause, dann „Station neu starten“.") % Kiosk.label_pause()
	pruefe(await warte_bis(func(): return ausweg in lvl.rezi.spricht(), 15.0),
		"REZI nennt den Ausweg (spricht: „%s“)" % lvl.rezi.spricht())


# ------------------------------------------------------------------ Tastenkappe

func test_tastenkappe_an_der_station() -> void:
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	var tor = _baustein(lvl, Stations.TimingGate)
	if not pruefe(tor != null, "Station 01 hat ein Aktualisierungs-Terminal"):
		return
	var start: Vector2 = lvl.player.global_position
	pruefe(tor._kappe == null or not tor._kappe.visible, "keine Kappe, solange Paul weit weg ist")
	lvl.player.global_position = Vector2(tor.rect.get_center().x, tor.rect.end.y - 4.0)
	lvl.player.velocity = Vector2.ZERO
	pruefe(await warte_bis(func(): return tor._kappe != null and tor._kappe.a >= 1.0, 2.0), "Kappe erscheint vor dem Terminal")
	if tor._kappe != null:
		gleich(tor._kappe.text, Kiosk.label_action(), "Kappe zeigt die Aktionstaste")
	lvl.player.global_position = start
	lvl.player.velocity = Vector2.ZERO
	pruefe(await warte_bis(func(): return tor._kappe != null and not tor._kappe.visible, 2.0), "Kappe verschwindet wieder")


# ------------------------------------------------------------------ REZI

func test_rezi_spricht_nach_lesezeit() -> void:
	gleich(Rezi.lesezeit("Hallo"), Rezi.LESEN_MIN, "kurzer Satz: Mindestzeit")
	gleich(Rezi.lesezeit("x".repeat(400)), Rezi.LESEN_MAX, "langer Satz: höchstens die Obergrenze")
	nahe(Rezi.lesezeit("x".repeat(70)), 1.2 + 70.0 / Rezi.LESEN_ZEICHEN_S, 0.001, "dazwischen nach Länge")
	gleich(Rezi.lesezeit("Hallo", 4.0), 4.0, "nie kürzer als verlangt")
	var r := Rezi.new()
	baum.root.add_child(r)
	extra.append(r)
	await frames(2)
	r.say("Erster Satz.")
	r.say("Zweiter Satz.")
	gleich(r.spricht(), "Erster Satz.", "neuer Satz wartet, solange der erste frisch ist")
	r.say("Zweiter Satz.")
	gleich(r._queue.size(), 1, "derselbe Satz wartet nur einmal")
	pruefe(await warte_bis(func(): return r.spricht() == "Zweiter Satz.", 5.0), "danach kommt der zweite")
	for s in ["A1", "B2", "C3", "D4"]:
		r.say(s)
	pruefe(r._queue.size() <= Rezi.WARTEN_MAX, "höchstens %d warten" % Rezi.WARTEN_MAX)
	pruefe(await warte_bis(func(): return r.spricht() == "", 40.0), "am Ende blendet die Blase aus")


# ------------------------------------------------------------------ Blättern

func test_briefing_blaettert_selbst() -> void:
	Game.reset_run()
	var b := Briefing.new(0)
	baum.root.add_child(b)
	extra.append(b)
	await frames(2)
	if not pruefe(b.paging(), "Briefing blättert selbst"):
		return
	var n := b.story.size()
	pruefe(n >= 2, "mehrere Erzählzeilen (%d)" % n)
	var fertig := [false]
	b.done.connect(func(): fertig[0] = true)
	await sekunden(BriefingDaten.TAKT + 1.0)
	gleich(b.seite, 0, "ohne Knopf bleibt die erste Zeile stehen")
	var u: float = b.story_u()
	pruefe(u >= float(b.story[0]["von"]) and u < float(b.story[0]["bis"]), "Bühne läuft im Abschnitt der Zeile")
	await echtzeit(0.3)      # Schonzeit gegen den Druck vom Screen davor
	b._voll = false
	b._unhandled_input(_taste(KEY_RIGHT))
	gleich(b.seite, 0, "erster Druck zeigt die ganze Zeile")
	pruefe(b._voll, "Zeile ganz aufgebaut")
	b._unhandled_input(_taste(KEY_RIGHT, false))
	b._unhandled_input(_taste(KEY_RIGHT))
	gleich(b.seite, 1, "zweiter Druck blättert vor")
	b._unhandled_input(_taste(KEY_RIGHT, false))
	b._unhandled_input(_taste(KEY_LEFT))
	gleich(b.seite, 0, "← blättert zurück")
	b._unhandled_input(_taste(KEY_LEFT, false))
	for i in n * 2 + 2:
		if fertig[0]:
			break
		b.vor()
	pruefe(fertig[0], "nach der letzten Zeile geht es weiter")


func test_halten_ueberspringt_den_screen() -> void:
	var b := Briefing.new(0)
	baum.root.add_child(b)
	extra.append(b)
	await frames(2)
	await echtzeit(0.3)
	var fertig := [false]
	b.done.connect(func(): fertig[0] = true)
	# kurz drücken: blättert, überspringt nicht
	Input.action_press("confirm")
	b._unhandled_input(_taste(KEY_SPACE))
	await echtzeit(0.3)
	Input.action_release("confirm")
	b._unhandled_input(_taste(KEY_SPACE, false))
	await echtzeit(Vignette.HALTEN_S)
	pruefe(not fertig[0], "kurzer Druck überspringt nicht")
	# halten: nach HALTEN_S ist der Screen übersprungen
	Input.action_press("confirm")
	b._unhandled_input(_taste(KEY_SPACE))
	await echtzeit(Vignette.HALTEN_S + 0.3)
	pruefe(fertig[0], "gehalten: Screen übersprungen")
	Input.action_release("confirm")


func test_probelauf_zeigt_die_ti_aktion() -> void:
	var intro := Intro.new(3)
	baum.root.add_child(intro)
	extra.append(intro)
	await echtzeit(Intro.TI_DRUCK + 0.6)
	# Mitmachen (Messe-Paket 2): Paul wartet am Terminal auf den Spieler
	gleich(intro._warte, "action", "Probelauf wartet auf die TI-Aktion des Spielers")
	pruefe(intro._ti_t < 0.0, "ohne Druck noch keine TI-Aktion")
	Input.action_press("action")
	await frames(2)
	Input.action_release("action")
	await echtzeit(0.3)
	pruefe(intro._ti_t >= 0.0, "nach dem Druck: TI-Aktion am Terminal")
	pruefe(intro._ti_popup.modulate.a > 0.5, "Tafel „TI-AKTION“ ist zu sehen")
	if not Kiosk.has_gamepad() and not (Kiosk.touch_seen or Kiosk.touch_forced):
		gleich(intro._ti_popup.tasten, ["E"], "am PC mit Taste E")


func test_briefing_nennt_das_echte_sammelziel() -> void:
	for i in Game.playlist.size():
		var b := Briefing.new(i)
		var s := b.tust_text()
		pruefe(not ("{" in s or "}" in s), "Station %d: Platzhalter übrig in „%s“" % [i + 1, s])
		b.free()
	var idx := Game.playlist.find("01-stammdaten")
	var ld := LevelData.load_level("01-stammdaten")
	var b1 := Briefing.new(idx)
	var ziel := "%d %s" % [ld.count_required, Game.t(ld.collect_label)]
	pruefe(ziel in b1.tust_text(), "Station 1 nennt „%s“: %s" % [ziel, b1.tust_text()])
	b1.free()


# ------------------------------------------------------------------ Stationskarte

func test_stationskarte_wartet_auf_den_spieler() -> void:
	var lvl = await _station("01-stammdaten")
	if not pruefe(lvl != null, "Station 01 startet"):
		return
	main.debug_finish_level()
	pruefe(await warte_bis(func(): return main.screen == main.Screen.CARD and is_instance_valid(main._current), 6.0), "Stationskarte erscheint")
	var karte = main._current
	await sekunden(9.0)      # früher ging es nach 6 s von selbst weiter
	if not gleich(main.screen, main.Screen.CARD, "Karte bleibt stehen, bis jemand drückt") or not is_instance_valid(karte):
		return
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(960, 540)
	karte._input(tap)
	pruefe(await warte_bis(func(): return main.screen != main.Screen.CARD, 5.0), "Fingertipp geht weiter")
