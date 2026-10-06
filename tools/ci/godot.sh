#!/usr/bin/env bash
# Runs Godot and fails when it exits non-zero or logs an error.
# Godot often exits 0 after a script or load error, so CI reads the log as well.
#   tools/ci/godot.sh --headless --path games/holdfast --quit
set -uo pipefail
log="$(mktemp)"
godot "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
  echo "::error::godot exited with $status"
  exit "$status"
fi
if grep -nE '^(SCRIPT )?ERROR:|Parse Error|Failed to load script|Failed loading resource' "$log" >/dev/null; then
  echo "::error::godot logged errors:"
  grep -nE '^(SCRIPT )?ERROR:|Parse Error|Failed to load script|Failed loading resource' "$log"
  exit 1
fi
