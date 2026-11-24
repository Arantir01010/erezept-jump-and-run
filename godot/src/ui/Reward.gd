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
	_label("Löse es am Medikamentenautomaten ein.", 30, Vector2(0, 150), Brand.UI_TEXT_DIM)

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
	_info_qr()

	# Siegel-Reihe als Zusammenfassung: je Station das Badge (Stichwort), statt nur
	# „◉ 1 … ◉ 10" — damit am Ende sichtbar wird, was man unterwegs gesichert hat.
	var badges := seal_badges()
	if not badges.is_empty():
		_label(tr("Das hast du gesichert:"), 24, Vector2(0, 606), Brand.UI_TEXT_DIM)
	var seals := HFlowContainer.new()
	seals.alignment = FlowContainer.ALIGNMENT_CENTER
	seals.add_theme_constant_override("h_separation", 26)
	seals.add_theme_constant_override("v_separation", 4)
	seals.position = Vector2(160, 642)
	seals.size = Vector2(1600, 80)
	for b in badges:
		var l := Label.new()
		l.text = "◉ " + str(b)
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Palette.GOLD)
		seals.add_child(l)
	add_child(seals)

	var rank := Game.rank()
	var medals := 0
	for r in Game.level_results:
		medals += int(r.get("medal_count", 0))
	if Game.wissen_medaille():
		medals += 1
	var zeile := tr("%d Punkte  ·  Sicherheitsstufe: %s  ·  %d Medaillen  ·  %.0f s") % [Game.score, Game.t(rank["label"]), medals, Game.elapsed_seconds()]
	if Game.wissen_fragen > 0:
		zeile += "  ·  " + tr("Wissen: %d / %d") % [Game.wissen_richtig, Game.wissen_fragen]
	_label(zeile, 30, Vector2(0, 732), Palette.WHITE)

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
		l.text = "%d.  %s   %d P" % [i, AVATARS[absi(int(e.get("avatar", 0))) % AVATARS.size()], int(e.get("score", 0))]
		l.add_theme_font_size_override("font_size", 24)
		box.add_child(l)
		i += 1
	add_child(box)

	if Game.qualifies(Game.score):
		_picker = true
		_label(tr("Neuer Bestwert! Wähle dein Symbol: ◀ ▶  dann %s") % Kiosk.label_action(), 24, Vector2(0, 796), Brand.UI_HIGHLIGHT)
		avatar_label = _label(AVATARS[0], 64, Vector2(0, 836), Palette.WHITE)
	hint = _label("", 22, Vector2(0, 1000), Brand.UI_TEXT_DIM)
	_label(Game.t(Game.config.get("disclaimer", {"de": ""})), 16, Vector2(0, 1040), Brand.UI_TEXT_MUTED)
	Sfx.play("seal")


## Zweiter, kleinerer QR-Code zum Mitnehmen (Punkt 17): Link zum Nachlesen aufs
## Handy, links und deutlich abgesetzt vom Gewinncode für den Automaten.
## Erzeugt von tools/gen_assets.py aus ending.infoLink; ohne Datei kein Code.
func _info_qr() -> void:
	const PFAD := "res://assets/qr/info.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(PFAD):
		tex = load(PFAD)
	if tex == null or str(Game.config.get("ending", {}).get("infoLink", "")) == "":
		return
	var q := TextureRect.new()
	q.texture = tex
	q.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	q.stretch_mode = TextureRect.STRETCH_SCALE
	q.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	q.size = Vector2(200, 200)
	q.position = Vector2(320, 300)
	var rahmen := ColorRect.new()
	rahmen.color = Color.WHITE
	rahmen.position = q.position - Vector2(10, 10)
	rahmen.size = q.size + Vector2(20, 20)
	add_child(rahmen)
	add_child(q)
	var l := Label.new()
	l.text = tr("Mehr zum E-Rezept — mit dem Handy scannen")
	l.position = Vector2(220, 528)
	l.size = Vector2(400, 80)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Brand.UI_TEXT_DIM)
	add_child(l)


## Badges der gesicherten Stationen in Spielreihenfolge (übersetzt). Ohne Badge
## oder mit reinem Welt-Etikett („Welt 5 · Abschluss") bleibt die Station weg.
static func seal_badges() -> Array[String]:
	var out: Array[String] = []
	for s in Game.seals:
		var id := str((s as Dictionary).get("level_id", "")) if s is Dictionary else ""
		if id == "":
			continue
		var data := LevelData.load_level(id)
		var badge := str(data.station.get("badge", "")).strip_edges()
		if badge == "" or badge.begins_with("Welt "):
			continue
		var t := TranslationServer.translate(badge)
		if not out.has(t):
			out.append(t)
	return out


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
			avatar_label.text = AVATARS[_avatar] + tr("  ✓ gespeichert")
			Sfx.play("medal")
	var left := _min - _t
	if left > 0.0:
		hint.text = tr("QR-Code scannen … (%d s)") % ceili(left)
	else:
		hint.text = tr("%s: Nächster Spieler") % Kiosk.label_jump()
		if Input.is_action_just_pressed("jump") or _t > _max:
			_fired = true
			done.emit()
	if _t > _max:
		_fired = true
		done.emit()
