extends Node
## AUFNAHME — nimmt die Eingaben einer Station auf und spielt sie für den
## Durchspieltreiber wieder ab (tests/durchspiel.gd). Ohne Schalter tut sie nichts.
##
## Aufnehmen (Mensch am PC): Station direkt starten und bis durch die Tür spielen.
##   godot --path godot --fixed-fps 60 -- --windowed --level=01-stammdaten --aufnahme=<datei.json>
## (Windows: Godot_v4.7.2-stable_win64_console.exe statt godot.) Die Datei gehört nach
## tests/durchspiel/<station>.json, dort spielt tools/pruefen.py (Stufe 7) sie ab. Den
## Pfad mit dem res-Präfix angeben; hier steht er bewusst ohne, weil Stufe 5 jeden
## res-Pfad in src/ für eine Laufzeitdatei des Exports hält.
## --fixed-fps 60 ist Pflicht für eine treue Aufnahme: Die Bausteine ticken im Bildtakt
## (Level._process), bei freier Bildrate liefe dieselbe Eingabe in der Wiedergabe anders.
## Damit das Spiel auf einem 144-Hz-Bildschirm nicht zu schnell läuft, deckelt die
## Aufnahme die Bildrate auf 60. Endet der Pfad nicht auf .json, ist er ein Ordner: je
## Station <ordner>/<station>.json. Geschrieben wird, sobald Paul das Ziel erreicht;
## „Station neu starten“ beginnt die Aufnahme von vorn. Eine Pause zählt nicht mit, wird
## aber vermerkt (wer in der Pause eine Taste drückt und hält, kann die Wiedergabe verschieben).
##
## Wiedergeben: tests/durchspiel.gd ruft wiedergeben(spur) vor dem Stationsstart.
##
## Aufnahme und Wiedergabe zählen gleich: Schritt 1 ist der erste Physikschritt nach
## dem Einhängen des Levels, gezählt werden nur Schritte ohne Pause, und beim
## Einhängen wird der Zufall fest gesät (Eingabespur.SAAT). Gelesen wird je Schritt
## Input.get_action_strength der Spielaktionen, BEVOR Paul sich bewegt (Autoloads
## laufen vor der Hauptszene). Ein Ereignis (Taste, Knopf, Stick) wirkt ab dem
## Physikschritt nach seiner Ankunft; darum spielt die Wiedergabe die Wechsel eines
## Schritts einen Schritt vorher über Input.parse_input_event ein — gepuffert, Godot
## liefert sie wie echte Tasten erst am Anfang der nächsten Runde aus. Drückt das Spiel
## selbst im Bildtakt (Kiosk: „hoch halten = Hülle“, Input.action_press), notiert die
## Aufnahme das im eigenen _process (nach Kiosk, vor dem Level) als Art „b“, und die
## Wiedergabe drückt es an derselben Stelle wieder per Input.action_press.

## Aufnahme geschrieben (Pfad, Spur).
signal aufgenommen(pfad: String, spur: Eingabespur)
## Wiedergabe: Station zu Ende (Ziel erreicht); `ist` hält Spur und Ende.
signal ziel_erreicht(ist: Eingabespur)

var modus := ""            # "", "aufnahme", "wiedergabe"
var level: Level           # laufende Station
var schritt := 0           # Physikschritte seit dem Einhängen (ohne Pause)
var quelle := "mensch"
var ziel := ""             # Aufnahme: Datei oder Ordner
var spur: Eingabespur      # Aufnahme: entsteht hier; Wiedergabe: wird abgespielt
var ist: Eingabespur       # Wiedergabe: beobachtete Spur
var fertig := false        # Station dieser Aufnahme/Wiedergabe abgeschlossen

var _stand: Dictionary[String, float] = {}
var _naechste := 0                       # Wiedergabe: Index der nächsten Eingabe
var _bildtakt: Array[int] = []           # Wiedergabe: „b“-Eingaben für den nächsten Bildtakt
var _letzter_physikframe := -1
var _takt_bild := -1                     # Taktprüfung: Bild und Physikschritt beim letzten _process
var _takt_physik := -1
var _verbunden := false
var _geschrieben := false               # Aufnahme in eine Datei: steht schon (weitere Stationen nicht)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	set_physics_process(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--aufnahme="):
			aufnehmen(a.get_slice("=", 1), "mensch")


## Aufnahme einschalten: `pfad` ist eine .json-Datei oder ein Ordner.
func aufnehmen(pfad: String, woher := "mensch") -> void:
	modus = "aufnahme"
	_geschrieben = false
	ziel = pfad
	quelle = woher
	_verbinden()
	if woher == "mensch":
		# 144-Hz-Bildschirm: nicht schneller laufen als der feste Takt (60 Bilder = 1 s Spielzeit)
		Engine.max_fps = 60
		print("[aufnahme] bereit: %s — Station bis durch die Tür spielen" % pfad)


## Wiedergabe einschalten (vor dem Stationsstart): `band` wird ab Schritt 1 eingespielt.
func wiedergeben(band: Eingabespur) -> void:
	modus = "wiedergabe"
	spur = band
	_verbinden()


## Ausschalten und alle Spielaktionen loslassen (Treiber zwischen zwei Läufen).
func aus() -> void:
	modus = ""
	level = null
	fertig = false
	set_process(false)
	set_physics_process(false)
	for a in Eingabespur.AKTIONEN:
		Input.action_release(a)


## Die laufende Station oder null (auch, wenn sie schon freigegeben ist).
func aktuelles_level() -> Level:
	return level if is_instance_valid(level) else null


## Pauls Position oder Vector2.INF, solange keine Station läuft.
func paul_ort() -> Vector2:
	if not is_instance_valid(level) or not is_instance_valid(level.player):
		return Vector2.INF
	return level.player.global_position


func _verbinden() -> void:
	if not _verbunden:
		_verbunden = true
		get_tree().node_added.connect(_eingehaengt)
	set_process(true)
	set_physics_process(true)


func _eingehaengt(n: Node) -> void:
	if modus == "" or not n is Level:
		return
	if modus == "aufnahme" and _geschrieben:
		level = null    # eine Datei hält eine Station; die nächste nimmt nur der Ordner-Modus auf
		return
	level = n as Level
	schritt = 0
	fertig = false
	_letzter_physikframe = Engine.get_physics_frames()
	_takt_bild = -1
	seed(Eingabespur.SAAT)
	var id := str(Game.playlist[Game.level_index]) if Game.level_index < Game.playlist.size() else ""
	_stand.clear()
	for a in Eingabespur.AKTIONEN:
		_stand[a] = Input.get_action_strength(a)
	if modus == "aufnahme":
		spur = Eingabespur.new()
		spur.neu(id, quelle)
		for a in Eingabespur.AKTIONEN:
			if _stand[a] > 0.0:
				spur.wechsel(0, a, _stand[a], "h")
	elif modus == "wiedergabe":
		ist = Eingabespur.new()
		ist.neu(id, "wiedergabe")
		_naechste = 0
		_bildtakt.clear()
		_einspielen(1)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(level) or fertig:
		return
	var pf := Engine.get_physics_frames()
	if pf - _letzter_physikframe > 1 and modus == "aufnahme":
		spur.pausiert = true
	_letzter_physikframe = pf
	schritt += 1
	if modus == "aufnahme":
		_beobachten(schritt, "e")
	var buch := spur if modus == "aufnahme" else ist
	if schritt % Eingabespur.SPUR_ABSTAND == 0 and is_instance_valid(level.player):
		buch.punkt(schritt, level.player.global_position)
	if level.finished:
		fertig = true
		var ort := level.player.global_position if is_instance_valid(level.player) else Vector2.ZERO
		buch.abschliessen(schritt, "ziel", ort)
		if modus == "aufnahme":
			_schreiben()
		else:
			ziel_erreicht.emit(ist)
		return
	if modus == "wiedergabe":
		_einspielen(schritt + 1)


func _process(_delta: float) -> void:
	if not is_instance_valid(level) or fertig:
		return
	_takt_pruefen()
	if modus == "aufnahme":
		# Was sich seit dem Physikschritt geändert hat, drückte das Spiel selbst (Kiosk
		# läuft vor uns) — es wirkt im Level ab diesem Bildtakt, also ab dem nächsten Schritt.
		_beobachten(schritt + 1, "b")
	elif modus == "wiedergabe":
		for i in _bildtakt:
			var a := spur.aktion_bei(i)
			var s := spur.staerke_bei(i)
			if s > 0.0:
				Input.action_press(a, s)
			else:
				Input.action_release(a)
		_bildtakt.clear()


## Fester Takt (--fixed-fps 60): Auf jedes Bild kommt genau ein Physikschritt. Die
## Engine-Schalter selbst zeigt OS.get_cmdline_args() nicht, darum wird gezählt.
func _takt_pruefen() -> void:
	var bild := Engine.get_process_frames()
	var physik := Engine.get_physics_frames()
	if modus == "aufnahme" and spur.takt_fest and _takt_bild >= 0 and bild - _takt_bild == 1 and physik - _takt_physik != 1:
		spur.takt_fest = false
		print("[aufnahme] ACHTUNG: kein fester Takt (%d Physikschritte in einem Bild) — mit --fixed-fps 60 starten, sonst kann die Wiedergabe abweichen" % (physik - _takt_physik))
	_takt_bild = bild
	_takt_physik = physik


func _beobachten(bei: int, art: String) -> void:
	for a in Eingabespur.AKTIONEN:
		var s := Input.get_action_strength(a)
		if s != _stand[a]:
			_stand[a] = s
			spur.wechsel(bei, a, s, art)


## Die Wechsel von Schritt `bei` einspielen: Ereignisse gepuffert (Godot liefert sie
## am Anfang der nächsten Runde aus, vor dem Physikschritt), „b“ für den nächsten Bildtakt.
func _einspielen(bei: int) -> void:
	while _naechste < spur.anzahl() and spur.schritt_bei(_naechste) <= bei:
		var i := _naechste
		_naechste += 1
		if spur.schritt_bei(i) < bei or spur.art_bei(i) == "h":
			continue   # Schritt 0 („h“) setzt der Treiber vor dem Start
		if spur.art_bei(i) == "b":
			_bildtakt.append(i)
			continue
		var ev := InputEventAction.new()
		ev.action = spur.aktion_bei(i)
		ev.strength = spur.staerke_bei(i)
		ev.pressed = ev.strength > 0.0
		Input.parse_input_event(ev)


func _schreiben() -> void:
	var pfad := ziel if ziel.get_extension() == "json" else ziel.path_join(spur.station + ".json")
	var e := spur.speichern(pfad)
	if e != OK:
		printerr("[aufnahme] konnte %s nicht schreiben (Fehler %d)" % [pfad, e])
		return
	var vorbehalt := ""
	if spur.pausiert:
		vorbehalt += " (mit Pause — Wiedergabe prüfen)"
	if not spur.takt_fest:
		vorbehalt += " (ohne festen Takt — Wiedergabe prüfen)"
	print("[aufnahme] %s: %d Eingaben, Ziel in Schritt %d (%.1f s) → %s%s" % [spur.station, spur.anzahl(),
		spur.ende_schritt, spur.ende_schritt / float(spur.physik_hz), ProjectSettings.globalize_path(pfad), vorbehalt])
	_geschrieben = ziel.get_extension() == "json"
	aufgenommen.emit(pfad, spur)
