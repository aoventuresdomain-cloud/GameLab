#!/usr/bin/env python3
"""Writes the four placeholder sound effects to assets/audio/ (hit, gold, level, boss).

The sounds are synthesised here from sine waves and seeded noise, so they are made for this
project and dedicated to the public domain (CC0). Run from games/holdfast:

    python3 tools/make_sounds.py

The output is the same every run. Replace a file with a recorded CC0 sound later by keeping its
name; assets/CREDITS.md lists where each one came from.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def tone(freq, seconds, volume=0.5, decay=6.0):
    n = int(RATE * seconds)
    return [volume * math.sin(2 * math.pi * freq * i / RATE) * math.exp(-decay * i / n) for i in range(n)]


def noise(seconds, volume=0.5, decay=10.0, seed=1):
    rng = random.Random(seed)
    n = int(RATE * seconds)
    return [volume * (rng.random() * 2 - 1) * math.exp(-decay * i / n) for i in range(n)]


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def after(seconds, samples):
    return [0.0] * int(RATE * seconds) + samples


def write(name, samples):
    peak = max(1.0, max(abs(s) for s in samples))
    frames = b"".join(struct.pack("<h", int(32767 * 0.8 * s / peak)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


os.makedirs(OUT, exist_ok=True)
write("hit", mix(noise(0.09, 0.6, 12.0), tone(180, 0.09, 0.5, 14.0)))
write("gold", mix(tone(988, 0.16, 0.4, 7.0), after(0.07, tone(1319, 0.22, 0.4, 6.0))))
write("level", mix(tone(523, 0.12, 0.4, 5.0), after(0.1, tone(659, 0.12, 0.4, 5.0)), after(0.2, tone(784, 0.3, 0.4, 4.0))))
write("boss", mix(tone(82, 0.9, 0.6, 3.0), tone(110, 0.9, 0.4, 3.5), after(0.25, tone(65, 0.65, 0.5, 3.0))))
