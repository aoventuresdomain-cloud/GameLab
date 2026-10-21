#!/usr/bin/env bash
# Installs Mesa's software OpenGL (llvmpipe) for Windows next to an exported
# game, so CI can render it on a runner with no GPU (KIT-08 screenshots). Used
# only by CI; nothing from it ships in a release. The archive is pinned by
# release, file name and SHA-256 (mesa-dist-win, MIT-style Mesa licences).
#
#   tools/ci/fetch_mesa_windows.sh DEST_DIR            # download, verify, extract
#   tools/ci/fetch_mesa_windows.sh DEST_DIR ARCHIVE    # verify and extract a local copy
#
# Bump the pin only with Head of Engineering review: change the release, the
# file name and the checksum together, then re-run the screenshots job.
set -euo pipefail

RELEASE="25.3.6"
FILE="mesa3d-25.3.6-release-msvc.7z"
SHA256="ca56d92bb2254a9a25557c95cfe27f02071a77b26daff4cbf9bc125ed3347fb5"
URL="https://github.com/pal1000/mesa-dist-win/releases/download/${RELEASE}/${FILE}"
# The two files that make a program's OpenGL come from Mesa instead of Windows.
FILES=(x64/opengl32.dll x64/libgallium_wgl.dll)

dest="${1:?usage: fetch_mesa_windows.sh DEST_DIR [ARCHIVE]}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

archive="${2:-}"
if [ -z "$archive" ]; then
  archive="$work/$FILE"
  curl -fsSL --retry 3 -o "$archive" "$URL"
fi

actual="$(sha256sum "$archive" | cut -d' ' -f1)"
if [ "$actual" != "$SHA256" ]; then
  echo "::error::$FILE checksum mismatch: expected $SHA256, got $actual"
  exit 1
fi

# 7z is a Windows program, so it needs Windows-style paths when run from Git Bash.
native() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else echo "$1"; fi; }
7z x -y "-o$(native "$work/out")" "$(native "$archive")" "${FILES[@]}" > /dev/null
mkdir -p "$dest"
for f in "${FILES[@]}"; do
  [ -f "$work/out/$f" ] || { echo "::error::$f is not in $FILE"; exit 1; }
  cp "$work/out/$f" "$dest/"
done
echo "Mesa $RELEASE ($FILE) verified; software OpenGL installed in $dest"
