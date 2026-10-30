extends KitTestCase
## HF-M2-58: one stat model. Hero, towers, Recruits, gear, blessings and tree nodes all change the
## same named stats in one place (`StatModel`), each stat read as (base + every add) x every multiply.
## This lists every stat the packs change and what changes it, and holds the packs to the model.


func _content() -> Dictionary:
	return HoldfastContent.base()


## {stat as the model names it: [sources that change it in the packs]}. A stat is named as the pack
## writes it, so a tower or Hero stat is the pack's `tower.x` or `hero.x`.
func _sources() -> Dictionary:
	var content := _content()
	var out := {}
	var add := func(stat: String, source: String) -> void:
		var list: Array = out.get(stat, [])
		if not source in list:
			list.append(source)
		out[stat] = list
	for node in content["upgrade_nodes"].values():
		for effect in node.get("effects", []):
			add.call(str(effect["stat"]), StatModel.TREE)
	for item in content["gear_items"].values():
		for effect in item.get("effects", []):
			add.call(str(effect["stat"]), StatModel.GEAR)
	for blessing in content["blessings"].values():
		for effect in blessing.get("effects", []):
			add.call(str(effect["stat"]), StatModel.BLESSING)
	for entry in content["recruit_traits"].values():
		for effect in entry.get("effects", []):
			add.call(str(effect["stat"]), StatModel.TRAIT)
	for entry in content["recruit_skills"].values():
		for effect in entry.get("effects", []):
			add.call(str(effect["stat"]), StatModel.SKILL)
	return out


func test_every_stat_a_pack_changes_is_in_the_model_from_a_source_the_model_allows() -> void:
	var sources := _sources()
	expect_true(sources.size() > 40, "the packs change many stats (%d)" % sources.size())
	for stat in sources:
		var allowed := StatModel.allowed_sources(str(stat))
		expect_false(allowed.is_empty(), "%s is a stat the model knows" % stat)
		for source in sources[stat]:
			expect_true(source in allowed, "%s changes %s, which the model lets only %s change" % [source, stat, allowed])


func test_every_effect_is_an_add_or_a_multiply_and_nothing_else() -> void:
	var content := _content()
	var groups := [content["upgrade_nodes"], content["gear_items"], content["blessings"], content["recruit_traits"], content["recruit_skills"]]
	for group in groups:
		for id in group:
			for effect in group[id].get("effects", []):
				var keys: Array = effect.keys()
				keys.erase("stat")
				keys.sort()
				expect_true(keys in [["add"], ["multiply"], ["add", "multiply"]], "%s: an effect is an add or a multiply, got %s" % [id, keys])


func test_blessings_never_change_a_recruit_and_gear_never_changes_a_tower() -> void:
	var sources := _sources()
	for stat in sources:
		if str(stat).begins_with("recruit."):
			expect_false(StatModel.BLESSING in sources[stat], "%s is not changed by a blessing" % stat)
		if str(stat).begins_with("tower."):
			expect_false(StatModel.GEAR in sources[stat], "%s is not changed by gear" % stat)
	expect_eq(StatModel.allowed_sources("recruit.damage"), [StatModel.TREE, StatModel.TRAIT, StatModel.SKILL], "a Recruit's damage comes from the tree, traits and skills")
	expect_eq(StatModel.allowed_sources("recruit.nonsense"), [], "an unknown Recruit stat is refused")
	expect_eq(StatModel.allowed_sources("gold_multiplier"), [StatModel.TREE, StatModel.BLESSING], "gold from the tree and blessings")
	expect_eq(StatModel.allowed_sources("nothing_at_all"), [], "an unknown stat is refused")


func test_a_stat_reads_base_plus_every_add_then_every_multiply() -> void:
	var stats := {}
	StatModel.put(stats, "recruit.health", {"add": 10.0})
	StatModel.put(stats, "recruit.health", {"multiply": 1.25})
	StatModel.put(stats, "recruit.health", {"add": 5.0, "multiply": 2.0})
	expect_near(StatModel.apply(stats, "recruit.health", 40.0), (40.0 + 15.0) * 2.5, 0.0001, "(base + adds) x multiplies")
	expect_near(StatModel.multiplier(stats, "recruit.health"), 2.5, 0.0001, "the multiplies on their own")
	expect_near(StatModel.apply(stats, "recruit.range", 7.0), 7.0, 0.0001, "an untouched stat is its base")
	var other := {}
	StatModel.put(other, "recruit.health", {"add": 5.0})
	var both := StatModel.combine(stats, other)
	expect_near(StatModel.apply(both, "recruit.health", 40.0), (40.0 + 20.0) * 2.5, 0.0001, "combined tables add and multiply together")
	expect_near(StatModel.apply(stats, "recruit.health", 40.0), 137.5, 0.0001, "and the first table is left alone")


func test_tower_and_hero_stats_are_scoped_to_the_node_they_belong_to() -> void:
	expect_eq(StatModel.scoped({"tower": "archer_post"}, "tower.damage"), "tower.archer_post.damage", "a tower node's stat")
	expect_eq(StatModel.scoped({"hero": "flare_archer"}, "hero.attack.damage"), "hero.flare_archer.attack.damage", "a Hero node's stat")
	expect_eq(StatModel.scoped({"hero": "flare_archer"}, "keep_health"), "keep_health", "a global stat stays global")
	expect_eq(StatModel.scoped({}, "recruit.health"), "recruit.health", "a Recruit stat is for every Recruit")
	expect_eq(StatModel.under({"recruit.health": 1, "keep_health": 2}, "recruit."), {"health": 1}, "a prefix is cut off")


func test_a_tree_node_changes_the_recruits_the_run_builds() -> void:
	var content: Dictionary = _content().duplicate(true)
	content["upgrade_nodes"]["test_barracks"] = {"id": "test_barracks", "effects": [{"stat": "recruit.health", "multiply": 1.25}, {"stat": "recruit.damage", "multiply": 1.25}]}
	var recruit := RecruitRoster.new_recruit("t1", "Test", "warden", [])
	var tree := StatModel.sum(content["upgrade_nodes"], ["test_barracks"])
	var plain := RecruitRoster.build(recruit, content)
	var housed := RecruitRoster.build(recruit, content, tree)
	expect_near(float(housed["health"]), float(plain["health"]) * 1.25, 0.0001, "Barracks: a quarter more health")
	expect_near(float(housed["damage"]), float(plain["damage"]) * 1.25, 0.0001, "Drills: a quarter more damage")
	expect_near(float(housed["damage_per_level"]), float(plain["damage_per_level"]) * 1.25, 0.0001, "and a quarter more damage a level")
	expect_eq(housed["range"], plain["range"], "nothing else moves")


func test_nothing_outside_the_model_multiplies_a_stat() -> void:
	# The one place that reads a pack effect's add and multiply is StatModel; a second path would be a
	# hidden multiplier. The UI's text lines only print the numbers.
	var allowed := ["res://scripts/rules/stat_model.gd", "res://scripts/ui/keep_screen.gd"]
	var found := []
	var dirs := ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var path := dir.path_join(file)
				if FileAccess.get_file_as_string(path).contains('["multiply"]') and not path in allowed:
					found.append(path)
	expect_eq(found, [], "files that read an effect's multiply themselves")
