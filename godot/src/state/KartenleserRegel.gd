class_name KartenleserRegel
extends RefCounted
## KARTENLESER-REGEL — was das Kartenterminal (Baustein „kartenleser“) gerade weiß
## und zeigt, ohne Szene: LED, Anzeige, logisch und sichtbar steckende Karte, der
## Abweis-Moment der falschen Karte, Rempler, Kopfschütteln, Aufblitzen.
##
## Die Zeit kommt als Argument (tick), das Ergebnis des Steckens auch (aus
## Game.insert_card). Klang, Licht, Stempel, Sprechblasen und die Kartenbewegung
## (Tween, Fortschritt 0..1) bleiben im Baustein: Er meldet Anfang und Ende der
## Bewegung und fragt hier nach, was gilt.
## Fachlich: Die Karte öffnet, sie liefert keine Daten (Zugriff freigegeben).

const ROT := "rot"        # zu
const GELB := "gelb"      # prüft oder belegt
const GRUEN := "gruen"    # freigegeben

## Abweis-Moment bei diesem Fortschritt der Abprall-Bewegung (0..1)
const ABPRALL_BEI := 0.5

## Spielzeit seit dem Start des Terminals (Summe der tick-Schritte)
var uhr := 0.0
## Karte, die laut Spiellogik steckt (Game.insert_card „ok“), bis Paul weggeht
var eingesteckt := ""
## Das Tor am Terminal ging schon auf (nur beim ersten Mal: Bonus, Ansage)
var geoeffnet := false
## Karte, die sichtbar im Schlitz sitzt (nach dem Hineingleiten)
var steckt := ""
var led := ROT
## Spielzeit, zu der die LED in ihre Ruhe zurückfällt (0 = keine Frist)
var led_bis := 0.0
## Anzeige: stecken | prueft | frei | abgelehnt | keine | belegt
var status := "stecken"
var status_bis := 0.0
## Laufende Kartenbewegung: rein | raus | abgelehnt | "" (keine)
var anim := ""
var anim_karte := ""
## Abweis-Moment dieser Bewegung schon gewesen?
var abgeprallt := false
var blitz := 0.0          # Aufblitzen der LED, klingt ab
var rempler := 0.0        # falsche Karte: die Säule wackelt
var nicken := 0.0         # Karte steckt woanders: Kopfschütteln
## REZIs Stationstext ist fällig, sobald die erste passende Karte sitzt
var ansage_offen := false


## Kartenliste aus level.json: „egk,hba“ oder ["egk", "hba"]; leere Liste → eGK.
static func karten_aus(roh: Variant) -> Array:
	var out: Array = []
	if roh is String:
		for s in str(roh).split(","):
			out.append(s.strip_edges().to_lower())
	else:
		for s: Variant in roh:
			out.append(str(s).to_lower())
	if out.is_empty():
		out.append("egk")
	return out


## Darf jetzt gesteckt werden? (nichts steckt, keine Bewegung läuft)
func kann_stecken() -> bool:
	return eingesteckt == "" and anim == ""


## Spielzeit weiter. anim_t: Fortschritt der laufenden Kartenbewegung (0..1).
## Liefert true im Abweis-Moment (einmal je falscher Karte); Stempel und Hinweis
## sind dann Sache des Bausteins.
func tick(delta: float, anim_t: float) -> bool:
	uhr += delta
	blitz = maxf(0.0, blitz - delta * 2.0)
	rempler = maxf(0.0, rempler - delta * 3.0)
	nicken = maxf(0.0, nicken - delta * 2.2)
	if led_bis > 0.0 and uhr >= led_bis:
		led_bis = 0.0
		led = GRUEN if steckt != "" else ROT
	if status_bis > 0.0 and uhr >= status_bis:
		status_bis = 0.0
		_anzeige("frei" if steckt != "" else "stecken", 0.0)
	if anim == "abgelehnt" and not abgeprallt and anim_t >= ABPRALL_BEI:
		abgeprallt = true
		rempler = 1.0
		blitz = 1.0
		led = ROT
		led_bis = uhr + 1.4
		_anzeige("abgelehnt", 2.6)
		return true
	return false


## Ergebnis von Game.insert_card übernehmen (result: ok, falsche-karte, nicht-dabei,
## belegt). mit_tor: Hängt ein Tor an diesem Terminal? Liefert true, wenn das Tor
## jetzt aufgeht (erste passende Karte).
func stecken(ergebnis: Dictionary, mit_tor: bool) -> bool:
	match str(ergebnis.get("result", "")):
		"ok":
			eingesteckt = str(ergebnis.get("card", ""))
			led = GELB
			led_bis = 0.0
			_anzeige("prueft", 0.0)
			if mit_tor and not geoeffnet:
				geoeffnet = true
				ansage_offen = true
				return true
		"falsche-karte":
			led = GELB
			_anzeige("prueft", 0.0)
		"nicht-dabei":
			_anzeige("keine", 2.4)
		"belegt":
			nicken = 1.0
			led = GELB
			led_bis = uhr + 1.2
			_anzeige("belegt", 2.6)
	return false


## Eine Kartenbewegung beginnt (rein, raus, abgelehnt).
func bewegung(art: String, karte: String) -> void:
	anim = art
	anim_karte = karte
	abgeprallt = false


## Die Kartenbewegung ist fertig. Liefert true, wenn jetzt eine Karte sitzt (nach
## „rein“); dann steht sie in steckt.
func bewegung_fertig() -> bool:
	var art := anim
	anim = ""
	if art != "rein":
		return false
	steckt = anim_karte
	led = GRUEN
	led_bis = 0.0
	blitz = 1.0
	_anzeige("frei", 0.0)
	return true


## Paul geht weg und nimmt seinen Ausweis mit. Liefert die Karte, die wieder
## herausgleitet ("" = keine). Was logisch steckte, steht vorher in eingesteckt.
func weggehen() -> String:
	eingesteckt = ""
	ansage_offen = false
	var raus := ""
	if steckt != "" or anim == "rein":
		raus = steckt if steckt != "" else anim_karte
		steckt = ""
	led = ROT
	led_bis = 0.0
	_anzeige("stecken", 0.0)
	return raus


## REZIs Ansage abholen (einmal): true, wenn sie jetzt dran ist.
func ansage_abholen() -> bool:
	var dran := ansage_offen
	ansage_offen = false
	return dran


func _anzeige(key: String, halten: float) -> void:
	status = key
	status_bis = uhr + halten if halten > 0.0 else 0.0
