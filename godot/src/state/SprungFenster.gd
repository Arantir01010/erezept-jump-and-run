class_name SprungFenster
extends RefCounted
## SPRUNGFENSTER — Coyote-Zeit und Sprungpuffer als reine Regel.
##
## Coyote-Zeit: Wer gerade über eine Kante gelaufen ist, darf noch kurz vom Boden
## abspringen. Sprungpuffer: Ein Sprungdruck kurz VOR der Landung zählt noch, sobald
## Paul aufsetzt. Beides zusammen macht Sprünge fair, ohne dass jemand es bemerkt.
##
## Lehre aus dem Strategiespiel (projekt-e, docs/wissen/20_godot_architektur.md,
## „Eingabe"): Zeitregeln als Klasse ohne Uhr und ohne Knoten schreiben. Jeder
## Zeitschritt kommt als Argument herein, also ist die Regel ohne Fenster prüfbar
## (tests/test_sprungfenster.gd), und Pause oder Zeitlupe verschieben nichts.

var coyote_dauer: float
var puffer_dauer: float
var _coyote := 0.0
var _puffer := 0.0


func _init(coyote_s := 0.10, puffer_s := 0.10) -> void:
	coyote_dauer = coyote_s
	puffer_dauer = puffer_s


## Ein Physikschritt. `auf_boden`: Paul steht in diesem Schritt; `gedrueckt`: der
## Sprung wurde in diesem Schritt neu gedrückt (nicht gehalten).
func schritt(delta: float, auf_boden: bool, gedrueckt: bool) -> void:
	if auf_boden:
		_coyote = coyote_dauer
	else:
		_coyote -= delta
	if gedrueckt:
		_puffer = puffer_dauer
	else:
		_puffer -= delta


## Ein Sprungwunsch liegt an (eben gedrückt oder höchstens `puffer_dauer` her).
func sprung_gewuenscht() -> bool:
	return _puffer > 0.0


## Ein Absprung vom Boden ist erlaubt (am Boden oder höchstens `coyote_dauer` danach).
func vom_boden() -> bool:
	return _coyote > 0.0


## Nach einem Bodensprung: Wunsch und Coyote-Zeit sind verbraucht (kein zweiter
## Bodensprung aus demselben Fenster).
func bodensprung() -> void:
	_puffer = 0.0
	_coyote = 0.0


## Nach einem Sprung ohne Boden (Wandsprung): nur der Wunsch ist verbraucht.
func wunsch_verbraucht() -> void:
	_puffer = 0.0


## Rücksetzen an die Fahne: alte Wünsche und Kanten zählen nicht mehr.
func zuruecksetzen() -> void:
	_coyote = 0.0
	_puffer = 0.0
