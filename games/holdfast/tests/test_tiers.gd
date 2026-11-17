extends KitTestCase
## HF-M2-87: four difficulty tiers. Easy (a softer fight that pays one star and shares Normal's record), Normal,
## Hard (a level's modifier, opened by a Normal win) and Extreme (a second modifier, opened by a Hard win).

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://tier_tests"
const LEVELS := ["outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]
const PILLARS := ["flare_archer", "dusk_mage", "tideblade"]
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]


func _content() -> Dictionary:
	return HoldfastContent.base()


func _rules(level: String, tier: Variant, content: Dictionary = {}) -> HoldfastRules:
	var pack := content if not content.is_empty() else _content()
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config(level, [], pack, "flare_archer", null, {}, [], false, false, "", {}, tier), SimRng.new(1))
	return rules


## A profile that has cleared the first five levels on Normal.
func _cleared(content: Dictionary) -> Dictionary:
	var profile := HoldfastMeta.new_profile(content)
	profile["levels_won"] = ["first_watch"] + LEVELS
	profile["unlocked"] = LEVELS.duplicate()
	for level in LEVELS:
		profile["stars"][level] = 1
	return profile


func _win(level: String, tier: String, keep_left: float) -> Dictionary:
	return {"outcome": HoldfastRules.OUTCOME_WON, "level": level, "gold": 10, "tier": tier, "keep_left": keep_left}


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


## The stat a modifier is about: the first thing it changes.
func _axis(content: Dictionary, id: String) -> String:
	return str(content["modifiers"][id]["effects"][0]["stat"])


# ------------------------------------------------------------------ the rules

func test_easy_applies_its_effects_from_data_and_gold_is_sixty_per_cent_of_normal() -> void:
	var content := _content()
	var effects: Array = content["modes"]["easy"]["effects"]
	var gold := 1.0
	for effect in effects:
		if effect["stat"] == "gold_multiplier":
			gold = float(effect["multiply"])
	expect_eq(gold, 0.6, "Easy pays 60% of Normal's gold")
	for level in LEVELS:
		var normal := _rules(level, "normal")
		var easy := _rules(level, "easy")
		expect_eq(easy.difficulty, "easy", "%s: the rules know the tier" % level)
		expect_false(easy.hard, "%s: Easy is not a Hard run" % level)
		expect_eq(easy.gold_multiplier, normal.gold_multiplier * gold, "%s: gold" % level)
		expect_true(easy.enemy_health_scale <= normal.enemy_health_scale, "%s: monsters are no tougher" % level)
		expect_true(easy.keep_health_max >= normal.keep_health_max, "%s: the Keep is no frailer" % level)
		expect_false(easy.result().get("hard", false), "%s: a Hard flag is not set" % level)
		expect_eq(easy.result()["tier"], "easy", "%s: the result names the tier" % level)
		expect_false(normal.result().has("tier"), "%s: a Normal run reads as it always did" % level)
		# The level's own softening makes it easier, never harder, and leaves the gold to the mode.
		var softening: Array = content["levels"][level].get("easy_effects", [])
		expect_false(softening.is_empty(), "%s softens something on Easy" % level)
		for effect in softening:
			expect_true(effect["stat"] != "gold_multiplier", "%s: the mode sets Easy's gold" % level)
			var more := float(effect["multiply"]) >= 1.0
			expect_true(more if effect["stat"] == "keep_health" else not more, "%s: %s goes the player's way" % [level, effect["stat"]])


func test_easy_carries_no_modifier_and_a_data_change_to_its_effects_is_followed() -> void:
	var content: Dictionary = _content().duplicate(true)
	content["modes"]["easy"]["effects"] = [{"stat": "enemy_speed", "multiply": 0.5}]
	var rules := _rules("outpost", "easy", content)
	expect_eq(rules.enemy_speed, 0.5, "the rules follow the data")
	expect_eq(rules.gold_multiplier, 1.0, "and nothing else changes")


func test_extreme_adds_a_second_modifier_on_another_axis_and_pays_no_more_gold_than_hard() -> void:
	var content := _content()
	for level in LEVELS:
		var first: Array = content["levels"][level]["modifiers"]
		var second: Array = content["levels"][level]["extreme_modifiers"]
		expect_eq(second.size(), 1, "%s has one second modifier" % level)
		expect_true(second[0] != first[0], "%s: it is another modifier" % level)
		expect_true(_axis(content, second[0]) != _axis(content, first[0]), "%s: on another axis (%s and %s)" % [level, first[0], second[0]])
		var hard := _rules(level, "hard")
		var extreme := _rules(level, "extreme")
		expect_true(extreme.hard and hard.hard, "%s: both are replays" % level)
		expect_eq(extreme.result()["tier"], "extreme", "%s: the result names the tier" % level)
		expect_true(extreme.gold_multiplier <= hard.gold_multiplier, "%s: no more gold than Hard" % level)
		# Both modifiers are in force: each multiplies the stat it changes.
		var speed := 1.0
		var health := 1.0
		for id in first + second:
			for effect in content["modifiers"][id]["effects"]:
				if effect["stat"] == "enemy_speed":
					speed *= float(effect["multiply"])
				elif effect["stat"] == "enemy_health":
					health *= float(effect["multiply"])
		expect_eq(extreme.enemy_speed, _rules(level, "normal").enemy_speed * speed, "%s: speed" % level)
		expect_true(absf(extreme.enemy_health_scale - health) < 0.0001, "%s: health" % level)


func test_the_tutorial_and_a_mistyped_tier_play_as_normal() -> void:
	expect_eq(_rules("first_watch", "extreme").difficulty, "normal", "the tutorial ignores the tier")
	expect_eq(_rules("outpost", "nightmare").difficulty, "normal", "an unknown tier is Normal")
	expect_eq(_rules("outpost", true).difficulty, "hard", "the old Hard flag still means Hard")
	expect_eq(_rules("outpost", false).difficulty, "normal", "and no flag Normal")


# ------------------------------------------------------------------ opening and paying

func test_an_easy_win_clears_the_level_and_pays_one_star_but_opens_no_hard() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile["unlocked"] = ["outpost"]
	profile["levels_won"] = ["first_watch"]
	var won := HoldfastMeta.bank_run(content, profile, _win("outpost", "easy", 0.95))
	expect_true("outpost" in won["levels_won"], "Easy clears the level")
	expect_true("shingle_beach" in won["unlocked"], "and opens the next one")
	expect_eq(won["stars"]["outpost"], 1, "it pays one star however well it went")
	expect_false(HoldfastMeta.hard_open(content, won, "outpost"), "Hard is not open on an Easy win")
	expect_eq(HoldfastMeta.tiers_open(content, won, "outpost"), ["easy", "normal"])
	var again := HoldfastMeta.bank_run(content, won, _win("outpost", "easy", 0.95))
	expect_eq(HoldfastMeta.stars_earned(again), HoldfastMeta.stars_earned(won), "and pays it once")


func test_a_normal_win_after_easy_opens_hard_and_the_two_share_three_stars() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile["unlocked"] = ["outpost"]
	profile["levels_won"] = ["first_watch"]
	var easy := HoldfastMeta.bank_run(content, profile, _win("outpost", "easy", 0.95))
	var normal := HoldfastMeta.bank_run(content, easy, _win("outpost", "normal", 0.95))
	expect_true(HoldfastMeta.hard_open(content, normal, "outpost"), "a Normal win opens Hard")
	expect_eq(normal["stars"]["outpost"], 3, "Normal pays up to three, sharing Easy's record")
	expect_eq(HoldfastMeta.stars_earned(normal), 3 + HoldfastMeta.stars_earned(HoldfastMeta.new_profile(content)), "never more than three together")
	var back := HoldfastMeta.bank_run(content, normal, _win("outpost", "easy", 0.95))
	expect_eq(back["stars"]["outpost"], 3, "an Easy win after Normal pays nothing more")
	expect_eq(HoldfastMeta.stars_earned(back), HoldfastMeta.stars_earned(normal))
	# And the other way round: a Normal win first, then Easy.
	var first := HoldfastMeta.bank_run(content, profile, _win("outpost", "normal", 0.6))
	var after := HoldfastMeta.bank_run(content, first, _win("outpost", "easy", 0.95))
	expect_eq(after["stars"], first["stars"], "Easy cannot raise a Normal record")
	expect_true(HoldfastMeta.hard_open(content, after, "outpost"), "and does not shut Hard")


func test_easy_gold_follows_the_run_and_easy_is_not_counted_as_a_clean_win() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile["unlocked"] = ["outpost"]
	profile["levels_won"] = ["first_watch"]
	var result := _win("outpost", "easy", 0.95)
	result["towers_lost"] = 0
	var clean := int(profile["counters"]["clean_wins"])
	var won := HoldfastMeta.bank_run(content, profile, result)
	expect_eq(int(won["counters"]["clean_wins"]), clean, "an Easy win does not count towards clean wins")
	var normal := result.duplicate()
	normal["tier"] = "normal"
	expect_eq(int(HoldfastMeta.bank_run(content, profile, normal)["counters"]["clean_wins"]), clean + 1, "a Normal one does")


func test_extreme_opens_on_a_hard_win_pays_hard_stars_once_and_opens_nothing_else() -> void:
	var content := _content()
	var profile := _cleared(content)
	expect_false(HoldfastMeta.extreme_open(content, profile, "outpost"), "not before Hard is won")
	expect_eq(HoldfastMeta.tiers_open(content, profile, "outpost"), ["easy", "normal", "hard"])
	var unopened := HoldfastMeta.bank_run(content, profile, _win("outpost", "extreme", 0.9))
	expect_eq(unopened["extreme_stars"], {}, "an Extreme win before Hard pays nothing")
	var hard := HoldfastMeta.bank_run(content, profile, _win("outpost", "hard", 0.55))
	expect_true(HoldfastMeta.extreme_open(content, hard, "outpost"), "a Hard win opens Extreme")
	expect_eq(HoldfastMeta.tiers_open(content, hard, "outpost"), ["easy", "normal", "hard", "extreme"])
	var before := HoldfastMeta.stars_earned(hard)
	var won := HoldfastMeta.bank_run(content, hard, _win("outpost", "extreme", 0.9))
	expect_eq(won["extreme_stars"], {"outpost": 3}, "Extreme pays as Hard does, up to three")
	expect_eq(HoldfastMeta.stars_earned(won), before + 3, "all of them new")
	expect_eq(won["levels_won"], hard["levels_won"], "no level is won again")
	expect_eq(won["unlocked"], hard["unlocked"], "and none is opened")
	var again := HoldfastMeta.bank_run(content, won, _win("outpost", "extreme", 0.9))
	expect_eq(HoldfastMeta.stars_earned(again), before + 3, "the same stars are not paid twice")
	var lost := HoldfastMeta.bank_run(content, hard, {"outcome": HoldfastRules.OUTCOME_LOST, "level": "outpost", "gold": 3, "tier": "extreme", "keep_left": 0.0})
	expect_eq(lost["extreme_stars"], {}, "a loss pays nothing")


func test_the_tutorial_and_an_unreached_level_offer_no_tiers() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_eq(HoldfastMeta.tiers_open(content, profile, "first_watch"), [], "never the tutorial's")
	expect_eq(HoldfastMeta.tiers_open(content, profile, "gull_rock"), [], "nor a level that is not open")
	profile["unlocked"] = ["outpost"]
	expect_eq(HoldfastMeta.tiers_open(content, profile, "outpost"), ["easy", "normal"], "Easy opens with the level")


# ------------------------------------------------------------------ through a real JSON save

func test_easy_and_extreme_records_come_back_from_a_real_save() -> void:
	var path := _save_path("tiers")
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run(_win("outpost", "easy", 0.9))
	expect_true("outpost" in profile.data["easy_only"], "an Easy-only level is listed")
	profile.bank_run(_win("outpost", "normal", 0.9))
	expect_false("outpost" in profile.data["easy_only"], "a Normal win takes it off")
	profile.bank_run(_win("outpost", "hard", 0.9))
	profile.bank_run(_win("outpost", "extreme", 0.9))
	profile.bank_run(_win("shingle_beach", "easy", 0.9))
	expect_eq(profile.get_extreme_stars("outpost"), 3)
	var expected := profile.data.duplicate(true)
	var total := profile.get_stars_earned()
	profile.free()

	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.load_status, "ok")
	expect_eq(again.data["extreme_stars"], {"outpost": 3}, "the Extreme stars come back")
	expect_eq(again.data["easy_only"], ["shingle_beach"], "and so does the Easy-only list")
	expect_eq(again.data, expected, "everything comes back, types included")
	expect_eq(again.get_stars_earned(), total, "with the same total")
	again.bank_run(_win("outpost", "extreme", 0.9))
	expect_eq(again.get_stars_earned(), total, "and the stars cannot be earned a second time")
	again.free()


func test_a_save_from_before_the_tiers_loads_with_none_and_a_bad_one_is_cleaned() -> void:
	var content := _content()
	var old: Dictionary = JSON.parse_string(JSON.stringify(HoldfastMeta.new_profile(content)))
	old.erase("extreme_stars")
	old.erase("easy_only")
	var loaded := HoldfastMeta.from_save(content, old)
	expect_eq(loaded["extreme_stars"], {}, "no Extreme stars")
	expect_eq(loaded["easy_only"], [], "and no Easy-only levels")
	var data := HoldfastMeta.new_profile(content)
	data["levels_won"] = ["first_watch", "outpost", "shingle_beach"]
	data["hard_stars"] = {"outpost": 1, "shingle_beach": 2}
	data["extreme_stars"] = {"outpost": 9, "shingle_beach": 2, "first_watch": 1}
	data["easy_only"] = ["shingle_beach", "shingle_beach", "gull_rock", "nowhere"]
	var cleaned := HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(data)))
	expect_eq(cleaned["easy_only"], ["shingle_beach"], "Easy-only lists only levels the save has won, once each")
	expect_eq(cleaned["hard_stars"], {"outpost": 1}, "an Easy-only level has no Hard record")
	expect_eq(cleaned["extreme_stars"], {"outpost": 3}, "Extreme stars need a Hard record, at most three")
	data["extreme_stars"] = "many"
	data["easy_only"] = 7
	var damaged := HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(data)))
	expect_eq([damaged["extreme_stars"], damaged["easy_only"]], [{}, []], "damaged data is dropped")


# ------------------------------------------------------------------ the screens

func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _chip_names(journey: Control) -> Array:
	var out := []
	for tier in journey.TIER_ORDER:
		if journey._chips[tier]["box"].visible:
			out.append(tier)
	return out


func test_the_chips_show_what_is_open_with_normal_picked_and_no_locked_chips() -> void:
	var main := _main()
	var profile: Node = main.profile
	ThroughLevelZero.apply(profile)
	var journey: Control = main.journey
	expect_eq(_chip_names(journey), ["easy", "normal"], "Easy and Normal from the start, no locked chips")
	expect_true(journey._chips["normal"]["button"].button_pressed, "Normal is picked")
	expect_false(journey._chips["easy"]["button"].button_pressed)
	profile.bank_run(_win("outpost", "normal", 0.6))
	expect_eq(_chip_names(journey), ["easy", "normal", "hard"], "Hard appears once a level is won on Normal")
	profile.bank_run(_win("outpost", "hard", 0.6))
	expect_eq(_chip_names(journey), ["easy", "normal", "hard", "extreme"], "Extreme once a Hard replay is won")
	expect_eq(profile.get_run_tier(), "normal", "and Normal is still the pick")
	journey._chips["extreme"]["button"].button_pressed = true
	journey.tier_requested.emit("extreme")
	expect_eq(profile.get_tier(), "extreme", "a chip picks its tier")
	profile.select_level("outpost")
	expect_eq(profile.get_run_tier(), "extreme", "a level with Extreme open plays it")
	expect_eq(journey._plan_target(), "outpost", "and Plan opens the latest level that has it")
	profile.select_level("shingle_beach")
	expect_eq(profile.get_run_tier(), "normal", "a level without it plays Normal")
	for tier in journey.TIER_ORDER:
		expect_true(str(journey._chips[tier]["button"].text) != "", "%s has its icon and word" % tier)
	main.free()


func test_an_easy_run_starts_with_the_tier_and_the_plan_page_says_so() -> void:
	var main := _main()
	var profile: Node = main.profile
	ThroughLevelZero.apply(profile)
	profile.select_tier("easy")
	main.journey.level_requested.emit("outpost")
	expect_true(main.planning._title.text.contains("Easy"), "the Plan page names the tier: %s" % main.planning._title.text)
	main.planning.start_requested.emit(["west_gate"])
	var source: Node = main.get_node("RunSource")
	expect_eq(source.hard, "easy", "the run is an Easy one")
	expect_true(source.is_running(), "and it started")
	main.free()


func test_the_chips_and_their_lines_do_not_overlap_at_either_window_size() -> void:
	for size in SIZES:
		var main := _main()
		tree.root.size = size
		var profile: Node = main.profile
		ThroughLevelZero.apply(profile)
		profile.bank_run(_win("outpost", "normal", 0.6))
		profile.bank_run(_win("outpost", "hard", 0.6))
		main.call("_show", main.Screen.MAP)
		await tree.process_frame
		await tree.process_frame
		var journey: Control = main.journey
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var rects := []
		for tier in journey.TIER_ORDER:
			var chip: Dictionary = journey._chips[tier]
			expect_true(chip["box"].visible, "%dx%d: %s is shown" % [size.x, size.y, tier])
			var box: Rect2 = chip["box"].get_global_rect()
			expect_true(screen.encloses(box), "%dx%d: %s is on screen" % [size.x, size.y, tier])
			expect_true(box.encloses(chip["button"].get_global_rect()) and box.encloses(chip["line"].get_global_rect()), "%dx%d: %s's button and line stay inside its chip" % [size.x, size.y, tier])
			expect_false(chip["button"].get_global_rect().intersects(chip["line"].get_global_rect()), "%dx%d: %s's word and line are apart" % [size.x, size.y, tier])
			var text_width: float = chip["line"].get_theme_font("font").get_string_size(chip["line"].text, HORIZONTAL_ALIGNMENT_LEFT, -1, chip["line"].get_theme_font_size("font_size")).x
			expect_true(text_width <= box.size.x, "%dx%d: %s's line fits its chip" % [size.x, size.y, tier])
			rects.append(box)
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				expect_false(rects[i].intersects(rects[j]), "%dx%d: chips %d and %d do not overlap" % [size.x, size.y, i, j])
			expect_false(rects[i].intersects(journey._map.get_global_rect()), "%dx%d: chip %d is clear of the map" % [size.x, size.y, i])
		main.free()


# ------------------------------------------------------------------ the no-input guard

func test_a_run_with_no_input_cannot_win_easy_at_the_outpost_and_wins_at_most_two_in_twenty_elsewhere() -> void:
	for pillar in PILLARS:
		for level in LEVELS:
			var wins := 0
			for run_seed in range(1, 21):
				var config := HoldfastContent.run_config(level, [], {}, pillar, null, {}, [], false, false, "", {}, "easy")
				var result: Dictionary = SimBotRunner.run(HoldfastRules.new(), SimController.new(), run_seed, config, 200000, HoldfastRules.TICK_RATE)["result"]
				wins += 1 if result["outcome"] == HoldfastRules.OUTCOME_WON else 0
			expect_true(wins <= (0 if level == "outpost" else 2), "%s %s: %d of 20 seeds won on Easy with no input" % [level, pillar, wins])


# ------------------------------------------------------------------ the bands

func test_the_bands_name_what_easy_and_extreme_are_judged_on() -> void:
	var bands := HoldfastBands.load_bands()
	for level in bands["easy"]["mild_levels"]:
		expect_true(level in HoldfastBands.levels(), "%s is a level" % level)
	expect_eq(bands["easy"]["mild_levels"], ["outpost", "shingle_beach"], "Easy is mild at the first two levels, where a hands-off Hero must still lose")
	expect_true(str(bands["extreme"]["level"]) in HoldfastBands.levels(), "Extreme names the level it is judged on")
	expect_eq(HoldfastBands.scope_problems(bands), PackedStringArray(), "the file is sound")


func test_easy_is_judged_by_the_poor_bot_and_extreme_on_one_level() -> void:
	var bands := HoldfastBands.load_bands()
	var cells := {}
	for pillar in PILLARS:
		for cell in ["average", "poor", "volley", "sniper", "no_special"]:
			cells["%s/%s" % [pillar, cell]] = []
	# Ten poor players: Normal won 4 at Tidewrack Cove, Easy 7; at Outpost both won 8 and Easy left more of the Keep.
	var poor := []
	for i in 10:
		poor.append({
			"tidewrack_cove": i < 4, "easy:tidewrack_cove": i < 7, "easy_keep:tidewrack_cove": 0.5,
			"outpost": i < 8, "easy:outpost": i < 8, "easy_keep:outpost": 0.7,
			HoldfastBands.FEEL: {"outpost": {"keep": 0.5, "seconds": 100.0}, "tidewrack_cove": {"keep": 0.5, "seconds": 100.0}},
		})
	cells["flare_archer/poor"] = poor
	cells["dusk_mage/poor"] = [{"gull_rock": false, "easy:gull_rock": true, "easy_keep:gull_rock": 0.5, HoldfastBands.FEEL: {"gull_rock": {"keep": 0.1, "seconds": 100.0}}}]
	cells["flare_archer/tree"] = [{"hours": 1.0, "filled": true, "dry": 0, "dry_median": 0.0, "extreme": {"gull_rock": [4, 10], "outpost": [3, 3]}, "extreme_poor": {"gull_rock": [2, 10]}}]
	var judged := HoldfastBands.evaluate(HoldfastBands.figures(bands, cells), {})
	expect_true(absf(float(judged["flare_archer/easy_gain/tidewrack_cove"]["value"]) - 0.3) < 0.0001, "Easy's gain is the poor bot's win rate on Easy less on Normal")
	expect_eq(judged["flare_archer/easy_gain/tidewrack_cove"]["state"], "met", "30 points is above the 15 asked at level 3")
	expect_eq(judged["flare_archer/easy_gain/outpost"]["state"], "met", "level 1 only has to be as forgiving")
	expect_true(absf(float(judged["flare_archer/easy_keep/outpost"]["value"]) - 0.2) < 0.0001, "and shows its gain in the Keep's health left")
	expect_eq(judged["flare_archer/easy_keep/outpost"]["state"], "met")
	expect_false(judged.has("flare_archer/easy_keep/tidewrack_cove"), "the Keep's health is judged only where Easy is mild")
	expect_true(judged.has("dusk_mage/easy_gain/gull_rock") and not judged.has("dusk_mage/easy_gain/outpost"), "a pillar is judged on its scope")
	expect_eq(judged["flare_archer/extreme/gull_rock"]["state"], "met", "40% is inside the 30 to 50 asked on Gull Rock")
	expect_eq(judged["flare_archer/extreme/outpost"]["state"], "met", "another level only has to be winnable")
	expect_eq(judged["flare_archer/extreme_poor/gull_rock"]["state"], "MISSED", "20% is over the poor bot's ceiling")
	expect_false(judged.has("dusk_mage/extreme/gull_rock"), "the other pillars are not judged on Extreme yet")
	cells["flare_archer/tree"][0]["extreme"]["outpost"] = [0, 3]
	expect_eq(HoldfastBands.evaluate(HoldfastBands.figures(bands, cells), {})["flare_archer/extreme/outpost"]["state"], "MISSED", "a level no player can win is a failure")
