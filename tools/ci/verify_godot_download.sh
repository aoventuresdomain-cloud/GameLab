#!/usr/bin/env bash
# Checks a downloaded Godot file against tools/ci/godot.sha512.
#   tools/ci/verify_godot_download.sh FILE_NAME DOWNLOADED_PATH
set -euo pipefail
name="$1"
path="$2"
sums="$(dirname "$0")/godot.sha512"
expected="$(grep -v '^#' "$sums" | awk -v n="$name" '$2 == n { print $1 }')"
if [ -z "$expected" ]; then
  echo "::error::no checksum for $name in tools/ci/godot.sha512 (add it from the release's SHA512-SUMS.txt)"
  exit 1
fi
actual="$(sha512sum "$path" | cut -d' ' -f1)"
if [ "$actual" != "$expected" ]; then
  echo "::error::$name checksum mismatch: expected $expected, got $actual"
  exit 1
fi
echo "$name: SHA-512 verified"
