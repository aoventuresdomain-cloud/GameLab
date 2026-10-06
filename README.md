# GameLab

GameLab is a game studio. This one repository holds every game and the shared **Studio Kit**.

- **Engine:** Godot 4 (latest stable 4.x), GDScript. Unity is the fallback if a game's M1 tech proof fails.
- **Current game:** Holdfast (game one), in `games/holdfast/`.

## Layout

```
studio/            board.md (work board, Head of Engineering), slate.md (games, Chief of Staff),
                   handoffs/ (thread handoffs), playbook/ (pipeline, pacing bands, checklists)
kit/               Studio Kit, a Godot 4 addon shared by every game
  sim/             deterministic simulation engine: fixed timestep, seeded RNG, bot runner (no rendering)
  packs/           pack loader and schema validation
  services/        save, steam, telemetry
  schema/          base JSON schemas; games extend them
  tests/           kit tests, run for every game
agents/            shared designer agents (design, balance loop, art, digest)
tools/botplay/     headless runner and bot policies
tools/release/     export and upload (CI only)
tools/studio/      repository checks (board format, kit boundary)
games/<name>/      one Godot project per game, with its own plan.md, content, tests and export presets
.github/workflows/ kit tests on every change; per-game jobs by path
```

## Getting started

1. Install the Godot version in `.godot-version` (the one place it is pinned; every CI job reads it).
2. Link the Studio Kit into every project: `python3 tools/link_kit.py`. Each `games/<name>/addons/gamelab_kit` (and `tools/kit-host/addons/gamelab_kit`) becomes a symlink to `kit/` on Linux and macOS, or a directory junction on Windows (no admin rights or developer mode needed). The links are not committed. Re-run after adding a game; `--check` verifies them, `--copy` copies instead where links are not possible.
3. Open `games/<name>/project.godot` in Godot. Edits under `addons/gamelab_kit/` are edits to `kit/`.

Tests, headless:

```
godot --headless --path tools/kit-host --import
godot --headless --path tools/kit-host -s res://addons/gamelab_kit/testing/run_tests.gd -- res://addons/gamelab_kit/tests
godot --headless --path games/holdfast --import
godot --headless --path games/holdfast -s res://addons/gamelab_kit/testing/run_tests.gd -- res://tests
```

## Rules that keep the studio and games apart

- Each game is its own Godot project under `games/` and uses the kit as an addon linked from `kit/`.
- Nothing game-specific goes in `kit/`. Game rules (combat, economy, content) live in the game; the kit holds only engines, formats and services. CI checks this.
- A change to `kit/` can affect every game: it needs Head of Engineering review, a full QA round and green tests for every active game.
- Content packs are data only, never code.
- Secrets live only in CI secrets. Nothing secret is committed or shipped.

## Checks

```
python3 tools/studio/check_repo.py
```

Runs in CI on every pull request. It checks the repository layout, that every board item has one owner and 2-5 Done when lines, that `kit/` names no game, and that no £ or € amounts are committed (the repository is public).
