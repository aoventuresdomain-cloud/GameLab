extends KitTestCase

const WalkerRules := preload("res://addons/gamelab_kit/tests/fixtures/walker_rules.gd")
const WalkerBot := preload("res://addons/gamelab_kit/tests/fixtures/walker_bot.gd")
const CONFIG := {"walkers": 6, "limit": 400}


func _run_headless(p_seed: int) -> SimEngine:
	var engine := SimEngine.new(WalkerRules.new(), WalkerBot.new(), p_seed, CONFIG)
	engine.run_to_end(10000)
	return engine


func test_same_seed_gives_identical_hash() -> void:
	var a := _run_headless(1234)
	var b := _run_headless(1234)
	expect_true(a.is_finished(), "run finished")
	expect_eq(a.tick, 400)
	expect_eq(a.state_hash(), b.state_hash())


func test_different_seed_gives_different_hash() -> void:
	expect_ne(_run_headless(1234).state_hash(), _run_headless(1235).state_hash())


func test_frame_rate_does_not_change_the_run() -> void:
	var headless := _run_headless(77)
	# Playable-build style: irregular frame times fed to advance().
	var frames := RandomNumberGenerator.new()
	frames.seed = 9
	var engine := SimEngine.new(WalkerRules.new(), WalkerBot.new(), 77, CONFIG)
	var guard := 0
	while not engine.is_finished() and guard < 100000:
		engine.advance(frames.randf_range(0.001, 0.2))
		guard += 1
	expect_eq(engine.tick, headless.tick)
	expect_eq(engine.state_hash(), headless.state_hash())


func test_advance_runs_only_whole_ticks() -> void:
	var engine := SimEngine.new(WalkerRules.new(), WalkerBot.new(), 1, CONFIG, 10)
	expect_eq(engine.advance(0.05), 0, "half a tick runs nothing")
	expect_eq(engine.advance(0.06), 1, "carry-over completes one tick")
	expect_eq(engine.advance(10.0), SimEngine.MAX_TICKS_PER_ADVANCE, "a long frame is capped")


func test_bot_runner_reports_the_run() -> void:
	var report := SimBotRunner.run(WalkerRules.new(), WalkerBot.new(), 5, CONFIG, 10000)
	expect_eq(report["ticks"], 400)
	expect_true(report["finished"])
	expect_eq(report["hash"], _run_headless(5).state_hash())


func test_hash_ignores_key_order() -> void:
	expect_eq(SimEngine.hash_data({"a": 1, "b": [1.5, 2]}), SimEngine.hash_data({"b": [1.5, 2], "a": 1}))


func test_sim_has_no_scene_tree_dependency() -> void:
	for file in DirAccess.get_files_at("res://addons/gamelab_kit/sim"):
		if not file.ends_with(".gd"):
			continue
		var script: GDScript = load("res://addons/gamelab_kit/sim/" + file)
		expect_false(ClassDB.is_parent_class(script.get_instance_base_type(), "Node"), file + " must not be a Node")
		var source := script.source_code
		# Scene tree, input, rendering, clock and global randomness are all off limits.
		for banned in ["get_tree\\(", "\\bInput\\.", "RenderingServer", "\\bTime\\.", "OS\\.get_ticks", "(?<![\\w.])rand[fi]\\(", "(?<![\\w.])randomize\\("]:
			var regex := RegEx.create_from_string(banned)
			expect_true(regex.search(source) == null, "%s matches %s" % [file, banned])
