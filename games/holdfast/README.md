# Holdfast (game one)

Offline single-player incremental tower defence with recruitable staff. Steam first. Its own Godot 4 project, using the Studio Kit as an addon.

- Plan: `plan.md`
- Work items: the Holdfast section of `studio/board.md`
- Combat and economy rules live here (`scripts/`), not in `kit/`. The kit's simulation engine runs them headless and in the playable build alike.

## Run UI (HF-M1-04)

`scenes/main.tscn` runs start screen → run (HUD) → summary → play again. The UI binds only to `scripts/ui/run_state_source.gd`: signals (`run_started`, `gold_changed`, `keep_health_changed`, `wave_changed`, `run_ended`) and `get_*`/`is_running()` reads. It never writes rule state; only `scripts/run_flow.gd` calls `start_run()`.

The `RunSource` node is `scripts/holdfast_run_source.gd` (`HoldfastRunSource`), an adapter over the kit's simulation engine running Holdfast's rules. It extends `run_state_source.gd` and emits the same signals, so the UI doesn't know which source it has. A seeded run ends the same way in the playable build as headless (`tests/test_holdfast_rules.gd`, `test_headless_and_playable_build_match`). `scripts/stub_run_source.gd` (fake waves from a seeded generator) is kept only for the UI tests.

The window is laid out at 1280×720 and scaled (`canvas_items`), so 1920×1080 is the same layout at 1.5×. Tests:

    godot --headless --path games/holdfast --import
    godot --headless --path games/holdfast --script res://tests/run_ui_tests.gd
