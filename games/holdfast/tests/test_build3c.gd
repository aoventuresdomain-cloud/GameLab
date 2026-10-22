extends KitTestCase
## Build 3c (HF-M2-21): monsters head for the tower and go for the Hero or a Recruit
## only up close. Expected values are worked by hand from the Outpost and the pack:
## keep (0, 0); tower at (-90, 30), radius 14; Wren at (-118, 58); Hero starts at
## (0, 80), radius 12; enemy radius 10; every enemy's engage_distance is 160.

const DT := 1.0 / HoldfastRules.TICK_RATE
const BIG := 1000000.0
const TOWER_AT := Vector2(-90, 30)
const WREN_AT := Vector2(-118, 58)


## Rules with no wave for 1000 s, nothing of ours doing damage and no staffed post.
func _quiet(edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	content["levels"]["outpost"]["staff"].erase("post")
	for at in content["levels"]["outpost"]["recruits"]:
		at.erase("post")
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, "flare_archer"), SimRng.new(1))
	return rules


## A standing enemy (speed 0 unless given) that goes for anyone within `engage`.
func _enemy(rules: HoldfastRules, at: Vector2, engage: float, damage: int = 0, speed: float = 0.0) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = BIG
	enemy.max_health = BIG
	enemy.radius = 10.0
	enemy.speed = speed
	enemy.damage = damage
	enemy.engage_distance = engage
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int) -> void:
	for i in ticks:
		rules.step(DT, {})


## One tick later, whom the enemy has picked.
func _target(rules: HoldfastRules, enemy: HoldfastRules.Enemy) -> String:
	_run(rules, 1)
	return enemy.target


# ------------------------------------------------------------------ the pure filter

func _cand(id: String, x: float, taunt := 0.0, always := false) -> Dictionary:
	return {"id": id, "pos": Vector2(x, 0), "taunt_radius": taunt, "downed": false, "always": always}


func _ids(list: Array) -> Array:
	return list.map(func(c: Dictionary) -> String: return c["id"])


func test_a_unit_is_in_reach_exactly_at_the_distance_but_not_just_outside() -> void:
	var at := _cand("a", 100.0)
	expect_eq(_ids(EnemyTargeting.within_reach(Vector2.ZERO, [at], 100.0)), ["a"], "exactly at the distance")
	expect_eq(_ids(EnemyTargeting.within_reach(Vector2.ZERO, [at], 99.9)), [], "just outside")
	expect_eq(_ids(EnemyTargeting.within_reach(Vector2.ZERO, [_cand("b", 100.1)], 100.0)), [], "a hair further")


func test_a_zero_distance_means_never_even_on_top_of_the_enemy() -> void:
	expect_eq(_ids(EnemyTargeting.within_reach(Vector2.ZERO, [_cand("a", 0.0), _cand("b", 5.0)], 0.0)), [])


func test_the_tower_is_always_open_and_a_taunt_reaches_by_its_own_radius() -> void:
	var list := [_cand("tower", 5000.0, 0.0, true), _cand("far", 5000.0), _cand("warden", 130.0, 130.0), _cand("late", 131.0, 130.0)]
	expect_eq(_ids(EnemyTargeting.within_reach(Vector2.ZERO, list, 100.0)), ["tower", "warden"], "the tower at any distance, a taunt to its edge")
	expect_eq(_ids(EnemyTargeting.within_reach(Vector2.ZERO, list, 0.0)), ["tower", "warden"], "a zero distance does not switch off a taunt")


# ------------------------------------------------------------------ in the rules

func test_an_enemy_goes_for_the_tower_by_default_and_the_hero_only_inside_the_distance() -> void:
	# Enemy (300, 0); the Hero at (200, 0) is exactly 100 away, the tower 391.
	var cases := {100.0: "hero", 99.9: "tower:archer_post", 0.0: "tower:archer_post"}
	for engage in cases:
		var rules := _quiet()
		rules.hero_position = Vector2(200, 0)
		var enemy := _enemy(rules, Vector2(300, 0), engage)
		expect_eq(_target(rules, enemy), cases[engage], "engage %s" % engage)


func test_an_enemy_far_from_everyone_heads_for_the_tower_not_the_hero() -> void:
	var rules := _quiet()
	rules.hero_position = Vector2(0, 80)
	var enemy := _enemy(rules, Vector2(400, 0), 160.0, 0, 56.0)
	_run(rules, 3)
	expect_eq(enemy.target, "tower:archer_post")
	expect_true(enemy.position.x < 400.0 and enemy.position.y > -1.0 and enemy.position.y < 1.0 + 10.0, "and walks")
	var before := enemy.position.distance_to(TOWER_AT)
	_run(rules, 30)
	expect_true(enemy.position.distance_to(TOWER_AT) < before, "closer to the tower, not the Hero (a nearer target when it was picked would have turned it)")


func test_a_recruit_follows_the_same_rule_as_the_hero() -> void:
	# Wren (-118, 58); the enemy 100 below her at (-118, 158); the tower is 131 away.
	var cases := {100.0: "recruit:wren", 99.9: "tower:archer_post"}
	for engage in cases:
		var rules := _quiet()
		rules.hero_position = Vector2(400, 300)
		var enemy := _enemy(rules, Vector2(-118, 158), engage)
		expect_eq(_target(rules, enemy), cases[engage], "engage %s" % engage)


func test_an_enemy_at_the_tower_keeps_hitting_it_while_the_hero_stands_nearby_but_outside_the_distance() -> void:
	# The enemy touches the tower (distance 24). The Hero 120 away is outside 100.
	var rules := _quiet()
	var enemy := _enemy(rules, TOWER_AT + Vector2(24, 0), 100.0, 5)
	rules.hero_position = enemy.position + Vector2(0, 120)
	_run(rules, 100)
	expect_eq(enemy.target, "tower:archer_post")
	expect_eq(rules.tower.health["health"], 60.0 - 5.0 * 4.0, "four hits of 5 in a little over 3 s (one a second, the first at once)")
	expect_eq(rules.hero_state["health"], rules.hero_state["max_health"], "the Hero untouched")


func test_an_enemy_at_the_tower_ignores_a_hero_standing_on_it_when_its_distance_is_zero() -> void:
	# The Hero is 5 away, nearer than the tower (24), but a distance of 0 means never.
	var rules := _quiet()
	var enemy := _enemy(rules, TOWER_AT + Vector2(24, 0), 0.0, 5)
	rules.hero_position = enemy.position + Vector2(5, 0)
	_run(rules, 40)
	expect_eq(enemy.target, "tower:archer_post")
	expect_eq(rules.hero_state["health"], rules.hero_state["max_health"], "the Hero untouched")


func test_an_enemy_at_the_tower_goes_for_a_hero_inside_the_distance_only_when_nearer_than_the_tower() -> void:
	var rules := _quiet()
	var enemy := _enemy(rules, TOWER_AT + Vector2(24, 0), 100.0, 5)
	rules.hero_position = enemy.position + Vector2(0, 60)
	expect_eq(_target(rules, enemy), "tower:archer_post", "inside the distance but the tower is nearer (24 against 60)")
	rules.hero_position = enemy.position + Vector2(0, 20)
	_run(rules, HoldfastRules.RETARGET_TICKS)
	expect_eq(enemy.target, "hero", "20 away is nearer than the tower")


func test_an_enemy_drops_a_hero_who_runs_out_of_the_distance_and_does_not_follow() -> void:
	var rules := _quiet()
	var enemy := _enemy(rules, Vector2(300, 0), 100.0, 0, 56.0)
	rules.hero_position = Vector2(250, 0)
	expect_eq(_target(rules, enemy), "hero")
	rules.hero_position = Vector2(0, 80)   # the Hero leaves: 300+ away
	_run(rules, HoldfastRules.RETARGET_TICKS)
	expect_eq(enemy.target, "tower:archer_post", "back to the tower within a retarget")
	var gap := enemy.position.distance_to(TOWER_AT)
	_run(rules, 60)
	expect_true(enemy.position.distance_to(TOWER_AT) < gap, "and it keeps walking that way")


func test_with_the_tower_down_an_enemy_heads_for_the_keep_unless_someone_is_close() -> void:
	var rules := _quiet()
	var killer := _enemy(rules, TOWER_AT, 0.0, 1000)
	_run(rules, 2)
	expect_false(rules.tower.up, "the tower is down")
	rules.enemies.erase(killer)
	rules.hero_position = Vector2(0, 200)
	var far := _enemy(rules, Vector2(300, 0), 100.0)
	expect_eq(_target(rules, far), "", "nobody close: the keep")
	rules.hero_position = Vector2(250, 0)
	_run(rules, HoldfastRules.RETARGET_TICKS)
	expect_eq(far.target, "hero", "the Hero inside the distance")


func test_enemies_spawn_with_the_distance_of_their_type_from_the_pack() -> void:
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], {}, "flare_archer"), SimRng.new(1))
	_run(rules, 120)
	expect_true(rules.enemies.size() > 0, "a wave has started")
	for enemy in rules.enemies:
		expect_eq(enemy.engage_distance, 160.0, enemy.type)


# ------------------------------------------------------------------ the pack

func test_every_enemy_type_has_a_positive_distance_and_the_schema_requires_one() -> void:
	var pack := PackLoader.load_pack(HoldfastContent.BASE_PACK, HoldfastContent.SCHEMA)
	expect_true(pack.ok)
	for id in HoldfastContent.base()["enemies"]:
		expect_true(float(HoldfastContent.base()["enemies"][id]["engage_distance"]) > 0.0, id + " has a close distance")
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var good := {"id": "x", "name": "X", "health": 5, "speed": 5, "radius": 5, "damage": 1, "gold": 1, "engage_distance": 0}
	for case in [["", true], ["missing", false], ["negative", false]]:
		var enemy := good.duplicate()
		if case[0] == "missing":
			enemy.erase("engage_distance")
		if case[0] == "negative":
			enemy["engage_distance"] = -1
		var errors: PackedStringArray = []
		schema.validate_def(enemy, "enemy", "enemies.json: $", errors, [])
		expect_eq(errors.is_empty(), case[1], "%s: %s" % [case[0], str(errors)])
