#!/usr/bin/env python3
"""Fails unless two progression reports carry the same full hash (KIT-08).

    compare_progression.py LINUX_REPORT.json WINDOWS_REPORT.json

Prints both hashes in full, so each CI log shows them. Only the hash is compared:
the reports also hold wall-clock time, which differs between machines.
"""
import json
import re
import sys

HASH = re.compile(r"[0-9a-f]{64}")


def read_hash(path):
    with open(path, encoding="utf-8") as f:
        value = json.load(f).get("hash", "")
    if not HASH.fullmatch(value):
        sys.exit(f"::error::{path} has no full 64-character report hash (got {value!r})")
    return value


def main(argv):
    if len(argv) != 3:
        sys.exit("usage: compare_progression.py LINUX_REPORT.json WINDOWS_REPORT.json")
    linux, windows = read_hash(argv[1]), read_hash(argv[2])
    print(f"Linux   report hash: {linux}")
    print(f"Windows report hash: {windows}")
    if linux != windows:
        sys.exit("::error::the seed-1 progression report differs between Linux and Windows")
    print("Same hash on both platforms.")


if __name__ == "__main__":
    main(sys.argv)
