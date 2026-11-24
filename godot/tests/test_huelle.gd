extends "res://tests/testfall.gd"
## Kernmechanik „Hülle" (src/state/Huelle.gd) — Port der Phaser-Tests
## tools/test/huelle.test.ts, dazu die fachlichen Leitplanken aus CLAUDE.md:
## VAU ist ein Raum (Klartext-Tempo, unsichtbar, andockfähig), Verschlüsselung ist
## keine Signatur, abgelaufene Sitzung fällt in den KLARTEXT zurück.


func _neu(cooldown := 0.0) -> Huelle:
	var h := Huelle.new()
	h.toggle_cooldown = cooldown
	return h


func test_startet_im_klartext() -> void:
	var h := _neu()
	gleich(h.state, Huelle.KLARTEXT, "Startzustand")
	gleich(h.speed_factor, 1.0, "Klartext-Tempo")
	pruefe(h.sichtbar, "Klartext muss sichtbar sein")
	pruefe(h.andockfaehig, "Klartext muss andocken können")


func test_jeder_zustand_hat_eigene_wirkung() -> void:
	var gesehen := {}
	for s in Huelle.TUNING:
		var e: Dictionary = Huelle.TUNING[s]
		gesehen["%s|%s|%s" % [e["speed"], e["sichtbar"], e["andock"]]] = true
	gleich(gesehen.size(), Huelle.TUNING.size(), "Zustände müssen unterscheidbar sein")


func test_verschluesselt_ist_der_zielkonflikt() -> void:
	var e: Dictionary = Huelle.TUNING[Huelle.VERSCHLUESSELT]
	pruefe(float(e["speed"]) < 1.0, "verschlüsselt muss langsamer sein")
	pruefe(float(e["speed"]) > 0.0, "kein Zustand darf Bewegung unmöglich machen")
	pruefe(not e["sichtbar"], "verschlüsselt ist unsichtbar")
	pruefe(not e["andock"], "verschlüsselt kann nicht andocken")


func test_vau_ist_ein_raum_kein_tunnel() -> void:
	var vau: Dictionary = Huelle.TUNING[Huelle.VAU]
	var klar: Dictionary = Huelle.TUNING[Huelle.KLARTEXT]
	gleich(vau["speed"], klar["speed"], "in der VAU arbeitet man wie im Klartext")
	pruefe(not vau["sichtbar"], "Betreiber sieht in der VAU nichts")
	pruefe(vau["andock"], "in der VAU kann man arbeiten (andocken)")


func test_toggle_wechselt_hin_und_her() -> void:
	var h := _neu()
	pruefe(h.toggle(), "erster Wechsel")
	gleich(h.state, Huelle.VERSCHLUESSELT, "nach dem ersten Wechsel")
	pruefe(h.toggle(), "zweiter Wechsel")
	gleich(h.state, Huelle.KLARTEXT, "nach dem zweiten Wechsel")


func test_cooldown_gegen_prellen() -> void:
	var h := _neu(0.15)
	pruefe(h.toggle(), "erster Wechsel direkt erlaubt")
	h.tick(0.05)
	pruefe(not h.toggle(), "innerhalb des Cooldowns blockiert")
	gleich(h.state, Huelle.VERSCHLUESSELT, "Zustand bleibt bei blockiertem Toggle")
	h.tick(0.11)
	pruefe(h.toggle(), "nach Ablauf wieder erlaubt")


func test_gesperrt_wirkungslos() -> void:
	var h := _neu()
	h.locked = true
	pruefe(not h.can_toggle(), "gesperrt: can_toggle falsch")
	pruefe(not h.toggle(), "gesperrt: Toggle wirkungslos")
	gleich(h.state, Huelle.KLARTEXT, "Zustand unverändert")


func test_vau_ueberschreibt_und_stellt_wieder_her() -> void:
	var h := _neu()
	h.toggle()
	pruefe(h.enter_vau(), "VAU betreten")
	gleich(h.state, Huelle.VAU, "in der VAU")
	pruefe(not h.can_toggle(), "in der VAU nicht umschaltbar")
	pruefe(not h.toggle(), "Toggle in der VAU wirkungslos")
	pruefe(h.leave_vau(), "VAU verlassen")
	gleich(h.state, Huelle.VERSCHLUESSELT, "alte Hülle kommt zurück")


func test_vau_ohne_ttl_laeuft_nie_ab() -> void:
	var h := _neu()
	h.enter_vau(0.0)
	pruefe(not h.vau_expires, "ohne TTL kein Ablauf")
	h.tick(60.0)
	gleich(h.state, Huelle.VAU, "nach 60 s noch in der VAU")
	gleich(h.vau_ratio, 1.0, "Sitzungsanteil bleibt voll")


func test_abgelaufene_sitzung_faellt_in_klartext() -> void:
	var h := _neu()
	h.toggle()   # verschlüsselt hinein — die Lehre gilt trotzdem
	var gruende: Array = []
	h.changed.connect(func(_von, _nach, grund): gruende.append(grund))
	h.enter_vau(1.0)
	pruefe(h.vau_expires, "mit TTL läuft die Sitzung")
	h.tick(0.4)
	nahe(h.vau_ratio, 0.6, 1e-6, "Restanteil nach 0,4 s")
	h.tick(0.6)
	gleich(h.state, Huelle.KLARTEXT, "abgelaufen → KLARTEXT, nicht zurück in verschlüsselt")
	pruefe(h.sichtbar, "die Lehre: eine abgelaufene Sitzung schützt nicht")
	gleich(h.vau_left, 0.0, "keine Restzeit")
	pruefe(gruende.has("session-expired"), "Grund 'session-expired' gemeldet")


func test_auffrischen_haelt_die_sitzung() -> void:
	var h := _neu()
	h.enter_vau(1.0)
	h.tick(0.9)
	pruefe(h.refresh_session(), "Auffrischen bei laufender Sitzung")
	nahe(h.vau_left, 1.0, 1e-6, "volle Restzeit nach dem Auffrischen")
	h.tick(0.9)
	gleich(h.state, Huelle.VAU, "aufgefrischt → noch drin")


func test_auffrischen_nur_bei_laufender_sitzung() -> void:
	var h := _neu()
	pruefe(not h.refresh_session(), "außerhalb der VAU nichts aufzufrischen")
	h.enter_vau(0.0)
	pruefe(not h.refresh_session(), "ohne TTL nichts aufzufrischen")


func test_farbe_und_text_je_zustand() -> void:
	# Dreifach-Markierung (Farbe + Form + Text): Farben müssen sich unterscheiden
	var farben := {}
	for s in [Huelle.KLARTEXT, Huelle.VERSCHLUESSELT, Huelle.VAU]:
		farben[Huelle.color_of(s).to_html()] = true
		pruefe(Huelle.label_of(s) != "", "Beschriftung für %s" % s)
	gleich(farben.size(), 3, "drei verschiedene Hüllen-Farben")
