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
var _stuck_tips := 0
var leitpfeil: Leitpfeil
## Ab dieser Zeit ohne Fortschritt zeigt der Leitpfeil den Weg (game-config.json
## „stuckGuideSeconds"; der erste REZI-Hinweis kommt nach STUCK_TIP_S).
const STUCK_TIP_S := 18.0
var stuck_guide_s := 30.0
var _started := false
var _verstreut_unterwegs := 0   # beim Treffer verloren, aber noch nicht als ScatteredBit da (deferred)
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
	player.respawned.connect(_on_respawned)

	rezi = Rezi.new()
	add_child(rezi)
	leitpfeil = Leitpfeil.new()
	leitpfeil.player = player
	add_child(leitpfeil)
	stuck_guide_s = float(Game.config.get("stuckGuideSeconds", 30))
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
	_cull_mechanics()
	for m in mechanics:
		if is_instance_valid(m):
			m.tick(delta)
	if data.camera_mode == "tube" and not finished:
		_update_tube(delta)
	if not finished:
		_check_stuck(delta)


## Zeichen-Culling: Bausteine außerhalb von Bild + CULL_RAND werden unsichtbar —
## Godot überspringt dann ihr _draw (und das ihrer Kinder) ganz. tick() läuft für
## alle weiter, damit Patrouillen, Tore und Sitzungen stimmen. Bis hierhin zeichnete
## jede Station in jedem Frame ALLE Bausteine neu, auch weit außerhalb des Bildes.
const CULL_RAND := Vector2(480.0, 360.0)

func view_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	if camera == null:
		return Rect2(Vector2.ZERO, size)
	var z := camera.zoom
	var welt := Vector2(size.x / maxf(z.x, 0.01), size.y / maxf(z.y, 0.01))
	return Rect2(camera.get_screen_center_position() - welt / 2.0, welt)


func _cull_mechanics() -> void:
	var sicht := view_rect().grow_individual(CULL_RAND.x, CULL_RAND.y, CULL_RAND.x, CULL_RAND.y)
	for m in mechanics:
		if is_instance_valid(m):
			var vis: bool = sicht.intersects(m.cull_rect())
			if m.visible != vis:
				m.visible = vis


# ------------------------------------------------------------- Impact-Reaktionen

func _on_landed(impact: float) -> void:
	# Staub rollt seitlich weg — Menge und Weite wachsen mit dem Aufprall
	Fx.land_dust(self, player.global_position, impact)
	if impact > 0.45:
		camera.kick(Vector2(0, 90.0 * impact))
		Fx.impact(impact * 0.5)
		# Flacher, breiter Ring am Boden statt Kreis um die Füße
		Fx.ring(self, player.global_position + Vector2(0, -4), Color(0.8, 0.88, 1.0), 30.0 + 70.0 * impact, 1.5 + impact)


## Sturz → Fahne: kurz aus dem Dunkeln aufblenden, Kamera sitzt sofort auf Paul.
func _on_respawned() -> void:
	Statistik.sturz()
	if camera:
		camera.snap()
	Fx.flash(Color(0.03, 0.05, 0.09), 0.9)
	Sfx.play("land", 0.8, -4.0)


func _on_hurt(lost: int) -> void:
	Statistik.treffer()
	_verstreut_unterwegs += lost
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


## Prüfsummen, die noch in der Station liegen: nicht eingesammelte (auch Bonus)
## plus verstreute. Für das Sicherheitsnetz der Tür (Basics.DoorExit).
func remaining_bits() -> int:
	var n := _verstreut_unterwegs
	for m in mechanics:
		if is_instance_valid(m) and m is Basics.Collectible and not m.taken:
			n += 1
	for c in get_children():
		if c is ScatteredBit:
			n += 1
	return n


## Verstreute Bits sind ECHTE Objekte und wieder einsammelbar (Anti-Softlock).
func _scatter_bits(pos: Vector2, count: int) -> void:
	_verstreut_unterwegs = maxi(0, _verstreut_unterwegs - count)
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
	var result := Game.finish_level(data.id, level_time, data.par_time, data.bits_total, data.hat_lauscher())
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
		_fortschritt()
		return
	# Wer still steht, ist nicht festgefahren (Idle) — und wer vor einer offenen
	# Station wartet (Schleuse, Stempel, Kartenleser …), macht genau das Richtige.
	if player.controls_locked or Kiosk.idle_seconds() > 5.0 or _wartet_an_station():
		_fortschritt()
		return
	var still := level_time - _last_progress
	if still >= STUCK_TIP_S and level_time - _last_stuck_tip >= 20.0:
		_last_stuck_tip = level_time
		_stuck_tips += 1
		var fallback := "Weiter nach rechts! %s = springen · %s = TI-Aktion" % [Kiosk.label_jump(), Kiosk.label_action()]
		var tip: String = Game.t(data.stuck_hint, fallback) if data.stuck_hint != null else fallback
		if still >= stuck_guide_s:
			tip = tr("Folge meinem Pfeil!")
		rezi.say(tip, 4.0)
	if still >= stuck_guide_s:
		leitpfeil.ziel = leit_ziel()
		leitpfeil.zeigen = true


func _fortschritt() -> void:
	_last_progress = level_time
	if leitpfeil:
		leitpfeil.zeigen = false


## Offene Station in Pauls Nähe? (Baustein mit done/opened == false, ±4 Kacheln)
func _wartet_an_station() -> bool:
	var px := player.global_position.x
	for m in mechanics:
		if not is_instance_valid(m) or not _offene_station(m):
			continue
		var r: Rect2 = m.rect
		if px > r.position.x - 4.0 * Game.TILE and px < r.end.x + 4.0 * Game.TILE:
			return true
	return false


static func _offene_station(m: Node) -> bool:
	for feld in ["done", "opened"]:
		var v = m.get(feld)
		if v is bool:
			return not v
	return false


## Wohin der Leitpfeil zeigt: Fehlen noch Prüfsummen für die Tür, zur nächsten
## (auch verstreuten); sonst zur nächsten offenen Station rechts von Paul; sonst zur Tür.
func leit_ziel() -> Vector2:
	var p := player.global_position
	var bester := Vector2.INF
	if Game.bits_this_level() < data.count_required:
		var naechst := INF
		for m in mechanics:
			if is_instance_valid(m) and m is Basics.Collectible and not m.taken:
				var d := p.distance_to(m.global_position)
				if d < naechst:
					naechst = d
					bester = m.global_position
		for c in get_children():
			if c is ScatteredBit:
				var d2 := p.distance_to(c.global_position)
				if d2 < naechst:
					naechst = d2
					bester = c.global_position
		if bester != Vector2.INF:
			return bester
	var min_x := INF
	for m in mechanics:
		if is_instance_valid(m) and _offene_station(m) and m.global_position.x > p.x - 2.0 * Game.TILE and m.global_position.x < min_x:
			min_x = m.global_position.x
			bester = m.global_position
	if bester != Vector2.INF:
		return bester
	for m in mechanics:
		if is_instance_valid(m) and m is Basics.DoorExit:
			return m.global_position
	return Vector2(data.world_width(), p.y)


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
		var lvl := get_parent() as Level
		# In eine Grube gefallen (die Welt hat unten keinen Boden): am letzten
		# Rücksetzpunkt wieder absetzen — verstreute Prüfsummen gehen nie verloren.
		# Früher fielen sie endlos (Level 04, Team-Feedback 9/2026).
		if lvl and lvl.player and global_position.y > lvl.data.world_height() + 64.0:
			global_position = lvl.player.respawn_point + Vector2(randf_range(-24.0, 24.0), -90.0)
			velocity = Vector2(0, -240.0)
			_age = minf(_age, 0.4)
		if _age > 0.7:
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
