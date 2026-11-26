class_name HUD
extends CanvasLayer
## HUD — Stationsname, TI-Streckenkarte, Prüfsummen, Punkte, Zeit gegen Par,
## Hülle-Anzeige (Farbe UND Form UND Text — Barrierefreiheit), Karten,
## Titel-Einblendung beim Levelstart, Kombo-Anzeige.
##
## Optik-Analyse/Team-Feedback 9/2026: Die gestufte Rand-Vignette (zehn harte
## Rechtecke je Rand, sichtbares Streifenraster) ist entfernt — PostFx hat schon
## eine weiche. Die rechte Spalte hängt an der Bildkante (lief 6 px hinaus, die
## Pillen überlappten), Zeit in PwC-Gelb statt Grün, Kombo mit dunkler Kontur.

signal pause_requested

var level: Level
var pause_btn: _PauseButton
var station: Label
var route: _Route
var bits_label: Label
var score_label: Label
var time_label: Label
var huelle_box: PanelContainer
var huelle_shape: _Shape
var huelle_label: Label
var huelle_hint: Label
var cards_box: PanelContainer
var cards_view: _Cards
var title_box: VBoxContainer
var title_label: Label
var sub_label: Label
var combo_label: Label
var hint_row: HBoxContainer
var hint_label: Label
var _combo_tw: Tween
var _last_huelle := ""

const RAND := 28.0            # Abstand der Pillen zum Bildrand, links wie rechts
## Karten-Fächer: rechte Kante bündig mit der Zeit-Pille, Zeile unten rechts
const CARDS_RIGHT := 1920.0 - RAND
const CARDS_Y := 950.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	station = _pill(root, Vector2(RAND, 22), 24)
	route = _Route.new()
	route.position = Vector2(700, 30)
	route.size = Vector2(520, 30)
	root.add_child(route)

	# Oben rechts, an der Bildkante verankert (wächst nach links, nie aus dem Bild):
	# [Pause · Prüfsummen · Punkte] / Zeit / Kombo
	var spalte := VBoxContainer.new()
	spalte.anchor_left = 1.0
	spalte.anchor_right = 1.0
	spalte.offset_left = -RAND
	spalte.offset_right = -RAND
	spalte.offset_top = 18.0
	spalte.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	spalte.add_theme_constant_override("separation", 10)
	spalte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spalte)
	var zeile := HBoxContainer.new()
	zeile.alignment = BoxContainer.ALIGNMENT_END
	zeile.add_theme_constant_override("separation", 12)
	zeile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spalte.add_child(zeile)
	# Pause-Knopf (Maus und Finger) links neben den Zählern
	pause_btn = _PauseButton.new()
	pause_btn.pressed.connect(func(): pause_requested.emit())
	zeile.add_child(pause_btn)
	var luecke := Control.new()      # etwas Luft zwischen Knopf und Zählern
	luecke.custom_minimum_size = Vector2(4, 0)
	luecke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zeile.add_child(luecke)
	bits_label = _pill(zeile, Vector2.ZERO, 24)
	bits_label.custom_minimum_size = Vector2(150, 0)
	score_label = _pill(zeile, Vector2.ZERO, 24)
	score_label.custom_minimum_size = Vector2(150, 0)
	for l in [bits_label, score_label]:
		(l.get_parent() as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Zeit so breit wie die beiden Zähler (2 × 186 + 12), rechtsbündig darunter
	time_label = _pill(spalte, Vector2.ZERO, 20)
	time_label.custom_minimum_size = Vector2(348, 0)
	(time_label.get_parent() as Control).size_flags_horizontal = Control.SIZE_SHRINK_END

	# Hülle-Anzeige unten links
	huelle_box = PanelContainer.new()
	huelle_box.position = Vector2(28, 960)
	huelle_box.add_theme_stylebox_override("panel", _pill_style())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	huelle_shape = _Shape.new()
	huelle_shape.custom_minimum_size = Vector2(34, 34)
	hb.add_child(huelle_shape)
	huelle_label = Label.new()
	huelle_label.add_theme_font_size_override("font_size", 26)
	huelle_label.add_theme_font_override("font", Brand.sans("bold"))
	hb.add_child(huelle_label)
	huelle_box.add_child(hb)
	root.add_child(huelle_box)
	huelle_hint = Label.new()
	huelle_hint.position = Vector2(34, 1022)
	huelle_hint.add_theme_font_size_override("font_size", 18)
	huelle_hint.add_theme_color_override("font_color", Palette.with_alpha(Palette.WHITE, 0.7))
	root.add_child(huelle_hint)

	# Karten-Fächer unten rechts: Symbole in Kartenfarbe (leer = Umriss, dabei =
	# gefüllt, gesteckt = Haken); der Flug Welt → HUD landet hier (Gruppe "hud")
	cards_box = PanelContainer.new()
	cards_box.position = Vector2(CARDS_RIGHT - 120.0, CARDS_Y)
	cards_box.add_theme_stylebox_override("panel", _pill_style())
	cards_view = _Cards.new()
	cards_box.add_child(cards_view)
	root.add_child(cards_box)
	cards_box.visible = false
	add_to_group("hud")

	# Titel-Einblendung
	title_box = VBoxContainer.new()
	title_box.position = Vector2(0, 150)
	title_box.size = Vector2(1920, 200)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = Brand.headline()
	ls.font_size = 74
	ls.font_color = Palette.WHITE
	ls.outline_size = 10
	ls.outline_color = Color(0.067, 0.067, 0.075, 0.85)
	ls.shadow_color = Color(0, 0, 0, 0.5)
	ls.shadow_size = 12
	title_label.label_settings = ls
	title_box.add_child(title_label)
	sub_label = Label.new()
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls2 := LabelSettings.new()
	ls2.font_size = 30
	ls2.font_color = Brand.UI_TEXT_DIM
	ls2.outline_size = 8
	ls2.outline_color = Color(0.067, 0.067, 0.075, 0.85)
	sub_label.label_settings = ls2
	title_box.add_child(sub_label)
	root.add_child(title_box)
	title_box.modulate.a = 0.0

	# Kombo unter der Zeit, rechtsbündig, mit dunkler Kontur — ohne verschwand sie
	# vor der warmen Archiv-Welt (Station 19/20)
	combo_label = Label.new()
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var lc := LabelSettings.new()
	lc.font = Brand.sans("bold")
	lc.font_size = 30
	lc.font_color = Brand.UI_ACCENT
	lc.outline_size = 9
	lc.outline_color = Color(0.067, 0.067, 0.075, 0.9)
	lc.shadow_color = Color(0, 0, 0, 0.45)
	lc.shadow_size = 8
	combo_label.label_settings = lc
	combo_label.modulate.a = 0.0
	spalte.add_child(combo_label)

	# Hinweiszeile unten: Piktogramm „Glühbirne" (PwC-Werte-Set) + Text
	hint_row = HBoxContainer.new()
	hint_row.position = Vector2(0, 996)
	hint_row.size = Vector2(1920, 44)
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.add_theme_constant_override("separation", 12)
	var bulb := Brand.pictogram("reimagine-the-possible", true)
	if bulb:
		var icon := TextureRect.new()
		icon.texture = bulb
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1, 1, 1, 0.8)
		hint_row.add_child(icon)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Palette.with_alpha(Palette.WHITE, 0.8))
	hint_row.add_child(hint_label)
	root.add_child(hint_row)
	hint_row.modulate.a = 0.0

	Game.hud_changed.connect(refresh)
	Game.combo_changed.connect(_on_combo)


## Pillen im PwC-Look: dunkles Grau, feine Kante, kleine Rundung (Brand.gd)
func _pill_style() -> StyleBoxFlat:
	return Brand.panel_style(Brand.UI_RADIUS, Brand.UI_PANEL, Brand.UI_BORDER, 1, 18, 6)


func _pill(parent: Control, pos: Vector2, font: int) -> Label:
	var p := PanelContainer.new()
	p.position = pos
	p.add_theme_stylebox_override("panel", _pill_style())
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_font_override("font", Brand.sans("medium"))
	l.add_theme_color_override("font_color", Palette.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	parent.add_child(p)
	return l


func bind(lvl: Level) -> void:
	level = lvl
	station.text = lvl.data.name_text()
	huelle_box.visible = lvl.data.huelle_enabled
	huelle_hint.visible = lvl.data.huelle_enabled
	huelle_hint.text = tr("%s: Hülle wechseln") % Kiosk.label_toggle()
	_last_huelle = ""
	_zeit_text = ""
	_zeit_unter_par = -1
	cards_view.reset()
	refresh()
	# Portal-Einblendung: Stationsname groß, ein Satz — dann weg
	title_label.text = lvl.data.name_text()
	sub_label.text = Game.t(lvl.data.station.get("portalText", ""))
	title_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(title_box, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.4)
	tw.tween_property(title_box, "modulate:a", 0.0, 0.6)
	if Game.level_index == 0:
		var lauf := tr("Knüppel") if (Kiosk.touch_seen or Kiosk.touch_forced) else (tr("Joystick") if Kiosk.has_gamepad() else tr("Pfeiltasten/WASD"))
		hint_label.text = tr("%s laufen · %s springen (in der Luft nochmal = Rezi-Schub) · %s TI-Aktion") % [
			lauf, Kiosk.label_jump(), Kiosk.label_action()]
		var tw2 := create_tween()
		tw2.tween_property(hint_row, "modulate:a", 1.0, 0.5)
		tw2.tween_interval(6.0)
		tw2.tween_property(hint_row, "modulate:a", 0.0, 0.8)


func refresh() -> void:
	if level == null or not is_instance_valid(level):
		return
	var need := level.data.count_required
	bits_label.text = "◉ %d" % Game.bits if need == 0 else "◉ %d / %d" % [Game.bits_this_level(), need]
	score_label.text = "%d P" % Game.score
	route.current = Game.level_index
	route.done = Game.seals.size()
	route.total = Game.playlist.size()
	route.queue_redraw()
	_refresh_huelle()
	var list := _level_cards()
	if list.is_empty():
		cards_box.visible = false
	else:
		cards_box.visible = true
		cards_view.layout(list)
		cards_box.position = Vector2(CARDS_RIGHT - _Cards.width_for(list.size()) - 36.0, CARDS_Y)
		cards_view.queue_redraw()


## Hülle-Anzeige: Farbe, Form und Text nur bei Wechsel neu setzen (ein Theme-
## Override löst jedes Mal ein Neu-Layout aus); die VAU-Restzeit in 0,1-s-Schritten.
func _refresh_huelle() -> void:
	if not level.data.huelle_enabled or level.player == null:
		return
	var h := level.player.huelle
	var s := h.state
	if s != _last_huelle:
		_last_huelle = s
		huelle_label.add_theme_color_override("font_color", Huelle.color_of(s))
		huelle_shape.state = s
		huelle_shape.queue_redraw()
	huelle_label.text = ("VAU  %.1f s" % h.vau_left) if h.vau_expires else Huelle.label_of(s)


## Welche Ausweise dieses Level kennt: die liegenden Karten des Levels (auch die
## noch nicht gefundenen — als leere Fächer) plus alles, was Paul schon dabeihat.
func _level_cards() -> Array:
	var list: Array = []
	if level and is_instance_valid(level):
		for o in level.data.objects:
			if str(o.get("type", "")) == "karte":
				var c := str(o.get("karte", "egk")).to_lower()
				if not list.has(c):
					list.append(c)
	for c in Game.cards:
		if not list.has(c):
			list.append(c)
	return list


## Bildschirmposition (HUD-Koordinaten) der Fachmitte einer Karte — Ziel des Flugs.
func card_slot_screen_pos(card: String) -> Vector2:
	if not cards_box.visible:
		refresh()
	return cards_box.position + Vector2(18, 6) + cards_view.slot_center(card)


func card_icon_size() -> Vector2:
	return _Cards.ICON


## Flug gestartet: Das Fach bleibt leer (Umriss), bis die Karte landet (card_pop).
func card_flight_started(card: String) -> void:
	cards_view.mark_pending(card)


## Kurze Reaktion des Fachs (Pop, Halo, Pille hellt auf) beim Aufnehmen/Stecken.
func card_pop(card: String) -> void:
	cards_view.pop(card)
	cards_box.modulate = Color(1.25, 1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(cards_box, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Zeit gegen Par: Text nur bei Änderung (0,1-s-Schritte), Farbe nur beim Wechsel
## über/unter Par. Früher setzte jeder Frame Text UND Farb-Override (Neu-Layout) und
## lief in der VAU-Sitzung das komplette refresh() — Teil des Ruckelns in Station 15.
var _zeit_text := ""
var _zeit_unter_par := -1

func _process(_delta: float) -> void:
	if level == null or not is_instance_valid(level):
		return
	var t := level.level_time
	var par := level.data.par_time
	var text := tr("Zeit %5.1f s   ·   Ziel %.0f s") % [t, par]
	if text != _zeit_text:
		_zeit_text = text
		time_label.text = text
	var unter := 1 if t <= par else 0
	if unter != _zeit_unter_par:
		_zeit_unter_par = unter
		# unter Par: PwC-Gelb (Medaille noch drin), darüber ruhiges Grau — kein
		# Grün (keine PwC-Farbe) und kein Warm (warm heißt im Spiel „Klartext")
		time_label.add_theme_color_override("font_color", Brand.UI_HIGHLIGHT if unter == 1 else Brand.UI_TEXT_DIM)
	if level.data.huelle_enabled and level.player and level.player.huelle.vau_expires:
		_refresh_huelle()


func _on_combo(combo: int) -> void:
	if combo < 2:
		return
	combo_label.text = tr("Kombo ×%d") % combo
	combo_label.modulate.a = 1.0
	combo_label.pivot_offset = Vector2(combo_label.size.x, combo_label.size.y * 0.5)   # wächst aus der rechten Kante
	combo_label.scale = Vector2(1.3, 1.3)
	if _combo_tw:
		_combo_tw.kill()
	_combo_tw = create_tween()
	_combo_tw.tween_property(combo_label, "scale", Vector2.ONE, 0.15)
	_combo_tw.tween_interval(Game.COMBO_WINDOW)
	_combo_tw.tween_property(combo_label, "modulate:a", 0.0, 0.3)


## Die Karten-Fächer: je Karte ein Symbol (KartenFx.draw_card) in Kartenfarbe.
## leer = Umriss, dabei = gefüllt, gesteckt = mit Haken. Pop + Halo beim Ereignis.
class _Cards extends Control:
	const ICON := Vector2(50, 32)
	const STRIDE := 62.0
	var cards: Array = []
	var _pops := {}
	var _pending := {}   # Karte ist unterwegs (Flug) — Fach bleibt bis zur Landung leer

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func reset() -> void:
		_pops.clear()
		_pending.clear()

	func mark_pending(card: String) -> void:
		_pending[card] = true
		queue_redraw()

	static func width_for(n: int) -> float:
		return maxi(n, 1) * STRIDE - (STRIDE - ICON.x)

	func layout(list: Array) -> void:
		if list != cards:
			cards = list.duplicate()
		custom_minimum_size = Vector2(width_for(cards.size()), ICON.y + 8.0)

	func slot_center(card: String) -> Vector2:
		var i := maxi(0, cards.find(card))
		return Vector2(i * STRIDE + ICON.x / 2.0, 4.0 + ICON.y / 2.0)

	func pop(card: String) -> void:
		_pops[card] = 1.0
		_pending.erase(card)
		set_process(true)

	func _process(delta: float) -> void:
		var any := false
		for k in _pops.keys():
			var v: float = maxf(0.0, float(_pops[k]) - delta * 2.0)
			_pops[k] = v
			if v > 0.0:
				any = true
		queue_redraw()
		if not any:
			set_process(false)

	func _draw() -> void:
		for i in cards.size():
			var card := str(cards[i])
			var mode := "umriss"
			if Game.card_slots.has(card):
				mode = "gesteckt"
			elif Game.has_card(card) and not _pending.has(card):
				mode = "voll"
			var center := Vector2(i * STRIDE + ICON.x / 2.0, 4.0 + ICON.y / 2.0)
			var p: float = float(_pops.get(card, 0.0))
			var k := p * p
			if p > 0.0:
				var c := KartenFx.color_of(card)
				var hc := c if Fx.web_fallback() else Palette.glow(c, 1.3)
				draw_circle(center, 30.0 + 16.0 * (1.0 - k), Color(hc.r, hc.g, hc.b, 0.40 * k))
			var s := 1.0 + 0.35 * k
			draw_set_transform(center, 0.0, Vector2(s, s))
			KartenFx.draw_card(self, Rect2(-ICON / 2.0, ICON), card, mode)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Runder Pause-Knopf: zwei Balken, Pille im PwC-Look. Finger kommt als Maus an
## (emulate_mouse_from_touch), deshalb nur Mausereignisse — sonst zweimal.
class _PauseButton extends Control:
	signal pressed

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(56, 56)
		size = Vector2(56, 56)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 27.0, Brand.UI_PANEL)
		draw_arc(c, 27.0, 0.0, TAU, 48, Brand.UI_BORDER, 1.5, true)
		draw_rect(Rect2(c + Vector2(-10, -11), Vector2(7, 22)), Palette.WHITE)
		draw_rect(Rect2(c + Vector2(3, -11), Vector2(7, 22)), Palette.WHITE)


class _Route extends Control:
	var current := 0
	var done := 0
	var total := 6

	func _draw() -> void:
		if total <= 0:
			return
		var step := size.x / maxf(total - 1, 1)
		draw_line(Vector2(0, 15), Vector2(size.x, 15), Color(0.663, 0.784, 0.988, 0.25), 3.0, true)
		for i in total:
			var p := Vector2(i * step, 15)
			if i < done:
				draw_circle(p, 9.0, Palette.glow(Palette.GOLD, 1.4))
			elif i == current:
				draw_circle(p, 10.0, Color(0.067, 0.067, 0.075))
				draw_arc(p, 10.0, 0, TAU, 20, Palette.glow(Palette.COOL, 1.5), 3.0, true)
				draw_circle(p, 4.0, Palette.glow(Palette.COOL, 1.5))
			else:
				draw_circle(p, 6.0, Color(0.631, 0.659, 0.702, 0.45))


class _Shape extends Control:
	var state := "klartext"

	func _draw() -> void:
		var c := Huelle.color_of(state)
		var g := Palette.glow(c, 1.5)
		var center := size / 2.0
		match state:
			"verschluesselt":
				var pts := PackedVector2Array()
				for k in 6:
					pts.append(center + Vector2(15, 0).rotated(k * PI / 3.0 - PI / 6.0))
				draw_colored_polygon(pts, g)
			"vau":
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -16), center + Vector2(16, 0), center + Vector2(0, 16), center + Vector2(-16, 0)]), g)
			_:
				draw_circle(center, 15.0, g)
