class_name Title
extends Vignette
## HAUPTMENÜ / ATTRACT — das Klinikum im Puppenhaus-Schnitt als lebendes Wimmelbild
## (Port von src/gfx/krankenhaus.ts + AttractScene.ts der Web-Fassung).
##
## Oben Medizin (OP, Stationen, Flur, Empfang), unten der Keller, in dem die TI
## wohnt (Konnektor → VAU → Fachdienst ePA); Datenpulse wandern vom
## Empfangs-Terminal hinunter. Alles Bewegte ist eine reine Funktion der Zeit.
## Paul und REZI stehen auf dem Apotheken-Dach und warten auf den Knopfdruck.
## Barrierefreiheit: kein Blinken über 3 Hz. Keine geschützten Symbole
## (weißes H auf Blau statt rotem Kreuz).

signal start_requested

signal lang_requested(code)

## Sprachflaggen oben rechts (Design-Raum): sechs Felder DE EN FR ES ZH HI —
## Klick oder Fingertipp wechselt die Sprache (F2 blättert), das Menü baut sich neu.
const FLAG_W := 14.0
const FLAG_H := 9.5
const FLAG_Y := 8.0
const FLAG_X0 := 524.0
const FLAG_STEP := 18.0
## Musik/Töne-Schalter oben links (F3 / F4)
const SND_X0 := 12.0
const SND_Y := 8.0
const SND_W := 30.0
const SND_H := 10.0
const SND_STEP := 34.0

const BODEN := 320.0
const HAUS := {"links": 84.0, "rechts": 484.0, "dach": 138.0}
const DECKEN := [138.0, 176.0, 214.0, 252.0, 316.0]
const SCHACHT := {"links": 450.0, "rechts": 476.0}
const KELLER := {"links": 96.0, "rechts": 472.0, "oben": 324.0, "unten": 352.0}
const FUSS := {"f3": 176.0, "f2": 214.0, "f1": 252.0, "eg": 316.0, "keller": 348.0, "strasse": 320.0}
const LEITUNG_A := [Vector2(309, 296), Vector2(309, 322), Vector2(160, 322), Vector2(160, 332), Vector2(128, 332)]
const LEITUNG_B := [Vector2(128, 340), Vector2(240, 340), Vector2(240, 344), Vector2(338, 344)]
const HALTE := [288.0, 224.0, 186.0, 148.0, 186.0, 224.0]
const WARTE := 2.2
const TEMPO := 34.0
const REZI_SPRUECHE := ["Drück den Knopf — los geht's!", "Ich bin REZI, dein e-Rezept.", "Unten im Keller wohnt die TI …", "Hülle an, Lauscher aus!"]

var _fahrplan: Array = []
var _fahrplan_dauer := 0.0
var sign_label: Label
var neon_label: Label
var press: Label
var player: Player
var rezi: Rezi
var _spruch := 0
var _next_spruch := 5.0
## Bedienungswahl: zwei Felder unten rechts (Tastatur/Arcade · Touch)
var mode := "keyboard"
var _pills: Array = []
var _legend: Array = []
var _lang_label: Label
var _snd_labels: Array = []
const PILL_KEYBOARD := Rect2(452, 316, 104, 14)
const PILL_TOUCH := Rect2(556, 316, 72, 14)
const PILL_BOX := Rect2(452, 316, 176, 14)   # Segment-Schalter: beide Felder in einem Rahmen
var _seg := 0.0                                # 0 = Tastatur, 1 = Touch (gleitet beim Wechsel)


func _init() -> void:
	sperre = 0.6
	weiter_text = ""
	entrance = false     # das Menü hat seine eigene Choreografie, Kopfzeilen sofort da


func _build() -> void:
	done.connect(func(): start_requested.emit())
	# Aufzugsplan: hoch und wieder runter, mit Wartezeit an jedem Halt
	var zeit := 0.0
	for i in HALTE.size():
		var von: float = HALTE[i]
		var nach: float = HALTE[(i + 1) % HALTE.size()]
		zeit += WARTE
		var dauer := absf(nach - von) / TEMPO
		_fahrplan.append([zeit, zeit + dauer, von, nach])
		zeit += dauer
	_fahrplan_dauer = zeit

	# ---- Schriften der Kulisse (Wortmarken als Easter Eggs) ----
	sign_label = label(140, 123, "gematik", 9, {"spacing": 0.4})
	label(140, 133, "KLINIKUM", 4.6, {"color": Pen.hex(0x9fc4e8), "spacing": 1.3, "bold": false})
	label(121, 259, "NOTAUFNAHME", 4.6, {"color": Pen.hex(0xffb367), "spacing": 0.7})
	label(406, 280.5, "Kein Notfall?", 3.6, {"color": Pen.hex(0xb8c6e0), "bold": false})
	label(406, 285.5, "116 117", 4.6, {"color": Pen.hex(0xffd75e)})
	label(237, 288, "E-REZEPT", 3.8, {"color": Pen.hex(0x4de3ff), "bold": false})
	label(328, 150, "KIM", 5, {"color": Pen.hex(0x8fd6c8), "spacing": 0.8})
	label(100, 147.5, "OP 1", 4.2, {"color": Pen.hex(0x9fb0cc), "bold": false})
	label(434, 221, "TIM", 4.4, {"color": Pen.hex(0x8fd6c8), "spacing": 0.6})
	label(245, 330, "VAU", 6.5, {"color": Pen.hex(0x4de3ff), "spacing": 1.0})
	label(118, 345.5, "KONNEKTOR", 4, {"color": Pen.hex(0x9fb0cc), "spacing": 0.5, "bold": false})
	label(345, 326.5, "FACHDIENST ePA", 4, {"color": Pen.hex(0x9fb0cc), "spacing": 0.3, "bold": false})
	label(570, 267, "APOTHEKE", 5.5, {"color": Pen.hex(0xffd75e), "spacing": 1.2})
	neon_label = label(564, 304, "E-REZEPT", 4.4, {"color": Pen.hex(0x4de3ff), "spacing": 0.5})

	# ---- Titel, Subline, Start-Zeile ----
	var cfg: Dictionary = Game.config.get("titleScreen", {})
	label(W / 2, 52, "PAUL & REZI", 8, {"color": Pen.hex(0xffd591), "spacing": 2.4, "stroke": Pen.hex(0x0a1730), "stroke_w": 1.0})
	label(W / 2, 76, Game.t(cfg.get("headline", {"de": "Das e-Rezept"})), 36, {"serif": true, "stroke": Pen.hex(0x0a1730), "stroke_w": 1.6, "spacing": 0.6})
	label(W / 2, 101, Game.t(cfg.get("subline", {"de": "Spiele dich durch die TI und erhalte dein e-Rezept!"})), 11.5, {"color": Pen.hex(0xcfe0ff), "bold": false, "stroke": Pen.hex(0x0a1730), "stroke_w": 1.0})
	press = label(W - 12, 340, "", 12, {"color": Pen.hex(0xffd591), "spacing": 0.5, "origin": Vector2(1, 0.5), "stroke": Pen.hex(0x0a1730), "stroke_w": 1.0})

	# ---- Bedienungswahl: zwei Felder über der Start-Zeile ----
	_pills = [
		{"mode": "keyboard", "rect": PILL_KEYBOARD, "label": label(PILL_KEYBOARD.position.x + 19, 323, "TASTATUR · ARCADE", 4.4, {"spacing": 0.5, "origin": Vector2(0, 0.5)})},
		{"mode": "touch", "rect": PILL_TOUCH, "label": label(PILL_TOUCH.position.x + 19, 323, "TOUCH", 4.4, {"spacing": 0.5, "origin": Vector2(0, 0.5)})},
	]
	label(PILL_BOX.end.x, 309.5, "BEDIENUNG · ◀ ▶ WECHSELN", 3.6, {"color": Pen.hex(0xffd591), "spacing": 1.2, "origin": Vector2(1, 0.5)})
	mode = Kiosk.suggested_input_mode()
	_seg = 1.0 if mode == "touch" else 0.0
	_lang_label = label(FLAG_X0 + 6 * FLAG_STEP - 4.0, 23.5, str(Game.LANG_NAMES.get(Game.lang, "Deutsch")), 3.8,
		{"color": Pen.hex(0xdfe6f0), "spacing": 0.3, "origin": Vector2(1, 0.5)})
	_snd_labels = [
		label(SND_X0 + 13.0, SND_Y + SND_H / 2, "MUSIK", 3.6, {"spacing": 0.5, "origin": Vector2(0, 0.5)}),
		label(SND_X0 + SND_STEP + 13.0, SND_Y + SND_H / 2, "TÖNE", 3.6, {"spacing": 0.5, "origin": Vector2(0, 0.5)}),
	]

	# ---- Tafel links: Veranstaltung, Steuerung, Rechtshinweis ----
	label(9, 290, str(Game.config.get("event", "Messe-Prototyp")), 4.4, {"color": Pen.hex(0xffd75e), "spacing": 0.4, "origin": Vector2(0, 0.5)})
	for i in 4:
		var y := 301.0 + i * 8.6
		_legend.append([
			label(9, y, "", 4.0, {"color": Pen.hex(0xdfe6f0), "spacing": 0.3, "origin": Vector2(0, 0.5)}),
			label(9, y + 4.2, "", 3.4, {"color": Pen.hex(0x9fb0cc), "bold": false, "origin": Vector2(0, 0.5)}),
		])
	_apply_mode()
	var disc := Game.t(Game.config.get("disclaimer", {"de": "Inoffizielles Lernspiel — kein Produkt der gematik."}))
	var teile: Array = []
	for teil in disc.replace(". ", ".|").replace(" — ", "|").split("|"):
		if teil.strip_edges() != "":
			teile.append(teil.strip_edges())
	for i in mini(3, teile.size()):
		label(9, 342 + i * 4.8, str(teile[i]), 3.3, {"color": Pen.hex(0x8fa2c4), "bold": false, "origin": Vector2(0, 0.5)})

	# ---- Tages-Bestenliste rechts oben (im Himmel, neben der Antenne) ----
	var hs := Game.highscores()
	if not hs.is_empty():
		label(570, 152, "TAGES-BESTENLISTE", 4.6, {"color": Pen.hex(0xffd75e), "spacing": 1.0})
		for i in mini(5, hs.size()):
			var e: Dictionary = hs[i]
			var txt := "%d.  %s   %d P" % [i + 1, Reward.AVATARS[int(e.get("avatar", 0)) % Reward.AVATARS.size()], int(e.get("score", 0))]
			label(570, 162 + i * 8, txt, 4.6, {"color": Pen.hex(0xdfe6f0), "bold": i == 0})

	# ---- Paul & REZI auf dem Apotheken-Dach ----
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(92 * S, 120)
	cs.shape = shape
	cs.position = Vector2(570 * S, 262 * S + 60)
	floor_body.add_child(cs)
	add_child(floor_body)
	player = Player.new()
	player.global_position = Vector2(598 * S, 262 * S)
	player.controls_locked = true
	player.facing = -1
	add_child(player)
	if player.visual:
		player.visual.light_mask = 9
	rezi = Rezi.new()
	add_child(rezi)
	rezi.follow(player)
	rezi.base_energy = 0.5
	rezi.light.range_item_cull_mask = 8


## Texte der Start-Zeile und der Steuerungstafel zur gewählten Bedienung.
func _apply_mode() -> void:
	var zeilen: Array = []
	var start := ""
	var cfg: Dictionary = Game.config.get("titleScreen", {})
	if mode == "touch":
		zeilen = [[tr("KNÜPPEL"), tr("laufen & ducken")], [tr("SPRUNG"), tr("springen · 2× REZI-Schub")], [tr("AKTION"), tr("TI-Aktion")], [tr("HÜLLE"), tr("Hülle an / aus")]]
		start = tr("Tippe auf TOUCH zum Start!")
	elif Kiosk.has_gamepad():
		zeilen = [[tr("JOYSTICK"), tr("laufen & ducken")], [tr("ROT"), tr("springen · 2× REZI-Schub")], [tr("BLAU"), tr("TI-Aktion")], [tr("HOCH"), tr("Hülle an / aus")]]
		start = Game.t(cfg.get("pressStart", {"de": "Drück den roten Knopf!"}))
	else:
		zeilen = [[tr("PFEILE / WASD"), tr("laufen & ducken")], [tr("LEERTASTE"), tr("springen · 2× REZI-Schub")], ["E", tr("TI-Aktion")], ["SHIFT", tr("Hülle an / aus")]]
		start = Game.t(cfg.get("pressStartKeyboard", {"de": "Drück LEERTASTE!"}))
	for i in _legend.size():
		_relabel(_legend[i][0], str(zeilen[i][0]))
		_relabel(_legend[i][1], str(zeilen[i][1]))
	_relabel(press, start, Vector2(1, 0.5), Vector2(W - 12, 340))
	for p in _pills:
		var l: Label = p["label"]
		l.modulate.a = 1.0 if p["mode"] == mode else 0.62


## Label-Text ändern und die Ausrichtung im Design-Raum erhalten.
func _relabel(l: Label, text: String, origin := Vector2(0, 0.5), at := Vector2.INF) -> void:
	var anchor := at
	if anchor == Vector2.INF:
		anchor = (l.position + l.size * origin) / S
	l.text = text
	l.reset_size()
	l.position = (anchor * S - l.size * origin).round()


func _select(m: String) -> void:
	if m == mode:
		return
	mode = m
	Sfx.play("tick")
	_apply_mode()


func _start_with(m: String) -> void:
	mode = m
	Kiosk.set_input_mode(m)
	_apply_mode()
	_advance()


func _pill_at(screen_pos: Vector2) -> String:
	var d := screen_pos / S
	for p in _pills:
		if (p["rect"] as Rect2).grow(3.0).has_point(d):
			return str(p["mode"])
	return ""


## Auswahl: Links/Rechts wechselt, Tipp auf ein Feld startet damit, Taste/Knopf startet
## mit der markierten Bedienung. Ein Fingertipp irgendwo sonst startet mit Touch.
func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	# F2 blättert durch die Sprachen, F3 Musik, F4 Töne (Tastatur/Arcade ohne Maus)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F2:
			_cycle_lang()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_F3:
			_toggle_sound("musik")
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_F4:
			_toggle_sound("toene")
			get_viewport().set_input_as_handled()
			return
	# Links = Tastatur/Arcade (linkes Feld), Rechts = Touch (rechtes Feld); kein Umschalt-Flackern bei Analog-Stick
	if event.is_action_pressed("move_left"):
		_select("keyboard")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_right"):
		_select("touch")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		return
	if event is InputEventScreenTouch and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		var flag := _flag_at(event.position)
		if flag != "":
			_choose_lang(flag)
			return
		var snd := _snd_at(event.position)
		if snd != "":
			_toggle_sound(snd)
			return
		var hit := _pill_at(event.position)
		_start_with(hit if hit != "" else "touch")
		return
	if event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		var flag_m := _flag_at(event.position)
		if flag_m != "":
			_choose_lang(flag_m)
			return
		var snd_m := _snd_at(event.position)
		if snd_m != "":
			_toggle_sound(snd_m)
			return
		var hit := _pill_at(event.position)
		if hit != "":
			_start_with(hit)
		return
	if not is_press(event) or tz < sperre:
		return
	_start_with(mode)


# ------------------------------------------------------------- Musik & Töne

func _snd_rect(i: int) -> Rect2:
	return Rect2(SND_X0 + i * SND_STEP, SND_Y, SND_W, SND_H)


func _snd_at(screen_pos: Vector2) -> String:
	var d := screen_pos / S
	if _snd_rect(0).grow(3.0).has_point(d):
		return "musik"
	if _snd_rect(1).grow(3.0).has_point(d):
		return "toene"
	return ""


func _toggle_sound(which: String) -> void:
	if which == "musik":
		Sfx.set_music(not Sfx.music_on)
	else:
		Sfx.set_sound(not Sfx.sound_on)
	Sfx.play("tick")
	_sync_sound_labels()


func _sync_sound_labels() -> void:
	if _snd_labels.size() == 2:
		(_snd_labels[0] as Label).modulate.a = 1.0 if Sfx.music_on else 0.45
		(_snd_labels[1] as Label).modulate.a = 1.0 if Sfx.sound_on else 0.45


## Zwei Pillen: Note (Musik) und Lautsprecher (Töne); aus = matt mit rotem Strich.
func _draw_sound(c: CanvasItem) -> void:
	_sync_sound_labels()
	for i in 2:
		var r := _snd_rect(i)
		var an: bool = Sfx.music_on if i == 0 else Sfx.sound_on
		Pen.rrect(c, r.position.x, r.position.y, r.size.x, r.size.y, 3, Color(0.176, 0.176, 0.176, 0.9 if an else 0.65))
		Pen.srrect(c, r.position.x, r.position.y, r.size.x, r.size.y, 3, Brand.UI_ACCENT if an else Color(1, 1, 1, 0.18), 1.0 if an else 0.7)
		var ix := r.position.x + 6.5
		var iy := r.position.y + r.size.y / 2
		var ic := Brand.UI_ACCENT if an else Pen.hex(0xdfe6f0, 0.6)
		if i == 0:
			Pen.circle(c, ix - 1.2, iy + 2.0, 1.5, ic)
			Pen.rect(c, ix + 0.1, iy - 3.4, 0.8, 5.4, ic)
			Pen.tri(c, ix + 0.1, iy - 3.4, ix + 3.2, iy - 2.2, ix + 0.1, iy - 1.6, ic)
		else:
			Pen.rect(c, ix - 3.2, iy - 1.3, 2.0, 2.6, ic)
			Pen.tri(c, ix - 1.2, iy - 1.3, ix + 1.0, iy - 3.2, ix + 1.0, iy + 3.2, ic)
			Pen.tri(c, ix - 1.2, iy + 1.3, ix + 1.0, iy + 3.2, ix - 1.2, iy - 1.3, ic)
			Pen.arc(c, ix + 1.0, iy, 2.6, -0.9, 0.9, ic, 0.6)
			Pen.arc(c, ix + 1.0, iy, 4.0, -0.8, 0.8, Pen.alpha(ic, 0.7), 0.6)
		if not an:
			Pen.line(c, ix - 4.0, iy + 4.0, ix + 5.0, iy - 4.0, Pen.DENY_COL, 1.0)


# ------------------------------------------------------------------ Sprachen

func _flag_rect(i: int) -> Rect2:
	return Rect2(FLAG_X0 + i * FLAG_STEP, FLAG_Y, FLAG_W, FLAG_H)


func _flag_at(screen_pos: Vector2) -> String:
	var d := screen_pos / S
	for i in Game.LANGS.size():
		if _flag_rect(i).grow(3.0).has_point(d):
			return str(Game.LANGS[i])
	return ""


func _choose_lang(code: String) -> void:
	if code == Game.lang:
		return
	Sfx.play("tick")
	lang_requested.emit(code)


func _cycle_lang() -> void:
	var i: int = Game.LANGS.find(Game.lang)
	_choose_lang(str(Game.LANGS[(i + 1) % Game.LANGS.size()]))


## Sechs Flaggen aus Grundformen; die gewählte hell mit Akzentrand und Marker.
func _draw_flags(c: CanvasItem) -> void:
	for i in Game.LANGS.size():
		var code := str(Game.LANGS[i])
		var r := _flag_rect(i)
		var an := code == Game.lang
		var a := 1.0 if an else 0.62
		Pen.rect(c, r.position.x + 0.8, r.position.y + 1.2, r.size.x, r.size.y, Color(0, 0, 0, 0.35 * a))
		_flag(c, code, r, a)
		if an:
			Pen.srect(c, r.position.x - 0.8, r.position.y - 0.8, r.size.x + 1.6, r.size.y + 1.6, Brand.UI_ACCENT, 1.0)
			Pen.tri(c, r.position.x + r.size.x / 2 - 2.2, r.end.y + 4.4, r.position.x + r.size.x / 2 + 2.2, r.end.y + 4.4, r.position.x + r.size.x / 2, r.end.y + 1.8, Brand.UI_ACCENT)
		else:
			Pen.srect(c, r.position.x, r.position.y, r.size.x, r.size.y, Color(1, 1, 1, 0.25), 0.5)


func _flag(c: CanvasItem, code: String, r: Rect2, a: float) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	match code:
		"de":
			Pen.rect(c, x, y, w, h / 3, Color(0.05, 0.05, 0.05, a))
			Pen.rect(c, x, y + h / 3, w, h / 3, Color(0.86, 0.09, 0.09, a))
			Pen.rect(c, x, y + 2 * h / 3, w, h / 3, Color(1.0, 0.80, 0.0, a))
		"en":
			Pen.rect(c, x, y, w, h, Color(0.0, 0.14, 0.49, a))
			Pen.line(c, x, y, x + w, y + h, Color(1, 1, 1, a), 1.8)
			Pen.line(c, x + w, y, x, y + h, Color(1, 1, 1, a), 1.8)
			Pen.line(c, x, y, x + w, y + h, Color(0.78, 0.06, 0.18, a), 0.7)
			Pen.line(c, x + w, y, x, y + h, Color(0.78, 0.06, 0.18, a), 0.7)
			Pen.rect(c, x + w / 2 - 1.5, y, 3.0, h, Color(1, 1, 1, a))
			Pen.rect(c, x, y + h / 2 - 1.5, w, 3.0, Color(1, 1, 1, a))
			Pen.rect(c, x + w / 2 - 0.9, y, 1.8, h, Color(0.78, 0.06, 0.18, a))
			Pen.rect(c, x, y + h / 2 - 0.9, w, 1.8, Color(0.78, 0.06, 0.18, a))
		"fr":
			Pen.rect(c, x, y, w / 3, h, Color(0.0, 0.14, 0.58, a))
			Pen.rect(c, x + w / 3, y, w / 3, h, Color(1, 1, 1, a))
			Pen.rect(c, x + 2 * w / 3, y, w / 3, h, Color(0.93, 0.16, 0.22, a))
		"es":
			Pen.rect(c, x, y, w, h, Color(0.98, 0.76, 0.05, a))
			Pen.rect(c, x, y, w, h / 4, Color(0.77, 0.07, 0.11, a))
			Pen.rect(c, x, y + 3 * h / 4, w, h / 4, Color(0.77, 0.07, 0.11, a))
		"zh":
			Pen.rect(c, x, y, w, h, Color(0.87, 0.16, 0.06, a))
			_star(c, x + 2.6, y + 2.7, 1.7, Color(1.0, 0.87, 0.0, a))
			for p in [Vector2(5.4, 0.9), Vector2(6.4, 2.1), Vector2(6.4, 3.6), Vector2(5.4, 4.7)]:
				_star(c, x + p.x, y + p.y, 0.55, Color(1.0, 0.87, 0.0, a))
		"hi":
			Pen.rect(c, x, y, w, h / 3, Color(1.0, 0.60, 0.20, a))
			Pen.rect(c, x, y + h / 3, w, h / 3, Color(1, 1, 1, a))
			Pen.rect(c, x, y + 2 * h / 3, w, h / 3, Color(0.07, 0.53, 0.03, a))
			Pen.scircle(c, x + w / 2, y + h / 2, 1.35, Color(0.0, 0.2, 0.5, a), 0.5)
			Pen.circle(c, x + w / 2, y + h / 2, 0.35, Color(0.0, 0.2, 0.5, a))


static func _star(c: CanvasItem, cx: float, cy: float, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang := -PI / 2 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.42
		pts.append(Vector2(cx + cos(ang) * rr, cy + sin(ang) * rr))
	c.draw_colored_polygon(pts, col)


## Segment-Schalter der Bedienungswahl: ein dunkler Rahmen, das gewählte Feld füllt
## sich orange (PwC-Akzent) mit weißer Schrift und gleitet beim Wechsel; Symbole:
## Tastenreihe mit Leertaste, Fingertipp mit Wellen.
func _draw_pills(c: CanvasItem) -> void:
	var b := PILL_BOX
	Pen.rrect(c, b.position.x + 0.6, b.position.y + 1.0, b.size.x, b.size.y, 4, Color(0, 0, 0, 0.35))
	Pen.rrect(c, b.position.x, b.position.y, b.size.x, b.size.y, 4, Color(0.05, 0.07, 0.12, 0.92))
	Pen.srrect(c, b.position.x, b.position.y, b.size.x, b.size.y, 4, Color(1, 1, 1, 0.16), 0.7)
	# gleitende Füllung
	var sx := lerpf(PILL_KEYBOARD.position.x, PILL_TOUCH.position.x, _seg)
	var sw := lerpf(PILL_KEYBOARD.size.x, PILL_TOUCH.size.x, _seg)
	Pen.rrect(c, sx + 1.2, b.position.y + 1.2, sw - 2.4, b.size.y - 2.4, 3, Brand.UI_ACCENT)
	Pen.rect(c, sx + 4, b.position.y + 1.9, sw - 8, 0.6, Color(1, 1, 1, 0.28))
	Pen.rect(c, sx + 4, b.end.y - 2.3, sw - 8, 0.6, Color(0, 0, 0, 0.18))
	# feine Trennlinie zwischen den Feldern (nur sichtbar, wo keine Füllung liegt)
	Pen.rect(c, PILL_TOUCH.position.x - 0.3, b.position.y + 3, 0.6, b.size.y - 6, Color(1, 1, 1, 0.10))
	for p in _pills:
		var r: Rect2 = p["rect"]
		var an: bool = p["mode"] == mode
		var ix := r.position.x + 10.0
		var iy := r.position.y + r.size.y / 2
		var ic := Color(1, 1, 1, 0.96) if an else Pen.hex(0xdfe6f0, 0.62)
		if p["mode"] == "keyboard":
			for k in 3:
				Pen.rrect(c, ix - 5.4 + k * 3.6, iy - 3.6, 2.8, 2.6, 0.5, ic)
			for k in 3:
				Pen.rrect(c, ix - 4.6 + k * 3.6, iy - 0.6, 2.8, 2.0, 0.5, Pen.alpha(ic, 0.8))
			Pen.rrect(c, ix - 4.2, iy + 1.9, 8.4, 1.6, 0.5, ic)
		else:
			# Fingerkuppe und Tipp-Wellen
			Pen.rrect(c, ix - 1.4, iy - 1.2, 2.8, 5.6, 1.4, ic)
			Pen.circle(c, ix, iy - 1.6, 1.5, ic)
			Pen.arc(c, ix, iy - 1.6, 3.4, -2.5, -0.65, Pen.alpha(ic, 0.9), 0.6)
			Pen.arc(c, ix, iy - 1.6, 5.0, -2.35, -0.8, Pen.alpha(ic, 0.55), 0.6)


func _tick(delta: float) -> void:
	# Segment-Schalter gleitet zum gewählten Feld
	_seg = lerpf(_seg, 1.0 if mode == "touch" else 0.0, 1.0 - exp(-14.0 * delta))
	# Start-Zeile: 750-ms-Yoyo (deutlich unter 3 Hz)
	press.modulate.a = 0.62 + 0.38 * sin(t * 4.19)
	# Neon: das E-REZEPT der Apotheke atmet, das gematik-Schild zuckt selten
	neon_label.modulate.a = 0.675 + 0.325 * sin(t * 4.19)
	sign_label.modulate.a = 0.55 if fmod(t, 2.75) < 0.15 else 1.0
	if fmod(t, 6.0) < 0.05 and player:
		player.facing = -player.facing
		rezi.happy()
	if tz > _next_spruch and rezi:
		rezi.say(tr(REZI_SPRUECHE[_spruch % REZI_SPRUECHE.size()]), 3.2)
		_spruch += 1
		_next_spruch = tz + 9.0


func _aufzug_y(tt: float) -> float:
	var u := fmod(tt, _fahrplan_dauer)
	var y: float = HALTE[0]
	for f in _fahrplan:
		if u >= f[1]:
			y = f[3]
		elif u >= f[0]:
			var k: float = (u - f[0]) / (f[1] - f[0])
			return f[2] + (f[3] - f[2]) * (0.5 - cos(k * PI) / 2.0)
	return y


# ------------------------------------------------------------------ Statik

func _tree(c: CanvasItem, tx: float, s: float, laub: Color) -> void:
	Pen.rect(c, tx - 1, BODEN - 10 * s, 2, 10 * s, Pen.hex(0x3a2f28))
	Pen.rect(c, tx - 6 * s, BODEN - 20 * s, 12 * s, 9 * s, laub)
	Pen.rect(c, tx - 4 * s, BODEN - 24 * s, 8 * s, 6 * s, laub)
	Pen.rect(c, tx - 6 * s, BODEN - 20 * s, 12 * s, 1, Color(1, 1, 1, 0.06))


func _draw_static(c: CanvasItem) -> void:
	var fog: Color = theme["fog"]
	var accent: Color = theme["accent"]
	var detail: Color = theme["detail"]
	var sky_top: Color = theme["sky_top"]
	var sky_bottom: Color = theme["sky_bottom"]
	var wand := Pen.darken(sky_top, 0.35)
	var raum := Pen.darken(sky_bottom, 0.62)
	var raum_hell := Pen.darken(sky_bottom, 0.52)
	var fenster_hell := Pen.mix(sky_bottom, fog, 0.55)
	var strasse := Pen.darken(theme["ground"], 0.45)
	var gehweg := Pen.darken(theme["ground_top"], 0.3)
	var K := Pen.K

	# ---- Straße & Gehweg ----
	Pen.rect(c, 0, BODEN - 2, W, 8, gehweg)
	Pen.rect(c, 0, BODEN - 2, W, 0.8, Color(1, 1, 1, 0.08))
	Pen.rect(c, 0, BODEN + 6, W, 40, strasse)
	var sx := 4.0
	while sx < W:
		Pen.rect(c, sx, 339, 7, 1.2, Pen.alpha(detail, 0.35))
		sx += 16.0
	for i in 4:
		Pen.rect(c, 190, 328 + i * 6, 34, 3, Color(1, 1, 1, 0.26 - i * 0.04))
	Pen.ellipse(c, 368, 333, 7, 2.6, Pen.hex(0x1a2333, 0.9))
	Pen.sellipse(c, 368, 333, 7, 2.6, Pen.alpha(detail, 0.4), 0.5)

	# ---- Park: Baum, Bank mit Leser ----
	var laub := Pen.mix(Pen.html("#3a6a55"), fog, 0.25)
	_tree(c, 491, 0.9, laub)
	Pen.rect(c, 502, 312, 1.6, 8, Pen.hex(0x3a4358))
	Pen.rect(c, 517, 312, 1.6, 8, Pen.hex(0x3a4358))
	Pen.rect(c, 500, 311, 21, 1.8, Pen.hex(0x6b5a3f))
	Pen.rect(c, 500, 305, 21, 1.4, Pen.hex(0x6b5a3f))
	Pen.sitzend(c, 509, 310, Pen.P_BESUCH)
	Pen.rect(c, 511.5, 302, 4, 3, Pen.hex(0xe9eef8, 0.9))

	# ---- Hauptgebäude: Hülle, Geschossdecken, Aufzugsschacht ----
	Pen.rect(c, HAUS.links, HAUS.dach, HAUS.rechts - HAUS.links, BODEN - HAUS.dach, wand)
	for i in DECKEN.size() - 1:
		Pen.rect(c, 90, DECKEN[i] + 4, SCHACHT.links - 90, DECKEN[i + 1] - DECKEN[i] - 4, raum if i % 2 == 0 else raum_hell)
	for y in DECKEN:
		Pen.rect(c, HAUS.links - 2, y, HAUS.rechts - HAUS.links + 4, 4, Pen.alpha(detail, 0.85))
		Pen.rect(c, HAUS.links - 2, y, HAUS.rechts - HAUS.links + 4, 0.7, Color(1, 1, 1, 0.14))
	Pen.rect(c, HAUS.links, HAUS.dach, 6, BODEN - HAUS.dach, Pen.darken(sky_top, 0.5))
	Pen.rect(c, HAUS.rechts - 8, HAUS.dach, 8, BODEN - HAUS.dach, Pen.darken(sky_top, 0.5))
	Pen.rect(c, SCHACHT.links - 2, 142, SCHACHT.rechts - SCHACHT.links + 4, 316 - 142, Pen.darken(sky_top, 0.55))
	Pen.rect(c, SCHACHT.links, 142, SCHACHT.rechts - SCHACHT.links, 316 - 142, Pen.hex(0x0b1322))
	Pen.rect(c, SCHACHT.links - 2, 122, SCHACHT.rechts - SCHACHT.links + 4, 16, wand)
	Pen.rect(c, SCHACHT.links - 2, 122, SCHACHT.rechts - SCHACHT.links + 4, 1.5, Pen.alpha(detail, 0.8))
	Pen.rect(c, SCHACHT.links + 6, 126, 9, 12, Pen.hex(0x0e1a2c))
	Pen.circle(c, SCHACHT.links + 13, 132, 0.7, Pen.alpha(accent, 0.7))

	# ---- Dach: Brüstung, Schild, Lüftung, Helipad, Antenne ----
	Pen.rect(c, HAUS.links - 2, HAUS.dach - 2, HAUS.rechts - HAUS.links + 4, 2, Pen.alpha(detail, 0.9))
	Pen.rect(c, 104, 116, 72, 22, Pen.hex(0x0d2440, 0.96))
	Pen.srect(c, 104, 116, 72, 22, Pen.alpha(detail, 0.8), 1.0)
	Pen.rect(c, 112, 129.5, 56, 1, Pen.alpha(K, 0.8))
	Pen.rect(c, 246, 130, 14, 8, Pen.hex(0x39445e))
	Pen.rect(c, 249, 126, 3, 4, Pen.hex(0x39445e))
	Pen.rect(c, 255, 126, 3, 4, Pen.hex(0x39445e))
	Pen.rect(c, 384, 132, 4, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, 448, 132, 4, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, 378, 128, 82, 4, Pen.hex(0x1c2536))
	Pen.sellipse(c, 419, 130, 26, 2.6, Pen.hex(0xd8e0f0, 0.75), 1.2)
	Pen.rect(c, 415, 128.6, 1.6, 2.8, Pen.hex(0xd8e0f0, 0.85))
	Pen.rect(c, 421.4, 128.6, 1.6, 2.8, Pen.hex(0xd8e0f0, 0.85))
	Pen.rect(c, 415, 129.6, 8, 0.9, Pen.hex(0xd8e0f0, 0.85))
	Pen.rect(c, 466, 96, 1.8, 42, Pen.hex(0x39445e))
	Pen.rect(c, 462, 104, 10, 1.2, Pen.hex(0x39445e))
	Pen.rect(c, 463.5, 112, 7, 1.2, Pen.hex(0x39445e))
	Pen.ellipse(c, 463, 106, 4, 3, Pen.alpha(detail, 0.9))

	# ================================================================ 2. OG
	for tx in [190.0, 282.0, 372.0]:
		Pen.rect(c, tx, 142, 2, 34, Pen.darken(sky_top, 0.45))
	# OP: Lampe, Tisch, Geräteturm
	Pen.rect(c, 137, 142, 1.4, 6, Pen.hex(0x39445e))
	Pen.rect(c, 132, 148, 11, 2.6, Pen.hex(0xe9eef8, 0.95))
	Pen.tri(c, 137.5, 151, 122, 168, 154, 168, Color(1, 1, 1, 0.06))
	Pen.rect(c, 120, 168, 40, 2.4, Pen.hex(0x2f3a52))
	Pen.rect(c, 126, 170, 3, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, 150, 170, 3, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, 104, 166, 9, 2, Pen.hex(0x39445e))
	Pen.rect(c, 107, 168, 1.4, 8, Pen.hex(0x39445e))
	Pen.rect(c, 105, 164.5, 2.5, 1.2, Pen.hex(0xd8e0f0, 0.9))
	Pen.rect(c, 109, 164.5, 3.5, 1.2, Pen.hex(0xd8e0f0, 0.9))
	# Labor
	Pen.rect(c, 196, 164, 78, 2.4, Pen.hex(0x2f3a52))
	Pen.rect(c, 200, 166.4, 2.4, 9.6, Pen.hex(0x2f3a52))
	Pen.rect(c, 266, 166.4, 2.4, 9.6, Pen.hex(0x2f3a52))
	Pen.rect(c, 198, 150, 44, 1.6, Pen.alpha(detail, 0.6))
	var kolben := [0x7fd07f, 0x4de3ff, 0xffd75e, 0x7fd07f, 0x9a7ae8]
	for i in 5:
		Pen.rect(c, 202 + i * 8, 146.5, 3, 3.5, Pen.hex(kolben[i], 0.85))
	Pen.tri(c, 226, 164, 233, 164, 229.5, 157, Pen.hex(0x7fd07f, 0.9))
	Pen.rect(c, 244, 158, 3, 6, Pen.hex(0x4de3ff, 0.9))
	# KIM-Büro
	Pen.rect(c, 292, 166, 34, 2.4, Pen.hex(0x2f3a52))
	Pen.rect(c, 296, 168.4, 2.4, 7.6, Pen.hex(0x2f3a52))
	Pen.rect(c, 318, 168.4, 2.4, 7.6, Pen.hex(0x2f3a52))
	Pen.rect(c, 297, 157, 9, 7, Pen.hex(0x0a1220))
	Pen.srect(c, 297, 157, 9, 7, Pen.hex(0x39445e), 0.6)
	Pen.rect(c, 338, 150, 16, 10, Pen.alpha(detail, 0.5))
	Pen.rect(c, 340, 152, 4, 3, Pen.hex(0xffd75e, 0.7))
	Pen.rect(c, 347, 154, 4, 3, Pen.hex(0x7fd07f, 0.7))
	# Röntgen
	Pen.rect(c, 380, 146, 36, 24, Pen.hex(0x0a1626))
	Pen.srect(c, 380, 146, 36, 24, Pen.hex(0x39445e), 0.8)
	Pen.line(c, 398, 149, 398, 167, Pen.hex(0xcfe4ff, 0.75), 0.8)
	for i in 5:
		Pen.sellipse(c, 398, 152 + i * 3.2, 10 - i * 0.8, 2, Pen.hex(0xcfe4ff, 0.6), 0.6)
	var kn := Pen.hex(0xe9eef8, 0.9)
	Pen.rect(c, 438, 148, 3.4, 3.4, kn)
	Pen.rect(c, 439.2, 151.4, 1, 8, kn)
	for i in 3:
		Pen.rect(c, 436.6, 153 + i * 2.2, 6.2, 0.9, kn)
	Pen.rect(c, 437, 161, 5.4, 1.4, kn)
	Pen.rect(c, 437.4, 162.4, 1.2, 8, kn)
	Pen.rect(c, 440.8, 162.4, 1.2, 8, kn)
	Pen.rect(c, 438, 170.5, 1.4, 5.5, kn)
	Pen.rect(c, 440.4, 170.5, 1.4, 5.5, kn)

	# ================================================================ 1. OG
	for tx in [190.0, 288.0, 386.0]:
		Pen.rect(c, tx, 180, 2, 34, Pen.darken(sky_top, 0.45))
	for fx in [112.0, 160.0, 226.0, 258.0, 318.0, 356.0]:
		Pen.rect(c, fx, 184, 6, 8, Pen.alpha(fenster_hell, 0.85))
		Pen.rect(c, fx, 184, 6, 0.8, Color(1, 1, 1, 0.12))
	Pen.rect(c, 98, 192, 1.2, 22, Pen.hex(0x39445e))
	Pen.rect(c, 95, 192, 7, 1.2, Pen.hex(0x39445e))
	Pen.rect(c, 94.5, 193, 3, 4.4, Pen.hex(0xffd75e, 0.85))
	Pen.rect(c, 262, 186, 14, 8, Pen.hex(0x0a1220))
	Pen.srect(c, 262, 186, 14, 8, Pen.hex(0x39445e), 0.6)
	Pen.rect(c, 240, 200, 12, 14, Pen.hex(0x2f3a52))
	Pen.rect(c, 240, 206.5, 12, 0.8, Pen.alpha(detail, 0.5))
	Pen.scircle(c, 348, 209, 4.4, Pen.hex(0x8fa2c4, 0.9), 0.9)
	Pen.scircle(c, 354.5, 211.5, 1.8, Pen.hex(0x8fa2c4, 0.9), 0.9)
	Pen.rect(c, 344, 200, 7, 2, Pen.hex(0x2f3a52))
	Pen.rect(c, 343, 196, 1.6, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, 370, 204, 5, 6, Pen.hex(0x3a6a55))
	Pen.rect(c, 369, 199, 7, 5, Pen.hex(0x7fd07f, 0.8))
	Pen.rect(c, 392, 202, 30, 2.4, Pen.hex(0x2f3a52))
	Pen.rect(c, 394, 204.4, 2.4, 9.6, Pen.hex(0x2f3a52))
	Pen.rect(c, 416, 204.4, 2.4, 9.6, Pen.hex(0x2f3a52))
	Pen.rect(c, 428, 196, 10, 12, Pen.hex(0x39445e))
	Pen.rect(c, 430.5, 205.5, 3, 2, Pen.hex(0xd8e0f0, 0.85))

	# ================================================================ EG-Flur
	for tx in [120.0, 168.0, 216.0, 264.0, 312.0]:
		Pen.rect(c, tx, 226, 10, 26, Pen.darken(sky_bottom, 0.72))
		Pen.circle(c, tx + 8, 240, 0.7, Pen.alpha(accent, 0.5))
		Pen.rect(c, tx + 2, 229, 6, 1.6, Pen.alpha(detail, 0.6))
	Pen.rect(c, 92, 249, SCHACHT.links - 94, 1, Pen.alpha(detail, 0.3))
	Pen.rect(c, 96, 240, 20, 1.8, Pen.hex(0xcfd6e6))
	Pen.rect(c, 98, 242, 1.4, 8, Pen.hex(0x2f3a52))
	Pen.rect(c, 111, 242, 1.4, 8, Pen.hex(0x2f3a52))
	Pen.circle(c, 99, 251, 1.4, Pen.hex(0x8fa2c4, 0.9))
	Pen.circle(c, 112, 251, 1.4, Pen.hex(0x8fa2c4, 0.9))
	Pen.rect(c, 110, 237.6, 5, 2, Pen.hex(0xf2f5fb, 0.9))

	# ================================================================ Erdgeschoss
	Pen.rect(c, 152, 256, 2, 60, Pen.darken(sky_top, 0.45))
	Pen.rect(c, 100, 262, 42, 54, Pen.darken(sky_bottom, 0.72))
	var ly := 266.0
	while ly < 314.0:
		Pen.rect(c, 102, ly, 38, 1, Pen.alpha(detail, 0.35))
		ly += 6.0
	Pen.tri(c, 96, BODEN + 6, 148, BODEN + 6, 148, BODEN - 2, gehweg)
	Pen.rect(c, 184, 262, 40, 54, Pen.hex(0x0d1a2c))
	Pen.srect(c, 184, 262, 40, 54, Pen.alpha(detail, 0.7), 0.8)
	Pen.rect(c, 178, 256, 52, 4, Pen.hex(0x2f3a52))
	Pen.rect(c, 162, 257, 16, 12, Pen.hex(0x1d4f9c))
	Pen.rect(c, 165, 259.5, 2.4, 7, Color(1, 1, 1, 0.95))
	Pen.rect(c, 172.6, 259.5, 2.4, 7, Color(1, 1, 1, 0.95))
	Pen.rect(c, 165, 262, 10, 2, Color(1, 1, 1, 0.95))
	Pen.ekg(c, 186, 259.5, 36, 2, 0.35, 0)
	Pen.rect(c, 162, 271, 18, 14, Pen.hex(0x0e1a2c, 0.9))
	var pfeile := [0x7fd07f, 0x4de3ff, 0xffd75e]
	for i in 3:
		Pen.rect(c, 164, 274 + i * 3.6, 10, 1.4, Pen.hex(pfeile[i], 0.85))
		Pen.tri(c, 174, 273.2 + i * 3.6, 174, 276.4 + i * 3.6, 177, 274.8 + i * 3.6, Pen.hex(pfeile[i], 0.85))
	Pen.rect(c, 230, 266, 14, 18, Pen.hex(0xf2f5fb, 0.92))
	for i in 6:
		for j in 6:
			if (i * 3 + j * 5 + ((i * j) % 3)) % 4 < 2:
				Pen.rect(c, 232 + i * 1.7, 268 + j * 1.7, 1.4, 1.4, Pen.hex(0x0d1a2c))
	Pen.rect(c, 232, 268, 3.4, 3.4, Pen.hex(0x0d1a2c))
	Pen.rect(c, 238.8, 268, 3.4, 3.4, Pen.hex(0x0d1a2c))
	Pen.rect(c, 232, 274.8, 3.4, 3.4, Pen.hex(0x0d1a2c))
	Pen.rect(c, 232, 280.5, 10, 1.6, Pen.alpha(K, 0.9))
	Pen.rect(c, 258, 300, 64, 16, Pen.hex(0x2f3a52))
	Pen.rect(c, 256, 298, 68, 3, Pen.hex(0x39445e))
	Pen.rect(c, 256, 298, 68, 0.8, Color(1, 1, 1, 0.1))
	Pen.rect(c, 264, 305, 4, 2.6, Pen.hex(0x7fd07f, 0.85))
	Pen.rect(c, 270, 305, 4, 2.6, Pen.hex(0x4de3ff, 0.85))
	Pen.rect(c, 276, 305, 4, 2.6, Pen.hex(0xffd75e, 0.85))
	Pen.rect(c, 304, 290, 10, 8, Pen.hex(0x39445e))
	Pen.rect(c, 305.5, 291.5, 7, 4, Pen.hex(0x0a1220))
	Pen.rect(c, 313, 295.5, 3.4, 1.6, Pen.hex(0xffd75e, 0.95))
	for cx in [346.0, 362.0, 378.0]:
		Pen.rect(c, cx - 3, 306, 6, 1.6, Pen.hex(0x39445e))
		Pen.rect(c, cx - 3, 307.6, 1.2, 8.4, Pen.hex(0x39445e))
		Pen.rect(c, cx + 1.8, 307.6, 1.2, 8.4, Pen.hex(0x39445e))
		Pen.rect(c, cx + 2.4, 298, 1.2, 8.4, Pen.hex(0x39445e))
	Pen.rect(c, 424, 288, 18, 28, Pen.hex(0x2f3a52))
	Pen.rect(c, 426, 290, 10, 20, Pen.hex(0x102138))
	var snack := [0xffd75e, 0x7fd07f, 0x9a7ae8]
	for r in 3:
		for col in 3:
			Pen.rect(c, 427.5 + col * 3, 292 + r * 5, 2, 3, Pen.hex(snack[(r + col) % 3], 0.8))
	Pen.rect(c, 394, 276, 24, 13, Pen.hex(0x0e1a2c, 0.92))
	Pen.srect(c, 394, 276, 24, 13, Pen.alpha(detail, 0.7), 0.6)
	Pen.rect(c, 338, 308, 5, 8, Pen.hex(0x3a6a55))
	Pen.rect(c, 336.5, 302, 8, 6, Pen.hex(0x7fd07f, 0.8))

	# ================================================================ Keller: hier wohnt die TI
	Pen.rect(c, KELLER.links, KELLER.oben, KELLER.rechts - KELLER.links, KELLER.unten - KELLER.oben, Pen.hex(0x080d16))
	Pen.srect(c, KELLER.links, KELLER.oben, KELLER.rechts - KELLER.links, KELLER.unten - KELLER.oben, Pen.alpha(Pen.darken(sky_top, 0.2), 0.5), 1.0)
	for tx in [190.0, 300.0, 390.0]:
		Pen.rect(c, tx, KELLER.oben, 2, KELLER.unten - KELLER.oben, Pen.darken(sky_top, 0.35))
	Pen.rect(c, 108, 328, 20, 13, Pen.hex(0x3a4358))
	Pen.srect(c, 108, 328, 20, 13, Pen.alpha(detail, 0.8), 0.7)
	Pen.rect(c, 126.5, 336, 3.6, 2, Pen.hex(0xffd75e, 0.95))
	Pen.rect(c, 192, KELLER.oben + 1, 106, KELLER.unten - KELLER.oben - 2, Pen.alpha(K, 0.05))
	Pen.scircle(c, 191, 336, 5.5, Pen.hex(0x8fa2c4, 0.5), 1.2)
	Pen.line(c, 186.5, 336, 195.5, 336, Pen.hex(0x8fa2c4, 0.45), 0.7)
	Pen.line(c, 191, 331.5, 191, 340.5, Pen.hex(0x8fa2c4, 0.45), 0.7)
	Pen.rect(c, 238, 340, 30, 2.2, Pen.hex(0x2f3a52))
	Pen.rect(c, 241, 342.2, 2, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, 262, 342.2, 2, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, 242, 333, 8, 6.4, Pen.hex(0x0a1220))
	Pen.rect(c, 252, 333, 8, 6.4, Pen.hex(0x0a1220))
	for rx in [308.0, 328.0, 348.0]:
		Pen.rect(c, rx, 328, 14, 21, Pen.hex(0x141c2e))
		Pen.srect(c, rx, 328, 14, 21, Pen.alpha(detail, 0.7), 0.7)
	Pen.rect(c, 396, 335, 68, 1.4, Pen.hex(0x39445e))
	Pen.rect(c, 396, 344.5, 68, 1.4, Pen.hex(0x39445e))
	for i in 14:
		Pen.rect(c, 398 + i * 4.6, 329 if i % 2 == 0 else 338.5, 3.4, 6, Pen.hex(pfeile[i % 3], 0.75))
	Pen.pfad_linie(c, LEITUNG_A, Pen.alpha(K, 0.18), 0.6)
	Pen.pfad_linie(c, LEITUNG_B, Pen.alpha(K, 0.18), 0.6)

	# ---- Apotheke rechts ----
	Pen.rect(c, 524, 262, 92, 58, Pen.darken(sky_top, 0.25))
	Pen.rect(c, 524, 262, 92, 10, Pen.darken(sky_top, 0.5))
	Pen.rect(c, 522, 260, 96, 2, Pen.alpha(detail, 0.85))
	Pen.rect(c, 532, 278, 44, 34, Pen.alpha(fenster_hell, 0.45))
	Pen.srect(c, 532, 278, 44, 34, Pen.alpha(detail, 0.8), 0.8)
	var regal := [0xffd75e, 0x7fd07f, 0x9a7ae8, 0x4de3ff]
	for r in 2:
		Pen.rect(c, 534, 288 + r * 9, 40, 1, Pen.hex(0x39445e, 0.9))
		for i in 7:
			Pen.rect(c, 536 + i * 5.4, 284.5 + r * 9, 2.6, 3.2, Pen.hex(regal[(i + r) % 4], 0.8))
	Pen.rect(c, 538, 296, 12, 12, Pen.hex(0xf2f5fb, 0.95))
	for i in 5:
		for j in 5:
			if (i * 5 + j * 3 + ((i + j) * 2) % 5) % 4 < 2:
				Pen.rect(c, 539.5 + i * 1.8, 297.5 + j * 1.8, 1.5, 1.5, Pen.hex(0x0d1a2c))
	Pen.rect(c, 588, 288, 18, 28, Pen.hex(0x0d1a2c))
	Pen.srect(c, 588, 288, 18, 28, Pen.alpha(detail, 0.8), 0.8)
	Pen.circle(c, 603, 302, 0.8, Pen.alpha(accent, 0.6))
	Pen.rect(c, 524, 274, 6, 1.6, Pen.hex(0x39445e))
	Pen.rect(c, 519, 275.6, 11, 11, Pen.hex(0x0d2440, 0.95))
	Pen.polyline(c, PackedVector2Array([Vector2(521, 284.6), Vector2(524.5, 277.6), Vector2(528, 284.6)]), Pen.alpha(accent, 0.95), 1.1)
	Pen.line(c, 522.6, 282, 526.4, 282, Pen.alpha(accent, 0.95), 1.1)
	Pen.rect(c, 532, 256.5, 6, 3.5, Pen.hex(0x1c2536))
	Pen.rect(c, 536.5, 254.5, 3, 3, Pen.hex(0x1c2536))
	Pen.tri(c, 536.5, 255, 537.5, 253, 538, 255, Pen.hex(0x1c2536))
	Pen.tri(c, 538.2, 255, 539.2, 253, 539.6, 255, Pen.hex(0x1c2536))
	# Laterne rechts
	Pen.rect(c, 628, 282, 1.6, 38, Pen.hex(0x39445e))
	Pen.rect(c, 626.6, 279, 4.4, 3.4, Pen.hex(0xffd9a0, 0.95))
	Pen.bodenschein(c, 629, BODEN + 1, 30, 0.08)

	# ---- Tafel links (Steuerung + Rechtshinweis) ----
	Pen.rrect(c, 4, 282, 82, 74, 3, Pen.hex(0x060d16, 0.8))
	Pen.srrect(c, 4, 282, 82, 74, 3, Color(1, 1, 1, 0.16), 0.7)
	Pen.rect(c, 8, 295.5, 74, 0.6, Color(1, 1, 1, 0.16))
	Pen.rect(c, 8, 337.5, 74, 0.6, Color(1, 1, 1, 0.12))


func _draw_glow(c: CanvasItem) -> void:
	var accent: Color = theme["accent"]
	Pen.glow(c, W / 2, 78, accent, 70, 0.16)
	Pen.glow(c, 140, 126, accent, 24, 0.12)
	Pen.glow(c, 204, 252, Pen.hex(0xcfe4ff), 20, 0.10)
	Pen.glow(c, 121, 264, Pen.WARM, 16, 0.09)
	Pen.glow(c, 245, 338, Pen.K, 18, 0.13)
	Pen.glow(c, 335, 338, Pen.K, 12, 0.07)
	Pen.glow(c, 570, 270, accent, 16, 0.09)
	Pen.glow(c, 564, 304, Pen.K, 11, 0.10)
	Pen.glow(c, 629, 281, Pen.hex(0xffd9a0), 13, 0.15)
	Pen.glow(c, 138, 152, Color.WHITE, 13, 0.08)
	Pen.glow(c, 369, 263, Pen.hex(0x4d8dff), 10, 0.10)


# ------------------------------------------------------------------- Leben

func _draw_life(c: CanvasItem) -> void:
	var K := Pen.K
	var HAUT := Pen.HAUT

	# ---- Aufzug: Kabine mit Licht, Seil, winziger Fahrgast ----
	var ay := _aufzug_y(t)
	Pen.rect(c, SCHACHT.links + 1, 142, 1, ay - 142, Pen.hex(0x39445e))
	Pen.rect(c, SCHACHT.links + 1, ay, SCHACHT.rechts - SCHACHT.links - 2, 28, Pen.hex(0xffe9b8, 0.22))
	Pen.rect(c, SCHACHT.links + 1, ay, SCHACHT.rechts - SCHACHT.links - 2, 1.6, Pen.hex(0x2f3a52))
	Pen.rect(c, SCHACHT.links + 1, ay + 26.4, SCHACHT.rechts - SCHACHT.links - 2, 1.6, Pen.hex(0x2f3a52))
	Pen.figur(c, SCHACHT.links + 12, ay + 26.4, Pen.P_BESUCH, 0, -1)

	# ---- Flur-Läufer + Rollstuhl-Gespann ----
	var laeufer := [[100.0, 430.0, 26.0, 0.0, Pen.P_AERZTIN, 2.6], [130.0, 440.0, 21.0, 7.0, Pen.P_PFLEGE, 2.3], [140.0, 380.0, 9.0, 3.0, Pen.P_PATIENT, 1.3]]
	for w in laeufer:
		var pos := Pen.pendel(t, w[0], w[1], w[2], w[3])
		Pen.figur(c, pos[0], FUSS.f1, w[4], t * w[5] * 0.5, pos[1])
	var rp := Pen.pendel(t, 150, 400, 13, 11)
	var vor: int = rp[1]
	var rx: float = rp[0] + vor * 6
	Pen.scircle(c, rx, 248.5, 3.4, Pen.hex(0x8fa2c4, 0.95), 0.9)
	Pen.scircle(c, rx + vor * 4.6, 250.4, 1.5, Pen.hex(0x8fa2c4, 0.95), 0.9)
	Pen.rect(c, rx - 3.4, 241.5, 6.8, 1.8, Pen.hex(0x2f3a52))
	Pen.rect(c, rx - vor * 3.4 - 0.8, 236, 1.6, 7, Pen.hex(0x2f3a52))
	Pen.sitzend(c, rx, 243, Pen.P_PATIENT)
	Pen.figur(c, rp[0] - vor * 3, FUSS.f1, Pen.P_PFLEGE, t * 1.9 * 0.5, vor)
	# TIM-Ecke: Arzt am Telefon, Sprechblasen wechseln sich ab
	var bob := sin(t * 2.1) * 0.4
	Pen.figur(c, 430, FUSS.f1, Pen.P_ARZT, 0, -1)
	Pen.rect(c, 426.4, 243.6 + bob * 0.2, 1.6, 2.6, Pen.alpha(K, 0.9))
	var wer := sin(t * 1.85)
	Pen.rrect(c, 418, 228, 8, 5, 1.5, Pen.hex(0xe9eef8, 0.85 if wer > 0 else 0.2))
	Pen.rrect(c, 428, 231.5, 8, 5, 1.5, Pen.hex(0x8fd6c8, 0.2 if wer > 0 else 0.85))
	# Wanduhr im Flur
	Pen.scircle(c, 107, 228, 3, Pen.hex(0xd8e0f0, 0.9), 0.7)
	Pen.line(c, 107, 228, 107 + sin(t * 0.105) * 2.4, 228 - cos(t * 0.105) * 2.4, Pen.hex(0xd8e0f0, 0.9), 0.7)
	Pen.line(c, 107, 228, 108.6, 227, Pen.hex(0xd8e0f0, 0.9), 0.7)

	# ---- 1. OG: Betten atmen, Monitore laufen, Visite, TV flimmert ----
	_bett(c, 104, FUSS.f2, Pen.hex(0x5c7ba8), Pen.hex(HAUT[1]), 0.0)
	_monitor(c, 132, FUSS.f2, 0.1)
	_bett(c, 204, FUSS.f2, Pen.hex(0x8a5f9e), Pen.hex(HAUT[0]), 2.1)
	_bett(c, 300, FUSS.f2, Pen.hex(0x4d8a70), Pen.hex(HAUT[2]), 4.2)
	_monitor(c, 328, FUSS.f2, 0.55)
	var nick := sin(t * 1.6) * 0.5
	Pen.figur(c, 150, FUSS.f2, Pen.P_ARZT, 0, -1)
	Pen.rect(c, 145.2, 205.6 + nick * 0.3, 3, 4, Pen.hex(0xf2f5fb, 0.95))
	var uinf := fmod(t, 1.6) / 1.6
	if uinf < 0.75:
		Pen.rect(c, 95.6, 198 + uinf * 12, 1, 1.6, Pen.hex(0xffd75e, 0.9 - uinf))
	Pen.rect(c, 263, 187, 12, 6, Pen.hex(0xcfe4ff, 0.1 + absf(sin(t * 2.7) * sin(t * 1.3)) * 0.12))
	Pen.sitzend(c, 404, 202, Pen.P_PFLEGE)
	Pen.rect(c, 429, 198, 1.4, 1.4, Pen.hex(0x7fd07f, 0.9 if sin(t * 2.4) > 0 else 0.25))

	# ---- 2. OG: OP läuft, Labor blubbert, KIM pingt, Röntgen flackert ----
	var b1 := sin(t * 1.5) * 0.5
	var b2 := sin(t * 1.5 + 1.7) * 0.5
	Pen.figur(c, 124, FUSS.f3, Pen.P_OP, 0, 1)
	Pen.figur(c, 156, FUSS.f3, Pen.P_OP, 0, -1)
	Pen.rect(c, 127 + b1, 164.5, 2, 1.4, Pen.hex(HAUT[0]))
	Pen.rect(c, 151 - b2, 164.5, 2, 1.4, Pen.hex(HAUT[0]))
	Pen.rect(c, 124, 165.4, 22, 2.6, Pen.hex(0x69b894))
	Pen.rect(c, 146, 164.8, 3, 2.6, Pen.hex(HAUT[2]))
	Pen.ekg(c, 168, 158, 8, 2, t, 0.8)
	var lp := Pen.pendel(t, 210, 262, 8, 5)
	Pen.figur(c, lp[0], FUSS.f3, Pen.P_TECHNIK, t * 1.2 * 0.5, lp[1])
	for i in 3:
		var u := fmod(t * 0.7 + i * 0.33, 1.0)
		Pen.circle(c, 229.5, 162 - u * 7, 0.8, Pen.hex(0x7fd07f, 0.7 - u * 0.6))
	Pen.sitzend(c, 312, 166, Pen.P_PFLEGE)
	var uk := fmod(t, 4.5) / 4.5
	var pop := sin((uk / 0.18) * PI) if uk < 0.18 else 0.0
	var ex := 301.5
	var ey := 152 - pop * 2.5
	Pen.rect(c, ex - 3, ey - 2, 6, 4, Pen.hex(0x8fd6c8, 0.55 + pop * 0.45))
	Pen.polyline(c, PackedVector2Array([Vector2(ex - 3, ey - 2), Vector2(ex, ey + 0.5), Vector2(ex + 3, ey - 2)]), Pen.hex(0x0a1220, 0.9), 0.5)
	Pen.rect(c, 380, 146, 36, 24, Pen.hex(0xcfe4ff, 0.03 + absf(sin(t * 3.1)) * 0.04))
	var tp := Pen.pendel(t, 424, 432, 3, 1)
	Pen.figur(c, tp[0], FUSS.f3, Pen.P_TECHNIK, 0, tp[1])

	# ---- EG: Empfang, Wartende, Putzroboter, Türen ----
	var eb := sin(t * 2.3) * 0.4
	Pen.rect(c, 291.4, 291.5 + eb * 0.3, 5.2, 6.5, Pen.hex(0x5fc4b8))
	Pen.rect(c, 292.2, 287.6 + eb * 0.4, 3.6, 3.8, Pen.hex(HAUT[2]))
	Pen.rect(c, 292.2, 287.6 + eb * 0.4, 3.6, 1.3, Pen.hex(0x14101a))
	Pen.figur(c, 250, FUSS.eg, Pen.P_BESUCH, 0, 1)
	Pen.rect(c, 253.4, 302.5, 3.2, 2.2, Pen.hex(0x7fd07f))
	Pen.rect(c, 253.9, 303, 1, 0.8, Color(1, 1, 1, 0.4 + sin(t * 3.4) * 0.35))
	Pen.sitzend(c, 346, 306, Pen.P_BESUCH)
	Pen.sitzend(c, 362, 306, Pen.P_KIND, sin(t * 3.2) * 1.4)
	var pr := Pen.pendel(t, 168, 420, 9, 4)
	Pen.rrect(c, pr[0] - 4, FUSS.eg - 4.6, 8, 4, 1.6, Pen.hex(0x2f3a52))
	Pen.rect(c, pr[0] - 1, FUSS.eg - 6, 2, 1.6, Pen.alpha(K, 0.95 if sin(t * 2.8) > 0 else 0.4))
	Pen.rect(c, pr[0] - pr[1] * 7, FUSS.eg - 1.4, 4, 0.7, Color(1, 1, 1, 0.14))
	# Besucher kommt von links, die Schiebetür öffnet sich
	var tuer_auf := 0.0
	var ub := fmod(t, 14.0)
	if ub < 4.4:
		var bx := 96 + (204 - 96) * (ub / 4.4)
		Pen.figur(c, bx, FUSS.strasse, Pen.P_BESUCH, t * 2.2 * 0.5, 1)
		tuer_auf = maxf(tuer_auf, clampf((32 - absf(bx - 204)) / 32, 0, 1))
	elif ub < 5.0:
		var k := (ub - 4.4) / 0.6
		Pen.figur(c, 204, FUSS.strasse - k * 2, Pen.P_BESUCH, 0, 1, 1 - k)
		tuer_auf = 1.0
	# Entlassener Patient läuft mit dem E-Rezept am Handy zur Apotheke
	var ue := fmod(t + 17, 30.0)
	if ue < 0.8:
		tuer_auf = 1.0
	if ue < 12.6:
		var k := clampf(ue / 12, 0, 1)
		var px := 204 + (596 - 204) * k
		var a := ue / 0.8 if ue < 0.8 else (1 - (ue - 12) / 0.6 if ue > 12 else 1.0)
		a = clampf(a, 0, 1)
		Pen.figur(c, px, FUSS.strasse, Pen.P_PATIENT, t * 2 * 0.5, 1, a)
		Pen.rect(c, px + 3, FUSS.strasse - 7.6, 1.6, 2.6, Pen.alpha(K, 0.95 * a))
		if ue < 1.2:
			tuer_auf = maxf(tuer_auf, 1 - (ue - 0.8) / 0.4)
	var o := tuer_auf * 7
	Pen.rect(c, 196 - o, 262, 8, 54, Pen.hex(0x9fc4e8, 0.3))
	Pen.rect(c, 204 + o, 262, 8, 54, Pen.hex(0x9fc4e8, 0.3))
	Pen.rect(c, 196 - o + 7, 262, 1, 54, Pen.hex(0xd8e0f0, 0.8))
	Pen.rect(c, 204 + o, 262, 1, 54, Pen.hex(0xd8e0f0, 0.8))
	# Zwei Passanten auf dem Gehweg
	var pa := Pen.pendel(t, 94, 620, 15, 40)
	Pen.figur(c, pa[0], FUSS.strasse, Pen.P_GRUEN, t * 2.1 * 0.5, pa[1])
	var pb := Pen.pendel(t, 96, 604, 19, 140)
	Pen.figur(c, pb[0], FUSS.strasse, Pen.P_GELB, t * 2.4 * 0.5, pb[1])

	# ---- Keller: Konnektor-LEDs, VAU-Arbeit, Rack-Lichter, Pulse, Maus ----
	var haengt := fmod(t, 12.0) > 8.4 and fmod(t, 12.0) < 9.9
	for i in 4:
		var an := sin(t * 2.2 + i * 1.9) > -0.2
		Pen.rect(c, 111 + i * 3.6, 331, 1.8, 1.8, Pen.hex(0x333c4e if haengt else 0x7fd07f, 0.95 if (an and not haengt) else 0.25))
	if haengt:
		Pen.rect(c, 111, 335, 1.8, 1.8, Pen.hex(0xff5050, 0.95))
	Pen.sitzend(c, 256, 346, Pen.P_TECHNIK)
	Pen.rect(c, 243, 334, 6, 4.4, Pen.alpha(K, 0.25 + absf(sin(t * 1.7)) * 0.25))
	Pen.rect(c, 253, 334, 6, 4.4, Pen.alpha(K, 0.25 + absf(sin(t * 1.7 + 1.2)) * 0.25))
	var racks := [308.0, 328.0, 348.0]
	for ri in 3:
		for reihe in 6:
			for sp in 3:
				var an := (ri * 7 + reihe * 13 + sp * 5 + int(floor(t * 2.5)) * 29) % 11 < 4
				Pen.rect(c, racks[ri] + 2.5 + sp * 3.6, 330.5 + reihe * 3, 1.6, 1.2, Pen.alpha(K, 0.9) if an else Pen.hex(0x333c4e, 0.3))
	for k in 3:
		var pA := Pen.pfad_punkt(LEITUNG_A, fmod(t / 6 + k / 3.0, 1.0))
		Pen.circle(c, pA.x, pA.y, 1.8, Pen.alpha(K, 0.25))
		Pen.circle(c, pA.x, pA.y, 0.7, Color(1, 1, 1, 0.9))
		var pB := Pen.pfad_punkt(LEITUNG_B, fmod(t / 5 + k / 3.0 + 0.15, 1.0))
		Pen.circle(c, pB.x, pB.y, 1.8, Pen.alpha(K, 0.25))
		Pen.circle(c, pB.x, pB.y, 0.7, Color(1, 1, 1, 0.9))
	var um := fmod(t, 23.0)
	if um < 1.1:
		var mx := 460 - (um / 1.1) * 62
		Pen.rect(c, mx, 348.6, 3, 1.6, Pen.hex(0x8a8fa0, 0.95))
		Pen.circle(c, mx - 0.4, 348.8, 0.8, Pen.hex(0x8a8fa0, 0.95))
		Pen.line(c, mx + 3, 349.4, mx + 5.5, 348.6 + sin(t * 30) * 0.6, Pen.hex(0x8a8fa0, 0.8), 0.5)

	# ---- Helipad-Randlichter + Antennen-Beacon (1 Hz) ----
	for i in 4:
		var an := sin(t * TAU + i * 1.57) > 0.2
		Pen.rect(c, 381 + i * 25.4, 127, 1.6, 1.6, Pen.hex(0x7fd07f, 0.9 if an else 0.15))
	Pen.circle(c, 467, 94.5, 1.1, Pen.hex(0xff5050, 0.95 if sin(t * TAU) > 0.5 else 0.1))
	# Tauben auf der Dachkante
	for i in 3:
		var ph := fmod(t * 0.42 + i * 2.3, 7.0)
		var hop := sin((ph / 0.3) * PI) * 2 if ph < 0.3 else 0.0
		var px := 300 + i * 17 + (1 if ph < 0.3 else 0)
		Pen.rect(c, px, 133.4 - hop, 3, 2, Pen.hex(0x8a92a8))
		Pen.circle(c, px + 3.2, 133.4 - hop, 1, Pen.hex(0x8a92a8))
	# Katzenschwanz, Hund an der Laterne
	Pen.line(c, 532.4, 258, 529.4, 256.6 + sin(t * 1.4) * 1.4, Pen.hex(0x1c2536), 0.9)
	Pen.rect(c, 614, 315.4, 5, 2.6, Pen.hex(0x6b4326))
	Pen.rect(c, 618.4, 313.6, 2.6, 2.6, Pen.hex(0x6b4326))
	Pen.rect(c, 614.6, 318, 1, 2, Pen.hex(0x6b4326))
	Pen.rect(c, 617.6, 318, 1, 2, Pen.hex(0x6b4326))
	Pen.line(c, 614, 316, 611.8, 314.4 + sin(t * 6) * 1, Pen.hex(0x6b4326), 0.8)
	# Dampf aus der Dachlüftung
	for i in 3:
		var k := fmod(t + i * 0.9, 2.6) / 2.6
		var e := 1.0 - pow(1.0 - k, 2)
		Pen.circle(c, 252 + (6 + i * 3) * e, 126 - (20 + i * 4) * e, 2.2 + 4.5 * e, Pen.hex(0xcfd8e8, 0.16 * (1 - k)))

	# ---- Hubschrauber: Anflug, Landung, Trage zur Dachtür, Abflug ----
	var uh := fmod(t, 26.0)
	var hx := -999.0
	var hy := 0.0
	var rotor := 1.0
	if uh < 5:
		var k := sin(((uh / 5) * PI) / 2)
		hx = -60 + (419 + 60) * k
		hy = 66 + (112 - 66) * k
	elif uh < 7:
		hx = 419
		hy = 112 + (125 - 112) * ((uh - 5) / 2)
	elif uh < 15:
		hx = 419
		hy = 125
		rotor = maxf(0.12, 1 - (uh - 7) / 3)
	elif uh < 18:
		hx = 419
		hy = 125
		rotor = minf(1, 0.12 + (uh - 15) / 2.4)
	elif uh < 23:
		var k := (uh - 18) / 5
		hx = 419 + (720 - 419) * k * k
		hy = 125 - 82 * k
	if hx > -900:
		Pen.rrect(c, hx - 9, hy - 7, 18, 7, 3, Pen.hex(0xd8e0f0))
		Pen.rect(c, hx + 3.5, hy - 6, 4.5, 3, Pen.hex(0x0d1a2c, 0.9))
		Pen.rect(c, hx - 22, hy - 5, 14, 2, Pen.hex(0xd8e0f0))
		Pen.rect(c, hx - 24, hy - 9, 2.6, 6, Pen.hex(0xd8e0f0))
		Pen.ekg(c, hx - 7, hy - 3.4, 12, 1.2, 0.35, 0.6)
		Pen.rect(c, hx - 8, hy + 0.6, 1.2, 2, Pen.hex(0x39445e))
		Pen.rect(c, hx + 6, hy + 0.6, 1.2, 2, Pen.hex(0x39445e))
		Pen.rect(c, hx - 10, hy + 2.6, 21, 1, Pen.hex(0x39445e))
		if rotor > 0.5:
			Pen.ellipse(c, hx, hy - 8.6, 34, 1.6, Pen.hex(0xcfd8e8, 0.3))
		else:
			var a := t * (2 + rotor * 26)
			Pen.line(c, hx - cos(a) * 16, hy - 8.6, hx + cos(a) * 16, hy - 8.6, Pen.hex(0xcfd8e8, 0.85), 0.8)
		Pen.circle(c, hx - 23, hy - 10, 0.9, Pen.hex(0xff5050, 0.9 if sin(t * TAU) > 0.4 else 0.1))
		if uh >= 8 and uh < 13.5:
			var k := (uh - 8) / 5.5
			var tsx := 428 + (SCHACHT.links + 4 - 428) * k
			Pen.figur(c, tsx - 5, 137.5, Pen.P_PFLEGE, t * 2 * 0.5, 1)
			Pen.figur(c, tsx + 7, 137.5, Pen.P_PFLEGE, t * 2 * 0.5, 1)
			Pen.rect(c, tsx - 4, 130.4, 10, 1.4, Pen.hex(0xcfd6e6))
			Pen.rect(c, tsx - 2, 128.8, 6, 1.6, Pen.hex(0xe9eef8, 0.95))

	# ---- Footer-Band: dunkler Verlauf hinter Tafel und Start-Zeile ----
	Pen.vgradient(c, 0, H - 60, W, 60, Pen.hex(0x04070c, 0.0), Pen.hex(0x04070c, 0.5))
	# ---- Bedienungswahl (über dem Band, unter den Schriften) ----
	_draw_pills(c)
	_draw_flags(c)
	_draw_sound(c)


func _bett(c: CanvasItem, x: float, y_boden: float, decke: Color, haut: Color, phase: float) -> void:
	Pen.rect(c, x, y_boden - 6, 1.6, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, x + 20.5, y_boden - 6, 1.6, 6, Pen.hex(0x2f3a52))
	Pen.rect(c, x - 0.5, y_boden - 7.6, 23, 1.8, Pen.hex(0xcfd6e6))
	Pen.rect(c, x + 17, y_boden - 9.6, 5, 2.2, Pen.hex(0xf2f5fb, 0.95))
	Pen.rect(c, x + 18, y_boden - 11.2, 3.2, 2.6, haut)
	var atem := sin(t * 1.4 + phase) * 0.5
	Pen.rect(c, x + 1, y_boden - 9.8, 16.5, 2.6, decke)
	Pen.rect(c, x + 6, y_boden - 10.8 - atem, 7, 1.4, decke)


func _monitor(c: CanvasItem, x: float, y_boden: float, phase: float) -> void:
	Pen.rect(c, x + 3.6, y_boden - 6, 1.4, 6, Pen.hex(0x39445e))
	Pen.rect(c, x, y_boden - 13, 9, 7, Pen.hex(0x0a1220))
	Pen.srect(c, x, y_boden - 13, 9, 7, Pen.hex(0x39445e), 0.6)
	Pen.ekg(c, x + 0.8, y_boden - 9.4, 7.4, 2.2, t, phase)
