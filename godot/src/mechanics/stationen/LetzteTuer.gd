extends Mechanic
## DIE LETZTE TÜR (Baustein „letzte-tuer“) — das Finale: die Tür, die nicht der Spieler öffnet.
##
## Die Tür ohne Öffner: Der Spieler kann sie nicht öffnen (Vorhängeschloss, Knopf
## wird abgewiesen). Das Zugriffsprotokoll erscheint, dann öffnet die Person, der
## die Akte gehört: Bügel springt auf, die Protokollzeile wird grün, die Tür hebt.
## Fachlich: Datensouveränität — die Tür gehört nicht dem Datensatz, sondern der Person.

var body: StaticBody2D
var _cs: CollisionShape2D
var phase := "wartet"      # wartet → protokoll → freigabe → offen
var _rise := 0.0
var _lock := 0.0           # 0 = Bügel zu, 1 = offen
var _ok_t := 0.0           # Einblendung der grünen Freigabezeile
var _t := 0.0
var _hint := false
var _last_deny := -100.0
var _lines: Array = []
var _ok_line := ""
var _completed := false
var _light: PointLight2D
var _glow: Sprite2D

func spawn() -> void:
	z_index = 5
	_light = Fx.light(self, Vector2(0, -rect.size.y / 2.0 + 20.0), Palette.GOLD, 260.0, 0.0)
	if Fx.web_fallback():
		_glow = Fx.glow_sprite(self, Palette.GOLD, 60.0, 0.0)
		_glow.position = _lock_local()
	body = StaticBody2D.new()
	body.collision_layer = 1
	_cs = CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(24.0, rect.size.y)
	_cs.shape = s
	body.add_child(_cs)
	add_child(body)
	make_sensor(Rect2(rect.position.x - 260, rect.position.y - 40, 260, rect.size.y + 40), _arrive)
	make_sensor(Rect2(rect.end.x + 20, rect.position.y, 120, rect.size.y), _through)

func _lock_local() -> Vector2:
	return Vector2(0, 6.0 - (rect.size.y - 10.0) * _rise)

func _arrive(_p: Player) -> void:
	if _hint:
		return
	_hint = true
	say(ltext("warteText", {"de": "Hier endet mein Weg. Jetzt entscheidet sie.", "en": "This is where my path ends. Now she decides."}), 4.0)
	get_tree().create_timer(2.2).timeout.connect(_start_protokoll)

func _through(_p: Player) -> void:
	if phase == "offen" and not _completed:
		_completed = true
		level.complete_level()

func tick(delta: float) -> void:
	_t += delta
	if _glow:
		_glow.position = _lock_local()
	queue_redraw()
	if phase != "offen" and player_in_rect(Rect2(rect.position.x - 120, rect.position.y, 120, rect.size.y)) and Input.is_action_just_pressed("action"):
		if _t - _last_deny > 2.0:
			_last_deny = _t
			Sfx.play("deny", 1.1, -6.0)
			say(ltext("denyText", {"de": "Kein Schlüssel öffnet diese Tür. Sie gehört nicht dir.", "en": "No key opens this door. It is not yours."}), 3.0)

func _start_protokoll() -> void:
	if phase != "wartet" or not is_inside_tree():
		return
	phase = "protokoll"
	var entries := Game.protokoll.duplicate()
	var lines: Array = []
	lines.append("ZUGRIFFSPROTOKOLL")
	if entries.is_empty():
		lines.append("— keine Einträge —")
	for e in entries.slice(0, 6):
		lines.append("gesehen · %s · %s" % [e["actor"], e["level_id"]])
	if entries.size() > 6:
		lines.append("… und %d weitere" % (entries.size() - 6))
	var i := 0
	for l in lines:
		get_tree().create_timer(0.55 * i).timeout.connect(func():
			if is_inside_tree():
				_lines.append(l)
				Sfx.play("tick", 1.2, -10.0))
		i += 1
	var wait := 0.55 * lines.size() + 1.8
	get_tree().create_timer(wait).timeout.connect(_freigabe.bind(entries.is_empty()))

## Der Freigabe-Beat: Bügel springt auf, die Freigabezeile wird grün — erst
## dann hebt die Tür. Sie öffnet nicht der Spieler, sondern die Inhaberin.
func _freigabe(lueckenlos: bool) -> void:
	if not is_inside_tree() or phase != "protokoll":
		return
	phase = "freigabe"
	_ok_line = ltext("freigabeZeile", {"de": "✓ FREIGABE · durch die Inhaberin der Akte", "en": "✓ RELEASED · by the owner of the record"})
	Sfx.play("ok", 0.9)
	var tw := create_tween()
	tw.tween_property(self, "_lock", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_ok_t", 1.0, 0.4)
	tw.tween_callback(func():
		if is_inside_tree():
			var at := to_global(_lock_local())
			Fx.sparkle(level, at, Palette.GOLD, 10, 160.0)
			Fx.ring(level, at, Palette.OK, 64.0)
			Sfx.play("checkpoint", 1.2, -6.0))
	tw.tween_interval(0.35)
	tw.tween_callback(_oeffnen.bind(lueckenlos))

func _oeffnen(lueckenlos: bool) -> void:
	if not is_inside_tree():
		return
	phase = "offen"
	if lueckenlos:
		say(ltext("lueckenlosText", {"de": "Sie sieht: Niemand hat mitgelesen.", "en": "She sees: nobody read along."}), 3.0)
		get_tree().create_timer(2.2).timeout.connect(func():
			if is_inside_tree():
				say(ltext("freigabeText", {"de": "Freigegeben — von ihr.", "en": "Released — by her."}), 3.0))
	else:
		say(ltext("freigabeText", {"de": "Freigegeben — von ihr.", "en": "Released — by her."}), 3.0)
	Sfx.play("gate", 0.8)
	Sfx.play("seal", 1.0, -8.0)
	_cs.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "_rise", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_light, "energy", 1.0, 0.9)
	if _glow:
		Fx.set_glow(_glow, Palette.GOLD, 1.0)
	Fx.ring(level, global_position, Palette.GOLD, 160.0)
	Fx.flash(Color(1, 0.95, 0.85), 0.25)

func _draw() -> void:
	var h := rect.size.y
	var lift := (h - 10.0) * _rise
	var door := Rect2(-24, -h / 2.0 - lift, 48, h)
	var open := phase == "offen"
	var edge := pal.detail.lerp(Palette.GOLD, maxf(_lock, 1.0 if open else 0.0))
	draw_panel(door, pal.fels.lightened(0.05), edge, 8, 0.8 if open else 0.15 + 0.5 * _lock, 3)
	# Rahmen
	draw_rect(Rect2(-30, -h / 2.0 - 8, 6, h + 8), pal.fels)
	draw_rect(Rect2(24, -h / 2.0 - 8, 6, h + 8), pal.fels)
	# Schild auf der Tür: wessen Akte
	draw_string(Brand.spaced(Brand.sans("medium"), 1), Vector2(-24, door.position.y + 30), ltext("tuerSchild", {"de": "AKTE", "en": "RECORD"}),
		HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.6))
	# Vorhängeschloss: Körper, Bügel (hebt und schwenkt beim Öffnen), Schlüsselloch → Haken
	var lp := Vector2(0, 6.0 - lift)
	var lc := pal.detail.lerp(Palette.GOLD, _lock)
	var lcg := Palette.glow(lc, 1.0 + 0.5 * _lock) if not Fx.web_fallback() else lc
	var lb := Rect2(lp.x - 11, lp.y - 2, 22, 18)
	var pivot := Vector2(lb.position.x + 5, lb.position.y)
	draw_set_transform(pivot + Vector2(0, -9.0 * _lock), -0.55 * _lock, Vector2.ONE)
	draw_arc(Vector2(6, 0), 6.0, PI, TAU, 14, lcg, 3.0, true)
	draw_line(Vector2(0, 0), Vector2(0, 3), lcg, 3.0)
	draw_line(Vector2(12, 0), Vector2(12, 3), lcg, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_panel(lb, Palette.shade(pal.metall, 0.2), lcg, 4, 0.6 * _lock, 2)
	if _lock < 0.5:
		draw_circle(lp + Vector2(0, 6), 2.5, Color(0.05, 0.05, 0.08))
		draw_rect(Rect2(lp.x - 1, lp.y + 6, 2, 6), Color(0.05, 0.05, 0.08))
	else:
		draw_polyline(PackedVector2Array([lp + Vector2(-5, 7), lp + Vector2(-1.5, 10.5), lp + Vector2(5, 3)]), Palette.OK, 2.5, true)
	# Zugriffsprotokoll über der Tür: Panel, Kopfzeile, Einträge (warm = offen
	# gelesen), Freigabezeile grün
	var n := _lines.size() + (1 if _ok_line != "" else 0)
	if n > 0:
		var row := 24.0
		var y0 := -h / 2.0 - 46.0 - n * row
		var panel := Rect2(-236, y0 - 20, 472, n * row + 30)
		var pe := Color(Palette.WARM.r, Palette.WARM.g, Palette.WARM.b, 0.55).lerp(Palette.OK, _ok_t)
		draw_panel(panel, Color(0.03, 0.05, 0.08, 0.80), pe, 8, 0.5 * _ok_t, 2)
		for i in _lines.size():
			var yy := y0 + i * row
			if i == 0:
				draw_string(Brand.spaced(Brand.sans("heavy"), 2), Vector2(-220, yy), str(_lines[i]), HORIZONTAL_ALIGNMENT_CENTER, 440, 17, Palette.WHITE)
			else:
				draw_string(Brand.sans("medium"), Vector2(-220, yy), str(_lines[i]), HORIZONTAL_ALIGNMENT_CENTER, 440, 16, Palette.WARM)
		if _ok_line != "":
			var yy := y0 + _lines.size() * row
			draw_line(Vector2(-200, yy - 17), Vector2(200, yy - 17), Color(pe.r, pe.g, pe.b, 0.5 * _ok_t), 1.0)
			draw_string(Brand.sans("heavy"), Vector2(-220 - (1.0 - _ok_t) * 16.0, yy), _ok_line, HORIZONTAL_ALIGNMENT_CENTER, 440, 16,
				Color(Palette.OK.r, Palette.OK.g, Palette.OK.b, _ok_t))
