@echo off
rem Holdfast Steam check (HF-M1-05). Double-click with Steam running and signed in.
rem Clears Spacewar's test achievement, plays one run with the bot (it wins),
rem and unlocks "Win one game", which pops up in the Steam overlay.
cd /d "%~dp0"
Holdfast.console.exe -- --autoplay --steam-reset-test-achievement
echo.
echo Check the lines above for: [steam] ready, achievement ACH_WIN_ONE_GAME: unlocked, AUTOPLAY DONE.
echo Then take a screenshot of this window and of the Steam overlay pop-up.
pause
