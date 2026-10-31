extends KitTestCase
## HF-M2-63: the first time a player meets the Hero's special, the run stops until they press it.
## Once only, never on Level 0, and a save that has won past Level 0 never sees it.

const Main := preload("res://scenes/main.tscn")


func _content() -> Dictionary:
	return HoldfastContent.base()


func _through_json(profile: Dictionary) -> Dictionary:
	return HoldfastMeta.from_save(_content(), JSON.parse_string(JSON.stringify(profile)))


# ------------------------------------------------------------------ the profile

func test_a_new_profile_is_due_on_every_level_but_the_tutorial() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_false(HoldfastMeta.special_due(content, profile, HoldfastMeta.tutorial_level(content)), "never on Level 0")
	expect_true(HoldfastMeta.special_due(content, profile, "outpost"))
	expect_false(HoldfastMeta.special_due(content, profile, "no_such_level"))


func test_a_taught_profile_is_never_due_and_the_flag_survives_a_real_save() -> void:
	var content := _content()
	var taught := HoldfastMeta.teach_special(HoldfastMeta.new_profile(content))
	expect_false(HoldfastMeta.special_due(content, taught, "outpost"))
	expect_true(_through_json(taught)["special_taught"], "saved and loaded, still taught")
	expect_false(_through_json(HoldfastMeta.new_profile(content))["special_taught"], "and a saved new game still has it to come")


func test_a_save_from_before_the_prompt_has_met_it_only_if_it_won_past_level_zero() -> void:
	var content := _content()
	var first := HoldfastMeta.tutorial_level(content)
	var old := HoldfastMeta.new_profile(content)
	old.erase("special_taught")
	old["levels_won"] = [first]
	expect_false(_through_json(old)["special_taught"], "only Level 0 won: the prompt is still to come")
	old["levels_won"] = [first, "outpost"]
	expect_true(_through_json(old)["special_taught"], "a level beyond it won: long past the prompt")


# ------------------------------------------------------------------ the run

func _source(taught: bool) -> HoldfastRunSource:
	var source := HoldfastRunSource.new()
	source.auto_step = false
	source.rng_seed = 3
	source.level_id = "outpost"
	source.teach_special = taught
	tree.root.add_child(source)
	source.start_run()
	return source


func test_the_run_stops_when_an_enemy_comes_within_the_specials_reach_and_waits_for_the_press() -> void:
	var source := _source(true)
	source.step(120.0)
	expect_true(source.is_teaching_special(), "stopped at the prompt")
	expect_true(source.is_held())
	expect_true(source.get_special_note().contains("Space"), "it names the key")
	var rules := source.get_rules()
	expect_true(rules.hero_ability_ready_in <= 0.0, "with the special ready")
	expect_true(rules.enemies.any(func(e: HoldfastRules.Enemy) -> bool: return e.position.distance_to(rules.hero_position) <= float(rules.hero_ability["range"]) + e.radius), "and an enemy in its reach")
	source.free()


func test_the_press_fires_the_special_and_the_prompt_never_comes_back() -> void:
	var source := _source(true)
	source.step(120.0)
	source.press_special()
	expect_false(source.is_teaching_special())
	expect_false(source.is_held())
	expect_eq(source.get_special_note(), "")
	source.step(0.2)
	var rules := source.get_rules()
	expect_true(rules.hero_ability_ready_in > 0.0, "the Hero fired it")
	expect_true(rules.hero_rapid_left > 0.0, "and the barrage is burning")
	for i in 20:
		source.step(5.0)
		expect_false(source.is_teaching_special(), "not again, at second %d" % ((i + 1) * 5))
	source.free()


func test_a_press_when_no_prompt_is_up_does_nothing() -> void:
	var source := _source(true)
	source.press_special()
	source.step(0.1)
	expect_true(source.get_rules().hero_ability_ready_in <= 0.0, "no cast")
	source.free()


func test_a_run_not_set_to_teach_never_stops() -> void:
	var source := _source(false)
	source.step(120.0)
	expect_false(source.is_teaching_special())
	source.free()


# ------------------------------------------------------------------ the flow

func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func test_level_zero_never_teaches() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = true
	main.call("_new_game")
	main.call("_level_picked", HoldfastMeta.tutorial_level(_content()))
	expect_true(source.is_running())
	expect_false(source.teach_special, "never on Level 0")
	var seconds := 0.0
	while source.is_running() and seconds < 600.0:
		source.step(1.0)
		seconds += 1.0
	expect_false(source.is_teaching_special(), "Level 0 ran through with no prompt")
	expect_true(profile.is_special_due("outpost"), "and the prompt is still to come")
	main.free()


func test_the_first_run_after_level_zero_teaches_once() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = true
	ThroughLevelZero.apply(profile)
	main.journey._buttons["outpost"].pressed.emit()
	main.planning._site_buttons["spot_1"].pressed.emit()
	main.planning.get_node("%StartButton").pressed.emit()
	expect_true(source.is_running())
	expect_true(source.teach_special, "the first level after it")
	source.step(120.0)
	expect_true(source.is_teaching_special())
	main.hud.special_requested.emit()
	expect_false(source.is_teaching_special())
	expect_true(profile.data["special_taught"], "the profile knows")
	expect_true(_through_json(profile.data)["special_taught"], "through a real save")
	expect_false(profile.is_special_due("outpost"))
	main.free()
