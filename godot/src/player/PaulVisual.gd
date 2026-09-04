class_name PaulVisual
extends Node2D
## PAUL als Vektorfigur: Kopf, Kapuzenpulli, Beine per Zwei-Knochen-IK, Arme,
## Gesicht mit Blinzeln. Alles wird pro Frame gezeichnet — kein Sprite-Sheet,
## trotzdem flüssige Laufzyklen, Sprungposen und Squash & Stretch.
##
## Game-Feel-Schicht (Ori: Silhouette und nachschwingende Anhängsel, Celeste:
## Richtung und Tempo über eine Kettensimulation):
##   • Kapuzenzipfel als Verlet-Kette (5 Glieder, in Weltkoordinaten simuliert):
##     hängt im Stand, streamt im Lauf, schwingt bei Sprung und Richtungswechsel,
##     leichter Wind. Wird hinter dem Körper gezeichnet, heller Bommel als Spitze.
##   • Streckung im Aufstieg, Schmierstreckung im schnellen Fall (> 70 % max_fall),
##     Landungs-Squash nach Aufprallstärke (setzt der Player), Lehnen in Lauf- UND
##     Beschleunigungsrichtung (Anlauf vor, Bremsen zurück), Atmen im Stand,
##     Blinzeln (gelegentlich doppelt), Blick in Bewegungsrichtung (Augen + Kopf),
##     gegenläufig schwingende Arme, kompaktes Ducken.
##   • Geisterspur: eingefrorene Nachbilder der Silhouette (neutral-hell, kein
##     Türkis — das hieße „verschlüsselt") beim REZI-Schub und bei sehr hohem Tempo.
##   • Laufrichtung: lokal ist +x immer vorn (scale.x spiegelt mit `facing`). Die
##     Schrittphase laeuft mit Vorzeichen relativ zur Blickrichtung, der Standfuss
##     wandert nach hinten und der Schwungfuss nach vorn — die Beine gehen nie
##     rueckwaerts. Knie zeigen nach vorn, Ellbogen nach hinten (Scharnier-Regel,
##     gilt fuer jede Armlage). Bremspose (Fuesse gestemmt, Oberkoerper zurueck),
##     solange der Player `brake` meldet; beim Umdrehen bleiben Lehnen und Blick in
##     Weltkoordinaten stetig, der Beinzyklus startet mit dem Abdruck neu.
## Alles leitet sich aus dem AKTUELLEN Zustand des Players ab — keine Eingabe-Latenz.
## Die Hülle zeigt sich als leuchtende Schale um die Figur (kühl = verschlüsselt,
## violett = VAU) — zusätzlich zur HUD-Anzeige, damit sie im Spielfeld lesbar ist.

var player: Player
var squash := Vector2.ONE
var flash := 0.0
var blink_until := 0.0

## Paul trägt Warm gegen die kühle Welt (Mario-Regel: Figur komplementär zur Umgebung).
const SKIN := Color(0.96, 0.80, 0.66)
const HAIR := Color(0.32, 0.20, 0.14)
const HOODIE := Color(0.92, 0.38, 0.26)
const HOODIE_DARK := Color(0.68, 0.24, 0.22)
const PANTS := Color(0.24, 0.28, 0.42)
const SHOE := Color(0.97, 0.96, 0.93)
const OUTLINE := Color(0.17, 0.14, 0.20)
const EYE := Color(0.14, 0.12, 0.18)
## Nachbilder: neutral-hell mit dunkler Kante, damit sie auf hellem UND dunklem Grund lesen.
const GHOST_FILL := Color(0.94, 0.91, 0.87)
const GHOST_EDGE := Color(0.30, 0.25, 0.30)
const GHOST_LIFE := 0.25

## Beugerichtung der Zwei-Knochen-IK (siehe _ik): Knie nach vorn, Ellbogen nach hinten
const LEG_BEND := -1.0
const ARM_BEND := 1.0

## Kapuzenzipfel (Verlet-Kette)
const TAIL_LINKS := 5
const TAIL_SEG := 6.2
const TAIL_GRAVITY := 1400.0
const TAIL_DRAG := 5.0
const TAIL_AWAY := 520.0
## Bremspose: Oberkoerper zurueck (lokal -x), Huefte etwas tiefer
const BRAKE_LEAN := -7.0
const BRAKE_BOB := -2.0

var _phase := 0.0
var _blink := 0.0
var _blink_timer := 2.0
var _blink_again := false
var _breathe := 0.0
var _lean := 0.0
var _accel_lean := 0.0
var _prev_vx := 0.0
var _shell_pulse := 0.0
var _bob := 0.0
var _look := Vector2.ZERO
var _rise := 0.0
var _fall := 0.0
var _wind_t := 0.0
var _tail := PackedVector2Array()
var _tail_prev := PackedVector2Array()
var _tail_dt := 1.0 / 60.0
var _tail_ready := false
var _ghosts_left := 0
var _ghost_timer := 0.0
var _speed_ghost_timer := 0.0
var _pose := {}
var _prev_facing := 0
## Blende der Bremspose (0 = Laufzyklus, 1 = gestemmt)
var _brake := 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	var dt := minf(delta, 1.0 / 30.0)
	var v := player.velocity
	var st := player.state
	var on_floor := player.is_on_floor()
	var braking := player.brake and on_floor and st == Player.State.RUN
	# Umdrehen: lokal ist +x vorn — damit Lehnen und Blick in Weltkoordinaten stetig
	# bleiben, kippen sie mit der Blickrichtung. Am Boden geht der Blick sofort nach vorn
	# (neue Laufrichtung); der Beinzyklus startet mit dem Abdruck neu (Phase PI: der
	# vordere Fuss steht, der hintere hebt ab).
	if _prev_facing != 0 and player.facing != _prev_facing:
		_lean = -lerpf(_lean, BRAKE_LEAN, _brake)
		_accel_lean = -_accel_lean
		_look.x = absf(_look.x) if on_floor else -_look.x
		_phase = PI
		_brake = 0.0
	_prev_facing = player.facing
	# Schrittphase mit Vorzeichen relativ zur Blickrichtung; beim Bremsen stehen die Fuesse
	if not braking:
		_phase += (v.x * player.facing / Player.T.run_speed) * delta * 14.0
	_brake = lerpf(_brake, 1.0 if braking else 0.0, 1.0 - exp(-60.0 * delta))
	_breathe += delta
	_shell_pulse += delta
	_wind_t += delta
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-11.0 * delta))
	flash = maxf(0.0, flash - delta * 3.0)

	# Lehnen: lokal ist +x immer vorn (scale.x spiegelt), also relativ zur Blickrichtung.
	# Dazu die Beschleunigung: Anlauf → nach vorn, Bremsen/Umkehren → nach hinten.
	var fwd := clampf(v.x * player.facing / Player.T.run_speed, -1.0, 1.0)
	var ax := 0.0
	if dt > 0.0001:
		ax = clampf((v.x - _prev_vx) / dt * player.facing / Player.T.accel, -1.0, 1.0)
	_prev_vx = v.x
	_accel_lean = lerpf(_accel_lean, ax * 2.5, 1.0 - exp(-10.0 * delta))
	_lean = lerpf(_lean, fwd * 4.0 + _accel_lean, 1.0 - exp(-9.0 * delta))

	# Blinzeln, gelegentlich doppelt
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 0.13
		if _blink_again:
			_blink_again = false
			_blink_timer = randf_range(2.2, 4.6)
		else:
			_blink_again = randf() < 0.3
			_blink_timer = 0.28 if _blink_again else randf_range(2.2, 4.6)
	_blink = maxf(0.0, _blink - delta)

	# Blick: nach vorn beim Laufen, in der Luft nach oben/unten mit der Flugrichtung
	var look_goal := Vector2(clampf(fwd * 1.3, -1.0, 1.0), 0.0)
	if not on_floor:
		look_goal.y = clampf(v.y / 700.0, -1.0, 1.0)
	if st == Player.State.DUCK:
		look_goal = Vector2(1.0, 0.5)
	_look = _look.lerp(look_goal, 1.0 - exp(-10.0 * delta))

	# Streckung im Aufstieg, Schmierstreckung im schnellen Fall (> 70 % max_fall).
	# Aufbau weich, Abbau sofort — die Landung darf nicht nachziehen.
	var rise_t := 0.0
	var fall_t := 0.0
	if not on_floor and st != Player.State.WALL:
		rise_t = clampf(-v.y / Player.T.jump_velocity, 0.0, 1.0)
		var f0: float = 0.7 * Player.T.max_fall
		fall_t = clampf((v.y - f0) / (Player.T.fast_fall - f0), 0.0, 1.0)

	_rise = lerpf(_rise, rise_t, 1.0 - exp(-14.0 * delta))
	_fall = fall_t if fall_t < _fall else lerpf(_fall, fall_t, 1.0 - exp(-12.0 * delta))

	# Wippen im Lauf (beim Bremsen: Huefte tief), Atmen im Stand
	if st == Player.State.RUN:
		_bob = lerpf(-absf(sin(_phase)) * 2.5, BRAKE_BOB, _brake)
	elif st == Player.State.IDLE:
		_bob = sin(_breathe * 2.2) * 1.2
	else:
		_bob = 0.0

	var sx := squash.x * (1.0 - 0.05 * _rise - 0.10 * _fall)
	var sy := squash.y * (1.0 + 0.09 * _rise + 0.22 * _fall)
	scale = Vector2(player.facing * sx, sy)

	_pose = _compute_pose(st)
	var anchor_local: Vector2 = _pose["tail_anchor"]
	_sim_tail(dt, anchor_local)
	_pose["tail"] = _tail_local()

	# Geisterspur: Schub-Nachbilder im Takt, dazu bei sehr hohem Tempo (Schnellfall, Feder)
	if _ghosts_left > 0:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = 0.04
			_ghosts_left -= 1
			_spawn_ghost(0.55)
	if not on_floor and v.length() > 1200.0:
		_speed_ghost_timer -= delta
		if _speed_ghost_timer <= 0.0:
			_speed_ghost_timer = 0.06
			_spawn_ghost(0.32)
	else:
		_speed_ghost_timer = 0.0

	# Unverwundbar: Blinken (deutlich unter 3 Hz, Barrierefreiheit)
	var now := Time.get_ticks_msec() / 1000.0
	if now < blink_until:
		modulate.a = 0.35 if fmod(now, 0.28) < 0.14 else 1.0
	else:
		modulate.a = 1.0
	queue_redraw()


## Geisterspur anstoßen (REZI-Schub): n eingefrorene Nachbilder im Abstand von 45 ms.
func ghost_burst(n := 5) -> void:
	_ghosts_left = n
	_ghost_timer = 0.0


# ------------------------------------------------------------------ Pose

## Alle Gelenkpunkte und Rechtecke der Figur für diesen Frame (lokale Zeichenkoordinaten,
## +x = vorn). Dieselbe Pose zeichnet die Figur, die Schmierkopie und die Nachbilder.
func _compute_pose(st: Player.State) -> Dictionary:
	var duck := st == Player.State.DUCK
	var idle := st == Player.State.IDLE
	var breath := (0.5 + 0.5 * sin(_breathe * 2.2)) if idle else 0.0
	var hip_y := -21.0 + _bob
	var torso_top := -41.0 + _bob - breath * 0.8
	var head_top := -63.0 + _bob - breath * 0.4
	var lean := lerpf(_lean, BRAKE_LEAN, _brake)
	if duck:
		# Kompakter Ball mit vorgeschobenem Kopf und breitem Stand: klare Silhouette
		hip_y = -12.0
		torso_top = -26.0
		head_top = -41.0
		lean = 3.0
	# Kopf folgt dem Blick: im Aufstieg zurück, im Fall nach vorn
	var head_dx := _look.y * 2.0 + _look.x * 0.8
	var hips := PackedVector2Array([Vector2(-5.0, hip_y), Vector2(5.0, hip_y)])
	var feet := _feet(st, duck)
	var shoulder := Vector2(lean * 0.5, torso_top + 5.0)
	var hands := _hands(st, duck)
	var torso := Rect2(-12.0 + lean * 0.5, torso_top, 24.0, hip_y - torso_top + 4.0)
	var hood := Rect2(-13.0 + lean * 0.7, head_top + 6.0, 26.0, 18.0)
	var head := Rect2(-12.0 + lean + head_dx, head_top, 24.0, 22.0)
	var anchor := Vector2(hood.position.x + 1.5, hood.position.y + 12.0)
	if duck:
		anchor = Vector2(hood.position.x + 1.0, hood.position.y + 11.0)
	return {
		"duck": duck, "hip_y": hip_y, "torso_top": torso_top, "head_top": head_top,
		"torso": torso, "hood": hood, "head": head, "hips": hips, "feet": feet,
		"shoulder": shoulder, "hands": hands, "tail_anchor": anchor, "tail": PackedVector2Array(),
	}


func _feet(st: Player.State, duck: bool) -> PackedVector2Array:
	if duck:
		return PackedVector2Array([Vector2(-10.0, 0.0), Vector2(10.0, 0.0)])
	match st:
		Player.State.RUN:
			var k: float = clampf(absf(player.velocity.x) / Player.T.run_speed, 0.5, 1.0)
			var stride := 10.0 * k
			var lift := 9.0 * k
			var a := _phase
			var b := _phase + PI
			# Standfuss (sin <= 0) wandert nach hinten und schiebt den Koerper vor,
			# Schwungfuss (sin > 0) hebt ab und schwingt nach vorn
			var f := PackedVector2Array([
				Vector2(-cos(a) * stride, -maxf(0.0, sin(a)) * lift),
				Vector2(-cos(b) * stride, -maxf(0.0, sin(b)) * lift),
			])
			if _brake > 0.01:
				# Bremspose: naher Fuss vorn gestemmt (gestrecktes Bein), hinterer leicht gebeugt
				f[0] = f[0].lerp(Vector2(-8.0, 0.0), _brake)
				f[1] = f[1].lerp(Vector2(13.0, 0.0), _brake)
			return f
		Player.State.JUMP:
			return PackedVector2Array([Vector2(-7.0, -4.0), Vector2(8.0, -10.0)])
		Player.State.FALL:
			return PackedVector2Array([Vector2(-8.0, -2.0), Vector2(6.0, -6.0)])
		Player.State.WALL:
			return PackedVector2Array([Vector2(-4.0, -6.0), Vector2(7.0, -2.0)])
		Player.State.HURT:
			return PackedVector2Array([Vector2(-9.0, -6.0), Vector2(5.0, -8.0)])
		_:
			return PackedVector2Array([Vector2(-6.0, 0.0), Vector2(6.0, 0.0)])


func _hands(st: Player.State, duck: bool) -> PackedVector2Array:
	if duck:
		# Hintere Hand am Knie, vordere stützt vorn am Boden
		return PackedVector2Array([Vector2(-7.0, -10.0), Vector2(12.0, -5.0)])
	match st:
		Player.State.RUN:
			# Gegenlaeufig zu den Beinen: naher Fuss 1 = +cos φ, ferne Hand 0 = +cos φ
			# (rechtes Bein vor, linker Arm vor), Weite mit dem Tempo
			var k: float = clampf(absf(player.velocity.x) / Player.T.run_speed, 0.4, 1.0)
			var s := 8.5 * k
			var h := PackedVector2Array([
				Vector2(cos(_phase) * s - 2.0, -26.0 + sin(_phase) * 2.5),
				Vector2(-cos(_phase) * s + 4.0, -26.0 - sin(_phase) * 2.5),
			])
			if _brake > 0.01:
				# Bremspose: beide Arme nach vorn (Schwung), Haende auf Brusthoehe
				h[0] = h[0].lerp(Vector2(3.0, -33.0), _brake)
				h[1] = h[1].lerp(Vector2(11.0, -29.0), _brake)
			return h
		Player.State.JUMP:
			return PackedVector2Array([Vector2(-14.0, -46.0), Vector2(12.0, -40.0)])
		Player.State.FALL:
			return PackedVector2Array([Vector2(-15.0, -38.0), Vector2(15.0, -36.0)])
		Player.State.WALL:
			return PackedVector2Array([Vector2(-6.0, -30.0), Vector2(16.0, -34.0)])
		Player.State.HURT:
			return PackedVector2Array([Vector2(-16.0, -30.0), Vector2(14.0, -34.0)])
		_:
			var b := sin(_breathe * 2.2)
			return PackedVector2Array([Vector2(-12.0, -22.0 + b), Vector2(12.0, -22.0 + b)])


# ------------------------------------------------------------------ Kapuzenzipfel

## Verlet-Kette in Weltkoordinaten: der Anker sitzt am Nacken, die Glieder folgen
## mit Schwerkraft, Luftwiderstand und leichtem Wind. Zeitkorrigiert, damit Hitstop
## (time_scale 0,02) die Kette mit einfriert statt sie weiterlaufen zu lassen.
func _sim_tail(dt: float, anchor_local: Vector2) -> void:
	var anchor := global_position + anchor_local * scale
	if not _tail_ready or _tail[0].distance_to(anchor) > 200.0:
		# Erster Frame oder Teleport (Respawn, Prüflauf): Kette hängt neu unter dem Anker
		_tail = PackedVector2Array()
		_tail_prev = PackedVector2Array()
		for i in TAIL_LINKS + 1:
			var p := anchor + Vector2(0.0, i * TAIL_SEG)
			_tail.append(p)
			_tail_prev.append(p)
		_tail_ready = true
		_tail_dt = maxf(dt, 0.0001)
		return
	var ratio := clampf(dt / maxf(_tail_dt, 0.0001), 0.0, 2.0)
	_tail_dt = maxf(dt, 0.0001)
	var damp := exp(-TAIL_DRAG * dt) * ratio
	var wind := Vector2(sin(_wind_t * 1.3) * 26.0 + sin(_wind_t * 3.1) * 12.0, 0.0)
	# Ruhelage leicht vom Rücken abgespreizt (Kapuzenstoff steht ab), sonst hängt der
	# Zipfel unsichtbar hinter dem Rumpf
	var away := Vector2(-player.facing * TAIL_AWAY, 0.0)
	var accel := Vector2(0.0, TAIL_GRAVITY) + wind + away
	for i in range(1, TAIL_LINKS + 1):
		var p := _tail[i]
		var vel := (p - _tail_prev[i]) * damp
		_tail_prev[i] = p
		_tail[i] = p + vel + accel * dt * dt
	_tail[0] = anchor
	_tail_prev[0] = anchor
	for _it in 3:
		for i in range(1, TAIL_LINKS + 1):
			var d := _tail[i] - _tail[i - 1]
			var l := d.length()
			if l > 0.001:
				_tail[i] = _tail[i - 1] + d / l * TAIL_SEG


## Kettenpunkte in lokale Zeichenkoordinaten (Spiegelung und Squash herausrechnen).
func _tail_local() -> PackedVector2Array:
	var out := PackedVector2Array()
	var sxi := 1.0 / (scale.x if absf(scale.x) > 0.01 else 1.0)
	var syi := 1.0 / (scale.y if absf(scale.y) > 0.01 else 1.0)
	for i in _tail.size():
		var rel := _tail[i] - global_position
		out.append(Vector2(rel.x * sxi, rel.y * syi))
	return out


func _draw_tail(pts: PackedVector2Array) -> void:
	var n := pts.size()
	if n < 2:
		return
	for pass_i in 2:
		var c := OUTLINE if pass_i == 0 else HOODIE_DARK
		var grow := 2.5 if pass_i == 0 else 0.0
		for i in range(1, n):
			var w := lerpf(9.0, 5.0, float(i - 1) / float(maxi(1, n - 2))) + grow
			draw_line(pts[i - 1], pts[i], c, w, true)
			draw_circle(pts[i - 1], w / 2.0, c)
			draw_circle(pts[i], w / 2.0, c)
	# Bommel: neutral-hell, macht die Spitze und damit die Bewegung lesbar
	var tip := pts[n - 1]
	draw_circle(tip, 5.4, OUTLINE)
	draw_circle(tip, 4.1, SHOE)
	draw_circle(tip + Vector2(-1.3, -1.3), 1.5, Color(1, 1, 1, 0.55))


# ------------------------------------------------------------------ Geisterspur

func _spawn_ghost(alpha: float) -> void:
	if _pose.is_empty():
		return
	var parent := player.get_parent()
	if parent == null:
		return
	var g := Ghost.new()
	g.pose = _pose.duplicate(true)
	g.alpha = alpha
	g.scale = scale
	g.z_index = player.z_index - 1
	g.light_mask = light_mask
	parent.add_child(g)
	g.global_position = global_position


## Ein eingefrorenes Nachbild: CanvasGroup, damit die halbtransparente Silhouette
## als EINE Fläche verblasst (keine sichtbaren Überlappungen der Glieder).
class Ghost extends CanvasGroup:
	var pose := {}
	var alpha := 0.5
	var _t := 0.0
	var _sil: Node2D

	func _ready() -> void:
		_sil = _GhostShape.new()
		_sil.pose = pose
		add_child(_sil)
		self_modulate.a = alpha

	func _process(delta: float) -> void:
		_t += delta
		if _t >= PaulVisual.GHOST_LIFE:
			queue_free()
			return
		self_modulate.a = alpha * (1.0 - _t / PaulVisual.GHOST_LIFE)


class _GhostShape extends Node2D:
	var pose := {}

	func _draw() -> void:
		PaulVisual.draw_silhouette(self, pose, PaulVisual.GHOST_FILL, PaulVisual.GHOST_EDGE)


## Flache Silhouette der Figur aus einer Pose (für Nachbilder und Schmierkopie).
static func draw_silhouette(ci: CanvasItem, p: Dictionary, fill: Color, edge: Color) -> void:
	if p.is_empty():
		return
	var hips: PackedVector2Array = p["hips"]
	var feet: PackedVector2Array = p["feet"]
	var hands: PackedVector2Array = p["hands"]
	var shoulder: Vector2 = p["shoulder"]
	var torso: Rect2 = p["torso"]
	var hood: Rect2 = p["hood"]
	var head: Rect2 = p["head"]
	var tail: PackedVector2Array = p["tail"]
	for pass_i in 2:
		var c := edge if pass_i == 0 else fill
		var grow := 2.5 if pass_i == 0 else 0.0
		for i in range(1, tail.size()):
			_sil_line(ci, tail[i - 1], tail[i], 7.0 + grow, c)
		if tail.size() > 0:
			ci.draw_circle(tail[tail.size() - 1], 4.1 + grow * 0.5, c)
		for i in 2:
			var knee := _ik(hips[i], feet[i], 11.0, 11.0, LEG_BEND)
			_sil_line(ci, hips[i], knee, 7.0 + grow, c)
			_sil_line(ci, knee, feet[i] + Vector2(0, -3), 6.5 + grow, c)
			_sil_round(ci, Rect2(feet[i].x - 5.0, feet[i].y - 5.0, 12.0, 6.0).grow(grow * 0.5), c, 3.0)
		_sil_round(ci, torso.grow(grow * 0.6), c, 7.0)
		_sil_round(ci, hood.grow(grow * 0.6), c, 9.0)
		for i in 2:
			var s := shoulder + Vector2(-8.0 if i == 0 else 8.0, 0.0)
			var elbow := _ik(s, hands[i], 9.0, 9.0, ARM_BEND)
			_sil_line(ci, s, elbow, 6.0 + grow, c)
			_sil_line(ci, elbow, hands[i], 5.5 + grow, c)
			ci.draw_circle(hands[i], 3.2 + grow * 0.5, c)
		_sil_round(ci, head.grow(grow * 0.6), c, 8.0)


static func _sil_line(ci: CanvasItem, a: Vector2, b: Vector2, w: float, c: Color) -> void:
	ci.draw_line(a, b, c, w, true)
	ci.draw_circle(a, w / 2.0, c)
	ci.draw_circle(b, w / 2.0, c)


static func _sil_round(ci: CanvasItem, r: Rect2, c: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


# ------------------------------------------------------------------ Zeichnen

func _draw() -> void:
	if player == null or _pose.is_empty():
		return
	var p := _pose
	var st := player.state
	var duck: bool = p["duck"]

	# Kontaktschatten: verankert Paul am Boden, schrumpft und verblasst mit der Höhe
	var gd := clampf(player.ground_distance, 0.0, 320.0)
	var sh_a := 0.32 * (1.0 - gd / 320.0)
	if sh_a > 0.01:
		var sh_s := 1.0 - gd / 640.0
		draw_set_transform(Vector2(0, gd + 1.0), 0.0, Vector2(sh_s, 0.28 * sh_s))
		draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, sh_a))
		draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, sh_a * 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Hülle-Schale (Spielfeld-Lesbarkeit der Kernmechanik)
	if player.huelle_enabled:
		_draw_shell(duck)

	# Schmierstreckung im schnellen Fall: eine weiche Kapsel zieht nach oben nach
	if _fall > 0.04:
		var head_top: float = p["head_top"]
		var hip_y: float = p["hip_y"]
		var up := 26.0 * _fall
		var smear := Rect2(-10.0, head_top - up, 20.0, hip_y - head_top + up + 10.0)
		_sil_round(self, smear, Color(HOODIE.r, HOODIE.g, HOODIE.b, 0.30 * _fall), 10.0)
		_sil_round(self, Rect2(-7.0, head_top - up * 0.55, 14.0, 12.0), Color(SKIN.r, SKIN.g, SKIN.b, 0.28 * _fall), 6.0)

	# Kapuzenzipfel hinter dem Körper
	_draw_tail(p["tail"])

	# Beine
	var hips: PackedVector2Array = p["hips"]
	var feet: PackedVector2Array = p["feet"]
	for i in 2:
		_draw_leg(hips[i], feet[i], i == 1)

	# Rumpf (Kapuzenpulli) mit Schattenseite rechts (Licht von oben links)
	var torso: Rect2 = p["torso"]
	_draw_round(torso, HOODIE, 7.0)
	draw_rect(Rect2(torso.position.x + torso.size.x * 0.55, torso.position.y + 3.0, torso.size.x * 0.45 - 3.0, torso.size.y - 6.0), Color(HOODIE_DARK.r, HOODIE_DARK.g, HOODIE_DARK.b, 0.55))
	draw_rect(Rect2(torso.position.x + 5.0, torso.end.y - 9.0, 14.0, 6.0), HOODIE_DARK)
	draw_rect(Rect2(torso.position.x + 3.0, torso.position.y + 3.0, 6.0, 3.0), Color(1, 1, 1, 0.25))
	# Kapuze hinter dem Kopf
	var hood: Rect2 = p["hood"]
	_draw_round(hood, HOODIE_DARK, 9.0)

	# Arme (hinterer Arm zuerst)
	var shoulder: Vector2 = p["shoulder"]
	var hands: PackedVector2Array = p["hands"]
	_draw_arm(shoulder + Vector2(-8, 0), hands[0], true)
	_draw_arm(shoulder + Vector2(8, 0), hands[1], false)

	# Kopf mit Schattenseite
	var head: Rect2 = p["head"]
	_draw_round(head, SKIN, 8.0)
	draw_rect(Rect2(head.position.x + head.size.x * 0.6, head.position.y + 6.0, head.size.x * 0.4 - 3.0, head.size.y - 9.0), Color(0.75, 0.50, 0.42, 0.35))
	# Haare
	var hx := head.position.x
	var hy := head.position.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(hx - 1, hy + 10), Vector2(hx + 2, hy + 2), Vector2(hx + 8, hy - 2),
		Vector2(hx + 16, hy - 1), Vector2(hx + 23, hy + 3), Vector2(hx + 25, hy + 9),
		Vector2(hx + 21, hy + 6), Vector2(hx + 14, hy + 4), Vector2(hx + 6, hy + 6),
	]), HAIR)
	# Gesicht (schaut in Laufrichtung: +x, weil scale.x spiegelt); Augen folgen dem Blick
	var eye_y := hy + 11.0 + _look.y * 1.2
	var eye_x := hx + 13.0 + _look.x * 1.3
	var hurt := st == Player.State.HURT
	var blink_scale := 0.15 if _blink > 0.0 else (0.45 if hurt else 1.0)
	draw_rect(Rect2(eye_x, eye_y - 2.0 * blink_scale, 3.0, 4.0 * blink_scale), EYE)
	draw_rect(Rect2(eye_x + 6.0, eye_y - 2.0 * blink_scale, 3.0, 4.0 * blink_scale), EYE)
	var mouth_x := hx + 15.0 + _look.x * 1.0
	if hurt:
		draw_line(Vector2(mouth_x - 1.0, eye_y + 7.0), Vector2(mouth_x + 6.0, eye_y + 6.0), EYE, 1.5, true)
	elif _fall > 0.55:
		# Schnellfall: kleines „oh"
		draw_circle(Vector2(mouth_x + 2.5, eye_y + 6.5), 1.7, EYE)
	else:
		draw_line(Vector2(mouth_x, eye_y + 6.0), Vector2(mouth_x + 5.0, eye_y + 6.0), EYE, 1.5, true)

	if flash > 0.0:
		var head_top: float = p["head_top"]
		draw_rect(Rect2(-16, head_top - 3, 32, -head_top + 4), Color(1, 1, 1, flash * 0.55))


func _draw_leg(hip: Vector2, foot: Vector2, front: bool) -> void:
	var knee := _ik(hip, foot, 11.0, 11.0, LEG_BEND)
	var c := PANTS if front else PANTS.darkened(0.25)
	_draw_limb(hip, knee, c, 7.0)
	_draw_limb(knee, foot + Vector2(0, -3), c, 6.5)
	# Schuh
	var sc := SHOE if front else SHOE.darkened(0.2)
	_draw_round(Rect2(foot.x - 5.0, foot.y - 5.0, 12.0, 6.0), sc, 3.0)


func _draw_arm(shoulder: Vector2, hand: Vector2, back: bool) -> void:
	var elbow := _ik(shoulder, hand, 9.0, 9.0, ARM_BEND)
	var c := HOODIE.darkened(0.25) if back else HOODIE
	_draw_limb(shoulder, elbow, c, 6.0)
	_draw_limb(elbow, hand, c, 5.5)
	draw_circle(hand, 3.2, SKIN if not back else SKIN.darkened(0.15))


## Zwei-Knochen-IK: Gelenkpunkt für Hüfte→Fuß bzw. Schulter→Hand.
## `bend` waehlt die Seite der Verbindungslinie: +1 dreht im Uhrzeigersinn (Bildschirm),
## -1 gegen ihn. Scharnier-Regel (lokal +x = vorn): Knie beugen nach vorn (Bein unten →
## Knie vor; Fuss vorn → Knie oben), Ellbogen nach hinten (Arm haengt → Ellbogen hinter;
## Hand vorn → Ellbogen unten; Hand oben → Ellbogen vorn). Das ergibt fuer jede Lage der
## Gliedmasse die anatomisch richtige Beugung — keine Ausnahmen pro Pose noetig.
static func _ik(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := a.distance_to(b)
	d = clampf(d, absf(l1 - l2) + 0.5, l1 + l2 - 0.5)
	var dir := (b - a).normalized() if d > 0.01 else Vector2.DOWN
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var ang := acos(cos_a) * bend
	return a + dir.rotated(ang) * l1


func _draw_limb(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	draw_line(a, b, OUTLINE, w + 2.5, true)
	draw_circle(a, (w + 2.5) / 2.0, OUTLINE)
	draw_circle(b, (w + 2.5) / 2.0, OUTLINE)
	draw_line(a, b, c, w, true)
	draw_circle(a, w / 2.0, c)
	draw_circle(b, w / 2.0, c)


func _draw_round(r: Rect2, c: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	sb.border_color = OUTLINE
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _draw_shell(duck: bool) -> void:
	var s := player.huelle.state
	if s == Huelle.KLARTEXT:
		return
	var c := Huelle.color_of(s)
	var pulse := 0.55 + 0.25 * sin(_shell_pulse * 4.0)
	var h := 52.0 if duck else 78.0
	var r := Rect2(-24.0, -h - 6.0, 48.0, h + 10.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c.r, c.g, c.b, 0.08)
	sb.set_corner_radius_all(22)
	sb.border_color = Palette.glow(Color(c.r, c.g, c.b, pulse), 1.6)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	# Hex-Schimmer: kleine Sechsecke, die langsam aufsteigen
	for i in 5:
		var t := fmod(_shell_pulse * 0.35 + i * 0.2, 1.0)
		var px := -16.0 + i * 8.0 + sin(_shell_pulse * 2.0 + i) * 3.0
		var py := r.end.y - t * r.size.y
		var a := (1.0 - t) * 0.6
		_hex(Vector2(px, py), 3.0, Color(c.r, c.g, c.b, a))


func _hex(center: Vector2, radius: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(center + Vector2(radius, 0).rotated(k * PI / 3.0))
	pts.append(pts[0])
	draw_polyline(pts, c, 1.2, true)
