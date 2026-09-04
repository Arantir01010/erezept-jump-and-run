class_name Mechanic
extends Node2D
## Basisklasse aller Bausteine. Jeder Baustein liest seine Parameter aus dem
## Objekt (level.json → objects[]) und level-weit aus mechanics[typ].
## Verhalten kommt nie aus der Karte, immer aus dem Code des Bausteins.

var level   # Level.gd (bewusst untypisiert: Level ↔ Mechanic verweisen aufeinander)
var obj := {}
var type := ""
var rect := Rect2()


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


## Lokalisierter Parameter mit Fallback ({de,en} oder String).
func ltext(key: String, fallback: Variant) -> String:
	var v = param(key, null)
	if v == null:
		return Game.t(fallback)
	return Game.t(v)


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
func draw_panel(r: Rect2, fill: Color, edge: Color, radius := 6, glow := 0.0, border := 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.anti_aliasing = true
	if glow > 0.0:
		sb.shadow_color = Color(edge.r, edge.g, edge.b, 0.35 * glow)
		sb.shadow_size = int(14 * glow)
	draw_style_box(sb, r)
