class_name Leitpfeil
extends Node2D
## LEITPFEIL — Hilfe für Feststeckende (Messe-Paket 2, 11/2026): Kommt Paul lange
## nicht voran, zeigt über ihm ein ruhiger Pfeil in REZI-Farbe zum nächsten Ziel
## (fehlende Prüfsumme, offene Station oder Tür). Kein Blinken: weiches Ein- und
## Ausblenden, leichtes Atmen unter 1 Hz. Der Level setzt `ziel` und `zeigen`.

const ABSTAND := 150.0       # über Pauls Kopf

var ziel := Vector2.INF
var zeigen := false
var player: Node2D
var _a := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = 40
	modulate.a = 0.0


func _process(delta: float) -> void:
	_t += delta
	var soll := 1.0 if zeigen and ziel != Vector2.INF and is_instance_valid(player) else 0.0
	_a = move_toward(_a, soll, delta * 2.5)
	modulate.a = _a
	visible = _a > 0.01
	if not visible:
		return
	# Pauls Bildposition (Physik-Interpolation): der Pfeil bewegt sich auch an 120/144-Hz-
	# Monitoren genau mit ihm, statt im 60-Hz-Takt der Physik zu zucken
	var bei: Vector2 = player.call("render_position") if player.has_method("render_position") else player.global_position
	global_position = bei + Vector2(0, -ABSTAND)
	var richtung := ziel - bei
	rotation = richtung.angle() if richtung.length() > 1.0 else 0.0
	queue_redraw()


func _draw() -> void:
	var atmen := 0.85 + 0.15 * sin(_t * TAU * 0.8)
	var c := Palette.COOL
	var schaft := PackedVector2Array([Vector2(-26, -7), Vector2(10, -7), Vector2(10, -18), Vector2(38, 0), Vector2(10, 18), Vector2(10, 7), Vector2(-26, 7)])
	draw_colored_polygon(schaft, Color(0.067, 0.067, 0.075, 0.55 * atmen))
	var innen := PackedVector2Array()
	for p in schaft:
		innen.append(p * 0.8 + Vector2(2, 0))
	draw_colored_polygon(innen, Palette.glow(Color(c.r, c.g, c.b, 0.95 * atmen), 1.3))
	var rand := schaft.duplicate()
	rand.append(schaft[0])
	draw_polyline(rand, Color(1, 1, 1, 0.8 * atmen), 2.0, true)
