class_name Player
extends CharacterBody2D
## PAUL — der Spieler. Zustandsmaschine mit dem kompletten „Game Feel"-Paket
## der Celeste/Mario-Schule:
##   • Beschleunigung/Abbremsen mit Luft-Momentum
##   • Coyote-Time, Jump-Buffer, variable Sprunghöhe, Scheitel-Schweben,
##     schwereres Fallen, Kanten-Korrektur beim Kopf-Bonk
##   • REZI-Schub (Doppelsprung, roter Knopf in der Luft — „die TI trägt dich")
##   • Wandrutschen + Wandsprung
##   • Ducken mit eigener Hitbox, Squash & Stretch, Hitstop bei Treffern
## Kein Tod — Treffer kosten Datenbits (Sonic-Prinzip).

signal jumped
signal double_jumped
signal wall_jumped
signal landed(impact: float)
signal got_hurt(lost: int)
signal bits_scattered(pos: Vector2, count: int)
signal state_changed(state: String)

## Bewegungswerte nach Celeste (Player.cs), mit Faktor 6 von 8-px- auf 48-px-Kacheln
## skaliert: MaxRun 90 → 540, RunAccel 1000 → 6000, AirMult 0,65, Gravity 900 → 5400,
## MaxFall 160 → 960, FastMaxFall 240 → 1440, JumpSpeed 105 → 630, JumpHBoost 40 → 240,
## VarJumpTime 0,2 s, HalfGravThreshold 40 → 240, JumpGraceTime 0,1 s.
## Sprunghöhe ≈ 3,4 Kacheln, Weite ≈ 6,3 Kacheln — die Baukasten-Grenzen bleiben gültig.
const T := {
	"run_speed": 540.0, "duck_speed": 0.45,
	"accel": 6000.0, "air_mult": 0.65,
	"jump_velocity": 630.0, "var_jump_time": 0.2, "half_grav": 240.0, "jump_hboost": 240.0,
	"double_jump_velocity": 560.0, "gravity": 5400.0, "max_fall": 960.0, "fast_fall": 1440.0,
	"coyote": 0.10, "buffer": 0.10, "corner_px": 15.0,
	"wall_slide": 240.0, "wall_jump_x": 780.0, "wall_jump_y": 630.0, "wall_lock": 0.16,
	"hurt_invuln": 1.1, "hurt_knockback": 420.0, "hurt_bits": 5, "hitstop": 0.07,
	"body_w": 30.0, "body_h": 63.0, "duck_h": 39.0,
}

enum State { IDLE, RUN, JUMP, FALL, DUCK, HURT, WALL }

var state: State = State.IDLE
## Blickrichtung (+1 rechts, -1 links). Am Boden folgt sie der tatsaechlichen Bewegung,
## in der Luft der Eingabe; Ausnahmen: Wandsprung (Wandnormale, solange es von der Wand
## weggeht) und Treffer (Blick zum Angreifer). Darf von aussen gesetzt werden (Titel).
var facing := 1
## Bremsen: am Boden wird gegen die Laufrichtung gedrueckt. Der Blick bleibt in
## Laufrichtung und PaulVisual zeigt die Bremspose, bis die Geschwindigkeit die
## Richtung wechselt - reine Optik, die Physik bremst wie bisher.
var brake := false
var controls_locked := false
## Autopilot: Probelauf-Screen steuert Paul per Choreografie (statt Input).
var autopilot := false
var auto_axis := 0.0
var auto_jump := false
var auto_jump_held := false
var respawn_point := Vector2.ZERO
var huelle := Huelle.new()
var huelle_enabled := false
var visual: PaulVisual
var shape: CollisionShape2D
var world_bottom := 2000.0
var vy_before := 0.0
## Abstand der Füße zum Boden darunter (für den Kontaktschatten).
var ground_distance := 0.0

var _coyote := 0.0
var _buffer := 0.0
var _var_jump := 0.0
var _can_double := true
var _wall_lock := 0.0
var _invuln_until := 0.0
var _hurt_left := 0.0
var _was_on_floor := false
var _ducking := false
var _wall_sliding := false
var _run_dust := 0.0
var _jump_held_grace := 0.0
## Nach dem Wandsprung: Richtung der Wandnormale, solange Paul noch von der Wand wegfliegt
var _wall_away := 0
## Ab dieser Geschwindigkeit gilt eine Bewegungsrichtung (gleich der RUN-Schwelle,
## damit Blick und Zustand nie auseinanderlaufen; kein Flackern um Null)
const FACE_EPS := 30.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(46)
	floor_constant_speed = true
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(T.body_w, T.body_h)
	shape.shape = rect
	shape.position = Vector2(0, -T.body_h / 2)
	add_child(shape)
	visual = PaulVisual.new()
	visual.player = self
	add_child(visual)
	respawn_point = global_position


var is_ducking: bool:
	get: return _ducking

var is_invulnerable: bool:
	get: return Time.get_ticks_msec() / 1000.0 < _invuln_until

var is_sichtbar: bool:
	get: return huelle.sichtbar if huelle_enabled else true

var is_andockfaehig: bool:
	get: return huelle.andockfaehig if huelle_enabled else true


func try_toggle_huelle() -> bool:
	if not huelle_enabled or controls_locked:
		return false
	var ok := huelle.toggle()
	if ok:
		Sfx.play("toggle_on" if huelle.state == Huelle.VERSCHLUESSELT else "toggle_off")
		visual.flash = 0.6
		visual.squash = Vector2(1.15, 0.9)
	return true


func _physics_process(delta: float) -> void:
	if huelle_enabled:
		huelle.tick(delta)
	var on_floor := is_on_floor()
	var now := Time.get_ticks_msec() / 1000.0
	if on_floor:
		_coyote = T.coyote
		_can_double = true
	else:
		_coyote -= delta
	_wall_lock = maxf(0.0, _wall_lock - delta)
	_hurt_left = maxf(0.0, _hurt_left - delta)

	var locked := controls_locked or _hurt_left > 0.0
	# Autopilot (Probelauf-Screen): Choreografie statt Spieler-Eingabe
	var ax := 0.0
	var jump_now := false
	var held := false
	var wants_duck := false
	if not locked:
		if autopilot:
			ax = auto_axis
			jump_now = auto_jump
			held = auto_jump_held
		else:
			ax = Input.get_axis("move_left", "move_right")
			jump_now = Input.is_action_just_pressed("jump")
			held = Input.is_action_pressed("jump")
			wants_duck = on_floor and Input.is_action_pressed("move_down")
	auto_jump = false
	if jump_now:
		_buffer = T.buffer
	else:
		_buffer -= delta
	_set_ducking(wants_duck)

	# --- Horizontalbewegung (Celeste: gleiche Beschleunigung für Anlauf und Stopp,
	#     in der Luft ×0,65 — Momentum, aber jederzeit korrigierbar) ---
	var factor := huelle.speed_factor if huelle_enabled else 1.0
	var speed: float = T.run_speed * factor * (T.duck_speed if _ducking else 1.0)
	var mult: float = 1.0 if on_floor else T.air_mult
	if _wall_lock > 0.0:
		pass # Wandsprung: kurz keine Steuerung, damit der Absprung Weite bekommt
	else:
		if absf(velocity.x) > speed and signf(velocity.x) == signf(ax):
			velocity.x = move_toward(velocity.x, ax * speed, T.accel * 0.4 * mult * delta)
		else:
			velocity.x = move_toward(velocity.x, ax * speed, T.accel * mult * delta)
	_update_facing(on_floor, ax)

	# --- Wandrutschen: nur wenn man gegen die Wand drückt ---
	_wall_sliding = false
	if not on_floor and is_on_wall_only() and velocity.y > 0.0 and ax != 0.0:
		var n := get_wall_normal()
		if signf(ax) == -signf(n.x):
			_wall_sliding = true

	# --- Springen: Buffer + Coyote, Wandsprung, REZI-Schub ---
	if _buffer > 0.0 and not _ducking and _hurt_left <= 0.0:
		if _coyote > 0.0:
			_do_jump(T.jump_velocity)
			velocity.x += T.jump_hboost * ax
			jumped.emit()
		elif _wall_sliding:
			var n := get_wall_normal()
			velocity.x = n.x * T.wall_jump_x
			velocity.y = -T.wall_jump_y
			_var_jump = T.var_jump_time
			facing = 1 if n.x > 0 else -1
			_wall_away = facing
			brake = false
			_wall_lock = T.wall_lock
			_buffer = 0.0
			_can_double = true
			visual.squash = Vector2(0.8, 1.22)
			Sfx.play("jump", 1.15)
			wall_jumped.emit()
		elif _can_double:
			_can_double = false
			_do_jump(T.double_jump_velocity)
			_var_jump = 0.14
			# REZI-Schub: stärkere Streckung und eingefrorene Nachbilder der Silhouette
			visual.squash = Vector2(0.78, 1.26)
			visual.ghost_burst(5)
			Sfx.play("double_jump")
			double_jumped.emit()

	# --- Sprungkurve (Celeste): variable Höhe über gehaltene Aufwärtsgeschwindigkeit,
	#     halbe Schwerkraft am Scheitel, gedeckelte Fallgeschwindigkeit, Schnellfall ---
	if on_floor and velocity.y > 0.0:
		velocity.y = 0.0
	if not on_floor:
		if _var_jump > 0.0:
			_var_jump -= delta
			if held:
				velocity.y = minf(velocity.y, -T.jump_velocity if _var_jump > 0.0 else velocity.y)
			else:
				_var_jump = 0.0
		var g_mult := 0.5 if (held and absf(velocity.y) < T.half_grav) else 1.0
		var down := not locked and Input.is_action_pressed("move_down")
		var max_fall: float = T.fast_fall if down else T.max_fall
		velocity.y = move_toward(velocity.y, max_fall, T.gravity * g_mult * delta)
		if _wall_sliding:
			velocity.y = minf(velocity.y, T.wall_slide)

	vy_before = velocity.y
	var was_on_floor := on_floor
	move_and_slide()
	_corner_correct()
	_measure_ground()

	# --- Landung ---
	if is_on_floor() and not was_on_floor:
		_wall_away = 0
		var impact := clampf(vy_before / T.max_fall, 0.0, 1.0)
		# Landungs-Squash proportional zur Aufprallstärke (leichter Hopser bis Vollbremsung)
		visual.squash = Vector2(1.0 + 0.30 * impact + 0.08, 1.0 - 0.26 * impact - 0.06)
		Sfx.play("land", 1.0 - 0.2 * impact, -6.0 + 6.0 * impact)
		landed.emit(impact)

	# --- Laufstaub ---
	if is_on_floor() and absf(velocity.x) > 150.0:
		_run_dust -= delta
		if _run_dust <= 0.0:
			_run_dust = 0.17
			Fx.dust(get_parent(), global_position - Vector2(facing * 12, 0), 1, 0.6)

	# --- Zustand ---
	var prev := state
	if _hurt_left > 0.0:
		state = State.HURT
	elif _ducking:
		state = State.DUCK
	elif _wall_sliding:
		state = State.WALL
	elif not is_on_floor():
		state = State.JUMP if velocity.y < -40.0 else State.FALL
	elif absf(velocity.x) > 30.0:
		state = State.RUN
	else:
		state = State.IDLE
	if state != prev:
		state_changed.emit(State.keys()[state])

	# Sicherheitsnetz: unter die Karte gefallen
	if global_position.y > world_bottom + 200.0:
		respawn()


func _measure_ground() -> void:
	if is_on_floor():
		ground_distance = 0.0
		return
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), global_position + Vector2(0, 700), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	ground_distance = (hit["position"].y - global_position.y) if not hit.is_empty() else 700.0


## Blickrichtung (siehe `facing`). Laeuft nach der Horizontalbewegung, also mit der
## Geschwindigkeit dieses Ticks. Keine Latenz: Aus dem Stand dreht Paul sofort mit der
## Eingabe; bei Tempo bleibt er bis zum Nulldurchgang in Laufrichtung (Bremspose) und
## dreht genau dann um, wenn die Bewegung kippt.
func _update_facing(on_floor: bool, ax: float) -> void:
	var was_braking := brake
	brake = false
	if _hurt_left > 0.0 or _wall_lock > 0.0:
		return # Treffer: Blick zum Angreifer (hurt); Wandsprung-Sperre: Wandnormale
	if on_floor:
		_wall_away = 0
		var mv := 0
		if absf(velocity.x) > FACE_EPS:
			mv = 1 if velocity.x > 0.0 else -1
		if mv != 0:
			brake = ax != 0.0 and (ax > 0.0) != (mv > 0)
			if facing != mv:
				_turn(mv, was_braking)
		elif ax != 0.0:
			var want := 1 if ax > 0.0 else -1
			if want != facing:
				_turn(want, was_braking)
		if brake and not was_braking:
			# Bremsstaub am gestemmten vorderen Fuss
			Fx.dust(get_parent(), global_position + Vector2(facing * 10, 0), 3, 0.7)
	else:
		if _wall_away != 0 and velocity.x * float(_wall_away) > 0.0:
			facing = _wall_away
		else:
			_wall_away = 0
			if ax != 0.0:
				facing = 1 if ax > 0.0 else -1


## Umdrehen am Boden: nach dem Bremsen ein kraeftiger Abdruck-Squash mit Staub,
## aus dem Stand nur ein kleiner Akzent.
func _turn(dir: int, from_brake: bool) -> void:
	facing = dir
	if from_brake:
		visual.squash = Vector2(1.16, 0.86)
		Fx.dust(get_parent(), global_position - Vector2(facing * 8, 0), 2, 0.5)
	else:
		visual.squash = Vector2(1.06, 0.95)


func _do_jump(v: float) -> void:
	velocity.y = -v
	_var_jump = T.var_jump_time
	_buffer = 0.0
	_coyote = 0.0
	# Absprung-Streckung: Impuls hier, den Rest hält PaulVisual über die Steiggeschwindigkeit
	visual.squash = Vector2(0.84, 1.16)
	Sfx.play("jump")


## Kanten-Korrektur: Kopf-Bonk knapp neben einer Kante → seitlich vorbeischieben.
func _corner_correct() -> void:
	if not is_on_ceiling() or vy_before > -20.0:
		return
	for step in [5.0, 10.0, 15.0]:
		if step > T.corner_px:
			break
		for dir in [facing, -facing]:
			var off := Vector2(dir * step, 0)
			var xf := global_transform.translated(off)
			if not test_move(xf, Vector2(0, -10)):
				global_position += off
				velocity.y = vy_before
				return


func _set_ducking(on: bool) -> void:
	if on == _ducking:
		return
	if not on:
		# Aufstehen nur, wenn oben Platz ist
		var xf := global_transform
		if test_move(xf, Vector2(0, -(T.body_h - T.duck_h) - 2)):
			return
	_ducking = on
	var rect := shape.shape as RectangleShape2D
	var h: float = T.duck_h if on else T.body_h
	rect.size = Vector2(T.body_w, h)
	shape.position = Vector2(0, -h / 2)


func bounce(v: float) -> void:
	velocity.y = -v
	_var_jump = 0.0
	_can_double = true
	visual.squash = Vector2(0.75, 1.3)


func set_respawn(p: Vector2) -> void:
	respawn_point = p


func respawn() -> void:
	global_position = respawn_point
	velocity = Vector2.ZERO
	visual.flash = 1.0


## Treffer: Bits spritzen weg, kurzer Rückstoß, Hitstop, Blinken.
func hurt(from_x: float) -> int:
	if is_invulnerable or controls_locked:
		return 0
	var now := Time.get_ticks_msec() / 1000.0
	_invuln_until = now + T.hurt_invuln
	_hurt_left = 0.35
	var dir := -1 if global_position.x < from_x else 1
	velocity = Vector2(dir * T.hurt_knockback, -420.0)
	# Blick zum Angreifer: der Koerper fliegt rueckwaerts weg, der Kopf bleibt beim Treffer.
	# (Level und REZI verlassen sich darauf: Kamera-Kick und REZIs Rueckzucker gehen
	# in -facing = Stossrichtung.)
	facing = -dir
	brake = false
	_wall_away = 0
	if state != State.HURT:
		state = State.HURT
		state_changed.emit(State.keys()[state])
	_set_ducking(false)
	Sfx.play("hurt")
	# Musik kurz und weich zurücknehmen, damit der Treffer Raum bekommt
	Sfx.music_duck(-6.0, 0.3)
	Fx.hitstop(get_tree(), T.hitstop)
	visual.blink_until = _invuln_until
	visual.flash = 1.0
	var lost := Game.lose_bits(T.hurt_bits)
	if lost > 0:
		bits_scattered.emit(global_position + Vector2(0, -30), lost)
	got_hurt.emit(lost)
	return lost
