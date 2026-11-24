class_name Eingabespur
extends RefCounted
## EINGABESPUR — eine gespielte Station als Eingabefolge, für den Durchspieltreiber
## (tests/durchspiel.gd): Welche Spielaktion war ab welchem Physikschritt seit
## Stationsbeginn wie stark gedrückt (nur die Wechsel), wo stand Paul alle
## SPUR_ABSTAND Schritte, und wie endete die Station. Aufgenommen wird von
## src/autoload/Aufnahme.gd — vom Menschen (--aufnahme=<datei>) oder vom Suchbot.
##
## Datei (JSON, Format 1; tools/pruefen.py Stufe 7 spielt tests/durchspiel/*.json ab):
##   {"format": 1, "station": "01-stammdaten", "quelle": "mensch", "saat": 20261124,
##    "physik_hz": 60, "takt_fest": true, "pausiert": false,
##    "eingaben": [[schritt, "aktion", stärke, "art"], …],
##    "spur": [[schritt, x, y], …],
##    "ende": {"schritt": n, "ergebnis": "ziel", "x": …, "y": …}}
## Arten: e = Ereignis (kommt wie ein Tastendruck vor dem Physikschritt an),
## b = vom Spiel selbst im Bildtakt gedrückt (Kiosk: „hoch halten = Hülle“ per
## Input.action_press), h = beim Stationsbeginn schon gehalten (Schritt 0).

const FORMAT := 1
## Feste Saat: Aufnahme und Wiedergabe säen den Zufall beim Einhängen des Levels damit.
const SAAT := 20261124
## Die Spielaktionen (wie Kiosk.ACTIONS, tests/test_durchspiel.gd prüft das). Menü-
## Aktionen (confirm, pause) fehlen mit Absicht: Eine Aufnahme spielt eine Station.
const AKTIONEN: Array[String] = ["move_left", "move_right", "move_up", "move_down", "jump", "action", "toggle"]
const ARTEN: Array[String] = ["e", "b", "h"]
const ERGEBNISSE: Array[String] = ["ziel", "absturz", "haenger", "falsch"]
## Pauls Position wird alle SPUR_ABSTAND Physikschritte notiert (0,5 s bei 60 Hz).
const SPUR_ABSTAND := 30

var station := ""
var quelle := "mensch"
var saat := SAAT
var physik_hz := 60
## Aufgenommen mit festem Takt (--fixed-fps 60)? Sonst kann die Wiedergabe abweichen.
var takt_fest := true
## Während der Aufnahme pausiert? Gezählt werden nur Schritte ohne Pause; eine Taste,
## die in der Pause gedrückt und danach gehalten wird, kann die Wiedergabe verschieben.
var pausiert := false
var ende_schritt := -1
var ende_ergebnis := ""
var ende_position := Vector2.ZERO
## Befunde beim Laden (leer = gültig)
var fehler: Array[String] = []

var _schritte := PackedInt32Array()
var _aktionen := PackedStringArray()
var _staerken := PackedFloat64Array()
var _arten := PackedStringArray()
var _spur_schritte := PackedInt32Array()
var _spur_orte := PackedVector2Array()


func neu(id: String, woher: String) -> void:
	station = id
	quelle = woher
	saat = SAAT
	physik_hz = Engine.physics_ticks_per_second
	takt_fest = true
	pausiert = false
	ende_schritt = -1
	ende_ergebnis = ""
	ende_position = Vector2.ZERO
	fehler.clear()
	_schritte.clear()
	_aktionen.clear()
	_staerken.clear()
	_arten.clear()
	_spur_schritte.clear()
	_spur_orte.clear()


# ------------------------------------------------------------------ Aufnehmen

func wechsel(schritt: int, aktion: String, staerke: float, art := "e") -> void:
	_schritte.append(schritt)
	_aktionen.append(aktion)
	_staerken.append(staerke)
	_arten.append(art)


func punkt(schritt: int, ort: Vector2) -> void:
	_spur_schritte.append(schritt)
	_spur_orte.append(ort)


func abschliessen(schritt: int, ergebnis: String, ort: Vector2) -> void:
	ende_schritt = schritt
	ende_ergebnis = ergebnis
	ende_position = ort


# ------------------------------------------------------------------ Lesen

func anzahl() -> int:
	return _schritte.size()


func schritt_bei(i: int) -> int:
	return _schritte[i]


func aktion_bei(i: int) -> String:
	return _aktionen[i]


func staerke_bei(i: int) -> float:
	return _staerken[i]


func art_bei(i: int) -> String:
	return _arten[i]


## Letzter Schritt mit einer Eingabe oder dem Ende (0 = leer).
func letzter_schritt() -> int:
	var n := 0
	if not _schritte.is_empty():
		n = _schritte[_schritte.size() - 1]
	return maxi(n, ende_schritt)


func spur_anzahl() -> int:
	return _spur_schritte.size()


func spur_schritt_bei(i: int) -> int:
	return _spur_schritte[i]


func spur_ort_bei(i: int) -> Vector2:
	return _spur_orte[i]


## Pauls notierte Position in `schritt`, sonst Vector2.INF.
func ort_bei(schritt: int) -> Vector2:
	var i := _spur_schritte.find(schritt)
	return _spur_orte[i] if i >= 0 else Vector2.INF


## Erste Abweichung der Spur von `soll` (beide Spuren an denselben Schritten).
## Rückgabe {} = deckungsgleich, sonst {"schritt", "soll", "ist", "abstand"}.
func erste_abweichung(soll: Eingabespur, toleranz := 0.01) -> Dictionary:
	for i in _spur_schritte.size():
		var s := _spur_schritte[i]
		var o := soll.ort_bei(s)
		if o == Vector2.INF:
			continue
		var d := o.distance_to(_spur_orte[i])
		if d > toleranz:
			return {"schritt": s, "soll": o, "ist": _spur_orte[i], "abstand": d}
	return {}


# ------------------------------------------------------------------ Datei

func als_daten() -> Dictionary:
	var eingaben: Array = []
	for i in _schritte.size():
		eingaben.append([_schritte[i], _aktionen[i], _staerken[i], _arten[i]])
	var spur: Array = []
	for i in _spur_schritte.size():
		spur.append([_spur_schritte[i], _spur_orte[i].x, _spur_orte[i].y])
	return {
		"format": FORMAT, "station": station, "quelle": quelle, "saat": saat,
		"physik_hz": physik_hz, "takt_fest": takt_fest, "pausiert": pausiert,
		"eingaben": eingaben, "spur": spur,
		"ende": {"schritt": ende_schritt, "ergebnis": ende_ergebnis, "x": ende_position.x, "y": ende_position.y},
	}


## Als Text: Kopf und Ende kompakt, je Eingabe und Spurpunkt eine Zeile (lesbare Diffs).
func als_text() -> String:
	var d := als_daten()
	var zeilen: PackedStringArray = ["{"]
	for k: String in ["format", "station", "quelle", "saat", "physik_hz", "takt_fest", "pausiert"]:
		zeilen.append("\t%s: %s," % [JSON.stringify(k), JSON.stringify(d[k], "", false, true)])
	for k: String in ["eingaben", "spur"]:
		var liste: Array = d[k]
		zeilen.append("\t%s: [" % JSON.stringify(k))
		for i in liste.size():
			zeilen.append("\t\t%s%s" % [JSON.stringify(liste[i], "", false, true), "," if i < liste.size() - 1 else ""])
		zeilen.append("\t],")
	zeilen.append("\t\"ende\": %s" % JSON.stringify(d["ende"], "", true, true))
	zeilen.append("}")
	return "\n".join(zeilen) + "\n"


func speichern(pfad: String) -> Error:
	var ordner := pfad.get_base_dir()
	if ordner != "" and not DirAccess.dir_exists_absolute(ordner):
		var e := DirAccess.make_dir_recursive_absolute(ordner)
		if e != OK:
			return e
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(als_text())
	f.close()
	return OK


static func laden(pfad: String) -> Eingabespur:
	if not FileAccess.file_exists(pfad):
		var leer := Eingabespur.new()
		leer.fehler.append("Datei fehlt: %s" % pfad)
		return leer
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(pfad)) != OK:
		var kaputt := Eingabespur.new()
		kaputt.fehler.append("kein JSON (Zeile %d: %s)" % [json.get_error_line(), json.get_error_message()])
		return kaputt
	return aus_daten(json.data)


## Aus geparstem JSON; jede Unstimmigkeit landet in `fehler` (die Spur bleibt dann leer).
static func aus_daten(roh: Variant) -> Eingabespur:
	var s := Eingabespur.new()
	if not roh is Dictionary:
		s.fehler.append("oberste Ebene ist kein Objekt")
		return s
	var d: Dictionary = roh
	var format_wert: Variant = d.get("format", null)
	if not _ist_zahl(format_wert) or _ganz(format_wert) != FORMAT:
		s.fehler.append("„format“ ist nicht %d" % FORMAT)
		return s
	var st: Variant = d.get("station", null)
	if not st is String or str(st) == "":
		s.fehler.append("„station“ fehlt")
	else:
		s.station = str(st)
	var q: Variant = d.get("quelle", "mensch")
	s.quelle = str(q)
	var saat_wert: Variant = d.get("saat", SAAT)
	s.saat = _ganz(saat_wert) if _ist_zahl(saat_wert) else SAAT
	var hz: Variant = d.get("physik_hz", 60)
	s.physik_hz = _ganz(hz) if _ist_zahl(hz) else 0
	s.takt_fest = _wahr(d.get("takt_fest", true))
	s.pausiert = _wahr(d.get("pausiert", false))

	var eingaben: Variant = d.get("eingaben", null)
	if not eingaben is Array:
		s.fehler.append("„eingaben“ ist keine Liste")
	else:
		var liste: Array = eingaben
		var vorher := 0
		for i in liste.size():
			var e: Variant = liste[i]
			var grund := _eingabe_fehler(e)
			if grund != "":
				s.fehler.append("Eingabe %d: %s" % [i, grund])
				continue
			var feld: Array = e
			var schritt := _ganz(feld[0])
			if schritt < vorher:
				s.fehler.append("Eingabe %d: Schritt %d vor Schritt %d (nicht sortiert)" % [i, schritt, vorher])
			vorher = schritt
			var aktion: String = feld[1]
			var staerke: float = feld[2]
			var art: String = feld[3]
			s.wechsel(schritt, aktion, staerke, art)

	var spur: Variant = d.get("spur", [])
	if not spur is Array:
		s.fehler.append("„spur“ ist keine Liste")
	else:
		var punkte: Array = spur
		for i in punkte.size():
			var p: Variant = punkte[i]
			var pf: Array = p if p is Array else []
			if pf.size() != 3:
				s.fehler.append("Spurpunkt %d: erwartet [schritt, x, y]" % i)
				continue
			if not (_ist_zahl(pf[0]) and _ist_zahl(pf[1]) and _ist_zahl(pf[2])):
				s.fehler.append("Spurpunkt %d: keine Zahlen" % i)
				continue
			var x: float = pf[1]
			var y: float = pf[2]
			s.punkt(_ganz(pf[0]), Vector2(x, y))

	var ende: Variant = d.get("ende", null)
	if not ende is Dictionary:
		s.fehler.append("„ende“ fehlt")
	else:
		var ed: Dictionary = ende
		var es: Variant = ed.get("schritt", null)
		var eg: Variant = ed.get("ergebnis", null)
		var ex: Variant = ed.get("x", null)
		var ey: Variant = ed.get("y", null)
		if not (_ist_zahl(es) and eg is String and _ist_zahl(ex) and _ist_zahl(ey)):
			s.fehler.append("„ende“ braucht schritt, ergebnis, x, y")
		elif not ERGEBNISSE.has(str(eg)):
			s.fehler.append("„ende.ergebnis“ unbekannt: %s" % str(eg))
		else:
			var x2: float = ex
			var y2: float = ey
			s.abschliessen(_ganz(es), str(eg), Vector2(x2, y2))
	if s.physik_hz != Engine.physics_ticks_per_second:
		s.fehler.append("aufgenommen mit %d Physikschritten/s, das Spiel läuft mit %d" % [s.physik_hz, Engine.physics_ticks_per_second])
	return s


static func _eingabe_fehler(e: Variant) -> String:
	if not e is Array:
		return "keine Liste"
	var feld: Array = e
	if feld.size() != 4:
		return "erwartet [schritt, aktion, stärke, art]"
	if not _ist_zahl(feld[0]) or _ganz(feld[0]) < 0:
		return "Schritt ist keine Zahl ≥ 0"
	if not feld[1] is String or not AKTIONEN.has(str(feld[1])):
		return "unbekannte Aktion %s" % str(feld[1])
	if not _ist_zahl(feld[2]):
		return "Stärke ist keine Zahl"
	var staerke: float = feld[2]
	if staerke < 0.0 or staerke > 1.0:
		return "Stärke %s außerhalb 0…1" % str(staerke)
	if not feld[3] is String or not ARTEN.has(str(feld[3])):
		return "unbekannte Art %s" % str(feld[3])
	return ""


static func _ist_zahl(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _wahr(v: Variant) -> bool:
	return typeof(v) == TYPE_BOOL and v == true


## JSON liefert Zahlen als float — ganzzahlig lesen.
static func _ganz(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		var i: int = v
		return i
	var f: float = v
	return roundi(f)
