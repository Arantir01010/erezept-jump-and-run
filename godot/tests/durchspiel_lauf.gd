extends RefCounted
## DURCHSPIEL-LAUF — Wiedergabe und Suche des Durchspieltreibers (Aufrufe: Kopf von
## tests/durchspiel.gd). Das Hauptskript lädt diese Datei erst, wenn die Autoloads
## stehen: Unter --script sind Game, Kiosk und Aufnahme beim Übersetzen des
## Hauptskripts noch keine Bezeichner — hier schon, darum ist hier alles typisiert.
##
## Ein Durchlauf: Kiosk.start_level_id setzen, Aufnahme.wiedergeben(spur), Hauptszene
## einhängen (Main._ready startet die Station direkt, wie --level=), dann je Bild
## beobachten, bis ein Ergebnis feststeht; danach die Szene abbauen, damit der nächste
## Durchlauf im selben Prozess von vorn beginnt.

const Laeufer := preload("res://tests/durchspiel_bot.gd")
const MAIN := "res://scenes/Main.tscn"
const ORDNER := "res://tests/durchspiel/"
## Bilder, bis die Station steht (Blende, Leveldaten)
const FRIST_START := 900
## Bilder ohne neuen Physikschritt (Pause, eingefroren)
const FRIST_SCHRITT := 300
## Schritte, die Paul trotz gehaltenem Links/Rechts auf der Stelle stehen darf
const STILLSTAND := 900
## Schritte nach der letzten Eingabe und dem Ende der Aufnahme, bis „falsch“ gilt
const NACHLAUF := 180
## Bilder nach dem Ziel: Siegel-Zeitlupe, 1,8 s bis zur Stationskarte, Blende
const AUSLAUF := 150
## Suche: Spielzeit je Versuch, Schritte ohne neuen Fortschritt nach rechts
const SUCHE_SCHRITTE := 3 * 60 * 60
const SUCHE_STILLSTAND := 1200

var baum: SceneTree
var zaehler: Object
var main: Node
var vorlauf := 0
var stoeren := false
var protokoll := false
var _gezogen := 0.0     # --zufall-stoeren: was zusätzlich gezogen wurde


## Einstieg (tests/durchspiel.gd): Rückgabe ist der Exit-Code.
func los(b: SceneTree, z: Object, args: PackedStringArray) -> int:
	baum = b
	zaehler = z
	var dateien: Array[String] = []
	var wiederholen := 1
	var suche := ""
	var ziel := ""
	var versuche := 0
	for a in args:
		var wert := a.substr(a.find("=") + 1) if "=" in a else ""
		if a.begins_with("--wiedergabe="):
			dateien.append(wert)
		elif a.begins_with("--ordner="):
			dateien.append_array(_aufnahmen_in(wert))
		elif a.begins_with("--wiederholen="):
			wiederholen = maxi(1, wert.to_int())
		elif a.begins_with("--vorlauf="):
			vorlauf = maxi(0, wert.to_int())
		elif a == "--zufall-stoeren":
			stoeren = true
		elif a == "--protokoll":
			protokoll = true
		elif a.begins_with("--suche="):
			suche = wert
		elif a.begins_with("--ziel="):
			ziel = wert
		elif a.begins_with("--versuche="):
			versuche = wert.to_int()
		else:
			printerr("durchspiel: unbekannter Schalter %s (Aufrufe: Kopf von tests/durchspiel.gd)" % a)
			return 2
	if suche != "":
		return await _suchen(suche, ziel if ziel != "" else ORDNER + suche + ".json", versuche)
	if dateien.is_empty():
		print("Keine Aufnahme angegeben: --wiedergabe=<datei> oder --ordner=<ordner>")
		print("0 Durchläufe, 0 fehlgeschlagen")
		return 2
	var anzahl := 0
	var fehlgeschlagen := 0
	for d in dateien:
		for k in wiederholen:
			var ergebnis := await _abspielen(d)
			anzahl += 1
			if ergebnis != "ziel":
				fehlgeschlagen += 1
	print("%d Durchläufe, %d fehlgeschlagen" % [anzahl, fehlgeschlagen])
	return 1 if fehlgeschlagen > 0 else 0


# ------------------------------------------------------------------ Wiedergabe

func _abspielen(datei: String) -> String:
	var band := Eingabespur.laden(datei)
	var station := band.station if band.station != "" else datei.get_file().get_basename()
	if not band.fehler.is_empty():
		return _melden(station, datei, _befund("absturz", "Aufnahme unlesbar: " + "; ".join(PackedStringArray(band.fehler.slice(0, 3)))))
	if not Game.playlist.has(station):
		return _melden(station, datei, _befund("absturz", "Station steht nicht in der Playlist"))
	var fehler_vorher: int = zaehler.call("anzahl")
	await _warten(vorlauf)
	# Beim Stationsbeginn gehaltene Tasten (Art „h“) vorher drücken
	for i in band.anzahl():
		if band.art_bei(i) == "h":
			_ereignis(band.aktion_bei(i), band.staerke_bei(i))
	await _warten(2)
	Aufnahme.wiedergeben(band)
	var befund := _befund("absturz", "Hauptszene lädt nicht")
	if _starten(station):
		befund = await _beobachten(band, fehler_vorher)
	var am_ziel: bool = befund["ergebnis"] == "ziel"
	await _abbauen(am_ziel)
	var neu := _neue_fehler(fehler_vorher)
	if befund["ergebnis"] != "absturz" and not neu.is_empty():
		befund = _befund("absturz", "%d Fehlermeldung(en), erste: %s (vorher: %s %s)" % [neu.size(), neu[0], befund["ergebnis"], befund["text"]])
	var vorbehalt := _vorbehalt(band)
	if vorbehalt != "":
		var ergebnis: String = befund["ergebnis"]
		var text: String = befund["text"]
		befund = _befund(ergebnis, text + vorbehalt)
	return _melden(station, datei, befund)


## Aufnahmen mit Pause oder ohne festen Takt (Mensch ohne --fixed-fps 60) können
## abweichen, ohne dass die Station sich geändert hat — das gehört in die Zeile.
func _vorbehalt(band: Eingabespur) -> String:
	var teile := PackedStringArray()
	if band.pausiert:
		teile.append("Aufnahme mit Pause")
	if not band.takt_fest:
		teile.append("Aufnahme ohne festen Takt")
	return "" if teile.is_empty() else " [%s — neu aufnehmen mit --fixed-fps 60, ohne Pause]" % ", ".join(teile)


func _beobachten(band: Eingabespur, fehler_vorher: int) -> Dictionary:
	var bilder := 0
	while Aufnahme.aktuelles_level() == null:
		await baum.process_frame
		bilder += 1
		if not _neue_fehler(fehler_vorher).is_empty():
			return _befund("absturz", "Fehlermeldung beim Start: %s" % _neue_fehler(fehler_vorher)[0])
		if bilder > FRIST_START:
			return _befund("haenger", "Station startet nicht (%d Bilder)" % FRIST_START)
	var letzter := -1
	var ohne := 0
	var ruhe_ort := Vector2.INF
	var ruhe_ab := 0
	var frist := band.letzter_schritt() + NACHLAUF
	var weiter := true
	while weiter:
		await baum.process_frame
		if stoeren:
			for i in 3:
				_gezogen += randf()
		var neu := _neue_fehler(fehler_vorher)
		if not neu.is_empty():
			return _befund("absturz", "Fehlermeldung in Schritt %d: %s" % [Aufnahme.schritt, neu[0]])
		if Aufnahme.fertig:
			return _ziel_befund(band)
		if Aufnahme.aktuelles_level() == null:
			return _befund("absturz", "Station verschwand in Schritt %d ohne Ziel" % Aufnahme.schritt)
		var s := Aufnahme.schritt
		if s == letzter:
			ohne += 1
			if ohne > FRIST_SCHRITT:
				return _befund("haenger", "seit %d Bildern kein Physikschritt (Pause oder eingefroren), Schritt %d" % [FRIST_SCHRITT, s])
			continue
		ohne = 0
		letzter = s
		var ort := Aufnahme.paul_ort()
		if Input.get_action_strength("move_left") > 0.0 or Input.get_action_strength("move_right") > 0.0:
			if ruhe_ort == Vector2.INF or ort.distance_to(ruhe_ort) > 2.0:
				ruhe_ort = ort
				ruhe_ab = s
			elif s - ruhe_ab >= STILLSTAND:
				return _befund("haenger", "Paul steht seit Schritt %d bei %s, obwohl die Aufnahme links/rechts hält%s"
					% [ruhe_ab, _ort(ort), _abweichung_text(Aufnahme.ist.erste_abweichung(band))])
		else:
			ruhe_ort = Vector2.INF
		if s > frist:
			return _befund("falsch", "Ziel nicht erreicht: Paul in Schritt %d bei %s, die Aufnahme war in Schritt %d am Ziel bei %s%s"
				% [s, _ort(ort), band.ende_schritt, _ort(band.ende_position), _abweichung_text(Aufnahme.ist.erste_abweichung(band))])
	return _befund("haenger", "Beobachtung abgebrochen")


func _ziel_befund(band: Eingabespur) -> Dictionary:
	var ist := Aufnahme.ist
	var abw := ist.erste_abweichung(band)
	var text := "Schritt %d (%.1f s), Paul bei %s" % [ist.ende_schritt, ist.ende_schritt / float(Engine.physics_ticks_per_second), _ort(ist.ende_position)]
	if ist.ende_schritt == band.ende_schritt and ist.ende_position.distance_to(band.ende_position) <= 0.01 and abw.is_empty():
		text += ", deckungsgleich mit der Aufnahme (Ende und %d Spurpunkte)" % _gemeinsam(ist, band)
	else:
		text += ", weicht von der Aufnahme ab (dort Schritt %d bei %s)%s" % [band.ende_schritt, _ort(band.ende_position), _abweichung_text(abw)]
	return _befund("ziel", text)


# ------------------------------------------------------------------ Suche (ohne Menschen aufnehmen)

func _suchen(station: String, ziel: String, versuche: int) -> int:
	if not Game.playlist.has(station):
		print("SUCHE %s: Station steht nicht in der Playlist" % station)
		return 1
	var n := versuche if versuche > 0 else Laeufer.VARIANTEN.size()
	for v in n:
		var bot := Laeufer.new(v % Laeufer.VARIANTEN.size())
		bot.protokoll = protokoll
		var fehler_vorher: int = zaehler.call("anzahl")
		Aufnahme.aufnehmen(ziel, "suche")
		var befund := _befund("absturz", "Hauptszene lädt nicht")
		if _starten(station):
			befund = await _laufen_lassen(bot, fehler_vorher, ziel)
		bot.alles_los()
		var am_ziel: bool = befund["ergebnis"] == "ziel"
		await _abbauen(am_ziel)
		print("SUCHE %s: Versuch %d (%s): %s – %s" % [station, v + 1, bot.name, befund["ergebnis"], befund["text"]])
		if am_ziel:
			return 0
	print("SUCHE %s: kein Versuch erreichte das Ziel" % station)
	return 1


func _laufen_lassen(bot: Laeufer, fehler_vorher: int, ziel: String) -> Dictionary:
	var bilder := 0
	while Aufnahme.aktuelles_level() == null:
		await baum.process_frame
		bilder += 1
		if bilder > FRIST_START:
			return _befund("haenger", "Station startet nicht (%d Bilder)" % FRIST_START)
	var bester := -INF
	var bester_ab := 0
	var weiter := true
	while weiter:
		await baum.process_frame
		var neu := _neue_fehler(fehler_vorher)
		if not neu.is_empty():
			return _befund("absturz", "Fehlermeldung in Schritt %d: %s" % [Aufnahme.schritt, neu[0]])
		if Aufnahme.fertig:
			var spur := Aufnahme.spur
			return _befund("ziel", "Schritt %d (%.1f s), %d Eingaben, %d Planungen → %s" % [spur.ende_schritt,
				spur.ende_schritt / float(Engine.physics_ticks_per_second), spur.anzahl(), bot.planungen,
				ProjectSettings.globalize_path(ziel)])
		var lvl := Aufnahme.aktuelles_level()
		if lvl == null:
			return _befund("absturz", "Station verschwand in Schritt %d ohne Ziel" % Aufnahme.schritt)
		bot.takt(lvl)
		var s := Aufnahme.schritt
		var x := Aufnahme.paul_ort().x
		if x > bester + 1.0:
			bester = x
			bester_ab = s
		elif s - bester_ab > SUCHE_STILLSTAND:
			return _befund("haenger", "kommt seit Schritt %d nicht über x = %.0f (Kachel %d) hinaus, Paul bei %s"
				% [bester_ab, bester, int(bester / Game.TILE), _ort(Aufnahme.paul_ort())])
		if s > SUCHE_SCHRITTE:
			return _befund("haenger", "Zeitlimit (%d Schritte), Paul bei %s" % [SUCHE_SCHRITTE, _ort(Aufnahme.paul_ort())])
	return _befund("haenger", "Suche abgebrochen")


# ------------------------------------------------------------------ Szene

func _starten(station: String) -> bool:
	var szene := load(MAIN) as PackedScene
	if szene == null:
		return false
	Kiosk.start_level_id = station
	main = szene.instantiate()
	baum.root.add_child(main)
	return true


## Szene abbauen: Abschluss auslaufen lassen, Zeitlupe/Treffer-Stopp abwarten (Fx: Timer
## mit ignore_time_scale), Aufnahme aus, alle Spielaktionen los, Hauptszene frei.
func _abbauen(nach_ziel: bool) -> void:
	if nach_ziel:
		await _warten(AUSLAUF)
	var n := 0
	while Engine.time_scale != 1.0 and n < 600:
		await baum.process_frame
		n += 1
	Aufnahme.aus()
	if is_instance_valid(main):
		main.queue_free()
	main = null
	Kiosk.start_level_id = ""
	baum.paused = false
	await _warten(3)


func _warten(bilder: int) -> void:
	for i in bilder:
		await baum.process_frame


# ------------------------------------------------------------------ Hilfen

func _aufnahmen_in(ordner: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(ordner):
		if f.ends_with(".json"):
			out.append(ordner.path_join(f))
	out.sort()
	return out


func _ereignis(aktion: String, staerke: float) -> void:
	var ev := InputEventAction.new()
	ev.action = aktion
	ev.strength = staerke
	ev.pressed = staerke > 0.0
	Input.parse_input_event(ev)


func _neue_fehler(vorher: int) -> Array[String]:
	var neu: Array[String] = zaehler.call("seit", vorher)
	return neu


func _befund(ergebnis: String, text: String) -> Dictionary:
	return {"ergebnis": ergebnis, "text": text}


func _melden(station: String, datei: String, befund: Dictionary) -> String:
	var ergebnis: String = befund["ergebnis"]
	print("DURCHLAUF %s (%s): %s – %s" % [station, datei, ergebnis, befund["text"]])
	return ergebnis


func _ort(v: Vector2) -> String:
	if v == Vector2.INF:
		return "(—)"
	return "(%.3f, %.3f; Kachel %d/%d)" % [v.x, v.y, floori(v.x / Game.TILE), floori((v.y - 1.0) / Game.TILE)]


func _abweichung_text(abw: Dictionary) -> String:
	if abw.is_empty():
		return ""
	var soll: Vector2 = abw["soll"]
	var ist: Vector2 = abw["ist"]
	var abstand: float = abw["abstand"]
	return "; erste Abweichung der Spur in Schritt %d: %.1f px (Aufnahme %s, jetzt %s)" % [abw["schritt"], abstand, _ort(soll), _ort(ist)]


func _gemeinsam(ist: Eingabespur, soll: Eingabespur) -> int:
	var n := 0
	for i in ist.spur_anzahl():
		if soll.ort_bei(ist.spur_schritt_bei(i)) != Vector2.INF:
			n += 1
	return n
