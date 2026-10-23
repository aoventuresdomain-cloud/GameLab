extends KitTestCase
## Stars and the empty castle (HF-M2-32): a new game starts with no slots and no cards, Level 0
## is a stub the player cannot lose that pays 2 stars and a little gold once, every won level pays
## up to 3 stars (each star once), the map guides the first two buys, the Plan page shows only
## what is owned, and an old save is refunded in gold and given stars.

const Main := preload("res://scenes/main.tscn")
const DT := 1.0 / HoldfastRules.TICK_RATE
const SAVE_DIR := "user://stars_tests"


func _content() -> Dictionary:
	return HoldfastContent.base()


func _fresh() -> Dictionary:
	return HoldfastMeta.new_profile(_content())


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


func _won(level: String, kept: int, gold := 0) -> Dictionary:
	return {"outcome": "won", "level": level, "gold": gold, "keep_health": kept, "keep_health_max": 100}


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


# ------------------------------------------------------------------ the empty castle

func test_a_new_game_has_no_stars_slots_cards_or_spots_and_starts_on_level_zero() -> void:
	var content := _content()
	var profile := _fresh()
	expect_eq(profile["stars"], {})
	expect_eq(HoldfastMeta.stars_earned(profile), 0)
	expect_eq(HoldfastMeta.castle_slots(content, profile), 0)
	expect_eq(HoldfastMeta.castle_cards(content, profile), 0)
	expect_eq(HoldfastMeta.owned_spots(content, profile), [])
	expect_false(HoldfastMeta.has_a_tower(content, profile))
	expect_eq(profile["level"], "first_watch")
	expect_eq(HoldfastMeta.layout_for(content, profile, "outpost"), [], "no tower, no layout")


func test_the_castle_ring_has_eight_spots_evenly_round_the_keep_in_the_order_they_open() -> void:
	var spots: Array = HoldfastMeta.castle_rules(_content())["spots"]
	expect_eq(spots.size(), 8)
	var angles := []
	for spot in spots:
		var at := Vector2(float(spot["x"]), float(spot["y"]))
		expect_true(absf(at.length() - 100.0) < 1.0, "%s sits 100 from the keep" % spot["id"])
		angles.append(fposmod(rad_to_deg(at.angle()), 360.0))
	var sorted := angles.duplicate()
	sorted.sort()
	for i in sorted.size():
		var gap: float = fposmod(float(sorted[(i + 1) % sorted.size()]) - float(sorted[i]), 360.0)
		expect_true(absf(gap - 45.0) < 1.0, "spots are 45 degrees apart: %f" % gap)
	# The first two slots are opposite each other, the first four a quarter turn apart.
	expect_true(absf(absf(angle_difference(deg_to_rad(float(angles[0])), deg_to_rad(float(angles[1])))) - PI) < 0.02)


func test_slots_and_cards_come_from_the_nodes_bought_and_cards_never_outnumber_slots() -> void:
	var content := _content()
	var profile := _fresh()
	profile["stars"] = {"first_watch": 2}
	expect_eq(HoldfastMeta.buy(content, profile, "castle_archer_1")["reason"], "Needs First Slot first")
	profile = HoldfastMeta.buy(content, profile, "castle_slot_1")["profile"]
	expect_eq(HoldfastMeta.castle_slots(content, profile), 1)
	expect_eq(HoldfastMeta.castle_cards(content, profile), 0, "a slot alone holds no post")
	expect_false(HoldfastMeta.has_a_tower(content, profile))
	profile = HoldfastMeta.buy(content, profile, "castle_archer_1")["profile"]
	expect_eq(HoldfastMeta.castle_cards(content, profile), 1)
	expect_true(HoldfastMeta.has_a_tower(content, profile))
	expect_eq(HoldfastMeta.owned_spots(content, profile).map(func(spot: Dictionary) -> String: return spot["id"]), ["spot_1"])
	var wide := content.duplicate(true)
	wide["upgrade_nodes"]["castle_archer_1"]["grants"]["cards"] = 5
	expect_eq(HoldfastMeta.castle_cards(wide, profile), 1, "cards are held to the slots")


# ------------------------------------------------------------------ stars

func test_a_star_node_costs_stars_not_gold_and_is_refused_without_them() -> void:
	var content := _content()
	var profile := _fresh()
	profile["gold"] = 5000
	var refused := HoldfastMeta.buy(content, profile, "castle_slot_1")
	expect_false(refused["ok"])
	expect_eq(refused["reason"], "Not enough stars", "gold does not buy a star node")
	profile["stars"] = {"first_watch": 2}
	var bought := HoldfastMeta.buy(content, profile, "castle_slot_1")
	expect_true(bought["ok"])
	expect_eq(bought["profile"]["gold"], 5000, "no gold is spent")
	expect_eq(HoldfastMeta.stars_available(content, bought["profile"]), 1)
	expect_eq(HoldfastMeta.stars_earned(bought["profile"]), 2, "earned stars are not spent away")
	var second := HoldfastMeta.buy(content, bought["profile"], "castle_archer_1")
	expect_true(second["ok"])
	expect_eq(HoldfastMeta.stars_available(content, second["profile"]), 0)
	expect_eq(HoldfastMeta.cost_text(content["upgrade_nodes"]["castle_slot_1"]), "1 star")
	expect_eq(HoldfastMeta.cost_text(content["upgrade_nodes"]["keep_walls_1"]), "60 gold")


func test_respec_frees_the_stars_and_gives_gold_back_less_a_fee_for_each_node() -> void:
	var content := _content()
	var profile := ThroughLevelZero.of(content, _fresh())
	profile["gold"] = 100
	profile["upgrades"].append("keep_walls_1")
	profile["layouts"]["outpost"] = ["spot_1"]
	var after := HoldfastMeta.respec(content, profile)
	# 100 held + 60 back for the Keep wall, less its 20 gold fee and 50 gold for each of the two star nodes.
	expect_eq(after["gold"], 100 + 60 - 20 - 2 * 50)
	expect_eq(after["upgrades"], [])
	expect_eq(HoldfastMeta.stars_available(content, after), 2, "both stars are free again")
	expect_false(HoldfastMeta.has_a_tower(content, after))
	expect_eq(HoldfastMeta.layout_for(content, after, "outpost"), [], "and the saved layout no longer stands")
	expect_false(HoldfastMeta.has_saved_layout(content, after, "outpost"))


func test_winning_pays_one_star_two_above_half_the_keep_and_three_above_four_fifths() -> void:
	var content := _content()
	var cases := {100: 3, 81: 3, 80: 2, 51: 2, 50: 1, 1: 1}
	for kept in cases:
		expect_eq(HoldfastMeta.stars_for_run(content, _won("outpost", kept)), cases[kept], "%d of 100 kept" % kept)
	expect_eq(HoldfastMeta.stars_for_run(content, {"outcome": "lost", "level": "outpost", "keep_health": 0, "keep_health_max": 100}), 0, "a loss pays nothing")
	expect_eq(HoldfastMeta.stars_for_run(content, {"outcome": "won", "level": "outpost"}), 1, "a win with no health figures still pays its star")
	expect_eq(HoldfastMeta.stars_for_run(content, _won("no_such_level", 100)), 0)


func test_each_star_is_paid_once_and_a_replay_pays_only_what_is_new() -> void:
	var content := _content()
	var profile := _fresh()
	profile = HoldfastMeta.bank_run(content, profile, _won("outpost", 30))
	expect_eq(profile["stars"]["outpost"], 1)
	profile = HoldfastMeta.bank_run(content, profile, _won("outpost", 90))
	expect_eq(profile["stars"]["outpost"], 3)
	expect_eq(HoldfastMeta.stars_earned(profile), 3)
	profile = HoldfastMeta.bank_run(content, profile, _won("outpost", 30))
	expect_eq(profile["stars"]["outpost"], 3, "a worse replay takes nothing back")
	profile = HoldfastMeta.bank_run(content, profile, _won("outpost", 100))
	expect_eq(HoldfastMeta.stars_earned(profile), 3, "and the same stars again pay nothing")
	var lost := HoldfastMeta.bank_run(content, _fresh(), {"outcome": "lost", "level": "outpost", "keep_health": 0, "keep_health_max": 100, "gold": 4})
	expect_eq(lost["stars"], {})


func test_level_zero_pays_two_stars_and_its_gold_once_and_only_when_won() -> void:
	var content := _content()
	var level: Dictionary = content["levels"]["first_watch"]
	expect_eq(int(level["reward"]["stars"]), 2)
	expect_eq(int(level["reward"]["gold"]), 150)
	var profile := HoldfastMeta.bank_run(content, _fresh(), {"outcome": "won", "level": "first_watch", "gold": 7, "keep_health": 100, "keep_health_max": 100})
	expect_eq(profile["stars"], {"first_watch": 2}, "two stars however much Keep is left")
	expect_eq(profile["gold"], 157, "the run's gold and the reward")
	expect_eq(profile["unlocked"], ["outpost"])
	var again := HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "first_watch", "gold": 3, "keep_health": 5, "keep_health_max": 100})
	expect_eq(again["stars"], {"first_watch": 2})
	expect_eq(again["gold"], 160, "only the run's own gold the second time")
	var lost := HoldfastMeta.bank_run(content, _fresh(), {"outcome": "lost", "level": "first_watch", "gold": 7})
	expect_eq(lost["gold"], 7)
	expect_eq(lost["stars"], {})


# ------------------------------------------------------------------ Level 0 in a run

func _fast_content(level: String) -> Dictionary:
	var content: Dictionary = _content().duplicate(true)
	var data: Dictionary = content["levels"][level]
	data["keep_health"] = 1
	data["first_wave_delay"] = 0.5
	data["waves"] = [{"spawns": [{"enemy": "grunt", "count": 2, "interval": 0.5}]}]
	content["enemies"]["grunt"]["speed"] = 400.0
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	return content


func _play_out(level: String) -> HoldfastRules:
	var content := _fast_content(level)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config(level, [], content, "flare_archer"), SimRng.new(1))
	var guard := 0
	while not rules.is_finished() and guard < 4000:
		rules.step(DT, {})
		guard += 1
	return rules


func test_the_keep_cannot_fall_on_level_zero_but_does_on_any_other_level() -> void:
	var other := _play_out("outpost")
	expect_eq(other.outcome, HoldfastRules.OUTCOME_LOST, "with nothing able to stop them, two grunts take a one-point Keep")
	var tutorial := _play_out("first_watch")
	expect_eq(tutorial.outcome, HoldfastRules.OUTCOME_WON, "the same grunts, and the Keep stands")
	expect_eq(tutorial.keep_health, tutorial.keep_health_max)
	expect_true(tutorial.tutorial)
	expect_false(other.tutorial)


func test_level_zero_keeps_its_own_post_whatever_layout_is_passed() -> void:
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("first_watch", [], {}, "flare_archer", ["spot_1", "spot_2"]), SimRng.new(1))
	expect_eq(rules.towers.size(), 1)
	expect_eq(rules.tower.position, Vector2(-90, 30))
	expect_eq(rules.layout_ids, [])


func test_the_hero_bot_wins_level_zero_on_every_path_and_seed() -> void:
	for pillar in ["flare_archer", "dusk_mage", "tideblade"]:
		for run_seed in range(1, 6):
			var result: Dictionary = HoldfastSim.run_headless(run_seed, HoldfastContent.run_config("first_watch", [], {}, pillar))["result"]
			expect_eq(result["outcome"], HoldfastRules.OUTCOME_WON, "%s seed %d" % [pillar, run_seed])


# ------------------------------------------------------------------ castle layouts in a run

func test_a_castle_layout_builds_a_post_on_each_spot_it_names_on_any_level() -> void:
	var spots: Array = HoldfastMeta.castle_rules(_content())["spots"]
	for level in ["outpost", "shingle_beach", "tidewrack_cove", "gull_rock"]:
		var layout := ["spot_3", "spot_1", "spot_8"]
		var rules := HoldfastRules.new()
		rules.setup(HoldfastContent.run_config(level, [], {}, "flare_archer", layout), SimRng.new(1))
		expect_eq(rules.layout_ids, layout, level)
		expect_eq(rules.towers.size(), 3, level)
		for i in layout.size():
			var want: Dictionary = spots[int(layout[i].trim_prefix("spot_")) - 1]
			expect_eq(rules.towers[i].position, Vector2(float(want["x"]), float(want["y"])), "%s: %s" % [level, layout[i]])


func test_a_castle_layout_with_a_repeat_or_an_unknown_spot_is_refused() -> void:
	for bad in [["spot_1", "spot_1"], ["spot_1", "spot_9"]]:
		var rules := HoldfastRules.new()
		rules.report_errors = false
		rules.setup(HoldfastContent.run_config("outpost", [], {}, "flare_archer", bad), SimRng.new(1))
		expect_ne(rules.setup_error, "", "refused: %s" % [bad])


func test_all_eight_spots_can_hold_a_post() -> void:
	var all := []
	for i in range(1, 9):
		all.append("spot_%d" % i)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], {}, "flare_archer", all), SimRng.new(1))
	expect_eq(rules.towers.size(), 8)


# ------------------------------------------------------------------ old saves

func _v3_save() -> Dictionary:
	return {
		"gold": 40, "runs": 9,
		"upgrades": ["keep_walls_1", "post_drills", "keep_walls_1", "gone_node", "flare_boots"],
		"levels_won": ["outpost", "shingle_beach", "gone_level"],
		"unlocked": ["shingle_beach", "tidewrack_cove"],
		"level": "tidewrack_cove", "pillar": "tideblade",
		"layouts": {"shingle_beach": ["west_gate", "east_gate"]},
		"gear": {"owned": ["tarred_bowstring"], "equipped": {"weapon": "tarred_bowstring"}},
	}


func test_a_version_three_save_is_refunded_in_gold_and_given_stars_and_loses_its_layouts() -> void:
	var content := _content()
	var migrated := HoldfastMeta.migrate_v3(_v3_save(), content)
	expect_eq(migrated["upgrades"], [], "the castle is empty")
	expect_eq(migrated["gold"], 40 + 60 + 110 + 90, "every bought node once, at its price; unknown ones give nothing")
	expect_eq(migrated["stars"], {"outpost": 3, "shingle_beach": 3, "first_watch": 2}, "3 for each level won, and Level 0's 2")
	expect_eq(migrated["layouts"], {})
	expect_true("first_watch" in migrated["levels_won"], "Level 0 counts as done")
	expect_true("outpost" in migrated["unlocked"], "so the first real level is open")
	expect_eq(migrated["unlocked"].size(), 3)
	expect_eq(migrated["runs"], 9)
	expect_eq(migrated["pillar"], "tideblade")
	var loaded := HoldfastMeta.from_save(content, migrated)
	expect_eq(HoldfastMeta.stars_available(content, loaded), 2 + 3 + 3)
	expect_eq(loaded["level"], "tidewrack_cove")
	expect_eq(loaded["gear"]["owned"], ["tarred_bowstring"], "gear is kept")
	expect_false(HoldfastMeta.has_a_tower(content, loaded), "the guided buys are still to make")


func test_the_save_given_to_a_migration_is_left_alone_and_the_tutorial_is_not_paid_twice() -> void:
	var content := _content()
	var save := _v3_save()
	var copy := save.duplicate(true)
	HoldfastMeta.migrate_v3(save, content)
	expect_eq(save, copy)
	var done := _v3_save()
	done["levels_won"] = ["first_watch", "outpost"]
	var migrated := HoldfastMeta.migrate_v3(done, content)
	expect_eq(migrated["stars"], {"first_watch": 2, "outpost": 3})
	expect_eq(migrated["levels_won"].count("first_watch"), 1)


func test_a_damaged_save_loads_with_fresh_values_and_never_crashes() -> void:
	var content := _content()
	var junk := [null, 7, "text", [], {}, -5, 2.5, true]
	for value in junk:
		var save := {"gold": value, "runs": value, "upgrades": value, "stars": value, "levels_won": value, "unlocked": value, "layouts": value, "gear": value, "level": value, "pillar": value}
		var migrated := HoldfastMeta.migrate_v3(save, content)
		var profile := HoldfastMeta.from_save(content, migrated)
		expect_true(profile["gold"] is int and profile["gold"] >= 0, "gold from %s" % [value])
		expect_true(profile["stars"] is Dictionary and profile["upgrades"] is Array, "shape from %s" % [value])
		var direct := HoldfastMeta.from_save(content, save)
		expect_true(direct["levels_won"] is Array and direct["layouts"] is Dictionary and direct["gear"]["owned"] is Array, "direct from %s" % [value])
	var odd := HoldfastMeta.from_save(content, {"stars": {"outpost": "many", "shingle_beach": 9, "gone": 2, "tidewrack_cove": -3, "old_pier": 2.0}, "gear": {"owned": null, "equipped": null}})
	expect_eq(odd["stars"], {"shingle_beach": 3, "tidewrack_cove": 0, "old_pier": 2}, "a star count is a whole number from 0 to 3 for a real level")
	expect_eq(odd["gear"]["owned"], [])


func test_a_save_cannot_hold_star_nodes_it_has_no_stars_for() -> void:
	var content := _content()
	var cheat := HoldfastMeta.from_save(content, {"upgrades": ["castle_slot_1", "castle_archer_1", "keep_walls_1"]})
	expect_eq(cheat["upgrades"], ["keep_walls_1"], "no stars, no star nodes")
	var one := HoldfastMeta.from_save(content, {"stars": {"outpost": 1}, "upgrades": ["castle_slot_1", "castle_archer_1"]})
	expect_eq(one["upgrades"], ["castle_slot_1"], "one star pays for one of them")


func test_an_old_save_file_migrates_through_the_profile_and_then_loads_as_the_new_version() -> void:
	var path := _save_path("v3")
	SaveService.new(path, 3).save(_v3_save())
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	expect_eq(profile.load_status, "migrated")
	expect_eq(profile.get_gold(), 300)
	expect_eq(profile.get_stars(), 8)
	expect_eq(profile.get_level_stars("outpost"), 3)
	expect_false(profile.has_a_tower())
	expect_true(profile.is_level_won("first_watch"))
	profile.buy("castle_slot_1")
	profile.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.load_status, "ok", "saved as version %d" % HoldfastMeta.SAVE_VERSION)
	expect_eq(again.get_castle_slots(), 1)
	expect_eq(again.get_stars(), 7)
	again.free()


# ------------------------------------------------------------------ the map and the guided buys

func _won_payload(level: String, kept := 100) -> Dictionary:
	return {"gold_earned": 12, "waves_cleared": 2, "total_waves": 2, "keep_fell": false,
			"result": {"outcome": HoldfastRules.OUTCOME_WON, "level": level, "gold": 12, "keep_health": kept, "keep_health_max": 100}}


func test_the_map_starts_on_level_zero_with_no_guide_and_every_other_level_locked() -> void:
	var main := _main()
	var map: Control = main.journey
	expect_false(map.get_node("%Guide").visible, "nothing to buy before Level 0 is won")
	expect_eq(map.get_node("%StarsValue").text, "0")
	expect_eq(map._next, "first_watch")
	expect_false(map._buttons["first_watch"].disabled)
	expect_true(map._level_text("first_watch").contains(_content()["levels"]["first_watch"]["intro"]), "its teaching text is on the map")
	expect_true(map._buttons["outpost"].disabled)
	main.free()


func test_after_level_zero_the_map_guides_the_first_slot_then_the_first_post_before_any_level() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile: HoldfastProfile = main.get_node("Profile")
	main.call("_on_run_ended", _won_payload("first_watch", 100))
	main.call("_show", main.Screen.MAP)
	expect_eq(profile.get_stars(), 2)
	expect_eq(map.get_node("%StarsValue").text, "2")
	expect_true(map.get_node("%Guide").visible)
	expect_true(map.get_node("%GuideButton").text.contains("First Slot"), map.get_node("%GuideButton").text)
	expect_true(map.get_node("%GuideButton").text.contains("1 star"))
	expect_true(map._buttons["outpost"].disabled, "Level 1 waits for both buys")
	expect_true(map._names["first_watch"].text.ends_with("Won, 2 stars"), map._names["first_watch"].text)
	map.level_requested.emit("outpost")
	expect_true(main.journey.visible and not main.planning.visible and not main.get_node("RunSource").is_running(), "a locked tap does nothing")
	map.get_node("%GuideButton").pressed.emit()
	expect_eq(profile.get_castle_slots(), 1)
	expect_true(map.get_node("%Guide").visible)
	expect_true(map.get_node("%GuideButton").text.contains("Archer Post"), map.get_node("%GuideButton").text)
	expect_true(map._buttons["outpost"].disabled, "a slot is not enough")
	map.get_node("%GuideButton").pressed.emit()
	expect_eq(profile.get_castle_cards(), 1)
	expect_false(map.get_node("%Guide").visible, "both buys made")
	expect_false(map._buttons["outpost"].disabled)
	expect_eq(map._next, "outpost")
	expect_eq(map.get_node("%StarsValue").text, "0")
	main.free()


func test_the_guide_waits_for_a_star_it_cannot_afford_and_says_so() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data["levels_won"].append("first_watch")
	profile.changed.emit()
	expect_true(map.get_node("%Guide").visible)
	expect_true(map.get_node("%GuideButton").disabled)
	expect_true(map.get_node("%GuideLabel").text.contains("Not enough stars"), map.get_node("%GuideLabel").text)
	main.free()


func test_a_level_cannot_be_planned_or_started_without_a_tower_even_if_asked_directly() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data["levels_won"].append("first_watch")
	profile.data["unlocked"].append("outpost")
	profile.select_level("outpost")
	main.call("_plan_run")
	expect_false(source.is_running())
	expect_false(main.planning.visible)
	expect_true(main.journey.visible, "back on the map, where the guide waits")
	main.call("_planned", [])
	expect_false(source.is_running(), "an empty plan starts nothing")
	main.free()


func test_a_saved_layout_must_name_owned_spots_once_each_and_no_more_than_the_cards_held() -> void:
	var content := _content().duplicate(true)
	content["upgrade_nodes"]["castle_slot_1"]["grants"]["slots"] = 3
	var profile := _fresh()
	profile["stars"] = {"first_watch": 2}
	profile = HoldfastMeta.buy(content, profile, "castle_slot_1")["profile"]
	profile = HoldfastMeta.buy(content, profile, "castle_archer_1")["profile"]
	expect_eq(HoldfastMeta.castle_cards(content, profile), 1, "three slots, one card")
	var refused := {
		"more posts than cards": ["spot_1", "spot_2"],
		"a spot not owned": ["spot_4"],
		"a spot that does not exist": ["moat"],
		"no spots": [],
		"a repeat": ["spot_1", "spot_1"],
	}
	for why in refused:
		expect_false(HoldfastMeta.is_valid_layout(content, profile, refused[why]), "refused: " + why)
		expect_eq(HoldfastMeta.set_layout(content, profile, "outpost", refused[why]), profile, "nothing saved: " + why)
	expect_false(HoldfastMeta.is_valid_layout(content, profile, "spot_1"), "refused: not a list")
	expect_true(HoldfastMeta.is_valid_layout(content, profile, ["spot_2"]), "any one owned spot is fine")
	var wide := HoldfastMeta.set_layout(content, profile, "outpost", ["spot_3"])
	expect_eq(wide["layouts"]["outpost"], ["spot_3"])


func test_an_empty_plan_or_a_locked_level_starts_nothing_even_with_a_tower() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data["levels_won"].append("first_watch")
	profile.data["unlocked"].append("outpost")
	profile.data["stars"] = {"first_watch": 2}
	profile.buy("castle_slot_1")
	profile.buy("castle_archer_1")
	profile.select_level("outpost")
	main.call("_planned", [])
	expect_false(source.is_running(), "an empty plan starts nothing")
	expect_eq(profile.get_level(), "outpost")
	main.call("_level_picked", "shingle_beach")
	expect_false(source.is_running(), "a locked level is not planned")
	expect_false(main.planning.visible, "and no Plan page opens for it")
	expect_eq(profile.get_level(), "outpost", "and not selected")
	main.free()


func test_the_summary_shows_the_stars_a_win_paid_and_the_first_win_reward_once() -> void:
	var main := _main()
	main.call("_on_run_ended", _won_payload("first_watch", 100))
	expect_eq(main.summary.get_node("%StarsValue").text, "+2")
	expect_true(main.summary.get_node("%Reward").visible)
	expect_true(main.summary.get_node("%Reward").text.contains("150"), main.summary.get_node("%Reward").text)
	main.call("_on_run_ended", _won_payload("first_watch", 100))
	expect_eq(main.summary.get_node("%StarsValue").text, "+0", "stars are paid once")
	expect_false(main.summary.get_node("%Reward").visible)
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.call("_on_run_ended", _won_payload("outpost", 60))
	expect_eq(main.summary.get_node("%StarsValue").text, "+2")
	main.call("_on_run_ended", _won_payload("outpost", 95))
	expect_eq(main.summary.get_node("%StarsValue").text, "+1", "only the missing star")
	main.call("_on_run_ended", {"gold_earned": 1, "waves_cleared": 0, "total_waves": 5, "keep_fell": true, "result": {"outcome": HoldfastRules.OUTCOME_LOST, "level": "outpost", "gold": 1}})
	expect_eq(main.summary.get_node("%StarsValue").text, "+0")
	main.free()


# ------------------------------------------------------------------ the Plan page and the tree

func test_the_plan_page_shows_only_the_owned_slots_and_cards() -> void:
	var main := _main()
	var plan: Control = main.planning
	var spots: Array = HoldfastMeta.castle_rules(_content())["spots"]
	plan.open("outpost", [], false, spots.slice(0, 3), 2)
	expect_eq(plan._site_buttons.keys(), ["spot_1", "spot_2", "spot_3"], "three slots, not eight")
	expect_eq(plan._tray.get_child_count(), 2)
	expect_eq(plan.get_node("%Count").text, "Posts: 0 of 2")
	expect_eq(plan._site_buttons["spot_2"].text, "West", "slots are named by where they stand")
	plan.open("outpost", [], false, spots.slice(0, 1), 0)
	expect_eq(plan._tray.get_child_count(), 0)
	expect_true(plan.get_node("%StartButton").disabled)
	plan._site_buttons["spot_1"].pressed.emit()
	expect_eq(plan._chosen, [], "no card, nothing to place")
	expect_true(plan.get_node("%StartButton").disabled)
	main.free()


func test_the_tree_prices_star_nodes_in_stars_shows_the_stars_and_buys_with_them() -> void:
	var main := _main()
	var tree_page: Control = main.keep_screen
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_true(tree_page._section_columns.has("castle"))
	expect_eq(tree_page._tab_buttons.keys().back(), "Castle")
	expect_eq(tree_page._node_buttons["castle_slot_1"].text, "First Slot  1 star")
	expect_true(tree_page._node_buttons["castle_slot_1"].disabled)
	expect_true(tree_page._node_text("castle_slot_1").contains("Cost 1 star"))
	expect_true(tree_page._node_text("castle_slot_1").contains("+1 castle slot"), tree_page._node_text("castle_slot_1"))
	expect_true(tree_page._node_text("castle_slot_1").contains("Not enough stars"))
	expect_eq(tree_page.get_node("%StarsValue").text, "0")
	profile.data["stars"]["first_watch"] = 2
	profile.changed.emit()
	expect_eq(tree_page.get_node("%StarsValue").text, "2")
	tree_page._node_buttons["castle_slot_1"].pressed.emit()
	expect_eq(profile.get_castle_slots(), 1)
	expect_eq(tree_page._node_buttons["castle_slot_1"].text, "First Slot (bought)")
	expect_eq(tree_page.get_node("%StarsValue").text, "1")
	expect_false(tree_page.get_node("%NextUnlocks").text.contains("star"), "the Next line lists gold upgrades only")
	main.free()
