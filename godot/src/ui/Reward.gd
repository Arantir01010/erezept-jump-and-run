class_name Reward
extends Control
## REWARD — „Dein e-Rezept ist da!": QR-Code für den Medikamentenautomaten,
## Siegel-Reihe, Sicherheitsstufe, Tages-Highscore (Avatar statt Name).
## QR mindestens minQrSeconds sichtbar, Auto-Reset nach rewardScreenSeconds.

signal done

const AVATARS := ["🐻", "🦊", "🐼", "🐸", "🦉", "🐙", "🐧", "🦋", "🐝", "🐬", "🦄", "🐢"]

var _t := 0.0
var _min := 10.0
var _max := 45.0
var _fired := false
var _picker := false
var _avatar := 0
var _saved := false
var avatar_label: Label
var hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ending: Dictionary = Game.config.get("ending", {})
	_min = float(ending.get("minQrSeconds", 10))
	_max = float(ending.get("rewardScreenSeconds", 45))
	if Kiosk.shots_dir != "":
		_max = 999.0
	var pal := Palette.from_theme(Game.theme("city"), "city")
	var bg := ColorRect.new()
	bg.color = pal.fill_dark
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_label("Dein e-Rezept ist da!", 74, Vector2(0, 60), Palette.WHITE, true, Brand.headline())
	_label("Löse es am Medikamentenautomaten ein.", 30, Vector2(0, 150), Color(0.85, 0.9, 1.0))

	# QR-Code: harte Kanten, ruhige weiße Fläche, kein Glühen (Funktion, keine Grafik)
	var qr := TextureRect.new()
	if ResourceLoader.exists("res://assets/qr/reward.png"):
		qr.texture = load("res://assets/qr/reward.png")
	else:
		var img := Image.load_from_file("res://assets/qr/reward.png")
		if img:
			qr.texture = ImageTexture.create_from_image(img)
	qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr.stretch_mode = TextureRect.STRETCH_SCALE
	qr.size = Vector2(360, 360)
	qr.position = Vector2(780, 220)
	var frame := ColorRect.new()
	frame.color = Color.WHITE
	frame.position = qr.position - Vector2(18, 18)
	frame.size = qr.size + Vector2(36, 36)
	add_child(frame)
	add_child(qr)

	# Siegel-Reihe
	var seals := HBoxContainer.new()
	seals.alignment = BoxContainer.ALIGNMENT_CENTER
	seals.add_theme_constant_override("separation", 12)
	seals.position = Vector2(0, 610)
	seals.size = Vector2(1920, 60)
	var idx := 1
	for s in Game.seals:
		var l := Label.new()
		l.text = "◉ %d" % idx
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Palette.GOLD)
		seals.add_child(l)
		idx += 1
	add_child(seals)

	var rank := Game.rank()
	var medals := 0
	for r in Game.level_results:
		medals += int(r.get("medal_count", 0))
	_label("%d Punkte  ·  Sicherheitsstufe: %s  ·  %d Medaillen  ·  %.0f s" % [Game.score, Game.t(rank["label"]), medals, Game.elapsed_seconds()], 30, Vector2(0, 680), Palette.WHITE)

	# Highscore
	var hs := Game.highscores()
	var box := VBoxContainer.new()
	box.position = Vector2(1400, 240)
	var head := Label.new()
	head.text = "TAGES-BESTENLISTE"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_font_override("font", Brand.spaced(Brand.sans("medium"), 3))
	head.add_theme_color_override("font_color", Brand.UI_HIGHLIGHT)
	box.add_child(head)
	var i := 1
	for e in hs:
		var l := Label.new()
		l.text = "%d.  %s   %d P" % [i, AVATARS[int(e["avatar"]) % AVATARS.size()], int(e["score"])]
		l.add_theme_font_size_override("font_size", 24)
		box.add_child(l)
		i += 1
	add_child(box)

	if Game.qualifies(Game.score):
		_picker = true
		_label("Neuer Bestwert! Wähle dein Symbol: ◀ ▶  dann %s" % Kiosk.label_action(), 24, Vector2(0, 760), Palette.GOLD)
		avatar_label = _label(AVATARS[0], 64, Vector2(0, 800), Palette.WHITE)
	hint = _label("", 22, Vector2(0, 1000), Color(0.7, 0.78, 0.9))
	_label(Game.t(Game.config.get("disclaimer", {"de": ""})), 16, Vector2(0, 1040), Color(0.55, 0.6, 0.72))
	Sfx.play("seal")


func _label(text: String, size: int, pos: Vector2, color: Color, outline := false, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(1920, size + 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = font if font else Brand.sans("roman")
	ls.font_size = size
	ls.font_color = color
	if outline:
		ls.outline_size = 10
		ls.outline_color = Color(0.02, 0.04, 0.08, 0.9)
	l.label_settings = ls
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	if _fired:
		return
	if _picker and not _saved:
		if Input.is_action_just_pressed("move_left"):
			_avatar = (_avatar + AVATARS.size() - 1) % AVATARS.size()
			avatar_label.text = AVATARS[_avatar]
			Sfx.play("ui")
		elif Input.is_action_just_pressed("move_right"):
			_avatar = (_avatar + 1) % AVATARS.size()
			avatar_label.text = AVATARS[_avatar]
			Sfx.play("ui")
		elif Input.is_action_just_pressed("action"):
			_saved = true
			Game.add_highscore(_avatar, Game.score)
			avatar_label.text = AVATARS[_avatar] + "  ✓ gespeichert"
			Sfx.play("medal")
	var left := _min - _t
	if left > 0.0:
		hint.text = "QR-Code scannen … (%d s)" % ceili(left)
	else:
		hint.text = "%s: Nächster Spieler" % Kiosk.label_jump()
		if Input.is_action_just_pressed("jump") or _t > _max:
			_fired = true
			done.emit()
	if _t > _max:
		_fired = true
		done.emit()
