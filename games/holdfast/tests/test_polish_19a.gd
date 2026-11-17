extends KitTestCase
## HF-M2-88 (Build 19a): the Call next wave button and the first-run special tip stay off the playfield (F-198,
## F-193), no tier silently plays another (F-199), and the Plan page's range discs stay inside the field (F-197).
## Interface only.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080)]


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


## A game past the guide with `outpost` won on Normal and the level after it open but not won.
func _two_levels(main: Node) -> Array:
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	var content := HoldfastContent.base()
	var won := "outpost"
	var fresh := HoldfastMeta.next_level(content, won)
	for list in [["levels_won", won], ["unlocked", won], ["unlocked", fresh]]:
		if not list[1] in profile.data[list[0]]:
			profile.data[list[0]].append(list[1])
	profile.changed.emit()
	return [won, fresh]


## The arena as the window sees it, in window pixels.
func _arena_rect(main: Node) -> Rect2:
	var world: Node2D = main.get_node("World")
	var half: Vector2 = main.get_node("RunSource").get_rules().arena_half
	var to_window := tree.root.get_final_transform()
	var a: Vector2 = to_window * world.world_to_screen(-half)
	var b: Vector2 = to_window * world.world_to_screen(half)
	return Rect2(a, b - a).abs()


func _window_rect(control: Control) -> Rect2:
	var to_window := tree.root.get_final_transform()
	var rect := control.get_global_rect()
	return Rect2(to_window * rect.position, to_window.basis_xform(rect.size))


func _run_in_windows(callback: Callable) -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.select_level("outpost")
	main.call("_start_run")
	var before := tree.root.size
	for window in WINDOWS:
		tree.root.size = window
		await tree.process_frame
		main.get_node("World")._process(0.0)
		callback.call(main, "%dx%d" % [window.x, window.y])
	tree.root.size = before
	main.free()


# ------------------------------------------------------------------ F-198

func test_the_call_wave_button_covers_no_playfield_at_both_sizes() -> void:
	await _run_in_windows(func(main: Node, size: String) -> void:
		var hud: Control = main.get_node("UI/Hud")
		var button := _window_rect(hud.get_node("%CallWaveButton"))
		var arena := _arena_rect(main)
		expect_false(button.intersects(arena), "%s: the button %s is clear of the field %s" % [size, button, arena])
		expect_true(button.size.y >= 44.0 * button.size.y / hud.get_node("%CallWaveButton").size.y, "%s: still a 44 px target" % size)
		expect_false(button.intersects(_window_rect(hud.get_node("%BossBar"))), "%s: and clear of the boss bar" % size)
		expect_false(button.intersects(_window_rect(hud.get_node("TopBar"))), "%s: and of the top bar" % size)
		expect_true(Rect2(Vector2.ZERO, Vector2(tree.root.size)).encloses(button), "%s: and on the screen" % size))


# ------------------------------------------------------------------ F-193

func test_the_special_tip_is_clear_of_the_field_the_button_and_the_boss_bar() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.select_level("outpost")
	main.call("_start_run")
	var hud: Control = main.get_node("UI/Hud")
	var tip: Label = hud.get_node("%SpecialTip")
	tip.visible = true
	var font := tip.get_theme_font("font")
	var font_size := tip.get_theme_font_size("font_size")
	expect_true(font_size >= 20, "the tip is in the 20 px font or larger")
	for window in WINDOWS:
		tree.root.size = window
		for pillar in HoldfastRunSource.SPECIAL_WHAT:
			var note: String = "Your special is ready: %s\n%s" % [HoldfastRunSource.SPECIAL_WHAT[pillar], HoldfastRunSource.SPECIAL_KEYS]
			tip.text = note
			await tree.process_frame
			main.get_node("World")._process(0.0)
			var size := "%dx%d %s" % [window.x, window.y, pillar]
			var rect := _window_rect(tip)
			expect_true(rect.size.x > 100.0 and rect.size.y > 30.0, "%s: the tip has been laid out (%s)" % [size, rect])
			expect_false(rect.intersects(_arena_rect(main)), "%s: the tip %s is clear of the field %s" % [size, rect, _arena_rect(main)])
			expect_false(rect.intersects(_window_rect(hud.get_node("%CallWaveButton"))), "%s: and of the call button" % size)
			expect_false(rect.intersects(_window_rect(hud.get_node("%BossBar"))) and hud.get_node("%BossBar").visible, "%s: and of the boss bar when it is up" % size)
			var box := font.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, tip.size.x, font_size)
			expect_true(box.y <= tip.size.y, "%s: its text fits (%.0f in %.0f px)" % [size, box.y, tip.size.y])
	tip.visible = false
	main.free()


func test_the_hud_shows_the_real_tip_in_its_own_label_and_no_other_note_with_it() -> void:
	var main := _main()
	var hud: Control = main.get_node("UI/Hud")
	var source: HoldfastRunSource = main.get_node("RunSource")
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.select_level("outpost")
	main.call("_start_run")
	source.teach_special = true
	hud.set_process(false)
	source.step(240.0)
	expect_true(source.is_teaching_special(), "the run is held at the prompt")
	hud._refresh_hero()
	expect_true(hud.get_node("%SpecialTip").visible)
	expect_eq(hud.get_node("%SpecialTip").text, source.get_special_note())
	expect_false(hud.get_node("%PostsNote").visible, "nothing else is up over the field with it")
	source.press_special()
	hud._refresh_hero()
	expect_false(hud.get_node("%SpecialTip").visible, "and it goes with the press")
	main.free()


# ------------------------------------------------------------------ F-199

func test_a_picked_tier_a_level_does_not_offer_is_said_and_the_run_matches() -> void:
	var main := _main()
	var levels := _two_levels(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	var planning: Control = main.planning
	expect_true(profile.get_tiers_open(levels[0]).has("hard"), "set-up: the won level offers Hard")
	expect_false(profile.get_tiers_open(levels[1]).has("hard"), "set-up: the next one does not")
	profile.select_tier("hard")
	# The level that has it: Hard is played, marked in the title, with no line.
	profile.select_level(levels[0])
	main.call("_open_plan")
	expect_eq(profile.get_run_tier(), "hard")
	expect_false(planning.get_node("%Hint").text.contains("opens after"), "Hard is open here: nothing to say")
	main.call("_start_run")
	expect_true(main.get_node("RunSource").hard == true, "and the run is Hard")
	main.get_node("RunSource").step(1000.0)
	main.call("_show", main.Screen.MAP)
	# The level that does not: Normal is played, and the page says so.
	profile.select_level(levels[1])
	main.call("_open_plan")
	expect_eq(profile.get_run_tier(), "normal")
	expect_true(planning.get_node("%Hint").visible)
	expect_true(planning.get_node("%Hint").text.contains("Hard opens after a Normal win here, so this plays Normal."), planning.get_node("%Hint").text)
	main.call("_start_run")
	expect_true(main.get_node("RunSource").hard == false, "and the run is Normal, as the page said")
	main.free()


func test_extreme_asked_where_only_hard_is_open_says_so_too() -> void:
	var main := _main()
	var levels := _two_levels(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_false(profile.get_tiers_open(levels[0]).has("extreme"), "set-up: Extreme is not open on the won level")
	profile.select_tier("extreme")
	profile.select_level(levels[0])
	main.call("_open_plan")
	expect_eq(profile.get_run_tier(), "normal")
	expect_true(main.planning.get_node("%Hint").text.contains("Extreme opens after a Hard win here, so this plays Normal."), main.planning.get_node("%Hint").text)
	main.free()


func test_the_line_goes_when_the_page_is_opened_for_a_level_that_offers_the_tier() -> void:
	var main := _main()
	var levels := _two_levels(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.select_tier("hard")
	profile.select_level(levels[1])
	main.call("_open_plan")
	expect_true(main.planning.get_node("%Hint").text.contains("opens after"))
	profile.select_level(levels[0])
	main.call("_open_plan")
	expect_false(main.planning.get_node("%Hint").text.contains("opens after"), "no stale line on the next page")
	main.free()


# ------------------------------------------------------------------ F-197

func test_the_plan_map_clips_its_range_discs_to_the_field_and_clears_the_header_and_rows() -> void:
	var main := _main()
	_two_levels(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.select_level("outpost")
	for window in WINDOWS:
		tree.root.size = window
		main.call("_open_plan")
		await tree.process_frame
		await tree.process_frame
		var planning: Control = main.planning
		var map: Control = planning.get_node("%Map")
		var size := "%dx%d" % [window.x, window.y]
		expect_true(map.clip_contents, "%s: nothing drawn on the map leaves it" % size)
		var rect := map.get_global_rect()
		var header: Control = planning.find_children("*", "HubHeader", true, false)[0]
		expect_true(rect.position.y >= header.get_global_rect().end.y - 0.5, "%s: the map starts below the header" % size)
		for row in [planning.get_node("Margin/Column/Footer"), planning.get_node("%Hint")]:
			if row.is_visible_in_tree():
				expect_false(rect.intersects(row.get_global_rect()), "%s: the map is clear of %s" % [size, row.name])
		expect_false(rect.intersects(planning.get_node("%Side").get_global_rect()), "%s: and of the tray" % size)
	main.free()
