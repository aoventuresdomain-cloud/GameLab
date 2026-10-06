extends KitTestCase
## HF-M1-03: the playable level in main.tscn on the real rules.

const Main := preload("res://scenes/main.tscn")


func _start(seed_value: int) -> Node:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	source.rng_seed = seed_value
	tree.root.add_child(main)
	main.call("_start_run")
	return main


func test_main_scene_runs_the_real_rules() -> void:
	var main := _start(1)
	expect_true(main.get_node("RunSource") is HoldfastRunSource, "RunSource drives the kit engine")
	expect_true(main.get_node("RunSource").is_running(), "Play starts a run")
	main.free()


func test_aura_follows_the_mouse_and_damages_enemies_under_it() -> void:
	var main := _start(2)
	var source: HoldfastRunSource = main.get_node("RunSource")
	var world: Node2D = main.get_node("World")
	var rules := source.get_rules()
	var guard := 0
	while rules.enemies.is_empty() and guard < 200:
		source.step(0.1)
		guard += 1
	expect_false(rules.enemies.is_empty(), "enemies arrive in waves")
	var enemy: HoldfastRules.Enemy = rules.enemies[0]
	world._process(0.0) # place the world for this window size
	var move := InputEventMouseMotion.new()
	# Window pixels, as the OS reports them (they go through the UI scaling).
	move.position = tree.root.get_final_transform() * world.world_to_screen(enemy.position)
	tree.root.push_input(move)
	world._process(0.0)
	var before := enemy.health
	source.step(0.1)
	expect_true(rules.aura_active, "the aura is on while the mouse is over the field")
	expect_true(rules.aura_position.distance_to(enemy.position) < enemy.speed * 0.2 + 1.0, "the aura is where the mouse is")
	expect_true(enemy.health < before, "the enemy under the aura took damage")
	main.free()


func test_tower_and_staff_attack_on_their_own_and_the_run_ends() -> void:
	var main := _start(3)
	var source: HoldfastRunSource = main.get_node("RunSource")
	var rules := source.get_rules()
	var tower_fired := false
	var staff_fired := false
	var guard := 0
	# No mouse at all: only the tower and the staff fight.
	while source.is_running() and guard < 20000:
		source.step(0.1)
		tower_fired = tower_fired or rules.tower.last_target >= 0
		staff_fired = staff_fired or rules.staff.last_target >= 0
		guard += 1
	expect_true(tower_fired, "the tower attacked")
	expect_true(staff_fired, "the staff member attacked")
	expect_false(source.is_running(), "the run ended")
	expect_true(rules.gold > 0, "kills dropped gold")
	expect_true(rules.outcome in [HoldfastRules.OUTCOME_WON, HoldfastRules.OUTCOME_LOST], "won or lost")
	main.free()


func test_a_run_with_a_bad_setup_is_refused() -> void:
	var source := HoldfastRunSource.new()
	source.auto_step = false
	source.report_errors = false
	source.level_id = "no_such_level"
	var started := [false]
	source.run_started.connect(func() -> void: started[0] = true)
	tree.root.add_child(source)
	source.start_run()
	expect_false(source.is_running(), "nothing runs")
	expect_false(started[0], "no run_started signal")
	expect_true(source.get_rules() == null, "no rules left to draw")
	source.step(1.0)
	expect_false(source.is_running(), "stepping a refused run does nothing")
	source.free()
