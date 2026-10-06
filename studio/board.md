# GameLab work board

*Owned by the Head of Engineering. One section per game plus the Kit. Every item has one owner and 2-5 checkable Done when lines before anyone works on it; review and QA go against those lines. Only the Head of Engineering changes an item's status and merges (once CI is green); engineers never merge their own work. Every finding goes in **Findings** below with an owner before anyone fixes it. Dates come only from `studio/estimates.md`.*

**Statuses:** Ready · In progress · In review · In QA · Done · Blocked
**QA depth:** `full` (core logic: kit, save and offline earnings, Steam, release pipeline) · `screens` (interface only: sanity plus a walk of changed screens) · `sanity`. Unlabelled means full.

**Current focus:** Holdfast Gate 1 passed (CEO, 2026-10-06): stay on Godot. M2 (fun slice → Gate 2) is approved but not started; the M2 items go on this board when the CEO says to start.

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

## Holdfast

*Game one. Plan: `games/holdfast/plan.md`. Milestone: M1 tech proof, done; Gate 1 passed 2026-10-06 (stay on Godot). Next: M2 fun slice → Gate 2, approved, waiting on the CEO's word to start.*

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

## Findings

*Every finding from review, QA, CI or the Advisor goes here with an owner before anyone fixes it. Closed findings stay, marked Fixed with the PR.*

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
