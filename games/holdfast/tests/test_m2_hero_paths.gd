extends KitTestCase
## HF-M2-14 Hero skill paths, tier locks and respec: strict tests written before
## the build (Head of QA, M2).
##
## The seam the build must provide (names are QA's; ask QA before the build if
## one has to change, never after). Pure functions on plain data, no nodes:
##
##   res://scripts/rules/hero_paths.gd   class_name HeroPaths
##
##   HeroPaths.new(definition: Dictionary)
##       definition = {
##         "tier_opens_after": {"2": 2, "3": 2, "4": 3},
##         "paths": {"guardian": [{"id": "g1a", "tier": 1}, ... 10 nodes], ...},
##       }
##       A path is 3 tiers of 3 nodes plus a 1-node capstone (tier 4). Tier N opens
##       once the Hero owns at least tier_opens_after[N] nodes of tier N-1 IN THE
##       SAME PATH. Tier 1 is always open. A threshold of 0 opens that tier alone.
##   validate() -> PackedStringArray            empty when the definition is fine
##   tier_is_open(owned: Array, path_id: String, tier: int) -> bool
##   buy(owned: Array, points: int, node_id: String) -> Dictionary
##       {ok, owned, points, reason}. One point per node. reason is "" on success,
##       else "locked", "owned", "no_points" or "unknown". A refusal returns the
##       state it was given. Never changes the arrays passed in.
##   respec(owned: Array, points: int, gold: int, cost: int) -> Dictionary
##       {ok, owned, points, gold, reason}. Gives every point back, empties owned
##       and charges cost gold. reason "no_gold" when gold < cost (nothing changes).
##       Respeccing with nothing owned is free.
##
## Worked numbers (the thresholds above, 8 points): reaching a capstone takes
## 2 (tier 1) + 2 (tier 2) + 3 (tier 3) = 7 nodes and the capstone is the 8th,
## which is exactly the "about 8 nodes in a session" the board describes.

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const SEAM := "res://scripts/rules/hero_paths.gd"
const OPENS := {"2": 2, "3": 2, "4": 3}


func _seam() -> GDScript:
	return QaSeam.new(self, "res://tests/qa_pending.json").use("hero_paths", SEAM)


func _path_nodes(prefix: String) -> Array:
	var nodes := []
	for tier in [1, 2, 3]:
		for letter in ["a", "b", "c"]:
			nodes.append({"id": "%s%d%s" % [prefix, tier, letter], "tier": tier})
	nodes.append({"id": prefix + "4", "tier": 4})
	return nodes


func _definition(opens: Dictionary = OPENS) -> Dictionary:
	return {
		"tier_opens_after": opens.duplicate(),
		"paths": {"guardian": _path_nodes("g"), "marksman": _path_nodes("m"), "warlord": _path_nodes("w")},
	}


func _paths(seam: GDScript, definition: Dictionary = {}) -> Object:
	return seam.new(definition if not definition.is_empty() else _definition())


func test_a_good_definition_has_no_errors() -> void:
	var seam := _seam()
	if seam == null:
		return
	expect_eq(_paths(seam).call("validate"), PackedStringArray())
	var zero_gate := _definition({"2": 0, "3": 2, "4": 3})
	expect_eq(_paths(seam, zero_gate).call("validate"), PackedStringArray(), "a threshold of 0 is allowed")


func test_bad_definitions_are_rejected() -> void:
	var seam := _seam()
	if seam == null:
		return
	var bad := {}
	var nine := _definition()
	nine["paths"]["guardian"].pop_back()
	bad["a path with 9 nodes"] = nine
	var eleven := _definition()
	eleven["paths"]["guardian"].append({"id": "g4b", "tier": 4})
	bad["a path with 11 nodes"] = eleven
	var two_capstones := _definition()
	two_capstones["paths"]["guardian"][8]["tier"] = 4
	bad["tiers 3,3,2,2 instead of 3,3,3,1"] = two_capstones
	var tier_five := _definition()
	tier_five["paths"]["guardian"][9]["tier"] = 5
	bad["a node in tier 5"] = tier_five
	var duplicate := _definition()
	duplicate["paths"]["marksman"][0]["id"] = "g1a"
	bad["an id used in two paths"] = duplicate
	bad["no paths"] = {"tier_opens_after": OPENS.duplicate(), "paths": {}}
	bad["an empty path"] = {"tier_opens_after": OPENS.duplicate(), "paths": {"guardian": []}}
	bad["no threshold for tier 3"] = _definition({"2": 2, "4": 3})
	bad["no thresholds at all"] = _definition({})
	bad["tier 2 needs 4 of a tier that has 3"] = _definition({"2": 4, "3": 2, "4": 3})
	bad["the capstone needs 4 of tier 3's 3"] = _definition({"2": 2, "3": 2, "4": 4})
	bad["a negative threshold"] = _definition({"2": -1, "3": 2, "4": 3})
	bad["a text threshold"] = _definition({"2": "two", "3": 2, "4": 3})
	for label in bad:
		var errors: PackedStringArray = _paths(seam, bad[label]).call("validate")
		expect_true(errors.size() >= 1, label + " must be rejected")
		for message in errors:
			expect_ne(message, "", label + ": every error says something")


func test_a_fresh_hero_has_only_tier_1_open() -> void:
	var seam := _seam()
	if seam == null:
		return
	var paths := _paths(seam)
	var expected := {1: true, 2: false, 3: false, 4: false}
	for tier in expected:
		expect_eq(paths.call("tier_is_open", [], "guardian", tier), expected[tier], "tier %d" % tier)


func test_tiers_open_exactly_at_the_threshold() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	# tier 2 needs 2 of tier 1: one is not enough, two is.
	expect_false(p.call("tier_is_open", ["g1a"], "guardian", 2), "1 of 2")
	expect_true(p.call("tier_is_open", ["g1a", "g1b"], "guardian", 2), "2 of 2")
	# tier 3 needs 2 of tier 2 (tier-1 nodes do not count).
	expect_false(p.call("tier_is_open", ["g1a", "g1b", "g2a"], "guardian", 3), "1 of 2 in tier 2")
	expect_true(p.call("tier_is_open", ["g1a", "g1b", "g2a", "g2b"], "guardian", 3), "2 of 2 in tier 2")
	expect_false(p.call("tier_is_open", ["g1a", "g1b", "g1c"], "guardian", 3), "three tier-1 nodes do not open tier 3")
	# the capstone needs 3 of tier 3.
	var two_of_three := ["g1a", "g1b", "g2a", "g2b", "g3a", "g3b"]
	expect_false(p.call("tier_is_open", two_of_three, "guardian", 4), "2 of 3 in tier 3")
	expect_true(p.call("tier_is_open", two_of_three + ["g3c"], "guardian", 4), "3 of 3 in tier 3")


func test_tiers_are_counted_per_path() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	var owned := ["g1a", "g1b"]
	expect_true(p.call("tier_is_open", owned, "guardian", 2))
	expect_false(p.call("tier_is_open", owned, "marksman", 2), "Guardian nodes do not open Marksman tier 2")
	expect_false(p.call("tier_is_open", owned, "warlord", 2))
	expect_true(p.call("tier_is_open", owned, "marksman", 1), "tier 1 is always open")


func test_a_zero_threshold_opens_only_its_own_tier() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam, _definition({"2": 0, "3": 2, "4": 3}))
	expect_true(p.call("tier_is_open", [], "guardian", 2), "tier 2 has no gate")
	expect_false(p.call("tier_is_open", [], "guardian", 3), "zero must not open every tier")
	expect_false(p.call("tier_is_open", [], "guardian", 4))


func test_buying_a_node() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	var owned := []
	var bought: Dictionary = p.call("buy", owned, 8, "g1a")
	expect_true(bought["ok"])
	expect_eq(bought["owned"], ["g1a"])
	expect_eq(bought["points"], 7)
	expect_eq(bought["reason"], "")
	expect_eq(owned, [], "the array passed in is not changed")


func test_refusals_change_nothing_and_say_why() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	var locked: Dictionary = p.call("buy", [], 8, "g2a")
	expect_false(locked["ok"])
	expect_eq(locked["reason"], "locked")
	expect_eq(locked["owned"], [])
	expect_eq(locked["points"], 8)
	var capstone_early: Dictionary = p.call("buy", ["g1a", "g1b", "g2a", "g2b", "g3a", "g3b"], 5, "g4")
	expect_eq(capstone_early["reason"], "locked", "capstone with 2 of 3 tier-3 nodes")
	expect_eq(capstone_early["points"], 5)
	var twice: Dictionary = p.call("buy", ["g1a"], 7, "g1a")
	expect_eq(twice["reason"], "owned")
	expect_eq(twice["points"], 7, "no points taken for a node already owned")
	expect_eq(twice["owned"], ["g1a"])
	var broke: Dictionary = p.call("buy", [], 0, "g1a")
	expect_false(broke["ok"])
	expect_eq(broke["reason"], "no_points")
	expect_eq(broke["owned"], [])
	var unknown: Dictionary = p.call("buy", ["g1a"], 5, "nope")
	expect_eq(unknown["reason"], "unknown")
	expect_eq(unknown["owned"], ["g1a"])
	expect_eq(unknown["points"], 5)
	var empty_id: Dictionary = p.call("buy", [], 5, "")
	expect_eq(empty_id["reason"], "unknown", "an empty id is unknown, not 'any node'")


func test_paths_can_be_mixed() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	var state := {"owned": [], "points": 3}
	for id in ["g1a", "m1a", "w1a"]:
		var result: Dictionary = p.call("buy", state["owned"], state["points"], id)
		expect_true(result["ok"], id)
		state = {"owned": result["owned"], "points": result["points"]}
	expect_eq(state["owned"], ["g1a", "m1a", "w1a"], "order of purchase kept")
	expect_eq(state["points"], 0)


func test_eight_points_reach_the_capstone_and_not_a_ninth_node() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	var order := ["g1a", "g1b", "g2a", "g2b", "g3a", "g3b", "g3c", "g4"]
	var owned := []
	var points := 8
	for id in order:
		var result: Dictionary = p.call("buy", owned, points, id)
		expect_true(result["ok"], "%s (%d points left)" % [id, points])
		owned = result["owned"]
		points = result["points"]
	expect_eq(points, 0)
	expect_eq(owned.size(), 8)
	expect_eq(owned[7], "g4", "the capstone is the 8th node")
	var ninth: Dictionary = p.call("buy", owned, points, "g1c")
	expect_false(ninth["ok"])
	expect_eq(ninth["reason"], "no_points")


func test_respec_gives_everything_back_and_charges() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	var owned := ["g1a", "g1b", "g2a", "g2b", "m1a", "w1a"]
	var result: Dictionary = p.call("respec", owned, 2, 100, 25)
	expect_true(result["ok"])
	expect_eq(result["owned"], [])
	expect_eq(result["points"], 8, "2 spare + 6 refunded")
	expect_eq(result["gold"], 75, "100 - 25")
	expect_eq(owned.size(), 6, "the array passed in is not changed")


func test_respec_money_boundaries() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	var owned := ["g1a", "g1b", "g2a"]
	var exact: Dictionary = p.call("respec", owned, 5, 25, 25)
	expect_true(exact["ok"], "exactly enough gold")
	expect_eq(exact["gold"], 0)
	var short: Dictionary = p.call("respec", owned, 5, 24, 25)
	expect_false(short["ok"], "one gold short")
	expect_eq(short["reason"], "no_gold")
	expect_eq(short["owned"], owned, "nothing changed")
	expect_eq(short["points"], 5)
	expect_eq(short["gold"], 24)
	var free: Dictionary = p.call("respec", owned, 5, 0, 0)
	expect_true(free["ok"], "a free respec works with no gold at all")
	expect_eq(free["owned"], [])
	expect_eq(free["points"], 8)
	expect_eq(free["gold"], 0)
	var nothing: Dictionary = p.call("respec", [], 8, 100, 25)
	expect_true(nothing["ok"])
	expect_eq(nothing["gold"], 100, "nothing to respec costs nothing")
	expect_eq(nothing["points"], 8)


func test_after_a_respec_the_tiers_lock_again() -> void:
	var seam := _seam()
	if seam == null:
		return
	var p := _paths(seam)
	var owned := ["g1a", "g1b", "g2a"]
	expect_true(p.call("tier_is_open", owned, "guardian", 2))
	var result: Dictionary = p.call("respec", owned, 5, 0, 0)
	expect_false(p.call("tier_is_open", result["owned"], "guardian", 2))
	var locked: Dictionary = p.call("buy", result["owned"], result["points"], "g2a")
	expect_eq(locked["reason"], "locked", "tier 2 must be earned again")


func test_the_rules_actually_use_the_paths_module() -> void:
	var qa := QaSeam.new(self, "res://tests/qa_pending.json")
	if not qa.check("hero_paths", ResourceLoader.exists(SEAM), SEAM):
		return
	var hits := QaSeam.mentions_outside("res://scripts", SEAM, PackedStringArray(["HeroPaths", "hero_paths.gd"]))
	expect_true(hits.size() >= 1, "no script under res://scripts uses HeroPaths, so buying and respec are not wired")
