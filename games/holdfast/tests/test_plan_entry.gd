extends KitTestCase
## HF-M2-53: the journey map opens the Plan page itself. The button is short-named and looks like
## the others in the header, is shut during the compulsory guide, the Start step and a run, never
## starts a level, and the Plan page's Back returns to the map.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1100, 650)]


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _plan_button(main: Node) -> Button:
	return main.journey.get_node("%PlanButton")


## A player past Level 0 with both guided buys made and the short fight done.
func _past_level_zero(main: Node) -> void:
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.get_node("Profile").data = HoldfastMeta.begin_stand(main.get_node("Profile").data)
	main.get_node("Profile").changed.emit()
	main.call("_show", main.Screen.MAP)


func test_the_plan_button_opens_the_plan_page_for_the_next_level_and_back_returns() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	_past_level_zero(main)
	var button := _plan_button(main)
	expect_eq(button.text, "Plan")
	expect_false(button.disabled)
	button.pressed.emit()
	expect_eq(main.screen, main.Screen.PLAN, "the Plan page is open")
	expect_eq(main.get_node("Profile").get_level(), "outpost", "on the next level to win")
	expect_false(source.is_running(), "and nothing started")
	main.planning.back_requested.emit()
	expect_eq(main.screen, main.Screen.MAP, "Back returns to the map")
	expect_false(source.is_running())
	main.free()


func test_a_press_on_the_plan_button_never_starts_a_level_and_only_a_start_on_the_page_does() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	_past_level_zero(main)
	_plan_button(main).pressed.emit()
	expect_false(source.is_running())
	main.planning.start_requested.emit([])
	expect_false(source.is_running(), "an empty plan starts nothing")
	main.free()


func test_the_plan_button_is_shut_during_the_guide_the_start_step_and_a_run() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	var content := HoldfastContent.base()
	main.call("_new_game")
	expect_true(_plan_button(main).disabled, "a new game has nothing to plan")
	profile.data = HoldfastMeta.bank_run(content, HoldfastMeta.new_profile(content), {"outcome": "won", "level": "first_watch", "gold": 0})
	profile.changed.emit()
	expect_true(_plan_button(main).disabled, "shut during the compulsory guide")
	main.call("_plan_from_map", "outpost")
	expect_eq(main.screen, main.Screen.MAP, "and the flow ignores it too")
	for id in ["castle_slot_1", "castle_archer_1"]:
		profile.buy(id)
	expect_true(_plan_button(main).disabled, "shut at the Start step")
	main.call("_plan_from_map", "outpost")
	expect_eq(main.screen, main.Screen.MAP)
	main.journey.stand_requested.emit()
	expect_true(source.is_running())
	main.call("_plan_from_map", "outpost")
	expect_eq(main.screen, main.Screen.RUN, "a run in progress cannot be left for the Plan page")
	source.step(1000.0)
	main.free()


func test_only_the_map_can_open_the_plan_page_this_way_and_never_for_the_tutorial() -> void:
	var main := _main()
	_past_level_zero(main)
	for screen in [main.Screen.HOME, main.Screen.TREE, main.Screen.HERO, main.Screen.SUMMARY]:
		main.call("_show", screen)
		main.call("_plan_from_map", "outpost")
		expect_eq(main.screen, screen, "ignored away from the map")
	main.call("_show", main.Screen.MAP)
	main.call("_plan_from_map", "first_watch")
	expect_eq(main.screen, main.Screen.MAP, "the tutorial has no plan to make")
	main.call("_plan_from_map", "gull_rock")
	expect_eq(main.screen, main.Screen.MAP, "nor does a level still locked")
	main.free()


func test_the_button_aims_at_the_last_open_level_once_every_open_level_is_won() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var content := HoldfastContent.base()
	_past_level_zero(main)
	var ids: Array = content["levels"].keys().filter(func(id: String) -> bool: return not content["levels"][id].get("tutorial", false))
	for id in ids:
		profile.data = HoldfastMeta.bank_run(content, profile.data, {"outcome": "won", "level": id, "gold": 0})
	profile.changed.emit()
	_plan_button(main).pressed.emit()
	expect_eq(main.screen, main.Screen.PLAN)
	var open: Array = ids.filter(func(id: String) -> bool: return id in profile.get_unlocked_levels())
	expect_eq(profile.get_level(), open[-1], "the last open level, never the tutorial")
	main.free()


func test_the_plan_button_fits_the_header_and_looks_like_the_others_at_every_size() -> void:
	var main := _main()
	_past_level_zero(main)
	var journey: Control = main.journey
	var plan := _plan_button(main)
	var tree_button: Button = journey.get_node("%TreeButton")
	for window in WINDOWS:
		tree.root.size = window
		await tree.process_frame
		await tree.process_frame
		var label := "%dx%d" % [window.x, window.y]
		var to_window := tree.root.get_final_transform()
		var rect: Rect2 = to_window * plan.get_global_rect()
		expect_true(plan.is_visible_in_tree(), "%s: shown" % label)
		expect_true(rect.position.x >= 0.0 and rect.end.x <= float(window.x), "%s: inside the width (%s)" % [label, rect])
		expect_true(rect.position.y >= 0.0 and rect.end.y <= float(window.y), "%s: inside the height (%s)" % [label, rect])
		expect_true(plan.size.x >= plan.get_minimum_size().x, "%s: the word fits its button" % label)
		expect_eq(plan.get_theme_font_size("font_size"), tree_button.get_theme_font_size("font_size"), "%s: same type size as Skill tree" % label)
		expect_eq(plan.size.y, tree_button.size.y, "%s: same height as Skill tree" % label)
		for other in [journey.get_node("%BackButton"), tree_button, journey.get_node("%GoldValue"), journey.get_node("%StarsValue")]:
			expect_false(plan.get_global_rect().intersects(other.get_global_rect()), "%s: clear of %s" % [label, other.name])
	main.free()
