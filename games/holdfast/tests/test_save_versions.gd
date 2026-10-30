extends KitTestCase
## HF-M2-62: an older save loads. tests/fixtures/saves/ holds one file saved at each save version, as
## that version's SaveService wrote it; each is loaded through the real path (HoldfastProfile reads the
## file and migrates it step by step) and must come out as the current profile, keeping what the player
## earned. A new SAVE_VERSION without its migration and its fixture fails here.

const FIXTURES := "res://tests/fixtures/saves"
const DIR := "user://save_versions"


func _content() -> Dictionary:
	return HoldfastContent.base()


## Loads the fixture saved at `version`: {status, data}, the data as the profile holds it.
func _load(version: int) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join("v%d.sav" % version)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	var source := "%s/v%d.sav" % [FIXTURES, version]
	expect_true(FileAccess.file_exists(source), "tests/fixtures/saves/v%d.sav is committed" % version)
	var text := FileAccess.get_file_as_string(source)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var profile := HoldfastProfile.new()
	profile.save_path = path
	profile.load_profile()
	var out := {"status": profile.load_status, "data": profile.data}
	profile.free()
	return out


func test_every_save_version_has_a_step_to_the_next_and_a_file_that_loads() -> void:
	var steps: Dictionary = HoldfastMeta.migrations(_content())
	for version in range(1, HoldfastMeta.SAVE_VERSION):
		expect_true(steps.has(version), "a step from version %d" % version)
	expect_eq(steps.size(), HoldfastMeta.SAVE_VERSION - 1, "and no others")
	for version in range(1, HoldfastMeta.SAVE_VERSION + 1):
		var loaded := _load(version)
		expect_eq(loaded["status"], "ok" if version == HoldfastMeta.SAVE_VERSION else "migrated", "version %d" % version)
		_whole(loaded["data"], "version %d" % version)


## What any loaded profile has to be.
func _whole(data: Dictionary, why: String) -> void:
	var content := _content()
	expect_eq(data.keys(), HoldfastMeta.new_profile(content).keys(), why + ": every field")
	for id in data["upgrades"]:
		expect_true(content["upgrade_nodes"].has(id), why + ": %s is a node" % id)
	expect_true(data["level"] in HoldfastMeta.unlocked_levels(content, data), why + ": the level is open")
	expect_true(data["gold"] >= 0 and data["runs"] >= 0, why)


func test_version_1_keeps_its_level_unlocks_and_every_refund() -> void:
	var data: Dictionary = _load(1)["data"]
	# 300 held, the four level nodes' and the tower nodes' prices back, and Stone walls I at its price.
	expect_eq(data["gold"], 300 + 120 + 500 + 110 + 70 + 60)
	expect_eq(data["upgrades"], [], "the tree is bought again from the first slot")
	expect_eq(data["levels_won"], ["outpost", "shingle_beach", "first_watch"], "the won levels stay and the tutorial counts as won")
	expect_eq(data["unlocked"], ["outpost", "shingle_beach", "tidewrack_cove"])
	expect_eq(data["stars"], {"first_watch": 2, "outpost": 3, "shingle_beach": 3})
	expect_eq(data["level"], "outpost")
	expect_eq(data["runs"], 6)


func test_version_2_gets_the_old_tower_nodes_and_the_rest_back_in_gold() -> void:
	var data: Dictionary = _load(2)["data"]
	expect_eq(data["gold"], 200 + 450 + 60)
	expect_eq(data["upgrades"], [])
	expect_eq(data["level"], "shingle_beach")
	expect_eq(data["layouts"], {}, "the layouts are reset with the castle")
	expect_eq(data["runs"], 9)


func test_version_3_keeps_its_gear_and_gets_its_nodes_back_in_gold() -> void:
	var data: Dictionary = _load(3)["data"]
	expect_eq(data["gold"], 50 + 90 + 160)
	expect_eq(data["upgrades"], [])
	expect_eq(data["gear"]["owned"], ["gull_feather_fletching"])
	expect_eq(data["gear"]["equipped"]["weapon"], "gull_feather_fletching", "and still wears it")
	expect_eq(data["level"], "tidewrack_cove")


func test_version_4_keeps_its_stars_and_gets_its_nodes_back_in_gold() -> void:
	var data: Dictionary = _load(4)["data"]
	expect_eq(data["gold"], 120 + 160 + 60, "the star nodes cost no gold to give back")
	expect_eq(data["upgrades"], [])
	expect_eq(data["stars"], {"first_watch": 2, "outpost": 3})
	expect_eq(data["runs"], 20)


func test_version_5_loads_as_it_is_and_gets_its_recruits_once() -> void:
	var data: Dictionary = _load(5)["data"]
	expect_eq(data["gold"], 640)
	expect_eq(data["upgrades"], ["castle_slot_1", "castle_archer_1", "post_rate", "keep_walls_1"])
	expect_eq(data["layouts"], {"outpost": ["spot_1"]})
	expect_eq(data["levels_won"], ["first_watch", "outpost", "shingle_beach"])
	expect_true(data["stand_done"] and data["stars_line_seen"])
	expect_true(data["recruits"]["roster"].size() >= 1, "a save from before Recruits that won the rescue levels gets them")
