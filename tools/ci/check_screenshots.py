#!/usr/bin/env python3
"""Checks the screenshots a windowed autoplay run saved (KIT-08).

    check_screenshots.py WIDTHxHEIGHT DIR

DIR must hold 1-start.png, 2-run.png and 3-summary.png, each exactly the stated
size and not blank. shortcut: "not blank" is a size floor (a flat-colour frame
compresses far below it), upgrade when a screen can legitimately be that plain.
"""
import os
import struct
import sys

NAMES = ("1-start.png", "2-run.png", "3-summary.png")
MIN_BYTES = 8000
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != PNG_SIGNATURE or head[12:16] != b"IHDR":
        sys.exit(f"::error::{path} is not a PNG")
    return struct.unpack(">II", head[16:24])


def main(argv):
    if len(argv) != 3 or "x" not in argv[1]:
        sys.exit("usage: check_screenshots.py WIDTHxHEIGHT DIR")
    want = tuple(int(n) for n in argv[1].split("x"))
    problems = []
    for name in NAMES:
        path = os.path.join(argv[2], name)
        if not os.path.isfile(path):
            problems.append(f"{path} is missing")
            continue
        got = png_size(path)
        size = os.path.getsize(path)
        print(f"{path}: {got[0]}x{got[1]}, {size} bytes")
        if got != want:
            problems.append(f"{path} is {got[0]}x{got[1]}, wanted {want[0]}x{want[1]}")
        if size < MIN_BYTES:
            problems.append(f"{path} looks blank ({size} bytes)")
    for problem in problems:
        print(f"::error::{problem}")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main(sys.argv)
