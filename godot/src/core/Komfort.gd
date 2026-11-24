class_name Komfort
extends RefCounted
## KOMFORT — Einstellungen für empfindliche Besucher an einer Stelle.
##
## „Bewegung reduzieren" nimmt Kamerastöße und Zoom-Stöße heraus; die Kamera folgt
## Paul weiter weich. Umschalten im Pausemenü. Lehre aus dem Strategiespiel (projekt-e,
## docs/wissen/11_effekte_zauber_klang.md): Saft wie Kamerastöße immer abschaltbar
## machen, am Messestand ist das Barrierefreiheit.
##
## Gespeichert in user://einstellungen.cfg (Abschnitt „komfort", neben dem Ton). Im
## Messe-Kiosk gilt die Wahl wie Musik und Töne nur für den laufenden Besucher
## (Kiosk.consume_idle_reset setzt zurück); Testläufe schreiben nichts.

const DATEI := "user://einstellungen.cfg"

## Nur für Tests: eigene Datei statt der echten Einstellungen.
static var datei_override := ""
static var _geladen := false
static var _ruhig := false


## Faktor für Kamerastöße und Zoom-Stöße: 1 normal, 0 bei „Bewegung reduzieren".
static func bewegung() -> float:
	return 0.0 if bewegung_reduziert() else 1.0


static func bewegung_reduziert() -> bool:
	_laden()
	return _ruhig


static func setze_bewegung_reduziert(an: bool) -> void:
	_laden()
	_ruhig = an
	if not _speichern_erlaubt():
		return
	var cf := ConfigFile.new()
	cf.load(_datei())   # Ton-Einstellungen in derselben Datei behalten
	cf.set_value("komfort", "bewegung_reduziert", an)
	cf.save(_datei())


## Messe-Kiosk: Beim Idle-Reset (neuer Besucher) gilt wieder volle Bewegung.
static func besucher_zuruecksetzen() -> void:
	_geladen = true
	_ruhig = false


static func _laden() -> void:
	if _geladen:
		return
	_geladen = true
	if not _speichern_erlaubt():
		return   # Kiosk und Testläufe starten immer mit voller Bewegung
	var cf := ConfigFile.new()
	if cf.load(_datei()) == OK:
		_ruhig = bool(cf.get_value("komfort", "bewegung_reduziert", false))


static func _datei() -> String:
	return datei_override if datei_override != "" else DATEI


static func _speichern_erlaubt() -> bool:
	var ml := Engine.get_main_loop() as SceneTree
	var k: Node = ml.root.get_node_or_null("Kiosk") if ml != null else null
	if k != null and bool(k.get("kiosk_mode")):
		return false
	if datei_override != "":
		return true
	return not Statistik.ist_testlauf()
