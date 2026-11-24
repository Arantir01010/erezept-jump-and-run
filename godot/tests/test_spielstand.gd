extends "res://tests/testfall.gd"
## Spielstand (src/autoload/Game.gd): Prüfsummen-Konto, Treffer, Medaillen.
## Jeder Test beginnt mit Game.reset_run() — Game ist ein Autoload mit globalem Zustand.


func test_treffer_zu_levelbeginn_kostet_nichts() -> void:
	# Team-Feedback 9/2026: Wer zu Beginn eines Levels getroffen wurde, sah weiter 0,
	# die nächsten bis zu 5 Prüfsummen zählten aber unsichtbar nicht mit.
	Game.reset_run()
	Game.add_bits(20)          # aus früheren Stationen
	Game.mark_level_start()
	gleich(Game.lose_bits(5), 0, "Verlust direkt nach Levelstart")
	gleich(Game.bits, 20, "Konto aus früheren Stationen bleibt unangetastet")
	gleich(Game.bits_this_level(), 0, "Stand dieser Station")
	Game.add_bits(1)
	gleich(Game.bits_this_level(), 1, "die erste neue Prüfsumme zählt sofort (keine versteckte Schuld)")


func test_treffer_kostet_hoechstens_fuenf_dieser_station() -> void:
	Game.reset_run()
	Game.add_bits(10)
	Game.mark_level_start()
	Game.add_bits(3)
	gleich(Game.lose_bits(5), 3, "nur die 3 dieser Station gehen verloren")
	gleich(Game.bits_this_level(), 0, "danach 0 in dieser Station")
	gleich(Game.bits, 10, "Konto früherer Stationen bleibt")
	Game.add_bits(8)
	gleich(Game.lose_bits(5), 5, "höchstens 5 je Treffer")
	gleich(Game.bits_this_level(), 3, "Rest dieser Station")


func test_treffer_beendet_die_kombo() -> void:
	Game.reset_run()
	Game.mark_level_start()
	Game.add_bits(1)
	Game.add_bits(1)
	pruefe(Game.combo >= 2, "Kombo läuft")
	Game.lose_bits(5)
	gleich(Game.combo, 0, "Kombo nach Treffer")


func test_medaillen_beim_abschluss() -> void:
	Game.reset_run()
	Game.mark_level_start()
	Game.add_bits(4)
	var r := Game.finish_level("test-station", 20.0, 30.0, 4)
	pruefe(r["medals"]["zeit"], "Zeit-Medaille unter Par")
	pruefe(r["medals"]["bits"], "alle Prüfsummen")
	pruefe(r["medals"]["lueckenlos"], "lückenlos ohne Lauscher-Treffer")
	Game.mark_level_start()
	Game.mark_seen("test-station-2", "Lauscher")
	var r2 := Game.finish_level("test-station-2", 40.0, 30.0, 4)
	pruefe(not r2["medals"]["zeit"], "keine Zeit-Medaille über Par")
	pruefe(not r2["medals"]["bits"], "keine Prüfsummen-Medaille ohne Prüfsummen")
	pruefe(not r2["medals"]["lueckenlos"], "mitgelesen → nicht lückenlos")


func test_karte_stecken_und_belegt() -> void:
	Game.reset_run()
	gleich(Game.insert_card(["egk"], "t1")["result"], "nicht-dabei", "ohne Karte")
	Game.add_card("smcb")
	gleich(Game.insert_card(["egk"], "t1")["result"], "falsche-karte", "falsche Karte")
	Game.add_card("egk")
	gleich(Game.insert_card(["egk"], "t1")["result"], "ok", "passende Karte")
	gleich(Game.insert_card(["egk"], "t2")["result"], "belegt", "Karte steckt schon in t1")
	Game.remove_card_from("t1")
	gleich(Game.insert_card(["egk"], "t2")["result"], "ok", "nach dem Ziehen wieder frei")
