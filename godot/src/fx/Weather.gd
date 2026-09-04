class_name Weather
extends Node2D
## WETTER — Regen und Gewitter für Welten mit `weather == "regen"`.
## Hängt unter der Kamera (zieht mit dem Bild).
##   Desktop: GPUParticles2D-Regen, der am Gelände zerplatzt — Kollision gegen das
##   Signed-Distance-Field der LightOccluder2D (Terrain setzt Occluder, `sdf_collision`
##   ist in Godot 4 standardmäßig an) — und dort über einen Sub-Emitter Spritzer setzt.
##   Browser (Compatibility): der bisherige CPU-Regen ohne Kollision.
## Blitze sind sehr selten (alle 25–45 s), höchstens zwei Frames hell, moderat und
## nie öfter als einmal pro Sekunde (Barrierefreiheit). Grollen nur, wenn ein Klang
## assets/audio/donner.wav (oder thunder.wav) vorhanden ist — sonst ohne.
## Entwicklungsschalter `--blitz`: Blitz alle 4 s, im Bild 0,4 s gehalten (nur zum
## Ansehen im Prüflauf; im Spiel bleibt es bei zwei Frames).

const DROP_W := 3
const DROP_H := 22

var pal: Palette
var sun: DirectionalLight2D
var _rain: GPUParticles2D
var _splash: GPUParticles2D
var _rain_cpu: CPUParticles2D
var _t := 0.0
var _next_bolt := 0.0
var _last_bolt := -10.0
var _sun_energy := 0.0
var _sun_color := Color.WHITE
var _thunder := ""
var _test := false


func build(palette: Palette, sun_light: DirectionalLight2D) -> void:
	pal = palette
	sun = sun_light
	if sun:
		_sun_energy = sun.energy
		_sun_color = sun.color
	_test = "--blitz" in OS.get_cmdline_user_args()
	_next_bolt = 2.0 if _test else randf_range(12.0, 30.0)
	for n in ["donner", "thunder"]:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			_thunder = n
			break
	if Fx.gpu_particles_ok():
		_build_gpu()
	else:
		_build_cpu()


## Tropfen als Strich (schmale helle Textur), leicht schräg.
static func _drop_texture() -> ImageTexture:
	var img := Image.create(DROP_W, DROP_H, false, Image.FORMAT_RGBA8)
	for y in DROP_H:
		var a := 1.0 - absf(y - DROP_H / 2.0) / (DROP_H / 2.0)
		for x in DROP_W:
			img.set_pixel(x, y, Color(1, 1, 1, a * (1.0 if x == 1 else 0.4)))
	return ImageTexture.create_from_image(img)


func _build_gpu() -> void:
	var drop := Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.45)
	# Spritzer: kleine helle Punkte, die vom Auftreffpunkt hochspringen und fallen
	_splash = GPUParticles2D.new()
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3(0, -1, 0)
	sm.spread = 50.0
	sm.initial_velocity_min = 120.0
	sm.initial_velocity_max = 260.0
	sm.gravity = Vector3(0, 1100, 0)
	sm.scale_min = 0.3
	sm.scale_max = 0.55
	sm.color = Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.9)
	sm.color_ramp = Fx.fade_ramp_texture(Color(1, 1, 1, 1.0))
	_splash.process_material = sm
	_splash.texture = Fx.dot_texture()
	_splash.amount = 700
	_splash.lifetime = 0.26
	_splash.fixed_fps = 60
	_splash.local_coords = false
	_splash.emitting = true
	_splash.z_index = 30
	_splash.visibility_rect = Rect2(-1400, -900, 2800, 1800)
	add_child(_splash)
	# Regen: fällt schräg, verschwindet beim Auftreffen und setzt dort Spritzer
	_rain = GPUParticles2D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1300, 40, 1)
	m.direction = Vector3(-0.18, 1, 0)
	m.spread = 3.0
	m.initial_velocity_min = 1100.0
	m.initial_velocity_max = 1400.0
	m.gravity = Vector3.ZERO
	m.scale_min = 1.0
	m.scale_max = 1.6
	m.color = drop
	m.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	m.collision_use_scale = false
	m.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	m.sub_emitter_amount_at_collision = 3
	m.sub_emitter_keep_velocity = false
	_rain.process_material = m
	_rain.texture = _drop_texture()
	_rain.amount = 420
	_rain.lifetime = 1.1
	_rain.preprocess = 1.0
	_rain.position = Vector2(0, -560)
	_rain.rotation = deg_to_rad(10)
	_rain.local_coords = false
	# Kollision: 60 Schritte/s (Standard 30 = ~47 px pro Schritt bei 1400 px/s) und ein
	# Kollisionsradius von 10 px, damit Tropfen an der Kante enden statt ~50 px darunter
	_rain.fixed_fps = 60
	_rain.collision_base_size = 10.0
	_rain.z_index = 30
	_rain.visibility_rect = Rect2(-1500, -200, 3000, 1600)
	add_child(_rain)
	_rain.sub_emitter = _rain.get_path_to(_splash)
	_rain.emitting = true


## Browser: CPU-Regen wie bisher (keine Kollision, keine Spritzer).
func _build_cpu() -> void:
	_rain_cpu = CPUParticles2D.new()
	_rain_cpu.amount = 260
	_rain_cpu.lifetime = 1.1
	_rain_cpu.preprocess = 1.0
	_rain_cpu.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain_cpu.emission_rect_extents = Vector2(1300, 40)
	_rain_cpu.position = Vector2(0, -560)
	_rain_cpu.direction = Vector2(-0.18, 1)
	_rain_cpu.spread = 3.0
	_rain_cpu.initial_velocity_min = 1100.0
	_rain_cpu.initial_velocity_max = 1400.0
	_rain_cpu.gravity = Vector2.ZERO
	_rain_cpu.scale_amount_min = 1.0
	_rain_cpu.scale_amount_max = 1.6
	_rain_cpu.color = Color(pal.cap_light.r, pal.cap_light.g, pal.cap_light.b, 0.45)
	_rain_cpu.texture = _drop_texture()
	_rain_cpu.rotation = deg_to_rad(10)
	_rain_cpu.z_index = 30
	add_child(_rain_cpu)


func _process(delta: float) -> void:
	_t += delta
	# Nie öfter als einmal pro Sekunde — auch im Testmodus
	if _t >= _next_bolt and _t - _last_bolt >= 1.0:
		_bolt()


## Ein Blitz: zwei Frames Aufheller im Post-Effekt, dazu springt die Sonne kurz
## als kaltes, hartes Licht an (Schatten der Kulisse zucken mit) und klingt ab.
func _bolt() -> void:
	_last_bolt = _t
	_next_bolt = _t + (4.0 if _test else randf_range(25.0, 45.0))
	var c := Color(0.86, 0.91, 1.0)
	Fx.lightning(c, 0.20, 24 if _test else 2)
	if sun:
		sun.energy = _sun_energy + 0.4
		sun.color = Color(1.25, 1.35, 1.6)
		var tw := sun.create_tween()
		tw.tween_interval(0.4 if _test else 2.0 / 60.0)
		tw.tween_property(sun, "energy", _sun_energy, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sun, "color", _sun_color, 0.22)
	if _thunder != "":
		get_tree().create_timer(randf_range(0.7, 1.8)).timeout.connect(_rumble)


func _rumble() -> void:
	Sfx.play(_thunder, randf_range(0.85, 1.0), -14.0)
