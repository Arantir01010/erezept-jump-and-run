extends RefCounted
## LÄUFER — ein einfacher Spieler für den Durchspieltreiber (tests/durchspiel.gd
## -- --suche=<station>). Er läuft nach rechts, springt über Lücken, Störfelder und
## Mauern und drückt an der PIN-Schleuse im Takt. Sprünge sucht er, indem er Pauls
## Bewegung vorausrechnet: dieselbe Rechnung wie Player._physics_process (Werte aus
## Player.T), Kollisionen über Player.test_move gegen die echten Körper (Gelände,
## Tore, Plattformen an ihrer jetzigen Stelle), Störfelder und Federn als Rechtecke.
## Die Kralle (deny-enemy) gilt als Störfeld, bis sie sich sperrt — er wartet sie ab;
## am Signatur-Stempel (stamp-exit) drückt er, wenn der Stempel oben steht.
## Er springt so spät wie möglich und nimmt den ersten sicheren Plan aus einer festen
## Liste (voller Sprung, mit Doppelsprung, mit früh losgelassenem Rechts, kurze Hüpfer).
##
## Er spielt nur über Eingabeereignisse (Input.parse_input_event) — genau das, was die
## Aufnahme (src/autoload/Aufnahme.gd) von einem Menschen mitschreibt. Entschieden wird
## am Anfang jedes Bildes (process_frame, nach Physikschritt s); was er drückt, wirkt ab
## Schritt s+1, dort beginnt auch die Vorausrechnung. Weicht Paul mehr als ABWEICHUNG
## vom vorausgerechneten Weg ab, rechnet er neu.
##
## Kann er nicht: Ducken, Hülle-Wechsel, Karten, Andocken, Rückwege, Tunnelkamera —
## solche Stationen nimmt ein Mensch auf (--aufnahme=…).

const DT := 1.0 / 60.0
## Player._ready: floor_snap_length
const SCHNAPP := 8.0
## Basics.Spring._on_enter: p.bounce(2100.0), nur wenn Paul nicht schnell steigt
const FEDER := 2100.0
const FEDER_STEIGT := -50.0
## Player._physics_process: Doppelsprung setzt _var_jump = 0.14
const DOPPEL_VAR := 0.14
const DOPPEL_HALTEN := 9
const LAUF_SCHRITTE := 48
const MAX_FLUG := 150
const ABWEICHUNG := 6.0
const FORTSCHRITT := 24.0
## Schritte Rückzug nach links, wenn Paul zu dicht vor einem Störfeld oder einer Lücke steht
const RUECKZUG := 24

## Varianten der Suche: [Name, Vorlauf in Schritten, Vorsicht in px]
const VARIANTEN := [["Standard", 12, 4.0], ["vorsichtig", 10, 10.0], ["knapp", 16, 1.0], ["früh", 24, 6.0]]

## Sprünge vom Boden in der Reihenfolge, in der sie versucht werden:
## (Sprungtaste halten, rechts halten, Doppelsprung ab Schritt; -1 = keiner, 999 = immer)
const BODEN := [
	Vector3i(12, 999, -1),
	Vector3i(12, 999, 18), Vector3i(12, 999, 24), Vector3i(12, 999, 30), Vector3i(12, 999, 14),
	Vector3i(12, 30, -1), Vector3i(12, 22, -1), Vector3i(12, 16, -1), Vector3i(12, 10, -1), Vector3i(12, 5, -1),
	Vector3i(6, 999, -1), Vector3i(6, 14, -1), Vector3i(6, 8, -1),
	Vector3i(2, 999, -1), Vector3i(2, 8, -1),
	Vector3i(12, 0, -1), Vector3i(12, 999, 40), Vector3i(12, 20, 24),
]
## In der Luft: (Doppelsprung ab Schritt, rechts halten, danach: 0 = loslassen, -1 = links)
const LUFT := [
	Vector3i(0, 999, 0), Vector3i(0, 12, 0), Vector3i(0, 0, 0), Vector3i(6, 999, 0), Vector3i(12, 999, 0),
	Vector3i(-1, 0, 0), Vector3i(-1, 0, -1), Vector3i(0, 0, -1), Vector3i(-1, 8, 0),
]
const TASTEN: Array[String] = ["move_left", "move_right", "jump", "action"]


## Pauls Bewegungszustand für die Vorausrechnung (die Felder von Player und SprungFenster).
class Zustand:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var boden := false
	var doppelt := true
	var var_sprung := 0.0
	var coyote := 0.0
	var puffer := 0.0
	var gehalten := false
	var wand := 0            # -1/+1: Wand links/rechts berührt (letzter Schritt)
	var sperre := 0.0        # Wandsprung: keine Steuerung (Player._wall_lock)

	func kopie() -> Zustand:
		var z := Zustand.new()
		z.pos = pos
		z.vel = vel
		z.boden = boden
		z.doppelt = doppelt
		z.var_sprung = var_sprung
		z.coyote = coyote
		z.puffer = puffer
		z.gehalten = gehalten
		z.wand = wand
		z.sperre = sperre
		return z


## Eine Eingabefolge (je Schritt: Richtung, Sprungtaste) und was die Rechnung ergab.
class Plan:
	var name := ""
	var ax := PackedFloat32Array()
	var sprung := PackedByteArray()
	var orte := PackedVector2Array()
	var ausgang := ""        # gelandet, ziel, stoss, grube, mauer, offen
	var problem_bei := -1    # erster Schritt (0 = s+1) mit Stoß, Grube oder Mauer
	var ende := Vector2.ZERO


var name := ""
var vorlauf := 12
var vorsicht := 4.0
## Zahl der Neuplanungen (für den Bericht der Suche)
var planungen := 0
## Jede Entscheidung mit ihren Kandidaten ausgeben (--protokoll)
var protokoll := false

var _level: Level
var _paul: Player
var _stoss := KinematicCollision2D.new()
var _gefahren: Array[Rect2] = []
var _federn: Array[Rect2] = []
var _schleusen: Array[Mechanic] = []
var _krallen: Array[Mechanic] = []
var _stempel: Array[Mechanic] = []
var _bewegliche: Array[Rect2] = []   # Störfelder dieses Bildes (Krallen, solange sie greifen können)
var _tuer: Basics.DoorExit
var _tuer_rect := Rect2()
var _tuer_offen := false
var _grube_y := 0.0
var _halb_b := 15.0
var _hoehe := 63.0
var _stand: Dictionary[String, bool] = {}
var _plan: Plan
var _plan_i := 0
var _rueckzug := 0
var _gewaehlt := -1     # Index (BODEN) des zuletzt gefundenen Sprungs

# Werte aus Player.T (beim Einrichten gelesen)
var _lauf := 540.0
var _beschl := 6000.0
var _luft := 0.65
var _sprung_v := 630.0
var _var_s := 0.2
var _halb_g := 240.0
var _schub := 240.0
var _doppel_v := 560.0
var _schwere := 5400.0
var _fall_max := 960.0
var _coyote_s := 0.1
var _puffer_s := 0.1
var _wand_rutsch := 240.0
var _wand_x := 780.0
var _wand_y := 630.0
var _wand_sperre := 0.16


func _init(variante := 0) -> void:
	var v: Array = VARIANTEN[clampi(variante, 0, VARIANTEN.size() - 1)]
	name = v[0]
	vorlauf = v[1]
	vorsicht = v[2]
	for t in TASTEN:
		_stand[t] = false


## Ein Bild: Station lesen, entscheiden, Tasten setzen (vor dem nächsten Physikschritt).
func takt(lvl: Level) -> void:
	if lvl == null or lvl.finished or not is_instance_valid(lvl.player):
		alles_los()
		return
	if lvl != _level:
		_einrichten(lvl)
	_tuer_offen = _tuer != null and is_instance_valid(_tuer) and _tuer.unlocked
	_krallen_lesen()
	if _paul.controls_locked or _paul._hurt_left > 0.0:
		_plan = null
		return
	var schleuse := _schleuse()
	if schleuse != null:
		_plan = null
		_setze("move_left", false)
		_setze("move_right", false)
		_setze("jump", false)
		_setze("action", _im_takt(schleuse) and not _stand["action"])
		return
	var stempel := _offener_stempel()
	if stempel != null:
		_plan = null
		_setze("move_left", false)
		_setze("move_right", false)
		_setze("jump", false)
		var oben: bool = stempel.get("stamp_up")
		_setze("action", oben and not _stand["action"])
		return
	_setze("action", false)
	var z := _zustand()
	if _plan != null:
		if _plan_i < _plan.ax.size() and _plan_i <= _plan.orte.size() and z.pos.distance_to(_plan.orte[_plan_i - 1]) <= ABWEICHUNG:
			_ausfuehren()
			return
		_plan = null
	planungen += 1
	if _rueckzug > 0:
		_rueckzug -= 1
		_druecken(-1.0, false)
		return
	if z.boden or z.coyote > 0.0:
		_am_boden(z)
	else:
		_in_der_luft(z)


## Alle Tasten des Läufers loslassen.
func alles_los() -> void:
	for t in TASTEN:
		_setze(t, false)
	_plan = null
	_rueckzug = 0


# ------------------------------------------------------------------ Entscheiden

func _am_boden(z: Zustand) -> void:
	var lauf := _rechnen(z, _laufplan(LAUF_SCHRITTE), false)
	if protokoll:
		_melden("Boden %s v=%s laufen: %s bei %d" % [z.pos, z.vel, lauf.ausgang, lauf.problem_bei])
	if lauf.problem_bei < 0 or lauf.problem_bei > vorlauf:
		_druecken(1.0, false)
		return
	var sprung := _bester_sprung(z)
	var wahl := _gewaehlt
	if sprung != null and lauf.problem_bei > 1:
		# So spät wie möglich: geht derselbe (oder ein früher gelisteter) Sprung auch noch
		# nach einem weiteren Schritt Anlauf?
		var spaeter := z.kopie()
		_schritt(spaeter, 1.0, false)
		if (spaeter.boden or spaeter.coyote > 0.0) and _bester_sprung(spaeter, wahl) != null:
			_druecken(1.0, false)
			return
	if sprung != null:
		_folgen(sprung)
		return
	if lauf.problem_bei > 1:
		_druecken(1.0, false)       # kein sicherer Sprung: noch näher heran
	elif lauf.ausgang == "mauer":
		_druecken(0.0, false)       # vor Mauer oder Tor stehen bleiben (Tor geht vielleicht auf)
	else:
		_rueckzug = RUECKZUG        # zu dicht vor Störfeld oder Lücke: Anlauf holen
		_druecken(-1.0, false)


func _in_der_luft(z: Zustand) -> void:
	var weiter := _rechnen(z, _luftplan(z, -1, 999, 0.0), true)
	if protokoll:
		_melden("Luft %s v=%s weiter: %s → %s" % [z.pos, z.vel, weiter.ausgang, weiter.ende])
	if _sicher(weiter, z, false):
		_folgen(weiter)
		return
	for k: Vector3i in LUFT:
		if k.x >= 0 and not z.doppelt:
			continue
		var p := _rechnen(z, _luftplan(z, k.x, k.y, float(k.z)), true)
		if protokoll:
			_melden("  %s: %s → %s" % [p.name, p.ausgang, p.ende])
		if _sicher(p, z, false):
			_folgen(p)
			return
	_folgen(weiter)


## Der erste sichere Sprung aus BODEN (höchstens bis Index `bis`), sein Index in _gewaehlt.
func _bester_sprung(z: Zustand, bis := -1) -> Plan:
	_gewaehlt = -1
	for i in BODEN.size():
		if bis >= 0 and i > bis:
			break
		var k: Vector3i = BODEN[i]
		var p := _rechnen(z, _sprungplan(z, k.x, k.y, k.z), true)
		if protokoll:
			_melden("  %s: %s bei %d → %s" % [p.name, p.ausgang, p.problem_bei, p.ende])
		if _sicher(p, z, true):
			_gewaehlt = i
			return p
	return null


func _melden(text: String) -> void:
	print("[läufer %d] %s" % [Aufnahme.schritt, text])


## Sicher: gelandet (vorwärts: mindestens FORTSCHRITT weiter rechts) oder an der offenen Tür.
func _sicher(p: Plan, z: Zustand, vorwaerts: bool) -> bool:
	if p.ausgang == "ziel":
		return true
	if p.ausgang != "gelandet":
		return false
	return not vorwaerts or p.ende.x >= z.pos.x + FORTSCHRITT


func _folgen(p: Plan) -> void:
	_plan = p
	_plan_i = 0
	_ausfuehren()


func _ausfuehren() -> void:
	_druecken(_plan.ax[_plan_i], _plan.sprung[_plan_i] != 0)
	_plan_i += 1


# ------------------------------------------------------------------ Pläne

func _laufplan(n: int) -> Plan:
	var p := Plan.new()
	p.name = "laufen"
	for i in n:
		p.ax.append(1.0)
		p.sprung.append(0)
	return p


## Vom Boden: Sprungtaste `halten` Schritte (eine gehaltene Taste erst loslassen),
## rechts bis `rechts`, Doppelsprung ab `doppel` (-1 = keiner).
func _sprungplan(z: Zustand, halten: int, rechts: int, doppel: int) -> Plan:
	var p := Plan.new()
	p.name = "sprung h%d r%d d%d" % [halten, rechts, doppel]
	var ab := 1 if z.gehalten else 0
	var zweiter := maxi(doppel, ab + halten + 1) if doppel >= 0 else -1
	for i in MAX_FLUG:
		p.ax.append(1.0 if i < rechts else 0.0)
		var an := (i >= ab and i < ab + halten) or (zweiter >= 0 and i >= zweiter and i < zweiter + DOPPEL_HALTEN)
		p.sprung.append(1 if an else 0)
	return p


## In der Luft: eine gehaltene Sprungtaste hält, solange der Sprung noch steigt;
## Doppelsprung ab `doppel` (-1 = keiner), rechts bis `rechts`, danach `danach`.
func _luftplan(z: Zustand, doppel: int, rechts: int, danach: float) -> Plan:
	var p := Plan.new()
	p.name = "luft d%d r%d %.0f" % [doppel, rechts, danach]
	var rest := ceili(z.var_sprung / DT) if z.gehalten and z.var_sprung > 0.0 else 0
	var zweiter := doppel
	if doppel >= 0 and z.gehalten:
		zweiter = maxi(doppel, rest + 1)
	for i in MAX_FLUG:
		p.ax.append(1.0 if i < rechts else danach)
		var an := i < rest or (zweiter >= 0 and i >= zweiter and i < zweiter + DOPPEL_HALTEN)
		p.sprung.append(1 if an else 0)
	return p


# ------------------------------------------------------------------ Vorausrechnung

## Rechnet `p` ab `start`. `bis_landung`: endet, sobald Paul nach einem Flug wieder
## steht — oder bei Ziel, Stoß, Grube, Mauer. Die Eingaben werden am Ende abgeschnitten,
## damit ax, sprung und orte gleich lang sind (auch ein Plan mit Problem wird befolgt,
## wenn in der Luft nichts Sicheres bleibt).
func _rechnen(start: Zustand, p: Plan, bis_landung: bool) -> Plan:
	var z := start.kopie()
	var flog := not z.boden
	var abflug := -1
	var mauer_seit := 0
	p.orte.clear()
	p.ausgang = "offen"
	p.problem_bei = -1
	for i in p.ax.size():
		var ax := p.ax[i]
		var war_boden := z.boden
		var blockiert := _schritt(z, ax, p.sprung[i] != 0)
		p.orte.append(z.pos)
		var koerper := Rect2(z.pos.x - _halb_b, z.pos.y - _hoehe, _halb_b * 2.0, _hoehe)
		if _tuer_offen and koerper.intersects(_tuer_rect):
			p.ausgang = "ziel"
			p.ende = z.pos
			_kuerzen(p, i + 1)
			return p
		if _trifft(koerper):
			p.ausgang = "stoss"
			p.problem_bei = i
			return _problem(p, z, i)
		if z.pos.y > _grube_y:
			p.ausgang = "grube"
			p.problem_bei = abflug if abflug >= 0 else i
			return _problem(p, z, i)
		if war_boden and not z.boden:
			abflug = i
		elif z.boden:
			abflug = -1
		if blockiert and z.boden and ax != 0.0:
			mauer_seit += 1
			if mauer_seit >= 2:
				p.ausgang = "mauer"
				p.problem_bei = maxi(0, i - 1)
				return _problem(p, z, i)
		else:
			mauer_seit = 0
		if bis_landung:
			if not z.boden:
				flog = true
			elif flog:
				p.ausgang = "gelandet"
				p.ende = z.pos
				_kuerzen(p, i + 1)
				return p
	p.ende = z.pos
	return p


func _kuerzen(p: Plan, n: int) -> void:
	p.ax.resize(n)
	p.sprung.resize(n)


func _problem(p: Plan, z: Zustand, i: int) -> Plan:
	p.ende = z.pos
	_kuerzen(p, i + 1)
	return p


## Ein Physikschritt wie Player._physics_process (ohne Ducken und Treffer).
## Rückgabe: Die waagerechte Bewegung stieß an.
func _schritt(z: Zustand, ax: float, sprung: bool) -> bool:
	var boden := z.boden
	if boden:
		z.doppelt = true
	var neu := sprung and not z.gehalten
	z.gehalten = sprung
	z.sperre = maxf(0.0, z.sperre - DT)
	# SprungFenster.schritt
	if boden:
		z.coyote = _coyote_s
	else:
		z.coyote -= DT
	if neu:
		z.puffer = _puffer_s
	else:
		z.puffer -= DT
	var mult := 1.0 if boden else _luft
	if z.sperre <= 0.0:
		if absf(z.vel.x) > _lauf and signf(z.vel.x) == signf(ax):
			z.vel.x = move_toward(z.vel.x, ax * _lauf, _beschl * 0.4 * mult * DT)
		else:
			z.vel.x = move_toward(z.vel.x, ax * _lauf, _beschl * mult * DT)
	var gleitet := not boden and z.wand != 0 and z.vel.y > 0.0 and ax != 0.0 and int(signf(ax)) == z.wand
	if z.puffer > 0.0:
		if z.coyote > 0.0:
			z.vel.y = -_sprung_v
			z.var_sprung = _var_s
			z.puffer = 0.0
			z.coyote = 0.0
			z.vel.x += _schub * ax
		elif gleitet:
			z.vel.x = -z.wand * _wand_x
			z.vel.y = -_wand_y
			z.var_sprung = _var_s
			z.sperre = _wand_sperre
			z.puffer = 0.0
			z.doppelt = true
		elif z.doppelt:
			z.doppelt = false
			z.vel.y = -_doppel_v
			z.var_sprung = DOPPEL_VAR
			z.puffer = 0.0
			z.coyote = 0.0
	if boden and z.vel.y > 0.0:
		z.vel.y = 0.0
	if not boden:
		if z.var_sprung > 0.0:
			z.var_sprung -= DT
			if sprung:
				z.vel.y = minf(z.vel.y, -_sprung_v if z.var_sprung > 0.0 else z.vel.y)
			else:
				z.var_sprung = 0.0
		var g := 0.5 if (sprung and absf(z.vel.y) < _halb_g) else 1.0
		z.vel.y = move_toward(z.vel.y, _fall_max, _schwere * g * DT)
		if gleitet:
			z.vel.y = minf(z.vel.y, _wand_rutsch)
	var blockiert := _bewegen(z, boden)
	var koerper := Rect2(z.pos.x - _halb_b, z.pos.y - _hoehe, _halb_b * 2.0, _hoehe)
	if z.vel.y >= FEDER_STEIGT:
		for f in _federn:
			if koerper.intersects(f):
				z.vel.y = -FEDER
				z.var_sprung = 0.0
				z.doppelt = true
				break
	return blockiert


## move_and_slide, vereinfacht: erst waagerecht, dann senkrecht (mit Bodenschnappen).
func _bewegen(z: Zustand, war_boden: bool) -> bool:
	var weg := z.vel * DT
	var blockiert := false
	z.wand = 0
	if weg.x != 0.0:
		if _paul.test_move(Transform2D(0.0, z.pos), Vector2(weg.x, 0.0), _stoss):
			z.pos.x += _stoss.get_travel().x
			z.wand = 1 if weg.x > 0.0 else -1
			z.vel.x = 0.0
			blockiert = true
		else:
			z.pos.x += weg.x
	z.boden = false
	if weg.y < 0.0:
		if _paul.test_move(Transform2D(0.0, z.pos), Vector2(0.0, weg.y), _stoss):
			z.pos.y += _stoss.get_travel().y
			z.vel.y = 0.0
		else:
			z.pos.y += weg.y
	else:
		var tief := weg.y + (SCHNAPP if war_boden else 0.0)
		if tief > 0.0 and _paul.test_move(Transform2D(0.0, z.pos), Vector2(0.0, tief), _stoss):
			z.pos.y += _stoss.get_travel().y
			z.vel.y = 0.0
			z.boden = true
		else:
			z.pos.y += weg.y
	return blockiert


func _trifft(koerper: Rect2) -> bool:
	for g in _gefahren:
		if koerper.intersects(g):
			return true
	for g in _bewegliche:
		if koerper.intersects(g):
			return true
	return false


## DenyEnemy.tick: Die Kralle trifft mit Rect2(x + _claw_x - 30, y - 9, 60, 18), _claw_x
## läuft bis ±reach. Bis sie sich sperrt (blocked), gilt der ganze Griffbereich.
func _krallen_lesen() -> void:
	_bewegliche.clear()
	for m in _krallen:
		if not is_instance_valid(m):
			continue
		var gesperrt: bool = m.get("blocked")
		if gesperrt:
			continue
		var reichweite: float = m.get("reach")
		var von_rechts: bool = m.get("from_right")
		var p := m.global_position
		var links := p.x - (reichweite if von_rechts else 0.0) - 30.0
		_bewegliche.append(Rect2(links, p.y - 9.0, reichweite + 60.0, 18.0).grow(vorsicht))


# ------------------------------------------------------------------ Station lesen

func _einrichten(lvl: Level) -> void:
	_level = lvl
	_paul = lvl.player
	_plan = null
	_gefahren.clear()
	_federn.clear()
	_schleusen.clear()
	_krallen.clear()
	_stempel.clear()
	_tuer = null
	for eintrag: Variant in lvl.mechanics:
		if not is_instance_valid(eintrag):
			continue   # eingesammelt (freigegeben) — erst prüfen, dann typisiert zuweisen
		var m: Mechanic = eintrag
		var r := m.rect
		match m.type:
			"spike":   # Basics.Spike: Fühler ab 14 px unter der Kachelkante, 6 px Rand
				_gefahren.append(Rect2(r.position.x + 6.0, r.position.y + 14.0, r.size.x - 12.0, r.size.y - 14.0).grow(vorsicht))
			"hazard":  # Basics.Hazard: 4 px Rand
				_gefahren.append(r.grow(-4.0).grow(vorsicht))
			"spring":  # Basics.Spring: untere 22 px, 6 px Rand
				_federn.append(Rect2(r.position.x + 6.0, r.end.y - 22.0, r.size.x - 12.0, 22.0))
			"timing-gate":
				_schleusen.append(m)
			"deny-enemy":
				_krallen.append(m)
			"stamp-exit":
				_stempel.append(m)
			"door-exit":   # Basics.DoorExit: Fühler 6 px breiter, 60 px höher
				_tuer = m as Basics.DoorExit
				_tuer_rect = Rect2(r.position.x - 6.0, r.position.y - 60.0, r.size.x + 12.0, r.size.y + 60.0)
	_grube_y = lvl.data.world_height() + 40.0
	var t: Dictionary = Player.T
	var breite: float = t["body_w"]
	_halb_b = breite / 2.0
	_hoehe = t["body_h"]
	_lauf = t["run_speed"]
	_beschl = t["accel"]
	_luft = t["air_mult"]
	_sprung_v = t["jump_velocity"]
	_var_s = t["var_jump_time"]
	_halb_g = t["half_grav"]
	_schub = t["jump_hboost"]
	_doppel_v = t["double_jump_velocity"]
	_schwere = t["gravity"]
	_fall_max = t["max_fall"]
	_coyote_s = t["coyote"]
	_puffer_s = t["buffer"]
	_wand_rutsch = t["wall_slide"]
	_wand_x = t["wall_jump_x"]
	_wand_y = t["wall_jump_y"]
	_wand_sperre = t["wall_lock"]


func _zustand() -> Zustand:
	var z := Zustand.new()
	z.pos = _paul.global_position
	z.vel = _paul.velocity
	z.boden = _paul.is_on_floor()
	z.doppelt = _paul._can_double
	z.var_sprung = _paul._var_jump
	z.coyote = _paul._sprung._coyote
	z.puffer = _paul._sprung._puffer
	z.gehalten = _stand["jump"]
	z.sperre = _paul._wall_lock
	if _paul.is_on_wall_only():
		z.wand = -int(signf(_paul.get_wall_normal().x))
	return z


## Die PIN-Schleuse, in der Paul gerade steht und die noch nicht gelöst ist.
func _schleuse() -> Mechanic:
	for m in _schleusen:
		if not is_instance_valid(m):
			continue
		var geloest: bool = m.get("done")
		if not geloest and m.player_in_rect(m.rect):
			return m
	return null


## Der Signatur-Stempel, unter dem Paul steht und der noch nicht gestempelt hat.
func _offener_stempel() -> Mechanic:
	for m in _stempel:
		if not is_instance_valid(m):
			continue
		var fertig: bool = m.get("done")
		if not fertig and m.player_in_rect(m.rect):
			return m
	return null


## Trifft ein Druck, der jetzt eingespielt wird, das Fenster? Er kommt erst im
## übernächsten tick() an (Level._process dieses Bildes läuft noch ohne ihn);
## TimingGate.tick: _t += delta, Takt neu ab elapsed ≥ _slow, Fenster elapsed < _slow·window_ratio.
func _im_takt(m: Mechanic) -> bool:
	var laeuft: bool = m.get("running")
	var t: float = m.get("_t")
	var beginn: float = m.get("_step_start")
	var gesperrt_bis: float = m.get("_fail_until")
	var dauer: float = m.get("_slow")
	var fenster: float = m.get("window_ratio")
	if not laeuft or dauer <= 0.0:
		return false
	var t1 := t + DT
	if t1 - beginn >= dauer:
		beginn = t1
	var t2 := t + 2.0 * DT
	return t2 >= gesperrt_bis and t2 - beginn < dauer * fenster * 0.75


# ------------------------------------------------------------------ Tasten

func _druecken(ax: float, sprung: bool) -> void:
	_setze("move_right", ax > 0.0)
	_setze("move_left", ax < 0.0)
	_setze("jump", sprung)


## Ein Wechsel als Ereignis — gepuffert, Godot liefert es vor dem nächsten Physikschritt aus.
func _setze(aktion: String, an: bool) -> void:
	if _stand[aktion] == an:
		return
	_stand[aktion] = an
	var ev := InputEventAction.new()
	ev.action = aktion
	ev.pressed = an
	ev.strength = 1.0 if an else 0.0
	Input.parse_input_event(ev)
