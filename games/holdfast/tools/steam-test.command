#!/bin/bash
# Holdfast Steam check on a Mac (HF-M2-00). Double-click with Steam running and signed in.
# Clears Spacewar's test achievement, plays one run with the bot (it wins),
# and unlocks "Win one game", which pops up in the Steam overlay.
cd "$(dirname "$0")" || exit 1
app="Holdfast.app"
if [ ! -d "$app" ]; then
  echo "Holdfast.app is not next to this file. Unpack the whole download first."
  read -n 1 -r -p "Press any key to close"
  exit 1
fi
# The download marks the app as "from the internet". Clearing that mark on this one
# app lets it open from here; no security setting is changed.
xattr -dr com.apple.quarantine "$app" 2>/dev/null
"$app/Contents/MacOS/Holdfast" -- --autoplay --steam-reset-test-achievement
echo
echo "Check the lines above for: [steam] ready, app 480; [steam] achievement ACH_WIN_ONE_GAME: unlocked; AUTOPLAY DONE."
echo "Then take a screenshot of this window and of the Steam pop-up."
read -n 1 -r -p "Press any key to close"
