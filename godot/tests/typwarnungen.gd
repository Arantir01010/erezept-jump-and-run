extends SceneTree
## TYPWARNUNGEN — zählt die GDScript-Warnungen aller Skripte unter src/ und tests/,
## für Stufe 3 von tools/pruefen.py (Obergrenzen je Art: tools/grenzwerte.json):
##
##   godot --headless -d --path godot --script res://tests/typwarnungen.gd < /dev/null
##
## Warum -d: Godot gibt Analysewarnungen beim Übersetzen nur bei aktivem Debugger aus
## (GDScript::reload → EngineDebugger::send_error). Ohne -d bricht das Skript ab.
## Warum stdin zu: Hält der lokale Debugger bei einem Parse-Fehler an, liest er Befehle
## von stdin — ist stdin geschlossen, beendet er das Programm, statt zu warten.
##
## Die strengen Typwarnungen (STRENG) schaltet dieses Skript nur für seinen eigenen Lauf
## ein (ProjectSettings zur Laufzeit; der Parser übernimmt sie über settings_changed).
## project.godot bleibt unberührt — Editor und Spiel zeigen sie also nicht.
## INFERRED_DECLARATION bleibt aus: `:=` ist in diesem Projekt gewollter Stil. Alle
## übrigen Warnungen zählen mit ihrer Stufe aus project.godot (Godot-Vorgabe).
##
## Jedes Skript wird mit CACHE_MODE_IGNORE neu übersetzt — auch die schon geladenen
## Autoloads. Ausgabe: je Warnung „WARNUNG <bereich> <ART> <datei>:<zeile> <text>", je
## Bereich und Art „ZAEHLUNG <bereich> <ART> <anzahl>", Skriptfehler als „SKRIPTFEHLER …",
## letzte Zeile „N Skripte, M Warnungen, F Skriptfehler". Exit-Code 0, bei Skriptfehlern 1.

const BEREICHE: Array[String] = ["res://src", "res://tests"]
const STRENG: Array[String] = ["untyped_declaration", "unsafe_property_access",
		"unsafe_method_access", "unsafe_cast", "unsafe_call_argument", "unsafe_void_return"]
const AUS: Array[String] = ["inferred_declaration"]
const EINSTELLUNG := "debug/gdscript/warnings/"


## Sammelt Warnungen und Skriptfehler, die Godot beim Übersetzen meldet.
## Ein Skript kann zweimal übersetzt werden — erst als Abhängigkeit eines anderen, dann
## ausdrücklich. Jede neue Folge von Warnungen derselben Datei ersetzt die vorige
## (letzter Übersetzungslauf zählt), so zählt nichts doppelt.
class Sammler extends Logger:
	var je_datei: Dictionary = {}          # Pfad → Array mit "<ART>\t<zeile>\t<text>"
	var skriptfehler: Array[String] = []
	var _letzte := ""
	var _sperre := Mutex.new()

	func neue_runde() -> void:
		_sperre.lock()
		_letzte = ""
		_sperre.unlock()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_sperre.lock()
		if error_type == Logger.ERROR_TYPE_WARNING and function == "GDScript::reload":
			if file != _letzte:
				_letzte = file
				je_datei[file] = []
			var liste: Array = je_datei[file]
			liste.append("%s\t%d\t%s" % [code, line, rationale])
		elif error_type == Logger.ERROR_TYPE_SCRIPT:
			skriptfehler.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])
		_sperre.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	# Erst im ersten Frame: Dann stehen die Autoloads, auf die Skripte sich beziehen.
	process_frame.connect(_los, CONNECT_ONE_SHOT)


func _los() -> void:
	if not EngineDebugger.is_active():
		printerr("Typwarnungen brauchen den Debugger: godot --headless -d … (siehe Kopf von tests/typwarnungen.gd)")
		print("0 Skripte, 0 Warnungen, 1 Skriptfehler")
		quit(1)
		return
	ProjectSettings.set_setting(EINSTELLUNG + "enable", true)
	for art: String in STRENG:
		ProjectSettings.set_setting(EINSTELLUNG + art, 1)
	for art: String in AUS:
		ProjectSettings.set_setting(EINSTELLUNG + art, 0)
	# settings_changed kommt verzögert; erst danach übernimmt der Parser die neuen Stufen.
	await process_frame
	await process_frame
	var skript: Script = get_script()
	var eigenes := skript.resource_path
	var dateien: Array[String] = []
	for ordner: String in BEREICHE:
		dateien.append_array(_skripte(ordner))
	var sammler := Sammler.new()
	OS.add_logger(sammler)
	var anzahl := 0
	for pfad: String in dateien:
		if pfad == eigenes:
			continue   # sich selbst neu zu übersetzen, während es läuft, ist nicht sicher
		sammler.neue_runde()
		ResourceLoader.load(pfad, "", ResourceLoader.CACHE_MODE_IGNORE)
		anzahl += 1
	OS.remove_logger(sammler)
	_bericht(sammler, anzahl)


func _bericht(sammler: Sammler, anzahl: int) -> void:
	var zaehlung: Dictionary[String, int] = {}     # "<bereich> <ART>" → Anzahl
	var summe := 0
	var pfade: Array = sammler.je_datei.keys()
	pfade.sort()
	for pfad: String in pfade:
		var bereich := _bereich(pfad)
		for eintrag: String in sammler.je_datei[pfad]:
			var teile: PackedStringArray = eintrag.split("\t", true, 2)
			print("WARNUNG %s %s %s:%s %s" % [bereich, teile[0], pfad.trim_prefix("res://"), teile[1], teile[2]])
			var schluessel := "%s %s" % [bereich, teile[0]]
			if not zaehlung.has(schluessel):
				zaehlung[schluessel] = 0
			zaehlung[schluessel] += 1
			summe += 1
	var schluessel_liste: Array[String] = zaehlung.keys()
	schluessel_liste.sort()
	for s: String in schluessel_liste:
		print("ZAEHLUNG %s %d" % [s, zaehlung[s]])
	for f: String in sammler.skriptfehler:
		print("SKRIPTFEHLER ", f)
	print("%d Skripte, %d Warnungen, %d Skriptfehler" % [anzahl, summe, sammler.skriptfehler.size()])
	quit(1 if not sammler.skriptfehler.is_empty() else 0)


static func _bereich(pfad: String) -> String:
	for ordner: String in BEREICHE:
		if pfad.begins_with(ordner + "/"):
			return ordner.trim_prefix("res://")
	return "andere"


## Alle .gd unter `ordner` (rekursiv), sortiert.
static func _skripte(ordner: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(ordner):
		if f.ends_with(".gd"):
			out.append(ordner.path_join(f))
	for sub: String in DirAccess.get_directories_at(ordner):
		out.append_array(_skripte(ordner.path_join(sub)))
	out.sort()
	return out
