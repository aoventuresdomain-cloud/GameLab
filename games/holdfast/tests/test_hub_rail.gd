extends KitTestCase
## HF-M2-73: the left rail on every hub screen (Map, Tree, Hero, Menu; Squad once a Recruit has
## joined), back always going to the parent, the Menu tab, and the home screen with its lighthouse.

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://hub_rail_tests"

const HUBS := {"Map": "journey", "Tree": "keep_screen", "Hero": "hero_page", "Squad": "recruits_page", "Menu": "menu"}


func _main(path: String = "", settings_path: String = "") -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	if path != "":
		main.get_node("Profile").save_path = path
	if settings_path != "":
		main.get_node("Settings").save_path = settings_path
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


## A game past the guide with one Recruit on the roster, so every tab is open.
func _with_a_recruit(main: Node) -> HoldfastProfile:
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["gold"] = 100000
	profile.hire(0)
	profile.changed.emit()
	return profile


func _visible_hubs(main: Node) -> Array:
	var out := []
	for tab in HUBS:
		if main.get(HUBS[tab]).visible:
			out.append(tab)
	return out


# ------------------------------------------------------------------ what the rail holds

func test_every_hub_screen_has_the_rail_with_one_word_tabs_and_marks_its_own() -> void:
	var main := _main()
	_with_a_recruit(main)
	for tab in HUBS:
		var screen: Control = main.get(HUBS[tab])
		var rail: HubRail = screen.rail
		expect_true(rail != null, "%s has the rail" % tab)
		expect_eq(rail.current, tab, "%s marks itself" % tab)
		expect_true(rail.tab(tab).button_pressed, "%s shows its own tab as the one in use" % tab)
		for name in ["Map", "Tree", "Hero", "Menu"]:
			expect_true(rail.tab(name).visible, "%s: %s is there" % [tab, name])
			expect_false(" " in rail.tab(name).text, "%s: %s is one word" % [tab, name])
			expect_true(rail.tab(name).custom_minimum_size.y >= 44.0, "%s: %s is a 44 px target" % [tab, name])
	main.free()


func test_squad_joins_the_rail_only_after_the_first_recruit() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	for tab in HUBS:
		expect_false(main.get(HUBS[tab]).rail.tab("Squad").visible, "%s: no Squad yet" % tab)
	profile.data["gold"] = 100000
	profile.hire(0)
	for tab in HUBS:
		expect_true(main.get(HUBS[tab]).rail.tab("Squad").visible, "%s: Squad after the first Recruit" % tab)
	main.free()


func test_a_dot_means_something_is_waiting_there() -> void:
	var main := _main()
	var profile := _with_a_recruit(main)
	var rail: HubRail = main.journey.rail
	expect_false(rail.has_dot("Squad"), "a Recruit with nothing to pick has no dot")
	profile.data["recruits"]["roster"][0]["xp"] = 50
	profile.changed.emit()
	expect_eq(rail.has_dot("Squad"), not profile.get_pending_picks().is_empty(), "a skill pick waiting puts a dot on Squad")
	expect_false(rail.has_dot("Map") or rail.has_dot("Menu"), "Map and Menu never ask for anything")
	main.free()


func test_the_guide_shuts_tree_hero_and_squad_and_asks_with_no_dots() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var content := HoldfastContent.base()
	profile.data = HoldfastMeta.bank_run(content, HoldfastMeta.new_profile(content), {"outcome": "won", "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	profile.changed.emit()
	var rail: HubRail = main.journey.rail
	expect_true(rail.tab("Tree").disabled and rail.tab("Hero").disabled, "shut while the guide has a buy due")
	expect_false(rail.tab("Map").disabled or rail.tab("Menu").disabled, "Map and Menu stay open")
	for tab in HUBS:
		expect_false(rail.has_dot(tab), "%s: no dot while the guide asks" % tab)
	main.free()


# ------------------------------------------------------------------ going places

func test_every_tab_reaches_its_screen_from_every_hub_screen() -> void:
	var main := _main()
	_with_a_recruit(main)
	for from in HUBS:
		for to in HUBS:
			main.call("_show", main.Screen.MAP)
			main.get(HUBS[from]).visible = true
			for other in HUBS:
				if other != from:
					main.get(HUBS[other]).visible = false
			main.get(HUBS[from]).rail.press(to)
			if from == to:
				expect_eq(_visible_hubs(main), [to], "%s to %s stays where it is" % [from, to])
			else:
				expect_eq(_visible_hubs(main), [to], "%s to %s" % [from, to])
	main.free()


func test_a_real_click_on_a_tab_goes_there() -> void:
	var main := _main()
	_with_a_recruit(main)
	main.call("_show", main.Screen.MAP)
	await tree.process_frame
	await tree.process_frame
	var button: Button = main.journey.rail.tab("Hero")
	var at := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		tree.root.push_input(click)
	expect_true(main.hero_page.visible and not main.journey.visible, "pressing the tab opens the Hero page")
	main.free()


func test_the_paths_the_rail_replaced_are_still_there() -> void:
	var main := _main()
	var profile := _with_a_recruit(main)
	profile.data = HoldfastMeta.begin_stand(profile.data)
	profile.changed.emit()
	main.call("_show", main.Screen.MAP)
	main.journey.get_node("%PlanButton").pressed.emit()
	expect_true(main.planning.visible, "the map's Plan button opens the Plan page")
	main.planning.back_requested.emit()
	expect_true(main.journey.visible, "and Plan goes back to the map")
	main.journey._hero_figure.pressed.emit()
	expect_true(main.hero_page.visible, "the Hero on the map opens the Hero page")
	main.hero_page.get_node("%TreeButton").pressed.emit()
	expect_true(main.keep_screen.visible, "the Hero page's Skill tree shortcut opens the tree")
	main.summary.show_summary({"gold_earned": 0, "waves_cleared": 1, "total_waves": 2, "keep_fell": true})
	main.call("_show", main.Screen.SUMMARY)
	main.summary.get_node("%TreeButton").pressed.emit()
	expect_true(main.keep_screen.visible, "the result page's Skill tree link opens the tree")
	main.free()


func test_back_goes_to_the_parent_screen() -> void:
	var main := _main()
	_with_a_recruit(main)
	for tab in ["Tree", "Hero", "Squad", "Menu"]:
		main.journey.rail.press(tab)
		expect_eq(_visible_hubs(main), [tab])
		if tab == "Squad":
			main.recruits_page.back_requested.emit()
		else:
			main.get(HUBS[tab]).get_node("%BackButton").pressed.emit()
		expect_eq(_visible_hubs(main), ["Map"], "back from %s goes to the map" % tab)
	main.journey.get_node("%BackButton").pressed.emit()
	expect_true(main.home.visible, "back from the map goes to the title")
	main.home.settings_requested.emit()
	main.settings_screen.get_node("%BackButton").pressed.emit()
	expect_true(main.home.visible, "Settings opened from the title goes back to it")
	main.call("_show", main.Screen.MENU)
	main.menu.settings_requested.emit()
	main.settings_screen.get_node("%BackButton").pressed.emit()
	expect_true(main.menu.visible, "Settings opened from the Menu goes back to it")
	main.menu.achievements_requested.emit()
	main.achievements_screen.get_node("%BackButton").pressed.emit()
	expect_true(main.menu.visible, "Achievements opened from the Menu goes back to it")
	main.menu.settings_requested.emit()
	main.settings_screen.get_node("%AchievementsButton").pressed.emit()
	main.achievements_screen.get_node("%BackButton").pressed.emit()
	expect_true(main.settings_screen.visible, "Achievements opened from Settings goes back to Settings")
	main.free()


# ------------------------------------------------------------------ the Menu tab

func test_the_menu_holds_settings_achievements_reset_and_back_to_title() -> void:
	var main := _main()
	_with_a_recruit(main)
	main.journey.rail.press("Menu")
	var menu: Control = main.menu
	for node in ["%SettingsButton", "%AchievementsButton", "%ResetButton", "%TitleButton"]:
		expect_true(menu.get_node(node).visible, "%s is on the Menu" % node)
	expect_eq(menu.get_node("%ResetButton").text, "Reset all upgrades")
	menu.get_node("%TitleButton").pressed.emit()
	expect_true(main.home.visible, "Back to title goes to the title")
	main.free()


func test_reset_all_upgrades_asks_twice_before_it_refunds() -> void:
	var main := _main()
	var profile := _with_a_recruit(main)
	var menu: Control = main.menu
	var button: Button = menu.get_node("%ResetButton")
	profile.data["gold"] = 100000
	expect_true(button.disabled, "nothing to refund yet")
	profile.buy("post_drills")
	expect_false(profile.get_respec_nodes().is_empty(), "an upgrade is owned")
	expect_false(button.disabled, "so Reset is open")
	main.journey.rail.press("Menu")
	button.pressed.emit()
	expect_true(button.text.contains("again to confirm"), "the first press only asks")
	expect_false(profile.get_respec_nodes().is_empty(), "and nothing is refunded")
	main.menu.visible = false
	main.menu.visible = true
	expect_eq(button.text, "Reset all upgrades", "looking away cancels the question")
	button.pressed.emit()
	button.pressed.emit()
	expect_true(profile.get_respec_nodes().is_empty(), "the second press refunds every upgrade")
	main.free()


# ------------------------------------------------------------------ the home screen

func test_the_home_screen_has_a_lighthouse_one_main_button_and_a_small_quit() -> void:
	var main := _main()
	var home: Control = main.home
	expect_true(home.get_node("%Scene") != null and home.get_node("%Scene").size.x >= 1000.0, "the lighthouse and sea fill the screen")
	expect_eq(home.get_node("%ContinueButton").theme_type_variation, &"MainButton", "Continue is the main button")
	for other in ["%NewGameButton", "%SettingsButton"]:
		expect_false(home.get_node(other).theme_type_variation == &"MainButton", "%s is not a main button" % other)
	expect_eq(home.get_node("%QuitButton").theme_type_variation, &"QuietButton", "Quit is quiet text")
	expect_true(home.get_node("%QuitButton").size.y >= 44.0, "and still a 44 px target")
	main.free()


func test_continue_names_the_level_from_a_real_json_save() -> void:
	var path := _path("continue_json")
	var first := _main(path)
	first.get_node("Profile").bank_run({"gold": 300, "outcome": "won", "level": "outpost"})
	first.free()
	# One header line (format, version, checksum), then the profile as JSON.
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text.substr(text.find("\n") + 1))
	expect_true(text.begins_with("GLSAVE") and parsed is Dictionary, "the save on disk is a header and then JSON")
	expect_eq(int(parsed.get("gold", -1)), 300, "with the gold in it")
	var main := _main(path)
	var profile: HoldfastProfile = main.get_node("Profile")
	var level: Dictionary = HoldfastContent.base()["levels"][profile.get_level()]
	var button: Button = main.home.get_node("%ContinueButton")
	expect_false(button.disabled, "the save is there to continue")
	expect_true(button.text.begins_with("Continue\n") and button.text.contains(str(level["name"])), "Continue names the level: %s" % button.text)
	button.pressed.emit()
	expect_true(main.journey.visible, "and Continue opens the map")
	main.free()


# ------------------------------------------------------------------ reduced motion

func test_the_beam_swings_and_stops_for_reduced_motion() -> void:
	var main := _main()
	var scene: Control = main.home.get_node("%Scene")
	var settings: HoldfastSettings = main.get_node("Settings")
	expect_true(main.home.is_beam_moving(), "the beam swings by default")
	scene._time = 2.5
	expect_true(absf(scene.beam_angle()) > 0.01, "and is off level while it swings")
	settings.set_reduced_motion(true)
	expect_false(main.home.is_beam_moving(), "reduced motion stops it")
	expect_eq(scene.beam_angle(), 0.0, "level, not frozen mid-swing")
	settings.set_reduced_motion(false)
	expect_true(main.home.is_beam_moving(), "and it swings again when switched off")
	main.free()


func test_reduce_motion_is_a_setting_on_the_settings_screen_and_is_remembered() -> void:
	var path := _path("settings_motion")
	var main := _main("", path)
	var settings: HoldfastSettings = main.get_node("Settings")
	var button: CheckButton = main.settings_screen.get_node("%MotionButton")
	expect_false(button.button_pressed, "off by default")
	button.button_pressed = true
	button.toggled.emit(true)
	expect_true(settings.is_motion_reduced(), "the switch reaches the settings")
	main.free()
	var again := HoldfastSettings.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_true(again.is_motion_reduced(), "and it is there next time")
	again.free()
