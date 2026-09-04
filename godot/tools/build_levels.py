"""
Level-Generator der Godot-Fassung: baut alle zehn Stationen nach den
Leveldesign-Regeln (Kishōtenketsu: Einführung → Entwicklung → Wendung mit
Weggabelung → Abschluss) und prüft die Erreichbarkeit mit den Sprungmaßen
(3 hoch, ~6 weit; Hülle-Level ~5, weil verschlüsselt langsamer gelaufen wird).

    python godot/tools/build_levels.py

Schreibt godot/levels/<id>/layout.txt + level.json. Stationstexte und
Mechanik-Parameter kommen aus godot/levels/_import/<id>/level.json (Sync aus
design/), nur Geometrie, Objektpositionen, Sammelziel und Par-Zeit sind neu.

Ausbau (A2): alle Level 30–50 % breiter, mehr Sprungelemente (Plattformketten
mit wechselnden Höhen, Sprungfedern, Pendel-Plattformen über Gruben, durch-
springbare Platten, Störfelder und Podeste als Timing-Hindernisse, schmale
Podeste, Wandsprung-Schächte als Bonuswege), Schwierigkeitskurve 01 → 20.

Runde 3 („etwas schwieriger"): Ketten-Lücken um eine Kachel weiter, das letzte
Podest jeder Podest-Reihe nur noch eine Kachel breit, zusätzliche Störfelder
zwischen den Plattformen, Pendel-Plattformen fahren schneller (58 statt 50)
und meist weiter (48 statt 32 px), pro Level ein Rücksetzpunkt weniger, Lauscher
patrouillieren 12 % schneller (LAUSCHER_TEMPO), Sammelziel 14 statt 12
(Tunnel 18 statt 16). Station 1 bleibt sanft — dort nur Lücken und Störfelder.

Der Erreichbarkeits-Check modelliert:
  • Lauf, Stufe (1 hoch), Sprung (Rise 0–3, Weite je Rise), Fall (bis 7 weit)
  • Sprungfeder `^`: bis 8 hoch
  • Störfeld `x`: keine Standfläche für den Pflichtweg (Level ist ohne Treffer schaffbar)
  • Pendel-Plattform: nur an beiden Endlagen fest, dazwischen eine „Fahrt"-Kante
  • Wandsprung-Schächte (Wände 2–4 Kacheln auseinander): NUR für Bonus-Prüfsummen
  • Pflichtziele (Tür, Checkpoints, Stationsbausteine, Sammelziel) müssen OHNE
    REZI-Schub und OHNE Wandsprung erreichbar sein
"""
from __future__ import annotations

import json
import math
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
IMPORT = GODOT / "levels" / "_import"
OUT = GODOT / "levels"

H = 23
SOLID = set("#=GA~%")
GROUND = 19          # Standreihe über dem Boden
SHOT_FRACS = (0.42, 0.66, 0.86)   # Kiosk.run_shots versetzt Paul auf diese Anteile der Breite
LAUSCHER_TEMPO = 1.12             # Runde 3: alle Lauscher patrouillieren schneller


class Level:
    def __init__(self, id_: str, width: int, tube: bool = False, huelle: bool = False):
        self.id = id_
        self.w = width
        self.g = [["."] * width for _ in range(H)]
        self.objects: list[dict] = []
        self.tube = tube
        self.huelle = huelle
        if tube:
            self.fill(0, width - 1, 0, 1, "%")
            self.row(0, width - 1, 2, "~")
            self.row(0, width - 1, 20, "~")
            self.fill(0, width - 1, 21, 22, "%")
        else:
            self.fill(0, width - 1, 20, 22, "#")
            # Weltrand: niemand läuft links oder rechts aus der Karte
            self.fill(0, 0, 15, 19, "#")
            self.fill(width - 1, width - 1, 15, 19, "#")

    # --- Gelände ---
    def put(self, x, y, ch):
        assert 0 <= x < self.w and 0 <= y < H, (self.id, x, y, ch)
        self.g[y][x] = ch

    def row(self, x0, x1, y, ch):
        for x in range(x0, x1 + 1):
            self.put(x, y, ch)

    def fill(self, x0, x1, y0, y1, ch):
        for y in range(y0, y1 + 1):
            self.row(x0, x1, y, ch)

    def pit(self, x0, x1):
        """Graben im Boden (kein Tod — Paul landet auf dem Levelboden und muss zurück)."""
        self.fill(x0, x1, 20, 22, ".")

    def plat(self, x0, x1, y):
        """Datenfeld `=` (von unten durchspringbar) in Reihe y, Standreihe y-1."""
        self.row(x0, x1, y, "=")

    def block(self, x0, x1, y0, ch="#"):
        """Solider Block von Reihe y0 bis zum Boden."""
        self.fill(x0, x1, y0, 22, ch)

    def step(self, x, y, ch="A"):
        self.put(x, y, ch)

    def steps_up(self, x, n, ch="A"):
        """Treppe aus Akzentblöcken: Stufe i (0..n-1) bei x+i ist i+1 hoch. Ende bei x+n-1."""
        for i in range(n):
            self.fill(x + i, x + i, GROUND - i, GROUND, ch)
        return x + n - 1

    def steps_down(self, x, n, ch="A"):
        for i in range(n):
            self.fill(x + i, x + i, GROUND - (n - 1 - i), GROUND, ch)
        return x + n - 1

    def pillar(self, x, top, w=1, ch="A"):
        """Schmales Podest von Reihe top bis zum Boden (Standreihe top-1)."""
        self.fill(x, x + w - 1, top, GROUND, ch)

    def wall(self, x, y0, y1=GROUND, w=1, ch="#"):
        self.fill(x, x + w - 1, y0, y1, ch)

    def chain(self, x, spec, bits=True):
        """Plattformkette: spec = [(span, row, gap_after), …]. Standreihe = row-1.
        Prüfsummen mittig über jeder Plattform. Gibt das x nach der letzten Lücke zurück."""
        for span, row, gap in spec:
            self.plat(x, x + span - 1, row)
            if bits:
                for bx in range(x + 1, x + span - 1, 2):
                    self.bits((bx, row - 2))
                if span <= 2:
                    self.bits((x, row - 2))
            x += span + gap
        return x

    def shaft(self, x, gap=3, top=9, w=2, bottom=17, bonus=True, trail=True):
        """Wandsprung-Schacht (Bonusweg): zwei hängende Säulen, unten 2 Kacheln
        Durchgang, oben Bonus-Prüfsumme. Pflichtweg läuft unten durch. Ende: x+2w+gap-1."""
        self.wall(x, top, bottom, w)
        self.wall(x + w + gap, top, bottom, w)
        cx = x + w + gap // 2
        if trail:
            for y in range(bottom - 2, top + 1, -3):
                self.bits((cx, y))
        if bonus:
            self.bonus(cx, top - 2)
        return x + 2 * w + gap - 1

    # --- Marker ---
    def player(self, x, y=GROUND):
        self.put(x, y, "P")

    def bits(self, *pts):
        for x, y in pts:
            assert self.g[y][x] == ".", (self.id, "Prüfsumme in Gelände", x, y, self.g[y][x])
            self.put(x, y, "o")

    def bits_row(self, x0, x1, y=GROUND, step=2):
        self.bits(*[(x, y) for x in range(x0, x1 + 1, step)])

    def bonus(self, x, y):
        assert self.g[y][x] == ".", (self.id, "Bonus in Gelände", x, y)
        self.put(x, y, "*")

    def cp(self, x, y=GROUND):
        assert self.g[y][x] == "." and self.g[y + 1][x] in SOLID, (self.id, "Checkpoint ohne Boden", x, y)
        self.put(x, y, "C")

    def door(self, x, y=GROUND):
        assert self.g[y + 1][x] in SOLID, (self.id, "Tür ohne Boden", x, y)
        self.put(x, y, "D")

    def spring(self, x, y=GROUND):
        assert self.g[y + 1][x] in SOLID, (self.id, "Feder ohne Boden", x, y)
        self.put(x, y, "^")

    def spikes(self, x0, x1, y=GROUND):
        for x in range(x0, x1 + 1):
            assert self.g[y + 1][x] in SOLID, (self.id, "Störfeld ohne Boden", x, y)
        self.row(x0, x1, y, "x")

    # --- Objekte ---
    def obj(self, type_, tx, ty, **kw):
        d = {"type": type_, "tx": tx, "ty": ty}
        d.update(kw)
        self.objects.append(d)
        return d

    def sign(self, tx, de, en=None, ty=16, tw=3, th=4):
        self.obj("info-sign", tx, ty, tw=tw, th=th, textDe=de, textEn=en or de)

    def mover(self, tx, ty, range_=64, speed=50, tw=2):
        """Pendel-Plattform: Standreihe ty-1, pendelt von tx bis tx+range_/16 (Kacheln)."""
        return self.obj("moving-platform", tx, ty, tw=tw, range=range_, speed=speed)

    def andock(self, tx, tw=3):
        return self.obj("andock-plattform", tx, 18.6, tw=tw)

    def lauscher(self, tx, ty=18, **kw):
        if "speed" in kw:
            kw["speed"] = int(round(kw["speed"] * LAUSCHER_TEMPO))
        return self.obj("lauscher", tx, ty, **kw)

    def lines(self):
        return ["".join(r) for r in self.g]


# ------------------------------------------------------------ Erreichbarkeit

MAX_DX = {0: 6, 1: 6, 2: 6, 3: 5}          # normale Level
MAX_DX_HUELLE = {0: 5, 1: 5, 2: 4, 3: 4}   # verschlüsselt = 80 % Tempo
MAX_DROP_DX = 7
SPRING_TOP = 8

DEFAULTS = {
    "gate": (0.5, 6), "timing-gate": (8, 5), "stillstand-podest": (3, 0.4),
    "krypto-dusche": (5, 6), "deny-enemy": (1.4, 0.4), "stamp-exit": (6, 6),
    "letzte-tuer": (3, 6), "info-sign": (2.5, 4), "moving-platform": (2, 0.4),
    "hazard": (1, 1), "lauscher": (1, 1), "andock-plattform": (3, 0.4),
    "vau-feld": (6, 5), "kontext-anker": (1, 1.5), "karte": (1.2, 0.8),
    "kartenleser": (3, 3), "deco": (1.5, 1.5),
}


def dims(o: dict) -> tuple[float, float]:
    d = DEFAULTS.get(o["type"], (1, 1))
    return float(o.get("tw", d[0])), float(o.get("th", d[1]))


STATION_TYPES = ("kartenleser", "timing-gate", "krypto-dusche", "vau-feld", "kontext-anker",
                 "karte", "stillstand-podest")
MUST_BE_FREE = ("gate", "lauscher", "karte", "kartenleser", "kontext-anker", "timing-gate",
                "krypto-dusche", "stamp-exit", "letzte-tuer", "deny-enemy")


def platform_cells(o: dict) -> tuple[list[tuple[int, int]], list[tuple[int, int]]]:
    """Feste Zellen einer Objekt-Plattform: (Startlage, Endlage) — Endlage nur bei Pendel."""
    tw, _ = dims(o)
    x0 = int(o["tx"]); x1 = int(o["tx"] + tw) - 1
    y = int(round(o["ty"]))
    start = [(x, y) for x in range(x0, x1 + 1)]
    if o["type"] != "moving-platform":
        return start, []
    shift = int(o.get("range", 64) / 16)
    end = [(x + shift, y) for x in range(x0, x1 + 1)]
    return start, end


def check(level: Level) -> tuple[list[str], dict]:
    g = [list(r) for r in level.lines()]
    w = level.w
    maxdx_tab = MAX_DX_HUELLE if level.huelle else MAX_DX
    drop_dx = MAX_DROP_DX - (1 if level.huelle else 0)
    extra_solid: set[tuple[int, int]] = set()
    rides: dict[tuple[int, int], list[tuple[int, int]]] = {}
    for o in level.objects:
        if o["type"] in ("andock-plattform", "stillstand-podest", "moving-platform"):
            start, end = platform_cells(o)
            for c in start + end:
                extra_solid.add(c)
            if end:
                # Fahrt: von jeder Standzelle der Startlage zu denen der Endlage (und zurück)
                s_stand = [(x, y - 1) for x, y in start]
                e_stand = [(x, y - 1) for x, y in end]
                for c in s_stand:
                    rides.setdefault(c, []).extend(e_stand)
                for c in e_stand:
                    rides.setdefault(c, []).extend(s_stand)

    def solid(x, y):
        if y >= H:
            return True
        if x < 0 or x >= w or y < 0:
            return False
        return g[y][x] in SOLID or (x, y) in extra_solid

    def free(x, y):
        return 0 <= x < w and 0 <= y < H and not solid(x, y)

    def standable(x, y):
        return free(x, y) and free(x, y - 1) and solid(x, y + 1) and g[y][x] != "x"

    start = None
    targets = {}
    for y in range(H):
        for x in range(w):
            ch = g[y][x]
            if ch == "P":
                start = (x, y)
            elif ch in "oD*^Cx":
                targets[(x, y)] = ch
    exits = [(int(o["tx"]) + 1, int(o["ty"] + dims(o)[1]) - 1)
             for o in level.objects if o["type"] in ("stamp-exit", "letzte-tuer")]
    assert start, level.id

    # 0-1-BFS: Laufen kostet 0, Sprung/Fahrt kostet 1 → Sprungzahl für die Par-Zeit
    INF = 10 ** 9
    dist = {start: 0}
    q = deque([start])
    while q:
        x, y = q.popleft()
        d = dist[(x, y)]
        walk, hops = [], []
        for dx in (-1, 1):
            nx = x + dx
            if standable(nx, y):
                walk.append((nx, y))
            if standable(nx, y - 1) and free(x, y - 1) and free(x, y - 2):
                walk.append((nx, y - 1))
        spring = g[y][x] == "^"
        top = SPRING_TOP if spring else 3
        for ty in range(max(0, y - top), min(H, y + 12)):
            rise = y - ty
            if rise > 0 and not (free(x, y - 2) and free(x, y - 3)):
                continue
            if spring and rise >= 0:
                maxdx = 6 if rise <= 5 else 4
            elif rise >= 0:
                maxdx = maxdx_tab[rise]
            else:
                maxdx = drop_dx
            for tx in range(x - maxdx, x + maxdx + 1):
                if (tx, ty) == (x, y) or not standable(tx, ty):
                    continue
                hops.append((tx, ty))
        hops.extend(rides.get((x, y), []))
        for c in walk:
            if dist.get(c, INF) > d:
                dist[c] = d
                q.appendleft(c)
        for c in hops:
            if dist.get(c, INF) > d + 1:
                dist[c] = d + 1
                q.append(c)
    reach = set(dist)

    # Wandsprung (nur Bonus): Schacht = freie Spalte(n) zwischen zwei Wänden, 2–4 breit.
    # Von einer erreichten Standzelle in der Nähe geht es den Schacht hoch bis 3 über
    # die niedrigere Wand; dort oben liegende Standflächen sind "Bonus-erreichbar".
    air: set[tuple[int, int]] = set()
    for y in range(H):
        x = 0
        while x < w:
            if solid(x, y):
                x += 1
                continue
            x2 = x
            while x2 + 1 < w and free(x2 + 1, y):
                x2 += 1
            gap = x2 - x + 1
            if 2 <= gap <= 4 and solid(x - 1, y) and solid(x2 + 1, y) and x - 1 >= 0 and x2 + 1 < w:
                for xx in range(x, x2 + 1):
                    air.add((xx, y))
            x = x2 + 1
    # Schacht-Zellen sind nur erreichbar, wenn eine erreichte Standzelle darunter/daneben liegt
    air_reach: set[tuple[int, int]] = set()
    for (ax, ay) in air:
        for (rx, ry) in reach:
            if abs(rx - ax) <= 4 and -1 <= ry - ay <= 12:
                air_reach.add((ax, ay))
                break
    # Aufstieg innerhalb des Schachts (zusammenhängende Schacht-Zellen nach oben) + 3 darüber
    grown = set(air_reach)
    changed = True
    while changed:
        changed = False
        for (ax, ay) in list(grown):
            for c in ((ax, ay - 1), (ax - 1, ay), (ax + 1, ay)):
                if c in air and c not in grown:
                    grown.add(c)
                    changed = True
    for (ax, ay) in list(grown):
        if (ax, ay - 1) not in air:
            for k in range(1, 4):
                for dx in (-1, 0, 1):
                    if free(ax + dx, ay - k):
                        grown.add((ax + dx, ay - k))
    reach_bonus = reach | grown
    # Standflächen, die man vom Schacht-Ausstieg aus erreicht (für Bonus-Ketten oben)
    for (ax, ay) in list(grown):
        for tx in range(ax - 3, ax + 4):
            for ty in range(ay - 1, min(H, ay + 12)):
                if standable(tx, ty):
                    reach_bonus.add((tx, ty))

    problems = []

    def grabbable(pt, dy_up, dx, pool):
        px, py = pt
        for (rx, ry) in pool:
            if abs(rx - px) <= dx and -1 <= ry - py <= dy_up:
                return True
        return False

    bits_easy = 0
    bits_all = 0
    bonus_all = 0
    for pt, ch in targets.items():
        if ch == "D" and not (pt in reach or grabbable(pt, 1, 2, reach)):
            problems.append(f"Tür bei {pt} unerreichbar")
        elif ch == "o":
            if grabbable(pt, 4, 5, reach):
                bits_easy += 1
            if grabbable(pt, 5, 6, reach_bonus):
                bits_all += 1
            else:
                problems.append(f"Prüfsumme bei {pt} unerreichbar")
        elif ch == "*":
            if grabbable(pt, 6, 7, reach_bonus):
                bonus_all += 1
            else:
                problems.append(f"Bonus bei {pt} unerreichbar (auch mit REZI-Schub/Wandsprung)")
        elif ch == "C" and pt not in reach and not grabbable(pt, 1, 2, reach):
            problems.append(f"Checkpoint bei {pt} unerreichbar")
    for e in exits:
        if not grabbable(e, 2, 3, reach):
            problems.append(f"Ausgang bei {e} unerreichbar")
    gates = {}
    openers = {}
    for o in level.objects:
        t = o["type"]
        tw_, th_ = dims(o)
        if t in STATION_TYPES:
            x0 = int(o["tx"]); y1 = int(o["ty"] + th_)
            w_ = int(tw_) or 1
            ok = any(grabbable((x0 + k, y1 - 1), 2, 2, reach) for k in range(max(1, w_)))
            if not ok:
                problems.append(f"{t} bei tx={o['tx']} nicht erreichbar")
        if t in MUST_BE_FREE:
            x0 = int(o["tx"]); x1 = int(math.ceil(o["tx"] + tw_)) - 1
            y0 = int(o["ty"]); y1 = int(math.ceil(o["ty"] + th_)) - 1
            for yy in range(max(0, y0), min(H, y1 + 1)):
                for xx in range(max(0, x0), min(w, x1 + 1)):
                    if g[yy][xx] in SOLID and g[yy][xx] != "G":   # Gold-Pads sind Aktions-Stellen
                        problems.append(f"{t} bei tx={o['tx']} steckt im Gelände ({xx},{yy})")
                        break
        if t == "gate":
            gates[o["name"]] = o
            gy = int(o["ty"] + th_)
            if not solid(int(o["tx"]), gy):
                problems.append(f"Tor {o['name']} endet nicht auf Boden")
        if "gate" in o and t != "gate":
            openers[o["gate"]] = o
    for n, gt in gates.items():
        op = openers.get(n)
        if op is None:
            problems.append(f"Tor {n} hat keinen Öffner")
        elif op["tx"] >= gt["tx"]:
            problems.append(f"Öffner von {n} liegt nicht links vom Tor")
    for n in openers:
        if n not in gates:
            problems.append(f"Öffner verweist auf unbekanntes Tor {n}")
    ls = sorted(o["tx"] for o in level.objects if o["type"] == "lauscher")
    for a, b in zip(ls, ls[1:]):
        if b - a < 2:
            problems.append(f"Lauscher bei {a} und {b} zu dicht")
    # Prüflauf-Positionen (Kiosk.run_shots): Paul wird auf Bodenhöhe abgesetzt
    for f in SHOT_FRACS:
        cx = int(w * f)
        for xx in (cx - 1, cx, cx + 1):
            if not (free(xx, GROUND) and free(xx, GROUND - 1) and solid(xx, GROUND + 1) and g[GROUND][xx] != "x"):
                problems.append(f"Prüflauf-Position x={xx} ({int(f * 100)} %) ist kein freier Boden")
                break
    # Sprünge auf dem Pflichtweg bis zum Ausgang
    goal_pts = [pt for pt, ch in targets.items() if ch == "D"] + exits
    jumps = min((dist.get(p, INF) for p in goal_pts), default=INF)
    if jumps >= INF:
        # Ausgang evtl. nur „greifbar": nächste erreichte Zelle in der Nähe
        for p in goal_pts:
            for (rx, ry), d in dist.items():
                if abs(rx - p[0]) <= 3 and -1 <= ry - p[1] <= 2:
                    jumps = min(jumps, d)
    info = {"jumps": jumps if jumps < INF else 0, "bits_easy": bits_easy, "bits_all": bits_all,
            "bonus": bonus_all}
    return problems, info


# ------------------------------------------------------------ Par-Zeit & Sammelziel

def interaction_seconds(level: Level, j: dict) -> float:
    m = j.get("mechanics", {})
    s = 0.0
    for o in level.objects:
        t = o["type"]
        p = lambda k, d: o.get(k, m.get(t, {}).get(k, d))
        if t == "timing-gate":
            s += int(p("steps", 4)) * int(p("stepMs", 900)) / 1000.0 + 1.5
        elif t == "stillstand-podest":
            s += int(p("scanMs", 1200)) / 1000.0 + 1.0
        elif t == "krypto-dusche":
            s += 1.5
        elif t == "kartenleser":
            s += 1.5
        elif t == "stamp-exit":
            s += 2.0
        elif t == "deny-enemy":
            s += 2.5
        elif t == "letzte-tuer":
            s += 7.0
        elif t == "lauscher":
            s += 2.0     # Patrouille abwarten oder verschlüsselt (langsam) vorbei
        elif t == "andock-plattform":
            s += 1.0     # Hülle umschalten, andocken, weiter
    return s


def par_seconds(level: Level, j: dict, info: dict) -> int:
    """Par grob aus Breite, Sprungzahl und Interaktionen: gute Spieler schaffen es,
    Messebesucher brauchen etwa das 1,5-fache."""
    if level.tube:
        tube = float(j.get("mechanics", {}).get("tube-scroll", {}).get("speed", 50)) * 3.0 / 48.0
        base = level.w / tube + interaction_seconds(level, j)
    else:
        v = 11.25 * (0.9 if level.huelle else 1.0)
        base = level.w / v + info["jumps"] * 0.6 + interaction_seconds(level, j) + 4.0
        if level.huelle:
            base *= 1.15   # Hülle-Wechsel, Lauscher abwarten
    return int(math.ceil(base * 1.2 / 5.0) * 5)


def count_required(info: dict, wanted: int) -> int:
    """Sammelziel: gewünschter Wert, aber immer mit 5 Prüfsummen Reserve zu den
    ohne Schub/Wandsprung erreichbaren (ein Treffer verstreut bis zu 5).
    0 = kein Sammelziel (Stempel-Ausgang, wie im Import)."""
    if wanted <= 0:
        return 0
    return max(3, min(wanted, info["bits_easy"] - 5))


# ------------------------------------------------------------ Level

def base_json(id_: str) -> dict:
    return json.loads((IMPORT / id_ / "level.json").read_text(encoding="utf-8"))


BUILDERS = []


def builder(fn):
    BUILDERS.append(fn)
    return fn



@builder
def lvl_01():
    """Tutorial (sanft): Laufen, Springen, Sammeln, ein Terminal, die erste Weggabelung."""
    L = Level("01-stammdaten", 168)
    L.player(3)
    # Ki — Laufen und Springen
    L.sign(5, "Willkommen im Daten-Check! Lauf nach rechts — Joystick oder Pfeiltasten.", "Welcome to the data check! Head right — joystick or arrow keys.")
    L.bits((8, 19), (10, 19))
    L.sign(12, "Springen: roter Knopf oder LEERTASTE. Hol dir die leuchtenden Daten-Kacheln!", "Jump: red button or SPACE. Grab the glowing data tiles!", tw=2)
    L.step(16, 19); L.bits((14, 18), (16, 17))
    L.fill(21, 22, 18, 19, "A"); L.bits((21, 16), (25, 18))
    L.cp(28)
    # Shō — die erste Plattformkette, steigend, mit Graben darunter
    L.plat(32, 35, 18); L.bits((33, 16), (34, 16))
    L.plat(39, 42, 16); L.bits((40, 14), (41, 14))
    L.pit(44, 46)
    L.plat(44, 47, 14); L.bits((45, 12), (46, 12)); L.bonus(46, 10)
    L.sign(45, "In der Luft nochmal springen: REZI trägt dich! Die goldene Kachel oben ist ein Bonus.", "Jump again in the air: REZI carries you! The golden tile up there is a bonus.", ty=12, th=8)
    L.plat(51, 54, 17); L.bits((52, 15), (53, 15))
    L.spikes(55, 55); L.bits((57, 19), (59, 18)); L.cp(60)
    # Pendel-Plattform über dem Graben: Fahrt oder gezielter Sprung
    L.pit(63, 68)
    L.mover(63, 18, range_=64, speed=58)
    L.bits((64, 16), (65, 16), (66, 16), (67, 16))
    L.cp(70)
    # Ten 1 — das Aktualisierungs-Terminal (Station)
    L.row(73, 79, 19, "G")
    L.obj("timing-gate", 73, 15, tw=7, th=5, gate="tor-daten")
    L.obj("gate", 82, 14, th=6, name="tor-daten")
    L.bits((85, 19), (87, 18))
    L.cp(89)
    # Ten 2 — Weggabelung: Feder nach oben zu den Bonus-Kacheln, unten Störfelder
    L.sign(90, "Zwei Wege: Die Feder bringt dich hoch zu den Bonus-Kacheln — unten warten Störfelder.", "Two ways: the spring takes you up to the bonus tiles — down here are jamming fields.", ty=15, tw=2, th=5)
    L.spring(93)
    L.plat(95, 98, 12); L.bonus(97, 9)
    L.plat(102, 105, 11); L.bonus(104, 8); L.bits((103, 9))
    L.plat(109, 112, 10); L.bonus(111, 7); L.bits((110, 8))
    L.spikes(98, 98); L.spikes(104, 105); L.spikes(113, 113)
    L.bits((96, 18), (101, 18), (108, 18))
    # schmale Podeste über Störfeldern — Timing und Präzision
    L.pillar(115, 18, w=2); L.bits((115, 16), (116, 16))
    L.spikes(117, 118)
    L.pillar(119, 17, w=2); L.bits((119, 15), (120, 15))
    L.spikes(121, 122)
    L.pillar(123, 16, w=2); L.bits((123, 14), (124, 14)); L.bonus(126, 12)
    L.spikes(125, 126)
    L.pillar(127, 17, w=2); L.bits((127, 15), (128, 15))
    L.cp(132)
    # Ketsu — Abstieg über durchspringbare Platten zum Portal
    L.plat(135, 138, 17); L.bits((136, 15), (137, 15))
    L.plat(142, 145, 15); L.bits((143, 13), (144, 13)); L.bonus(147, 11)
    L.plat(149, 151, 17); L.bits((150, 15))
    L.spikes(140, 140); L.spikes(147, 147)
    L.bits((153, 18), (155, 19), (157, 19), (158, 19))
    L.cp(153)
    L.sign(158, "Alle Daten geprüft? Dann öffnet das Portal — {n} Kacheln reichen.", "All data checked? Then the portal opens — {n} tiles are enough.", ty=15, th=5)
    L.door(164)
    j = base_json(L.id)

    def finish(jj, n):
        jj["stuckHint"] = {"de": f"Immer nach rechts! Sammle {n} Daten-Kacheln, dann öffnet das Portal am Ende.",
                           "en": f"Keep heading right! Collect {n} data tiles, then the portal at the end opens."}
        for o in jj["objects"]:
            if o["type"] == "info-sign":
                o["textDe"] = o["textDe"].replace("{n}", str(n))
                o["textEn"] = o["textEn"].replace("{n}", str(n))
    j["_finish"] = finish
    return L, j, 13


@builder
def lvl_02():
    """Kartenterminal: Kontaktfedern (Sprungfedern), Kralle, PIN-Schleuse, Aufstieg zum Stempel."""
    L = Level("02-kartenterminal", 150)
    L.player(3)
    L.bits((7, 19), (9, 19), (12, 18))
    L.step(14, 19); L.fill(20, 21, 18, 19, "A"); L.bits((18, 17), (21, 16))
    L.cp(25)
    L.pit(29, 31); L.bits((30, 17))
    # Shō — Kette + Kontaktfedern als Trampoline
    L.plat(33, 37, 17); L.bits((34, 15), (35, 15), (36, 15))
    L.plat(41, 45, 14); L.bits((42, 12), (43, 12)); L.bonus(44, 10)
    L.bits((47, 19))
    L.spring(50)
    L.plat(52, 55, 12); L.bits((53, 10), (54, 10)); L.bonus(57, 9)
    L.plat(58, 60, 15); L.bits((59, 13))
    L.bits((49, 19), (56, 19), (63, 19))
    L.spikes(61, 61)
    # Pendel-Plattform über dem Graben (Runde 3: weiter und schneller, kein Rücksetzpunkt davor)
    L.pit(66, 71)
    L.mover(66, 18, range_=64, speed=58)
    L.bits((67, 16), (68, 16), (69, 16), (70, 16))
    L.cp(73)
    # Ten — Kriechgang mit Skimming-Kralle, dann die PIN-Schleuse
    L.sign(74, "Vorsicht, Skimming-Kralle — duck dich im Kriechgang!", "Careful, skimming claw — duck in the crawlway!")
    L.fill(77, 85, 14, 17, "#")
    L.bits((79, 19), (83, 19))
    L.obj("deny-enemy", 81.1, 18.55, fromRight=True, reach=42)
    L.row(89, 95, 19, "G")
    L.obj("timing-gate", 89, 15, tw=7, th=5, gate="gate-pin")
    L.obj("gate", 98, 14, th=6, name="gate-pin")
    # Ketsu — Aufstieg zum Signatur-Podium: Podeste, Kette, Bonus-Schacht, Störfelder
    L.sign(100, "Dr. Pixel wartet oben mit dem Stempel. Rauf da!", "Dr. Pixel is waiting up there with the stamp. Climb!")
    L.cp(102)
    L.pillar(104, 18, w=2); L.bits((104, 16), (105, 16))
    L.spikes(106, 107)
    L.pillar(108, 17, w=2); L.bits((108, 15), (109, 15))
    L.spikes(110, 111)
    L.pillar(112, 16, w=1); L.bits((112, 14))
    L.plat(116, 119, 14); L.bits((117, 12), (118, 12))
    L.plat(122, 125, 11); L.bits((123, 9), (124, 9)); L.bonus(127, 8)
    L.shaft(129, gap=3, top=8)          # Säulen 129–130 und 134–135, Bonus oben
    L.spikes(138, 139)
    L.block(141, 147, 17)
    L.obj("stamp-exit", 141, 11, tw=6, th=6)
    L.bits((143, 15), (144, 14), (145, 15))
    j = base_json(L.id)
    return L, j, 0          # Stempel-Ausgang: kein Sammelziel (wie im Import)


@builder
def lvl_03():
    """KOV Gateway (Tube, Auto-Scroll): Podeste, Krypto-Dusche, drei Bahnen voller Bits."""
    L = Level("03-kov-gateway", 182, tube=True)
    L.player(3)
    L.bits((7, 19), (9, 19), (11, 19))
    L.plat(12, 15, 17); L.bits((13, 15), (14, 15))
    L.plat(18, 21, 14); L.bits((19, 12), (20, 12)); L.bonus(22, 9)
    L.fill(25, 26, 18, 19, "A"); L.bits((25, 16))
    L.obj("stillstand-podest", 30, 17.6, gate="gate-scan-1")
    L.obj("gate", 37, 14, th=6, name="gate-scan-1")
    L.fill(41, 42, 18, 19, "A"); L.bits((40, 17), (44, 19), (46, 19)); L.spikes(45, 45)
    L.plat(48, 51, 17); L.bits((49, 15), (50, 15))
    L.plat(54, 57, 14); L.bits((55, 12), (56, 12))
    L.plat(60, 63, 11); L.bits((61, 9), (62, 9)); L.bonus(65, 8)
    L.bits((66, 19), (68, 19)); L.spikes(67, 67)
    L.obj("krypto-dusche", 70, 14, gate="gate-krypto")
    L.obj("gate", 78, 14, th=6, name="gate-krypto")
    # Ride — drei Bahnen: Boden, Platte, Feder-Hochbahn
    L.bits_row(82, 96, 19)
    L.plat(84, 96, 16); L.bits_row(85, 95, 14)
    L.spring(99)
    L.plat(101, 106, 12); L.bits_row(102, 105, 10, 1); L.bonus(108, 9)
    L.plat(109, 112, 14); L.bits((110, 12), (111, 12))
    L.bits((114, 19), (116, 19))
    L.obj("stillstand-podest", 122, 17.6, gate="gate-scan-2")
    L.obj("gate", 128, 14, th=6, name="gate-scan-2")
    # Pendel-Fähre in der Höhe zu einer Bonus-Bahn
    L.plat(130, 133, 17); L.bits((131, 15), (132, 15))
    L.plat(136, 139, 14); L.bits((137, 12), (138, 12))
    L.mover(142, 13, range_=80, speed=45)
    L.plat(150, 155, 12); L.bits_row(151, 154, 10, 1); L.bonus(157, 9)
    L.bits_row(134, 148, 19)
    L.plat(158, 161, 15); L.bits((159, 13), (160, 13))
    L.bits_row(150, 172, 19)
    L.door(177)
    for tx, d in ((18, 4), (52, 5), (88, 3), (120, 5), (150, 4), (170, 3)):
        L.obj("deco", tx, 0.4, sprite="krake-0", anim="krake-swim", drift=d)
    j = base_json(L.id)
    return L, j, 18



@builder
def lvl_04():
    """Die Hülle (Regen): Lauscher, Andock-Plattformen, erste VAU — Hülle-Wechsel lernen."""
    L = Level("04-die-huelle", 182, huelle=True)
    L.player(3)
    # Ki — Hülle wechseln, der erste Lauscher
    L.bits((8, 19), (10, 19)); L.cp(14)
    L.sign(5, "Joystick HOCH (oder Shift) wechselt deine Hülle. Probier es aus!", "Joystick UP (or Shift) switches your shell. Try it!")
    L.sign(18, "Achtung, Lauscher! Er sieht nur unverschlüsselte Daten.", "Careful, an eavesdropper! He only sees unencrypted data.")
    L.lauscher(26, patrol=44, speed=26, reach=96, spread=20)
    L.plat(30, 33, 17); L.bits((31, 15), (32, 15))
    L.plat(37, 40, 14); L.bits((38, 12), (39, 12)); L.bonus(41, 9)
    # Shō — Andock-Plattform: nur Klartext trägt
    L.lauscher(44, patrol=-32, speed=30, reach=88, spread=18)
    L.bits((42, 19), (47, 19))
    L.pit(50, 53); L.cp(48); L.bits((51, 17), (52, 17))
    L.sign(53, "Die Plattform trägt nur Klartext — und unten ist nichts.", "The platform only carries plain text — and below is nothing.")
    L.pit(55, 59)
    L.andock(56)
    L.lauscher(62, patrol=36, speed=24, reach=92, spread=20)
    L.bits((61, 18), (65, 19)); L.cp(67)
    L.plat(70, 73, 17); L.bits((71, 15), (72, 15))
    L.spikes(74, 74)
    L.plat(77, 80, 15); L.bits((78, 13), (79, 13))
    L.spikes(81, 82); L.bits((83, 19))
    # Ten — die VAU: schnell UND unsichtbar; danach Grube + Pendel-Plattform
    L.obj("vau-feld", 86, 15, tw=6, th=5, ttlMs=5000)
    L.obj("kontext-anker", 89, 18)
    L.bits((87, 18), (90, 18))
    L.lauscher(96, patrol=28, speed=32, reach=96, spread=20)
    L.cp(102)
    L.pit(104, 106); L.bits((105, 17))
    L.pit(107, 111)
    L.andock(108)
    L.bits((113, 19))
    L.pit(115, 118)
    L.mover(115, 18, range_=32, speed=58)
    L.bits((116, 16), (117, 16))
    # Weggabelung: hohe Kette mit Bonus (zweiter Lauscher bewacht den Ausstieg)
    L.plat(124, 127, 17); L.bits((125, 15), (126, 15))
    L.plat(130, 133, 14); L.bits((131, 12), (132, 12)); L.bonus(135, 9)
    L.lauscher(128, patrol=-28, speed=30, reach=92, spread=18)
    L.lauscher(137, ty=12, patrol=-20, speed=26, reach=88, spread=18)
    # Ketsu — schmale Podeste, letzter Lauscher, Portal
    L.lauscher(142, patrol=24, speed=34, reach=96, spread=20)
    L.bits((140, 19), (144, 19), (146, 18))
    L.cp(147)
    L.pillar(149, 18, w=2); L.bits((149, 16), (150, 16))
    L.spikes(151, 152)
    L.pillar(153, 17, w=2); L.bits((153, 15), (154, 15))
    L.pillar(158, 16, w=2); L.bits((158, 14), (159, 14)); L.bonus(161, 12)
    L.spikes(160, 161)
    L.spikes(163, 163); L.bits((164, 19), (166, 19), (168, 18))
    L.cp(170)
    L.sign(172, "Geschafft! Vertraulichkeit heißt: unterwegs liest niemand mit.", "Well done! Confidentiality means nobody reads along on the way.")
    L.door(177)
    j = base_json(L.id)
    return L, j, 14


@builder
def lvl_05():
    """Identität: eGK und SMC-B — zwei Rollen, zwei Karten; dazu Feder, Pendel, Podeste."""
    L = Level("05-identitaet", 176, huelle=True)
    L.player(3)
    L.sign(5, "Vor dir liegt eine Gesundheitskarte. Nimm sie mit!", "There is a health card ahead. Pick it up!")
    L.bits((7, 19), (9, 18))
    L.obj("karte", 10, 18.2, karte="egk", hint={"de": "eGK gefunden — sie weist dich aus. Gespeichert ist auf ihr nichts.", "en": "Found the eGK — it identifies you. It stores nothing."})
    L.obj("kartenleser", 16, 16.9, tw=3, th=3, karten=["egk"], gate="tor-anmeldung", hint={"de": "Karte stecken: TI-Aktion drücken.", "en": "Insert your card: press the TI action."})
    L.obj("gate", 20, 14, th=6, name="tor-anmeldung")
    L.cp(24); L.bits((26, 19))
    # Shō — Lauscher-Korridor, Kette, das zweite Terminal oben
    L.lauscher(28, patrol=40, speed=28, reach=96, spread=20)
    L.plat(34, 37, 17); L.bits((35, 15), (36, 15))
    L.plat(41, 44, 14); L.bits((42, 12), (43, 12)); L.bonus(46, 10)
    L.lauscher(47, patrol=-30, speed=24, reach=88, spread=18)
    L.pit(50, 52); L.bits((49, 18), (51, 17)); L.cp(54)
    L.sign(56, "Noch ein Terminal — oben. Probier deine Karte ruhig aus.", "Another terminal — up there. Go ahead and try your card.")
    L.plat(58, 62, 17)
    L.obj("kartenleser", 59, 13.9, tw=3, th=3, karten=["smcb"], hint={"de": "Dieses Terminal will den Praxisausweis sehen.", "en": "This terminal wants to see the practice card."},
          **{"falsche-karteHint": {"de": "ZUGRIFF VERWEIGERT — die eGK weist DICH aus, nicht die Praxis. Hier braucht es die SMC-B.", "en": "ACCESS DENIED — the eGK identifies YOU, not the practice. This needs the SMC-B."}})
    L.bits((63, 15), (65, 16)); L.bonus(61, 12)
    L.spring(68)
    L.plat(70, 73, 12); L.bits((71, 10), (72, 10)); L.bonus(75, 9)
    L.bits((74, 19), (76, 18))
    L.obj("karte", 78, 18.2, karte="smcb", hint={"de": "SMC-B — der Ausweis der Einrichtung. Eine zweite Rolle, eine zweite Karte.", "en": "SMC-B — the institution's card. A second role needs a second card."})
    L.cp(82)
    # Ten — das Tor der Einrichtung, Andock-Grube, Pendel-Grube
    L.lauscher(86, patrol=26, speed=30, reach=92, spread=18)
    L.obj("kartenleser", 94, 16.9, tw=3, th=3, karten=["smcb"], gate="tor-zugang", gateHint={"de": "Dieses Tor prüft die Einrichtung — steck die SMC-B am Terminal links.", "en": "This gate checks the institution — insert the SMC-B at the terminal on the left."})
    L.obj("gate", 100, 14, th=6, name="tor-zugang")
    L.pit(103, 107)
    L.andock(104)
    L.bits((105, 17))
    L.cp(110)
    L.lauscher(113, patrol=22, speed=32, reach=92, spread=18)
    L.pit(118, 121)
    L.mover(118, 18, range_=48, speed=58)
    L.bits((119, 16), (120, 16))
    # Ketsu — Kette, Podeste, letzter Lauscher, Portal
    L.lauscher(125, patrol=26, speed=32, reach=92, spread=18)
    L.plat(129, 132, 17); L.bits((130, 15), (131, 15))
    L.plat(135, 138, 15); L.bits((136, 13), (137, 13)); L.bonus(140, 11)
    L.pillar(143, 18, w=2); L.bits((143, 16), (144, 16))
    L.spikes(145, 146)
    L.pillar(147, 17, w=1); L.bits((147, 15))
    L.lauscher(153, patrol=20, speed=28, reach=88, spread=18)
    L.bits((151, 19), (155, 19), (158, 18), (161, 19))
    L.cp(159)
    L.sign(164, "Die Karte war der Schlüssel — der Inhalt lag nie auf ihr.", "The card was the key — the content was never on it.")
    L.door(170)
    j = base_json(L.id)
    return L, j, 14


@builder
def lvl_13():
    """e-Rezept (Rechenzentrum): falscher Leser, echtes Terminal, Schacht, Lauscher-Timing."""
    L = Level("13-e-rezept", 176, huelle=True)
    L.player(3)
    L.sign(5, "Das Rezept liegt im Fachdienst, nicht auf der Karte. Die Karte öffnet nur.", "The prescription is in the service, not on the card. The card only opens.")
    L.bits((7, 19), (9, 18))
    L.obj("karte", 12, 18.2, karte="egk")
    L.cp(18); L.bits((15, 19), (20, 19))
    # Shō — Kette über Störfeld, Kriechgang mit falschem Leser, Andock-Grube
    L.lauscher(24, patrol=34, speed=28, reach=92, spread=20)
    L.plat(28, 31, 17); L.bits((29, 15), (30, 15))
    L.spikes(32, 33)
    L.plat(34, 37, 14); L.bits((35, 12), (36, 12)); L.bonus(38, 9)
    L.cp(40)
    L.sign(42, "Vorsicht: Nicht jeder Kartenleser ist echt. Duck dich!", "Careful: not every card reader is genuine. Duck!")
    L.fill(44, 51, 14, 17, "#")
    L.obj("deny-enemy", 47.1, 18.55, fromRight=True, reach=42)
    L.bits((45, 19), (50, 19))
    L.pit(53, 57)
    L.andock(54)
    L.bits((55, 17))
    L.lauscher(60, patrol=30, speed=30, reach=92, spread=18)
    L.cp(64)
    # Ten — das echte Terminal, Pendel-Grube, Bonus-Schacht, Lauscher am Ausstieg
    L.obj("kartenleser", 68, 16.9, tw=3, th=3, karten=["egk"], gate="tor-apotheke", gateHint={"de": "Die Apotheke braucht deine Freigabe — eGK am ECHTEN Terminal stecken.", "en": "The pharmacy needs your release — insert the eGK at the REAL terminal."})
    L.obj("gate", 76, 14, th=6, name="tor-apotheke")
    L.cp(80)
    L.pit(83, 86)
    L.mover(83, 18, range_=48, speed=58)
    L.bits((84, 16), (85, 16))
    L.shaft(90, gap=3, top=8)                    # Säulen 90–91 / 95–96
    L.lauscher(99, patrol=-26, speed=32, reach=92, spread=18)
    L.pit(104, 108)
    L.andock(105)
    L.bits((106, 17))
    L.lauscher(111, patrol=22, speed=26, reach=88, spread=20)
    L.bits((113, 19))
    L.cp(116)
    # Ketsu — Podeste über Störfeldern, hohe Kette mit Bonus, Abstieg zum Portal
    L.pillar(119, 18, w=2); L.bits((119, 16), (120, 16))
    L.spikes(121, 122)
    L.pillar(123, 17, w=2); L.bits((123, 15), (124, 15))
    L.spikes(125, 126)
    L.pillar(127, 16, w=1); L.bits((127, 14))
    L.plat(131, 134, 14); L.bits((132, 12), (133, 12))
    L.plat(138, 141, 11); L.bits((139, 9), (140, 9)); L.bonus(143, 8)
    L.bits((145, 19), (149, 19))
    L.lauscher(147, patrol=22, speed=26, reach=88, spread=20)
    L.bits((153, 19), (157, 18))
    L.cp(155)
    L.sign(160, "Zieh die Karte — der Zugriff endet sofort. Es bleibt nichts zurück.", "Pull the card — access ends immediately. Nothing is left behind.")
    L.door(168)
    j = base_json(L.id)
    return L, j, 14


@builder
def lvl_14():
    """Die VAU (Rechenzentrum): Räume, in denen man im Klartext arbeitet — dazwischen zählt die Hülle."""
    L = Level("14-die-vau", 180, huelle=True)
    L.player(3)
    L.sign(5, "Die VAU ist kein Tunnel, sondern ein Raum: drinnen wird im Klartext gearbeitet.", "The VAU is not a tunnel but a room: inside, work happens in plain text.")
    L.bits((7, 19), (9, 19)); L.cp(14)
    L.lauscher(18, patrol=0, speed=20, reach=88, spread=18)
    L.obj("vau-feld", 24, 15, tw=7, th=5)
    L.bits((26, 18), (28, 18))
    # Shō — VAU-Raum auf der Plattform, Lauscher am Ausstieg
    L.plat(36, 44, 17)
    L.obj("vau-feld", 37, 12, tw=8, th=5, ttlMs=6000)
    L.bits((38, 15), (40, 15), (42, 15))
    L.lauscher(47, ty=15, patrol=0, speed=20, reach=88, spread=18)
    L.cp(49)
    L.sign(51, "Zwischen den Räumen zählt wieder deine eigene Hülle.", "Between the rooms your own shell counts again.")
    L.lauscher(53, patrol=30, speed=30, reach=96, spread=20)
    L.plat(57, 60, 17); L.bits((58, 15), (59, 15)); L.bonus(61, 12)
    L.spikes(62, 63)
    L.lauscher(66, patrol=-26, speed=26, reach=88, spread=18)
    L.bits((64, 19), (69, 19)); L.cp(72)
    # Ten — Andock-Grube mit Wache, Pendel-Grube, hohe VAU mit Kontext-Anker, Feder
    L.pit(78, 82)
    L.andock(79)
    L.bits((80, 17))
    L.lauscher(90, patrol=24, speed=34, reach=96, spread=20)
    L.bits((86, 19), (88, 18))
    L.pit(95, 98)
    L.mover(95, 18, range_=48, speed=58)
    L.bits((96, 16), (97, 16))
    L.plat(102, 104, 17); L.bits((103, 15))
    L.plat(106, 113, 14)
    L.obj("vau-feld", 107, 9, tw=6, th=5, ttlMs=4500)
    L.obj("kontext-anker", 109, 12)
    L.bits((107, 12), (112, 12))
    L.lauscher(115, ty=12, patrol=-20, speed=26, reach=88, spread=18)
    L.bits((116, 19), (118, 19))
    L.spring(121)
    L.plat(123, 126, 12); L.bits((124, 10), (125, 10)); L.bonus(128, 9)
    L.cp(129)
    # Ketsu — Lauscher, Podeste, Portal
    L.lauscher(131, patrol=24, speed=34, reach=96, spread=20)
    L.plat(135, 138, 17); L.bits((136, 15), (137, 15)); L.bonus(137, 12)
    L.pillar(141, 18, w=2); L.bits((141, 16), (142, 16))
    L.spikes(143, 144)
    L.pillar(145, 17, w=2); L.bits((145, 15), (146, 15))
    L.spikes(147, 148)
    L.pillar(149, 16, w=1); L.bits((149, 14))
    L.lauscher(153, patrol=-22, speed=30, reach=92, spread=18)
    L.bits((155, 19), (158, 18), (161, 19))
    L.cp(159)
    L.sign(166, "Drinnen schnell UND unsichtbar. Das kann sonst nichts.", "Inside fast AND invisible. Nothing else can do that.")
    L.door(174)
    j = base_json(L.id)
    return L, j, 14


@builder
def lvl_15():
    """Kontextschlüssel (Rechenzentrum): Sitzungen laufen ab — wer trödelt, wird sichtbar."""
    L = Level("15-kontextschluessel", 182, huelle=True)
    L.player(3)
    L.sign(5, "Der Kontextschlüssel gilt nur eine Weile. Danach bist du wieder sichtbar.", "The context key is valid for a while only. After that you are visible again.")
    L.bits((7, 19), (9, 19)); L.cp(18)
    L.lauscher(26, patrol=0, speed=20, reach=92, spread=20)
    # Shō — großer VAU-Raum mit Plattform und Anker, dann zweite VAU + Andock-Grube
    L.obj("vau-feld", 34, 13, tw=13, th=7, ttlMs=5000)
    L.obj("kontext-anker", 42, 17)
    L.plat(36, 39, 17); L.bits((37, 15), (38, 15))
    L.bits((44, 18), (46, 18)); L.cp(50)
    L.lauscher(52, patrol=28, speed=30, reach=92, spread=18)
    L.spikes(56, 57)
    L.obj("vau-feld", 60, 15, tw=6, th=5, ttlMs=4000)
    L.pit(68, 71)
    L.andock(68)
    L.bits((69, 17))
    L.lauscher(75, patrol=-24, speed=32, reach=96, spread=20)
    L.cp(78)
    # Ten — Pendel-Grube, Bonus-Schacht, hohe VAU-Kette mit Anker
    L.lauscher(82, patrol=22, speed=28, reach=88, spread=18)
    L.pit(86, 89)
    L.mover(86, 18, range_=48, speed=58)
    L.bits((87, 16), (88, 16))
    L.shaft(92, gap=3, top=8)                    # Säulen 92–93 / 97–98
    L.cp(100)
    L.plat(103, 106, 17); L.bits((104, 15), (105, 15))
    L.plat(109, 116, 14)
    L.obj("vau-feld", 110, 9, tw=6, th=5, ttlMs=3500)
    L.obj("kontext-anker", 112, 12)
    L.bits((110, 12), (115, 12))
    L.plat(119, 122, 11); L.bits((120, 9), (121, 9)); L.bonus(124, 8)
    L.lauscher(120, patrol=20, speed=30, reach=92, spread=18)
    L.bits((124, 19), (127, 18))
    # Ketsu — VAU mit knapper Sitzung vor dem Wächter, Podeste, Portal
    L.obj("vau-feld", 134, 15, tw=5, th=5, ttlMs=3500)
    L.lauscher(142, patrol=18, speed=34, reach=92, spread=18)
    L.pillar(145, 18, w=2); L.bits((145, 16), (146, 16))
    L.spikes(147, 148)
    L.pillar(149, 17, w=2); L.bits((149, 15), (150, 15))
    L.spikes(151, 152)
    L.pillar(153, 16, w=1); L.bits((153, 14)); L.bonus(156, 12)
    L.lauscher(158, patrol=-20, speed=30, reach=88, spread=18)
    L.bits((160, 19), (163, 19), (166, 18))
    L.cp(162)
    L.sign(170, "Eine abgelaufene Sitzung schützt nicht — sie fällt in den Klartext.", "An expired session does not protect — it falls back into plain text.")
    L.door(176)
    j = base_json(L.id)
    return L, j, 14


@builder
def lvl_19():
    """Berechtigungen (Archiv): drei Türen, nur DEINE Karte öffnet — Schacht, Podeste, Wachen."""
    L = Level("19-berechtigungen", 176, huelle=True)
    L.player(3)
    L.sign(5, "Drei Türen. Alle drei öffnen nur mit DEINER Karte — keine Praxiskarte hilft hier.", "Three doors. All three open only with YOUR card — no practice card helps here.")
    L.bits((7, 19), (9, 18))
    L.obj("karte", 12, 18.2, karte="egk")
    L.cp(20)
    L.obj("kartenleser", 26, 16.9, tw=3, th=3, karten=["egk"], gate="tor-eins", gateHint={"de": "Nur die Versicherte öffnet — die SMC-B hilft hier nicht.", "en": "Only the insured person opens — the SMC-B does not help here."})
    L.obj("gate", 34, 14, th=6, name="tor-eins")
    # Shō — zweites Terminal oben, Kette, Pendel-Grube
    L.cp(38)
    L.lauscher(42, patrol=26, speed=28, reach=92, spread=20)
    L.plat(46, 49, 17); L.bits((47, 15), (48, 15))
    L.spikes(50, 51)
    L.plat(52, 57, 17)
    L.obj("kartenleser", 54, 13.9, tw=3, th=3, karten=["egk"], gate="tor-zwei")
    L.bits((53, 15), (57, 15))
    L.obj("gate", 62, 14, th=6, name="tor-zwei")
    L.cp(66)
    L.lauscher(68, patrol=-22, speed=30, reach=88, spread=18)
    L.plat(70, 73, 17); L.bits((71, 15), (72, 15))
    L.plat(75, 78, 14); L.bits((76, 12), (77, 12)); L.bonus(79, 10)
    L.pit(80, 83)
    L.mover(80, 18, range_=48, speed=58)
    L.bits((81, 16), (82, 16))
    # Ten — Andock-Grube mit Wache, drittes Terminal
    L.pit(88, 92)
    L.andock(89)
    L.bits((90, 17))
    L.lauscher(96, patrol=20, speed=32, reach=92, spread=18)
    L.cp(99)
    L.obj("kartenleser", 103, 16.9, tw=3, th=3, karten=["egk"], gate="tor-drei")
    L.obj("gate", 109, 14, th=6, name="tor-drei")
    L.cp(112)
    # Ketsu — Bonus-Schacht, Podeste über Störfeldern, Kette, Portal
    L.shaft(114, gap=3, top=8)                   # Säulen 114–115 / 119–120
    L.pillar(124, 18, w=2); L.bits((124, 16), (125, 16))
    L.spikes(126, 127)
    L.pillar(128, 17, w=2); L.bits((128, 15), (129, 15))
    L.spikes(130, 131)
    L.pillar(132, 16, w=1); L.bits((132, 14))
    L.lauscher(136, patrol=22, speed=30, reach=92, spread=18)
    L.plat(140, 143, 17); L.bits((141, 15), (142, 15))
    L.plat(146, 149, 14); L.bits((147, 12), (148, 12)); L.bonus(151, 10)
    L.bits((153, 19), (156, 19), (159, 18))
    L.cp(155)
    L.sign(162, "Und du kannst sie wieder zumachen. Das ist der Unterschied.", "And you can close them again. That is the difference.")
    L.door(168)
    j = base_json(L.id)
    return L, j, 14


@builder
def lvl_20():
    """Souveränität (Archiv): kein Lauscher, kein Tor — nur der Weg, mit Präzision statt Gefahr."""
    L = Level("20-souveraenitaet", 148, huelle=True)
    L.player(3)
    L.sign(5, "Kein Lauscher mehr. Kein Tor. Nur noch der Weg.", "No more eavesdroppers. No gate. Just the path.")
    L.bits((7, 19), (9, 19), (11, 19))
    L.plat(16, 19, 17); L.bits((17, 15), (18, 15))
    L.plat(22, 26, 14); L.bits((23, 12), (24, 12), (25, 12)); L.bonus(28, 11)
    L.cp(30)
    # Shō — Podeste ohne Störfelder (Präzision), die eigene Akte als VAU-Raum
    L.bits((32, 19), (34, 19))
    L.pillar(37, 18, w=2); L.bits((37, 16), (38, 16))
    L.pillar(41, 17, w=1); L.bits((41, 15))
    L.pillar(45, 16, w=1); L.bits((45, 14))
    L.sign(49, "Die Akte gehört dir. Sie wird nicht ohne dich gefüllt.", "The record is yours. It is not filled without you.")
    L.plat(52, 59, 17)
    L.obj("vau-feld", 53, 12, tw=6, th=5)
    L.bits((54, 15), (56, 15), (58, 15))
    L.plat(62, 65, 14); L.bits((63, 12), (64, 12)); L.bonus(66, 10)
    L.cp(68)
    # Ten — Pendel-Grube, Bonus-Schacht, Feder-Hochweg
    L.pit(72, 75)
    L.mover(72, 18, range_=48, speed=58)
    L.bits((73, 16), (74, 16))
    L.shaft(79, gap=3, top=8)                    # Säulen 79–80 / 84–85
    L.spring(89)
    L.plat(91, 94, 12); L.bits((92, 10), (93, 10))
    L.plat(97, 100, 10); L.bits((98, 8), (99, 8)); L.bonus(102, 7)
    L.bits((96, 19), (99, 19), (102, 19))
    L.cp(105)
    L.sign(107, "Du entscheidest, wer hineinsieht — und du kannst es zurücknehmen.", "You decide who looks inside — and you can take it back.")
    # Ketsu — letzte Kette, dann die Tür, die nicht der Spieler öffnet
    L.plat(110, 113, 17); L.bits((111, 15), (112, 15))
    L.plat(117, 120, 14); L.bits((118, 12), (119, 12)); L.bonus(121, 10)
    L.bits((122, 19), (125, 19), (128, 19))
    L.sign(132, "Einfach. Sicher. Digital.", "Simple. Secure. Digital.")
    L.obj("letzte-tuer", 137, 14, th=6)
    j = base_json(L.id)
    return L, j, 14


# --8<-- LEVELS --8<--


def main() -> None:
    # Windows-Konsole (cp1252) kann ✓/✗ nicht — Ausgabe immer als UTF-8
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ok = True
    for build in BUILDERS:
        L, j, wanted = build()
        problems, info = check(L)
        lines = L.lines()
        bits = sum(l.count("o") for l in lines)
        bonus = sum(l.count("*") for l in lines)
        need = count_required(info, wanted)
        j["collectible"]["countRequired"] = need
        j["parTimeSeconds"] = par_seconds(L, j, info)
        j["objects"] = L.objects
        if callable(j.get("_finish")):      # Texte mit Sammelziel (z. B. „… Kacheln reichen") nachziehen
            j.pop("_finish")(j, need)
        d = OUT / L.id
        d.mkdir(parents=True, exist_ok=True)
        (d / "layout.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
        (d / "level.json").write_text(json.dumps(j, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        status = "✓" if not problems else "✗"
        print(f"{status} {L.id:22s} {L.w:3d} breit · {bits:2d} Prüfsummen ({info['bits_easy']} leicht) + {bonus} Bonus"
              f" · Ziel {need} · {info['jumps']:2d} Pflichtsprünge · Par {j['parTimeSeconds']} s")
        for p in problems:
            ok = False
            print("    !", p)
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
