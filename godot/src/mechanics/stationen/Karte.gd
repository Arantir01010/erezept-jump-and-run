extends Mechanic
## KARTE (Baustein „karte“) — Identität: eGK / HBA / SMC-B, der Ausweis zum Aufsammeln.
##
## Ausweis zum Aufsammeln. Schwebt, der Chip fängt Licht, Name als Bildunterschrift.
## Beim Aufnehmen fliegt die Karte in ihr HUD-Fach (KartenFx.fly_to_hud).
## Fachlich: Identität, keine Währung — zählt nirgends mit, öffnet keine Tür D.

var card := "egk"
var taken := false
var _t := 0.0
var _ground := INF         # Bodenhöhe (lokal) für den Schatten; INF = kein Boden gefunden
var _light: PointLight2D
var _glow: Sprite2D

func spawn() -> void:
	z_index = 6
	card = str(obj.get("karte", "egk")).to_lower()
	_t = randf() * TAU
	make_sensor(Rect2(rect.position - Vector2(10, 30), rect.size + Vector2(20, 40)), _enter)
	var c := KartenFx.color_of(card)
	_light = Fx.light(self, Vector2(0, -8), c, 110.0, 0.3)
	if Fx.web_fallback():
		_glow = Fx.glow_sprite(self, c, 40.0, 0.6)
		_glow.position = Vector2(0, -8)
	# Boden unter der Karte suchen: Der Schatten verankert das Schweben
	var tx := int(floor(rect.get_center().x / Game.TILE))
	var ty := int(floor(rect.end.y / Game.TILE))
	for i in 6:
		if ty + i >= data.height:
			break
		if data.is_solid(tx, ty + i):
			_ground = float(ty + i) * Game.TILE - position.y
			break

func _bob() -> float:
	return sin(_t * 2.0) * 5.0

func _enter(_p: Player) -> void:
	if taken:
		return
	taken = true
	Game.add_card(card)   # Spiellogik sofort — die Animation läuft darüber
	var c := KartenFx.color_of(card)
	var inf := KartenFx.info(card)
	var at := global_position + Vector2(0, _bob() - 8.0)
	Sfx.play("bonus", 0.95)
	Fx.sparkle(level, at, c, 12, 200.0)
	Fx.ring(level, at, c, 64.0)
	Fx.light_burst(level, at, c, 180.0, 1.0, 0.35)
	rezi.happy()
	if _light:
		_light.queue_free()
		_light = null
	if _glow:
		_glow.queue_free()
		_glow = null
	# Flug ins HUD-Fach; ohne HUD (Tests) bleibt der Schwebetext
	if not KartenFx.fly_to_hud(level, at, card, func(): Sfx.play("ui", 1.35, -6.0)):
		Fx.float_text(level, global_position + Vector2(0, -40), str(inf["kurz"]) + " ✓", c, 26)
	var h = obj.get("hint", null)
	if h != null:
		say(Game.t(h), 3.5)
	queue_free()

func tick(delta: float) -> void:
	if taken:
		return
	_t += delta
	if _light:
		_light.energy = 0.28 + 0.08 * sin(_t * 2.0)
	if _glow:
		Fx.set_glow(_glow, KartenFx.color_of(card), 0.55 + 0.15 * sin(_t * 2.0))
	queue_redraw()

func _draw() -> void:
	if taken:
		return
	var c := KartenFx.color_of(card)
	var bob := _bob()
	var tilt := sin(_t * 1.3 + 0.7) * 0.05
	# Bodenschatten: kleiner und blasser, je höher die Karte gerade schwebt
	if _ground < INF:
		var k := 1.0 - (bob + 5.0) / 10.0 * 0.35
		draw_set_transform(Vector2(0, _ground - 2.0), 0.0, Vector2(k, 0.28 * k))
		draw_circle(Vector2.ZERO, 30.0, Color(0.05, 0.05, 0.08, 0.22 * k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# leiser Hof: Fundstück im Abendlicht
	draw_circle(Vector2(0, bob - 8.0), 46.0, Color(c.r, c.g, c.b, 0.08))
	draw_set_transform(Vector2(0, bob - 8.0), tilt, Vector2.ONE)
	KartenFx.draw_card(self, Rect2(-KartenFx.BASE / 2.0, KartenFx.BASE), card, "voll", KartenFx.glint_phase(_t), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Bildunterschrift: der Name der Karte, lesbar
	var inf := KartenFx.info(card)
	var nc := Palette.tint(c, 0.45)
	var y := bob + 34.0
	var kname := str(TranslationServer.translate(str(inf["name"])))
	draw_string_outline(Brand.sans("medium"), Vector2(-80, y), kname, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, 4, Color(0.05, 0.06, 0.09, 0.85))
	draw_string(Brand.sans("medium"), Vector2(-80, y), kname, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, nc)
