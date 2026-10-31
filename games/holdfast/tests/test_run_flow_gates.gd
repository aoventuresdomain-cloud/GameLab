extends KitTestCase
## HF-M2-64: pause and leave a run, the locked Hero paths, the end of content and game speed.
## Every saved state in here goes through a real file.

const Main := preload("res://scenes/main.tscn")
const Guidance := preload("res://scripts/ui/guidance.gd")
const SAVE_DIR := "user://test_run_flow_gates"


func _content() -> Dictionary:
	return HoldfastContent.base()


func _through_json(profile: Dictionary) -> Dictionary:
	return HoldfastMeta.from_save(_content(), JSON.parse_string(JSON.stringify(profile)))


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


## Main with a stepped-by-hand source, a profile past Level 0, and the first run on Outpost started.
func _run_started(save_path := "") -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	if save_path != "":
		main.get_node("Profile").save_path = save_path
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	main.journey._buttons["outpost"].pressed.emit()
	main.planning._site_buttons["spot_1"].pressed.emit()
	main.planning.get_node("%StartButton").pressed.emit()
	return main


# ------------------------------------------------------------------ the Hero paths

func test_a_new_game_has_only_the_first_path_open_and_each_closed_one_says_what_opens_it() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_true(HoldfastMeta.path_open(content, profile, "flare_archer"))
	expect_false(HoldfastMeta.path_open(content, profile, "dusk_mage"))
	expect_eq(HoldfastMeta.path_lock_reason(content, profile, "flare_archer"), "")
	expect_eq(HoldfastMeta.path_lock_reason(content, profile, "dusk_mage"), "Opens when you win Gull Rock.")
	expect_true(HoldfastMeta.path_lock_reason(content, profile, "tideblade").contains("not built yet"), "the Tideblade says its biome does not exist yet")


func test_picking_a_closed_path_changes_nothing() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	for id in ["dusk_mage", "tideblade"]:
		expect_eq(HoldfastMeta.select_pillar(content, profile, id), profile, id)


func test_winning_gull_rock_opens_the_dusk_mage_and_never_the_tideblade() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_eq(HoldfastMeta.paths_opened_by(content, "gull_rock"), ["dusk_mage"])
	expect_eq(HoldfastMeta.paths_opened_by(content, "outpost"), [])
	var won := HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "gull_rock", "gold": 0})
	expect_true(HoldfastMeta.path_open(content, won, "dusk_mage"))
	expect_false(HoldfastMeta.path_open(content, won, "tideblade"), "no level opens it yet")
	expect_eq(HoldfastMeta.select_pillar(content, won, "dusk_mage")["pillar"], "dusk_mage")
	var lost := HoldfastMeta.bank_run(content, profile, {"outcome": "lost", "level": "gull_rock", "gold": 0})
	expect_false(HoldfastMeta.path_open(content, lost, "dusk_mage"), "losing it opens nothing")


func test_the_gate_holds_through_a_real_save_and_a_save_already_using_a_path_keeps_it() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_false(HoldfastMeta.path_open(content, _through_json(profile), "dusk_mage"))
	var won := HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "gull_rock", "gold": 0})
	expect_true(HoldfastMeta.path_open(content, _through_json(won), "dusk_mage"), "won, saved, loaded: open")
	# A save from before the gate that plays the Tideblade, with nothing won.
	var old := HoldfastMeta.new_profile(content)
	old["pillar"] = "tideblade"
	old.erase("paths_kept")
	var loaded := _through_json(old)
	expect_eq(loaded["pillar"], "tideblade")
	expect_true(HoldfastMeta.path_open(content, loaded, "tideblade"), "it keeps the path it plays")
	var back := HoldfastMeta.select_pillar(content, loaded, "flare_archer")
	expect_eq(HoldfastMeta.select_pillar(content, _through_json(back), "tideblade")["pillar"], "tideblade", "and can return to it after a save")
	expect_false(HoldfastMeta.path_open(content, loaded, "dusk_mage"), "the other is still closed")


func test_the_profile_answers_the_two_questions_the_screens_ask() -> void:
	var profile := HoldfastProfile.new()
	tree.root.add_child(profile)
	expect_eq(profile.get_pillar_lock_reason("dusk_mage"), "Opens when you win Gull Rock.")
	expect_eq(profile.get_pillar_lock_reason("flare_archer"), "")
	expect_eq(profile.get_paths_opened_by("gull_rock"), ["dusk_mage"])
	profile.select_pillar("dusk_mage")
	expect_eq(profile.get_pillar(), "flare_archer", "the closed path was not taken")
	profile.free()


func test_every_gate_in_the_pack_names_a_real_level_or_says_why_not() -> void:
	var content := _content()
	for id in content["hero_paths"]:
		var opens: Dictionary = content["hero_paths"][id].get("opens", {})
		if opens.is_empty():
			continue
		var after := str(opens.get("after", ""))
		expect_true(content["levels"].has(after) or (after == "" and str(opens.get("reason", "")) != ""), id + " opens at a level that exists, or says why not")


# ------------------------------------------------------------------ the end of content

func test_content_is_cleared_only_when_every_level_beyond_the_tutorial_is_won_and_it_survives_a_save() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_false(HoldfastMeta.content_cleared(content, profile))
	var ids: Array = content["levels"].keys().filter(func(id: String) -> bool: return not content["levels"][id].get("tutorial", false))
	for i in ids.size():
		profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": ids[i], "gold": 0})
		expect_eq(HoldfastMeta.content_cleared(content, _through_json(profile)), i == ids.size() - 1, "after %s" % ids[i])


func test_an_all_won_save_has_no_next_level_and_says_more_is_coming() -> void:
	var path := _save_path("all_won")
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	ThroughLevelZero.apply(profile)
	profile.begin_stand()
	for id in _content()["levels"]:
		profile.bank_run({"outcome": "won", "level": id, "gold": 0})
	profile.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_true(again.is_content_cleared(), "loaded from the file")
	expect_eq(Guidance.next_goal(_content(), again), Guidance.MORE_COMING)
	var notes: Dictionary = Guidance.summary_notes(_content(), again, {"outcome": "won", "level": "gull_rock"}, "")
	expect_eq(notes["way_on"], Guidance.MORE_COMING, "the summary has no next level and says more is coming")
	again.free()


# ------------------------------------------------------------------ pause and leave

func test_a_paused_run_does_not_move_and_resumes_where_it_was() -> void:
	var main := _run_started()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = true
	source._process(1.0)
	var before := source.get_engine().state_hash()
	main.hud.pause_requested.emit(true)
	expect_true(source.is_paused())
	source._process(1.0)
	source._process(1.0)
	expect_eq(source.get_engine().state_hash(), before, "nothing moved while paused")
	main.hud.pause_requested.emit(false)
	expect_false(source.is_paused())
	source._process(1.0)
	expect_true(source.get_engine().state_hash() != before, "and it moves again")
	main.free()


func test_the_keys_and_the_button_pause_and_resume() -> void:
	var main := _run_started()
	var source: HoldfastRunSource = main.get_node("RunSource")
	for code in [KEY_ESCAPE, KEY_P]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.pressed = true
		main.hud._input(key)
		expect_true(source.is_paused(), "pause with %d" % code)
		main.hud._input(key)
		expect_false(source.is_paused(), "and resume with it")
	main.hud._pause_button.pressed.emit()
	expect_true(source.is_paused(), "the button pauses")
	main.hud._refresh_hero()
	expect_true(main.hud._pause_screen.visible, "and the pause screen is up")
	main.hud._pause_button.pressed.emit()
	expect_false(source.is_paused())
	main.free()


func test_leaving_asks_twice_and_banks_nothing() -> void:
	var main := _run_started()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	var before := profile.data.duplicate(true)
	before["run_open"] = true
	var ended := []
	source.run_ended.connect(func(summary: Dictionary) -> void: ended.append(summary))
	source.step(20.0)
	main.hud.pause_requested.emit(true)
	main.hud._leave_button.pressed.emit()
	expect_true(source.is_running(), "one press only asks")
	expect_true(main.hud._leave_button.text.contains("Nothing is banked"))
	main.hud._leave_button.pressed.emit()
	expect_false(source.is_running(), "the second leaves")
	expect_true(ended.is_empty(), "no result is sent")
	expect_eq(profile.data["runs"], before["runs"], "no run is counted")
	expect_eq(profile.data["gold"], before["gold"], "no gold is paid")
	expect_eq(profile.data["stars"], before["stars"], "no stars")
	expect_eq(profile.data["levels_won"], before["levels_won"], "no level is won")
	expect_false(profile.data["run_open"], "and the run is no longer open")
	expect_eq(main.screen, main.Screen.MAP, "the player is back on the map")
	main.free()


func test_resuming_after_the_first_press_resets_it() -> void:
	var main := _run_started()
	var source: HoldfastRunSource = main.get_node("RunSource")
	main.hud.pause_requested.emit(true)
	main.hud._leave_button.pressed.emit()
	main.hud.pause_requested.emit(false)
	main.hud._refresh_hero()
	main.hud.pause_requested.emit(true)
	main.hud._leave_button.pressed.emit()
	expect_true(source.is_running(), "the earlier press did not carry over")
	main.free()


func test_a_run_started_after_leaving_banks_once_and_pays_once() -> void:
	var main := _run_started()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	var runs: int = profile.data["runs"]
	main.hud.leave_requested.emit()
	main.journey._buttons["outpost"].pressed.emit()
	main.planning.auto_place()
	main.planning.get_node("%StartButton").pressed.emit()
	expect_true(source.is_running())
	source.controller_override = null
	for i in 600:
		if not source.is_running():
			break
		source.step(5.0)
	expect_false(source.is_running(), "it ran to its end")
	expect_eq(profile.data["runs"], runs + 1, "exactly one run counted")
	expect_false(profile.data["run_open"])
	main.free()


func test_a_reload_mid_run_says_the_run_is_gone_and_loses_nothing_else() -> void:
	var path := _save_path("reload")
	var main := _run_started(path)
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_true(profile.data["run_open"], "the run is open in the save")
	var kept := profile.data.duplicate(true)
	kept["run_open"] = false
	main.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_true(again.load_message.contains("lost when the game closed"), "the player is told: %s" % again.load_message)
	expect_eq(again.data, kept, "everything else is as it was")
	expect_false(again.data["run_open"])
	again.leave_run()
	again.free()
	var third := HoldfastProfile.new()
	third.save_path = path
	tree.root.add_child(third)
	expect_false(third.load_message.contains("lost when the game closed"), "and it is said once")
	third.free()


func test_a_run_that_ends_or_is_left_leaves_no_open_run_in_the_save() -> void:
	var path := _save_path("closed")
	var main := _run_started(path)
	main.hud.leave_requested.emit()
	main.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_false(again.load_message.contains("lost when the game closed"), "left: nothing to report")
	again.free()


# ------------------------------------------------------------------ game speed

func test_speed_is_one_or_two_and_survives_a_real_save() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_eq(profile["speed"], 1)
	expect_eq(_through_json(HoldfastMeta.set_speed(profile, 2))["speed"], 2)
	expect_eq(HoldfastMeta.set_speed(profile, 7)["speed"], 1, "anything else is 1x")
	var damaged := profile.duplicate(true)
	damaged["speed"] = "fast"
	expect_eq(_through_json(damaged)["speed"], 1)


func test_the_rules_and_rewards_are_the_same_at_both_speeds() -> void:
	var results := []
	for speed in [1, 2]:
		var source := HoldfastRunSource.new()
		source.auto_step = true
		source.rng_seed = 5
		source.level_id = "outpost"
		source.use_bot = true
		tree.root.add_child(source)
		source.set_speed(speed)
		source.start_run()
		var frames := 0
		while source.is_running() and frames < 100000:
			source._process(1.0 / 20.0)
			frames += 1
		expect_false(source.is_running())
		results.append({"hash": source.get_engine().state_hash(), "result": source.get_rules().result(), "frames": frames})
		source.free()
	expect_eq(results[1]["hash"], results[0]["hash"], "the same run, tick for tick")
	expect_eq(results[1]["result"], results[0]["result"], "and the same gold, stars and outcome")
	expect_true(results[1]["frames"] * 2 <= results[0]["frames"] + 2, "in half the frames")


func test_the_button_flips_the_speed_and_the_profile_remembers_it() -> void:
	var path := _save_path("speed")
	var main := _run_started(path)
	var source: HoldfastRunSource = main.get_node("RunSource")
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_eq(source.get_speed(), 1)
	main.hud._speed_button.pressed.emit()
	expect_eq(source.get_speed(), 2)
	main.hud._refresh_hero()
	expect_eq(main.hud._speed_button.text, "2x")
	expect_eq(profile.get_speed(), 2)
	main.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.get_speed(), 2, "after a reload")
	again.leave_run()
	again.free()
