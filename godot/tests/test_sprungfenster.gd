extends "res://tests/testfall.gd"
## Coyote-Zeit und Sprungpuffer (src/state/SprungFenster.gd) — ohne Szene, ohne Uhr:
## jeder Zeitschritt kommt als Argument herein. Dazu: Unverwundbarkeit und Blinken
## laufen in Spielzeit (Pause und Zeitlupe fressen sie nicht mehr auf).

const DT := 1.0 / 60.0

var main: Node


func aufraeumen() -> void:
	baum.paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


func test_coyote_zeit_nach_der_kante() -> void:
	var f := SprungFenster.new(0.10, 0.10)
	f.schritt(DT, true, false)
	pruefe(f.vom_boden(), "am Boden: Absprung erlaubt")
	# 5 Schritte in der Luft = 0,083 s < 0,10 s → noch erlaubt
	for i in 5:
		f.schritt(DT, false, false)
	pruefe(f.vom_boden(), "kurz nach der Kante (5 Schritte) noch erlaubt")
	# Der 6. Schritt liegt genau auf 0,1 s und damit auf der Rundungsgrenze (wie
	# vor der Umstellung) — geprüft wird deshalb erst der 7.
	f.schritt(DT, false, false)
	f.schritt(DT, false, false)
	pruefe(not f.vom_boden(), "nach 7 Schritten (0,117 s) vorbei")


func test_sprungpuffer_vor_der_landung() -> void:
	var f := SprungFenster.new(0.10, 0.10)
	f.schritt(DT, false, false)
	f.schritt(DT, false, false)   # Coyote ist hier noch aktiv, also erst abwarten
	for i in 6:
		f.schritt(DT, false, false)
	pruefe(not f.vom_boden(), "lange in der Luft: kein Bodensprung")
	f.schritt(DT, false, true)    # Druck in der Luft
	pruefe(f.sprung_gewuenscht(), "Druck in der Luft wird vorgemerkt")
	pruefe(not f.vom_boden(), "…aber in der Luft noch kein Bodensprung")
	for i in 4:
		f.schritt(DT, false, false)
	f.schritt(DT, true, false)    # Landung 5 Schritte später
	pruefe(f.sprung_gewuenscht() and f.vom_boden(), "Landung 0,083 s nach dem Druck: Sprung kommt")


func test_puffer_verfaellt() -> void:
	var f := SprungFenster.new(0.10, 0.10)
	f.schritt(DT, false, true)
	for i in 7:
		f.schritt(DT, false, false)
	pruefe(not f.sprung_gewuenscht(), "Druck 0,117 s vor der Landung verfällt")


func test_bodensprung_verbraucht_beides() -> void:
	var f := SprungFenster.new(0.10, 0.10)
	f.schritt(DT, true, true)
	pruefe(f.sprung_gewuenscht() and f.vom_boden(), "Druck am Boden")
	f.bodensprung()
	pruefe(not f.sprung_gewuenscht(), "Wunsch verbraucht")
	pruefe(not f.vom_boden(), "Coyote verbraucht: kein zweiter Bodensprung aus demselben Fenster")


func test_wandsprung_verbraucht_nur_den_wunsch() -> void:
	var f := SprungFenster.new(0.10, 0.10)
	f.schritt(DT, true, false)
	f.schritt(DT, false, true)
	f.wunsch_verbraucht()
	pruefe(not f.sprung_gewuenscht(), "Wunsch verbraucht")
	pruefe(f.vom_boden(), "Coyote-Zeit bleibt unberührt")


func test_zuruecksetzen() -> void:
	var f := SprungFenster.new(0.10, 0.10)
	f.schritt(DT, true, true)
	f.zuruecksetzen()
	pruefe(not f.sprung_gewuenscht() and not f.vom_boden(), "nach dem Rücksetzen gilt nichts Altes mehr")


func test_werte_aus_player() -> void:
	nahe(float(Player.T.coyote), 0.10, 0.0001, "Coyote-Zeit wie bisher")
	nahe(float(Player.T.buffer), 0.10, 0.0001, "Sprungpuffer wie bisher")


func test_unverwundbar_steht_in_der_pause() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await frames(3)
	Kiosk.note_input()
	main._start_level(maxi(0, Game.playlist.find("01-stammdaten")))
	await warte_bis(func(): return main.screen == main.Screen.LEVEL and is_instance_valid(main.level) and main.level._started, 3.0)
	if not pruefe(is_instance_valid(main.level), "Station 01 startet"):
		return
	var p: Player = main.level.player
	p.respawn()
	pruefe(p.is_invulnerable, "Schonzeit nach dem Rücksetzen")
	baum.paused = true
	# 60 Frames angehalten: Die Schonzeit (0,6 s) darf in der Pause nicht ablaufen,
	# egal wie lange die Pause in Echtzeit dauert.
	await frames(60)
	pruefe(p.is_invulnerable, "in der Pause läuft die Schonzeit nicht ab")
	pruefe(p.visual.blink_left > 0.0, "in der Pause blinkt Paul nicht zu Ende")
	baum.paused = false
	await frames(45)
	pruefe(not p.is_invulnerable, "nach 0,75 s Spielzeit ist die Schonzeit (0,6 s) vorbei")
