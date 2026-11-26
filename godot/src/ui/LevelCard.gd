class_name LevelCard
extends Control
## STATIONSKARTE nach jedem Level: was die Station gezeigt hat (Name, Merksatz,
## Fachbegriff, Zone), wie es lief (Zeit, Prüfsummen, Lückenlos, Punkte) und wo
## die Reise steht (Route der Stationen). Weiter nur per Knopf, Fingertipp oder
## Klick: Früher ging es nach 6 s von selbst weiter — wer noch las, war plötzlich
## im nächsten Briefing (Team-Feedback 9/2026). Verlässt jemand den Messestand,
## greift der Idle-Reset (--kiosk).
##
## Gestaltung nach brand/DESIGN-PROMPT.md (Rückmeldung 11/2026: „sieht zu sehr
## nach Standard-KI aus“). Weg sind Farbverlauf, drehender Strahlenkranz, drei
## gleiche Sternkarten mit Schein, der zentrierte Stapel und der Funkenregen.
## Jetzt: ruhige Fläche in der Farbe der Zone, links bündig Eyebrow, Stationsname
## in Charter und der Merksatz, rechts EINE Ergebnis-Tafel mit drei Zeilen. Die
## einzige inszenierte Bewegung: Die Zeilen bekommen nacheinander ihren
## Prüfvermerk, bei drei von drei landet zum Schluss ein „GEPRÜFT“-Stempel.
## Danach steht alles still (keine Dauerbewegung, kein Blinken).

signal done

const LX := 150.0              # linke Satzkante
const LW := 860.0              # Breite der linken Spalte
const OBEN := 236.0            # Oberkante von Eyebrow und Ergebnis-Tafel
const PX := 1110.0             # Ergebnis-Tafel: linke Kante …
const PW := 660.0              # … und Breite
const KNOPF_ABSTAND := 40.0    # Weiter-Knopf unter der Tafel
const ROUTE_Y := 184.0
const ROUTE_STEP := 36.0
const ROUTE_GELB := 0.5        # die eben geschaffte Station wird gelb (s)
const VERMERK_AB := 0.6        # erster Prüfvermerk (s), dann im Takt
const VERMERK_TAKT := 0.35
const STEMPEL_UM := 1.85       # „GEPRÜFT“ bei drei von drei
const RUHE_AB := 2.4           # danach wird nichts mehr neu gezeichnet

var _t := 0.0
var _armed := false
var _fired := false
var _pal: Palette
var _idx := 0                  # diese Station (Route), beim Öffnen festgehalten
var _n := 0
var _vermerke: Array[Control] = []
var _spalte: Control           # Bausteine für den Layout-Test
var _tafel: Control
var _weiter: Control
var _fuss: Control
var stempel: Control = null    # nur bei drei von drei


func setup(data: LevelData, result: Dictionary, has_next: bool) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pal = Palette.from_theme(Game.theme(data.theme_name), data.theme_name)
	_n = Game.playlist.size()
	_idx = clampi(Game.level_index, 0, maxi(0, _n - 1))
	var medals: Dictionary = result.get("medals", {})
	var got: Array[bool] = [bool(medals.get("zeit", false)), bool(medals.get("bits", false)),
		bool(medals.get("lueckenlos", false))]
	# Ohne Lauscher (Station 01–03) gibt es nichts mitzulesen: Zeile und Medaille entfallen.
	var mit_lauschern := bool(result.get("mit_lauschern", true))
	if not mit_lauschern:
		got.resize(2)

	# ---- links oben: Eyebrow, Stationsname, Merksatz, Fachbegriff
	var links := VBoxContainer.new()
	links.position = Vector2(LX, OBEN)
	links.custom_minimum_size = Vector2(LW, 0)
	links.add_theme_constant_override("separation", 0)
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(links)
	_spalte = links
	_text(links, tr("Station %d / %d") % [_idx + 1, _n], 22,
		Brand.UI_EYEBROW, Brand.spaced(Brand.sans("medium"), 4))
	_luft(links, 12)
	var stationsname := data.name_text()
	var titel := _text(links, stationsname, titel_groesse(stationsname, LW), Brand.UI_TEXT, Brand.headline(), 0.0, true)
	titel.label_settings.line_spacing = -0.22 * titel.label_settings.font_size
	_luft(links, 26)
	var satz := merksatz(data)
	if satz != "":
		_text(links, satz, 34, Brand.UI_TEXT_DIM, Brand.sans("roman"), satzbreite(satz, Brand.sans("roman"), 34, LW))
	_luft(links, 44)
	var badge := str(data.station.get("badge", ""))
	if badge != "":
		var reihe := HBoxContainer.new()
		reihe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reihe.add_child(_pille(badge))
		links.add_child(reihe)

	# ---- rechts: Ergebnis-Tafel, drei Zeilen statt drei Karten
	var tafel := PanelContainer.new()
	tafel.add_theme_stylebox_override("panel", Brand.panel_style(Brand.UI_RADIUS, Brand.UI_PANEL, Brand.UI_BORDER, 1, 44, 34))
	tafel.position = Vector2(PX, OBEN)
	tafel.custom_minimum_size = Vector2(PW, 0)
	tafel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tafel)
	_tafel = tafel
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", 0)
	liste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tafel.add_child(liste)
	_text(liste, tr("Dein Ergebnis"), 20, Brand.UI_EYEBROW, Brand.spaced(Brand.sans("medium"), 3))
	_luft(liste, 22)
	var zeilen := [
		[tr("Zeit"), tr("%.1f s / Ziel %.0f s") % [result.get("time", 0.0), result.get("par", 0.0)]],
		[tr("Prüfsummen"), "%d / %d" % [result.get("bits", 0), result.get("bits_total", 0)]],
	]
	if mit_lauschern:
		zeilen.append([tr("Lückenlos"), tr("nie mitgelesen") if got[2] else tr("im Klartext mitgelesen: %d×") % int(result.get("seen", 0))])
	for i in zeilen.size():
		liste.add_child(_regel())
		liste.add_child(_zeile(str(zeilen[i][0]), str(zeilen[i][1]), got[i]))
	liste.add_child(_regel())
	_luft(liste, 24)
	var punkte := _text(liste, tr("%d Punkte") % Game.score, 44, Brand.UI_TEXT, Brand.sans("bold"))

	# ---- unter der Tafel, rechtsbündig: der Primärknopf (PwC-Orange, gefüllt)
	var knopf := _knopf(tr("Weiter: %s") % Kiosk.label_confirm() if has_next else tr("Zum e-Rezept: %s") % Kiosk.label_confirm())
	add_child(knopf)
	_weiter = knopf
	var kg := knopf.get_combined_minimum_size()
	knopf.position = Vector2(PX + PW - kg.x, OBEN + tafel.get_combined_minimum_size().y + KNOPF_ABSTAND)
	var unten := knopf.position.y + kg.y

	# ---- links unten, auf der Grundlinie des Knopfs: die Zone als Fußnote
	var fuss := VBoxContainer.new()
	fuss.add_theme_constant_override("separation", 6)
	fuss.custom_minimum_size = Vector2(LW, 0)
	fuss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fuss)
	_fuss = fuss
	if _pal.zone_name != "":
		_text(fuss, _pal.zone_name, 18, Color(Brand.GREY_300, 0.72), Brand.spaced(Brand.sans("medium"), 3))
	if _pal.zone_fact != "":
		_text(fuss, _pal.zone_fact, 24, Brand.UI_TEXT_DIM, Brand.sans("roman"), satzbreite(_pal.zone_fact, Brand.sans("roman"), 24, LW))
	# An der Grundlinie des Knopfs verankert und nach oben wachsend: Umbrechende
	# Labels kennen ihre Höhe erst nach dem Layout. Oberkante = Unterkante, die Höhe
	# kommt allein aus der Mindestgröße.
	fuss.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fuss.offset_left = LX
	fuss.offset_right = LX + LW
	fuss.offset_top = unten
	fuss.offset_bottom = unten

	var alle := got.all(func(v): return v)
	if alle:
		stempel = _stempel(tr("Geprüft"))
		add_child(stempel)
		var g := stempel.get_combined_minimum_size()
		stempel.size = g
		stempel.position = Vector2(PX + PW - 48.0 - g.x, OBEN + 16.0)
		stempel.pivot_offset = g * 0.5
		stempel.rotation = -0.06

	# ---- Auftritt: eine orchestrierte Bewegung, danach Ruhe
	var k := 0
	for c in links.get_children():
		if c is Label or c is HBoxContainer:
			c.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(0.05 + 0.07 * k)
			tw.tween_property(c, "modulate:a", 1.0, 0.3)
			k += 1
	links.position.x = LX - 24.0
	create_tween().tween_property(links, "position:x", LX, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fuss.modulate.a = 0.0
	var tf := create_tween()
	tf.tween_interval(0.05 + 0.07 * k)
	tf.tween_property(fuss, "modulate:a", 1.0, 0.3)
	tafel.modulate.a = 0.0
	tafel.position.y = OBEN + 18.0
	var tt := create_tween()
	tt.tween_interval(0.2)
	tt.tween_property(tafel, "modulate:a", 1.0, 0.35)
	tt.parallel().tween_property(tafel, "position:y", OBEN, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Prüfvermerke nacheinander: geschafft = gelber Vermerk mit Haken, offen = Strichring
	for i in _vermerke.size():
		var v := _vermerke[i]
		var ok := got[i]
		var tw := create_tween()
		tw.tween_interval(VERMERK_AB + i * VERMERK_TAKT)
		if ok:
			tw.tween_callback(func():
				v.scale = Vector2(1.6, 1.6)
				Sfx.play("medal", 1.0 + i * 0.1))
			tw.tween_property(v, "modulate:a", 1.0, 0.1)
			tw.parallel().tween_property(v, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_callback(func(): Sfx.play("ui", 0.8))
			tw.tween_property(v, "modulate:a", 1.0, 0.25)
	punkte.modulate.a = 0.0
	var tp := create_tween()
	tp.tween_interval(VERMERK_AB + 3 * VERMERK_TAKT)
	tp.tween_property(punkte, "modulate:a", 1.0, 0.3)
	if stempel:
		stempel.modulate.a = 0.0
		var ts := create_tween()
		ts.tween_interval(STEMPEL_UM)
		ts.tween_callback(func():
			stempel.scale = Vector2(1.7, 1.7)
			Sfx.play("seal", 1.0, -4.0))
		ts.tween_property(stempel, "modulate:a", 1.0, 0.06)
		ts.parallel().tween_property(stempel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Der Knopf erscheint, sobald er angenommen wird
	knopf.modulate.a = 0.0
	var ta := create_tween()
	ta.tween_interval(0.8)
	ta.tween_callback(func(): _armed = true)
	ta.tween_property(knopf, "modulate:a", 1.0, 0.25)

	# Nach dem Layout: Sehr lange Namen und Sätze (zwei Zeilen Titel, zwei Zeilen
	# Merksatz) dürfen die Fußnote nie überdecken, dann rutscht sie nach unten.
	for i in 2:
		await get_tree().process_frame
	if not is_instance_valid(fuss) or not is_instance_valid(links):
		return
	var frei := links.position.y + links.size.y + 32.0
	if fuss.position.y < frei:
		fuss.position.y = frei


## Merksatz der Station ohne das Häkchen davor: Den Haken setzt jetzt die Tafel.
static func merksatz(data: LevelData) -> String:
	var s := Game.t(data.station.get("stampText", "")).strip_edges()
	while s.begins_with("✓"):
		s = s.substr(1).strip_edges()
	return s


## Schriftgröße des Stationsnamens: eine Zeile, solange das ab 80 px geht
## („Die Berechtigungen“), sonst die größte, bei der jedes Wort in die Spalte passt
## und der Name höchstens zwei Zeilen braucht („Versichertenstammdaten“ ist ein Wort).
static func titel_groesse(text: String, breite: float) -> int:
	var f := Brand.headline()
	for einzeilig in range(104, 79, -4):
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, einzeilig).x <= breite:
			return einzeilig
	var g := 104
	while g > 56:
		var passt := true
		for wort in text.split(" ", false):
			if f.get_string_size(wort, HORIZONTAL_ALIGNMENT_LEFT, -1, g).x > breite:
				passt = false
				break
		if passt and f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, breite, g).y <= g * 2.6:
			return g
		g -= 4
	return g


## Umbruchbreite für ausgeglichene Zeilen: Braucht ein Satz zwei Zeilen, werden
## beide etwa gleich lang (kein einzelnes Wort allein in der letzten Zeile).
static func satzbreite(text: String, font: Font, groesse: int, max_breite: float) -> float:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x
	if w <= max_breite:
		return max_breite
	var zeilen := ceilf(w / max_breite)
	return minf(max_breite, w / zeilen + groesse * 2.0)


## Label in Markenschrift. breite > 0: Umbruch auf diese Breite; umbruch: Umbruch
## auf die Breite der Spalte (Stationsname). Sonst einzeilig (Pillen, Knopf, Stempel).
func _text(parent: Control, text: String, groesse: int, farbe: Color, font: Font, breite := 0.0, umbruch := false) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # Texte kommen schon übersetzt
	l.label_settings = Brand.label_settings(groesse, farbe, font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if breite > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size.x = breite
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	elif umbruch:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(l)
	return l


func _luft(parent: Control, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)


func _regel() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.12)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Eine Protokollzeile: Prüfvermerk, Bezeichnung (Versalien), Wert.
func _zeile(titel: String, wert: String, ok: bool) -> HBoxContainer:
	var z := HBoxContainer.new()
	z.custom_minimum_size = Vector2(0, 112)
	z.add_theme_constant_override("separation", 26)
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := Vermerk.new()
	v.ok = ok
	v.custom_minimum_size = Vector2(60, 60)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.pivot_offset = Vector2(30, 30)
	v.modulate.a = 0.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.add_child(v)
	_vermerke.append(v)
	var spalte := VBoxContainer.new()
	spalte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spalte.add_theme_constant_override("separation", 2)
	spalte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ok:
		spalte.modulate.a = 0.7          # offen: zurückgenommen, aber lesbar
	z.add_child(spalte)
	_text(spalte, titel, 20, Brand.UI_TEXT_DIM, Brand.spaced(Brand.sans("medium"), 3))
	_text(spalte, wert, 30, Brand.UI_TEXT, Brand.sans("roman"))
	return z


## Fachbegriff der Station (z. B. „eGK · eHBA · QES“): Pille mit feiner Kante.
## Bewusst nicht in Versalien — „eGK“ bleibt „eGK“.
func _pille(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Brand.panel_style(Brand.UI_RADIUS, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.34), 1, 18, 7))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text(p, text, 24, Brand.UI_TEXT, Brand.spaced(Brand.sans("medium"), 1))
	return p


func _knopf(text: String) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Brand.UI_ACCENT_STRONG
	sb.set_corner_radius_all(Brand.UI_RADIUS)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	var k := PanelContainer.new()
	k.add_theme_stylebox_override("panel", sb)
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text(k, text, 26, Brand.WHITE, Brand.sans("bold"))
	return k


## „GEPRÜFT“-Stempel: doppelte Kante wie ein Gummistempel, Text in Versalien.
func _stempel(text: String) -> PanelContainer:
	var aussen := PanelContainer.new()
	aussen.add_theme_stylebox_override("panel", Brand.panel_style(4, Color(0, 0, 0, 0), Brand.UI_HIGHLIGHT, 3, 4, 4))
	aussen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var innen := PanelContainer.new()
	innen.add_theme_stylebox_override("panel", Brand.panel_style(2, Color(0, 0, 0, 0), Brand.UI_HIGHLIGHT, 1, 18, 6))
	innen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aussen.add_child(innen)
	_text(innen, text, 28, Brand.UI_HIGHLIGHT, Brand.spaced(Brand.sans("heavy"), 4))
	return aussen


## Haken als Linie (kein Schriftzeichen: fehlt in Teilen der Schriften).
static func haken(ci: CanvasItem, p: Vector2, r: float, farbe: Color, breite: float) -> void:
	ci.draw_polyline(PackedVector2Array([p + Vector2(-r, 0.05 * r), p + Vector2(-0.3 * r, 0.7 * r), p + Vector2(r, -0.6 * r)]),
		farbe, breite, true)


## Fläche in der Farbe der Zone und die Route der Stationen. Nur während des
## Auftritts neu gezeichnet, danach steht das Bild.
func _draw() -> void:
	if _pal == null:
		return
	draw_rect(Rect2(0, 0, 1920, 1080), Color(_pal.fill_dark, 1.0))
	_route()


## Route oben links wie im Briefing: geschaffte Stationen gelb mit Haken, die
## eben geschaffte wird nach dem Auftritt gelb, kommende als Ring.
func _route() -> void:
	var n := _n
	if n <= 1:
		return
	var idx := _idx
	var x0 := LX + 10.0
	var y := ROUTE_Y
	var k := clampf((_t - ROUTE_GELB + 0.25) / 0.25, 0.0, 1.0)
	draw_line(Vector2(x0, y), Vector2(x0 + (n - 1) * ROUTE_STEP, y), Color(1, 1, 1, 0.18), 2.0)
	var bis := (idx - 1 + k) * ROUTE_STEP
	if bis > 0.0:
		draw_line(Vector2(x0, y), Vector2(x0 + bis, y), Color(Brand.UI_HIGHLIGHT, 0.8), 2.0)
	for i in n:
		var p := Vector2(x0 + i * ROUTE_STEP, y)
		if i < idx or (i == idx and _t >= ROUTE_GELB):
			var r := 9.0
			if i == idx:
				var s := clampf((_t - ROUTE_GELB) / 0.2, 0.0, 1.0)
				r *= 1.0 + 0.4 * (1.0 - s) * (1.0 - s)
			draw_circle(p, r, Brand.UI_HIGHLIGHT)
			haken(self, p, r * 0.5, Brand.GREY_1000, 2.2)
		elif i == idx:
			draw_circle(p, 9.0, Brand.UI_ACCENT)
			draw_circle(p, 3.5, Brand.GREY_1000)
		else:
			draw_circle(p, 7.0, _pal.fill_dark.darkened(0.25))
			draw_arc(p, 7.0, 0.0, TAU, 24, Color(1, 1, 1, 0.4), 1.5, true)


func _process(delta: float) -> void:
	_t += delta
	if _t < RUHE_AB + delta:
		queue_redraw()
	if _fired:
		return
	if _armed and Input.is_action_just_pressed("confirm"):
		weiter()


## Weiter zur nächsten Station (Knopf, Fingertipp, Prüflauf).
func weiter() -> void:
	if _fired:
		return
	_fired = true
	Sfx.play("ok")
	done.emit()


func _input(event: InputEvent) -> void:
	# Fingertipp oder Mausklick: weiter wie der Knopf — ohne Automatik der einzige
	# Weg für Touch-Geräte (die Bildschirmknöpfe gibt es nur im Level).
	if not _armed:
		return
	if (event is InputEventScreenTouch and event.pressed) or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		weiter()


## Prüfvermerk einer Zeile: gelbe Scheibe mit Haken (geschafft) oder Strichring
## mit Strich (offen). Offen ist kein Fehler, darum ohne Rot.
class Vermerk extends Control:
	var ok := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if ok:
			draw_circle(c, r, Brand.UI_HIGHLIGHT)
			LevelCard.haken(self, c, r * 0.46, Brand.GREY_1000, 5.0)
		else:
			var n := 20
			for i in n:
				var a := i * TAU / n
				draw_arc(c, r - 1.5, a, a + TAU / n * 0.5, 4, Brand.UI_TEXT_MUTED, 2.0, true)
			draw_line(c - Vector2(r * 0.3, 0.0), c + Vector2(r * 0.3, 0.0), Brand.UI_TEXT_MUTED, 3.0, true)
