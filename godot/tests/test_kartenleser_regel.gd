extends "res://tests/testfall.gd"
## KARTENLESER-REGEL ohne Szene: Die Zeit kommt als Argument, das Ergebnis des
## Steckens auch (wie aus Game.insert_card). Gleiche Abläufe wie der Leser im Level
## (test_kartenleser.gd), hier mit genauen Schwellen.

const PASSEND := {"result": "ok", "card": "egk"}
const FALSCH := {"result": "falsche-karte", "card": ""}
const KEINE := {"result": "nicht-dabei", "card": ""}
const BELEGT := {"result": "belegt", "card": ""}


## In Schritten von 0,1 s weiterlaufen; anim_t bleibt dabei stehen.
func _laufen(r: KartenleserRegel, dauer: float, anim_t := 0.0) -> void:
	for _i in roundi(dauer * 10.0):
		r.tick(0.1, anim_t)


func test_kartenliste_aus_den_leveldaten() -> void:
	gleich(KartenleserRegel.karten_aus("eGK, HBA"), ["egk", "hba"], "Text mit Komma")
	gleich(KartenleserRegel.karten_aus(["SMCB"]), ["smcb"], "Liste")
	gleich(KartenleserRegel.karten_aus([]), ["egk"], "leere Liste → eGK")


func test_anfangs_rot_und_bereit() -> void:
	var r := KartenleserRegel.new()
	gleich(r.led, KartenleserRegel.ROT, "LED")
	gleich(r.status, "stecken", "Anzeige")
	pruefe(r.kann_stecken(), "bereit zum Stecken")


func test_passende_karte_oeffnet_das_tor_einmal() -> void:
	var r := KartenleserRegel.new()
	pruefe(r.stecken(PASSEND, true), "erste passende Karte öffnet das Tor")
	gleich(r.eingesteckt, "egk", "steckt logisch")
	gleich(r.led, KartenleserRegel.GELB, "LED prüft")
	gleich(r.status, "prueft", "Anzeige prüft")
	pruefe(r.geoeffnet and r.ansage_offen, "Tor gemerkt, Ansage fällig")
	r.bewegung("rein", r.eingesteckt)
	pruefe(not r.kann_stecken(), "während des Gleitens kein zweiter Versuch")
	_laufen(r, 0.5, 0.9)
	gleich(r.steckt, "", "sitzt erst nach dem Gleiten")
	pruefe(r.bewegung_fertig(), "Karte sitzt")
	gleich(r.steckt, "egk", "sichtbar im Schlitz")
	gleich(r.led, KartenleserRegel.GRUEN, "LED grün")
	gleich(r.status, "frei", "Anzeige frei")
	gleich(r.blitz, 1.0, "LED blitzt auf")
	pruefe(r.ansage_abholen(), "Ansage jetzt")
	pruefe(not r.ansage_abholen(), "Ansage nur einmal")
	# Weggehen: Karte gleitet heraus, beim zweiten Stecken bleibt das Tor-Merkmal
	gleich(r.weggehen(), "egk", "Karte gleitet heraus")
	gleich(r.eingesteckt, "", "nichts steckt logisch")
	gleich(r.steckt, "", "nichts sitzt")
	gleich(r.led, KartenleserRegel.ROT, "LED rot")
	gleich(r.status, "stecken", "Anzeige zurück")
	r.bewegung("raus", "egk")
	pruefe(not r.bewegung_fertig(), "Herausgleiten setzt keine Karte")
	pruefe(not r.stecken(PASSEND, true), "Tor geht nur beim ersten Mal auf")
	pruefe(not r.ansage_offen, "keine zweite Ansage")


func test_ohne_tor_keine_ansage() -> void:
	var r := KartenleserRegel.new()
	pruefe(not r.stecken(PASSEND, false), "kein Tor, nichts geht auf")
	pruefe(not r.geoeffnet and not r.ansage_offen, "nichts gemerkt")


func test_weggehen_waehrend_des_hineingleitens() -> void:
	var r := KartenleserRegel.new()
	r.stecken(PASSEND, true)
	r.bewegung("rein", "egk")
	gleich(r.weggehen(), "egk", "die gleitende Karte kommt wieder heraus")
	pruefe(not r.ansage_offen, "Ansage verfällt")
	var leer := KartenleserRegel.new()
	gleich(leer.weggehen(), "", "ohne Karte gleitet nichts")


func test_falsche_karte_prallt_einmal_ab() -> void:
	var r := KartenleserRegel.new()
	pruefe(not r.stecken(FALSCH, true), "falsche Karte öffnet nichts")
	gleich(r.led, KartenleserRegel.GELB, "LED prüft")
	gleich(r.status, "prueft", "Anzeige prüft")
	gleich(r.eingesteckt, "", "nichts steckt")
	r.bewegung("abgelehnt", "hba")
	pruefe(not r.tick(0.1, 0.49), "vor der Hälfte kein Abweis-Moment")
	pruefe(r.tick(0.1, 0.5), "Abweis-Moment bei der Hälfte")
	gleich(r.led, KartenleserRegel.ROT, "LED rot")
	gleich(r.status, "abgelehnt", "Anzeige abgelehnt")
	gleich(r.rempler, 1.0, "Rempler")
	nahe(r.led_bis, r.uhr + 1.4, 0.0001, "LED-Frist 1,4 s")
	nahe(r.status_bis, r.uhr + 2.6, 0.0001, "Anzeige-Frist 2,6 s")
	pruefe(not r.tick(0.1, 0.8), "Abweis-Moment nur einmal")
	nahe(r.rempler, 0.7, 0.0001, "Rempler klingt ab (3 je Sekunde)")
	pruefe(not r.bewegung_fertig(), "abgeprallte Karte sitzt nicht")
	_laufen(r, 1.5)
	gleich(r.led, KartenleserRegel.ROT, "LED nach der Frist rot (keine Karte)")
	gleich(r.led_bis, 0.0, "LED-Frist vorbei")
	gleich(r.status, "abgelehnt", "Anzeige hält noch")
	_laufen(r, 1.3)
	gleich(r.status, "stecken", "Anzeige zurück")
	pruefe(r.kann_stecken(), "wieder bereit")


func test_ohne_karte_und_karte_steckt_woanders() -> void:
	var r := KartenleserRegel.new()
	r.stecken(KEINE, true)
	gleich(r.led, KartenleserRegel.ROT, "LED bleibt rot")
	gleich(r.status, "keine", "Anzeige keine Karte")
	_laufen(r, 2.3)
	gleich(r.status, "keine", "hält 2,4 s")
	_laufen(r, 0.2)
	gleich(r.status, "stecken", "dann zurück")
	r.stecken(BELEGT, true)
	gleich(r.nicken, 1.0, "Kopfschütteln")
	gleich(r.led, KartenleserRegel.GELB, "LED gelb")
	gleich(r.status, "belegt", "Anzeige belegt")
	_laufen(r, 0.3)
	nahe(r.nicken, 1.0 - 0.3 * 2.2, 0.0001, "Kopfschütteln klingt ab (2,2 je Sekunde)")
	_laufen(r, 1.1)
	gleich(r.led, KartenleserRegel.ROT, "LED nach 1,2 s zurück")
	gleich(r.status, "belegt", "Anzeige hält 2,6 s")
	_laufen(r, 1.4)
	gleich(r.status, "stecken", "Anzeige zurück")
	gleich(r.nicken, 0.0, "Kopfschütteln vorbei, nie negativ")


func test_led_und_anzeige_kehren_zur_sitzenden_karte_zurueck() -> void:
	var r := KartenleserRegel.new()
	r.stecken(PASSEND, false)
	r.bewegung("rein", "egk")
	r.bewegung_fertig()
	r.led = KartenleserRegel.GELB
	r.led_bis = r.uhr + 0.3
	r.status = "belegt"
	r.status_bis = r.uhr + 0.3
	_laufen(r, 0.4)
	gleich(r.led, KartenleserRegel.GRUEN, "LED zurück auf grün, solange die Karte sitzt")
	gleich(r.status, "frei", "Anzeige zurück auf frei")
	nahe(r.blitz, 0.2, 0.0001, "Aufblitzen klingt ab (2 je Sekunde)")


func test_gleiche_eingaben_gleicher_zustand() -> void:
	var a := KartenleserRegel.new()
	var b := KartenleserRegel.new()
	var laeufe: Array[KartenleserRegel] = [a, b]
	for r in laeufe:
		r.stecken(FALSCH, true)
		r.bewegung("abgelehnt", "hba")
		r.tick(0.25, 0.3)
		r.tick(0.25, 0.6)
		r.tick(0.7, 1.0)
		r.bewegung_fertig()
	gleich([a.uhr, a.led, a.led_bis, a.status, a.status_bis, a.rempler, a.blitz],
		[b.uhr, b.led, b.led_bis, b.status, b.status_bis, b.rempler, b.blitz], "zwei Läufe, ein Zustand")
