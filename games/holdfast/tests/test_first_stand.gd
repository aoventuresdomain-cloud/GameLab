extends KitTestCase
## HF-M2-44: the first minutes. The second guided buy goes straight into a short real fight on
## the post just bought (Level 0's Keep still cannot fall), the guide is two taps and nothing
## else, one line on what stars buy shows once, and a save that is past Level 0 never meets
## either again.

const Main := preload("res://scenes/main.tscn")
## What a player needs per tap of a button or a level (a generous guess, not a measure).
const TAP_SECONDS := 4.0
const TWO_MINUTES := 120.0


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _content() -> Dictionary:
	return HoldfastContent.base()


## A profile that has won Level 0 and made neither guided buy.
func _after_level_zero() -> Dictionary:
	var content := _content()
	return HoldfastMeta.bank_run(content, HoldfastMeta.new_profile(content), {"outcome": "won", "level": HoldfastMeta.tutorial_level(content), "gold": 0})


## Plays the running source to its end with the bot, a second at a time; the seconds it took.
func _play_out(source: HoldfastRunSource) -> float:
	source.use_bot = true
	var seconds := 0.0
	while source.is_running() and seconds < 600.0:
		source.step(1.0)
		seconds += 1.0
	return seconds


# ------------------------------------------------------------------ the rule

func test_the_stand_is_due_after_level_zero_and_both_guided_buys_and_only_once() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_false(HoldfastMeta.stand_due(content, profile), "a new game has no tower")
	profile = _after_level_zero()
	expect_false(HoldfastMeta.stand_due(content, profile), "Level 0 won, nothing bought")
	profile = HoldfastMeta.buy(content, profile, "castle_slot_1")["profile"]
	expect_false(HoldfastMeta.stand_due(content, profile), "a slot alone is not a post")
	profile = HoldfastMeta.buy(content, profile, "castle_archer_1")["profile"]
	expect_true(HoldfastMeta.stand_due(content, profile), "the second buy makes it due")
	var unwon := HoldfastMeta.new_profile(content)
	unwon["upgrades"] = ["castle_slot_1", "castle_archer_1"]
	expect_false(HoldfastMeta.stand_due(content, unwon), "a castle with a post but no Level 0 won is not it")
	var begun := HoldfastMeta.begin_stand(profile)
	expect_false(HoldfastMeta.stand_due(content, begun), "and once begun it is not due again")
	expect_true(HoldfastMeta.stand_due(content, profile), "the profile it was given is left alone")


func test_the_stand_layout_is_one_valid_ring_spot_for_the_one_post() -> void:
	var content := _content()
	var profile := _after_level_zero()
	for id in ["castle_slot_1", "castle_archer_1"]:
		profile = HoldfastMeta.buy(content, profile, id)["profile"]
	var layout := HoldfastMeta.stand_layout(content, profile)
	expect_eq(layout.size(), 1, "the post just bought")
	expect_true(HoldfastMeta.is_valid_layout(content, profile, layout), str(layout))


# ------------------------------------------------------------------ the fight

func test_the_stand_is_fought_on_the_castle_post_with_its_own_short_waves() -> void:
	var content := _content()
	var first := HoldfastMeta.tutorial_level(content)
	var layout := ["spot_3"]
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config(first, [], content, "flare_archer", layout, {}, [], true), SimRng.new(1))
	expect_true(rules.stand and rules.tutorial)
	var enemies := 0
	for wave in content["levels"][first]["stand"]["waves"]:
		for spawn in wave["spawns"]:
			enemies += int(spawn["count"])
	expect_eq(rules.total_waves, content["levels"][first]["stand"]["waves"].size())
	expect_eq(rules._schedule.size(), enemies, "the stand's enemies, not the level's")
	expect_eq(rules.towers.size(), 1)
	var spot: Dictionary = {}
	for each in HoldfastMeta.ring_spots(content):
		if each["id"] == "spot_3":
			spot = each
	expect_eq(rules.tower.position, Vector2(float(spot["x"]), float(spot["y"])), "on the castle's spot, not the level's placed post")
	expect_eq(rules.layout_ids, ["spot_3"])
	var plain := HoldfastRules.new()
	plain.setup(HoldfastContent.run_config(first, [], content, "flare_archer", layout), SimRng.new(1))
	expect_false(plain.stand, "without the flag Level 0 is the Level 0 it was")
	expect_eq(plain.tower.position, Vector2(-90, 30))
	expect_eq(plain.total_waves, content["levels"][first]["waves"].size())


func test_the_stand_cannot_be_lost_and_is_won_by_the_post_alone() -> void:
	var content := _content()
	var first := HoldfastMeta.tutorial_level(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config(first, [], content, "flare_archer", ["spot_1"], {}, [], true), SimRng.new(1))
	var guard := 0
	while not rules.is_finished() and guard < 6000:
		rules.step(1.0 / 30.0, {})
		guard += 1
	expect_eq(rules.outcome, HoldfastRules.OUTCOME_WON, "an idle Hero and one post still win it")
	expect_eq(rules.keep_health, rules.keep_health_max, "and the Keep is untouched")
	expect_true(rules.result()["gold"] > 0, "a real fight: kills pay gold")


func test_the_stand_data_names_real_enemies_and_says_its_line() -> void:
	var content := _content()
	var stand: Dictionary = content["levels"][HoldfastMeta.tutorial_level(content)]["stand"]
	expect_true(str(stand["intro"]) != "")
	for wave in stand["waves"]:
		for spawn in wave["spawns"]:
			expect_true(content["enemies"].has(spawn["enemy"]), str(spawn["enemy"]))


# ------------------------------------------------------------------ the flow

func test_the_second_guided_buy_on_the_map_starts_the_stand_at_once() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	profile.data = _after_level_zero()
	profile.changed.emit()
	main.journey.buy_requested.emit("castle_slot_1")
	expect_false(source.is_running(), "the slot alone starts nothing")
	main.journey.buy_requested.emit("castle_archer_1")
	expect_true(source.is_running(), "the post starts the fight")
	expect_eq(main.screen, main.Screen.RUN)
	expect_true(source.get_rules().stand)
	expect_eq(source.get_rules().level_id, "first_watch")
	expect_eq(source.get_rules().layout_ids.size(), 1, "with the post just bought")
	expect_eq(source.get_posts_note(), str(_content()["levels"]["first_watch"]["stand"]["intro"]), "and its own line before the first wave")
	expect_true(profile.data["stand_done"], "begun, so never again")
	main.free()


func test_the_second_guided_buy_from_the_tree_starts_it_too_and_closes_the_card() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	profile.data = _after_level_zero()
	profile.changed.emit()
	var page: Control = main.keep_screen
	main.call("_show", main.Screen.TREE)
	TreeCard.buy(page, "castle_slot_1")
	expect_false(source.is_running())
	TreeCard.buy(page, "castle_archer_1")
	expect_true(source.is_running() and source.get_rules().stand)
	expect_false(page._card.visible, "no card is left open behind the fight")
	main.free()


func test_the_finished_stand_banks_its_gold_only_and_offers_level_one() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	profile.data = _after_level_zero()
	profile.changed.emit()
	var before: Dictionary = profile.data.duplicate(true)
	main.journey.buy_requested.emit("castle_slot_1")
	main.journey.buy_requested.emit("castle_archer_1")
	_play_out(source)
	expect_false(source.is_running())
	expect_eq(source.get_rules().outcome, HoldfastRules.OUTCOME_WON)
	expect_true(main.summary.visible)
	expect_true(main.summary.get_node("%NextLevelButton").visible, "Level 1 is next")
	expect_eq(profile.data["levels_won"], before["levels_won"], "nothing is won twice")
	expect_eq(profile.data["stars"], before["stars"], "no stars are paid again")
	expect_eq(profile.data["unlocked"], before["unlocked"])
	expect_eq(profile.data["upgrades"].size(), 2)
	expect_eq(profile.get_gold(), int(before["gold"]) + int(source.get_rules().result()["gold"]), "only what the fight earned, no Level 0 reward again")
	expect_false(main.summary.get_node("%Reward").visible)
	main.summary.get_node("%NextLevelButton").pressed.emit()
	expect_eq(main.screen, main.Screen.PLAN, "and Level 1 plans as normal, the one post already placeable")
	main.free()


func test_the_stand_is_not_offered_again_after_a_refund_and_the_same_two_buys() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	profile.data = _after_level_zero()
	profile.data["gold"] = 500
	profile.changed.emit()
	main.journey.buy_requested.emit("castle_slot_1")
	main.journey.buy_requested.emit("castle_archer_1")
	_play_out(source)
	main.call("_show", main.Screen.MAP)
	profile.respec()
	expect_eq(profile.get_guided_step(), "castle_slot_1", "a refund brings the two buys back")
	main.journey.buy_requested.emit("castle_slot_1")
	main.journey.buy_requested.emit("castle_archer_1")
	expect_false(source.is_running(), "but not the fight")
	expect_eq(main.screen, main.Screen.MAP)
	main.free()


func test_a_normal_buy_never_starts_a_fight() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	profile.data = ThroughLevelZero.of(_content(), HoldfastMeta.new_profile(_content()))
	expect_true(HoldfastMeta.stand_due(_content(), profile.data), "the stand is still to come for this profile")
	profile.data["gold"] = 5000
	profile.changed.emit()
	for id in ["flare_focus", "castle_slot_2"]:
		main.keep_screen.buy_requested.emit(id)
	expect_false(source.is_running())
	main.free()


# ------------------------------------------------------------------ old saves

func test_a_save_from_before_this_never_meets_the_stand_or_the_line() -> void:
	var content := _content()
	var old := _after_level_zero()
	old.erase("stand_done")
	old.erase("stars_line_seen")
	var loaded := HoldfastMeta.from_save(content, old)
	expect_true(loaded["stand_done"] and loaded["stars_line_seen"], "a save without the two keys has been through them")
	for id in ["castle_slot_1", "castle_archer_1"]:
		loaded = HoldfastMeta.buy(content, loaded, id)["profile"]
	expect_false(HoldfastMeta.stand_due(content, loaded))
	var migrated := HoldfastMeta.from_save(content, HoldfastMeta.migrate_v4(old, content))
	expect_true(migrated["stand_done"] and migrated["stars_line_seen"], "so does one that is migrated first")
	expect_false(HoldfastMeta.from_save(content, {})["stand_done"], "no save at all is a new game")
	expect_false(HoldfastMeta.from_save(content, HoldfastMeta.new_profile(content))["stars_line_seen"], "and a saved new game still has them to come")


func test_an_old_save_walks_the_two_buys_on_the_map_without_a_fight() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var old := _after_level_zero()
	old.erase("stand_done")
	old.erase("stars_line_seen")
	profile.data = HoldfastMeta.from_save(_content(), old)
	profile.changed.emit()
	main.journey.buy_requested.emit("castle_slot_1")
	main.journey.buy_requested.emit("castle_archer_1")
	expect_false(main.get_node("RunSource").is_running())
	expect_eq(main.screen, main.Screen.HOME, "the screen is where it was")
	main.free()


# ------------------------------------------------------------------ the guide

func test_the_guide_is_two_taps_and_nothing_else_is_guided() -> void:
	var content := _content()
	expect_eq(HoldfastMeta.castle_rules(content)["guided"], ["castle_slot_1", "castle_archer_1"])
	var profile := _after_level_zero()
	profile["gold"] = 5000
	profile["stars"]["outpost"] = 3
	for id in ["castle_slot_1", "castle_archer_1"]:
		expect_eq(HoldfastMeta.guided_step(content, profile), id)
		profile = HoldfastMeta.buy(content, profile, id)["profile"]
	expect_eq(HoldfastMeta.guided_step(content, profile), "", "after the second the guide is over")
	for id in content["upgrade_nodes"]:
		expect_false(HoldfastMeta.why_not_buy(content, profile, id).begins_with("Buy "), "%s is not held back by the guide: %s" % [id, HoldfastMeta.why_not_buy(content, profile, id)])


func test_after_the_stand_every_screen_opens_freely() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data = _after_level_zero()
	profile.changed.emit()
	main.journey.buy_requested.emit("castle_slot_1")
	main.journey.buy_requested.emit("castle_archer_1")
	_play_out(main.get_node("RunSource"))
	main.call("_show", main.Screen.MAP)
	for screen in [main.Screen.TREE, main.Screen.HERO, main.Screen.PLAN, main.Screen.MAP]:
		main.call("_show", screen)
		expect_eq(main.screen, screen)
	main.journey.refresh()
	expect_false(main.journey.get_node("%Guide").visible, "no guide strip is left")
	expect_eq(profile.get_guided_step(), "")
	main.free()


# ------------------------------------------------------------------ the line on stars

func test_the_first_summary_that_pays_stars_says_what_they_buy_and_never_again() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	main.call("_new_game")
	expect_false(profile.has_seen_stars_line())
	main.call("_level_picked", "first_watch")
	_play_out(source)
	var note: Label = main.summary.get_node("%StarsNote")
	expect_true(note.visible)
	expect_eq(note.text, "Stars buy slots and towers. Gold buys upgrades.")
	expect_true(profile.has_seen_stars_line())
	# The stand pays no stars, and a replay of Level 0 pays none either: the line is not shown again.
	main.journey.buy_requested.emit("castle_slot_1")
	main.journey.buy_requested.emit("castle_archer_1")
	_play_out(source)
	expect_false(note.visible, "the stand's summary has no line")
	profile.data["stars"].erase("outpost")
	main.call("_level_picked", "first_watch")
	_play_out(source)
	expect_false(note.visible, "nor does a replay")
	main.free()


func test_the_stars_line_is_not_on_any_other_screen_before_it_is_due() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	main.call("_new_game")
	for screen in [main.home, main.journey, main.hero_page, main.keep_screen, main.planning]:
		for text in _texts(screen):
			expect_false(text.contains("Stars buy"), "%s: %s" % [screen.name, text])
	main.free()


func _texts(node: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for child in node.get_children():
		if child is Label or child is Button:
			out.append(child.text)
		out.append_array(_texts(child))
	return out


# ------------------------------------------------------------------ the clock

func test_a_timed_bot_walk_reaches_the_stand_within_about_two_minutes_of_start() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.rng_seed = 1
	# Five taps: Start (a new game), Level 0, the summary's map button, and the two guided buys.
	# The fight in the middle is the bot's, in game seconds.
	main.call("_new_game")
	main.call("_level_picked", "first_watch")
	var fight := _play_out(source)
	main.summary.get_node("%MapButton").pressed.emit()
	main.journey.buy_requested.emit("castle_slot_1")
	main.journey.buy_requested.emit("castle_archer_1")
	expect_true(source.is_running() and source.get_rules().stand, "the stand has begun")
	var clock := 5.0 * TAP_SECONDS + fight
	print("[first stand] reached the stand at about %.0f s (Level 0 took %.0f s of it)" % [clock, fight])
	expect_true(clock <= TWO_MINUTES, "reached at about %.0f s" % clock)
	main.free()
