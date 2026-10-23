extends KitTestCase
## HF-M2-34: the six Hero and tower links. Each is a star node in the tree that joins a Hero
## to the Archer Posts, and each has a test of its effect and of its absence. Numbers are
## worked by hand from the pack: the Outpost's post at (-90, 30) with range 170, cooldown 1 s,
## health 60; the Hero starts at (0, 80), shoots 210 from where they stand, and has 60 health.

const DT := 1.0 / HoldfastRules.TICK_RATE
const BIG := 1000000.0
const LINKS := ["link_lit_post", "link_pillar_echo", "link_rally", "link_last_light", "link_watchtower", "link_crossfire"]
## The Advisor's table: what each link needs, and its cost in stars.
const NEEDS := {
	"link_lit_post": [["post_rate"], 1],
	"link_pillar_echo": [["link_lit_post", "flare_embers"], 2],
	"link_rally": [["post_mend"], 1],
	"link_last_light": [["link_rally", "post_timbers"], 2],
	"link_watchtower": [["post_sight"], 1],
	"link_crossfire": [["castle_archer_2"], 2],
}
const POST := Vector2(-90, 30)


func _nodes() -> Dictionary:
	return HoldfastContent.base()["upgrade_nodes"]


## Rules with nothing happening: no wave for 1000 s, the Hero and Recruits harmless, and the
## post doing `post_damage` a shot. `layout` names the posts (null for the Outpost's one).
func _rules(upgrades: Array, post_damage := 0.0, layout: Variant = null) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = post_damage
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	content["levels"]["outpost"]["staff"].erase("post")
	for at in content["levels"]["outpost"]["recruits"]:
		at.erase("post")
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", upgrades, content, "flare_archer", layout), SimRng.new(1))
	return rules


## The Hero is down and stays down for the length of a test.
func _down(rules: HoldfastRules) -> void:
	rules.hero_state["downed"] = true
	rules.hero_state["get_up_in"] = 100.0


func _enemy(rules: HoldfastRules, at: Vector2, health := BIG) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	enemy.speed = 0.0
	enemy.damage = 0
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


## Every upgrade a link needs, and the links before it, so a run can own it.
func _with(link: String) -> Array:
	var out := []
	_collect(link, out)
	return out


func _collect(id: String, out: Array) -> void:
	for required in _nodes()[id].get("requires", []):
		_collect(required, out)
	if not id in out:
		out.append(id)


# ------------------------------------------------------------------ the nodes

func test_each_link_is_a_star_node_that_needs_what_the_advisor_says() -> void:
	for id in LINKS:
		var node: Dictionary = _nodes()[id]
		expect_true(HoldfastMeta.is_star_node(node), id + " costs stars")
		expect_eq(int(node["cost"]), int(NEEDS[id][1]), id + " cost")
		expect_eq(Array(node["requires"]), NEEDS[id][0], id + " needs")
		expect_eq(node["branch"], "archer_post", id + " sits in the Archer Post section")
		expect_true(str(node.get("text", "")) != "", id + " says what it does")


func test_a_link_cannot_be_bought_before_what_it_needs() -> void:
	var content := HoldfastContent.base()
	for id in LINKS:
		var profile := HoldfastMeta.new_profile(content)
		profile["pillar"] = "flare_archer"
		profile["stars"] = {"x": 99}
		expect_true(HoldfastMeta.why_not_buy(content, profile, id).begins_with("Needs"), id + " is closed at the start")
		profile["upgrades"] = _with(id).filter(func(other: String) -> bool: return other != id)
		expect_eq(HoldfastMeta.why_not_buy(content, profile, id), "", id + " opens once its requirements are owned")


func test_the_second_and_third_archer_need_the_slot_they_will_stand_in() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile["stars"] = {"x": 99}
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1"]
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_archer_2"), "Needs Second Slot first")
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1", "castle_slot_2"]
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_archer_2"), "")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_archer_3"), "Needs Second Archer first")
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"]
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_archer_3"), "Needs Third Slot first")
	profile["upgrades"].append("castle_slot_3")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "castle_archer_3"), "")


func test_every_link_effect_is_read_by_the_rules() -> void:
	var rules := _rules(_with_all())
	var post: HoldfastRules.Attacker = rules.tower
	expect_near(post.hero_haste, 0.25, 0.0001)
	expect_eq(post.hero_radius, 150.0)
	expect_near(post.crossfire, 0.2, 0.0001)
	expect_eq(post.burn_dps, 2.0)
	expect_eq(post.burn_seconds, 3.0)
	expect_eq(post.rally_repair, 6.0)
	expect_near(post.rally_shield, 0.5, 0.0001)
	expect_eq(post.rally_radius, 90.0)
	expect_eq(post.rally_seconds, 3.0)
	expect_eq(post.last_light, 4.0)
	expect_eq(post.last_light_radius, 220.0)
	expect_eq(post.watch_range, 40.0)
	expect_eq(post.watch_radius, 130.0)
	var none := _rules([])
	expect_false(none.tower.links, "a post with no links carries none")
	expect_true(post.links)


func _with_all() -> Array:
	var out := []
	for id in LINKS:
		_collect(id, out)
	return out


# ------------------------------------------------------------------ Lit Post

func _shots_in_a_hundred_seconds(upgrades: Array, hero_at: Vector2) -> int:
	var rules := _rules(upgrades, 5.0)
	rules.hero_position = hero_at
	_enemy(rules, POST + Vector2(0, -90))
	_run(rules, 3000)
	return rules.tower.shots


func _ready_in_after_first_shot(upgrades: Array, hero_at: Vector2, downed: bool) -> float:
	var rules := _rules(upgrades, 5.0)
	rules.hero_position = hero_at
	if downed:
		_down(rules)
	_enemy(rules, POST + Vector2(0, -90))
	_run(rules, 1)
	return rules.tower.ready_in


func test_lit_post_makes_a_post_shoot_a_quarter_faster_with_the_hero_close() -> void:
	var owned := _with("link_lit_post")
	var bare := owned.filter(func(id: String) -> bool: return id != "link_lit_post")
	# Quick hands (a step on the way) already cut the cooldown to 0.75 s: 133 shots in 100 s.
	var base := _shots_in_a_hundred_seconds(bare, POST + Vector2(60, 0))
	expect_near(base, 133.0, 2.0, "Quick hands alone")
	expect_eq(_shots_in_a_hundred_seconds(owned, POST + Vector2(700, 0)), base, "Hero far: no change")
	# A quarter faster is a cooldown of 0.6 s, which the 30-tick clock rounds up to 19 ticks: about 158.
	var near := _shots_in_a_hundred_seconds(owned, POST + Vector2(60, 0))
	expect_true(near > base * 1.18 and near < base * 1.27, "Hero close: shots %d against %d" % [near, base])
	expect_near(_ready_in_after_first_shot(owned, POST + Vector2(60, 0), false), 0.6, 0.0001, "0.75 s cooldown over 1.25")
	expect_near(_ready_in_after_first_shot(owned, POST + Vector2(700, 0), false), 0.75, 0.0001, "far: the plain cooldown")


func test_lit_post_stops_when_the_hero_is_down() -> void:
	expect_near(_ready_in_after_first_shot(_with("link_lit_post"), POST + Vector2(60, 0), true), 0.75, 0.0001)


# ------------------------------------------------------------------ Crossfire

## What two posts (castle spots 1 and 2) take off one enemy standing in range of both in one tick.
func _crossfire_loss(upgrades: Array, layout: Array) -> float:
	var rules := _rules(upgrades, 10.0, layout)
	var enemy := _enemy(rules, Vector2(0, -50))
	_run(rules, 1)
	return BIG - enemy.health


func test_crossfire_adds_a_fifth_when_a_second_post_hits_the_same_enemy() -> void:
	var owned := _with("link_crossfire")
	var bare := owned.filter(func(id: String) -> bool: return id != "link_crossfire")
	var two := ["spot_1", "spot_2"]
	var plain := _crossfire_loss(bare, two)
	# Both shots are the same size, so the second counts 1.2 times: 2.2 shots in all.
	expect_near(_crossfire_loss(owned, two) / plain, 2.2 / 2.0, 0.001, "two posts")
	expect_near(_crossfire_loss(owned, ["spot_1"]) / (plain / 2.0), 1.0, 0.001, "a lone post gains nothing")


## What one post's shot takes off an enemy another post (`by`) last shot `ago` seconds back.
func _after_another_post(by: String, ago: float) -> float:
	var rules := _rules(_with("link_crossfire"), 10.0, ["spot_1"])
	var enemy := _enemy(rules, Vector2(0, -50))
	enemy.shot_by = by if by != "" else rules.tower.key
	enemy.shot_at = rules.time - ago
	_run(rules, 1)
	return BIG - enemy.health


func test_crossfire_needs_a_different_post_and_a_recent_hit() -> void:
	var plain := _after_another_post("tower:elsewhere", 100.0)
	expect_true(plain > 0.0)
	expect_near(_after_another_post("tower:elsewhere", 0.5) / plain, 1.2, 0.001, "another post, half a second ago")
	expect_near(_after_another_post("tower:elsewhere", 5.0) / plain, 1.0, 0.001, "five seconds ago is too old")
	expect_near(_after_another_post("", 0.5) / plain, 1.0, 0.001, "the same post twice gains nothing")


# ------------------------------------------------------------------ Pillar Echo

func test_pillar_echo_sets_what_a_post_hits_burning() -> void:
	var owned := _with("link_pillar_echo")
	var rules := _rules(owned)
	var enemy := _enemy(rules, POST + Vector2(0, -90))
	_run(rules, 60)
	expect_eq(enemy.burn_dps, 2.0)
	expect_true(enemy.burn_left > 2.0 and enemy.burn_left <= 3.0, "three seconds, refreshed by each shot: %s" % enemy.burn_left)
	# Two seconds of 2 a second, less the first tick: a little under 4.
	var lost := BIG - enemy.health
	expect_true(lost > 3.5 and lost < 4.0, "burned for %s" % lost)
	var bare := _rules(owned.filter(func(id: String) -> bool: return id != "link_pillar_echo"))
	var plain := _enemy(bare, POST + Vector2(0, -90))
	_run(bare, 60)
	expect_eq(plain.burn_dps, 0.0, "no node, no burn")
	expect_eq(plain.health, BIG)


# ------------------------------------------------------------------ Rally

func test_rally_repairs_and_shields_a_post_the_hero_holds_beside() -> void:
	var owned := _with("link_rally")
	var rules := _rules(owned)
	rules.tower.health = UnitHealth.damage(rules.tower.health, 30.0)
	var hurt: float = rules.tower.health["health"]
	rules.hero_position = POST + Vector2(50, 0)
	# A bystander on the field, so this is not the between-waves repair.
	_enemy(rules, Vector2(800, 800))
	_run(rules, 30)
	expect_near(rules.tower.health["health"], hurt + 6.0, 0.01, "6 a second")
	expect_near(rules.tower.shield_left, 3.0, 0.01)
	rules._hit_unit(rules.tower, 20.0)
	expect_near(rules.tower.health["health"], hurt + 6.0 - 10.0, 0.01, "half of 20 turned away")


func test_rally_shield_lingers_three_seconds_and_needs_the_hero_to_hold_still() -> void:
	var rules := _rules(_with("link_rally"))
	rules.hero_position = POST + Vector2(50, 0)
	_run(rules, 1)
	expect_near(rules.tower.shield_left, 3.0, 0.01)
	# Walking away (and so not holding) lets it run down.
	_run(rules, 60, {"move": [1.0, 0.0]})
	expect_near(rules.tower.shield_left, 1.0, 0.05, "two of the three seconds gone")
	_run(rules, 40, {"move": [1.0, 0.0]})
	expect_eq(rules.tower.shield_left, 0.0)
	# Walking beside it is not holding.
	var walking := _rules(_with("link_rally"))
	walking.hero_position = POST + Vector2(10, 0)
	walking.tower.health = UnitHealth.damage(walking.tower.health, 30.0)
	var hurt: float = walking.tower.health["health"]
	_enemy(walking, Vector2(800, 800))
	_run(walking, 30, {"move": [0.0, 1.0]})
	expect_eq(walking.tower.health["health"], hurt, "no repair while moving")
	expect_eq(walking.tower.shield_left, 0.0)


func test_rally_does_nothing_far_away_without_the_node_or_for_a_downed_hero() -> void:
	var far := _rules(_with("link_rally"))
	far.hero_position = POST + Vector2(400, 0)
	far.tower.health = UnitHealth.damage(far.tower.health, 30.0)
	var far_hurt: float = far.tower.health["health"]
	_enemy(far, Vector2(800, 800))
	_run(far, 30)
	expect_eq(far.tower.health["health"], far_hurt)
	var bare := _rules(_with("link_rally").filter(func(id: String) -> bool: return id != "link_rally"))
	bare.hero_position = POST + Vector2(50, 0)
	_enemy(bare, Vector2(800, 800))
	bare.tower.health = UnitHealth.damage(bare.tower.health, 30.0)
	var bare_hurt: float = bare.tower.health["health"]
	_run(bare, 30)
	expect_eq(bare.tower.health["health"], bare_hurt, "no node: no repair while enemies are about")
	bare._hit_unit(bare.tower, 20.0)
	expect_eq(bare.tower.health["health"], bare_hurt - 20.0, "and no shield")
	var down := _rules(_with("link_rally"))
	down.hero_position = POST + Vector2(50, 0)
	_down(down)
	down.tower.health = UnitHealth.damage(down.tower.health, 30.0)
	var down_hurt: float = down.tower.health["health"]
	_enemy(down, Vector2(800, 800))
	_run(down, 30)
	expect_eq(down.tower.health["health"], down_hurt)


# ------------------------------------------------------------------ Last Light

## What one blow of `blow` to a post left at `left` health costs an enemy over the next tick, and whether the post flared.
func _flare(upgrades: Array, hero_at: Vector2, blow: float, left := 20.0) -> Array:
	var rules := _rules(upgrades, 5.0)
	rules.hero_position = hero_at
	var enemy := _enemy(rules, POST + Vector2(0, -90))
	rules.tower.health = UnitHealth.damage(rules.tower.health, float(rules.tower.health["max_health"]) - left)
	rules._hit_unit(rules.tower, blow)
	_run(rules, 1)
	return [BIG - enemy.health, rules.tower.last_light_spent]


func test_last_light_fires_one_big_volley_when_a_post_is_about_to_fall_with_the_hero_close() -> void:
	var owned := _with("link_last_light")
	var plain := _flare(owned, POST + Vector2(700, 0), 6.0)
	var shot: float = plain[0]
	expect_true(shot > 0.0)
	expect_false(plain[1], "the Hero is too far: no flare")
	var flared := _flare(owned, POST + Vector2(100, 0), 6.0)
	expect_true(flared[1])
	# The post's own shot, plus four times its damage on top.
	expect_near(float(flared[0]) / shot, 5.0, 0.001)
	var quiet := _flare(owned, POST + Vector2(100, 0), 2.0, 40.0)
	expect_eq(float(quiet[0]) / shot, 1.0, "still above a quarter of its health: no flare")
	expect_false(quiet[1])
	var bare := _flare(owned.filter(func(id: String) -> bool: return id != "link_last_light"), POST + Vector2(100, 0), 6.0)
	expect_eq(float(bare[0]) / shot, 1.0, "no node: no volley")


func test_last_light_flares_once_until_the_post_is_mended() -> void:
	var rules := _rules(_with("link_last_light"), 5.0)
	rules.hero_position = POST + Vector2(100, 0)
	var enemy := _enemy(rules, POST + Vector2(0, -90))
	rules.tower.health = UnitHealth.damage(rules.tower.health, float(rules.tower.health["max_health"]) - 20.0)
	rules._hit_unit(rules.tower, 1.0)
	_run(rules, 1)
	var first := BIG - enemy.health
	expect_true(first > 0.0)
	rules._hit_unit(rules.tower, 1.0)
	enemy.health = BIG
	_run(rules, 30)
	expect_true(BIG - enemy.health < first, "the second blow does not flare again")
	rules.tower.health = UnitHealth.repair(rules.tower.health, 100.0)
	rules._hit_unit(rules.tower, 1.0)
	expect_false(rules.tower.last_light_spent, "mended past half: ready again")
	rules.tower.health = UnitHealth.damage(rules.tower.health, float(rules.tower.health["health"]) - 20.0)
	rules._hit_unit(rules.tower, 1.0)
	expect_true(rules.tower.last_light_due, "and it flares again")


func test_a_post_that_falls_outright_does_not_flare() -> void:
	var rules := _rules(_with("link_last_light"), 5.0)
	rules.hero_position = POST + Vector2(100, 0)
	_enemy(rules, POST + Vector2(0, -90))
	rules._hit_unit(rules.tower, 500.0)
	expect_false(rules.tower.up)
	expect_false(rules.tower.last_light_due)


# ------------------------------------------------------------------ Watchtower

## How far the Hero's arrow flies when shot with an enemy 150 away, the Hero at `hero_at`.
func _arrow_reach(upgrades: Array, hero_at: Vector2) -> float:
	var rules := _rules(upgrades)
	rules.hero_position = hero_at
	var target := hero_at + Vector2(150, 0)
	_enemy(rules, Vector2(clampf(target.x, -900, 900), target.y))
	_run(rules, 1)
	return rules.projectiles[0].distance_left if not rules.projectiles.is_empty() else -1.0


func test_watchtower_gives_the_hero_beside_a_post_more_range() -> void:
	var owned := _with("link_watchtower")
	var bare := owned.filter(func(id: String) -> bool: return id != "link_watchtower")
	var near := _arrow_reach(owned, POST + Vector2(50, 0))
	var base := _arrow_reach(bare, POST + Vector2(50, 0))
	expect_true(base > 0.0)
	expect_near(near - base, 40.0, 0.001, "40 further beside a post")
	expect_near(_arrow_reach(owned, POST + Vector2(400, 0)) - base, 0.0, 0.001, "Hero far from every post: no change")


func test_watchtower_lets_the_hero_shoot_what_was_just_out_of_reach() -> void:
	var owned := _with("link_watchtower")
	var bare := owned.filter(func(id: String) -> bool: return id != "link_watchtower")
	for case in [[owned, true], [bare, false]]:
		var rules := _rules(case[0])
		rules.hero_position = POST + Vector2(50, 0)
		# 240 away: past the 210 + 10 radius, inside 250 + 10.
		_enemy(rules, rules.hero_position + Vector2(240, 0))
		_run(rules, 1)
		expect_eq(not rules.projectiles.is_empty(), case[1], "shot taken: %s" % case[1])


# ------------------------------------------------------------------ the Hero is not nerfed

func test_the_links_leave_the_hero_as_strong_as_before() -> void:
	var steps := []
	for id in _with_all():
		if not id in LINKS:
			steps.append(id)
	var with_all := _rules(_with_all())
	var without := _rules(steps)
	expect_eq(with_all.hero_attack, without.hero_attack)
	expect_eq(with_all.hero_ability, without.hero_ability)
	expect_eq(with_all.hero_speed, without.hero_speed)
	expect_eq(with_all.hero_state["health"], without.hero_state["health"])
