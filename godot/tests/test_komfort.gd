extends "res://tests/testfall.gd"
## „Bewegung reduzieren" (src/core/Komfort.gd): Pausemenü-Schalter, keine Kamera- und
## Zoom-Stöße, gespeichert am PC/Browser, im Messe-Kiosk nur für den laufenden Besucher.

const TESTDATEI := "user://test-komfort.cfg"

var main: Node


func aufraeumen() -> void:
	Komfort._ruhig = false
	Komfort._geladen = false
	Komfort.datei_override = ""
	if FileAccess.file_exists(TESTDATEI):
		DirAccess.remove_absolute(TESTDATEI)
	Kiosk.kiosk_mode = false
	Kiosk.note_input()
	Sfx.reset_visitor_choices()
	baum.paused = false
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


func _tr(s: String) -> String:
	return str(TranslationServer.translate(s))


func test_kamera_ohne_stoesse() -> void:
	var cam := GameCamera.new()
	baum.root.add_child(cam)
	Komfort.besucher_zuruecksetzen()
	cam.kick(Vector2(0, 90))
	cam.punch(0.12)
	pruefe(cam._kick_vel.length() > 1.0, "normal: Kamerastoß wirkt")
	pruefe(cam._zoom_extra > 0.1, "normal: Zoom-Stoß wirkt")
	cam._kick_vel = Vector2.ZERO
	cam._zoom_extra = 0.0
	Komfort.setze_bewegung_reduziert(true)
	cam.kick(Vector2(0, 90))
	cam.punch(0.12)
	gleich(cam._kick_vel, Vector2.ZERO, "reduziert: kein Kamerastoß")
	gleich(cam._zoom_extra, 0.0, "reduziert: kein Zoom-Stoß")
	cam.queue_free()


func test_schalter_im_pausemenue() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await frames(3)
	Kiosk.note_input()
	main._start_level(maxi(0, Game.playlist.find("01-stammdaten")))
	await warte_bis(func(): return main.screen == main.Screen.LEVEL and is_instance_valid(main.level) and main.level._started, 3.0)
	main.toggle_pause()
	await frames(2)
	var pm = main.pause_menu
	if not pruefe(pm != null, "Pausemenü offen"):
		return
	var zeile: int = PauseMenu.ROWS.find("bewegung")
	if not pruefe(zeile >= 0, "Zeile „Bewegung reduzieren“ vorhanden"):
		return
	gleich(pm._rows[zeile].text, _tr("Bewegung reduzieren: aus"), "steht anfangs auf aus")
	pm._activate(zeile)
	pruefe(Komfort.bewegung_reduziert(), "nach dem Wählen reduziert")
	gleich(pm._rows[zeile].text, _tr("Bewegung reduzieren: an"), "Zeile zeigt „an“")
	pm._activate(zeile)
	pruefe(not Komfort.bewegung_reduziert(), "zweites Wählen schaltet zurück")


func test_gespeichert_am_pc_nicht_im_kiosk() -> void:
	Komfort.datei_override = TESTDATEI
	Komfort._geladen = false
	Komfort.setze_bewegung_reduziert(true)
	var cf := ConfigFile.new()
	pruefe(cf.load(TESTDATEI) == OK and bool(cf.get_value("komfort", "bewegung_reduziert", false)), "am PC gespeichert")
	# neu laden wie nach einem Neustart des Spiels
	Komfort._geladen = false
	Komfort._ruhig = false
	pruefe(Komfort.bewegung_reduziert(), "nach dem Neustart wieder reduziert")
	# Messe-Kiosk: nicht speichern, beim Idle-Reset zurück auf volle Bewegung
	Kiosk.kiosk_mode = true
	Komfort.setze_bewegung_reduziert(false)
	cf = ConfigFile.new()
	cf.load(TESTDATEI)
	pruefe(bool(cf.get_value("komfort", "bewegung_reduziert", false)), "im Kiosk wird die Besucherwahl nicht gespeichert")
	Komfort.setze_bewegung_reduziert(true)
	Kiosk.last_input_ms = Time.get_ticks_msec() - int((Kiosk.idle_reset_seconds + 30.0) * 1000.0)
	pruefe(Kiosk.consume_idle_reset(), "Idle-Reset fällig")
	pruefe(not Komfort.bewegung_reduziert(), "nach dem Idle-Reset wieder volle Bewegung")


func test_testlauf_schreibt_keine_einstellungen() -> void:
	Komfort._geladen = false
	pruefe(not Komfort._speichern_erlaubt(), "Testläufe schreiben nicht in user://einstellungen.cfg")
