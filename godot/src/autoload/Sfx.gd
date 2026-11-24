extends Node
## SFX — Klang-Seite des Game Feel. Alle Klänge kommen aus godot/assets/audio
## (erzeugt von tools/gen_assets.py). Eigener WAV-Loader, damit die Dateien
## ohne Editor-Import laufen (Kommandozeile, Export-Filter *.wav).

const DIR := "res://assets/audio/"
const POOL_SIZE := 10
const SETTINGS := "user://einstellungen.cfg"
## Grundpegel der Musik unter den Klängen (dB auf dem Musik-Bus)
const MUSIC_DB := -14.0
const MUSIC_PAUSE_DB := -26.0
## Alle Klänge, die das Spiel benutzt — werden beim Start geladen, damit das erste
## Abspielen keinen Ruckler macht (im Browser läuft alles in einem Thread).
const PRELOAD := [
	"bonus", "checkpoint", "collect", "deny", "double_jump", "gate", "hurt", "jump",
	"land", "medal", "ok", "seal", "spring", "tick", "toggle_on", "toggle_off", "ui",
	"vau", "wallslide",
]
const MUSIC_PRELOAD := ["music_title", "music_level", "music_level2", "music_reward"]
const VOLUME_STEP := 0.1

var enabled := true        # Gesamtschalter aus der Konfiguration (audio)
var music_on := true       # Nutzerwahl: Musik (Hauptmenü / Pause, gespeichert)
var sound_on := true       # Nutzerwahl: Töne
var _wanted := ""          # zuletzt gewünschte Musik — läuft an, sobald Musik wieder an ist
var _wanted_loop := true
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween
var _music_db := MUSIC_DB  # Zielpegel der Musik (normal oder Pause), Duck kehrt dorthin zurück
## Gesamtlautstärke 0..1 — legt das Standpersonal fest (Strg+F9 / Strg+F10 oder
## --lautstaerke=70), gespeichert in user://einstellungen.cfg.
var volume := 1.0
var _bus_music := 0
var _bus_sfx := 0
var _started_ms: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # Klänge und Musik auch in der Pause
	enabled = bool(Game.config.get("audio", true))
	_load_settings()
	_build_buses()
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--lautstaerke="):
			volume = clampf(float(str(a).get_slice("=", 1)) / 100.0, 0.0, 1.0)
	_apply_volume()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
		_started_ms.append(0)
	_music = AudioStreamPlayer.new()
	_music.bus = "Musik"
	_music.volume_db = MUSIC_DB
	add_child(_music)
	if enabled:
		for n in PRELOAD:
			_stream(n)
		for n in MUSIC_PRELOAD:
			_stream(n, n != "music_reward")


## Busse „Musik" und „SFX" unter Master, auf Master ein harter Begrenzer: Viele
## Klänge gleichzeitig (Kombo, Siegel + Musik) dürfen nicht übersteuern.
## Zur Laufzeit angelegt, damit keine Bus-Datei im Projekt nötig ist.
func _build_buses() -> void:
	for bus_name in ["Musik", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
		if bus_name == "Musik":
			_bus_music = idx
		else:
			_bus_sfx = idx
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		lim.pre_gain_db = 0.0
		AudioServer.add_bus_effect(master, lim)
	# Klänge etwas unter 0 dB: Spitzen bis −1,9 dBFS je Klang, mehrere summieren sich
	AudioServer.set_bus_volume_db(_bus_sfx, -3.0)


func _apply_volume() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(master, volume <= 0.001)


## Gesamtlautstärke in Stufen (Standpersonal). Gibt den neuen Wert zurück.
func change_volume(delta: float) -> float:
	volume = clampf(snappedf(volume + delta, VOLUME_STEP), 0.0, 1.0)
	_apply_volume()
	_save_settings()
	play("tick")
	return volume


## Messe-Kiosk: Musik/Töne aus gilt nur für den laufenden Besucher. Beim Idle-Reset
## (und beim Start im Kiosk) ist beides wieder an — sonst bleibt der Stand stumm,
## wenn ein Besucher im Hauptmenü auf „Musik aus" tippt.
func reset_visitor_choices() -> void:
	sound_on = true
	if not music_on:
		music_on = true
		var w := _wanted
		_music_name = ""
		if w != "":
			music(w, 0.8, _wanted_loop)


func _persist_visitor_choices() -> bool:
	# Kiosk ist ein späterer Autoload — beim Laden der Einstellungen evtl. noch nicht
	# da; Kiosk._ready setzt die Besucherwahl im Messe-Modus dann selbst zurück.
	var k := get_node_or_null("/root/Kiosk")
	return k == null or not bool(k.get("kiosk_mode"))


## Klang oder Musik laden: MP3 (Musik aus lizenzfreien Quellen, siehe assets/audio/
## CREDITS.md) hat Vorrang, sonst WAV (erzeugte Klänge aus gen_assets.py).
func _stream(name: String, loop := false) -> AudioStream:
	var key := name + ("@loop" if loop else "")
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = null
	var ogg := DIR + name + ".ogg"
	var mp3 := DIR + name + ".mp3"
	if ResourceLoader.exists(ogg):
		var o := load(ogg) as AudioStreamOggVorbis
		if o:
			o = o.duplicate()
			o.loop = loop
			s = o
	elif FileAccess.file_exists(ogg):
		var o2 := AudioStreamOggVorbis.load_from_file(ogg)
		if o2:
			o2.loop = loop
			s = o2
	elif ResourceLoader.exists(mp3):
		var m := load(mp3) as AudioStreamMP3
		if m:
			m = m.duplicate()
			m.loop = loop
			s = m
	elif FileAccess.file_exists(mp3):
		var m2 := AudioStreamMP3.new()
		m2.data = FileAccess.get_file_as_bytes(mp3)
		m2.loop = loop
		s = m2
	if s == null:
		var path := DIR + name + ".wav"
		var w: AudioStreamWAV = null
		# Exportierter Build: Godot packt die importierte Ressource, nicht die Rohdatei
		if ResourceLoader.exists(path):
			w = load(path) as AudioStreamWAV
			if w and loop:
				w = w.duplicate()
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = w.data.size() / (2 * (2 if w.stereo else 1))
		if w == null:
			w = _load_wav(path, loop)
		s = w
	_streams[key] = s
	return s


## Minimaler PCM-16-WAV-Leser (mono/stereo, 16 Bit).
static func _load_wav(path: String, loop: bool) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		push_warning("Klang fehlt: %s" % path)
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		push_warning("Kein WAV: %s" % path)
		return null
	var channels := 1
	var rate := 44100
	var bits := 16
	var pos := 12
	var data := PackedByteArray()
	while pos + 8 <= bytes.size():
		var id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		var body := pos + 8
		if id == "fmt ":
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
		elif id == "data":
			data = bytes.slice(body, body + size)
		pos = body + size + (size & 1)
	if bits != 16 or data.is_empty():
		push_warning("WAV-Format nicht unterstützt (%d Bit): %s" % [bits, path])
		return null
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = channels == 2
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = data.size() / (2 * channels)
	return s


## Einstellungen aus user://einstellungen.cfg: Lautstärke immer; die Besucherwahl
## Musik/Töne nur außerhalb des Messe-Kiosks (dort startet jeder Besucher mit Ton).
func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		volume = clampf(float(cf.get_value("audio", "lautstaerke", 1.0)), 0.0, 1.0)
		if _persist_visitor_choices():
			music_on = bool(cf.get_value("audio", "musik", true))
			sound_on = bool(cf.get_value("audio", "toene", true))


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)   # vorhandene Werte (z. B. Besucherwahl außerhalb des Kiosks) behalten
	cf.set_value("audio", "lautstaerke", volume)
	if _persist_visitor_choices():
		cf.set_value("audio", "musik", music_on)
		cf.set_value("audio", "toene", sound_on)
	cf.save(SETTINGS)


## Musik an/aus: aus blendet die laufende Musik weg, an startet die zuletzt gewünschte.
func set_music(on: bool) -> void:
	music_on = on
	_save_settings()
	if on:
		var w := _wanted
		_music_name = ""
		if w != "":
			music(w, 0.8, _wanted_loop)
	else:
		music_stop(0.4)   # _wanted bleibt gemerkt


func set_sound(on: bool) -> void:
	sound_on = on
	_save_settings()


## Pause: Musik leiser (bleibt hörbar), Fortsetzen holt sie zurück.
func music_pause(on: bool) -> void:
	if not _music.playing:
		return
	if _music_tween:
		_music_tween.kill()
	_music_db = MUSIC_PAUSE_DB if on else MUSIC_DB
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", _music_db, 0.3)


## Einen Klang abspielen. pitch 1.0 = original, vol in dB relativ.
func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not enabled or not sound_on:
		return
	var s := _stream(name)
	if s == null:
		return
	var idx := -1
	for i in _pool.size():
		if not _pool[i].playing:
			idx = i
			break
	if idx < 0:
		# Pool voll: den am längsten laufenden Klang überschreiben
		idx = 0
		for i in _pool.size():
			if _started_ms[i] < _started_ms[idx]:
				idx = i
	var p := _pool[idx]
	_started_ms[idx] = Time.get_ticks_msec()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


## Musik wechseln (Überblendung). loop=false für einmalige Stücke (Reward).
func music(name: String, fade := 0.8, loop := true) -> void:
	_wanted = name
	_wanted_loop = loop
	if not enabled or not music_on or _music_name == name:
		return
	_music_name = name
	var s := _stream(name, loop)
	if s == null:
		return
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -40.0, fade * 0.5)
		_music_tween.tween_callback(_swap_music.bind(s))
	else:
		_music.stream = s
		_music.volume_db = -40.0
		_music.play()
	_music_db = MUSIC_DB
	_music_tween.tween_property(_music, "volume_db", _music_db, fade)


func _swap_music(s: AudioStream) -> void:
	_music.stream = s
	_music.play()


func music_stop(fade := 0.6) -> void:
	_music_name = ""
	if not _music.playing:
		return
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -40.0, fade)
	_music_tween.tween_callback(_music.stop)


## Kurzer Duck der Musik (z. B. beim Siegel), kehrt von selbst zurück.
func music_duck(amount_db := -8.0, seconds := 0.6) -> void:
	if not _music.playing:
		return
	# Läuft gerade eine Blende (Wechsel, Stopp, Pause), hat die Vorrang.
	if _music_tween and _music_tween.is_running():
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", _music_db + amount_db, 0.05)
	_music_tween.tween_interval(seconds)
	_music_tween.tween_property(_music, "volume_db", _music_db, 0.5)


## Beim Beenden alle Klänge anhalten (sonst meldet Godot laufende Wiedergaben als Leck).
func _exit_tree() -> void:
	for p in _pool:
		p.stop()
	if _music:
		_music.stop()
