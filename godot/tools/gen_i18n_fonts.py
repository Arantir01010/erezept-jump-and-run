"""
Erzeugt die Schrift-Untermengen für Chinesisch und Hindi aus Noto Sans (SIL OFL 1.1):
nur die Zeichen, die in godot/i18n/*.json tatsächlich vorkommen, plus Ziffern und
Satzzeichen. Ergebnis: godot/assets/i18n/NotoSansSC-subset.otf (~200-400 KB statt 16 MB)
und NotoSansDevanagari-subset.ttf; Brand.gd hängt sie als Fallback an alle Schriften.

    python godot/tools/gen_i18n_fonts.py

Quellen (einmalig nach .tools/downloads/fonts/ laden, werden nicht mitversioniert):
  NotoSansCJKsc-Regular.otf   https://github.com/notofonts/noto-cjk (Sans/OTF/SimplifiedChinese)
  NotoSansDevanagari[wdth,wght].ttf   https://github.com/google/fonts (ofl/notosansdevanagari)
Braucht: pip install fonttools
Nach jeder Änderung an den Übersetzungen neu laufen lassen — fehlende Zeichen zeigt Godot
als leere Kästchen.
"""
from __future__ import annotations

import json
import string
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / ".tools" / "downloads" / "fonts"
I18N = ROOT / "godot" / "i18n"
OUT = ROOT / "godot" / "assets" / "i18n"

COMMON = string.digits + string.ascii_letters + string.punctuation + " " + "€–—…·•‑‐‘’‚“”„«»°×÷≤≥→←↑↓✓✗◀▶◉★☆"
ZH_PUNCT = "，。！？：；、（）《》〈〉「」『』【】—…·～"
HI_PUNCT = "।॥‌‍"   # Danda, doppelter Danda, ZWNJ/ZWJ (Ligaturen)

FONTS = {
    "zh": {"src": "NotoSansCJKsc-Regular.otf", "out": "NotoSansSC-subset.otf", "extra": ZH_PUNCT, "instance": None},
    "hi": {"src": "NotoSansDevanagari[wdth,wght].ttf", "out": "NotoSansDevanagari-subset.ttf", "extra": HI_PUNCT,
           "instance": {"wght": 500, "wdth": 100}},
}


def chars_for(lang: str) -> set[str]:
    chars: set[str] = set(COMMON)
    for f in sorted(I18N.glob("*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        for key, row in data.items():
            if key.startswith("_") or not isinstance(row, dict):
                continue
            chars.update(str(row.get(lang, "")))
    return chars


def build(lang: str) -> None:
    spec = FONTS[lang]
    src = SRC / spec["src"]
    if not src.exists():
        raise SystemExit(f"Quelle fehlt: {src} (siehe Docstring)")
    chars = chars_for(lang) | set(spec["extra"])
    text = "".join(sorted(chars))
    options = subset.Options()
    options.layout_features = ["*"]          # Indic-Shaping (GSUB/GPOS) vollständig behalten
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    options.hinting = False
    options.glyph_names = False
    options.drop_tables += ["vhea", "vmtx"]
    font = TTFont(str(src))
    if spec["instance"] and "fvar" in font:
        font = instancer.instantiateVariableFont(font, spec["instance"])
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / spec["out"]
    font.save(str(out))
    print(f"{lang}: {len(chars)} Zeichen → {out.name} ({out.stat().st_size // 1024} KB)")


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    for lang in FONTS:
        build(lang)
    lic = OUT / "OFL.txt"
    parts = []
    for name in ["OFL-NotoSansCJK.txt", "OFL-NotoSansDevanagari.txt"]:
        p = SRC / name
        if p.exists():
            parts.append(f"===== {name} =====\n" + p.read_text(encoding="utf-8", errors="replace"))
    if parts:
        lic.write_text("Noto Sans CJK SC und Noto Sans Devanagari — SIL Open Font License 1.1\n"
                       "Untermengen erzeugt mit godot/tools/gen_i18n_fonts.py\n\n" + "\n\n".join(parts),
                       encoding="utf-8", newline="\n")
        print("Lizenz:", lic.name)


if __name__ == "__main__":
    main()
