extends KitTestCase
## HF-M2-67: a second biome is data only. A throwaway stub (a level, a boss and the Hero path its boss
## opens) is added as one more file to a copy of the base pack, loads, plays in the simulator and opens
## what it should, with no change to the code. The bands gate refuses a level with no band entry, and a
## pillar's scope widens to the new level by editing the bands file alone.
##
## Code changes this needed (the only ones, all in HoldfastBands): levels, scope and scope_problems take the
## pack to read (the base pack when none is given); scope_problems reports a level with no band entry (it
## used to be a missing-key crash in the sweep); and the sweep climbs every level of the pack, not a
## hard-coded five.

const PACK_DIR := "user://second_biome_pack"
const STUB_LEVEL := "stub_reef"
const STUB_BOSS := "stub_boss"
const STUB_FILE := "stub_biome.json"


## Plain data copied from the base pack, so editing the copy never touches the real content.
func _copy(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


## The stub biome as a pack file: a boss and a level that sends it, a copy of the last level with the
## last biome's boss replaced.
func _stub_file(base: Dictionary) -> Dictionary:
	var boss: Dictionary = _copy(base["enemies"]["fog_warden"])
	boss["id"] = STUB_BOSS
	boss["name"] = "Stub Boss"
	var level: Dictionary = _copy(base["levels"]["gull_rock"])
	level["id"] = STUB_LEVEL
	level["name"] = "Stub Reef"
	level["number"] = int(level["number"]) + 1
	for wave in level["waves"]:
		for spawn in wave["spawns"]:
			if spawn["enemy"] == "fog_warden":
				spawn["enemy"] = STUB_BOSS
	return {"enemies": [boss], "levels": [level]}


## Copies the base pack to a scratch folder with the stub file listed last, and loads it.
func _stub_pack() -> PackLoader.Pack:
	var base := HoldfastContent.base()
	DirAccess.make_dir_recursive_absolute(PACK_DIR)
	var dir := DirAccess.open(PACK_DIR)
	for file in dir.get_files():
		dir.remove(file)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HoldfastContent.BASE_PACK.path_join("pack.json")))
	for file in manifest["files"]:
		_copy_file(HoldfastContent.BASE_PACK.path_join(file), PACK_DIR.path_join(file))
	manifest["files"].append(STUB_FILE)
	_write(PACK_DIR.path_join("pack.json"), manifest)
	_write(PACK_DIR.path_join(STUB_FILE), _stub_file(base))
	return PackLoader.load_pack(PACK_DIR, HoldfastContent.SCHEMA)


func _copy_file(from: String, to: String) -> void:
	var handle := FileAccess.open(to, FileAccess.WRITE)
	handle.store_string(FileAccess.get_file_as_string(from))


func _write(path: String, data: Dictionary) -> void:
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(JSON.stringify(data, "  "))


## The stub pack's content, with the Tideblade opening at the stub boss (a data edit).
func _content() -> Dictionary:
	var pack := _stub_pack()
	expect_eq(pack.errors, PackedStringArray(), "the stub pack loads with no error")
	var content := pack.content
	content["hero_paths"]["tideblade"]["opens"] = {"after": STUB_LEVEL}
	return content


# ------------------------------------------------------------------ the stub loads and plays

func test_the_stub_biome_loads_as_one_more_pack_file_after_the_last_level() -> void:
	var content := _content()
	var ids: Array = content["levels"].keys()
	expect_eq(ids[-1], STUB_LEVEL, "the stub level comes last")
	expect_eq(ids[-2], "gull_rock", "after the current last level")
	expect_true(HoldfastProgression.has_boss(content, STUB_LEVEL), "and sends a boss")
	expect_eq(content["enemies"][STUB_BOSS]["tier"], "boss", "a boss-tier one of its own")
	expect_eq(HoldfastBands.levels(content).size(), HoldfastBands.levels().size() + 1, "the gate sees one level more")


func test_the_stub_level_plays_in_the_simulator() -> void:
	var content := _content()
	var config := HoldfastContent.run_config(STUB_LEVEL, [], content, "flare_archer", null, {}, [], false, RecruitMeta.bot_squad(content, HoldfastMeta.new_profile(content)))
	var report: Dictionary = SimBotRunner.run(HoldfastRules.new(), HoldfastSkilledBot.new(HoldfastSkilledBot.AVERAGE), 7, config, HoldfastCurve.MAX_TICKS, HoldfastRules.TICK_RATE)
	expect_true(report["finished"], "the run reached an end")
	expect_true(report["result"]["outcome"] in [HoldfastRules.OUTCOME_WON, HoldfastRules.OUTCOME_LOST], "with a result: %s" % str(report["result"]["outcome"]))
	expect_true(report["seconds"] > 30.0, "and it was played, not skipped (%.0f s)" % report["seconds"])


func test_winning_the_last_old_level_opens_the_stub_and_winning_the_stub_opens_the_tideblade() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	expect_false(STUB_LEVEL in HoldfastMeta.unlocked_levels(content, profile), "closed at the start")
	expect_false(HoldfastMeta.path_open(content, profile, "tideblade"), "and so is the Tideblade")
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": "gull_rock", "gold": 0, "keep_left": 0.6})
	expect_true(STUB_LEVEL in HoldfastMeta.unlocked_levels(content, profile), "winning Gull Rock opens the stub")
	expect_false(HoldfastMeta.path_open(content, profile, "tideblade"), "the Tideblade still waits for its boss")
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": STUB_LEVEL, "gold": 0, "keep_left": 0.6})
	expect_true(HoldfastMeta.path_open(content, profile, "tideblade"), "winning the stub opens the Tideblade")


# ------------------------------------------------------------------ the bands gate

func test_the_bands_gate_fails_on_a_biome_with_no_band_entry() -> void:
	var content := _content()
	var bands := HoldfastBands.load_bands()
	expect_eq(HoldfastBands.scope_problems(bands), PackedStringArray(), "the real pack is sound")
	var problems := HoldfastBands.scope_problems(bands, content)
	expect_true(problems.size() >= 1, "the new level fails the gate")
	expect_true(" ".join(problems).contains(STUB_LEVEL + " has no band entry"), "naming the level: %s" % " | ".join(problems))
	expect_true(" ".join(problems).contains("no `hard` band entry"), "and its missing Hard band")


func test_a_data_edit_gives_the_new_level_its_bands_and_widens_a_pillars_scope_to_it() -> void:
	var content := _content()
	var bands := HoldfastBands.load_bands()
	expect_false(STUB_LEVEL in HoldfastBands.scope(bands, "dusk_mage", content), "the Dusk Mage is not judged on the stub yet")
	var edited := bands.duplicate(true)
	edited["bands"][STUB_LEVEL] = {"average": [0.3, 0.6], "poor_min": 0.1}
	edited["hard"][STUB_LEVEL] = {"average": [0.2, 0.5]}
	edited["pillar_levels"]["dusk_mage"] = ["gull_rock", STUB_LEVEL]
	edited["pillar_levels"]["tideblade"] = [STUB_LEVEL]
	expect_eq(HoldfastBands.scope_problems(edited, content), PackedStringArray(), "with bands and a scope, the gate is satisfied")
	expect_eq(HoldfastBands.scope(edited, "dusk_mage", content), ["gull_rock", STUB_LEVEL], "the Dusk Mage's scope widened by data alone")
	expect_eq(HoldfastBands.scope(edited, "tideblade", content), [STUB_LEVEL], "and the Tideblade's moved to the new biome")
	expect_true(STUB_LEVEL in HoldfastBands.scope(edited, "flare_archer", content), "a pillar with no entry is judged on every level, the new one too")
