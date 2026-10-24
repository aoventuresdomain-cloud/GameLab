extends KitTestCase
## HF-M2-45: always something to buy, and a first gear piece that is certain. The curve bot has
## something it can afford at every return to the tree on its way through levels 1 to 5 (a gap is
## reported by level and attempt); a small dot on the Skill tree tab says something new can be
## bought and clears when the tree is looked at; the first piece of gear comes with the first win
## of Level 1 on every seed, and a dot on the Hero tab stays until the Hero page has been opened.

const Main := preload("res://scenes/main.tscn")


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _content() -> Dictionary:
	return HoldfastContent.base()


# ------------------------------------------------------------------ the simulator check

func test_the_curve_bot_has_something_to_afford_at_every_return_to_the_tree() -> void:
	for run_seed in range(1, 13):
		var climb := HoldfastCurve.climb(run_seed, HoldfastSkilledBot.AVERAGE)
		expect_eq(climb["gaps"], [], "seed %d (average player): a return with nothing to afford" % run_seed)
	for run_seed in range(1, 7):
		var climb := HoldfastCurve.climb(run_seed, HoldfastSkilledBot.POOR)
		expect_eq(climb["gaps"], [], "seed %d (poor player): a return with nothing to afford" % run_seed)


func test_a_gap_is_reported_with_its_level_and_attempt() -> void:
	var skip: Array = _content()["upgrade_nodes"].keys().filter(func(id: String) -> bool: return not id in ["castle_slot_1", "castle_archer_1"])
	var climb := HoldfastCurve.climb(1, HoldfastSkilledBot.AVERAGE, "flare_archer", 5, skip)
	expect_true(climb["gaps"].size() >= 3, "a player with nothing to buy has gaps: %s" % str(climb["gaps"]))
	expect_eq(climb["gaps"][0], {"level": "shingle_beach", "attempt": 1}, "Level 1 is bought for by the guided stars; the first return with nothing is before Level 2")
	expect_true(climb["gaps"].size() >= climb["dry_runs"], "every dry return is in the list")


# ------------------------------------------------------------------ the Skill tree dot

func _at_the_map_with_gold(main: Node, gold: int) -> HoldfastProfile:
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run({"gold": gold, "outcome": "lost", "level": "outpost"})
	main.journey.refresh()
	return profile


func test_the_dot_shows_when_something_can_be_bought_and_the_name_stays_short() -> void:
	var main := _main()
	var map: Control = main.journey
	expect_false(map._tree_dot.visible, "a new game has nothing to buy")
	_at_the_map_with_gold(main, 100)
	expect_true(map._tree_dot.visible, "100 gold buys something")
	expect_eq(map.get_node("%TreeButton").text, "Skill tree", "the count is gone: the dot says it")
	expect_true(map._tree_dot.get_parent() == map.get_node("%TreeButton"))
	main.free()


func test_looking_at_the_tree_clears_the_dot_and_it_stays_clear_on_the_way_back() -> void:
	var main := _main()
	var map: Control = main.journey
	_at_the_map_with_gold(main, 100)
	main.call("_show", main.Screen.TREE)
	expect_false(map._tree_dot.visible, "opened")
	main.call("_show", main.Screen.MAP)
	expect_false(map._tree_dot.visible, "and still clear when back, though the same things can still be bought")
	main.free()


func test_what_became_affordable_while_the_tree_was_open_asks_for_no_dot() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile := _at_the_map_with_gold(main, 100)
	main.call("_show", main.Screen.TREE)
	var first: String = profile.get_buyable_nodes()[0]
	TreeCard.buy(main.keep_screen, first)
	expect_false(first in profile.get_buyable_nodes(), "bought")
	# Something that became affordable while the tree was open was seen there too.
	profile.bank_run({"gold": 5000, "outcome": "lost", "level": "outpost"})
	main.call("_show", main.Screen.MAP)
	expect_false(map._tree_dot.visible, "what the player saw in the tree asks for no dot")
	main.free()


func test_the_dot_comes_back_when_something_new_becomes_affordable() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile := _at_the_map_with_gold(main, 100)
	main.call("_show", main.Screen.TREE)
	main.call("_show", main.Screen.MAP)
	expect_false(map._tree_dot.visible)
	profile.bank_run({"gold": 5000, "outcome": "lost", "level": "outpost"})
	expect_true(map._tree_dot.visible, "a run's gold made new nodes affordable")
	main.free()


func test_no_dot_while_the_guide_has_the_tree_shut() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile: HoldfastProfile = main.get_node("Profile")
	var content := _content()
	profile.data = HoldfastMeta.bank_run(content, HoldfastMeta.new_profile(content), {"outcome": "won", "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	profile.changed.emit()
	expect_false(profile.get_buyable_nodes().is_empty(), "the guided slot is on offer")
	expect_false(map._tree_dot.visible, "but the guide, not a dot, asks for it")
	expect_false(map._hero_dot.visible)
	main.free()


func test_the_dot_is_a_drawn_shape_on_the_corner_not_over_the_name() -> void:
	var main := _main()
	var map: Control = main.journey
	_at_the_map_with_gold(main, 100)
	main.call("_show", main.Screen.MAP)
	await tree.process_frame
	await tree.process_frame
	var button: Button = map.get_node("%TreeButton")
	var dot: Control = map._tree_dot
	expect_true(dot.size.x >= 12.0 and dot.size.x == dot.size.y, "a visible round dot")
	expect_true(dot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "it never takes a press")
	var corner := button.get_global_rect().end - Vector2(0, button.size.y)
	expect_true(dot.get_global_rect().has_point(corner), "it sits on the top right corner")
	expect_true(tree.root.get_visible_rect().encloses(dot.get_global_rect()), "and stays on screen")
	main.free()


# ------------------------------------------------------------------ the first gear piece

func _won_outpost(run_seed: int) -> HoldfastRules:
	var content: Dictionary = _content().duplicate(true)
	content["levels"]["outpost"]["waves"] = [{"spawns": [{"enemy": "grunt", "count": 2, "interval": 0.5}]}]
	content["levels"]["outpost"]["first_wave_delay"] = 0.5
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, "flare_archer"), SimRng.new(run_seed))
	var guard := 0
	while not rules.is_finished() and guard < 4000:
		rules.step(1.0 / 30.0, {})
		guard += 1
	return rules


func test_the_first_win_of_level_one_gives_the_first_piece_on_every_seed() -> void:
	var first := str(_content()["levels"]["outpost"]["first_clear_gear"])
	expect_true(first != "", "the pack names it")
	for run_seed in range(1, 41):
		var rules := _won_outpost(run_seed)
		expect_eq(rules.outcome, HoldfastRules.OUTCOME_WON, "seed %d won" % run_seed)
		expect_eq(rules.result()["gear_found"], [first], "seed %d: the piece comes with the win, not by chance" % run_seed)


func test_the_piece_is_banked_and_worn_and_not_given_twice() -> void:
	var content := _content()
	var first := str(content["levels"]["outpost"]["first_clear_gear"])
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "outpost", "gold": 0, "gear_found": [first]})
	expect_true(first in profile["gear"]["owned"])
	expect_true(first in profile["gear"]["equipped"].values(), "worn at once, so the Hero page has something in a slot")
	var again := HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "outpost", "gold": 0, "gear_found": [first]})
	expect_eq(again["gear"]["owned"], profile["gear"]["owned"], "no second copy")


# ------------------------------------------------------------------ the Hero dot

func test_a_new_piece_puts_a_dot_on_the_hero_tab_until_the_page_is_opened() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	expect_false(map._hero_dot.visible, "nothing found yet")
	profile.bank_run({"outcome": "won", "level": "outpost", "gold": 0, "gear_found": ["wave_worn_boots"]})
	expect_true(map._hero_dot.visible, "a piece nobody has looked at")
	expect_true(map._hero_dot.get_parent() == map._hero_button)
	main.call("_show", main.Screen.HERO)
	expect_false(map._hero_dot.visible, "the page was opened")
	main.call("_show", main.Screen.MAP)
	expect_false(map._hero_dot.visible)
	profile.bank_run({"outcome": "won", "level": "shingle_beach", "gold": 0, "gear_found": ["gull_feather_fletching"]})
	expect_true(map._hero_dot.visible, "the next piece asks again")
	main.free()


func test_a_save_from_before_the_dot_has_seen_the_gear_it_owns() -> void:
	var content := _content()
	var old := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	old = HoldfastMeta.bank_run(content, old, {"outcome": "won", "level": "outpost", "gold": 0, "gear_found": ["wave_worn_boots"]})
	old.erase("gear_seen")
	var loaded := HoldfastMeta.from_save(content, old)
	expect_false(HoldfastMeta.has_unseen_gear(loaded), "no dot on every start for a player with gear")
	expect_eq(loaded["gear_seen"], ["wave_worn_boots"])
	expect_eq(HoldfastMeta.from_save(content, {})["gear_seen"], [], "a new game has seen nothing")
	var saved := old.duplicate(true)
	saved["gear_seen"] = ["wave_worn_boots", "not_a_piece", 4]
	expect_eq(HoldfastMeta.from_save(content, saved)["gear_seen"], ["wave_worn_boots"], "ids it does not own are dropped")
	saved["gear_seen"] = []
	expect_true(HoldfastMeta.has_unseen_gear(HoldfastMeta.from_save(content, saved)), "a save that says nothing was seen still has the dot")
