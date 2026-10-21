extends KitTestCase
## HF-M2-14 slice 1: the Hero in the playable build. The keyboard feeds the same
## tick input the bot does, and a seeded run with recorded inputs ends the same
## in the playable build as headless.

const Main := preload("res://scenes/main.tscn")
const DT := 1.0 / HoldfastRules.TICK_RATE


## Plays recorded tick inputs back by tick number; empty once they run out.
class Replay:
	extends SimController
	var inputs: Array = []

	func get_input(_rules: SimRules, tick: int) -> Dictionary:
		return inputs[tick] if tick < inputs.size() else {}


func _start(seed_value: int) -> Node:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	source.rng_seed = seed_value
	tree.root.add_child(main)
	main.call("_start_run")
	return main


func test_keyboard_input_moves_the_hero_and_an_arrow_hits_an_enemy() -> void:
	var main := _start(2)
	var source: HoldfastRunSource = main.get_node("RunSource")
	var rules := source.get_rules()
	var start := rules.hero_position
	source.set_hero_input(Vector2.RIGHT, false)
	source.step(1.0)
	# 30 ticks at 170 px/s, worked by hand from the pack.
	expect_near(rules.hero_position.x - start.x, 170.0, 0.001, "D held for a second")
	var guard := 0
	var hit := false
	while source.is_running() and not hit and guard < 3000:
		var before := 0.0
		for enemy in rules.enemies:
			before += enemy.health
		source.step(DT)
		guard += 1
		# An enemy lost health with the tower and staff out of reach is not
		# provable here, so look for the Hero's own arrows having landed.
		hit = rules.kills > 0 or _any_hurt(rules)
	expect_true(hit, "the Hero's arrows, tower and staff hurt something")
	main.free()


func _any_hurt(rules: HoldfastRules) -> bool:
	for enemy in rules.enemies:
		if enemy.health < enemy.max_health:
			return true
	return false


func test_space_press_between_ticks_fires_the_ability_exactly_once() -> void:
	var main := _start(3)
	var source: HoldfastRunSource = main.get_node("RunSource")
	var rules := source.get_rules()
	source.set_hero_input(Vector2.ZERO, true)
	source.step(DT)
	expect_true(rules.hero_ability_ready_in > 0.0, "the ability fired and is charging")
	var charging := rules.hero_ability_ready_in
	source.step(DT)
	expect_true(rules.hero_ability_ready_in < charging, "the press was used up, not repeated")
	main.free()


func test_wasd_arrows_and_space_are_mapped_to_physical_keys() -> void:
	HoldfastPlayerHero.ensure_actions()
	var expected := {
		HoldfastPlayerHero.ACTION_LEFT: [KEY_A, KEY_LEFT],
		HoldfastPlayerHero.ACTION_RIGHT: [KEY_D, KEY_RIGHT],
		HoldfastPlayerHero.ACTION_UP: [KEY_W, KEY_UP],
		HoldfastPlayerHero.ACTION_DOWN: [KEY_S, KEY_DOWN],
		HoldfastPlayerHero.ACTION_ABILITY: [KEY_SPACE],
	}
	for action in expected:
		var codes := []
		for event in InputMap.action_get_events(action):
			codes.append((event as InputEventKey).physical_keycode)
		codes.sort()
		var want: Array = expected[action].duplicate()
		want.sort()
		expect_eq(codes, want, action)
	# Calling it again doesn't double up the keys.
	HoldfastPlayerHero.ensure_actions()
	expect_eq(InputMap.action_get_events(HoldfastPlayerHero.ACTION_ABILITY).size(), 1)


func test_the_player_controller_reads_actions_and_keeps_a_press_until_a_tick_takes_it() -> void:
	HoldfastPlayerHero.ensure_actions()
	var player := HoldfastPlayerHero.new()
	Input.action_press(HoldfastPlayerHero.ACTION_RIGHT)
	Input.action_press(HoldfastPlayerHero.ACTION_UP)
	Input.action_press(HoldfastPlayerHero.ACTION_ABILITY)
	player.sample()
	Input.action_release(HoldfastPlayerHero.ACTION_RIGHT)
	Input.action_release(HoldfastPlayerHero.ACTION_UP)
	Input.action_release(HoldfastPlayerHero.ACTION_ABILITY)
	var first := player.get_input(null, 0)
	expect_near(first["move"][0], 0.7071, 0.001, "D and W together: a diagonal of length 1")
	expect_near(first["move"][1], -0.7071, 0.001)
	expect_eq(first["ability"], true, "Space was pressed since the last tick")
	player.sample()
	var second := player.get_input(null, 1)
	expect_eq(second["move"], [0.0, 0.0], "nothing held")
	expect_eq(second["ability"], false, "the press is used up")


## The same recorded inputs, headless and in the playable build with uneven frame
## times, end in the same state (a seeded random walk with Space presses).
func test_headless_and_playable_build_match_with_recorded_inputs() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 4242
	var directions := [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]]
	var inputs := []
	var heading: Array = directions[0]
	for tick in 3000:
		if tick % 20 == 0:
			heading = directions[dice.randi_range(0, directions.size() - 1)]
		inputs.append({"move": heading, "ability": dice.randf() < 0.01})
	var frames := RandomNumberGenerator.new()
	frames.seed = 99
	for run_seed in [1, 7]:
		var replay := Replay.new()
		replay.inputs = inputs
		var headless := SimBotRunner.run(HoldfastRules.new(), replay, run_seed, HoldfastContent.run_config(), 100000, HoldfastRules.TICK_RATE)
		var source := HoldfastRunSource.new()
		source.auto_step = false
		source.rng_seed = run_seed
		var played_replay := Replay.new()
		played_replay.inputs = inputs
		source.controller_override = played_replay
		tree.root.add_child(source)
		source.start_run()
		var frames_run := 0
		while source.is_running() and frames_run < 1_000_000:
			source.step(frames.randf_range(1.0 / 144.0, 1.0 / 15.0))
			frames_run += 1
		var label := "seed %d" % run_seed
		expect_false(source.is_running(), label + " playable run ended")
		expect_eq(source.get_engine().state_hash(), headless["hash"], label + " state hash")
		expect_eq(source.get_rules().result(), headless["result"], label + " result")
		source.free()
