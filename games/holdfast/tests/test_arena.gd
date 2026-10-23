extends KitTestCase
## HF-M2-19: a bigger arena. Its size comes from the level in the pack, the Hero walks to every
## edge and corner of it and no further, spawns stay inside it, and the camera shows all of it.

const Main := preload("res://scenes/main.tscn")
const DT := 1.0 / HoldfastRules.TICK_RATE
const SIZES := {"outpost": Vector2(1920, 858), "shingle_beach": Vector2(1920, 920), "tidewrack_cove": Vector2(1920, 960), "old_pier": Vector2(1920, 1000), "gull_rock": Vector2(1920, 1040)}


## Rules with no wave for 1000 s and nothing doing damage.
func _quiet(level: String = "outpost", upgrades: Array = [], edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"][level]["first_wave_delay"] = 1000.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config(level, upgrades, content, "flare_archer"), SimRng.new(1))
	return rules


func _run(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


# ------------------------------------------------------------------ the size

func test_each_level_gives_its_arena_size_in_the_pack() -> void:
	for level in SIZES:
		expect_eq(_quiet(level).arena_size(), SIZES[level], level + " arena")


func test_the_outpost_arena_is_about_one_and_a_half_times_the_old_playfield() -> void:
	# The old playfield was the disc of the Outpost's 420 spawn radius: 840 wide and high.
	var size := _quiet().arena_size()
	expect_true(size.x / 840.0 >= 1.4 and size.x / 840.0 <= 2.4, "width ratio %.2f" % (size.x / 840.0))
	expect_true(size.y / 840.0 >= 1.0 and size.y / 840.0 <= 1.6, "height ratio %.2f" % (size.y / 840.0))


func test_a_level_without_an_arena_gets_the_default() -> void:
	var rules := _quiet("outpost", [], func(c: Dictionary) -> void: c["levels"]["outpost"].erase("arena"))
	expect_eq(rules.arena_size(), HoldfastRules.DEFAULT_ARENA)


func test_a_bad_arena_in_the_pack_is_refused() -> void:
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var level: Dictionary = HoldfastContent.base()["levels"]["outpost"].duplicate(true)
	var fine: PackedStringArray = []
	schema.validate_def(level, "level", "levels.json: $", fine, [])
	expect_eq(fine, PackedStringArray(), "the real level is valid")
	for bad in [{"width": 100, "height": 858}, {"width": 1920}, {"width": "wide", "height": 858}, {"width": 1920, "height": 858, "depth": 1}]:
		level["arena"] = bad
		var errors: PackedStringArray = []
		schema.validate_def(level, "level", "levels.json: $", errors, [])
		expect_true(errors.size() >= 1, "rejected: " + str(bad))


# ------------------------------------------------------------------ the Hero reaches every edge and corner, no further

func test_the_hero_reaches_each_edge_and_stops_there() -> void:
	for level in SIZES:
		var half: Vector2 = SIZES[level] * 0.5
		var cases := {Vector2(1, 0): Vector2(half.x, 80), Vector2(-1, 0): Vector2(-half.x, 80), Vector2(0, 1): Vector2(0, half.y), Vector2(0, -1): Vector2(0, -half.y)}
		for dir in cases:
			var rules := _quiet(level)
			_run(rules, 6 * HoldfastRules.TICK_RATE, {"move": [dir.x, dir.y]})
			expect_eq(rules.hero_position, cases[dir], "%s: edge %s" % [level, dir])
			_run(rules, 30, {"move": [dir.x, dir.y]})
			expect_eq(rules.hero_position, cases[dir], "%s: and no further %s" % [level, dir])


func test_the_hero_reaches_each_corner_and_stops_there() -> void:
	for level in SIZES:
		var half: Vector2 = SIZES[level] * 0.5
		for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var rules := _quiet(level)
			_run(rules, 10 * HoldfastRules.TICK_RATE, {"move": [corner.x, corner.y]})
			expect_eq(rules.hero_position, corner * half, "%s: corner %s" % [level, corner])


func test_a_dash_never_carries_the_hero_out_of_the_arena() -> void:
	# Tideblade's ability dashes along the facing.
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, "tideblade"), SimRng.new(1))
	var edge := rules.arena_half.x
	rules.hero_position = Vector2(edge - 5.0, 0.0)
	rules.hero_facing = Vector2.RIGHT
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = Vector2(edge - 5.0 + 30.0, 0.0)
	enemy.health = 1000000.0
	enemy.max_health = enemy.health
	enemy.radius = 10.0
	rules.enemies.append(enemy)
	_run(rules, 3, {"ability": true})
	expect_true(rules.hero_position.x <= edge, "dash ended at x=%.1f, arena edge %.1f" % [rules.hero_position.x, edge])


# ------------------------------------------------------------------ spawns and arrows stay inside

func test_every_spawn_is_inside_the_arena_even_with_the_widest_beam() -> void:
	# Three beam nodes (+100) push the fog edge past the Outpost arena's half-height of 429.
	var beams := ["keep_beam_1", "keep_beam_2", "keep_beam_3"]
	for level in SIZES:
		var rules := HoldfastRules.new()
		var content := HoldfastContent.base()
		var owned := beams.duplicate()
		rules.setup(HoldfastContent.run_config(level, owned, content), SimRng.new(3))
		var half := rules.arena_half
		var seen := 0
		var guard := 0
		while not rules.is_finished() and guard < 4000:
			rules.step(DT, {})
			guard += 1
			for enemy in rules.enemies:
				if enemy.position.distance_to(Vector2.ZERO) > 0.0 and enemy.uid >= seen:
					seen = enemy.uid + 1
					expect_true(absf(enemy.position.x) <= half.x + 0.001 and absf(enemy.position.y) <= half.y + 0.001, "%s: enemy %d at %s" % [level, enemy.uid, enemy.position])
		expect_true(seen >= 10, "%s: saw spawns" % level)


func test_an_arrow_fired_from_the_edge_starts_inside_the_arena() -> void:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, "flare_archer"), SimRng.new(1))
	rules.hero_position = Vector2(rules.arena_half.x, 0.0)
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = Vector2(rules.arena_half.x - 100.0, 0.0)
	enemy.health = 1000000.0
	enemy.max_health = enemy.health
	enemy.radius = 10.0
	rules.enemies.append(enemy)
	_run(rules, 1)
	expect_true(rules.projectiles.size() >= 1, "the Hero fired")
	for arrow in rules.projectiles:
		expect_true(absf(arrow.position.x) <= rules.arena_half.x + 0.001, "arrow at %s" % arrow.position)


# ------------------------------------------------------------------ the camera shows all of it

func test_the_whole_arena_is_on_screen_below_the_hud_at_common_window_sizes() -> void:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	tree.root.add_child(main)
	main.call("_start_run")
	var world: Node2D = main.get_node("World")
	var bar: Control = main.get_node("UI/Hud/TopBar")
	var window_before := tree.root.size
	for level in ["outpost", "gull_rock"]:
		source.level_id = level
		source.layout = null
		source.start_run()
		var rules := source.get_rules()
		expect_eq(rules.arena_size(), SIZES[level], level + " is the level on show")
		for window in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
			tree.root.size = window
			await tree.process_frame
			world._process(0.0)
			var to_window := tree.root.get_final_transform()
			var hud_bottom: float = (to_window * bar.get_global_rect().end).y
			var size := "%s %dx%d" % [level, window.x, window.y]
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var at: Vector2 = to_window * world.world_to_screen(corner * rules.arena_half)
				expect_true(at.x >= 0.0 and at.x <= window.x, "%s: corner %s x=%.0f is inside the window" % [size, corner, at.x])
				expect_true(at.y >= hud_bottom and at.y <= window.y, "%s: corner %s y=%.0f is below the HUD (%.0f) and inside the window" % [size, corner, at.y, hud_bottom])
			expect_true(world.scale.x >= world.MIN_SCALE, "%s: scale %.2f stays readable" % [size, world.scale.x])
	tree.root.size = window_before
	main.free()
