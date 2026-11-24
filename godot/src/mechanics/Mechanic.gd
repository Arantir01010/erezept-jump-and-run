class_name Mechanic
extends Node2D
## Basisklasse aller Bausteine. Jeder Baustein liest seine Parameter aus dem
## Objekt (level.json → objects[]) und level-weit aus mechanics[typ].
## Verhalten kommt nie aus der Karte, immer aus dem Code des Bausteins.

var level   # Level.gd (bewusst untypisiert: Level ↔ Mechanic verweisen aufeinander)
var obj := {}
var type := ""
var rect := Rect2()
## Zeichen-Culling (Level._cull_mechanics): Wie weit zeichnet der Baustein über sein
## Rechteck hinaus (Lichtkegel, Pendelweg)? Außerhalb von Bild + Rand ist er
## unsichtbar — _draw entfällt, tick() läuft weiter (Zustand bleibt korrekt).
var draw_reach := Vector2.ZERO


func setup(lvl, o: Dictionary) -> void:
	level = lvl
	obj = o
	type = str(o.get("type", ""))
	rect = Rect2(float(o.get("tx", 0)) * Game.TILE, float(o.get("ty", 0)) * Game.TILE,
		float(o.get("tw", 1)) * Game.TILE, float(o.get("th", 1)) * Game.TILE)
	position = rect.get_center()
	spawn()


## Vom Baustein überschrieben.
func spawn() -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Bereich, den der Baustein (an seiner aktuellen Position) bezeichnet.
func cull_rect() -> Rect2:
	return Rect2(global_position - rect.size / 2.0 - draw_reach, rect.size + draw_reach * 2.0)


var player: Player:
	get: return level.player

var rezi: Rezi:
	get: return level.rezi

var pal: Palette:
	get: return level.pal

var data: LevelData:
	get: return level.data


func param(key: String, fallback: Variant) -> Variant:
	return data.param(obj, key, fallback)


## Lokalisierter Parameter mit Fallback ({de,en} oder String). Knopfnamen wie
## {action} setzt BriefingDaten.tasten passend zur Bedienung ein („Taste E",
## „Knopf BLAU", „AKTION") — früher stand in den Stationstexten „Blauer Knopf",
## am PC wusste niemand, welche Taste das ist (Team-Feedback 9/2026).
func ltext(key: String, fallback: Variant) -> String:
	var v = param(key, null)
	if v == null:
		return BriefingDaten.tasten(Game.t(fallback))
	return BriefingDaten.tasten(Game.t(v))


## Tastenkappe über dem Baustein, solange er auf die TI-Aktion wartet (Paul steht
## davor): zeigt E, BLAU oder AKTION — je nach Bedienung. Ruhig: weich ein- und
## ausblenden, leichtes Schweben, kein Blinken. Pro Frame aus tick() aufrufen.
var _kappe: Kappe

func kappe(pos: Vector2, zeigen: bool, delta: float) -> void:
	if _kappe == null:
		if not zeigen:
			return
		_kappe = Kappe.new()
		add_child(_kappe)
	_kappe.position = pos
	_kappe.tick(delta, zeigen)


class Kappe extends Node2D:
	var a := 0.0
	var text := ""
	var _t := 0.0
	static var _sb: StyleBoxFlat

	func _ready() -> void:
		z_as_relative = false
		z_index = 40          # vor Paul (10) und REZI (12)
		visible = false

	func tick(delta: float, zeigen: bool) -> void:
		var vorher := a
		a = move_toward(a, 1.0 if zeigen else 0.0, delta * 5.0)
		if a <= 0.0 and vorher <= 0.0:
			return
		_t += delta
		text = Kiosk.label_action()
		visible = a > 0.0
		queue_redraw()

	func _draw() -> void:
		if _sb == null:
			_sb = StyleBoxFlat.new()
			_sb.anti_aliasing = true
			_sb.set_corner_radius_all(9)
		var font := Brand.sans("medium")
		var size := 26
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var w := maxf(48.0, tw + 28.0)
		var h := 44.0
		var y := sin(_t * TAU * 0.8) * 3.0 - (1.0 - a) * 10.0   # schwebt; taucht von unten auf
		var r := Rect2(-w / 2.0, -h / 2.0 + y, w, h)
		# dunkle Unterkante (Tastenhub), dann die helle Kappe
		_sb.bg_color = Color(0.106, 0.141, 0.22, 0.92 * a)
		draw_style_box(_sb, Rect2(r.position + Vector2(0, 5), r.size))
		_sb.bg_color = Color(0.875, 0.902, 0.941, 0.97 * a)
		draw_style_box(_sb, r)
		var base := r.position.y + h / 2.0 + font.get_ascent(size) / 2.0 - 3.0
		draw_string(font, Vector2(r.position.x, base), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(0.086, 0.137, 0.227, a))
		# kleiner Zeiger nach unten: hier drücken
		var s := r.end.y + 9.0
		draw_colored_polygon(PackedVector2Array([Vector2(-7, s), Vector2(7, s), Vector2(0, s + 8)]), Color(0.875, 0.902, 0.941, 0.85 * a))


## Sensor-Zone (Area2D) auf dem Spieler-Layer; Callback bei Betreten/Verlassen.
func make_sensor(r: Rect2, on_enter: Callable, on_exit := Callable()) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	cs.shape = s
	cs.position = r.get_center() - position
	a.add_child(cs)
	# Verzögert (CONNECT_DEFERRED): Rückrufe ändern Physik (Treffer, Hitbox,
	# neue Körper) — während die Physik ihre Abfragen abarbeitet, ist das verboten.
	# is_instance_valid: beim Abbau des Baums (Levelwechsel, Beenden) kann der
	# Körper schon freigegeben sein, wenn der verzögerte Rückruf ankommt.
	a.body_entered.connect(func(b):
		if is_instance_valid(b) and b is Player and is_instance_valid(self):
			on_enter.call(b), CONNECT_DEFERRED)
	if on_exit.is_valid():
		a.body_exited.connect(func(b):
			if is_instance_valid(b) and b is Player and is_instance_valid(self):
				on_exit.call(b), CONNECT_DEFERRED)
	add_child(a)
	return a


func player_in_rect(r: Rect2) -> bool:
	if player == null:
		return false
	var p := player.global_position + Vector2(0, -20)
	return r.has_point(p)


func local_rect() -> Rect2:
	return Rect2(rect.position - position, rect.size)


func gate_named(gate_name: String):
	return level.gates.get(gate_name, null)


func linked_gate():
	var g = obj.get("gate", null)
	if g == null:
		return null
	return gate_named(str(g))


func say(text: String, hold := 3.0) -> void:
	if rezi:
		rezi.say(text, hold)


## Weiche Panel-Zeichnung mit optionalem Glühen (Materialsystem).
## Eine geteilte StyleBox für alle Bausteine: draw_style_box legt die Geometrie
## sofort an, danach darf die Box für den nächsten Aufruf umgestellt werden.
## Früher entstand je Aufruf und Frame eine neue StyleBoxFlat (Speicher-Churn).
static var _panel_sb: StyleBoxFlat

func draw_panel(r: Rect2, fill: Color, edge: Color, radius := 6, glow := 0.0, border := 2) -> void:
	if _panel_sb == null:
		_panel_sb = StyleBoxFlat.new()
		_panel_sb.anti_aliasing = true
	var sb := _panel_sb
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.border_color = edge
	sb.set_border_width_all(border)
	if glow > 0.0:
		sb.shadow_color = Color(edge.r, edge.g, edge.b, 0.35 * glow)
		sb.shadow_size = int(14 * glow)
	else:
		sb.shadow_size = 0
	draw_style_box(sb, r)
