extends "res://tests/testfall.gd"
## KARTENFARBEN — eine Quelle für eGK, HBA und SMC-B: KartenFx.INFO (Karte in der
## Welt, Kartenleser, HUD, Flug) und über KartenFx.koerper() auch das Briefing.
## Früher hatte das Briefing eigene Hex-Werte, die beim Umfärben nicht mitgingen.

## Die alten Kopien im Briefing (eGK, HBA, SMC-B).
const ALTE_KOPIEN := ["0x2c7a52", "0xb8703a", "0x4d6aa8"]
## Palette.shade schiebt Schatten Richtung Blau.
const BLAU := 0.62


## Das Briefing malt Karten aus KartenFx, nicht aus eigenen Hex-Werten.
func test_briefing_nimmt_kartenfarben_aus_kartenfx() -> void:
	var text := FileAccess.get_file_as_string("res://src/ui/Briefing.gd")
	if not pruefe(text != "", "src/ui/Briefing.gd nicht lesbar"):
		return
	for h in ALTE_KOPIEN:
		pruefe(not text.contains(h), "Briefing.gd hat wieder eine eigene Kartenfarbe (%s) — KartenFx.koerper() nehmen" % h)
	var von := text.find("func _karte(")
	if not pruefe(von >= 0, "Briefing._karte nicht gefunden"):
		return
	var bis := text.find("\nfunc ", von + 1)
	if bis < 0:
		bis = text.length()
	pruefe(text.substr(von, bis - von).contains("KartenFx.koerper("),
		"Briefing._karte zeichnet den Kartenkörper nicht aus KartenFx.koerper()")


## eGK und SMC-B: Körper genau wie bisher in der Welt (Palette.shade mit 0,48) — die
## Spielgrafik bleibt pixelgleich.
func test_koerper_egk_smcb_wie_bisher() -> void:
	for k in ["egk", "smcb"]:
		gleich(KartenFx.koerper(k), Palette.shade(KartenFx.color_of(k), 0.48), "%s: Kartenkörper" % k)


## Jede Karte: Körper deutlich dunkler als die Kartenfarbe, Farbton bleibt oder
## wandert ein Stück auf kürzestem Weg Richtung Blau (Schatten kühler, nie Richtung
## Gelb/Oliv), und der goldene Chip des Briefings hebt sich ab (≥ 3:1, Maß für Grafik).
func test_koerper_dunkel_kuehl_lesbar() -> void:
	var chip := Pen.hex(0xffd75e)
	for k in KartenFx.INFO:
		var c := KartenFx.color_of(k)
		var b := KartenFx.koerper(k)
		pruefe(b.v <= c.v * 0.6, "%s: Körper nicht dunkel genug (Helligkeit %.2f bei Kartenfarbe %.2f)" % [k, b.v, c.v])
		var weg := _schritt(c.h, b.h)
		var zu_blau := _schritt(c.h, BLAU)
		pruefe(absf(weg) < 0.001 or (signf(weg) == signf(zu_blau) and absf(weg) <= absf(zu_blau)),
			"%s: Körper-Farbton wandert weg von Blau (%.3f → %.3f)" % [k, c.h, b.h])
		pruefe(absf(weg) <= 0.05, "%s: Körper-Farbton weicht zu weit ab (%.3f → %.3f)" % [k, c.h, b.h])
		var kontrast := _kontrast(b, chip)
		pruefe(kontrast >= 3.0, "%s: Chip auf Kartenkörper zu schwach (%.2f:1)" % [k, kontrast])


## Kürzester Farbtonschritt von a nach b, mit Vorzeichen (−0,5 … 0,5).
static func _schritt(a: float, b: float) -> float:
	return fposmod(b - a + 0.5, 1.0) - 0.5


static func _linear(x: float) -> float:
	if x <= 0.04045:
		return x / 12.92
	return pow((x + 0.055) / 1.055, 2.4)


## Kontrastverhältnis nach WCAG (relative Leuchtdichte).
static func _kontrast(a: Color, b: Color) -> float:
	var la := 0.2126 * _linear(a.r) + 0.7152 * _linear(a.g) + 0.0722 * _linear(a.b)
	var lb := 0.2126 * _linear(b.r) + 0.7152 * _linear(b.g) + 0.0722 * _linear(b.b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
