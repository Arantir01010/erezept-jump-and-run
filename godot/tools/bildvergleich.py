#!/usr/bin/env python3
"""BILDVERGLEICH — Vorher/Nachher messen statt raten.

Vergleicht zwei Bilder oder zwei Ordner (Paare = gleiche Dateinamen) und gibt je
Paar eine Tabellenzeile aus, dazu eine Schlusszeile über alle Paare:

  ØΔ R/G/B      mittlere absolute Abweichung je Kanal (0–255)
  geändert      Anteil der Pixel, deren größte Kanalabweichung > --schwelle ist
  überstrahlt   Anteil der Pixel mit allen Kanälen ≥ 250, je Bild (A → B)
  Helligkeit    mittlere Luma (0,299 R + 0,587 G + 0,114 B, 0–255), je Bild
  Sättigung     mittlere HSV-Sättigung in %, je Bild
  Wärme         mittleres R − B (0–255; positiv = warm), je Bild

Je Paar entstehen im Ausgabeordner <name>-diff.png (|A − B| × 10) und
<name>-nebeneinander.png (A | B mit Beschriftung).

  python godot/tools/bildvergleich.py vorher.png nachher.png --aus /tmp/vergleich
  python godot/tools/bildvergleich.py bilder-a/ bilder-b/ --aus /tmp/vergleich --md
  … --schwelle 8 --namen "Glühen A" "Glühen B" --verkleinern 0.5 --json werte.json

Rauschen: Papierkorn und Partikel unterscheiden auch zwei Bilder derselben
Einstellung. Für eine ehrliche Aussage zuerst A gegen A' (zweiter Lauf) messen —
das ist der Rauschboden — und erst den Unterschied darüber deuten.
Exit-Code 0 = verglichen, 2 = Bedienfehler oder fehlende Bibliotheken.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import numpy as np
    from PIL import Image, ImageDraw, ImageFont
except ImportError as fehlt:  # pragma: no cover - abhängig von der Umgebung
    sys.stderr.write(
        "bildvergleich: braucht Pillow und numpy (pip install pillow numpy) — "
        f"es fehlt: {fehlt.name}\n"
    )
    sys.exit(2)

ENDUNGEN = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}


def zahl(x: float, nachkomma: int = 2) -> str:
    """Deutsche Schreibweise: Komma als Dezimaltrenner."""
    return f"{x:.{nachkomma}f}".replace(".", ",")


def laden(pfad: Path) -> np.ndarray:
    with Image.open(pfad) as bild:
        return np.asarray(bild.convert("RGB"), dtype=np.float32)


def kennzahlen(rgb: np.ndarray) -> dict:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hoch = rgb.max(axis=2)
    tief = rgb.min(axis=2)
    saettigung = np.where(hoch > 0.0, (hoch - tief) / np.maximum(hoch, 1e-6), 0.0)
    return {
        "helligkeit": float((0.299 * r + 0.587 * g + 0.114 * b).mean()),
        "saettigung": float(saettigung.mean() * 100.0),
        "waerme": float((r - b).mean()),
        "ueberstrahlt": float((tief >= 250.0).mean() * 100.0),
    }


# Schriften mit Umlauten (Linux, Windows, macOS); Pillows eingebaute Schrift kennt kein „ü“
SCHRIFTEN = ["DejaVuSans.ttf", "LiberationSans-Regular.ttf", "arial.ttf", "Arial.ttf", "segoeui.ttf",
             "Helvetica.ttc"]


def schrift(groesse: int):
    for name in SCHRIFTEN:
        try:
            return ImageFont.truetype(name, groesse)
        except OSError:
            continue
    try:
        return ImageFont.load_default(size=groesse)
    except TypeError:  # Pillow < 10.1
        return ImageFont.load_default()


def nebeneinander(a: np.ndarray, b: np.ndarray, name_a: str, name_b: str, faktor: float) -> Image.Image:
    bild_a = Image.fromarray(a.astype(np.uint8))
    bild_b = Image.fromarray(b.astype(np.uint8))
    if faktor != 1.0:
        groesse = (max(1, round(bild_a.width * faktor)), max(1, round(bild_a.height * faktor)))
        bild_a = bild_a.resize(groesse, Image.LANCZOS)
        bild_b = bild_b.resize(groesse, Image.LANCZOS)
    kopf = max(28, bild_a.height // 24)
    luecke = 8
    gesamt = Image.new("RGB", (bild_a.width * 2 + luecke, bild_a.height + kopf), (24, 24, 24))
    gesamt.paste(bild_a, (0, kopf))
    gesamt.paste(bild_b, (bild_a.width + luecke, kopf))
    stift = ImageDraw.Draw(gesamt)
    font = schrift(int(kopf * 0.62))
    stift.text((12, kopf * 0.18), name_a, fill=(235, 235, 235), font=font)
    stift.text((bild_a.width + luecke + 12, kopf * 0.18), name_b, fill=(235, 235, 235), font=font)
    return gesamt


def paare(a: Path, b: Path) -> tuple[list[tuple[str, Path, Path]], list[str]]:
    if a.is_file() and b.is_file():
        return [(a.stem, a, b)], []
    if a.is_dir() and b.is_dir():
        namen_a = {p.name for p in a.iterdir() if p.suffix.lower() in ENDUNGEN}
        namen_b = {p.name for p in b.iterdir() if p.suffix.lower() in ENDUNGEN}
        gemeinsam = sorted(namen_a & namen_b)
        einzeln = sorted(namen_a ^ namen_b)
        return [(Path(n).stem, a / n, b / n) for n in gemeinsam], einzeln
    raise SystemExit(f"bildvergleich: {a} und {b} müssen beide Bilder oder beide Ordner sein")


def vergleichen(name: str, pfad_a: Path, pfad_b: Path, args, aus: Path | None) -> dict | None:
    a = laden(pfad_a)
    b = laden(pfad_b)
    if a.shape != b.shape:
        print(f"  {name}: Größen verschieden ({a.shape[1]}×{a.shape[0]} gegen {b.shape[1]}×{b.shape[0]}) — übersprungen")
        return None
    d = np.abs(a - b)
    je_kanal = d.reshape(-1, 3).mean(axis=0)
    zeile = {
        "name": name,
        "abweichung_rgb": [float(x) for x in je_kanal],
        "abweichung": float(je_kanal.mean()),
        "max_abweichung": float(d.max()),
        "geaendert": float((d.max(axis=2) > args.schwelle).mean() * 100.0),
        "a": kennzahlen(a),
        "b": kennzahlen(b),
    }
    if aus is not None:
        Image.fromarray(np.clip(d * 10.0, 0.0, 255.0).astype(np.uint8)).save(aus / f"{name}-diff.png")
        nebeneinander(a, b, args.namen[0], args.namen[1], args.verkleinern).save(aus / f"{name}-nebeneinander.png")
    return zeile


SPALTEN = ["Bild", "ØΔ R", "ØΔ G", "ØΔ B", "geändert %", "überstrahlt % A→B",
           "Helligkeit A→B", "Sättigung % A→B", "Wärme A→B"]


def zellen(z: dict) -> list[str]:
    a, b = z["a"], z["b"]
    return [
        z["name"],
        *(zahl(x) for x in z["abweichung_rgb"]),
        zahl(z["geaendert"]),
        f"{zahl(a['ueberstrahlt'])} → {zahl(b['ueberstrahlt'])}",
        f"{zahl(a['helligkeit'], 1)} → {zahl(b['helligkeit'], 1)}",
        f"{zahl(a['saettigung'], 1)} → {zahl(b['saettigung'], 1)}",
        f"{zahl(a['waerme'], 1)} → {zahl(b['waerme'], 1)}",
    ]


def tabelle(zeilen: list[dict], markdown: bool) -> str:
    werte = [zellen(z) for z in zeilen]
    if markdown:
        kopf = "| " + " | ".join(SPALTEN) + " |"
        trenner = "|" + "|".join("---" if i == 0 else "---:" for i in range(len(SPALTEN))) + "|"
        return "\n".join([kopf, trenner] + ["| " + " | ".join(w) + " |" for w in werte])
    breiten = [max(len(SPALTEN[i]), *(len(w[i]) for w in werte)) for i in range(len(SPALTEN))]
    def fmt(w: list[str]) -> str:
        return "  ".join(w[i].ljust(breiten[i]) if i == 0 else w[i].rjust(breiten[i]) for i in range(len(w)))
    return "\n".join([fmt(SPALTEN), "  ".join("-" * x for x in breiten)] + [fmt(w) for w in werte])


def schlusszeile(zeilen: list[dict], schwelle: float) -> str:
    n = len(zeilen)
    def mittel(f) -> float:
        return sum(f(z) for z in zeilen) / n
    return (
        f"{n} Paar{'e' if n != 1 else ''} · mittlere Abweichung {zahl(mittel(lambda z: z['abweichung']))} "
        f"· geändert {zahl(mittel(lambda z: z['geaendert']), 1)} % (Schwelle {zahl(schwelle, 0)}) "
        f"· überstrahlt {zahl(mittel(lambda z: z['a']['ueberstrahlt']))} → {zahl(mittel(lambda z: z['b']['ueberstrahlt']))} % "
        f"· Helligkeit {zahl(mittel(lambda z: z['a']['helligkeit']), 1)} → {zahl(mittel(lambda z: z['b']['helligkeit']), 1)} "
        f"· Sättigung {zahl(mittel(lambda z: z['a']['saettigung']), 1)} → {zahl(mittel(lambda z: z['b']['saettigung']), 1)} % "
        f"· Wärme {zahl(mittel(lambda z: z['a']['waerme']), 1)} → {zahl(mittel(lambda z: z['b']['waerme']), 1)}"
    )


def main() -> int:
    p = argparse.ArgumentParser(description="Zwei Bilder oder zwei Ordner gleicher Dateinamen vergleichen.")
    p.add_argument("a", type=Path, help="Bild oder Ordner A (vorher)")
    p.add_argument("b", type=Path, help="Bild oder Ordner B (nachher)")
    p.add_argument("--aus", type=Path, help="Ordner für Differenz- und Nebeneinander-Bilder")
    p.add_argument("--schwelle", type=float, default=8.0,
                   help="ab welcher Kanalabweichung (0–255) ein Pixel als geändert zählt (Vorgabe 8)")
    p.add_argument("--namen", nargs=2, default=None, metavar=("A", "B"),
                   help="Beschriftung im Nebeneinander-Bild (Vorgabe: Datei-/Ordnernamen)")
    p.add_argument("--verkleinern", type=float, default=1.0,
                   help="Maßstab des Nebeneinander-Bilds (z. B. 0.5); Messung immer in voller Größe")
    p.add_argument("--md", action="store_true", help="Tabelle als Markdown ausgeben")
    p.add_argument("--json", type=Path, help="alle Werte zusätzlich als JSON-Datei schreiben")
    args = p.parse_args()

    if not args.a.exists() or not args.b.exists():
        sys.stderr.write(f"bildvergleich: {args.a if not args.a.exists() else args.b} gibt es nicht\n")
        return 2
    if args.namen is None:
        args.namen = [args.a.name or str(args.a), args.b.name or str(args.b)]
    if not 0.0 < args.verkleinern <= 1.0:
        sys.stderr.write("bildvergleich: --verkleinern muss zwischen 0 und 1 liegen\n")
        return 2
    if args.aus is not None:
        args.aus.mkdir(parents=True, exist_ok=True)

    liste, einzeln = paare(args.a, args.b)
    for n in einzeln:
        print(f"  nur in einem Ordner: {n}")
    zeilen = [z for z in (vergleichen(n, pa, pb, args, args.aus) for n, pa, pb in liste) if z is not None]
    if not zeilen:
        sys.stderr.write("bildvergleich: keine vergleichbaren Paare\n")
        return 2
    print(tabelle(zeilen, args.md))
    if args.json is not None:
        args.json.write_text(json.dumps({"schwelle": args.schwelle, "paare": zeilen}, indent=2, ensure_ascii=False), encoding="utf-8")
    print(schlusszeile(zeilen, args.schwelle))
    return 0


if __name__ == "__main__":
    sys.exit(main())
