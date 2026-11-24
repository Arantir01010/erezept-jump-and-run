extends SceneTree
## DURCHSPIELTREIBER — spielt die aufgenommenen Eingaben einer Station ab und sagt, ob
## Paul damit noch ans Ziel kommt. Nach jeder Leveländerung zeigt sich so, ob eine
## Station noch lösbar ist (tools/pruefen.py, Stufe 7, spielt tests/durchspiel/*.json).
##
##   godot --headless --path godot --fixed-fps 60 --script res://tests/durchspiel.gd -- --wiedergabe=res://tests/durchspiel/01-stammdaten.json
##   … -- --ordner=res://tests/durchspiel                alle Aufnahmen eines Ordners
##   … -- --wiedergabe=<datei> --wiederholen=3           dreimal im selben Prozess
##   … -- --wiedergabe=<datei> --vorlauf=37              37 Bilder später starten (andere Uhr)
##   … -- --wiedergabe=<datei> --zufall-stoeren          je Bild zusätzlich Zufall ziehen
##   … -- --suche=01-stammdaten [--ziel=<datei>] [--versuche=N] [--protokoll]
##        ohne Menschen aufnehmen: der Läufer (tests/durchspiel_bot.gd) spielt, die
##        Aufnahme schreibt mit (Standardziel res://tests/durchspiel/<station>.json);
##        --protokoll druckt, was der Läufer plant („[läufer N] …“)
##
## Aufnehmen am PC (Mensch): src/autoload/Aufnahme.gd. Je Durchlauf eine Zeile
## „DURCHLAUF <station> (<datei>): <ergebnis> – <angaben>“, Ergebnis:
##   ziel     Tür/Ende erreicht; dazu, ob Ende und Spur deckungsgleich mit der Aufnahme sind
##   absturz  Fehlermeldung von Engine oder Skript, Aufnahme unlesbar, Station unbekannt
##   haenger  Station startet nicht, keine Physikschritte mehr, Paul steht trotz gehaltenem
##            Links/Rechts STILLSTAND Schritte auf der Stelle, oder der Wachhund schlägt an
##   falsch   Aufnahme zu Ende (plus NACHLAUF Schritte), Ziel nicht erreicht, Paul anderswo
## (Fristen: tests/durchspiel_lauf.gd.) Letzte Zeile „N Durchläufe, M fehlgeschlagen“;
## Exit-Code 0 = alle am Ziel, 1 = nicht alle, 2 = falscher Aufruf oder Wachhund.
## --fixed-fps 60 ist Pflicht: ein Bild = ein Physikschritt = 1/60 s, auf jedem Rechner.
##
## Warum zwei Dateien: Unter --script übersetzt Godot dieses Skript, bevor die Autoloads
## Bezeichner sind — Klassen, die Game & Co. nennen (Level, Player), gingen hier nicht.
## Die Arbeit macht darum tests/durchspiel_lauf.gd, erst zur Laufzeit geladen.

const LAUF := "res://tests/durchspiel_lauf.gd"
const WACHHUND_S := 1500.0

var _zaehler: Logger
var _start_ms := 0


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	_zaehler = (load("res://tests/fehlerzaehler.gd") as GDScript).new()
	OS.add_logger(_zaehler)
	# Erst im ersten Bild starten: dann haben die Autoloads ihr _ready gehabt.
	process_frame.connect(_starten, CONNECT_ONE_SHOT)


func _process(_delta: float) -> bool:
	if (Time.get_ticks_msec() - _start_ms) / 1000.0 > WACHHUND_S:
		printerr("Wachhund: Durchspiel hängt seit %.0f s — Abbruch." % WACHHUND_S)
		quit(2)
	return false


func _starten() -> void:
	# --fixed-fps 60: dann kommt auf jedes Bild genau ein Physikschritt. Die Engine-Schalter
	# selbst zeigt OS.get_cmdline_args() nicht, darum wird gezählt.
	var physik := Engine.get_physics_frames()
	for i in 5:
		await process_frame
	if Engine.get_physics_frames() - physik != 5:
		printerr("durchspiel: bitte mit --fixed-fps 60 starten (%d Physikschritte in 5 Bildern; sonst hängt die Wiedergabe an der Rechnergeschwindigkeit)" % (Engine.get_physics_frames() - physik))
		quit(2)
		return
	var skript := load(LAUF) as GDScript
	if skript == null or not skript.can_instantiate():
		printerr("durchspiel: %s lässt sich nicht laden (Skriptfehler, siehe oben)" % LAUF)
		print("0 Durchläufe, 0 fehlgeschlagen")
		quit(2)
		return
	var lauf: Object = skript.new()
	var rc: int = await lauf.call("los", self, _zaehler, OS.get_cmdline_user_args())
	OS.remove_logger(_zaehler)
	quit(rc)
