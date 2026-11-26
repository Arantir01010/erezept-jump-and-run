class_name Betrieb
extends CanvasLayer
## BETRIEB — verstecktes Menü fürs Standpersonal (Messe-Paket 2, 11/2026).
## Öffnen: Strg+Umschalt+F10, oder am Arcade-Pult SPRUNG und AKTION zusammen
## 5 s halten (Kiosk.gd). Hält das Spiel an, solange es offen ist.
##
## Zeigt die anonyme Tagesstatistik (Statistik.gd) und bietet: Lautstärke,
## Tages-Bestenliste löschen (zweimal bestätigen), Spiel beenden (nicht im
## Browser), Schließen. Nur Deutsch: Das Menü ist fürs Personal, nicht für Besucher.

signal closed

var _zeilen: Array[Dictionary] = []   # {id, label}
var _wahl := 0
var _loeschen_bestaetigt := false
var _war_pausiert := false
var _info: Label


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_war_pausiert = get_tree().paused
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.067, 0.067, 0.075, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(140, 70)
	box.size = Vector2(1640, 940)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	box.add_child(_text("Betrieb — nur fürs Standpersonal", 40, Brand.UI_HIGHLIGHT))
	box.add_child(_text(_ueberblick(), 26, Palette.WHITE))
	box.add_child(_tabelle())
	var abstand := Control.new()
	abstand.custom_minimum_size = Vector2(0, 16)
	box.add_child(abstand)
	_zeile(box, "lautstaerke")
	_zeile(box, "bestenliste")
	if not OS.has_feature("web"):
		_zeile(box, "beenden")
	_zeile(box, "schliessen")
	_info = _text("◀ ▶ Lautstärke · ▲ ▼ wählen · Sprung/Aktion/Enter ausführen · Esc schließen", 22, Brand.UI_TEXT_DIM)
	box.add_child(_info)
	_auffrischen()


func _text(t: String, groesse: int, farbe: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	return l


func _ueberblick() -> String:
	var s := Statistik.summe()
	var gestartet := int(s.get("laeufe", 0))
	var fertig := int(s.get("laeufe_fertig", 0))
	var quote := (100.0 * fertig / gestartet) if gestartet > 0 else 0.0
	var gesamt: Array = s.get("gesamtzeiten", []) if s.get("gesamtzeiten") is Array else []
	var txt := "Heute (%s): %d Durchläufe gestartet · %d bis zum Ende (%.0f %%)" % [s.get("datum", ""), gestartet, fertig, quote]
	if not gesamt.is_empty():
		txt += " · Gesamtzeit Median %s" % _mmss(Statistik.median(gesamt))
	var w = s.get("wissen")
	if w is Dictionary and int(w.get("fragen", 0)) > 0:
		txt += " · Quiz %d× (%.0f %% richtig)" % [int(w.get("beantwortet", 0)), 100.0 * int(w.get("richtig", 0)) / int(w.get("fragen", 1))]
	if Statistik.ist_testlauf():
		txt += "   [Testlauf: eigene Zählung]"
	return txt


func _tabelle() -> GridContainer:
	var g := GridContainer.new()
	var kopf := ["Station", "erreicht", "geschafft", "Median", "Treffer", "Stürze", "Neustarts", "Abbrüche (Idle)"]
	g.columns = kopf.size()
	g.add_theme_constant_override("h_separation", 34)
	g.add_theme_constant_override("v_separation", 2)
	for k in kopf:
		g.add_child(_text(k, 22, Brand.UI_TEXT_DIM))
	var stn: Dictionary = Statistik.summe().get("stationen", {})
	for id in Game.playlist:
		var st: Dictionary = stn.get(str(id), {}) if stn.get(str(id)) is Dictionary else {}
		var zeiten: Array = st.get("zeiten", []) if st.get("zeiten") is Array else []
		var werte := [str(id), int(st.get("erreicht", 0)), int(st.get("geschafft", 0)),
			_mmss(Statistik.median(zeiten)) if not zeiten.is_empty() else "–",
			int(st.get("treffer", 0)), int(st.get("stuerze", 0)), int(st.get("neustarts", 0)),
			"%d (%d)" % [int(st.get("abbrueche", 0)), int(st.get("idle", 0))]]
		for w in werte:
			g.add_child(_text(str(w), 22, Palette.WHITE))
	return g


static func _mmss(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


func _zeile(box: VBoxContainer, id: String) -> void:
	var l := _text("", 30, Palette.WHITE)
	box.add_child(l)
	_zeilen.append({"id": id, "label": l})


func _auffrischen() -> void:
	for i in _zeilen.size():
		var z := _zeilen[i]
		var t := ""
		match z["id"]:
			"lautstaerke": t = "Lautstärke:  ◀ %d %% ▶" % roundi(Sfx.volume * 100.0)
			"bestenliste": t = "Tages-Bestenliste löschen" + ("  — wirklich? nochmal drücken" if _loeschen_bestaetigt else "")
			"beenden": t = "Spiel beenden"
			"schliessen": t = "Schließen"
		var l: Label = z["label"]
		l.text = ("▶  " if i == _wahl else "    ") + t
		l.add_theme_color_override("font_color", Brand.UI_HIGHLIGHT if i == _wahl else Palette.WHITE)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		schliessen()
	elif event.is_action_pressed("move_up"):
		_wahl = (_wahl + _zeilen.size() - 1) % _zeilen.size()
		_loeschen_bestaetigt = false
	elif event.is_action_pressed("move_down"):
		_wahl = (_wahl + 1) % _zeilen.size()
		_loeschen_bestaetigt = false
	elif event.is_action_pressed("move_left") and _zeilen[_wahl]["id"] == "lautstaerke":
		Sfx.change_volume(-Sfx.VOLUME_STEP)
	elif event.is_action_pressed("move_right") and _zeilen[_wahl]["id"] == "lautstaerke":
		Sfx.change_volume(Sfx.VOLUME_STEP)
	elif event.is_action_pressed("jump") or event.is_action_pressed("action") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
		ausfuehren(str(_zeilen[_wahl]["id"]))
	_auffrischen()


func ausfuehren(id: String) -> void:
	match id:
		"lautstaerke":
			Sfx.change_volume(Sfx.VOLUME_STEP if Sfx.volume < 0.999 else -1.0)
		"bestenliste":
			if _loeschen_bestaetigt:
				if FileAccess.file_exists(Game.HIGHSCORE_PATH):
					DirAccess.remove_absolute(Game.HIGHSCORE_PATH)
				_loeschen_bestaetigt = false
				_info.text = "Tages-Bestenliste gelöscht."
				Sfx.play("ok")
			else:
				_loeschen_bestaetigt = true
		"beenden":
			get_tree().quit(Kiosk.QUIT_OPERATOR)
		"schliessen":
			schliessen()


func schliessen() -> void:
	get_tree().paused = _war_pausiert
	closed.emit()
	queue_free()
