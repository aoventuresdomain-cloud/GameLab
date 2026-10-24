extends KitTestCase
## Navigation rework, part 2 of Part A (HF-M2-29): the Plan page. Tower cards are dragged
## into slots (or a slot is pressed), Auto-place suggests a layout, Quick start reuses the
## last one. Nothing is placed inside the level.

const Main := preload("res://scenes/main.tscn")


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


## Opens the Plan page for a player who owns the first `slots` castle spots and `cards` Archer Posts.
func _open(level := "shingle_beach", layout: Array = [], saved := false, slots := 4, cards := 2) -> Control:
	var plan: Control = _main().planning
	plan.open(level, layout, saved, HoldfastMeta.castle_rules(HoldfastContent.base())["spots"].slice(0, slots), cards)
	return plan


func _card(from := "") -> Dictionary:
	return {"kind": "tower", "tower": "archer_post", "from": from}


func test_a_first_visit_has_empty_slots_one_card_per_owned_post_and_nothing_to_start() -> void:
	var plan := _open("shingle_beach")
	expect_eq(plan._chosen, [])
	expect_eq(plan._tray.get_child_count(), 2, "the player owns two Archer Posts")
	expect_true(plan.get_node("%StartButton").disabled, "no post, no start")
	expect_true(plan.get_node("%QuickButton").disabled, "no last layout yet")
	expect_eq(plan.get_node("%Count").text, "Posts: 0 of 2")
	plan.get_parent().get_parent().free()


func test_the_outpost_allows_one_card() -> void:
	var plan := _open("outpost", [], false, 1, 1)
	expect_eq(plan._tray.get_child_count(), 1)
	plan.get_parent().get_parent().free()


func test_auto_place_is_the_suggested_layout_and_lets_the_player_start() -> void:
	var plan := _open("shingle_beach")
	plan.get_node("%AutoButton").pressed.emit()
	var owned: Array = HoldfastContent.base()["castle_rules"]["castle"]["spots"].slice(0, 4)
	expect_eq(plan._chosen, HoldfastRules.best_sites(owned, HoldfastContent.base()["levels"]["shingle_beach"]["spawn_arcs"], 2))
	expect_eq(plan._chosen.size(), 2)
	expect_false(plan.get_node("%StartButton").disabled)
	expect_eq(plan.get_node("%Count").text, "Posts: 2 of 2")
	plan.get_parent().get_parent().free()


func test_dragging_a_card_onto_an_empty_slot_places_it_until_the_limit() -> void:
	var plan := _open("shingle_beach")
	expect_true(plan._slot_can_drop(Vector2.ZERO, _card(), "spot_2"))
	plan._slot_drop(Vector2.ZERO, _card(), "spot_2")
	expect_eq(plan._chosen, ["spot_2"])
	expect_false(plan._slot_can_drop(Vector2.ZERO, _card(), "spot_2"), "a slot already holding a post takes no card")
	plan._slot_drop(Vector2.ZERO, _card(), "spot_1")
	expect_eq(plan._chosen, ["spot_2", "spot_1"])
	expect_false(plan._slot_can_drop(Vector2.ZERO, _card(), "spot_3"), "no card left in hand")
	plan._slot_drop(Vector2.ZERO, _card(), "spot_3")
	expect_eq(plan._chosen, ["spot_2", "spot_1"], "a refused drop changes nothing")
	plan.get_parent().get_parent().free()


func test_a_drop_that_is_not_a_tower_card_is_refused() -> void:
	var plan := _open("shingle_beach")
	for bad in [null, "x", {}, {"kind": "wall", "from": ""}]:
		expect_false(plan._slot_can_drop(Vector2.ZERO, bad, "spot_2"))
	expect_false(plan._side_can_drop(Vector2.ZERO, _card()), "a card from the tray has nothing to return")
	plan.get_parent().get_parent().free()


func test_a_placed_post_can_be_moved_to_another_slot_keeping_its_place_in_order() -> void:
	var plan := _open("shingle_beach", ["spot_2", "spot_1"])
	var data: Variant = plan._slot_drag(Vector2.ZERO, "spot_2", plan._site_buttons["spot_2"])
	expect_eq(data, _card("spot_2"))
	expect_false(plan._slot_can_drop(Vector2.ZERO, data, "spot_1"), "not onto another post")
	plan._slot_drop(Vector2.ZERO, data, "spot_3")
	expect_eq(plan._chosen, ["spot_3", "spot_1"])
	plan.get_parent().get_parent().free()


func test_an_empty_slot_has_nothing_to_drag() -> void:
	var plan := _open("shingle_beach")
	expect_true(plan._slot_drag(Vector2.ZERO, "spot_2", plan._site_buttons["spot_2"]) == null)
	plan.get_parent().get_parent().free()


func test_dropping_a_lifted_post_on_the_card_side_returns_its_card() -> void:
	var plan := _open("shingle_beach", ["spot_2", "spot_1"])
	expect_true(plan._side_can_drop(Vector2.ZERO, _card("spot_1")))
	plan._side_drop(Vector2.ZERO, _card("spot_1"))
	expect_eq(plan._chosen, ["spot_2"])
	expect_eq(plan.get_node("%Count").text, "Posts: 1 of 2")
	expect_false(plan._side_can_drop(Vector2.ZERO, _card("spot_1")), "it is no longer placed")
	plan.get_parent().get_parent().free()


func test_placed_cards_wait_greyed_and_cards_in_hand_are_lit() -> void:
	var plan := _open("shingle_beach", ["spot_2"])
	expect_eq(plan._tray.get_child(0).modulate, Color(1, 1, 1, 0.45), "placed")
	expect_eq(plan._tray.get_child(1).modulate, Color.WHITE, "in hand")
	plan.get_parent().get_parent().free()


func test_quick_start_reuses_the_last_layout_and_is_greyed_without_one() -> void:
	var plan := _open("shingle_beach", ["spot_1", "spot_3"], true)
	expect_false(plan.get_node("%QuickButton").disabled)
	var heard := []
	plan.start_requested.connect(func(layout: Array) -> void: heard.append(layout))
	plan._chosen = ["spot_2"]
	plan.get_node("%QuickButton").pressed.emit()
	expect_eq(heard, [["spot_1", "spot_3"]], "the saved one, whatever is placed now")
	plan.get_parent().get_parent().free()


func test_the_flow_opens_empty_the_first_time_then_with_the_last_layout() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	main.journey.level_requested.emit("outpost")
	expect_eq(main.planning._chosen, [], "first visit")
	expect_true(main.planning.get_node("%QuickButton").disabled)
	expect_eq(main.planning._site_buttons.size(), 8, "the whole ring")
	expect_eq(main.planning.get_node("%Count").text, "Posts: 0 of 1", "one slot, so one post")
	main.planning._site_buttons["spot_1"].pressed.emit()
	main.planning.get_node("%StartButton").pressed.emit()
	expect_true(profile.has_saved_layout("outpost"))
	main.free()
	var again := _main()
	ThroughLevelZero.apply(again.get_node("Profile"))
	again.get_node("Profile").set_layout("outpost", ["spot_1"])
	again.journey.level_requested.emit("outpost")
	expect_eq(again.planning._chosen, ["spot_1"], "kept for the next visit")
	expect_false(again.planning.get_node("%QuickButton").disabled)
	again.planning.get_node("%QuickButton").pressed.emit()
	expect_true(again.get_node("RunSource").is_running() and again.hud.visible, "Quick start starts the level")
	expect_eq(again.get_node("RunSource").get_rules().layout_ids, ["spot_1"])
	again.free()


func test_a_layout_is_saved_only_when_valid_so_quick_start_never_reuses_a_bad_one() -> void:
	var content := HoldfastContent.base()
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	expect_false(HoldfastMeta.has_saved_layout(content, profile, "shingle_beach"))
	for bad in [["spot_1", "no_such_spot"], ["spot_1", "spot_2"], ["spot_1", "spot_1"], []]:
		profile["layouts"]["shingle_beach"] = bad
		expect_false(HoldfastMeta.has_saved_layout(content, profile, "shingle_beach"), "not a saved layout: %s" % [bad])
	profile["layouts"]["shingle_beach"] = ["spot_1"]
	expect_true(HoldfastMeta.has_saved_layout(content, profile, "shingle_beach"))
	profile["layouts"]["first_watch"] = ["spot_1"]
	expect_false(HoldfastMeta.has_saved_layout(content, profile, "first_watch"), "the tutorial has no layout")


# ------------------------------------------------------------------ F-056: a lifted post returns from anywhere

## Moves the pointer like a hand: press on `from`, move a little, move to `to`, let go.
func _drag(from: Vector2, to: Vector2) -> void:
	var to_window := tree.root.get_final_transform()
	var steps := [[from, true], [from + Vector2(12, 0), true], [to, true], [to, false]]
	var last: Vector2 = from
	for step in steps:
		var at: Vector2 = to_window * step[0]
		var move := InputEventMouseMotion.new()
		move.position = at
		move.relative = step[0] - last
		last = step[0]
		move.button_mask = MOUSE_BUTTON_MASK_LEFT if step[1] else 0
		tree.root.push_input(move)
		if step == steps[0] or step == steps[3]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = step[1]
			click.position = at
			tree.root.push_input(click)
		await tree.process_frame


func test_a_post_let_go_on_a_card_a_button_the_map_or_empty_space_returns_to_the_tray() -> void:
	var main := _main()
	tree.root.size = Vector2i(1280, 720)
	for screen in [main.home, main.journey, main.hero_page, main.keep_screen, main.summary]:
		screen.visible = false
	var plan: Control = main.planning
	plan.visible = true
	await tree.process_frame
	for name in ["a card", "Auto-place", "Quick start", "Start level", "Journey map", "the map's empty space", "the backdrop"]:
		plan.open("shingle_beach", ["spot_2"], false, HoldfastContent.base()["castle_rules"]["castle"]["spots"].slice(0, 4), 2)
		await tree.process_frame
		var spots := {
			"a card": plan._tray.get_child(1).get_global_rect().get_center(),
			"Auto-place": plan.get_node("%AutoButton").get_global_rect().get_center(),
			"Quick start": plan.get_node("%QuickButton").get_global_rect().get_center(),
			"Start level": plan.get_node("%StartButton").get_global_rect().get_center(),
			"Journey map": plan.get_node("%BackButton").get_global_rect().get_center(),
			"the map's empty space": plan._map.get_global_rect().position + Vector2(40, 40),
			"the backdrop": Vector2(640, 700),
		}
		var from: Vector2 = plan._site_buttons["spot_2"].get_global_rect().get_center()
		await _drag(from, spots[name])
		expect_eq(plan._chosen, [], "let go on %s: the post is back in the tray" % name)
	# A free slot still takes it, which moves the post rather than returning it.
	plan.open("shingle_beach", ["spot_2"], false, HoldfastContent.base()["castle_rules"]["castle"]["spots"].slice(0, 4), 2)
	await tree.process_frame
	await _drag(plan._site_buttons["spot_2"].get_global_rect().get_center(), plan._site_buttons["spot_1"].get_global_rect().get_center())
	expect_eq(plan._chosen, ["spot_1"], "a free slot moves it")
	main.free()
