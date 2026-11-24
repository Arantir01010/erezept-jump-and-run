extends SceneTree
## TESTLAUF der Godot-Fassung — ohne Fenster, für Menschen und CI:
##
##   godot --headless --path godot --fixed-fps 60 --script res://tests/lauf.gd
##   godot … --script res://tests/lauf.gd -- --nur=huelle     (nur passende Dateien)
##
## Findet tests/test_*.gd, legt je Methode test_* ein frisches Objekt an und ruft
## sie auf (await erlaubt). Gewertet werden die Prüfungen des Tests UND jede
## Fehlermeldung der Engine/Skripte währenddessen (fehlerzaehler.gd).
## Letzte Zeile: „N Tests, M fehlgeschlagen"; Exit-Code 0 = alles grün, 1 = Fehler,
## 2 = Wachhund (Lauf hing länger als WACHHUND_S Sekunden Echtzeit).
## --fixed-fps 60 macht die Spielzeit unabhängig vom Rechner: ein Frame = 1/60 s.

const ORDNER := "res://tests/"
const WACHHUND_S := 900.0

var _zaehler: Logger
var _start_ms := 0


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	_zaehler = load(ORDNER + "fehlerzaehler.gd").new()
	OS.add_logger(_zaehler)
	# Erst im ersten Frame starten: dann haben die Autoloads (Game, Sfx, Kiosk) ihr _ready gehabt.
	process_frame.connect(_starten, CONNECT_ONE_SHOT)


func _process(_delta: float) -> bool:
	if (Time.get_ticks_msec() - _start_ms) / 1000.0 > WACHHUND_S:
		printerr("Wachhund: Testlauf hängt seit %.0f s — Abbruch." % WACHHUND_S)
		quit(2)
	return false


func _starten() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--nur="):
			filter = str(a).get_slice("=", 1)
	var dateien: Array[String] = []
	for f in DirAccess.get_files_at(ORDNER):
		if f.begins_with("test_") and f.ends_with(".gd") and (filter == "" or filter in f):
			dateien.append(f)
	dateien.sort()

	var anzahl := 0
	var fehlgeschlagen := 0
	var liste: Array[String] = []
	for f in dateien:
		var vorher_laden := (_zaehler as Object).call("anzahl") as int
		var skript := load(ORDNER + f) as GDScript
		if skript == null or not skript.can_instantiate():
			print("✗ %s lässt sich nicht laden" % f)
			for m in (_zaehler as Object).call("seit", vorher_laden):
				print("      ", m)
			anzahl += 1
			fehlgeschlagen += 1
			liste.append(f)
			continue
		print("▸ %s" % f.get_basename())
		for m in skript.get_script_method_list():
			var name := str(m["name"])
			if not name.begins_with("test_"):
				continue
			var fall: Object = skript.new()
			fall.set("baum", self)
			var vorher := (_zaehler as Object).call("anzahl") as int
			var t0 := Time.get_ticks_msec()
			await fall.call(name)
			# Verzögerte Rückrufe (CONNECT_DEFERRED, call_deferred) dem Test noch zuordnen
			await process_frame
			await process_frame
			var probleme: Array = (fall.get("fehler") as Array).duplicate()
			for meldung in (_zaehler as Object).call("seit", vorher):
				probleme.append("Fehlermeldung: " + str(meldung))
			anzahl += 1
			if probleme.is_empty():
				print("  ✓ %s (%d ms)" % [name, Time.get_ticks_msec() - t0])
			else:
				fehlgeschlagen += 1
				liste.append("%s.%s" % [f.get_basename(), name])
				print("  ✗ %s" % name)
				for p in probleme.slice(0, 15):
					print("      ", p)
				if probleme.size() > 15:
					print("      … und %d weitere" % (probleme.size() - 15))
			if fall.has_method("aufraeumen"):
				await fall.call("aufraeumen")

	var warnungen: Array = (_zaehler as Object).get("warnungen")
	print("")
	if not warnungen.is_empty():
		print("%d Warnungen (nicht gewertet), z. B.: %s" % [warnungen.size(), warnungen[0]])
	if not liste.is_empty():
		print("Fehlgeschlagen: ", ", ".join(liste))
	print("%d Tests, %d fehlgeschlagen (%.1f s)" % [anzahl, fehlgeschlagen, (Time.get_ticks_msec() - _start_ms) / 1000.0])
	OS.remove_logger(_zaehler)
	quit(1 if fehlgeschlagen > 0 else 0)
