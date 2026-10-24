extends KitTestCase
## HF-M2-38: the two guided buys (First Slot, then the first Archer Post) are compulsory: until
## they are made nothing else can be bought and the tree and the Hero page stay shut. A new game,
## an old save and a respec all walk through them and never get stuck. The tree opens on
## everything on show, zoomed out as far as stays legible, and keeps the player's view after.

const Main := preload("res://scenes/main.tscn")


func _content() -> Dictionary:
	return HoldfastContent.base()


## A profile that has won Level 0 (2 stars) and has not made the guided buys.
func _after_level_zero(gold := 150) -> Dictionary:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	profile["gold"] = gold
	return profile


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


# ------------------------------------------------------------------ the rule

func test_the_guide_runs_from_level_zero_until_the_castle_has_a_tower() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_eq(HoldfastMeta.guided_step(content, profile), "", "before Level 0 is won there is nothing to buy with")
	profile = _after_level_zero()
	expect_eq(HoldfastMeta.guided_step(content, profile), "castle_slot_1", "first the slot")
	profile = HoldfastMeta.buy(content, profile, "castle_slot_1")["profile"]
	expect_eq(HoldfastMeta.guided_step(content, profile), "castle_archer_1", "then the Archer Post")
	profile = HoldfastMeta.buy(content, profile, "castle_archer_1")["profile"]
	expect_eq(HoldfastMeta.guided_step(content, profile), "", "and then it is done")


func test_while_a_step_is_due_nothing_else_can_be_bought() -> void:
	var content := _content()
	var profile := _after_level_zero(5000)
	for id in content["upgrade_nodes"]:
		if id != "castle_slot_1":
			expect_eq(HoldfastMeta.why_not_buy(content, profile, id), "Buy First Slot first", id + " waits for the guide")
			expect_false(HoldfastMeta.buy(content, profile, id)["ok"], id + " cannot be bought")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_slot_1"), "", "the step itself can")
	profile = HoldfastMeta.buy(content, profile, "castle_slot_1")["profile"]
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_slot_2"), "Buy Archer Post first", "the second step is the only one open now")
	profile = HoldfastMeta.buy(content, profile, "castle_archer_1")["profile"]
	profile["stars"]["outpost"] = 3
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_slot_2"), "", "once the guide is done the tree is free")


func test_the_guided_nodes_follow_the_pack_not_a_fixed_pair() -> void:
	var content: Dictionary = _content().duplicate(true)
	content["castle_rules"]["castle"]["guided"] = ["castle_slot_1"]
	var profile := _after_level_zero()
	expect_eq(HoldfastMeta.guided_step(content, profile), "castle_slot_1")
	profile = HoldfastMeta.buy(content, profile, "castle_slot_1")["profile"]
	expect_eq(HoldfastMeta.guided_step(content, profile), "", "a one-step guide ends after one")


# ------------------------------------------------------------------ the screens

func test_the_map_shuts_the_tree_and_the_hero_page_until_the_guide_is_done() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.new_game()
	var map: Control = main.journey
	expect_false(map.get_node("%TreeButton").disabled, "a new game can open the tree")
	profile.data = _after_level_zero()
	profile.changed.emit()
	expect_true(map.get_node("%Guide").visible)
	expect_true(map.get_node("%TreeButton").disabled, "the tree is shut during the guide")
	expect_true(map._hero_button.disabled, "and so is the Hero page")
	expect_true(map._hero_figure.disabled, "including the figure")
	map.get_node("%GuideButton").pressed.emit()
	expect_eq(profile.get_upgrades(), ["castle_slot_1"], "the guide buys the slot")
	expect_true(map.get_node("%TreeButton").disabled)
	map.get_node("%GuideButton").pressed.emit()
	expect_true(profile.has_a_tower())
	expect_false(map.get_node("%Guide").visible)
	expect_false(map.get_node("%TreeButton").disabled, "the tree opens when the guide is done")
	expect_false(map._hero_button.disabled)
	main.free()


func test_the_tree_page_offers_only_the_guided_step_while_one_is_due() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data = _after_level_zero(5000)
	profile.changed.emit()
	var page: Control = main.keep_screen
	for id in page._node_buttons:
		expect_eq(page._node_buttons[id].disabled, id != "castle_slot_1", id)
	page._node_buttons["castle_slot_2"].pressed.emit()
	expect_eq(profile.get_upgrades(), [], "pressing another node buys nothing")
	page._node_buttons["castle_slot_1"].pressed.emit()
	expect_eq(profile.get_upgrades(), ["castle_slot_1"], "the step can be bought here too, so it is never out of reach")
	main.free()


# ------------------------------------------------------------------ never stuck

func test_a_new_game_walks_the_guide_from_level_zero() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.new_game()
	expect_eq(profile.get_guided_step(), "")
	expect_false(profile.has_a_tower())
	profile.bank_run({"outcome": "won", "level": HoldfastMeta.tutorial_level(_content()), "gold": 0})
	expect_eq(profile.get_stars(), 2, "Level 0 pays exactly the two stars the guide costs")
	expect_true(profile.buy("castle_slot_1"))
	expect_true(profile.buy("castle_archer_1"))
	expect_true(profile.has_a_tower())
	expect_eq(profile.get_guided_step(), "")
	expect_true(main.journey._is_open("outpost"), "and the first real level is open")
	main.free()


func test_an_old_save_with_levels_won_gets_the_guide_and_the_stars_to_finish_it() -> void:
	var content := _content()
	var old := HoldfastMeta.migrate_v3({
		"gold": 40, "upgrades": ["keep_walls_1", "post_drills"],
		"levels_won": ["outpost", "shingle_beach"], "unlocked": ["shingle_beach"],
		"level": "shingle_beach", "pillar": "flare_archer", "layouts": {"shingle_beach": ["west_gate"]},
	}, content)
	var profile := HoldfastMeta.from_save(content, old)
	expect_eq(HoldfastMeta.guided_step(content, profile), "castle_slot_1", "the guide starts at the first step")
	expect_true(HoldfastMeta.stars_available(content, profile) >= 2, "with stars to pay for both steps")
	for id in HoldfastMeta.castle_rules(content)["guided"]:
		var bought := HoldfastMeta.buy(content, profile, id)
		expect_true(bought["ok"], id)
		profile = bought["profile"]
	expect_eq(HoldfastMeta.guided_step(content, profile), "")
	expect_true(HoldfastMeta.has_a_tower(content, profile))


func test_a_save_that_lost_its_stars_can_replay_level_zero_to_be_paid_again() -> void:
	var content := _content()
	var profile := _after_level_zero()
	profile["stars"] = {}
	profile = HoldfastMeta.from_save(content, profile)
	expect_eq(HoldfastMeta.guided_step(content, profile), "castle_slot_1")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_slot_1"), "Not enough stars", "short of stars")
	var tutorial := HoldfastMeta.tutorial_level(content)
	expect_true(tutorial in HoldfastMeta.unlocked_levels(content, profile), "Level 0 is still open")
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": tutorial, "gold": 0})
	expect_eq(HoldfastMeta.stars_available(content, profile), 2, "winning it pays the stars the guide needs")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_slot_1"), "")


func test_a_respec_sends_the_player_back_through_the_guide_with_the_stars_to_finish_it() -> void:
	var content := _content()
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	profile["gold"] = 1000
	for id in ["castle_slot_2", "castle_archer_2", "keep_walls_1"]:
		profile["stars"]["outpost"] = 3
		var bought := HoldfastMeta.buy(content, profile, id)
		expect_true(bought["ok"], id)
		profile = bought["profile"]
	expect_eq(HoldfastMeta.guided_step(content, profile), "")
	profile = HoldfastMeta.respec(content, profile)
	expect_eq(profile["upgrades"], [], "the tree is empty")
	expect_eq(HoldfastMeta.guided_step(content, profile), "castle_slot_1", "so the guide is due again")
	expect_eq(HoldfastMeta.stars_available(content, profile), HoldfastMeta.stars_earned(profile), "every star is free")
	for id in HoldfastMeta.castle_rules(content)["guided"]:
		var bought := HoldfastMeta.buy(content, profile, id)
		expect_true(bought["ok"], "%s after a respec" % id)
		profile = bought["profile"]
	expect_eq(HoldfastMeta.guided_step(content, profile), "")


func test_respec_from_the_tree_page_leaves_the_guided_step_buyable_there() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["gold"] = 1000
	profile.changed.emit()
	profile.respec()
	var page: Control = main.keep_screen
	expect_eq(profile.get_guided_step(), "castle_slot_1")
	expect_false(page._node_buttons["castle_slot_1"].disabled, "the step is open on the tree page")
	page._node_buttons["castle_slot_1"].pressed.emit()
	page._node_buttons["castle_archer_1"].pressed.emit()
	expect_true(profile.has_a_tower(), "and finishes there")
	main.free()


# ------------------------------------------------------------------ the tree's first view

func _open_tree(profile_data: Dictionary) -> Array:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data = profile_data
	profile.changed.emit()
	main.journey.get_node("%TreeButton").pressed.emit()
	await tree.process_frame
	await tree.process_frame
	return [main, main.keep_screen]


func _on_screen(page: Control, id: String) -> bool:
	return page.get_node("%View").get_global_rect().encloses(page._node_buttons[id].get_global_rect())


func test_the_tree_opens_on_everything_that_is_shown_as_large_as_that_fits() -> void:
	# Only the Hero and Keep sections are next to the castle at the start; they fit at a legible size.
	var made := await _open_tree(ThroughLevelZero.castle(_content(), _after_level_zero()))
	var main: Node = made[0]
	var page: Control = made[1]
	var zoom: float = page.get_node("%Web").scale.x
	expect_true(zoom >= page.OVERVIEW_ZOOM_MIN and zoom <= 1.0, "zoom %s is between the floor and real size" % zoom)
	var shown := 0
	for id in page._node_buttons:
		if page._node_buttons[id].visible and page._node_buttons[id].get_parent().visible:
			shown += 1
			if page.get_node("%Web").scale.x > page.OVERVIEW_ZOOM_MIN + 0.001:
				expect_true(_on_screen(page, id), "%s is in the first view" % id)
	expect_true(shown > 4, "there is a tree to see")
	main.free()


func test_when_the_tree_is_too_wide_it_opens_at_the_floor_centred_on_what_the_player_owns() -> void:
	var content := _content()
	var profile := ThroughLevelZero.castle(content, _after_level_zero())
	profile["stars"]["outpost"] = 3
	profile["stars"]["shingle_beach"] = 3
	profile["gold"] = 5000
	for id in ["castle_slot_2", "castle_archer_2", "gate_mage"]:
		var bought := HoldfastMeta.buy(content, profile, id)
		profile = bought["profile"] if bought["ok"] else profile
	var made := await _open_tree(profile)
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	expect_near(web.scale.x, 0.5, 0.0001, "as small as is still legible (10 px names)")
	var owned := Rect2()
	for id in profile["upgrades"]:
		var rect: Rect2 = page._node_buttons[id].get_global_rect()
		owned = rect if owned == Rect2() else owned.merge(rect)
		expect_true(_on_screen(page, id), "%s, which the player owns, is in view" % id)
	var view_centre: Vector2 = page.get_node("%View").get_global_rect().get_center()
	expect_true(owned.get_center().distance_to(view_centre) < 30.0, "and sits in the middle of the view")
	main.free()


func test_the_view_the_player_chose_survives_closing_and_opening_the_tree() -> void:
	var made := await _open_tree(ThroughLevelZero.castle(_content(), _after_level_zero()))
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	page.zoom_by(1.5)
	var scale_after := web.scale.x
	var place := web.position
	page.get_node("%BackButton").pressed.emit()
	main.journey.get_node("%TreeButton").pressed.emit()
	await tree.process_frame
	expect_eq(web.scale.x, scale_after, "the zoom stays")
	expect_eq(web.position, place, "and so does the pan")
	main.free()


func test_resizing_the_page_keeps_the_view_the_player_chose() -> void:
	var made := await _open_tree(ThroughLevelZero.castle(_content(), _after_level_zero()))
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	page.zoom_by(1.5)
	var scale_after := web.scale.x
	page.get_node("%View").resized.emit()
	expect_eq(web.scale.x, scale_after, "the zoom stays")
	main.free()


func test_a_view_nobody_touched_is_laid_out_again_each_visit() -> void:
	var made := await _open_tree(ThroughLevelZero.castle(_content(), _after_level_zero()))
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var first := web.scale.x
	page.get_node("%BackButton").pressed.emit()
	main.get_node("Profile").data["gold"] = 1
	main.journey.get_node("%TreeButton").pressed.emit()
	await tree.process_frame
	expect_eq(web.scale.x, first, "same overview")
	main.free()
