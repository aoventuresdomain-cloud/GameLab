extends KitTestCase
## HF-M2-63: Keeper's Habit. The Flare barrage fires on its own at 70% of its power when three
## enemies are within its reach; a press still fires it at full power; one cooldown covers both.

const DT := 1.0 / HoldfastRules.TICK_RATE
## The barrage's arrow (pack: damage 7, burn 3 a second, reach 260, cooldown 14 s, 5 s of fire).
const FULL_DAMAGE := 7.0
const FULL_BURN := 3.0


## A run on Outpost with nothing coming, a Hero whose own arrow cannot reach anything (so every
## arrow in flight is the barrage's) and the Habit bought or not.
func _run_with(habit: bool) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	content["staff"]["bryn"]["damage"] = 0.0
	content["staff"]["bryn"]["damage_per_level"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["range"] = 1.0
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", ["flare_habit"] if habit else [], content), SimRng.new(1))
	return rules


func _enemy(rules: HoldfastRules, at: Vector2) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = 1.0e6
	enemy.max_health = 1.0e6
	enemy.radius = 10.0
	enemy.speed = 0.0
	rules.enemies.append(enemy)
	return enemy


func _crowd(rules: HoldfastRules, count: int) -> void:
	for i in count:
		_enemy(rules, rules.hero_position + Vector2(120.0, float(i) * 20.0))


func _step(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


## The ticks (counted from 1) on which a new arrow left the Hero, and the damage each carried.
func _shots(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> Array:
	var out := []
	var seen := []
	for tick in range(1, ticks + 1):
		_step(rules, 1, input)
		for arrow in rules.projectiles:
			if not arrow in seen:
				seen.append(arrow)
				out.append([tick, arrow.damage])
	return out


func test_the_node_gives_the_barrage_its_auto_power() -> void:
	expect_eq(float(_run_with(true).hero_ability["auto_power"]), 0.7)
	expect_false(_run_with(false).hero_ability.has("auto_power"), "without the node the stat is not there")


func test_three_close_enemies_set_it_off_at_seventy_percent_power() -> void:
	var rules := _run_with(true)
	_crowd(rules, 3)
	var shots := _shots(rules, 30)
	expect_false(shots.is_empty(), "it fires without a press")
	expect_true(int(shots[0][0]) >= 8 and int(shots[0][0]) <= 11, "after a third of a second waiting for a press, not at once: tick %d" % int(shots[0][0]))
	for shot in shots:
		expect_true(is_equal_approx(float(shot[1]), FULL_DAMAGE * 0.7), "every arrow is at 70% power")
	expect_true(is_equal_approx(rules.projectiles[0].burn_dps, FULL_BURN * 0.7), "and its burn")
	expect_true(rules.hero_ability_ready_in > 13.0, "the cooldown began")


func test_two_enemies_are_not_enough_and_a_third_out_of_reach_does_not_count() -> void:
	var rules := _run_with(true)
	_crowd(rules, 2)
	_enemy(rules, rules.hero_position + Vector2(400.0, 0.0))
	expect_true(_shots(rules, 60).is_empty(), "two close and one out of reach")
	_enemy(rules, rules.hero_position + Vector2(-100.0, 0.0))
	expect_false(_shots(rules, 20).is_empty(), "the third one close sets it off")


func test_a_dead_enemy_does_not_count() -> void:
	var rules := _run_with(true)
	_crowd(rules, 3)
	rules.enemies[2].health = 0.0
	expect_true(_shots(rules, 60).is_empty())


func test_without_the_node_three_close_enemies_set_off_nothing() -> void:
	var rules := _run_with(false)
	_crowd(rules, 3)
	expect_true(_shots(rules, 90).is_empty())


func test_a_press_still_fires_at_full_power_even_with_fewer_than_three_close() -> void:
	var rules := _run_with(true)
	_crowd(rules, 1)
	var shots := _shots(rules, 10, {"ability": true})
	expect_false(shots.is_empty())
	for shot in shots:
		expect_eq(float(shot[1]), FULL_DAMAGE, "a press is full power")
	expect_eq(rules.hero_rapid_power, 1.0)


func test_a_press_with_three_close_is_full_power_not_the_habit() -> void:
	var rules := _run_with(true)
	_crowd(rules, 3)
	var shots := _shots(rules, 10, {"ability": true})
	expect_eq(float(shots[0][1]), FULL_DAMAGE, "the press comes first")


func test_one_cooldown_covers_the_habit_and_a_press() -> void:
	var rules := _run_with(true)
	_crowd(rules, 3)
	var shots := _shots(rules, 440, {"ability": true})
	# Cast on tick 1 (full power) and burning for 5 s (150 ticks); the next is ready 14 s = 420 ticks later, and is a press again.
	var gaps := shots.filter(func(s: Array) -> bool: return int(s[0]) > 160 and int(s[0]) < 420)
	expect_true(gaps.is_empty(), "nothing between the burst and the cooldown's end")
	expect_true(shots.any(func(s: Array) -> bool: return int(s[0]) >= 420), "ready again after 14 s")
	var habit := _run_with(true)
	_crowd(habit, 3)
	var own := _shots(habit, 470)
	expect_eq(float(own[0][1]) / FULL_DAMAGE, 0.7)
	expect_true(own.filter(func(s: Array) -> bool: return int(s[0]) > 175 and int(s[0]) < 435).is_empty(), "it waits out the cooldown too")
	expect_true(own.any(func(s: Array) -> bool: return int(s[0]) >= 435), "and fires on its own again when ready")


func test_a_knocked_down_hero_does_not_fire_it() -> void:
	var rules := _run_with(true)
	_crowd(rules, 3)
	rules.hero_state = HeroKnockdown.take_damage(rules.hero_state, 1000.0, [100.0])
	expect_true(_shots(rules, 30).is_empty())


func test_a_press_inside_the_wait_comes_first_and_is_full_power() -> void:
	var rules := _run_with(true)
	_crowd(rules, 3)
	var out := []
	for tick in range(1, 40):
		_step(rules, 1, {"ability": tick == 6})
	for arrow in rules.projectiles:
		out.append(arrow.damage)
	expect_false(out.is_empty())
	for damage in out:
		expect_eq(float(damage), FULL_DAMAGE, "the player's press beat the Habit to it")


func test_enemies_that_leave_before_the_wait_is_over_start_it_again() -> void:
	var rules := _run_with(true)
	_crowd(rules, 3)
	_step(rules, 5)
	rules.enemies[0].position = Vector2(900.0, 900.0)
	_step(rules, 20)
	expect_true(rules.projectiles.is_empty(), "two left in reach: nothing")
	rules.enemies[0].position = rules.hero_position + Vector2(120.0, 0.0)
	_step(rules, 5)
	expect_true(rules.projectiles.is_empty(), "back at three, the wait starts over")
	_step(rules, 10)
	expect_false(rules.projectiles.is_empty())
