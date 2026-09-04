"""
Level-Sync: kopiert die Level-Quellen des Phaser-Baukastens (design/) in das
Godot-Projekt, damit beide Fassungen dieselben Inhalte spielen.

    python godot/tools/sync_levels.py

Ziel:
    godot/levels/_import/<id>/layout.txt + level.json   (aus design/levels)
    godot/config/themes.json, playlist.json, game-config.json, input-bindings.json

Godot-eigene Level liegen direkt in godot/levels/<id>/ und haben Vorrang vor
dem Import (der Loader in src/core/LevelData.gd prüft zuerst dort). So kann
ein Level in Godot neu gebaut werden, ohne das design/-Original anzufassen.
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DESIGN = ROOT / "design"
PUBLIC = ROOT / "public" / "config"
GODOT = ROOT / "godot"
IMPORT = GODOT / "levels" / "_import"
CONFIG = GODOT / "config"


def main() -> None:
    playlist = json.loads((DESIGN / "playlist.json").read_text(encoding="utf-8"))
    IMPORT.mkdir(parents=True, exist_ok=True)
    CONFIG.mkdir(parents=True, exist_ok=True)

    copied = []
    for level_id in playlist:
        src = DESIGN / "levels" / level_id
        if not src.is_dir():
            print(f"  ! Level {level_id} fehlt in design/levels — übersprungen")
            continue
        dst = IMPORT / level_id
        dst.mkdir(parents=True, exist_ok=True)
        for name in ("layout.txt", "level.json"):
            shutil.copyfile(src / name, dst / name)
        copied.append(level_id)

    shutil.copyfile(DESIGN / "playlist.json", CONFIG / "playlist.json")
    shutil.copyfile(PUBLIC / "themes.json", CONFIG / "themes.json")
    shutil.copyfile(PUBLIC / "input-bindings.json", CONFIG / "input-bindings.json")

    # game-config: nur die Felder, die Godot braucht (levelOrder kommt aus der Playlist)
    gc = json.loads((PUBLIC / "game-config.json").read_text(encoding="utf-8"))
    keep = {k: gc[k] for k in ("event", "language", "titleScreen", "ending", "disclaimer",
                               "audio", "idleResetSeconds", "softAutopilotSeconds") if k in gc}
    (CONFIG / "game-config.json").write_text(json.dumps(keep, ensure_ascii=False, indent=2) + "\n",
                                             encoding="utf-8")

    print(f"Level importiert: {len(copied)} → {IMPORT.relative_to(ROOT)}")
    for lid in copied:
        print(f"  ✓ {lid}")
    print(f"Konfiguration → {CONFIG.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
