extends "res://tests/testfall.gd"
## UNTERTITELLEISTE (Team-Feedback 9/2026, F4: „Text schwer lesbar vor bewegtem
## Hintergrund“, die REZI-Blase wanderte mit Figur und Kamera): Im Level stehen
## REZIs Sätze fest unten in der Mitte, im Bodenstreifen unter Pauls Laufhöhe.
## Lange Sätze brechen ausgeglichen um, nichts ragt aus dem Bild oder liegt auf
## Hülle-Anzeige, Karten oder der Steuerungs-Hinweiszeile. Auf dem Titelbild
## (ohne HUD) bleibt die Blase.

const SPRACHEN := ["de", "en", "fr", "es", "zh", "hi"]

var main: Node
var _extra: Array = []


func _station(id: String) -> Node:
	if not is_instance_valid(main):
		main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		baum.root.add_child(main)
		await frames(3)
	Kiosk.note_input()
	# Erst weiter, wenn die NEUE Station läuft (dieselbe Station noch einmal: die
	# alte bleibt bis nach der Blende stehen und wird dann freigegeben).
	# (Instanz-ID statt Knoten merken: ein freigegebener Knoten im Lambda meldet Fehler.)
	var alt: int = main.level.get_instance_id() if is_instance_valid(main.level) else 0
	main._start_level(maxi(0, Game.playlist.find(id)))
	var neu := func() -> bool: return main.screen == main.Screen.LEVEL and is_instance_valid(main.level) and main.level.get_instance_id() != alt and main.level._started and main.level.data.id == id
	await warte_bis(neu, 3.0)
	return main.level if neu.call() else null


func aufraeumen() -> void:
	Game.set_lang(Game.default_lang)
	Kiosk.set_input_mode("")
	baum.paused = false
	if is_instance_valid(main):
		main.queue_free()
	main = null
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	await frames(3)


func test_rezi_spricht_im_level_in_der_leiste() -> void:
	var lvl = await _station("04-die-huelle")
	if not pruefe(lvl != null, "Station 04 startet"):
		return
	var hud: HUD = main.hud
	lvl.rezi.say("Ein Satz für die Leiste.", 3.0)
	await frames(2)
	pruefe(hud.untertitel_box.visible and hud.untertitel_label.text == "Ein Satz für die Leiste.", "Satz steht in der Leiste („%s“)" % hud.untertitel_label.text)
	pruefe(not lvl.rezi.bubble.visible, "keine Blase in der Welt")
	gleich(lvl.rezi.spricht(), "Ein Satz für die Leiste.", "spricht() kennt den Satz")


func test_leiste_steht_fest_unten_in_der_mitte() -> void:
	var lvl = await _station("04-die-huelle")
	if not pruefe(lvl != null, "Station 04 startet"):
		return
	var hud: HUD = main.hud
	lvl.rezi.say("Kurzer Satz.", 6.0)
	await frames(12)
	var r := hud.untertitel_box.get_global_rect()
	nahe(r.get_center().x, 960.0, 2.0, "mittig")
	pruefe(r.end.y <= 1080.0 - 30.0 and r.position.y >= 900.0, "im Bodenstreifen unten (%s)" % r)
	# Paul und Kamera bewegen sich, die Leiste nicht
	lvl.player.global_position.x += 900.0
	lvl.player.global_position.y -= 200.0
	await frames(40)
	var r2 := hud.untertitel_box.get_global_rect()
	pruefe(r2.position.is_equal_approx(r.position), "Leiste wandert nicht mit (%s → %s)" % [r.position, r2.position])


func test_leiste_blendet_nach_lesezeit_aus() -> void:
	var lvl = await _station("04-die-huelle")
	if not pruefe(lvl != null, "Station 04 startet"):
		return
	var hud: HUD = main.hud
	lvl.rezi.say("Hallo.", 0.0)
	await frames(2)
	pruefe(hud.untertitel_box.visible, "Leiste erscheint")
	await frames(int((Rezi.LESEN_MIN + 0.6) * 60))
	pruefe(not hud.untertitel_box.visible, "nach der Lesezeit wieder weg")
	gleich(lvl.rezi.spricht(), "", "REZI schweigt")


func test_lange_saetze_ausgeglichen_und_im_bild() -> void:
	var bild := Rect2(30, 20, 1920 - 60, 1080 - 40)
	var fehler := 0
	for sprache in SPRACHEN:
		Game.set_lang(sprache)
		var lvl = await _station("05-identitaet")
		if lvl == null:
			pruefe(false, "%s: Station 05 startet" % sprache)
			continue
		var hud: HUD = main.hud
		# die längsten Sätze im Spiel: Tür-Abweisung mit Ausweg (zwei Zeilen) und der Hängen-Tipp
		var tuer := tr("Noch %d %s sammeln!") % [4, Game.t(lvl.data.collect_label)] + "\n" + tr("Hängst du fest? %s: Pause, dann „Station neu starten“.") % Kiosk.label_pause()
		var tipp := BriefingDaten.tasten(Game.t(lvl.data.stuck_hint))
		# dazu ein Satz, der sicher umbrechen muss (der Tipp so oft, bis er über 1,4 Zeilen geht)
		var f_satz: Font = hud.untertitel_label.label_settings.font
		var lang := tipp
		while f_satz.get_string_size(lang, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD.UNTERTITEL_GROESSE).x < HUD.UNTERTITEL_MAX * 1.4:
			lang += ("" if sprache == "zh" else " ") + tipp
		for satz in [tuer, tipp, lang]:
			lvl.rezi.say(satz, 5.0)
			await frames(6)
			var wo := "%s: „%s“" % [sprache, satz.left(30)]
			var r := hud.untertitel_box.get_global_rect()
			var ok := pruefe(bild.encloses(r), "%s ragt aus dem Bild %s" % [wo, r])
			ok = pruefe(hud.untertitel_label.get_line_count() <= 3, "%s: höchstens drei Zeilen (%d)" % [wo, hud.untertitel_label.get_line_count()]) and ok
			ok = pruefe(hud.untertitel_label.size.x <= HUD.UNTERTITEL_MAX + 2.0, "%s: Zeile höchstens %d px (%d)" % [wo, HUD.UNTERTITEL_MAX, hud.untertitel_label.size.x]) and ok
			if satz == lang:
				ok = pruefe(hud.untertitel_label.get_line_count() >= 2, "%s: langer Satz bricht um" % wo) and ok
			for p in [hud.huelle_box, hud.huelle_hint, hud.cards_box]:
				if (p as Control).visible:
					ok = pruefe(not r.intersects((p as Control).get_global_rect()), "%s liegt auf Hülle-Anzeige oder Karten" % wo) and ok
			if sprache != "zh":
				var f: Font = hud.untertitel_label.label_settings.font
				for wort in satz.replace("\n", " ").split(" ", false):
					var w := f.get_string_size(wort, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD.UNTERTITEL_GROESSE).x
					ok = pruefe(w <= hud.untertitel_label.size.x + 2.0, "%s: „%s“ breiter als die Zeile" % [wo, wort]) and ok
			if not ok:
				fehler += 1
			lvl.rezi._queue.clear()
			lvl.rezi._verstumme()
	gleich(fehler, 0, "Sätze mit Layoutfehlern")
	# ausgeglichen: ein Satz, der knapp über eine Zeile geht, steht auf zwei gleich langen
	var font := Brand.sans("medium")
	var lang := "Diese Station prüft, ob deine Karte echt ist und ob du sie gerade benutzen darfst — erst dann geht es weiter."
	var w_satz := font.get_string_size(lang, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD.UNTERTITEL_GROESSE).x
	if w_satz > HUD.UNTERTITEL_MAX:
		var b := HUD.untertitel_breite(lang, font, HUD.UNTERTITEL_GROESSE)
		pruefe(b < HUD.UNTERTITEL_MAX and b >= w_satz / 2.0, "zwei gleich lange Zeilen: Breite %d für %d" % [b, w_satz])


func test_tablet_leiste_meidet_knueppel_und_knoepfe() -> void:
	Kiosk.set_input_mode("touch")
	var bild := Rect2(30, 20, 1920 - 60, 1080 - 40)
	var fehler := 0
	for sprache in SPRACHEN:
		Game.set_lang(sprache)
		var lvl = await _station("05-identitaet")
		if lvl == null:
			pruefe(false, "%s: Station 05 startet" % sprache)
			continue
		await warte_bis(func(): return main.touch.visible, 1.0)
		if not pruefe(main.touch.visible, "Bildschirm-Steuerung liegt über dem Bild"):
			return
		var sperr: Array = []
		for b in main.touch.buttons:
			var rb: float = float(b["r"]) + 8.0
			sperr.append([str(b["label"]), Rect2(Vector2(b["pos"]) - Vector2(rb, rb), Vector2(2.0 * rb, 2.0 * rb + 36.0))])
		var rk: float = main.touch.stick_r + 8.0
		sperr.append(["Knüppel", Rect2(main.touch.stick_home - Vector2(rk, rk), Vector2(2.0 * rk, 2.0 * rk))])
		var hud: HUD = main.hud
		var tipp := BriefingDaten.tasten(Game.t(lvl.data.stuck_hint))
		var f_satz: Font = hud.untertitel_label.label_settings.font
		var lang := tipp
		while f_satz.get_string_size(lang, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD.UNTERTITEL_GROESSE).x < HUD.UNTERTITEL_MAX * 1.4:
			lang += ("" if sprache == "zh" else " ") + tipp
		for satz in [tipp, lang]:
			lvl.rezi.say(satz, 5.0)
			await frames(6)
			var wo := "%s: „%s“" % [sprache, satz.left(30)]
			var r := hud.untertitel_box.get_global_rect()
			var ok := pruefe(bild.encloses(r), "%s ragt aus dem Bild %s" % [wo, r])
			ok = pruefe(hud.untertitel_label.get_line_count() <= 4, "%s: höchstens vier Zeilen (%d)" % [wo, hud.untertitel_label.get_line_count()]) and ok
			for sp in sperr:
				ok = pruefe(not r.intersects(sp[1]), "%s liegt unter „%s“ %s / %s" % [wo, sp[0], r, sp[1]]) and ok
			if not ok:
				fehler += 1
			lvl.rezi._queue.clear()
			lvl.rezi._verstumme()
	gleich(fehler, 0, "Sätze mit Layoutfehlern am Tablet")


func test_ueber_der_steuerungs_hinweiszeile() -> void:
	var lvl = await _station(str(Game.playlist[0]))
	if not pruefe(lvl != null, "Station 1 startet"):
		return
	var hud: HUD = main.hud
	await frames(40)       # Hinweiszeile ist eingeblendet
	if not pruefe(hud.hint_row.visible and hud.hint_row.modulate.a > 0.5, "Hinweiszeile zur Steuerung steht"):
		return
	lvl.rezi.say("Ein Satz, während die Steuerung erklärt wird.", 9.0)
	await frames(6)
	var r := hud.untertitel_box.get_global_rect()
	var h := hud.hint_row.get_global_rect()
	pruefe(r.end.y <= h.position.y - 4.0, "Leiste steht über der Hinweiszeile (%d / %d)" % [r.end.y, h.position.y])
	# nach dem Hinweis rückt die Leiste nach unten an den Rand
	await frames(int(7.5 * 60))
	pruefe(not hud.hint_row.visible, "Hinweiszeile gibt ihren Platz frei")
	lvl.rezi.say("Noch ein Satz.", 3.0)
	await frames(6)
	nahe(hud.untertitel_box.get_global_rect().end.y, 1080.0 - HUD.UNTEN_RAND, 1.0, "Leiste unten am Rand")


func test_ohne_hud_bleibt_die_blase() -> void:
	var r := Rezi.new()
	baum.root.add_child(r)
	_extra.append(r)
	await frames(1)
	r.say("Titelbild.", 3.0)
	await frames(2)
	pruefe(r.bubble.visible and r.bubble_label.text == "Titelbild.", "ohne Untertitel-Ziel spricht REZI in der Blase")
	gleich(r.spricht(), "Titelbild.", "spricht() gilt auch für die Blase")
