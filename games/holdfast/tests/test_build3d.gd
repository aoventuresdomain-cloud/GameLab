extends KitTestCase
## Build 3d: HF-M2-23 (a pause and a banner between waves). Expected values are
## worked by hand: 30 ticks a second, so a pause of 1 s is 30 ticks. The pause is added
## to each later wave's delay; waves still come on the clock, stacked or not.

const Main := preload("res://scenes/main.tscn")
const DT := 1.0 / HoldfastRules.TICK_RATE


## The Outpost with `waves` one-Grunt waves, the first at `first` seconds and every later
## one `delay` seconds after the one before (plus the pause), and the given pause.
func _rules(pause: Variant, waves := 2, delay := 2.0, first := 0.0) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	var level: Dictionary = content["levels"]["outpost"]
	level["first_wave_delay"] = first
	if pause != null:
		level["wave_pause"] = pause
	level["waves"] = []
	for w in waves:
		var entry := {"spawns": [{"enemy": "grunt", "count": 1, "interval": 1}]}
		if w > 0:
			entry["delay"] = delay
		level["waves"].append(entry)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, "flare_archer"), SimRng.new(1))
	return rules


func _step(rules: HoldfastRules, ticks := 1) -> void:
	for i in ticks:
		rules.step(DT, {})


## Steps until the wave with this number (1-based) has an enemy out; returns the ticks it took, or -1.
func _ticks_until_wave(rules: HoldfastRules, number: int, limit := 2000) -> int:
	for i in limit:
		if rules.wave >= number:
			return i
		_step(rules)
	return -1


func test_the_pause_is_added_to_the_delay_and_not_a_tick_early() -> void:
	# Wave 1 spawns on tick 1; wave 2 is due 2 s delay + 1 s pause = 90 ticks later.
	var rules := _rules(1.0)
	_ticks_until_wave(rules, 1)
	expect_eq(rules.ticks, 1)
	_step(rules, 88)
	expect_eq(rules.wave, 1, "tick 89: one short")
	_step(rules, 1)
	expect_eq(rules.wave, 2, "tick 90: 3 s after the first")


func test_waves_still_stack_when_the_one_before_is_alive() -> void:
	var rules := _rules(1.0)
	_ticks_until_wave(rules, 1)
	rules.enemies[0].speed = 0.0
	_step(rules, 89)
	expect_eq(rules.wave, 2, "the second wave came with the first Grunt still alive")
	expect_eq(rules.enemies.size(), 2)


func test_with_no_pause_the_timing_is_the_old_timing_exactly() -> void:
	var rules := _rules(0.0)
	_ticks_until_wave(rules, 1)
	_step(rules, 58)
	expect_eq(rules.wave, 1, "tick 59: one short of 2 s")
	_step(rules, 1)
	expect_eq(rules.wave, 2, "tick 60: 2 s, as before the pause existed")
	expect_eq(rules.wave_banner(), "", "and no banner")


func test_a_longer_pause_waits_that_much_longer() -> void:
	var rules := _rules(2.5)
	_ticks_until_wave(rules, 1)
	_step(rules, 133)
	expect_eq(rules.wave, 1, "tick 134 is one short of 2 + 2.5 s (tick 135)")
	_step(rules, 1)
	expect_eq(rules.wave, 2)


func test_each_later_wave_gets_the_pause_and_the_first_does_not() -> void:
	var rules := _rules(1.0, 3)
	expect_eq(rules._wave_starts[0], 0.0, "the first wave is not delayed")
	expect_eq(rules._wave_starts[1], 3.0, "2 s delay + 1 s pause")
	expect_eq(rules._wave_starts[2], 6.0, "and again for the third")


func test_the_banner_names_the_next_wave_for_the_last_pause_before_it() -> void:
	# Wave 2 starts at 3.0 s (tick 90): "Wave 2" from 2.0 s (tick 60) to the tick before.
	var rules := _rules(1.0)
	_step(rules, 59)
	expect_eq(rules.wave_banner(), "", "tick 59: 1.03 s to go")
	_step(rules, 1)
	expect_eq(rules.wave_banner(), "Wave 2", "tick 60: exactly one pause to go")
	_step(rules, 29)
	expect_eq(rules.wave_banner(), "Wave 2", "tick 89")
	_step(rules, 1)
	expect_eq(rules.wave_banner(), "", "tick 90: the wave has started, and it was the last")


func test_the_banner_also_announces_the_first_wave() -> void:
	var rules := _rules(1.0, 2, 2.0, 2.0)
	_step(rules, 29)
	expect_eq(rules.wave_banner(), "", "tick 29")
	_step(rules, 1)
	expect_eq(rules.wave_banner(), "Wave 1", "tick 30: 1 s before the first wave")
	_step(rules, 30)
	expect_eq(rules.wave, 1)
	expect_eq(rules.wave_banner(), "", "tick 60: it has started")


func test_there_is_no_pause_after_the_last_wave() -> void:
	var rules := _rules(1.0)
	_ticks_until_wave(rules, 2)
	for enemy in rules.enemies:
		enemy.health = 0.0
	rules._any_dead = true
	_step(rules, 1)
	expect_eq(rules.outcome, HoldfastRules.OUTCOME_WON, "won the tick the last wave was gone")


func test_the_pack_sets_the_pause_and_the_default_is_one_second() -> void:
	expect_eq(HoldfastRules.DEFAULT_WAVE_PAUSE, 1.0)
	expect_eq(_rules(null).wave_pause, 1.0, "a level that does not say gets the default")
	expect_eq(_rules(0.25).wave_pause, 0.25)
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var level: Dictionary = HoldfastContent.base()["levels"]["outpost"].duplicate(true)
	var errors: PackedStringArray = []
	schema.validate_def(level, "level", "levels.json: $", errors, [])
	expect_true(errors.is_empty(), str(errors))
	level["wave_pause"] = -1
	errors.clear()
	schema.validate_def(level, "level", "levels.json: $", errors, [])
	expect_false(errors.is_empty(), "a negative pause is refused")
	level["wave_pause"] = 0
	errors.clear()
	schema.validate_def(level, "level", "levels.json: $", errors, [])
	expect_true(errors.is_empty(), "zero is allowed: " + str(errors))


# ------------------------------------------------------------------ the banner on screen

func test_the_hud_shows_the_banner_only_just_before_a_wave() -> void:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	tree.root.add_child(main)
	main.call("_start_run")
	var hud: Control = main.get_node("UI/Hud")
	var label: Label = hud.get_node("%WaveBanner")
	hud._process(0.0)
	expect_false(label.visible, "hidden before the first wave")
	var rules := source.get_rules()
	var first: float = rules._wave_starts[0]
	rules.time = first - 0.5
	hud._process(0.0)
	expect_true(label.visible, "half a second before the first wave")
	expect_eq(label.text, "Wave 1")
	rules.time = first - rules.wave_pause - 0.5
	hud._process(0.0)
	expect_false(label.visible, "earlier than the pause: hidden")
	main.free()


func test_the_banner_is_readable_and_clear_of_the_hero_the_tower_and_the_keep() -> void:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	tree.root.add_child(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.select_level("outpost")
	main.call("_start_run")
	var world: Node2D = main.get_node("World")
	var hud: Control = main.get_node("UI/Hud")
	var label: Label = hud.get_node("%WaveBanner")
	var rules := source.get_rules()
	rules.time = rules._wave_starts[0] - 0.5
	hud._process(0.0)
	var window_before := tree.root.size
	for window in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = window
		await tree.process_frame
		world._process(0.0)
		var to_window := tree.root.get_final_transform()
		var rect: Rect2 = to_window * label.get_global_rect()
		var size := "%dx%d" % [window.x, window.y]
		expect_true(rect.position.y >= (to_window * hud.get_node("TopBar").get_global_rect().end).y, "%s: below the HUD bar" % size)
		expect_true(rect.position.x >= 0.0 and rect.end.x <= window.x, "%s: inside the window" % size)
		var text_px := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
		expect_true(text_px.x <= label.size.x, "%s: the text fits the label" % size)
		expect_true(label.get_theme_font_size("font_size") * to_window.get_scale().y >= 30.0, "%s: large enough to read from a distance" % size)
		var spots := {"keep": Vector2.ZERO, "tower": rules.tower.position, "Hero": rules.hero_position}
		for name in spots:
			var at: Vector2 = to_window * world.world_to_screen(spots[name])
			expect_false(rect.grow(24.0).has_point(at), "%s: the banner does not cover the %s" % [size, name])
	tree.root.size = window_before
	main.free()
