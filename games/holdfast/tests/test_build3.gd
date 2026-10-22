extends KitTestCase
## Build 3 (HF-M2-02, HF-M2-06, HF-M2-18, KIT-07 wiring): gold and upgrades that
## save, the five-level biome, the keep screen, and the Hero getting up where they
## fell. Expected numbers are worked by hand from the pack values noted beside them.
##
## Pack: keep at (0, 0) radius 36; Hero radius 12, health 60 (Flare Archer), pickup
## 30, starts (0, 80), knock-down waits 3 s, 6 s, 10 s; spawn radius 420 on the
## Outpost; a Grunt walks 56 a second; tower health 60 at (-90, 30).

const Main := preload("res://scenes/main.tscn")
const DT := 1.0 / HoldfastRules.TICK_RATE
const BIG := 1000000.0
const SAVE_DIR := "user://build3_tests"
const Hud := preload("res://scripts/ui/hud.gd")


func _nodes() -> Dictionary:
	return HoldfastContent.base()["upgrade_nodes"]


func _meta_content() -> Dictionary:
	return HoldfastContent.base()


# ------------------------------------------------------------------ helpers

## Rules with no wave for 1000 s and nothing of ours doing damage.
func _quiet(edit: Callable = Callable(), upgrades: Array = [], level: String = "outpost") -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"][level]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	content["levels"][level]["staff"].erase("post")
	for at in content["levels"][level]["recruits"]:
		at.erase("post")
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config(level, upgrades, content, "flare_archer"), SimRng.new(1))
	return rules


func _enemy(rules: HoldfastRules, at: Vector2, health: float = 100.0, damage: int = 0) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	enemy.speed = 0.0
	enemy.damage = damage
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


## Knocks the Hero down where they stand, with one enemy that hits for more than their health.
func _knock_down(rules: HoldfastRules) -> void:
	var hitter := _enemy(rules, rules.hero_position, BIG, 1000)
	_run(rules, 1)
	rules.enemies.erase(hitter)


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


# ------------------------------------------------------------------ the tree in the pack

func test_the_tree_has_about_thirty_nodes_in_the_four_branches() -> void:
	var nodes := _nodes()
	expect_true(nodes.size() >= 28 and nodes.size() <= 32, "about 30 nodes, got %d" % nodes.size())
	var by_branch := {}
	for id in nodes:
		by_branch[nodes[id]["branch"]] = int(by_branch.get(nodes[id]["branch"], 0)) + 1
	expect_eq(by_branch.keys().size(), 4, "towers, keep, gold, unlocks: " + str(by_branch))
	for branch in ["towers", "keep", "gold", "unlocks"]:
		expect_true(int(by_branch.get(branch, 0)) >= 4, branch + " has real depth")


func test_the_branches_cover_what_the_board_names() -> void:
	var stats_by_branch := {}
	for id in _nodes():
		var node: Dictionary = _nodes()[id]
		for effect in node.get("effects", []):
			var list: Array = stats_by_branch.get(node["branch"], [])
			if not effect["stat"] in list:
				list.append(effect["stat"])
			stats_by_branch[node["branch"]] = list
	for stat in ["tower_damage", "tower_health", "tower_repair"]:
		expect_true(stat in stats_by_branch["towers"], "towers: " + stat)
	for stat in ["keep_health", "beam_reach"]:
		expect_true(stat in stats_by_branch["keep"], "keep: " + stat)
	expect_true("gold_multiplier" in stats_by_branch["gold"], "gold gain")
	expect_false(stats_by_branch.has("unlocks"), "unlock nodes carry no stat; they open levels")


func test_requirements_only_point_at_nodes_listed_before_them() -> void:
	var seen := []
	for id in _nodes():
		for required in _nodes()[id].get("requires", []):
			expect_true(required in seen, "%s requires %s, which must come first" % [id, required])
		seen.append(id)


func test_every_level_after_the_first_is_opened_by_exactly_one_node_in_order() -> void:
	var levels: Array = HoldfastContent.base()["levels"].keys()
	expect_eq(levels, ["outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"], "one coastal biome, five levels")
	var openers := {}
	for id in _nodes():
		if _nodes()[id].has("unlocks"):
			var level: String = _nodes()[id]["unlocks"]
			openers[level] = int(openers.get(level, 0)) + 1
	for i in range(1, levels.size()):
		expect_eq(openers.get(levels[i], 0), 1, levels[i] + " has one unlock node")
		var opener: String = "unlock_" + levels[i]
		expect_true(_nodes().has(opener), opener + " exists")
		if i > 1:
			expect_eq(_nodes()[opener]["requires"], ["unlock_" + levels[i - 1]], "levels open in order")
	expect_false(openers.has(levels[0]), "the first level is always open")


func test_a_dangling_unlock_is_refused_by_the_pack_loader_naming_the_field() -> void:
	var pack := PackLoader.load_pack(HoldfastContent.BASE_PACK, HoldfastContent.SCHEMA)
	expect_true(pack.ok)
	# The same check on a broken copy: the schema's x-ref ties "unlocks" to the levels.
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var errors: PackedStringArray = []
	var refs := []
	schema.validate_def({"upgrade_nodes": [{"id": "x", "name": "X", "branch": "unlocks", "cost": 5, "unlocks": "nowhere"}]}, "content", "upgrades.json: $", errors, refs)
	expect_true(errors.is_empty(), str(errors))
	expect_eq(refs[0][1], "levels", "unlocks refers to a level")
	expect_eq(refs[0][2], "nowhere")


# ------------------------------------------------------------------ meta actions

func test_a_new_profile_starts_empty_on_the_first_level_and_pillar() -> void:
	var profile := HoldfastMeta.new_profile(_meta_content())
	expect_eq(profile, {"gold": 0, "upgrades": [], "levels_won": [], "level": "outpost", "pillar": "flare_archer", "runs": 0})


func test_buying_pays_the_cost_and_records_the_upgrade_without_changing_the_old_profile() -> void:
	var content := _meta_content()
	var before := HoldfastMeta.new_profile(content)
	before["gold"] = 200
	var result := HoldfastMeta.buy(content, before, "keep_walls_1")  # costs 60
	expect_true(result["ok"])
	expect_eq(result["profile"]["gold"], 140)
	expect_eq(result["profile"]["upgrades"], ["keep_walls_1"])
	expect_eq(before["gold"], 200, "the profile given is untouched")
	expect_eq(before["upgrades"], [])


func test_buying_is_refused_with_a_reason_and_changes_nothing() -> void:
	var content := _meta_content()
	var profile := HoldfastMeta.new_profile(content)
	profile["gold"] = 109
	var cases := {
		"tower_drills_1": "Not enough gold",   # costs 110, one short
		"tower_drills_2": "Needs Archer drills I first",
		"no_such_node": "No such upgrade",
	}
	for id in cases:
		var refused := HoldfastMeta.buy(content, profile, id)
		expect_false(refused["ok"], id)
		expect_eq(refused["reason"], cases[id], id)
		expect_eq(refused["profile"], profile, id + ": nothing changed")
	profile["gold"] = 110
	expect_true(HoldfastMeta.buy(content, profile, "tower_drills_1")["ok"], "exactly enough gold buys it")
	profile["gold"] = 5000
	var bought: Dictionary = HoldfastMeta.buy(content, profile, "tower_drills_1")["profile"]
	expect_eq(HoldfastMeta.buy(content, bought, "tower_drills_1")["reason"], "Already bought")
	expect_true(HoldfastMeta.buy(content, bought, "tower_drills_2")["ok"], "the requirement is met now")


func test_levels_unlock_through_bought_nodes_and_a_locked_level_cannot_be_picked() -> void:
	var content := _meta_content()
	var profile := HoldfastMeta.new_profile(content)
	profile["gold"] = 1000
	expect_eq(HoldfastMeta.unlocked_levels(content, profile), ["outpost"])
	expect_eq(HoldfastMeta.select_level(content, profile, "shingle_beach"), profile, "locked: nothing changes")
	profile = HoldfastMeta.buy(content, profile, "unlock_shingle_beach")["profile"]  # 120
	expect_eq(HoldfastMeta.unlocked_levels(content, profile), ["outpost", "shingle_beach"])
	expect_eq(HoldfastMeta.select_level(content, profile, "shingle_beach")["level"], "shingle_beach")
	expect_eq(HoldfastMeta.select_level(content, profile, "no_such_level"), profile)
	expect_eq(HoldfastMeta.buy(content, profile, "unlock_old_pier")["reason"], "Needs Open Tidewrack Cove first")


func test_picking_a_pillar_needs_a_real_one() -> void:
	var content := _meta_content()
	var profile := HoldfastMeta.new_profile(content)
	expect_eq(HoldfastMeta.select_pillar(content, profile, "tideblade")["pillar"], "tideblade")
	expect_eq(HoldfastMeta.select_pillar(content, profile, "not_a_pillar"), profile)
	expect_eq(profile["pillar"], "flare_archer", "the profile given is untouched")


func test_banking_a_run_adds_its_gold_and_marks_only_won_levels() -> void:
	var profile := HoldfastMeta.new_profile(_meta_content())
	profile["gold"] = 10
	var lost := HoldfastMeta.bank_run(profile, {"gold": 25, "outcome": "lost", "level": "outpost"})
	expect_eq(lost["gold"], 35)
	expect_eq(lost["runs"], 1)
	expect_eq(lost["levels_won"], [])
	var won := HoldfastMeta.bank_run(lost, {"gold": 5, "outcome": "won", "level": "outpost"})
	expect_eq(won["gold"], 40)
	expect_eq(won["levels_won"], ["outpost"])
	expect_eq(HoldfastMeta.bank_run(won, {"gold": 1, "outcome": "won", "level": "outpost"})["levels_won"], ["outpost"], "no repeats")
	expect_eq(HoldfastMeta.bank_run(profile, {"gold": -50, "outcome": "lost", "level": "outpost"})["gold"], 10, "a run never takes gold away")
	expect_eq(profile["runs"], 0, "the profile given is untouched")


func test_a_loaded_profile_is_made_safe_before_use() -> void:
	var content := _meta_content()
	var messy := {
		"gold": -5, "runs": 3,
		"upgrades": ["keep_walls_1", "gone_node", "keep_walls_1"],
		"levels_won": ["outpost", "gone_level"],
		"level": "gull_rock",   # locked: falls back
		"pillar": "gone_pillar",
	}
	var profile := HoldfastMeta.from_save(content, messy)
	expect_eq(profile["gold"], 0)
	expect_eq(profile["upgrades"], ["keep_walls_1"])
	expect_eq(profile["levels_won"], ["outpost"])
	expect_eq(profile["level"], "outpost")
	expect_eq(profile["pillar"], "flare_archer")
	expect_eq(profile["runs"], 3)
	expect_eq(HoldfastMeta.from_save(content, {}), HoldfastMeta.new_profile(content), "an empty save is a new game")


# ------------------------------------------------------------------ saving through the kit

func test_the_profile_saves_after_each_change_and_reloads_exactly() -> void:
	var path := _save_path("profile")
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	expect_eq(profile.load_status, "missing", "no save yet")
	profile.bank_run({"gold": 300, "outcome": "won", "level": "outpost"})
	expect_true(profile.buy("unlock_shingle_beach"))  # 120
	expect_true(profile.buy("keep_walls_1"))          # 60
	profile.select_level("shingle_beach")
	profile.select_pillar("tideblade")
	var expected := profile.data.duplicate(true)
	expect_eq(expected["gold"], 120)
	profile.free()

	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.load_status, "ok")
	expect_eq(again.data, expected, "everything comes back, types included")
	expect_true(again.has_progress())
	again.free()
	var mid_run_service := SaveService.new(path, HoldfastMeta.SAVE_VERSION)
	expect_eq(mid_run_service.load_save()["data"], expected, "it is a plain SaveService file")


func test_a_damaged_save_falls_back_to_the_last_good_one_and_says_so() -> void:
	var path := _save_path("damaged")
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	profile.bank_run({"gold": 50, "outcome": "lost", "level": "outpost"})
	profile.bank_run({"gold": 70, "outcome": "lost", "level": "outpost"})
	profile.free()
	var bytes := FileAccess.get_file_as_bytes(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, bytes.size() / 2))
	file.close()

	var again := HoldfastProfile.new()
	again.save_path = path
	var notices: Array = []
	again.notice.connect(func(message: String) -> void: notices.append(message))
	tree.root.add_child(again)
	expect_eq(again.load_status, "recovered")
	expect_eq(again.get_gold(), 50, "the earlier save, not the broken one")
	expect_eq(notices.size(), 1, "the player is told")
	expect_ne(again.load_message, "")
	again.free()


func test_an_unreadable_only_save_starts_a_new_game_and_tells_the_player() -> void:
	var path := _save_path("garbage")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	expect_eq(profile.load_status, "corrupt")
	expect_ne(profile.load_message, "")
	expect_false(profile.has_progress(), "nothing to continue")
	expect_eq(profile.get_gold(), 0)
	profile.free()


func test_a_newer_save_is_left_alone_and_the_player_is_told_progress_will_not_save() -> void:
	var path := _save_path("newer")
	SaveService.new(path, HoldfastMeta.SAVE_VERSION + 1).save({"gold": 999})
	var before := FileAccess.get_file_as_bytes(path)
	var profile := HoldfastProfile.new()
	profile.save_path = path
	var notices: Array = []
	profile.notice.connect(func(message: String) -> void: notices.append(message))
	tree.root.add_child(profile)
	expect_eq(profile.load_status, "newer")
	profile.bank_run({"gold": 10, "outcome": "lost", "level": "outpost"})
	expect_true(notices.size() >= 2, "told on load and told the save failed: " + str(notices))
	expect_eq(FileAccess.get_file_as_bytes(path), before, "the newer save is untouched")
	profile.free()


func test_headless_runs_keep_the_profile_in_memory() -> void:
	var profile := HoldfastProfile.new()
	tree.root.add_child(profile)
	expect_eq(profile.save_path, "", "tests and CI never touch the player's save")
	profile.bank_run({"gold": 5, "outcome": "lost", "level": "outpost"})
	expect_eq(profile.get_gold(), 5)
	profile.free()


# ------------------------------------------------------------------ the beam and the upgrades in a run

func test_the_fog_edge_is_where_the_beam_reaches_and_enemies_spawn_there() -> void:
	var content := HoldfastContent.base()
	var radii := {"outpost": 420.0, "shingle_beach": 440.0, "tidewrack_cove": 460.0, "old_pier": 480.0, "gull_rock": 500.0}
	for level in radii:
		expect_eq(float(content["levels"][level]["spawn_radius"]), radii[level], level + " pack distance")
		var rules := HoldfastRules.new()
		rules.setup(HoldfastContent.run_config(level), SimRng.new(1))
		expect_eq(rules.spawn_radius, radii[level], level + " rules")
	# Two beam nodes: +30 and +30.
	var wide := HoldfastRules.new()
	wide.setup(HoldfastContent.run_config("outpost", ["keep_beam_1", "keep_beam_2"]), SimRng.new(1))
	expect_eq(wide.spawn_radius, 480.0)
	expect_eq(wide.hero_max_distance, 480.0, "the Hero may go as far as the beam reaches")
	var guard := 0
	while wide.enemies.is_empty() and guard < 200:
		wide.step(DT, {})
		guard += 1
	expect_false(wide.enemies.is_empty(), "the first enemy spawns")
	# It spawned one tick ago; at most one tick of walking (56/30) in from the edge.
	var from_keep := wide.enemies[0].position.length()
	expect_true(from_keep <= 480.0 and from_keep > 480.0 - 56.0 * DT - 0.001, "starts at the fog edge: %f" % from_keep)


func test_a_wider_beam_lengthens_the_walk_in_by_the_extra_distance() -> void:
	# One Grunt, nothing hurting it. Ticks until it is within 200 of the keep.
	var walk := func(upgrades: Array) -> int:
		var rules := _quiet(func(c: Dictionary) -> void:
			c["levels"]["outpost"]["first_wave_delay"] = 0.0
			c["levels"]["outpost"]["waves"] = [{"spawns": [{"enemy": "grunt", "count": 1}]}]
			c["hero_paths"]["flare_archer"]["attack"]["range"] = 1.0, upgrades)
		rules.hero_position = Vector2(0, -300)  # far from the Grunt's walk
		var ticks := 0
		while ticks < 1000:
			rules.step(DT, {})
			ticks += 1
			if not rules.enemies.is_empty() and rules.enemies[0].position.length() <= 200.0:
				break
		return ticks
	var near: int = walk.call([])
	var far: int = walk.call(["keep_beam_1", "keep_beam_2"])
	# 60 px more at 56 a second is 3.36 s, 32.1 ticks; the target is close to straight in.
	expect_true(far - near >= 30 and far - near <= 34, "walk-in is %d ticks longer" % (far - near))


func test_tower_upgrades_raise_damage_and_health_by_the_pack_amounts() -> void:
	var base := _quiet()
	var upgraded := _quiet(Callable(), ["tower_drills_1", "tower_drills_2", "tower_stone_1", "tower_stone_2"])
	expect_eq(upgraded.tower.health["max_health"], base.tower.health["max_health"] + 50.0, "+20 and +30 health")
	expect_eq(upgraded.tower.health["health"], upgraded.tower.health["max_health"], "built at full health")
	expect_eq(float(HoldfastContent.base()["towers"]["archer_post"]["damage"]), 4.0)
	var damaging := HoldfastRules.new()
	damaging.setup(HoldfastContent.run_config("outpost", ["tower_drills_1", "tower_drills_2"]), SimRng.new(1))
	expect_eq(damaging.tower.damage, 4.0 + 2.0 + 4.0)


func test_the_tower_repairs_between_waves_only_and_up_to_its_maximum() -> void:
	var rules := _quiet(Callable(), ["tower_mend_1"])  # 2 health a second
	rules.tower.health = UnitHealth.damage(rules.tower.health, 30.0)
	_run(rules, 30)
	expect_near(rules.tower.health["health"], 32.0, 0.001, "30 + 2 in a second with the field clear")
	var bystander := _enemy(rules, Vector2(400, 0))
	_run(rules, 60)
	expect_near(rules.tower.health["health"], 32.0, 0.001, "no repair while an enemy is on the field")
	rules.enemies.erase(bystander)
	_run(rules, 30 * 30)
	expect_eq(rules.tower.health["health"], 60.0, "stops at the maximum")
	var wrecked := _quiet(Callable(), ["tower_mend_1"])
	wrecked.tower.health = UnitHealth.damage(wrecked.tower.health, 60.0)
	wrecked.tower.up = false
	_run(wrecked, 90)
	expect_eq(wrecked.tower.health["health"], 0.0, "a destroyed tower is not repaired")
	var without := _quiet()
	without.tower.health = UnitHealth.damage(without.tower.health, 30.0)
	_run(without, 90)
	expect_eq(without.tower.health["health"], 30.0, "no upgrade, no repair")


func test_every_upgrade_in_the_pack_is_understood_by_the_rules() -> void:
	var known := ["aura_dps", "aura_radius", "keep_health", "gold_multiplier", "tower_damage", "tower_health", "tower_repair", "beam_reach", "staff_damage"]
	var all := []
	for id in _nodes():
		all.append(id)
		for effect in _nodes()[id].get("effects", []):
			expect_true(effect["stat"] in known, id + " uses " + effect["stat"])
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", all), SimRng.new(1))
	expect_eq(rules.setup_error, "")
	# Hand-worked totals: keep 100 + (25+50+75+100+150) = 500; beam 420 + 100; gold x1.25*1.3*1.2*1.15*1.1*1.1.
	expect_eq(rules.keep_health_max, 500)
	expect_eq(rules.spawn_radius, 520.0)
	expect_near(rules.gold_multiplier, 1.25 * 1.3 * 1.2 * 1.15 * 1.1 * 1.1, 0.0001)
	expect_eq(rules.tower_repair, 10.0)


func test_each_level_is_winnable_with_its_kit_by_every_pillar_bot() -> void:
	var content := HoldfastContent.base()
	for level in content["levels"]:
		var check: Dictionary = content["levels"][level]["balance_check"] if content["levels"][level].has("balance_check") else {}
		if not check.has("kit_gold"):
			continue
		var kit := HoldfastProgression.buy_cheapest(content["upgrade_nodes"], [], int(check["kit_gold"]))
		for pillar in ["flare_archer", "dusk_mage", "tideblade"]:
			var won := 0
			var hard := 0
			for run_seed in range(1, int(check["seeds"]) + 1):
				var result: Dictionary = HoldfastSim.run_headless(run_seed, HoldfastContent.run_config(level, kit, {}, pillar))["result"]
				won += 1 if result["outcome"] == HoldfastRules.OUTCOME_WON else 0
				hard += 1 if result["outcome"] != HoldfastRules.OUTCOME_WON or int(result["hero_knockdowns"]) > 1 else 0
			expect_true(won >= int(check["min_won_runs"]), "%s %s with %d gold of upgrades won %d of %d" % [level, pillar, check["kit_gold"], won, check["seeds"]])
			expect_true(hard >= int(check["min_hard_runs"]), "%s %s had %d hard runs" % [level, pillar, hard])


# ------------------------------------------------------------------ the Hero gets up where they fell

func test_the_hero_gets_up_where_they_fell_after_the_same_wait_and_drops_xp_there() -> void:
	# First and fourth knock-down: waits 3, 6, 10, 10 (the last entry holds).
	var waits := [3.0, 6.0, 10.0, 10.0]
	var rules := _quiet()
	rules.hero_position = Vector2(150, 90)
	for n in 4:
		rules.carried_xp = 7
		var fell_at := rules.hero_position
		_knock_down(rules)
		expect_true(rules.hero_state["downed"], "knock-down %d" % (n + 1))
		expect_near(rules.hero_state["get_up_in"], waits[n] - DT, 0.001, "wait for knock-down %d" % (n + 1))
		expect_eq(rules.xp_tokens.back().position, fell_at, "the XP drops where they fell")
		expect_eq(rules.xp_tokens.back().amount, 7)
		var ticks := 0
		while rules.hero_state["downed"] and ticks < 2000:
			_run(rules, 1)
			ticks += 1
		expect_eq(rules.hero_position, fell_at, "knock-down %d: up where they fell" % (n + 1))
		expect_eq(rules.hero_state["health"], 60.0)
		expect_near(float(ticks) * DT, waits[n] - DT, 0.04, "knock-down %d: waited %.0f s" % [n + 1, waits[n]])
		_run(rules, 61)  # past the untouchable window
		rules.xp_tokens.clear()
		rules.carried_xp = 0


func test_a_hero_who_fell_on_blocked_ground_or_outside_gets_up_on_open_ground() -> void:
	var rules := _quiet()
	rules.hero_position = Vector2(0, -10)  # inside the keep (radius 36 + Hero 12 = 48)
	_knock_down(rules)
	_run(rules, 91)
	expect_eq(rules.hero_position, Vector2(0, -48), "pushed to the edge of the keep")
	var far := _quiet()
	far.hero_position = Vector2(600, 0)  # beyond the 420 playfield
	_knock_down(far)
	_run(far, 91)
	expect_eq(far.hero_position, Vector2(420, 0), "pulled back inside the playfield")


func test_the_hero_is_untouchable_for_the_pack_time_after_getting_up() -> void:
	var rules := _quiet()
	expect_eq(rules.hero_untouchable_seconds, 2.0, "default 2 s")
	_knock_down(rules)
	var ticks := 0
	while rules.hero_state["downed"]:
		_run(rules, 1)
		ticks += 1
	expect_true(rules.hero_untouchable(), "untouchable the moment they are up")
	var hitter := _enemy(rules, rules.hero_position, BIG, 1000)
	_run(rules, 58)  # 58 ticks after getting up: 1.93 s
	expect_true(rules.hero_untouchable(), "still untouchable at 1.93 s")
	expect_false(rules.hero_state["downed"], "the enemy standing on them did nothing")
	expect_eq(rules.hero_state["health"], 60.0)
	_run(rules, 1)  # 59 ticks: 1.97 s
	expect_true(rules.hero_untouchable(), "and at 1.97 s")
	expect_false(rules.hero_state["downed"])
	hitter.hit_in = 0.0
	_run(rules, 1)  # 60 ticks: exactly 2 s
	expect_false(rules.hero_untouchable(), "touchable at exactly 2 s")
	# The enemy was left aimed at the Hero's old spot; it hits once it has the Hero as its target again.
	_run(rules, 40)
	expect_true(rules.hero_state["downed"], "the next hit lands")
	expect_eq(rules.hero_state["knockdowns"], 2)


func test_enemies_do_not_pick_an_untouchable_hero_as_their_target() -> void:
	var rules := _quiet()
	_knock_down(rules)
	while rules.hero_state["downed"]:
		_run(rules, 1)
	var near := _enemy(rules, rules.hero_position + Vector2(5, 0))
	_run(rules, 12)
	expect_ne(near.target, "hero", "the Hero is not a target while untouchable")
	_run(rules, 60)
	expect_eq(near.target, "hero", "and is again once it ends")


func test_untouchable_time_comes_from_the_pack_and_zero_is_allowed() -> void:
	var zero := _quiet(func(c: Dictionary) -> void: c["hero_paths"]["flare_archer"]["untouchable_seconds"] = 0.0)
	_knock_down(zero)
	while zero.hero_state["downed"]:
		_run(zero, 1)
	expect_false(zero.hero_untouchable(), "zero: touchable at once")
	var long := _quiet(func(c: Dictionary) -> void: c["hero_paths"]["flare_archer"]["untouchable_seconds"] = 5.0)
	_knock_down(long)
	while long.hero_state["downed"]:
		_run(long, 1)
	_run(long, 149)  # 4.97 s
	expect_true(long.hero_untouchable())
	_run(long, 1)    # 5 s
	expect_false(long.hero_untouchable())
	var bad := PackSchema.load_file(HoldfastContent.SCHEMA)
	var errors: PackedStringArray = []
	var entry: Dictionary = HoldfastContent.base()["hero_paths"]["flare_archer"].duplicate(true)
	entry["untouchable_seconds"] = -1
	bad.validate_def(entry, "hero_path", "heroes.json: $", errors, [])
	expect_any_contains(errors, "untouchable_seconds")


# ------------------------------------------------------------------ headless and playable agree

class Replay:
	extends SimController
	var inputs: Array = []

	func get_input(_rules: SimRules, tick: int) -> Dictionary:
		return inputs[tick] if tick < inputs.size() else {}


func test_headless_and_playable_build_match_on_a_later_level_with_upgrades_and_falls() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 91
	var directions := [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1]]
	var inputs := []
	var heading: Array = directions[0]
	for tick in 4000:
		if tick % 20 == 0:
			heading = directions[dice.randi_range(0, directions.size() - 1)]
		inputs.append({"move": heading, "ability": dice.randf() < 0.02})
	var frames := RandomNumberGenerator.new()
	frames.seed = 8
	var upgrades := ["keep_beam_1", "tower_drills_1", "tower_mend_1", "tower_stone_1", "keep_walls_1", "unlock_shingle_beach", "unlock_tidewrack_cove", "unlock_old_pier", "unlock_gull_rock"]
	for level in ["outpost", "gull_rock"]:
		for id in ["flare_archer", "dusk_mage", "tideblade"]:
			var replay := Replay.new()
			replay.inputs = inputs
			var config := HoldfastContent.run_config(level, upgrades, {}, id)
			var headless := SimBotRunner.run(HoldfastRules.new(), replay, 4, config, 100000, HoldfastRules.TICK_RATE)
			var source := HoldfastRunSource.new()
			source.auto_step = false
			source.rng_seed = 4
			source.hero_path = id
			source.level_id = level
			source.upgrades = upgrades
			var played := Replay.new()
			played.inputs = inputs
			source.controller_override = played
			tree.root.add_child(source)
			source.start_run()
			var count := 0
			while source.is_running() and count < 1_000_000:
				source.step(frames.randf_range(1.0 / 144.0, 1.0 / 15.0))
				count += 1
			var label := "%s %s" % [level, id]
			expect_false(source.is_running(), label + " ended")
			expect_eq(source.get_engine().state_hash(), headless["hash"], label + " state hash")
			expect_eq(source.get_rules().result(), headless["result"], label + " result")
			expect_true(int(headless["result"]["hero_knockdowns"]) >= 0)
			source.free()


# ------------------------------------------------------------------ the screens and the flow

func _main(path: String = "") -> Node:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	if path != "":
		main.get_node("Profile").save_path = path
	tree.root.add_child(main)
	return main


func test_the_app_opens_on_the_home_screen_and_new_game_leads_to_the_keep() -> void:
	var main := _main()
	expect_true(main.home.visible and not main.keep_screen.visible)
	expect_true(main.home.get_node("%ContinueButton").disabled, "nothing to continue yet")
	main.home.get_node("%NewGameButton").pressed.emit()
	expect_true(main.keep_screen.visible and not main.home.visible)
	main.keep_screen.get_node("%BackButton").pressed.emit()
	expect_true(main.home.visible, "Back returns home")
	main.free()


func test_continue_resumes_a_save_and_new_game_asks_twice_before_erasing_it() -> void:
	var path := _save_path("continue")
	var first := _main(path)
	first.get_node("Profile").bank_run({"gold": 400, "outcome": "won", "level": "outpost"})
	first.free()

	var main := _main(path)
	var home: Control = main.home
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_false(home.get_node("%ContinueButton").disabled, "there is a save to continue")
	expect_eq(profile.get_gold(), 400)
	home.get_node("%NewGameButton").pressed.emit()
	expect_true(home.visible, "the first click only asks")
	expect_true(home.get_node("%NewGameButton").text.contains("Erase"), "and says what it will do")
	expect_eq(profile.get_gold(), 400, "nothing erased yet")
	home.get_node("%ContinueButton").pressed.emit()
	expect_true(main.keep_screen.visible, "Continue goes to the keep")
	expect_eq(profile.get_gold(), 400, "and keeps the progress")
	main.keep_screen.get_node("%BackButton").pressed.emit()
	home.get_node("%NewGameButton").pressed.emit()
	home.get_node("%NewGameButton").pressed.emit()
	expect_true(main.keep_screen.visible, "the second click starts over")
	expect_eq(profile.get_gold(), 0)
	main.free()


func test_the_keep_screen_buys_through_the_flow_and_the_profile_saves() -> void:
	var path := _save_path("keep_buy")
	var main := _main(path)
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.bank_run({"gold": 200, "outcome": "lost", "level": "outpost"})
	var keep: Control = main.keep_screen
	keep.visible = true
	var drills: Button = keep._node_buttons["tower_drills_1"]
	var walls: Button = keep._node_buttons["keep_walls_1"]
	expect_true(drills.disabled == false and walls.disabled == false, "both affordable (110, 60)")
	expect_true(keep._node_buttons["tower_drills_2"].disabled, "needs the first drill")
	walls.pressed.emit()
	expect_eq(profile.get_gold(), 140)
	expect_true(walls.disabled and walls.text.contains("bought"))
	expect_eq(keep.get_node("%GoldValue").text, "140")
	drills.pressed.emit()
	expect_eq(profile.get_gold(), 30)
	expect_true(keep._node_buttons["tower_drills_2"].disabled, "450 is out of reach")
	main.free()
	var reloaded: Dictionary = SaveService.new(path, HoldfastMeta.SAVE_VERSION).load_save()["data"]
	expect_eq(reloaded["gold"], 30)
	expect_eq(reloaded["upgrades"], ["keep_walls_1", "tower_drills_1"])


func test_level_and_pillar_picks_start_the_next_run_with_the_bought_upgrades() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.bank_run({"gold": 500, "outcome": "lost", "level": "outpost"})
	var keep: Control = main.keep_screen
	keep.visible = true
	expect_true(keep._level_buttons["shingle_beach"].disabled, "locked until bought")
	keep._node_buttons["unlock_shingle_beach"].pressed.emit()    # 120
	keep._node_buttons["keep_beam_1"].pressed.emit()             # 200
	keep._node_buttons["tower_stone_1"].pressed.emit()           # 70
	expect_false(keep._level_buttons["shingle_beach"].disabled, "open now")
	keep._level_buttons["shingle_beach"].pressed.emit()
	keep.select_pillar("dusk_mage")
	keep.select_pillar("not_a_pillar")
	expect_eq(keep.selected_pillar, "dusk_mage", "an unknown pillar changes nothing")
	expect_eq(keep.selected_level, "shingle_beach")
	keep.get_node("%PlayButton").pressed.emit()
	var source: HoldfastRunSource = main.get_node("RunSource")
	var rules := source.get_rules()
	expect_eq(rules.level_id, "shingle_beach")
	expect_eq(rules.hero_path_id, "dusk_mage")
	expect_eq(rules.spawn_radius, 440.0 + 30.0, "the beam node applies")
	expect_eq(rules.tower.health["max_health"], 80.0, "and the tower timbers")
	main.free()


func test_a_finished_run_banks_its_gold_and_the_summary_returns_to_the_keep() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.use_bot = true
	source.rng_seed = 1
	main.call("_start_run")
	source.step(3600.0)
	expect_false(source.is_running())
	var result: Dictionary = source.get_rules().result()
	expect_true(int(result["gold"]) > 0)
	expect_eq(profile.get_gold(), int(result["gold"]), "the run's gold is in the bank")
	expect_eq(int(profile.data["runs"]), 1)
	expect_true(main.summary.visible)
	main.summary.get_node("%KeepButton").pressed.emit()
	expect_true(main.keep_screen.visible and not main.summary.visible)
	expect_eq(main.keep_screen.get_node("%GoldValue").text, Hud.format_number(int(result["gold"])), "and the keep shows it")
	main.free()


func test_screens_only_ask_the_profile_never_change_it() -> void:
	var allowed := ["changed", "notice", "load_message", "load_status"]
	var dir := "res://scripts/ui/"
	var re := RegEx.create_from_string("\\b_?profile\\.(\\w+)")
	var seen := 0
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd") or file == "run_state_source.gd":
			continue
		var text := FileAccess.get_file_as_string(dir + file)
		for m in re.search_all(text):
			seen += 1
			var member := m.get_string(1)
			expect_true(member.begins_with("get_") or member.begins_with("is_") or member.begins_with("has_") or member.begins_with("why_") or member in allowed,
					"%s touches profile.%s: screens may read or listen only" % [file, member])
		expect_false(text.contains("HoldfastMeta.buy") or text.contains("SaveService") or text.contains("FileAccess"), file + " does not change progress or write files itself")
		expect_false(text.contains("start_run"), file + " never starts a run itself")
	expect_true(seen > 5, "the check saw the screens' profile reads")


func test_the_hud_shows_the_hero_the_ability_the_knock_down_timer_and_what_was_lost() -> void:
	var main := _main()
	main.call("_start_run")
	var source: HoldfastRunSource = main.get_node("RunSource")
	var rules := source.get_rules()
	var hud: Control = main.hud
	hud._refresh_hero()
	expect_eq(hud.get_node("%HeroValue").text, "60 / 60")
	expect_eq(hud.get_node("%AbilityValue").text, "Ready")
	expect_eq(hud.get_node("%LostValue").text, "0 / 0")
	rules.hero_ability_ready_in = 3.2
	rules.towers_lost = 1
	rules.recruits_downed = 2
	rules.hero_state["health"] = 41.0
	hud._refresh_hero()
	expect_eq(hud.get_node("%HeroValue").text, "41 / 60")
	expect_eq(hud.get_node("%AbilityValue").text, "3.2 s")
	expect_eq(hud.get_node("%LostValue").text, "1 / 2")
	rules.hero_state = HeroKnockdown.take_damage(rules.hero_state, 100.0, rules.hero_delays)
	hud._refresh_hero()
	expect_eq(hud.get_node("%HeroValue").text, "Down 3 s", "the knock-down timer")
	main.free()


func test_the_hud_fits_at_both_sizes_with_the_worst_numbers() -> void:
	var main := _main()
	main.call("_start_run")
	var hud: Control = main.hud
	hud.get_node("%GoldValue").text = "9,999,999"
	hud.get_node("%WaveValue").text = "99 / 99"
	hud.get_node("%KeepValue").text = "99,999 / 99,999"
	hud.get_node("%HeroValue").text = "Down 10 s"
	hud.get_node("%AbilityValue").text = "10.0 s"
	hud.get_node("%LostValue").text = "99 / 99"
	var window_before := tree.root.size
	for window in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = window
		await tree.process_frame
		var view := tree.root.get_visible_rect()
		var bar: Control = hud.get_node("TopBar")
		expect_true(view.encloses(bar.get_global_rect()), "%s: the HUD bar is on screen" % window)
		expect_true(bar.get_global_rect().end.y <= 121.0, "%s: and no taller than the space the world view leaves it" % window)
		for label in ["GoldValue", "WaveValue", "HeroValue", "AbilityValue", "LostValue"]:
			var node: Label = hud.get_node("%" + label)
			expect_true(node.size.x + 0.5 >= node.get_minimum_size().x, "%s: %s is not clipped" % [window, label])
	tree.root.size = window_before
	main.free()


# ------------------------------------------------------------------ the progression stop

func test_the_ten_hour_progression_stops_right_after_the_run_that_buys_the_last_upgrade() -> void:
	var report := HoldfastProgression.play(1, 10.0)
	expect_eq(report["upgrades_owned"], report["upgrades_total"], "every upgrade is bought")
	var unlocks: Array = report["unlocks"]
	expect_eq(unlocks.size(), report["upgrades_total"])
	expect_eq(unlocks[-1]["after_run"], report["runs_played"], "the last run played is the one that bought the last upgrade")
	expect_true(unlocks[-1]["at_seconds"] <= report["sim_seconds"], "and it stops there, not later")
	expect_true(report["sim_seconds"] < 10.0 * 3600.0, "well inside the ten hours")
	var before_last := 0
	for unlock in unlocks:
		if int(unlock["after_run"]) < int(report["runs_played"]):
			before_last += 1
	expect_true(before_last < int(report["upgrades_total"]), "some upgrade was still unbought before the last run")


func test_a_progression_with_upgrades_left_plays_on_to_the_end_of_its_time() -> void:
	var report := HoldfastProgression.play(7, 0.25)
	expect_true(report["upgrades_owned"] < report["upgrades_total"], "a quarter hour does not buy the whole tree")
	expect_true(report["sim_seconds"] >= 0.25 * 3600.0, "so it keeps playing until the time is up")
