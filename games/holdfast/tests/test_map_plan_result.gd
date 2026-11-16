extends KitTestCase
## HF-M2-77: the Map names the boss by its level name with one next-goal line and no chapter count; Plan
## has one Start button, the route drawn on the field, a tower count with "Add a tower" in one tile, the
## blessing choice with None and a Squad tile only after the first rescue; the result has three star
## slots over a Keep-health bar with its marks, coins and stars gained, an Unlocked list read from the
## pack, the Salvaged line, no explaining line, and Spend stars as the main button while a guided buy waits.

const Main := preload("res://scenes/main.tscn")
const Summary := preload("res://scripts/ui/run_summary.gd")


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


func _content() -> Dictionary:
	return HoldfastContent.base()


func _texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.is_visible_in_tree()).map(func(l: Label) -> String: return l.text)


# ------------------------------------------------------------------ the map

func test_the_map_is_one_word_with_one_goal_line_that_names_the_boss_by_its_level() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.begin_stand()
	main.call("_show", main.Screen.MAP)
	await _settle()
	var map: Control = main.journey
	expect_eq(map.get_node("Margin/Column/Header/Title").text, "Map", "the screen is called Map")
	var info: Label = map.get_node("%Info")
	expect_eq(info.text, "Next: The Outpost, then Fog Warden at Gull Rock", "the goal names the boss by its level")
	expect_eq(info.autowrap_mode, TextServer.AUTOWRAP_OFF, "one line, not a paragraph")
	expect_true(info.size.y < info.get_theme_font(&"font").get_height(info.get_theme_font_size(&"font_size")) * 2.0, "and it is one line high (%s)" % info.size.y)
	for text in _texts(map):
		expect_false(text.to_lower().contains("chapter") or text.contains(" of 5"), "no chapter count: %s" % text)
	expect_eq(map._names["gull_rock"].text, "Gull Rock\nBoss: Fog Warden", "the boss's node keeps its level name")
	main.free()


# ------------------------------------------------------------------ Plan

func _plan(main: Node) -> Control:
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	main.journey.level_requested.emit("outpost")
	return main.planning


func test_plan_has_one_start_button_and_a_tower_count_with_add_a_tower_in_one_tile() -> void:
	var main := _main()
	var plan := _plan(main)
	await _settle()
	var starts := plan.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.begins_with("Start") or b.text.begins_with("Quick"))
	expect_eq(starts.size(), 1, "one Start button")
	expect_eq(starts[0].text.split("\n")[0], "Start level")
	var count: Control = plan.get_node("%Count")
	var tower: Button = plan.get_node("%TowerButton")
	var tile: Node = count.get_parent().get_parent()
	expect_true(tile is PanelContainer and tile == tower.get_parent().get_parent(), "the count and the button are in one tile")
	main.get_node("Profile").data["stars"]["first_watch"] = 5
	main.get_node("Profile").changed.emit()
	main.call("_offer_tower")
	await _settle()
	expect_true(tower.visible and tower.text.begins_with("Add a tower"), "the button says Add a tower (%s)" % tower.text)
	expect_false(plan.get_node("%Hint").text.contains("Drag a post") or plan.get_node("%Hint").text.contains("press a spot"), "nothing explains how to place a post")
	main.free()


func test_plan_draws_the_route_from_each_spawn_arc_to_the_keep() -> void:
	var main := _main()
	var plan := _plan(main)
	await _settle()
	var arcs: Array = _content()["levels"]["outpost"]["spawn_arcs"]
	var lines: Array = plan.route_lines()
	expect_eq(lines.size(), arcs.size(), "a route for each place they come from")
	var map: Rect2 = Rect2(Vector2.ZERO, plan.get_node("%Map").size)
	var centre := map.get_center()
	for line in lines:
		expect_true(map.grow(1.0).has_point(line[0]), "it starts on the field (%s)" % line[0])
		expect_true(line[1].distance_to(centre) < line[0].distance_to(centre), "and runs in to the keep")
		expect_true(line[1].distance_to(centre) > float(_content()["levels"]["outpost"]["keep_radius"]) * plan._scale(), "stopping at its wall")
	main.free()


func test_the_blessing_choice_ends_in_none_and_offers_only_what_is_given() -> void:
	var main := _main()
	var plan := _plan(main)
	plan.set_blessings(["steady_flame"])
	expect_eq(plan._blessing_buttons.keys(), ["steady_flame", ""])
	expect_eq(plan._blessing_buttons[""].text, "None")
	expect_true(plan._blessing_buttons[""].button_pressed, "None is picked to begin with")
	main.free()


func test_the_squad_tile_waits_for_the_first_rescue() -> void:
	var main := _main()
	var plan := _plan(main)
	plan.set_squad([], 0)
	await _settle()
	expect_false(plan.get_node("%SquadTile").visible or plan.get_node("%SquadButton").is_visible_in_tree(), "no Recruit yet, no Squad tile")
	plan.set_squad(["Wren"], 1)
	await _settle()
	expect_true(plan.get_node("%SquadTile").visible and plan.get_node("%SquadButton").is_visible_in_tree(), "after the first rescue it is there")
	main.free()


# ------------------------------------------------------------------ the result

func _show(main: Node, result: Dictionary, extra := {}, next := "") -> Control:
	var summary: Dictionary = {"gold_earned": 340, "waves_cleared": 8, "total_waves": 8, "keep_fell": false, "stars_paid": 2, "reward_gold": 0, "keep_health": 72, "keep_health_max": 100, "result": result, "notes": {}, "unlocks": []}
	summary.merge(extra, true)
	main.summary.show_summary(summary, next)
	main.summary.visible = true
	return main.summary


func test_the_result_has_three_star_slots_lit_for_the_keep_health_with_the_marks_on_the_bar() -> void:
	var main := _main()
	for case in [[0.9, 3], [0.6, 2], [0.3, 1]]:
		var page := _show(main, {"outcome": "won", "level": "shingle_beach", "keep_left": case[0]}, {"keep_health": case[0] * 100.0})
		await _settle()
		var row: Control = page.get_node("%StarRow")
		expect_eq(row.get_child_count(), 3, "three slots")
		var lit := 0
		for slot in row.get_children():
			if slot.modulate.a > 0.9:
				lit += 1
		expect_eq(lit, case[1], "%d stars at %s of the Keep left" % [case[1], case[0]])
		var bar: Control = page.get_node("%KeepBar")
		expect_true(bar.size.y <= 12.0, "the bar is thin (%s)" % bar.size.y)
		expect_near(page._keep_left, case[0], 0.001, "and filled to the Keep's health")
		expect_eq(page._tiers.map(func(t: Dictionary) -> float: return float(t["above"])), [0.5, 0.8], "with a mark where each extra star is earned")
	main.free()


func test_the_result_shows_the_coins_and_stars_gained_with_their_pictures() -> void:
	var main := _main()
	var page := _show(main, {"outcome": "won", "level": "shingle_beach", "keep_left": 0.72})
	await _settle()
	expect_eq(page.get_node("%GoldValue").text, "340")
	expect_eq(page.get_node("%StarsValue").text, "+2")
	expect_eq(page.get_node("Centre/Row/Panel/Column/Stats/Gold/GoldIcon").texture.resource_path.get_file(), "coin.svg")
	expect_eq(page.get_node("Centre/Row/Panel/Column/Stats/Stars/StarsIcon").texture.resource_path.get_file(), "star.svg")
	main.free()


func test_the_unlocked_list_is_read_from_the_pack_with_an_icon_each_and_salvage_on_its_own_line() -> void:
	var main := _main()
	var content := _content()
	var before := HoldfastMeta.new_profile(content)
	var result := {"outcome": HoldfastRules.OUTCOME_WON, "level": "first_watch", "gold": 0, "keep_left": 0.9, "salvaged": 45}
	var after := HoldfastMeta.bank_run(content, before, result)
	var unlocks := HoldfastMeta.unlocks(content, before, after, result)
	var page := _show(main, result, {"unlocks": unlocks})
	await _settle()
	var list: VBoxContainer = page.get_node("%UnlockedList")
	expect_true(page.get_node("%Unlocked").visible, "the list is there")
	var blessing: Dictionary = content["blessings"]["steady_flame"]
	var row: HBoxContainer = list.get_child(0)
	expect_eq(row.get_child(1).text, "%s: %s" % [blessing["name"], blessing["text"]], "the blessing in the pack's own words")
	expect_eq(row.get_child(0).texture.resource_path.get_file(), "unlock_blessing.svg", "with its own icon, not the flame")
	expect_eq(list.get_child_count(), 1, "the salvage is not a row")
	expect_eq(page.get_node("%Salvaged").text, "Salvaged: 45 gold")
	expect_true(page.get_node("%Salvaged").visible)
	var none := _show(main, result, {"unlocks": [], "result": {"outcome": "won", "level": "first_watch", "keep_left": 0.9}})
	expect_false(none.get_node("%Unlocked").visible, "nothing unlocked, no list")
	expect_false(none.get_node("%Salvaged").visible, "nothing salvaged, no line")
	main.free()


func test_each_kind_of_unlock_has_its_own_picture() -> void:
	var seen := {}
	for kind in Summary.UNLOCK_ICONS:
		var path: String = "res://assets/ui/icons/%s.svg" % Summary.UNLOCK_ICONS[kind]
		expect_true(ResourceLoader.exists(path), "%s: %s is there" % [kind, path])
		seen[path] = true
	expect_eq(seen.size(), Summary.UNLOCK_ICONS.size(), "no two kinds share one")


func test_the_main_button_is_spend_stars_while_a_guided_buy_waits_and_the_result_never_explains_stars() -> void:
	var main := _main()
	main.call("_new_game")
	main.call("_on_run_ended", {"gold_earned": 50, "waves_cleared": 2, "total_waves": 2, "keep_fell": false, "keep_health": 100, "keep_health_max": 100, "result": {"outcome": "won", "level": "first_watch", "gold": 50, "keep_left": 1.0}})
	await _settle()
	var page: Control = main.summary
	expect_true(page.get_node("%SpendButton").visible, "a guided buy is waiting: Spend stars")
	expect_eq(page.get_node("%SpendButton").text, "Spend stars")
	expect_eq(page.get_node("%SpendButton").theme_type_variation, &"MainButton", "and it is the main button")
	expect_false(page.get_node("%NextLevelButton").visible, "not Next level")
	expect_eq(page.get_node("%PlayAgainButton").theme_type_variation, &"", "Play again is not")
	for text in _texts(page):
		expect_false(text.contains("Stars buy"), "no explaining line: %s" % text)
	var asked := []
	page.tree_requested.connect(func() -> void: asked.append(true))
	page.get_node("%SpendButton").pressed.emit()
	expect_eq(asked.size(), 1, "it goes to the tree")
	main.get_node("Profile").data["upgrades"] = ["castle_slot_1", "castle_archer_1"]
	main.call("_on_run_ended", {"gold_earned": 50, "waves_cleared": 2, "total_waves": 2, "keep_fell": false, "keep_health": 100, "keep_health_max": 100, "result": {"outcome": "won", "level": "outpost", "gold": 50, "keep_left": 1.0}})
	await _settle()
	expect_false(page.get_node("%SpendButton").visible, "once the buys are made it is gone")
	expect_true(page.get_node("%NextLevelButton").visible and page.get_node("%NextLevelButton").theme_type_variation == &"MainButton", "and Next level is the main button")
	main.free()
