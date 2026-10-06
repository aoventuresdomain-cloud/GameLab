#!/usr/bin/env bash
# Installs itch.io's butler at a pinned version into ./butler/, checked against
# a pinned SHA-256 (never "LATEST"). Used by the main-only itch-draft upload;
# the butler-pin job runs it on pull requests so a bad pin fails before main.
#
# To bump: empty both pins and run the script once; it fails, printing the
# current release and its checksum to pin. Bump only with Head of Engineering
# review (the release pipeline is qa:full).
set -euo pipefail

BUTLER_VERSION="15.32.0"
BUTLER_SHA256="2335971394ef6596f95ded0833e85ee28755e13761716ef4c91d6b11f69162f5"

version="$BUTLER_VERSION"
if [ -z "$version" ]; then
  version="$(curl -fsSL --retry 3 https://broth.itch.zone/butler/linux-amd64/LATEST | tr -d '[:space:]')"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fsSL --retry 3 -o "$work/butler.zip" "https://broth.itch.zone/butler/linux-amd64/${version}/archive/default"
actual="$(sha256sum "$work/butler.zip" | cut -d' ' -f1)"
if [ -z "$BUTLER_VERSION" ] || [ "$actual" != "$BUTLER_SHA256" ]; then
  echo "::error::butler is not pinned to this archive. Pin BUTLER_VERSION=\"$version\" BUTLER_SHA256=\"$actual\" (currently '$BUTLER_VERSION' '$BUTLER_SHA256')"
  exit 1
fi

rm -rf butler
unzip -q "$work/butler.zip" -d butler
chmod +x butler/butler
butler/butler -V
