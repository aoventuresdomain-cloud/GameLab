extends KitTestCase
## One connected tree (HF-M2-33): every node hangs off First Slot, the tree shows only what is next
## to something owned, gold nodes cost gold and star nodes cost stars, the castle chain grants slots
## and cards (cards two behind), a respec takes a fee, and a version 4 save is refunded into the tree.

const Main := preload("res://scenes/main.tscn")
const CASTLE_ORDER := ["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_slot_3", "castle_slot_4", "castle_slot_5", "castle_archer_2", "castle_archer_3"]


func _content() -> Dictionary:
	return HoldfastContent.base()


func _fresh() -> Dictionary:
	return HoldfastMeta.new_profile(_content())


## A profile that holds `owned` (no checks) with `gold` and `stars` earned in all.
func _holding(owned: Array, gold := 0, stars := 0) -> Dictionary:
	var profile := _fresh()
	profile["upgrades"] = owned.duplicate()
	profile["gold"] = gold
	profile["stars"] = {"outpost": mini(stars, 3), "shingle_beach": clampi(stars - 3, 0, 3), "tidewrack_cove": clampi(stars - 6, 0, 3), "gull_rock": clampi(stars - 9, 0, 3)} if stars > 0 else {}
	return profile


func _shown(profile: Dictionary) -> Array:
	var out := []
	for id in _content()["upgrade_nodes"]:
		if HoldfastMeta.is_visible(_content(), profile, id):
			out.append(id)
	out.sort()
	return out


# ------------------------------------------------------------------ the graph

func test_every_node_hangs_off_first_slot_through_the_nodes_it_requires() -> void:
	var nodes: Dictionary = _content()["upgrade_nodes"]
	expect_eq(nodes.size(), 62)
	var roots := []
	for id in nodes:
		if nodes[id].get("requires", []).is_empty():
			roots.append(id)
	expect_eq(roots, ["castle_slot_1"], "one start")
	var reached := ["castle_slot_1"]
	var grew := true
	while grew:
		grew = false
		for id in nodes:
			if id in reached:
				continue
			for required in nodes[id].get("requires", []):
				if required in reached:
					reached.append(id)
					grew = true
					break
	expect_eq(reached.size(), nodes.size(), "no node is cut off from the start")


func test_a_new_game_shows_first_slot_alone_and_each_buy_shows_what_is_next_to_it() -> void:
	var content := _content()
	var profile := _fresh()
	expect_eq(_shown(profile), ["castle_slot_1"])
	profile = _holding(["castle_slot_1"], 0, 3)
	expect_eq(_shown(profile), ["castle_archer_1", "castle_slot_1", "castle_slot_2"], "the two nodes that need it, and itself")
	profile = _holding(["castle_slot_1", "castle_archer_1"], 0, 3)
	var shown := _shown(profile)
	for id in ["flare_boots", "flare_hide", "flare_focus", "post_timbers", "post_sight", "post_drills", "post_rate", "keep_walls_1", "keep_beam_1", "tithe_1", "castle_archer_2"]:
		expect_true(id in shown, "%s opens with the first Archer Post" % id)
	for id in ["flare_hands", "flare_longer", "post_mend", "post_scope", "flare_inferno", "castle_slot_3", "castle_archer_3"]:
		expect_false(id in shown, "%s is two buys away, so it stays hidden" % id)
	expect_false(HoldfastMeta.is_visible(content, profile, "no_such_node"))


func test_a_node_of_another_heros_path_is_never_shown_even_when_owned_next_to_it() -> void:
	var profile := _holding(["castle_slot_1", "castle_archer_1"], 0, 3)
	profile["pillar"] = "dusk_mage"
	expect_false(HoldfastMeta.is_visible(_content(), profile, "flare_boots"))
	expect_true(HoldfastMeta.is_visible(_content(), profile, "post_timbers"), "the shared part stays")


func test_a_bought_node_stays_shown_and_the_tree_grows_as_the_player_buys() -> void:
	var content := _content()
	var profile := _holding(["castle_slot_1", "castle_archer_1"], 5000, 3)
	var before := _shown(profile).size()
	var bought := HoldfastMeta.buy(content, profile, "post_sight")
	expect_true(bought["ok"])
	expect_true(HoldfastMeta.is_visible(content, bought["profile"], "post_sight"))
	expect_true(HoldfastMeta.is_visible(content, bought["profile"], "post_scope"), "its child appears")
	expect_eq(_shown(bought["profile"]).size(), before + 2, "Scope and the Watchtower link both appear")


# ------------------------------------------------------------------ prices and the castle chain

func test_star_nodes_cost_stars_and_gold_nodes_cost_gold() -> void:
	var nodes: Dictionary = _content()["upgrade_nodes"]
	var star_nodes := []
	for id in nodes:
		if HoldfastMeta.is_star_node(nodes[id]):
			star_nodes.append(id)
	star_nodes.sort()
	var expected := CASTLE_ORDER + ["flare_inferno", "post_piercing", "post_storm", "link_lit_post", "link_pillar_echo", "link_rally", "link_last_light", "link_watchtower", "link_crossfire", "link_posted_hand", "gate_mage", "link_eclipse", "squad_hand_3", "squad_hand_4"]
	expected.sort()
	expect_eq(star_nodes, expected, "the castle chain, the three capstones, the seven links, the Mage gate and its link, and the two squad hands are the star nodes")
	for id in nodes:
		if not HoldfastMeta.is_star_node(nodes[id]):
			expect_false(nodes[id].has("currency"), id)
	var rich := _holding(["castle_slot_1", "castle_archer_1"], 999999, 0)
	rich["stars"] = {}
	expect_eq(HoldfastMeta.why_not_buy(_content(), rich, "post_timbers"), "")
	var broke := _holding(["castle_slot_1", "castle_archer_1"], 0, 0)
	expect_eq(HoldfastMeta.why_not_buy(_content(), broke, "post_timbers"), "Not enough gold")
	var starless := _holding(["castle_slot_1"], 999999, 0)
	expect_eq(HoldfastMeta.why_not_buy(_content(), starless, "castle_slot_2"), "Not enough stars", "gold cannot buy a star node")


func test_the_castle_chain_grants_slots_and_cards_with_cards_two_behind() -> void:
	var content := _content()
	var all := _holding(CASTLE_ORDER, 0, 12)
	expect_eq(HoldfastMeta.castle_slots(content, all), 5)
	expect_eq(HoldfastMeta.castle_cards(content, all), 3, "three cards for five slots")
	var one := _holding(["castle_slot_1", "castle_archer_1", "castle_archer_2", "castle_archer_3"], 0, 12)
	expect_eq(HoldfastMeta.castle_cards(content, one), 1, "cards never pass the slots")
	expect_eq(HoldfastMeta.castle_slots(content, one), 1)
	var profile := _fresh()
	profile["stars"] = {"outpost": 3, "shingle_beach": 3, "tidewrack_cove": 3, "gull_rock": 3}
	var wanted := ["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_slot_3", "castle_slot_4", "castle_slot_5"]
	var prices := {"castle_slot_1": 1, "castle_archer_1": 1, "castle_slot_2": 1, "castle_slot_3": 2, "castle_slot_4": 3, "castle_slot_5": 4}
	for id in wanted:
		expect_eq(int(content["upgrade_nodes"][id]["cost"]), prices[id], id)
		var bought := HoldfastMeta.buy(content, profile, id)
		expect_true(bought["ok"], "%s: %s" % [id, bought["reason"]])
		profile = bought["profile"]
	expect_eq(HoldfastMeta.castle_slots(content, profile), 5)
	expect_eq(HoldfastMeta.stars_available(content, profile), 0, "1+1+1+2+3+4 stars, all spent")
	var skipping := HoldfastMeta.buy(content, _holding(["castle_slot_1"], 0, 12), "castle_slot_3")
	expect_false(skipping["ok"])
	expect_eq(skipping["reason"], "Needs %s first" % content["upgrade_nodes"]["castle_slot_2"]["name"])


func test_both_archer_capstones_can_be_bought_with_enough_stars() -> void:
	var content := _content()
	var nodes: Dictionary = content["upgrade_nodes"]
	for id in ["post_piercing", "post_storm", "flare_inferno"]:
		expect_eq(nodes[id]["currency"], "stars")
		expect_eq(int(nodes[id]["cost"]), 3)
	var owned := ["castle_slot_1", "castle_archer_1", "post_drills", "post_sight", "post_scope", "post_twin", "post_marksman", "post_burst"]
	var profile := _holding(owned, 0, 12)
	var first := HoldfastMeta.buy(content, profile, "post_piercing")
	expect_true(first["ok"], first["reason"])
	var second := HoldfastMeta.buy(content, first["profile"], "post_storm")
	expect_true(second["ok"], "no fork closes the second one: " + str(second["reason"]))
	expect_eq(HoldfastMeta.stars_available(content, second["profile"]), 12 - 2 - 6, "two castle stars and three for each capstone")
	var short := _holding(owned, 999999, 3)
	short["upgrades"] = owned.duplicate()
	expect_eq(HoldfastMeta.stars_available(content, short), 3 - 2, "two stars are in the castle")
	expect_eq(HoldfastMeta.why_not_buy(content, short, "post_piercing"), "Not enough stars")


func test_steady_hands_and_lamp_oil_change_the_hero_in_a_run() -> void:
	var base := HoldfastRules.new()
	base.setup(HoldfastContent.run_config("outpost", [], {}, "flare_archer"), SimRng.new(1))
	var hands := HoldfastRules.new()
	hands.setup(HoldfastContent.run_config("outpost", ["flare_hands"], {}, "flare_archer"), SimRng.new(1))
	var both := HoldfastRules.new()
	both.setup(HoldfastContent.run_config("outpost", ["flare_hands", "flare_lamp"], {}, "flare_archer"), SimRng.new(1))
	expect_near(float(hands.hero_attack["cooldown"]), float(base.hero_attack["cooldown"]) * 0.87, 0.0001, "Steady hands: a draw 13% quicker")
	expect_eq(float(hands.hero_ability["cooldown"]), float(base.hero_ability["cooldown"]), "and the ability untouched")
	expect_near(float(both.hero_ability["cooldown"]), float(base.hero_ability["cooldown"]) * 0.9, 0.0001, "Lamp oil: the ability back 10% sooner")
	var tree: Dictionary = _content()["upgrade_nodes"]
	expect_eq(tree["flare_hands"]["requires"], ["flare_focus"])
	expect_eq(tree["flare_lamp"]["requires"], ["flare_hands"])
	expect_eq(int(tree["flare_hands"]["cost"]), 300)
	expect_eq(int(tree["flare_lamp"]["cost"]), 300)


# ------------------------------------------------------------------ respec

func test_a_respec_fee_is_a_tenth_of_a_gold_price_at_least_twenty_and_a_flat_fifty_for_a_star_node() -> void:
	var nodes: Dictionary = _content()["upgrade_nodes"]
	expect_eq(HoldfastMeta.respec_fee(nodes["flare_boots"]), 20, "a tenth of 90 is under the floor")
	expect_eq(HoldfastMeta.respec_fee(nodes["flare_hands"]), 30, "a tenth of 300")
	expect_eq(HoldfastMeta.respec_fee(nodes["post_scope"]), 60)
	expect_eq(HoldfastMeta.respec_fee(nodes["post_marksman"]), 140)
	expect_eq(HoldfastMeta.respec_fee(nodes["castle_slot_1"]), 50)
	expect_eq(HoldfastMeta.respec_fee(nodes["flare_inferno"]), 50, "a capstone is a star node too")


func test_a_respec_gives_back_prices_less_fees_and_every_star() -> void:
	var content := _content()
	var owned := ["castle_slot_1", "castle_archer_1", "flare_boots", "flare_focus", "flare_hands"]
	var profile := _holding(owned, 1000, 6)
	expect_eq(HoldfastMeta.stars_available(content, profile), 4)
	# 90 + 120 + 300 back, less 20 + 20 + 30; the two star nodes stay and cost no fee.
	expect_eq(HoldfastMeta.respec_gold_change(content, profile), 510 - 70)
	expect_eq(HoldfastMeta.why_not_respec(content, profile), "")
	var after := HoldfastMeta.respec(content, profile)
	expect_eq(after["gold"], 1000 + 440)
	expect_eq(after["upgrades"], ["castle_slot_1", "castle_archer_1"])
	expect_eq(HoldfastMeta.stars_available(content, after), 4, "the two stars of the guided buys stay spent")
	expect_eq(profile["upgrades"].size(), 5, "the profile given is untouched")


func test_a_respec_is_refused_when_the_fees_are_more_than_the_gold_held() -> void:
	var content := _content()
	var owned := ["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"]
	var short := _holding(owned, 99, 5)
	expect_eq(HoldfastMeta.why_not_respec(content, short), "Not enough gold for the refund fee")
	expect_eq(HoldfastMeta.respec(content, short), short, "nothing changes")
	var enough := _holding(owned, 100, 5)
	expect_eq(HoldfastMeta.why_not_respec(content, enough), "")
	expect_eq(HoldfastMeta.respec(content, enough)["gold"], 0, "the fees take the last of it")
	expect_eq(HoldfastMeta.why_not_respec(content, _fresh()), "Nothing to refund")
	# A gold node's refund can pay its own fee.
	var covered := _holding(["flare_boots"], 0, 3)
	expect_eq(HoldfastMeta.why_not_respec(content, covered), "")
	expect_eq(HoldfastMeta.respec(content, covered)["gold"], 70)


func test_the_profile_tells_the_player_why_a_respec_was_refused() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	var notices := []
	profile.notice.connect(func(text: String) -> void: notices.append(text))
	profile.respec()
	expect_eq(notices, ["Nothing to refund"])
	profile.data = _holding(["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"], 10, 5)
	profile.respec()
	expect_eq(notices[-1], "Not enough gold for the refund fee")
	expect_eq(profile.get_upgrades().size(), 4, "nothing was taken back")
	expect_eq(profile.get_respec_gold_change(), -100)
	main.free()


func test_a_respec_waits_until_the_run_is_over() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["gold"] = 500
	var owned: Array = profile.get_upgrades().duplicate()
	var source: Node = main.get_node("RunSource")
	main.call("_start_run")
	expect_true(source.is_running(), "a run is on")
	var notes := []
	profile.notice.connect(func(text: String) -> void: notes.append(text))
	main.keep_screen.respec_requested.emit()
	expect_eq(profile.get_upgrades(), owned, "nothing is taken back mid-run")
	expect_eq(profile.get_gold(), 500)
	expect_eq(notes, ["A refund waits until the run is over."])
	main.free()


# ------------------------------------------------------------------ the old save

func test_a_version_four_save_is_refunded_in_gold_and_keeps_its_stars() -> void:
	var content := _content()
	expect_eq(HoldfastMeta.SAVE_VERSION, 5)
	var data := {
		"gold": 100, "runs": 7, "level": "outpost",
		"upgrades": ["castle_slot_1", "castle_archer_1", "post_drills", "post_scope", "flare_boots", "post_storm", "flare_inferno", "post_piercing"],
		"layouts": {"outpost": ["spot_1"]},
		"stars": {"first_watch": 2, "outpost": 3},
		"levels_won": ["first_watch", "outpost"],
	}
	var migrated := HoldfastMeta.migrate_v4(data, content)
	# Castle nodes were stars (nothing back); the three capstones were gold nodes of 3000, 2400 and 3000.
	expect_eq(migrated["gold"], 100 + 110 + 600 + 90 + 3000 + 2400 + 3000)
	expect_eq(migrated["upgrades"], [])
	expect_eq(migrated["layouts"], {})
	expect_eq(migrated["stars"], {"first_watch": 2, "outpost": 3}, "the stars are kept")
	expect_eq(migrated["levels_won"], ["first_watch", "outpost"])
	expect_eq(migrated["runs"], 7)
	expect_eq(data["upgrades"].size(), 8, "the save given is untouched")
	var loaded := HoldfastMeta.from_save(content, migrated)
	expect_eq(HoldfastMeta.stars_available(content, loaded), 5)


func test_a_damaged_version_four_save_still_migrates() -> void:
	var content := _content()
	var migrated := HoldfastMeta.migrate_v4({"gold": "lots", "upgrades": ["no_such_node", "post_drills", "post_drills", 7, null], "layouts": 3}, content)
	expect_eq(migrated["gold"], 110, "a bad purse counts as nothing; each real node once")
	expect_eq(migrated["upgrades"], [])
	expect_eq(migrated["layouts"], {})
	expect_eq(HoldfastMeta.migrate_v4({}, content)["gold"], 0)


# ------------------------------------------------------------------ the tree screen

func test_the_tree_screen_shows_only_the_nodes_next_to_what_is_owned() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	var keep: Control = main.keep_screen
	keep.visible = true
	var shown := []
	for id in keep._node_buttons:
		if keep._node_buttons[id].visible:
			shown.append(id)
	expect_eq(shown, ["castle_slot_1"], "a new game shows First Slot alone")
	expect_eq(keep.tab_names(), PackedStringArray(["Castle"]))
	ThroughLevelZero.apply_castle(profile)
	expect_true(keep._node_buttons["flare_boots"].visible, "next to the first Archer Post")
	expect_false(keep._node_buttons["flare_longer"].visible, "two buys away")
	expect_false(keep._node_buttons["castle_slot_3"].visible)
	expect_eq(keep.tab_names(), PackedStringArray(["Hero", "Archer Post", "Keep", "Castle", "Mage Post"]))
	main.free()
