#!/usr/bin/env bash
# Packs the exported macOS build for download: build/macos/Holdfast-mac-test.tar.gz
# holds Holdfast.app and the one-click steam-test.command. A tar.gz, because the
# zip GitHub makes of a CI artifact drops file permissions, and a .command file
# that is not executable cannot be double-clicked. Fails if the export is not what
# the Steam check needs (the app binary, GodotSteam's library, an ad-hoc signature).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
out="$root/build/macos"
zip="$out/Holdfast.zip"
[ -f "$zip" ] || { echo "::error::$zip is missing; export the macOS preset first"; exit 1; }

listing="$(unzip -Z "$zip")"
for needed in "Holdfast.app/Contents/MacOS/Holdfast" "Holdfast.app/Contents/MacOS/libsteam_api.dylib" "Holdfast.app/Contents/_CodeSignature/CodeResources"; do
  grep -q "$needed" <<<"$listing" || { echo "::error::$needed is missing from the macOS export"; exit 1; }
done
grep -E '^-rwx.* Holdfast.app/Contents/MacOS/Holdfast$' <<<"$listing" >/dev/null \
  || { echo "::error::the macOS app binary is not executable in the export"; exit 1; }

pack="$out/pack/Holdfast-mac-test"
rm -rf "$out/pack"
mkdir -p "$pack"
unzip -q "$zip" -d "$pack"
cp "$root/games/holdfast/tools/steam-test.command" "$pack/steam-test.command"
chmod 755 "$pack/steam-test.command" "$pack/Holdfast.app/Contents/MacOS/Holdfast"
tar -czf "$out/Holdfast-mac-test.tar.gz" -C "$out/pack" Holdfast-mac-test
tar -tvzf "$out/Holdfast-mac-test.tar.gz" | grep -E '^-rwx.* Holdfast-mac-test/steam-test.command$' >/dev/null \
  || { echo "::error::steam-test.command lost its execute permission in the archive"; exit 1; }
ls -la "$out"
