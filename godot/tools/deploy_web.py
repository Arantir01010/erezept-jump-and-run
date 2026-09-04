"""
Veröffentlicht die Browser-Fassung der Godot-Version auf GitHub Pages.

    python godot/tools/deploy_web.py               # Web-Export neu bauen und veröffentlichen
    python godot/tools/deploy_web.py --no-export   # godot/build-web/ nehmen, wie es ist
    python godot/tools/deploy_web.py --no-push     # nur den Branch `web` lokal aktualisieren

Ablauf: Godot-Web-Export (Preset „Web", nothreads — läuft ohne COOP/COEP-Header, also
auch auf GitHub Pages) → die Export-Dateien werden der einzige Inhalt des Branches
`web` (über einen temporären Worktree, die Historie bleibt erhalten) → Push.
GitHub Pages ist auf „Branch web, Ordner /" eingestellt (Repository → Settings → Pages)
und veröffentlicht nach dem Push von selbst, meist in unter zwei Minuten:

    https://arantir01010.github.io/erezept-jump-and-run/

Der Branch `web` enthält keinen Quelltext, nur die Auslieferung: index.html, index.js,
die Engine (index.wasm, ~40 MB, ändert sich nur mit der Godot-Version) und das Spiel
(index.pck, ~2 MB). Die PwC-Schriften stecken im PCK — wer das nicht möchte, exportiert
vorher ohne assets/fonts/ (Brand.gd fällt dann auf die Godot-Standardschrift zurück).
"""
from __future__ import annotations

import argparse
import datetime
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
BUILD = ROOT / "godot" / "build-web"
BRANCH = "web"
URL = "https://arantir01010.github.io/erezept-jump-and-run/"
DATEIEN = [
    "index.html", "index.js", "index.wasm", "index.pck",
    "index.audio.worklet.js", "index.audio.position.worklet.js",
    "index.icon.png", "index.apple-touch-icon.png", "index.png",
]
README = """# Browser-Fassung — Paul & REZI, Das e-Rezept Jump 'n' Run

Dieser Branch ist die Auslieferung für GitHub Pages und wird von
`godot/tools/deploy_web.py` erzeugt. Nichts hier von Hand ändern — der nächste
Lauf des Skripts überschreibt alles. Quelltext: Branch `main`, Ordner `godot/`.

Stand: {stamp} · Quellstand main {sha}
Live: {url}

Aufruf-Schalter: `?touch=1` (Bildschirm-Steuerung), `?level=<id>` (direkt ins Level),
`?kiosk=1` (Messe: Idle-Reset, kein Cursor).
"""


def run(*cmd: str, cwd: Path | None = None, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess:
    r = subprocess.run(list(cmd), cwd=str(cwd or ROOT), text=True, capture_output=capture,
                       encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        if capture:
            sys.stdout.write(r.stdout or "")
            sys.stderr.write(r.stderr or "")
        raise SystemExit("Befehl fehlgeschlagen: " + " ".join(cmd))
    return r


def export() -> None:
    if not GODOT.exists():
        raise SystemExit(f"Godot fehlt: {GODOT}")
    print("== Web-Export (Preset Web)")
    run(str(GODOT), "--headless", "--path", "godot", "--export-release", "Web", "build-web/index.html")


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Browser-Fassung auf GitHub Pages veröffentlichen")
    ap.add_argument("--no-export", action="store_true", help="vorhandenes godot/build-web/ verwenden")
    ap.add_argument("--no-push", action="store_true", help="Branch nur lokal aktualisieren")
    ap.add_argument("--trailer", default="", help="Zusatzzeile für die Commit-Nachricht")
    args = ap.parse_args()

    if not args.no_export:
        export()
    fehlt = [f for f in DATEIEN if not (BUILD / f).exists()]
    if fehlt:
        raise SystemExit("Export unvollständig, es fehlen: " + ", ".join(fehlt))

    sha = run("git", "rev-parse", "--short", "HEAD", capture=True).stdout.strip()
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    run("git", "fetch", "origin", check=False)
    has_remote = run("git", "rev-parse", "--verify", "--quiet", f"origin/{BRANCH}", check=False, capture=True).returncode == 0

    tmp = Path(tempfile.mkdtemp(prefix="paul-rezi-web-"))
    wt = tmp / "web"
    try:
        print(f"== Branch {BRANCH} aktualisieren (Worktree {wt})")
        run("git", "worktree", "add", "--detach", str(wt), "HEAD")
        if has_remote:
            run("git", "checkout", "-q", "-B", BRANCH, f"origin/{BRANCH}", cwd=wt)
        else:
            run("git", "checkout", "-q", "--orphan", BRANCH, cwd=wt)
        run("git", "rm", "-r", "-f", "-q", "--ignore-unmatch", ".", cwd=wt)
        for p in wt.iterdir():
            if p.name == ".git":
                continue
            shutil.rmtree(p) if p.is_dir() else p.unlink()
        for f in DATEIEN:
            shutil.copy2(BUILD / f, wt / f)
        (wt / ".nojekyll").write_text("", encoding="utf-8")
        (wt / "README.md").write_text(README.format(stamp=stamp, sha=sha, url=URL), encoding="utf-8", newline="\n")
        run("git", "add", "-A", cwd=wt)
        if not run("git", "status", "--porcelain", cwd=wt, capture=True).stdout.strip():
            print("Keine Änderung gegenüber dem veröffentlichten Stand.")
            return
        msg = f"Browser-Fassung {stamp} (Quellstand main {sha})"
        if args.trailer:
            msg += "\n\n" + args.trailer
        run("git", "commit", "-q", "-m", msg, cwd=wt)
        if args.no_push:
            print(f"Branch {BRANCH} lokal aktualisiert (kein Push).")
            return
        run("git", "push", "-u", "origin", BRANCH, cwd=wt)
        print("Gepusht. GitHub Pages veröffentlicht gleich:", URL)
    finally:
        run("git", "worktree", "remove", "--force", str(wt), check=False)
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
