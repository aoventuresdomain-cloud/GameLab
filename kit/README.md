# GameLab Studio Kit

A Godot 4 addon shared by every GameLab game. Each game links it in as `addons/gamelab_kit/`.

| Folder | Holds |
|---|---|
| `sim/` | Deterministic simulation engine: fixed timestep, seeded RNG, bot runner. No rendering dependency, so it runs headless. Games plug their own rules into it |
| `packs/` | Pack loader and schema validation |
| `schema/` | Versioned base JSON schemas; games extend them |
| `services/` | Save, Steam, telemetry |
| `tests/` | Kit tests, run in CI for every game |

Nothing game-specific belongs here: no game names, no game rules, no game content. `tools/studio/check_repo.py` fails CI if `kit/` names a game.
