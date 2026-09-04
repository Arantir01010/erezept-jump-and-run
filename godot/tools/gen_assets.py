"""
Asset-Generator: erzeugt alle Binär-Assets der Godot-Fassung aus Code —
keine Lizenzfragen, reproduzierbar, offline.

    python godot/tools/gen_assets.py

Erzeugt:
    godot/assets/audio/*.wav     Klänge (Sprung, Landung, Sammeln, …) + Musikschleifen
    godot/assets/qr/reward.png   Offline-QR-Code für den Reward-Screen (statischer Gewinncode)

Alle Klänge sind synthetisiert (Sinus/Rechteck/Dreieck/Rauschen mit Hüllkurven).
Die Musik ist eine kurze, nahtlos loopende Chiptune-Schleife (Am–F–C–G),
bewusst leise gemischt: Rückmeldung und Stimmung, kein Ohrwurm-Zwang am Stand.
"""
from __future__ import annotations

import json
import math
import struct
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
GODOT = ROOT / "godot"
AUDIO = GODOT / "assets" / "audio"
QR_DIR = GODOT / "assets" / "qr"
SR = 44100


# ------------------------------------------------------------------ Synthese

def env(n: int, attack: float, decay: float, sustain: float = 0.0, release: float = 0.0) -> np.ndarray:
    """ADSR-artige Hüllkurve in Sekunden, Ergebnislänge n Samples."""
    t = np.arange(n) / SR
    total = n / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.where(t < attack, 1.0, np.clip(1 - (t - attack) / max(decay, 1e-4) * (1 - sustain), sustain, 1.0))
    r_start = max(total - release, 0)
    r = np.where(t > r_start, np.clip(1 - (t - r_start) / max(release, 1e-4), 0, 1), 1.0)
    return a * d * r


def tone(freq_from: float, freq_to: float, dur: float, kind: str = "sine", curve: float = 1.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    p = (t / dur) ** curve
    freq = freq_from * (freq_to / freq_from) ** p if freq_from > 0 and freq_to > 0 else np.full(n, freq_from)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    if kind == "sine":
        return np.sin(phase)
    if kind == "square":
        return np.sign(np.sin(phase)) * 0.6
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if kind == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    raise ValueError(kind)


def noise(dur: float, cutoff: float, seed: int = 1) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    x = rng.uniform(-1, 1, n)
    # einfacher Ein-Pol-Tiefpass
    alpha = math.exp(-2 * math.pi * cutoff / SR)
    y = np.empty(n)
    acc = 0.0
    for i in range(n):
        acc = alpha * acc + (1 - alpha) * x[i]
        y[i] = acc
    return y / (np.max(np.abs(y)) + 1e-9)


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def normalize(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def write_wav(name: str, data: np.ndarray, peak: float = 0.9) -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    data = normalize(data, peak)
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(str(AUDIO / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  ♪ {name}  ({len(data) / SR:.2f} s)")


# ------------------------------------------------------------------ Klänge

def sfx() -> None:
    # Sprung: heller Chirp aufwärts
    j = tone(320, 760, 0.14, "tri") * env(int(0.14 * SR), 0.005, 0.12)
    write_wav("jump.wav", j, 0.6)
    # REZI-Schub (Doppelsprung): zwei Töne + Schimmer
    d = mix(tone(520, 1040, 0.16, "tri") * env(int(0.16 * SR), 0.004, 0.14),
            tone(1560, 2080, 0.12, "sine") * env(int(0.12 * SR), 0.01, 0.1) * 0.35)
    write_wav("double_jump.wav", d, 0.6)
    # Landung: weicher Boden-Thump
    l = noise(0.09, 320, seed=3) * env(int(0.09 * SR), 0.002, 0.08)
    write_wav("land.wav", l, 0.5)
    # Sammeln: Zwei-Ton-Blip (Tonhöhe variiert die Engine per pitch_scale)
    c = mix(tone(880, 880, 0.05, "sine") * env(int(0.05 * SR), 0.002, 0.05),
            np.concatenate([np.zeros(int(0.045 * SR)), tone(1320, 1320, 0.08, "sine") * env(int(0.08 * SR), 0.002, 0.07)]))
    write_wav("collect.wav", c, 0.55)
    # Bonus-Bit: kleines Arpeggio
    b = np.concatenate([tone(f, f, 0.06, "tri") * env(int(0.06 * SR), 0.002, 0.06) for f in (784, 988, 1175, 1568)])
    write_wav("bonus.wav", b, 0.6)
    # Treffer: fallender Brumm
    h = tone(300, 70, 0.28, "saw") * env(int(0.28 * SR), 0.002, 0.26) * 0.7
    write_wav("hurt.wav", h, 0.7)
    # ZUGRIFF VERWEIGERT: Buzzer mit Tremolo
    n = int(0.32 * SR)
    trem = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 18 * np.arange(n) / SR))
    dz = tone(140, 120, 0.32, "square") * env(n, 0.002, 0.3) * trem
    write_wav("deny.wav", dz, 0.6)
    # Tor öffnet: aufsteigende Quinte
    g = mix(tone(440, 440, 0.16, "tri") * env(int(0.16 * SR), 0.005, 0.15),
            np.concatenate([np.zeros(int(0.12 * SR)), tone(660, 660, 0.3, "tri") * env(int(0.3 * SR), 0.005, 0.28)]))
    write_wav("gate.wav", g, 0.6)
    # Siegel: Stempel-Thunk + Glanzton
    s = mix(noise(0.12, 400, seed=7) * env(int(0.12 * SR), 0.001, 0.1) * 1.2,
            tone(90, 60, 0.18, "sine") * env(int(0.18 * SR), 0.001, 0.16),
            np.concatenate([np.zeros(int(0.08 * SR)), tone(1318, 1318, 0.6, "sine") * env(int(0.6 * SR), 0.01, 0.55) * 0.5]),
            np.concatenate([np.zeros(int(0.16 * SR)), tone(1976, 1976, 0.5, "sine") * env(int(0.5 * SR), 0.01, 0.45) * 0.3]))
    write_wav("seal.wav", s, 0.8)
    # Hülle an (verschlüsseln): Sweep hoch mit Rauschschleier
    on = mix(tone(240, 960, 0.22, "tri") * env(int(0.22 * SR), 0.004, 0.2),
             noise(0.22, 3000, seed=11) * env(int(0.22 * SR), 0.01, 0.2) * 0.25)
    write_wav("toggle_on.wav", on, 0.55)
    off = mix(tone(960, 240, 0.2, "tri") * env(int(0.2 * SR), 0.004, 0.18),
              noise(0.2, 1500, seed=12) * env(int(0.2 * SR), 0.01, 0.18) * 0.2)
    write_wav("toggle_off.wav", off, 0.55)
    # VAU betreten: warmer Akkord
    v = mix(*[tone(f, f, 0.5, "sine") * env(int(0.5 * SR), 0.03, 0.45) for f in (523, 659, 784)])
    write_wav("vau.wav", v, 0.5)
    # Checkpoint: sanfte Glocke
    cp = mix(tone(1047, 1047, 0.35, "sine") * env(int(0.35 * SR), 0.003, 0.33),
             tone(2093, 2093, 0.2, "sine") * env(int(0.2 * SR), 0.003, 0.18) * 0.3)
    write_wav("checkpoint.wav", cp, 0.5)
    # Sprungfeder
    sp = tone(200, 900, 0.18, "square") * env(int(0.18 * SR), 0.003, 0.16) * 0.5
    write_wav("spring.wav", sp, 0.55)
    # UI-Klick
    ui = tone(1200, 900, 0.05, "sine") * env(int(0.05 * SR), 0.001, 0.045)
    write_wav("ui.wav", ui, 0.5)
    # Timing-Licht (Takt) und Treffer im Fenster
    tk = tone(660, 660, 0.06, "tri") * env(int(0.06 * SR), 0.002, 0.05)
    write_wav("tick.wav", tk, 0.45)
    ok = mix(tone(880, 880, 0.08, "tri") * env(int(0.08 * SR), 0.002, 0.07),
             np.concatenate([np.zeros(int(0.06 * SR)), tone(1320, 1320, 0.1, "tri") * env(int(0.1 * SR), 0.002, 0.09)]))
    write_wav("ok.wav", ok, 0.55)
    # Medaille / Kartenauswertung
    md = np.concatenate([tone(f, f, 0.09, "tri") * env(int(0.09 * SR), 0.003, 0.085) for f in (659, 880, 1319)])
    write_wav("medal.wav", md, 0.6)
    # Wandrutsch-Kratzen (leise, wird gelooped)
    ws = noise(0.3, 900, seed=21) * 0.4
    write_wav("wallslide.wav", ws, 0.35)


# ------------------------------------------------------------------ Musik

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name: str) -> float:
    """Notenname wie 'A3' → Frequenz."""
    letter = name[:-1]
    octave = int(name[-1])
    semis = NOTE[letter] + (octave - 4) * 12 - 9  # A4 = 440
    return 440.0 * 2 ** (semis / 12)


def note_wave(f: float, dur: float, kind: str, a: float, d: float, sus: float, rel: float, vol: float) -> np.ndarray:
    n = int(dur * SR)
    return tone(f, f, dur, kind) * env(n, a, d, sus, rel) * vol


def music(name: str, bpm: int, chords: list[tuple[str, list[str], str]], bars_per_chord: int, calm: bool) -> None:
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * bars_per_chord * len(chords)
    n = int(total * SR)
    out = np.zeros(n)

    def place(sig: np.ndarray, at: float) -> None:
        i = int(at * SR)
        j = min(n, i + len(sig))
        if i < n:
            out[i:j] += sig[: j - i]

    rng = np.random.default_rng(5)
    for ci, (root, chord_notes, bass) in enumerate(chords):
        start = ci * bars_per_chord * bar
        for b in range(bars_per_chord):
            bs = start + b * bar
            # Pad: Akkord, weich, lange Hüllkurve
            for cn in chord_notes:
                place(note_wave(freq(cn), bar, "sine", 0.25, 0.4, 0.8, 0.35, 0.05 if calm else 0.04), bs)
                place(note_wave(freq(cn) * 2, bar, "tri", 0.3, 0.4, 0.6, 0.35, 0.012), bs)
            # Bass: Achtel auf Grundton, Oktavwechsel
            if not calm:
                for e in range(8):
                    f = freq(bass) * (2 if e % 4 == 3 else 1)
                    place(note_wave(f, beat / 2 * 0.9, "square", 0.004, 0.12, 0.35, 0.05, 0.11), bs + e * beat / 2)
            else:
                for e in range(2):
                    place(note_wave(freq(bass), beat * 2 * 0.95, "tri", 0.02, 0.6, 0.5, 0.3, 0.1), bs + e * beat * 2)
            # Arpeggio: Sechzehntel über den Akkord (+ Oktave)
            arp = [freq(x) * 2 for x in chord_notes] + [freq(chord_notes[0]) * 4]
            pattern = [0, 1, 2, 3, 2, 1, 0, 2] if not calm else [0, 2, 1, 3]
            step = beat / 4 if not calm else beat
            for e in range(int(bar / step)):
                f = arp[pattern[e % len(pattern)] % len(arp)]
                vol = 0.05 if not calm else 0.035
                if not calm and e % 8 == 0:
                    vol *= 1.3
                place(note_wave(f, step * 0.8, "tri", 0.003, 0.09, 0.2, 0.03, vol), bs + e * step)
            # Schlagzeug: Kick auf 1 und 3, Hat auf Achteln, Snare-Rauschen auf 2 und 4
            if not calm:
                for k in (0, 2):
                    kick = tone(150, 45, 0.16, "sine") * env(int(0.16 * SR), 0.001, 0.14) * 0.5
                    place(kick, bs + k * beat)
                for s_ in (1, 3):
                    sn = noise(0.12, 2500, seed=int(rng.integers(1, 1000))) * env(int(0.12 * SR), 0.001, 0.1) * 0.22
                    place(sn, bs + s_ * beat)
                for e in range(8):
                    hat = noise(0.03, 8000, seed=int(rng.integers(1, 1000))) * env(int(0.03 * SR), 0.001, 0.025) * (0.1 if e % 2 else 0.14)
                    place(hat, bs + e * beat / 2)

    # nahtlos: Ausklang der letzten Noten auf den Anfang falten
    tail = int(0.4 * SR)
    fold = out[n:] if len(out) > n else None
    out = out[:n]
    # sanfter Loop-Übergang
    fade = np.linspace(0, 1, tail)
    out[:tail] = out[:tail] * fade + out[-tail:] * (1 - fade) * 0.5
    write_wav(name, out, 0.6)


def music_all() -> None:
    # Hauptschleife: Am – F – C – G, 124 BPM, je 2 Takte → 8 Takte ≈ 15,5 s
    music("music_level.wav", 124, [
        ("A", ["A3", "C4", "E4"], "A2"),
        ("F", ["F3", "A3", "C4"], "F2"),
        ("C", ["C4", "E4", "G4"], "C3"),
        ("G", ["G3", "B3", "D4"], "G2"),
    ], 2, calm=False)
    # Titel/Reward: ruhiger, ohne Schlagzeug
    music("music_title.wav", 92, [
        ("C", ["C4", "E4", "G4"], "C3"),
        ("A", ["A3", "C4", "E4"], "A2"),
        ("F", ["F3", "A3", "C4"], "F2"),
        ("G", ["G3", "B3", "D4"], "G2"),
    ], 2, calm=True)


# ------------------------------------------------------------------ QR-Code

def qr() -> None:
    import qrcode
    from qrcode.constants import ERROR_CORRECT_M

    cfg = json.loads((GODOT / "config" / "game-config.json").read_text(encoding="utf-8"))
    payload = cfg.get("ending", {}).get("staticPayload", "EREZEPT-MESSE-GEWINN")
    q = qrcode.QRCode(error_correction=ERROR_CORRECT_M, box_size=12, border=2)
    q.add_data(payload)
    q.make(fit=True)
    img = q.make_image(fill_color="black", back_color="white")
    QR_DIR.mkdir(parents=True, exist_ok=True)
    img.save(QR_DIR / "reward.png")
    print(f"  ▦ qr/reward.png  ({payload}, {img.size[0]}×{img.size[1]} px)")


if __name__ == "__main__":
    print("Klänge:")
    sfx()
    print("Musik:")
    music_all()
    print("QR:")
    qr()
