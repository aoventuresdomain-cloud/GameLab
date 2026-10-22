# Mac Steam check: Setup Desk checklist (HF-M2-00)

For the CEO's Mac, to close HF-M1-05 lines 1 and 2. Nothing here asks anyone to
change a macOS security setting. About ten minutes, once.

## Before

- Steam for Mac is installed, running and signed in.
- Download the latest `holdfast-macos-<commit>` artifact from the CI run on `main`
  (GitHub, Actions, the run, Artifacts). It downloads as a zip.

## Steps

1. Double-click the downloaded zip. It holds `Holdfast-mac-test.tar.gz`; double-click that too. A folder `Holdfast-mac-test` appears with `Holdfast.app` and `steam-test.command` in it.
2. First launch of an unsigned app: **right-click** `steam-test.command`, choose **Open**, then **Open** again in the box that appears. (A plain double-click is refused the first time, because the file is unsigned. Right-click and Open is the normal way past that for this one file; no setting is changed.) Later runs can be double-clicked.
3. A Terminal window opens and the game starts and plays one run by itself. The game window closes after a few seconds; the Terminal window stays open.
4. In the Terminal window, look for these lines:
   - `[steam] ready, app 480`
   - `[steam] achievement ACH_WIN_ONE_GAME: unlocked`
   - `AUTOPLAY DONE`
5. Take a screenshot of the Terminal window and of the Steam pop-up ("Win one game"), or of Spacewar's achievements page. Send both to the Chief of Staff.

## If something differs

- macOS says the app is damaged or cannot be opened even after right-click and Open: send a screenshot of the message. Do not change any security setting.
- The window shows `[steam] unavailable ...`: check Steam is running and signed in, then run it again.
- The game never opens (the Terminal shows `Killed` or a crash): send a screenshot. This is the case where the live Steam check moves to M4 with the real app ID, and the board says so.
