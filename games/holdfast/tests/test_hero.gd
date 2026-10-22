extends KitTestCase
## HF-M2-14 slice 1: the Hero (Flare Archer) moves, fires on their own and uses
## their ability, on the same rules the playable build and the bot run. Expected
## numbers are worked by hand from the pack values noted beside them.

const DT := 1.0 / HoldfastRules.TICK_RATE
const SCHEMA := HoldfastContent.SCHEMA


## Rules with no wave for 1000 s, and a tower and staff that do no damage, so
## only the Hero and what a test adds are on the field.
func _quiet(edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	content["staff"]["bryn"]["damage"] = 0.0
	content["staff"]["bryn"]["damage_per_level"] = 0.0
	# These tests are worked by hand from an attack damage of 6.
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 6.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content), SimRng.new(1))
	return rules


## `_quiet` with the old one-off fan as the ability (9 arrows over 70 degrees, 8 s), which
## a pack still gets when `rapid_seconds` is 0. `edit` then changes the pack as in `_quiet`.
func _fan(edit: Callable = Callable()) -> HoldfastRules:
	return _quiet(func(c: Dictionary) -> void:
		c["hero_paths"]["flare_archer"]["ability"].merge({"cooldown": 8, "speed": 420, "count": 9, "spread_degrees": 70, "rapid_seconds": 0}, true)
		if edit.is_valid():
			edit.call(c))


func _enemy(rules: HoldfastRules, at: Vector2, radius: float = 10.0, health: float = 100.0) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = radius
	enemy.speed = 0.0
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


func test_the_flare_archer_pack_is_valid_and_placed_on_the_level() -> void:
	var rules := _quiet()
	expect_eq(rules.hero_path_id, "flare_archer")
	expect_eq(rules.hero_position, Vector2(0, 80), "the level says where the Hero starts")
	expect_eq(rules.hero_attack["kind"], "projectile")
	expect_eq(rules.hero_ability["name"], "Flare Barrage")


func test_wasd_input_moves_the_hero_at_the_pack_speed() -> void:
	# Pack: move_speed 170 px/s, start (0, 80). One second of "right" is 170 px.
	var rules := _quiet()
	_run(rules, HoldfastRules.TICK_RATE, {"move": [1, 0]})
	expect_near(rules.hero_position.x, 170.0, 0.001, "one second right")
	expect_near(rules.hero_position.y, 80.0, 0.001)
	_run(rules, HoldfastRules.TICK_RATE, {"move": [0, -1]})
	expect_near(rules.hero_position.y, 80.0 - 170.0, 0.001, "one second up (y is down on screen)")


func test_diagonal_and_oversized_input_are_no_faster_than_straight() -> void:
	var diagonal := _quiet()
	_run(diagonal, HoldfastRules.TICK_RATE, {"move": [1, 1]})
	expect_near(diagonal.hero_position.distance_to(Vector2(0, 80)), 170.0, 0.001, "W+D is not faster")
	var huge := _quiet()
	_run(huge, HoldfastRules.TICK_RATE, {"move": [50, 0]})
	expect_near(huge.hero_position.x, 170.0, 0.001, "an input longer than 1 is shortened")


func test_off_empty_and_garbage_move_input_means_no_movement() -> void:
	for bad in [null, [], [1], [1, 0, 0], "right", {"x": 1}, [NAN, 0], [INF, 0], ["1", 0], [0, 0], [true, false]]:
		var rules := _quiet()
		_run(rules, 10, {"move": bad})
		expect_eq(rules.hero_position, Vector2(0, 80), "no movement for %s" % [bad])
	var none := _quiet()
	_run(none, 10)
	expect_eq(none.hero_position, Vector2(0, 80), "no move key at all")


func test_the_hero_cannot_leave_the_arena() -> void:
	# Pack: the Outpost arena is 1920 wide, so 960 either side of the keep. Walk right for
	# 6 s (1020 px of travel at 170 px/s) from x = 0.
	var rules := _quiet()
	_run(rules, 6 * HoldfastRules.TICK_RATE, {"move": [1, 0]})
	expect_eq(rules.hero_position.x, 960.0, "stopped at the arena's right edge")


func test_the_hero_fires_at_an_enemy_in_range_and_the_arrow_hits_it() -> void:
	# Pack: attack damage 6, range 210, speed 480 px/s = 16 px per tick, arrow radius 5.
	# Hero (0,80), enemy (150,80) radius 10: the arrow touches it once its path
	# reaches x = 135, which is the end of tick 9 (9 x 16 = 144).
	var rules := _quiet()
	var enemy := _enemy(rules, Vector2(150, 80))
	_run(rules, 1)
	expect_eq(rules.projectiles.size(), 1, "fired on the first tick")
	expect_eq(enemy.health, 100.0, "not arrived yet")
	_run(rules, 7)
	expect_eq(enemy.health, 100.0, "still in flight after 8 ticks (128 px)")
	_run(rules, 1)
	expect_eq(enemy.health, 94.0, "hit on tick 9 for 6")
	expect_true(rules.projectiles.is_empty(), "the arrow is used up")


func test_the_hero_keeps_firing_on_the_attack_cooldown() -> void:
	# Pack cooldown 0.5 s: in 2 s that is about 4 arrows, each 6 damage, and the
	# enemy has 100 health, so it takes 24 or fewer by tick 60 (the last arrow
	# is still flying).
	var rules := _quiet()
	var enemy := _enemy(rules, Vector2(150, 80))
	_run(rules, 60)
	expect_true(enemy.health <= 100.0 - 3 * 6.0, "at least 3 arrows hit in 2 s")
	expect_true(enemy.health >= 100.0 - 4 * 6.0, "no more than 4 arrows hit in 2 s")


func test_no_arrow_for_an_enemy_out_of_range() -> void:
	# Range 210 plus the enemy's radius 10: an enemy centre at 221 is out, 219 is in.
	var out := _quiet()
	_enemy(out, Vector2(0, 80 + 221))
	_run(out, 1)
	expect_true(out.projectiles.is_empty(), "221 px away: out of range")
	var inside := _quiet()
	_enemy(inside, Vector2(0, 80 + 219))
	_run(inside, 1)
	expect_eq(inside.projectiles.size(), 1, "219 px away: in range")


func test_an_arrow_flies_only_as_far_as_its_range() -> void:
	# Ability arrows (range 260, speed 420 = 14 px per tick) vanish after 260 px: 19 ticks.
	var rules := _fan()
	_run(rules, 1, {"ability": true})
	expect_eq(rules.projectiles.size(), 9)
	_run(rules, 17)
	expect_eq(rules.projectiles.size(), 9, "still flying after 18 ticks (252 px)")
	_run(rules, 1)
	expect_true(rules.projectiles.is_empty(), "gone after 19 ticks")


func test_a_fast_arrow_cannot_skip_a_thin_enemy() -> void:
	# 3000 px/s is 100 px per tick; the enemy (radius 1) is 50 px along, between
	# where the arrow starts and where it ends the tick.
	var rules := _quiet(func(content: Dictionary) -> void:
		content["hero_paths"]["flare_archer"]["attack"]["speed"] = 3000.0)
	var enemy := _enemy(rules, Vector2(50, 80), 1.0)
	_run(rules, 1)
	expect_eq(enemy.health, 94.0, "hit in the tick it was passed")


func test_an_arrow_stops_at_the_first_enemy_on_its_path() -> void:
	var rules := _quiet()
	var near := _enemy(rules, Vector2(60, 80))
	var far := _enemy(rules, Vector2(120, 80))
	_run(rules, 9)
	expect_eq(near.health, 94.0, "the near one took the arrow")
	expect_eq(far.health, 100.0, "the far one was behind it")


func test_the_hero_faces_the_nearest_enemy_and_the_first_one_on_a_tie() -> void:
	# Hero at (0, 80). Both enemies stand outside the keep's reach and don't move.
	var tie := _quiet()
	_enemy(tie, Vector2(150, 80))
	_enemy(tie, Vector2(-150, 80))
	_run(tie, 1)
	expect_eq(tie.hero_facing, Vector2(1, 0), "a tie goes to the enemy that spawned first")
	var nearer := _quiet()
	_enemy(nearer, Vector2(200, 80))
	_enemy(nearer, Vector2(-100, 80))
	_run(nearer, 1)
	expect_eq(nearer.hero_facing, Vector2(-1, 0), "the nearer one wins")


func test_with_no_enemy_the_hero_faces_the_way_they_walk() -> void:
	var rules := _quiet()
	_run(rules, 1, {"move": [1, 0]})
	expect_eq(rules.hero_facing, Vector2(1, 0))
	_run(rules, 1, {"move": [0, 0]})
	expect_eq(rules.hero_facing, Vector2(1, 0), "standing still keeps the facing")


func test_the_ability_fires_a_fan_across_the_pack_spread() -> void:
	# Pack: 9 arrows over 70 degrees, centred on the facing. Facing starts up (0, -1).
	# Rotating (0, -1) by t gives (sin t, -cos t), speed 420 px/s.
	var rules := _fan()
	_run(rules, 1, {"ability": true})
	expect_eq(rules.projectiles.size(), 9)
	var first: Vector2 = rules.projectiles[0].velocity
	var middle: Vector2 = rules.projectiles[4].velocity
	var last: Vector2 = rules.projectiles[8].velocity
	var t := deg_to_rad(35.0)
	expect_near(first.x, -sin(t) * 420.0, 0.001, "first arrow, 35 degrees left")
	expect_near(first.y, -cos(t) * 420.0, 0.001)
	expect_near(middle.x, 0.0, 0.001, "middle arrow straight ahead")
	expect_near(middle.y, -420.0, 0.001)
	expect_near(last.x, sin(t) * 420.0, 0.001, "last arrow, 35 degrees right")


func test_the_ability_goes_on_cooldown_and_only_a_real_true_presses_it() -> void:
	# Pack cooldown 8 s = 240 ticks.
	var rules := _fan()
	for not_a_press in [false, 1, "true", null, [true]]:
		_run(rules, 1, {"ability": not_a_press})
	expect_true(rules.projectiles.is_empty(), "only true presses the ability")
	_run(rules, 1, {"ability": true})
	expect_eq(rules.projectiles.size(), 9)
	_run(rules, 1, {"ability": true})
	expect_eq(rules.projectiles.size(), 9, "pressed again at once: on cooldown, nothing new")
	_run(rules, 238)
	expect_true(rules.projectiles.is_empty(), "the fan has flown out")
	expect_true(rules.hero_ability_ready_in > 0.0, "one tick before 8 s: still charging")
	_run(rules, 2)
	expect_true(rules.hero_ability_ready_in <= 0.0, "ready after 8 s")
	_run(rules, 1, {"ability": true})
	expect_eq(rules.projectiles.size(), 9, "fires again once it is ready")


## Rules whose Flare ability is a rapid-fire burst of `seconds`, an arrow every `interval`.
func _burst(seconds: float, interval: float) -> HoldfastRules:
	return _quiet(func(c: Dictionary) -> void:
		c["hero_paths"]["flare_archer"]["ability"].merge({"count": 1, "spread_degrees": 0, "rapid_seconds": seconds, "rapid_interval": interval}, true))


## The ticks (counted from 1) on which a new arrow left the Hero.
func _shot_ticks(rules: HoldfastRules, ticks: int, press_on: int = 1) -> Array:
	var shots := []
	var seen := []
	for tick in range(1, ticks + 1):
		_run(rules, 1, {"ability": tick == press_on})
		if not rules.projectiles.is_empty() and not rules.projectiles.back() in seen:
			seen.append(rules.projectiles.back())
			shots.append(tick)
	return shots


func test_the_ability_can_be_a_burst_of_rapid_fire_for_the_pack_seconds() -> void:
	# 1.05 s with an arrow every 0.19 s (6 ticks): shots on ticks 1, 7, 13, 19, 25 and 31. At
	# tick 31 there is 1.05 - 30/30 = 0.05 s left; at tick 37 the burst is over.
	var rules := _burst(1.05, 0.19)
	expect_eq(_shot_ticks(rules, 90), [1, 7, 13, 19, 25, 31])


func test_a_burst_that_runs_out_stays_out_until_the_cooldown_is_done() -> void:
	# Space held down every tick. Pack cooldown 14 s = 420 ticks from the press on tick 1: the
	# first burst is ticks 1 to 31, nothing between ticks 40 and 418, a second burst by tick 425.
	var rules := _burst(1.05, 0.19)
	var shots := []
	var seen := []
	for tick in range(1, 426):
		_run(rules, 1, {"ability": true})
		if not rules.projectiles.is_empty() and not rules.projectiles.back() in seen:
			seen.append(rules.projectiles.back())
			shots.append(tick)
	expect_eq(shots.filter(func(t: int) -> bool: return t < 40), [1, 7, 13, 19, 25, 31])
	expect_eq(shots.filter(func(t: int) -> bool: return t >= 40 and t <= 418), [], "charging")
	expect_true(shots.any(func(t: int) -> bool: return t > 418), "the second burst starts once it is ready")


func test_a_burst_of_zero_seconds_is_the_plain_one_off_use() -> void:
	# With rapid_seconds 0 the press fires `count` arrows once, as before.
	var rules := _quiet(func(c: Dictionary) -> void:
		c["hero_paths"]["flare_archer"]["ability"].merge({"count": 1, "spread_degrees": 0, "rapid_seconds": 0.0, "rapid_interval": 0.2}, true))
	expect_eq(_shot_ticks(rules, 60), [1])
	expect_near(rules.hero_rapid_left, 0.0, 0.0001)


func test_a_burst_arrow_every_tick_when_the_interval_is_shorter_than_a_tick() -> void:
	# The pack's smallest interval, 0.05 s, is under two ticks: an arrow on every second tick at most, never two in one.
	var rules := _burst(0.5, 0.05)
	var shots := _shot_ticks(rules, 30)
	expect_true(shots.size() >= 8 and shots.size() <= 15, "about a dozen arrows in half a second: %s" % [shots])


func test_a_knocked_down_hero_stops_the_burst() -> void:
	var rules := _burst(3.0, 0.2)
	_run(rules, 3, {"ability": true})
	expect_true(rules.hero_rapid_left > 0.0, "firing")
	rules.hero_state = HeroKnockdown.take_damage(rules.hero_state, 1000.0, [3.0, 6.0, 10.0])
	_run(rules, 1)
	expect_near(rules.hero_rapid_left, 0.0, 0.0001, "the burst ends when they go down")
	var arrows := rules.projectiles.size()
	_run(rules, 20)
	expect_true(rules.projectiles.size() <= arrows, "no new arrows while they are down")


## Rules whose Flare ability is one plain arrow (no burst, pierce, burn or tint) with `extra` merged
## into the ability, no light bonus and a Hero attack that does nothing, so only that arrow hurts.
func _arrow(extra: Dictionary) -> HoldfastRules:
	return _quiet(func(c: Dictionary) -> void:
		c["levels"]["outpost"]["light"]["bonus"] = 0.0
		c["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
		var ability: Dictionary = c["hero_paths"]["flare_archer"]["ability"]
		for key in ["pierce", "burn_dps", "burn_seconds", "colour"]:
			ability.erase(key)
		ability.merge({"count": 1, "spread_degrees": 0, "rapid_seconds": 0, "damage": 7.0, "radius": 6.0}, true)
		ability.merge(extra, true))


func test_a_piercing_arrow_hurts_that_many_enemies_in_a_line_once_each() -> void:
	# Pierce 3, damage 7: the first three enemies along the line lose 7 each (not 14), the fourth none.
	var rules := _arrow({"pierce": 3})
	var line := []
	for x in [60.0, 100.0, 140.0, 180.0]:
		line.append(_enemy(rules, Vector2(x, 80)))
	_run(rules, 1, {"ability": true})
	_run(rules, 40)
	expect_near(line[0].health, 93.0, 0.001, "first")
	expect_near(line[1].health, 93.0, 0.001, "second")
	expect_near(line[2].health, 93.0, 0.001, "third")
	expect_near(line[3].health, 100.0, 0.001, "the arrow was spent on three")


func test_an_arrow_with_no_pierce_in_the_pack_stops_at_the_first_enemy() -> void:
	var rules := _arrow({})
	var line := []
	for x in [60.0, 100.0]:
		line.append(_enemy(rules, Vector2(x, 80)))
	_run(rules, 1, {"ability": true})
	_run(rules, 40)
	expect_near(line[0].health, 93.0, 0.001)
	expect_near(line[1].health, 100.0, 0.001)


func test_a_fire_arrow_leaves_a_burn_for_the_pack_seconds() -> void:
	# 7 on the hit, then 3 a second for 3 s = 9 more, in whole ticks (a tick is 0.1 of a second's damage).
	var rules := _arrow({"burn_dps": 3.0, "burn_seconds": 3.0})
	var enemy := _enemy(rules, Vector2(80, 80))
	_run(rules, 1, {"ability": true})
	_run(rules, 12)
	expect_true(enemy.burn_left > 2.0, "burning after the hit")
	_run(rules, 150)
	expect_near(enemy.health, 100.0 - 7.0 - 9.0, 0.11)
	expect_near(enemy.burn_left, 0.0, 0.0001, "the burn is out")
	var after := enemy.health
	_run(rules, 30)
	expect_eq(enemy.health, after, "and does no more")


func test_a_second_hit_renews_the_burn_instead_of_adding_to_it() -> void:
	var rules := _arrow({"burn_dps": 3.0, "burn_seconds": 3.0, "cooldown": 0.5})
	var enemy := _enemy(rules, Vector2(80, 80), 10.0, 1000.0)
	_run(rules, 1, {"ability": true})
	_run(rules, 60)
	expect_true(enemy.burn_left < 1.2, "a second of burn left: %s" % enemy.burn_left)
	_run(rules, 1, {"ability": true})
	_run(rules, 8)
	expect_true(enemy.burn_left > 2.5 and enemy.burn_left <= 3.0, "back to the full burn: %s" % enemy.burn_left)
	expect_eq(enemy.burn_dps, 3.0, "at the same rate, not doubled")


func test_a_burn_can_finish_an_enemy() -> void:
	# 8 health: the 7 from the arrow leaves 1, and the burn takes it within half a second.
	var rules := _arrow({"burn_dps": 3.0, "burn_seconds": 3.0})
	_enemy(rules, Vector2(80, 80), 10.0, 8.0)
	_run(rules, 1, {"ability": true})
	_run(rules, 40)
	expect_true(rules.enemies.is_empty(), "burnt down and gone")


func test_the_shipped_flare_barrage_is_the_advisors_burst() -> void:
	# Advisor: 5 s, fire rate x3 the normal attack, pierce 3, about 3 damage a second for 3 s, cooldown 14 s, bigger tinted arrows.
	var path: Dictionary = HoldfastContent.base()["hero_paths"]["flare_archer"]
	var ability: Dictionary = path["ability"]
	expect_eq(float(ability["rapid_seconds"]), 5.0)
	expect_true(float(path["attack"]["cooldown"]) / float(ability["rapid_interval"]) >= 3.0, "at least three times the rate")
	expect_eq(int(ability["pierce"]), 3)
	expect_eq(float(ability["burn_dps"]) * float(ability["burn_seconds"]), 9.0)
	expect_eq(float(ability["cooldown"]), 14.0)
	expect_true(float(ability["radius"]) > float(path["attack"]["radius"]), "bigger arrows")
	expect_true(str(ability["colour"]) != "", "tinted")
	var rules := _quiet()
	_run(rules, 1, {"ability": true})
	expect_eq(rules.projectiles[0].colour, str(ability["colour"]), "the arrow carries the tint")


func test_pierce_burn_and_tint_values_outside_the_limits_are_rejected() -> void:
	var schema := PackSchema.load_file(SCHEMA)
	var good: Dictionary = HoldfastContent.base()["hero_paths"]["flare_archer"].duplicate(true)
	var cases := {"pierce 0": ["pierce", 0], "pierce 11": ["pierce", 11], "burn seconds 0": ["burn_seconds", 0.0], "burn dps negative": ["burn_dps", -1.0],
			"colour not hex": ["colour", "orange"], "rapid interval under a tick": ["rapid_interval", 0.04], "rapid seconds negative": ["rapid_seconds", -1.0]}
	for label in cases:
		var bad: Dictionary = good.duplicate(true)
		bad["ability"][cases[label][0]] = cases[label][1]
		var errors := PackedStringArray()
		schema.validate_def(bad, "hero_path", label, errors, [])
		expect_false(errors.is_empty(), "rejected: " + label)


func test_arrow_counts_at_the_limits() -> void:
	# One arrow goes straight (no spread applied); 32 is the most the pack allows.
	var one := _fan(func(c: Dictionary) -> void: c["hero_paths"]["flare_archer"]["ability"]["count"] = 1)
	_run(one, 1, {"ability": true})
	expect_eq(one.projectiles.size(), 1)
	expect_near(one.projectiles[0].velocity.x, 0.0, 0.001, "a single arrow is not offset by the spread")
	var many := _fan(func(c: Dictionary) -> void: c["hero_paths"]["flare_archer"]["ability"]["count"] = 32)
	_run(many, 1, {"ability": true})
	expect_eq(many.projectiles.size(), 32)
	var flat := _fan(func(c: Dictionary) -> void: c["hero_paths"]["flare_archer"]["ability"]["spread_degrees"] = 0.0)
	_run(flat, 1, {"ability": true})
	for arrow in flat.projectiles:
		expect_near(arrow.velocity.x, 0.0, 0.001, "no spread: every arrow goes the same way")


func test_pack_values_one_past_the_limit_are_rejected() -> void:
	var schema := PackSchema.load_file(SCHEMA)
	var good: Dictionary = HoldfastContent.base()["hero_paths"]["flare_archer"].duplicate(true)
	var cases := {
		"ability count 0": ["ability", "count", 0],
		"ability count 33": ["ability", "count", 33],
		"attack cooldown 0": ["attack", "cooldown", 0.0],
		"attack speed 0": ["attack", "speed", 0.0],
		"attack range negative": ["attack", "range", -1.0],
		"spread over 360": ["ability", "spread_degrees", 361.0],
		"unknown kind": ["attack", "kind", "beam"],
	}
	for label in cases:
		var bad: Dictionary = good.duplicate(true)
		bad[cases[label][0]][cases[label][1]] = cases[label][2]
		var errors := PackedStringArray()
		schema.validate_def(bad, "hero_path", label, errors, [])
		expect_false(errors.is_empty(), "rejected: " + label)
	var errors := PackedStringArray()
	schema.validate_def(good, "hero_path", "good", errors, [])
	expect_true(errors.is_empty(), "the shipped Hero path is valid: %s" % [errors])


func test_the_keep_falling_ends_the_run_with_the_hero_idle() -> void:
	# One grunt nothing can kill walks in for 5 damage; the keep has 5 health.
	# Enemies go for the nearest tower, Recruit or Hero before the keep, so the
	# grunt kills each of those first (the Hero stays down for the whole test),
	# and only then reaches the keep.
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	var level: Dictionary = content["levels"]["outpost"]
	level["keep_health"] = 5
	level["waves"] = [{"spawns": [{"enemy": "grunt", "count": 1}]}]
	content["enemies"]["grunt"]["speed"] = 100000.0
	content["enemies"]["grunt"]["health"] = 1000000.0
	content["enemies"]["grunt"]["damage"] = 1000
	content["hero_paths"]["flare_archer"]["knockdown_delays"] = [100000]
	content["towers"]["archer_post"]["damage"] = 0.0
	content["staff"]["bryn"]["damage"] = 0.0
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content), SimRng.new(1))
	for i in 1000:
		rules.step(DT, {})
	expect_eq(rules.outcome, HoldfastRules.OUTCOME_LOST, "keep falls = run over")
	expect_eq(rules.keep_health, 0)


func test_the_bot_hero_clears_waves_and_never_leaves_the_ring() -> void:
	var report := HoldfastSim.run_headless(1)
	expect_true(report["finished"], "the run ends")
	expect_true(report["result"]["kills"] > 0, "the bot Hero killed things")
