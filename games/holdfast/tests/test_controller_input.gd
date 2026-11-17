extends KitTestCase
## HF-M2-69: the whole game with a pad or the keyboard alone. The actions carry pad events, L1 and R1
## step the rail tabs, B or Escape backs out of every screen, the run pauses and changes speed from
## the pad, a focus always shows, and the main flow is walked with no mouse.

const Main := preload("res://scenes/main.tscn")


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


func _button(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


## Sends an event the way the engine does: through the viewport's input, then the GUI.
func _send(event: InputEvent) -> void:
	tree.root.push_input(event)
	# A button acts on the release, so the press is followed by one.
	if event is InputEventJoypadButton or event is InputEventKey:
		var release: InputEvent = event.duplicate()
		release.pressed = false
		tree.root.push_input(release)


func _stick(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


# ------------------------------------------------------------------ the actions

func test_the_heros_actions_answer_the_stick_the_dpad_and_a() -> void:
	HoldfastPlayerHero.ensure_actions()
	expect_true(InputMap.event_is_action(_stick(JOY_AXIS_LEFT_X, -1.0), HoldfastPlayerHero.ACTION_LEFT))
	expect_true(InputMap.event_is_action(_stick(JOY_AXIS_LEFT_X, 1.0), HoldfastPlayerHero.ACTION_RIGHT))
	expect_true(InputMap.event_is_action(_stick(JOY_AXIS_LEFT_Y, -1.0), HoldfastPlayerHero.ACTION_UP))
	expect_true(InputMap.event_is_action(_stick(JOY_AXIS_LEFT_Y, 1.0), HoldfastPlayerHero.ACTION_DOWN))
	for pair in [[JOY_BUTTON_DPAD_LEFT, HoldfastPlayerHero.ACTION_LEFT], [JOY_BUTTON_DPAD_RIGHT, HoldfastPlayerHero.ACTION_RIGHT], [JOY_BUTTON_DPAD_UP, HoldfastPlayerHero.ACTION_UP], [JOY_BUTTON_DPAD_DOWN, HoldfastPlayerHero.ACTION_DOWN], [JOY_BUTTON_A, HoldfastPlayerHero.ACTION_ABILITY]]:
		expect_true(InputMap.event_is_action(_button(pair[0]), pair[1]), str(pair[1]))
	expect_true(InputMap.event_is_action(_key(KEY_SPACE), HoldfastPlayerHero.ACTION_ABILITY), "the keyboard still works")


func test_pause_speed_and_the_tab_steps_have_a_key_and_a_pad_button() -> void:
	HoldfastInput.ensure_actions()
	expect_true(InputMap.event_is_action(_button(JOY_BUTTON_A), "ui_accept"), "A accepts")
	expect_true(InputMap.event_is_action(_button(JOY_BUTTON_B), "ui_cancel"), "B cancels")
	for direction in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		expect_true(InputMap.action_get_events(direction).any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton), "%s has the d-pad" % direction)
		expect_true(InputMap.action_get_events(direction).any(func(e: InputEvent) -> bool: return e is InputEventJoypadMotion), "%s has the stick" % direction)
	for pair in [[HoldfastInput.ACTION_PAUSE, KEY_ESCAPE, JOY_BUTTON_START], [HoldfastInput.ACTION_PAUSE, KEY_P, JOY_BUTTON_START], [HoldfastInput.ACTION_SPEED, KEY_F, JOY_BUTTON_Y], [HoldfastInput.ACTION_TAB_PREV, KEY_PAGEUP, JOY_BUTTON_LEFT_SHOULDER], [HoldfastInput.ACTION_TAB_NEXT, KEY_PAGEDOWN, JOY_BUTTON_RIGHT_SHOULDER]]:
		expect_true(InputMap.event_is_action(_key(pair[1]), pair[0]), "%s by key" % pair[0])
		expect_true(InputMap.event_is_action(_button(pair[2]), pair[0]), "%s by pad" % pair[0])


# ------------------------------------------------------------------ the hub

func test_l1_and_r1_step_through_the_open_tabs_and_wrap() -> void:
	var main := _main()
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.call("_show", main.Screen.MAP)
	var order := [main.Screen.TREE, main.Screen.HERO, main.Screen.MENU, main.Screen.MAP]
	for expected in order:
		_send(_button(JOY_BUTTON_RIGHT_SHOULDER))
		expect_eq(main.screen, expected, "R1 goes on")
	_send(_button(JOY_BUTTON_LEFT_SHOULDER))
	expect_eq(main.screen, main.Screen.MENU, "L1 goes back round")
	_send(_key(KEY_PAGEUP))
	expect_eq(main.screen, main.Screen.HERO, "Page Up is the same as L1")
	main.free()


func test_l1_and_r1_skip_the_tabs_the_guide_has_shut() -> void:
	var main := _main()
	main.call("_new_game")
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.bank_run({"gold": 300, "outcome": "won", "level": "first_watch"})
	expect_true(profile.get_guided_step() != "", "a guided buy is due")
	expect_eq(main.screen, main.Screen.MAP)
	_send(_button(JOY_BUTTON_RIGHT_SHOULDER))
	expect_eq(main.screen, main.Screen.MENU, "Tree and Hero are shut: Map goes to Menu")
	_send(_button(JOY_BUTTON_RIGHT_SHOULDER))
	expect_eq(main.screen, main.Screen.MAP)
	main.free()


func test_b_and_escape_back_out_of_every_page_to_its_parent() -> void:
	var main := _main()
	ThroughLevelZero.apply(main.get_node("Profile"))
	for screen in [main.Screen.TREE, main.Screen.HERO, main.Screen.MENU, main.Screen.PLAN]:
		main.call("_show", screen)
		_send(_button(JOY_BUTTON_B))
		expect_eq(main.screen, main.Screen.MAP, "B leaves %d" % screen)
	main.call("_show", main.Screen.MENU)
	main.menu.settings_requested.emit()
	expect_eq(main.screen, main.Screen.SETTINGS)
	_send(_key(KEY_ESCAPE))
	expect_eq(main.screen, main.Screen.MENU, "Escape goes back to where Settings was opened")
	main.call("_show", main.Screen.MAP)
	_send(_button(JOY_BUTTON_B))
	expect_eq(main.screen, main.Screen.HOME, "the map's back is the title")
	_send(_button(JOY_BUTTON_B))
	expect_eq(main.screen, main.Screen.HOME, "and the title has none")
	main.free()


func test_b_does_nothing_on_a_result_and_closes_the_tree_card_before_leaving() -> void:
	var main := _main()
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.call("_on_run_ended", {"gold_earned": 5, "waves_cleared": 5, "total_waves": 5, "keep_fell": false,
			"result": {"outcome": HoldfastRules.OUTCOME_WON, "level": "outpost", "gold": 5}})
	expect_eq(main.screen, main.Screen.SUMMARY)
	_send(_button(JOY_BUTTON_B))
	expect_eq(main.screen, main.Screen.SUMMARY, "a result waits for a choice")
	main.call("_show", main.Screen.TREE)
	var id: String = main.keep_screen._node_buttons.keys()[0]
	main.keep_screen.open_card(id)
	_send(_button(JOY_BUTTON_B))
	expect_false(main.keep_screen._card.visible, "the first B closes the card")
	expect_eq(main.screen, main.Screen.TREE)
	_send(_button(JOY_BUTTON_B))
	expect_eq(main.screen, main.Screen.MAP, "the second leaves")
	main.free()


# ------------------------------------------------------------------ the run

func _run_started() -> Node:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.select_level("outpost")
	main.call("_start_run")
	main.hud.set_process(false)
	return main


func test_start_pauses_and_resumes_and_y_changes_the_speed() -> void:
	var main := _run_started()
	var source: HoldfastRunSource = main.get_node("RunSource")
	expect_true(source.is_running() and not source.is_held())
	_send(_button(JOY_BUTTON_START))
	expect_true(source.is_paused(), "Start pauses")
	main.hud._refresh_hero()
	expect_true(main.hud._resume_button.has_focus(), "the focus is on Resume so A resumes")
	_send(_button(JOY_BUTTON_Y))
	expect_eq(source.get_speed(), 1, "no speed change while paused")
	_send(_button(JOY_BUTTON_B))
	expect_false(source.is_paused(), "B closes the pause card")
	_send(_button(JOY_BUTTON_Y))
	expect_eq(source.get_speed(), 2, "Y doubles the speed")
	_send(_key(KEY_F))
	expect_eq(source.get_speed(), 1, "F toggles it back")
	_send(_button(JOY_BUTTON_START))
	_send(_button(JOY_BUTTON_START))
	expect_false(source.is_paused(), "Start again resumes")
	main.free()


func test_a_pad_button_lifts_the_hold_and_answers_the_specials_prompt() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	main.call("_new_game")
	main.call("_level_picked", "first_watch")
	expect_true(source.is_held(), "Level 0 starts held")
	_send(_button(JOY_BUTTON_X))
	expect_false(source.is_held(), "any pad button begins")
	main.free()
	# The special's prompt (F-159): A answers it, since A is the special's own button.
	var run := _main()
	var run_source: HoldfastRunSource = run.get_node("RunSource")
	run_source.teach_special = true
	run_source.level_id = "outpost"
	run.call("_show", run.Screen.RUN)
	run_source.start_run()
	run_source.step(120.0)
	expect_true(run_source.is_teaching_special(), "stopped at the prompt")
	var asked := [0]
	run.hud.special_requested.connect(func() -> void: asked[0] += 1)
	_send(_button(JOY_BUTTON_X))
	expect_eq(asked[0], 0, "a button that is not the special's does not answer it")
	_send(_button(JOY_BUTTON_A))
	expect_eq(asked[0], 1, "A does")
	run.free()


# ------------------------------------------------------------------ focus and reach

## Every control a player can act on can take the focus, on every screen, so nothing needs a mouse.
func test_every_button_on_every_screen_can_take_the_focus() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run({"gold": 500, "outcome": "won", "level": "outpost"})
	var missing := []
	var checked := 0
	var screens := {
		"home": main.home, "map": main.journey, "tree": main.keep_screen, "hero": main.hero_page,
		"squad": main.recruits_page, "menu": main.menu, "settings": main.settings_screen,
		"achievements": main.achievements_screen, "plan": main.planning, "summary": main.summary,
	}
	for key in screens:
		var screen: Control = screens[key]
		screen.visible = true
		await tree.process_frame
		for button in screen.find_children("*", "BaseButton", true, false):
			if button.is_visible_in_tree() and not button.disabled:
				checked += 1
				if button.focus_mode == Control.FOCUS_NONE:
					missing.append("%s/%s" % [key, screen.get_path_to(button)])
		screen.visible = false
	expect_true(checked > 30, "the scan saw %d buttons" % checked)
	expect_eq(missing, [], "buttons a pad could not reach")
	main.free()


func test_a_screen_opens_with_the_focus_on_something() -> void:
	var main := _main()
	ThroughLevelZero.apply(main.get_node("Profile"))
	for screen in [main.Screen.HOME, main.Screen.MAP, main.Screen.TREE, main.Screen.HERO, main.Screen.MENU, main.Screen.PLAN]:
		main.call("_show", screen)
		await tree.process_frame
		var owner: Control = tree.root.gui_get_focus_owner()
		expect_true(owner != null and owner.is_visible_in_tree(), "screen %d has a focus" % screen)
	main.free()


# ------------------------------------------------------------------ the whole flow, no mouse

func test_the_main_flow_is_walked_with_a_pad_and_no_mouse() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	await tree.process_frame
	expect_eq(main.screen, main.Screen.HOME)
	# New game: the only open choice on a fresh title screen has the focus; A takes it.
	_send(_button(JOY_BUTTON_A))
	await tree.process_frame
	expect_eq(main.screen, main.Screen.MAP, "A on the title starts or continues")
	# The map's focus is on the open level, or the guide's button; A takes it.
	var guard := 0
	while main.screen == main.Screen.MAP and guard < 4:
		_send(_button(JOY_BUTTON_A))
		await tree.process_frame
		guard += 1
	expect_true(main.screen in [main.Screen.RUN, main.Screen.PLAN], "A on the map goes on to the level (screen %d)" % main.screen)
	if main.screen == main.Screen.PLAN:
		_send(_button(JOY_BUTTON_A))
		await tree.process_frame
	expect_eq(main.screen, main.Screen.RUN, "and the level starts")
	_send(_button(JOY_BUTTON_A))
	await tree.process_frame
	expect_false(source.is_held(), "a button begins the run")
	_send(_button(JOY_BUTTON_START))
	main.hud._refresh_hero()
	expect_true(main.hud._pause_screen.visible, "Start pauses")
	await tree.process_frame
	# Down to Back to map, then A twice (the second confirms): out of the run, on the map.
	_send(_button(JOY_BUTTON_DPAD_DOWN))
	expect_true(main.hud._leave_button.has_focus(), "the d-pad moves the focus to Back to map")
	_send(_button(JOY_BUTTON_A))
	_send(_button(JOY_BUTTON_A))
	await tree.process_frame
	expect_eq(main.screen, main.Screen.MAP, "back on the map")
	_send(_button(JOY_BUTTON_B))
	expect_eq(main.screen, main.Screen.HOME, "B on the map goes to the title")
	main.free()


func test_the_tree_follows_the_focus_to_a_node_off_the_edge_of_the_view() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	for id in HoldfastContent.base()["upgrade_nodes"]:
		if not id in profile.data["upgrades"]:
			profile.data["upgrades"].append(id)
	profile.changed.emit()
	main.call("_show", main.Screen.TREE)
	await tree.process_frame
	await tree.process_frame
	var keep: Control = main.keep_screen
	var view: Rect2 = keep._view.get_global_rect()
	keep.go_to(keep._node_buttons.keys()[0])
	var far := ""
	for id in keep._node_buttons:
		var button: Button = keep._node_buttons[id]
		if button.visible and not view.encloses(button.get_global_rect()):
			far = id
			break
	expect_true(far != "", "some node is out of the view at real size")
	if far != "":
		keep._node_buttons[far].grab_focus()
		await tree.process_frame
		expect_true(view.encloses(keep._node_buttons[far].get_global_rect()), "the view moved to the focused node")
	main.free()


# ------------------------------------------------------------------ the Steam Deck

func test_the_screens_fit_the_decks_1280_by_800() -> void:
	var main := _main()
	ThroughLevelZero.apply_castle(main.get_node("Profile"))
	var before := tree.root.size
	tree.root.size = Vector2i(1280, 800)
	await tree.process_frame
	var view := tree.root.get_visible_rect()
	var off := []
	for screen in [main.home, main.journey, main.keep_screen, main.hero_page, main.recruits_page, main.menu, main.settings_screen, main.planning, main.summary]:
		screen.visible = true
		await tree.process_frame
		var web: Control = screen.get_node_or_null("%Web")
		for control: Control in screen.find_children("*", "Control", true, false):
			if not control.is_visible_in_tree() or (web != null and web.is_ancestor_of(control)):
				continue
			if not (control is Label or control is BaseButton):
				continue
			var inside := false
			var parent: Node = control.get_parent()
			while parent != null and parent != screen:
				if parent is ScrollContainer:
					inside = true
				parent = parent.get_parent()
			var rect: Rect2 = control.get_global_rect()
			if not inside and not view.encloses(rect):
				off.append("%s/%s" % [screen.name, screen.get_path_to(control)])
		screen.visible = false
	expect_eq(off, [], "controls off the 1280x800 screen")
	tree.root.size = before
	main.free()
