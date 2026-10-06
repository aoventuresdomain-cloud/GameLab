# GameLab Studio Kit

A Godot 4 addon shared by every GameLab game. Each game links it in as `addons/gamelab_kit/`.

| Folder | Holds |
|---|---|
| `sim/` | Deterministic simulation engine: fixed timestep, seeded RNG, bot runner. No rendering dependency, so it runs headless. Games plug their own rules into it |
| `packs/` | Pack loader and schema validation |
| `schema/` | Versioned base JSON schemas; games extend them |
| `services/` | Save, Steam, telemetry |
| `tests/` | Kit tests, run in CI for every game |
| `testing/` | The headless test runner and `KitTestCase` every game's tests use |

## Simulation engine (`sim/`)

A game writes its rules as a `SimRules` (setup, step, is_finished, snapshot, result) and its inputs as `SimController`s (a bot, or the player's devices). `SimEngine` runs the rules on a fixed timestep with a seeded `SimRng`:

- Headless: `SimEngine.run_to_end()` or `SimBotRunner.run()`, as fast as the machine allows.
- Playable build: call `engine.advance(frame_delta)` each frame. It runs whole fixed ticks only, so the same seed and inputs reach the same states at any frame rate. Rendering reads the rules' state; it never steps them.
- `engine.state_hash()` hashes the full state for determinism checks.

## Content packs (`packs/`, `schema/`)

A pack is a folder with `pack.json` (manifest) and the JSON files it lists. `schema/pack.v0.schema.json` is the versioned base for levels, enemies, towers, staff and upgrade nodes; a game extends it with `"$extends"`. `PackLoader.load_pack(dir, schema)` validates every file, checks `x-ref` ids, and refuses anything that is not data (non-JSON files, res:// or user:// paths, scripts, scenes, resources). Errors name the file and the field, e.g. `enemies.json: $.enemies[0].health: expected number, got string`.

Nothing game-specific belongs here: no game names, no game rules, no game content. `tools/studio/check_repo.py` fails CI if `kit/` names a game.
