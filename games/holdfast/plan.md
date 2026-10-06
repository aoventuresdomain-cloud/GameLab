# Holdfast: plan (build excerpt)

*This repository is public, so this file carries only the build-facing parts of the Holdfast plan (v2, 6 Oct 2026): the game, the kit, the architecture, milestones and the Unity fallback. The full plan, including money, budget, gates' numbers and stop rules, stays in the GameLab project files (`holdfast-project-plan.md`) until the repository is made private. Then the full plan replaces this excerpt. Section numbers match the full plan.*

*Studio matters (repository, kit, team, rules) are in the GameLab project's `gamelab-studio.md`, which wins on those.*

## 3. The game

**Run (3-8 minutes):**
1. Pick a level, up to 3 staff for your keep, and 1 of 3 offered blessings (temporary boosts for this run).
2. Enemies come in waves. Hover the mouse (or a controller cursor) over them to deal aura damage. Towers and staff attack on their own.
3. Enemies drop gold and occasional staff XP tokens. Staff level up mid-run and pick from 2 skill options.
4. The run ends when the keep falls or the boss dies. You keep all the gold.

**Between runs:**
- **Upgrade tree** (the Incrempire hook): 60-80 nodes bought with gold. Aura damage and size, tower slots, gold gain, new enemy types and biomes. It visibly opens up.
- **Staff** (the twist): recruit 8 characters in 4 classes (e.g. Warden, Alchemist, Ranger, Engineer). Each has levels, a personal skill tree of about 10 nodes, and 2 gear slots earned from bosses. Keep slots are limited, so choosing your staff is the strategy.
- **Blessings:** about 20, unlocked through play, so runs feel different.
- **Offline earnings:** your keep earns gold while the game is closed, **capped at 8 hours**, so playing always beats waiting.
- **Endless mode** after the main game: scaling waves for upgrade-tree and staff completionists.

**Pacing targets** (checked by the simulator): first upgrade within 60 seconds, a new unlock at least every 3-5 minutes in the first hour, no grind wall longer than 10 minutes of repeated runs, main game finished in 4-6 hours, and every staff build able to clear the main game.

**Controls and feel:** mouse first, full controller support (Steam Deck), and big readable numbers. Satisfying hit feedback, screen shake and flash toggles. Saves are resumable at any moment.

**Art direction (default, confirm in M2):** clean top-down 2D with bold outlines and a limited palette. Start from CC0 or licensed packs (e.g. Kenney) and use AI-generated variants against a locked style guide. The owner approves every new asset family. Steam requires the store page to disclose AI-generated content (section 11).

## 4. The GameLab Studio Kit (what Holdfast builds first)

| Kit part | What it does |
|---|---|
| **Progression simulator** (centre of the kit) | Deterministic game rules on a fixed timestep with a seeded random generator, with no rendering dependency, so it runs headless. Bot policies play the full progression (hours of play in seconds) and report time to each unlock, grind walls, dead ends, runaway numbers and how viable each staff build is |
| **Content pack format** | Versioned JSON schema for levels, biomes, enemies, bosses, staff, skill trees, gear, blessings and upgrade-tree nodes. Packs are data only, never code |
| **Design agent** | Turns a brief ("new frost biome, 5 levels, 1 new Alchemist variant, mid-game") into a draft pack that passes the schema |
| **Balance loop** | If the simulator's report is outside the pacing bands, the design agent adjusts and re-runs automatically, up to N rounds, then asks the owner |
| **Art agent** | Generates sprite and icon variants from the locked style guide and flags anything new for owner approval |
| **Approval** | Each pack arrives as a pull request with a one-screen summary: previews, pacing numbers and a diff. The owner approves by merging on their phone (GitHub mobile) |
| **Delivery (Steam phase)** | Approved packs are bundled into the next Steam build (free update) or a DLC. No download server is needed on Steam |
| **Delivery (mobile phase, later)** | Signed (Ed25519) packs on static hosting with a manifest and offline cache, for live events. Built only if Gate 5 passes |
| **Services layer** | Save (local plus Steam Cloud), Steam (achievements, stats, cloud saves), and opt-in anonymous telemetry. Ads, Store and Consent adapters are added in the mobile phase |

**Build only what Holdfast needs.** The kit lives in `kit/` of the GameLab repository and nothing Holdfast-specific goes there; it is generalised only when game two starts (`gamelab-studio.md` section 4).

## 7. Architecture (also drawn as a diagram)

**The game (Godot 4, GDScript):**
- **Game layer** (Holdfast-specific): scenes, aura and cursor control, towers, staff behaviour, UI, juice (effects, sound).
- **Progression simulator** (kit): deterministic rules engine that reads packs. No rendering dependency, so it runs headless in CI.
- **Pack loader** (kit): reads bundled packs and validates them against the schema.
- **Services layer** (kit): `Save` (local file plus Steam Cloud), `Steam` (achievements, stats and cloud saves through the GodotSteam extension; Valve's public test app ID until the store page exists), `Telemetry` (opt-in, anonymous, off by default in the EU until consent).

**In the cloud (build project):**
- **Repository** (GitHub): game, kit, packs, agents, tools.
- **CI** (GitHub Actions on Linux): tests, schema checks, the headless progression simulator, Windows, macOS and web exports, and upload to a Steam beta branch with steamcmd. Setting a build live is a manual step that needs the owner's go-ahead.
- **Demo hosting:** Steam (demo app), itch.io and galaxy.click (web export).
- **Agents** (Claude, run as scheduled routines or scripts): design agent, balance loop, art agent with an image-generation API, and the digest writer.

**Mobile phase (later, only after Gate 5):** iOS and Android exports from the same project, with `Ads`, `Store` and `Consent` adapters, signed pack delivery for live events, and cloud macOS builds. That plan is in `holdfast-project-plan-v1-iphone.md` sections 6, 7 and 11.

**Security:** Steam build credentials and any API keys live only in CI secrets; nothing secret ships in the game; packs are data only. Cheating in a single-player game is accepted.

## 9. Milestones and done criteria

| # | Milestone | Done when | Owner's part |
|---|---|---|---|
| M1 | **Tech proof** | A Godot 4 build runs on Windows and in a browser (web export), produced by CI. One level is playable with the aura, 1 tower and 1 staff, using the kit as an addon linked from `GameLab/kit`. The headless simulator plays 10 hours of progression in under a minute in CI, with a determinism test. A Steam achievement fires using Valve's test app ID. **Go/no-go for Godot** | Play the web build in a browser |
| M2 | **Fun slice** | 1 biome, 5 levels, 3 staff with skill trees, about 30 upgrade nodes and 6 blessings, all hand-made. 5-10 outside testers: median first session of 30+ minutes, most want to keep playing, and **at least half name the staff as a reason to keep playing**. Pacing bands set and passing. Art style locked. **Go/no-go for the concept** | Recruit testers (or approve the Player Researcher's route), play, judge feel, approve style |
| M3 | **Designer pipeline** | Pack schema frozen. The design agent produces a level pack and a staff pack from one-line briefs; the simulator checks them in CI; the owner approves a pull request on their phone; the pack appears in the next build | Approve the first packs on the phone |
| M4 | **Steam page and demo** | Steam store page live with capsule art, trailer, AI-content disclosure and wishlist button. Free demo (first biome, about 45-60 minutes) passes Valve review and is live on Steam, itch.io and galaxy.click. Wishlists and demo playtime appear in the weekly digest | Setup Desk Steam checklist; approve the page and demo; go-ahead to publish |
| M5 | **Full game** | 4 biomes, about 20 levels, 8 staff, the full upgrade tree, about 20 blessings, endless mode, achievements, controller support, Steam Deck check and settings. Most content made through the designer pipeline, every pack passing the simulator | Play through, approve packs |
| M6 | **Launch prep** | Demo in a Steam Next Fest. Target 5,000+ wishlists. Release-ready full QA round clean. Store page final, price and launch discount set | Approve price, release date and Next Fest entry |
| M7 | **Steam launch** | Live on Steam at the approved price. Weekly digest running. First free update scheduled | Go-ahead to release |
| L1 | **After launch** | One free content update within about 2 months. One paid DLC (new biome plus 2 staff) if sales are at or above the base case | Approve update and DLC price |
| P | **Mobile phase** (only after Gate 5) | Short Advisor check, then the v1 mobile plan: iPhone (and Android) free-to-play build, retention test with 500+ players, then App Store launch | Approve the start, the test and the launch |

Hard rule: **M3 does not start until Gate 2 passes.** The demo (M4) can start alongside M3.

## 13. Switching to Unity if needed

- **Before M3:** switch cheaply. Only the M1 proof and the M2 slice are rewritten.
- **What always carries over:** pack schema and all packs, agents, pacing bands, art, audio, CI design and the price and DLC plan.
- **What is rewritten:** the game layer, the simulator (in C#) and the services adapters.
