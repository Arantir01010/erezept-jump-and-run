#!/usr/bin/env python3
"""
Aufräumen und Archivieren (einmalig ausgeführt am 03.09.2026, bleibt als Protokoll).

Was passiert:
  1. archive/  am Repo-Stamm anlegen (mit eigener .gitignore, nichts davon geht ins Git).
  2. _to_delete/ + levels-update.bundle  →  archive/2026-08_phaser-altdateien.zip
  3. Veraltete Screenshot-Sätze aus godot/shots/  →  archive/2026-09_godot-prueflauf-alt.zip
     (behalten werden die Sätze, aus denen der Bericht seine Bilder zieht, und die letzten Läufe)
  4. Brand-Quellpaket (entpackte Monotype-/PwC-Pakete)  →  archive/brand-quelle_July2024.zip
     Daraus ins Projekt übernommen:
       godot/assets/fonts/        die genutzten TTF-Schnitte (Helvetica Neue LT Pro, ITC Charter)
       godot/assets/brand/pictograms/   PwC-Werte-Piktogramme (weiß + schwarz)
       godot/brand/lizenz/        EULAs, Trademark-Hinweise, Font-Listen, Metadaten
  5. Der entpackte Ordner godot/brand/ITCCharter_Webfonts_July2024 (2)/ wird danach entfernt.

Alles ist umkehrbar: Die Zips enthalten die Originale vollständig.
"""
import os
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
ARCHIV = ROOT / "archive"
BRAND_SRC = GODOT / "brand" / "ITCCharter_Webfonts_July2024 (2)"

KEEP_SHOTS = {
    "menu-01", "menu-13", "paket", "touch-01",
    "w-01-stammdaten", "w-02-kartenterminal", "w-03-kov-gateway", "w-14-die-vau", "w-19-berechtigungen",
    "n-02-kartenterminal", "n-03-kov-gateway", "n-04-die-huelle", "n-13-e-rezept", "n-14-die-vau", "n-20-souveraenitaet",
}

FONTS = {
    "HelveticaNeue_Desktop_July2024 (1)/HelveticaNeue_Desktop_July2024/Neue Helvetica/OpenType TTF Pro": [
        "HelveticaNeueLTPro-Lt.ttf", "HelveticaNeueLTPro-Roman.ttf", "HelveticaNeueLTPro-It.ttf",
        "HelveticaNeueLTPro-Md.ttf", "HelveticaNeueLTPro-Bd.ttf", "HelveticaNeueLTPro-Hv.ttf",
    ],
    "ITCCharter_Desktop_July2024 (1)/ITCCharter_Desktop_July2024/ITC Fonts/Fonts/ITC Charter/OpenType TTF Com": [
        "ITCCharterCom-Regular.ttf", "ITCCharterCom-Italic.ttf", "ITCCharterCom-Bold.ttf", "ITCCharterCom-BoldItalic.ttf",
    ],
}
LIZENZ = {
    "HelveticaNeue_Desktop_July2024 (1)/HelveticaNeue_Desktop_July2024/Neue Helvetica/Documents/License/Font Software EULA.pdf": "HelveticaNeue_Font-Software-EULA.pdf",
    "HelveticaNeue_Desktop_July2024 (1)/HelveticaNeue_Desktop_July2024/Neue Helvetica/Documents/Trademarks/Trademark.pdf": "HelveticaNeue_Trademark.pdf",
    "HelveticaNeue_Desktop_July2024 (1)/HelveticaNeue_Desktop_July2024/Neue Helvetica/Documents/Font related/Font List.pdf": "HelveticaNeue_Font-List.pdf",
    "HelveticaNeue_Desktop_July2024 (1)/HelveticaNeue_Desktop_July2024/Metadata/font_metadata.txt": "HelveticaNeue_font_metadata.txt",
    "ITCCharter_Desktop_July2024 (1)/ITCCharter_Desktop_July2024/ITC Fonts/Documents/License/Font Software EULA.pdf": "ITCCharter_Font-Software-EULA.pdf",
    "ITCCharter_Desktop_July2024 (1)/ITCCharter_Desktop_July2024/ITC Fonts/Documents/Trademarks/Trademark.pdf": "ITCCharter_Trademark.pdf",
    "ITCCharter_Desktop_July2024 (1)/ITCCharter_Desktop_July2024/ITC Fonts/Documents/Font related/ITC Charter Family VP Font List.pdf": "ITCCharter_Font-List.pdf",
}
PIKTO = "PwC_values_pictograms_rgb_png (2)/PwC_values_pictograms_rgb_png"


def zip_tree(zip_path: Path, items: list[Path], base: Path) -> int:
    n = 0
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for item in items:
            if item.is_file():
                z.write(item, item.relative_to(base).as_posix())
                n += 1
            else:
                for f in sorted(item.rglob("*")):
                    if f.is_file():
                        z.write(f, f.relative_to(base).as_posix())
                        n += 1
    return n


def main() -> None:
    ARCHIV.mkdir(exist_ok=True)
    (ARCHIV / ".gitignore").write_text("# Archiv: nichts davon gehört ins Repository\n*\n!.gitignore\n!README.md\n", encoding="utf-8")

    # 2) Phaser-Altdateien
    alt = [p for p in [ROOT / "_to_delete", ROOT / "levels-update.bundle"] if p.exists()]
    if alt:
        zp = ARCHIV / "2026-08_phaser-altdateien.zip"
        n = zip_tree(zp, alt, ROOT)
        print(f"{zp.name}: {n} Dateien")
        for p in alt:
            shutil.rmtree(p) if p.is_dir() else p.unlink()

    # 3) Veraltete Screenshot-Sätze
    shots = GODOT / "shots"
    old = [d for d in sorted(shots.iterdir()) if d.is_dir() and d.name not in KEEP_SHOTS]
    if old:
        zp = ARCHIV / "2026-09_godot-prueflauf-alt.zip"
        n = zip_tree(zp, old, shots)
        print(f"{zp.name}: {n} Dateien aus {len(old)} Sätzen")
        for d in old:
            shutil.rmtree(d)

    # 4) Brand-Quellpaket sichern, Nutzdateien übernehmen
    if BRAND_SRC.exists():
        zp = ARCHIV / "brand-quelle_ITCCharter-HelveticaNeue-PwC-Piktogramme_July2024.zip"
        n = zip_tree(zp, [BRAND_SRC], BRAND_SRC.parent)
        print(f"{zp.name}: {n} Dateien")
        fonts_dir = GODOT / "assets" / "fonts"
        fonts_dir.mkdir(parents=True, exist_ok=True)
        for sub, names in FONTS.items():
            for name in names:
                src = BRAND_SRC / sub / name
                if not src.exists():
                    sys.exit(f"fehlt: {src}")
                shutil.copy2(src, fonts_dir / name)
        print(f"Fonts: {sum(len(v) for v in FONTS.values())} Schnitte → {fonts_dir.relative_to(ROOT)}")
        liz = GODOT / "brand" / "lizenz"
        liz.mkdir(parents=True, exist_ok=True)
        for rel, dst in LIZENZ.items():
            src = BRAND_SRC / rel
            if not src.exists():
                sys.exit(f"fehlt: {src}")
            shutil.copy2(src, liz / dst)
        print(f"Lizenz-Dokumente: {len(LIZENZ)} → {liz.relative_to(ROOT)}")
        pk = GODOT / "assets" / "brand" / "pictograms"
        pk.mkdir(parents=True, exist_ok=True)
        cnt = 0
        for variant in ("PwC_values_pict_white_rgb_png", "PwC_values_pict_black_rgb_png"):
            for f in sorted((BRAND_SRC / PIKTO / variant).glob("*.png")):
                # PwC_values_pict_care_rgb_white.png → care_white.png
                stem = f.stem.replace("PwC_values_pict_", "").replace("_rgb", "")
                shutil.copy2(f, pk / f"{stem}.png")
                cnt += 1
        print(f"Piktogramme: {cnt} → {pk.relative_to(ROOT)}")
        shutil.rmtree(BRAND_SRC)
        print("Entpacktes Quellpaket entfernt:", BRAND_SRC.name)

    print("fertig.")


if __name__ == "__main__":
    main()
