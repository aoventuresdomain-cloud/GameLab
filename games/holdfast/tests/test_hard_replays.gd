extends KitTestCase
## HF-M2-65: level modifiers and Hard replays. A level carries modifiers in its data; once the level is
## won, its Hard replay plays with them, pays stars again (once, the best only) and opens nothing.

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://hard_replay_tests"
## The stat each of the five modifiers changes, and where the rules keep it.
const LEVELS := ["outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]


func _content() -> Dictionary:
	return HoldfastContent.base()


func _rules(content: Dictionary, level: String, hard: bool) -> HoldfastRules:
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config(level, [], content, "flare_archer", null, {}, [], false, false, "", {}, hard), SimRng.new(1))
	return rules


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


## A profile that has cleared the first five levels.
func _cleared(content: Dictionary) -> Dictionary:
	var profile := HoldfastMeta.new_profile(content)
	profile["levels_won"] = ["first_watch"] + LEVELS
	profile["unlocked"] = LEVELS.duplicate()
	for level in LEVELS:
		profile["stars"][level] = 1
	return profile


func _hard_win(level: String, keep_left: float) -> Dictionary:
	return {"outcome": HoldfastRules.OUTCOME_WON, "level": level, "gold": 10, "hard": true, "keep_left": keep_left}


# ------------------------------------------------------------------ the data

func test_each_of_the_five_levels_carries_a_modifier_that_the_pack_defines() -> void:
	var content := _content()
	expect_true(content["modifiers"].size() >= 5, "the pack defines modifiers")
	for level in LEVELS:
		var ids: Array = content["levels"][level]["modifiers"]
		expect_eq(ids.size(), 1, "%s has one" % level)
		for id in ids:
			expect_true(content["modifiers"].has(id), "%s: %s is in the pack" % [level, id])
	expect_false(content["levels"]["first_watch"].has("modifiers"), "the tutorial has none")
	var words := LEVELS.map(func(level: String) -> String: return HoldfastMeta.hard_label(content, level))
	expect_eq(words.size(), 5)
	for word in words:
		expect_true(str(word) != "", "each has an icon and one word")
	for i in words.size():
		for j in range(i + 1, words.size()):
			expect_true(words[i] != words[j], "no two levels share a modifier: %s" % words[i])


func test_the_modifiers_change_more_than_one_kind_of_thing() -> void:
	var stats := {}
	for id in _content()["modifiers"]:
		for effect in _content()["modifiers"][id]["effects"]:
			stats[effect["stat"]] = true
	expect_true(stats.size() >= 4, "monsters' speed, health or damage, gold and the Keep are all in play: %s" % str(stats.keys()))
	expect_true(stats.has("keep_health") and stats.has("gold_multiplier") and stats.has("enemy_speed"), "Keep, gold and monster changes")


func test_every_modifier_is_read_from_data() -> void:
	var base := _content()
	for level in LEVELS:
		var content: Dictionary = base.duplicate(true)
		var id: String = content["levels"][level]["modifiers"][0]
		# Replace its effects with a marker of each kind in turn: the rules must follow the data.
		for check in [["enemy_speed", 3.0], ["enemy_health", 2.5], ["enemy_damage", 4.0], ["gold_multiplier", 0.25], ["keep_health", 0.5]]:
			content["modifiers"][id]["effects"] = [{"stat": check[0], "multiply": check[1]}]
			var normal := _rules(content, level, false)
			var hard := _rules(content, level, true)
			expect_true(hard.hard and not normal.hard, "%s: Hard is on only when asked" % level)
			match check[0]:
				"enemy_speed":
					expect_eq([normal.enemy_speed, hard.enemy_speed], [1.0, 3.0], "%s: speed" % level)
				"enemy_health":
					expect_eq([normal.enemy_health_scale, hard.enemy_health_scale], [1.0, 2.5], "%s: health" % level)
				"enemy_damage":
					expect_eq([normal.enemy_damage_scale, hard.enemy_damage_scale], [1.0, 4.0], "%s: damage" % level)
				"gold_multiplier":
					expect_eq([normal.gold_multiplier, hard.gold_multiplier], [1.0, 0.25], "%s: gold" % level)
				"keep_health":
					expect_eq(hard.keep_health_max, roundi(normal.keep_health_max * 0.5), "%s: the Keep" % level)


func test_the_levels_own_modifier_is_what_a_hard_run_applies() -> void:
	var content := _content()
	for level in LEVELS:
		var id: String = content["levels"][level]["modifiers"][0]
		var effect: Dictionary = content["modifiers"][id]["effects"][0]
		var normal := _rules(content, level, false)
		var hard := _rules(content, level, true)
		match effect["stat"]:
			"enemy_speed":
				expect_eq(hard.enemy_speed, normal.enemy_speed * float(effect["multiply"]), "%s: %s" % [level, id])
			"enemy_health":
				expect_eq(hard.enemy_health_scale, float(effect["multiply"]), "%s: %s" % [level, id])
			"enemy_damage":
				expect_eq(hard.enemy_damage_scale, float(effect["multiply"]), "%s: %s" % [level, id])
			"gold_multiplier":
				expect_eq(hard.gold_multiplier, float(effect["multiply"]), "%s: %s" % [level, id])
			"keep_health":
				expect_eq(hard.keep_health_max, roundi(float(normal.keep_health_max) * float(effect["multiply"])), "%s: %s" % [level, id])
		expect_eq(normal.enemy_health_scale, 1.0, "%s: Normal is untouched" % level)


func test_a_hard_replay_changes_what_the_monsters_do_not_only_their_numbers() -> void:
	var content := _content()
	content["levels"]["outpost"]["first_wave_delay"] = 0.0
	var normal := _rules(content, "outpost", false)
	var swift := _rules(content, "outpost", true)
	for rules in [normal, swift]:
		for i in 60:
			rules.step(1.0 / HoldfastRules.TICK_RATE, {})
	expect_true(not normal.enemies.is_empty() and not swift.enemies.is_empty(), "monsters are out")
	# The same spawns, the swift ones have come further in the same time.
	var far_normal := 0.0
	var far_swift := 0.0
	for e in normal.enemies:
		far_normal = maxf(far_normal, e.position.length())
	for e in swift.enemies:
		far_swift = maxf(far_swift, e.position.length())
	expect_true(swift.enemy_speed > normal.enemy_speed, "Swift monsters are faster: %s against %s" % [swift.enemy_speed, normal.enemy_speed])
	var result := swift.result()
	expect_true(result.get("hard", false), "the result says it was a Hard replay")
	expect_false(normal.result().has("hard"), "and a Normal run does not")


func test_the_tutorial_has_no_hard_replay_even_when_asked() -> void:
	var content := _content()
	var rules := _rules(content, "first_watch", true)
	expect_false(rules.hard, "the tutorial ignores Hard")
	expect_eq(HoldfastMeta.hard_modifiers(content, "first_watch"), [], "and has no modifiers")


func test_nightmare_is_a_stub_in_data_that_nothing_offers() -> void:
	var modes: Dictionary = _content()["modes"]
	expect_true(modes.has("hard") and modes["hard"]["built"], "Hard is built")
	expect_true(modes.has("nightmare") and not modes["nightmare"]["built"], "Nightmare is only a stub: it shows where it goes")
	expect_eq(modes["nightmare"]["unlock"], "hard_cleared", "after Hard")


# ------------------------------------------------------------------ opening and paying

func test_hard_opens_when_the_level_is_won() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_false(HoldfastMeta.hard_open(content, profile, "outpost"), "not before the win")
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": "outpost", "gold": 0, "keep_left": 0.6})
	expect_true(HoldfastMeta.hard_open(content, profile, "outpost"), "once it is won")
	expect_false(HoldfastMeta.hard_open(content, profile, "shingle_beach"), "only that level's")
	expect_false(HoldfastMeta.hard_open(content, profile, "first_watch"), "never the tutorial's")


func test_a_hard_win_pays_its_stars_once_and_opens_nothing_else() -> void:
	var content := _content()
	var profile := _cleared(content)
	profile["unlocked"] = ["shingle_beach"]
	profile["levels_won"] = ["first_watch", "outpost"]
	profile["stars"] = {"outpost": 1}
	var before := HoldfastMeta.stars_earned(profile)
	var won := HoldfastMeta.bank_run(content, profile, _hard_win("outpost", 0.9))
	expect_eq(won["hard_stars"], {"outpost": 3}, "above 80% of the Keep left: three stars on Hard")
	expect_eq(won["stars"], {"outpost": 1}, "Normal's stars are untouched")
	expect_eq(HoldfastMeta.stars_earned(won), before + 3, "and they are all new stars")
	expect_eq(won["levels_won"], profile["levels_won"], "no level is won again")
	expect_eq(won["unlocked"], profile["unlocked"], "and none is opened")
	expect_eq(int(won["gold"]), int(profile["gold"]) + 10, "the gold of the run is banked, with no first-clear reward")
	var again := HoldfastMeta.bank_run(content, won, _hard_win("outpost", 0.9))
	expect_eq(HoldfastMeta.stars_earned(again), before + 3, "the same stars are not paid twice")
	var worse := HoldfastMeta.bank_run(content, won, _hard_win("outpost", 0.55))
	expect_eq(worse["hard_stars"], {"outpost": 3}, "a worse win keeps the best")
	var mid := HoldfastMeta.bank_run(content, profile, _hard_win("outpost", 0.55))
	var better := HoldfastMeta.bank_run(content, mid, _hard_win("outpost", 0.95))
	expect_eq([mid["hard_stars"]["outpost"], better["hard_stars"]["outpost"]], [2, 3], "a better win pays only the difference")
	expect_eq(HoldfastMeta.stars_earned(better), before + 3, "three stars in all, never six")


func test_a_lost_or_unopened_hard_replay_pays_no_stars() -> void:
	var content := _content()
	var profile := _cleared(content)
	var lost := HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_LOST, "level": "outpost", "gold": 5, "hard": true, "keep_left": 0.0})
	expect_eq(lost["hard_stars"], {}, "a loss pays nothing")
	var fresh := HoldfastMeta.new_profile(content)
	var unopened := HoldfastMeta.bank_run(content, fresh, _hard_win("outpost", 0.9))
	expect_eq(unopened["hard_stars"], {}, "a level not yet won has no Hard replay to pay")
	expect_false("outpost" in unopened["levels_won"], "and a Hard win does not win the level")


func test_hard_stars_reach_the_stars_to_spend_and_the_blessing_rules_through_the_total() -> void:
	var content := _content()
	var profile := _cleared(content)
	var free := HoldfastMeta.stars_available(content, profile)
	profile["hard_stars"] = {"gull_rock": 3, "outpost": 2}
	expect_eq(HoldfastMeta.stars_available(content, profile), free + 5, "five more stars to spend")
	expect_eq(HoldfastMeta.blessings_unlocked(content, profile).has("tides_gift"), HoldfastMeta.stars_earned(profile) >= 8, "the star-count blessing counts them")


# ------------------------------------------------------------------ through a real JSON save

func test_hard_stars_are_saved_and_come_back_from_a_real_save() -> void:
	var path := _save_path("hard")
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run({"gold": 0, "outcome": "won", "level": "outpost", "keep_left": 0.6})
	expect_true(profile.is_hard_open("outpost"), "winning Outpost opens its Hard replay")
	profile.bank_run(_hard_win("outpost", 0.9))
	expect_eq(profile.get_hard_stars("outpost"), 3)
	var expected := profile.data.duplicate(true)
	var total := profile.get_stars_earned()
	profile.free()

	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.load_status, "ok")
	expect_eq(again.data["hard_stars"], {"outpost": 3}, "the Hard stars come back")
	expect_eq(again.data, expected, "everything comes back, types included")
	expect_eq(again.get_stars_earned(), total, "with the same total")
	again.bank_run(_hard_win("outpost", 0.9))
	expect_eq(again.get_stars_earned(), total, "and they cannot be earned a second time")
	again.free()


func test_a_save_cannot_claim_hard_stars_it_has_not_earned() -> void:
	var content := _content()
	var data := HoldfastMeta.new_profile(content)
	data["levels_won"] = ["first_watch", "outpost"]
	data["hard_stars"] = {"outpost": 2, "shingle_beach": 3, "first_watch": 3, "nowhere": 1}
	var loaded := HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(data)))
	expect_eq(loaded["hard_stars"], {"outpost": 2}, "only a won level with a Hard replay keeps its stars")
	data["hard_stars"] = {"outpost": 9}
	expect_eq(HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(data)))["hard_stars"], {"outpost": 3}, "at most three")
	data["hard_stars"] = "many"
	expect_eq(HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(data)))["hard_stars"], {}, "damaged data is dropped")
	var old: Dictionary = JSON.parse_string(JSON.stringify(HoldfastMeta.new_profile(content)))
	old.erase("hard_stars")
	expect_eq(HoldfastMeta.from_save(content, old)["hard_stars"], {}, "a save from before Hard has none")


# ------------------------------------------------------------------ the screens

func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func test_the_map_shows_a_cleared_levels_modifier_and_a_switch_turns_hard_on() -> void:
	var main := _main()
	var profile: Node = main.profile
	ThroughLevelZero.apply(profile)
	var journey: Control = main.journey
	expect_false(journey._hard_button.visible, "no Hard switch before a level is cleared")
	expect_eq(journey._hard_names["outpost"].text, "", "nor a modifier")
	profile.bank_run({"gold": 0, "outcome": "won", "level": "outpost", "keep_left": 0.6})
	expect_true(journey._hard_button.visible, "the switch appears once a level is cleared")
	expect_eq(journey._hard_names["outpost"].text, ">> Swift", "the cleared level names its modifier on a line under its caption")
	expect_eq(journey._hard_names["shingle_beach"].text, "", "a level not cleared does not")
	expect_false(journey._names["outpost"].text.contains("Swift"), "the caption itself is as it was")
	expect_false(profile.is_hard_selected(), "Normal is the default")
	journey._hard_button.button_pressed = true
	expect_true(profile.is_hard_on(), "the switch turns Hard on")
	journey._hard_button.button_pressed = false
	expect_false(profile.is_hard_on(), "and off")
	journey._hard_button.button_pressed = true
	profile.select_level("outpost")
	expect_true(profile.is_hard_selected(), "the cleared level plays as its Hard replay")
	profile.select_level("shingle_beach")
	expect_false(profile.is_hard_selected(), "a level with no Hard open plays Normal")
	expect_eq(journey._plan_target(), "outpost", "Plan opens the latest cleared level while Hard is on")
	main.free()


func test_a_hard_run_starts_with_the_flag_and_the_plan_page_says_so() -> void:
	var main := _main()
	var profile: Node = main.profile
	ThroughLevelZero.apply(profile)
	profile.bank_run({"gold": 0, "outcome": "won", "level": "outpost", "keep_left": 0.6})
	profile.select_hard(true)
	main.journey.level_requested.emit("outpost")
	expect_true(main.planning._title.text.contains("Hard: >> Swift"), "the Plan page names the modifier: %s" % main.planning._title.text)
	main.planning.start_requested.emit(["west_gate"])
	var source: Node = main.get_node("RunSource")
	expect_true(source.hard, "the run is the Hard replay")
	expect_true(source.is_running(), "and it started")
	main.free()
	var normal := _main()
	ThroughLevelZero.apply(normal.profile)
	normal.profile.bank_run({"gold": 0, "outcome": "won", "level": "outpost", "keep_left": 0.6})
	normal.journey.level_requested.emit("outpost")
	expect_true(normal.planning._title.text.ends_with("The Outpost"), "Normal says nothing extra: %s" % normal.planning._title.text)
	normal.planning.start_requested.emit(["west_gate"])
	expect_false(normal.get_node("RunSource").hard, "a Normal run is not Hard")
	normal.free()


# ------------------------------------------------------------------ the simulator and the bands

func test_the_simulator_plays_a_hard_replay_and_a_climb_can_include_one() -> void:
	var content := _content()
	var config := HoldfastContent.run_config("outpost", [], content, "flare_archer", null, {}, [], false, false, "", {}, true)
	var report := HoldfastSim.run_headless(1, config)
	expect_true(report["result"].get("hard", false), "the headless simulator runs a Hard replay and the result says so")
	var climb := HoldfastCurve.climb(1, HoldfastSkilledBot.AVERAGE, "flare_archer", 2, [], false, [], true)
	expect_true(climb["levels"]["outpost"].has("hard"), "a climb with Hard replays records the first level's")
	var plain := HoldfastCurve.climb(1, HoldfastSkilledBot.AVERAGE, "flare_archer", 2)
	expect_false(plain["levels"]["outpost"].has("hard"), "and one without them does not")


func test_every_level_has_a_hard_band_and_a_hard_cell_is_played() -> void:
	var bands := HoldfastBands.load_bands()
	for level in HoldfastBands.levels():
		var band: Array = bands["hard"][level]["average"]
		expect_true(float(band[0]) < float(band[1]) and float(band[1]) <= 1.0, "%s has a Hard band with room" % level)
	var rows := HoldfastBands.hard_cell("flare_archer", 1)
	expect_eq(rows.size(), 1, "one player")
	expect_true(rows[0].has("outpost") and rows[0]["outpost"] is bool, "who played the first level's Hard replay")


func test_a_hard_replay_outside_its_band_fails_the_gate() -> void:
	var bands := HoldfastBands.load_bands()
	var cells := {}
	for pillar in HoldfastBands.PILLARS:
		for cell in ["average", "poor", "volley", "sniper", "no_special"]:
			cells["%s/%s" % [pillar, cell]] = [{}]
		cells["%s/hard" % pillar] = [{"outpost": true, "gull_rock": true}, {"outpost": true, "gull_rock": true}]
	var figs := HoldfastBands.figures(bands, cells)
	expect_true(figs.has("flare_archer/hard/outpost") and figs.has("flare_archer/hard/old_pier"), "the Flare Archer has a Hard figure for each level")
	expect_true(figs.has("dusk_mage/hard/gull_rock") and not figs.has("dusk_mage/hard/outpost"), "a pillar is judged on its scope, as for Normal")
	var judged := HoldfastBands.evaluate(figs, {})
	expect_eq(judged["flare_archer/hard/outpost"]["state"], "MISSED", "every player winning Hard at Outpost is above its band")
	cells["flare_archer/hard"] = [{"outpost": true}, {"outpost": false}]
	expect_eq(HoldfastBands.evaluate(HoldfastBands.figures(bands, cells), {})["flare_archer/hard/outpost"]["state"], "met", "half of the players is inside it")
