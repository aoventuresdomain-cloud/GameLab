# GameLab work board

*Owned by the Head of Engineering. One section per game plus the Kit. Every item has one owner and 2-5 checkable Done when lines; review and QA go against those lines. Only the Head of Engineering changes an item's status and merges.*

**Statuses:** Ready · In progress · In review · In QA · Done · Blocked
**QA depth:** `full` (core logic: kit, save and offline earnings, Steam, release pipeline) · `screens` (interface only: sanity plus a walk of changed screens) · `sanity`. Unlabelled means full.

**Current focus:** Holdfast M1 (tech proof) → Gate 1.

## Studio

### STU-01 Repository layout, board and slate
- **Owner:** Head of Engineering
- **Status:** In review
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
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] `games/holdfast/addons/gamelab_kit/` resolves to `kit/` (link or a scripted sync step), on Linux CI and on a Windows checkout, and the method is written in `README.md`.
  - [ ] `godot --headless --path games/holdfast --quit` opens the project with the kit addon enabled and no errors in CI.
  - [ ] Holdfast code calls a kit class, covered by a test.
  - [ ] The Godot version is pinned in one place and used by every CI job.

### KIT-02 Shared simulation engine: timestep, seed and bot runner
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] `kit/sim/` provides a fixed-timestep loop, a seeded random generator and a bot runner that drive any game's rules through one interface; it has no rendering or scene-tree dependency.
  - [ ] The same engine drives both the headless run and the playable build (the build adds rendering and input on top; it never steps the rules itself).
  - [ ] Determinism test in `kit/tests/`: two runs with the same seed and inputs give a byte-identical state hash; a different seed gives a different hash.
  - [ ] Kit tests run headless in CI and red blocks merge.

### KIT-03 Pack format v0 and pack loader
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Done when:**
  - [ ] `kit/schema/` holds a versioned base JSON schema for levels, enemies, towers, staff and upgrade nodes, which games extend.
  - [ ] The loader validates a pack against the schema and rejects an invalid one with an error naming the file and field (tested).
  - [ ] The loader refuses anything that is not data (scripts, scene or resource references), tested.
  - [ ] The Holdfast M1 level, enemy, tower and staff values come from a pack in `games/holdfast/content/base/`, not from code.

### KIT-04 Steam service with a safe fallback
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Depends on:** KIT-01
- **Done when:**
  - [ ] `kit/services/steam` wraps GodotSteam (version pinned) behind a small interface: init, unlock achievement, store stats.
  - [ ] Without Steam running (CI, web build, headless) the service is a no-op that logs once and never crashes, covered by a test.
  - [ ] Uses Valve's public test app ID (480) until Holdfast has its own; no credentials or app secrets in the repository.

### KIT-05 CI pipeline: tests and exports
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Depends on:** KIT-01
- **Done when:**
  - [ ] Kit tests run on every pull request; Holdfast tests and exports run when `kit/` or `games/holdfast/` change; any red job blocks merge.
  - [ ] Every push to `main` produces a Windows build and a web build of Holdfast as downloadable CI artifacts.
  - [ ] The web export runs in a current desktop browser without special server headers (single-threaded export).
  - [ ] The workflow uses no secrets until M4 (Steam upload), and `tools/release/` documents what it will need.

## Holdfast

*Game one. Plan: `games/holdfast/plan.md`. Milestone: M1 tech proof → Gate 1 (stay on Godot or switch to Unity).*

### HF-M1-01 Holdfast combat rules on the shared engine
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Depends on:** KIT-02, KIT-03
- **Done when:**
  - [ ] Holdfast's rules (waves, aura damage, 1 tower, 1 staff, gold and staff XP drops, keep health) live in `games/holdfast/`, plug into the kit engine and have no rendering dependency.
  - [ ] The mouse aura has a bot model that calls the same damage function as the player's aura, so the headless run and the playable build share one set of rules.
  - [ ] The same seeded run gives identical gold, XP and wave results in the headless simulator and in the playable build driven by the bot aura (automated test).

### HF-M1-02 Ten hours of progression headless in under a minute
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Depends on:** HF-M1-01
- **Done when:**
  - [ ] A CI job plays 10 simulated hours of Holdfast progression (repeated runs plus a stub upgrade purchase between runs) with a bot policy, and finishes in under 60 seconds of wall-clock time, printed in the log.
  - [ ] The job writes a report (time to each unlock, gold per run, runs played) as a CI artifact.
  - [ ] The job fails if the 60-second budget is exceeded or the determinism check (two runs, same seed, same report hash) fails.

### HF-M1-03 One playable level in Windows and web builds
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Depends on:** HF-M1-01, KIT-05
- **Done when:**
  - [ ] Enemies come in waves at the keep; the aura follows the mouse and damages enemies under it; 1 tower and 1 staff attack on their own.
  - [ ] Enemies drop gold; the run ends when the keep falls or the last wave is cleared.
  - [ ] The CI web build and Windows build both play one full run with no errors in the log.
  - [ ] Placeholder art only (CC0), with sources listed in `games/holdfast/assets/CREDITS.md`.

### HF-M1-04 Run HUD and run flow screens
- **Owner:** UI Engineer
- **Status:** Ready
- **QA:** screens
- **Depends on:** HF-M1-03 (can start on stub data)
- **Done when:**
  - [ ] The HUD shows gold, keep health and wave number, updating live during a run.
  - [ ] Start screen → run → end-of-run summary (gold earned, waves cleared) → play again works with the mouse alone.
  - [ ] Text is readable at 1280×720 and 1920×1080, in the Windows build and the browser.
  - [ ] The UI reads game state only through signals or read-only accessors and never changes the rules' state.

### HF-M1-05 Test Steam achievement fires
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** full
- **Depends on:** KIT-04, HF-M1-03
- **Done when:**
  - [ ] Clearing the level in the Windows build unlocks one achievement on Valve's test app (480) through the kit Steam service.
  - [ ] Evidence on the item: the log line and a screenshot of the Steam overlay notification, from a Windows PC with Steam running.
  - [ ] The web build and CI runs are unaffected (no-op path, tests green).

### HF-M1-06 macOS export cost check
- **Owner:** Gameplay Engineer
- **Status:** Ready
- **QA:** sanity
- **Depends on:** KIT-05
- **Done when:**
  - [ ] CI attempts an unsigned macOS export once and records pass or fail.
  - [ ] A short note on this item states what shipping macOS would add (signing, notarisation, testing, cost) and a recommendation for Gate 1.

### HF-M1-07 Gate 1 full QA round
- **Owner:** Head of QA and Validation (per job)
- **Status:** Blocked (waits on HF-M1-01 to HF-M1-06)
- **QA:** full
- **Done when:**
  - [ ] One fixed build (commit recorded) is tested end to end against every M1 Done when line on this board.
  - [ ] Merges are frozen to blocker and major fixes during the round, and each fix is re-checked.
  - [ ] The round closes clean: no open blocker or major issue.

### HF-M1-08 Gate 1 brief for the CEO
- **Owner:** Head of Engineering
- **Status:** Blocked (waits on HF-M1-07)
- **QA:** sanity
- **Done when:**
  - [ ] One page: a link to play the web build, the Windows build, simulator timing and determinism results, achievement evidence, the macOS note and open risks.
  - [ ] A recommendation: stay on Godot or switch to Unity, with the reason.
  - [ ] Sent to the CEO through the Chief of Staff with one question and the recommendation marked.

## Decisions and open questions

- 2026-10-06: Shared simulation engine (timestep, seed, bot runner) in `kit/`; Holdfast's combat rules in `games/holdfast/`; the headless simulator and the playable build run the same rules, including a bot model of the aura. Game Design Advisor point, accepted (KIT-02, HF-M1-01).
- 2026-10-06: The repository is public, so `games/holdfast/plan.md` holds only the build-facing excerpt until the repository is made private (Setup Desk).
- Open (decide in M1): macOS at launch or Windows and Steam Deck only (HF-M1-06).
