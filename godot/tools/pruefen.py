#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pruefen.py — alle Prüfstufen der Godot-Fassung mit einem Befehl, von billig nach teuer.

    python3 godot/tools/pruefen.py                  Stufen 0–5 (vor dem Push, in der CI)
    python3 godot/tools/pruefen.py --schnell        nur Stufen 0 und 1, braucht kein Godot (Commit-Haken)
    python3 godot/tools/pruefen.py --bilder         zusätzlich Stufe 6 (Bildprobe; Linux: xvfb-run)
    python3 godot/tools/pruefen.py --ohne-export    Stufe 5 auslassen (zählt als übersprungen)
    python3 godot/tools/pruefen.py --nur 2,3        nur diese Stufen (kein Import vorweg!)
    python3 godot/tools/pruefen.py --tests huelle   Stufe 4 nur mit passenden tests/test_*.gd
    python3 godot/tools/pruefen.py --godot <pfad>   Godot-Programm (sonst $GODOT, .tools/…, PATH)
    python3 godot/tools/pruefen.py --nur 3 --grenzen-nachziehen   tools/grenzwerte.json auf den Ist-Stand
    python3 godot/tools/pruefen.py --selbsttest     nur die Prüfer an künstlichen Dateien testen
    python3 godot/tools/pruefen.py --liste          Stufen zeigen, nichts ausführen

Stufen — jede endet mit genau einer Schlusszeile „STUFE <n> <name>: <urteil> – …":
  0 Dateien          NUL-/Steuerzeichen, CRLF, UTF-8 und BOM in Textdateien; jede .gd/.gdshader unter src/
                     und tests/ hat ihre .uid (auf der Platte UND im Git-Index), keine verwaisten oder
                     doppelten UIDs; jede JSON-Datei parst streng (Python json, keine doppelten Schlüssel,
                     kein NaN); Selbsttest der Prüfer; tools/schichten_pruefen.py, falls vorhanden
  1 Level-Generator  tools/build_levels.py, danach levels/ gegen Git (wie tools/ci/godot-tests.yml)
  2 Import           godot --headless --import; der Import endet trotz Fehlern mit 0, darum wird das
                     Log nach SCRIPT ERROR, Parse Error und ERROR: durchsucht
  3 Typwarnungen     tests/typwarnungen.gd mit -d: GDScript-Warnungen je Bereich und Art gegen
                     tools/grenzwerte.json (mehr = Fehler, weniger = Hinweis zum Nachziehen)
  4 Tests            tests/lauf.gd, Schlusszeile „N Tests, M fehlgeschlagen"
  5 Exportprobe      --export-pack „Web" und „Windows" (geht ohne Export-Vorlagen), PCK-Verzeichnis
                     lesen: Laufzeitdateien drin, tests/ tools/ docs/ shots/ build*/ nicht
  6 Bildprobe        nur mit --bilder: tests/standbild.gd an zwei Stationen, Bilder da, nicht einfarbig

Rückgabe: 0 = jede Stufe bestanden, 1 = mindestens eine fehlgeschlagen, 2 = keine fehlgeschlagen, aber
etwas übersprungen (zählt nie als sauber). Letzte Zeile: „N Stufen, M fehlgeschlagen, K übersprungen".
Eine Stufe, deren Unterprozess seine erwartete Schlusszeile nicht liefert, gilt als fehlgeschlagen.
Unterprozesse schreiben in Dateien unter godot/.pruefen/ (nie durch eine Pipe; der Ordner hat eine
.gdignore, damit Godot nichts davon importiert). Nur Standardbibliothek; Linux, Windows, Git Bash.
"""
import argparse
import hashlib
import json
import math
import os
import re
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import traceback
import zlib

for _strom in (sys.stdout, sys.stderr):
    try:
        _strom.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

HIER = os.path.dirname(os.path.abspath(__file__))          # godot/tools
GODOT = os.path.dirname(HIER)                               # godot
WURZEL = os.path.dirname(GODOT)                             # Arbeitskopie
LOGS = os.path.join(GODOT, ".pruefen")
GRENZWERTE = os.path.join(HIER, "grenzwerte.json")
GODOT_TOOLS = os.path.join(WURZEL, ".tools", "Godot_v4.7.2-stable_win64_console.exe")   # wie build.ps1

FRIST_PYTHON = 180      # Sekunden: Level-Generator, schichten_pruefen.py
FRIST_IMPORT = 900      # erster Import eines frischen Klons dauert länger
FRIST_WARNUNGEN = 300
FRIST_TESTS = 1000      # lauf.gd hat einen eigenen Wachhund nach 900 s
FRIST_EXPORT = 600      # je Paket
FRIST_BILD = 900        # je Station; unter Xvfb rendert Godot in Software (gemessen ~215 s je Station)

BESTANDEN = "bestanden"
FEHLGESCHLAGEN = "FEHLGESCHLAGEN"
UEBERSPRUNGEN = "übersprungen"
MAX_DETAILS = 25

# --- Stufe 0: welche Dateien ---------------------------------------------------------------------------
TEXT_ENDUNGEN = {".gd", ".gdshader", ".json", ".txt", ".tscn", ".tres", ".cfg", ".godot", ".import", ".uid",
                 ".md", ".html", ".py", ".ps1", ".bat", ".cmd", ".sh", ".yml", ".yaml", ".csv", ".svg"}
TEXT_NAMEN = {".gitignore", ".gdignore", ".gitattributes"}
# Ordner (relativ zu godot/), die nicht zur Quelle gehören: Cache, Logs, Builds, Bilder, lizenzierte Marken-Assets
OHNE_ORDNER = {".godot", ".pruefen", "shots", "__pycache__", ".git", "assets/fonts", "assets/brand", "brand/lizenz"}
STEUERZEICHEN = re.compile(rb"[\x01-\x08\x0b\x0c\x0e-\x1f\x7f]")
EINZELNES_CR = re.compile(rb"\r(?!\n)")
UID_IMPORT = re.compile(r'^uid="(uid://[0-9a-z]+)"', re.M)
UID_SZENE = re.compile(r'^\[gd_(?:scene|resource)[^\]]*\buid="(uid://[0-9a-z]+)"')

# --- Stufe 2/6: Logs --------------------------------------------------------------------------------------
ANSI = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
# Bekannte harmlose Fehlerblöcke (Block = ERROR-Zeile + folgende „at:"-Zeilen). Begründung je Muster:
BEKANNT_HARMLOS = [
    # Kein Soundgerät (CI-Container, Xvfb, Server): Godot fällt auf den Dummy-Treiber zurück, das Spiel läuft.
    re.compile(r"drivers/alsa/|audio_driver_alsa|ALSA lib|drivers/pulseaudio/|audio_driver_pulseaudio"),
]

# --- Stufe 5: Export --------------------------------------------------------------------------------------
PACK_DIR_ENCRYPTED = 1
PACK_REL_FILEBASE = 2
PACK_SPARSE_BUNDLE = 4
PACK_FILE_ENCRYPTED = 1
PACK_FILE_REMOVAL = 2
UNERWUENSCHT = re.compile(r"^(?:tests|tools|docs|shots|build[^/]*|\.pruefen|brand)/")
# Endungen, die der Code aus einem res://-Ordner zur Laufzeit lädt (Daten, Klänge, Bilder, Schriften, Shader)
LAUFZEIT_ENDUNGEN = {".json", ".txt", ".cfg", ".csv", ".wav", ".ogg", ".mp3", ".png", ".jpg", ".jpeg", ".webp",
                     ".svg", ".ttf", ".otf", ".woff", ".woff2", ".gdshader", ".tscn", ".tres", ".scn", ".res", ".gd"}
RES_PFAD = re.compile(r"res://[^\"'\s)\],]*")
EXPORT_PRESETS = ("Web", "Windows")

# --- Stufe 6: Bilder --------------------------------------------------------------------------------------
BILD_STATIONEN = (("01-stammdaten", "0.42"), ("15-kontextschluessel", "vau-feld"))
BILD_MIN_SIGMA = 4.0    # Standardabweichung der Helligkeit (0–255); ein einfarbiges Bild hat 0

SCHLUSS_TESTS = re.compile(r"^(\d+) Tests, (\d+) fehlgeschlagen")
SCHLUSS_WARNUNGEN = re.compile(r"^(\d+) Skripte, (\d+) Warnungen, (\d+) Skriptfehler$")
ZAEHLUNG = re.compile(r"^ZAEHLUNG (\S+) (\S+) (\d+)$")


# =========================================================================================================
# Grundbausteine
# =========================================================================================================

class Ergebnis:
    """Urteil einer Stufe, der Inhalt ihrer Schlusszeile und Detailzeilen, die davor gedruckt werden."""

    def __init__(self):
        self.urteil = None
        self.text = ""
        self.details = []

    def setze(self, urteil, text):
        self.urteil, self.text = urteil, text
        return self

    def detail(self, zeile):
        self.details.append(zeile)

    def liste(self, titel, eintraege, max_anzahl=MAX_DETAILS):
        if not eintraege:
            return
        self.details.append(titel)
        for x in eintraege[:max_anzahl]:
            self.details.append("  " + x)
        if len(eintraege) > max_anzahl:
            self.details.append("  … und %d weitere" % (len(eintraege) - max_anzahl))


class Kontext:
    def __init__(self, args):
        self.args = args
        self.godot = None
        self.godot_version = ""
        self.git = None          # (wurzel, präfix von godot/ in der Arbeitskopie) oder None


def rel(pfad, basis=GODOT):
    return os.path.relpath(pfad, basis).replace(os.sep, "/")


def logpfad(name):
    return os.path.join(LOGS, name)


def logs_vorbereiten():
    """godot/.pruefen/ anlegen — die .gdignore zuerst, damit ein offener Editor den Ordner nie einliest."""
    os.makedirs(LOGS, exist_ok=True)
    ignore = os.path.join(LOGS, ".gdignore")
    if not os.path.exists(ignore):
        with open(ignore, "w", encoding="utf-8", newline="\n"):
            pass


def baum_beenden(p):
    """Prozess samt Kindern beenden (Godots Konsolenfassung unter Windows startet die Anwendung als Kind,
    xvfb-run startet Xvfb und Godot)."""
    try:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
        else:
            os.killpg(p.pid, signal.SIGKILL)
    except Exception:
        try:
            p.kill()
        except Exception:
            pass
    try:
        p.wait(timeout=30)
    except Exception:
        pass


def ausfuehren(befehl, log, frist, cwd=GODOT, env=None):
    """Startet `befehl`, Ausgabe (stdout und stderr) in die Logdatei, stdin geschlossen.
    Rückgabe: Rückgabecode, None bei Zeitüberschreitung (der ganze Prozessbaum wird beendet)."""
    extra = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
    with open(log, "wb") as aus:
        p = subprocess.Popen(befehl, stdout=aus, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, cwd=cwd,
                             env=env, **extra)
        try:
            return p.wait(timeout=frist)
        except subprocess.TimeoutExpired:
            baum_beenden(p)
            return None
        except BaseException:
            baum_beenden(p)
            raise


def log_zeilen(log):
    try:
        with open(log, encoding="utf-8", errors="replace") as f:
            return [ANSI.sub("", z.rstrip("\r\n")) for z in f.read().splitlines()]
    except OSError:
        return []


def letzte_passende(zeilen, muster):
    treffer = None
    for z in zeilen:
        m = muster.match(z.strip())
        if m:
            treffer = m
    return treffer


def schwanz(log, anzahl=12):
    return ["| " + z for z in log_zeilen(log) if z.strip()][-anzahl:]


def godot_finden(angabe):
    """--godot, sonst $GODOT, sonst die Konsolenfassung in <Arbeitskopie>/.tools/ (wie build.ps1), sonst PATH."""
    if angabe:
        return angabe if os.path.isfile(angabe) else shutil.which(angabe)
    umgebung = os.environ.get("GODOT")
    if umgebung:
        gefunden = umgebung if os.path.isfile(umgebung) else shutil.which(umgebung)
        if gefunden:
            return gefunden
        print("Hinweis: GODOT=%s zeigt auf kein Programm; es wird weitergesucht." % umgebung, flush=True)
    if os.path.isfile(GODOT_TOOLS):
        return GODOT_TOOLS
    for name in ("godot", "godot4", "Godot_v4.7.2-stable_win64_console.exe", "Godot_v4.7.2-stable_win64_console",
                 "godot.exe", "Godot_v4.7.2-stable_linux.x86_64"):
        gefunden = shutil.which(name)
        if gefunden:
            return gefunden
    return None


def godot_version(godot):
    log = logpfad("godot-version.log")
    rc = ausfuehren([godot, "--version"], log, 60)
    zeilen = [z for z in log_zeilen(log) if z.strip()]
    return zeilen[-1].strip() if rc == 0 and zeilen else None


def git_finden():
    """(Wurzel der Arbeitskopie, Pfad von godot/ darin) oder None. Git wird immer aus der Wurzel mit
    expliziten Pfaden aufgerufen: In Commit-Haken exportiert Git GIT_DIR/GIT_INDEX_FILE, und ein Aufruf aus
    einem Unterordner würde den Unterordner dann für die Wurzel halten."""
    if not shutil.which("git"):
        return None
    try:
        r = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=WURZEL, capture_output=True, text=True,
                           encoding="utf-8", timeout=60)
    except Exception:
        return None
    if r.returncode != 0 or not r.stdout.strip():
        return None
    wurzel = os.path.normpath(r.stdout.strip())
    praefix = rel(GODOT, wurzel)
    if praefix.startswith(".."):
        return None
    return wurzel, praefix


def git(ctx, *args):
    """Git-Befehl aus der Wurzel der Arbeitskopie; Rückgabe (Rückgabecode, Ausgabe)."""
    r = subprocess.run(["git", "-c", "core.quotepath=off"] + list(args), cwd=ctx.git[0], capture_output=True,
                       text=True, encoding="utf-8", errors="replace", timeout=120)
    return r.returncode, r.stdout


def git_pfad(ctx, pfad_in_godot):
    return ctx.git[1] + "/" + pfad_in_godot if pfad_in_godot else ctx.git[1]


def git_namen(ctx, *args):
    """Pfadliste (-z) eines Git-Befehls, umgerechnet auf Pfade relativ zu godot/."""
    rc, aus = git(ctx, *args)
    if rc != 0:
        return None
    vorne = ctx.git[1] + "/"
    return sorted(n[len(vorne):] if n.startswith(vorne) else n for n in aus.split("\0") if n)


# =========================================================================================================
# Stufe 0 — Dateien
# =========================================================================================================

def dateien_unter(wurzel):
    """Alle Dateien unter `wurzel` außer Cache, Logs, Builds und lizenzierten Assets: (absolut, relativ)."""
    for ordner, unterordner, namen in os.walk(wurzel):
        r = rel(ordner, wurzel)
        r = "" if r == "." else r
        behalten = []
        for u in sorted(unterordner):
            ur = (r + "/" + u) if r else u
            if ur in OHNE_ORDNER or (not r and u.startswith("build")):
                continue
            behalten.append(u)
        unterordner[:] = behalten
        for n in sorted(namen):
            yield os.path.join(ordner, n), ((r + "/" + n) if r else n)


def ist_textdatei(relpfad):
    name = relpfad.rsplit("/", 1)[-1]
    return (name in TEXT_NAMEN or os.path.splitext(name)[1].lower() in TEXT_ENDUNGEN
            or relpfad.startswith("tools/githooks/"))


def zeile_bei(daten, pos):
    return daten.count(b"\n", 0, pos) + 1


def datei_befunde(daten, relpfad):
    """Befunde einer Textdatei: (Art, Pfad, Beschreibung)."""
    b = []
    nul = daten.find(b"\x00")
    if nul >= 0:
        b.append(("NUL-Byte", relpfad, "%d NUL-Byte(s), erstes in Zeile %d" % (daten.count(b"\x00"), zeile_bei(daten, nul))))
    m = STEUERZEICHEN.search(daten)
    if m:
        b.append(("Steuerzeichen", relpfad, "0x%02X in Zeile %d" % (daten[m.start()], zeile_bei(daten, m.start()))))
    m = EINZELNES_CR.search(daten)
    if m:
        b.append(("Steuerzeichen", relpfad, "einzelnes CR (0x0D) in Zeile %d" % zeile_bei(daten, m.start())))
    if b"\r\n" in daten:
        b.append(("CRLF", relpfad, "%d Zeile(n) enden mit CRLF, erste: %d (Repo-Regel: LF, siehe .gitattributes)"
                  % (daten.count(b"\r\n"), zeile_bei(daten, daten.find(b"\r\n")))))
    # Ausnahme .ps1: Windows PowerShell 5.1 liest UTF-8 ohne BOM als ANSI (Umlaute kaputt) — dort ist er Pflicht.
    if daten.startswith(b"\xef\xbb\xbf") and not relpfad.endswith(".ps1"):
        b.append(("BOM", relpfad, "UTF-8-BOM am Dateianfang"))
    try:
        daten.decode("utf-8")
    except UnicodeDecodeError as ex:
        b.append(("kein UTF-8", relpfad, "ungültiges Byte 0x%02X in Zeile %d" % (daten[ex.start], zeile_bei(daten, ex.start))))
    return b


class _DoppelterSchluessel(ValueError):
    pass


def _paare(paare):
    d = {}
    for k, v in paare:
        if k in d:
            raise _DoppelterSchluessel('doppelter Schlüssel "%s"' % k)
        d[k] = v
    return d


def _keine_konstante(name):
    raise ValueError("%s ist kein gültiges JSON" % name)


def json_streng(text):
    """Parst JSON so streng wie möglich: wie Python json (kein nachgestelltes Komma, keine Kommentare), dazu
    keine doppelten Schlüssel und kein NaN/Infinity. Godots JSON ist nachsichtiger — andere Werkzeuge nicht."""
    return json.loads(text, object_pairs_hook=_paare, parse_constant=_keine_konstante)


def json_befunde(daten, relpfad):
    try:
        text = daten.decode("utf-8")
    except UnicodeDecodeError:
        return []        # schon als „kein UTF-8" gemeldet
    try:
        json_streng(text)
    except ValueError as ex:
        return [("JSON", relpfad, str(ex))]
    return []


def uid_befunde(wurzel, dateien, index):
    """.uid-Regeln. `dateien`: relative Pfade unter `wurzel`; `index`: Menge der Pfade im Git-Index (relativ zu
    `wurzel`) oder None. Rückgabe (Befunde, Zahl der geprüften Skripte/Shader)."""
    b = []
    menge = set(dateien)
    skripte = [d for d in dateien if d.startswith(("src/", "tests/")) and d.endswith((".gd", ".gdshader"))]
    for d in skripte:
        if d + ".uid" not in menge:
            b.append(("UID fehlt", d, "%s.uid fehlt — Godot-Import laufen lassen und die .uid mit einchecken" % d))
        elif index is not None and d in index and d + ".uid" not in index:
            b.append(("UID nicht eingecheckt", d + ".uid", "liegt nur auf der Platte, %s ist aber im Git-Index — "
                      "git add %s.uid" % (d, d)))
    uids = {}
    for d in dateien:
        if d.endswith(".uid"):
            if d[:-4] not in menge:
                b.append(("UID verwaist", d, "die Quelldatei %s gibt es nicht (mehr)" % d[:-4]))
            try:
                with open(os.path.join(wurzel, d), encoding="utf-8", errors="replace") as f:
                    uid = f.read().strip()
            except OSError:
                continue
            if uid:
                uids.setdefault(uid, []).append(d)
        elif d.endswith(".import") or d.endswith((".tscn", ".tres")):
            try:
                with open(os.path.join(wurzel, d), encoding="utf-8", errors="replace") as f:
                    kopf = f.read(4096)
            except OSError:
                continue
            m = (UID_IMPORT.search(kopf) if d.endswith(".import") else UID_SZENE.match(kopf))
            if m:
                uids.setdefault(m.group(1), []).append(d)
    for uid, wer in sorted(uids.items()):
        if len(wer) > 1:
            b.append(("UID doppelt", ", ".join(wer), "%s — Godot löst dann falsch auf; eine Datei neu importieren" % uid))
    return b, len(skripte)


def stufe_0(ctx):
    e = Ergebnis()
    befunde = []
    alle = list(dateien_unter(GODOT))
    text_anzahl = json_anzahl = 0
    for absolut, r in alle:
        if not ist_textdatei(r):
            continue
        with open(absolut, "rb") as f:
            daten = f.read()
        text_anzahl += 1
        befunde += datei_befunde(daten, r)
        if r.endswith(".json"):
            json_anzahl += 1
            befunde += json_befunde(daten, r)
    index = None
    if ctx.git:
        index = git_namen(ctx, "ls-files", "-z", "--", ctx.git[1])
        index = set(index) if index is not None else None
    if index is None:
        e.detail("Git-Index nicht lesbar (kein Git?) — .uid nur auf der Platte geprüft")
    uid_b, skripte = uid_befunde(GODOT, [r for _, r in alle], index)
    befunde += uid_b

    st_n, st_fehler = selbsttest()
    for zeile in st_fehler:
        befunde.append(("Selbsttest", "tools/pruefen.py", zeile))

    schichten = schichten_pruefen(ctx, befunde, e)

    befunde.sort(key=lambda x: (x[0], x[1]))
    e.liste("Befunde (%d):" % len(befunde), ["%s: %s — %s" % b for b in befunde])
    text = "%d Textdateien (%d Skripte/Shader, %d JSON), %d Befunde; Selbsttest %d Prüfungen, %d fehlgeschlagen; " \
           "Schichten: %s" % (text_anzahl, skripte, json_anzahl, len(befunde), st_n, len(st_fehler), schichten)
    return e.setze(FEHLGESCHLAGEN if befunde else BESTANDEN, text)


def schichten_pruefen(ctx, befunde, e):
    """tools/schichten_pruefen.py (eigenes Werkzeug), falls vorhanden: letzte nichtleere Zeile = Schlusszeile,
    Rückgabecode 0 = sauber. Fehlt es, entfällt die Teilprüfung (Hinweis, kein Fehler)."""
    skript = os.path.join(HIER, "schichten_pruefen.py")
    if not os.path.isfile(skript):
        return "entfällt (tools/schichten_pruefen.py fehlt)"
    with open(skript, encoding="utf-8", errors="replace") as f:
        mit_selbsttest = "--selbsttest" in f.read()
    ergebnisse = []
    for zusatz in ([[]] + ([["--selbsttest"]] if mit_selbsttest else [])):
        log = logpfad("0-schichten%s.log" % ("-selbsttest" if zusatz else ""))
        rc = ausfuehren([sys.executable, "-X", "utf8", skript] + zusatz, log, FRIST_PYTHON)
        zeilen = [z.strip() for z in log_zeilen(log) if z.strip()]
        schluss = zeilen[-1] if zeilen else None
        name = "schichten_pruefen.py" + (" --selbsttest" if zusatz else "")
        if rc is None:
            befunde.append(("Schichten", name, "Zeitgrenze %d s überschritten (Log: %s)" % (FRIST_PYTHON, rel(log))))
            ergebnisse.append("Zeitgrenze")
        elif rc != 0 or schluss is None:
            befunde.append(("Schichten", name, "Rückgabecode %s, Schlusszeile: %s (Log: %s)"
                            % (rc, schluss or "keine", rel(log))))
            ergebnisse.append(schluss or "keine Schlusszeile")
        else:
            ergebnisse.append(schluss)
        e.detail("%s: %s" % (name, schluss or "(keine Ausgabe)"))
    return " / ".join(ergebnisse)


# =========================================================================================================
# Stufe 1 — Level-Generator
# =========================================================================================================

def level_stand():
    """Inhaltsprüfsummen der erzeugten Level (levels/ ohne _import/, das ist Eingabe des Generators)."""
    stand = {}
    basis = os.path.join(GODOT, "levels")
    for absolut, r in dateien_unter(basis):
        if r.startswith("_import/"):
            continue
        with open(absolut, "rb") as f:
            stand["levels/" + r] = hashlib.sha256(f.read()).hexdigest()
    return stand


def stufe_1(ctx):
    e = Ergebnis()
    generator = os.path.join(HIER, "build_levels.py")
    if not os.path.isfile(generator):
        return e.setze(FEHLGESCHLAGEN, "tools/build_levels.py fehlt")
    levels_git = None
    if ctx.git:
        levels_git = [git_pfad(ctx, "levels"), ":(exclude)" + git_pfad(ctx, "levels/_import")]
        offen = git_namen(ctx, "diff", "--name-only", "-z", "--", *levels_git)
        if offen:
            e.liste("Nicht gestagte Änderungen:", offen)
            return e.setze(FEHLGESCHLAGEN, "%d nicht gestagte Änderung(en) in levels/ — der Generator würde sie "
                                           "überschreiben; erst einchecken (git add godot/levels) oder verwerfen"
                           % len(offen))
    vorher = level_stand()
    log = logpfad("1-level-generator.log")
    rc = ausfuehren([sys.executable, "-X", "utf8", generator], log, FRIST_PYTHON)
    if rc is None:
        return e.setze(FEHLGESCHLAGEN, "Zeitgrenze von %d s überschritten (Log: %s)" % (FRIST_PYTHON, rel(log)))
    zeilen = log_zeilen(log)
    stationen = [z for z in zeilen if z.startswith(("✓", "✗"))]
    probleme = [z.strip() for z in zeilen if z.startswith("✗") or z.strip().startswith("!")]
    nachher = level_stand()
    abweichend = sorted(p for p in set(vorher) | set(nachher) if vorher.get(p) != nachher.get(p))
    neu_ungetrackt = []
    if ctx.git:
        diff = git_namen(ctx, "diff", "--name-only", "-z", "--", *levels_git) or []
        neu_ungetrackt = git_namen(ctx, "ls-files", "--others", "--exclude-standard", "-z", "--", *levels_git) or []
        abweichend = sorted(set(abweichend) | set(diff) | set(neu_ungetrackt))
    e.liste("Generator meldet:", probleme)
    e.liste("Weicht vom Generator ab (Ergebnis prüfen und einchecken):", abweichend)
    if not stationen:
        e.details += schwanz(log)
        return e.setze(FEHLGESCHLAGEN, "keine Stationszeilen (✓/✗) in der Ausgabe, Rückgabecode %s (Log: %s)"
                       % (rc, rel(log)))
    zahl_probleme = sum(1 for z in stationen if z.startswith("✗"))
    text = "%d Stationen erzeugt, %d mit Problemen, %d Dateien weichen von levels/ ab" % (
        len(stationen), zahl_probleme, len(abweichend))
    if not ctx.git:
        text += " (ohne Git: Abgleich mit den Dateien auf der Platte)"
    if rc != 0:
        text += ", Rückgabecode %d" % rc
    ok = rc == 0 and zahl_probleme == 0 and not abweichend
    return e.setze(BESTANDEN if ok else FEHLGESCHLAGEN, text)


# =========================================================================================================
# Stufe 2 — Import (und Log-Auswertung für Stufe 6)
# =========================================================================================================

def log_auswerten(zeilen):
    """Zählt Fehlerblöcke in einer Godot-Ausgabe. Ein Block ist eine Meldungszeile samt folgender „at:"-Zeilen;
    ein Block, der zu BEKANNT_HARMLOS passt, wird ignoriert (aber gezählt).
    Rückgabe dict: skriptfehler, fehler, ignoriert, warnungen (Listen der Meldungszeilen)."""
    erg = {"skriptfehler": [], "fehler": [], "ignoriert": [], "warnungen": []}
    zeilen = [ANSI.sub("", z) for z in zeilen]
    i = 0
    while i < len(zeilen):
        z = zeilen[i]
        block = [z]
        j = i + 1
        while j < len(zeilen) and re.match(r"^\s+(at:|GDScript backtrace|\[\d+\])", zeilen[j]):
            block.append(zeilen[j])
            j += 1
        text = z.strip()
        if "SCRIPT ERROR" in z or "Parse Error" in z:
            art = "skriptfehler"
        elif "ERROR:" in z:
            art = "fehler"
        elif "WARNING:" in z:
            art = "warnungen"
        else:
            art = None
        if art in ("skriptfehler", "fehler") and any(m.search(" ".join(block)) for m in BEKANNT_HARMLOS):
            art = "ignoriert"
        if art:
            erg[art].append(text + ("  " + block[1].strip() if len(block) > 1 else ""))
        i = j if art else i + 1
    return erg


def stufe_2(ctx):
    e = Ergebnis()
    if not ctx.godot:
        return e.setze(FEHLGESCHLAGEN, "Godot nicht gefunden (--godot <pfad> oder Umgebungsvariable GODOT)")
    log = logpfad("2-import.log")
    rc = ausfuehren([ctx.godot, "--headless", "--path", GODOT, "--import"], log, FRIST_IMPORT)
    if rc is None:
        return e.setze(FEHLGESCHLAGEN, "Zeitgrenze von %d s überschritten (Log: %s)" % (FRIST_IMPORT, rel(log)))
    zeilen = log_zeilen(log)
    # Der Import hat keine Schlusszeile; erwartet werden der Godot-Kopf und das Ende des Dateiscans.
    kopf = any(z.startswith("Godot Engine v") for z in zeilen)
    scan = any(re.search(r"\[ DONE \]\s+first_scan_filesystem", z) for z in zeilen)
    a = log_auswerten(zeilen)
    e.liste("Skriptfehler:", a["skriptfehler"])
    e.liste("Fehlerzeilen:", a["fehler"])
    e.liste("Ignoriert (bekannt harmlos):", a["ignoriert"], 5)
    e.liste("Warnzeilen (nicht gewertet):", a["warnungen"], 10)
    text = "Rückgabecode %d, %d Skriptfehler, %d Fehlerzeilen (%d bekannt harmlos ignoriert), %d Warnzeilen" % (
        rc, len(a["skriptfehler"]), len(a["fehler"]), len(a["ignoriert"]), len(a["warnungen"]))
    if not (kopf and scan):
        e.details += schwanz(log)
        return e.setze(FEHLGESCHLAGEN, "keine erwartete Abschlusszeile („[ DONE ] first_scan_filesystem“) — " + text)
    ok = rc == 0 and not a["skriptfehler"] and not a["fehler"]
    return e.setze(BESTANDEN if ok else FEHLGESCHLAGEN, text)


# =========================================================================================================
# Stufe 3 — Typwarnungen
# =========================================================================================================

def grenzen_laden():
    with open(GRENZWERTE, encoding="utf-8") as f:
        roh = json_streng(f.read())
    grenzen = {}
    for bereich, arten in roh.items():
        if bereich.startswith("_"):
            continue
        if not isinstance(arten, dict):
            raise ValueError("Bereich %s: erwartet ein Objekt {Art: Zahl}" % bereich)
        grenzen[bereich] = {}
        for art, zahl in arten.items():
            if isinstance(zahl, bool) or not isinstance(zahl, int) or zahl < 0:
                raise ValueError("%s/%s: Grenze muss eine ganze Zahl ≥ 0 sein" % (bereich, art))
            grenzen[bereich][art] = zahl
    return grenzen


def grenzen_vergleichen(ist, grenzen):
    """ist/grenzen: {bereich: {art: zahl}}. Nicht aufgeführte Arten haben die Grenze 0.
    Rückgabe (über: [(bereich, art, ist, grenze)], unter: [...])."""
    ueber, unter = [], []
    for bereich in sorted(set(ist) | set(grenzen)):
        i_b, g_b = ist.get(bereich, {}), grenzen.get(bereich, {})
        for art in sorted(set(i_b) | set(g_b)):
            i, g = i_b.get(art, 0), g_b.get(art, 0)
            if i > g:
                ueber.append((bereich, art, i, g))
            elif i < g:
                unter.append((bereich, art, i, g))
    return ueber, unter


def grenzen_schreiben(ist):
    daten = {
        "_hinweis": "Obergrenzen der GDScript-Warnungen je Bereich und Art (Stufe 3 von tools/pruefen.py, Zählung: "
                    "tests/typwarnungen.gd). Mehr = Fehler, weniger = Hinweis zum Nachziehen: python3 "
                    "godot/tools/pruefen.py --nur 3 --grenzen-nachziehen. Nicht aufgeführte Arten: Grenze 0.",
    }
    for bereich in sorted(ist):
        daten[bereich] = {art: ist[bereich][art] for art in sorted(ist[bereich])}
    with open(GRENZWERTE, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(daten, ensure_ascii=False, indent=2) + "\n")


def stufe_3(ctx):
    e = Ergebnis()
    if not ctx.godot:
        return e.setze(FEHLGESCHLAGEN, "Godot nicht gefunden (--godot <pfad> oder Umgebungsvariable GODOT)")
    log = logpfad("3-typwarnungen.log")
    # -d: nur mit aktivem Debugger gibt Godot Analysewarnungen aus; stdin ist zu (ausfuehren), damit ein
    # Debugger-Halt bei einem Parse-Fehler das Programm beendet, statt auf Eingaben zu warten.
    rc = ausfuehren([ctx.godot, "--headless", "-d", "--path", GODOT, "--script", "res://tests/typwarnungen.gd"],
                    log, FRIST_WARNUNGEN)
    if rc is None:
        return e.setze(FEHLGESCHLAGEN, "Zeitgrenze von %d s überschritten (Log: %s)" % (FRIST_WARNUNGEN, rel(log)))
    zeilen = log_zeilen(log)
    schluss = letzte_passende(zeilen, SCHLUSS_WARNUNGEN)
    if not schluss:
        e.details += schwanz(log)
        return e.setze(FEHLGESCHLAGEN, "keine Schlusszeile „N Skripte, M Warnungen, F Skriptfehler“, Rückgabecode %s "
                                       "(Log: %s)" % (rc, rel(log)))
    skripte, warnungen, skriptfehler = (int(x) for x in schluss.groups())
    ist = {}
    for z in zeilen:
        m = ZAEHLUNG.match(z.strip())
        if m:
            ist.setdefault(m.group(1), {})[m.group(2)] = int(m.group(3))
    summen = {b: sum(a.values()) for b, a in ist.items()}
    zahlen = "%d Skripte, %d Warnungen (%s), %d Skriptfehler" % (
        skripte, warnungen, ", ".join("%s %d" % (b, summen[b]) for b in sorted(summen)) or "keine", skriptfehler)
    if skriptfehler or rc != 0:
        e.liste("Skriptfehler:", [z.strip()[len("SKRIPTFEHLER "):] for z in zeilen if z.startswith("SKRIPTFEHLER ")])
        return e.setze(FEHLGESCHLAGEN, zahlen + ", Rückgabecode %d (Log: %s)" % (rc, rel(log)))
    if ctx.args.grenzen_nachziehen:
        alt = grenzen_laden() if os.path.isfile(GRENZWERTE) else {}
        ueber, unter = grenzen_vergleichen(ist, alt)
        e.liste("Grenze ERHÖHT:", ["%s %s: %d → %d" % (b, a, g, i) for b, a, i, g in ueber])
        e.liste("Grenze gesenkt:", ["%s %s: %d → %d" % (b, a, g, i) for b, a, i, g in unter])
        grenzen_schreiben(ist)
        e.detail("tools/grenzwerte.json auf den Ist-Stand gesetzt (%d erhöht, %d gesenkt)" % (len(ueber), len(unter)))
    if not os.path.isfile(GRENZWERTE):
        return e.setze(FEHLGESCHLAGEN, zahlen + "; tools/grenzwerte.json fehlt (anlegen: --nur 3 --grenzen-nachziehen)")
    try:
        grenzen = grenzen_laden()
    except (ValueError, OSError) as ex:
        return e.setze(FEHLGESCHLAGEN, zahlen + "; tools/grenzwerte.json unlesbar: %s" % ex)
    ueber, unter = grenzen_vergleichen(ist, grenzen)
    if ueber:
        # Wo die Warnungen der überschrittenen Arten herkommen: zuerst Dateien, die laut Git geändert oder neu
        # sind (dort liegt fast immer der Zuwachs), dann die Dateien mit den meisten Treffern.
        arten = {(b, a) for b, a, _, _ in ueber}
        je_datei = {}
        for z in zeilen:
            teile = z.split(" ", 4)
            if len(teile) >= 4 and teile[0] == "WARNUNG" and (teile[1], teile[2]) in arten:
                datei = teile[3].rsplit(":", 1)[0]
                je_datei[(teile[2], datei)] = je_datei.get((teile[2], datei), 0) + 1
        e.liste("Über der Grenze (mehr Warnungen als erlaubt):", ["%s %s: %d > Grenze %d" % x for x in ueber])
        if ctx.git:
            ordner = [git_pfad(ctx, "src"), git_pfad(ctx, "tests")]
            geaendert = set((git_namen(ctx, "diff", "--name-only", "-z", "HEAD", "--", *ordner) or [])
                            + (git_namen(ctx, "ls-files", "--others", "--exclude-standard", "-z", "--", *ordner) or []))
            e.liste("Davon in geänderten oder neuen Dateien (Git):",
                    ["%s %s: %d" % (a, d, n) for (a, d), n in sorted(je_datei.items()) if d in geaendert])
        e.liste("Meiste Treffer insgesamt:", ["%s %s: %d" % (a, d, n) for (a, d), n in
                                              sorted(je_datei.items(), key=lambda x: -x[1])[:5]])
    e.liste("Unter der Grenze (Grenze nachziehen: --nur 3 --grenzen-nachziehen):",
            ["%s %s: %d < Grenze %d" % x for x in unter])
    text = zahlen + "; %d Arten über der Grenze, %d darunter" % (len(ueber), len(unter))
    return e.setze(FEHLGESCHLAGEN if ueber else BESTANDEN, text)


# =========================================================================================================
# Stufe 4 — Tests
# =========================================================================================================

def stufe_4(ctx):
    e = Ergebnis()
    if not ctx.godot:
        return e.setze(FEHLGESCHLAGEN, "Godot nicht gefunden (--godot <pfad> oder Umgebungsvariable GODOT)")
    log = logpfad("4-tests.log")
    befehl = [ctx.godot, "--headless", "--path", GODOT, "--fixed-fps", "60", "--script", "res://tests/lauf.gd"]
    if ctx.args.tests:
        befehl += ["--", "--nur=" + ctx.args.tests]
    rc = ausfuehren(befehl, log, FRIST_TESTS)
    if rc is None:
        return e.setze(FEHLGESCHLAGEN, "Zeitgrenze von %d s überschritten (Log: %s)" % (FRIST_TESTS, rel(log)))
    zeilen = log_zeilen(log)
    schluss = letzte_passende(zeilen, SCHLUSS_TESTS)
    for z in zeilen:
        if z.startswith(("Fehlgeschlagen:", "Wachhund")) or "Warnungen (nicht gewertet)" in z:
            e.detail(z.strip())
    if not schluss:
        e.details += schwanz(log)
        return e.setze(FEHLGESCHLAGEN, "keine Schlusszeile „N Tests, M fehlgeschlagen“, Rückgabecode %s (Log: %s)"
                       % (rc, rel(log)))
    zeile = [z.strip() for z in zeilen if SCHLUSS_TESTS.match(z.strip())][-1]
    ok = rc == 0 and int(schluss.group(2)) == 0 and int(schluss.group(1)) > 0
    if rc != 0:
        zeile += ", Rückgabecode %d" % rc
    if ctx.args.tests:
        zeile += " (nur „%s“)" % ctx.args.tests
    return e.setze(BESTANDEN if ok else FEHLGESCHLAGEN, zeile)


# =========================================================================================================
# Stufe 5 — Exportprobe (PCK-Leser)
# =========================================================================================================

class PckFehler(Exception):
    pass


class Pck:
    """Verzeichnis eines Godot-4-Pakets (core/io/file_access_pack.cpp, editor/export/editor_export_platform.cpp):
      Kopf  "GDPC", u32 Formatversion (2, 3 oder 4), u32 major/minor/patch, u32 Paket-Flags, u64 Dateibasis,
            ab Version 3 u64 Verzeichnis-Offset (beide relativ zum Paketanfang); Version 2: 16 × u32 reserviert,
            das Verzeichnis folgt direkt.
      Verz. u32 Anzahl, je Datei: u32 Pfadlänge (auf 4 Byte aufgefüllt), Pfad (UTF-8, mit NUL aufgefüllt,
            ohne „res://"), u64 Offset (relativ zur Dateibasis), u64 Größe, 16 Byte MD5, u32 Datei-Flags.
      Flags Paket: 1 Verzeichnis verschlüsselt, 2 relative Dateibasis, 4 Sparse-Bundle;
            Datei: 1 verschlüsselt, 2 entfernt (Patch), 4 Delta.
      Ein in eine EXE eingebettetes Paket endet mit u64 Paketgröße + "GDPC"."""

    def __init__(self, pfad):
        self.pfad = pfad
        self.eintraege = {}      # Pfad → (absoluter Offset, Größe, Flags)
        with open(pfad, "rb") as f:
            f.seek(0, 2)
            ende = f.tell()
            f.seek(0)
            start = 0
            if f.read(4) != b"GDPC":
                if ende < 16:
                    raise PckFehler("zu kurz für ein Paket")
                f.seek(ende - 4)
                if f.read(4) != b"GDPC":
                    raise PckFehler("kein GDPC-Kopf (weder am Anfang noch am Ende der Datei)")
                f.seek(ende - 12)
                groesse = struct.unpack("<Q", f.read(8))[0]
                start = ende - 12 - groesse
                if start < 0:
                    raise PckFehler("eingebettetes Paket: Größe passt nicht zur Datei")
                f.seek(start)
                if f.read(4) != b"GDPC":
                    raise PckFehler("eingebettetes Paket: kein GDPC-Kopf an Position %d" % start)
            self.version, maj, mino, patch, self.flags = struct.unpack("<5I", f.read(20))
            self.godot = "%d.%d.%d" % (maj, mino, patch)
            if self.version not in (2, 3, 4):
                raise PckFehler("Paketformat %d unbekannt (bekannt: 2, 3, 4)" % self.version)
            basis = struct.unpack("<Q", f.read(8))[0]
            if self.version >= 3 or (self.flags & PACK_REL_FILEBASE):
                basis += start
            if self.version >= 3:
                f.seek(struct.unpack("<Q", f.read(8))[0] + start)
            else:
                f.read(16 * 4)
            anzahl = struct.unpack("<I", f.read(4))[0]
            if self.flags & PACK_DIR_ENCRYPTED:
                raise PckFehler("Paketverzeichnis verschlüsselt (encrypt_directory) — Inhalt nicht lesbar")
            for _ in range(anzahl):
                laenge = struct.unpack("<I", f.read(4))[0]
                name = f.read(laenge).split(b"\0", 1)[0].decode("utf-8", errors="replace")
                if name.startswith("res://"):
                    name = name[len("res://"):]
                ofs, groesse = struct.unpack("<QQ", f.read(16))
                f.read(16)
                dflags = struct.unpack("<I", f.read(4))[0]
                if dflags & PACK_FILE_REMOVAL:
                    self.eintraege.pop(name, None)
                    continue
                self.eintraege[name] = (basis + ofs, groesse, dflags)

    def lesen(self, name):
        """Inhalt einer (kleinen) Datei als Text, None wenn verschlüsselt oder Sparse-Bundle."""
        ofs, groesse, dflags = self.eintraege[name]
        if dflags & PACK_FILE_ENCRYPTED or self.flags & PACK_SPARSE_BUNDLE:
            return None
        with open(self.pfad, "rb") as f:
            f.seek(ofs)
            return f.read(groesse).decode("utf-8", errors="replace")


def pflichtdateien(wurzel):
    """Dateien, die das Spiel zur Laufzeit braucht, abgeleitet aus dem Code: jedes res://-Literal in src/**/*.gd,
    scenes/**/*.tscn und project.godot, das eine Datei im Repo nennt; nennt es einen Ordner (z. B. „res://i18n",
    „res://levels/", „res://assets/audio/%s.wav"), alle ladbaren Dateien darin (LAUFZEIT_ENDUNGEN); dazu alle
    Skripte, Shader und Szenen unter src/ und scenes/ und die Projektdateien des Exports.
    Rückgabe ({pfad: quelle}, [Hinweise auf genannte, aber fehlende Pfade])."""
    pflicht, hinweise = {}, []

    def ordner_dateien(ordner):
        for o, unter, namen in os.walk(ordner):
            unter[:] = sorted(u for u in unter if not u.startswith(".")
                              and not os.path.exists(os.path.join(o, u, ".gdignore")))
            for n in sorted(namen):
                if os.path.splitext(n)[1].lower() in LAUFZEIT_ENDUNGEN:
                    yield rel(os.path.join(o, n), wurzel)

    quellen = [r for _, r in dateien_unter(wurzel)
               if (r.startswith("src/") and r.endswith(".gd")) or (r.startswith("scenes/") and r.endswith(".tscn"))]
    quellen.append("project.godot")
    for q in quellen:
        try:
            with open(os.path.join(wurzel, q), encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            continue
        for m in RES_PFAD.finditer(text):
            p = m.group(0)[len("res://"):]
            for zeichen in "%{<":            # Platzhalter: „%s", „{id}", „<id>" (auch aus Kommentaren)
                if zeichen in p:
                    p = p[:p.index(zeichen)]
                    p = p[:p.rfind("/") + 1]
            p = p.rstrip("/")
            if not p:
                continue
            ziel = os.path.join(wurzel, p)
            if os.path.isfile(ziel):
                pflicht.setdefault(p, q)
            elif os.path.isdir(ziel):
                if not os.path.exists(os.path.join(ziel, ".gdignore")):
                    for d in ordner_dateien(ziel):
                        pflicht.setdefault(d, q + " (Ordner res://%s)" % p)
            else:
                hinweise.append("%s nennt res://%s — nicht im Repo (optional?)" % (q, p))
    for ordner in ("src", "scenes"):
        for d in ordner_dateien(os.path.join(wurzel, ordner)):
            if d.endswith((".gd", ".gdshader", ".tscn", ".tres")):
                pflicht.setdefault(d, "Spielcode")
    for d in ("project.binary", ".godot/global_script_class_cache.cfg", ".godot/uid_cache.bin"):
        pflicht.setdefault(d, "Projektdatei des Exports")
    return pflicht, sorted(set(hinweise))


def pck_aufloesen(pck, pfad):
    """Ist `pfad` im Paket — direkt, als importierte Ressource (.import → Ziel unter .godot/imported) oder
    umgewandelt (.remap → .gdc / exportierte Szene)? Rückgabe (ok, Grund)."""
    if pfad in pck.eintraege:
        return True, ""
    for endung in (".import", ".remap"):
        meta = pfad + endung
        if meta in pck.eintraege:
            inhalt = pck.lesen(meta)
            if inhalt is None:
                return True, "verschlüsselt, Ziel nicht geprüft"
            ziele = re.findall(r'^path(?:\.[\w-]+)?="res://([^"]+)"', inhalt, re.M)
            if not ziele:
                return False, "%s ohne path=" % meta
            fehlen = [z for z in ziele if z not in pck.eintraege]
            if fehlen:
                return False, "%s da, Ziel fehlt: %s" % (meta, ", ".join(fehlen))
            return True, ""
    return False, "nicht im Paket"


def pck_pruefen(pck, pflicht):
    fehlend = []
    for p in sorted(pflicht):
        ok, grund = pck_aufloesen(pck, p)
        if not ok:
            fehlend.append("%s — %s (gebraucht von %s)" % (p, grund, pflicht[p]))
    unerwuenscht = [n for n in sorted(pck.eintraege) if UNERWUENSCHT.match(n)]
    return fehlend, unerwuenscht


def stufe_5(ctx):
    e = Ergebnis()
    if not ctx.godot:
        return e.setze(FEHLGESCHLAGEN, "Godot nicht gefunden (--godot <pfad> oder Umgebungsvariable GODOT)")
    pflicht, hinweise = pflichtdateien(GODOT)
    e.liste("Vom Code genannt, aber nicht im Repo (nicht gewertet):", hinweise, 8)
    teile, fehlgeschlagen, vorlagen_fehlen = [], False, []
    temp = tempfile.mkdtemp(prefix="pruefen_export_")
    try:
        for preset in EXPORT_PRESETS:
            log = logpfad("5-export-%s.log" % preset.lower())
            ziel = os.path.join(temp, preset.lower() + ".pck")
            rc = ausfuehren([ctx.godot, "--headless", "--path", GODOT, "--export-pack", preset, ziel], log,
                            FRIST_EXPORT)
            if rc is None:
                teile.append("%s: Zeitgrenze %d s überschritten" % (preset, FRIST_EXPORT))
                fehlgeschlagen = True
                continue
            if rc != 0 or not os.path.isfile(ziel):
                text = "\n".join(log_zeilen(log))
                if re.search(r"export template|Export-Vorlage", text, re.I):
                    vorlagen_fehlen.append(preset)
                    teile.append("%s: Export braucht Vorlagen" % preset)
                else:
                    teile.append("%s: Export fehlgeschlagen, Rückgabecode %s (Log: %s)" % (preset, rc, rel(log)))
                    e.details += schwanz(log, 6)
                    fehlgeschlagen = True
                continue
            try:
                pck = Pck(ziel)
            except (PckFehler, OSError, struct.error) as ex:
                teile.append("%s: Paket nicht lesbar: %s" % (preset, ex))
                fehlgeschlagen = True
                continue
            fehlend, unerwuenscht = pck_pruefen(pck, pflicht)
            e.liste("%s — fehlt im Paket:" % preset, fehlend)
            e.liste("%s — unerwünscht im Paket:" % preset, unerwuenscht)
            e.detail("%s: Paketformat %d, Godot %s, %.1f MB, Flags %d" % (
                preset, pck.version, pck.godot, os.path.getsize(ziel) / 1e6, pck.flags))
            teile.append("%s: %d Dateien im Paket, %d fehlen, %d unerwünscht" % (
                preset, len(pck.eintraege), len(fehlend), len(unerwuenscht)))
            if fehlend or unerwuenscht:
                fehlgeschlagen = True
    finally:
        shutil.rmtree(temp, ignore_errors=True)
    text = "; ".join(teile) + " (%d Pflichtdateien aus dem Code)" % len(pflicht)
    if fehlgeschlagen:
        return e.setze(FEHLGESCHLAGEN, text)
    if vorlagen_fehlen:
        return e.setze(UEBERSPRUNGEN, text + " — --export-pack braucht hier Export-Vorlagen (Editor → Export → "
                                             "Vorlagen verwalten), Paketinhalt nicht prüfbar")
    return e.setze(BESTANDEN, text)


# =========================================================================================================
# Stufe 6 — Bildprobe (PNG-Leser)
# =========================================================================================================

def png_lesen(pfad):
    """Minimaler PNG-Leser (8 Bit je Kanal, Grau/Grau+Alpha/RGB/RGBA, ohne Interlace — so speichert Godot).
    Rückgabe (breite, höhe, kanäle, zeilen als bytearray)."""
    with open(pfad, "rb") as f:
        daten = f.read()
    if daten[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("keine PNG-Datei")
    pos, idat, kopf = 8, [], None
    while pos + 8 <= len(daten):
        laenge, typ = struct.unpack(">I4s", daten[pos:pos + 8])
        inhalt = daten[pos + 8:pos + 8 + laenge]
        pos += 12 + laenge
        if typ == b"IHDR":
            kopf = struct.unpack(">IIBBBBB", inhalt)
        elif typ == b"IDAT":
            idat.append(inhalt)
        elif typ == b"IEND":
            break
    if kopf is None:
        raise ValueError("PNG ohne IHDR")
    breite, hoehe, tiefe, farbtyp, _, _, interlace = kopf
    kanaele = {0: 1, 2: 3, 4: 2, 6: 4}.get(farbtyp)
    if tiefe != 8 or kanaele is None or interlace != 0:
        raise ValueError("PNG-Format nicht unterstützt (Tiefe %d, Farbtyp %d, Interlace %d)" % (tiefe, farbtyp, interlace))
    roh = zlib.decompress(b"".join(idat))
    schritt = breite * kanaele
    if len(roh) < hoehe * (schritt + 1):
        raise ValueError("PNG-Daten zu kurz")
    vorher = bytearray(schritt)
    zeilen = []
    p = 0
    k = kanaele
    for _ in range(hoehe):
        filt = roh[p]
        z = bytearray(roh[p + 1:p + 1 + schritt])
        p += 1 + schritt
        if filt == 1:
            for i in range(k, schritt):
                z[i] = (z[i] + z[i - k]) & 0xFF
        elif filt == 2:
            z = bytearray((a + b) & 0xFF for a, b in zip(z, vorher))
        elif filt == 3:
            for i in range(schritt):
                z[i] = (z[i] + (((z[i - k] if i >= k else 0) + vorher[i]) >> 1)) & 0xFF
        elif filt == 4:
            for i in range(schritt):
                a = z[i - k] if i >= k else 0
                b = vorher[i]
                c = vorher[i - k] if i >= k else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                z[i] = (z[i] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 0xFF
        elif filt != 0:
            raise ValueError("unbekannter PNG-Zeilenfilter %d" % filt)
        zeilen.append(z)
        vorher = z
    return breite, hoehe, kanaele, zeilen


def bild_helligkeit(pfad, schritt=2, ohne_pil=False):
    """(breite, höhe, Standardabweichung der Helligkeit 0–255). Mit Pillow, falls vorhanden, sonst eigener Leser
    (jedes `schritt`-te Pixel in beiden Richtungen). Helligkeit nach ITU-R 601: 0,299 R + 0,587 G + 0,114 B."""
    if not ohne_pil:
        try:
            from PIL import Image, ImageStat   # optional
            with Image.open(pfad) as bild:
                return bild.width, bild.height, ImageStat.Stat(bild.convert("L")).stddev[0]
        except ImportError:
            pass
    breite, hoehe, k, zeilen = png_lesen(pfad)
    n = s = q = 0.0
    for y in range(0, hoehe, schritt):
        z = zeilen[y]
        for x in range(0, breite * k, schritt * k):
            h = (0.299 * z[x] + 0.587 * z[x + 1] + 0.114 * z[x + 2]) if k >= 3 else z[x]
            n += 1
            s += h
            q += h * h
    mittel = s / n
    return breite, hoehe, math.sqrt(max(0.0, q / n - mittel * mittel))


def stufe_6(ctx):
    e = Ergebnis()
    if not ctx.godot:
        return e.setze(FEHLGESCHLAGEN, "Godot nicht gefunden (--godot <pfad> oder Umgebungsvariable GODOT)")
    vorne = []
    if shutil.which("xvfb-run"):
        vorne = ["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24"]
    elif not (os.name == "nt" or sys.platform == "darwin" or os.environ.get("DISPLAY")
              or os.environ.get("WAYLAND_DISPLAY")):
        return e.setze(UEBERSPRUNGEN, "kein xvfb-run und kein Bildschirm — Bildprobe braucht ein Fenster")
    ziel = os.path.join(LOGS, "bilder")
    shutil.rmtree(ziel, ignore_errors=True)        # vorher leeren: nie ein altes Bild prüfen
    os.makedirs(ziel)
    teile, fehler = [], False
    for level, stelle in BILD_STATIONEN:
        log = logpfad("6-bild-%s.log" % level)
        rc = ausfuehren(vorne + [ctx.godot, "--path", GODOT, "--rendering-method", "gl_compatibility",
                                 "--resolution", "1920x1080", "--script", "res://tests/standbild.gd", "--",
                                 "--windowed", "--webfx", "--level=" + level, "--an=" + stelle, "--ziel=" + ziel],
                        log, FRIST_BILD)
        zeilen = log_zeilen(log)
        a = log_auswerten(zeilen)
        e.liste("%s — Skriptfehler:" % level, a["skriptfehler"])
        e.liste("%s — Fehlerzeilen (nicht gewertet):" % level, a["fehler"], 5)
        bild = os.path.join(ziel, "%s-%s.png" % (level, stelle))
        gemeldet = any(z.strip() == "[bild] " + bild or z.strip().endswith("%s-%s.png" % (level, stelle))
                       for z in zeilen if z.strip().startswith("[bild]"))
        if rc is None:
            teile.append("%s: Zeitgrenze %d s überschritten" % (level, FRIST_BILD))
            fehler = True
            continue
        if not gemeldet:
            e.details += schwanz(log, 6)
            teile.append("%s: keine Zeile „[bild] …%s-%s.png“, Rückgabecode %s" % (level, level, stelle, rc))
            fehler = True
            continue
        if not os.path.isfile(bild) or os.path.getsize(bild) == 0:
            teile.append("%s: Bild fehlt (%s)" % (level, rel(bild)))
            fehler = True
            continue
        try:
            breite, hoehe, sigma = bild_helligkeit(bild)
        except (ValueError, OSError, zlib.error) as ex:
            teile.append("%s: Bild unlesbar: %s" % (level, ex))
            fehler = True
            continue
        einfarbig = sigma <= BILD_MIN_SIGMA
        teile.append("%s %s: %dx%d, Helligkeit σ=%.1f%s" % (level, stelle, breite, hoehe, sigma,
                                                             " — EINFARBIG" if einfarbig else ""))
        e.detail("Bild: %s" % rel(bild))
        if einfarbig or rc != 0 or a["skriptfehler"]:
            fehler = True
    text = "; ".join(teile) + " (Schwelle σ > %.1f)" % BILD_MIN_SIGMA
    return e.setze(FEHLGESCHLAGEN if fehler else BESTANDEN, text)


# =========================================================================================================
# Selbsttest — die Prüfer an künstlichen Dateien (läuft in Stufe 0 mit und einzeln mit --selbsttest)
# =========================================================================================================

def _png_schreiben(pfad, breite, hoehe, kanaele, pixel, filter_folge):
    """PNG mit wählbaren Zeilenfiltern schreiben (nur für den Selbsttest des Lesers)."""
    farbtyp = {1: 0, 2: 4, 3: 2, 4: 6}[kanaele]
    roh, vorher = bytearray(), bytes(breite * kanaele)
    k = kanaele
    for y in range(hoehe):
        z = bytes(v for x in range(breite) for v in pixel(x, y))
        f = filter_folge[y % len(filter_folge)]
        out = bytearray()
        for i in range(len(z)):
            a = z[i - k] if i >= k else 0
            b = vorher[i]
            c = vorher[i - k] if i >= k else 0
            if f == 0:
                pr = 0
            elif f == 1:
                pr = a
            elif f == 2:
                pr = b
            elif f == 3:
                pr = (a + b) >> 1
            else:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
            out.append((z[i] - pr) & 0xFF)
        roh.append(f)
        roh += out
        vorher = z

    def block(typ, inhalt):
        return struct.pack(">I", len(inhalt)) + typ + inhalt + struct.pack(">I", zlib.crc32(typ + inhalt) & 0xFFFFFFFF)

    with open(pfad, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + block(b"IHDR", struct.pack(">IIBBBBB", breite, hoehe, 8, farbtyp, 0, 0, 0))
                + block(b"IDAT", zlib.compress(bytes(roh))) + block(b"IEND", b""))


def _pck_schreiben(pfad, dateien, version=4, vorne=b""):
    """Kleines Godot-Paket schreiben (nur für den Selbsttest des Lesers). dateien: {name: bytes}.
    `vorne` != b"" schreibt es eingebettet hinter diese Bytes (wie in eine EXE)."""
    namen = sorted(dateien)
    kopf_laenge = 4 + 20 + 8 + (8 + 64 if version >= 3 else 64)
    inhalt = bytearray()
    lage = {}
    for n in namen:
        while len(inhalt) % 16:
            inhalt.append(0)
        lage[n] = len(inhalt)
        inhalt += dateien[n]
    verzeichnis = bytearray(struct.pack("<I", len(namen)))
    for n in namen:
        b = n.encode("utf-8")
        b += b"\0" * ((4 - len(b) % 4) % 4)
        verzeichnis += struct.pack("<I", len(b)) + b + struct.pack("<QQ", lage[n], len(dateien[n])) + b"\0" * 16
        verzeichnis += struct.pack("<I", 0)
    if version >= 3:
        basis = kopf_laenge
        dir_ofs = basis + len(inhalt)
        kopf = b"GDPC" + struct.pack("<5I", version, 4, 7, 2, PACK_REL_FILEBASE) + struct.pack("<QQ", basis, dir_ofs)
        kopf += b"\0" * 64
        paket = kopf + bytes(inhalt) + bytes(verzeichnis)
    else:
        basis = kopf_laenge + len(verzeichnis)
        kopf = b"GDPC" + struct.pack("<5I", 2, 4, 2, 0, PACK_REL_FILEBASE) + struct.pack("<Q", basis) + b"\0" * 64
        paket = kopf + bytes(verzeichnis) + bytes(inhalt)
    if vorne:
        paket = vorne + paket + struct.pack("<Q", len(paket)) + b"GDPC"
    with open(pfad, "wb") as f:
        f.write(paket)


def selbsttest():
    """Rückgabe (Zahl der Prüfungen, Liste der Fehlschläge)."""
    n = [0]
    fehler = []

    def pruefe(ok, was):
        n[0] += 1
        if not ok:
            fehler.append(was)

    def arten(befunde):
        return sorted(b[0] for b in befunde)

    # Textdateien
    pruefe(arten(datei_befunde(b"extends Node\n\x00\n", "a.gd")) == ["NUL-Byte"], "NUL-Byte nicht erkannt")
    pruefe(arten(datei_befunde(b'{"a": 1}\x01\n', "a.json")) == ["Steuerzeichen"], "Steuerzeichen nicht erkannt")
    pruefe(arten(datei_befunde(b"a\r\nb\r\n", "a.txt")) == ["CRLF"], "CRLF nicht erkannt")
    pruefe(arten(datei_befunde(b"a\rb\n", "a.txt")) == ["Steuerzeichen"], "einzelnes CR nicht erkannt")
    pruefe(arten(datei_befunde(b"\xef\xbb\xbf{}\n", "a.json")) == ["BOM"], "BOM nicht erkannt")
    pruefe(arten(datei_befunde(b"gr\xfc\xdfe\n", "a.txt")) == ["kein UTF-8"], "Latin-1 nicht erkannt")
    pruefe(datei_befunde("extends Node\n\tvar ä := 1\n".encode("utf-8"), "a.gd") == [], "saubere Datei bemängelt")
    # JSON
    pruefe(len(json_befunde(b'{"a": [1, 2,]}', "a.json")) == 1, "nachgestelltes Komma nicht erkannt")
    pruefe("doppelter" in str(json_befunde(b'{"a": 1, "b": {"c": 1, "c": 2}}', "a.json")),
           "doppelter Schlüssel nicht erkannt")
    pruefe(len(json_befunde(b'{"a": NaN}', "a.json")) == 1, "NaN nicht erkannt")
    pruefe(len(json_befunde(b'{"a": 1} // x', "a.json")) == 1, "Kommentar nicht erkannt")
    pruefe(json_befunde('{"ä": [1, 2.5, null, true]}'.encode("utf-8"), "a.json") == [], "sauberes JSON bemängelt")
    # .uid
    temp = tempfile.mkdtemp(prefix="pruefen_selbsttest_")
    try:
        def schreibe(name, inhalt):
            pfad = os.path.join(temp, *name.split("/"))
            os.makedirs(os.path.dirname(pfad), exist_ok=True)
            with open(pfad, "w", encoding="utf-8", newline="\n") as f:
                f.write(inhalt)

        schreibe("src/a.gd", "extends Node\n")                       # ohne .uid
        schreibe("src/b.gd", "extends Node\n")
        schreibe("src/b.gd.uid", "uid://abc123\n")
        schreibe("tests/c.gd.uid", "uid://def456\n")                 # verwaist
        schreibe("assets/x.png.import", '[remap]\n\nimporter="texture"\nuid="uid://abc123"\n')   # doppelt mit b
        schreibe("src/s.gdshader", "shader_type canvas_item;\n")
        schreibe("src/s.gdshader.uid", "uid://ghi789\n")
        dateien = sorted(r for _, r in dateien_unter(temp))
        b, zahl = uid_befunde(temp, dateien, {"src/b.gd", "src/s.gdshader", "src/s.gdshader.uid"})
        pruefe(zahl == 3, "Zahl der Skripte/Shader falsch (%d statt 3)" % zahl)
        pruefe(arten(b) == ["UID doppelt", "UID fehlt", "UID nicht eingecheckt", "UID verwaist"],
               "UID-Befunde falsch: %s" % arten(b))
        b, _ = uid_befunde(temp, dateien, None)
        pruefe("UID nicht eingecheckt" not in arten(b), "Index-Prüfung ohne Index")

        # Log-Auswertung
        log = [
            "Godot Engine v4.7.2.stable.official - https://godotengine.org",
            "\x1b[1;31mERROR:\x1b[0m Condition \"status < 0\" is true. Returning: ERR_CANT_OPEN",
            "   at: init_output_device (drivers/alsa/audio_driver_alsa.cpp:89)",
            "WARNING: All audio drivers failed, falling back to the dummy driver.",
            "SCRIPT ERROR: Parse Error: Expected expression.",
            "          at: GDScript::reload (res://src/x.gd:3)",
            "ERROR: Failed to load script \"res://src/x.gd\" with error \"Parse error\".",
            "   at: load (modules/gdscript/gdscript.cpp:2907)",
            "[ DONE ] first_scan_filesystem",
        ]
        a = log_auswerten(log)
        pruefe([len(a[k]) for k in ("skriptfehler", "fehler", "ignoriert", "warnungen")] == [1, 1, 1, 1],
               "Log-Auswertung falsch: %s" % {k: len(v) for k, v in a.items()})

        # PNG-Leser: alle Zeilenfilter, alle Farbtypen; einfarbig gegen Verlauf
        for k in (1, 2, 3, 4):
            pfad = os.path.join(temp, "verlauf%d.png" % k)
            _png_schreiben(pfad, 23, 17, k, lambda x, y, k=k: [(x * 11 + y * 7 + c * 50) & 0xFF for c in range(k)],
                           [0, 1, 2, 3, 4])
            breite, hoehe, kk, zeilen = png_lesen(pfad)
            soll = [[(x * 11 + y * 7 + c * 50) & 0xFF for x in range(23) for c in range(k)] for y in range(17)]
            pruefe((breite, hoehe, kk) == (23, 17, k) and [list(z) for z in zeilen] == soll,
                   "PNG-Leser falsch (Kanäle %d)" % k)
        eben = os.path.join(temp, "eben.png")
        _png_schreiben(eben, 40, 30, 3, lambda x, y: [12, 34, 56], [4, 1])
        streifen = os.path.join(temp, "streifen.png")
        _png_schreiben(streifen, 40, 30, 3, lambda x, y: [255, 255, 255] if (x // 5) % 2 else [0, 0, 0], [0, 2, 4])
        for ohne_pil in (True, False):       # eigener Leser und (falls installiert) Pillow
            weg = "eigener Leser" if ohne_pil else "Pillow/Standardweg"
            pruefe(bild_helligkeit(eben, ohne_pil=ohne_pil)[2] <= BILD_MIN_SIGMA, "einfarbig nicht erkannt (%s)" % weg)
            pruefe(bild_helligkeit(streifen, ohne_pil=ohne_pil)[2] > BILD_MIN_SIGMA,
                   "Bild mit Inhalt als einfarbig gewertet (%s)" % weg)

        # PCK-Leser und Paketprüfung (Formate 4 und 2, eingebettet)
        imp = '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\npath="res://.godot/imported/x.wav-1.sample"\n'
        paket = {"project.binary": b"x", "config/a.json": b"{}", "assets/x.wav.import": imp.encode(),
                 ".godot/imported/x.wav-1.sample": b"RIFF", "src/a.gd.remap": b'[remap]\n\npath="res://src/a.gdc"\n',
                 "src/b.gd.remap": b'[remap]\n\npath="res://src/b.gdc"\n', "src/b.gdc": b"GDSC",
                 "tests/test_x.gdc": b"GDSC", "build-web/x.txt": b"x"}
        pflicht = {"config/a.json": "t", "assets/x.wav": "t", "src/a.gd": "t", "src/b.gd": "t", "config/b.json": "t"}
        for version, vorne in ((4, b""), (2, b""), (4, b"MZ" + b"\0" * 1001)):
            pfad = os.path.join(temp, "p%d.pck" % version)
            _pck_schreiben(pfad, paket, version, vorne)
            pck = Pck(pfad)
            pruefe(sorted(pck.eintraege) == sorted(paket), "PCK-Verzeichnis falsch (Format %d, eingebettet %s)"
                   % (version, bool(vorne)))
            pruefe(pck.lesen("src/b.gd.remap") == '[remap]\n\npath="res://src/b.gdc"\n', "PCK-Inhalt falsch gelesen")
            fehlend, unerw = pck_pruefen(pck, pflicht)
            pruefe([f.split(" ")[0] for f in fehlend] == ["config/b.json", "src/a.gd"],
                   "fehlende Pflichtdateien falsch: %s" % fehlend)
            pruefe(unerw == ["build-web/x.txt", "tests/test_x.gdc"], "unerwünschte Dateien falsch: %s" % unerw)
        kaputt = os.path.join(temp, "kaputt.pck")
        with open(kaputt, "wb") as f:
            f.write(b"kein Paket" * 10)
        try:
            Pck(kaputt)
            pruefe(False, "kaputtes Paket nicht erkannt")
        except PckFehler:
            pruefe(True, "")
    finally:
        shutil.rmtree(temp, ignore_errors=True)

    # Grenzwerte
    ueber, unter = grenzen_vergleichen({"src": {"A": 3, "NEU": 1}, "tests": {"B": 1}},
                                       {"src": {"A": 2, "C": 4}, "tests": {"B": 1}})
    pruefe(ueber == [("src", "A", 3, 2), ("src", "NEU", 1, 0)] and unter == [("src", "C", 0, 4)],
           "Grenzvergleich falsch: %s / %s" % (ueber, unter))
    return n[0], fehler


# =========================================================================================================
# Ablauf
# =========================================================================================================

STUFEN = [
    (0, "Dateien", stufe_0),
    (1, "Level-Generator", stufe_1),
    (2, "Import", stufe_2),
    (3, "Typwarnungen", stufe_3),
    (4, "Tests", stufe_4),
    (5, "Exportprobe", stufe_5),
    (6, "Bildprobe", stufe_6),
]


def stufen_waehlen(a):
    """Rückgabe (gewählte Nummern, ausgelassene Nummern mit Grund)."""
    if a.nur:
        try:
            nummern = sorted({int(x) for x in a.nur.replace(" ", "").split(",") if x})
        except ValueError:
            raise SystemExit("--nur erwartet Stufennummern, z. B. --nur 2,3")
        unbekannt = [x for x in nummern if x not in [s[0] for s in STUFEN]]
        if unbekannt:
            raise SystemExit("unbekannte Stufe(n): %s" % unbekannt)
    elif a.schnell:
        nummern = [0, 1]
    else:
        nummern = [0, 1, 2, 3, 4, 5] + ([6] if a.bilder else [])
    ausgelassen = {5: "--ohne-export"} if a.ohne_export and 5 in nummern else {}
    return nummern, ausgelassen


def main():
    ap = argparse.ArgumentParser(description="Prüfstufen der Godot-Fassung (Kopf der Datei: alle Aufrufe).")
    ap.add_argument("--schnell", action="store_true", help="nur Stufen 0 und 1 (Commit-Haken, ohne Godot)")
    ap.add_argument("--bilder", action="store_true", help="zusätzlich Stufe 6 (Bildprobe, braucht ein Fenster/xvfb)")
    ap.add_argument("--ohne-export", action="store_true", help="Stufe 5 auslassen (zählt als übersprungen)")
    ap.add_argument("--nur", metavar="N[,N…]", help="nur diese Stufen")
    ap.add_argument("--tests", metavar="TEIL", help="Stufe 4: nur tests/test_*.gd, deren Name TEIL enthält")
    ap.add_argument("--godot", metavar="PFAD", help="Godot-Programm (sonst $GODOT, .tools/…, PATH)")
    ap.add_argument("--grenzen-nachziehen", action="store_true",
                    help="Stufe 3: tools/grenzwerte.json auf den gezählten Ist-Stand setzen")
    ap.add_argument("--selbsttest", action="store_true", help="nur die Prüfer an künstlichen Dateien testen")
    ap.add_argument("--liste", action="store_true", help="Stufen zeigen, nichts ausführen")
    a = ap.parse_args()

    if a.liste:
        for nr, name, _ in STUFEN:
            print("Stufe %d: %s%s" % (nr, name, " (nur mit --bilder)" if nr == 6 else ""))
        return 0
    if a.selbsttest:
        zahl, fehler = selbsttest()
        for f in fehler:
            print("  ✗ " + f)
        print("SELBSTTEST: %d Prüfungen, %d fehlgeschlagen" % (zahl, len(fehler)))
        return 1 if fehler else 0

    nummern, ausgelassen = stufen_waehlen(a)
    if a.grenzen_nachziehen and 3 not in nummern:
        raise SystemExit("--grenzen-nachziehen gehört zu Stufe 3 (z. B. --nur 3 --grenzen-nachziehen)")
    logs_vorbereiten()
    ctx = Kontext(a)
    ctx.git = git_finden()
    print("pruefen.py — Godot-Fassung unter %s" % GODOT)
    if any(n >= 2 for n in nummern):
        ctx.godot = godot_finden(a.godot)
        if ctx.godot:
            ctx.godot_version = godot_version(ctx.godot)
            if ctx.godot_version is None:
                print("Godot: %s startet nicht (godot --version scheitert)" % ctx.godot)
                ctx.godot = None
            else:
                print("Godot: %s (%s)" % (ctx.godot, ctx.godot_version))
        else:
            print("Godot: nicht gefunden (--godot <pfad>, Umgebungsvariable GODOT oder godot im PATH)")
    print("Git: %s" % ("Arbeitskopie %s" % ctx.git[0] if ctx.git else "keins — Abgleich gegen Git entfällt"))
    print("Logs: %s" % LOGS, flush=True)

    t_gesamt = time.time()
    fehlgeschlagen = uebersprungen = 0
    for nr, name, funktion in STUFEN:
        if nr not in nummern:
            continue
        print("== Stufe %d: %s ==" % (nr, name), flush=True)
        t0 = time.time()
        if nr in ausgelassen:
            e = Ergebnis().setze(UEBERSPRUNGEN, "ausgelassen (%s)" % ausgelassen[nr])
        else:
            try:
                e = funktion(ctx)
            except KeyboardInterrupt:
                raise
            except Exception as ex:   # eine kaputte Stufe darf die übrigen nicht verdecken
                e = Ergebnis().setze(FEHLGESCHLAGEN, "Stufe abgebrochen: %s: %s" % (type(ex).__name__, ex))
                e.details += ["| " + z for z in traceback.format_exc().splitlines()[-6:]]
            if e.urteil is None:
                e.setze(FEHLGESCHLAGEN, "Stufe lieferte kein Ergebnis")
        for zeile in e.details:
            print("  " + zeile)
        print("STUFE %d %s: %s – %s [%.1f s]" % (nr, name, e.urteil, e.text, time.time() - t0), flush=True)
        if e.urteil == FEHLGESCHLAGEN:
            fehlgeschlagen += 1
        elif e.urteil == UEBERSPRUNGEN:
            uebersprungen += 1
    print("Dauer: %.0f s" % (time.time() - t_gesamt))
    print("%d Stufen, %d fehlgeschlagen, %d übersprungen" % (len(nummern), fehlgeschlagen, uebersprungen), flush=True)
    if fehlgeschlagen:
        return 1
    return 2 if uebersprungen else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nabgebrochen (Strg+C)")
        sys.exit(1)
