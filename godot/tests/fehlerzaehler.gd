extends Logger
## FEHLERZÄHLER — hängt sich als Logger an die Engine (OS.add_logger, Godot 4.5+)
## und sammelt jede Fehlermeldung: push_error, SCRIPT ERROR, Engine-Fehler.
## Der Testlauf (lauf.gd) wertet einen Test als fehlgeschlagen, wenn währenddessen
## eine Meldung kam — auch wenn alle Prüfungen grün waren (Fehler in Rückrufen,
## kaputte Signale, Laufzeitfehler in einem Baustein).
## Warnungen werden nur gezählt, nicht als Fehler gewertet.
## Logger-Methoden können aus anderen Threads kommen, daher die Sperre.

var meldungen: Array[String] = []
var warnungen: Array[String] = []
var _sperre := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var text := rationale if rationale != "" else code
	var wo := "%s:%d" % [file.get_file(), line] if file != "" else function
	_sperre.lock()
	if error_type == Logger.ERROR_TYPE_WARNING:
		warnungen.append("%s (%s)" % [text, wo])
	else:
		meldungen.append("%s (%s)" % [text, wo])
	_sperre.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func anzahl() -> int:
	_sperre.lock()
	var n := meldungen.size()
	_sperre.unlock()
	return n


## Alle Meldungen ab Position `ab` (Stand vor dem Test).
func seit(ab: int) -> Array[String]:
	_sperre.lock()
	var neu: Array[String] = meldungen.slice(ab)
	_sperre.unlock()
	return neu
