extends KitTestCase
## HF-M2-62: a save that has been edited by hand, or damaged in a way its checksum cannot see (the
## checksum is recomputed whenever the game saves), loads without a script error and falls back to
## safe values field by field. Every top-level field and the nested ones are replaced with each kind
## of wrong value and loaded through the real path: SaveService writes the file, HoldfastProfile
## reads it. The loaded profile must then pass `_check`, which is what the rest of the game relies on.

const DIR := "user://save_integrity"
## Wrong values: nothing, text, a flag, a negative, a fraction, a huge number, and empty and
## mixed-up lists and dictionaries.
const BAD: Array = [null, "x", true, -7, 3.5, 1.0e30, -1.0e30, [], [null, 1, "x", {}, [1]], {}, {"a": null, "b": [1]}]


func _content() -> Dictionary:
	return HoldfastContent.base()


## A save with something in every field, as the game writes it today.
func _good() -> Dictionary:
	var content := _content()
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	profile["gold"] = 500
	profile["runs"] = 3
	profile["gear"]["owned"] = ["worn_cloak"] if content["gear_items"].has("worn_cloak") else [content["gear_items"].keys()[0]]
	profile["recruits"]["roster"] = [RecruitRoster.new_recruit("bryn", "Bryn", "warden"), RecruitRoster.new_recruit("wren", "Wren", "lookout")]
	profile["recruits"]["squad"] = ["bryn"]
	profile["recruits"]["posted"] = {"spot_1": "bryn"}
	profile["names"] = {"keep": "Gull Light", "hero": "Ada"}
	return profile


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var base := DIR.path_join(name)
	for suffix in [".sav", ".sav.bak", ".sav.tmp"]:
		DirAccess.remove_absolute(base + suffix)
	return base + ".sav"


## Writes `data` as a save of `version` and reads it back the way the game does.
func _load(data: Dictionary, name := "case", version := HoldfastMeta.SAVE_VERSION) -> Dictionary:
	var path := _path(name)
	expect_true(SaveService.new(path, version).save(data), "the test save is written")
	var profile := HoldfastProfile.new()
	profile.save_path = path
	profile.load_profile()
	var loaded: Dictionary = profile.data
	profile.free()
	return loaded


## What the rest of the game relies on in a loaded profile.
func _check(data: Dictionary, why: String) -> void:
	var content := _content()
	var shape := HoldfastMeta.new_profile(content)
	expect_eq(data.keys(), shape.keys(), why + ": every field is there")
	expect_true(data["gold"] is int and data["gold"] >= 0, why + ": gold is a whole number from 0 (%s)" % [data["gold"]])
	expect_true(data["runs"] is int and data["runs"] >= 0, why + ": runs")
	for id in data["upgrades"]:
		expect_true(id is String and content["upgrade_nodes"].has(id), why + ": upgrade %s is known" % [id])
	expect_eq(data["upgrades"].size(), _unique(data["upgrades"]).size(), why + ": no upgrade twice")
	for level in data["stars"]:
		expect_true(content["levels"].has(level) and data["stars"][level] is int and data["stars"][level] >= 0 and data["stars"][level] <= HoldfastMeta.MAX_LEVEL_STARS, why + ": stars for %s" % [level])
	var ids: Array = content["levels"].keys()
	for list in ["levels_won", "unlocked"]:
		for id in data[list]:
			expect_true(id is String and content["levels"].has(id), why + ": %s holds a known level (%s)" % [list, id])
	for id in data["unlocked"]:
		var at := ids.find(id)
		expect_true(at <= 0 or ids[at - 1] in HoldfastMeta.unlocked_levels(content, data) or ids[at - 1] in data["levels_won"], why + ": %s is not opened out of turn" % id)
	expect_true(data["level"] in HoldfastMeta.unlocked_levels(content, data), why + ": the level is open")
	expect_true(content["hero_paths"].has(data["pillar"]), why + ": the pillar is known")
	expect_true(data["layouts"] is Dictionary, why + ": layouts")
	for level in data["layouts"]:
		expect_true(content["levels"].has(level), why + ": a layout for a known level")
	for id in data["gear"]["owned"]:
		expect_true(content["gear_items"].has(id), why + ": gear %s is known" % [id])
	for slot in data["gear"]["equipped"]:
		var worn: Variant = data["gear"]["equipped"][slot]
		expect_true(worn is String and (worn == "" or worn in data["gear"]["owned"]), why + ": what is worn is owned")
	for id in data["gear_seen"]:
		expect_true(id in data["gear"]["owned"], why + ": gear seen is owned")
	for flag in ["stand_done", "stars_line_seen"]:
		expect_true(data[flag] is bool, why + ": " + flag)
	var recruits: Dictionary = data["recruits"]
	var roster := []
	for recruit in recruits["roster"]:
		expect_true(recruit is Dictionary and recruit["id"] is String and not RecruitRoster.build(recruit, content, {}).is_empty(), why + ": a Recruit on the roster can be built")
		roster.append(recruit["id"])
	for id in recruits["squad"]:
		expect_true(id in roster, why + ": the squad is on the roster")
	expect_true(recruits["squad"].size() <= RecruitMeta.slots(content, data), why + ": the squad fits its places")
	for key in ["round", "next", "bought"]:
		expect_true(recruits[key] is int and recruits[key] >= 0, why + ": recruits." + key)
	for index in recruits["hired"]:
		expect_true(index is int, why + ": hired")
	for site in RecruitMeta.posted(data):
		expect_true(RecruitMeta.posted(data)[site] in recruits["squad"], why + ": a posted Recruit is on the squad")
	for who in ["keep", "hero"]:
		expect_true(data["names"][who] is String, why + ": the name of " + who)


func _unique(list: Array) -> Array:
	var out := []
	for item in list:
		if not item in out:
			out.append(item)
	return out


# ------------------------------------------------------------------ every field, every wrong value

## The fields to break: a path into the save, as keys.
const PATHS: Array = [
	["gold"], ["runs"], ["upgrades"], ["stars"], ["stars", "outpost"], ["levels_won"], ["unlocked"], ["level"], ["pillar"],
	["layouts"], ["layouts", "outpost"], ["gear"], ["gear", "owned"], ["gear", "equipped"], ["gear_seen"], ["stand_done"], ["stars_line_seen"],
	["recruits"], ["recruits", "roster"], ["recruits", "squad"], ["recruits", "round"], ["recruits", "hired"], ["recruits", "next"],
	["recruits", "bought"], ["recruits", "posted"], ["recruits", "welcome"], ["names"], ["names", "keep"], ["names", "hero"],
]


func _with(path: Array, value: Variant) -> Dictionary:
	var data := _good().duplicate(true)
	var node: Dictionary = data
	for i in path.size() - 1:
		if not node.get(path[i]) is Dictionary:
			node[path[i]] = {}
		node = node[path[i]]
	node[path[-1]] = value
	return data


func test_a_wrong_value_in_any_field_loads_to_safe_values() -> void:
	for path in PATHS:
		for bad in BAD:
			_check(_load(_with(path, bad)), "%s = %s" % ["/".join(PackedStringArray(path)), JSON.stringify(bad)])


func test_a_missing_field_loads_to_safe_values() -> void:
	for path in PATHS:
		var data := _good().duplicate(true)
		var node: Dictionary = data
		for i in path.size() - 1:
			node = node.get(path[i], {}) if node.get(path[i]) is Dictionary else {}
		node.erase(path[-1])
		_check(_load(data), "%s missing" % "/".join(PackedStringArray(path)))


func test_wrong_values_inside_the_lists_are_dropped_one_by_one() -> void:
	var data := _good()
	data["upgrades"] = [null, 5, ["castle_slot_1"], "castle_slot_1", {"id": 1}, "castle_archer_1", "no_such_node"]
	data["levels_won"] = [null, ["x"], HoldfastMeta.tutorial_level(_content()), 7]
	data["gear"]["owned"] = [null, 3, "no_such_item", _good()["gear"]["owned"][0]]
	var profile := _load(data)
	_check(profile, "mixed lists")
	expect_eq(profile["upgrades"], ["castle_slot_1", "castle_archer_1"], "the good ones stay, in order")
	expect_eq(profile["levels_won"], [HoldfastMeta.tutorial_level(_content())])
	expect_eq(profile["gear"]["owned"], [_good()["gear"]["owned"][0]])


func test_a_good_save_loads_unchanged() -> void:
	var good := _good()
	var profile := _load(good)
	_check(profile, "good")
	for key in ["gold", "runs", "upgrades", "stars", "levels_won", "unlocked", "gear", "names"]:
		expect_eq(profile[key], good[key], key)
	expect_eq(profile["recruits"]["squad"], ["bryn"])
	expect_eq(RecruitMeta.posted(profile), {"spot_1": "bryn"})


# ------------------------------------------------------------------ a level cannot be opened out of turn

func test_a_hand_edited_unlocked_list_cannot_open_a_later_level_alone() -> void:
	var content := _content()
	var ids: Array = content["levels"].keys()
	var last: String = ids[-1]
	for data in [{"unlocked": [last]}, {"unlocked": [last], "level": last}, {"unlocked": [ids[3], ids[4]], "level": ids[4]}]:
		var save := HoldfastMeta.new_profile(content)
		save.merge(data, true)
		var profile := _load(save)
		_check(profile, "unlocked %s" % [data["unlocked"]])
		expect_false(last in HoldfastMeta.unlocked_levels(content, profile), "%s stays shut" % last)
		expect_eq(profile["level"], ids[0], "and the level falls back to the first")


func test_a_real_run_of_unlocks_is_kept() -> void:
	var content := _content()
	var ids: Array = content["levels"].keys()
	var save := HoldfastMeta.new_profile(content)
	save["levels_won"] = ids.slice(0, 3)
	save["unlocked"] = ids.slice(1, 4)
	var profile := _load(save)
	expect_eq(profile["levels_won"], ids.slice(0, 3))
	expect_eq(profile["unlocked"], ids.slice(1, 4))


# ------------------------------------------------------------------ old saves with wrong values go through their migrations

func _old(version: int) -> Dictionary:
	var content := _content()
	return {"gold": 90, "upgrades": ["castle_slot_1"], "levels_won": [HoldfastMeta.tutorial_level(content)], "unlocked": [], "level": "outpost", "pillar": "flare_archer", "runs": 2}


func test_old_saves_with_wrong_values_migrate_without_an_error() -> void:
	for version in range(1, HoldfastMeta.SAVE_VERSION):
		for field in ["gold", "upgrades", "levels_won", "unlocked", "stars", "layouts", "runs"]:
			for bad in BAD:
				var data := _old(version)
				data[field] = bad
				_check(_load(data, "old", version), "v%d %s = %s" % [version, field, JSON.stringify(bad)])


# ------------------------------------------------------------------ Recruit fields, and numbers too big to be true

func test_a_wrong_value_in_a_recruit_field_leaves_a_whole_recruit_or_none() -> void:
	for field in ["id", "name", "class", "traits", "xp", "skills", "extra"]:
		for bad in BAD:
			var data := _good()
			data["recruits"]["roster"][0][field] = bad
			var profile := _load(data)
			_check(profile, "recruit %s = %s" % [field, JSON.stringify(bad)])
	var data := _good()
	data["recruits"]["roster"][0]["traits"] = ["no_such_trait", null, 5]
	data["recruits"]["roster"][0]["skills"] = ["no_such_skill", [1]]
	var profile := _load(data)
	expect_eq(profile["recruits"]["roster"][0]["traits"], [])
	expect_eq(profile["recruits"]["roster"][0]["skills"], [])


func test_huge_numbers_are_capped_not_believed() -> void:
	var data := _good()
	data["gold"] = 9.0e18
	data["runs"] = 9.0e18
	data["recruits"]["roster"][0]["xp"] = 9.0e18
	data["recruits"]["round"] = 9.0e18
	data["recruits"]["next"] = 9.0e18
	data["recruits"]["bought"] = 9.0e18
	var started := Time.get_ticks_msec()
	var profile := _load(data)
	_check(profile, "huge")
	expect_eq(profile["gold"], int(HoldfastMeta.WHOLE_LIMIT))
	expect_eq(profile["runs"], int(HoldfastMeta.WHOLE_LIMIT))
	expect_eq(profile["recruits"]["roster"][0]["xp"], RecruitRoster.XP_MAX)
	expect_true(RecruitRoster.level_of(profile["recruits"]["roster"][0], _content()) < 5000, "a level can be worked out at once")
	expect_true(Time.get_ticks_msec() - started < 2000, "and the load does not stall")


func test_a_level_whose_predecessor_was_won_is_open_as_winning_makes_it() -> void:
	var content := _content()
	var ids: Array = content["levels"].keys()
	var save := HoldfastMeta.new_profile(content)
	save["levels_won"] = [ids[3]]
	save["unlocked"] = [ids[4]]
	var profile := _load(save)
	_check(profile, "won then opened")
	expect_eq(profile["unlocked"], [ids[4]], "a win opens the next level")
	expect_false(ids[5] in HoldfastMeta.unlocked_levels(content, profile), "and only that one")
