extends KitTestCase
## HF-M2-78: the Hero page has four headline numbers (the "i" button shows them all), the special on
## its own card, the five slots around the Hero, a bag grid with a one-line wear cue and the next path
## as a goal; the Squad page shows each Recruit's class, post, trait and level, the slots used, and a
## plain "?" for each Recruit not yet found.

const Main := preload("res://scenes/main.tscn")
const Squad := preload("res://scripts/ui/recruits_page.gd")


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


func _hero(main: Node) -> Control:
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.call("_show", main.Screen.HERO)
	return main.hero_page


# ------------------------------------------------------------------ the Hero page

func test_the_hero_page_shows_four_headline_numbers_and_the_i_button_shows_them_all() -> void:
	var main := _main()
	var page := _hero(main)
	await _settle()
	var stats: Label = page.get_node("%Stats")
	expect_eq(stats.text.split("\n").size(), 4, "four numbers: %s" % stats.text)
	expect_true(stats.text.begins_with("Health "), "health first")
	expect_false(stats.text.contains("Pickup reach"), "the rest wait behind the i button")
	var info: Button = page.get_node("%StatsInfoButton")
	info.button_pressed = true
	info.pressed.emit()
	await _settle()
	expect_eq(stats.text.split("\n").size(), 9, "all nine with where they come from")
	expect_false(page.get_node("%Stage").visible, "the Hero and the slots make room for them")
	info.button_pressed = false
	info.pressed.emit()
	await _settle()
	expect_eq(stats.text.split("\n").size(), 4, "and back to four")
	expect_true(page.get_node("%Stage").visible)
	main.free()


func test_the_special_is_on_its_own_card_with_its_name_and_how_often_it_comes() -> void:
	var main := _main()
	var page := _hero(main)
	await _settle()
	var card: Control = page.get_node("%SpecialCard")
	expect_true(card is PanelContainer and card.visible, "its own card")
	expect_eq(page.get_node("%SpecialName").text, "Flare Barrage")
	expect_eq(page.get_node("%SpecialLine").text, "Special: Space, every 14 s")
	var stage: Rect2 = page.get_node("%Stage").get_global_rect()
	expect_true(stage.encloses(card.get_global_rect()), "it sits with the Hero, not among the numbers")
	for slot in page._slot_panels:
		expect_false(card.get_global_rect().intersects(page._slot_panels[slot].get_global_rect()), "and clear of the %s slot" % slot)
	main.free()


func test_the_five_slots_stand_on_both_sides_of_the_hero() -> void:
	var main := _main()
	var page := _hero(main)
	await _settle()
	var middle: float = page.get_node("%Stage").get_global_rect().get_center().x
	var left := 0
	var right := 0
	for slot in page._slot_panels:
		var rect: Rect2 = page._slot_panels[slot].get_global_rect()
		left += 1 if rect.end.x <= middle - page.FIGURE_HALF else 0
		right += 1 if rect.position.x >= middle + page.FIGURE_HALF else 0
	expect_eq(left + right, 5, "none of them on the Hero")
	expect_true(left >= 2 and right >= 2, "around the Hero (%d, %d)" % [left, right])
	main.free()


func test_the_bag_is_a_grid_with_a_one_line_cue_that_stays_while_there_are_pieces() -> void:
	var main := _main()
	var page := _hero(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data["gear"]["owned"] = ["driftwood_stave", "wave_worn_boots", "storm_cap"]
	profile.changed.emit()
	await _settle()
	var bag: GridContainer = page.get_node("%Bag")
	expect_eq(bag.get_child_count(), 3, "three pieces in the bag")
	var hint: Label = page.get_node("%BagHint")
	expect_eq(hint.text, page.WEAR_HINT)
	expect_eq(hint.autowrap_mode, TextServer.AUTOWRAP_OFF, "one line")
	expect_true(hint.size.y < hint.get_theme_font(&"font").get_height(hint.get_theme_font_size(&"font_size")) * 2.0, "and one line high (%s)" % hint.size.y)
	profile.wear_gear("wave_worn_boots")
	await _settle()
	expect_eq(hint.text, page.WEAR_HINT, "still there with a piece on")
	main.free()


func test_the_goal_names_the_next_path_and_what_opens_it() -> void:
	var main := _main()
	var page := _hero(main)
	await _settle()
	var goal: Label = page.get_node("%GoalLine")
	expect_eq(goal.text, "Dusk Mage: boss, level 5", "the path, and the boss level that opens it")
	expect_true(page.get_node("%GoalRow").visible)
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data["levels_won"].append("gull_rock")
	profile.changed.emit()
	await _settle()
	expect_false(page.get_node("%GoalRow").visible, "once it is open there is no goal (the last path has no level yet)")
	main.free()


# ------------------------------------------------------------------ the Squad page

func _squad_main() -> Array:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["gold"] = 100000
	profile.hire(0)
	profile.changed.emit()
	main.call("_show", main.Screen.RECRUITS)
	return [main, profile, main.recruits_page]


func test_the_squad_line_says_slots_and_how_many_are_used() -> void:
	expect_eq(Squad.slots_text(1, 2), "2 slots, 1 used")
	expect_eq(Squad.slots_text(0, 1), "1 slot, 0 used")
	var set := _squad_main()
	var main: Node = set[0]
	var profile: HoldfastProfile = set[1]
	var page: Control = set[2]
	await _settle()
	var used: int = profile.get_squad_ids().size()
	expect_eq(page._slots_line.text, Squad.slots_text(used, profile.get_squad_slots()))
	expect_eq(page._title.text, "Squad", "one word")
	main.free()


func test_each_recruit_card_has_class_post_trait_and_level() -> void:
	var set := _squad_main()
	var main: Node = set[0]
	var profile: HoldfastProfile = set[1]
	var page: Control = set[2]
	var recruit: Dictionary = profile.get_recruits()[0]
	if not str(recruit["id"]) in profile.get_squad_ids():
		profile.toggle_squad(str(recruit["id"]))
	profile.post_recruit("spot_2", str(recruit["id"]))
	await _settle()
	var lines: PackedStringArray = page._cards[str(recruit["id"])].text.split("\n")
	var cls: String = HoldfastContent.base()["recruit_classes"][recruit["class"]]["name"]
	var trait_name: String = HoldfastContent.base()["recruit_traits"][recruit["traits"][0]]["name"]
	expect_eq(lines.size(), 4, "four lines: %s" % lines)
	expect_eq(lines[0], "%s, level %d" % [recruit["name"], RecruitRoster.level_of(recruit, HoldfastContent.base())], "name and level")
	expect_eq(lines[1], cls, "the class")
	expect_eq(lines[2], "Post: West", "the post it stands on")
	expect_eq(lines[3], trait_name, "the trait")
	expect_true(page._cards[str(recruit["id"])].icon != null, "a Recruit found has their class's picture")
	profile.toggle_squad(str(recruit["id"]))
	await _settle()
	expect_eq(page._cards[str(recruit["id"])].text.split("\n")[2], "Off the squad", "a Recruit off the squad has no post")
	main.free()


func test_a_recruit_not_found_is_a_plain_question_mark_with_no_class_or_picture() -> void:
	var set := _squad_main()
	var main: Node = set[0]
	var profile: HoldfastProfile = set[1]
	var page: Control = set[2]
	await _settle()
	var rescues: Array = HoldfastContent.base()["recruit_rescues"].values()
	var found := 0
	for rescue in rescues:
		found += 0 if profile.get_recruit(str(rescue["id"])).is_empty() else 1
	expect_eq(page._unfound.size(), rescues.size() - found, "one for each Recruit not found")
	expect_true(page._unfound.size() > 0, "there is one to see")
	for card in page._unfound:
		var texts: Array = card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		expect_eq(texts, ["?"], "only a question mark")
		expect_eq(card.find_children("*", "TextureRect", true, false).size(), 0, "no picture")
		expect_true(card.find_children("*", "Button", true, false).is_empty(), "nothing to press")
	main.free()
