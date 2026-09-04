class_name Level
extends Node2D
## LEVEL — baut ein Stationslevel aus LevelData: Kulisse, Gelände, Paul, REZI,
## Bausteine, Kamera, Licht. Kennt nur den Baukasten und die Kameramodi
## (horizontal = Follow, tube = Auto-Scroll-Korridor).
## Impact-Reaktionen (Aufprall, Treffer, Siegel, Tor) laufen hier zusammen:
## Kamera-Kick, Post-Impuls, Lichtblitz, Zeitlupe.
## Licht: Sonne (Schattenfarbe der Welt), REZI-Leitlicht, Sonnenstand driftet
## über die Stationen einer Welt; Wetter (Regen, Blitz) liegt in Weather.gd.
## Entwicklungsschalter: `--start-at=<baustein-typ>` setzt Paul auf den ersten
## Baustein dieses Typs (z. B. `--start-at=vau-feld` für den Prüflauf).

signal completed(result: Dictionary)

const REGISTRY := {
	"collectible": Basics.Collectible, "bonus": Basics.Collectible, "checkpoint": Basics.Checkpoint,
	"door-exit": Basics.DoorExit, "spring": Basics.Spring, "spike": Basics.Spike,
	"info-sign": Basics.InfoSign, "moving-platform": Basics.MovingPlatform, "hazard": Basics.Hazard,
	"gate": Basics.Gate, "deco": Basics.Deco,
}

var data: LevelData
var pal: Palette
var player: Player
var rezi: Rezi
var camera: GameCamera
var terrain: Terrain
var backdrop: Backdrop
var gates := {}
var mechanics: Array = []
var scroll_locks: Array[Callable] = []
var level_time := 0.0
var finished := false
var tube_speed := 0.0
var _tube_x := 0.0
var _max_progress := 0.0
var _last_progress := 0.0
var _last_stuck_tip := -100.0
var _started := false
var sun: DirectionalLight2D
var weather: Weather
static var _world_cache := {}


func setup(level_data: LevelData) -> void:
	data = level_data
	pal = Palette.from_theme(Game.theme(data.theme_name), data.theme_name)
	Game.mark_level_start()
	var w := data.world_width()
	var h := data.world_height()
	if Fx.post:
		Fx.post.grade_for(pal)
	# Sonnenstand driftet über die Stationen einer Welt: Morgen früh sieht anders
	# aus als Morgen spät (Palette.sun_drift je weiterer Station derselben Welt)
	var station := _station_in_world()
	pal.sun_pos = Vector2(clampf(pal.sun_pos.x + pal.sun_drift.x * station, 0.06, 0.94),
		clampf(pal.sun_pos.y + pal.sun_drift.y * station, 0.0, 0.6))

	# Grundlicht der Welt (Tageszeit), dazu die Sonne als gerichtetes Licht mit Schatten
	var cm := CanvasModulate.new()
	cm.color = pal.ambient
	add_child(cm)
	# Mischlicht statt additiv: tönt warm und wirft Schatten, überstrahlt aber nie
	sun = DirectionalLight2D.new()
	sun.color = pal.sun
	sun.energy = pal.sun_energy
	sun.height = 0.75
	sun.blend_mode = Light2D.BLEND_MODE_MIX
	sun.range_item_cull_mask = 1
	sun.shadow_enabled = pal.sun_shadow > 0.0
	# Schatten sind gefärbt, nicht schwarz: kühl (Hue-Shift), das Licht bleibt warm
	sun.shadow_color = pal.shadow_for_light(pal.sun_shadow)
	sun.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	sun.shadow_filter_smooth = 8.0
	# Lichtrichtung: von der Sonne im Bild Richtung Boden
	var from := Vector2(pal.sun_pos.x - 0.5, pal.sun_pos.y - 0.5)
	sun.rotation = (Vector2(0.15, 1.0) - from * 1.2).angle() - PI / 2.0
	add_child(sun)

	backdrop = Backdrop.new()
	backdrop.build(pal, w, h, data.id)
	add_child(backdrop)

	terrain = Terrain.new()
	terrain.build(data, pal)
	add_child(terrain)

	player = Player.new()
	player.global_position = data.spawn_point()
	player.world_bottom = h
	player.z_index = 10
	add_child(player)
	player.huelle_enabled = data.huelle_enabled
	if data.huelle_enabled:
		player.huelle.toggle_cooldown = data.huelle_cooldown_ms / 1000.0
		player.huelle.reset(Huelle.VERSCHLUESSELT if data.huelle_start == "verschluesselt" else Huelle.KLARTEXT)
		player.huelle.changed.connect(_on_huelle_changed)
	player.bits_scattered.connect(_scatter_bits, CONNECT_DEFERRED)
	player.landed.connect(_on_landed)
	player.jumped.connect(func(): Fx.dust(self, player.global_position, 3, 0.8))
	player.double_jumped.connect(_on_double_jump)
	player.wall_jumped.connect(func(): Fx.dust(self, player.global_position + Vector2(-player.facing * 14, -30), 4, 1.0))
	player.got_hurt.connect(_on_hurt)

	rezi = Rezi.new()
	add_child(rezi)
	rezi.follow(player)
	rezi.base_energy = pal.rezi_energy
	for s in Game.seals:
		rezi.add_seal(s["seal_id"])
	rezi.set_encrypted(Game.encrypted)
	# REZIs Leitlicht wirft die Schattenfarbe der Welt (statt schwarz)
	if rezi.light:
		rezi.light.shadow_color = pal.shadow_for_light(0.42)
	# Browser: kein HDR-Glühen — additiver Hof ersetzt das Leuchten der Kapsel
	if Fx.web_fallback():
		Fx.glow_sprite(rezi, Color(0.62, 0.90, 1.0), 64.0, 0.9)

	var objs: Array = []
	for m in data.markers:
		if m["type"] == "spawn":
			continue
		objs.append({"type": m["type"], "tx": m["tx"], "ty": m["ty"], "tw": 1, "th": 1})
	var all: Array = data.objects.duplicate()
	all.sort_custom(func(a, b): return a["type"] == "gate" and b["type"] != "gate")
	for o in all:
		objs.append(o)
	for o in objs:
		_spawn_mechanic(o)
	_apply_start_at()

	camera = GameCamera.new()
	add_child(camera)
	camera.setup(player, w, h)
	if data.camera_mode == "tube":
		var tp: Dictionary = data.mechanics.get("tube-scroll", {})
		tube_speed = float(tp.get("speed", 50)) * 3.0
		camera.manual = true
		_tube_x = 0.0
		camera.global_position = Vector2(960, 540)
	# Wetter im offenen Netz: Regen (mit Spritzern) und seltene Blitze, zieht mit der Kamera
	if pal.weather == "regen":
		weather = Weather.new()
		camera.add_child(weather)
		weather.build(pal, sun)
	_max_progress = player.global_position.x
	_started = true
	# Zwei Level-Stücke: Chiptune in Praxis/Zugang, Synthwave im Rechenzentrum und Archiv
	Sfx.music("music_level2" if data.theme_name in ["zentrale-zone", "akte"] else "music_level")


## Wievielte Station dieser Welt ist das aktuelle Level (0 = erste)? Zählt in der
## Playlist alle vorherigen Level derselben Welt (für die Sonnendrift).
func _station_in_world() -> int:
	var k := 0
	var upto := mini(Game.level_index, Game.playlist.size())
	for i in upto:
		if _world_of(str(Game.playlist[i])) == pal.world_name:
			k += 1
	return k


## Welt eines Levels aus dessen level.json (nur das Thema, gecacht).
static func _world_of(level_id: String) -> String:
	if _world_cache.has(level_id):
		return str(_world_cache[level_id])
	var wn := ""
	var dir := LevelData.level_dir(level_id)
	if dir != "":
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir + "level.json"))
		if parsed is Dictionary:
			var tn := str(parsed.get("theme", "city"))
			wn = Palette.from_theme(Game.theme(tn), tn).world_name
	_world_cache[level_id] = wn
	return wn


## Entwicklung/Prüflauf: `--start-at=<typ>` setzt Paul auf den ersten Baustein dieses Typs.
func _apply_start_at() -> void:
	for a in OS.get_cmdline_user_args():
		if not str(a).begins_with("--start-at="):
			continue
		var want := str(a).get_slice("=", 1)
		for m in mechanics:
			if is_instance_valid(m) and m.type == want:
				player.global_position = Vector2(m.rect.get_center().x, m.rect.end.y - 2.0)
				player.set_respawn(player.global_position)
				return


func _spawn_mechanic(o: Dictionary) -> void:
	var t := str(o.get("type", ""))
	var mech_script = REGISTRY.get(t, null)
	if mech_script == null:
		mech_script = Stations.REGISTRY.get(t, null)
	if mech_script == null:
		push_warning("Unbekannter Baustein '%s' - uebersprungen (die Messe crasht nie)." % t)
		return
	var m: Mechanic = mech_script.new()
	if t == "bonus":
		m.set("bonus", true)
	add_child(m)
	m.setup(self, o)
	mechanics.append(m)


func _process(delta: float) -> void:
	if not _started:
		return
	if not finished:
		level_time += delta
		if data.huelle_enabled and Input.is_action_just_pressed("toggle"):
			player.try_toggle_huelle()
	for m in mechanics:
		if is_instance_valid(m):
			m.tick(delta)
	if data.camera_mode == "tube" and not finished:
		_update_tube(delta)
	if not finished:
		_check_stuck(delta)


# ------------------------------------------------------------- Impact-Reaktionen

func _on_landed(impact: float) -> void:
	# Staub rollt seitlich weg — Menge und Weite wachsen mit dem Aufprall
	Fx.land_dust(self, player.global_position, impact)
	if impact > 0.45:
		camera.kick(Vector2(0, 90.0 * impact))
		Fx.impact(impact * 0.5)
		# Flacher, breiter Ring am Boden statt Kreis um die Füße
		Fx.ring(self, player.global_position + Vector2(0, -4), Color(0.8, 0.88, 1.0), 30.0 + 70.0 * impact, 1.5 + impact)


func _on_hurt(_lost: int) -> void:
	camera.kick(Vector2(player.facing * -60, -30))
	rezi.scared()
	Fx.flash(Palette.DENY, 0.28)
	Fx.impact(1.0)
	Fx.light_burst(self, player.global_position + Vector2(0, -30), Palette.DENY, 260.0, 1.4, 0.4)


func _on_huelle_changed(_from: String, to: String, reason: String) -> void:
	Game.hud_changed.emit()
	var c := Huelle.color_of(to)
	Fx.ring(self, player.global_position + Vector2(0, -32), c, 80.0)
	Fx.light_burst(self, player.global_position + Vector2(0, -32), c, 300.0, 1.3, 0.5)
	Fx.impact(0.3)
	if reason == "session-expired":
		Fx.float_text(self, player.global_position + Vector2(0, -80), "SITZUNG ABGELAUFEN", Palette.WARM, 24)
		Sfx.play("deny", 0.9, -4.0)
		Fx.flash(Palette.WARM, 0.15)
	elif reason == "enter-vau":
		Sfx.play("vau")
		Fx.flash(Palette.VAU, 0.12)


func _on_double_jump() -> void:
	rezi.swoop()
	Fx.sparkle(self, player.global_position, Palette.COOL, 10, 240.0)
	Fx.ring(self, player.global_position + Vector2(0, 6), Palette.COOL, 50.0)
	Fx.light_burst(self, player.global_position, Palette.COOL, 220.0, 1.2, 0.35)


func on_collected(_c: Node) -> void:
	pass


## Verstreute Bits sind ECHTE Objekte und wieder einsammelbar (Anti-Softlock).
func _scatter_bits(pos: Vector2, count: int) -> void:
	for i in count:
		var b := ScatteredBit.new()
		b.global_position = pos
		b.velocity = Vector2(randf_range(-260, 260), randf_range(-560, -360))
		add_child(b)


func complete_level() -> void:
	if finished:
		return
	finished = true
	player.controls_locked = true
	player.velocity.x = 0.0
	Game.add_seal(data.seal_icon, data.id)
	rezi.add_seal(data.seal_icon)
	rezi.say(Game.t(data.station.get("reziText", "")), 3.5)
	Sfx.play("seal")
	Sfx.music_duck()
	# Der große Moment: Blitz, Zeitlupe, Zoom, Lichtwelle
	Fx.flash(Color(1, 0.96, 0.85), 0.5)
	Fx.slowmo(get_tree(), 0.25, 0.5)
	camera.punch(0.12)
	camera.kick(Vector2(0, -90))
	Fx.burst(self, rezi.global_position, Palette.GOLD, 34, 420.0)
	Fx.ring(self, rezi.global_position, Palette.GOLD, 160.0, 4.0)
	Fx.ring(self, rezi.global_position, Palette.WHITE, 260.0, 2.0)
	# Lichtwelle: kräftiger Kern, der schnell abklingt, plus weiter, weicher Hof
	Fx.light_burst(self, rezi.global_position, Palette.GOLD, 300.0, 2.0, 0.6)
	Fx.light_burst(self, rezi.global_position, Palette.tint(Palette.GOLD, 0.4), 560.0, 1.1, 1.3)
	var result := Game.finish_level(data.id, level_time, data.par_time, data.bits_total)
	await get_tree().create_timer(1.8).timeout
	completed.emit(result)


func register_scroll_lock(c: Callable) -> void:
	scroll_locks.append(c)


## Tunnel-Kamera: fährt von selbst nach rechts, aber elastisch — sie lässt Paul nie
## hinter dem linken Rand zurück (wartet, sobald er TUBE_RAND vom Rand steht, z. B.
## auf dem Prüf-Podest) und eilt ihm nie davon. Früher wurde Paul am Rand per
## Teleport mitgezogen — mitten in Wände und aus dem Bild hinaus.
const TUBE_RAND := 150.0

func _update_tube(delta: float) -> void:
	var view_w := 1920.0
	var held := false
	for c in scroll_locks:
		if c.call():
			held = true
	if not held:
		_tube_x += tube_speed * delta
	var px := player.global_position.x
	_tube_x = minf(_tube_x, px - TUBE_RAND)            # wartet auf Paul
	_tube_x = maxf(_tube_x, px - view_w * 0.55)          # eilt nicht davon
	_tube_x = clampf(_tube_x, 0.0, data.world_width() - view_w)
	camera.global_position = Vector2(_tube_x + view_w / 2.0, data.world_height() / 2.0)
	# rechter Rand bleibt eine weiche Grenze (Physik, kein Teleport)
	var max_x := _tube_x + view_w - 40.0
	if px > max_x and player.velocity.x > 0:
		player.velocity.x = 0


func _check_stuck(_delta: float) -> void:
	if player.global_position.x > _max_progress + 12.0:
		_max_progress = player.global_position.x
		_last_progress = level_time
		return
	if player.controls_locked or Kiosk.idle_seconds() > 5.0:
		_last_progress = level_time
		return
	if level_time - _last_progress >= 18.0 and level_time - _last_stuck_tip >= 20.0:
		_last_stuck_tip = level_time
		var fallback := "Weiter nach rechts! %s = springen · %s = TI-Aktion" % [Kiosk.label_jump(), Kiosk.label_action()]
		rezi.say(Game.t(data.stuck_hint, fallback) if data.stuck_hint != null else fallback, 4.0)


## Verstreutes Bit: hüpft, bleibt liegen, wieder einsammelbar (ohne Punkte).
class ScatteredBit extends CharacterBody2D:
	var _age := 0.0
	var _grav := 2400.0
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		var cs := CollisionShape2D.new()
		var s := CircleShape2D.new()
		s.radius = 8.0
		cs.shape = s
		add_child(cs)
		z_index = 7
		Fx.light(self, Vector2.ZERO, Palette.COOL, 60.0, 0.5)

	func _physics_process(delta: float) -> void:
		_age += delta
		_t += delta
		if not is_on_floor():
			velocity.y += _grav * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if velocity.y > 0:
				velocity.y = -velocity.y * 0.45
				if absf(velocity.y) < 60.0:
					velocity.y = 0.0
		move_and_slide()
		if _age > 0.7:
			var lvl := get_parent() as Level
			if lvl and lvl.player and global_position.distance_to(lvl.player.global_position + Vector2(0, -30)) < 40.0:
				Game.bits += 1
				Game.hud_changed.emit()
				Fx.sparkle(lvl, global_position, Palette.COOL, 6, 140.0)
				Sfx.play("collect", 0.9, -4.0)
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 if _age < 0.7 else 0.65 + 0.35 * sin(_t * 6.0)
		draw_circle(Vector2.ZERO, 6.0, Palette.glow(Color(Palette.COOL.r, Palette.COOL.g, Palette.COOL.b, a), 1.5))
