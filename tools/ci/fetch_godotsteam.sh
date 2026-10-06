#!/usr/bin/env bash
# Installs GodotSteam's prebuilt Windows export template for the pinned Godot
# version into build/godotsteam/, checked against a pinned SHA-256.
# The Windows preset in games/*/export_presets.cfg points its custom template
# at build/godotsteam/godotsteam.template.win64.exe (and .debug.template for
# debug exports); steam_api64.dll must ship next to the exported .exe.
#
# Bump the pin only with Head of Engineering review and a full QA round: change
# the release, the file name and the checksum together, and make sure the
# file name's g<version> matches /.godot-version.
#
#   tools/ci/fetch_godotsteam.sh            # download, verify, extract
#   tools/ci/fetch_godotsteam.sh ARCHIVE    # verify and extract a local copy
set -euo pipefail

RELEASE="v4.23"
FILE="godotsteam-g472-s165-gs423-templates.tar.xz"
SHA256="8f1891f3cc6b9f3f3d535be12d2bcc5c1496f876f8873d3f42ce028ce2035339"
# Paths inside the archive.
RELEASE_TEMPLATE="win64/godotsteam.472.template.win64.exe"
DEBUG_TEMPLATE="win64/godotsteam.472.debug.template.win64.exe"
STEAM_DLL="win64/steam_api64.dll"
URL="https://github.com/GodotSteam/GodotSteam/releases/download/${RELEASE}/${FILE}"

root="$(cd "$(dirname "$0")/../.." && pwd)"
dest="$root/build/godotsteam"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

godot_version="$(tr -d '[:space:]' < "$root/.godot-version")"
if [[ "$FILE" != *"-g${godot_version//./}-"* ]]; then
  echo "::error::GodotSteam pin $FILE does not match Godot $godot_version in .godot-version"
  exit 1
fi

archive="${1:-}"
if [ -z "$archive" ]; then
  archive="$work/$FILE"
  curl -fsSL --retry 3 -o "$archive" "$URL"
fi

actual="$(sha256sum "$archive" | cut -d' ' -f1)"
if [ "$actual" != "$SHA256" ]; then
  echo "::error::$FILE checksum mismatch: expected $SHA256, got $actual"
  exit 1
fi

tar -xJf "$archive" -C "$work" "$RELEASE_TEMPLATE" "$DEBUG_TEMPLATE" "$STEAM_DLL"
mkdir -p "$dest"
mv "$work/$RELEASE_TEMPLATE" "$dest/godotsteam.template.win64.exe"
mv "$work/$DEBUG_TEMPLATE" "$dest/godotsteam.debug.template.win64.exe"
mv "$work/$STEAM_DLL" "$dest/steam_api64.dll"

# Godot looks for the console wrapper next to a custom template, as
# <template>_console.exe. The wrapper only launches the .exe beside it, so the
# stock one from the same Godot version's templates is the right one.
stock="${GODOT_TEMPLATES_DIR:-$HOME/.local/share/godot/export_templates}/${godot_version}.stable"
for kind in release debug; do
  wrapper="$stock/windows_${kind}_x86_64_console.exe"
  if [ ! -f "$wrapper" ]; then
    echo "::error::missing $wrapper (install Godot $godot_version export templates first)"
    exit 1
  fi
done
cp "$stock/windows_release_x86_64_console.exe" "$dest/godotsteam.template.win64_console.exe"
cp "$stock/windows_debug_x86_64_console.exe" "$dest/godotsteam.debug.template.win64_console.exe"
echo "GodotSteam $RELEASE ($FILE) verified and installed in build/godotsteam"
ls -la "$dest"
