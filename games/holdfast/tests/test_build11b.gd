extends KitTestCase
## Build 11b: a save from before Recruits that already won the rescue levels gets its Recruits once
## on load; the Recruits page says "1 more Recruit is waiting"; Refund all names stars as stars.

const KeepScreen = preload("res://scripts/ui/keep_screen.gd")
const RecruitsPage = preload("res://scripts/ui/recruits_page.gd")


func _content() -> Dictionary:
	return HoldfastContent.base()


## A save as Build 10 left it: levels won, no Recruit state and no given names.
func _old_save(won: Array) -> Dictionary:
	var data := HoldfastMeta.new_profile(_content())
	data.erase("recruits")
	data.erase("names")
	data["levels_won"] = won
	return data


func _ids(profile: Dictionary, key: String) -> Array:
	var out := []
	for entry in profile["recruits"][key]:
		out.append(entry["id"] if entry is Dictionary else entry)
	return out


func test_an_old_save_that_won_level_two_and_four_gets_bryn_and_wren() -> void:
	var profile := HoldfastMeta.from_save(_content(), _old_save(["outpost", "shingle_beach", "tidewrack_cove", "old_pier"]))
	expect_eq(_ids(profile, "roster"), ["bryn", "wren"], "both are on the roster")
	expect_eq(_ids(profile, "squad"), ["bryn", "wren"], "and on the squad")
	expect_eq(profile["recruits"]["roster"][0]["class"], "warden", "Bryn is the Warden")
	expect_eq(profile["recruits"]["roster"][1]["class"], "lookout", "Wren is the Lookout")


func test_an_old_save_gets_only_the_rescues_it_has_earned() -> void:
	var one := HoldfastMeta.from_save(_content(), _old_save(["outpost", "shingle_beach"]))
	expect_eq(_ids(one, "roster"), ["bryn"], "level 2 won: Bryn only")
	var none := HoldfastMeta.from_save(_content(), _old_save(["outpost"]))
	expect_eq(_ids(none, "roster"), [], "level 1 won: nobody")
	var only_four := HoldfastMeta.from_save(_content(), _old_save(["old_pier"]))
	expect_eq(_ids(only_four, "roster"), ["wren"], "level 4 won on its own: Wren")


func test_the_rescues_are_granted_once_and_not_again_after_a_save() -> void:
	var content := _content()
	var first := HoldfastMeta.from_save(content, _old_save(["shingle_beach", "old_pier"]))
	var saved := first.duplicate(true)
	saved["recruits"]["roster"] = []
	saved["recruits"]["squad"] = []
	var again := HoldfastMeta.from_save(content, saved)
	expect_eq(_ids(again, "roster"), [], "a save that has Recruit state is left as it is")
	var kept := HoldfastMeta.from_save(content, first)
	expect_eq(_ids(kept, "roster"), ["bryn", "wren"], "and the Recruits it has stay, with no copies")


func test_a_rescue_on_load_with_no_place_on_the_squad_joins_the_roster_only() -> void:
	var content: Dictionary = _content().duplicate(true)
	content["recruit_rescues"]["third"] = {"id": "cal", "name": "Cal", "class": "warden", "level": "tidewrack_cove"}
	var profile := HoldfastMeta.from_save(content, _old_save(["shingle_beach", "tidewrack_cove", "old_pier"]))
	expect_eq(_ids(profile, "roster").size(), 3, "all three join")
	expect_eq(_ids(profile, "squad").size(), 2, "two places only")


func test_more_picks_waiting_reads_in_the_singular_and_the_plural() -> void:
	expect_eq(RecruitsPage.more_picks_text(1), "1 more Recruit is waiting for a pick.")
	expect_eq(RecruitsPage.more_picks_text(3), "3 more Recruits are waiting for a pick.")


func test_refund_all_says_stars_as_stars_and_a_fee_as_a_fee() -> void:
	expect_eq(KeepScreen.refund_all_text(0, 120), "Refund all: +120 gold", "gold nodes only")
	expect_eq(KeepScreen.refund_all_text(0, -10), "Refund all: -10 gold", "a gold loss with no stars")
	expect_eq(KeepScreen.refund_all_text(2, -10), "Refund all: +2 stars, fee 10 gold", "stars only: the stars first, the fee named")
	expect_eq(KeepScreen.refund_all_text(1, -10), "Refund all: +1 star, fee 10 gold", "one star")
	expect_eq(KeepScreen.refund_all_text(3, 90), "Refund all: +90 gold, +3 stars", "gold and stars")


func test_respec_stars_counts_the_star_nodes_owned() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1", "squad_hand_3"]
	expect_eq(HoldfastMeta.respec_stars(content, profile), 2, "two stars for Third Hand; the castle nodes stay")
	profile["upgrades"] = []
	expect_eq(HoldfastMeta.respec_stars(content, profile), 0, "nothing bought, nothing back")


## A save an older build wrote again: the new profile's Recruit state, untouched, with levels won.
func _default_state_save(won: Array) -> Dictionary:
	var data := HoldfastMeta.new_profile(_content())
	data["levels_won"] = won
	return data


func test_a_save_with_the_untouched_default_recruit_state_gets_the_rescues_once() -> void:
	var content := _content()
	var won := ["outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]
	var profile := HoldfastMeta.from_save(content, _default_state_save(won))
	expect_eq(_ids(profile, "roster"), ["bryn", "wren"], "both come, as the levels were won")
	expect_eq(_ids(profile, "squad"), ["bryn", "wren"], "and join the squad")
	var again := HoldfastMeta.from_save(content, profile)
	expect_eq(_ids(again, "roster"), ["bryn", "wren"], "loading the saved result again adds nobody")


func test_a_recruit_state_with_any_change_in_it_is_never_topped_up() -> void:
	var content := _content()
	var won := ["shingle_beach", "old_pier"]
	var changes := {
		"a hire": func(data: Dictionary) -> void: data["recruits"]["hired"] = [0],
		"a purchase": func(data: Dictionary) -> void: data["recruits"]["bought"] = 1,
		"the next number": func(data: Dictionary) -> void: data["recruits"]["next"] = 2,
		"a squad": func(data: Dictionary) -> void: data["recruits"]["squad"] = ["bryn"],
		"a rescue": func(data: Dictionary) -> void: data["recruits"]["roster"] = [RecruitRoster.new_recruit("bryn", "Bryn", "warden")],
		"a renamed keep": func(data: Dictionary) -> void: data["names"]["keep"] = "Lantern",
		"a renamed hero": func(data: Dictionary) -> void: data["names"]["hero"] = "Ash",
	}
	for label in changes:
		var data := _default_state_save(won)
		changes[label].call(data)
		var profile := HoldfastMeta.from_save(content, data)
		expect_eq(_ids(profile, "roster").size(), 1 if label == "a rescue" else 0, "%s: no top-up" % label)
		expect_false(profile["recruits"].has("welcome"), "%s: nobody to welcome" % label)


## A save as the real flow leaves it: levels won through HoldfastMeta.bank_run (so the round count and the
## profile are what a banked run writes), with the Recruits a build that did not rescue yet never gave.
func _banked_save(levels: Array) -> Dictionary:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	for level in levels:
		profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": level, "gold": 10})
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_LOST, "level": levels[-1], "gold": 0})
	profile["recruits"]["roster"] = []
	profile["recruits"]["squad"] = []
	return profile


## What a save file gives back: the same data through JSON, so every number is a float.
func _through_json(data: Dictionary) -> Dictionary:
	var back: Variant = JSON.parse_string(JSON.stringify(data))
	expect_true(back is Dictionary, "the save reads back")
	return back if back is Dictionary else {}


func test_a_save_with_banked_runs_but_no_hiring_still_gets_the_rescues() -> void:
	var content := _content()
	var data := _through_json(_banked_save(["outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]))
	expect_true(int(data["recruits"]["round"]) > 0, "the real flow moved the round on")
	expect_true(data["recruits"]["bought"] is float, "the numbers came back as floats, as a real save has them")
	var profile := HoldfastMeta.from_save(content, data)
	expect_eq(_ids(profile, "roster"), ["bryn", "wren"], "banked runs alone do not count as a change")
	expect_eq(int(profile["recruits"]["round"]), int(data["recruits"]["round"]), "the round count is kept")


func test_a_banked_save_with_a_hire_or_a_rename_is_not_topped_up() -> void:
	var content := _content()
	var hired := _banked_save(["outpost", "shingle_beach"])
	hired["recruits"]["bought"] = 1
	hired["recruits"]["next"] = 2
	expect_eq(_ids(HoldfastMeta.from_save(content, _through_json(hired)), "roster"), [], "bought and next moved: no top-up")
	var renamed := _banked_save(["outpost", "shingle_beach"])
	renamed["names"]["keep"] = "Lantern"
	expect_eq(_ids(HoldfastMeta.from_save(content, _through_json(renamed)), "roster"), [], "a renamed keep: no top-up")
	var squad := _banked_save(["outpost", "shingle_beach"])
	squad["recruits"]["squad"] = ["bryn"]
	expect_eq(_ids(HoldfastMeta.from_save(content, _through_json(squad)), "roster"), [], "a squad pick: no top-up")


func test_a_default_save_read_back_from_json_gets_the_rescues_at_round_zero_and_after() -> void:
	var content := _content()
	var fresh := _through_json(_default_state_save(["outpost", "shingle_beach", "old_pier"]))
	expect_eq(_ids(HoldfastMeta.from_save(content, fresh), "roster"), ["bryn", "wren"], "round 0: both come")
	var played := _through_json(_default_state_save(["outpost", "shingle_beach", "old_pier"]))
	played["recruits"]["round"] = 1
	expect_eq(_ids(HoldfastMeta.from_save(content, played), "roster"), ["bryn", "wren"], "round 1: both come")
	var saved := _through_json(HoldfastMeta.from_save(content, fresh))
	expect_eq(_ids(HoldfastMeta.from_save(content, saved), "roster"), ["bryn", "wren"], "and loading the result again adds nobody")


func test_the_recruits_who_come_with_a_load_are_welcomed_until_the_page_is_opened() -> void:
	var content := _content()
	var profile := HoldfastMeta.from_save(content, _old_save(["shingle_beach", "old_pier"]))
	expect_eq(RecruitMeta.welcome_text(profile), "Bryn and Wren have joined you", "both are named")
	var saved := HoldfastMeta.from_save(content, profile)
	expect_eq(RecruitMeta.welcome_text(saved), "Bryn and Wren have joined you", "the welcome survives a save")
	var seen := RecruitMeta.clear_welcome(saved)
	expect_eq(RecruitMeta.welcome_text(seen), "", "opening the page clears it")
	expect_eq(RecruitMeta.welcome_text(HoldfastMeta.from_save(content, seen)), "", "and it stays cleared")
	var one := HoldfastMeta.from_save(content, _old_save(["shingle_beach"]))
	expect_eq(RecruitMeta.welcome_text(one), "Bryn has joined you", "one Recruit: has")
	expect_eq(RecruitMeta.welcome_text(HoldfastMeta.from_save(content, _old_save(["outpost"]))), "", "nobody came: nothing to say")
	var damaged := HoldfastMeta.new_profile(content)
	damaged["recruits"]["welcome"] = "not a list"
	expect_eq(RecruitMeta.welcome_text(HoldfastMeta.from_save(content, damaged)), "", "a damaged welcome is ignored")
