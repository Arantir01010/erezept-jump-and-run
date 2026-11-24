extends "res://tests/testfall.gd"
## Messe-Härtung (src/autoload/Kiosk.gd, src/Main.gd, src/ui/PauseMenu.gd):
## Der Idle-Reset gilt NUR im Kiosk-Modus (--kiosk / ?kiosk=1) und löst genau
## einmal aus. Team-Feedback 9/2026: Wer am PC eine Minute den Fragebogen
## ausfüllte, landete wieder bei Station 1.

var main: Node


func aufraeumen() -> void:
	Kiosk.kiosk_mode = false
	Kiosk.note_input()
	baum.paused = false
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


func _lange_still() -> void:
	Kiosk.last_input_ms = Time.get_ticks_msec() - int((Kiosk.idle_reset_seconds + 30.0) * 1000.0)


func test_ohne_kiosk_kein_reset() -> void:
	Kiosk.kiosk_mode = false
	_lange_still()
	pruefe(not Kiosk.consume_idle_reset(), "am PC oder im Browser kein Idle-Reset")


func test_im_kiosk_genau_einmal() -> void:
	Kiosk.kiosk_mode = true
	_lange_still()
	pruefe(Kiosk.consume_idle_reset(), "im Kiosk nach Ablauf fällig")
	pruefe(not Kiosk.consume_idle_reset(), "danach nicht noch einmal (Blende läuft)")


func test_level_bleibt_am_pc_stehen_und_springt_im_kiosk_zum_titel() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await frames(3)
	main._start_level(0)
	pruefe(await warte_bis(func(): return main.screen == main.Screen.LEVEL and is_instance_valid(main.level), 3.0),
		"Level startet")
	Kiosk.kiosk_mode = false
	_lange_still()
	await frames(30)
	gleich(main.screen, main.Screen.LEVEL, "ohne Kiosk bleibt das Level stehen")
	# Pause am PC: auch das Pausemenü wirft niemanden hinaus
	main.toggle_pause()
	await frames(10)
	pruefe(main.pause_menu != null, "Pausemenü offen")
	gleich(main.screen, main.Screen.LEVEL, "ohne Kiosk bleibt die Pause stehen")
	main.toggle_pause()
	await frames(3)
	Kiosk.kiosk_mode = true
	_lange_still()
	pruefe(await warte_bis(func(): return main.screen == main.Screen.TITLE, 3.0), "im Kiosk zurück zum Titel")
