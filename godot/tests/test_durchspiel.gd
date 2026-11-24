extends "res://tests/testfall.gd"
## Durchspieltreiber (src/core/Eingabespur.gd, src/autoload/Aufnahme.gd): das Format
## der Aufnahmen, die Prüfung beim Laden, dieselben Aktionen wie das Spiel — und dass
## eine Wiedergabe sich mit ihrer Aufnahme deckt (aufgenommen und zweimal abgespielt
## im selben Lauf, daher unabhängig vom Levelinhalt). Ob die gespeicherten Aufnahmen
## unter tests/durchspiel/ noch ans Ziel führen, prüft tools/pruefen.py Stufe 7.

const STATION := "01-stammdaten"
const DATEI := "user://test_durchspiel_spur.json"
## Ziel der Aufnahme im Test — wird nie geschrieben (Paul erreicht die Tür nicht)
const NIE := "user://test_durchspiel_nie.json"

var main: Node


func aufraeumen() -> void:
	Aufnahme.aus()
	if is_instance_valid(main):
		main.queue_free()
	main = null
	Kiosk.start_level_id = ""
	baum.paused = false
	for pfad: String in [DATEI, NIE]:
		if FileAccess.file_exists(pfad):
			DirAccess.remove_absolute(pfad)
	await frames(3)


func _beispiel() -> Eingabespur:
	var s := Eingabespur.new()
	s.neu(STATION, "test")
	s.wechsel(0, "move_right", 1.0, "h")
	s.wechsel(12, "jump", 1.0)
	s.wechsel(24, "jump", 0.0)
	s.wechsel(30, "move_up", 1.0, "b")
	s.wechsel(31, "move_left", 0.5)
	s.punkt(30, Vector2(391.0, 959.986328125))
	s.punkt(60, Vector2(661.25, 836.5))
	s.abschliessen(75, "ziel", Vector2(700.123456789, 800.5))
	return s


func _geaendert(d: Dictionary, schluessel: String, wert: Variant) -> Dictionary:
	var kopie := d.duplicate(true)
	kopie[schluessel] = wert
	return kopie


func test_ohne_schalter_nimmt_nichts_auf() -> void:
	gleich(Aufnahme.modus, "", "ohne --aufnahme ist die Aufnahme aus")
	pruefe(not Aufnahme.is_processing() and not Aufnahme.is_physics_processing(), "die Aufnahme läuft nicht mit")


func test_aktionen_wie_im_spiel() -> void:
	gleich(PackedStringArray(Eingabespur.AKTIONEN), PackedStringArray(Kiosk.ACTIONS),
		"Eingabespur.AKTIONEN = Kiosk.ACTIONS (sonst fehlen Tasten in der Aufnahme)")
	for a: String in Eingabespur.AKTIONEN:
		pruefe(InputMap.has_action(a), "Aktion %s steht in der InputMap" % a)


func test_format_hin_und_zurueck() -> void:
	var s := _beispiel()
	gleich(s.speichern(DATEI), OK, "speichern")
	var t := Eingabespur.laden(DATEI)
	gleich(t.fehler.size(), 0, "geladen ohne Befund: %s" % "; ".join(PackedStringArray(t.fehler)))
	gleich(t.station, STATION, "Station")
	gleich(t.quelle, "test", "Quelle")
	gleich(t.saat, Eingabespur.SAAT, "Saat")
	pruefe(t.takt_fest and not t.pausiert, "Takt fest, ohne Pause")
	gleich(t.anzahl(), s.anzahl(), "Zahl der Eingaben")
	for i in mini(s.anzahl(), t.anzahl()):
		gleich([t.schritt_bei(i), t.aktion_bei(i), t.staerke_bei(i), t.art_bei(i)],
			[s.schritt_bei(i), s.aktion_bei(i), s.staerke_bei(i), s.art_bei(i)], "Eingabe %d" % i)
	gleich(t.spur_anzahl(), 2, "Spurpunkte")
	gleich(t.ort_bei(30), Vector2(391.0, 959.986328125), "Spurpunkt bitgenau (volle Genauigkeit im JSON)")
	gleich(t.ort_bei(45), Vector2.INF, "kein Spurpunkt in Schritt 45")
	gleich([t.ende_schritt, t.ende_ergebnis, t.ende_position], [75, "ziel", s.ende_position], "Ende bitgenau")
	gleich(t.letzter_schritt(), 75, "letzter Schritt = Ende")
	pruefe(t.erste_abweichung(s).is_empty(), "geladene Spur deckt sich mit der geschriebenen")


func test_text_ist_zeilenweise_und_streng() -> void:
	var text := _beispiel().als_text()
	pruefe(text.ends_with("}\n") and not "\r" in text, "LF-Zeilen, Zeilenende am Schluss")
	pruefe("\n\t\t[12,\"jump\",1.0,\"e\"],\n" in text, "je Eingabe eine Zeile (lesbare Diffs)")
	pruefe(not ",\n\t]" in text, "kein Komma vor der schließenden Klammer (strenges JSON)")
	var json := JSON.new()
	gleich(json.parse(text), OK, "gültiges JSON")


func test_fehlerhafte_aufnahmen_werden_benannt() -> void:
	var gut := _beispiel().als_daten()
	gleich(Eingabespur.aus_daten(gut).fehler.size(), 0, "unverändert gültig")
	var faelle := {
		"„format“ ist nicht 1": _geaendert(gut, "format", 2),
		"„station“ fehlt": _geaendert(gut, "station", ""),
		"unbekannte Aktion fliegen": _geaendert(gut, "eingaben", [[0, "fliegen", 1.0, "e"]]),
		"außerhalb 0…1": _geaendert(gut, "eingaben", [[0, "jump", 2.0, "e"]]),
		"unbekannte Art x": _geaendert(gut, "eingaben", [[0, "jump", 1.0, "x"]]),
		"nicht sortiert": _geaendert(gut, "eingaben", [[5, "jump", 1.0, "e"], [4, "jump", 0.0, "e"]]),
		"Spurpunkt 0": _geaendert(gut, "spur", [[30, 1.0]]),
		"„ende.ergebnis“ unbekannt": _geaendert(gut, "ende", {"schritt": 1, "ergebnis": "gewonnen", "x": 0.0, "y": 0.0}),
		"30 Physikschritten/s": _geaendert(gut, "physik_hz", 30),
	}
	for erwartet: String in faelle:
		var s := Eingabespur.aus_daten(faelle[erwartet])
		var text := "; ".join(PackedStringArray(s.fehler))
		pruefe(erwartet in text, "Befund „%s“ erwartet, ist: %s" % [erwartet, text])
	gleich(Eingabespur.aus_daten([1, 2]).fehler.size(), 1, "Liste statt Objekt")
	gleich(Eingabespur.laden("user://gibt_es_nicht.json").fehler.size(), 1, "fehlende Datei")


func test_abweichung_nennt_den_ersten_schritt() -> void:
	var soll := _beispiel()
	var ist := Eingabespur.new()
	ist.neu(STATION, "wiedergabe")
	ist.punkt(30, Vector2(391.0, 959.986328125))
	ist.punkt(60, Vector2(664.25, 836.5))
	var abw := ist.erste_abweichung(soll)
	gleich(abw.get("schritt", -1), 60, "erste Abweichung in Schritt 60")
	var abstand: float = abw.get("abstand", 0.0)
	nahe(abstand, 3.0, 0.001, "Abstand 3 px")


## Aufnehmen wie am PC (Ereignisse über Input.parse_input_event, gepuffert wie echte
## Tasten), dann zweimal abspielen: dieselben Spurpunkte, dieselbe Endposition.
func test_wiedergabe_deckt_sich_mit_der_aufnahme() -> void:
	Aufnahme.aus()
	Aufnahme.aufnehmen(NIE, "test")
	var laeuft := await _station_starten()
	if not laeuft:
		return
	await frames(2)
	var start := Aufnahme.paul_ort()
	_taste("move_right", 1.0)
	await frames(40)
	_taste("jump", 1.0)
	await frames(12)
	_taste("jump", 0.0)
	await frames(50)
	_taste("move_right", 0.0)
	_taste("move_left", 1.0)
	await frames(25)
	_taste("move_left", 0.0)
	await frames(33)
	var band := Aufnahme.spur
	var bis := Aufnahme.schritt
	var ende := Aufnahme.paul_ort()
	pruefe(ende.distance_to(start) > 100.0, "Paul ist gelaufen (von %s nach %s)" % [start, ende])
	gleich(band.anzahl(), 6, "sechs Wechsel aufgenommen")
	gleich(band.spur_anzahl(), floori(bis / float(Eingabespur.SPUR_ABSTAND)), "ein Spurpunkt je %d Schritte" % Eingabespur.SPUR_ABSTAND)
	await _abbauen()
	for runde in 2:
		Aufnahme.wiedergeben(band)
		laeuft = await _station_starten()
		if not laeuft:
			return
		pruefe(await warte_bis(func() -> bool: return Aufnahme.schritt >= bis, 30.0),
			"Wiedergabe %d erreicht Schritt %d" % [runde + 1, bis])
		var abw := Aufnahme.ist.erste_abweichung(band)
		pruefe(abw.is_empty(), "Wiedergabe %d deckt sich mit der Aufnahme: %s" % [runde + 1, str(abw)])
		gleich(Aufnahme.ist.spur_anzahl(), band.spur_anzahl(), "Wiedergabe %d: gleich viele Spurpunkte" % (runde + 1))
		gleich(Aufnahme.paul_ort(), ende, "Wiedergabe %d: dieselbe Endposition in Schritt %d" % [runde + 1, bis])
		await _abbauen()


func _station_starten() -> bool:
	Kiosk.start_level_id = STATION
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	baum.root.add_child(main)
	return pruefe(await warte_bis(func() -> bool: return Aufnahme.aktuelles_level() != null, 10.0), "Station startet")


func _abbauen() -> void:
	Aufnahme.aus()
	if is_instance_valid(main):
		main.queue_free()
	main = null
	Kiosk.start_level_id = ""
	await frames(3)


func _taste(aktion: String, staerke: float) -> void:
	var ev := InputEventAction.new()
	ev.action = aktion
	ev.strength = staerke
	ev.pressed = staerke > 0.0
	Input.parse_input_event(ev)
