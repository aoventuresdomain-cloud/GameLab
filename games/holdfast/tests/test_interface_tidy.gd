extends KitTestCase
## HF-M2-40: short names and look instead of words. The journey map says nothing of locked, next
## or won; "Respec" is "Refund" wherever it shows; an owned tree node glows green and has no
## "bought" word; the Plan page has no red arcs; the Hero page has the Hero in the middle, the
## numbers on the left, the five gear slots on the right and the bag of pieces not worn below.

const Main := preload("res://scenes/main.tscn")
const STATE_WORDS := ["locked", "next", "open", "won", "bought"]


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _page_with(main: Node, owned: Array) -> Control:
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.bank_run({"outcome": "lost", "level": "outpost", "gold": 0, "gear_found": owned})
	for id in owned:
		profile.wear_gear(id) # a drop lands in the bag; the player puts it on
	profile.take_off_gear("weapon")
	return main.hero_page


## Every Label and Button text under `node` that is on show.
func _texts(node: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for child in node.get_children():
		if (child is Label or child is Button) and child.is_visible_in_tree():
			out.append(child.text)
		out.append_array(_texts(child))
	return out


func _has_word(text: String, word: String) -> bool:
	var found := false
	for part in text.to_lower().split(" ", false):
		if part.trim_suffix(".").trim_suffix(",").trim_suffix(":") == word:
			found = true
	return found


# ------------------------------------------------------------------ journey map

func test_the_journey_map_says_nothing_of_locked_next_open_or_won() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile: HoldfastProfile = main.get_node("Profile")
	for stage in 3:
		if stage == 1:
			ThroughLevelZero.apply(profile)
		if stage == 2:
			profile.bank_run({"outcome": "won", "level": "outpost", "gold": 0})
		map.refresh()
		for id in map._ids:
			for word in STATE_WORDS:
				expect_false(_has_word(map._names[id].text, word), "stage %d: %s caption has '%s'" % [stage, id, word])
				expect_false(_has_word(map._level_text(id), word), "stage %d: %s hover text has '%s'" % [stage, id, word])
	main.free()


func test_a_level_caption_is_its_name_then_the_boss_or_the_stars_it_earned() -> void:
	var main := _main()
	var map: Control = main.journey
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.bank_run({"outcome": "won", "level": "outpost", "gold": 0})
	map.refresh()
	var content := HoldfastContent.base()
	expect_eq(map._names["shingle_beach"].text, str(content["levels"]["shingle_beach"]["name"]), "the next level is a name and nothing else")
	expect_eq(map._names["old_pier"].text, str(content["levels"]["old_pier"]["name"]), "so is one out of reach")
	expect_eq(map._names["gull_rock"].text, "%s\nBoss: Fog Warden" % content["levels"]["gull_rock"]["name"], "a boss level names its boss")
	expect_true(map._names["outpost"].text.ends_with("\n1 of 3 stars"), map._names["outpost"].text)
	main.free()


func test_the_map_is_drawn_green_for_cleared_amber_for_next_and_dim_for_the_rest() -> void:
	var main := _main()
	var map: Control = main.journey
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.get_node("Profile").bank_run({"outcome": "won", "level": "outpost", "gold": 0})
	map.refresh()
	expect_eq(map._next, "shingle_beach", "the next level is the one that glows")
	expect_true(map.COLOUR_WON != map.COLOUR_OPEN and map.COLOUR_OPEN != map.COLOUR_LOCKED and map.COLOUR_GLOW != map.COLOUR_LOCKED, "the four looks differ")
	main.free()


# ------------------------------------------------------------------ Refund

func test_respec_is_called_refund_wherever_it_shows() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var screens := [main.home, main.journey, main.hero_page, main.keep_screen, main.planning, main.summary, main.hud]
	for screen in screens:
		screen.visible = true
	for stage in 2:
		if stage == 1:
			ThroughLevelZero.apply(profile)
			profile.changed.emit()
		for screen in screens:
			for text in _texts(screen):
				expect_false(text.to_lower().contains("respec"), "%s shows '%s'" % [screen.name, text])
	var button: Button = main.keep_screen.get_node("%RespecButton")
	expect_true(button.text.begins_with("Refund"), button.text)
	expect_true(button.text.contains("gold"), "it says what comes back in gold")
	profile.new_game()
	var notices: Array = []
	profile.notice.connect(func(text: String) -> void: notices.append(text))
	profile.respec()
	expect_eq(notices, ["Nothing to refund"], "a new game has nothing to take back")
	main.free()


# ------------------------------------------------------------------ the tree

func test_an_owned_node_glows_green_and_has_no_bought_word() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.changed.emit()
	var page: Control = main.keep_screen
	var slot: Button = page._node_buttons["castle_slot_1"]
	expect_eq(slot.text, "First Slot", "the name alone")
	expect_true(slot.get_theme_stylebox("disabled") == page._owned_style and slot.get_theme_stylebox("normal") == page._owned_style, "it glows")
	page.open_card("castle_slot_1")
	expect_false(TreeCard.text(page).to_lower().contains("bought"), TreeCard.text(page))
	page.close_card()
	var other: Button = page._node_buttons["castle_slot_2"]
	expect_false(other.get_theme_stylebox("normal") == page._owned_style, "a node not owned keeps the theme's look")
	profile.data["gold"] = 500
	profile.respec()
	expect_false(slot.get_theme_stylebox("normal") == page._owned_style, "and the glow goes with a refund")
	main.free()


# ------------------------------------------------------------------ Plan page

func test_the_plan_page_has_no_red_arcs_and_no_hint_about_them() -> void:
	var main := _main()
	var plan: Control = main.planning
	plan.open("outpost", [], false, HoldfastMeta.ring_spots(HoldfastContent.base()), 1, 0, 1)
	expect_false(plan.get_node("%Hint").text.to_lower().contains("red"), plan.get_node("%Hint").text)
	expect_false(plan.get_script().get_script_constant_map().has("COLOUR_ARC"), "the arc colour is gone")
	main.free()


# ------------------------------------------------------------------ Hero page

func test_the_hero_page_has_the_numbers_left_the_hero_in_the_middle_and_the_slots_right() -> void:
	var main := _main()
	var page := _page_with(main, ["driftwood_stave", "wave_worn_boots"])
	for window in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = window
		page.visible = true
		await tree.process_frame
		await tree.process_frame
		var stats: Rect2 = page.get_node("%Stats").get_global_rect()
		var figure: Rect2 = page.get_node("%HeroFigure").get_global_rect()
		var slots: Rect2 = page.get_node("%SlotColumn").get_global_rect()
		var bag: Rect2 = page.get_node("%Bag").get_global_rect()
		expect_true(stats.end.x <= figure.position.x + 0.5, "%s: numbers left of the Hero" % window)
		expect_true(figure.end.x <= slots.position.x + 0.5, "%s: slots right of the Hero" % window)
		expect_true(figure.size.x >= 100.0 and figure.size.y >= 150.0, "%s: the Hero has room (%s)" % [window, figure.size])
		expect_true(bag.position.y >= slots.end.y - 0.5 and bag.position.y >= figure.end.y - 0.5, "%s: the bag is below" % window)
		expect_true(tree.root.get_visible_rect().encloses(slots), "%s: the slots are on screen" % window)
	main.free()


func test_a_piece_worn_leaves_the_bag_and_comes_back_when_taken_off() -> void:
	var main := _main()
	var page := _page_with(main, ["driftwood_stave", "wave_worn_boots"])
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.take_off_gear("boots")
	var bag: HFlowContainer = page.get_node("%Bag")
	expect_eq(bag.get_child_count(), 2)
	profile.wear_gear("driftwood_stave")
	expect_eq(bag.get_child_count(), 1, "the worn one is on its slot, not in the bag")
	expect_eq(page._slot_panels["weapon"].get_node("Row/Item").text, "Driftwood stave")
	profile.take_off_gear("weapon")
	await tree.process_frame
	expect_eq(bag.get_child_count(), 2, "taken off, it is back")
	expect_eq(page._slot_panels["weapon"].get_node("Row/Item").text, "", "and the slot is empty")
	main.free()


func test_a_slot_with_a_piece_glows_green_and_an_empty_one_does_not() -> void:
	var main := _main()
	var page := _page_with(main, ["driftwood_stave"])
	var profile: HoldfastProfile = main.get_node("Profile")
	var weapon: PanelContainer = page._slot_panels["weapon"]
	var empty_look := weapon.get_theme_stylebox("panel")
	profile.wear_gear("driftwood_stave")
	var worn_look := weapon.get_theme_stylebox("panel")
	expect_true(worn_look is StyleBoxFlat and (worn_look as StyleBoxFlat).bg_color == page.COLOUR_WORN, "worn: green")
	profile.take_off_gear("weapon")
	expect_false(weapon.get_theme_stylebox("panel") is StyleBoxFlat and (weapon.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == page.COLOUR_WORN, "empty: plain again")
	expect_true(empty_look != worn_look)
	main.free()


func test_a_slot_names_what_it_is_for_on_hover_not_in_its_label() -> void:
	var main := _main()
	var page: Control = main.hero_page
	var boots: PanelContainer = page._slot_panels["boots"]
	expect_eq(boots.get_node("Row/Title").text, "Boots")
	expect_eq(boots.tooltip_text, "Boots: move speed, faster get-up")
	main.free()


func test_the_numbers_show_the_totals_and_the_i_button_adds_where_they_come_from() -> void:
	var main := _main()
	var page := _page_with(main, ["wave_worn_boots"])
	var stats: Label = page.get_node("%Stats")
	expect_true(stats.text.contains("Move speed 195"), stats.text)
	expect_false(stats.text.contains("base"), "totals only to start with")
	var info: Button = page.get_node("%StatsInfoButton")
	info.button_pressed = true
	info.pressed.emit()
	expect_true(stats.text.contains("Move speed 195 (base 170, tree 0, gear +25)"), stats.text)
	info.button_pressed = false
	info.pressed.emit()
	expect_false(stats.text.contains("base"), "and back")
	main.free()


func test_the_skill_tree_button_is_short_whichever_path_is_picked() -> void:
	var main := _main()
	var page: Control = main.hero_page
	for id in HoldfastContent.base()["hero_paths"]:
		main.get_node("Profile").select_pillar(id)
		expect_eq(page.get_node("%TreeButton").text, "Skill tree", id)
	main.free()
