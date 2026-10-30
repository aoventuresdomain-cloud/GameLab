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
	expect_eq(HoldfastMeta.respec_stars(content, profile), 1 + 1 + 2, "two stars for Third Hand on top of the castle nodes")
	profile["upgrades"] = []
	expect_eq(HoldfastMeta.respec_stars(content, profile), 0, "nothing bought, nothing back")
