extends Mechanic
## KARTENLESER (Baustein „kartenleser“) — Identität: eGK / HBA / SMC-B, das Terminal.
##
## Das Terminal: Display mit der erwarteten Karte (Umriss in Kartenfarbe) und
## einer Statuszeile, Schlitz mit atmendem Licht, LED rot → gelb → grün.
## Beim Stecken gleitet die Karte sichtbar hinein (0,15 s Anflug + 0,35 s Gleiten,
## reine Funktion von _anim_t) und bleibt sichtbar stecken. Falsche Karte: Rempler,
## Karte springt wieder heraus, Stempel. Belegt: Kopfschütteln.
## Spiellogik (Game.insert_card, Tor) bleibt sofort — die Animation läuft darüber.
## Fachlich: Die Karte öffnet, sie liefert keine Daten (Zugriff freigegeben).
## Was das Terminal weiß und zeigt (LED, Anzeige, Karte im Schlitz, Abweis-Moment),
## steht in der Regelklasse KartenleserRegel (src/state/, ohne Szene testbar); hier
## bleiben Zeichnung, Licht, Klang, Effekte, Sprechblasen und die Kartenbewegung.

## Säule: Display, LED und Schlitz liegen über Kopf- und REZI-Höhe (REZI schwebt
## bei etwa −92 px, Oberkante ≈ −120), damit Paul davor nichts verdeckt.
const W := 104.0
const H := 184.0
const CARD := Vector2(56, 36)
## Schlitz etwas rechts der Mitte: REZI schwebt links über Paul und würde eine
## mittige Karte anschneiden.
const SLOT_X := 12.0
const STATUS := {
	"stecken": {"de": "Karte stecken", "en": "Insert card"},
	"prueft": {"de": "Prüfe Karte …", "en": "Checking card …"},
	"frei": {"de": "Freigegeben ✓", "en": "Released ✓"},
	"abgelehnt": {"de": "Abgelehnt ✗", "en": "Rejected ✗"},
	"keine": {"de": "Keine Karte", "en": "No card"},
	"belegt": {"de": "Steckt woanders", "en": "In another slot"},
}
var accepted: Array = []
var terminal_id := ""
## Zustand des Terminals (LED, Anzeige, Karte, Abweis-Moment …)
var regel := KartenleserRegel.new()
var _hint := false
var _light: PointLight2D
var _glow: Sprite2D
# Kartenbewegung als reine Funktion von _anim_t (0..1); Art und Karte: regel.anim, regel.anim_karte
var _anim_t := 0.0
var _anim_from := Vector2.ZERO
var _anim_tw: Tween

func spawn() -> void:
	z_index = 5
	accepted = KartenleserRegel.karten_aus(obj.get("karten", ["egk"]))
	terminal_id = "leser-%s" % str(rect.position.x)
	make_sensor(rect, _enter, _exit)
	# LED-Licht klein und im Ruhe-Rot schwach: Es soll die Säule nicht rot tönen
	# (in hellen Welten wirkte das wie Alarm) — erst grün darf es leuchten.
	_light = Fx.light(self, _led_pos(), Palette.DENY, 80.0, 0.12)
	if Fx.web_fallback():
		_glow = Fx.glow_sprite(self, Palette.DENY, 18.0, 0.35)
		_glow.position = _led_pos()
	var g = linked_gate()
	if g:
		g.open_hint = ltext("gateHint", {"de": "Dieses Tor öffnet nur eine Karte — steck sie am Terminal links.",
			"en": "Only a card opens this gate — insert it at the terminal on the left."})

# --- Geometrie (lokal) ---

func _body() -> Rect2:
	var r := local_rect()
	return Rect2(-W / 2.0, r.end.y - H, W, H)

## LED sitzt oben rechts im Display
func _led_pos() -> Vector2:
	return Vector2(36, _body().position.y + 22.0)

func _slot_y() -> float:
	return _body().position.y + 96.0

## Karten-Ecke oben links, wenn sie vor dem Schlitz schwebt
func _mouth() -> Vector2:
	return Vector2(SLOT_X - CARD.x / 2.0, _body().position.y + 44.0)

## Karten-Ecke oben links, wenn sie steckt (oberes Drittel bleibt sichtbar)
func _seat() -> Vector2:
	return Vector2(SLOT_X - CARD.x / 2.0, _body().position.y + 74.0)

## Über der Säule: Schwebetexte und Stempel
func _above() -> Vector2:
	return global_position + Vector2(0, local_rect().end.y - H - 22.0)

# --- Sensor ---

func _enter(_p: Player) -> void:
	if not _hint:
		_hint = true
		say(ltext("hint", {"de": "Karte stecken: %s drücken." % Kiosk.label_action(), "en": "Insert your card: press the action."}))

## Wer weggeht, nimmt seinen Ausweis mit — die Karte gleitet wieder heraus.
func _exit(_p: Player) -> void:
	if regel.eingesteckt != "":
		Game.remove_card_from(terminal_id)
	var card := regel.weggehen()
	if card != "":
		_play("raus", card, Vector2.ZERO, 0.3)
		Sfx.play("tick", 0.9, -8.0)

# --- Ablauf ---

func tick(delta: float) -> void:
	if regel.tick(delta, _anim_t):
		_reject_beat()
	var lc := _led_color()
	_light.color = lc
	var breathe := 0.03 * sin(regel.uhr * PI) if regel.led != "gruen" else 0.0   # 0,5 Hz
	var base_e := 0.12
	match regel.led:
		"gruen":
			base_e = 0.55
		"gelb":
			base_e = 0.3
		_:
			base_e = 0.25 if regel.led_bis > 0.0 else 0.12
	_light.energy = base_e + regel.blitz * 0.6 + breathe
	if _glow:
		Fx.set_glow(_glow, lc, (0.9 if regel.led == "gruen" else 0.35) + regel.blitz * 0.6)
	queue_redraw()
	kappe(Vector2(W / 2.0 + 36.0, _slot_y()), player_in_rect(rect) and regel.kann_stecken(), delta)
	if not player_in_rect(rect):
		return
	if Input.is_action_just_pressed("action") and regel.kann_stecken():
		_versuch()

func _versuch() -> void:
	var res := Game.insert_card(accepted, terminal_id)   # Spiellogik sofort
	var from := to_local(player.global_position + Vector2(0, -44.0))
	var g = linked_gate()
	var tor_auf := regel.stecken(res, true if g else false)
	match str(res["result"]):
		"ok":
			Sfx.play("tick", 1.15, -6.0)
			_play("rein", regel.eingesteckt, from, 0.5)
			if tor_auf:
				g.open()
				Game.add_security_bonus()
		"falsche-karte":
			Sfx.play("tick", 1.15, -6.0)
			var wrong := str(Game.cards[0]) if Game.cards.size() > 0 else "egk"
			_play("abgelehnt", wrong, from, 0.7)
		"nicht-dabei":
			Sfx.play("deny", 1.5, -8.0)
			say(ltext("nicht-dabeiHint", {"de": "Die passende Karte hast du noch nicht — such sie unterwegs!",
				"en": "You do not have the right card yet — find it along the way!"}))
		"belegt":
			Sfx.play("deny", 1.5, -8.0)
			say(ltext("belegtHint", {"de": "Deine Karte steckt noch woanders — hol sie erst dort ab.",
				"en": "Your card is still in another slot — pick it up there first."}))

## Der Abweis-Moment (falsche Karte): Rempler, LED rot und Anzeige setzt die Regel;
## hier der Stempel — nur die echte Zurückweisung durch die TI bekommt ihn.
func _reject_beat() -> void:
	Fx.deny_stamp(level, _above(), ltext("denyText", {"de": "ZUGRIFF VERWEIGERT", "en": "ACCESS DENIED"}))
	# REZIs Hinweis erst, wenn der Stempel verblasst — sonst überlagern sich beide
	var hint := ltext("falsche-karteHint", {"de": "ZUGRIFF VERWEIGERT — diese Karte gehört hier nicht hin.",
		"en": "ACCESS DENIED — this card does not belong here."})
	get_tree().create_timer(1.3).timeout.connect(func():
		if is_inside_tree():
			say(hint, 3.5))

## Farbe der Statuszeile: folgt allein aus der Anzeige der Regel.
func _status_color() -> Color:
	match regel.status:
		"frei":
			return Palette.OK
		"abgelehnt":
			return Palette.DENY
		"prueft", "keine", "belegt":
			return Palette.WARM
	return Palette.WHITE

func _led_color() -> Color:
	match regel.led:
		"gruen":
			return Palette.OK
		"gelb":
			return Palette.WARM
	return Palette.DENY

# --- Karten-Animation ---

func _play(kind: String, card: String, from: Vector2, seconds: float) -> void:
	if _anim_tw:
		_anim_tw.kill()
	regel.bewegung(kind, card)
	_anim_from = from
	_anim_t = 0.0
	_anim_tw = create_tween()
	_anim_tw.tween_property(self, "_anim_t", 1.0, seconds)
	_anim_tw.tween_callback(_anim_done)

## Karte sitzt: LED grün, Ring, Funken, Klang, Display, Schwebetext, HUD-Pop.
func _anim_done() -> void:
	if not regel.bewegung_fertig():
		return
	var c := KartenFx.color_of(regel.steckt)
	var at := to_global(Vector2(SLOT_X, _slot_y()))
	Sfx.play("ok", 1.1)
	Fx.ring(level, at, Palette.OK, 76.0)
	Fx.sparkle(level, at, c, 10, 170.0)
	Fx.light_burst(level, at, Palette.OK, 200.0, 1.1, 0.4)
	var inf := KartenFx.info(regel.steckt)
	Fx.float_text(level, _above(), "%s ✓ · %s" % [inf["kurz"],
		Game.t({"de": "Zugriff freigegeben", "en": "access granted"})], c, 22)
	KartenFx.hud_pop(level, regel.steckt)
	if regel.ansage_abholen():
		say(Game.t(data.station.get("reziText", "")), 3.5)

## Lage der animierten Karte (Ecke oben links, Drehung, Deckkraft) —
## reine Funktion von Art und Fortschritt t.
func _card_pose(kind: String, t: float) -> Dictionary:
	var mouth := _mouth()
	var seat := _seat()
	var pos := seat
	var rot := 0.0
	var alpha := 1.0
	match kind:
		"rein":
			if t < 0.3:
				var u := smoothstep(0.0, 1.0, t / 0.3)
				pos = _anim_from.lerp(mouth, u) + Vector2(0, -sin(u * PI) * 26.0)
				rot = lerpf(-0.35, 0.0, u)
			else:
				var u := 1.0 - pow(1.0 - (t - 0.3) / 0.7, 3.0)
				pos = mouth.lerp(seat, u)
		"raus":
			var u := 1.0 - pow(1.0 - t, 3.0)
			pos = seat.lerp(mouth + Vector2(0, -14.0), u)
			rot = lerpf(0.0, -0.18, u)
			alpha = 1.0 - smoothstep(0.55, 1.0, t)
		"abgelehnt":
			var halb := mouth.lerp(seat, 0.45)
			if t < 0.25:
				var u := smoothstep(0.0, 1.0, t / 0.25)
				pos = _anim_from.lerp(mouth, u) + Vector2(0, -sin(u * PI) * 26.0)
				rot = lerpf(-0.35, 0.0, u)
			elif t < 0.5:
				var u := 1.0 - pow(1.0 - (t - 0.25) / 0.25, 3.0)
				pos = mouth.lerp(halb, u)
			else:
				var v := (t - 0.5) / 0.5
				var u := 1.0 - pow(1.0 - v, 2.0)
				pos = halb.lerp(mouth + Vector2(30.0, -46.0), u)
				rot = lerpf(0.0, 0.4, u)
				alpha = 1.0 - smoothstep(0.5, 1.0, v)
	return {"pos": pos, "rot": rot, "alpha": alpha}

static func _fit_font(font: Font, text: String, max_w: float, size: int) -> int:
	var s := size
	while s > 7 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 1
	return s

# --- Zeichnung ---

func _draw() -> void:
	var body := _body()
	var by := body.position.y
	# Rempler (falsche Karte) und Kopfschütteln (belegt): Bewegung um den Fuß, ≤ 3 Hz
	var sx := sin(regel.uhr * 18.0) * 4.0 * regel.rempler
	var rot := sin(regel.uhr * 16.0) * 0.045 * regel.nicken
	var pivot := Vector2(sx, body.end.y)
	var o := Vector2(0, -body.end.y)
	draw_set_transform(pivot, rot, Vector2.ONE)
	# Gehäuse
	var shell := Rect2(body.position + o, body.size)
	draw_panel(shell, pal.metall, pal.detail, 8, 0.25)
	# Display: dunkel, erwartete Karte(n) als Umriss, darunter die Statuszeile
	var disp := Rect2(-44, by + 8 + o.y, 88, 48)
	draw_rect(disp, Color(0.02, 0.05, 0.08, 0.93))
	draw_rect(disp, Color(pal.detail.r, pal.detail.g, pal.detail.b, 0.45), false, 1.0)
	var gx := -40.0
	for a in accepted:
		KartenFx.draw_card(self, Rect2(gx, disp.position.y + 6.0, 26, 17), str(a), "umriss")
		gx += 30.0
	var st: Dictionary = STATUS.get(regel.status, STATUS["stecken"])
	var txt := Game.t(st)
	var fs := _fit_font(Brand.sans("medium"), txt, 80.0, 11)
	draw_string(Brand.sans("medium"), Vector2(disp.position.x + 4, disp.end.y - 8), txt, HORIZONTAL_ALIGNMENT_CENTER, disp.size.x - 8, fs, _status_color())
	# Karte (animiert oder gesteckt) — vor dem Display, hinter der Front
	var card := ""
	var pose := {}
	if regel.anim != "":
		card = regel.anim_karte
		pose = _card_pose(regel.anim, _anim_t)
	elif regel.steckt != "":
		card = regel.steckt
		pose = {"pos": _seat(), "rot": 0.0, "alpha": 1.0}
	if card != "":
		var p: Vector2 = pose["pos"]
		var pr: float = pose["rot"]
		var pa: float = pose["alpha"]
		var center_q := p + CARD / 2.0 + o
		draw_set_transform(pivot + center_q.rotated(rot), rot + pr, Vector2.ONE)
		KartenFx.draw_card(self, Rect2(-CARD / 2.0, CARD), card, "voll", -1.0, pa)
		draw_set_transform(pivot, rot, Vector2.ONE)
	# Front unter dem Schlitz: verdeckt den Kartenkörper (oben eckig, unten rund)
	var sy := _slot_y() + o.y
	var front := Rect2(shell.position.x, sy, shell.size.x, shell.end.y - sy)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = pal.metall
	fsb.border_color = pal.detail
	fsb.set_border_width_all(2)
	fsb.corner_radius_bottom_left = 8
	fsb.corner_radius_bottom_right = 8
	fsb.anti_aliasing = true
	draw_style_box(fsb, front)
	draw_rect(Rect2(front.position.x + 6, front.end.y - 6, front.size.x - 12, 4), Palette.shade(pal.metall, 0.35))
	# Schlitz mit Licht: atmet in der Farbe der erwarteten Karte, gesteckt = grün
	draw_rect(Rect2(SLOT_X - 34, sy - 2, 68, 7), Color(0.02, 0.04, 0.08))
	var slot_c := KartenFx.color_of(str(accepted[0]))
	var slot_a := 0.45 + 0.25 * sin(regel.uhr * PI)   # 0,5 Hz
	if regel.steckt != "":
		slot_c = Palette.OK
		slot_a = 0.9
	draw_rect(Rect2(SLOT_X - 32, sy + 0.5, 64, 2), Color(slot_c.r, slot_c.g, slot_c.b, slot_a))
	# LED mit Fassung: rot (zu), gelb (prüft/belegt), grün (freigegeben); atmet mit 0,5 Hz
	var lp := _led_pos() + o
	var lc := _led_color()
	var k := 1.0
	match regel.led:
		"gruen":
			k = 1.6
		"gelb":
			k = 1.5
		_:
			k = 1.5 if regel.led_bis > 0.0 else 1.0
	k *= 0.86 + 0.14 * sin(regel.uhr * PI)
	draw_circle(lp, 9.5, Color(0.03, 0.05, 0.08, 0.95))
	var led_draw := Palette.glow(lc, k) if not Fx.web_fallback() else lc.lightened(clampf(0.25 * (k - 1.0), 0.0, 0.3))
	draw_circle(lp, 6.5 + regel.blitz * 3.0, led_draw)
	draw_circle(lp + Vector2(-2, -2), 1.8, Color(1, 1, 1, 0.35))
	# Säulenfront unter dem Schlitz: vertiefte Blende mit Lüftungsrillen
	var vent := Rect2(-36, sy + 22.0, 72, front.size.y - 40.0)
	draw_panel(vent, Palette.shade(pal.metall, 0.25), Palette.shade(pal.detail, 0.3), 5, 0.0, 1)
	for i in 3:
		var vy := vent.position.y + 12.0 + i * 12.0
		draw_line(Vector2(vent.position.x + 10, vy), Vector2(vent.end.x - 10, vy), Palette.shade(pal.metall, 0.45), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
