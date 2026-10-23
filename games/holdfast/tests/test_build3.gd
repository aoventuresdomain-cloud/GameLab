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

func test_the_tree_has_sections_with_real_depth() -> void:
	var nodes := _nodes()
	var sections: Dictionary = HoldfastContent.base()["upgrade_sections"]
	expect_true(nodes.size() >= 30 and nodes.size() <= 60, "about 50 nodes, got %d" % nodes.size())
	var by_branch := {}
	for id in nodes:
		expect_true(sections.has(nodes[id]["branch"]), id + " sits in a section the pack lists")
		by_branch[nodes[id]["branch"]] = int(by_branch.get(nodes[id]["branch"], 0)) + 1
	expect_eq(by_branch.keys().size(), 5, "flare_archer, archer_post, keep, gold, castle: " + str(by_branch))
	for branch in ["flare_archer", "archer_post", "keep", "gold"]:
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
	for stat in ["tower.damage", "tower.health", "tower.repair", "tower.range", "tower.cooldown"]:
		expect_true(stat in stats_by_branch["archer_post"], "archer_post: " + stat)
	for stat in ["hero.move_speed", "hero.health", "hero.attack.damage"]:
		expect_true(stat in stats_by_branch["flare_archer"], "flare_archer: " + stat)
	for stat in ["keep_health", "beam_reach"]:
		expect_true(stat in stats_by_branch["keep"], "keep: " + stat)
	expect_true("gold_multiplier" in stats_by_branch["gold"], "gold gain")


func test_requirements_only_point_at_nodes_listed_before_them() -> void:
	var seen := []
	for id in _nodes():
		for required in _nodes()[id].get("requires", []):
			expect_true(required in seen, "%s requires %s, which must come first" % [id, required])
		seen.append(id)


func test_the_biome_has_five_levels_and_no_node_sells_one() -> void:
	var levels: Array = HoldfastContent.base()["levels"].keys()
	expect_eq(levels, ["first_watch", "outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"], "one coastal biome: Level 0 and five levels")
	for id in _nodes():
		expect_ne(_nodes()[id]["branch"], "unlocks", id + " is not a level node")
		expect_false(_nodes()[id].has("unlocks"), id + " opens no level")


func test_the_pack_schema_refuses_a_node_that_sells_a_level() -> void:
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var errors: PackedStringArray = []
	schema.validate_def({"upgrade_nodes": [{"id": "x", "name": "X", "branch": "gold", "cost": 5, "unlocks": "shingle_beach"}]}, "content", "upgrades.json: $", errors, [])
	expect_false(errors.is_empty(), "an unlocks field is not part of a node")
	errors.clear()
	schema.validate_def({"upgrade_nodes": [{"id": "x", "name": "X", "branch": "unlocks", "cost": 5}]}, "content", "upgrades.json: $", errors, [])
	expect_false(errors.is_empty(), "and neither is a levels branch")


# ------------------------------------------------------------------ meta actions

func test_a_new_profile_starts_empty_on_the_first_level_and_pillar() -> void:
	var profile := HoldfastMeta.new_profile(_meta_content())
	expect_eq(profile, {"gold": 0, "upgrades": [], "stars": {}, "levels_won": [], "unlocked": [], "level": "first_watch", "pillar": "flare_archer", "runs": 0, "layouts": {}, "gear": {"owned": [], "equipped": {"weapon": "", "helmet": "", "armour": "", "boots": "", "ring": ""}}})


func test_buying_pays_the_cost_and_records_the_upgrade_without_changing_the_old_profile() -> void:
	var content := _meta_content()
	var before := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	before["gold"] = 200
	var owned: Array = before["upgrades"].duplicate()
	var result := HoldfastMeta.buy(content, before, "keep_walls_1")  # costs 60
	expect_true(result["ok"])
	expect_eq(result["profile"]["gold"], 140)
	expect_eq(result["profile"]["upgrades"], owned + ["keep_walls_1"])
	expect_eq(before["gold"], 200, "the profile given is untouched")
	expect_eq(before["upgrades"], owned)


func test_buying_is_refused_with_a_reason_and_changes_nothing() -> void:
	var content := _meta_content()
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	profile["gold"] = 109
	var cases := {
		"post_drills": "Not enough gold",   # costs 110, one short
		"post_mend": "Needs Post timbers first",
		"no_such_node": "No such upgrade",
	}
	for id in cases:
		var refused := HoldfastMeta.buy(content, profile, id)
		expect_false(refused["ok"], id)
		expect_eq(refused["reason"], cases[id], id)
		expect_eq(refused["profile"], profile, id + ": nothing changed")
	profile["gold"] = 110
	expect_true(HoldfastMeta.buy(content, profile, "post_drills")["ok"], "exactly enough gold buys it")
	profile["gold"] = 5000
	var bought: Dictionary = HoldfastMeta.buy(content, profile, "post_drills")["profile"]
	expect_eq(HoldfastMeta.buy(content, bought, "post_drills")["reason"], "Already bought")
	expect_true(HoldfastMeta.buy(content, bought, "post_twin")["ok"], "the requirement is met now")


func test_levels_unlock_by_winning_the_previous_one_and_a_locked_level_cannot_be_picked() -> void:
	var content := _meta_content()
	var profile := HoldfastMeta.new_profile(content)
	profile["gold"] = 100000
	expect_eq(HoldfastMeta.unlocked_levels(content, profile), ["first_watch"])
	expect_eq(HoldfastMeta.select_level(content, profile, "shingle_beach"), profile, "locked: nothing changes")
	for id in content["upgrade_nodes"]:
		var bought: Dictionary = HoldfastMeta.buy(content, profile, id)
		if bought["ok"]:
			profile = bought["profile"]
	expect_eq(HoldfastMeta.unlocked_levels(content, profile), ["first_watch"], "no purchase opens a level")
	var lost := HoldfastMeta.bank_run(content, profile, {"gold": 0, "outcome": "lost", "level": "outpost"})
	expect_eq(HoldfastMeta.unlocked_levels(content, lost), ["first_watch"], "losing opens nothing")
	var past_zero := HoldfastMeta.bank_run(content, profile, {"gold": 0, "outcome": "won", "level": "first_watch"})
	var won := HoldfastMeta.bank_run(content, past_zero, {"gold": 0, "outcome": "won", "level": "outpost"})
	expect_eq(HoldfastMeta.unlocked_levels(content, won), ["first_watch", "outpost", "shingle_beach"])
	expect_eq(HoldfastMeta.select_level(content, won, "shingle_beach")["level"], "shingle_beach")
	expect_eq(HoldfastMeta.select_level(content, won, "tidewrack_cove"), won, "only the next one opens")
	expect_eq(HoldfastMeta.select_level(content, won, "no_such_level"), won)


func test_winning_each_level_in_order_opens_the_next_and_the_last_opens_nothing() -> void:
	var content := _meta_content()
	var profile := HoldfastMeta.new_profile(content)
	var order := ["first_watch", "outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]
	for i in order.size():
		profile = HoldfastMeta.bank_run(content, profile, {"gold": 0, "outcome": "won", "level": order[i]})
		expect_eq(HoldfastMeta.unlocked_levels(content, profile), order.slice(0, mini(i + 2, order.size())), "after winning " + order[i])
	expect_eq(profile["levels_won"], order)
	expect_eq(HoldfastMeta.bank_run(content, profile, {"gold": 0, "outcome": "won", "level": "gull_rock"})["unlocked"].size(), 5, "winning again changes nothing")


func test_picking_a_pillar_needs_a_real_one() -> void:
	var content := _meta_content()
	var profile := HoldfastMeta.new_profile(content)
	expect_eq(HoldfastMeta.select_pillar(content, profile, "tideblade")["pillar"], "tideblade")
	expect_eq(HoldfastMeta.select_pillar(content, profile, "not_a_pillar"), profile)
	expect_eq(profile["pillar"], "flare_archer", "the profile given is untouched")


func test_banking_a_run_adds_its_gold_and_marks_only_won_levels() -> void:
	var content := _meta_content()
	var profile := HoldfastMeta.new_profile(content)
	profile["gold"] = 10
	var lost := HoldfastMeta.bank_run(content, profile, {"gold": 25, "outcome": "lost", "level": "outpost"})
	expect_eq(lost["gold"], 35)
	expect_eq(lost["runs"], 1)
	expect_eq(lost["levels_won"], [])
	var won := HoldfastMeta.bank_run(content, lost, {"gold": 5, "outcome": "won", "level": "outpost"})
	expect_eq(won["gold"], 40)
	expect_eq(won["levels_won"], ["outpost"])
	expect_eq(HoldfastMeta.bank_run(content, won, {"gold": 1, "outcome": "won", "level": "outpost"})["levels_won"], ["outpost"], "no repeats")
	expect_eq(HoldfastMeta.bank_run(content, profile, {"gold": -50, "outcome": "lost", "level": "outpost"})["gold"], 10, "a run never takes gold away")
	expect_eq(profile["runs"], 0, "the profile given is untouched")


func test_a_loaded_profile_is_made_safe_before_use() -> void:
	var content := _meta_content()
	var messy := {
		"gold": -5, "runs": 3,
		"upgrades": ["keep_walls_1", "gone_node", "keep_walls_1"],
		"levels_won": ["outpost", "gone_level"],
		"unlocked": ["shingle_beach", "gone_level", "shingle_beach"],
		"level": "gull_rock",   # locked: falls back
		"pillar": "gone_pillar",
	}
	var profile := HoldfastMeta.from_save(content, messy)
	expect_eq(profile["gold"], 0)
	expect_eq(profile["upgrades"], ["keep_walls_1"])
	expect_eq(profile["levels_won"], ["outpost"])
	expect_eq(profile["unlocked"], ["shingle_beach"])
	expect_eq(profile["level"], "first_watch")
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
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run({"gold": 300, "outcome": "won", "level": "outpost"})
	expect_true(profile.buy("keep_walls_1"))          # 60
	profile.select_level("shingle_beach")
	profile.select_pillar("tideblade")
	var expected := profile.data.duplicate(true)
	expect_eq(expected["gold"], 240)
	expect_eq(expected["unlocked"], ["shingle_beach"])
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


## A Build 3 save (version 1), as the game wrote it: level nodes bought, one level never won.
func _v1_save(path: String, gold: int) -> void:
	SaveService.new(path, 1).save({
		"gold": gold, "runs": 7,
		"upgrades": ["keep_walls_1", "unlock_shingle_beach", "unlock_tidewrack_cove", "tower_drills_1"],
		"levels_won": ["outpost"],
		"level": "tidewrack_cove", "pillar": "tideblade",
	})


func test_a_build_3_save_keeps_its_levels_and_gets_the_level_nodes_gold_back() -> void:
	var path := _save_path("v1")
	_v1_save(path, 50)
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	expect_eq(profile.load_status, "migrated")
	expect_eq(profile.get_unlocked_levels(), ["first_watch", "outpost", "shingle_beach", "tidewrack_cove"], "both bought levels stay open, won or not")
	expect_eq(profile.get_upgrades(), [], "the level nodes are gone from the upgrades, the Archer drills the tree no longer has, and the castle starts empty")
	expect_eq(profile.get_gold(), 50 + 120 + 500 + 110 + 60, "their cost comes back, the drills' 110, and Stone walls I's 60")
	expect_eq(profile.get_level(), "tidewrack_cove", "the level it was on is kept")
	expect_eq(profile.get_pillar(), "tideblade")
	expect_eq(profile.data["runs"], 7)
	expect_true(profile.is_level_won("outpost") and not profile.is_level_won("shingle_beach"), "wins are as they were")
	profile.select_level("shingle_beach")
	profile.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.load_status, "ok", "saved as the new version once it changed")
	expect_eq(again.get_unlocked_levels(), ["first_watch", "outpost", "shingle_beach", "tidewrack_cove"])
	expect_eq(again.get_level(), "shingle_beach")
	again.free()


func test_migrating_a_save_without_level_nodes_changes_only_its_shape() -> void:
	var old := {"gold": 9, "upgrades": ["keep_walls_1"], "levels_won": []}
	var migrated := HoldfastMeta.migrate_v1(old, HoldfastContent.base())
	expect_eq(migrated, {"gold": 9, "upgrades": ["keep_walls_1"], "levels_won": [], "unlocked": []})
	expect_eq(old, {"gold": 9, "upgrades": ["keep_walls_1"], "levels_won": []}, "the save given is untouched")


func test_a_build_3_save_that_won_levels_without_buying_their_nodes_opens_the_next_ones() -> void:
	var content := _meta_content()
	var won := HoldfastMeta.migrate_v1({"gold": 5, "upgrades": ["keep_walls_1"], "levels_won": ["outpost", "shingle_beach"]}, content)
	expect_eq(won["unlocked"], ["shingle_beach", "tidewrack_cove"], "winning a level opens the next, as it does now")
	expect_eq(won["gold"], 5, "no node bought, nothing refunded")
	var profile := HoldfastMeta.from_save(content, won)
	expect_eq(HoldfastMeta.unlocked_levels(content, profile), ["first_watch", "shingle_beach", "tidewrack_cove"])
	var last := HoldfastMeta.migrate_v1({"levels_won": ["gull_rock", "gone_level"]}, content)
	expect_eq(last["unlocked"], [], "the last level has no next, an unknown one opens nothing")
	var both := HoldfastMeta.migrate_v1({"upgrades": ["unlock_shingle_beach"], "levels_won": ["outpost"]}, content)
	expect_eq(both["unlocked"], ["shingle_beach"], "a level opened both ways is listed once")


func test_a_level_node_listed_twice_in_a_save_is_refunded_once() -> void:
	var migrated := HoldfastMeta.migrate_v1({"gold": 0, "upgrades": ["unlock_shingle_beach", "unlock_shingle_beach"]}, _meta_content())
	expect_eq(migrated["gold"], 120)
	expect_eq(migrated["unlocked"], ["shingle_beach"])
	expect_eq(migrated["upgrades"], [])


func test_winning_a_level_already_won_still_opens_the_next_one() -> void:
	var content := _meta_content()
	var profile := HoldfastMeta.new_profile(content)
	profile["levels_won"] = ["outpost"]   # won before the next level could be opened by it
	var again := HoldfastMeta.bank_run(content, profile, {"gold": 0, "outcome": "won", "level": "outpost"})
	expect_eq(again["unlocked"], ["shingle_beach"])
	expect_eq(again["levels_won"], ["outpost"], "still listed once")


func test_a_damaged_build_3_save_recovers_and_migrates_and_a_newer_one_is_still_left_alone() -> void:
	var path := _save_path("v1_damaged")
	_v1_save(path, 10)
	_v1_save(path, 20)
	var bytes := FileAccess.get_file_as_bytes(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, bytes.size() / 2))
	file.close()
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	expect_eq(profile.load_status, "recovered")
	expect_eq(profile.get_unlocked_levels(), ["first_watch", "outpost", "shingle_beach", "tidewrack_cove"], "the earlier save is migrated too")
	expect_eq(profile.get_gold(), 10 + 120 + 500 + 110 + 60, "and the removed Archer drills and Stone walls I are refunded")
	profile.free()
	var newer := _save_path("v1_newer")
	SaveService.new(newer, HoldfastMeta.SAVE_VERSION + 1).save({"gold": 1, "unlocked": ["gull_rock"]})
	var untouched := FileAccess.get_file_as_bytes(newer)
	var other := HoldfastProfile.new()
	other.save_path = newer
	tree.root.add_child(other)
	expect_eq(other.load_status, "newer")
	expect_eq(other.get_unlocked_levels(), ["first_watch"], "nothing is read from a newer save")
	expect_eq(FileAccess.get_file_as_bytes(newer), untouched)
	other.free()


func test_winning_saves_the_unlock_at_once_and_losing_never_unlocks() -> void:
	var path := _save_path("win_saves")
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	profile.bank_run({"gold": 5, "outcome": "lost", "level": "outpost"})
	var after_loss := HoldfastProfile.new()
	after_loss.save_path = path
	tree.root.add_child(after_loss)
	expect_eq(after_loss.get_unlocked_levels(), ["first_watch"], "a loss opens nothing")
	after_loss.free()
	profile.bank_run({"gold": 5, "outcome": "won", "level": "first_watch"})
	profile.bank_run({"gold": 5, "outcome": "won", "level": "outpost"})
	profile.free()  # no quit hook: the win must already be on disk
	var reloaded := HoldfastProfile.new()
	reloaded.save_path = path
	tree.root.add_child(reloaded)
	expect_eq(reloaded.get_unlocked_levels(), ["first_watch", "outpost", "shingle_beach"], "win, reload, next level open")
	reloaded.select_level("shingle_beach")
	expect_eq(reloaded.get_level(), "shingle_beach")
	reloaded.free()


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
	var upgraded := _quiet(Callable(), ["post_drills", "post_timbers"])
	expect_eq(upgraded.tower.health["max_health"], base.tower.health["max_health"] + 30.0, "+30 health")
	expect_eq(upgraded.tower.health["health"], upgraded.tower.health["max_health"], "built at full health")
	expect_eq(float(HoldfastContent.base()["towers"]["archer_post"]["damage"]), 4.0)
	var damaging := HoldfastRules.new()
	damaging.setup(HoldfastContent.run_config("outpost", ["post_drills"]), SimRng.new(1))
	expect_eq(damaging.tower.damage, 4.0 + 2.0)


func test_the_tower_repairs_between_waves_only_and_up_to_its_maximum() -> void:
	var rules := _quiet(Callable(), ["post_mend"])  # 3 health a second
	rules.tower.health = UnitHealth.damage(rules.tower.health, 30.0)
	_run(rules, 30)
	expect_near(rules.tower.health["health"], 33.0, 0.001, "30 + 3 in a second with the field clear")
	var bystander := _enemy(rules, Vector2(400, 0))
	_run(rules, 60)
	expect_near(rules.tower.health["health"], 33.0, 0.001, "no repair while an enemy is on the field")
	rules.enemies.erase(bystander)
	_run(rules, 30 * 30)
	expect_eq(rules.tower.health["health"], 60.0, "stops at the maximum")
	var wrecked := _quiet(Callable(), ["post_mend"])
	wrecked.tower.health = UnitHealth.damage(wrecked.tower.health, 60.0)
	wrecked.tower.up = false
	_run(wrecked, 90)
	expect_eq(wrecked.tower.health["health"], 0.0, "a destroyed tower is not repaired")
	var without := _quiet()
	without.tower.health = UnitHealth.damage(without.tower.health, 30.0)
	_run(without, 90)
	expect_eq(without.tower.health["health"], 30.0, "no upgrade, no repair")


func test_every_upgrade_in_the_pack_is_understood_by_the_rules() -> void:
	var known := ["aura_dps", "aura_radius", "keep_health", "gold_multiplier", "beam_reach", "staff_damage"]
	var known_tower := ["damage", "health", "range", "cooldown", "repair", "extra_targets", "lone_bonus", "pierce", "burst_every", "burst_extra", "storm_every", "storm_share", "hero_haste", "hero_radius", "crossfire", "burn_dps", "burn_seconds", "rally_repair", "rally_shield", "rally_radius", "rally_seconds", "last_light", "last_light_radius", "watch_range", "watch_radius"]
	var known_hero := ["move_speed", "health", "attack.damage", "attack.cooldown", "attack.count", "attack.spread_degrees", "ability.rapid_seconds", "ability.pierce", "ability.burn_dps", "ability.burn_seconds", "ability.cooldown", "armour", "getup_time", "pickup_radius"]
	var all := []
	for id in _nodes():
		all.append(id)
		for effect in _nodes()[id].get("effects", []):
			var stat := str(effect["stat"])
			var understood: bool = stat in known or (stat.begins_with("tower.") and stat.substr(6) in known_tower) or (stat.begins_with("hero.") and stat.substr(5) in known_hero)
			expect_true(understood, id + " uses " + stat)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", all), SimRng.new(1))
	expect_eq(rules.setup_error, "")
	# Hand-worked totals: keep 100 + (25+50+75+100+150) = 500; beam 420 + 100; gold x1.25*1.3*1.2*1.15*1.1*1.1.
	expect_eq(rules.keep_health_max, 500)
	expect_eq(rules.spawn_radius, 520.0)
	expect_near(rules.gold_multiplier, 1.25 * 1.3 * 1.2 * 1.15 * 1.1 * 1.1, 0.0001)
	expect_eq(rules.tower.repair, 3.0)


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
	far.hero_position = Vector2(1200, 0)  # beyond the 960 half-width of the arena
	_knock_down(far)
	_run(far, 91)
	expect_eq(far.hero_position, Vector2(960, 0), "pulled back inside the arena")


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
	var upgrades := ["keep_beam_1", "post_drills", "post_mend", "post_timbers", "keep_walls_1", "tithe_1"]
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


func test_the_app_opens_on_the_home_screen_and_new_game_leads_to_the_journey_map() -> void:
	var main := _main()
	expect_true(main.home.visible and not main.journey.visible)
	expect_true(main.home.get_node("%ContinueButton").disabled, "nothing to continue yet")
	main.home.get_node("%NewGameButton").pressed.emit()
	expect_true(main.journey.visible and not main.home.visible)
	main.journey.get_node("%BackButton").pressed.emit()
	expect_true(main.home.visible, "Main menu returns home")
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
	expect_true(main.journey.visible, "Continue goes to the journey map")
	expect_eq(profile.get_gold(), 400, "and keeps the progress")
	main.journey.get_node("%BackButton").pressed.emit()
	home.get_node("%NewGameButton").pressed.emit()
	home.get_node("%NewGameButton").pressed.emit()
	expect_true(main.journey.visible, "the second click starts over")
	expect_eq(profile.get_gold(), 0)
	main.free()


func test_the_keep_screen_buys_through_the_flow_and_the_profile_saves() -> void:
	var path := _save_path("keep_buy")
	var main := _main(path)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.bank_run({"gold": 200, "outcome": "lost", "level": "outpost"})
	var keep: Control = main.keep_screen
	keep.visible = true
	var drills: Button = keep._node_buttons["post_drills"]
	var walls: Button = keep._node_buttons["keep_walls_1"]
	expect_true(drills.disabled == false and walls.disabled == false, "both affordable (110, 60)")
	expect_true(keep._node_buttons["post_twin"].disabled, "needs the first drill")
	walls.pressed.emit()
	expect_eq(profile.get_gold(), 140)
	expect_true(walls.disabled and walls.text.contains("bought"))
	expect_eq(keep.get_node("%GoldValue").text, "140")
	drills.pressed.emit()
	expect_eq(profile.get_gold(), 30)
	expect_true(keep._node_buttons["post_twin"].disabled, "600 is out of reach")
	main.free()
	var reloaded: Dictionary = SaveService.new(path, HoldfastMeta.SAVE_VERSION).load_save()["data"]
	expect_eq(reloaded["gold"], 30)
	expect_eq(reloaded["upgrades"], ["castle_slot_1", "castle_archer_1", "keep_walls_1", "post_drills"])


func test_level_and_pillar_picks_start_the_next_run_with_the_bought_upgrades() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.bank_run({"gold": 500, "outcome": "lost", "level": "outpost"})
	var keep: Control = main.keep_screen
	var map: Control = main.journey
	keep.visible = true
	expect_true(map._buttons["shingle_beach"].disabled, "locked until the first level is won")
	expect_true(map._level_text("shingle_beach").contains("Win the previous level"), "and it says why")
	profile.bank_run({"gold": 0, "outcome": "won", "level": "outpost"})
	keep._node_buttons["keep_beam_1"].pressed.emit()             # 200
	keep._node_buttons["post_timbers"].pressed.emit()            # 70
	expect_false(map._buttons["shingle_beach"].disabled, "open now")
	main.hero_page.select_pillar("dusk_mage")
	main.hero_page.select_pillar("not_a_pillar")
	expect_eq(main.hero_page.selected_pillar, "dusk_mage", "an unknown pillar changes nothing")
	map._buttons["shingle_beach"].pressed.emit()
	expect_eq(profile.get_level(), "shingle_beach")
	main.planning.auto_place()
	main.planning.get_node("%StartButton").pressed.emit()
	var source: HoldfastRunSource = main.get_node("RunSource")
	var rules := source.get_rules()
	expect_eq(rules.level_id, "shingle_beach")
	expect_eq(rules.hero_path_id, "dusk_mage")
	expect_eq(rules.spawn_radius, 440.0 + 30.0, "the beam node applies")
	expect_eq(rules.tower.health["max_health"], 90.0, "and the tower timbers")
	main.free()


func test_a_finished_run_banks_its_gold_and_the_summary_returns_to_the_journey_map() -> void:
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
	expect_eq(profile.get_gold(), int(result["gold"]) + 150, "the run's gold and Level 0's reward are in the bank")
	expect_eq(int(profile.data["runs"]), 1)
	expect_true(main.summary.visible)
	main.summary.get_node("%MapButton").pressed.emit()
	expect_true(main.journey.visible and not main.summary.visible)
	expect_eq(main.journey.get_node("%GoldValue").text, Hud.format_number(int(result["gold"]) + 150), "and the map shows it")
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
