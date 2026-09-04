extends Node
## SFX — Klang-Seite des Game Feel. Alle Klänge kommen aus godot/assets/audio
## (erzeugt von tools/gen_assets.py). Eigener WAV-Loader, damit die Dateien
## ohne Editor-Import laufen (Kommandozeile, Export-Filter *.wav).

const DIR := "res://assets/audio/"
const POOL_SIZE := 10
const SETTINGS := "user://einstellungen.cfg"

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # Klänge und Musik auch in der Pause
	enabled = bool(Game.config.get("audio", true))
	_load_settings()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	add_child(_music)


## Klang oder Musik laden: MP3 (Musik aus lizenzfreien Quellen, siehe assets/audio/
## CREDITS.md) hat Vorrang, sonst WAV (erzeugte Klänge aus gen_assets.py).
func _stream(name: String, loop := false) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var s: AudioStream = null
	var mp3 := DIR + name + ".mp3"
	if ResourceLoader.exists(mp3):
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
	_streams[name] = s
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


## Nutzerwahl Musik/Töne aus user://einstellungen.cfg (überlebt Neustart und Idle-Reset).
func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		music_on = bool(cf.get_value("audio", "musik", true))
		sound_on = bool(cf.get_value("audio", "toene", true))


func _save_settings() -> void:
	var cf := ConfigFile.new()
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
		music_stop(0.4)
		_wanted = _wanted   # bleibt gemerkt


func set_sound(on: bool) -> void:
	sound_on = on
	_save_settings()


## Pause: Musik leiser (bleibt hörbar), Fortsetzen holt sie zurück.
func music_pause(on: bool) -> void:
	if not _music.playing:
		return
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -26.0 if on else -14.0, 0.3)


## Einen Klang abspielen. pitch 1.0 = original, vol in dB relativ.
func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not enabled or not sound_on:
		return
	var s := _stream(name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return
	# Pool voll: ältesten überschreiben
	var p := _pool[0]
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
	_music_tween.tween_property(_music, "volume_db", -14.0, fade)


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
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -14.0 + amount_db, 0.05)
	tw.tween_interval(seconds)
	tw.tween_property(_music, "volume_db", -14.0, 0.5)
