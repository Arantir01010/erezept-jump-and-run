"""
Auswertung der anonymen Messe-Statistik (src/core/Statistik.gd).

    python godot/tools/statistik_auswerten.py [ORDNER] [--csv datei.csv]

ORDNER enthält die Dateien ereignisse-JJJJ-MM-TT.jsonl (mehrere Tage werden
zusammengefasst). Ohne Angabe: der Standardordner der Windows-Fassung
%APPDATA%/Godot/app_userdata/Paul & REZI/statistik.

Ausgabe je Station: erreicht, geschafft, Abschlussquote, Median-Zeit, Treffer und
Stürze je Versuch, Neustarts, Abbrüche (davon Idle) — und je Durchlauf: Anzahl,
bis zum Ende, Median-Gesamtzeit, Sprachen, Bedienung. Daraus lassen sich
Abbruchstellen, die 4–6-Minuten-Frage und das 80-%-Kriterium des Playtests ablesen.
Nur Standardbibliothek.
"""

from __future__ import annotations

import csv
import json
import os
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path


def standard_ordner() -> Path:
    appdata = os.environ.get("APPDATA")
    if appdata:
        return Path(appdata) / "Godot" / "app_userdata" / "Paul & REZI" / "statistik"
    return Path.home() / ".local" / "share" / "godot" / "app_userdata" / "Paul & REZI" / "statistik"


def lese(ordner: Path) -> list[dict]:
    ereignisse = []
    for datei in sorted(ordner.glob("ereignisse-*.jsonl")):
        for zeile in datei.read_text(encoding="utf-8").splitlines():
            zeile = zeile.strip()
            if not zeile:
                continue
            try:
                e = json.loads(zeile)
            except json.JSONDecodeError:
                continue          # halbe Zeile nach Stromausfall
            if isinstance(e, dict):
                ereignisse.append(e)
    return ereignisse


def mmss(s: float | None) -> str:
    if s is None:
        return "–"
    return f"{int(s) // 60}:{int(s) % 60:02d}"


def auswerten(ereignisse: list[dict]) -> tuple[dict, dict]:
    st: dict[str, dict] = defaultdict(lambda: {"erreicht": 0, "geschafft": 0, "zeiten": [], "treffer": 0,
                                               "stuerze": 0, "versuche": 0, "neustarts": 0, "abbrueche": 0, "idle": 0})
    laeufe = {"gestartet": 0, "fertig": 0, "gesamtzeiten": [], "sprachen": Counter(), "bedienung": Counter(),
              "enden": Counter(), "quiz": 0, "quiz_richtig": 0, "quiz_fragen": 0}
    reihenfolge: list[str] = []
    for e in ereignisse:
        art = e.get("art")
        sid = str(e.get("station", ""))
        if sid and sid not in reihenfolge:
            reihenfolge.append(sid)
        if art == "lauf_start":
            laeufe["gestartet"] += 1
            laeufe["sprachen"][e.get("sprache", "?")] += 1
            laeufe["bedienung"][e.get("bedienung", "?")] += 1
        elif art == "station_start":
            st[sid]["erreicht"] += 1
        elif art in ("station_ende", "neustart") or (art == "lauf_ende" and sid):
            s = st[sid]
            s["versuche"] += 1
            s["treffer"] += int(e.get("treffer", 0))
            s["stuerze"] += int(e.get("stuerze", 0))
            if art == "station_ende":
                s["geschafft"] += 1
                s["zeiten"].append(float(e.get("sekunden", 0)))
            elif art == "neustart":
                s["neustarts"] += 1
            elif e.get("grund") != "geschafft":
                s["abbrueche"] += 1
                if e.get("grund") == "idle":
                    s["idle"] += 1
        if art == "wissen":
            laeufe["quiz"] += 1
            laeufe["quiz_richtig"] += int(e.get("richtig", 0))
            laeufe["quiz_fragen"] += int(e.get("fragen", 0))
        if art == "lauf_ende":
            laeufe["enden"][e.get("grund", "?")] += 1
            if e.get("grund") == "geschafft":
                laeufe["fertig"] += 1
                laeufe["gesamtzeiten"].append(float(e.get("sekunden", 0)))
    sortiert = {k: st[k] for k in sorted(reihenfolge)}
    return sortiert, laeufe


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = [a for a in sys.argv[1:]]
    csv_ziel = None
    if "--csv" in args:
        i = args.index("--csv")
        csv_ziel = Path(args[i + 1])
        del args[i:i + 2]
    ordner = Path(args[0]) if args else standard_ordner()
    ereignisse = lese(ordner)
    if not ereignisse:
        print(f"Keine Ereignisse in {ordner}")
        raise SystemExit(1)
    stationen, laeufe = auswerten(ereignisse)
    g = laeufe["gestartet"]
    print(f"Durchläufe: {g} gestartet · {laeufe['fertig']} bis zum Ende"
          f" ({100 * laeufe['fertig'] / g if g else 0:.0f} %) · Median-Gesamtzeit "
          f"{mmss(statistics.median(laeufe['gesamtzeiten']) if laeufe['gesamtzeiten'] else None)}")
    print("Enden:     " + ", ".join(f"{k} {v}" for k, v in laeufe["enden"].most_common()))
    print("Sprachen:  " + ", ".join(f"{k} {v}" for k, v in laeufe["sprachen"].most_common()))
    if laeufe["quiz_fragen"]:
        print(f"Quiz:      {laeufe['quiz']}× beantwortet, "
              f"{100 * laeufe['quiz_richtig'] / laeufe['quiz_fragen']:.0f} % der Antworten richtig")
    print("Bedienung: " + ", ".join(f"{k} {v}" for k, v in laeufe["bedienung"].most_common()))
    print()
    kopf = ["Station", "erreicht", "geschafft", "Quote", "Median", "Treffer/V", "Stürze/V", "Neustarts", "Abbrüche (Idle)"]
    zeilen = []
    for sid, s in stationen.items():
        v = max(1, s["versuche"])
        zeilen.append([sid, s["erreicht"], s["geschafft"],
                       f"{100 * s['geschafft'] / s['erreicht']:.0f} %" if s["erreicht"] else "–",
                       mmss(statistics.median(s["zeiten"]) if s["zeiten"] else None),
                       f"{s['treffer'] / v:.1f}", f"{s['stuerze'] / v:.1f}", s["neustarts"],
                       f"{s['abbrueche']} ({s['idle']})"])
    breiten = [max(len(str(z[i])) for z in [kopf] + zeilen) for i in range(len(kopf))]
    for z in [kopf] + zeilen:
        print("  ".join(str(w).ljust(breiten[i]) for i, w in enumerate(z)))
    if csv_ziel:
        with csv_ziel.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f, delimiter=";")
            w.writerow(kopf)
            w.writerows(zeilen)
        print(f"\nCSV: {csv_ziel}")


if __name__ == "__main__":
    main()
