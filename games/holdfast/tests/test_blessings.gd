extends KitTestCase
## HF-M2-04: six blessings from the pack, each earned by playing, one of three offered at the start
## of every level but the tutorial. Each blessing changes the run in the way its pack entry says
## and nothing else; bots play without one. Numbers are the Advisor's placeholders, from the pack.

const Main := preload("res://scenes/main.tscn")
const IDS := ["steady_flame", "lamp_oil", "long_sight", "second_wind", "tides_gift", "thick_fog"]


func _content() -> Dictionary:
	return HoldfastContent.base()


## Rules on the Flare Archer's Outpost with `blessing` and no wave for 1000 s (0 s: the first wave at once).
func _world(blessing := "", first_wave := 1000.0, level := "outpost") -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"][level]["first_wave_delay"] = first_wave
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config(level, [], content, "flare_archer", null, {}, [], false, false, blessing), SimRng.new(1))
	return rules


func _profile(won: Array = [], stars: Dictionary = {}) -> Dictionary:
	var profile := HoldfastMeta.new_profile(_content())
	profile["levels_won"] = won
	profile["stars"] = stars
	return profile


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


# ------------------------------------------------------------------ the pack and the unlocks

func test_the_pack_has_the_six_blessings_each_with_a_name_a_line_and_a_way_to_earn_it() -> void:
	var blessings: Dictionary = _content()["blessings"]
	expect_eq(blessings.keys(), IDS, "six, in the Advisor's order")
	for id in IDS:
		expect_true(str(blessings[id]["name"]) != "" and str(blessings[id]["text"]) != "", id + " names itself and says what it does")
		if blessings[id]["unlock"]["kind"] == "won":
			expect_true(_content()["levels"].has(blessings[id]["unlock"]["level"]), id + " is earned on a level that exists")


func test_a_blessing_is_earned_by_a_win_or_by_stars() -> void:
	var content := _content()
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile()), [], "a new game has none")
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile(["first_watch"])), ["steady_flame"], "the tutorial")
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile(["first_watch", "outpost"])), ["steady_flame", "lamp_oil"], "level 1")
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile(["outpost", "shingle_beach"])), ["lamp_oil", "long_sight"], "level 2, without the tutorial")
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile(["tidewrack_cove"])), ["second_wind"], "level 3")
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile([], {"outpost": 2, "shingle_beach": 3, "tidewrack_cove": 2})), ["thick_fog"], "3 stars on one level, 7 in all")
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile([], {"outpost": 2, "shingle_beach": 2, "tidewrack_cove": 2, "old_pier": 2})), ["tides_gift"], "8 stars in all, none with 3 on a level")
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile([], {"outpost": 3, "shingle_beach": 3, "old_pier": 2})), ["tides_gift", "thick_fog"], "both star rules")
	expect_eq(HoldfastMeta.blessings_unlocked(content, _profile(["first_watch", "outpost", "shingle_beach", "tidewrack_cove"], {"outpost": 3, "shingle_beach": 3, "old_pier": 2})).size(), 6, "all six")


# ------------------------------------------------------------------ the offer

func test_nothing_is_offered_on_the_tutorial_or_before_a_blessing_is_earned() -> void:
	var content := _content()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	expect_eq(HoldfastMeta.blessing_offer(content, _profile(["first_watch", "outpost"]), "first_watch", rng), [], "level 0 offers none")
	expect_eq(HoldfastMeta.blessing_offer(content, _profile(), "outpost", rng), [], "nothing earned yet")


func test_with_fewer_than_three_earned_the_player_sees_those() -> void:
	var content := _content()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	expect_eq(HoldfastMeta.blessing_offer(content, _profile(["first_watch"]), "outpost", rng), ["steady_flame"], "one earned: one offered")
	expect_eq(HoldfastMeta.blessing_offer(content, _profile(["first_watch", "outpost"]), "shingle_beach", rng), ["steady_flame", "lamp_oil"], "two earned: both")
	expect_eq(HoldfastMeta.blessing_offer(content, _profile(["first_watch", "outpost", "shingle_beach"]), "tidewrack_cove", rng).size(), 3, "three earned: three")


func test_with_more_earned_three_are_drawn_at_random_from_those_earned() -> void:
	var content := _content()
	var profile := _profile(["first_watch", "outpost", "shingle_beach", "tidewrack_cove"], {"outpost": 3, "shingle_beach": 3, "old_pier": 2})
	var earned := HoldfastMeta.blessings_unlocked(content, profile)
	var seen := {}
	var rng := RandomNumberGenerator.new()
	for draw_seed in 40:
		rng.seed = draw_seed
		var offer := HoldfastMeta.blessing_offer(content, profile, "old_pier", rng)
		expect_eq(offer.size(), 3, "three each time")
		expect_eq(offer.duplicate().filter(func(id: String) -> bool: return offer.count(id) == 1).size(), 3, "no blessing twice")
		for id in offer:
			expect_true(id in earned, id + " is earned")
			seen[id] = true
		seen[",".join(offer)] = true
	for id in earned:
		expect_true(seen.has(id), id + " comes up in some draw")
	expect_true(seen.size() > earned.size() + 3, "the three on offer vary from draw to draw")


# ------------------------------------------------------------------ the six, one by one

func test_steady_flame_shortens_the_heros_special_cooldown_by_a_fifth() -> void:
	var plain := _world()
	var blessed := _world("steady_flame")
	expect_eq(blessed.hero_ability["cooldown"], plain.hero_ability["cooldown"] * 0.8)
	expect_eq(blessed.hero_attack["cooldown"], plain.hero_attack["cooldown"], "only the special")


func test_lamp_oil_mends_towers_and_the_keep_between_waves_only() -> void:
	var rules := _world("lamp_oil")
	var tower: HoldfastRules.Attacker = rules.towers[0]
	var max_health := float(tower.health["max_health"])
	tower.health = UnitHealth.damage(tower.health, max_health * 0.5)
	rules.keep_health -= 50
	var keep_before := rules.keep_health
	var dt := 1.0 / HoldfastRules.TICK_RATE
	for tick in HoldfastRules.TICK_RATE * 2:
		rules.step(dt, {})
	expect_true(absf(float(tower.health["health"]) - max_health * 0.54) < max_health * 0.001, "a tower mends 2%% of its health a second: %s of %s" % [tower.health["health"], max_health])
	expect_true(absf(float(rules.keep_health - keep_before) - rules.keep_health_max * 0.04) <= 1.0, "so does the Keep: +%d of %d" % [rules.keep_health - keep_before, rules.keep_health_max])
	var plain := _world()
	var plain_tower: HoldfastRules.Attacker = plain.towers[0]
	plain_tower.health = UnitHealth.damage(plain_tower.health, max_health * 0.5)
	plain.keep_health -= 50
	for tick in HoldfastRules.TICK_RATE * 2:
		plain.step(dt, {})
	expect_eq(float(plain_tower.health["health"]), max_health * 0.5, "without it nothing mends")
	expect_eq(plain.keep_health, rules.keep_health_max - 50, "the Keep neither")


func test_lamp_oil_does_nothing_while_an_enemy_is_on_the_field() -> void:
	var rules := _world("lamp_oil", 0.0)
	var dt := 1.0 / HoldfastRules.TICK_RATE
	rules.step(dt, {})
	expect_false(rules.enemies.is_empty(), "set-up: a wave is out")
	var tower: HoldfastRules.Attacker = rules.towers[0]
	tower.health = UnitHealth.damage(tower.health, 10.0)
	var hurt := float(tower.health["health"])
	rules.keep_health -= 10
	var keep := rules.keep_health
	for tick in HoldfastRules.TICK_RATE:
		rules.step(dt, {})
	expect_false(rules.enemies.is_empty(), "set-up: the wave is still out")
	expect_eq(float(tower.health["health"]), hurt, "the tower waits for the field to clear")
	expect_true(rules.keep_health <= keep, "and so does the Keep")


func test_the_pick_is_not_reachable_on_level_0_or_before_the_first_tower() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data = _profile(["first_watch"], {"first_watch": 2})
	profile.data["unlocked"] = ["outpost"]
	profile.changed.emit()
	expect_true("outpost" in profile.get_unlocked_levels(), "set-up: the first level is open")
	main.journey.level_requested.emit("outpost")
	expect_false(main.planning.visible, "no Plan page, so no pick, while the castle has no post (the compulsory guide)")
	main.free()


func test_long_sight_lengthens_every_towers_range_by_a_seventh() -> void:
	var plain := _world()
	var blessed := _world("long_sight")
	expect_true(plain.towers.size() > 0, "set-up: the Outpost has a post")
	for i in plain.towers.size():
		expect_eq(blessed.towers[i].attack_range, plain.towers[i].attack_range * 1.15)
	expect_eq(blessed.towers[0].cooldown, plain.towers[0].cooldown, "only the range")


func test_second_wind_cuts_the_heros_wait_to_get_up_by_two_fifths() -> void:
	var plain := _world()
	var blessed := _world("second_wind")
	expect_eq(blessed.hero_delays.size(), plain.hero_delays.size())
	for i in plain.hero_delays.size():
		expect_true(absf(float(blessed.hero_delays[i]) - float(plain.hero_delays[i]) * 0.6) < 0.0001, "wait %d" % (i + 1))
	expect_eq(blessed.hero_state["max_health"], plain.hero_state["max_health"], "the Hero's health is not touched")


func test_tides_gift_pays_30_per_cent_more_gold_and_costs_the_keep_15_per_cent() -> void:
	var plain := _world()
	var blessed := _world("tides_gift")
	expect_eq(blessed.gold_multiplier, plain.gold_multiplier * 1.3)
	expect_eq(blessed.keep_health_max, roundi(plain.keep_health_max * 0.85))
	expect_eq(blessed.keep_health, blessed.keep_health_max, "the Keep starts full")


func test_thick_fog_speeds_monsters_by_15_per_cent_and_pays_25_per_cent_more_gold() -> void:
	var plain := _world("", 0.0)
	var blessed := _world("thick_fog", 0.0)
	plain.step(1.0 / HoldfastRules.TICK_RATE, {})
	blessed.step(1.0 / HoldfastRules.TICK_RATE, {})
	expect_true(not plain.enemies.is_empty() and not blessed.enemies.is_empty(), "set-up: both have a wave out")
	expect_eq(blessed.enemies[0].type, plain.enemies[0].type)
	expect_eq(blessed.enemies[0].speed, plain.enemies[0].speed * 1.15)
	expect_eq(blessed.gold_multiplier, plain.gold_multiplier * 1.25)
	expect_eq(blessed.keep_health_max, plain.keep_health_max, "the Keep is as it was")


# ------------------------------------------------------------------ what a blessing never does

func test_the_hero_is_never_weakened_by_any_blessing() -> void:
	var plain := _world()
	for id in IDS:
		var blessed := _world(id)
		expect_eq(blessed.hero_state["max_health"], plain.hero_state["max_health"], id + ": health")
		expect_eq(blessed.hero_speed, plain.hero_speed, id + ": speed")
		expect_eq(blessed.hero_attack, plain.hero_attack, id + ": attack")
		expect_true(float(blessed.hero_ability["cooldown"]) <= float(plain.hero_ability["cooldown"]), id + ": special cooldown")
		for i in plain.hero_delays.size():
			expect_true(float(blessed.hero_delays[i]) <= float(plain.hero_delays[i]), id + ": get-up wait")


func test_a_blessing_never_changes_the_stars_a_run_pays() -> void:
	var content := _content()
	var plain := _world()
	expect_false(plain.result().has("keep_left"), "a run with no blessing is judged on the Keep as it stands")
	var tides := _world("tides_gift")
	tides._hurt_keep(10)
	var expected := 1.0 - 10.0 / float(plain.keep_health_max)
	expect_eq(tides.result()["keep_left"], expected, "judged on the Keep without the blessing's 15 per cent")
	var oil := _world("lamp_oil")
	oil._hurt_keep(30)
	oil.step(1.0 / HoldfastRules.TICK_RATE, {})
	oil.step(1.0, {})
	expect_true(oil.keep_health > oil.keep_health_max - 30, "set-up: the Keep has mended")
	expect_eq(oil.result()["keep_left"], 1.0 - 30.0 / float(plain.keep_health_max), "mending does not lift the stars")
	var won := tides.result().duplicate()
	won["outcome"] = HoldfastRules.OUTCOME_WON
	var tiers: Array = HoldfastMeta.castle_rules(content)["star_tiers"]
	expect_eq(HoldfastMeta.stars_for_run(content, won), int(tiers[-1]["stars"]), "the same stars as an unblessed run that took the same blow")


func test_a_run_with_no_blessing_is_as_it_was_and_an_unknown_blessing_is_refused() -> void:
	expect_false(HoldfastContent.run_config().has("blessing"), "the default config names none")
	expect_false(HoldfastContent.run_config("outpost", [], {}, "flare_archer", null, {}, [], false, true).has("blessing"), "so does the game's own with a layout")
	var rules := _world("not_a_blessing")
	expect_true(rules.setup_error.contains("unknown blessing"), "an unknown one is refused: " + rules.setup_error)


func test_the_bots_that_hold_the_pacing_bands_play_without_a_blessing() -> void:
	var config := HoldfastContent.run_config("outpost", [], _content(), "flare_archer", null, {}, [], false, true)
	var a: Dictionary = SimBotRunner.run(HoldfastRules.new(), HoldfastSkilledBot.new(), 7, config, 3000, HoldfastRules.TICK_RATE)
	var b: Dictionary = SimBotRunner.run(HoldfastRules.new(), HoldfastSkilledBot.new(), 7, config, 3000, HoldfastRules.TICK_RATE)
	expect_eq(a["hash"], b["hash"], "set-up: a run repeats")
	var blessed := config.duplicate()
	blessed["blessing"] = "steady_flame"
	var c: Dictionary = SimBotRunner.run(HoldfastRules.new(), HoldfastSkilledBot.new(), 7, blessed, 3000, HoldfastRules.TICK_RATE)
	expect_true(a["hash"] != c["hash"], "a blessing changes the run, so leaving it out is what keeps the bands comparable")


# ------------------------------------------------------------------ the Plan page and the flow

func test_the_plan_page_offers_the_blessings_beside_no_blessing_and_starts_as_none() -> void:
	var main := _main()
	var plan: Control = main.planning
	plan.open("outpost", [], false, HoldfastMeta.ring_spots(_content()), 1, 0, 1)
	plan.set_blessings(["steady_flame", "lamp_oil"])
	expect_eq(plan._blessing_buttons.keys(), ["steady_flame", "lamp_oil", ""], "the two and No blessing last")
	expect_eq(plan._blessing_buttons[""].text, "No blessing")
	expect_eq(plan._blessing_buttons["lamp_oil"].text, "Lamp Oil")
	expect_eq(plan.blessing(), "", "nothing is picked until the player picks")
	expect_true(plan.get_node("%Blessings").visible, "the choice shows")
	plan._blessing_buttons["lamp_oil"].pressed.emit()
	expect_eq(plan.blessing(), "lamp_oil")
	expect_true(plan.get_node("%BlessingText").text.contains("2%"), "and says what it does")
	plan._blessing_buttons[""].pressed.emit()
	expect_eq(plan.blessing(), "")
	plan.set_blessings([])
	expect_false(plan.get_node("%Blessings").visible, "an empty offer hides the choice")
	expect_eq(plan.blessing(), "")
	main.free()


func test_the_flow_offers_what_is_earned_and_starts_the_run_with_the_pick() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var data := _profile(["first_watch", "outpost"], {"first_watch": 2, "outpost": 1})
	for id in ["castle_slot_1", "castle_archer_1"]:
		data["upgrades"].append(id)
	data["unlocked"] = ["shingle_beach"]
	data["layouts"] = {"shingle_beach": ["spot_1"]}
	profile.data = data
	profile.changed.emit()
	main.journey.level_requested.emit("shingle_beach")
	var plan: Control = main.planning
	expect_eq(plan._blessing_buttons.keys(), ["steady_flame", "lamp_oil", ""], "the two earned, drawn for this level")
	plan._blessing_buttons["steady_flame"].pressed.emit()
	plan.start_requested.emit(["spot_1"])
	var source: Node = main.get_node("RunSource")
	expect_eq(source.blessing, "steady_flame", "the run source is told")
	expect_eq(source.get_rules().hero_ability["cooldown"] < HoldfastContent.base()["hero_paths"]["flare_archer"]["ability"]["cooldown"], true, "and the run has it")
	main.free()


func test_the_tutorial_starts_with_no_blessing_and_no_choice() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data = _profile(["first_watch"], {"first_watch": 2})
	profile.changed.emit()
	var source: Node = main.get_node("RunSource")
	source.blessing = "steady_flame"
	main.journey.level_requested.emit("first_watch")
	expect_eq(source.blessing, "", "level 0 clears any earlier pick")
	expect_eq(HoldfastMeta.blessing_offer(_content(), profile.data, "first_watch", RandomNumberGenerator.new()), [], "and offers none")
	main.free()
