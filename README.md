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

Runs in CI on every pull request. It checks the repository layout, that every board item has one owner and 2-5 Done when lines, and that `kit/` names no game.
