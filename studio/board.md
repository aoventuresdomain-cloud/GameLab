# GameLab work board

*Owned by the Head of Engineering. One section per game plus the Kit. Every item has one owner and 2-5 checkable Done when lines before anyone works on it; review and QA go against those lines. Only the Head of Engineering changes an item's status and merges (once CI is green); engineers never merge their own work. Every finding goes in **Findings** below with an owner before anyone fixes it, graded MUST FIX (blocks merge) or FOLLOW-UP (logged, doesn't block), as in `studio/playbook/shipping.md`. Dates come only from `studio/estimates.md`.*

**Statuses:** Ready · In progress · In review · In QA · Done · Blocked
**QA depth:** `full` (core logic: kit, save data, Steam, release pipeline) · `screens` (interface only: sanity plus a walk of changed screens) · `sanity`. Unlabelled means full.

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
- **Status:** Merged in #44, Build 3 of 7
- **QA:** full
- **Done when:**
  - [ ] Packs can reference entries in other files by id, and the loader rejects a dangling reference naming the file and field (tested).
  - [ ] Every pack carries a schema version; the loader rejects an unknown major version (tested).
  - [ ] Nothing Holdfast-specific is added to `kit/` (repo check passes).

### KIT-07 Save service
- **Owner:** Gameplay Engineer
- **Status:** Merged in #44, Build 3 of 7 (QA focused check clear, no must-fix)
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
- **Status:** Built and merged in #52 (CI makes the Mac package), Build 3 of 7. One line stays open: the three Steam lines on the CEO's Mac, a ten-minute Setup Desk check, not needed to play in the browser
- **QA:** full
- **Done when:**
  - [ ] CI builds an unsigned macOS build with GodotSteam (template pinned by name and SHA-256, as for Windows) and a one-click `steam-test.command`.
  - [ ] On the CEO's Mac with Steam for Mac running, it logs `[steam] ready, app 480` and `[steam] achievement ACH_WIN_ONE_GAME: unlocked`. Evidence is a screenshot of the pop-up or of Spacewar's achievements page, which closes HF-M1-05 lines 1 and 2.
  - [ ] A Setup Desk checklist covers first launch of an unsigned app (right-click, Open) without asking the CEO to change system security settings.
  - [ ] If the Mac route fails, the live check moves to M4 with the real app ID, and the board says so.

### HF-M2-01 Pacing bands
- **Owner:** Gameplay Engineer (the Balance Analyst role is not woken; amended 2026-10-22 for Build 7 of 8)
- **Status:** Parked for M2b (CEO 2026-10-23 10:17): overall pacing, stat tidy-up and balancing everything happen after all the mechanics are settled. Formerly Build 7 of 8. Not part of the tree, gear and Mage slice
- **QA:** full (pack retune changes outcomes)
- **Done when:**
  - [ ] `games/holdfast/content/pacing-bands.json` holds first-time win-rate bands per pillar and per bot (average and poor) for levels 1-5, with a per-pillar first-time floor, from the Advisor's targets. Hero stats are not nerfed.
  - [ ] It also holds the special on/off gap rule and the Old Pier first-time band. Each band says how the simulator measures it.
  - [ ] Volley and Sniper are within a stated gap on every level (F-044), and Shingle Beach is fair for the Dusk Mage including with one post (F-049). Any Hero buff is cleared with the Advisor and logged first.
  - [ ] The Advisor's view on the bands is logged on the board.

### HF-M2-02 Meta progression: biome, 5 levels and the upgrade tree
- **Owner:** Gameplay Engineer
- **Status:** Merged in #48, Build 3 of 7, waiting on the CEO's playtest (the mini-boss on level 5 follows in Build 5; until then level 5 is a plain level)
- **QA:** full
- **Done when:**
  - [ ] One coastal biome with 5 hand-made levels, the fifth ending in the mini-boss from HF-M2-16, all from packs. The fog edge sits where the keep's beam reaches, and enemies spawn at it, so widening the beam lengthens their walk in (distances from packs, tested).
  - [ ] About 30 upgrade-tree nodes are bought with gold between runs, from packs. The branches are towers (damage, health, repair between waves), keep and gold gain, and unlocks (levels). The 3rd and 4th deploy slots and the recruitment board's size come back with the Recruits in Build 7. The Hero's own paths are separate (HF-M2-14).
  - [ ] Gold and upgrades persist through KIT-07.
  - [ ] The headless and playable builds still end a seeded run identically (parity test).

### HF-M2-14 Your Hero
- **Owner:** Gameplay Engineer
- **Status:** In progress: slice 1 (Flare Archer) merged in #32 on 2026-10-21; slice 2 (Dusk Mage and Tideblade, pillar pick on the start screen) merged in #36 on 2026-10-22, waiting on the CEO's playtest. Not yet built: capstones and nodes (iteration 4), Hero pull in Eclipse
- **QA:** full
- **Done when:**
  - [ ] There is one player-named Hero, the Keeper. They move with WASD and auto-aim at the nearest enemy. The attack comes from their path, and the ability from their path fires with Space on a cooldown. The lantern is the Keeper's light, not their attack: it pushes the fog edge back and gives a damage bonus to anything the Hero hits inside lit areas. Every attack is light, fire or the shadow that light casts. The mouse-cursor aura is gone.
  - [ ] The Hero has 3 pillars from packs (working names, the CEO can rename): Flare Archer (auto-fires flares, Space is Flare Barrage; capstone Beacon Arrow plants a temporary light post), Dusk Mage (auto shadow pulses with a small area, extra damage in unlit fog; Space is Eclipse, which dims the Keeper's own light for a few seconds and pulls and slows enemies into a dark zone; capstone Total Eclipse, with nearby light posts dark while it lasts) and Tideblade (quick short arc stabs, Space is Dash-Strike with the cooldown refunded on a kill; capstone Lighthouse Sweep, a rotating blade line). Only three attack behaviours are coded (projectile, area, arc); the rest is pack data. Each has 10 nodes on a shared skeleton: tier 1 stats and feel, tier 2 changes to the Space ability, tier 3 changes to the main attack, plus a capstone that changes the ability. At least half changing behaviour rather than a percentage, and unlocks a different active ability. Hero level is capped so a tester can buy about 8 nodes in a session; only the next tier is open and deeper tiers show locked. Pillars can be mixed, and a full respec between runs is free or cheap.
  - [ ] Movement and abilities are inputs on the kit engine's fixed timestep, so a seeded run with recorded inputs ends identically headless and in the playable build (parity test).
  - [ ] At zero health the Hero is knocked down, drops their unbanked XP where they fell for the player to collect, and gets back up where they fell (CEO change, 2026-10-22, see HF-M2-18). The delay grows with each knock-down in the run (delays from packs, tested).
  - [ ] Head of QA's strict expected-failure tests, written from worked examples before the build, now pass; boundary cases (zero health, first and fourth knock-down, off and empty pack values) are covered.

### HF-M2-15 Enemies fight back
- **Owner:** Gameplay Engineer
- **Status:** In progress: slice 2 rules (targeting, taunt, downed and revive, lit areas, staffed posts) merged in #36 on 2026-10-22, waiting on the CEO's playtest. Not yet built: the home screen, run summary lists if missing
- **QA:** full
- **Done when:**
  - [ ] Enemies target the nearest tower, Recruit or the Hero, else the keep (rule from packs, tested); a Warden's taunt pulls enemies to it.
  - [ ] Towers have health and are destroyed for the rest of the run at zero; a Recruit at zero health is downed for the rest of the run unless the Hero stands on them for about 3 seconds, which revives them (time from packs); permanent death is only an opt-in Hard setting in M5; all tested, including a simulator run where Recruits fall mid-wave.
  - [ ] Each light post lights a small area, and enemies inside a lit area take extra damage (radius and bonus from packs, tested); a Recruit staffing a post adds its role's effect there (Warden taunt, Lookout mark and slow, Alchemist field, Engineer repair).
  - [ ] Health bars show only on damaged units, a hit flashes clearly (shared with HF-M2-07), and the run summary lists towers lost and Recruits knocked out.
  - [ ] Head of QA's strict expected-failure tests, written from worked examples before the build, now pass; targeting ties, no towers left, and an empty or zero lit-area bonus are covered.

### HF-M2-03 Recruits: hiring, traits, levels and the squad
- **Owner:** Gameplay Engineer
- **Status:** On hold (CEO, 2026-10-22): Recruit work is parked until the core gameplay is established. What exists (Bryn, Wren, revive, leash) stays as is. Comes back as Build 7 of 7 if the CEO wants it
- **QA:** full
- **Done when:**
  - [ ] A recruitment board on the keep screen offers Recruits to hire with gold, from packs. Each has a generated name, one of 4 classes (Warden, Lookout, Alchemist, Engineer; Recruits hold posts and the Hero owns the damage, so Recruit damage stays modest; the Alchemist lays status fields at posts: burn, slow, heal) and one of about 8 traits (for example "Steady: +20% range", "Coward: flees below half health"). Each trait is covered by a rules test.
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
- **Status:** Go (CEO 2026-10-22 19:35), Build 6 of 8, third in the run 4b + 5 + 6. Recruits are parked, so the "squad" lines below mean the Hero plus towers for now Merged in #82 (QA clear on `90acceb`, no MUST FIX). Waiting on the CEO's playtest with 4b and Build 5.
- **QA:** full
- **Depends on:** HF-M2-14, HF-M2-15, HF-M2-02
- **Done when:**
  - [ ] At least 2 new monster types from packs (for example a fast runner and a heavy one), appearing from level 2, each with a rules test and a place in the simulator's bands.
  - [ ] Gear is for the Hero only: the Hero has 2 gear slots filled from a pool of about 6 items in packs, Recruits have no gear slots (tested), and gear persists through KIT-07.
  - [ ] An elite on level 2 or 3 always drops a gear item, so every tester sees gear before the boss.
  - [ ] Level 5 ends with a mini-boss from the fog that cannot be beaten without the Hero's path ability; its behaviour comes from packs (tested) and it drops gear.
  - [ ] Every Hero path, with a squad the bot picks, beats the boss in the simulator (bot report per path), and a Hero-only bot is measured against Hero plus squad.

### HF-M2-17 Slice 2b: monsters that can beat the Hero, and Recruits that move
- **Owner:** Gameplay Engineer
- **Status:** Merged in #40 on 2026-10-22 (Build 2b of 6), waiting on the CEO's playtest. Bot results on 12 seeds: Flare Archer 2 won, Dusk Mage 5, Tideblade 9; a no-input run loses on every pillar
- **QA:** sanity plus the simulator check below (a quick fix to slice 2, from the CEO's first playtest on 2026-10-22; findings F-024 and F-025)
- **Depends on:** HF-M2-14, HF-M2-15
- **Done when:**
  - [ ] The Hero stays as strong as it is now (CEO: do not nerf the Hero). Monsters get stronger instead: enemy health, damage and numbers rise as waves and levels progress, set in packs (no code change just for balance), so that a bot playing each pillar with no upgrades loses some runs and wins some, and a run played with no input loses.
  - [ ] A simulator test fails if a Hero can never lose: for each pillar, across a fixed set of seeds, at least one run ends with the keep fallen or the Hero knocked down more than once, and at least one run is won (thresholds from packs, run in CI order).
  - [ ] Recruits move: each Recruit has a home post and moves to engage the nearest enemy within a leash distance of it, retreats to the post when hurt or when nothing is in range, and stays inside the leash (rule in the rules engine, pack values, tested at the boundary: exactly at the leash, zero leash, downed Recruit does not move). A Recruit staffing a light post stays at it and still adds its role effect.
  - [ ] Parity test and the 60 second budget still pass, the progression hash is re-pinned once with old and new in the PR, and the web build is checked in Chromium.

### HF-M2-18 Hero gets back up where they fell
- **Owner:** Gameplay Engineer
- **Status:** Merged in #48, Build 3 of 7, waiting on the CEO's playtest
- **QA:** sanity
- **Depends on:** HF-M2-14
- **Done when:**
  - [ ] After the 3 s, 6 s, 10 s wait the Hero gets back up where they fell, not at the keep or beside a tower; the wait and the unbanked XP drop where they fell are unchanged (tested for the first and fourth knock-down).
  - [ ] The Hero is untouchable for a short pack-set time (default 2 s) after getting up, so they are not knocked down again at once by whatever stood over them (time from packs, zero allowed, tested at the boundary).
  - [ ] A Hero who fell outside the playfield or on blocked ground gets back up on the nearest open ground inside it (tested), and the headless run and the playable build agree (parity test).

### HF-M2-19 Bigger arena, Hero reaches the edges
- **Owner:** Gameplay Engineer
- **Status:** Merged in #51, Build 3b of 7, waiting on the CEO's playtest
- **QA:** screens
- **Depends on:** HF-M2-14
- **Done when:**
  - [ ] The playable arena is larger (size from packs, default about 1.5 times the current width and height), and the camera shows it without clipping on a 16:9 window and a laptop-sized one.
  - [ ] The Hero can walk to every edge and corner of the arena and no further (tested at each edge and corner), and the arrow and enemy spawns still sit inside it.
  - [ ] No rule, pack tuning or pillar number changes except the arena size and where things sit in it; the progression hash is unchanged or re-pinned once with old and new in the PR, and parity and the 60 second budget still pass.

### HF-M2-20 Levels unlock by winning the previous level
- **Owner:** Gameplay Engineer
- **Status:** Merged in #57, Build 3c of 7, waiting on the CEO's playtest
- **QA:** full (changes save data)
- **Depends on:** HF-M2-02
- **Done when:**
  - [ ] Level N+1 unlocks only when level N is won, never by buying a node; the level-unlock nodes leave the upgrade tree (no node sells a level) and the keep screen shows a locked level with the plain reason "Win the previous level".
  - [ ] An existing save keeps every level it has already unlocked, and a level that was unlocked only by a bought node but never won stays playable for that save (migration tested from the Build 3 save, plus a damaged and a newer save).
  - [ ] Winning a level saves the unlock at once (tested: win, reload, next level open); losing or quitting a level never unlocks the next.
  - [ ] The ten-hour progression run and the parity test still pass, the progression hash is re-pinned once with old and new in the PR, and the 60 second budget holds.

### HF-M2-21 Monsters go for the tower and only fight the Hero up close
- **Owner:** Gameplay Engineer
- **Status:** Merged in #58, Build 3c of 7, waiting on the CEO's playtest
- **QA:** full (core rules)
- **Depends on:** HF-M2-17
- **Done when:**
  - [ ] Monsters head for the tower by default. A monster attacks the Hero (or a Recruit) only while that unit is within a pack-set close distance of it, and goes back to the tower once the unit is out of range; it never follows a unit across the map (tested at the boundary: exactly at the distance, just outside, zero distance means never).
  - [ ] A monster already attacking the tower keeps attacking it while the Hero stands nearby, unless the Hero is inside its close distance (tested).
  - [ ] The Hero is not weaker and monsters are not weaker: the pillar bots still lose some runs and win some, checked with the simulator by pillar (numbers from packs, any retune written in the PR).
  - [ ] Parity test and the 60 second budget pass, the progression hash is re-pinned once with old and new in the PR, and the web build is checked in Chromium.

### HF-M2-22 Early levels are winnable
- **Owner:** Gameplay Engineer
- **Status:** Merged in #65 (2026-10-22), part of Build 4 of 7. Level 1 average bot about 75%, level 2 about 78%, below the Advisor's 90% and 75% for level 1 because the no-input run must still lose; to be raised after the CEO's playtest if needed
- **QA:** full (balance change in packs)
- **Depends on:** HF-M2-21
- **Done when:**
  - [ ] The Hero is not nerfed (no pack value that lowers a Hero's damage, health, speed or ability) and monsters still get stronger wave by wave (health, damage or numbers rise from one wave to the next, tested from packs); the easing comes from the last waves of levels 1 and 2 in packs only (waves 1 to 3 were already won; losses were all in the last wave; HoE call 2026-10-22).
  - [ ] A first-time player with no upgrades wins levels 1 and 2 clearly more often than not: the simulator's bot for each pillar, using a weak (not perfect) play model, wins at least the win rate the Game Design Advisor sets for those levels, and later levels still have wins and losses somewhere in the grid (bands as pack values, checked in CI order).
  - [ ] A run played with no input still loses (at most 10% wins on levels 1 and 2 across seeds, none on 3 to 5; see F-036), and the pillar bots still lose some runs on the later levels (the tower can fall).
  - [ ] Parity and the 60 second budget pass, the progression hash is re-pinned once with old and new in the PR, and any existing-test change has my OK first.

### HF-M2-23 A short pause and a banner between waves
- **Owner:** Gameplay Engineer
- **Status:** Ready, now part of Build 4 of 7 (CEO playtest of Build 3c, 2026-10-22)
- **QA:** screens
- **Depends on:** HF-M2-14
- **Done when:**
  - [ ] Between waves there is a pause of a pack-set time (default 1 second) in which no new monster spawns, and the next wave starts after it (rule in the rules engine, tested: zero allowed, the last wave has no pause after it, headless and playable agree); waves still stack.
  - [ ] A clear banner shows "Wave N" during the pause before each wave (waves still stack; no "Wave cleared" text, HoE call 2026-10-22), readable at 1280x720 and 1920x1080, and does not cover the Hero or the tower.
  - [ ] The ten-hour progression run, parity and the 60 second budget still pass (progression hash re-pinned once if the pause moves it).

### HF-M2-24 Towers can be brought back after they fall (DROPPED)
- **Owner:** Gameplay Engineer
- **Status:** Dropped (CEO, 2026-10-22 17:18): towers are not resurrectable. Nothing to build; any partial work is reverted
- **QA:** full (core rules)
- **Depends on:** HF-M2-15
- **Done when:**
  - [ ] A fallen tower shows as fallen on the map and comes back when the Hero stands on it for the pack-set time (default 3 s), with a pack-set share of its health, once per fall; the Hero leaving, falling or the wave ending resets the timer (tested at the boundary: exactly at the time, one tick short, zero time, Hero knocked down mid-way).
  - [ ] The keep falling still ends the run, a fallen tower is not targeted by monsters, and a revived tower is targeted again (tested).
  - [ ] The simulator's bots use it and the pillar bots' win rates stay inside the bands from HF-M2-22; parity and the 60 second budget pass, the progression hash is re-pinned once.

### HF-M2-25 Hero skills and upgrade tree rework (SUPERSEDED by HF-M2-26)
- **Owner:** Gameplay Engineer
- **Status:** Superseded (CEO, 2026-10-22 19:15): the CEO wants an Incrempire-like tree with sections per tower, starting with the Flare Archer and the Archer Post only. A 17-node version was built locally and held, never pushed. The reusable parts (save migration v2 to v3, respec, either-or and requires fields, next-unlock display) move to HF-M2-26
- **QA:** full (upgrade and save data)
- **Depends on:** HF-M2-14, HF-M2-04
- **Done when:**
  - [ ] The between-run upgrade tree has about 15 to 20 nodes (down from 26), from packs. Branches offer a real choice (picking one closes another), and most nodes change behaviour rather than add a percentage. The gold chain is 2 to 3 nodes. No new tower types.
  - [ ] The two next unlocks are visible on screen with their cost and effect; locked deeper nodes show as locked. The Hero's skills (HF-M2-14) sit in the same screen flow without a new menu.
  - [ ] A blessing pick (1 of 3, HF-M2-04) is offered before each run; each blessing's effect has a rules test.
  - [ ] Saves from the 26-node tree migrate without losing gold or levels (refund of nodes that no longer exist, tested); parity and the 60 second budget pass, the progression hash is re-pinned once with old and new in the PR, and any existing-test change has my OK first.

### HF-M2-26 Flare Archer and Archer Post tree, with site planning
- **Owner:** Gameplay Engineer
- **Status:** Go (CEO 2026-10-22 19:35), Build 5 of 8, second in the run 4b + 5 + 6 (CEO direction 2026-10-22 19:15, plan signed off 19:19: do the Archer and the Archer Post properly first, then other towers, characters and synergies one at a time; Advisor's first-slice shape accepted). No new tower types; the Mage Post and the rest are later slices and need the CEO's go Merged in #77 (QA clear on `150f3cd`, no MUST FIX).
- **QA:** full (upgrade and save data, core rules)
- **Depends on:** HF-M2-14, HF-M2-22
- **Done when:**
  - [ ] The upgrade screen is a tree with sections, built so a further tower section (for example a Mage Post) plugs in from packs without reworking the screen. This slice has two sections: the Flare Archer Hero and the Archer Post. Dimmed distant nodes, the next unlocks shown with cost and effect, a cheap or free respec.
  - [ ] The Archer Post section has about 11 nodes from packs (CEO signed off 2026-10-22 19:19: four basics for tower health, fire rate, damage and range, one repair, then the Sniper or Volley fork with a final node each) with a fork between two styles (Sniper or Volley) that closes the other. The nodes mix plain stat upgrades in the Incrempire way (tower health, fire rate, damage, range; CEO 2026-10-22 19:17) with a few behaviour-changing ones, so the player always has cheap upgrades to buy as well as real choices. The Flare Archer Hero's path (HF-M2-14, 10 nodes on the shared skeleton) sits in its own section. Each new effect has a rules test and the tower upgrades are keyed by tower type so later towers reuse them. The tower data leaves room (empty fields, no behaviour) for a bonus when a Recruit is posted there and a bonus when the Hero's flare lands in the tower's area, so synergies plug in later; nothing else is built for them (Advisor, CEO agreed 2026-10-22).
  - [ ] Before a run on levels 1 and 2 a planning screen lets the player choose which sites get an Archer Post (the number of posts is limited by a pack value); enemies come from more than one direction on those levels so the choice matters; the chosen layout is used by the run, saved with the profile and shown on the run start. The choice is made before the first wave (no mid-run placing in this slice).
  - [ ] The simulator's bots use the planning choice and the fork; the first-time bands from HF-M2-22 still hold and each fork has a win rate inside the pillar bands (checked in CI order); parity and the 60 second budget pass; the progression hash is re-pinned once with old and new in the PR; any existing-test change has my OK first and is logged.
  - [ ] Saves from the current tree migrate without losing gold or levels (refund of nodes that no longer exist at their old cost, tested); the web build is checked in Chromium.

### HF-M2-27 Stronger specials and a post-win screen (slice 4b)
- **Owner:** Gameplay Engineer
- **Status:** Go (CEO 2026-10-22 19:35): slice 4b, built first in the run 4b + Build 5 + Build 6. The Dusk Mage's and Tideblade's specials follow the Advisor's view, asked for at the start of the run Merged: part 1 in #74, part 2 in #76 (QA clear on `9883a17`).
- **QA:** full (core rules for the special), screens for the post-win screen
- **Depends on:** HF-M2-14
- **Done when:**
  - [ ] The Flare Archer's Space special becomes a short burst of rapid fire for a few seconds (duration, rate and cooldown from packs), clearly stronger than the old barrage in play; the simulator's Flare bot uses it and the first-time bands from HF-M2-22 still hold (retune in packs only, written in the PR).
  - [ ] The Dusk Mage's and Tideblade's specials are reviewed with the Advisor's view and strengthened only as that view says (numbers from packs, tested at the boundary: zero cooldown, zero duration).
  - [ ] After a win, a screen offers Next level and Upgrade screen (Next level is not offered after the last unlocked level or a loss; a loss keeps its current screen); readable at 1280x720 and 1920x1080; saved gold and unlocks are written before the screen shows.
  - [ ] Parity and the 60 second budget pass, the progression hash is re-pinned once with old and new in the PR, and any existing-test change has my OK first.

### HF-M2-28 Recalibrate levels and balance all pillars
- **Owner:** Gameplay Engineer
- **Status:** Backlog, M2b (CEO 2026-10-23 10:17): balancing every pillar and level, the stat-model unification and the overall pacing wait until all the mechanics are settled. HF-M2-35 keeps only levels 1 to 5 winnable for the Flare Archer with the new empty-castle start
- **QA:** full (pack retune changes outcomes)
- **Done when:**
  - [ ] Bands per pillar and per bot (average, poor) for every level, with a per-pillar first-time floor, from the Advisor's targets (pillar balance view, 2026-10-22, in the Advisor views table). Hero stats are not nerfed.
  - [ ] Dusk Mage and Tideblade are brought within the floor (F-044, F-049, F-043), and Volley and Sniper are within the stated gap per level.
  - [ ] The simulator gates on the bands and CI fails when one is missed (HF-M2-01, HF-M2-05).
- **Notes:** Re-scoped from Build 7 (parked). When Build 7 is proposed again it is mechanics-first and Archer-only, not a cross-pillar balance pass.

### HF-M2-29 Menus, journey map and Plan page (navigation rework, part 1)
- **Owner:** Gameplay Engineer (the UI Engineer thread is closed; the Gameplay Engineer built the current screens)
- **Status:** Merged (#88, #91), QA clear, waiting on the CEO's playtest. Walls, synergies and Recruits stay out
- **QA:** full (screens and the run flow change; tests that click through the flow change, each with my OK first)
- **Done when:**
  - [ ] A main menu with Continue, New game, Settings and Quit opens the journey map. The home and keep screens no longer exist as two screens that do the same job.
  - [ ] The journey map is a path of level nodes: cleared nodes show a tick, the next glows, locked ones are dimmed, the level 5 boss is marked. Tapping an available level opens the Plan page, the map shows the Hero as a tappable figure beside the path, and has a button to the skill tree (the existing tree screen, unchanged for now) and shows gold and an "upgrades available" glow.
  - [ ] The Plan page shows the level map with the tower sites. Available towers are cards (the Archer Post card only) that the player drags into slots around the castle, within the pack-set post limit. Auto-place gives a suggested layout, and Quick start reuses the last layout and starts the level. Nothing is placed inside the level.
  - [ ] Tapping the Hero opens a Hero page that takes over the existing pillar picker and the Gear row (two slots, owned gear, worn; no new gear), with a link to the Hero section of the tree. Wearing and removing gear save as today. Recruits are not shown yet (room left).
  - [ ] The result screen offers Next level (to the Plan page) and the journey map, and the skill tree beside it. Old saves load unchanged, with layouts and gear kept. Walls and other new piece types are not built (they need the CEO's go); the slot and card data leave room for them.

### HF-M2-30 Skill tree as one zoomable web with jump tabs (navigation rework, part 2)
- **Owner:** Gameplay Engineer (the UI Engineer thread is closed; the Gameplay Engineer built the current screens)
- **Status:** Merged (#92), QA clear, waiting on the CEO's playtest. Walls, synergies and Recruits stay out
- **QA:** full
- **Depends on:** HF-M2-29
- **Done when:**
  - [ ] The skill tree is one web the player pans and zooms, with tabs along the top (Hero, Archer Post, Keep) that move the view to a section. Sections for towers and Recruits that do not exist yet are not shown.
  - [ ] Node positions and links come from the packs (data only); nodes beyond the next one or two steps are dimmed, and buying, respec, refund and the Hero pillar choice work as they do now.
  - [ ] The tree opens from the journey map, and the existing save, migration and refund rules are unchanged (no node ids lost).
  - [ ] Bridge nodes and Hero and tower synergies (the Keeper's light through towers) are NOT in this item; they follow as their own item once the web and the Plan page exist.

### HF-M2-32 Stars, empty castle and Level 0 (tree rework, part 1)
- **Owner:** Gameplay Engineer
- **Status:** Merged (#100, QA clear at 8ca3388). Originally: Ready. CEO go 2026-10-23 09:27 on the Advisor's tree and star logic (`/mnt/project-files/holdfast/m2/advisor-tree-grammar-and-first-nodes.md`). Costs are placeholders, tuned in HF-M2-35. Build order is HF-M2-32, 33, 34, 35, one PR each, merged in order
- **QA:** full (save data and the run flow change)
- **Done when:**
  - [x] A new game starts with an empty castle (no slots, no cards, no stars). Level 0 is on the journey map, cannot be lost (the Keep cannot fall) and pays exactly 2 stars and 150 gold once; its teaching text is a short stub (the full tutorial text follows later).
  - [x] A won level pays stars once per level: 1 for a win, 2 above 50% Keep health left, 3 above 80%; a replay pays only the stars not yet earned. Stars show on the journey map and in the tree.
  - [x] After Level 0 the map guides two compulsory purchases in order, First Slot then the first tower from the tree (Archer is the only choice for now), before any level can be started. The Plan page shows only the slots and cards owned, around the castle ring of 8 spots, and will not start a level with no tower placed.
  - [x] Old saves load: every bought node is refunded in full as gold, stars are granted as if the won levels had paid 3 each plus the 2 from Level 0, and layouts reset to a first visit. A null or damaged field loads as a fresh value, never a crash.

### HF-M2-33 One connected tree with stars, slots and respec (tree rework, part 2)
- **Owner:** Gameplay Engineer
- **Status:** Building (HF-M2-32 merged). The CEO approved the pan and zoom fix (2026-10-23 10:12); it goes in as its own commit
- **QA:** full
- **Depends on:** HF-M2-32
- **Done when:**
  - [ ] The tree is one connected graph (castle arm, Keeper ring, Flare Archer arm, Archer Post arm, Tithe and Stone walls) that starts at First Slot; only nodes next to an owned node are shown; positions and links come from the packs (data only).
  - [ ] Gold nodes cost gold, star nodes cost stars; castle nodes grant the slots and cards the Plan page uses (cards stay two behind slots); forks exclude each other; both Archer capstones can be bought with enough stars; the two new stat nodes (Steady hands, Lamp oil) work in a run.
  - [ ] Respec refunds a node's price minus a fee (about 10% of a gold node's price, at least 20 gold; a flat 50 gold for a star node; stars back in full) and is refused mid-run.
  - [ ] Dragging pans the web from anywhere including over nodes (a click without movement still buys), wheel and trackpad zoom at the cursor between about 0.4x and 2.5x, and the page does not scroll or zoom over the tree.
  - [ ] The Plan page's slot buttons and tray do not overlap with all 8 spots and 8 cards at 1280x720 and 1920x1080 (F-063); the journey map header spaces Gold and Stars cleanly and the map does not shift when the guide strip goes (F-062).
  - [ ] Mage, Mender and Frost posts, Tower Gate I, walls, Recruits and Hard and Nightmare replays are not built (they need the CEO's go).

### HF-M2-34 Six Hero and tower links (tree rework, part 3)
- **Owner:** Gameplay Engineer
- **Status:** Ready, after HF-M2-33 is merged
- **QA:** full (core rules change)
- **Depends on:** HF-M2-33
- **Done when:**
  - [ ] Lit Post and Crossfire work in a run: a post with the Hero within about 150px fires 25% faster; two posts shooting the same enemy deal 20% more.
  - [ ] Pillar Echo and Last Light work: Flare Archer arrows from the post burn; a post about to fall flares and fires one big volley when the Hero is close.
  - [ ] Rally and Watchtower work: holding next to a post repairs and shields it for 3 seconds; standing near an Archer Post gives the Hero more range.
  - [ ] Each link is a star node placed next to the nodes it needs in the tree, has a test of its effect and of its absence, and the Hero is not nerfed.

### HF-M2-35 Retune levels 1 to 5 for the empty-castle start (tree rework, part 4)
- **Owner:** Gameplay Engineer
- **Status:** Ready, last of the tree slice: after HF-M2-37 is merged (it tunes everything the earlier items added). Archer only; other pillars stay in HF-M2-28
- **QA:** full
- **Depends on:** HF-M2-37
- **Done when:**
  - [ ] The simulator has bots that place posts by the stars a player would have at that point, wear the gear a player would have found, place Mage Posts when the gate is taken, and buy gold nodes on the same curve, and the progression hash is re-pinned with the reason logged.
  - [ ] Levels 1 to 5 hit the Advisor's win-rate targets for the Flare Archer on that curve (about 90% on level 1 and 75% on level 2, the rest from the Advisor's table), with the numbers in the PR body.
  - [ ] A player never goes more than about three runs without being able to afford something new, checked by the same bots.
  - [ ] Any pack numbers changed are data only, and no existing test is loosened without my OK.

### HF-M2-36 Hero gear: five slots, inventory and stat breakdown
- **Owner:** Gameplay Engineer
- **Status:** Ready, after HF-M2-34 is merged. CEO go 2026-10-23 10:12. Design: Advisor's view (`/mnt/project-files/holdfast/m2/advisor-tree-stats-gear-ring.md`, section 3). Item numbers are placeholders for HF-M2-35
- **QA:** full (save data and Hero stats change)
- **Depends on:** HF-M2-34
- **Done when:**
  - [ ] The Hero has five slots (Weapon, Helmet, Armour, Boots, Ring), each with its own stat identity (pack data). The six existing items move to the right slots with their ids kept, and about six new items fill Helmet, Armour, Boots and Ring (about 12 in all).
  - [ ] The Hero page shows an inventory of owned items; dragging an item into its slot wears it (same gesture as the Plan-page cards) and a tap works too; wearing and removing save, and the Hero page shows a stat breakdown (base, tree, gear) using the existing add-then-multiply rule.
  - [ ] Items come from play: one first-clear item per level plus elite and boss drops, each given once. Old saves keep what they own and wear (the old `charm` slot maps to the item's new slot) and load without a crash.
  - [ ] Gear stays Hero-only; no Recruit gear.

### HF-M2-37 Mage Post and the first Tower Gate
- **Owner:** Gameplay Engineer
- **Status:** Ready, after HF-M2-36 is merged. CEO go 2026-10-23 10:12 on the Mage Post and the first Tower Gate. Design: the Advisor's sketch (`advisor-tree-grammar-and-first-nodes.md`, Tower Gate I) and its tree view (`advisor-tree-stats-gear-ring.md`, section 1)
- **QA:** full (new tower type, tree and Plan page change)
- **Depends on:** HF-M2-36
- **Done when:**
  - [ ] Tower Gate I is a star node in the tree (2 stars, and 5 nodes owned) that says how many more nodes it needs. It offers the Mage Post; the Mender and Frost posts are not built and are not offered yet. Taking the gate opens a Mage card on the Plan page, placed in the same slots as the Archer.
  - [ ] The Mage Post works in a run: area damage that hits hardest in the dark, from pack data (stats in `towers.json`), with its own health, range and cooldown, and monsters target it like the Archer Post.
  - [ ] A short Mage branch in the tree (a few gold stat nodes, with one Hero link: Eclipse is wider when centred on a Mage Post), placed next to the gate.
  - [ ] Old saves load unchanged (the gate is simply not taken). The three reserved links, the Mender and Frost posts, walls and Gate II are not built.

### HF-M2-05 Simulator covers the slice and gates on the bands
- **Owner:** Gameplay Engineer
- **Status:** Parked for M2b (CEO 2026-10-23 10:17); formerly Build 7 of 8, amended for the parked Recruits. HF-M2-35 adds only the bots the tree slice needs
- **QA:** full
- **Depends on:** HF-M2-01
- **Done when:**
  - [ ] Two bots (average and poor) play levels 1-5 headless in CI within the existing time budget, for every pillar, with upgrades, tree picks and post sites.
  - [ ] The report checks HF-M2-01's bands for both bots and every pillar, and shows win rates per level and pillar.
  - [ ] CI fails when a band is missed.

### HF-M2-06 Home screen and keep screen
- **Owner:** Gameplay Engineer for the Build 3 part below (plain screens, no new role woken); UI Engineer for the polish later
- **Status:** Build 3 part merged in #48, waiting on the CEO's playtest; the Build 4 and 5 parts stay Ready
- **QA:** screens
- **Done when:**
  - [ ] A home screen (Continue, New game, Settings, Quit) leads to the keep screen, the hub between runs.
  - [ ] The keep screen holds level select, the upgrade tree, the Hero's paths and respec, the recruitment board, the Recruit roster, the squad pick, the blessing picker and naming. All of it works with the mouse alone.
  - [ ] The in-run HUD shows the Hero's health and ability cooldown, the knock-down timer, and the towers and Recruits lost.
  - [ ] Text is readable at 1280×720 and 1920×1080 in the Windows build and the browser.
  - [ ] The screens change progress only through the rules' own actions (no direct state writes), tested.

### HF-M2-07 Feel and settings
- **Owner:** UI Engineer
- **Status:** Deferred (CEO, 2026-10-22 19:35): mechanics first; feel, look and animation are agreed after Build 8, with a Designer giving rough sketches in a separate thread first. Not part of Build 6
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
- **Status:** Ready, parked with Build 7 until the CEO confirms after Build 6; needs a Researcher thread from the Chief of Staff (the Gameplay Engineer does not do trademark searches)
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
| F-023 | HF-M2-14 | `test_playable_hero.gd::test_the_player_controller_reads_actions_and_keeps_a_press_until_a_tick_takes_it` failed once in CI on a PR that touched no code ("expected false, got true"), then passed on re-run of the same commit (HoE, #35) | Minor | Gameplay Engineer | Fixed in `player_hero.gd` in #36 with the test unchanged |
| F-024 | HF-M2-17 | The monsters are too weak: the CEO could not die in the slice 2 build; the fix is stronger monsters, not a weaker Hero (CEO playtest, 2026-10-22) | Major | Gameplay Engineer | Fixed in #40, waiting on the CEO's playtest |
| F-025 | HF-M2-17 | Recruits do not move; the CEO expects them to move and fight, not stand like towers (CEO playtest, 2026-10-22) | Major | Gameplay Engineer | Fixed in #40, waiting on the CEO's playtest |
| F-026 | HF-M2-02 | FOLLOW-UP from QA on the save service: in the web build a save is lost whole if the tab closes in the same instant it is written (nothing half-written, the previous save loads). The game must autosave at end of run and after spends and upgrades, not rely on a save-on-quit hook (QA, commit 804ecd3a) | Minor | Gameplay Engineer | Fixed in #48 (autosave after every spend and at the end of each run), waiting on the CEO's playtest |
| F-027 | HF-M2-18 | FOLLOW-UP, design: because the Hero now gets up where they fell, they stand on their own dropped XP and pick it up at once, so the knock-down no longer costs unbanked XP. Left as the CEO specified; the CEO judges after playing, an option is to get up a short step from the token | Minor | Head of Engineering | Open, for the CEO's call after the Build 3 playtest |
| F-028 | HF-M2-01 | Balance: the Flare Archer wins Tidewrack Cove about 1 in 40 seeds with its kit (1 in 12 before the bigger arena) while the Tideblade wins most; not retuned in Build 3 | Minor | Gameplay Engineer | Open, handled with the pacing bands in Build 6 unless the CEO's playtest says otherwise |
| F-029 | HF-M2-19 | FOLLOW-UP from QA's screens walk: Recruit name and down labels are about 7 px tall at 1280x720 (0.65 scale), hard to read | Minor | Gameplay Engineer | Open, a small fix in a later build |
| F-030 | HF-M2-19 | FOLLOW-UP from QA's screens walk: with the Hero at the top edge, its aura arc and health bar draw faintly over the HUD panel's lower edge | Minor | Gameplay Engineer | Open, a small fix in a later build |
| F-031 | HF-M2-21 | FOLLOW-UP from QA: with monsters going for the tower, bot win rates fall (336 to 282 wins of 540 across pillars, levels and upgrade tiers; Dusk Mage and Tideblade harder, Flare Archer level; fresh-profile Gull Rock 0 of 36). No pack value weakens the Hero or strengthens monsters beyond the targeting rule. Not retuned in Build 3c | Minor | Gameplay Engineer | Open, handled with the pacing bands in Build 6 unless the CEO's playtest says otherwise |
| F-032 | HF-M2-20 | FOLLOW-UP from QA: the save migration crashes on wrong-typed fields in a hash-valid, hand-edited save (null upgrades, non-numeric gold), and a hand-edited unlocked list can open a later level alone. Not reachable in normal play | Minor | Gameplay Engineer | Open, low priority |
| F-033 | HF-M2-03 | Known issue from the CEO's playtest: only Bryn moves, the other Recruit stays put (CEO, 2026-10-22). Recruits are parked | Minor | Gameplay Engineer | Open, for Build 7 (Recruits); only worked on earlier if trivial |
| F-034 | HF-M2-23 | FOLLOW-UP from QA (#62): the wave banner can sit over the Hero when it stands in the top-centre strip about 60 units inside the north edge, for that 1 s; the test only checks the start position | Minor | Gameplay Engineer | Open, rides the next PR that touches the banner |
| F-035 | HF-M2-23 | FOLLOW-UP from QA (#62, test gap): nothing pins that `wave_banner()` returns an empty string once the last wave has started | Minor | Gameplay Engineer | Open, a test added in the next Gameplay PR |
| F-036 | HF-M2-22 | FOLLOW-UP from QA (#65): with no input, Outpost Flare Archer wins 3 of 40 seeds (the idle Hero auto-fires); every other level and pillar is 0 of 40 | Minor | Gameplay Engineer | Open, accepted at up to 10% on levels 1 and 2; test pin only if under about 5 s |
| F-037 | HF-M2-22 | FOLLOW-UP from QA (#65): the first-time bands are pooled over pillars, so a first-time Dusk Mage on Outpost wins 53% (average bot) and the poor bot is under 50% for every pillar on at least one of the two levels | Minor | Gameplay Engineer | Open, per-pillar floor goes to Build 6 pacing |
| F-038 | HF-M2-27 | FOLLOW-UP from QA (#74): no test counts arrows per burst, so a double-fire mutant passes all 308 tests | Minor | Gameplay Engineer | Open, a test added in the next Gameplay PR |
| F-039 | HF-M2-27 | FOLLOW-UP from QA (#74): an enemy killed by burn in `_step_enemies` still acts that tick (a burning enemy at 0.05 hp hit the keep for 9, with no kill or gold) | Minor | Gameplay Engineer | Open |
| F-040 | HF-M2-27 | FOLLOW-UP from QA (#74): the Shingle Beach retune hardens it for the Dusk Mage (73% to 53%) and Tideblade (98% to 88%); the Flare first-time lift is about +20 on average and +42 poor | Minor | Gameplay Engineer | Open, per-pillar bands in Build 6 pacing (as F-037) |
| F-041 | HF-M2-26 | FOLLOW-UP from QA (#76): Dash is hittable on the tick after the cast (Hero 80 to 70 reproduced) | Minor | Gameplay Engineer | Fixed in #77 (grace set on the cast tick, test and mutant) |
| F-042 | HF-M2-27 | FOLLOW-UP from QA (#76): the burst test counted `projectiles.back()` once per tick, so a double `_fire` mutant passed (F-038 half closed) | Minor | Gameplay Engineer | Fixed in #77 (counts every arrow spawned) |
| F-043 | HF-M2-27 | FOLLOW-UP from QA (#76): Old Pier first-time with no upgrades is much harder (Flare avg 14 to 5 of 30, poor 6 to 0); no band for levels 3-5 | Minor | Gameplay Engineer | Open, Build 7 pacing (with F-028, F-031) |
| F-044 | HF-M2-26 | FOLLOW-UP from QA (#77): Volley beats Sniper (Old Pier 8000 gold: Dusk 13 vs 34 of 40, Tideblade 32 vs 39; Gull Rock Dusk 28 vs 40); CI needs only 1 in 12 | Minor | Gameplay Engineer | Open, Build 7 pacing |
| F-045 | HF-M2-26 | FOLLOW-UP from QA (#77): the fork test reaches no fork node at 500 and 2500 gold | Minor | Gameplay Engineer | Open, Build 7 if cheap |
| F-046 | HF-M2-26 | FOLLOW-UP from QA (#77): null upgrades or gold in a v2 save file gives a script error and gold silently 0 | Minor | Gameplay Engineer | Open, Build 6 if tiny (data-integrity) |
| F-047 | HF-M2-26 | FOLLOW-UP from QA (#77): `buy()` in the rules accepts another pillar's Hero node (the UI hides it) | Minor | Gameplay Engineer | Open, Build 6 if tiny |
| F-048 | HF-M2-26 | FOLLOW-UP from QA (#77): only the first post's repair is tested (mutant survived) | Minor | Gameplay Engineer | Open, Build 6 if tiny |
| F-049 | HF-M2-26 | FOLLOW-UP from QA (#77): Shingle Beach after the retune is hard for the Dusk Mage (53% to 37%) and one post only is a trap (Dusk 1 of 20) | Minor | Gameplay Engineer | Open, Build 7 pacing |
| F-050 | HF-M2-16 | FOLLOW-UP from QA (#82): null `levels_won`, `unlocked` or `gear.owned` in a save still throws in `from_save` and leaves the profile data empty (the guard covers only gold and upgrades; use `_list` for all list reads). Same family as F-046 | Minor | Gameplay Engineer | Open, next Gameplay PR (data-integrity) |
| F-051 | HF-M2-16 | FOLLOW-UP from QA (#82): after the `kit_gold` pack change the fork test reaches only the first fork node at Old Pier 5000 and none elsewhere; the Flare Archer wins 40 of 40 on every kit level and `min_hard_runs` is 0, so no loss check exists on kit levels | Minor | Gameplay Engineer | Open, goes with HF-M2-28 (recalibrate with the levels) |
| F-052 | HF-M2-16 | FOLLOW-UP from QA (#82): not checked, the Hero-only bot against the Hero-plus-squad line | Minor | Head of QA | Open, Gate 2 round |
| F-053 | HF-M2-29 | MUST FIX from the Gameplay Engineer (#88): the test runner does not report FAIL when a test dies with a script error after an earlier expectation passed (three `test_build4b.gd` tests errored on a missing node and still showed ok) | Major | Gameplay Engineer | Closed in #91 (QA checked) |
| F-054 | HF-M2-29 | FOLLOW-UP from QA (#88, fadb96d): the drawn Hero figure on the journey map is not tappable, only the "Hero: <path>" button below it (the Done when line says a tappable figure) | Minor | Gameplay Engineer | Closed in #91 (QA checked) |
| F-055 | HF-M2-29 | FOLLOW-UP from QA (#88, fadb96d), cosmetic: at 1080p the level 1 name label touches the glow ring and the Tidewrack Cove label sits on the path | Minor | Gameplay Engineer | Closed in #91 (QA checked) |
| F-056 | HF-M2-29 | FOLLOW-UP from QA (#91, 1eea004): returning a lifted post to the tray only works when dropped on the "Towers" caption or thin gaps; dropping on a card, empty space or the buttons silently does nothing | Minor | Gameplay Engineer | Mostly fixed in #92 (2ef6dff). Gap left: the empty spacer between the last card and Auto-place still refuses a drop. Open FOLLOW-UP |
| F-057 | HF-M2-30 | FOLLOW-UP from QA (#92, 134c2f2): one bad pack section produces 128 follow-on "no upgrade_sections entry" errors after the real one | Minor | Gameplay Engineer | Open, Gate 2 round |
| F-058 | HF-M2-30 | FOLLOW-UP from QA (#92, 134c2f2): the "Hero" tab name is hard-coded in `run_flow.gd` but tab names are pack data, so a rename silently breaks the Hero link jump | Minor | Gameplay Engineer | Open, Gate 2 round |
| F-059 | HF-M2-30 | FOLLOW-UP from QA (#92, 134c2f2): the layout test no longer size- or clip-checks section heading labels (nodes are checked as strictly as before) | Minor | Gameplay Engineer | Open, Gate 2 round |
| F-060 | HF-M2-28 | Backlog from QA (#92): with Dusk Mage or Tideblade there is no Hero tab, so the Hero page link still says "Open the Dusk Mage section" and opens on Archer Post. Belongs with the other pillars' work | Minor | Gameplay Engineer | Backlog, HF-M2-28 |
| F-061 | HF-M2-32 | FOLLOW-UP from QA (#100, 8ca3388): the Level 0 teaching text is one unwrapped line, clipped at both screen edges, and vanishes about 2 s into Wave 1. Waits for the full tutorial text, which the CEO skipped for now | Minor | Gameplay Engineer | Backlog, with the tutorial text |
| F-062 | HF-M2-32 | FOLLOW-UP from QA (#100, 8ca3388), cosmetic: the map header separates the Gold caption from its value and the value sits against Stars; the map shifts vertically when the guide strip disappears | Minor | Gameplay Engineer | In HF-M2-33 |
| F-063 | HF-M2-33 | FOLLOW-UP from QA (#100, 8ca3388): with 8 spots and 8 cards the Plan slot buttons overlap in pairs (3/5/7, 4/6/8) at both sizes. Not reachable in the real pack yet (1 slot, 1 card) | Minor | Gameplay Engineer | In HF-M2-33 |
| 2026-10-22 | `games/holdfast/tests/test_m2_hero_getup.gd::test_nearest_open_ground_skips_edges_that_are_blocked_by_another_area` | Second blocked rectangle changed from Rect2(35,10,25,40) to Rect2(20,10,40,40); assertions unchanged (PR #47) | The expected point broke QA's own rule: (35,20) is open ground and nearer than the expected one. Intent kept: the top, right and bottom edges of the first area stay covered | Head of Engineering |

## Test changes

*Only the Head of Engineering may OK changing a test, never on the assumption that the code is right. Ask QA or the Advisor when unclear.*

| Date | Test | Change | Why | OK'd by |
|---|---|---|---|---|
| 2026-10-06 | `games/holdfast/tests/run_ui_tests.gd` | Pin the stub run source instead of the real rules | Its "wave advances" check encoded the stub's pacing; once the real rules are wired in, it would test level balance rather than the UI. The real rules keep their own end-to-end coverage (parity test, exported-build autoplay smoke test) | Head of Engineering |
| 2026-10-21 | `games/holdfast/tests/test_playable_level.gd` | Replaced `test_aura_follows_the_mouse_and_damages_enemies_under_it` with `test_wasd_moves_the_hero_and_its_arrow_hits_an_enemy_in_the_playable_build`; the progression hash is re-pinned once (TICK_RATE 10 to 30, bot Hero replaces the bot aura) | The CEO's design removed the mouse aura, so the old pin is obsolete, not wrong code. The new test goes red with the input wiring broken. The re-pin has the parity test (headless equals playable) and the 60 second budget as its safeguards; old and new hashes are in PR #32 | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_hero.gd::test_the_keep_falling_ends_the_run_with_the_hero_idle` | Setup changed to an unkillable grunt that kills a unit in one hit; assertions unchanged (run lost, keep 0) | The CEO's rule sends enemies to the nearest tower, Recruit or Hero before the keep, so the old single grunt no longer reaches the keep first. Intent kept | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_holdfast_rules.gd::test_a_wave_with_an_enemy_that_reached_the_keep_is_not_cleared` (F-005) | Setup zeroes the Hero's attack damage and lets grunts wipe the defenders before reaching the keep; assertions unchanged (kills 0, waves cleared 0) | The Hero now auto-fires, so the old setup cleared the wave. Intent kept | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_playable_level.gd::test_wasd_moves_the_hero_and_its_arrow_hits_an_enemy_in_the_playable_build` | Setup zeroes every Recruit's damage instead of the per-level staff damage setting; assertions unchanged | Staff damage becomes per Recruit | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned once: `61b99537...4558` to `05a32bb8...b07f` | Enemies fighting back changes every run; the parity test and the 60 second budget (29.9 s for two passes) are the safeguards. Full hashes in PR #36 | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_slice2.gd::test_a_staffed_warden_pulls_enemies_within_reach_off_what_is_nearer` | Setup adds the east post to Bryn; assertions unchanged | The Warden now roams unless staffing a post, so the old default no longer had him staffed. Intent kept | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned once more in #40: `05a32bb8...b07f` to `a1a752ee...a6b9` | Stronger monsters and roaming Recruits change every run. Parity test passes; ten-hour run 45.1 s of the 60 s budget (was 29.9 s) | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/qa_pending.json` | Removed `save_wiring` and `hero_getup` (#48), `save_service` (#44) | Their seams now exist; QA's ratchet requires the removal | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_holdfast_rules.gd::test_numbers_come_from_the_pack` | Node `aura_focus_1` changed to `tower_drills_1`, asserting tower damage is base + 2 (#48) | The aura is gone from play (HF-M2-14) and the tree has no aura nodes. Intent kept: a pack upgrade changes a live stat | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_slice2.gd`: `..._gets_up_at_the_start` to `..._gets_up_where_they_fell`; the dropped-XP pickup test places its token directly; `test_the_start_screen_pick_...` to `test_the_keep_screen_pick_...` (#48) | Expectations follow the new get-up rule and the renamed screen; the 31 px and 30 px pickup assertions are unchanged | HF-M2-18 changes the rule these tests pinned (CEO change). Intent kept | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/run_ui_tests.gd` | Flow test starts on the home screen and clicks New game; layout test adds home and keep at 1280x720 and 1920x1080 (#48) | The app now opens on the home screen | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #48: `a1a752ee...a6b9` to `62191b7c...63f7` | New levels and the 30-node tree change every run. The ten-hour run now stops once every upgrade is bought (50 runs, 9.8 s) because the full ten hours took 71 s against the 60 s budget. Parity test passes | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_hero.gd::test_the_hero_cannot_leave_the_spawn_ring` to `..._leave_the_arena` (#51) | The Hero now stops at the arena edge (x = 960) instead of the spawn ring | HF-M2-19 (CEO change). Intent kept: the Hero cannot walk out of play | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_build3.gd` fog-edge test and get-up-outside test (#51) | Fog-edge test drops its `hero_max_distance` line; get-up-outside test uses x = 1200 and expects 960 | The old distance cap is replaced by the arena edge. Intent kept | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #51: `62191b7c...63f7` to `d0bae866...2829` | Bigger arenas change every run. Parity passes; 49 runs, 9.4 s. Tidewrack Cove `balance_check` seeds raised from 12 to 40 (pack data) | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_build3.gd` (#57): `test_the_tree_has_about_thirty_nodes_in_the_four_branches` to about 26 nodes in three branches; `test_levels_unlock_through_bought_nodes...` to `..._through_wins`; two tests deleted (`test_every_level_has_one_unlock_node_and_levels_open_in_order`, `test_a_dangling_unlock_is_refused_by_the_pack_loader_naming_the_field`); new-profile shape test gains `unlocked`; flow and parity tests no longer buy unlock nodes | Levels now unlock by winning (CEO change, HF-M2-20); the `unlocks` field leaves the game pack schema. Intent kept: tree, unlocks and save rules still tested, now for the new rule | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #57: `d0bae866...2829` to `143e03de...5115` (44 runs, 10.1 s) | The 26-node tree and unlock-by-win change every run. Parity passes | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_hero.gd` `_quiet()` setup (#58) | One setup line pins the Flare Archer's attack damage at 6.0; four tests' assertions unchanged (the hero fires and the arrow hits; keeps firing on the cooldown; a fast arrow cannot skip a thin enemy; an arrow stops at the first enemy) | The Archer's pack damage went from 6 to 7 (a Hero buff), and these tests are hand-worked from 6. Same pattern as test_slice2 | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #58: `143e03de...5115` to `c90d0a9e...b199` (40 runs, 9.4 s) | Monsters go for the tower, so every run changes. Parity passes | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #62: `c90d0a9e...b199` to `d9b81e5c...cf7d` (HF-M2-23 pause between waves; no existing test changed) | A 1 s pause moves every run's timing | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #65: `d9b81e5c...cf7d` to `aa369750...6b4a` (HF-M2-22 easing of the last waves of levels 1 and 2; `outpost` min_hard_runs 1 to 0 in the pack; no existing test changed) | Easier runs end differently | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #74: `aa369750...6b4a` to `1842fa9a...2190` (HF-M2-27 Flare Barrage burst and the Shingle Beach retune: last-wave damage 1.75 to 1.95, grunts 11 to 12, runners 6 to 7; wall 5.9 s) | Stronger Flare changes run outcomes | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #76: `1842fa9a...2190` to `3346f51d...048ec` (HF-M2-27 Eclipse and Dash-Strike; old_pier waves 6 and 7 retuned) | Stronger specials change run outcomes | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_slice2.gd` (four Eclipse and Dash-Strike tests) | Setup-only in #76: each builds with the old Eclipse or Dash fixture; no assertion changed | Fixture set-up only | Head of Engineering |
| 2026-10-22 | Progression hash | Re-pinned in #77: `3346f51d...048ec` to `bda28bd4...09fa7` (HF-M2-26 Archer Post tree, planning screen and the shingle_beach retune) | Tower stats and layouts change run outcomes | Head of Engineering |
| 2026-10-22 | `test_build3.gd` items 1-12 and `test_holdfast_rules.gd` item 13, plus planning Start-click insertions in `run_ui_tests.gd`, `test_build3.gd` and `test_build4b.gd` | Approved by the Head of Engineering for #77: the three Archer Post chains are replaced by the 11-node section, tower stats are keyed by tower, the v1 migration refunds removed nodes and Play opens the planning screen. Old and new for each are in the #77 body; no assertion was loosened | Intended design change | Head of Engineering |
| 2026-10-23 | Progression hash | Re-pinned in #82: `bda28bd4...09fa7` to `d71d47e4...be7d` (HF-M2-16 new monsters, gear, boss and the levels 2-5 retune; 24 runs, 5.1 s) | New monsters and the retune change run outcomes | Head of Engineering |
| 2026-10-23 | `games/holdfast/tests/test_build3.gd::test_a_new_profile_starts_empty_on_the_first_level_and_pillar` | #82: the expected profile gains `"gear": {"owned": [], "equipped": {"weapon": "", "charm": ""}}`, as `"layouts"` did in #77. One UI layout check added in `run_ui_tests.gd`; nothing existing touched or loosened | New save field | Head of Engineering |
| 2026-10-22 | `games/holdfast/tests/test_hero.gd` (four `_fan` fixture setups) | Setup-only change in #74 so the fixtures fit the burst fire rate; no assertion changed | Fixture set-up only | Head of Engineering |
| 2026-10-23 | `test_build3.gd` (4 tests), `test_build4b.gd` (3), `test_build5.gd` (4), `test_build6.gd` (2), `test_slice2.gd` (1), `run_ui_tests.gd` (flow and layout list) | Approved by the Head of Engineering for #88: repointed at the journey map, Hero page and Main menu/Journey map buttons (the keep screen is split); level tap replaces the Play button; pillar and gear checks move to the Hero page. Old and new for each are in the #88 body; no assertion loosened or removed | HF-M2-29 (CEO change). Intent kept | Head of Engineering |
| 2026-10-23 | `test_build5.gd::test_play_opens_the_planning_screen_and_start_runs_on_the_chosen_site`; `run_ui_tests.gd`; `kit/testing/run_tests.gd` (F-053) | Approved for #91: the first-visit test expects 'Posts: 0 of 1' with Start disabled, then places west_gate and north_gate (limit behaviour unchanged); the first-run UI flow presses Auto-place before Start; the runner now reports a script error in a test as FAIL, with a kit test that runs it on a fixture. QA checked eight erroring scratch tests all fail, and the stricter runner exposed no other erroring test. No assertion loosened | HF-M2-29 Plan page (CEO change) and F-053 | Head of Engineering |
| 2026-10-23 | `games/holdfast/tests/run_ui_tests.gd::_check_layout` (and `_texts` gains an optional skip argument) | Approved for #92: the general layout loop skips the web's panned nodes and a per-tab check, after jumping to each tab, asserts every node of the tab is in view, not clipped and at least 20 px on screen including zoom. Nodes are checked as strictly as before; section heading labels are no longer size- or clip-checked (F-059). No other existing test changed | HF-M2-30 tree web (CEO change). Intent kept | Head of Engineering |
| 2026-10-23 | `test_build3.gd`, `test_build4.gd`, `test_build4b.gd`, `test_build5.gd`, `test_build6.gd`, `test_rework_a.gd`, `test_rework_a_plan.gd`, `test_rework_b.gd`, `test_arena.gd`, `run_ui_tests.gd` (#100, listed old to new in its description) | First level, section count, node count, spot ids and start flow updated; `test_arena.gd` sets `source.layout = null` | New first level (Level 0), empty castle, Castle tab and spot ring; no assertion loosened (QA checked the diff) | Head of Engineering |

## Advisor views

| Date | Item | Advisor view | Decision |
|---|---|---|---|
| 2026-10-06 | KIT-02, HF-M1-01 | The headless simulator and the playable build must share one rules engine, including a bot model of the mouse aura, or balance drifts from Gate 2 on. Shared engine in `kit/`, Holdfast combat rules in `games/holdfast/`. | Accepted: folded into KIT-02 and HF-M1-01 Done when lines |
| 2026-10-06 | M2 plan | First review of the M2 draft: 4 heroes with 2 slots to start, extra pacing bands checked by a weaker bot, reward moments, an open survey question | Accepted: all 5 points folded into the M2 plan |
| 2026-10-06 | M2 plan | On the CEO's playtest: agree it plays like Incrempire; the player leads one hero (picked before each run) in place of the mouse aura, enemies fight back, add a home screen and hero and tower upgrades; heroes must be impossible to miss; rename "staff" to "heroes"; difficulty levels wait for M5 | Accepted by the Head of Engineering; the CEO approved the plan, difficulty in M5 and the name "heroes" |
| 2026-10-06 | M2 plan | The hero you lead gets back up at the keep when knocked down, with a longer wait after each knock-down in a run and their unbanked XP dropped where they fell; the run ends only when the keep falls | Accepted: in the M2 plan (HF-M2-14) |
| 2026-10-06 | M2 plan | On the CEO's one Hero, many Recruits: one player-named Hero with 3 skill paths (Guardian, Marksman, Warlord) and free or cheap respec; Recruits hired with gold, each with a generated name, class and trait, levelling but with no skill trees; 2 deploy slots to start; the bot picks a path and a squad, measured per path | Accepted: in the M2 plan (HF-M2-14, HF-M2-03), with 4 Recruit classes |
| 2026-10-21 | M2 scope change | Hero gets 10 nodes a path (3 tiers of 3 plus a capstone), level-capped so about 8 nodes fit a session; Recruit trees of 3 forks of 2 (24 nodes) on the level-up card; Hero-only gear from a pool of about 6; level-5 mini-boss with a guaranteed elite gear drop on level 2 or 3; bands check the squad adds a clear-rate gain | Accepted: HF-M2-14, HF-M2-03, HF-M2-01, new HF-M2-16. A Recruit trait as a boss drop is not in M2 (CEO's call) |
| 2026-10-21 | Hero pillars | The lantern becomes the Keeper's light (fog-push, bonus in lit areas), and every pillar's damage is light or fire. Recruits hold posts and the Hero owns the damage, so Warden no longer competes with the swordsman; Archer becomes Lookout. Shared 10-node skeleton across pillars (tier 1 stats, tier 2 the Space ability, tier 3 the main attack, capstone). Three coded attack behaviours (projectile, area, arc), auto-aim, simple bots, clear times per pillar against the same bands | Accepted: HF-M2-14, HF-M2-03, HF-M2-05 |
| 2026-10-21 | Pillar names | Flare Archer, Dusk Mage and Tideblade with a dark pillar allowed under 'light, fire or the shadow light casts'; Alchemist to status fields at posts so it no longer overlaps the mage's burst; the mage's lit and unlit zones need the simulator to model them | Accepted: HF-M2-14, HF-M2-03, HF-M2-05 |
| 2026-10-22 | Upgrade tree (Build 4) | The 26 nodes left after the level unlocks go are all number bumps in chains, so there is no build variety and the gold chain is a trap. Fewer, chunkier nodes (15 to 20), branching choices, two or three new tower types, a short gold chain, the next unlocks shown on screen, a first-clear reward. Asked the CEO what bothered them most (too samey, too slow, too few choices) | Pending the CEO's answer; folded into Build 4 |
| 2026-10-22 | Pillar balance for Build 7 (asked 23:01) | Recommends buffing the weak pillars (Dusk Mage, Tideblade) and leaving the Flare Archer alone, rather than pack-only tuning, which hides the gap; try a smaller Mage buff plus a stronger Eclipse, and cap flat armour at about 70% block or let area damage partly ignore it. Floor: no pillar more than 10 points under or over the level target, Flare up to +15 on levels 1-2 only, targets about 75 / 60 / 50 / 50 for levels 2-5 (level 5 spread is 50 points today). Volley and Sniper within about 10 points averaged over levels 1-5, one fork may lead by up to 20 on a level only if the monster mix favours it; measure per level, not pooled. Not applied: Build 7 is parked until the CEO confirms after Build 6. |
| 2026-10-23 | Menus and navigation | Four pages joined by a journey map (main menu, journey map hub, skill tree, Plan page). The tree is one big zoomable web with jump tabs, not separate tab pages, so Hero and tower links show as bridges. Placement moves to a Plan page before each level with a budget, Auto-place and a Quick start for the last layout; inside the level the player only upgrades and repairs between waves. Order: menus, map and Plan page first; the web second; bridge nodes and synergies third. Headline twist: the Keeper's light flows through the towers (lit posts, the special fired through nearby towers). Full note: `holdfast/m2/advisor-menus-navigation.md` in the project files. Answered: accepted. Changed: bridge nodes and synergies stay out of the first two items. |

## Decisions and open questions

- 2026-10-22: **Go on the revised plan** (CEO). Recruits are parked until the core gameplay is established (HF-M2-03 on hold, what exists stays as is). The CEO now gets 7 builds: 3 Gold and saves, 4 Hero skills, 5 Monsters and the boss, 6 Pacing, 7 Recruits. Build 3 starts now and includes HF-M2-18. Defaults picked by HoE: the Gameplay Engineer builds the plain Build 3 screens (no new role woken); the save service PR (KIT-07, core logic) gets QA's strict tests plus a focused QA check on that one commit, not a full round.
- 2026-10-22: CEO after Build 2b: pillar difficulty feels good enough (no retune); the Hero gets back up where they fell, not at the keep (HF-M2-18, in Build 3). Defaults picked by HoE: a short untouchable time after getting up, because the Hero can now fall in the middle of a fight; the wait, XP drop and Recruit rules are unchanged.
- 2026-10-22: CEO after Build 3 start: the map felt small and the Hero could not reach the edge (HF-M2-19). Defaults picked by HoE: a quick fix with the Build 3 letter (3b) that rides after Build 3 and changes only arena size; the estimate stays the same.
- 2026-10-22: CEO after Builds 3 and 3b: the map size is fine; levels must unlock by winning the previous level, not by buying in the tree (HF-M2-20); monsters go for the tower and only fight the Hero up close, no chasing across the map (HF-M2-21); the skill tree needs big changes, not yet specified. Defaults picked by HoE: a quick fix called Build 3c of 7 with HF-M2-20 and HF-M2-21 only; the tree changes fold into Build 4, after the Game Design Advisor reviews the tree and the CEO says what they dislike.
- 2026-10-22: CEO after Build 3c: could not beat the levels (too hard after the monster change), wants a pause of about 1 second between waves with a banner, towers that can be brought back, and noted only Bryn moves (F-033, parked); the skill tree needs a different approach, details later. Defaults picked by HoE: a quick fix called Build 3d of 7 with HF-M2-22, HF-M2-23 and HF-M2-24; the Hero is not nerfed and the easing is in the early waves of levels 1 and 2 in packs; towers come back when the Hero stands on them for 3 s; Build 4 is held until the CEO sends the tree direction, and nothing in 3d depends on the tree.
- 2026-10-22: CEO's first playtest of slice 2: the Hero is too strong to die, and Recruits must move. Slice 2b (HF-M2-17) is a quick fix before slice 3; the team stops again after its build. The CEO's follow-up: make monsters stronger, do not nerf the Hero. Defaults picked by HoE: Recruits leash to a home post, engage the nearest enemy in range and retreat when hurt; balance is pack data only.
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
- 2026-10-22: **Go on slice 2** (CEO). Recruits at zero health are downed for the run, and the Hero revives them by standing on them for about 3 seconds; permanent death is an opt-in Hard setting in M5. Staffed light posts give each Recruit role its effect. Slice 2 uses a fixed starter squad from packs; the recruitment board is slice 3. Head of Engineering, from the coordinator's relay of the CEO's yes.
- 2026-10-21: **Stop and test after each playable build** (CEO). After each iteration build, no work starts on the next slice until the CEO has tested and sent feedback or a go; nothing is woken or timed while waiting. Head of Engineering hands the coordinator the build link and a three-line note on what to try. From the CEO's message.
- 2026-10-21: **Hero pillars named: Flare Archer, Dusk Mage, Tideblade** (CEO's Fire Arrow, Dark Magician and Assassin types; names are working names). Attack rule is now light, fire or the shadow light casts; Alchemist moves to status fields. Advisor's view logged. Head of Engineering.
- 2026-10-21: **Hero pillars: fire archer, mage, swordsman** (CEO), replacing Guardian, Marksman and Warlord and the lantern as the Hero's attack. The lantern stays as the Keeper's light (fog-push, damage bonus in lit areas). Recruit Archer renamed Lookout (marks targets, slows fog creatures, extends light) so no Recruit duplicates the fire archer. Advisor's view logged. Head of Engineering, from the CEO's message.
- 2026-10-21: **M2 runs as short iterations** (CEO: keep it very lean, test iteratively, give feedback as it develops). A playable build for the CEO after each slice; outside testers and Recruit trait boss drops are out of M2; Gate 2 is decided from the CEO's own playtests. Sanity checks per slice, one full QA round at the end (HF-M2-12). Plan and dates in `studio/estimates.md`. Head of Engineering, from the CEO's message.
- 2026-10-21: **Go on M2** (CEO). Scope changes folded in before work: the Hero gets more skills (10 a path), Recruits get small skill trees (reverses 'no skill trees'), gear is for the Hero only, and a mini-boss ends level 5 (coordinator default; further boss placement is M5 planning). New item HF-M2-16. Head of Engineering, from the CEO's message and the Advisor's view.
- 2026-10-22 17:18: CEO: towers must not be resurrectable (HF-M2-24 dropped), and Build 3d and Build 4 ship together as "Build 4 of 7", evaluated together. Tree built in the Advisor's direction as HF-M2-25 (about 15 to 20 branching, behaviour-changing nodes, gold chain 2 to 3, next unlocks visible, blessing before each run, no new tower types); details to be discussed after the CEO sees it.

- 2026-10-22 19:15: CEO (with the Advisor): the tree should be Incrempire-like, with sections per tower, but start with the Flare Archer and the Archer Post only, then other towers, characters and synergies one at a time. Tree work becomes its own slice, HF-M2-26, as Build 5 of 8 (the build total goes from 7 to 8: Build 4 is the wave pause and easing, 5 the tree slice, 6 monsters and boss, 7 pacing, 8 Recruits, parked). HF-M2-25 is superseded. The Advisor's wider ideas (Mage and Mender posts, bridges between sections, Recruits at posts, mid-run placing) are not in scope until the CEO says go.
- 2026-10-22 19:31: CEO: waves keep stacking on the timer (no change to the wave overlap). Backlog, idea only: call the next wave early for a bonus, a next-wave countdown, and a wait-for-clear option. Slice 4b (HF-M2-27) is the stronger specials and the post-win screen, held until the CEO's go.
- 2026-10-22 19:35: CEO GO: build 4b (HF-M2-27), Build 5 (HF-M2-26) and Build 6 (HF-M2-16) together as one run, then stop for the CEO's decision. The plan stays at 8 builds; no Look and feel build now. Feel, look and animation (HF-M2-07, HF-M2-08) are agreed after Build 8, with Designer sketches in a separate thread. Waves keep stacking. One combined handoff, labelled 4b / 5 of 8 / 6 of 8. Merge order: 4b, 5, 6.

- 2026-10-22 22:41: CEO GO to add Build 7 of 8 to the run. Reversed at 23:02 (below).
- 2026-10-22 23:02: CEO: reverse the Build 7 add. The run is 4b + 5 + 6 again. The team stops after Build 6 and waits for the CEO to test and confirm before Build 7 (pacing) starts. The Build 7 board items stay amended and parked. Hero buffs vs pack-only tuning is an open question for the Advisor, asked at 23:01, to be answered when Build 7 starts.
- 2026-10-22 23:10: CEO: focus on the Flare Archer and getting the mechanics complete. Balancing the other pillars and recalibrating level difficulty across the board is future work (backlog HF-M2-28, with the Advisor's findings). Build 6 gets only the tuning the Archer needs to be playable. Build 7 stays parked and, when re-scoped, is proposed mechanics-first and Archer-only.

- 2026-10-23 00:30: Run complete: 4b (#74, #76), Build 5 (#77) and Build 6 (#82) are merged, QA clear on each. The team stops and waits for the CEO to test and confirm. Build 7 is parked (notes in `studio/handoffs/2026-10-23-build7-resume.md`).
- 2026-10-23 00:45: CEO feedback after testing 4b, 5 and 6: the upgrade screen and home screen are the same thing; rework into separate pages from a main menu, with levels as a path map (tap an available level to load it), the skill tree on its own page with tabs (tower, Hero, recruit) or one large Incrempire-style tree, and placement on its own page instead of inside the level. The long-term aim is an Incrempire-like game with the CEO's own twist (Hero and tower synergy, other ideas). Advisor asked first for the structure; board item HF-M2-29 proposed. Build 7 stays parked and this likely replaces it as the next slice (CEO decides).
- 2026-10-23 00:56: CEO approved the Advisor's navigation structure (main menu, journey map hub, one zoomable tree page with jump tabs, Plan page before each level) and added that the Plan page is tower cards dragged into slots around the castle, with walls maybe later (a new piece type, needs the CEO's go). HF-M2-29 (menu, map, Plan page) and HF-M2-30 (tree web) are finalised as proposed items; nothing starts until the CEO says go.
- 2026-10-23 00:57: CEO idea: show the Hero (and later Recruits) on the journey map, tappable for gear selection. Advisor agreed; folded into HF-M2-29 as a Hero figure and Hero page (existing pillar picker and Gear row move there, no new gear, Recruits later). No separate item. Nothing starts until the CEO says go.
- 2026-10-23 01:04: CEO go on HF-M2-29 and HF-M2-30 (build A then B, one combined handoff, then stop). Mockups approved as a guide to iterate later. Retry goes via the Plan page with the last layout kept. Still out: walls, Hero-tower synergies, Recruits, Build 7.
- 2026-10-23 08:32: CEO decision: no offline earnings in the game (it was an M5 line with an 8-hour cap in the plan). Removed from the plan, the QA-by-risk rules and this board; nothing in the code or save existed only for it, so no code change. Recruits stay parked, to be improved later.
- 2026-10-23 09:27: CEO go to build the Advisor's tree and star logic (stars buy slots, cards, links and capstones; gold buys stat nodes; empty castle start; Level 0 stub; adjacent nodes only; respec for a small fee). Items HF-M2-32 to HF-M2-35, one PR each in that order. Not in this build: Mage, Mender, Frost, Tower Gate I, the three reserved links, walls, Recruits, Hard and Nightmare replays, blessings, full tutorial text. Stat-model unification (monsters first) is deferred: the tree does not need it and it would widen every PR. Old saves are refunded in gold and given stars rather than mapped node by node.
- 2026-10-23 10:12: CEO go on the tree pan/zoom fix (inside HF-M2-33), Hero gear slots and inventory (HF-M2-36) and the Mage Post with the first Tower Gate (HF-M2-37). Level 0 tutorial text skipped for now (it may change). Order: HF-M2-32, 33, 34, 36, 37, then the retune HF-M2-35 last so it tunes the finished content. One PR each, then one combined handoff and a stop.
- 2026-10-23 10:17: CEO decisions: overall pacing, stat tidy-up and balancing everything move to a later "M2b", after all mechanics are settled (this covers the old Build 7, HF-M2-01, HF-M2-05 and HF-M2-28; relabelled, no new work). M3 and M4 stay unchanged. Final art is the last step after everything else is decided; placeholder art until then, no art work now.
