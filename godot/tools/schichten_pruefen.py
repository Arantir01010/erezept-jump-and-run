#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
schichten_pruefen.py — Schichtgrenze der reinen Regelklassen unter src/state/.

Eine Regelklasse hält Regeln und Zustand, sonst nichts: Sie erbt von RefCounted, bekommt Zeit,
Eingaben und Daten als Argumente und meldet Änderungen per Signal. Zeichnen, Szenenbaum, Dateien,
Uhr, Eingabe und Autoloads bleiben bei den Bausteinen (src/mechanics/), der Oberfläche (src/ui/)
und der Welt. So läuft jede Regel im Test ohne Szene. Abhängigkeit zeigt nur nach innen: Eine
Regelklasse kennt keine Klasse der äußeren Ordner (AUSSEN unten); src/core/ gilt als innen.

    python tools/schichten_pruefen.py                alle .gd unter src/state/
    python tools/schichten_pruefen.py <ordner> ...   andere Ordner (relativ zu godot/), z. B. Gegenprobe
    python tools/schichten_pruefen.py --selbsttest   Beispiele gegen alle Regeln

Ausgabe: je Bruch eine Zeile `<datei>:<zeile>: <Regel> „<Fund>“ — <Grund>`, zuletzt die Schlusszeile
`N Dateien, M Brüche`. Rückgabe 0 = kein Bruch, 1 = mindestens ein Bruch (beim Selbsttest: mindestens
ein Beispiel falsch erkannt). tools/pruefen.py wertet Schlusszeile und Rückgabe aus.

Lesart: Kommentare (#, ##) fallen weg, die Inhalte von Zeichenketten werden zu Leerzeichen (auch
mehrzeilige mit drei Anführungszeichen); die Zeilennummern bleiben. Ein Kommentar wie „Zeit kommt als
Argument, nicht aus Time.“ schlägt also nicht an. Lesart „text“ (Basisklasse, Pfad nach außen) behält
die Zeichenketten, denn dort steht der Pfad.

Erlaubt: Signale (signal, emit, connect), ein eigener RandomNumberGenerator, Color, Vector2, Mathematik,
andere Regelklassen und die Klassen aus src/core/ (Palette, Brand, LevelData).

Gegenprobe: `python tools/schichten_pruefen.py src/mechanics/stationen` meldet in den Bausteinen viele
Brüche (Basisklasse Mechanic, draw_…, queue_redraw, Autoload Game, Kartenfarben aus KartenFx …), und der
Selbsttest prüft jede Regel mit Treffern und Nicht-Treffern.

Grenzen: ein Netz, kein Beweis. Gelesen wird Text, kein Typsystem: Bekommt eine Regelklasse einen Knoten
als Variant herein und ruft etwas daran auf, fällt das nur über einen Namen aus der Tabelle auf. Ob eine
Regelklasse Farben oder Texte für die Anzeige liefert (Huelle.color_of über Palette, Huelle.label_of über
TranslationServer), prüft dieses Werkzeug nicht.

Ohne Fremdbibliotheken.
"""
import argparse
import os
import re
import sys

for _strom in (sys.stdout, sys.stderr):
    try:
        _strom.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

HIER = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HIER)

STANDARD = ["src/state"]
# Die äußeren Ordner: Ihre class_name-Klassen kennt eine Regelklasse nicht.
AUSSEN = ["src/mechanics", "src/ui", "src/world", "src/player", "src/actors", "src/fx", "src/autoload"]
# Falls project.godot nicht lesbar ist
AUTOLOADS_STANDARD = ["Game", "Sfx", "Kiosk"]

# Platzhalter in den Mustern, beim Start gefüllt:
#   {regelklassen}  class_name der Dateien unter src/state/ (als „|Name|Name“)
#   {autoloads}     Namen aus project.godot, Abschnitt [autoload]
#   {aussen}        class_name der Dateien in den äußeren Ordnern (AUSSEN)
#
# (Name, Muster, Lesart, Grund). Lesart „code“: ohne Kommentare, Zeichenketten geleert;
# „text“: ohne Kommentare, Zeichenketten bleiben.
REGELN = [
    ("Basisklasse",
     r"""\bextends\s+(?!(?:RefCounted|Object{regelklassen})\s*:?\s*$|["']res://src/state/)\S+""", "text",
     "Regelklassen erben von RefCounted (oder Object oder einer anderen Regelklasse), nicht von einem Knoten"),
    ("Szene",
     r"""\b(?:Node(?:2D|3D)?|SceneTree|PackedScene|Viewport)\b"""
     r"""|\b(?:get_tree|get_node|get_node_or_null|get_parent|add_child|remove_child|queue_free|instantiate"""
     r"""|get_viewport)\s*\(|(?<![\w"'])\$\s*[\w"']""", "code",
     "keine Knoten, kein Szenenbaum: eine Regel hängt nicht im Baum"),
    ("Baum-Rückruf",
     r"""\bfunc\s+_(?:ready|process|physics_process|enter_tree|exit_tree)\s*\(""", "code",
     "keine Rückrufe des Szenenbaums: die Regel läuft, wenn der Baustein sie ruft (mit der Zeit als Argument)"),
    ("Darstellung",
     r"""\b(?:CanvasItem|CanvasLayer|Control|Sprite2D|AnimatedSprite2D|Label|Tween|Texture\w*|ShaderMaterial"""
     r"""|StyleBox\w*|RenderingServer)\b|\b(?:draw_\w+|queue_redraw|create_tween|_draw)\s*\(""", "code",
     "nichts zeichnen, nichts animieren: das macht der Baustein"),
    ("Datei",
     r"""\b(?:load|preload)\s*\(|\b(?:FileAccess|DirAccess|ConfigFile|ResourceLoader|ResourceSaver"""
     r"""|ProjectSettings)\b""", "code",
     "nichts laden, keine Dateien: Daten kommen als Argument herein"),
    ("Uhr und System",
     r"""\b(?:Time|OS|Engine|Performance|DisplayServer)\s*\.|\bget_ticks_\w+|\b(?:Timer|create_timer)\b""", "code",
     "keine Uhr, kein System: Zeit kommt als Argument (delta oder jetzt)"),
    ("Eingabe",
     r"""\b(?:Input|InputMap)\s*\.|\bInputEvent\w*|\b_(?:input|unhandled_input|unhandled_key_input"""
     r"""|shortcut_input|gui_input)\s*\(""", "code",
     "keine Eingabe abfragen: der Baustein übersetzt Tasten in Aufrufe"),
    ("Zufall",
     r"""(?<![\w.])(?<!func )(?:randi|randf|randi_range|randf_range|randfn|randomize|seed|rand_from_seed)\s*\("""
     r"""|\.(?:shuffle|pick_random)\s*\(""", "code",
     "Zufall nur aus einem eigenen RandomNumberGenerator (Startwert setzbar, Test wiederholbar)"),
    ("Autoload",
     r"""\b(?:{autoloads})\b""", "code",
     "keine Autoloads: was die Regel braucht, bekommt sie als Argument"),
    ("Äußere Klasse",
     r"""\b(?:{aussen})\b""", "code",
     "keine Klasse aus Bausteinen, Oberfläche, Welt, Spieler, Figuren, Effekten: Abhängigkeit zeigt nach innen"),
    ("Pfad nach außen",
     r"""res://(?!src/state/)[\w./-]*""", "text",
     "kein Pfad nach außen (Szenen, Bausteine, Daten): eine Regelklasse lädt nichts"),
]

KLASSE = re.compile(r"^\s*class_name\s+(\w+)", re.M)


def regeln_bauen(regelklassen, autoloads, aussen):
    """Füllt die Platzhalter und übersetzt die Muster; liefert (Name, Regex, Lesart, Grund)."""
    def liste(namen):
        return "|".join(re.escape(n) for n in namen) or "(?!)"
    fertig = []
    for name, muster, lesart, grund in REGELN:
        m = (muster.replace("{regelklassen}", "".join("|" + re.escape(n) for n in regelklassen))
             .replace("{autoloads}", liste(autoloads))
             .replace("{aussen}", liste(aussen)))
        fertig.append((name, re.compile(m), lesart, grund))
    return fertig


def lesarten(text):
    """Zwei Fassungen mit denselben Zeilen: (code, text). Beide ohne Kommentare; „code“ ersetzt die
    Inhalte der Zeichenketten durch Leerzeichen, „text“ lässt sie stehen."""
    code, mit = [], []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "#":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c in "\"'":
            q = c * 3 if text.startswith(c * 3, i) else c
            roh = i > 0 and text[i - 1] == "r" and (i < 2 or not (text[i - 2].isalnum() or text[i - 2] == "_"))
            j = i + len(q)
            while j < n and not text.startswith(q, j):
                if text[j] == "\\" and not roh:
                    j += 2
                    continue
                if text[j] == "\n" and len(q) == 1:
                    break          # nicht geschlossen: endet mit der Zeile
                j += 1
            j = min(j, n)
            zu = text.startswith(q, j)
            ende = j + len(q) if zu else j
            mit.append(text[i:ende])
            code.append(q + "".join("\n" if z == "\n" else " " for z in text[i + len(q):j]) + (q if zu else ""))
            i = ende
            continue
        code.append(c)
        mit.append(c)
        i += 1
    return "".join(code), "".join(mit)


def text_pruefen(text, regeln):
    """Liefert die Funde als (Zeile, Regel, Fundtext, Grund); je Zeile und Regel höchstens einer."""
    code, mit = lesarten(text)
    funde = []
    for nr, (zc, zt) in enumerate(zip(code.split("\n"), mit.split("\n")), 1):
        for name, muster, lesart, grund in regeln:
            m = muster.search(zc if lesart == "code" else zt)
            if m:
                funde.append((nr, name, m.group(0).strip(), grund))
    return funde


def gd_dateien(ordner):
    """Alle .gd unter einem Ordner (relativ zu godot/), sortiert, als Pfade relativ zu godot/."""
    basis = os.path.join(GODOT, *ordner.split("/"))
    out = []
    for wurzel, unter, namen in os.walk(basis):
        unter[:] = sorted(u for u in unter if not u.startswith("."))
        for n in sorted(namen):
            if n.endswith(".gd"):
                out.append(os.path.relpath(os.path.join(wurzel, n), GODOT).replace(os.sep, "/"))
    return out


def lesen(rel):
    with open(os.path.join(GODOT, *rel.split("/")), encoding="utf-8") as f:
        return f.read()


def klassennamen(ordner_liste):
    namen = []
    for o in ordner_liste:
        for rel in gd_dateien(o):
            try:
                namen += KLASSE.findall(lesen(rel))
            except (OSError, UnicodeDecodeError):
                pass
    return sorted(set(namen))


def autoloads():
    """Die Autoload-Namen aus project.godot ([autoload]); sonst die bekannten drei."""
    try:
        with open(os.path.join(GODOT, "project.godot"), encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return list(AUTOLOADS_STANDARD)
    m = re.search(r"^\[autoload\]\s*$(.*?)(?=^\[|\Z)", text, re.M | re.S)
    if not m:
        return list(AUTOLOADS_STANDARD)
    return sorted(set(re.findall(r"^\s*(\w+)\s*=", m.group(1), re.M))) or list(AUTOLOADS_STANDARD)


def pruefen(ordner_liste):
    regelklassen = klassennamen(STANDARD)
    regeln = regeln_bauen(regelklassen, autoloads(), klassennamen(AUSSEN))
    print("Prüfe %s — Regelklassen: %s" % (", ".join(ordner_liste), ", ".join(regelklassen) or "keine"))
    brueche = []
    anzahl = 0
    for o in ordner_liste:
        if not os.path.isdir(os.path.join(GODOT, *o.split("/"))):
            brueche.append("%s: Ordner fehlt" % o)
            continue
        for rel in gd_dateien(o):
            anzahl += 1
            try:
                text = lesen(rel)
            except (OSError, UnicodeDecodeError) as e:
                brueche.append("%s: nicht lesbar (%s)" % (rel, e))
                continue
            for nr, name, fund, grund in text_pruefen(text, regeln):
                brueche.append("%s:%d: %s „%s“ — %s" % (rel, nr, name, fund, grund))
    for b in brueche:
        print(b)
    print("%d Dateien, %d Brüche" % (anzahl, len(brueche)))
    return 1 if brueche else 0


# Selbsttest: feste Namen statt der echten Ordner, damit das Ergebnis nicht vom Stand abhängt.
ST_REGELKLASSEN = ["Huelle", "KartenleserRegel"]
ST_AUTOLOADS = ["Game", "Sfx", "Kiosk"]
ST_AUSSEN = ["Mechanic", "KartenFx", "Pen", "Stations"]

# (Inhalt, erwartete Regeln; leer = darf nicht anschlagen)
SELBSTTEST = [
    # Basisklasse
    ("class_name X extends RefCounted\n", []),
    ("extends RefCounted  # kein Node\n", []),
    ("extends Object\n", []),
    ("extends Huelle\n", []),
    ("extends \"res://src/state/Huelle.gd\"\n", []),
    ("class _Teil extends RefCounted:\n\tvar x := 1\n", []),
    ("extends Node\n", ["Basisklasse", "Szene"]),
    ("extends Node2D\n", ["Basisklasse", "Szene"]),
    ("class _Teil extends Node2D:\n\tpass\n", ["Basisklasse", "Szene"]),
    ("extends Mechanic\n", ["Basisklasse", "Äußere Klasse"]),
    ("extends Resource\n", ["Basisklasse"]),
    ("extends \"res://src/mechanics/Mechanic.gd\"\n", ["Basisklasse", "Pfad nach außen"]),
    # Szene und Rückrufe
    ("var t := get_tree()\n", ["Szene"]),
    ("var k = $Kind\n", ["Szene"]),
    ("var s: PackedScene\n", ["Szene"]),
    ("teil.queue_free()\n", ["Szene"]),
    ("func _process(delta):\n\tpass\n", ["Baum-Rückruf"]),
    ("func _ready() -> void:\n\tpass\n", ["Baum-Rückruf"]),
    ("func tick(delta: float, jetzt: float) -> void:\n\t_uhr = jetzt\n", []),
    # Darstellung
    ("func _draw():\n\tdraw_rect(r, c)\n", ["Darstellung"]),
    ("queue_redraw()\n", ["Darstellung"]),
    ("var c: CanvasItem\n", ["Darstellung"]),
    ("var tw := create_tween()\n", ["Darstellung"]),
    ("var farbe := Color(0.3, 0.8, 0.5)\nvar p := Vector2(1, 2)\n", []),
    # Dateien
    ("var d = load(\"res://x.json\")\n", ["Datei", "Pfad nach außen"]),
    ("const R := preload(\"res://src/state/Huelle.gd\")\n", ["Datei"]),
    ("var f := FileAccess.open(p, FileAccess.READ)\n", ["Datei"]),
    ("var x := lade(daten)\nfunc _load_teil(): pass\nvar download := 1\n", []),
    # Uhr und System
    ("var t := Time.get_ticks_msec()\n", ["Uhr und System"]),
    ("if OS.has_feature(\"web\"): pass\n", ["Uhr und System"]),
    ("var f := Engine.get_frames_drawn()\n", ["Uhr und System"]),
    ("var z := Timer.new()\n", ["Uhr und System"]),
    # Eingabe
    ("if Input.is_action_pressed(\"jump\"): pass\n", ["Eingabe"]),
    ("func _unhandled_input(e: InputEvent):\n\tpass\n", ["Eingabe"]),
    # Zufall
    ("var z := randf()\n", ["Zufall"]),
    ("var z := randi_range(1, 6)\n", ["Zufall"]),
    ("liste.shuffle()\n", ["Zufall"]),
    ("var w := RandomNumberGenerator.new()\nw.seed = 7\nvar z := w.randf()\nvar y := w.randi_range(1, 6)\n", []),
    ("func seed(wert: int) -> void:\n\t_w.seed = wert\n", []),
    # Autoloads und äußere Klassen
    ("Game.score += 1\n", ["Autoload"]),
    ("Sfx.play(\"ok\")\n", ["Autoload"]),
    ("var k := Kiosk\n", ["Autoload"]),
    ("var game_over := false\nvar GameCamera_x := 1\nvar Nodes := 0\n", []),
    ("var info := KartenFx.INFO\n", ["Äußere Klasse"]),
    ("Pen.rect(c, 0, 0, 1, 1, Color.WHITE)\n", ["Äußere Klasse"]),
    ("var p := Palette.shade(Color.RED)\n", []),
    # Signale sind erlaubt
    ("signal geoeffnet(karte: String)\ngeoeffnet.emit(\"egk\")\nchanged.connect(_f)\n", []),
    # Pfade
    ("var p := \"res://src/state/Huelle.gd\"\n", []),
    ("var p := \"res://levels/01-stammdaten/level.json\"\n", ["Pfad nach außen"]),
    # Lesart: Kommentare und Zeichenketten
    ("# Zeit kommt als Argument, nicht aus Time.\n## kein Node, kein draw_rect(), kein Game.\n", []),
    ("var s := \"Game. Time. Input. load( get_tree() Node\"\n", []),
    ("var s := \"\"\"\nTime.get_ticks_msec()\n\"\"\"\nvar x := 1\n", []),
    ("var s := 'Node'  # Input.\n", []),
    ("var s := \"#\"; var t := Time.get_ticks_msec()\n", ["Uhr und System"]),
    ("var s := \"a\\\"Time.\\\"b\"\n", []),
    ("var s := \"\"\"\nmehrzeilig\n\"\"\"\nvar t := Time.get_ticks_msec()\n", ["Uhr und System"]),
]


def selbsttest():
    regeln = regeln_bauen(ST_REGELKLASSEN, ST_AUTOLOADS, ST_AUSSEN)
    fehler = []
    for nr, (text, erwartet) in enumerate(SELBSTTEST, 1):
        ist = sorted({name for _, name, _, _ in text_pruefen(text, regeln)})
        if ist != sorted(set(erwartet)):
            fehler.append("Beispiel %d %r: erwartet %s, gefunden %s" % (nr, text, sorted(set(erwartet)), ist))
    # Zeilennummern bleiben über mehrzeilige Zeichenketten hinweg erhalten
    zeilen = [z for z, _, _, _ in text_pruefen("var s := \"\"\"\na\nb\n\"\"\"\nvar t := Time.get_ticks_msec()\n", regeln)]
    if zeilen != [5]:
        fehler.append("Zeilennummer nach mehrzeiliger Zeichenkette: erwartet [5], gefunden %s" % zeilen)
    # Jede Regel hat mindestens ein Beispiel, an dem sie anschlägt
    gedeckt = {name for _, erwartet in SELBSTTEST for name in erwartet}
    for name, _, _, _ in REGELN:
        if name not in gedeckt:
            fehler.append("Regel „%s“ ohne Beispiel, an dem sie anschlägt" % name)
    for f in fehler:
        print(f)
    print("Selbsttest: %d Beispiele, %d Fehler" % (len(SELBSTTEST), len(fehler)))
    return 1 if fehler else 0


def main(argv=None):
    p = argparse.ArgumentParser(description="Schichtgrenze der Regelklassen (src/state/) prüfen.")
    p.add_argument("ordner", nargs="*", help="Ordner relativ zu godot/ (Standard: src/state)")
    p.add_argument("--selbsttest", action="store_true", help="Beispiele gegen alle Regeln prüfen")
    a = p.parse_args(argv)
    if a.selbsttest:
        return selbsttest()
    return pruefen([o.strip("/").replace("\\", "/") for o in a.ordner] or list(STANDARD))


if __name__ == "__main__":
    sys.exit(main())
