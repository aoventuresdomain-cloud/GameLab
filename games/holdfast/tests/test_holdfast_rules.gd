extends KitTestCase
## HF-M1-01: Holdfast rules on the kit engine, shared by the headless run and the playable build.

const SEEDS := [1, 2, 3, 42, 2026]


func _rules(config: Dictionary = {}) -> HoldfastRules:
	var rules := HoldfastRules.new()
	rules.setup(config if not config.is_empty() else HoldfastContent.run_config(), SimRng.new(1))
	return rules


func _enemy(rules: HoldfastRules, at: Vector2, health: float = 100.0) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	rules.enemies.append(enemy)
	return enemy


func test_base_pack_is_valid() -> void:
	var pack := PackLoader.load_pack(HoldfastContent.BASE_PACK, HoldfastContent.SCHEMA)
	expect_true(pack.ok, "errors: %s" % [pack.errors])
	for content_type in ["levels", "enemies", "towers", "staff", "upgrade_nodes"]:
		expect_false(pack.get_entries(content_type).is_empty(), content_type + " present")


func test_numbers_come_from_the_pack() -> void:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	var level: Dictionary = content["levels"]["outpost"]
	var rules := _rules(HoldfastContent.run_config("outpost", [], content))
	expect_eq(rules.keep_health_max, int(level["keep_health"]))
	expect_eq(rules.aura_dps, float(level["aura"]["dps"]))
	expect_eq(rules.tower.damage, float(content["towers"]["archer_post"]["damage"]))
	# Change the data, not the code, and the rules follow.
	level["keep_health"] = 7
	level["aura"]["dps"] = 99.0
	content["towers"]["archer_post"]["damage"] = 11.0
	rules = _rules(HoldfastContent.run_config("outpost", [], content))
	expect_eq(rules.keep_health_max, 7)
	expect_eq(rules.aura_dps, 99.0)
	expect_eq(rules.tower.damage, 11.0)


func test_upgrades_apply_their_effects() -> void:
	var base := _rules()
	var upgraded := _rules(HoldfastContent.run_config("outpost", ["aura_focus_1", "keep_walls_1", "tithe_1"]))
	expect_eq(upgraded.aura_dps, base.aura_dps + 3.0)
	expect_eq(upgraded.keep_health_max, base.keep_health_max + 25)
	expect_eq(upgraded.gold_multiplier, 1.25)


func test_aura_damages_only_enemies_under_it() -> void:
	var rules := _rules()
	var inside := _enemy(rules, Vector2(200, 0))
	var edge := _enemy(rules, Vector2(200 + rules.aura_radius + 9.0, 0))
	var outside := _enemy(rules, Vector2(200 + rules.aura_radius + 11.0, 0))
	rules.apply_aura(Vector2(200, 0), 0.5)
	expect_near(inside.health, 100.0 - rules.aura_dps * 0.5, 0.0001, "under the aura")
	expect_true(edge.health < 100.0, "touching the edge")
	expect_eq(outside.health, 100.0, "outside the aura")


func test_bot_and_mouse_reach_the_same_damage_function() -> void:
	var by_mouse := _rules()
	var by_bot := _rules()
	var mouse_target := _enemy(by_mouse, Vector2(150, 0), 50.0)
	var bot_target := _enemy(by_bot, Vector2(150, 0), 50.0)
	var player := HoldfastPlayerAura.new()
	var bot := HoldfastAuraBot.new()
	bot.dt = 1.0 / HoldfastRules.TICK_RATE
	bot.cursor = Vector2(150, 0)
	player.cursor = Vector2(150, 0)
	var mouse_input := player.get_input(by_mouse, 0)
	var bot_input := bot.get_input(by_bot, 0)
	expect_eq(mouse_input, bot_input, "same input shape and position")
	by_mouse.step(bot.dt, mouse_input)
	by_bot.step(bot.dt, bot_input)
	expect_true(mouse_target.health < 50.0, "the mouse aura did damage")
	expect_eq(mouse_target.health, bot_target.health)


func test_headless_run_finishes_with_drops() -> void:
	var report := HoldfastSim.run_headless(1)
	var result: Dictionary = report["result"]
	expect_true(report["finished"], "run ends")
	expect_true(result["outcome"] in [HoldfastRules.OUTCOME_WON, HoldfastRules.OUTCOME_LOST])
	expect_true(result["gold"] > 0, "kills drop gold")
	expect_true(result["xp"] > 0, "kills drop staff XP")
	expect_true(result["wave"] >= 1, "waves arrive")
	print("    seed 1: %s" % JSON.stringify(result))


func test_same_seed_same_run_headless() -> void:
	expect_eq(HoldfastSim.run_headless(9)["hash"], HoldfastSim.run_headless(9)["hash"])
	expect_ne(HoldfastSim.run_headless(9)["hash"], HoldfastSim.run_headless(10)["hash"])


## Done when: the same seeded run gives identical gold, XP and wave results in
## the headless simulator and in the playable build driven by the bot aura.
func test_headless_and_playable_build_match() -> void:
	var frames := RandomNumberGenerator.new()
	frames.seed = 31337
	for run_seed in SEEDS:
		var headless := HoldfastSim.run_headless(run_seed)
		var source := HoldfastRunSource.new()
		source.use_bot = true
		source.auto_step = false
		source.rng_seed = run_seed
		tree.root.add_child(source)
		var ended := {}
		source.run_ended.connect(func(summary: Dictionary) -> void: ended.merge(summary))
		source.start_run()
		var frames_run := 0
		while source.is_running() and frames_run < 1_000_000:
			# Uneven frame times, from 144 fps to a 15 fps stutter.
			source.step(frames.randf_range(1.0 / 144.0, 1.0 / 15.0))
			frames_run += 1
		var played: Dictionary = source.get_rules().result()
		var expected: Dictionary = headless["result"]
		var label := "seed %d" % run_seed
		expect_false(source.is_running(), label + " playable run ended")
		for key in ["outcome", "gold", "xp", "staff_level", "kills", "wave", "waves_cleared", "keep_health", "ticks"]:
			expect_eq(played[key], expected[key], "%s %s" % [label, key])
		expect_eq(source.get_engine().state_hash(), headless["hash"], label + " state hash")
		expect_eq(ended.get("gold_earned"), expected["gold"], label + " run_ended reports the gold")
		source.free()


func test_rules_have_no_rendering_or_input_dependency() -> void:
	for dir in ["res://scripts/rules/", "res://scripts/bots/"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var script: GDScript = load(dir + file)
			expect_false(ClassDB.is_parent_class(script.get_instance_base_type(), "Node"), file + " is not a Node")
			for banned in ["get_tree\\(", "\\bInput\\.", "RenderingServer", "\\bTime\\.", "OS\\.get_ticks", "(?<![\\w.])rand[fi]\\(", "(?<![\\w.])randomize\\(", "draw_"]:
				expect_true(RegEx.create_from_string(banned).search(script.source_code) == null, "%s matches %s" % [file, banned])
