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


func _open(level := "shingle_beach", layout: Array = [], saved := false) -> Control:
	var plan: Control = _main().planning
	plan.open(level, layout, saved)
	return plan


func _card(from := "") -> Dictionary:
	return {"kind": "tower", "tower": "archer_post", "from": from}


func test_a_first_visit_has_empty_slots_one_card_per_allowed_post_and_nothing_to_start() -> void:
	var plan := _open("shingle_beach")
	expect_eq(plan._chosen, [])
	expect_eq(plan._tray.get_child_count(), 2, "the pack allows two posts here")
	expect_true(plan.get_node("%StartButton").disabled, "no post, no start")
	expect_true(plan.get_node("%QuickButton").disabled, "no last layout yet")
	expect_eq(plan.get_node("%Count").text, "Posts: 0 of 2")
	plan.get_parent().get_parent().free()


func test_the_outpost_allows_one_card() -> void:
	var plan := _open("outpost")
	expect_eq(plan._tray.get_child_count(), 1)
	plan.get_parent().get_parent().free()


func test_auto_place_is_the_suggested_layout_and_lets_the_player_start() -> void:
	var plan := _open("shingle_beach")
	plan.get_node("%AutoButton").pressed.emit()
	expect_eq(plan._chosen, HoldfastRules.best_layout(HoldfastContent.base()["levels"]["shingle_beach"]))
	expect_eq(plan._chosen.size(), 2)
	expect_false(plan.get_node("%StartButton").disabled)
	expect_eq(plan.get_node("%Count").text, "Posts: 2 of 2")
	plan.get_parent().get_parent().free()


func test_dragging_a_card_onto_an_empty_slot_places_it_until_the_limit() -> void:
	var plan := _open("shingle_beach")
	expect_true(plan._slot_can_drop(Vector2.ZERO, _card(), "west_gate"))
	plan._slot_drop(Vector2.ZERO, _card(), "west_gate")
	expect_eq(plan._chosen, ["west_gate"])
	expect_false(plan._slot_can_drop(Vector2.ZERO, _card(), "west_gate"), "a slot already holding a post takes no card")
	plan._slot_drop(Vector2.ZERO, _card(), "east_gate")
	expect_eq(plan._chosen, ["west_gate", "east_gate"])
	expect_false(plan._slot_can_drop(Vector2.ZERO, _card(), "south_gate"), "no card left in hand")
	plan._slot_drop(Vector2.ZERO, _card(), "south_gate")
	expect_eq(plan._chosen, ["west_gate", "east_gate"], "a refused drop changes nothing")
	plan.get_parent().get_parent().free()


func test_a_drop_that_is_not_a_tower_card_is_refused() -> void:
	var plan := _open("shingle_beach")
	for bad in [null, "x", {}, {"kind": "wall", "from": ""}]:
		expect_false(plan._slot_can_drop(Vector2.ZERO, bad, "west_gate"))
	expect_false(plan._side_can_drop(Vector2.ZERO, _card()), "a card from the tray has nothing to return")
	plan.get_parent().get_parent().free()


func test_a_placed_post_can_be_moved_to_another_slot_keeping_its_place_in_order() -> void:
	var plan := _open("shingle_beach", ["west_gate", "east_gate"])
	var data: Variant = plan._slot_drag(Vector2.ZERO, "west_gate", plan._site_buttons["west_gate"])
	expect_eq(data, _card("west_gate"))
	expect_false(plan._slot_can_drop(Vector2.ZERO, data, "east_gate"), "not onto another post")
	plan._slot_drop(Vector2.ZERO, data, "south_gate")
	expect_eq(plan._chosen, ["south_gate", "east_gate"])
	plan.get_parent().get_parent().free()


func test_an_empty_slot_has_nothing_to_drag() -> void:
	var plan := _open("shingle_beach")
	expect_true(plan._slot_drag(Vector2.ZERO, "west_gate", plan._site_buttons["west_gate"]) == null)
	plan.get_parent().get_parent().free()


func test_dropping_a_lifted_post_on_the_card_side_returns_its_card() -> void:
	var plan := _open("shingle_beach", ["west_gate", "east_gate"])
	expect_true(plan._side_can_drop(Vector2.ZERO, _card("east_gate")))
	plan._side_drop(Vector2.ZERO, _card("east_gate"))
	expect_eq(plan._chosen, ["west_gate"])
	expect_eq(plan.get_node("%Count").text, "Posts: 1 of 2")
	expect_false(plan._side_can_drop(Vector2.ZERO, _card("east_gate")), "it is no longer placed")
	plan.get_parent().get_parent().free()


func test_placed_cards_wait_greyed_and_cards_in_hand_are_lit() -> void:
	var plan := _open("shingle_beach", ["west_gate"])
	expect_eq(plan._tray.get_child(0).modulate, Color(1, 1, 1, 0.45), "placed")
	expect_eq(plan._tray.get_child(1).modulate, Color.WHITE, "in hand")
	plan.get_parent().get_parent().free()


func test_quick_start_reuses_the_last_layout_and_is_greyed_without_one() -> void:
	var plan := _open("shingle_beach", ["east_gate", "south_gate"], true)
	expect_false(plan.get_node("%QuickButton").disabled)
	var heard := []
	plan.start_requested.connect(func(layout: Array) -> void: heard.append(layout))
	plan._chosen = ["west_gate"]
	plan.get_node("%QuickButton").pressed.emit()
	expect_eq(heard, [["east_gate", "south_gate"]], "the saved one, whatever is placed now")
	plan.get_parent().get_parent().free()


func test_the_flow_opens_empty_the_first_time_then_with_the_last_layout() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	main.journey.level_requested.emit("outpost")
	expect_eq(main.planning._chosen, [], "first visit")
	expect_true(main.planning.get_node("%QuickButton").disabled)
	main.planning._site_buttons["north_gate"].pressed.emit()
	main.planning.get_node("%StartButton").pressed.emit()
	expect_true(profile.has_saved_layout("outpost"))
	main.free()
	var again := _main()
	again.get_node("Profile").set_layout("outpost", ["north_gate"])
	again.journey.level_requested.emit("outpost")
	expect_eq(again.planning._chosen, ["north_gate"], "kept for the next visit")
	expect_false(again.planning.get_node("%QuickButton").disabled)
	again.planning.get_node("%QuickButton").pressed.emit()
	expect_true(again.get_node("RunSource").is_running() and again.hud.visible, "Quick start starts the level")
	expect_eq(again.get_node("RunSource").get_rules().layout_ids, ["north_gate"])
	again.free()


func test_a_layout_is_saved_only_when_valid_so_quick_start_never_reuses_a_bad_one() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	expect_false(HoldfastMeta.has_saved_layout(content, profile, "shingle_beach"))
	profile["layouts"]["shingle_beach"] = ["west_gate", "no_such_site"]
	expect_false(HoldfastMeta.has_saved_layout(content, profile, "shingle_beach"), "an invalid one is not a saved layout")
	profile["layouts"]["shingle_beach"] = ["west_gate", "east_gate"]
	expect_true(HoldfastMeta.has_saved_layout(content, profile, "shingle_beach"))
	expect_false(HoldfastMeta.has_saved_layout(content, profile, "tidewrack_cove"), "a level with no sites has none")
