extends "res://tests/testfall.gd"
## STATIONSKARTE (Screen nach jeder Station), gestaltet nach brand/DESIGN-PROMPT.md
## statt im „Standard-KI-Look“ (Rückmeldung 11/2026): Prüfvermerke kommen
## nacheinander, der „GEPRÜFT“-Stempel nur bei drei von drei, nichts ragt aus dem
## Bild oder überdeckt sich (alle Stationen, alle Sprachen), keine Sterne, kein
## Funkenregen, nichts zentriert gestapelt, und nach dem Auftritt steht das Bild.

const SPRACHEN := ["de", "en", "fr", "es", "zh", "hi"]
const RAND := 40.0              # Mindestabstand zum Bildrand

var schichten: Array = []
var _alter_index := -1


func aufraeumen() -> void:
	Game.set_lang(Game.default_lang)
	if _alter_index >= 0:
		Game.level_index = _alter_index
	for s in schichten:
		if is_instance_valid(s):
			s.queue_free()
	schichten.clear()
	await frames(2)


## Karte wie in Main._on_level_completed, aber ohne gespielte Station davor.
func _karte(id: String, medaillen: Array) -> LevelCard:
	if _alter_index < 0:
		_alter_index = Game.level_index
	var data := LevelData.load_level(id)
	Game.level_index = maxi(0, Game.playlist.find(id))
	var m := {"zeit": "zeit" in medaillen, "bits": "bits" in medaillen, "lueckenlos": "lueckenlos" in medaillen}
	var total := maxi(1, data.bits_total)
	var result := {
		"level_id": id, "time": data.par_time * (0.8 if m.zeit else 1.3), "par": data.par_time,
		"bits": total if m.bits else total - 1, "bits_total": total, "seen": 0 if m.lueckenlos else 2, "medals": m,
	}
	var schicht := CanvasLayer.new()
	schicht.layer = 10
	baum.root.add_child(schicht)
	schichten.append(schicht)
	var karte := LevelCard.new()
	schicht.add_child(karte)
	karte.setup(data, result, Game.level_index + 1 < Game.playlist.size())
	return karte


static func _labels(n: Node) -> Array[Label]:
	var out: Array[Label] = []
	for c in n.find_children("*", "Label", true, false):
		out.append(c)
	return out


func test_pruefvermerke_kommen_nacheinander() -> void:
	var karte := _karte("04-die-huelle", ["zeit", "bits", "lueckenlos"])
	var v: Array = karte._vermerke
	if not gleich(v.size(), 3, "drei Zeilen auf der Tafel"):
		return
	await frames(int(0.3 * 60))
	pruefe(v.all(func(x): return x.modulate.a == 0.0), "vor 0,6 s noch kein Prüfvermerk")
	await frames(int(0.5 * 60))       # 0,8 s
	pruefe(v[0].modulate.a > 0.5 and v[2].modulate.a == 0.0, "bei 0,8 s nur der erste Vermerk (%.2f / %.2f)" % [v[0].modulate.a, v[2].modulate.a])
	await frames(int(0.9 * 60))       # 1,7 s
	pruefe(v.all(func(x): return x.modulate.a > 0.99 and x.scale.is_equal_approx(Vector2.ONE)), "bei 1,7 s alle drei Vermerke fest")


func test_stempel_nur_bei_drei_von_drei() -> void:
	for med in [[], ["zeit"], ["zeit", "bits"], ["bits", "lueckenlos"]]:
		var k := _karte("01-stammdaten", med)
		pruefe(k.stempel == null, "kein Stempel bei %s" % [med])
	var alle := _karte("01-stammdaten", ["zeit", "bits", "lueckenlos"])
	if not pruefe(alle.stempel != null, "Stempel bei drei von drei"):
		return
	var texte := _labels(alle.stempel).map(func(l): return l.text)
	pruefe(str(TranslationServer.translate("Geprüft")) in texte, "Stempel sagt „GEPRÜFT“: %s" % [texte])
	gleich(alle.stempel.modulate.a, 0.0, "Stempel kommt erst nach den Vermerken")
	await frames(int(2.1 * 60))
	pruefe(alle.stempel.modulate.a > 0.99 and alle.stempel.scale.is_equal_approx(Vector2.ONE), "Stempel sitzt nach 2,1 s")


func test_kein_standard_ki_look() -> void:
	var karte := _karte("19-berechtigungen", ["zeit", "bits", "lueckenlos"])
	await frames(int(2.6 * 60))
	for l in _labels(karte):
		pruefe(not ("★" in l.text or "☆" in l.text), "keine Sterne als Schriftzeichen: „%s“" % l.text)
		pruefe(l.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER, "nichts zentriert gestapelt: „%s“" % l.text)
		pruefe(not l.text.begins_with("✓"), "Haken als Linie, nicht als Zeichen: „%s“" % l.text)
	var funken := karte.find_children("*", "CPUParticles2D", true, false).size() + karte.find_children("*", "GPUParticles2D", true, false).size()
	gleich(funken, 0, "kein Funkenregen")


func test_nach_dem_auftritt_steht_das_bild() -> void:
	# Früher drehte sich ein Strahlenkranz ohne Ende, die Fläche wurde jedes Bild neu
	# gezeichnet. Jetzt: Auftritt, dann Ruhe.
	var karte := _karte("13-e-rezept", ["zeit"])
	var gezeichnet := [0]
	karte.draw.connect(func(): gezeichnet[0] += 1)
	await frames(60)
	if not pruefe(gezeichnet[0] > 0, "während des Auftritts wird gezeichnet (sonst misst der Test nichts)"):
		return
	await frames(int(1.6 * 60))      # 2,6 s
	gezeichnet[0] = 0
	await frames(60)
	gleich(gezeichnet[0], 0, "zwischen 2,6 und 3,6 s zeichnet die Karte nicht mehr neu")


func test_nichts_ragt_heraus_in_allen_sprachen() -> void:
	var karten: Array = []
	for sprache in SPRACHEN:
		Game.set_lang(sprache)
		for id in Game.playlist:
			karten.append([sprache, id, _karte(str(id), ["zeit", "bits", "lueckenlos"])])
	await frames(int(1.0 * 60))      # Auftritt (Spalte, Tafel) ist durch
	var bild := Rect2(RAND, RAND, 1920.0 - 2.0 * RAND, 1080.0 - 2.0 * RAND)
	var fehlerzahl := 0
	for e in karten:
		var wo := "%s/%s" % [e[0], e[1]]
		var karte: LevelCard = e[2]
		var links: Control = karte._spalte        # Eyebrow, Name, Merksatz, Pille
		var tafel: Control = karte._tafel
		var knopf: Control = karte._weiter
		var fuss: Control = karte._fuss
		var ok := true
		for l in _labels(karte):
			if l.text == "" or not l.is_visible_in_tree():
				continue
			var r := l.get_global_rect()
			ok = pruefe(bild.encloses(r), "%s: „%s“ ragt aus dem Bild %s" % [wo, l.text.left(30), r]) and ok
			# Text darf nicht über das Label hinauslaufen (ein Wort zu lang für die Zeile).
			# Chinesisch bricht zwischen beliebigen Zeichen um, dort gibt es keine Wörter.
			if e[0] == "zh":
				continue
			var f: Font = l.label_settings.font
			for wort in l.text.split(" ", false):
				var w := f.get_string_size(wort, HORIZONTAL_ALIGNMENT_LEFT, -1, l.label_settings.font_size).x
				ok = pruefe(w <= r.size.x + 2.0, "%s: „%s“ breiter als die Zeile (%d > %d)" % [wo, wort, w, r.size.x]) and ok
		var lr := links.get_global_rect()
		ok = pruefe(lr.end.x <= LevelCard.PX - 40.0, "%s: linke Spalte reicht in die Tafel" % wo) and ok
		ok = pruefe(knopf.get_global_rect().position.y >= tafel.get_global_rect().end.y + 20.0, "%s: Knopf liegt auf der Tafel" % wo) and ok
		# Fußnote: gemessen am Text, nicht am Kasten (der kann höher sein als sein Inhalt)
		var fl := _labels(fuss)
		if fl.is_empty():
			continue
		var fuss_oben := fl[0].get_global_rect().position.y
		var fuss_unten := fl[-1].get_global_rect().end.y
		ok = pruefe(fuss_oben >= lr.end.y + 24.0, "%s: Fußnote überdeckt den Text darüber" % wo) and ok
		if fuss_oben > lr.end.y + 40.0:
			ok = nahe(fuss_unten, knopf.get_global_rect().end.y, 2.0, "%s: Fußnote und Knopf auf einer Grundlinie" % wo) and ok
		if not ok:
			fehlerzahl += 1
	gleich(fehlerzahl, 0, "Karten mit Layoutfehlern (von %d)" % karten.size())


func test_merksatz_ohne_haekchen_davor() -> void:
	for id in Game.playlist:
		var data := LevelData.load_level(str(id))
		var s := LevelCard.merksatz(data)
		pruefe(s != "" and not s.begins_with("✓"), "%s: Merksatz „%s“" % [id, s])


func test_lange_namen_bleiben_in_der_spalte() -> void:
	var f := Brand.headline()
	for name in ["Versichertenstammdaten", "Die Berechtigungen", "बीमित व्यक्ति का मूल डेटा", "La receta electrónica"]:
		var g := LevelCard.titel_groesse(name, LevelCard.LW)
		pruefe(g >= 56 and g <= 104, "%s: Größe %d" % [name, g])
		for wort in name.split(" ", false):
			pruefe(f.get_string_size(wort, HORIZONTAL_ALIGNMENT_LEFT, -1, g).x <= LevelCard.LW, "%s: „%s“ passt bei %d px" % [name, wort, g])
	# Ausgeglichener Umbruch: kein Wort allein in der letzten Zeile
	var font := Brand.sans("roman")
	var satz := "Rechte vergeben — drei Türen, eine Entscheidung: deine."
	var b := LevelCard.satzbreite(satz, font, 34, 700.0)
	var w := font.get_string_size(satz, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	if w > 700.0:
		pruefe(b < 700.0 and b >= w / 2.0, "zwei gleich lange Zeilen: Breite %d für %d" % [b, w])
