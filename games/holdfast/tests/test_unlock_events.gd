extends KitTestCase
## HF-M2-76: after a run the profile can list what it unlocked (a blessing, a Recruit rescue, a gear piece, a Hero
## path, the gold a spare drop was salvaged for), read from the pack with no name in code, for the result screen and
## Plan. Nothing about it is saved, and Plan offers only the blessings earned, in the pack's own words.

const Main := preload("res://scenes/main.tscn")
const GEAR := "tarred_bowstring"


func _content() -> Dictionary:
	return HoldfastContent.base()


func _won(level: String, extra := {}) -> Dictionary:
	var result := {"outcome": HoldfastRules.OUTCOME_WON, "level": level, "gold": 0, "keep_left": 0.6, "towers_lost": 1}
	result.merge(extra, true)
	return result


## The profile either side of banking `result`, and what the bank unlocked.
func _bank(profile: Dictionary, result: Dictionary, content := {}) -> Dictionary:
	var pack: Dictionary = content if not content.is_empty() else _content()
	var after := HoldfastMeta.bank_run(pack, profile, result)
	return {"after": after, "unlocks": HoldfastMeta.unlocks(pack, profile, after, result)}


func _kinds(unlocks: Array) -> Array:
	return unlocks.map(func(each: Dictionary) -> String: return each["kind"])


func _fresh() -> Dictionary:
	return HoldfastMeta.new_profile(_content())


# ------------------------------------------------------------------ one test per kind

func test_a_win_that_earns_a_blessing_lists_it_with_the_packs_name_and_line() -> void:
	var content := _content()
	var banked := _bank(_fresh(), _won("first_watch"))
	expect_eq(banked["unlocks"].size(), 1, "the tutorial earns one blessing")
	var got: Dictionary = banked["unlocks"][0]
	expect_eq(got["kind"], "blessing")
	expect_eq(got["id"], "steady_flame")
	expect_eq(got["name"], content["blessings"]["steady_flame"]["name"], "the pack's name")
	expect_eq(got["text"], content["blessings"]["steady_flame"]["text"], "and the pack's line")


func test_a_blessing_earned_by_stars_is_listed_when_the_stars_pass_its_count() -> void:
	var content := _content()
	var profile := _fresh()
	profile["levels_won"] = ["first_watch", "outpost", "shingle_beach", "tidewrack_cove"]
	profile["stars"] = {"outpost": 3, "shingle_beach": 3, "tidewrack_cove": 1}
	var banked := _bank(profile, _won("old_pier", {"keep_left": 0.9}))
	var ids: Array = banked["unlocks"].filter(func(each: Dictionary) -> bool: return each["kind"] == "blessing").map(func(each: Dictionary) -> String: return each["id"])
	expect_true("tides_gift" in ids, "8 stars earned: %s" % str(ids))
	expect_false("steady_flame" in ids, "one already held is not listed again")


func test_winning_a_level_again_unlocks_nothing_new() -> void:
	var first := _bank(_fresh(), _won("first_watch"))
	var again := _bank(first["after"], _won("first_watch"))
	expect_eq(again["unlocks"], [], "a blessing is listed once")


func test_a_win_that_frees_a_recruit_lists_the_recruit_and_the_class() -> void:
	var content := _content()
	var rescue: Dictionary = content["recruit_rescues"].values()[0]
	var profile := _fresh()
	profile["levels_won"] = ["first_watch"]
	var banked := _bank(profile, _won(str(rescue["level"])))
	var found: Array = banked["unlocks"].filter(func(each: Dictionary) -> bool: return each["kind"] == "recruit")
	expect_eq(found.size(), 1, "one rescue")
	expect_eq(found[0]["id"], rescue["id"])
	expect_eq(found[0]["name"], rescue["name"], "the pack's name")
	expect_eq(found[0]["text"], content["recruit_classes"][rescue["class"]]["name"], "and the class's name")
	expect_eq(_kinds(_bank(banked["after"], _won(str(rescue["level"])))["unlocks"]).count("recruit"), 0, "not again")


func test_a_gear_piece_new_to_the_bag_is_listed_and_one_already_owned_is_not() -> void:
	var content := _content()
	var banked := _bank(_fresh(), _won("outpost", {"gear_found": [GEAR]}))
	var got: Array = banked["unlocks"].filter(func(each: Dictionary) -> bool: return each["kind"] == "gear")
	expect_eq(got.size(), 1)
	expect_eq(got[0]["id"], GEAR)
	expect_eq(got[0]["name"], content["gear_items"][GEAR]["name"], "the pack's name")
	var again := _bank(banked["after"], _won("outpost", {"gear_found": [GEAR]}))
	expect_eq(_kinds(again["unlocks"]).count("gear"), 0, "a spare is not an unlock")


func test_a_win_that_opens_a_hero_path_lists_it_by_its_pack_name() -> void:
	var content := _content()
	var level := "gull_rock"
	var opened: Array = HoldfastMeta.paths_opened_by(content, level)
	expect_true(opened.size() >= 1, "the pack opens a path at the Gull Rock boss")
	var profile := _fresh()
	profile["levels_won"] = ["first_watch"]
	var banked := _bank(profile, _won(level))
	var got: Array = banked["unlocks"].filter(func(each: Dictionary) -> bool: return each["kind"] == "hero_path")
	expect_eq(got.map(func(each: Dictionary) -> String: return each["id"]), opened)
	expect_eq(got[0]["name"], content["hero_paths"][opened[0]]["name"], "the pack's name")
	expect_eq(_kinds(_bank(banked["after"], _won(level))["unlocks"]).count("hero_path"), 0, "once")


func test_the_gold_a_spare_drop_was_salvaged_for_is_listed_with_its_amount() -> void:
	var banked := _bank(_fresh(), _won("gull_rock", {"salvaged": 300}))
	var got: Array = banked["unlocks"].filter(func(each: Dictionary) -> bool: return each["kind"] == "salvage")
	expect_eq(got.size(), 1)
	expect_eq(got[0]["amount"], 300)
	expect_eq(_kinds(_bank(_fresh(), _won("gull_rock"))["unlocks"]).count("salvage"), 0, "no salvage, no line")


# ------------------------------------------------------------------ read from the pack, not the code

func test_what_is_listed_follows_the_pack_when_the_pack_is_edited() -> void:
	var content: Dictionary = _content().duplicate(true)
	content["blessings"]["steady_flame"]["name"] = "Edited Flame"
	content["blessings"]["steady_flame"]["text"] = "Edited line."
	content["hero_paths"]["dusk_mage"]["name"] = "Edited Mage"
	content["gear_items"][GEAR]["name"] = "Edited Bow"
	var banked := _bank(HoldfastMeta.new_profile(content), _won("first_watch", {"gear_found": [GEAR]}), content)
	var by_kind := {}
	for each in banked["unlocks"]:
		by_kind[each["kind"]] = each
	expect_eq(by_kind["blessing"]["name"], "Edited Flame")
	expect_eq(by_kind["blessing"]["text"], "Edited line.")
	expect_eq(by_kind["gear"]["name"], "Edited Bow")
	var gull := _bank(HoldfastMeta.new_profile(content), _won("gull_rock"), content)
	var path: Array = gull["unlocks"].filter(func(each: Dictionary) -> bool: return each["kind"] == "hero_path")
	expect_eq(path[0]["name"], "Edited Mage")


func test_the_profile_lists_the_last_banked_runs_unlocks_and_saves_nothing_new() -> void:
	var profile := HoldfastProfile.new()
	tree.root.add_child(profile)
	var keys_before := profile.data.keys()
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run(_won("shingle_beach", {"gear_found": [GEAR], "salvaged": 62}))
	var kinds := _kinds(profile.get_last_unlocks())
	expect_true("recruit" in kinds and "gear" in kinds and "salvage" in kinds, "what the run unlocked: %s" % str(kinds))
	expect_eq(profile.data.keys().size(), keys_before.size(), "no saved field was added")
	for key in profile.data:
		expect_true(key in keys_before, "%s was there before" % key)
	var round_trip: Dictionary = HoldfastMeta.from_save(_content(), JSON.parse_string(JSON.stringify(profile.data)))
	expect_eq(round_trip.keys().size(), profile.data.keys().size(), "a real JSON save keeps the same fields")
	expect_false(JSON.stringify(profile.data).contains("unlock_events"), "and holds no event list")
	profile.bank_run(_won("shingle_beach"))
	expect_eq(profile.get_last_unlocks(), [], "the next run starts the list again")
	profile.free()


# ------------------------------------------------------------------ Plan offers only what is earned

func _plan_after(won: Array) -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	var profile: HoldfastProfile = main.get_node("Profile")
	var data := HoldfastMeta.new_profile(_content())
	data["levels_won"] = won
	data["unlocked"] = ["outpost"]
	for id in ["castle_slot_1", "castle_archer_1"]:
		data["upgrades"].append(id)
	data["layouts"] = {"outpost": ["spot_1"]}
	profile.data = data
	profile.changed.emit()
	main.journey.level_requested.emit("outpost")
	return main


func test_a_new_save_after_the_tutorial_is_offered_none_and_the_steady_flame_only() -> void:
	var content := _content()
	var main := _plan_after(["first_watch"])
	var plan: Control = main.planning
	expect_eq(plan._blessing_buttons.keys(), ["steady_flame", ""], "the Steady Flame, then None")
	expect_eq(plan._blessing_buttons["steady_flame"].text, content["blessings"]["steady_flame"]["name"], "in the pack's name")
	plan._blessing_buttons["steady_flame"].pressed.emit()
	expect_eq(plan._blessing_text.text, content["blessings"]["steady_flame"]["text"], "and its own line")
	for id in content["blessings"]:
		if id != "steady_flame":
			expect_false(plan._blessing_buttons.has(id), "%s is not earned yet" % id)
	main.free()


func test_a_save_with_nothing_earned_is_offered_no_choice() -> void:
	var main := _plan_after([])
	expect_eq(main.planning._blessing_buttons.keys(), [], "nothing to pick")
	expect_false(main.planning.get_node("%Blessings").visible)
	main.free()
