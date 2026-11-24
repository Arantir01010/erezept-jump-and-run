class_name Grafik
extends RefCounted
## GRAFIKSTUFEN UND GLÜHEN — die eine Stelle, an der entschieden wird, wie
## aufwendig gezeichnet wird. Regel aus dem Strategiespiel (projekt-e,
## docs/wissen/11 „Grafikstufen für Effekte"): Stufen ändern nur die
## Bildqualität, nie Ort, Maßstab oder Zeitpunkt von irgendetwas.
##
##   Stufe 0 „Browser" — Vorgabe im Web-Build und mit --webfx, genau die
##     bisherige Browser-Behandlung: Glüh-Sprites statt HDR-Glühfarben
##     (Fx.web_fallback), Partikel auf der CPU (Fx.gpu_particles_ok falsch:
##     Siegel-Funken ohne Nachfunken, Regen ohne Kollision und Spritzer),
##     Wolken und Vordergrund ohne Weichzeichner (kulissen_unschaerfe).
##   Stufe 1 „Mitte" — HDR-Glühen und alle Shader wie Stufe 2. Abgeschaltet:
##     GPU-Partikel (CPU-Partikel wie im Browser; läuft so auch im
##     Compatibility-Rückfall ohne Compute/Sub-Emitter) und das 8×-MSAA der
##     2D-Ebene (höchstens 2×: ein Viertel der Abtastwerte im HDR-Puffer und
##     in jeder Auflösung für Screen-Texture-Shader; Kanten bleiben geglättet).
##   Stufe 2 „Voll" — Vorgabe am Desktop: HDR-Glühen, GPU-Partikel mit
##     Sub-Emittern und SDF-Kollision, MSAA laut Projekt (8×).
##
## Übersteuern: --grafik=0|1|2 (nach --; schlägt --webfx). Renderer, hdr_2d und
## das abgeschaltete MSAA des Browsers kommen weiter aus den Projekteinstellungen
## je Plattform. Stufe 0 am Desktop lässt die Kantenglättung unverändert, damit
## --webfx-Standbilder mit früheren vergleichbar bleiben.
##
## Glühen (WorldEnvironment, umgebung_einrichten): zwei Voreinstellungen.
##   A — die bisherigen Werte aus Main.gd (Vorgabe): additiv, HDR-Schwelle 1,35.
##   B — die Einstellung aus dem Strategiespiel: Mischung Screen, Schwelle 2,0,
##       Stärke 0,3, nur die unteren Glühstufen, Entbänderung (Viewport).
## Wahl: --glow=a|b (dazu --glow=aus, nur zum Messen). Umschalten mit F7 nur mit
## --vergleich oder in Debug-Builds außerhalb von --kiosk; eine kurze
## Einblendung nennt die aktive Variante.

const BROWSER := 0
const MITTE := 1
const VOLL := 2
const NAMEN: Array[String] = ["Browser", "Mitte", "Voll"]

## Glühen A: unverändert aus Main.gd (Stand 24.11.2026). `levels` = Godots
## glow_levels/1…7 (Index 0…6); Index 6 war nie gesetzt und steht auf der
## Godot-Vorgabe 0,0. `debanding` gilt für den Viewport (Projektvorgabe: aus).
const GLOW_A := {
	"intensity": 0.65,
	"strength": 1.0,
	"bloom": 0.03,
	"blend_mode": Environment.GLOW_BLEND_MODE_ADDITIVE,
	"hdr_threshold": 1.35,
	"hdr_scale": 2.4,
	"levels": [0.0, 0.85, 0.6, 0.9, 0.4, 0.55, 0.0],
	"debanding": false,
}

## Glühen B: Strategiespiel (docs/wissen/11 „Glow ohne das ganze Bild zu
## verwaschen", 10 „Glow und Leuchten"): Schwelle 2,0 (bei 1,0–1,5 wusch dort
## ein dichter Effekt zum Fleck), Screen statt additiv, Stärke 0,3, nur die
## unteren Stufen, Bloom 0, Bleed-Skala 1,0, Entbänderung gegen Bänder im Hof.
const GLOW_B := {
	"intensity": 0.3,
	"strength": 1.0,
	"bloom": 0.0,
	"blend_mode": Environment.GLOW_BLEND_MODE_SCREEN,
	"hdr_threshold": 2.0,
	"hdr_scale": 1.0,
	"levels": [0.0, 0.5, 0.8, 0.3, 0.0, 0.0, 0.0],
	"debanding": true,
}

## Vorgewärmte Shaderdateien: alle unter src/shaders/ außer der Blende
## (wipe.gdshader), die ab dem ersten Bild läuft — wie der eingebettete Shader
## des Post-Effekts (PostFx.gd). test_grafik.gd prüft, dass die Liste vollständig ist.
const VORWAERM_SHADER: Array[String] = [
	"res://src/shaders/god_rays.gdshader",
	"res://src/shaders/ground_fog.gdshader",
	"res://src/shaders/hall_rays.gdshader",
	"res://src/shaders/kulisse_blur.gdshader",
	"res://src/shaders/puddle.gdshader",
	"res://src/shaders/vau_gitter.gdshader",
	"res://src/shaders/wind.gdshader",
]
const VORWAERM_OHNE: Array[String] = ["res://src/shaders/wipe.gdshader"]

static var _stufe := -1
static var _glow := ""


# ------------------------------------------------------------------ Stufe

## Aktive Grafikstufe 0…2 (einmal aus Kommandozeile und Plattform gelesen).
static func stufe() -> int:
	if _stufe < 0:
		var args := OS.get_cmdline_user_args()
		_schalter_pruefen(args)
		_stufe = stufe_aus(args, OS.has_feature("web"))
	return _stufe


## Reine Regel (für Tests): Browser oder --webfx → 0, sonst 2; --grafik=N
## übersteuert (begrenzt auf 0…2). Ungültige Werte zählen nicht.
static func stufe_aus(args: PackedStringArray, web: bool) -> int:
	var s := BROWSER if web or "--webfx" in args else VOLL
	for a in args:
		if a.begins_with("--grafik="):
			var w := a.get_slice("=", 1)
			if w.is_valid_int():
				s = clampi(w.to_int(), BROWSER, VOLL)
	return s


## Nur für Tests und Werkzeuge: Stufe fest setzen; -1 liest wieder neu ein.
static func setze_stufe(s: int) -> void:
	_stufe = clampi(s, BROWSER, VOLL) if s >= 0 else -1


static func stufe_name() -> String:
	return NAMEN[stufe()]


## Stufe 0: additive Glüh-Sprites statt HDR-Glühfarben (Fx.web_fallback).
static func glueh_sprites() -> bool:
	return stufe() == BROWSER


## Nur Stufe 2: GPU-Partikel mit Sub-Emittern und Kollision (Fx.gpu_particles_ok).
static func gpu_partikel() -> bool:
	return stufe() == VOLL


## Weichzeichner für Wolken und Vordergrund (je eine CanvasGroup mit
## kulisse_blur, Backdrop): in Stufe 0 aus, wie im Browser schon immer. Ferne und
## mittlere Stadt bleiben in jeder Stufe weich.
static func kulissen_unschaerfe() -> bool:
	return stufe() != BROWSER


## Obergrenze für das 2D-MSAA der Stufe (-1 = Projekteinstellung bleibt).
static func msaa_2d_grenze() -> int:
	return Viewport.MSAA_2X if stufe() == MITTE else -1


# ------------------------------------------------------------------ Glühen

## Aktive Glüh-Variante: "a" (Vorgabe), "b" oder "aus".
static func glow_variante() -> String:
	if _glow == "":
		_glow = glow_aus(OS.get_cmdline_user_args())
	return _glow


## Reine Regel (für Tests): --glow=a|b|aus, sonst "a".
static func glow_aus(args: PackedStringArray) -> String:
	var v := "a"
	for a in args:
		if a.begins_with("--glow="):
			var w := a.get_slice("=", 1).to_lower()
			if w in ["a", "b", "aus"]:
				v = w
	return v


static func glow_werte(variante: String) -> Dictionary:
	return GLOW_B if variante == "b" else GLOW_A


## Voreinstellung auf eine Umgebung legen, die Entbänderung auf den Viewport
## (ohne Viewport bleibt dieser unberührt). "aus" = A mit glow_enabled falsch.
static func glow_anwenden(e: Environment, variante: String, vp: Viewport = null) -> void:
	var w := glow_werte(variante)
	e.glow_enabled = variante != "aus"
	e.glow_intensity = w["intensity"]
	e.glow_strength = w["strength"]
	e.glow_bloom = w["bloom"]
	e.glow_blend_mode = w["blend_mode"]
	e.glow_hdr_threshold = w["hdr_threshold"]
	e.glow_hdr_scale = w["hdr_scale"]
	var stufen: Array = w["levels"]
	for i in stufen.size():
		e.set_glow_level(i, stufen[i])
	if vp != null:
		var projekt := bool(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_debanding", false))
		vp.use_debanding = bool(w["debanding"]) or projekt


## Variante wechseln (F7) — merkt sie und legt sie auf die Umgebung.
static func glow_setzen(variante: String, e: Environment, vp: Viewport = null) -> void:
	_glow = variante
	glow_anwenden(e, variante, vp)


## Kurzname für die Einblendung und die Messbilder.
static func glow_text(variante: String) -> String:
	match variante:
		"b":
			return "Glühen B · Strategiespiel (Screen, Schwelle 2,0)"
		"aus":
			return "Glühen aus (nur Messung)"
	return "Glühen A · bisher (additiv, Schwelle 1,35)"


## F7-Umschaltung erlaubt? Mit --vergleich immer, sonst nur in Debug-Builds
## und nie im Messe-Kiosk.
static func umschalten_erlaubt(args: PackedStringArray, debug: bool) -> bool:
	return "--vergleich" in args or (debug and not "--kiosk" in args)


# ------------------------------------------------------------------ Einrichten

## Main._ready: WorldEnvironment mit der gewählten Glüh-Variante, das MSAA der
## Stufe und (wenn erlaubt) die F7-Umschaltung. Mit den Vorgaben (Stufe 2,
## Glühen A) entsteht genau die frühere Umgebung aus Main.gd.
static func umgebung_einrichten(main: Node) -> WorldEnvironment:
	var vp := main.get_viewport()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	glow_anwenden(e, glow_variante(), vp)
	env.environment = e
	main.add_child(env)
	msaa_anwenden(vp)
	if umschalten_erlaubt(OS.get_cmdline_user_args(), OS.is_debug_build()):
		var u := _Umschalter.new()
		u.umgebung = e
		main.add_child.call_deferred(u)   # hinter allen anderen Kindern von Main
	return env


## Stufe 1: 2D-MSAA auf höchstens 2× senken (nie anheben); sonst bleibt der Viewport.
static func msaa_anwenden(vp: Viewport) -> void:
	var grenze := msaa_2d_grenze()
	if grenze >= 0 and vp.msaa_2d > grenze:
		vp.msaa_2d = grenze


static func _schalter_pruefen(args: PackedStringArray) -> void:
	for a in args:
		if a.begins_with("--grafik=") and not a.get_slice("=", 1) in ["0", "1", "2"]:
			push_warning("Grafik: %s ungültig — erlaubt sind --grafik=0|1|2" % a)
		elif a.begins_with("--glow=") and not a.get_slice("=", 1).to_lower() in ["a", "b", "aus"]:
			push_warning("Grafik: %s ungültig — erlaubt sind --glow=a|b|aus" % a)


# ------------------------------------------------------------------ Vorwärmen

## Vorwärmen gegen den Ruckler beim ersten Effekt (Strategiespiel: erstes Bild mit
## neuem Shader sonst 50–60 ms): jede Shader- und Partikel-Materialkombination des
## Spiels einmal zeichnen lassen und nach `bilder` Frames wieder freigeben.
## Alles liegt 1–2 px groß in der linken oberen Bildecke auf Ebene 99, also unter
## der Blende (Main: Ebene 100), die beim Start geschlossen ist. Außerhalb des
## Bildes ginge es nicht: Godot zeichnet nichts, was außerhalb des Sichtfelds liegt,
## und die Pipeline entstünde erst beim ersten echten Effekt.
## Abschaltbar mit --ohne-vorwaermen (Vorher/Nachher-Messung im selben Codestand).
static func vorwaermen(eltern: Node, bilder := 3) -> void:
	if "--ohne-vorwaermen" in OS.get_cmdline_user_args() or not eltern.is_inside_tree():
		return
	var baum := eltern.get_tree()
	var lage := CanvasLayer.new()
	lage.name = "Vorwaermen"
	lage.layer = 99
	eltern.add_child(lage)
	# Shaderdateien: je ein 1×1-Rechteck (UV und Vertexfarbe wie bei den Nutzern)
	for pfad in VORWAERM_SHADER:
		var sh := load(pfad) as Shader
		if sh == null:
			push_error("Grafik.vorwaermen: %s fehlt" % pfad)
			continue
		var m := ShaderMaterial.new()
		m.shader = sh
		if pfad.ends_with("kulisse_blur.gdshader"):
			# wie in Backdrop._group: Material einer CanvasGroup
			var g := CanvasGroup.new()
			g.fit_margin = 2.0
			g.clear_margin = 2.0
			g.material = m
			g.add_child(_punkt(Color(1, 1, 1, 1), null))
			lage.add_child(g)
		else:
			lage.add_child(_punkt(Color(1, 1, 1, 1), m))
	# CanvasItemMaterial: additiv + unbeleuchtet (Glüh-Sprites), additiv (Vignette)
	Fx.glow_sprite(lage, Color.WHITE, 1.0, 1.0).position = Vector2(1, 1)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lage.add_child(_punkt(Color.WHITE, add))
	# Licht und Schatten (Sonne, Punktlicht mit PCF13) auf einem beleuchteten Punkt
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2)])
	occ.occluder = poly
	lage.add_child(occ)
	var sonne := DirectionalLight2D.new()
	sonne.shadow_enabled = true
	sonne.energy = 0.1
	lage.add_child(sonne)
	Fx.light(lage, Vector2(1, 1), Color.WHITE, 2.0, 0.5, true)
	# Partikel über die echten Wege: Fx.burst (GPU mit Sub-Emitter, in Stufe 0/1
	# die CPU-Funken), Staub (CPU). Kurz leben lassen, dann mit der Ebene weg.
	var gpu_ok := gpu_partikel() and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if gpu_ok:
		Fx.burst(lage, Vector2(1, 1), Color.WHITE, 1, 1.0)
		_regen_probe(lage)
	else:
		Fx.sparkle(lage, Vector2(1, 1), Color.WHITE, 1, 1.0)
	Fx.dust(lage, Vector2(1, 1), 1, 0.1)
	for i in bilder:
		await baum.process_frame
	if is_instance_valid(lage):
		lage.queue_free()


## Ein 1×1-Punkt mit Material (Vertexfarbe weiß, UV 0…1 wie ein ColorRect).
static func _punkt(farbe: Color, mat: Material) -> ColorRect:
	var r := ColorRect.new()
	r.color = farbe
	r.size = Vector2(1, 1)
	r.position = Vector2(1, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	return r


## Prozessmaterial wie der GPU-Regen (Weather._build_gpu): Kasten-Emission,
## Kollision „verbergen", Sub-Emitter bei Kollision; Spritzer mit Farbrampe.
## Nur die Merkmale bestimmen den erzeugten Shader, nicht die Zahlenwerte.
static func _regen_probe(lage: Node) -> void:
	var spritzer := GPUParticles2D.new()
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3(0, -1, 0)
	sm.spread = 50.0
	sm.gravity = Vector3(0, 1100, 0)
	sm.scale_min = 0.3
	sm.scale_max = 0.55
	sm.color_ramp = Fx.fade_ramp_texture(Color(1, 1, 1, 1.0))
	spritzer.process_material = sm
	spritzer.texture = Fx.dot_texture()
	spritzer.amount = 1
	spritzer.lifetime = 0.1
	spritzer.fixed_fps = 60
	spritzer.local_coords = false
	spritzer.position = Vector2(1, 1)
	lage.add_child(spritzer)
	var regen := GPUParticles2D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1, 1, 1)
	m.direction = Vector3(-0.18, 1, 0)
	m.spread = 3.0
	m.gravity = Vector3.ZERO
	m.scale_min = 1.0
	m.scale_max = 1.6
	m.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	m.collision_use_scale = false
	m.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	m.sub_emitter_amount_at_collision = 1
	m.sub_emitter_keep_velocity = false
	regen.process_material = m
	regen.texture = Fx.dot_texture()
	regen.amount = 1
	regen.lifetime = 0.1
	regen.fixed_fps = 60
	regen.local_coords = false
	regen.position = Vector2(1, 1)
	lage.add_child(regen)
	regen.sub_emitter = regen.get_path_to(spritzer)
	regen.emitting = true


# ------------------------------------------------------------------ F7

## Umschalter für den Glüh-Vergleich: F7 wechselt A ⇄ B, eine kurze Einblendung
## oben links nennt die aktive Variante. Läuft auch in der Pause.
class _Umschalter extends CanvasLayer:
	var umgebung: Environment
	var hinweis: Label
	var _tw: Tween

	func _ready() -> void:
		name = "GlowUmschalter"
		layer = 120
		process_mode = Node.PROCESS_MODE_ALWAYS
		hinweis = Label.new()
		var ls := LabelSettings.new()
		ls.font_size = 22
		ls.font_color = Color(1, 1, 1)
		ls.outline_size = 6
		ls.outline_color = Color(0.03, 0.05, 0.08, 0.9)
		hinweis.label_settings = ls
		hinweis.position = Vector2(24, 20)
		hinweis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hinweis.visible = false
		add_child(hinweis)

	func _input(event: InputEvent) -> void:
		var k := event as InputEventKey
		if k == null or not k.pressed or k.echo or k.keycode != KEY_F7:
			return
		get_viewport().set_input_as_handled()
		umschalten()

	func umschalten() -> void:
		var neu := "a" if Grafik.glow_variante() == "b" else "b"
		Grafik.glow_setzen(neu, umgebung, get_viewport())
		hinweis.text = Grafik.glow_text(neu)
		hinweis.visible = true
		hinweis.modulate.a = 1.0
		if _tw != null:
			_tw.kill()   # zweimal F7 kurz hintereinander: neue Einblendung voll stehen lassen
		_tw = hinweis.create_tween()
		_tw.tween_interval(1.6)
		_tw.tween_property(hinweis, "modulate:a", 0.0, 0.4)
		_tw.tween_callback(func(): hinweis.visible = false)
