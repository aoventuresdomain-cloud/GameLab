extends KitTestCase
## Build 4b (HF-M2-27): the post-win screen offers Next level and the Upgrade
## screen. The Flare Barrage burst is tested in test_hero.gd.

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://build4b_tests"


func _main(path: String = "") -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	if path != "":
		main.get_node("Profile").save_path = path
	tree.root.add_child(main)
	return main


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


## The run_ended payload for a run of `level` that ended with `outcome` and earned `gold`.
func _ended(level: String, outcome: String, gold: int) -> Dictionary:
	return {"gold_earned": gold, "waves_cleared": 6, "total_waves": 6, "keep_fell": outcome == HoldfastRules.OUTCOME_LOST,
			"result": {"outcome": outcome, "level": level, "gold": gold}}


func test_a_win_offers_the_next_level_and_the_upgrade_screen() -> void:
	var main := _main()
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON, 50))
	expect_true(main.summary.visible)
	expect_true(main.summary.get_node("%NextLevelButton").visible, "Shingle Beach opened by the win")
	expect_eq(main.summary.get_node("%KeepButton").text, "Upgrade screen")
	main.summary.get_node("%KeepButton").pressed.emit()
	expect_true(main.keep_screen.visible and not main.summary.visible, "the upgrade screen is the keep")
	main.free()


func test_next_level_starts_a_run_on_the_next_level() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON, 50))
	main.summary.get_node("%NextLevelButton").pressed.emit()
	expect_eq(profile.get_level(), "shingle_beach")
	expect_true(source.is_running())
	expect_true(main.hud.visible and not main.summary.visible, "the run is on screen")
	expect_eq(source.get_rules().level_id, "shingle_beach")
	main.free()


func test_a_loss_keeps_its_screen_with_no_next_level() -> void:
	var main := _main()
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_LOST, 5))
	expect_false(main.summary.get_node("%NextLevelButton").visible, "no next level after a loss")
	expect_eq(main.summary.get_node("%KeepButton").text, "Back to the keep")
	expect_true(main.summary.get_node("%PlayAgainButton").visible)
	expect_eq(main.summary.get_node("%Title").text, "The keep has fallen")
	main.free()


func test_the_last_level_has_no_next_level() -> void:
	var main := _main()
	var levels: Array = HoldfastContent.base()["levels"].keys()
	main.call("_on_run_ended", _ended(levels[levels.size() - 1], HoldfastRules.OUTCOME_WON, 50))
	expect_false(main.summary.get_node("%NextLevelButton").visible, "nothing after the last level")
	expect_eq(main.summary.get_node("%KeepButton").text, "Upgrade screen")
	main.free()


func test_a_win_that_does_not_open_the_next_level_does_not_offer_it() -> void:
	# A summary shown for a level whose successor is still locked offers nothing.
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_eq(profile.get_next_level("shingle_beach"), "", "level 3 is locked until level 2 is won")
	expect_eq(profile.get_next_level("outpost"), "", "and level 2 until level 1 is won")
	profile.bank_run({"gold": 0, "outcome": HoldfastRules.OUTCOME_WON, "level": "outpost"})
	expect_eq(profile.get_next_level("outpost"), "shingle_beach")
	expect_eq(profile.get_next_level("nowhere"), "", "an unknown level has none")
	main.free()


func test_gold_and_unlocks_are_saved_before_the_screen_shows() -> void:
	var path := _save_path("before_summary")
	var main := _main(path)
	var seen := {}
	main.summary.visibility_changed.connect(func() -> void:
		if main.summary.visible and not seen.has("gold"):
			var check := HoldfastProfile.new()
			check.save_path = path
			check.load_profile()
			seen["gold"] = check.get_gold()
			seen["unlocked"] = check.get_unlocked_levels()
			check.free())
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON, 77))
	expect_eq(seen.get("gold"), 77, "the gold was on disk when the screen appeared")
	expect_true("shingle_beach" in seen.get("unlocked", []), "and the level it opened")
	main.free()
