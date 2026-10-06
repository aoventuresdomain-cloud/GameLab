extends KitTestCase
## HF-M1-05: clearing the level asks the kit Steam service for the test
## achievement; without Steam (here, headless) that is a safe no-op.

const Main := preload("res://scenes/main.tscn")


func test_steam_hooks_use_the_test_app_and_survive_without_steam() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var hooks: Node = main.get_node("SteamHooks")
	expect_eq(hooks.APP_ID, 480, "Valve's test app until Holdfast has its own")
	expect_false(hooks.steam.is_available(), "no Steam in a headless run")
	main.call("_start_run")
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.step(3600.0)
	expect_false(source.is_running(), "the run ended without Steam getting in the way")
	expect_eq(hooks.steam.log_lines.size(), 1, "logged once")
	main.free()


func test_only_a_won_run_unlocks_the_level_achievement() -> void:
	var hooks := preload("res://scripts/steam_hooks.gd")
	expect_true(hooks.clears_level({"result": {"outcome": HoldfastRules.OUTCOME_WON}}), "won")
	expect_false(hooks.clears_level({"keep_fell": true, "result": {"outcome": HoldfastRules.OUTCOME_LOST}}), "lost")
	expect_false(hooks.clears_level({"keep_fell": false, "result": {"outcome": HoldfastRules.OUTCOME_INVALID}}), "invalid run, keep never fell")
	expect_false(hooks.clears_level({"keep_fell": false}), "no result")
