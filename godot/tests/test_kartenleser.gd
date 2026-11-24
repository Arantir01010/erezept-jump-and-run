extends "res://tests/testfall.gd"
## KARTENLESER im laufenden Level (Station 05): passende Karte, falsche Karte, keine
## Karte, Karte steckt woanders, Weggehen — wie LED, Anzeige und Karte im Schlitz
## nacheinander stehen. Der Ablauf hängt an der Spielzeit (Level._process, Tween),
## darum mit Abstand zu jeder Schwelle geprüft.

var main: Node
var _karten: Array = []
var _plaetze := {}


func _station(id: String) -> Node:
	_karten = Game.cards.duplicate()
	_plaetze = Game.card_slots.duplicate()
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	await frames(3)
	Kiosk.note_input()
	main._start_level(maxi(0, Game.playlist.find(id)))
	await warte_bis(func(): return main.screen == main.Screen.LEVEL and is_instance_valid(main.level) and main.level._started, 3.0)
	return main.level


func aufraeumen() -> void:
	Game.cards = _karten
	Game.card_slots = _plaetze
	if is_instance_valid(main):
		main.queue_free()
	await frames(3)


## Der Leser, der diese Karte will (der linke, wenn es mehrere gibt); Paul steht davor.
func _leser(lvl, karte: String) -> Variant:
	var bester = null
	for m in lvl.mechanics:
		if is_instance_valid(m) and m.type == "kartenleser" and (m.accepted as Array).has(karte):
			if bester == null or m.rect.position.x < bester.rect.position.x:
				bester = m
	if bester != null:
		var p := Vector2(bester.rect.get_center().x, bester.rect.end.y - 2.0)
		lvl.player.global_position = p
		lvl.player.set_respawn(p)
		lvl.player.velocity = Vector2.ZERO
	return bester


## Was der Leser gerade zeigt und weiß — die einzige Stelle, die sein Inneres liest.
func _zustand(k) -> Dictionary:
	var r: KartenleserRegel = k.regel
	return {"led": r.led, "status": r.status, "steckt": r.steckt, "anim": r.anim,
		"eingesteckt": r.eingesteckt, "tor_gemerkt": r.geoeffnet, "rempler": r.rempler, "nicken": r.nicken}


func _erwarte(k, soll: Dictionary, wann: String) -> void:
	var ist := _zustand(k)
	for key in soll:
		gleich(ist[key], soll[key], "%s: %s" % [wann, key])


func test_passende_karte_oeffnet_das_tor_und_bleibt_stecken() -> void:
	var lvl = await _station("05-identitaet")
	var k = _leser(lvl, "egk")
	if not pruefe(k != null, "Station 05 hat einen eGK-Leser"):
		return
	await frames(3)
	Game.cards = ["egk"]
	Game.card_slots = {}
	k._versuch()
	_erwarte(k, {"eingesteckt": "egk", "led": "gelb", "status": "prueft", "anim": "rein", "steckt": "",
		"tor_gemerkt": true}, "gleich nach dem Stecken")
	pruefe(k.linked_gate() != null and k.linked_gate().is_open, "Tor ist offen")
	await sekunden(0.8)
	_erwarte(k, {"anim": "", "steckt": "egk", "led": "gruen", "status": "frei"}, "Karte sitzt")
	# Weggehen: Paul nimmt die Karte mit, sie gleitet sichtbar heraus
	k._exit(lvl.player)
	_erwarte(k, {"eingesteckt": "", "steckt": "", "anim": "raus", "led": "rot", "status": "stecken"}, "weggegangen")
	pruefe(not Game.card_slots.has("egk"), "Steckplatz wieder frei")
	await sekunden(0.5)
	_erwarte(k, {"anim": "", "steckt": "", "led": "rot"}, "herausgeglitten")


func test_falsche_karte_prallt_ab() -> void:
	var lvl = await _station("05-identitaet")
	var k = _leser(lvl, "egk")
	if not pruefe(k != null, "Station 05 hat einen eGK-Leser"):
		return
	await frames(3)
	Game.cards = ["hba"]
	Game.card_slots = {}
	k._versuch()
	_erwarte(k, {"eingesteckt": "", "led": "gelb", "status": "prueft", "anim": "abgelehnt"}, "gleich nach dem Stecken")
	await sekunden(0.2)       # Abweis-Moment bei der Hälfte der 0,7 s
	_erwarte(k, {"led": "gelb", "status": "prueft", "anim": "abgelehnt"}, "vor dem Abprallen")
	await sekunden(0.3)
	_erwarte(k, {"led": "rot", "status": "abgelehnt", "anim": "abgelehnt"}, "abgeprallt")
	pruefe(float(_zustand(k)["rempler"]) > 0.0, "Rempler läuft")
	await sekunden(0.4)
	_erwarte(k, {"anim": "", "steckt": "", "status": "abgelehnt"}, "Karte wieder heraus")
	await sekunden(2.4)
	_erwarte(k, {"led": "rot", "status": "stecken", "eingesteckt": ""}, "wieder bereit")
	pruefe(Game.card_slots.is_empty(), "nichts steckt")


func test_ohne_karte_und_karte_steckt_woanders() -> void:
	var lvl = await _station("05-identitaet")
	var k = _leser(lvl, "egk")
	if not pruefe(k != null, "Station 05 hat einen eGK-Leser"):
		return
	await frames(3)
	Game.cards = []
	Game.card_slots = {}
	k._versuch()
	_erwarte(k, {"led": "rot", "status": "keine", "anim": ""}, "ohne Karte")
	await sekunden(2.7)
	_erwarte(k, {"status": "stecken"}, "Hinweis vorbei")
	Game.cards = ["egk"]
	Game.card_slots = {"egk": "anderes-terminal"}
	k._versuch()
	_erwarte(k, {"led": "gelb", "status": "belegt", "anim": "", "eingesteckt": ""}, "steckt woanders")
	pruefe(float(_zustand(k)["nicken"]) > 0.0, "Kopfschütteln läuft")
	await sekunden(1.4)
	_erwarte(k, {"led": "rot", "status": "belegt"}, "LED zurück, Anzeige noch")
	await sekunden(1.5)
	_erwarte(k, {"status": "stecken"}, "Anzeige zurück")
