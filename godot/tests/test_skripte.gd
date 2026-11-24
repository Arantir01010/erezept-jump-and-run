extends "res://tests/testfall.gd"
## Kompiliert jedes Skript unter src/ — auch solche, die kein anderer Test lädt.
## Ein Tippfehler in einem selten benutzten Baustein fällt sonst erst auf der
## Messe auf. Parse-Fehler meldet die Engine; der Fehlerzähler wertet sie.


func test_alle_skripte_kompilieren() -> void:
	var anzahl := 0
	for pfad in dateien("res://src", ".gd"):
		var s := load(pfad) as GDScript
		anzahl += 1
		if not pruefe(s != null, "%s lädt nicht" % pfad):
			continue
		pruefe(s.can_instantiate(), "%s hat Fehler (lässt sich nicht instanziieren)" % pfad)
	pruefe(anzahl >= 20, "zu wenige Skripte gefunden (%d)" % anzahl)


func test_hauptszene_laedt() -> void:
	var szene := load("res://scenes/Main.tscn") as PackedScene
	if pruefe(szene != null, "scenes/Main.tscn lädt nicht"):
		pruefe(szene.can_instantiate(), "scenes/Main.tscn lässt sich nicht instanziieren")
