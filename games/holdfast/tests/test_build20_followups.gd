extends KitTestCase
## HF-M2-90 (Build 20): five follow-ups from QA, interface only. F-201 the Volume slider's focus ring, F-202 Extreme on
## the Plan title and the map's level line, F-203 the Home Continue label, F-204 the first-run tip's keys, F-205 the map
## chip on a level that does not offer the tier.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080)]


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	main.get_node("Profile").save_path = "user://build20_followups.sav"
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _past_the_guide(main: Node) -> HoldfastProfile:
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	return profile


## The first level that has an Extreme replay, with its Hard replay won so that Extreme is open.
func _open_extreme(profile: HoldfastProfile, stars := 0) -> String:
	var content := HoldfastContent.base()
	for id in content["levels"]:
		if not HoldfastMeta.extreme_modifiers(content, id).is_empty():
			for list in [["levels_won", id], ["unlocked", id]]:
				if not list[1] in profile.data[list[0]]:
					profile.data[list[0]].append(list[1])
			profile.data["hard_stars"][id] = 1
			profile.data["extreme_stars"][id] = stars
			profile.changed.emit()
			return str(id)
	return ""


# ------------------------------------------------------------------ F-201

func test_the_volume_slider_has_the_focus_ring_while_it_is_focused() -> void:
	var main := _main()
	main.call("_show", main.Screen.SETTINGS)
	await tree.process_frame
	await tree.process_frame
	var screen: Control = main.settings_screen
	var slider: HSlider = screen.get_node("%VolumeSlider")
	var ring: Panel = screen.get_node("%FocusRing")
	expect_false(ring.visible, "no ring while another control has the focus")
	slider.grab_focus()
	await tree.process_frame
	expect_true(slider.has_focus())
	expect_true(ring.visible, "the ring shows on the focused slider")
	expect_eq(ring.get_global_rect(), slider.get_global_rect(), "and runs round the whole slider")
	var box: StyleBoxFlat = ring.get_theme_stylebox("panel")
	var button_ring: StyleBoxFlat = screen.get_node("%BackButton").get_theme_stylebox("focus")
	expect_true(box.border_width_left >= 3 and not box.draw_center, "a ring, not a fill")
	expect_eq(box.border_color, button_ring.border_color, "in the same colour as every other control's ring")
	expect_true(slider.size.y >= 44.0, "and the slider is a 44 px target")
	screen.get_node("%BackButton").grab_focus()
	await tree.process_frame
	expect_false(ring.visible, "the ring goes when the focus does")
	main.free()


# ------------------------------------------------------------------ F-202

func test_the_plan_names_the_two_extreme_modifiers() -> void:
	var main := _main()
	var profile := _past_the_guide(main)
	var level := _open_extreme(profile)
	expect_true(level != "", "set-up: a level has an Extreme replay")
	profile.select_tier("extreme")
	profile.select_level(level)
	main.call("_open_plan")
	expect_eq(profile.get_run_tier(), "extreme")
	var label: String = profile.get_extreme_label(level)
	expect_true(label.contains(","), "two modifiers, so a comma: " + label)
	expect_eq(main.planning._title.text, "Plan: %s (Extreme)" % HoldfastContent.base()["levels"][level]["name"], "the title stays short")
	expect_true(main.planning.get_node("%Hint").text.contains("Extreme: %s" % label), "and the line under it names both: " + main.planning.get_node("%Hint").text)
	main.free()


## F-208: a long title once made the header wider than the screen, pushing Back off the left and the tower list off the right.
func test_no_plan_header_control_leaves_the_screen_for_any_level_and_tier_at_both_sizes() -> void:
	var main := _main()
	var profile := _past_the_guide(main)
	var content := HoldfastContent.base()
	var planning: Control = main.planning
	var longest_name := ""
	var longest_label := ""
	for id in content["levels"]:
		if str(content["levels"][id]["name"]).length() > longest_name.length():
			longest_name = str(content["levels"][id]["name"])
		longest_label = longest_label if longest_label.length() >= HoldfastMeta.extreme_label(content, id).length() else HoldfastMeta.extreme_label(content, id)
	for window in WINDOWS:
		tree.root.size = window
		var screen := Rect2(Vector2.ZERO, Vector2(window))
		var cases := []
		for id in content["levels"]:
			if id == HoldfastMeta.tutorial_level(content):
				continue
			cases.append([id, "extreme", HoldfastMeta.extreme_label(content, id)])
			cases.append([id, "hard", HoldfastMeta.hard_label(content, id)])
			cases.append([id, "easy", ""])
		for case in cases:
			planning.open(case[0], [], false, profile.get_ring_spots(), profile.get_castle_cards(), profile.get_castle_mage_cards(), profile.get_castle_slots())
			planning.set_tier(case[1], case[2], case[1])
			planning.show()
			await tree.process_frame
			await tree.process_frame
			_expect_header_on_screen(planning, screen, "%dx%d %s %s" % [window.x, window.y, case[0], case[1]])
		# The worst case: the longest level name with the longest pair of modifiers.
		var any := "outpost"
		planning.open(any, [], false, profile.get_ring_spots(), profile.get_castle_cards(), profile.get_castle_mage_cards(), profile.get_castle_slots())
		planning._level = planning._level.duplicate()
		planning._level["name"] = longest_name
		planning.set_tier("extreme", longest_label + ", " + longest_label, "extreme")
		planning.show()
		await tree.process_frame
		await tree.process_frame
		_expect_header_on_screen(planning, screen, "%dx%d the longest name with a doubled label" % [window.x, window.y])
	main.free()


func _expect_header_on_screen(planning: Control, screen: Rect2, what: String) -> void:
	var header: Control = planning.get_node("Margin/Column/Header")
	for control in header.find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and control.get_global_rect().size.x > 0.0:
			expect_true(screen.encloses(control.get_global_rect()), "%s: %s is on the screen (%s)" % [what, control.name, control.get_global_rect()])
	var tile: Control = planning.get_node("Margin/Column/Header/Extra/TowerTile")
	expect_false(planning._title.get_global_rect().intersects(tile.get_global_rect()), "%s: the title is clear of the tower tile" % what)
	expect_true(screen.encloses(planning.get_node("Margin/Column/Body").get_global_rect()), "%s: the body is on the screen" % what)


func test_the_map_line_under_a_level_gives_the_extreme_record_once_extreme_is_open() -> void:
	var main := _main()
	var profile := _past_the_guide(main)
	var level := _open_extreme(profile, 0)
	var map: Control = main.journey
	map.refresh()
	var line: String = map._hard_names[level].text
	expect_true(line.contains("\nExtreme"), "an open Extreme replay has a line of its own: %s" % line)
	expect_true(line.ends_with("Extreme"), "and no record to give before it has paid: %s" % line)
	profile.data["extreme_stars"][level] = 2
	profile.changed.emit()
	map.refresh()
	expect_true(map._hard_names[level].text.ends_with("Extreme: 2 of 3"), map._hard_names[level].text)
	expect_true(map._hard_names[level].text.contains("1 of 3"), "Hard's record is still there: " + map._hard_names[level].text)
	main.free()


func test_the_extreme_line_overlaps_nothing_on_the_map_at_both_sizes() -> void:
	var main := _main()
	var profile := _past_the_guide(main)
	_open_extreme(profile, 2)
	for id in HoldfastContent.base()["levels"]:
		if not id in profile.data["unlocked"]:
			profile.data["unlocked"].append(id)
		if not id in profile.data["levels_won"]:
			profile.data["levels_won"].append(id)
		profile.data["hard_stars"][id] = 3
	profile.changed.emit()
	main.call("_show", main.Screen.MAP)
	var map: Control = main.journey
	for window in WINDOWS:
		tree.root.size = window
		await tree.process_frame
		await tree.process_frame
		map.refresh()
		await tree.process_frame
		var rects := []
		for id in map._ids:
			for control in [map._buttons[id], map._names[id], map._hard_names[id]]:
				if control.visible and (control is Button or control.text != ""):
					rects.append([control.get_global_rect(), "%s %s" % [id, control.name]])
		var map_rect: Rect2 = map._map.get_global_rect()
		for i in rects.size():
			expect_true(map_rect.encloses(rects[i][0]), "%dx%d: %s is inside the map" % [window.x, window.y, rects[i][1]])
			for j in range(i + 1, rects.size()):
				expect_false(rects[i][0].intersects(rects[j][0]), "%dx%d: %s overlaps %s" % [window.x, window.y, rects[i][1], rects[j][1]])
	main.free()


# ------------------------------------------------------------------ F-203

func test_continue_names_the_next_level_the_map_names() -> void:
	var main := _main()
	var profile := _past_the_guide(main)
	var button: Button = main.home.get_node("%ContinueButton")
	var content := HoldfastContent.base()
	# Outpost won, then Hard and Extreme replays of it played: the last level played is Outpost, the next step is the next level.
	profile.bank_run({"gold": 0, "outcome": "won", "level": "outpost"})
	profile.select_level("outpost")
	profile.bank_run({"gold": 0, "outcome": "won", "level": "outpost", "hard": true})
	var next: String = main.journey._next
	expect_true(next != "" and next != "outpost", "set-up: the map's next level is not the one last played (%s)" % next)
	main.home.refresh()
	var level: Dictionary = content["levels"][next]
	expect_eq(button.text, "Continue\nLevel %d · %s" % [int(level["number"]), level["name"]], button.text)
	expect_false(button.text.contains("The Outpost"), "not the last level played")
	main.free()


func test_continue_at_level_zero_keeps_naming_the_level_the_player_is_on() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.new_game()
	profile.bank_run({"gold": 5, "outcome": "lost", "level": HoldfastMeta.tutorial_level(HoldfastContent.base())})
	main.home.refresh()
	var button: Button = main.home.get_node("%ContinueButton")
	var level: Dictionary = HoldfastContent.base()["levels"][profile.get_level()]
	expect_eq(button.text, "Continue\nLevel %d · %s" % [int(level["number"]), level["name"]], button.text)
	main.free()


# ------------------------------------------------------------------ F-204

func _hud_fires(main: Node, event: InputEvent) -> bool:
	var hud: Control = main.get_node("UI/Hud")
	var fired := [false]
	var listener := func() -> void: fired[0] = true
	hud.special_requested.connect(listener)
	hud._input(event)
	hud.special_requested.disconnect(listener)
	return fired[0]


func _at_the_special_prompt() -> Node:
	var main := _main()
	var profile := _past_the_guide(main)
	profile.select_level("outpost")
	main.call("_start_run")
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.teach_special = true
	source.step(240.0)
	return main


func test_the_tip_names_only_keys_that_fire_the_special() -> void:
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.keycode = KEY_SPACE
	space.pressed = true
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var key_a := InputEventKey.new()
	key_a.physical_keycode = KEY_A
	key_a.keycode = KEY_A
	key_a.pressed = true
	# Each answer to the prompt ends it, so every event gets its own run held at the prompt.
	for case in [["Space", space, true], ["A on a pad", pad, true], ["click", click, true], ["the keyboard's A", key_a, false]]:
		var main := _at_the_special_prompt()
		var source: HoldfastRunSource = main.get_node("RunSource")
		expect_true(source.is_teaching_special(), "set-up: held at the prompt")
		var note := source.get_special_note()
		var fired := _hud_fires(main, case[1])
		if case[2]:
			expect_true(note.contains(case[0]) and fired, "%s is named and fires it: %s" % [case[0], note])
		else:
			expect_false(fired, "the keyboard's A does not fire it")
			expect_false(note.contains("Space, A or"), "so the tip does not offer a bare A: " + note)
		main.free()


# ------------------------------------------------------------------ F-205

func test_the_map_chip_goes_back_to_normal_when_the_level_played_does_not_offer_the_tier() -> void:
	var main := _main()
	var profile := _past_the_guide(main)
	var content := HoldfastContent.base()
	var won := "outpost"
	var fresh := HoldfastMeta.next_level(content, won)
	for list in [["levels_won", won], ["unlocked", won], ["unlocked", fresh]]:
		if not list[1] in profile.data[list[0]]:
			profile.data[list[0]].append(list[1])
	profile.changed.emit()
	var map: Control = main.journey
	profile.select_tier("hard")
	profile.select_level(fresh)
	main.call("_open_plan")
	expect_true(main.planning.get_node("%Hint").text.contains("Hard opens after a Normal win here"), "the Plan page still says it")
	expect_eq(profile.get_tier(), "normal", "and the pick is Normal now")
	main.call("_show", main.Screen.MAP)
	map.refresh()
	expect_true(map._chips["normal"]["button"].button_pressed, "the map's chip reads Normal")
	expect_false(map._chips["hard"]["button"].button_pressed, "and not Hard")
	# Where the level does offer it, the pick stays.
	profile.select_tier("hard")
	profile.select_level(won)
	main.call("_open_plan")
	expect_eq(profile.get_tier(), "hard", "Hard stays picked on a level that has it")
	main.free()

