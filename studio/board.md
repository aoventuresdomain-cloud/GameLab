# GameLab work board

*Owned by the Head of Engineering. One section per game plus the Kit. Every item has one owner and 2-5 checkable Done when lines before anyone works on it; review and QA go against those lines. Only the Head of Engineering changes an item's status and merges (once CI is green); engineers never merge their own work. Every finding goes in **Findings** below with an owner before anyone fixes it, graded MUST FIX (blocks merge) or FOLLOW-UP (logged, doesn't block), as in `studio/playbook/shipping.md`. Dates come only from `studio/estimates.md`.*

**Statuses:** Ready · In progress · In review · In QA · Done · Blocked
**QA depth:** `full` (core logic: kit, save and offline earnings, Steam, release pipeline) · `screens` (interface only: sanity plus a walk of changed screens) · `sanity`. Unlabelled means full.

**Current focus:** Holdfast Gate 1 passed (CEO, 2026-10-06): stay on Godot. M2 (fun slice → Gate 2) started on the CEO's go, 2026-10-21. Its items are below, all Ready; Sonnet only, lean builds.

## Studio

### STU-01 Repository layout, board and slate
- **Owner:** Head of Engineering
- **Status:** Done
- **QA:** sanity
- **Done when:**
  - [x] The repository has `studio/`, `kit/`, `agents/`, `tools/`, `games/holdfast/` and `.github/workflows/` as in `gamelab-studio.md` section 3.
  - [x] `studio/board.md` lists the Holdfast M1 items and the Kit items, each with one owner and 2-5 Done when lines.
  - [x] `studio/slate.md` lists Holdfast as active game one at M1.
  - [x] CI runs `tools/studio/check_repo.py` on every pull request and it passes.

## Kit

*Kit items need Head of Engineering review, a full QA round and green tests for every active game. Owner while only one game is active: Gameplay Engineer.*

### KIT-01 Kit as a Godot addon, linked into Holdfast
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06)
- **QA:** full
- **Done when:**
  - [x] `games/holdfast/addons/gamelab_kit/` resolves to `kit/` (link or a scripted sync step), on Linux CI and on a Windows checkout, and the method is written in `README.md`.
  - [x] `godot --headless --path games/holdfast --quit` opens the project with the kit addon enabled and no errors in CI.
  - [x] Holdfast code calls a kit class, covered by a test.
  - [x] The Godot version is pinned in one place (4.7.2-stable since #10, F-009 decision; was 4.6-stable) and used by every CI job.
  - [x] `games/holdfast/project.godot` is owned by this item from now on and keeps the display, renderer and theme settings HF-M1-04 added.

### KIT-02 Shared simulation engine: timestep, seed and bot runner
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06; line 4 met once the required checks went on, F-008)
- **QA:** full
- **Done when:**
  - [x] `kit/sim/` provides a fixed-timestep loop, a seeded random generator and a bot runner that drive any game's rules through one interface; it has no rendering or scene-tree dependency.
  - [x] The same engine drives both the headless run and the playable build (the build adds rendering and input on top; it never steps the rules itself).
  - [x] Determinism test in `kit/tests/`: two runs with the same seed and inputs give a byte-identical state hash; a different seed gives a different hash.
  - [x] Kit tests run headless in CI and red blocks merge.

### KIT-03 Pack format v0 and pack loader
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06)
- **QA:** full
- **Done when:**
  - [x] `kit/schema/` holds a versioned base JSON schema for levels, enemies, towers, staff and upgrade nodes, which games extend.
  - [x] The loader validates a pack against the schema and rejects an invalid one with an error naming the file and field (tested).
  - [x] The loader refuses anything that is not data (scripts, scene or resource references), tested.
  - [x] The Holdfast M1 level, enemy, tower and staff values come from a pack in `games/holdfast/content/base/`, not from code.

### KIT-04 Steam service with a safe fallback
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06)
- **QA:** full
- **Depends on:** KIT-01
- **Done when:**
  - [x] `kit/services/steam` wraps GodotSteam (version pinned) behind a small interface: init, unlock achievement, store stats.
  - [x] Without Steam running (CI, web build, headless) the service is a no-op that logs once and never crashes, covered by a test.
  - [x] Uses Valve's public test app ID (480) until Holdfast has its own; no credentials or app secrets in the repository.

### KIT-05 CI pipeline: tests and exports
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06; line 1 met once the required checks went on, F-008)
- **QA:** full
- **Depends on:** KIT-01
- **Done when:**
  - [x] Kit tests run on every pull request; Holdfast tests and exports run when `kit/` or `games/holdfast/` change; any red job blocks merge.
  - [x] The Holdfast job runs the UI tests (`godot --headless --path games/holdfast --script res://tests/run_ui_tests.gd`) after an import step.
  - [x] Every push to `main` produces a Windows build and a web build of Holdfast as downloadable CI artifacts.
  - [x] The web export runs in a current desktop browser without special server headers (single-threaded export).
  - [x] The only secret before M4 is `BUTLER_API_KEY`, used to upload the web build to the restricted itch.io draft page for Gate 1 (never published); `tools/release/` documents every secret the pipeline uses.

### KIT-06 Pack format v1: references and versioning
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] Packs can reference entries in other files by id, and the loader rejects a dangling reference naming the file and field (tested).
  - [ ] Every pack carries a schema version; the loader rejects an unknown major version (tested).
  - [ ] Nothing Holdfast-specific is added to `kit/` (repo check passes).

### KIT-07 Save service
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] Progress saves locally and reloads exactly, at any moment, including mid-run (tested). That covers gold, upgrades, the Hero's paths, nodes and gear, the Recruit roster with levels, traits and skill picks, unlocked blessings and names.
  - [ ] A corrupt or truncated save is detected, the previous good save is kept, and the player is told (tested).
  - [ ] Saves carry a version, and a v1 save loads after a format change (migration test).
  - [ ] Works in the Windows build and the browser build (browser storage).
  - [ ] The save-format change carries a tested rollback note: an older build opening a newer save refuses safely and leaves the file untouched.

### KIT-08 Determinism and screenshots on Windows
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] CI runs the seed-1 progression run on Windows and Linux and fails if the full report hashes differ.
  - [ ] The full hash is printed in both logs (not truncated).
  - [ ] The Windows CI job also renders a run (not headless) and uploads screenshots at 1280×720 and 1920×1080. That lets QA check Windows readability without a Windows PC, and closes F-013 and the Windows half of HF-M1-04 line 3.

## Holdfast

*Game one. Plan: `games/holdfast/plan.md`. Milestone: M1 tech proof, done; Gate 1 passed 2026-10-06 (stay on Godot). M2 fun slice → Gate 2 started 2026-10-21.*

### HF-M1-01 Holdfast combat rules on the shared engine
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06)
- **QA:** full
- **Depends on:** KIT-02, KIT-03
- **Done when:**
  - [x] Holdfast's rules (waves, aura damage, 1 tower, 1 staff, gold and staff XP drops, keep health) live in `games/holdfast/`, plug into the kit engine and have no rendering dependency.
  - [x] The mouse aura has a bot model that calls the same damage function as the player's aura, so the headless run and the playable build share one set of rules.
  - [x] The same seeded run gives identical gold, XP and wave results in the headless simulator and in the playable build driven by the bot aura (automated test).

### HF-M1-02 Ten hours of progression headless in under a minute
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06)
- **QA:** full
- **Depends on:** HF-M1-01
- **Done when:**
  - [x] A CI job plays 10 simulated hours of Holdfast progression (repeated runs plus a stub upgrade purchase between runs) with a bot policy, and finishes in under 60 seconds of wall-clock time, printed in the log.
  - [x] The job writes a report (time to each unlock, gold per run, runs played) as a CI artifact.
  - [x] The job fails if the 60-second budget is exceeded or the determinism check (two runs, same seed, same report hash) fails.

### HF-M1-03 One playable level in Windows and web builds
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06). The Windows build is played through headless in CI; seeing it on a Windows screen moves to KIT-08 (F-013)
- **QA:** full
- **Depends on:** HF-M1-01, KIT-05
- **Done when:**
  - [x] Enemies come in waves at the keep; the aura follows the mouse and damages enemies under it; 1 tower and 1 staff attack on their own.
  - [x] Enemies drop gold; the run ends when the keep falls or the last wave is cleared.
  - [x] The CI web build and Windows build both play one full run with no errors in the log.
  - [x] Placeholder art only (CC0), with sources listed in `games/holdfast/assets/CREDITS.md`.
  - [x] `scenes/main.tscn` uses `HoldfastRunSource` (the kit engine), so the exported builds run the real rules, and the UI tests pass with the stub pinned.

### HF-M1-04 Run HUD and run flow screens
- **Owner:** UI Engineer
- **Status:** Done (Gate 1 QA round on `cad3bc8`; Gate 1 passed 2026-10-06). Line 3 passes in the browser at both sizes; the Windows-build half moves to KIT-08 (CI screenshots in M2), because the studio has no Windows PC
- **QA:** screens
- **Depends on:** HF-M1-03 (can start on stub data)
- **Done when:**
  - [x] The HUD shows gold, keep health and wave number, updating live during a run.
  - [x] Start screen → run → end-of-run summary (gold earned, waves cleared) → play again works with the mouse alone.
  - [ ] Text is readable at 1280×720 and 1920×1080, in the Windows build and the browser.
  - [x] The UI reads game state only through signals or read-only accessors and never changes the rules' state.

### HF-M1-05 Test Steam achievement fires
- **Owner:** Gameplay Engineer
- **Status:** Done, partly met (CEO accepted at Gate 1, 2026-10-06). CI proves GodotSteam loads in the Windows build (F-015). The live unlock in lines 1 and 2 needs Steam running on a desktop, and the studio has no Windows PC, so it moves to HF-M2-00 (Mac build with Steam for Mac on the CEO's Mac; fallback: the real store app in M4)
- **QA:** full
- **Depends on:** KIT-04, HF-M1-03
- **Done when:**
  - [ ] Clearing the level in the Windows build unlocks one achievement on Valve's test app (480) through the kit Steam service.
  - [ ] Evidence on the item, from a Windows PC with Steam running: the log line `[steam] achievement ACH_WIN_ONE_GAME: unlocked` and a screenshot of the Steam overlay notification (or, if the overlay doesn't show for a game started outside Steam, of Spacewar's achievements page with the unlock time).
  - [x] The web build and CI runs are unaffected (no-op path, tests green).

### HF-M1-06 macOS export cost check
- **Owner:** Gameplay Engineer
- **Status:** Done (Gate 1 passed 2026-10-06). The CEO decides on selling on Mac before M4; M2 adds an unsigned Mac test build (HF-M2-00)
- **QA:** sanity
- **Depends on:** KIT-05
- **Done when:**
  - [x] CI attempts an unsigned macOS export once and records pass or fail.
  - [x] A short note on this item states what shipping macOS would add (signing, notarisation, testing, cost) and a recommendation for Gate 1.
- **Note (from #7):** the unsigned export succeeds in CI (a 62 MB universal zip; ETC2/ASTC texture import is now enabled in `project.godot`). Shipping macOS would add:
  - Signing: an Apple Developer Program membership (a paid yearly sign-up, so CEO go-ahead first) and a Developer ID certificate held as CI secrets.
  - Notarisation: every build goes to Apple's notary service and gets its ticket stapled; without it, macOS blocks the app on first launch. Steam does not do this for us.
  - Steam: a second GodotSteam template pin (macOS) and a Mac depot.
  - Testing: QA on a real Mac (Apple Silicon at least). Nobody in the studio has one today.
  - Engine: no code changes; the export already builds unsigned.
- **Recommendation (accepted by the Head of Engineering):** no macOS build at Gate 1. Mac players use the itch.io web build. The unsigned export stays in CI as a free early warning. macOS at Steam launch goes to the CEO as one question in the Gate 1 brief.

### HF-M1-07 Gate 1 full QA round
- **Owner:** Head of QA and Validation (per job)
- **Status:** Done: round 1 on fixed commit `cad3bc8` closed clean on 2026-10-06, no blockers or majors (results in the GameLab project files, `holdfast/hf-m1-07/`). The two Partial lines cleared when the required checks went on (F-008). Three Windows-only cases move to M2 (HF-M2-00 and KIT-08), and QA re-checks them there. Merge freeze lifted
- **QA:** full
- **Done when:**
  - [x] One fixed build (commit recorded) is tested end to end against every M1 Done when line on this board.
  - [x] Merges are frozen to blocker and major fixes during the round, and each fix is re-checked.
  - [x] The round closes clean: no open blocker or major issue.

### HF-M1-08 Gate 1 brief for the CEO
- **Owner:** Head of Engineering
- **Status:** Done: the CEO approved Gate 1 (stay on Godot) and the M2 plan together on 2026-10-06 (brief in the GameLab project files, `holdfast/gate1/`)
- **QA:** sanity
- **Done when:**
  - [x] One page: a link to play the web build, the Windows build, simulator timing and determinism results, achievement evidence, the macOS note and open risks.
  - [x] A recommendation: stay on Godot or switch to Unity, with the reason.
  - [x] Sent to the CEO through the Chief of Staff with one question and the recommendation marked.

### HF-M2-00 Mac test build and live Steam achievement
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] CI builds an unsigned macOS build with GodotSteam (template pinned by name and SHA-256, as for Windows) and a one-click `steam-test.command`.
  - [ ] On the CEO's Mac with Steam for Mac running, it logs `[steam] ready, app 480` and `[steam] achievement ACH_WIN_ONE_GAME: unlocked`. Evidence is a screenshot of the pop-up or of Spacewar's achievements page, which closes HF-M1-05 lines 1 and 2.
  - [ ] A Setup Desk checklist covers first launch of an unsigned app (right-click, Open) without asking the CEO to change system security settings.
  - [ ] If the Mac route fails, the live check moves to M4 with the real app ID, and the board says so.

### HF-M2-01 Pacing bands
- **Owner:** Balance Analyst
- **Status:** Ready
- **QA:** sanity
- **Done when:**
  - [ ] `games/holdfast/content/pacing-bands.json` encodes the plan's targets for the slice: first upgrade within 60 seconds, a new unlock every 3-5 minutes in the first hour, no grind wall over 10 minutes of repeated runs.
  - [ ] It adds the Advisor's bands: a bot finishes the slice in 45-75 minutes, runs last 3-8 minutes, the first Recruit can be hired by the end of run 1, and a squad adds a meaningful clear-rate gain over the Hero alone.
  - [ ] Each band says how the simulator measures it and is checked against both an optimal bot and a mediocre-skill bot. The Gameplay Engineer reviews them.
  - [ ] The Advisor's view on the bands is logged on the board.

### HF-M2-02 Meta progression: biome, 5 levels and the upgrade tree
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] One coastal biome with 5 hand-made levels, the fifth ending in the mini-boss from HF-M2-16, all from packs. The fog edge sits where the keep's beam reaches, and enemies spawn at it, so widening the beam lengthens their walk in (distances from packs, tested).
  - [ ] About 30 upgrade-tree nodes are bought with gold between runs, from packs. The branches are towers (damage, health, repair between waves), keep and gold gain, and unlocks (levels, the 3rd and 4th deploy slots, the recruitment board's size). The Hero's own paths are separate (HF-M2-14).
  - [ ] Gold and upgrades persist through KIT-07.
  - [ ] The headless and playable builds still end a seeded run identically (parity test).

### HF-M2-14 Your Hero
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] There is one player-named Hero, the Keeper. They move with WASD, and their lantern damages fog creatures in a radius around them (M1's aura damage, now centred on the Keeper). The ability from their path fires with Space on a cooldown. The mouse-cursor aura is gone.
  - [ ] The Hero has 3 skill paths from packs: Guardian (tanky, taunts, protects towers), Marksman (ranged, fast, kites) and Warlord (buffs and commands Recruits). Each has 10 nodes (three tiers of three, plus a capstone that changes the path's ability), at least half changing behaviour rather than a percentage, and unlocks a different active ability. Hero level is capped so a tester can buy about 8 nodes in a session; only the next tier is open and deeper tiers show locked. Paths can be mixed, and a full respec between runs is free or cheap.
  - [ ] Movement and abilities are inputs on the kit engine's fixed timestep, so a seeded run with recorded inputs ends identically headless and in the playable build (parity test).
  - [ ] At zero health the Hero is knocked down, drops their unbanked XP where they fell for the player to collect, and gets back up at the keep. The delay grows with each knock-down in the run (delays from packs, tested).
  - [ ] Head of QA's strict expected-failure tests, written from worked examples before the build, now pass; boundary cases (zero health, first and fourth knock-down, off and empty pack values) are covered.

### HF-M2-15 Enemies fight back
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] Enemies target the nearest tower, Recruit or the Hero, else the keep (rule from packs, tested).
  - [ ] Towers have health and are destroyed for the rest of the run at zero; Recruits are knocked out for the run; both are tested.
  - [ ] Each light post lights a small area, and enemies inside a lit area take extra damage (radius and bonus from packs, tested).
  - [ ] Health bars show only on damaged units, a hit flashes clearly (shared with HF-M2-07), and the run summary lists towers lost and Recruits knocked out.
  - [ ] Head of QA's strict expected-failure tests, written from worked examples before the build, now pass; targeting ties, no towers left, and an empty or zero lit-area bonus are covered.

### HF-M2-03 Recruits: hiring, traits, levels and the squad
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] A recruitment board on the keep screen offers Recruits to hire with gold, from packs. Each has a generated name, one of 4 classes (Warden, Archer, Alchemist, Engineer) and one of about 8 traits (for example "Steady: +20% range", "Coward: flees below half health"). Each trait is covered by a rules test.
  - [ ] Deploy slots start at 2, with the 3rd and 4th bought in the tree. The player picks the squad before each run from a roster that can be larger.
  - [ ] Recruits earn XP from tokens mid-run, level up and can gain a trait. Each class has a small skill tree of three forks of two choices (24 nodes across the 4 classes, from packs), offered as a pick-1-of-2 on the level-up card with no new screen. Each choice changes behaviour (Warden: taunt or bulwark) and has a rules test. Recruits have no gear.
  - [ ] Recruits are drawn as distinct shapes in class colours, bigger than enemies and smaller than the Hero. Each shows a name tag, a level-up flash, short barks ("Hold the gate!") and a visible knock-out. They stand at the keep between waves.
  - [ ] The keep, the Hero and every Recruit can be renamed, and names persist. Every Hero path, with a squad the bot picks, can clear the slice in the simulator (bot report per path).

### HF-M2-04 Blessings
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] 6 blessings from packs, unlocked through play; the player picks 1 of 3 offered at run start.
  - [ ] Each blessing's effect is covered by a rules test.

### HF-M2-16 Hero gear and the first boss
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Depends on:** HF-M2-14, HF-M2-15, HF-M2-02
- **Done when:**
  - [ ] Gear is for the Hero only: the Hero has 2 gear slots filled from a pool of about 6 items in packs, Recruits have no gear slots (tested), and gear persists through KIT-07.
  - [ ] An elite on level 2 or 3 always drops a gear item, so every tester sees gear before the boss.
  - [ ] Level 5 ends with a mini-boss from the fog that cannot be beaten without the Hero's path ability; its behaviour comes from packs (tested) and it drops gear.
  - [ ] Every Hero path, with a squad the bot picks, beats the boss in the simulator (bot report per path), and a Hero-only bot is measured against Hero plus squad.

### HF-M2-05 Simulator covers the slice and gates on the bands
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Depends on:** HF-M2-01 to HF-M2-04, HF-M2-14, HF-M2-15
- **Done when:**
  - [ ] Two bots play the whole slice headless in CI within the existing time budget: one that picks a Hero path and a squad, moves the Hero towards the largest group of enemies near the keep and uses the ability on cooldown, and a weak version of it. The run covers levels, upgrades, hiring, path and squad picks, and blessings.
  - [ ] The report checks HF-M2-01's bands for both bots and every Hero path. It shows time to each unlock and the first Recruit, grind walls and run length.
  - [ ] CI fails when a band is missed.

### HF-M2-06 Home screen and keep screen
- **Owner:** UI Engineer
- **Status:** Ready
- **QA:** screens
- **Done when:**
  - [ ] A home screen (Continue, New game, Settings, Quit) leads to the keep screen, the hub between runs.
  - [ ] The keep screen holds level select, the upgrade tree, the Hero's paths and respec, the recruitment board, the Recruit roster, the squad pick, the blessing picker and naming. All of it works with the mouse alone.
  - [ ] The in-run HUD shows the Hero's health and ability cooldown, the knock-down timer, and the towers and Recruits lost.
  - [ ] Text is readable at 1280×720 and 1920×1080 in the Windows build and the browser.
  - [ ] The screens change progress only through the rules' own actions (no direct state writes), tested.

### HF-M2-07 Feel and settings
- **Owner:** UI Engineer
- **Status:** Ready
- **QA:** screens
- **Done when:**
  - [ ] Hit flash, screen shake, damage number pops, particles, clear Hero ability hits and a keep that grows with upgrades, in code, within the style guide.
  - [ ] Reward moments: gold vacuums to a ticking counter, upgrade purchases light up with a sound, Hero node picks and Recruit level-ups are their own moments, and numbers use short formats (1.2K, 3.4M).
  - [ ] CC0 sound effects for hits, gold, level-ups and the boss, with sources in `CREDITS.md`.
  - [ ] Settings for volume, screen shake and flashes, saved through KIT-07.
  - [ ] No frame drops below 60 fps with the slice's largest wave in the browser build on the CI reference run.

### HF-M2-08 Style guide locked
- **Owner:** Product Designer
- **Status:** Ready
- **QA:** sanity
- **Done when:**
  - [ ] `games/holdfast/content/style-guide/` holds the guide for The Last Lighthouse, glow on dark: camera, outline weight, a palette of about 16 colours, light direction and how the beam and lantern glow read against the fog, the Keeper's look, one colour per Recruit class, and what never appears.
  - [ ] Placeholder portraits for the Hero and the 4 Recruit classes in the house style.
  - [ ] A CI check fails on colours outside the palette in drawn art and sprites.
  - [ ] A freelancer brief for the human-made portraits is drafted in project files (no commission; CEO decision before M4).
  - [ ] The CEO approves the style (via the Setup Desk at Gate 2).

### HF-M2-09 Playable builds for the CEO, after each slice
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** sanity
- **Done when:**
  - [ ] After each slice is merged, CI publishes a build the CEO plays on the Mac with no extra steps (the private itch.io draft web build in the browser; the Mac build from HF-M2-00 once it exists), with the commit shown on the title screen.
  - [ ] Before each CEO build: one production-shaped run (real build, the game's own default names, new game to quit) and the full suite in CI's order, both on that commit.
  - [ ] Each build goes with a two-line note: what changed and what to try. The CEO's feedback goes on the board's Findings table with an owner before anyone fixes it.

### HF-M2-10 Tester sessions
- **Owner:** Player Researcher
- **Status:** Blocked: moved to a later stage (CEO, 2026-10-21). Outside testers are not part of M2; the local session log and tester guide go with them
- **QA:** none (research)
- **Done when:**
  - [ ] 5-10 outside testers recruited by an approved route.
  - [ ] Report: median first-session length from the logs, how many want to keep playing, and how many name the Hero or Recruits as a reason, with quotes.
  - [ ] Findings logged on the board with owners.

### HF-M2-11 Name check
- **Owner:** Researcher (per job)
- **Status:** Ready
- **QA:** none (research)
- **Done when:**
  - [ ] Steam and UK/EU/US trademark search for "Holdfast" and for "The Last Lighthouse", with any clash noted in the plan.
  - [ ] 3-5 alternative names that pass the same search, in project files. At least 3 of them fit the lighthouse theme. No filing or purchase (CEO decision).

### HF-M2-12 Gate 2 full QA round
- **Owner:** Head of QA and Validation
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] One fixed build is tested end to end against every M2 Done when line on this board, and merges are frozen to blocker and major fixes during the round.
  - [ ] Every result names the fixed commit; if `main` moves under the build, the run is void and restarts on the new commit.
  - [ ] One production-shaped run (real build, the game's own defaults, new game to quit) and the full suite in CI's order, on that commit. A finding counts only if it reproduces without test-only helpers, and each is graded MUST FIX or FOLLOW-UP.

### HF-M2-13 Gate 2 brief
- **Owner:** Head of Engineering
- **Status:** Ready
- **QA:** none (document)
- **Done when:**
  - [ ] The CEO has one brief with their own playtest notes, the pacing report, style for approval, the QA result and a go / rework / stop recommendation.
  - [ ] The brief states the commit each QA result was run on.

## Findings

*Every finding from review, QA, CI or the Advisor goes here with an owner before anyone fixes it. Closed findings stay, marked Fixed with the PR. Grading (from 20 Oct 2026): Blocker and Major findings are MUST FIX and block the merge; Minor ones are FOLLOW-UP and don't, unless the row says otherwise. New findings put MUST FIX or FOLLOW-UP in the Severity cell. A finding counts only if it reproduces without test-only helpers.*

| ID | Item | Finding | Severity | Owner | Status |
|---|---|---|---|---|---|
| F-001 | HF-M1-04 | Readability not yet confirmed in the Windows build and the browser (only desktop Linux so far) | Minor | Head of QA and Validation | Fixed for the browser (HF-M1-07 passed at both sizes on `cad3bc8`). The Windows-build check moves to KIT-08's CI screenshots in M2, because the studio has no Windows PC |
| F-002 | HF-M1-02 | The bot wins every run on placeholder numbers, so the progression report says nothing about balance yet; the report must say so | Minor | Balance Analyst (M2); report note by Gameplay Engineer | Report note Fixed (#7); balance deferred to M2 |
| F-003 | HF-M1-02 | `tools/progression.gd --out` with an absolute path writes under the project folder instead | Minor | Gameplay Engineer | Fixed (#7) |
| F-005 | HF-M1-01 | `waves_cleared` counts waves whose enemies reached the keep. Ruling: a wave is cleared only when every enemy in it was killed; add a test | Minor | Gameplay Engineer | Fixed (#7) |
| F-006 | HF-M1-01 | `HoldfastRules.setup` uses `assert` for bad config, which release exports strip; use `push_error` and return early | Minor | Gameplay Engineer | Fixed (#7) |
| F-007 | KIT-01 | `kit/README.md` lists `services/`, which doesn't exist yet | Minor | Gameplay Engineer | Fixed (#7) |
| F-008 | KIT-02, KIT-05 | Only `repo-checks` is required on `main`, so red kit or Holdfast jobs don't block merge; add `kit-tests`, `holdfast` and `kit-link-windows` as required checks | Major | Setup Desk (CEO's hands) | Fixed 2026-10-06: the CEO confirmed the required checks are on |
| F-009 | KIT-04, HF-M1-05 | GodotSteam publishes no build for Godot 4.6 (only module templates for 4.5.2 and 4.7.x), so the Windows build can't fire a Steam achievement on the current pin | Major (Gate 1) | Gameplay Engineer | Fixed (#10) |
| F-004 | KIT-05 | No CI upload of the web build to the itch.io Draft page yet, and `tools/release/README.md` does not list `BUTLER_API_KEY` | Major (Gate 1) | Gameplay Engineer | Fixed (#7): first upload from `main` succeeded on 2026-10-06 after F-014 |
| F-010 | KIT-05 | `itch-draft` downloads butler from `LATEST` and hands it `BUTLER_API_KEY`, so an unpinned binary sees a secret. Pin a butler version and check its SHA-256, as for the GodotSteam template | Major | Gameplay Engineer | Fixed (#10) |
| F-011 | HF-M1-05 | `steam_hooks.gd` unlocks the "level cleared" achievement whenever the keep didn't fall, so an `OUTCOME_INVALID` run would unlock it. Check for `OUTCOME_WON`, and have `HoldfastRunSource` refuse to start a run when `setup_error` is set; add a test | Minor | Gameplay Engineer | Fixed (#10) |
| F-012 | KIT-05 | `smoke-web` waits a fixed `sleep 1` for `http.server` before loading the page, which can fail on a slow runner. Poll the URL until it responds | Minor | Gameplay Engineer | Fixed (#10) |
| F-013 | HF-M1-03 | `smoke-windows` runs `--headless`, so CI never exercises the Windows renderer (the web smoke run does render, through SwiftShader) | Minor | Head of QA and Validation | Moved to M2: KIT-08 takes screenshots from the Windows build in CI, since the studio has no Windows PC |
| F-014 | KIT-05 | First `itch-draft` run on `main` (after #7): butler logged in with `BUTLER_API_KEY`, but itch.io refused the build with "Please verify your account's email address before uploading a build". `itch-draft` stays red on every push to `main` until this is done | Major (Gate 1) | Setup Desk (CEO's hands: verify the itch.io account email) | Fixed 2026-10-06: email verified, `itch-draft` re-run on `main` passed |
| F-015 | HF-M1-05 | `smoke-windows` proves the GodotSteam template ran but not that the `Steam` singleton loads, because `SteamService.init` returns at the headless check first. Log `Engine.has_singleton("Steam")` in the unavailable message and have `smoke-windows` assert it, so the CEO's Steam session isn't the first test | Major (Gate 1) | Gameplay Engineer | Fixed (#12): `smoke-windows` asserts `GodotSteam loaded: yes` |
| F-016 | KIT-05 | `tools/release/README.md` says every downloaded tool is pinned, but the Godot editor and export templates are pinned by version only, not SHA-256 like GodotSteam and butler. Add the two checksums or reword the README | Minor | Gameplay Engineer | Fixed (#12): CI checks Godot downloads against the official SHA-512 sums |
| F-017 | HF-M1-05 | Spacewar's `ACH_WIN_ONE_GAME` may already be unlocked on the CEO's Steam account, so the unlock would not show. Add an opt-in `--steam-reset-test-achievement` flag (app 480 only, never on by default) that clears it at startup, and a `steam-test.bat` in the Windows CI artifact that runs `Holdfast.console.exe --autoplay --steam-reset-test-achievement`, so the CEO's check is one double-click | Minor | Gameplay Engineer | Fixed (#12): `steam-test.bat` is in the Windows artifact |
| F-018 | HF-M1-03, HF-M1-04 | The HUD bar covers the top ~120 px of the play area at 720p, so enemies arriving from the top and the aura pass underneath it (UI Engineer's F-001 screenshots). Fit the drawn world into the area below the HUD | Minor (fix before Gate 1) | UI Engineer (may change `world_view.gd` placement and scale only; drawing, input and rules stay as they are) | Fixed (#14): keep centred below the HUD, view scale 0.85-1, new layout test at 720p and 1080p |
| F-019 | HF-M1-03, HF-M1-04 | `games/holdfast/README.md` still says the `RunSource` node is `stub_run_source.gd` and that wiring the real rules is future work, but `main.tscn` uses `HoldfastRunSource` since #7 (Head of QA, preparing HF-M1-07) | Minor (docs) | Gameplay Engineer | Fixed (#16) |
| F-020 | KIT-02 | `kit/sim/sim_engine.gd` checks its arguments (null rules, tick rate <= 0) with `assert`, which release exports strip, the same pattern F-006 fixed in Holdfast. No current caller passes bad values (Head of QA, HF-M1-07) | Minor | Gameplay Engineer | Open: after Gate 1 |
| F-021 | KIT-03 | One invalid enemy entry drops the whole enemies file, so the loader adds about 11 follow-on "no enemies entry with id" errors, valid enemies included; the first error is correct. The version error also prints "must be one of [0.0]" (Head of QA, HF-M1-07) | Minor | Gameplay Engineer | Open: after Gate 1 |
| F-022 | HF-M1-02 | The progression report prints "budget 0 s" for a fractional budget (Head of QA, HF-M1-07) | Minor | Gameplay Engineer | Open: after Gate 1 |

## Test changes

*Only the Head of Engineering may OK changing a test, never on the assumption that the code is right. Ask QA or the Advisor when unclear.*

| Date | Test | Change | Why | OK'd by |
|---|---|---|---|---|
| 2026-10-06 | `games/holdfast/tests/run_ui_tests.gd` | Pin the stub run source instead of the real rules | Its "wave advances" check encoded the stub's pacing; once the real rules are wired in, it would test level balance rather than the UI. The real rules keep their own end-to-end coverage (parity test, exported-build autoplay smoke test) | Head of Engineering |

## Advisor views

| Date | Item | Advisor view | Decision |
|---|---|---|---|
| 2026-10-06 | KIT-02, HF-M1-01 | The headless simulator and the playable build must share one rules engine, including a bot model of the mouse aura, or balance drifts from Gate 2 on. Shared engine in `kit/`, Holdfast combat rules in `games/holdfast/`. | Accepted: folded into KIT-02 and HF-M1-01 Done when lines |
| 2026-10-06 | M2 plan | First review of the M2 draft: 4 heroes with 2 slots to start, extra pacing bands checked by a weaker bot, reward moments, an open survey question | Accepted: all 5 points folded into the M2 plan |
| 2026-10-06 | M2 plan | On the CEO's playtest: agree it plays like Incrempire; the player leads one hero (picked before each run) in place of the mouse aura, enemies fight back, add a home screen and hero and tower upgrades; heroes must be impossible to miss; rename "staff" to "heroes"; difficulty levels wait for M5 | Accepted by the Head of Engineering; the CEO approved the plan, difficulty in M5 and the name "heroes" |
| 2026-10-06 | M2 plan | The hero you lead gets back up at the keep when knocked down, with a longer wait after each knock-down in a run and their unbanked XP dropped where they fell; the run ends only when the keep falls | Accepted: in the M2 plan (HF-M2-14) |
| 2026-10-06 | M2 plan | On the CEO's one Hero, many Recruits: one player-named Hero with 3 skill paths (Guardian, Marksman, Warlord) and free or cheap respec; Recruits hired with gold, each with a generated name, class and trait, levelling but with no skill trees; 2 deploy slots to start; the bot picks a path and a squad, measured per path | Accepted: in the M2 plan (HF-M2-14, HF-M2-03), with 4 Recruit classes |
| 2026-10-21 | M2 scope change | Hero gets 10 nodes a path (3 tiers of 3 plus a capstone), level-capped so about 8 nodes fit a session; Recruit trees of 3 forks of 2 (24 nodes) on the level-up card; Hero-only gear from a pool of about 6; level-5 mini-boss with a guaranteed elite gear drop on level 2 or 3; bands check the squad adds a clear-rate gain | Accepted: HF-M2-14, HF-M2-03, HF-M2-01, new HF-M2-16. A Recruit trait as a boss drop is not in M2 (CEO's call) |

## Decisions and open questions

- 2026-10-06: The repository stays public for now (CEO decision), to go private once the idea matures. Until then `games/holdfast/plan.md` is a build excerpt and nothing commercially sensitive is committed (`CLAUDE.md`).
- 2026-10-06: Gate 1 web build is played from a password-protected itch.io draft page (not a public release), uploaded by CI with butler. Agreed with the Setup Desk.
- 2026-10-06: Godot pinned at 4.6-stable. KIT-01 owns `project.godot`; KIT-05 runs the UI tests in CI (overlaps from HF-M1-04, settled by the Head of Engineering).
- 2026-10-06: Godot pin moves from 4.6-stable to 4.7.2, because GodotSteam ships Windows export templates for 4.7.x but nothing for 4.6. The Windows export uses GodotSteam's template (pinned by file name and SHA-256); the web export stays on stock templates. Rejected: 4.5.2 (older engine, downgrade) and building GodotSteam ourselves (slow and fragile). Head of Engineering (F-009).
- Open (M3 or replays): floating-point results may differ between Linux CI and Windows players; harmless for M1, matters if saves or replays must match exactly across machines.
- 2026-10-06: No macOS build at Gate 1; Mac players use the itch.io web build, and the unsigned macOS export stays in CI as an early warning. Head of Engineering (HF-M1-06).
- 2026-10-06: HF-M1-05 line 2 also accepts Spacewar's achievements page with the unlock time, in case the overlay doesn't show for a game started outside Steam (Head of Engineering, Setup Desk question).
- Open (CEO, before M4): ship macOS at Steam launch or Windows and Steam Deck only. Needs a paid Apple Developer sign-up (CEO go-ahead); the CEO's Mac covers QA (HF-M1-06 note).
- 2026-10-06: The CEO has a Mac and no Windows PC. Nobody plans hands-on steps that need Windows: Windows evidence comes from CI (KIT-08 screenshots), and the live Steam check runs on an unsigned Mac build (HF-M2-00). Head of Engineering, from the CEO's answer.
- 2026-10-06: **Gate 1 passed: stay on Godot** (CEO). The live Steam achievement line was only partly met and moves to HF-M2-00, with the real store app in M4 as the fallback.
- 2026-10-06: **M2 plan approved** (CEO), with its defaults: the player leads one hero, picked before each run, in place of the mouse aura; enemies attack towers and heroes; a home screen; hero and tower upgrades; 4 heroes; an unsigned Mac test build; unpaid testers through a private itch.io page with download keys (the CEO sees the recruitment post first). M2 does not start until the CEO says so.
- 2026-10-06: Difficulty levels wait for M5 (Hard mode and endless modifiers), so tester results in M2 stay comparable (CEO, on the Advisor's advice).
- 2026-10-06: The recruitable characters are called **heroes** in the game, the store page and plans from M2 on (CEO). M1 code and this board's M1 items keep "staff".
- 2026-10-06: **One Hero, many Recruits** (CEO, replacing the "heroes" naming and the pre-run hero pick above). There is exactly one Hero, the character you control: player-named, with 3 skill paths. Everyone you hire is a **Recruit**: hired with gold, with a generated name, a class and a trait, and no skill tree. M1 code and this board's M1 items keep "staff".
- 2026-10-06: **Theme: The Last Lighthouse** (CEO, from the Advisor's three options). A lighthouse on a coast swallowed by a living fog. Fog creatures attack, the Hero is the Keeper with a lantern, Recruits are rescued survivors, and keep upgrades widen the beam to push the fog back. "Holdfast" stays the working title until the M2 name check, which also covers lighthouse names. The Weird West and The Hive are kept for possible later versions.
- 2026-10-20: **Shipping rules adopted** (CEO's shipping playbook): `studio/playbook/shipping.md`, linked from `CLAUDE.md`. QA results name a commit hash; release candidates get a production-shaped run and the full suite in CI's order; findings are graded MUST FIX or FOLLOW-UP; expected-failure tests come first for high-risk items; overlap is checked before every merge. Docs-only board, estimate, slate and plan PRs may be opened and merged by the Head of Engineering once CI is green; everything else is opened by its owner and merged by the Head of Engineering. M2 stays paused until the CEO says go.
- 2026-10-21: **M2 runs as short iterations** (CEO: keep it very lean, test iteratively, give feedback as it develops). A playable build for the CEO after each slice; outside testers and Recruit trait boss drops are out of M2; Gate 2 is decided from the CEO's own playtests. Sanity checks per slice, one full QA round at the end (HF-M2-12). Plan and dates in `studio/estimates.md`. Head of Engineering, from the CEO's message.
- 2026-10-21: **Go on M2** (CEO). Scope changes folded in before work: the Hero gets more skills (10 a path), Recruits get small skill trees (reverses 'no skill trees'), gear is for the Hero only, and a mini-boss ends level 5 (coordinator default; further boss placement is M5 planning). New item HF-M2-16. Head of Engineering, from the CEO's message and the Advisor's view.
