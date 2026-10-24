extends KitTestCase
## Navigation rework, part 1 (HF-M2-29): the main menu, the journey map with its level
## nodes and the Hero figure, the Hero page, and the links on the result screen.

const Main := preload("res://scenes/main.tscn")
const LEVELS := ["first_watch", "outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


func _win(profile: HoldfastProfile, levels: Array) -> void:
	for id in levels:
		profile.bank_run({"gold": 0, "outcome": "won", "level": id})


func test_continue_says_where_the_player_is_and_is_plain_with_no_save() -> void:
	var main := _main()
	var button: Button = main.home.get_node("%ContinueButton")
	expect_eq(button.text, "Continue", "nothing to continue yet")
	var profile: HoldfastProfile = main.get_node("Profile")
	_win(profile, ["outpost"])
	profile.select_pillar("tideblade")
	profile.select_level("shingle_beach")
	profile.bank_run({"gold": 1240, "outcome": "lost", "level": "shingle_beach"})
	expect_eq(button.text, "Continue\nLevel 2 · Tideblade · 1,240 gold")
	main.free()


func test_the_map_has_one_node_per_level_in_the_packs_order() -> void:
	var main := _main()
	expect_eq(main.journey._ids, LEVELS)
	for id in LEVELS:
		expect_true(main.journey._buttons.has(id), id)
	main.free()


func test_a_new_game_has_the_first_level_next_and_the_rest_locked() -> void:
	var main := _main()
	var map: Control = main.journey
	map.refresh()
	expect_eq(map._next, "first_watch")
	expect_false(map._buttons["first_watch"].disabled)
	for id in LEVELS.slice(1):
		expect_true(map._buttons[id].disabled, "%s is locked" % id)
		var level_name: String = HoldfastContent.base()["levels"][id]["name"]
		expect_eq(map._names[id].text, level_name + "\nBoss: Fog Warden" if id == "gull_rock" else level_name, id)
	expect_eq(map._buttons["first_watch"].text, "0", "an open level shows its number")
	main.free()


func test_a_cleared_level_loses_its_number_and_the_next_one_opens() -> void:
	var main := _main()
	var map: Control = main.journey
	ThroughLevelZero.apply(main.get_node("Profile"))
	_win(main.get_node("Profile"), ["outpost", "shingle_beach"])
	expect_eq(map._next, "tidewrack_cove")
	expect_eq(map._buttons["outpost"].text, "", "a tick is drawn instead")
	expect_true(map._names["outpost"].text.ends_with("\n1 of 3 stars"))
	expect_false(map._names["outpost"].text.contains("Won"), "cleared is shown by the tick, not a word")
	expect_false(map._buttons["outpost"].disabled, "a cleared level can be replayed")
	expect_false(map._buttons["tidewrack_cove"].disabled)
	expect_true(map._buttons["old_pier"].disabled)
	main.free()


func test_only_the_level_with_a_boss_is_marked() -> void:
	var main := _main()
	for id in LEVELS:
		expect_eq(main.journey.boss_name(id), "Fog Warden" if id == "gull_rock" else "", id)
	ThroughLevelZero.apply(main.get_node("Profile"))
	_win(main.get_node("Profile"), LEVELS.slice(0, 5))
	expect_true(main.journey._names["gull_rock"].text.ends_with("Boss: Fog Warden"))
	main.free()


func test_tapping_an_open_level_plans_it_and_a_locked_one_does_nothing() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	_win(profile, ["outpost"])
	main.journey._buttons["old_pier"].pressed.emit()
	expect_eq(profile.get_level(), "first_watch", "locked: no change")
	main.journey.level_requested.emit("shingle_beach")
	expect_eq(profile.get_level(), "shingle_beach")
	expect_true(main.planning.visible and not main.journey.visible, "the Plan page opens")
	main.free()


func test_the_skill_tree_button_has_a_dot_when_upgrades_can_be_bought() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_eq(map.upgrades_available(), 0)
	expect_eq(map.get_node("%TreeButton").text, "Skill tree")
	expect_false(map._tree_dot.visible, "nothing to buy, no dot")
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run({"gold": 100, "outcome": "lost", "level": "outpost"})
	var affordable := 0
	for id in HoldfastContent.base()["upgrade_nodes"]:
		if profile.why_not_buy(id) == "":
			affordable += 1
	expect_true(affordable > 0, "100 gold buys something")
	expect_eq(map.upgrades_available(), affordable)
	expect_eq(map.get_node("%TreeButton").text, "Skill tree")
	expect_true(map._tree_dot.visible, "the dot says there is something to buy")
	main.free()


func test_the_hero_figure_names_the_path_and_opens_the_hero_page() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_eq(main.journey._hero_button.text, "Hero: Flare Archer")
	profile.select_pillar("dusk_mage")
	expect_eq(main.journey._hero_button.text, "Hero: Dusk Mage")
	main.journey._hero_button.pressed.emit()
	expect_true(main.hero_page.visible and not main.journey.visible)
	main.hero_page.get_node("%BackButton").pressed.emit()
	expect_true(main.journey.visible and not main.hero_page.visible)
	main.free()


func test_the_hero_page_shows_the_slots_and_links_to_the_heros_tree_section() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var page: Control = main.hero_page
	var weapon: Label = page.get_node("%SlotColumn").get_child(0).get_node("Row/Item")
	expect_eq(weapon.text, "")
	profile.bank_run({"outcome": "won", "level": "shingle_beach", "gold": 0, "gear_found": ["tarred_bowstring"]})
	expect_eq(weapon.text, "Tarred bowstring")
	expect_eq(page.get_node("%TreeButton").text, "Skill tree")
	page.visible = true
	page.get_node("%TreeButton").pressed.emit()
	expect_true(main.keep_screen.visible and not page.visible)
	main.free()


func test_the_map_and_the_summary_both_open_the_skill_tree_and_it_returns_to_the_map() -> void:
	var main := _main()
	main.journey.get_node("%TreeButton").pressed.emit()
	expect_true(main.keep_screen.visible and not main.journey.visible)
	main.keep_screen.get_node("%BackButton").pressed.emit()
	expect_true(main.journey.visible and not main.keep_screen.visible)
	main.summary.get_node("%TreeButton").pressed.emit()
	expect_true(main.keep_screen.visible and not main.summary.visible)
	main.free()


func test_retry_after_a_loss_goes_through_the_plan_page_with_the_last_layout_kept() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.select_level("outpost")
	profile.set_layout("outpost", ["spot_1"])
	main.call("_on_run_ended", {"gold_earned": 5, "waves_cleared": 1, "total_waves": 5, "keep_fell": true,
			"result": {"outcome": HoldfastRules.OUTCOME_LOST, "level": "outpost", "gold": 5}})
	var retry: Button = main.summary.get_node("%PlayAgainButton")
	expect_eq(retry.text, "Retry")
	retry.pressed.emit()
	expect_true(main.planning.visible and not main.summary.visible)
	expect_eq(main.planning._chosen, ["spot_1"], "the last layout is kept")
	main.free()


func test_a_win_offers_play_again_and_the_old_nodes_are_gone() -> void:
	var main := _main()
	main.call("_on_run_ended", {"gold_earned": 5, "waves_cleared": 5, "total_waves": 5, "keep_fell": false,
			"result": {"outcome": HoldfastRules.OUTCOME_WON, "level": "outpost", "gold": 5}})
	expect_eq(main.summary.get_node("%PlayAgainButton").text, "Play again")
	for node in ["%LevelRow", "%PillarRow", "%GearRow", "%PlayButton"]:
		expect_true(main.keep_screen.get_node_or_null(node) == null, "%s moved off the tree page" % node)
	main.free()
