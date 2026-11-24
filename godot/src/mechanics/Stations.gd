## STATIONS-BAUSTEINE: die Sicherheits-Mechaniken der TI.
##   timing-gate        PIN-Schleuse (blauer Knopf im Takt)
##   lauscher           sieht NUR Klartext (Hülle-Kernmechanik)
##   andock-plattform   trägt nur Klartext oder VAU
##   vau-feld           Klartext-schnell UND unsichtbar; ttlMs = Kontextschlüssel
##   kontext-anker      frischt die VAU-Sitzung auf
##   stamp-exit         Signatur-Stempel als Levelausgang (QES)
##   deny-enemy         Skimming-Kralle — die TI blockt sie
##   stillstand-podest  Scan im Stillstand
##   krypto-dusche      Verschlüsselung anlegen
##   karte / kartenleser  Identität: eGK / HBA / SMC-B
##   letzte-tuer        das Finale: die Tür, die nicht der Spieler öffnet
## Markenregel überall: Es wird nie gekämpft — die Architektur schützt.
##
## Jeder Baustein steht in einer eigenen Datei unter src/mechanics/stationen/.
## Diese Datei ist nur noch das Verzeichnis: Typ aus level.json → Skript. Die
## Konstanten tragen die alten Klassennamen, darum gilt weiter Stations.Kartenleser,
## Stations.Lauscher.NEUTRAL oder is_instance_of(m, Stations.TimingGate).
class_name Stations

const TimingGate := preload("res://src/mechanics/stationen/TimingGate.gd")
const Lauscher := preload("res://src/mechanics/stationen/Lauscher.gd")
const AndockPlattform := preload("res://src/mechanics/stationen/AndockPlattform.gd")
const VauFeld := preload("res://src/mechanics/stationen/VauFeld.gd")
const KontextAnker := preload("res://src/mechanics/stationen/KontextAnker.gd")
const StampExit := preload("res://src/mechanics/stationen/StampExit.gd")
const DenyEnemy := preload("res://src/mechanics/stationen/DenyEnemy.gd")
const StillstandPodest := preload("res://src/mechanics/stationen/StillstandPodest.gd")
const KryptoDusche := preload("res://src/mechanics/stationen/KryptoDusche.gd")
const Karte := preload("res://src/mechanics/stationen/Karte.gd")
const Kartenleser := preload("res://src/mechanics/stationen/Kartenleser.gd")
const LetzteTuer := preload("res://src/mechanics/stationen/LetzteTuer.gd")

const REGISTRY := {
	"timing-gate": TimingGate, "lauscher": Lauscher, "andock-plattform": AndockPlattform,
	"vau-feld": VauFeld, "kontext-anker": KontextAnker, "stamp-exit": StampExit,
	"deny-enemy": DenyEnemy, "stillstand-podest": StillstandPodest, "krypto-dusche": KryptoDusche,
	"karte": Karte, "kartenleser": Kartenleser, "letzte-tuer": LetzteTuer,
}

## Kürzel, Name, Rolle, Farbe je Karte — Wahrheit liegt in KartenFx.INFO.
const CARD_INFO := KartenFx.INFO
