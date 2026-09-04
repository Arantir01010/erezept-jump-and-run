class_name Huelle
extends RefCounted
## HÜLLE — die Kernmechanik (KAPSEL 2.1), Godot-Port von src/state/HuelleState.ts.
##
##   Klartext       — schnell, kann andocken, aber für Lauscher SICHTBAR
##   Verschlüsselt  — langsam, kann NICHT andocken, dafür unsichtbar
##   VAU            — schnell UND unsichtbar UND andockfähig, nur im Feld,
##                    optional nur solange die Sitzung frisch ist
##
## Fachliche Leitplanken: Die VAU ist kein Tunnel, sondern ein Raum. Diese
## Klasse kennt keine Signatur (Verschlüsselung ≠ Signatur). Läuft die Sitzung
## ab, fällt der Spieler in den KLARTEXT zurück (sichtbar) — das ist die Lehre.

signal changed(from: String, to: String, reason: String)

const KLARTEXT := "klartext"
const VERSCHLUESSELT := "verschluesselt"
const VAU := "vau"

const TUNING := {
	KLARTEXT: {"speed": 1.0, "sichtbar": true, "andock": true},
	VERSCHLUESSELT: {"speed": 0.8, "sichtbar": false, "andock": false},
	VAU: {"speed": 1.0, "sichtbar": false, "andock": true},
}

var state := KLARTEXT
var locked := false
var toggle_cooldown := 0.15
var _before_vau := KLARTEXT
var _last_toggle := -1000.0
var _ttl := 0.0
var _left := 0.0
var _clock := 0.0


func reset(start := KLARTEXT) -> void:
	var from := state
	state = start
	_before_vau = start
	_last_toggle = -1000.0
	_ttl = 0.0
	_left = 0.0
	locked = false
	changed.emit(from, state, "reset")


var speed_factor: float:
	get: return TUNING[state]["speed"]

var sichtbar: bool:
	get: return TUNING[state]["sichtbar"]

var andockfaehig: bool:
	get: return TUNING[state]["andock"]

var in_vau: bool:
	get: return state == VAU

var vau_expires: bool:
	get: return in_vau and _ttl > 0.0

var vau_ratio: float:
	get:
		if not vau_expires:
			return 1.0
		return clampf(_left / _ttl, 0.0, 1.0)

var vau_left: float:
	get: return maxf(0.0, _left) if vau_expires else 0.0


func can_toggle() -> bool:
	return not locked and not in_vau and _clock - _last_toggle >= toggle_cooldown


## Klartext ⇄ Verschlüsselt. In der VAU bewusst wirkungslos.
func toggle() -> bool:
	if not can_toggle():
		return false
	var from := state
	state = VERSCHLUESSELT if from == KLARTEXT else KLARTEXT
	_before_vau = state
	_last_toggle = _clock
	changed.emit(from, state, "toggle")
	return true


func enter_vau(ttl := 0.0) -> bool:
	if in_vau:
		if ttl > 0.0:
			_ttl = ttl
			_left = ttl
		return false
	var from := state
	_before_vau = from
	state = VAU
	_ttl = maxf(0.0, ttl)
	_left = _ttl
	changed.emit(from, state, "enter-vau")
	return true


func leave_vau() -> bool:
	if not in_vau:
		return false
	var from := state
	state = KLARTEXT if _before_vau == VAU else _before_vau
	_ttl = 0.0
	_left = 0.0
	changed.emit(from, state, "leave-vau")
	return true


func refresh_session() -> bool:
	if not vau_expires:
		return false
	_left = _ttl
	return true


## Zeit vergeht. Abgelaufene Sitzung → Klartext (sichtbar!).
func tick(delta: float) -> void:
	_clock += delta
	if not vau_expires:
		return
	_left -= delta
	if _left > 0.0:
		return
	var from := state
	state = KLARTEXT
	_before_vau = KLARTEXT
	_ttl = 0.0
	_left = 0.0
	changed.emit(from, state, "session-expired")


static func color_of(s: String) -> Color:
	match s:
		VERSCHLUESSELT: return Palette.COOL
		VAU: return Palette.VAU
		_: return Palette.WARM


static func label_of(s: String) -> String:
	match s:
		VERSCHLUESSELT: return str(TranslationServer.translate("VERSCHLÜSSELT"))
		VAU: return "VAU"
		_: return str(TranslationServer.translate("KLARTEXT"))
