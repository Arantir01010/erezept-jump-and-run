extends RefCounted
## TESTFALL — Basis jeder Testdatei (tests/test_*.gd). lauf.gd legt je Methode
## test_* ein frisches Objekt an, setzt `baum` und ruft die Methode auf (await
## erlaubt). Prüfungen sammeln Fehlschläge, statt abzubrechen — so zeigt ein Lauf
## alle Abweichungen auf einmal.

var fehler: Array[String] = []
## Der laufende SceneTree: für Tests, die Knoten, Frames oder Spielzeit brauchen.
var baum: SceneTree


func pruefe(ok: bool, was: String) -> bool:
	if not ok:
		fehler.append(was)
	return ok


func gleich(ist: Variant, soll: Variant, was: String) -> bool:
	var vergleichbar := typeof(ist) == typeof(soll) or (_zahl(ist) and _zahl(soll))
	if vergleichbar and ist == soll:
		return true
	fehler.append("%s: erwartet %s, ist %s" % [was, var_to_str(soll), var_to_str(ist)])
	return false


func nahe(ist: float, soll: float, toleranz: float, was: String) -> bool:
	if absf(ist - soll) <= toleranz:
		return true
	fehler.append("%s: erwartet %.4f ± %.4f, ist %.4f" % [was, soll, toleranz, ist])
	return false


static func _zahl(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## n Prozess-Frames abwarten (mit --fixed-fps 60 sind das n/60 s Spielzeit).
func frames(n: int) -> void:
	for i in n:
		await baum.process_frame


## Spielzeit abwarten (Timer des Baums, läuft auch in der Pause nicht weiter).
func sekunden(s: float) -> void:
	await baum.create_timer(s).timeout


## Warten, bis `bedingung` wahr ist — höchstens `max_s` Sekunden Spielzeit.
func warte_bis(bedingung: Callable, max_s := 5.0) -> bool:
	var frist := int(max_s * 60.0)
	for i in frist:
		if bedingung.call():
			return true
		await baum.process_frame
	return bedingung.call()


## Alle Dateien mit `endung` unter `ordner` (rekursiv), sortiert.
static func dateien(ordner: String, endung: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(ordner):
		if f.ends_with(endung):
			out.append(ordner.path_join(f))
	for sub in DirAccess.get_directories_at(ordner):
		out.append_array(dateien(ordner.path_join(sub), endung))
	out.sort()
	return out
