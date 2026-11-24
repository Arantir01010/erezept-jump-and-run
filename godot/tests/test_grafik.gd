extends "res://tests/testfall.gd"
## GRAFIK: Grafikstufen (eine Abfragestelle, Übersteuerung, was jede Stufe
## abschaltet), Glüh-Voreinstellungen A/B (A = die früheren Werte aus Main.gd,
## Regressionsschutz), F7-Umschaltung nur wo erlaubt, Vorwärmen ohne Fehler und
## vollständig, Fx-API unverändert.

var knoten: Node


func aufraeumen() -> void:
	Grafik.setze_stufe(-1)
	Grafik._glow = ""
	if is_instance_valid(knoten):
		knoten.queue_free()
	await frames(2)


func _neuer_knoten() -> Node:
	knoten = Node.new()
	baum.root.add_child(knoten)
	return knoten


## So baute Main.gd die Umgebung bis zum 24.11.2026 (wörtlich übernommen).
static func _umgebung_bisher() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.65
	e.glow_strength = 1.0
	e.glow_bloom = 0.03
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.glow_hdr_threshold = 1.35
	e.glow_hdr_scale = 2.4
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 0.85)
	e.set_glow_level(2, 0.6)
	e.set_glow_level(3, 0.9)
	e.set_glow_level(4, 0.4)
	e.set_glow_level(5, 0.55)
	return e


## Alle gespeicherten Eigenschaften zweier Umgebungen vergleichen.
func _gleiche_umgebung(ist: Environment, soll: Environment, was: String) -> void:
	for p in soll.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var n := str(p["name"])
		gleich(ist.get(n), soll.get(n), "%s: %s" % [was, n])


# ------------------------------------------------------------------ Stufen

func test_stufe_vorgaben_und_uebersteuerung() -> void:
	gleich(Grafik.stufe_aus(PackedStringArray(), false), Grafik.VOLL, "Desktop ohne Schalter")
	gleich(Grafik.stufe_aus(PackedStringArray(), true), Grafik.BROWSER, "Web-Build")
	gleich(Grafik.stufe_aus(PackedStringArray(["--webfx"]), false), Grafik.BROWSER, "--webfx")
	gleich(Grafik.stufe_aus(PackedStringArray(["--grafik=0"]), false), 0, "--grafik=0")
	gleich(Grafik.stufe_aus(PackedStringArray(["--grafik=1"]), false), 1, "--grafik=1")
	gleich(Grafik.stufe_aus(PackedStringArray(["--grafik=2"]), true), 2, "--grafik=2 im Browser")
	gleich(Grafik.stufe_aus(PackedStringArray(["--webfx", "--grafik=1"]), false), 1, "--grafik schlägt --webfx")
	gleich(Grafik.stufe_aus(PackedStringArray(["--grafik=7"]), false), 2, "--grafik=7 begrenzt")
	gleich(Grafik.stufe_aus(PackedStringArray(["--grafik=-3"]), false), 0, "--grafik=-3 begrenzt")
	gleich(Grafik.stufe_aus(PackedStringArray(["--grafik=hoch"]), false), 2, "ungültiger Wert zählt nicht")
	# Dieser Testlauf hat keinen Schalter: Desktop-Vorgabe, Fx wie bisher
	gleich(Grafik.stufe(), Grafik.VOLL, "Stufe im Testlauf")
	gleich(Fx.web_fallback(), false, "Fx.web_fallback am Desktop")
	gleich(Fx.gpu_particles_ok(), true, "Fx.gpu_particles_ok am Desktop")


func test_stufen_schalten_nur_bildqualitaet() -> void:
	# 0 = Browser-Pfad, 1 = Mitte (HDR-Glühen, CPU-Partikel, MSAA ≤ 2×), 2 = voll
	var soll := {
		0: {"sprites": true, "gpu": false, "msaa": -1},
		1: {"sprites": false, "gpu": false, "msaa": Viewport.MSAA_2X},
		2: {"sprites": false, "gpu": true, "msaa": -1},
	}
	for s in soll:
		Grafik.setze_stufe(s)
		gleich(Grafik.stufe(), s, "setze_stufe(%d)" % s)
		gleich(Fx.web_fallback(), soll[s]["sprites"], "Stufe %d: Fx.web_fallback" % s)
		gleich(Grafik.glueh_sprites(), soll[s]["sprites"], "Stufe %d: Glüh-Sprites" % s)
		gleich(Fx.gpu_particles_ok(), soll[s]["gpu"], "Stufe %d: Fx.gpu_particles_ok" % s)
		gleich(Grafik.msaa_2d_grenze(), soll[s]["msaa"], "Stufe %d: MSAA-Grenze" % s)
	Grafik.setze_stufe(-1)
	gleich(Grafik.stufe(), Grafik.VOLL, "setze_stufe(-1) liest neu ein")


func test_stufe_1_senkt_msaa_und_hebt_nie_an() -> void:
	var vp := SubViewport.new()
	_neuer_knoten().add_child(vp)
	for s in [0, 1, 2]:
		Grafik.setze_stufe(s)
		vp.msaa_2d = Viewport.MSAA_8X
		Grafik.msaa_anwenden(vp)
		gleich(vp.msaa_2d, Viewport.MSAA_2X if s == 1 else Viewport.MSAA_8X, "Stufe %d: MSAA 8× wird" % s)
		vp.msaa_2d = Viewport.MSAA_DISABLED
		Grafik.msaa_anwenden(vp)
		gleich(vp.msaa_2d, Viewport.MSAA_DISABLED, "Stufe %d: MSAA aus bleibt aus" % s)


# ------------------------------------------------------------------ Glühen

func test_glow_a_ist_die_bisherige_umgebung() -> void:
	# Regressionsschutz: Vorgabe (A, Stufe 2) = genau die frühere Umgebung aus Main.gd
	gleich(Grafik.glow_variante(), "a", "Vorgabe-Variante")
	var root := baum.root
	var msaa_vorher := root.msaa_2d
	var deband_vorher := root.use_debanding
	var env := Grafik.umgebung_einrichten(_neuer_knoten())
	pruefe(env != null and env.environment != null, "umgebung_einrichten liefert eine Umgebung")
	_gleiche_umgebung(env.environment, _umgebung_bisher(), "Umgebung A")
	gleich(root.msaa_2d, msaa_vorher, "MSAA des Fensters unverändert")
	gleich(root.use_debanding, deband_vorher, "Entbänderung des Fensters unverändert")
	# glow_anwenden auf eine frische Umgebung ergibt dasselbe
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	Grafik.glow_anwenden(e, "a")
	_gleiche_umgebung(e, _umgebung_bisher(), "glow_anwenden(a)")


func test_glow_b_ist_die_strategiespiel_einstellung() -> void:
	var e := Environment.new()
	var vp := SubViewport.new()
	_neuer_knoten().add_child(vp)
	Grafik.glow_anwenden(e, "b", vp)
	gleich(e.glow_enabled, true, "B: an")
	nahe(e.glow_hdr_threshold, 2.0, 0.0001, "B: HDR-Schwelle")
	gleich(e.glow_blend_mode, Environment.GLOW_BLEND_MODE_SCREEN, "B: Mischung Screen")
	nahe(e.glow_intensity, 0.3, 0.0001, "B: Stärke")
	nahe(e.glow_bloom, 0.0, 0.0001, "B: kein Bloom")
	var stufen := [0.0, 0.5, 0.8, 0.3, 0.0, 0.0, 0.0]
	for i in stufen.size():
		nahe(e.get_glow_level(i), stufen[i], 0.0001, "B: Glühstufe %d" % i)
	gleich(vp.use_debanding, true, "B: Entbänderung am Viewport")
	Grafik.glow_anwenden(e, "a", vp)
	gleich(vp.use_debanding, false, "zurück zu A: Entbänderung wieder aus")
	nahe(e.glow_hdr_threshold, 1.35, 0.0001, "zurück zu A: Schwelle")
	Grafik.glow_anwenden(e, "aus")
	gleich(e.glow_enabled, false, "--glow=aus schaltet ab")


func test_glow_schalter() -> void:
	gleich(Grafik.glow_aus(PackedStringArray()), "a", "ohne Schalter")
	gleich(Grafik.glow_aus(PackedStringArray(["--glow=b"])), "b", "--glow=b")
	gleich(Grafik.glow_aus(PackedStringArray(["--glow=B"])), "b", "--glow=B")
	gleich(Grafik.glow_aus(PackedStringArray(["--glow=aus"])), "aus", "--glow=aus")
	gleich(Grafik.glow_aus(PackedStringArray(["--glow=c"])), "a", "ungültig → A")
	pruefe(Grafik.glow_text("a").contains("A") and Grafik.glow_text("b").contains("B"), "Einblendung nennt die Variante")


func test_f7_nur_wo_erlaubt_und_schaltet_um() -> void:
	gleich(Grafik.umschalten_erlaubt(PackedStringArray(), true), true, "Debug-Build")
	gleich(Grafik.umschalten_erlaubt(PackedStringArray(), false), false, "Release ohne --vergleich")
	gleich(Grafik.umschalten_erlaubt(PackedStringArray(["--kiosk"]), true), false, "Debug im Kiosk")
	gleich(Grafik.umschalten_erlaubt(PackedStringArray(["--vergleich"]), false), true, "Release mit --vergleich")
	gleich(Grafik.umschalten_erlaubt(PackedStringArray(["--vergleich", "--kiosk"]), false), true, "--vergleich im Kiosk")
	# Der Testlauf ist ein Debug-Build ohne --kiosk: Umschalter ist da
	var env := Grafik.umgebung_einrichten(_neuer_knoten())
	await frames(1)
	var u := knoten.get_node_or_null("GlowUmschalter")
	if not pruefe(u != null, "Umschalter angelegt"):
		return
	gleich(knoten.get_child(knoten.get_child_count() - 1), u, "Umschalter hängt hinter allen anderen Kindern")
	var f7 := InputEventKey.new()
	f7.keycode = KEY_F7
	f7.pressed = true
	baum.root.push_input(f7)
	gleich(Grafik.glow_variante(), "b", "F7 → B")
	nahe(env.environment.glow_hdr_threshold, 2.0, 0.0001, "F7 → Schwelle 2,0")
	pruefe(u.hinweis.visible and u.hinweis.text.contains("B"), "Einblendung zeigt B")
	baum.root.push_input(f7)
	gleich(Grafik.glow_variante(), "a", "F7 → wieder A")
	_gleiche_umgebung(env.environment, _umgebung_bisher(), "nach F7 F7")
	gleich(baum.root.use_debanding, false, "nach F7 F7: Entbänderung aus")
	await sekunden(2.2)
	gleich(u.hinweis.visible, false, "Einblendung verschwindet")


# ------------------------------------------------------------------ Vorwärmen

func test_vorwaermen_laeuft_ohne_fehler_und_raeumt_auf() -> void:
	for s in [2, 1, 0]:
		Grafik.setze_stufe(s)
		var k := _neuer_knoten()
		var t0 := Time.get_ticks_usec()
		Grafik.vorwaermen(k)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		pruefe(ms < 300.0, "Stufe %d: Vorwärmen blockiert %.0f ms (Grenze 300)" % [s, ms])
		var lage := k.get_node_or_null("Vorwaermen")
		if not pruefe(lage != null, "Stufe %d: Vorwärm-Ebene angelegt" % s):
			continue
		gleich((lage as CanvasLayer).layer, 99, "unter der Blende (Ebene 100)")
		var gpu := lage.find_children("*", "GPUParticles2D", true, false).size()
		var cpu := lage.find_children("*", "CPUParticles2D", true, false).size()
		# (im Compatibility-Renderer wärmt auch Stufe 2 keine GPU-Partikel vor)
		var gpu_soll: bool = s == 2 and RenderingServer.get_current_rendering_method() != "gl_compatibility"
		pruefe((gpu >= 3) == gpu_soll, "Stufe %d: GPU-Partikel nur in Stufe 2 (%d)" % [s, gpu])
		pruefe(cpu >= 1, "Stufe %d: CPU-Partikel dabei" % s)
		var mats := 0
		for c in lage.find_children("*", "CanvasItem", true, false):
			if (c as CanvasItem).material is ShaderMaterial:
				mats += 1
		gleich(mats, Grafik.VORWAERM_SHADER.size(), "Stufe %d: je Shaderdatei ein Material" % s)
		await frames(5)
		pruefe(not is_instance_valid(lage), "Stufe %d: Vorwärm-Ebene wieder frei" % s)
		knoten.queue_free()
		await frames(1)


func test_vorwaermliste_vollstaendig() -> void:
	var shaderdateien := dateien("res://src/shaders/", ".gdshader")
	for f in shaderdateien:
		pruefe(f in Grafik.VORWAERM_SHADER or f in Grafik.VORWAERM_OHNE,
			"%s fehlt in Grafik.VORWAERM_SHADER (neuer Shader → vorwärmen)" % f)
	for f in Grafik.VORWAERM_SHADER:
		pruefe(ResourceLoader.exists(f), "%s gibt es nicht" % f)
	# Eingebettete Shader: nur der Post-Effekt (läuft ab dem ersten Bild). Ein neuer
	# eingebetteter Shader gehört nach src/shaders/ oder in Grafik.vorwaermen.
	var eingebettet: Array[String] = []
	for f in dateien("res://src/", ".gd"):
		if FileAccess.get_file_as_string(f).contains("shader_type"):
			eingebettet.append(f)
	gleich(eingebettet, ["res://src/fx/PostFx.gd"] as Array[String], "Dateien mit eingebettetem Shader")


func test_regen_probe_trifft_den_shader_des_wetters() -> void:
	# Vorwärmen baut den GPU-Regen nach (Weather._build_gpu). Gleiche Merkmale =
	# derselbe erzeugte Prozess-Shader; driftet Weather weg, fällt das hier auf.
	var k := _neuer_knoten()
	var w := Weather.new()
	k.add_child(w)
	w.build(Palette.for_world("netz-regen"), null)
	var lage := Node2D.new()
	k.add_child(lage)
	Grafik._regen_probe(lage)
	await frames(1)
	var probe: Array = lage.find_children("*", "GPUParticles2D", true, false)
	if not pruefe(probe.size() == 2 and w._rain != null, "Regen und Probe angelegt"):
		return
	var paare := [[w._splash, probe[0], "Spritzer"], [w._rain, probe[1], "Regen"]]
	for p in paare:
		gleich(_merkmale(p[1].process_material), _merkmale(p[0].process_material),
			"%s: Merkmale der Probe wie bei Weather" % p[2])


## Was Godots erzeugten Partikel-Shader bestimmt: Schalter, Aufzählungen und welche
## Texturen/Kurven gesetzt sind — nicht die Zahlenwerte (die sind Uniforms).
static func _merkmale(m: ParticleProcessMaterial) -> Dictionary:
	var out := {}
	for p in m.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var n := str(p["name"])
		match int(p["type"]):
			TYPE_BOOL:
				out[n] = m.get(n)
			TYPE_INT:
				if not n.contains("amount"):
					out[n] = m.get(n)
			TYPE_OBJECT:
				if n != "script":
					out[n] = m.get(n) != null
	return out


# ------------------------------------------------------------------ Fx

func test_fx_api_unveraendert() -> void:
	# Name → [Argumente, davon mit Vorgabe] wie vor der Umstellung auf Grafik.gd
	var soll := {
		"web_fallback": [0, 0], "gpu_particles_ok": [0, 0], "radial_texture": [0, 0],
		"cone_texture": [0, 0], "dot_texture": [0, 0], "light": [7, 3], "glow_sprite": [4, 1],
		"set_glow": [3, 0], "impact": [1, 0], "flash": [2, 0], "lightning": [3, 1],
		"hitstop": [2, 0], "slowmo": [3, 0], "dust": [4, 2], "land_dust": [3, 0],
		"sparkle": [5, 2], "burst": [5, 2], "ring": [5, 2], "light_burst": [6, 3],
		"deny_stamp": [3, 1], "float_text": [5, 1], "fade_ramp_texture": [1, 0],
	}
	var ist := {}
	for m in (load("res://src/fx/Fx.gd") as GDScript).get_script_method_list():
		ist[str(m["name"])] = [(m["args"] as Array).size(), (m["default_args"] as Array).size()]
	for n in soll:
		if pruefe(ist.has(n), "Fx.%s fehlt" % n):
			gleich(ist[n], soll[n], "Fx.%s: Argumente/Vorgaben" % n)
	# Fx.post bleibt die Schnittstelle zum Post-Effekt (Main setzt sie)
	pruefe(typeof(Fx.post) in [TYPE_NIL, TYPE_OBJECT], "Fx.post gibt es")
