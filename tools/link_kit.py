#!/usr/bin/env python3
"""Link the Studio Kit (kit/) into every Godot project as addons/gamelab_kit.

Each game under games/<name>/ and the kit test host under tools/kit-host/ gets
addons/gamelab_kit pointing at kit/. The link is not committed (see .gitignore);
run this once after cloning and again after adding a game:

    python3 tools/link_kit.py            # link every project
    python3 tools/link_kit.py --check    # fail if any link is missing or wrong

Linux and macOS get a symlink. Windows gets a directory junction, which needs no
admin rights or developer mode. --copy makes a plain copy instead (last resort,
for file systems without links; re-run after every kit change).
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "kit"
LINK_NAME = Path("addons") / "gamelab_kit"


def projects():
    found = [p for p in sorted((ROOT / "games").iterdir()) if (p / "project.godot").is_file()]
    host = ROOT / "tools" / "kit-host"
    if (host / "project.godot").is_file():
        found.append(host)
    return found


def points_at_kit(link):
    try:
        return link.resolve(strict=True) == KIT.resolve(strict=True)
    except OSError:
        return False


def remove(link):
    if link.is_symlink() or is_junction(link):
        # Removes the link only, never the kit behind it.
        os.unlink(link) if link.is_symlink() else os.rmdir(link)
    elif link.is_dir():
        shutil.rmtree(link)
    elif link.exists():
        link.unlink()


def is_junction(path):
    return hasattr(path, "is_junction") and path.is_junction()


def make_link(link, copy):
    link.parent.mkdir(parents=True, exist_ok=True)
    if copy:
        shutil.copytree(KIT, link)
    elif os.name == "nt":
        subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(KIT)], check=True, capture_output=True)
    else:
        link.symlink_to(os.path.relpath(KIT, link.parent), target_is_directory=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="only check, change nothing")
    parser.add_argument("--copy", action="store_true", help="copy the kit instead of linking it")
    args = parser.parse_args()

    if not (KIT / "plugin.cfg").is_file():
        print(f"kit not found at {KIT}")
        return 1
    problems = 0
    for project in projects():
        link = project / LINK_NAME
        rel = link.relative_to(ROOT).as_posix()
        if args.check:
            if points_at_kit(link) and (link / "plugin.cfg").is_file():
                print(f"ok      {rel}")
            else:
                print(f"missing {rel} (run python3 tools/link_kit.py)")
                problems += 1
            continue
        if points_at_kit(link) and not args.copy:
            print(f"ok      {rel}")
            continue
        if link.exists() or link.is_symlink():
            remove(link)
        make_link(link, args.copy)
        if not (link / "plugin.cfg").is_file():
            print(f"failed  {rel}")
            problems += 1
        else:
            print(f"{'copied ' if args.copy else 'linked '} {rel} -> kit/")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
