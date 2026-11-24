extends "res://tests/testfall.gd"
## Spielzeit statt Wanduhr: Kombo-Fenster und Laufzeit (Game.spielzeit) und die
## Bildschirme (Vignette.t/tz) laufen im Spieltakt. Pause oder echte Wartezeit
## verschieben nichts, und mit --fixed-fps ergibt derselbe Ablauf dieselben Zahlen.
## Gegenprobe: Mit der alten Wanduhr (Time.get_ticks_msec) scheitern die ersten vier,
## mit dem alten 50-ms-Fenster im Titel der fünfte.

var main: Node


func aufraeumen() -> void:
	baum.paused = false
	Game.reset_run()
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


## Echte Zeit vergehen lassen, ohne dass das Spiel einen Schritt macht.
func _wanduhr_warten(s: float) -> void:
	OS.delay_msec(int(s * 1000.0))


func test_kombo_ueberdauert_die_pause() -> void:
	Game.reset_run()
	Game.add_bits(1)
	gleich(Game.combo, 1, "das erste Bit startet die Kombo")
	baum.paused = true
	await frames(2)
	_wanduhr_warten(Game.COMBO_WINDOW + 0.3)
	await frames(2)
	baum.paused = false
	Game.add_bits(1)
	gleich(Game.combo, 2, "nach der Pause zählt die Kombo weiter")


func test_kombo_endet_nach_dem_fenster_in_spielzeit() -> void:
	Game.reset_run()
	Game.add_bits(1)
	await frames(int(ceil(Game.COMBO_WINDOW * 60.0)) + 6)
	Game.add_bits(1)
	gleich(Game.combo, 1, "nach 1,1 s Spielzeit beginnt eine neue Kombo, auch wenn kaum echte Zeit verging")


func test_laufzeit_ohne_pause() -> void:
	Game.reset_run()
	await frames(60)
	var vorher := Game.elapsed_seconds()
	nahe(vorher, 1.0, 0.04, "60 Bilder bei --fixed-fps 60 sind 1 s Laufzeit")
	baum.paused = true
	_wanduhr_warten(0.5)
	await frames(30)
	baum.paused = false
	nahe(Game.elapsed_seconds(), vorher, 0.001, "die Pause zählt nicht zur Laufzeit")


func test_bildschirme_laufen_in_spielzeit() -> void:
	var v := Vignette.new()
	baum.root.add_child(v)
	await frames(2)
	var t0: float = v.tz
	_wanduhr_warten(0.4)
	await frames(60)
	nahe(v.tz - t0, 1.0, 0.04, "60 Bilder sind 1 s auf dem Bildschirm, echte Wartezeit zählt nicht")
	var t1: float = v.tz
	baum.paused = true
	await frames(30)
	baum.paused = false
	nahe(v.tz, t1, 0.001, "in der Pause steht der Bildschirm")
	v.queue_free()


func test_titel_dreht_paul_einmal_je_takt() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await warte_bis(func() -> bool: return main.get("_current") is Title, 3.0)
	var angezeigt: Variant = main.get("_current")
	if not pruefe(angezeigt is Title, "Titel angezeigt"):
		return
	var titel: Title = angezeigt
	if not pruefe(titel.player != null, "Titel mit Paul"):
		return
	titel.set_process(false)   # die Zeit setzt der Test
	for hz: int in [60, 120, 144]:
		titel._dreh_takt = 0
		titel.tz = 0.0         # keine REZI-Sprüche dazwischen
		var richtung: int = titel.player.facing
		var drehungen := 0
		for i in 13 * hz:      # 13 s: Taktwechsel bei 6 s und 12 s
			titel.t = float(i) / hz
			titel._tick(1.0 / hz)
			if titel.player.facing != richtung:
				drehungen += 1
				richtung = titel.player.facing
		gleich(drehungen, 2, "%d Hz: in 13 s genau zwei Drehungen" % hz)
