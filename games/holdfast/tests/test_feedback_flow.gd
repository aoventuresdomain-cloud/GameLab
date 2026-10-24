extends KitTestCase
## HF-M2-46 to 51 (the flow half of the CEO's feedback round): a teaching note that is short, fits
## the screen and waits for a press; Level 0 with no tower; a Start button instead of a fight that
## begins by itself; a first gear piece that waits in the bag.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080)]
## The longest line a teaching note may be before its hint.
const NOTE_MAX_CHARS := 80


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _content() -> Dictionary:
	return HoldfastContent.base()


func _key(pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.pressed = pressed
	event.echo = echo
	return event


# ------------------------------------------------------------------ 46: the note

func test_both_teaching_lines_are_short() -> void:
	var level: Dictionary = _content()["levels"][HoldfastMeta.tutorial_level(_content())]
	for text in [str(level["intro"]), str(level["stand"]["intro"])]:
		expect_true(text.length() <= NOTE_MAX_CHARS, "%d characters: %s" % [text.length(), text])


func test_a_teaching_run_waits_for_a_press_and_does_not_move_until_it_comes() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	main.call("_new_game")
	main.call("_level_picked", "first_watch")
	expect_true(source.is_running() and source.is_held(), "Level 0 starts held")
	source.auto_step = true
	source._process(5.0)
	expect_eq(source.get_rules().time, 0.0, "nothing moves while the note is up")
	expect_eq(source.get_posts_note(), str(_content()["levels"]["first_watch"]["intro"]), "the note is the level's line")
	main.hud.begin_requested.emit()
	expect_false(source.is_held())
	expect_eq(source.get_posts_note(), "", "the note goes with the press")
	source._process(0.2)
	expect_true(source.get_rules().time > 0.0, "and the run moves")
	main.free()


func test_a_run_that_teaches_nothing_never_waits() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.get_node("Profile").select_level("outpost")
	main.call("_start_run")
	expect_true(source.is_running())
	expect_false(source.is_held(), "an ordinary level starts moving at once")
	main.free()


func test_a_click_a_tap_or_a_key_lifts_the_hold_and_nothing_else_does() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	var hud: Control = main.hud
	main.call("_new_game")
	main.call("_level_picked", "first_watch")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var lift := InputEventScreenTouch.new()
	lift.pressed = false
	var motion := InputEventMouseMotion.new()
	for event in [_key(false), _key(true, true), up, lift, motion]:
		hud._input(event)
		expect_true(source.is_held(), "%s does not begin it" % event.get_class())
	for event in [_key(), down, touch]:
		if source.is_running():
			source.step(1000.0)
		main.call("_start_run")
		expect_true(source.is_held())
		hud._input(event)
		expect_false(source.is_held(), "%s begins it" % event.get_class())
	main.free()


func test_the_note_asks_for_the_press_and_the_hint_goes_when_it_is_given() -> void:
	var main := _main()
	var hud: Control = main.hud
	main.call("_new_game")
	main.call("_level_picked", "first_watch")
	hud._process(0.0)
	var note: Label = hud.get_node("%PostsNote")
	expect_true(note.visible)
	expect_true(note.text.ends_with(hud.HOLD_HINT), note.text)
	main.hud.begin_requested.emit()
	hud._process(0.0)
	expect_false(note.visible, "no note once the run has begun")
	main.free()


func test_the_note_fits_the_window_at_both_sizes() -> void:
	var main := _main()
	var hud: Control = main.hud
	main.call("_new_game")
	for stand in [false, true]:
		var source: HoldfastRunSource = main.get_node("RunSource")
		if source.is_running():
			source.step(1000.0)
		if stand:
			ThroughLevelZero.apply(main.get_node("Profile"))
			main.get_node("Profile").select_level("first_watch")
			main.get_node("Profile").data["stand_done"] = false
			main.get_node("Profile").data["layouts"] = {}
		main.call("_start_run", stand)
		for window in WINDOWS:
			tree.root.size = window
			await tree.process_frame
			hud._process(0.0)
			var note: Label = hud.get_node("%PostsNote")
			var rect: Rect2 = tree.root.get_final_transform() * note.get_global_rect()
			var label := "%dx%d, %s" % [window.x, window.y, "stand" if stand else "Level 0"]
			expect_true(note.visible, label)
			expect_true(note.autowrap_mode != TextServer.AUTOWRAP_OFF, "%s: wraps" % label)
			expect_true(rect.position.x >= 0.0 and rect.end.x <= float(window.x), "%s: inside the width (%s)" % [label, rect])
			expect_true(rect.position.y >= 0.0 and rect.end.y <= float(window.y), "%s: inside the height (%s)" % [label, rect])
			expect_true(note.get_minimum_size().y <= note.size.y, "%s: every line fits the label (%s in %s)" % [label, note.get_minimum_size(), note.size])
			expect_true(note.get_line_count() <= 4, "%s: %d lines" % [label, note.get_line_count()])
	main.free()


# ------------------------------------------------------------------ 47: Level 0 has no tower

func test_level_zero_has_no_tower_of_its_own_and_every_other_level_has_one() -> void:
	var content := _content()
	for id in content["levels"]:
		var level: Dictionary = content["levels"][id]
		if level.get("tutorial", false):
			expect_false(level.has("tower"), "%s builds no tower" % id)
		else:
			expect_true(level.has("tower"), "%s names its tower" % id)


func test_level_zero_starts_with_no_tower_in_the_game_and_the_stand_brings_the_post() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	main.call("_new_game")
	main.call("_level_picked", "first_watch")
	expect_eq(source.get_rules().towers.size(), 0, "no tower on Level 0")
	expect_eq(source.get_rules().layout_ids, [])
	source.step(1000.0)
	main.free()


func test_the_hero_alone_wins_level_zero_on_every_path_and_seed_and_it_cannot_be_lost() -> void:
	for pillar in ["flare_archer", "dusk_mage", "tideblade"]:
		for run_seed in range(1, 9):
			var report := HoldfastSim.run_headless(run_seed, HoldfastContent.run_config("first_watch", [], {}, pillar))
			expect_eq(report["result"]["outcome"], HoldfastRules.OUTCOME_WON, "%s seed %d" % [pillar, run_seed])
			expect_true(int(report["result"]["gold"]) > 0, "%s seed %d: the Hero's kills pay" % [pillar, run_seed])


# ------------------------------------------------------------------ 49: Start, not a surprise

func test_nothing_starts_a_run_but_a_press_on_a_level_or_on_start() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	profile.data = HoldfastMeta.bank_run(_content(), HoldfastMeta.new_profile(_content()), {"outcome": "won", "level": "first_watch", "gold": 0})
	profile.changed.emit()
	for id in ["castle_slot_1", "castle_archer_1"]:
		main.journey.buy_requested.emit(id)
		main.keep_screen.buy_requested.emit(id) # a second buy of the same node is refused
	expect_false(source.is_running())
	main.journey.stand_requested.emit()
	expect_true(source.is_running() and source.get_rules().stand, "the Start press begins the fight")
	expect_true(source.is_held(), "behind its own note")
	source.step(1000.0)
	main.journey.stand_requested.emit()
	expect_false(source.is_running(), "and it is never offered a second time")
	main.free()


# ------------------------------------------------------------------ 51: the first piece waits in the bag

func test_the_first_win_of_level_one_leaves_the_piece_in_the_bag_with_a_dot_on_the_hero_tab() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	var first := str(_content()["levels"]["outpost"]["first_clear_gear"])
	profile.bank_run({"outcome": "won", "level": "outpost", "gold": 0, "gear_found": [first]})
	expect_true(first in profile.get_gear_owned())
	expect_eq(profile.get_gear_worn(), {}, "nothing is equipped for the player")
	expect_true(profile.has_unseen_gear(), "so the Hero tab has its dot")
	main.call("_show", main.Screen.MAP)
	expect_true(main.journey._hero_dot.visible)
	var bag: Container = main.hero_page.get_node("%Bag")
	main.call("_show", main.Screen.HERO)
	expect_eq(bag.get_child_count(), 1, "the piece is in the bag")
	expect_false(profile.has_unseen_gear(), "opening the Hero page clears the dot")
	main.hero_page.gear_wear_requested.emit(first)
	expect_true(first in profile.get_gear_worn().values(), "and the player equips it")
	expect_eq(bag.get_child_count(), 0)
	main.free()


func test_the_bots_wear_what_they_find_so_the_simulator_is_unchanged() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "outpost", "gold": 0, "gear_found": ["wave_worn_boots"]})
	expect_eq(HoldfastMeta.worn_gear(profile), {})
	profile = HoldfastMeta.wear_free_slots(content, profile)
	expect_eq(HoldfastMeta.worn_gear(profile), {"boots": "wave_worn_boots"})
	expect_eq(HoldfastMeta.wear_free_slots(content, profile), profile, "wearing twice changes nothing")


# ------------------------------------------------------------------ 50: the parked Recruits and light posts

func _rules_for(level: String, parked: bool) -> HoldfastRules:
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config(level, [], _content(), "", null, {}, [], false, parked), SimRng.new(1))
	return rules


func test_a_parked_run_has_no_recruits_no_staff_and_no_light_posts_on_any_level() -> void:
	for id in _content()["levels"]:
		var rules := _rules_for(id, true)
		expect_eq(rules.setup_error, "", "%s sets up" % id)
		expect_eq(rules.recruits.size(), 0, "%s: no Recruits" % id)
		expect_eq(rules.staff, null, "%s: no staff" % id)
		expect_eq(rules.posts.size(), 0, "%s: no light posts" % id)


func test_the_flag_is_off_by_default_and_turning_it_off_brings_them_back() -> void:
	var rules := _rules_for("outpost", false)
	expect_true(rules.recruits.size() > 0 or rules.staff != null, "Recruits stand when not parked")
	expect_true(rules.posts.size() > 0, "and so do the light posts")
	expect_false("parked" in HoldfastContent.run_config("outpost"), "an ordinary config does not carry the flag")


func test_the_game_parks_them_in_every_run_it_starts() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.get_node("Profile").select_level("outpost")
	main.call("_start_run")
	expect_true(source.is_running())
	expect_eq(source.get_rules().recruits.size(), 0, "no Recruits in the game")
	expect_eq(source.get_rules().posts.size(), 0, "no light posts in the game")
	source.step(1000.0)
	main.free()
