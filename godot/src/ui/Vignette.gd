class_name Vignette
extends Node2D
## VIGNETTE — Basis aller Info-Screens (Hauptmenü, Zeitreise, Probelauf, ePA-Wissen).
##
## Die Screens stammen 1:1 aus der Web-Fassung und leben im 640×360-Design-Raum:
## `stage` ist ein Node2D mit Skalierung 3 (→ 1920×1080), darin liegen vier
## Zeichenebenen — Himmel, Statik (einmal gezeichnet), additives Leuchten und
## „Leben" (jeden Frame neu, reine Funktion der Zeit). Schriften liegen
## UNSKALIERT in `textlayer` (Label mit 3-facher Schriftgröße), damit sie
## scharf bleiben. Dazu: Mindest-Anzeigedauer mit Zeitbalken, Weiter-Zeile,
## Fortschrittspunkte, Rand-Vignette und „jeder Knopf blättert weiter".
##
## ERZÄHLBAND (Runde 3): Erzählzeilen laufen nicht mehr als dünne Zeile über
## den Himmel, sondern in einem dunklen Textband unter der Überschrift — mit
## REZI als Erzähler, Aufbau Zeichen für Zeichen, Zeilenpunkten und Ausblendung
## im Takt. Unterklassen melden Zeilen mit `story_line(text, von, bis)` und
## den Takt mit `story_cycle`; Alpha, Aufbau und Bandhöhe regelt die Basis.
## ENTRANCE: Überschriften und Schilder gleiten beim Öffnen des Screens ein,
## Bühne und Leben blenden auf (aus in Title, das eine eigene Choreografie hat).

signal done

const W := 640.0
const H := 360.0
const S := 3.0
# Erzählband unter der Überschrift (Design-Raum)
const BAND_X := 34.0
const BAND_W := 572.0
const BAND_Y := 84.0
const BAND_PAD := 7.0
const BAND_TEXT_X := 84.0       # links davon sitzt REZI als Erzähler
const BAND_TEXT_W := 506.0
const BAND_ACCENT := 0xffd591

var theme := {}
var sperre := 0.0
var weiter_text := "LEERTASTE: Weiter!"
var dots: Array = []
var tz := 0.0
var t := 0.0
var stage: Node2D
var sky: Canvas
var statik: Canvas
var glow: Canvas
var leben: Canvas
var textlayer: Node2D
var weiter: Label
var _anchor := -1.0
var _done := false
var entrance := true
var story: Array = []           # [{label, von, bis, h}] — Erzählzeilen im Band
var story_cycle := 0.0          # 0 = keine Wiederholung, sonst Taktlänge in s
var story_narrator := true      # REZI links im Band
var _story_band_a := 0.0
var _story_h := 0.0
var _story_last := -1
var _story_reveal := 1.0
var _entrance_items: Array = []     # [label, zielposition, zielalpha, verzögerung]
var _entrance_active := false
static var _fonts := {}


class Canvas extends Node2D:
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


func _ready() -> void:
	theme = city_theme()
	stage = Node2D.new()
	stage.scale = Vector2(S, S)
	add_child(stage)
	sky = _canvas(_draw_sky)
	statik = _canvas(_draw_static)
	glow = _canvas(_draw_glow)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	leben = _canvas(_draw_life_wrapper)
	_motes()
	var vig := Canvas.new()
	vig.painter = _draw_vignette
	add_child(vig)
	textlayer = Node2D.new()
	add_child(textlayer)
	_build()
	if weiter_text != "":
		weiter = label(W - 12, 340, weiter_text, 10.5, {"color": Pen.hex(0xffd591), "spacing": 0.4, "origin": Vector2(1, 0.5), "stroke": Pen.hex(0x0a1730), "stroke_w": 1.0})
		weiter.modulate.a = 0.0
	if entrance:
		_entrance()


func _canvas(painter: Callable) -> Canvas:
	var c := Canvas.new()
	c.painter = painter
	stage.add_child(c)
	return c


## Farbwelt „city" der Web-Fassung — die Nacht, in der alle Screens spielen.
static func city_theme() -> Dictionary:
	var th: Dictionary = Game.theme("city")
	var d := {
		"sky_top": Pen.html(str(th.get("skyTop", "#2a3550"))),
		"sky_bottom": Pen.html(str(th.get("skyBottom", "#4a5b82"))),
		"ground": Pen.html(str(th.get("ground", "#3a3f4a"))),
		"ground_top": Pen.html(str(th.get("groundTop", "#565d6e"))),
		"accent": Pen.html(str(th.get("accent", "#ffd75e"))),
		"detail": Pen.html(str(th.get("detail", "#7f8ba6"))),
	}
	d["fog"] = Pen.fog_of(d["sky_bottom"])
	return d


# ------------------------------------------------------------ Überschreibbar

## Statische Bühne (einmal). Unterklassen zeichnen hier.
func _draw_static(_c: CanvasItem) -> void:
	pass


## Additive Lichtflecken (einmal).
func _draw_glow(_c: CanvasItem) -> void:
	pass


## Bewegtes, jeden Frame: `t` absolute Sekunden, `tz` Sekunden seit Anzeige.
func _draw_life(_c: CanvasItem) -> void:
	pass


## Labels und Kinder anlegen (nach den Zeichenebenen).
func _build() -> void:
	pass


## Pro Frame (Label-Alphas, Choreografie).
func _tick(_delta: float) -> void:
	pass


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	t = Time.get_ticks_msec() / 1000.0
	if _anchor < 0.0:
		_anchor = t
	tz = maxf(0.0, t - _anchor)
	if weiter:
		weiter.modulate.a = 0.0 if tz < sperre else 0.65 + 0.35 * sin(tz * 4.0)
	_entrance_tick()
	_tick(delta)
	_story_tick()
	leben.queue_redraw()


func _draw_life_wrapper(c: CanvasItem) -> void:
	_draw_life(c)
	_draw_story_band(c)
	# Weiter-Zeile erst nach der Mindestdauer; vorher ein feiner Zeitbalken
	if sperre > 0.0 and tz < sperre:
		Pen.rect(c, W - 72, 339, 60, 1.6, Pen.hex(0xffd591, 0.2))
		Pen.rect(c, W - 72, 339, 60.0 * tz / sperre, 1.6, Pen.hex(0xffd591, 0.6))
	for i in dots.size():
		Pen.circle(c, W - 40 + i * 10, 352, 2, Pen.hex(0xffd591, 0.9 if dots[i] else 0.3))


func _unhandled_input(event: InputEvent) -> void:
	if _done or not is_press(event):
		return
	if tz < sperre:
		return
	_advance()


## Zählt als „Knopf gedrückt": Taste, Gamepad-Knopf, echter Fingertipp, Mausklick.
static func is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return false
		return k.keycode < KEY_F1 or k.keycode > KEY_F12
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION
	if event is InputEventMouseButton:
		return event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION
	return false


func _advance() -> void:
	_done = true
	set_process_unhandled_input(false)
	Sfx.play("ui")
	done.emit()


## Für den Prüflauf: sofort weiter, Sperre ignorieren.
func skip() -> void:
	if not _done:
		_advance()


# ---------------------------------------------------------------- Schriften

## Label im Design-Raum: (x, y) in 640×360-Koordinaten, `size` wie im Original.
## opts: color, bold (Standard true), serif (Überschrift in ITC Charter),
##       stroke, stroke_w, spacing, origin, alpha
func label(x: float, y: float, text: String, size: float, opts := {}) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	if bool(opts.get("serif", false)):
		ls.font = font_serif(float(opts.get("spacing", 0.0)))
	else:
		ls.font = font(bool(opts.get("bold", true)), float(opts.get("spacing", 0.0)))
	ls.font_size = maxi(7, roundi(size * S))
	ls.font_color = opts.get("color", Color.WHITE)
	if opts.has("stroke"):
		ls.outline_color = opts["stroke"]
		ls.outline_size = maxi(1, roundi(float(opts.get("stroke_w", 1.0)) * S * 0.8))
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textlayer.add_child(l)
	l.reset_size()
	var origin: Vector2 = opts.get("origin", Vector2(0.5, 0.5))
	l.position = (Vector2(x, y) * S - l.size * origin).round()
	l.modulate.a = float(opts.get("alpha", 1.0))
	return l


## Fließtext und Schilder: Helvetica Neue (Medium für „bold" — das Original
## lief mit Schriftgewicht 600 —, Roman für normal), Buchstabenabstand in px.
static func font(bold: bool, spacing: float) -> Font:
	var key := "sans-%s-%d" % [bold, roundi(spacing * S)]
	if _fonts.has(key):
		return _fonts[key]
	var f := Brand.spaced(Brand.sans("medium" if bold else "roman"), roundi(spacing * S))
	_fonts[key] = f
	return f


## Überschriften: ITC Charter Bold.
static func font_serif(spacing: float) -> Font:
	var key := "serif-%d" % roundi(spacing * S)
	if _fonts.has(key):
		return _fonts[key]
	var f := Brand.spaced(Brand.headline(), roundi(spacing * S))
	_fonts[key] = f
	return f


## Titel + Untertitel wie auf allen Info-Screens.
func header(titel: String, untertitel: String) -> void:
	label(W / 2, 44, titel, 26, {"serif": true, "stroke": Pen.hex(0x0a1730), "stroke_w": 1.2, "spacing": 1.2})
	label(W / 2, 72, untertitel, 10.5, {"color": Pen.hex(0xcfe0ff), "bold": false, "stroke": Pen.hex(0x0a1730), "stroke_w": 1.0})


# ---------------------------------------------------------------- Erzählband

## Erzählzeile im Band: sichtbar von `von` bis `bis` (Sekunden im Takt
## `story_cycle`, sonst seit Anzeige). Mehrzeilig, Aufbau Zeichen für Zeichen.
## opts: size (Design-px, Standard 11), color, bold (Standard true)
func story_line(text: String, von: float, bis: float, opts := {}) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font(bool(opts.get("bold", true)), 0.0)
	ls.font_size = roundi(float(opts.get("size", 11.0)) * S)
	ls.font_color = opts.get("color", Pen.hex(0xf6f8ff))
	ls.line_spacing = 3.0
	l.label_settings = ls
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line_h := ls.font.get_height(ls.font_size) + ls.line_spacing
	var measured := ls.font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, BAND_TEXT_W * S, ls.font_size)
	var lines := maxi(1, roundi(measured.y / ls.font.get_height(ls.font_size)))
	var text_h := lines * line_h
	l.custom_minimum_size = Vector2(BAND_TEXT_W * S, text_h)
	l.size = Vector2(BAND_TEXT_W * S, text_h)
	l.position = (Vector2(BAND_TEXT_X, BAND_Y + BAND_PAD) * S).round()
	l.modulate.a = 0.0
	l.visible_ratio = 0.0
	textlayer.add_child(l)
	story.append({"label": l, "von": von, "bis": bis, "h": BAND_PAD * 2.0 + text_h / S})
	return l


## Zeit im Erzähltakt.
func story_u() -> float:
	return fmod(tz, story_cycle) if story_cycle > 0.0 else tz


func _story_tick() -> void:
	if story.is_empty():
		return
	var u := story_u()
	var von0: float = story[0]["von"]
	var bis1: float = story[story.size() - 1]["bis"]
	_story_band_a = Pen.blende(u, von0 - 0.2, bis1 + 0.1, 0.35)
	var hsum := 0.0
	var wsum := 0.0
	var aktiv := -1
	var best := 0.0
	for i in story.size():
		var s: Dictionary = story[i]
		var l: Label = s["label"]
		var von: float = s["von"]
		var bis: float = s["bis"]
		var a := Pen.blende(u, von, bis, 0.3)
		l.modulate.a = a
		var dauer := clampf((bis - von) * 0.38, 0.5, 1.7)
		var reveal := clampf((u - von) / dauer, 0.0, 1.0) if a > 0.0 else 0.0
		l.visible_ratio = reveal
		l.position.y = roundi((BAND_Y + BAND_PAD) * S + (1.0 - a) * 2.0 * S)
		hsum += float(s["h"]) * a
		wsum += a
		if a > best:
			best = a
			aktiv = i
			_story_reveal = reveal
	if wsum > 0.0:
		_story_h = hsum / wsum
	if aktiv != _story_last:
		_story_last = aktiv
		if aktiv >= 0 and tz > 0.4:
			Sfx.play("tick", 1.35, -16.0)


## Das Band selbst: Schatten, Fläche, Akzentleiste, REZI als Erzähler mit
## Sprechwellen, solange die Zeile sich aufbaut, Zeilenpunkte unten rechts.
func _draw_story_band(c: CanvasItem) -> void:
	if story.is_empty() or _story_band_a <= 0.01:
		return
	var a := _story_band_a
	var h := maxf(_story_h, BAND_PAD * 2.0 + 12.0)
	var y := BAND_Y
	Pen.rrect(c, BAND_X + 1.5, y + 2.5, BAND_W, h, 6, Color(0, 0, 0, 0.35 * a))
	Pen.rrect(c, BAND_X, y, BAND_W, h, 6, Pen.hex(0x070f1c, 0.88 * a))
	Pen.vgradient(c, BAND_X + 6, y + 0.5, BAND_W - 12, h * 0.45, Color(1, 1, 1, 0.05 * a), Color(1, 1, 1, 0.0))
	Pen.srrect(c, BAND_X, y, BAND_W, h, 6, Color(1, 1, 1, 0.16 * a), 0.8)
	Pen.rrect(c, BAND_X + 3.5, y + 5, 2.4, h - 10, 1.2, Pen.hex(BAND_ACCENT, 0.95 * a))
	Pen.rect(c, BAND_TEXT_X - 9, y + 7, 0.6, h - 14, Color(1, 1, 1, 0.12 * a))
	if story_narrator:
		var cx := BAND_X + 28.0
		var cy := y + h * 0.5 + sin(t * 2.4) * 0.8
		Pen.circle(c, cx, cy, 11.0, Pen.alpha(Pen.K, 0.07 * a))
		Pen.rezi(c, cx, cy, a, 1.7, false, false)
		if _story_reveal < 1.0:
			for k in 3:
				var f := fmod(t * 1.6 + k / 3.0, 1.0)
				Pen.arc(c, cx + 9.5, cy, 3.0 + f * 7.0, -0.55, 0.55, Pen.alpha(Pen.K, (1.0 - f) * 0.7 * a), 0.8)
	var n := story.size()
	for i in n:
		var on := i == _story_last
		Pen.circle(c, BAND_X + BAND_W - 9 - (n - 1 - i) * 6, y + h - 4.5, 1.7 if on else 1.1, Pen.hex(BAND_ACCENT, (0.95 if on else 0.32) * a))


# ------------------------------------------------------------------ Entrance

## Beim Öffnen: Schilder und Überschriften gleiten von oben ein (gestaffelt),
## Bühne, Leuchten und Leben blenden auf. Zeilen mit Alpha 0 (Rufe, Erzählband)
## steuern die Unterklassen selbst — die bleiben unangetastet. Läuft nach der
## Wanduhr (tz), nicht über Tweens: stockt die Bildschleife (Browser-Tab im
## Hintergrund, Shader-Aufbau), springt alles einfach an seinen Platz.
func _entrance() -> void:
	var i := 0
	for n in textlayer.get_children():
		if not (n is Label):
			continue
		var l := n as Label
		if l == weiter or l.modulate.a <= 0.0:
			continue
		_entrance_items.append([l, l.position, l.modulate.a, 0.10 + i * 0.045])
		l.position += Vector2(0, -5.0 * S)
		l.modulate.a = 0.0
		i += 1
	for cv in [statik, glow, leben]:
		cv.modulate.a = 0.0
	_entrance_active = true


func _entrance_tick() -> void:
	if not _entrance_active:
		return
	var fertig := true
	var ka := clampf(tz / 0.65, 0.0, 1.0)
	for cv in [statik, glow, leben]:
		cv.modulate.a = sin(ka * PI * 0.5)
	if ka < 1.0:
		fertig = false
	for it in _entrance_items:
		var l: Label = it[0]
		if not is_instance_valid(l):
			continue
		var k := clampf((tz - float(it[3])) / 0.5, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		l.position = (it[1] as Vector2) + Vector2(0, -5.0 * S * (1.0 - e))
		l.modulate.a = float(it[2]) * clampf(k * 1.4, 0.0, 1.0)
		if k < 1.0:
			fertig = false
	if fertig:
		_entrance_active = false
		_entrance_items.clear()


# ------------------------------------------------------------------ Kulisse

## Nachthimmel + ferne Silhouette + Nebelband + Horizontglühen — der Backdrop
## der Web-Fassung mit `nurFerneSilhouette` (das Motiv steht davor).
func _draw_sky(c: CanvasItem) -> void:
	var top: Color = theme["sky_top"]
	var bot: Color = theme["sky_bottom"]
	var fog: Color = theme["fog"]
	Pen.vgradient(c, 0, 0, W, H, top, bot)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 80:
		var sx := rng.randf() * W
		var sy := rng.randf() * 170.0
		var a := 0.12 + rng.randf() * 0.4
		Pen.circle(c, sx, sy, 0.45 + rng.randf() * 0.6, Color(0.9, 0.94, 1.0, a))
	# fernes Himmelslicht: kühle Kuppel über dem Horizont
	Pen.ellipse(c, 320, 330, 1000, 300, Pen.alpha(fog, 0.10))
	# Fern-Silhouette: Türme in Dunstfarbe
	var sil := Pen.mix(bot, fog, 0.5)
	rng.seed = 11
	var x := -12.0
	while x < W + 20.0:
		var w := 22.0 + rng.randf() * 18.0
		var h := 40.0 + rng.randf() * 50.0
		Pen.rect(c, x, 320 - h, w, h + 4, sil)
		if rng.randf() < 0.35:
			Pen.rect(c, x + w * 0.5 - 0.6, 320 - h - 8, 1.2, 8, sil)
		for fy in range(int(320 - h + 6), 300, 9):
			for fx in range(int(x + 4), int(x + w - 4), 7):
				if (fx * 5 + fy * 11) % 9 < 2:
					Pen.rect(c, fx, fy, 2.4, 3.2, Pen.alpha(fog, 0.35))
		x += w + rng.randf() * 12.0
	# Nebelband zwischen Fern- und Nahzone
	Pen.vgradient(c, 0, 86, W, 68, Pen.alpha(fog, 0.0), Pen.alpha(fog, 0.34))
	Pen.vgradient(c, 0, 154, W, 70, Pen.alpha(fog, 0.34), Pen.alpha(fog, 0.0))
	# Horizontglühen: warmes Licht knapp über der Spielebene
	Pen.vgradient(c, 0, 236, W, 84, Pen.hex(0xffb070, 0.0), Pen.hex(0xffb070, 0.11))


func _motes() -> void:
	var m := CPUParticles2D.new()
	m.amount = 36
	m.lifetime = 9.0
	m.preprocess = 9.0
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.emission_rect_extents = Vector2(W * 0.5, H * 0.4)
	m.position = Vector2(W * 0.5, H * 0.45)
	m.direction = Vector2(0, -1)
	m.spread = 180.0
	m.gravity = Vector2.ZERO
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 4.0
	m.scale_amount_min = 0.5
	m.scale_amount_max = 1.1
	m.color = Color(1.0, 0.96, 0.88, 0.22)
	m.texture = Fx.radial_texture()
	m.scale_amount_min = 0.006
	m.scale_amount_max = 0.014
	stage.add_child(m)


func _draw_vignette(c: CanvasItem) -> void:
	var ww := W * S
	var hh := H * S
	var d := Color(0.0, 0.0, 0.0, 0.0)
	var k := Color(0.0, 0.0, 0.0, 0.34)
	var e := 150.0
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(ww, 0), Vector2(ww, e), Vector2(0, e)]), PackedColorArray([k, k, d, d]))
	c.draw_polygon(PackedVector2Array([Vector2(0, hh - e), Vector2(ww, hh - e), Vector2(ww, hh), Vector2(0, hh)]), PackedColorArray([d, d, k, k]))
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, hh), Vector2(0, hh)]), PackedColorArray([k, d, d, k]))
	c.draw_polygon(PackedVector2Array([Vector2(ww - e, 0), Vector2(ww, 0), Vector2(ww, hh), Vector2(ww - e, hh)]), PackedColorArray([d, k, k, d]))
