class_name LevelCard
extends Control
## STATIONSKARTE nach jedem Level: Auftauch-Stempel („✓ …"), Fachbegriff-Chip,
## Zonen-Fakt, drei Medaillen (Zeit / Prüfsummen / Lückenlos) und Punkte.
## Ersetzt den Stadt-Zwischenlauf: kürzer, lesbarer, und der Wiederspielwert
## steht sichtbar auf dem Tisch. Weiter per Knopf oder nach ein paar Sekunden.
## Runde 3: Farbverlauf der Zone statt Schwarz, drehender Strahlenkranz hinter
## den Medaillen, der Stationsname schlägt wie ein Stempel ein, Funkenregen bei
## drei Medaillen.

signal done

var _t := 0.0
var _armed := false
var _fired := false
var _auto := 6.0
var _pal: Palette
var _bg: Vignette.Canvas
var _stamp_t := -1.0


func setup(data: LevelData, result: Dictionary, has_next: bool) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pal := Palette.from_theme(Game.theme(data.theme_name), data.theme_name)
	_pal = pal
	var bg := ColorRect.new()
	bg.color = Color(pal.fill_dark.r, pal.fill_dark.g, pal.fill_dark.b, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_bg = Vignette.Canvas.new()
	_bg.painter = _draw_bg
	add_child(_bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.position = Vector2(360, 140)
	col.size = Vector2(1200, 800)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	add_child(col)

	_add(col, tr("STATION %d / %d") % [Game.level_index + 1, Game.playlist.size()], 24, Brand.UI_TEXT_DIM, false, Brand.spaced(Brand.sans("medium"), 4))
	var titel := _add(col, data.name_text(), 68, Palette.WHITE, true, Brand.headline())
	titel.modulate.a = 0.0
	_add(col, Game.t(data.station.get("stampText", "")), 34, Palette.OK, false, Brand.sans("medium"))
	var badge := str(data.station.get("badge", ""))
	if badge != "":
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", Brand.accent_style(Brand.UI_HIGHLIGHT, Brand.UI_RADIUS, 22, 6, false))
		var cl := Label.new()
		cl.text = badge
		cl.add_theme_font_size_override("font_size", 26)
		cl.add_theme_font_override("font", Brand.sans("medium"))
		cl.add_theme_color_override("font_color", Brand.UI_HIGHLIGHT)
		chip.add_child(cl)
		var center := CenterContainer.new()
		center.add_child(chip)
		col.add_child(center)
	if pal.zone_name != "":
		_add(col, "%s — %s" % [pal.zone_name, pal.zone_fact], 22, Color(0.75, 0.82, 0.94))

	# Medaillen
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	var medals: Dictionary = result.get("medals", {})
	_medal(row, "ZEIT", tr("%.1f s / Ziel %.0f s") % [result.get("time", 0.0), result.get("par", 0.0)], medals.get("zeit", false))
	_medal(row, "PRÜFSUMMEN", "%d / %d" % [result.get("bits", 0), result.get("bits_total", 0)], medals.get("bits", false))
	_medal(row, "LÜCKENLOS", tr("nie mitgelesen") if medals.get("lueckenlos", false) else tr("%d× gesehen") % int(result.get("seen", 0)), medals.get("lueckenlos", false))
	col.add_child(row)
	_add(col, tr("%d Punkte") % Game.score, 30, Palette.WHITE, false, Brand.sans("medium"))
	var next := tr("Weiter: %s") % Kiosk.label_jump() if has_next else tr("Zum e-Rezept: %s") % Kiosk.label_jump()
	_add(col, next, 22, Brand.UI_ACCENT, false, Brand.sans("medium"))

	# Medaillen nacheinander einblenden
	var i := 0
	for m in row.get_children():
		m.modulate.a = 0.0
		m.scale = Vector2(1.4, 1.4)
		var tw := create_tween()
		tw.tween_interval(0.5 + i * 0.35)
		tw.tween_callback(func(): Sfx.play("medal", 1.0 + i * 0.1) if medals.values()[i] else Sfx.play("ui", 0.8))
		tw.tween_property(m, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(m, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
	get_tree().create_timer(0.8).timeout.connect(func(): _armed = true)
	if Kiosk.shots_dir != "":
		_auto = 999.0
	var alle := medals.size() > 0 and medals.values().all(func(v): return bool(v))
	if alle:
		get_tree().create_timer(1.7).timeout.connect(func():
			if is_instance_valid(_bg):
				Fx.burst(_bg, Vector2(960, 540), Brand.UI_HIGHLIGHT, 36, 560.0)
				Sfx.play("bonus", 1.1, -4.0))
	# Stempel: der Stationsname schlägt ein, sobald das Layout steht
	await get_tree().process_frame
	if not is_instance_valid(titel):
		return
	titel.pivot_offset = titel.size * 0.5
	titel.scale = Vector2(1.7, 1.7)
	titel.rotation = -0.07
	var st := create_tween()
	st.tween_interval(0.12)
	st.tween_callback(func():
		_stamp_t = _t
		Sfx.play("seal", 1.0, -6.0))
	st.tween_property(titel, "modulate:a", 1.0, 0.12)
	st.parallel().tween_property(titel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	st.parallel().tween_property(titel, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add(parent: Control, text: String, size: int, color: Color, outline := false, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ls := LabelSettings.new()
	ls.font = font if font else Brand.sans("roman")
	ls.font_size = size
	ls.font_color = color
	if outline:
		ls.outline_size = 10
		ls.outline_color = Color(0.02, 0.04, 0.08, 0.9)
	l.label_settings = ls
	parent.add_child(l)
	return l


func _medal(parent: Control, title: String, value: String, got: bool) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Brand.accent_style(Brand.UI_HIGHLIGHT if got else Brand.GREY_MID, Brand.UI_RADIUS, 26, 16, got))
	box.pivot_offset = Vector2(120, 60)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := Label.new()
	icon.text = "★" if got else "☆"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 44)
	icon.add_theme_color_override("font_color", Brand.UI_HIGHLIGHT if got else Brand.GREY_MID)
	v.add_child(icon)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_font_override("font", Brand.spaced(Brand.sans("medium"), 2))
	t.add_theme_color_override("font_color", Palette.WHITE if got else Brand.UI_TEXT_MUTED)
	v.add_child(t)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 18)
	val.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	v.add_child(val)
	box.add_child(v)
	parent.add_child(box)


## Hintergrund: Farbverlauf der Zone, langsam drehender Strahlenkranz, Stempelring.
func _draw_bg(c: CanvasItem) -> void:
	var base := _pal.fill_dark
	Pen.vgradient(c, 0, 0, 1920, 1080, base.darkened(0.35), base.lightened(0.05))
	var ctr := Vector2(960, 560)
	var acc := Brand.UI_HIGHLIGHT
	for i in 14:
		var a0 := _t * 0.10 + i * TAU / 14.0
		var a1 := a0 + TAU / 30.0
		c.draw_polygon(PackedVector2Array([ctr, ctr + Vector2(cos(a0), sin(a0)) * 1500.0, ctr + Vector2(cos(a1), sin(a1)) * 1500.0]),
			PackedColorArray([Color(acc.r, acc.g, acc.b, 0.07), Color(acc.r, acc.g, acc.b, 0.0), Color(acc.r, acc.g, acc.b, 0.0)]))
	# Randabdunklung
	var d := Color(0, 0, 0, 0)
	var k := Color(0, 0, 0, 0.45)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 220), Vector2(0, 220)]), PackedColorArray([k, k, d, d]))
	c.draw_polygon(PackedVector2Array([Vector2(0, 860), Vector2(1920, 860), Vector2(1920, 1080), Vector2(0, 1080)]), PackedColorArray([d, d, k, k]))
	# Stempelring um den Titel
	if _stamp_t >= 0.0:
		var kk := (_t - _stamp_t) / 0.55
		if kk < 1.0:
			c.draw_arc(Vector2(960, 300), 60.0 + 260.0 * kk, 0.0, TAU, 64, Color(acc.r, acc.g, acc.b, 0.6 * (1.0 - kk)), 6.0 * (1.0 - kk) + 1.0, true)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_bg):
		_bg.queue_redraw()
	if _fired:
		return
	if (_armed and Input.is_action_just_pressed("confirm")) or _t > _auto:
		_fired = true
		Sfx.play("ok")
		done.emit()
