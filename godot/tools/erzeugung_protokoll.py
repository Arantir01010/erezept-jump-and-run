#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
erzeugung_protokoll.py — hält jede Erzeugung mit einem KI-Dienst fest (Grafik, Klang, Musik, Sprache).

    python godot/tools/erzeugung_protokoll.py --neu --dienst higgsfield --modell <modell>
        --prompt-datei prompt.txt --parameter quality=medium --parameter seed=42
        --eingabe vorlage.png --ausgabe godot/assets/sprites/paul.png
        --kosten 2 --einheit Credits --auftrag <auftragskennung> --bedingungen "Higgsfield, Stand 23.10.2026"
    python godot/tools/erzeugung_protokoll.py --pruefen [DATEI]   Form jeder Zeile prüfen
    python godot/tools/erzeugung_protokoll.py --liste [DATEI]     Übersicht mit Kostensumme
    python godot/tools/erzeugung_protokoll.py --selbsttest        die Prüfer an künstlichen Zeilen testen

Ablage: godot/docs/erzeugungsprotokoll.jsonl, eine JSON-Zeile je Erzeugung, nur anhängen. Warum dort:
  • versioniert wie der Code: Prompt, Modell und Kosten bleiben am Stand der Assets nachvollziehbar;
  • docs/ steht im exclude_filter beider Export-Presets — Prompts und Kosten landen nie im Spiel;
  • getrennt von assets/: Der Herkunftstest (tests/test_herkunft.gd) inventarisiert dort nur Spieldateien;
  • eine Zeile je Eintrag, nur anhängen: Zusammenführen zweier Zweige gibt kaum Konflikte.

Ein Asset, dessen Eintrag in assets/HERKUNFT.json „ki": true trägt, braucht hier eine Zeile, deren
ausgabe.sha256 zur Datei passt (prüft tests/test_herkunft.gd). Wer eine KI-Datei nachbearbeitet
(zuschneiden, umwandeln), protokolliert das als eigene Zeile: dienst „lokal", modell = Werkzeug,
die KI-Datei als --eingabe, das Ergebnis als --ausgabe.

Pfade stehen relativ zu godot/ (sonst zur Arbeitskopie, sonst nur der Dateiname) — keine Benutzerordner.
Nicht ins Protokoll gehören Zugangsdaten, signierte Adressen, Schlüssel, Kontokennungen und
E-Mail-Adressen: Ein Eintrag mit so etwas wird abgelehnt (Muster: GEHEIM). Nur Standardbibliothek.
Schlusszeile bei --pruefen: „N Einträge, M fehlerhaft"; Rückgabe 0 oder 1.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import sys

for _strom in (sys.stdout, sys.stderr):
    try:
        _strom.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

HIER = os.path.dirname(os.path.abspath(__file__))     # godot/tools
GODOT = os.path.dirname(HIER)                         # godot
WURZEL = os.path.dirname(GODOT)                       # Arbeitskopie
PROTOKOLL = os.path.join(GODOT, "docs", "erzeugungsprotokoll.jsonl")

PFLICHT = ("nr", "zeit", "dienst", "modell", "prompt", "parameter", "eingaben", "ausgabe", "kosten", "auftrag",
           "bedingungen")
DATEI_FELDER = ("datei", "sha256", "bytes")
KOSTEN_FELDER = ("betrag", "einheit")
ZEIT = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:\d{2})?")
SHA256 = re.compile(r"[0-9a-f]{64}")

# Geheimnisse: signierte Adressen, Schlüssel und Token, Kontokennungen, E-Mail-Adressen. Ein Muster je Zeile
# als r"…" ohne Anführungszeichen darin — tests/test_herkunft.gd liest genau diese Liste mit und prüft damit
# das eingecheckte Protokoll.
GEHEIM = [
    r"X-Amz-(?:Signature|Credential|Security-Token)",
    r"X-Goog-(?:Signature|Credential)",
    r"(?i)[?&](?:sig|signature|token|access_token|policy|key-pair-id)=",
    r"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]{8,}",
    r"(?i)api[_-]?key",
    r"\bsk-[A-Za-z0-9_-]{16,}",
    r"\bAKIA[0-9A-Z]{16}\b",
    r"\bAIza[0-9A-Za-z_-]{30,}",
    r"\b(?:ghp|gho|ghs|ghu|github_pat)_[A-Za-z0-9_]{20,}",
    r"\bhf_[A-Za-z0-9]{20,}",
    r"\bxox[abprs]-[A-Za-z0-9-]{10,}",
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    r"\buser_[0-9A-Za-z]{12,}",
    r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}",
]
GEHEIM_RE = [re.compile(m) for m in GEHEIM]


# ------------------------------------------------------------------------------------------------ Dateien

def sha256_datei(pfad):
    h = hashlib.sha256()
    with open(pfad, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def anzeigepfad(pfad):
    """Relativ zu godot/, sonst zur Arbeitskopie, sonst nur der Dateiname (keine Benutzerordner)."""
    voll = os.path.abspath(pfad)
    for basis in (GODOT, WURZEL):
        try:
            rel = os.path.relpath(voll, basis)
        except ValueError:          # Windows: anderes Laufwerk
            continue
        if not rel.startswith(".."):
            return rel.replace("\\", "/")
    return os.path.basename(voll)


def datei_eintrag(pfad):
    return {"datei": anzeigepfad(pfad), "sha256": sha256_datei(pfad), "bytes": os.path.getsize(pfad)}


def lesen(pfad):
    """(Zeilennummer, Eintrag oder None, Fehlertext) je nicht leerer Zeile."""
    if not os.path.exists(pfad):
        return []
    out = []
    with open(pfad, encoding="utf-8") as f:
        for n, zeile in enumerate(f, 1):
            if not zeile.strip():
                continue
            try:
                out.append((n, json.loads(zeile), ""))
            except ValueError as ex:
                out.append((n, None, "kein gültiges JSON: %s" % ex))
    return out


# ------------------------------------------------------------------------------------------------ Prüfen

def geheimnisse(text):
    return [m.group(0) for r in GEHEIM_RE for m in [r.search(text)] if m]


def _zahl(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _datei_fehler(d, wo):
    if not isinstance(d, dict):
        return ["%s ist kein Objekt {datei, sha256, bytes}" % wo]
    out = ["%s: unbekanntes Feld %s" % (wo, k) for k in d if k not in DATEI_FELDER]
    out += ["%s: Feld fehlt: %s" % (wo, k) for k in DATEI_FELDER if k not in d]
    p = d.get("datei")
    if not isinstance(p, str) or not p.strip():
        out.append("%s: datei fehlt" % wo)
    elif p.startswith("/") or "\\" in p or re.match(r"[A-Za-z]:", p) or ".." in p.split("/"):
        out.append("%s: datei %r ist kein relativer Pfad (relativ zu godot/ oder nur der Name)" % (wo, p))
    if not SHA256.fullmatch(str(d.get("sha256", ""))):
        out.append("%s: sha256 ist keine 64-stellige Hex-Zahl" % wo)
    if not (isinstance(d.get("bytes"), int) and not isinstance(d.get("bytes"), bool) and d["bytes"] >= 0):
        out.append("%s: bytes ist keine Ganzzahl ≥ 0" % wo)
    return out


def fehler_im_eintrag(e):
    if not isinstance(e, dict):
        return ["kein Objekt"]
    out = ["Feld fehlt: %s" % k for k in PFLICHT if k not in e]
    out += ["unbekanntes Feld: %s" % k for k in e if k not in PFLICHT]
    if not (isinstance(e.get("nr"), int) and not isinstance(e.get("nr"), bool) and e["nr"] >= 1):
        out.append("nr ist keine Ganzzahl ≥ 1")
    if not (isinstance(e.get("zeit"), str) and ZEIT.fullmatch(e["zeit"])):
        out.append("zeit ist nicht JJJJ-MM-TTThh:mm (mit Zeitzone)")
    for k in ("dienst", "modell"):
        if not (isinstance(e.get(k), str) and e[k].strip()):
            out.append("%s fehlt" % k)
    for k in ("prompt", "auftrag", "bedingungen"):
        if k in e and not isinstance(e[k], str):
            out.append("%s ist kein Text" % k)
    par = e.get("parameter")
    if not isinstance(par, dict):
        out.append("parameter ist kein Objekt")
    else:
        for k, v in par.items():
            if not (isinstance(v, str) or _zahl(v) or isinstance(v, bool)):
                out.append("parameter %s: nur Text, Zahl oder Wahrheitswert" % k)
    if not isinstance(e.get("eingaben"), list):
        out.append("eingaben ist keine Liste")
    else:
        for i, d in enumerate(e["eingaben"]):
            out += _datei_fehler(d, "eingaben[%d]" % i)
    out += _datei_fehler(e.get("ausgabe"), "ausgabe")
    k = e.get("kosten")
    if not isinstance(k, dict) or set(k) != set(KOSTEN_FELDER):
        out.append("kosten braucht genau {betrag, einheit}")
    else:
        if not (_zahl(k["betrag"]) and k["betrag"] >= 0):
            out.append("kosten.betrag ist keine Zahl ≥ 0")
        if not (isinstance(k["einheit"], str) and k["einheit"].strip()):
            out.append("kosten.einheit fehlt (z. B. Credits, EUR)")
    for g in geheimnisse(json.dumps(e, ensure_ascii=False)):
        out.append("enthält etwas wie ein Geheimnis (Zugangsdaten, signierte Adresse, Kontokennung, "
                   "E-Mail-Adresse): %r" % (g[:12] + "…"))
    return out


def protokoll_fehler(zeilen):
    """Fehler je Zeile: [(zeilennummer, nr, [fehler])]; prüft auch doppelte und fallende Nummern."""
    out = []
    vorige = 0
    gesehen = set()
    for n, e, lesefehler in zeilen:
        fehler = [lesefehler] if lesefehler else fehler_im_eintrag(e)
        nr = e.get("nr") if isinstance(e, dict) else None
        if isinstance(nr, int) and not isinstance(nr, bool):
            if nr in gesehen:
                fehler.append("nr %d doppelt" % nr)
            elif nr < vorige:
                fehler.append("nr %d nach %d — nur anhängen, nichts einsortieren" % (nr, vorige))
            gesehen.add(nr)
            vorige = max(vorige, nr)
        if fehler:
            out.append((n, nr, fehler))
    return out


# ------------------------------------------------------------------------------------------------ Befehle

def _wert(text):
    if text in ("true", "false"):
        return text == "true"
    for typ in (int, float):
        try:
            return typ(text)
        except ValueError:
            pass
    return text


def befehl_neu(a):
    if bool(a.prompt is not None) == bool(a.prompt_datei):
        print("Genau eines von --prompt oder --prompt-datei angeben (Wortlaut der Eingabe).")
        return 1
    if a.prompt_datei:
        with open(a.prompt_datei, encoding="utf-8") as f:
            prompt = f.read().strip("\n")
    else:
        prompt = a.prompt
    parameter = {}
    for p in a.parameter or []:
        if "=" not in p:
            print("--parameter braucht name=wert: %r" % p)
            return 1
        k, v = p.split("=", 1)
        parameter[k.strip()] = _wert(v.strip())
    pfad = a.datei or PROTOKOLL
    vorhanden = [e for _, e, _ in lesen(pfad) if isinstance(e, dict)]
    eintrag = {
        "nr": max([e.get("nr", 0) for e in vorhanden if isinstance(e.get("nr"), int)] or [0]) + 1,
        "zeit": a.zeit or datetime.datetime.now().astimezone().isoformat(timespec="minutes"),
        "dienst": a.dienst,
        "modell": a.modell,
        "prompt": prompt,
        "parameter": parameter,
        "eingaben": [datei_eintrag(p) for p in (a.eingabe or [])],
        "ausgabe": datei_eintrag(a.ausgabe),
        "kosten": {"betrag": int(a.kosten) if a.kosten.is_integer() else a.kosten, "einheit": a.einheit},
        "auftrag": a.auftrag or "",
        "bedingungen": a.bedingungen or "",
    }
    fehler = fehler_im_eintrag(eintrag)
    if fehler:
        print("Eintrag abgelehnt: " + "; ".join(fehler))
        return 1
    os.makedirs(os.path.dirname(os.path.abspath(pfad)), exist_ok=True)
    with open(pfad, "a", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(eintrag, ensure_ascii=False, sort_keys=True) + "\n")
    print("Eintrag %d geschrieben: %s/%s, %s (sha256 %s…), %g %s" % (
        eintrag["nr"], a.dienst, a.modell, eintrag["ausgabe"]["datei"], eintrag["ausgabe"]["sha256"][:12],
        a.kosten, a.einheit))
    return 0


def befehl_pruefen(pfad):
    zeilen = lesen(pfad)
    if not os.path.exists(pfad):
        print("Kein Protokoll unter %s — noch keine KI-Erzeugung festgehalten." % anzeigepfad(pfad))
    schlecht = protokoll_fehler(zeilen)
    for n, nr, fehler in schlecht:
        print("  Zeile %d (nr %s): %s" % (n, nr, "; ".join(fehler)))
    print("%d Einträge, %d fehlerhaft" % (len(zeilen), len(schlecht)))
    return 1 if schlecht else 0


def befehl_liste(pfad):
    summe = {}
    for _, e, fehler in lesen(pfad):
        if fehler or not isinstance(e, dict):
            print("  (unlesbare Zeile)")
            continue
        k = e.get("kosten", {})
        summe[k.get("einheit", "?")] = summe.get(k.get("einheit", "?"), 0) + (k.get("betrag") or 0)
        print("%3s  %-22s %-12s %-26s %8s %-8s %s" % (e.get("nr"), e.get("zeit"), e.get("dienst"), e.get("modell"),
                                                     k.get("betrag"), k.get("einheit"),
                                                     e.get("ausgabe", {}).get("datei")))
    print("Summe: " + (", ".join("%g %s" % (v, k) for k, v in sorted(summe.items())) or "0"))
    return 0


def befehl_selbsttest():
    """Gegenprobe der Prüfer: ein gültiger Eintrag geht durch, jede Verletzung wird gemeldet."""
    def gut(**aend):
        e = {"nr": 1, "zeit": "2026-11-24T21:30+01:00", "dienst": "higgsfield", "modell": "beispiel-bild-2",
             "prompt": "Paul im Lauf, flache Vektorgrafik, warme Palette", "parameter": {"seed": 42, "hd": True},
             "eingaben": [{"datei": "assets/sprites/vorlage.png", "sha256": "a" * 64, "bytes": 10}],
             "ausgabe": {"datei": "assets/sprites/paul.png", "sha256": "b" * 64, "bytes": 2048},
             "kosten": {"betrag": 2, "einheit": "Credits"}, "auftrag": "job-1234", "bedingungen": ""}
        e.update(aend)
        return e

    def pruefe(e, teil):
        f = fehler_im_eintrag(e)
        return (not f) if teil is None else any(teil in x for x in f)

    faelle = [
        ("gültiger Eintrag", gut(), None),
        ("signierte S3-Adresse", gut(prompt="https://b.s3.amazonaws.com/x.png?X-Amz-Signature=abc"), "Geheimnis"),
        ("SAS-Signatur", gut(auftrag="https://x.blob.core.windows.net/a?sv=1&sig=abcdef"), "Geheimnis"),
        ("Bearer-Token", gut(parameter={"kopf": "Bearer abcdefghijklmnop"}), "Geheimnis"),
        ("API-Schlüssel", gut(prompt="nimm sk-abcdefghijklmnopqrstu"), "Geheimnis"),
        ("AWS-Schlüssel", gut(bedingungen="AKIAABCDEFGHIJKLMNOP"), "Geheimnis"),
        ("GitHub-Token", gut(auftrag="ghp_abcdefghijklmnopqrstuvwxyz0123"), "Geheimnis"),
        ("privater Schlüssel", gut(prompt="-----BEGIN RSA PRIVATE KEY-----"), "Geheimnis"),
        ("Kontokennung", gut(auftrag="user_ABCDEFGHIJKLMNOP"), "Geheimnis"),
        ("E-Mail-Adresse", gut(bedingungen="Rückfragen an max.muster@example.org"), "Geheimnis"),
        ("Feld fehlt", {k: v for k, v in gut().items() if k != "modell"}, "Feld fehlt: modell"),
        ("unbekanntes Feld", gut(notiz="x"), "unbekanntes Feld: notiz"),
        ("sha256 kaputt", gut(ausgabe={"datei": "a.png", "sha256": "xyz", "bytes": 1}), "sha256"),
        ("absoluter Pfad", gut(ausgabe={"datei": "C:/Users/x/a.png", "sha256": "b" * 64, "bytes": 1}),
         "kein relativer Pfad"),
        ("Benutzerordner", gut(eingaben=[{"datei": "/home/x/a.png", "sha256": "a" * 64, "bytes": 1}]),
         "kein relativer Pfad"),
        ("negative Kosten", gut(kosten={"betrag": -1, "einheit": "Credits"}), "kosten.betrag"),
        ("Kosten ohne Einheit", gut(kosten={"betrag": 1}), "kosten braucht"),
        ("nr als Wahrheitswert", gut(nr=True), "nr ist"),
        ("Zeit ohne Uhrzeit", gut(zeit="24.11.2026"), "zeit"),
        ("Parameter verschachtelt", gut(parameter={"a": {"b": 1}}), "parameter a"),
    ]
    fehlgeschlagen = 0
    for name, e, teil in faelle:
        if not pruefe(e, teil):
            fehlgeschlagen += 1
            print("  ✗ %s: erwartet %s, gemeldet %s" % (name, teil or "kein Fehler", fehler_im_eintrag(e)))
    zeilen = [(1, gut(), ""), (2, gut(), ""), (3, gut(nr=0), ""), (4, None, "kein gültiges JSON: x")]
    doppelt = protokoll_fehler(zeilen)
    if [n for n, _, _ in doppelt] != [2, 3, 4] or "doppelt" not in doppelt[0][2][0]:
        fehlgeschlagen += 1
        print("  ✗ Zeilenprüfung (doppelte nr, nr 0, kaputtes JSON): %s" % doppelt)
    print("Selbsttest: %d Prüfungen, %d fehlgeschlagen" % (len(faelle) + 1, fehlgeschlagen))
    return 1 if fehlgeschlagen else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="Protokoll der Erzeugungen mit KI-Diensten (godot/docs/"
                                             "erzeugungsprotokoll.jsonl)")
    was = ap.add_mutually_exclusive_group(required=True)
    was.add_argument("--neu", action="store_true", help="einen Eintrag anhängen")
    was.add_argument("--pruefen", nargs="?", const=PROTOKOLL, metavar="DATEI", help="Protokoll prüfen")
    was.add_argument("--liste", nargs="?", const=PROTOKOLL, metavar="DATEI", help="Übersicht")
    was.add_argument("--selbsttest", action="store_true", help="die Prüfer testen")
    ap.add_argument("--datei", help="anderes Protokoll für --neu (Vorgabe: godot/docs/erzeugungsprotokoll.jsonl)")
    ap.add_argument("--dienst", help="z. B. higgsfield, lokal")
    ap.add_argument("--modell", help="Modell bzw. Werkzeug")
    ap.add_argument("--prompt", help="Wortlaut der Eingabe")
    ap.add_argument("--prompt-datei", help="Datei mit dem Wortlaut (UTF-8)")
    ap.add_argument("--parameter", action="append", metavar="NAME=WERT", help="Einstellung (wiederholbar)")
    ap.add_argument("--eingabe", action="append", metavar="DATEI", help="Eingabedatei (wiederholbar)")
    ap.add_argument("--ausgabe", metavar="DATEI", help="erzeugte Datei")
    ap.add_argument("--kosten", type=float, help="Kosten (0 für lokal)")
    ap.add_argument("--einheit", default="Credits", help="Einheit der Kosten (Vorgabe: Credits)")
    ap.add_argument("--auftrag", help="Auftragskennung des Dienstes")
    ap.add_argument("--bedingungen", help="Fassung der Nutzungsbedingungen, z. B. 'Higgsfield, Stand 23.10.2026'")
    ap.add_argument("--zeit", help="Zeitpunkt, falls nicht jetzt (JJJJ-MM-TTThh:mm+hh:mm)")
    a = ap.parse_args(argv)
    if a.selbsttest:
        return befehl_selbsttest()
    if a.pruefen:
        return befehl_pruefen(a.pruefen)
    if a.liste:
        return befehl_liste(a.liste)
    fehlt = [n for n in ("dienst", "modell", "ausgabe", "kosten") if getattr(a, n) is None]
    if fehlt:
        ap.error("--neu braucht " + ", ".join("--" + n for n in fehlt))
    return befehl_neu(a)


if __name__ == "__main__":
    sys.exit(main())
