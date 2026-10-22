extends KitTestCase
## Build 3d: HF-M2-23 (a pause and a banner between waves). Expected values are
## worked by hand: 30 ticks a second, so a pause of 1 s is 30 ticks.

const Main := preload("res://scenes/main.tscn")
const DT := 1.0 / HoldfastRules.TICK_RATE


## The Outpost with two or three one-Grunt waves, the first starting at once and every
## later one due `delay` seconds after the one before, and the given pause.
func _rules(pause: Variant, waves := 2, delay := 0.0) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	var level: Dictionary = content["levels"]["outpost"]
	level["first_wave_delay"] = 0.0
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


## Kills an enemy the way damage would.
func _kill(rules: HoldfastRules, enemy: HoldfastRules.Enemy) -> void:
	enemy.health = 0.0
	rules._any_dead = true


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


## Plays wave 1: waits for its Grunt, kills it, returns the tick it was cleared on.
func _clear_first_wave(rules: HoldfastRules) -> int:
	_ticks_until_wave(rules, 1)
	_kill(rules, rules.enemies[0])
	_step(rules)
	expect_eq(rules.waves_cleared, 1, "the first wave is cleared")
	return rules.ticks


func test_the_next_wave_starts_after_the_pause_and_not_a_tick_before() -> void:
	var rules := _rules(1.0)
	var cleared_on := _clear_first_wave(rules)
	_step(rules, 29)
	expect_eq(rules.wave, 1, "one tick short of 30: still the first wave")
	expect_eq(rules.enemies.size(), 0, "and nothing has spawned")
	_step(rules, 1)
	expect_eq(rules.wave, 2, "exactly 30 ticks after the clear the second wave spawns")
	expect_eq(rules.ticks - cleared_on, 30)


func test_a_longer_pause_waits_that_long_and_no_monster_spawns_in_it() -> void:
	var rules := _rules(2.5)
	_clear_first_wave(rules)
	for i in 74:
		_step(rules)
		expect_eq(rules.enemies.size(), 0, "tick %d of 75: nothing spawned" % (i + 1))
	_step(rules)
	expect_eq(rules.wave, 2, "75 ticks is 2.5 s")


func test_with_no_pause_waves_start_on_schedule_even_with_enemies_left() -> void:
	var rules := _rules(0.0, 2, 2.0)
	_ticks_until_wave(rules, 1)
	_step(rules, 58)
	expect_eq(rules.wave, 1, "the second wave is due 2 s after the first spawned (tick 60)")
	_step(rules, 1)
	expect_eq(rules.wave, 2, "on schedule, the first Grunt still alive")
	expect_eq(rules.enemies.size(), 2)


func test_a_wave_waits_for_the_one_before_to_be_gone_then_for_the_pause() -> void:
	var rules := _rules(1.0, 2, 2.0)
	_ticks_until_wave(rules, 1)
	rules.enemies[0].speed = 0.0
	_step(rules, 300)   # well past the schedule
	expect_eq(rules.wave, 1, "the first Grunt is alive: no second wave")
	_kill(rules, rules.enemies[0])
	_step(rules, 1)
	var cleared_on := rules.ticks
	_step(rules, 29)
	expect_eq(rules.wave, 1)
	_step(rules, 1)
	expect_eq(rules.wave, 2)
	expect_eq(rules.ticks - cleared_on, 30)


func test_the_last_wave_has_no_pause_after_it() -> void:
	var rules := _rules(1.0)
	_clear_first_wave(rules)
	_ticks_until_wave(rules, 2)
	_kill(rules, rules.enemies[0])
	_step(rules, 1)
	expect_eq(rules.outcome, HoldfastRules.OUTCOME_WON, "won the tick the last wave was cleared")
	expect_eq(rules.wave_pause_left, 0.0)
	expect_eq(rules.wave_banner(), "")


func test_a_wave_that_leaks_still_gets_its_pause_but_is_not_called_cleared() -> void:
	var rules := _rules(1.0)
	_ticks_until_wave(rules, 1)
	rules.enemies.clear()
	rules._wave_gone(0, false)   # the Grunt reached the keep
	expect_eq(rules.waves_cleared, 0, "a wave that leaked is not cleared")
	expect_eq(rules.wave_banner(), "Wave 2", "no \"cleared\", but the pause and the next wave's number")
	_step(rules, 29)
	expect_eq(rules.wave, 1)
	_step(rules, 1)
	expect_eq(rules.wave, 2, "the next wave came after the pause")


func test_the_banner_says_cleared_then_the_next_wave_then_nothing() -> void:
	var rules := _rules(1.0)
	expect_eq(rules.wave_banner(), "", "no banner before any wave")
	_clear_first_wave(rules)
	expect_eq(rules.wave_banner(), "Wave cleared")
	_step(rules, 14)
	expect_eq(rules.wave_banner(), "Wave cleared", "the first half of the pause")
	_step(rules, 1)
	expect_eq(rules.wave_banner(), "Wave 2", "the second half")
	_step(rules, 14)
	expect_eq(rules.wave_banner(), "Wave 2")
	_step(rules, 1)
	expect_eq(rules.wave_banner(), "", "the wave has started")


func test_the_pause_is_part_of_the_state_the_hash_covers() -> void:
	var a := _rules(1.0)
	var b := _rules(1.0)
	_clear_first_wave(a)
	_clear_first_wave(b)
	_step(a, 5)
	_step(b, 6)
	expect_ne(SimEngine.hash_data(a.snapshot()), SimEngine.hash_data(b.snapshot()))
	_step(a, 1)
	expect_eq(SimEngine.hash_data(a.snapshot()), SimEngine.hash_data(b.snapshot()), "the same ticks, the same hash")


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

func test_the_hud_shows_the_banner_only_during_a_pause() -> void:
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
	rules.wave_pause_left = 0.9
	rules.pause_next_wave = 3
	rules.pause_cleared = true
	hud._process(0.0)
	expect_true(label.visible)
	expect_eq(label.text, "Wave cleared")
	rules.wave_pause_left = 0.2
	hud._process(0.0)
	expect_eq(label.text, "Wave 3")
	rules.wave_pause_left = 0.0
	hud._process(0.0)
	expect_false(label.visible)
	main.free()


func test_the_banner_is_readable_and_clear_of_the_hero_the_tower_and_the_keep() -> void:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	tree.root.add_child(main)
	main.call("_start_run")
	var world: Node2D = main.get_node("World")
	var hud: Control = main.get_node("UI/Hud")
	var label: Label = hud.get_node("%WaveBanner")
	var rules := source.get_rules()
	rules.wave_pause_left = 0.9
	rules.pause_next_wave = 2
	rules.pause_cleared = true
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
