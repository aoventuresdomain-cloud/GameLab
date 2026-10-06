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


func test_reset_flag_only_works_for_the_test_app() -> void:
	var hooks := preload("res://scripts/steam_hooks.gd")
	var flag := PackedStringArray(["--autoplay", hooks.RESET_FLAG])
	expect_true(hooks.resets_test_achievement(480, flag), "test app with the flag")
	expect_false(hooks.resets_test_achievement(480, PackedStringArray(["--autoplay"])), "never by default")
	expect_false(hooks.resets_test_achievement(3141590, flag), "ignored for any other app")
	expect_false(hooks.resets_test_achievement(0, flag), "ignored without an app")


func test_reset_flag_without_steam_is_a_safe_no_op() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var hooks: Node = main.get_node("SteamHooks")
	hooks.start_reset(PackedStringArray(["--autoplay", hooks.RESET_FLAG]))
	hooks._process(0.1)
	expect_false(hooks._reset_pending, "nothing pending without Steam")
	expect_eq(hooks.steam.log_lines.size(), 1, "only the unavailable line")
	main.free()
