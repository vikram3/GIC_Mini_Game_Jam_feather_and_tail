#!/usr/bin/env python3
"""Feather & Tail - procedural audio generator.

Synthesises every sound in Audio/ from scratch (no samples, no licences):
  music_calm.wav   - gentle garden theme (C major, 92 BPM, 16 bars, loops seamlessly)
  music_tense.wav  - same tempo/length, A minor chase stem. The game cross-fades
                     between the two stems when a teddy starts chasing.
  ambience.wav     - wind, a trickle of water and distant birds (loops)
  sfx_*.wav        - all gameplay / UI sound effects

Run:  python3 tools/make_audio.py      (needs numpy + scipy)
Re-run any time you want to tweak a sound; Godot re-imports the files automatically.
"""
import os
import struct
import numpy as np
from scipy import signal

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Audio")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(20261001)
SR = 22050


def use(sr):
    global SR
    SR = sr


# ------------------------------------------------------------------ basics
def tt(dur):
    return np.arange(int(dur * SR)) / SR


def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def noise(dur):
    return RNG.standard_normal(int(dur * SR))


def bp(x, lo, hi, order=2):
    nyq = SR / 2.0
    hi = min(hi, nyq * 0.95)
    sos = signal.butter(order, [lo / nyq, hi / nyq], btype="band", output="sos")
    return signal.sosfilt(sos, x)


def lp(x, fc, order=2):
    sos = signal.butter(order, min(fc, SR / 2 * 0.95) / (SR / 2), btype="low", output="sos")
    return signal.sosfilt(sos, x)


def hp(x, fc, order=2):
    sos = signal.butter(order, fc / (SR / 2), btype="high", output="sos")
    return signal.sosfilt(sos, x)


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.1):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    a_n, d_n, r_n = max(a_n, 1), max(d_n, 1), max(r_n, 1)
    sus = max(n - a_n - d_n - r_n, 0)
    env = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, s, d_n, endpoint=False),
        np.full(sus, s),
        np.linspace(s, 0, r_n),
    ])
    if len(env) < n:
        env = np.pad(env, (0, n - len(env)))
    return env[:n]


def fade(x, a=0.004, r=0.01):
    x = x.copy()
    an, rn = min(int(a * SR), len(x) // 2), min(int(r * SR), len(x) // 2)
    if an > 0:
        x[:an] *= np.linspace(0, 1, an)
    if rn > 0:
        x[-rn:] *= np.linspace(1, 0, rn)
    return x


def sine(f, dur):
    return np.sin(2 * np.pi * f * tt(dur))


def sweep(f0, f1, dur, expo=True):
    t = tt(dur)
    if expo:
        f = f0 * (f1 / f0) ** (t / max(dur, 1e-6))
    else:
        f = np.linspace(f0, f1, len(t))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def bell(f, dur, decay=3.5, bright=1.0):
    t = tt(dur)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * decay)
    x += 0.35 * bright * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * decay * 1.6)
    x += 0.15 * bright * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * decay * 2.4)
    return fade(x, 0.003, 0.02)


def pluck(f, dur, decay=5.0):
    t = tt(dur)
    x = np.zeros_like(t)
    for k in range(1, 7):
        x += (1.0 / k ** 1.4) * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (decay + 2.0 * k))
    return fade(x, 0.002, 0.02)


def saw(f, dur, detune=0.0):
    t = tt(dur)
    return 2.0 * ((t * f * (1.0 + detune)) % 1.0) - 1.0


def pad_note(f, dur, a=0.6, r=0.9):
    x = (np.sin(2 * np.pi * f * tt(dur)) + 0.5 * np.sin(2 * np.pi * f * 1.004 * tt(dur))
         + 0.18 * np.sin(2 * np.pi * f * 2.0 * tt(dur)))
    return x * adsr(len(x), a, 0.2, 0.85, r)


def place(buf, x, start, gain=1.0):
    i = int(start * SR)
    if i >= len(buf):
        return
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n] * gain


def reverb(x, decay=1.4, wet=0.25, pre=0.012):
    n = int(decay * 1.4 * SR)
    t = np.arange(n) / SR
    ir = RNG.standard_normal(n) * np.exp(-t * (6.0 / decay))
    ir = lp(ir, 5000)
    ir[: int(pre * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wetsig = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - wet * 0.5) + wetsig * wet * 1.6


def fold_loop(buf, length):
    """Wrap the reverb tail past `length` back onto the start so loops are seamless."""
    out = buf[:length].copy()
    tail = buf[length:]
    out[: len(tail)] += tail[: length]
    return out


def crossfade_loop(x, xf):
    """x has length L+xf. Returns length L whose end blends smoothly into its start."""
    L = len(x) - xf
    out = x[:L].copy()
    fi = np.linspace(0, 1, xf)
    out[:xf] = out[:xf] * fi + x[L:] * (1 - fi)
    return out


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def save(name, x, loop=False, peak=0.85):
    x = norm(x, peak)
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if len(data) % 2:
        chunks += b"\0"
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    path = os.path.join(OUT, name)
    with open(path, "wb") as fh:
        fh.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)
    print("  %-28s %5.1fs  %6.0f KB" % (name, len(x) / SR, os.path.getsize(path) / 1024))


# ------------------------------------------------------------------- music
BPM = 92.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 16


def music_calm():
    use(22050)
    L = int(BAR * BARS * SR)
    buf = np.zeros(L + int(3 * SR))
    rng = np.random.default_rng(7)
    # C  Am  F  G  C  Em  F  G   (x2)
    chords = [
        ([60, 64, 67], 36), ([57, 60, 64], 33), ([53, 57, 60], 29 + 12), ([55, 59, 62], 31 + 12),
        ([60, 64, 67], 36), ([52, 55, 59], 40), ([53, 57, 60], 29 + 12), ([55, 59, 62], 31 + 12),
    ] * 2
    penta = [60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84]
    rhythms = [
        [(0, 1.5), (1.5, 0.5), (2, 2)],
        [(0, 1), (1, 1), (2, 2)],
        [(0, 2), (2, 1), (3, 1)],
        [(0, 1), (1.5, 0.5), (2, 1), (3, 1)],
        [(0, 0.5), (0.5, 0.5), (1, 1), (2, 2)],
        [(0, 3), (3, 1)],
    ]
    idx = 5
    for bar in range(BARS):
        notes, root = chords[bar]
        t0 = bar * BAR
        # pad
        for n in notes:
            place(buf, pad_note(mtof(n), BAR + 0.7, 0.7, 1.0), t0, 0.075)
        place(buf, pad_note(mtof(notes[0] - 12), BAR + 0.7, 0.9, 1.0), t0, 0.06)
        # bass: beats 1, 3 (+ off-beat pickup on even bars)
        for b, g in ((0, 1.0), (2, 0.8)):
            x = sine(mtof(root), BEAT * 1.6) * adsr(int(BEAT * 1.6 * SR), 0.01, 0.15, 0.5, 0.35)
            x += 0.25 * sine(mtof(root + 12), BEAT * 1.6) * adsr(int(BEAT * 1.6 * SR), 0.01, 0.1, 0.3, 0.3)
            place(buf, x, t0 + b * BEAT, 0.32 * g)
        if bar % 2 == 1:
            place(buf, sine(mtof(root + 7), BEAT) * adsr(int(BEAT * SR), 0.01, 0.1, 0.4, 0.3), t0 + 3.5 * BEAT, 0.16)
        # arpeggio (eighths)
        pat = [0, 1, 2, 1, 2, 1, 0, 1] if bar % 2 == 0 else [0, 2, 1, 2, 1, 2, 1, 0]
        for i, p in enumerate(pat):
            n = notes[p] + 12
            g = 0.13 if i % 4 == 0 else 0.085
            if bar >= 8:
                g *= 1.15
            place(buf, pluck(mtof(n), BEAT * 1.4, 6.0), t0 + i * BEAT * 0.5, g)
        # melody (enters bar 3, fuller in the second half)
        if bar >= 2 and not (bar in (7, 15) and False):
            rh = rhythms[rng.integers(len(rhythms))]
            first = True
            for off, dur in rh:
                if first:
                    cands = [i for i, m in enumerate(penta) if (m % 12) in [n % 12 for n in notes]]
                    idx = min(cands, key=lambda i: abs(i - idx))
                    first = False
                else:
                    idx = int(np.clip(idx + rng.choice([-2, -1, -1, 0, 1, 1, 2]), 2, len(penta) - 1))
                m = penta[idx]
                place(buf, bell(mtof(m), max(dur * BEAT * 1.6, 0.8), 3.2), t0 + off * BEAT, 0.16)
                if bar >= 8 and off == 0:
                    place(buf, bell(mtof(m - 12), 1.2, 3.0), t0 + off * BEAT, 0.07)
        # shaker + woodblock
        for i in range(8):
            if i % 2 == 1 or bar >= 4:
                h = hp(noise(0.06), 6000) * np.exp(-tt(0.06) * 60)
                place(buf, h, t0 + i * BEAT * 0.5, 0.05 if i % 2 else 0.03)
        if bar >= 4:
            wb = sine(1250, 0.07) * np.exp(-tt(0.07) * 45)
            place(buf, wb, t0 + 3 * BEAT, 0.07)
        # soft kick in the second half
        if bar >= 8:
            for b in (0, 2):
                k = sweep(110, 48, 0.28) * np.exp(-tt(0.28) * 9)
                place(buf, k, t0 + b * BEAT, 0.22)
    buf = reverb(buf, 1.8, 0.28)
    out = fold_loop(buf, L)
    save("music_calm.wav", out, loop=True, peak=0.7)


def music_tense():
    use(22050)
    L = int(BAR * BARS * SR)
    buf = np.zeros(L + int(3 * SR))
    # Am Am F E | Am Dm F E  (x2)
    chords = [
        ([57, 60, 64], 33), ([57, 60, 64], 33), ([53, 57, 60], 41), ([52, 56, 59], 40),
        ([57, 60, 64], 33), ([50, 53, 57], 38), ([53, 57, 60], 41), ([52, 56, 59], 40),
    ] * 2
    for bar in range(BARS):
        notes, root = chords[bar]
        t0 = bar * BAR
        # string pad with tremolo
        for n in notes:
            f = mtof(n)
            x = (saw(f, BAR + 0.3, 0.003) + saw(f, BAR + 0.3, -0.003)) * 0.5
            x = lp(x, 1100)
            x *= (0.75 + 0.25 * np.sin(2 * np.pi * 6.0 * tt(BAR + 0.3)))
            x *= adsr(len(x), 0.25, 0.2, 0.85, 0.25)
            place(buf, x, t0, 0.07)
        # drone
        d = sine(mtof(root - 12 if root > 36 else root), BAR + 0.4)
        d *= adsr(len(d), 0.3, 0.2, 0.9, 0.3)
        place(buf, d, t0, 0.3)
        # driving eighth-note bass
        for i in range(8):
            f = mtof(root + (0 if i % 4 != 3 else 12))
            x = lp(saw(f, BEAT * 0.45), 500) * adsr(int(BEAT * 0.45 * SR), 0.005, 0.08, 0.4, 0.12)
            place(buf, x, t0 + i * BEAT * 0.5, 0.22 if i % 2 == 0 else 0.14)
        # heartbeat "lub-dub"
        for b in range(4):
            for off, g in ((0.0, 0.34), (0.32, 0.2)):
                k = sweep(95, 42, 0.22) * np.exp(-tt(0.22) * 12)
                place(buf, k, t0 + b * BEAT + off * BEAT, g)
        # ticking 16ths
        for i in range(16):
            tick = hp(noise(0.03), 7000) * np.exp(-tt(0.03) * 120)
            place(buf, tick, t0 + i * BEAT * 0.25, 0.05 if i % 4 else 0.08)
        # nervous high stab on beat 4 every other bar
        if bar % 2 == 1:
            for n in notes:
                place(buf, pluck(mtof(n + 24), 0.6, 9.0), t0 + 3 * BEAT, 0.09)
        # riser into the loop point
        if bar in (7, 15):
            r = bp(noise(BAR), 400, 6000, 2) * np.linspace(0, 1, int(BAR * SR)) ** 2
            place(buf, r, t0, 0.18)
    buf = reverb(buf, 1.1, 0.18)
    out = fold_loop(buf, L)
    save("music_tense.wav", out, loop=True, peak=0.7)


def ambience():
    use(22050)
    dur, xf = 28.0, 2.0
    n = int((dur + xf) * SR)
    t = np.arange(n) / SR
    wind = bp(RNG.standard_normal(n), 120, 900, 2)
    wind *= 0.6 + 0.4 * np.sin(2 * np.pi * t / 9.0 + 1.0) * np.sin(2 * np.pi * t / 5.3)
    leaves = bp(RNG.standard_normal(n), 2500, 7000, 2) * (0.25 + 0.2 * np.sin(2 * np.pi * t / 6.7) ** 2) * 0.35
    water = bp(RNG.standard_normal(n), 900, 3500, 2)
    water *= (0.5 + 0.5 * np.abs(signal.sosfilt(
        signal.butter(2, 14 / (SR / 2), output="sos"), RNG.standard_normal(n)) * 6.0)).clip(0, 1) * 0.18
    mix = wind * 0.32 + leaves + water
    # birds
    birds = np.zeros(n)
    for _ in range(26):
        st = RNG.uniform(0.5, dur + xf - 1.0)
        base = RNG.uniform(2200, 4200)
        for k in range(RNG.integers(2, 5)):
            d = RNG.uniform(0.06, 0.13)
            tc = np.arange(int(d * SR)) / SR
            f = base * (1 + 0.35 * np.sin(np.pi * tc / d) + RNG.uniform(-0.1, 0.25) * tc / d)
            f = f * (1 + 0.03 * np.sin(2 * np.pi * 38 * tc))
            c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tc / d) ** 2
            i0 = int((st + k * (d + 0.045)) * SR)
            if i0 + len(c) < n:
                birds[i0:i0 + len(c)] += c * 0.08
    mix = mix + birds
    out = crossfade_loop(mix, int(xf * SR))
    save("ambience.wav", out, loop=True, peak=0.6)


# --------------------------------------------------------------------- sfx
def sfx():
    use(44100)

    def s(name, x, peak=0.8):
        save("sfx_%s.wav" % name, fade(x, 0.002, 0.012), peak=peak)

    # UI
    s("ui_hover", sine(1500, 0.05) * np.exp(-tt(0.05) * 60), 0.35)
    x = np.zeros(int(0.3 * SR))
    place(x, pluck(660, 0.25, 9), 0, 1)
    place(x, pluck(990, 0.22, 9), 0.055, 0.8)
    s("ui_click", x, 0.6)
    x = np.zeros(int(0.5 * SR))
    place(x, bell(523.25, 0.4, 7), 0, 1)
    place(x, bell(392.0, 0.4, 7), 0.07, 0.8)
    s("pause_open", x, 0.5)
    x = np.zeros(int(0.5 * SR))
    place(x, bell(392.0, 0.4, 7), 0, 0.8)
    place(x, bell(523.25, 0.4, 7), 0.07, 1)
    s("pause_close", x, 0.5)

    # characters
    sw = np.zeros(int(0.6 * SR))
    place(sw, bp(noise(0.3), 300, 2500) * np.sin(np.linspace(0, np.pi, int(0.3 * SR))) ** 2, 0, 0.5)
    place(sw, bell(523.25, 0.45, 6), 0, 0.5)
    place(sw, bell(783.99, 0.4, 6), 0.09, 0.45)
    s("swap", sw, 0.6)

    x = np.zeros(int(0.7 * SR))
    for st, base, d in ((0.0, 2600, 0.11), (0.15, 3100, 0.11), (0.31, 3600, 0.17)):
        tc = np.arange(int(d * SR)) / SR
        f = base * (1 + 0.45 * np.sin(np.pi * tc / d)) * (1 + 0.04 * np.sin(2 * np.pi * 30 * tc))
        c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tc / d) ** 1.5
        place(x, c, st, 1)
    s("chirp", x, 0.65)

    # hedge cutting
    x = np.zeros(int(0.55 * SR))
    for st in (0.0, 0.09):
        place(x, bp(noise(0.05), 3000, 9000) * np.exp(-tt(0.05) * 70), st, 1)
        place(x, sine(4200, 0.08) * np.exp(-tt(0.08) * 50), st, 0.5)
    place(x, bp(noise(0.4), 500, 3500) * np.sin(np.linspace(0, np.pi, int(0.4 * SR))) * np.exp(-tt(0.4) * 5), 0.1, 0.7)
    s("snip", x, 0.8)
    s("scrape", bp(noise(0.08), 2000, 7000) * np.sin(np.linspace(0, np.pi, int(0.08 * SR))), 0.35)
    s("rustle", bp(noise(0.32), 700, 4500) * np.sin(np.linspace(0, np.pi, int(0.32 * SR))) ** 1.5, 0.4)

    # traps
    x = (sine(1800, 0.06) + 0.6 * sine(2790, 0.06)) * np.exp(-tt(0.06) * 55)
    s("disarm_tick", x, 0.45)
    x = np.zeros(int(0.7 * SR))
    for i, f in enumerate((783.99, 1046.5, 1318.5)):
        place(x, bell(f, 0.5, 5), i * 0.07, 0.8)
    s("disarm_done", x, 0.6)
    x = np.zeros(int(0.7 * SR))
    for st in (0.0, 0.2):
        place(x, lp(saw(330, 0.12), 1800) * adsr(int(0.12 * SR), 0.005, 0.05, 0.6, 0.04), st, 1)
    s("danger", x, 0.6)

    # fruit
    x = np.zeros(int(0.7 * SR))
    place(x, bp(noise(0.07), 900, 5000) * np.exp(-tt(0.07) * 45), 0.0, 1.0)
    place(x, sweep(380, 900, 0.09) * np.exp(-tt(0.09) * 22), 0.0, 0.7)
    place(x, bell(1318.5, 0.5, 6), 0.05, 0.8)
    s("pickup_apple", x, 0.7)
    x = np.zeros(int(0.9 * SR))
    for i, f in enumerate((987.77, 1318.5, 1568.0)):
        place(x, bell(f, 0.6, 4.5), i * 0.075, 0.7)
    place(x, hp(noise(0.5), 7000) * np.exp(-tt(0.5) * 8), 0.1, 0.04)
    s("pickup_pear", x, 0.7)
    x = np.zeros(int(1.8 * SR))
    for i, m in enumerate((72, 76, 79, 84, 88, 91, 96)):
        place(x, bell(mtof(m), 0.9, 3.5), i * 0.085, 0.7)
    place(x, hp(noise(1.2), 6000) * np.exp(-tt(1.2) * 3.2), 0.2, 0.05)
    s("exit_open", x, 0.75)
    x = sweep(170, 80, 0.16) * np.exp(-tt(0.16) * 18)
    place(x, lp(noise(0.05), 1500) * np.exp(-tt(0.05) * 60), 0, 0.5)
    s("locked", x, 0.7)

    # command acknowledgement / refusal
    x = np.zeros(int(0.3 * SR))
    place(x, bell(880, 0.22, 10), 0, 0.8)
    place(x, bell(1174.7, 0.22, 10), 0.07, 0.8)
    s("command", x, 0.45)
    x = np.zeros(int(0.35 * SR))
    for st, f in ((0.0, 233), (0.11, 185)):
        place(x, lp(saw(f, 0.12), 900) * adsr(int(0.12 * SR), 0.005, 0.04, 0.6, 0.05), st, 1)
    s("deny", x, 0.5)

    # teddies
    x = np.zeros(int(0.5 * SR))
    place(x, sine(440, 0.14) * adsr(int(0.14 * SR), 0.01, 0.03, 0.7, 0.07), 0.0, 0.7)
    place(x, sine(587.33, 0.22) * adsr(int(0.22 * SR), 0.01, 0.03, 0.7, 0.14), 0.13, 0.7)
    s("notice", x, 0.55)
    x = np.zeros(int(0.6 * SR))
    place(x, lp(saw(220, 0.4), 2500) * np.exp(-tt(0.4) * 7), 0, 0.8)
    place(x, lp(saw(329.6, 0.4), 2500) * np.exp(-tt(0.4) * 7), 0, 0.6)
    place(x, bell(880, 0.5, 6), 0.0, 0.5)
    s("alert", x, 0.8)
    t = tt(0.6)
    x = np.sin(2 * np.pi * np.cumsum(520 * np.exp(-t * 1.8) * (1 + 0.04 * np.sin(2 * np.pi * 9 * t))) / SR)
    x *= adsr(len(t), 0.01, 0.1, 0.6, 0.3)
    place(x, bell(260, 0.4, 8), 0.0, 0.3)
    s("caught", x, 0.6)
    x = sweep(130, 45, 0.5) * np.exp(-tt(0.5) * 6)
    y = np.zeros(int(1.6 * SR))
    place(y, x, 0, 1.0)
    for i, m in enumerate((67, 63, 60)):
        place(y, bell(mtof(m), 1.0, 2.5), 0.25 + i * 0.32, 0.55)
    s("harmed", y, 0.8)
    x = lp(noise(0.1), 700) * np.exp(-tt(0.1) * 40)
    place(x, sine(95, 0.1) * np.exp(-tt(0.1) * 35), 0, 0.8)
    s("guard_step", x, 0.4)

    # footsteps
    for i, fc in enumerate((900, 700, 1100)):
        x = lp(noise(0.09), fc) * np.exp(-tt(0.09) * 38)
        place(x, sine(120 + i * 12, 0.08) * np.exp(-tt(0.08) * 40), 0, 0.6)
        s("step%d" % (i + 1), x, 0.4)
    for i, f in enumerate((240, 285)):
        x = bp(noise(0.08), 400, 1500) * np.exp(-tt(0.08) * 45)
        place(x, sine(f, 0.09) * np.exp(-tt(0.09) * 38), 0, 0.8)
        s("step_wood%d" % (i + 1), x, 0.45)
    s("flap", bp(noise(0.2), 250, 1800) * np.sin(np.linspace(0, np.pi, int(0.2 * SR))) ** 2, 0.22)

    # jingles
    x = np.zeros(int(4.2 * SR))
    mel = [(72, 0.0, 0.4), (76, 0.28, 0.4), (79, 0.56, 0.4), (84, 0.84, 0.5),
           (83, 1.3, 0.3), (84, 1.55, 0.3), (88, 1.8, 0.9)]
    for m, st, d in mel:
        place(x, bell(mtof(m), 1.3, 3.2), st, 0.7)
        place(x, pluck(mtof(m - 12), 1.0, 4), st, 0.35)
    for m in (60, 64, 67, 72, 76):
        place(x, bell(mtof(m), 2.4, 1.8), 1.8, 0.35)
    place(x, hp(noise(2.0), 6000) * np.exp(-tt(2.0) * 2.2), 1.8, 0.04)
    x = reverb(x, 1.8, 0.3)
    s("win", x, 0.85)
    y = np.zeros(int(3.4 * SR))
    for m, st, d in [(67, 0.0, 0.6), (63, 0.5, 0.6), (60, 1.0, 0.6), (55, 1.6, 1.4)]:
        place(y, bell(mtof(m), 1.4, 2.4), st, 0.7)
        place(y, pad_note(mtof(m - 12), 1.4, 0.05, 0.6), st, 0.12)
    y = reverb(y, 1.6, 0.3)
    s("lose", y, 0.8)


if __name__ == "__main__":
    print("Generating Feather & Tail audio into", os.path.abspath(OUT))
    music_calm()
    music_tense()
    ambience()
    sfx()
    print("done.")
