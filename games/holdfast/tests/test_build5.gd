extends KitTestCase
## Build 5 (HF-M2-26): the Flare Archer and Archer Post tree, Archer Post sites and
## spawn arcs, and the planning screen. Expected numbers are worked by hand from the
## pack values noted beside them.

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://build5_tests"
const DT := 1.0 / HoldfastRules.TICK_RATE
const ALL_PILLARS := ["flare_archer", "dusk_mage", "tideblade"]


# ------------------------------------------------------------------ helpers

## Rules with no wave for 1000 s, no light bonus, and only the Archer Posts able to
## hurt anything (their damage is `post_damage`); `edit` may change the content copy.
func _world(upgrades: Array = [], layout: Variant = null, level := "outpost", post_damage := 0.0, edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"][level]["first_wave_delay"] = 1000.0
	content["levels"][level]["light"]["bonus"] = 0.0
	content["levels"][level]["staff"].erase("post")
	for at in content["levels"][level]["recruits"]:
		at.erase("post")
	content["towers"]["archer_post"]["damage"] = post_damage
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config(level, upgrades, content, "flare_archer", layout), SimRng.new(1))
	return rules


func _enemy(rules: HoldfastRules, at: Vector2, health := 1000.0) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	enemy.speed = 0.0
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int) -> void:
	for i in ticks:
		rules.step(DT, {})


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


func _main(path: String = "") -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	if path != "":
		main.get_node("Profile").save_path = path
	tree.root.add_child(main)
	return main


# ------------------------------------------------------------------ sites and layouts

func test_a_level_builds_an_archer_post_on_each_chosen_site() -> void:
	var one := _world([], ["north_gate"])
	expect_eq(one.towers.size(), 1)
	expect_eq(one.tower.position, Vector2(-20, -100), "outpost north gate")
	expect_eq(one.layout_ids, ["north_gate"])
	var two := _world([], ["west_gate", "east_gate"], "shingle_beach")
	expect_eq(two.towers.size(), 2, "shingle beach allows two posts")
	expect_eq(two.towers[0].position, Vector2(-95, -20))
	expect_eq(two.towers[1].position, Vector2(100, -10))
	expect_eq(two.towers[0].key, "tower:archer_post", "the first keeps the tower's own key")
	expect_eq(two.towers[1].key, "tower:archer_post@east_gate", "the second adds its site")
	expect_true(two.tower == two.towers[0], "`tower` is the first post")


func test_without_a_layout_the_first_site_is_used_and_a_bad_layout_is_refused() -> void:
	var rules := _world()
	expect_eq(rules.tower.position, Vector2(-90, 30), "the old tower place")
	for bad in [[], ["no_such_site"], ["west_gate", "east_gate"], "west_gate"]:
		var refused := _world([], bad)
		expect_eq(refused.outcome, HoldfastRules.OUTCOME_INVALID, "refused: " + str(bad))
		expect_true(refused.setup_error.contains("layout"), "and says why: " + refused.setup_error)
	var twice := _world([], ["west_gate", "west_gate"], "shingle_beach")
	expect_eq(twice.outcome, HoldfastRules.OUTCOME_INVALID, "the same site twice (two posts are allowed here)")
	# A config with no layout at all, as the rules get it from a hand-made test config.
	var config := HoldfastContent.run_config("outpost", [], {}, "flare_archer")
	config.erase("layout")
	var bare := HoldfastRules.new()
	bare.setup(config, SimRng.new(1))
	expect_eq(bare.layout_ids, ["west_gate"], "no layout in the config: the level's first site")
	expect_eq(bare.tower.position, Vector2(-90, 30))


func test_a_level_without_sites_keeps_its_one_tower_whatever_the_layout() -> void:
	var rules := _world([], ["west_gate"], "tidewrack_cove")
	expect_eq(rules.outcome, HoldfastRules.OUTCOME_RUNNING)
	expect_eq(rules.towers.size(), 1)
	expect_eq(rules.tower.position, Vector2(-90, 30))
	expect_eq(rules.layout_ids, [])


func test_the_best_layout_takes_the_sites_nearest_where_the_enemies_come_from() -> void:
	var levels: Dictionary = HoldfastContent.base()["levels"]
	expect_eq(HoldfastRules.best_layout(levels["outpost"]), ["west_gate"], "arcs at 200 then 20 degrees, one post")
	expect_eq(HoldfastRules.best_layout(levels["shingle_beach"]), ["west_gate", "east_gate"], "arcs at 180 then 0")
	expect_eq(HoldfastRules.best_layout(levels["tidewrack_cove"]), [], "no sites, no layout")
	var no_arcs: Dictionary = levels["shingle_beach"].duplicate(true)
	no_arcs.erase("spawn_arcs")
	expect_eq(HoldfastRules.best_layout(no_arcs), ["west_gate", "east_gate"], "without arcs, the first sites")
	no_arcs["max_posts"] = 9
	expect_eq(HoldfastRules.best_layout(no_arcs).size(), 4, "never more than the level has")
	var bent: Dictionary = levels["shingle_beach"].duplicate(true)
	bent["spawn_arcs"] = [{"centre": 90, "width": 80}]
	expect_eq(HoldfastRules.best_layout(bent), ["south_gate", "east_gate"], "the south arc takes the south gate, then the next nearest in turn")


func test_enemies_spawn_inside_the_levels_arcs_and_all_round_without_any() -> void:
	for level in ["outpost", "shingle_beach"]:
		var rules := _world([], null, level, 0.0, func(c: Dictionary) -> void:
			c["levels"][level]["first_wave_delay"] = 0.0
			c["levels"][level]["waves"] = [{"spawns": [{"enemy": "grunt", "count": 60, "interval": 0.0}]}])
		rules.step(DT, {})
		expect_eq(rules.enemies.size(), 60, level)
		var arcs: Array = HoldfastContent.base()["levels"][level]["spawn_arcs"]
		var hits := [0, 0]
		var lowest := [999.0, 999.0]
		var highest := [-999.0, -999.0]
		for enemy in rules.enemies:
			var angle := rad_to_deg(atan2(enemy.position.y, enemy.position.x))
			var found := -1
			for i in arcs.size():
				if absf(angle_difference(deg_to_rad(float(arcs[i]["centre"])), deg_to_rad(angle))) <= deg_to_rad(float(arcs[i]["width"]) * 0.5) + 0.001:
					found = i
			expect_true(found >= 0, "%s: an enemy at %.0f degrees is inside an arc" % [level, angle])
			if found >= 0:
				hits[found] += 1
				var from_centre := rad_to_deg(angle_difference(deg_to_rad(float(arcs[found]["centre"])), deg_to_rad(angle)))
				lowest[found] = minf(lowest[found], from_centre)
				highest[found] = maxf(highest[found], from_centre)
		expect_true(hits[0] >= 10 and hits[1] >= 10, "%s: both arcs are used (%s)" % [level, str(hits)])
		for i in 2:
			expect_true(highest[i] - lowest[i] > 60.0 and highest[i] - lowest[i] <= 80.001, "%s: arc %d is filled across most of its 80 degrees (%.0f)" % [level, i, highest[i] - lowest[i]])
	var round_about := _world([], null, "tidewrack_cove", 0.0, func(c: Dictionary) -> void:
		c["levels"]["tidewrack_cove"]["first_wave_delay"] = 0.0
		c["levels"]["tidewrack_cove"]["waves"] = [{"spawns": [{"enemy": "grunt", "count": 60, "interval": 0.0}]}])
	round_about.step(DT, {})
	var left := 0
	for enemy in round_about.enemies:
		left += 1 if enemy.position.x < 0.0 else 0
	expect_true(left > 10 and left < 50, "a level with no arcs spawns on both sides (%d of 60 on the left)" % left)


func test_a_second_post_attacks_and_falls_on_its_own() -> void:
	var rules := _world([], ["west_gate", "east_gate"], "shingle_beach", 5.0)
	_enemy(rules, Vector2(-150, -20), 100.0)
	_enemy(rules, Vector2(150, -10), 100.0)
	_run(rules, 1)
	expect_true(rules.towers[0].last_target >= 0 and rules.towers[1].last_target >= 0, "each post shoots what is in its own range")
	rules.towers[1].up = false
	rules.towers[1].health = UnitHealth.damage(rules.towers[1].health, 1000.0)
	_run(rules, 40)
	expect_true(rules.towers[0].up, "the other post stands")
	expect_eq(rules.towers[1].last_target, -1, "a fallen post does not shoot")


func test_enemies_go_for_a_second_post_and_wear_it_down() -> void:
	var rules := _world([], ["west_gate", "east_gate"], "shingle_beach")
	var enemy := _enemy(rules, rules.towers[1].position + Vector2(24, 0), 1000.0)
	enemy.damage = 5
	enemy.hit_interval = 1.0
	_run(rules, 1)
	expect_eq(enemy.target, "tower:archer_post@east_gate", "the post it stands at")
	expect_eq(rules.towers[1].health["health"], 55.0)
	expect_eq(rules.towers[0].health["health"], 60.0, "the other post is untouched")


# ------------------------------------------------------------------ Archer Post stats

func test_tower_nodes_apply_to_the_tower_they_name() -> void:
	var nodes := {
		"a": {"tower": "archer_post", "effects": [{"stat": "tower.damage", "add": 1}]},
		"b": {"tower": "mage_post", "effects": [{"stat": "tower.damage", "add": 5}]},
		"c": {"hero": "flare_archer", "effects": [{"stat": "hero.attack.damage", "add": 2}, {"stat": "hero.move_speed", "multiply": 1.5}]},
		"d": {"effects": [{"stat": "keep_health", "add": 7}]},
	}
	var stats := HoldfastRules.upgrade_stats(nodes, ["a", "b", "c", "d"])
	expect_eq(stats["tower.archer_post.damage"]["add"], 1.0)
	expect_eq(stats["tower.mage_post.damage"]["add"], 5.0, "another tower's own entry")
	expect_eq(stats["hero.flare_archer.attack.damage"]["add"], 2.0)
	expect_eq(stats["hero.flare_archer.move_speed"]["multiply"], 1.5)
	expect_eq(stats["keep_health"]["add"], 7.0, "a global stat keeps its name")
	expect_false(stats.has("tower.damage"))


func test_the_four_basic_post_nodes_change_health_damage_range_and_speed() -> void:
	var base := _world([], null, "outpost", 4.0)
	var upgraded := _world(["post_timbers", "post_drills", "post_sight", "post_rate"], null, "outpost", 4.0)
	expect_eq(upgraded.tower.health["max_health"], base.tower.health["max_health"] + 30.0, "post_timbers +30")
	expect_eq(upgraded.tower.health["health"], upgraded.tower.health["max_health"], "built at full health")
	expect_eq(upgraded.tower.damage, 6.0, "post_drills +2 on 4")
	expect_eq(upgraded.tower.attack_range, 200.0, "post_sight +30 on 170")
	expect_eq(upgraded.tower.cooldown, 0.75, "post_rate x0.75 on 1")
	expect_eq(base.tower.cooldown, 1.0)


func test_every_post_gets_the_node_not_just_the_first() -> void:
	var rules := _world(["post_drills"], ["west_gate", "east_gate"], "shingle_beach", 4.0)
	expect_eq(rules.towers[0].damage, 6.0)
	expect_eq(rules.towers[1].damage, 6.0)


func test_twin_arrows_hit_the_next_nearest_enemy_too() -> void:
	var rules := _world(["post_twin"], null, "outpost", 10.0, func(c: Dictionary) -> void: c["towers"]["archer_post"]["range"] = 400.0)
	var near := _enemy(rules, Vector2(-150, 30))
	var next := _enemy(rules, Vector2(-250, 30))
	var far := _enemy(rules, Vector2(-330, 30))
	_run(rules, 1)
	expect_eq(near.health, 990.0, "the one nearest the keep")
	expect_eq(next.health, 990.0, "and the next")
	expect_eq(far.health, 1000.0, "but not a third")
	var alone := _world(["post_twin"], null, "outpost", 10.0)
	var only := _enemy(alone, Vector2(-150, 30))
	_run(alone, 1)
	expect_eq(only.health, 990.0, "with one enemy it is a plain shot")


func test_marksman_doubles_the_hit_on_a_lone_target_only() -> void:
	var lone := _world(["post_marksman"], null, "outpost", 10.0)
	var target := _enemy(lone, Vector2(-150, 30))
	_run(lone, 1)
	expect_eq(target.health, 980.0, "lone_bonus 1 doubles it")
	var pair := _world(["post_marksman"], null, "outpost", 10.0)
	var first := _enemy(pair, Vector2(-150, 30))
	var second := _enemy(pair, Vector2(-170, 30))
	_run(pair, 1)
	expect_eq(first.health + second.health, 1990.0, "two in range: a plain hit on one")
	var out_of_range := _world(["post_marksman"], null, "outpost", 10.0)
	var near := _enemy(out_of_range, Vector2(-150, 30))
	_enemy(out_of_range, Vector2(-900, 30))
	_run(out_of_range, 1)
	expect_eq(near.health, 980.0, "an enemy outside the range does not count against being alone")


func test_piercing_shot_hits_the_enemies_in_line_behind_the_target() -> void:
	var rules := _world(["post_piercing"], null, "outpost", 10.0, func(c: Dictionary) -> void: c["towers"]["archer_post"]["range"] = 400.0)
	# The tower is at (-90, 30); the line runs west along y = 30 through the nearest to the keep.
	var target := _enemy(rules, Vector2(-150, 30))
	var second := _enemy(rules, Vector2(-200, 30))
	var third := _enemy(rules, Vector2(-260, 30))
	var fourth := _enemy(rules, Vector2(-320, 30))
	var aside := _enemy(rules, Vector2(-200, 100))
	_run(rules, 1)
	expect_eq(target.health, 990.0)
	expect_eq(second.health, 990.0, "first behind")
	expect_eq(third.health, 990.0, "second behind: pierce 2")
	expect_eq(fourth.health, 1000.0, "a third behind is past it")
	expect_eq(aside.health, 1000.0, "off the line (70 px, wider than 10 + 8)")
	var wrong_way := _world(["post_piercing"], null, "outpost", 10.0, func(c: Dictionary) -> void: c["towers"]["archer_post"]["range"] = 400.0)
	var south := _enemy(wrong_way, Vector2(-90, 130))
	var north := _enemy(wrong_way, Vector2(-90, -170))
	_run(wrong_way, 1)
	expect_eq(south.health, 990.0, "the target")
	expect_eq(north.health, 1000.0, "on the other side of the tower from the target: not in line behind it")
	var edge := _world(["post_piercing"], null, "outpost", 10.0, func(c: Dictionary) -> void: c["towers"]["archer_post"]["range"] = 400.0)
	var lead := _enemy(edge, Vector2(-150, 30))
	var just_in := _enemy(edge, Vector2(-250, 30 + 17.9))
	var just_out := _enemy(edge, Vector2(-300, 30 + 18.5))
	_run(edge, 1)
	expect_eq(lead.health, 990.0)
	expect_true(just_in.health < 1000.0, "inside radius + pierce width at the far end of the line is hit")
	expect_eq(just_out.health, 1000.0, "outside it is not")


func test_burst_fire_makes_every_fourth_shot_three_times_as_heavy() -> void:
	var rules := _world(["post_burst"], null, "outpost", 10.0, func(c: Dictionary) -> void: c["towers"]["archer_post"]["cooldown"] = 0.95)
	var target := _enemy(rules, Vector2(-150, 30), 100000.0)
	var hits: Array[float] = []
	var health := target.health
	for i in 270:
		_run(rules, 1)
		if target.health < health:
			hits.append(health - target.health)
			health = target.health
	expect_eq(hits.slice(0, 8), [10.0, 10.0, 10.0, 30.0, 10.0, 10.0, 10.0, 30.0], "burst_every 4, burst_extra 2")


func test_arrow_storm_hits_everything_in_range_for_half_the_damage_every_ten_seconds() -> void:
	var rules := _world(["post_storm"], null, "outpost", 10.0, func(c: Dictionary) -> void: c["towers"]["archer_post"]["cooldown"] = 999.0)
	var first := _enemy(rules, Vector2(-150, 30))
	var second := _enemy(rules, Vector2(-200, 30))
	_run(rules, 30 * 9)
	expect_eq(first.health, 990.0, "only the opening shot so far")
	expect_eq(second.health, 1000.0)
	_run(rules, 30 * 2)
	expect_eq(first.health, 985.0, "the storm: half of 10")
	expect_eq(second.health, 995.0)
	_run(rules, 30 * 8)
	expect_eq(second.health, 995.0, "and not again before ten more seconds")
	_run(rules, 30 * 3)
	expect_eq(second.health, 990.0, "the second storm")


func test_a_storm_waits_for_something_in_range_and_a_fallen_post_makes_none() -> void:
	var rules := _world(["post_storm"], null, "outpost", 10.0, func(c: Dictionary) -> void: c["towers"]["archer_post"]["cooldown"] = 999.0)
	_run(rules, 30 * 15)
	var late := _enemy(rules, Vector2(-150, 30))
	_run(rules, 3)
	expect_eq(late.health, 985.0, "ready and waiting: the opening shot and the storm come at once")
	var down := _world(["post_storm"], null, "outpost", 10.0, func(c: Dictionary) -> void: c["towers"]["archer_post"]["cooldown"] = 999.0)
	var spared := _enemy(down, Vector2(-150, 30))
	down.tower.up = false
	_run(down, 30 * 12)
	expect_eq(spared.health, 1000.0)


func test_patch_up_repairs_between_waves_at_the_pack_rate() -> void:
	var rules := _world(["post_mend"])
	rules.tower.health = UnitHealth.damage(rules.tower.health, 30.0)
	_run(rules, 30)
	expect_near(rules.tower.health["health"], 33.0, 0.001, "3 a second")
	var rate := _world(["post_mend"], ["west_gate"], "outpost", 0.0)
	expect_eq(rate.tower.repair, 3.0)


# ------------------------------------------------------------------ the Flare Archer's nodes

func test_the_flare_archer_nodes_change_the_heros_numbers() -> void:
	var base := _world()
	expect_eq(base.hero_speed, 170.0)
	var tuned := _world(["flare_boots", "flare_hide", "flare_focus", "flare_quick", "flare_twin", "flare_heavy", "flare_longer", "flare_pierce", "flare_embers", "flare_inferno"])
	expect_eq(tuned.hero_speed, 190.0, "flare_boots +20")
	expect_eq(tuned.hero_state["max_health"], 80.0, "flare_hide +20")
	# damage (0 in this world's attack, +2) x 1.3: hand-worked on the shipped 7 below.
	var shipped := HoldfastRules.new()
	shipped.setup(HoldfastContent.run_config("outpost", ["flare_focus", "flare_heavy", "flare_quick", "flare_twin"], {}, "flare_archer"), SimRng.new(1))
	expect_near(float(shipped.hero_attack["damage"]), (7.0 + 2.0) * 1.3, 0.0001, "+2 then x1.3")
	expect_near(float(shipped.hero_attack["cooldown"]), 0.4, 0.0001, "flare_quick x0.8 on 0.5")
	expect_eq(int(shipped.hero_attack["count"]), 2, "flare_twin: two arrows")
	expect_eq(float(shipped.hero_attack["spread_degrees"]), 10.0)
	var barrage := HoldfastRules.new()
	barrage.setup(HoldfastContent.run_config("outpost", ["flare_longer", "flare_pierce", "flare_embers", "flare_inferno"], {}, "flare_archer"), SimRng.new(1))
	expect_eq(float(barrage.hero_ability["rapid_seconds"]), 5.0 + 2.0 + 3.0, "longer and inferno")
	expect_eq(int(barrage.hero_ability["pierce"]), 4, "hot tips +1 on 3")
	expect_eq(float(barrage.hero_ability["burn_dps"]), 5.0, "embers +2 on 3")
	expect_eq(float(barrage.hero_ability["burn_seconds"]), 5.0, "inferno +2 on 3")
	expect_eq(float(barrage.hero_ability["cooldown"]), 10.0, "inferno -4 on 14")


func test_hero_nodes_touch_only_their_own_pillar_and_never_the_shared_pack() -> void:
	var mage := HoldfastRules.new()
	mage.setup(HoldfastContent.run_config("outpost", ["flare_boots", "flare_focus", "flare_inferno"], {}, "dusk_mage"), SimRng.new(1))
	expect_eq(mage.hero_speed, 160.0, "the Dusk Mage keeps their speed")
	expect_eq(float(mage.hero_attack["damage"]), 5.0)
	expect_eq(float(mage.hero_ability["cooldown"]), 16.0)
	var content := HoldfastContent.base()
	expect_eq(float(content["hero_paths"]["flare_archer"]["attack"]["damage"]), 7.0, "the cached pack is not changed by a run")
	expect_eq(float(content["hero_paths"]["flare_archer"]["ability"]["cooldown"]), 14.0)
	expect_eq(int(content["hero_paths"]["flare_archer"]["attack"]["count"]), 1)


func test_a_twin_arrow_shot_fires_two_arrows_across_ten_degrees() -> void:
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", ["flare_twin"], {}, "flare_archer"), SimRng.new(1))
	rules.hero_facing = Vector2.RIGHT
	rules._fire(rules.hero_attack)
	expect_eq(rules.projectiles.size(), 2)
	var spread := absf(rad_to_deg(rules.projectiles[0].velocity.angle_to(rules.projectiles[1].velocity)))
	expect_near(spread, 10.0, 0.001)


# ------------------------------------------------------------------ the tree's shape

## The base pack with Scope and Twin arrows made a fork again: the real tree has none (both Archer
## capstones can be bought), so the fork rules are tested on this copy.
func _forked() -> Dictionary:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["upgrade_nodes"]["post_scope"]["excludes"] = ["post_twin"]
	content["upgrade_nodes"]["post_twin"]["excludes"] = ["post_scope"]
	return content


func test_the_post_section_has_eighteen_nodes_and_no_fork() -> void:
	var nodes: Dictionary = HoldfastContent.base()["upgrade_nodes"]
	var post := []
	for id in nodes:
		if nodes[id]["branch"] == "archer_post":
			post.append(id)
	expect_eq(post.size(), 18, "four basics, one repair, three a side, seven links")
	for id in ["post_timbers", "post_drills", "post_sight", "post_rate"]:
		expect_eq(nodes[id]["requires"], ["castle_archer_1"], id + " is a cheap basic that needs only the first Archer Post")
	for id in nodes:
		expect_false(nodes[id].has("excludes"), "%s closes nothing: both Archer capstones can be bought" % id)
	expect_eq(nodes["post_piercing"]["requires"], ["post_marksman"])
	expect_eq(nodes["post_storm"]["requires"], ["post_burst"])
	var flare := 0
	for id in nodes:
		flare += 1 if nodes[id]["branch"] == "flare_archer" else 0
	expect_eq(flare, 12, "the Flare Archer's twelve nodes")
	for id in nodes:
		if nodes[id].has("tower"):
			expect_eq(nodes[id]["branch"], nodes[id]["tower"], id)
		if nodes[id].has("hero") and not nodes[id].has("tower"):
			expect_eq(nodes[id]["branch"], nodes[id]["hero"], id)


func test_a_further_tower_section_plugs_in_from_the_pack_alone() -> void:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["upgrade_sections"]["mage_post"] = {"id": "mage_post", "name": "Mage Post", "order": 9}
	content["upgrade_nodes"]["mage_x"] = {"id": "mage_x", "name": "X", "branch": "mage_post", "tower": "archer_post", "tier": 1, "cost": 5, "effects": [{"stat": "tower.damage", "add": 3}]}
	var profile := HoldfastMeta.new_profile(content)
	profile["gold"] = 5
	expect_true(HoldfastMeta.buy(content, profile, "mage_x")["ok"])
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", ["mage_x"], content, "flare_archer"), SimRng.new(1))
	expect_eq(rules.tower.damage, 7.0)
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var errors: PackedStringArray = []
	schema.validate_def({"upgrade_nodes": [{"id": "x", "name": "X", "branch": "gold", "cost": 5}]}, "content", "upgrades.json: $", errors, [])
	expect_false(errors.is_empty(), "a node needs a tier now")


# ------------------------------------------------------------------ the profile

func test_a_fork_closes_the_other_side_both_ways_and_names_why() -> void:
	var content := _forked()
	var profile := HoldfastMeta.new_profile(content)
	profile["gold"] = 99999
	profile["upgrades"] = ["post_sight", "post_scope"]
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "post_twin"), "Needs Archer drills first")
	profile["upgrades"].append("post_drills")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "post_twin"), "Closed by Scope")
	var refused := HoldfastMeta.buy(content, profile, "post_twin")
	expect_false(refused["ok"])
	expect_eq(refused["profile"], profile, "nothing changes")
	var other := HoldfastMeta.new_profile(content)
	other["gold"] = 99999
	other["upgrades"] = ["post_drills", "post_twin", "post_sight"]
	expect_eq(HoldfastMeta.why_not_buy(content, other, "post_scope"), "Closed by Twin arrows", "and the other way round")


func test_a_save_holding_both_sides_of_a_fork_keeps_the_first() -> void:
	var content := _forked()
	var loaded := HoldfastMeta.from_save(content, {"gold": 5, "upgrades": ["post_drills", "post_sight", "post_scope", "post_twin"]})
	expect_eq(loaded["upgrades"], ["post_drills", "post_sight", "post_scope"])


func test_respec_gives_every_upgrade_back_at_its_price_less_a_fee_each() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile["gold"] = 40
	profile["upgrades"] = ["post_timbers", "keep_walls_1", "flare_boots"]   # 70 + 60 + 90
	var after := HoldfastMeta.respec(content, profile)
	expect_eq(after["gold"], 40 + 70 + 60 + 90 - 3 * 20, "each node's price less its fee (a tenth, at least 20)")
	expect_eq(after["upgrades"], [])
	expect_eq(profile["upgrades"].size(), 3, "the profile given is untouched")
	expect_eq(HoldfastMeta.respec(content, after), after, "nothing to give back the second time")
	var again := HoldfastMeta.buy(content, after, "post_scope")
	expect_false(again["ok"], "the tree is empty, so the choice is open again but deeper nodes need their first")


func test_the_next_unlocks_are_the_two_cheapest_nodes_one_buy_away_for_this_pillar() -> void:
	var content := HoldfastContent.base()
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	var castle: Array = profile["upgrades"].duplicate()
	expect_eq(HoldfastMeta.next_unlocks(content, profile), ["keep_walls_1", "post_timbers"], "60 and 70")
	profile["upgrades"] = castle + ["keep_walls_1", "post_timbers"]
	expect_eq(HoldfastMeta.next_unlocks(content, profile), ["flare_hide", "flare_boots"], "80 and 90")
	expect_true(HoldfastMeta.is_near(content, profile, "post_mend"), "its requirement is bought")
	expect_false(HoldfastMeta.is_near(content, profile, "post_burst"), "two buys away")
	expect_false(HoldfastMeta.is_near(content, profile, "post_timbers"), "bought is not next")
	profile["pillar"] = "dusk_mage"
	expect_false(HoldfastMeta.is_near(content, profile, "flare_hide"), "another Hero's node is never next")
	profile["upgrades"] = castle + ["post_drills", "post_scope"]
	expect_true(HoldfastMeta.is_near(content, profile, "post_twin"), "with no fork, the other side is next")
	expect_false(HoldfastMeta.is_near(_forked(), profile, "post_twin"), "on a fork, a closed node is never next")
	profile["upgrades"] = castle
	expect_eq(HoldfastMeta.next_unlocks(content, profile, 1), ["keep_walls_1"], "the limit holds")


func test_a_version_two_save_gets_the_removed_post_nodes_back_as_gold_and_keeps_the_rest() -> void:
	var migrated := HoldfastMeta.migrate_v2({"gold": 10, "upgrades": ["tower_drills_1", "keep_walls_1", "tower_drills_1", "tower_stone_2", "tower_mend_3", "tithe_1", "tower_drills_5", "tower_stone_4", "tower_mend_1"], "runs": 3}, HoldfastContent.base())
	expect_eq(migrated["upgrades"], ["keep_walls_1", "tithe_1"], "keep and tithe stay")
	expect_eq(migrated["gold"], 10 + 110 + 260 + 1200 + 2600 + 1400 + 150, "each removed node once, at its old price")
	expect_eq(migrated["runs"], 3)
	var costs := HoldfastMeta.V2_TOWER_COSTS
	expect_eq(costs.size(), 12)
	var untouched := {"gold": 5, "upgrades": ["keep_walls_1"]}
	expect_eq(HoldfastMeta.migrate_v2(untouched, HoldfastContent.base()), untouched)


func test_a_version_two_file_loads_through_the_profile_and_saves_as_version_three() -> void:
	var path := _save_path("v2")
	SaveService.new(path, 2).save({"gold": 30, "upgrades": ["tower_stone_1", "keep_walls_1", "tower_mend_2"], "levels_won": ["outpost"], "unlocked": ["shingle_beach"], "level": "shingle_beach", "pillar": "tideblade", "runs": 4})
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	expect_eq(profile.load_status, "migrated")
	expect_eq(profile.get_upgrades(), [], "the castle starts empty, so every bought node is refunded")
	expect_eq(profile.get_gold(), 30 + 70 + 520 + 60)
	expect_eq(profile.get_level(), "shingle_beach")
	expect_eq(profile.get_pillar(), "tideblade")
	expect_eq(profile.data["layouts"], {})
	profile.select_level("outpost")
	profile.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.load_status, "ok", "saved as the new version")
	expect_eq(again.get_gold(), 30 + 70 + 520 + 60)
	again.free()


## The pack's content with the castle grown to four slots and two Archer Post cards, so layouts of more than one post can be checked.
func _wide_castle() -> Dictionary:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["upgrade_nodes"]["castle_slot_1"]["grants"]["slots"] = 4
	content["upgrade_nodes"]["castle_archer_1"]["grants"]["cards"] = 2
	return content


func test_a_layout_is_checked_saved_and_defaulted() -> void:
	var content := _wide_castle()
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	expect_eq(HoldfastMeta.layout_for(content, profile, "shingle_beach"), ["spot_2", "spot_1"], "the default is the best layout")
	expect_eq(HoldfastMeta.layout_for(content, profile, "first_watch"), [], "the tutorial has its own post")
	var chosen := HoldfastMeta.set_layout(content, profile, "shingle_beach", ["spot_4", "spot_3"])
	expect_eq(chosen["layouts"]["shingle_beach"], ["spot_4", "spot_3"])
	expect_eq(HoldfastMeta.layout_for(content, chosen, "shingle_beach"), ["spot_4", "spot_3"])
	expect_eq(profile["layouts"], {}, "the profile given is untouched")
	for bad in [[], ["spot_2", "spot_1", "spot_4"], ["spot_2", "spot_2"], ["nowhere"]]:
		expect_eq(HoldfastMeta.set_layout(content, chosen, "shingle_beach", bad), chosen, "refused: " + str(bad))
	expect_eq(HoldfastMeta.set_layout(content, chosen, "first_watch", ["spot_2"]), chosen, "the tutorial")
	expect_eq(HoldfastMeta.set_layout(content, chosen, "no_such_level", ["spot_2"]), chosen)
	var loaded := HoldfastMeta.from_save(content, {"stars": {"first_watch": 2}, "upgrades": ["castle_slot_1", "castle_archer_1"], "layouts": {"shingle_beach": ["spot_4"], "outpost": ["bogus"], "gone": ["x"], "tidewrack_cove": ["west_gate"], "old_pier": ["spot_99"]}})
	expect_eq(loaded["layouts"], {"shingle_beach": ["spot_4"]}, "only valid layouts of real levels are kept")
	expect_eq(HoldfastMeta.from_save(content, {"layouts": 7})["layouts"], {}, "and nonsense is dropped")


func test_a_chosen_layout_survives_a_save_and_a_reload() -> void:
	var path := _save_path("layout")
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	ThroughLevelZero.apply(profile)
	profile.set_layout("outpost", ["spot_1"])
	profile.set_layout("outpost", ["nowhere"])
	expect_eq(profile.get_layout("outpost"), ["spot_1"])
	profile.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.get_layout("outpost"), ["spot_1"])
	expect_eq(again.get_layout("shingle_beach"), ["spot_2"], "a level never planned gets the best layout the castle allows")
	again.free()


# ------------------------------------------------------------------ the screens

func test_play_opens_the_planning_screen_and_start_runs_on_the_chosen_site() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	ThroughLevelZero.apply(profile)
	main.journey._buttons["outpost"].pressed.emit()
	expect_true(main.planning.visible and not main.journey.visible and not source.is_running(), "planning comes first")
	expect_eq(main.planning.get_node("%Count").text, "Posts: 0 of 1", "a first visit starts with empty slots")
	expect_true(main.planning.get_node("%StartButton").disabled, "no post, no start")
	main.planning.open("outpost", [], false, HoldfastContent.base()["castle_rules"]["castle"]["spots"].slice(0, 2), 1)
	main.planning._site_buttons["spot_2"].pressed.emit()
	expect_eq(main.planning.get_node("%Count").text, "Posts: 1 of 1")
	main.planning._site_buttons["spot_1"].pressed.emit()
	expect_eq(main.planning.get_node("%Count").text, "Posts: 1 of 1", "one post: the new choice replaces the old")
	main.journey.level_requested.emit("outpost")
	main.planning._site_buttons["spot_1"].pressed.emit()
	main.planning.get_node("%StartButton").pressed.emit()
	expect_true(source.is_running() and main.hud.visible and not main.planning.visible)
	expect_eq(source.get_rules().layout_ids, ["spot_1"])
	expect_eq(source.get_rules().tower.position, Vector2(100, 0))
	expect_eq(profile.get_layout("outpost"), ["spot_1"], "saved with the profile")
	expect_eq(source.get_posts_note(), "Posts: 1", "and shown as the run starts")
	expect_eq(source.get_wave_banner(), "", "the wave banner is left alone")
	main.free()


func test_the_planning_screen_toggles_sites_up_to_the_limit_and_will_not_start_empty() -> void:
	var main := _main()
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.journey._buttons["outpost"].pressed.emit()
	var planning: Control = main.planning
	planning.open("shingle_beach", ["spot_2", "spot_1"], false, HoldfastContent.base()["castle_rules"]["castle"]["spots"].slice(0, 4), 2)
	expect_eq(planning.get_node("%Count").text, "Posts: 2 of 2")
	planning._site_buttons["spot_3"].pressed.emit()
	expect_eq(planning._chosen, ["spot_1", "spot_3"], "at the limit the oldest makes way")
	planning._site_buttons["spot_3"].pressed.emit()
	planning._site_buttons["spot_1"].pressed.emit()
	expect_eq(planning._chosen, [])
	expect_true(planning.get_node("%StartButton").disabled, "no post, no start")
	planning._site_buttons["spot_2"].pressed.emit()
	expect_false(planning.get_node("%StartButton").disabled)
	var heard := []
	planning.start_requested.connect(func(layout: Array) -> void: heard.append(layout))
	planning.get_node("%StartButton").pressed.emit()
	expect_eq(heard, [["spot_2"]])
	main.free()


func test_back_from_planning_returns_to_the_journey_map_and_the_tutorial_starts_at_once() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	main.journey._buttons["first_watch"].pressed.emit()
	expect_true(source.is_running() and not main.planning.visible, "the tutorial has its own post, so no planning")
	expect_eq(source.get_rules().layout_ids, [])
	expect_eq(source.get_posts_note(), HoldfastContent.base()["levels"]["first_watch"]["intro"], "and says its teaching text instead of a posts line")
	source.step(3600.0)
	main.call("_show", main.Screen.MAP)
	ThroughLevelZero.apply(profile)
	main.journey._buttons["outpost"].pressed.emit()
	main.planning.get_node("%BackButton").pressed.emit()
	expect_true(main.journey.visible and not main.planning.visible and not source.is_running())
	main.free()


func test_the_keep_screen_shows_sections_dims_the_far_nodes_and_lists_the_next_unlocks() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var keep: Control = main.keep_screen
	keep.visible = true
	expect_true(keep.get_node("%RespecButton").disabled, "nothing to respec yet")
	ThroughLevelZero.apply_castle(profile)
	expect_eq(keep._section_columns.keys().size(), 6, "Flare Archer, Archer Post, Keep, Tithe, Castle, Mage Post")
	expect_true(keep._section_columns["flare_archer"].visible)
	expect_eq(keep._node_buttons["post_timbers"].modulate, Color.WHITE, "one buy away: in full")
	expect_eq(keep._node_buttons["post_burst"].modulate, keep.DIMMED, "far: dimmed")
	expect_true(keep.get_node_or_null("%NextUnlocks") == null, "the strip of what is next is gone")
	keep.open_card("keep_walls_1")
	expect_true(keep._card_price.text.begins_with("60") and TreeCard.text(keep).contains("25"), "its card has the price and the effect")
	keep.close_card()
	expect_true(keep.get_node("%RespecButton").disabled, "the two castle buys stay: nothing to take back yet")
	# The real tree has no fork; this one runs on a copy that makes Scope and Twin arrows one.
	var forked := _forked()
	profile._content = forked
	keep._content = forked
	profile.data["paths_kept"] = ["dusk_mage"]
	main.hero_page.select_pillar("dusk_mage")
	expect_false(keep._section_columns["flare_archer"].visible, "another Hero: the Flare Archer's section is hidden")
	profile.bank_run({"gold": 5000, "outcome": "lost", "level": "outpost"})
	TreeCard.buy(keep, "post_drills")
	TreeCard.buy(keep, "post_scope")
	TreeCard.buy(keep, "post_sight")
	TreeCard.buy(keep, "post_scope")
	expect_true(not TreeCard.can_buy(keep, "post_twin") and keep._node_buttons["post_twin"].text.contains("closed"), "the other side of the fork is closed")
	expect_true(keep._card_note.text.contains("Closed by Scope"))
	keep.open_card("post_scope")
	expect_true(TreeCard.text(keep).contains("Replaces Twin arrows"), TreeCard.text(keep))
	expect_false(keep.get_node("%RespecButton").disabled)
	var gold_before := profile.get_gold()
	keep.get_node("%RespecButton").pressed.emit()
	keep.get_node("%ConfirmButton").pressed.emit()
	expect_eq(profile.get_upgrades(), ["castle_slot_1", "castle_archer_1"], "the two guided buys stay")
	expect_eq(profile.get_gold(), gold_before + 110 + 120 + 600 - 20 - 20 - 60, "the gold nodes' prices less a fee each; the two star nodes stay and cost no fee")
	expect_false(not TreeCard.can_buy(keep, "post_twin") and keep._node_buttons["post_twin"].text.contains("closed"), "the choice is open again")
	main.free()


func test_effect_text_names_each_new_stat_in_words() -> void:
	var keep: Control = load("res://scenes/ui/keep_screen.tscn").instantiate()
	for id in HoldfastContent.base()["upgrade_nodes"]:
		for effect in HoldfastContent.base()["upgrade_nodes"][id].get("effects", []):
			var text: String = keep.get_script().call("_stat_text", str(effect["stat"]))
			expect_false(text.contains(".") or text.contains("_"), "%s reads as words: %s" % [effect["stat"], text])
	keep.free()


# ------------------------------------------------------------------ the bots

func test_the_progression_bot_never_buys_both_sides_of_a_fork_and_can_avoid_one() -> void:
	var nodes: Dictionary = _forked()["upgrade_nodes"]
	var castle := ["castle_slot_1", "castle_archer_1"]
	var plenty := HoldfastProgression.buy_cheapest(nodes, castle, 999999)
	expect_true("post_scope" in plenty and not "post_twin" in plenty, "ties go to the first id: Scope")
	expect_false("post_burst" in plenty or "post_storm" in plenty, "and nothing behind the closed side")
	var twin := HoldfastProgression.buy_cheapest(nodes, castle, 999999, ["post_scope"])
	expect_true("post_twin" in twin and "post_burst" in twin and not "post_scope" in twin, "avoiding Scope takes the Volley side")
	expect_true("post_storm" in HoldfastProgression.buy_cheapest(nodes, castle + twin, 0, ["post_scope"], 99), "and its star capstone with the stars")
	expect_eq(HoldfastProgression.reachable_total(nodes, [], []), 40 - 0, "an empty profile can still reach every gold node")
	expect_eq(HoldfastProgression.reachable_total(nodes, ["post_scope"]), 40 - 2, "Scope closes Twin and Burst fire (Arrow storm is a star node, not counted)")
	expect_eq(HoldfastProgression.reachable_total(nodes, [], ["post_scope"]), 40 - 2, "avoiding it does the same")
	var real: Dictionary = HoldfastContent.base()["upgrade_nodes"]
	var both := HoldfastProgression.buy_cheapest(real, castle, 999999)
	expect_true("post_scope" in both and "post_twin" in both, "the real tree has no fork: the bot buys both sides")
	expect_eq(HoldfastProgression.reachable_total(real, ["post_scope"]), 40, "and Scope closes nothing")


func test_the_bots_play_the_planning_choice() -> void:
	var config := HoldfastContent.run_config("shingle_beach")
	expect_eq(config["layout"], ["west_gate", "east_gate"], "the default for a bot is the best layout")
	expect_false(HoldfastContent.run_config("tidewrack_cove").has("layout"))
	expect_eq(HoldfastContent.run_config("outpost", [], {}, "", ["north_gate"])["layout"], ["north_gate"], "an explicit choice wins")
	var a: Dictionary = HoldfastSim.run_headless(3, HoldfastContent.run_config("shingle_beach", [], {}, "", ["west_gate", "east_gate"]))
	var b: Dictionary = HoldfastSim.run_headless(3, HoldfastContent.run_config("shingle_beach"))
	expect_eq(a["hash"] if a.has("hash") else a["result"], b["hash"] if b.has("hash") else b["result"], "the same layout, the same run")


func test_every_post_repairs_between_waves_not_only_the_first() -> void:
	var rules := _world(["post_mend"], ["west_gate", "east_gate"], "shingle_beach")
	for built in rules.towers:
		built.health = UnitHealth.damage(built.health, 30.0)
	var before: Array = rules.towers.map(func(built): return built.health["health"])
	_run(rules, 30)
	for i in rules.towers.size():
		expect_near(rules.towers[i].health["health"], before[i] + 3.0, 0.001, "post %d mends 3 in a second" % i)
