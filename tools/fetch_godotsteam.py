#!/usr/bin/env python3
"""Install the pinned GodotSteam GDExtension into a game's addons/godotsteam.

The pin lives in kit/services/steam/godotsteam.json. The addon is not committed
(see .gitignore); CI fetches it before a Windows export, and so can a developer:

    python3 tools/fetch_godotsteam.py games/holdfast
    python3 tools/fetch_godotsteam.py --list      # recent release tags

Without it the game still runs: the kit's SteamService falls back to a no-op.
"""
import io
import json
import os
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / "kit" / "services" / "steam" / "godotsteam.json"
API = "https://api.github.com/repos/{repo}/releases"


def get_json(url):
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def main():
    pin = json.loads(PIN.read_text(encoding="utf-8"))
    releases_url = API.format(repo=pin["repository"])
    if len(sys.argv) > 1 and sys.argv[1] == "--list":
        for release in get_json(releases_url + "?per_page=20"):
            assets = ", ".join(a["name"] for a in release["assets"])
            print(f"{release['tag_name']}: {assets}")
        return 0
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    game = (ROOT / sys.argv[1]).resolve()
    if not (game / "project.godot").is_file():
        print(f"{game} is not a Godot project")
        return 1

    try:
        release = get_json(f"{releases_url}/tags/{pin['tag']}")
    except urllib.error.HTTPError as error:
        print(f"GodotSteam release {pin['tag']} not found ({error}). Recent tags:")
        for release in get_json(releases_url + "?per_page=10"):
            print("  " + release["tag_name"])
        return 1
    assets = [a for a in release["assets"] if pin["asset_contains"] in a["name"] and a["name"].endswith(".zip")]
    if len(assets) != 1:
        print(f"expected one asset containing {pin['asset_contains']!r} in {pin['tag']}, found: {[a['name'] for a in release['assets']]}")
        return 1
    asset = assets[0]
    print(f"downloading {asset['name']}")
    with urllib.request.urlopen(asset["browser_download_url"], timeout=300) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))

    target = game / "addons" / "godotsteam"
    if target.exists():
        shutil.rmtree(target)
    prefix = next((n[: n.index("addons/godotsteam/")] for n in archive.namelist() if "addons/godotsteam/" in n), None)
    if prefix is None:
        print("archive has no addons/godotsteam folder")
        return 1
    for name in archive.namelist():
        if not name.startswith(prefix + "addons/godotsteam/") or name.endswith("/"):
            continue
        dest = game / name[len(prefix):]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(archive.read(name))
    print(f"installed GodotSteam {pin['tag']} into {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
