extends KitTestCase
## Build 6 (HF-M2-16): two new monster types, Hero-only gear, an elite that always drops
## gear on levels 2 and 3, and a level 5 boss that only the Hero's ability can hurt.
## Expected numbers are worked by hand from the pack values noted beside them.

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://build6_tests"
const DT := 1.0 / HoldfastRules.TICK_RATE
const SCHEMA := HoldfastContent.SCHEMA
const PILLARS := ["flare_archer", "dusk_mage", "tideblade"]
const ITEMS := ["gull_feather_fletching", "tarred_bowstring", "driftwood_stave", "storm_cap", "beacon_visor", "sea_glass_charm", "oilskin_vest", "barnacle_plate", "wave_worn_boots", "kelp_sandals", "lamp_oil_flask", "tide_band"]
## The pieces elites and bosses drop: every piece a level does not hand out for a first win.
const DROPS := ["tarred_bowstring", "driftwood_stave", "beacon_visor", "sea_glass_charm", "barnacle_plate", "kelp_sandals", "lamp_oil_flask"]


# ------------------------------------------------------------------ helpers

## Rules on `level` with no wave for 1000 s, no light bonus, and nothing able to hurt an
## enemy but the Hero's own attack and ability (towers and staff do no damage).
func _world(level := "gull_rock", hero := "flare_archer", gear := {}, owned := [], edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"][level]["first_wave_delay"] = 1000.0
	content["levels"][level]["light"]["bonus"] = 0.0
	content["levels"][level]["staff"].erase("post")
	for at in content["levels"][level]["recruits"]:
		at.erase("post")
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config(level, [], content, hero, null, gear, owned), SimRng.new(1))
	return rules


func _enemy(rules: HoldfastRules, type: String, at: Vector2, health := 100.0) -> HoldfastRules.Enemy:
	var data: Dictionary = HoldfastContent.base()["enemies"][type]
	var enemy := HoldfastRules.Enemy.new()
	enemy.type = type
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = float(data["radius"])
	enemy.speed = 0.0
	enemy.tier = str(data.get("tier", "normal"))
	enemy.required_ability = str(data.get("required_ability", ""))
	enemy.exposed_seconds = float(data.get("exposed_seconds", 0.0))
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


## A Hero bot that never uses its ability.
class NoAbilityBot:
	extends HoldfastHeroBot

	func get_input(rules: SimRules, tick: int) -> Dictionary:
		var input := super.get_input(rules, tick)
		input["ability"] = false
		return input


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


# ------------------------------------------------------------------ monsters

func test_the_new_monsters_are_in_the_pack_and_differ_from_the_old_ones() -> void:
	var enemies: Dictionary = HoldfastContent.base()["enemies"]
	expect_true(float(enemies["sprinter"]["speed"]) > float(enemies["runner"]["speed"]), "faster than a runner")
	expect_true(float(enemies["sprinter"]["health"]) <= float(enemies["grunt"]["health"]), "and fragile")
	expect_true(float(enemies["bulwark"]["health"]) > 2.0 * float(enemies["brute"]["health"]), "a bulwark is much heavier than a brute")
	expect_true(float(enemies["bulwark"]["speed"]) < float(enemies["brute"]["speed"]), "and slower")
	for type in ["sprinter", "bulwark"]:
		expect_eq(str(enemies[type].get("tier", "normal")), "normal")


func test_the_new_monsters_come_from_level_two_and_never_on_level_one() -> void:
	var levels: Dictionary = HoldfastContent.base()["levels"]
	for id in levels:
		var seen := {}
		for wave in levels[id]["waves"]:
			for spawn in wave["spawns"]:
				seen[spawn["enemy"]] = int(seen.get(spawn["enemy"], 0)) + int(spawn["count"])
		if id == "outpost" or id == "first_watch":
			for type in ["sprinter", "bulwark", "tide_captain", "fog_warden"]:
				expect_false(seen.has(type), "%s has no %s" % [id, type])
		else:
			expect_true(seen.has("sprinter") and seen.has("bulwark"), "%s has both new monsters" % id)


func test_a_sprinter_walks_faster_than_a_runner_from_the_same_start() -> void:
	var rules := _world()
	var data: Dictionary = HoldfastContent.base()["enemies"]
	var fast := _enemy(rules, "sprinter", Vector2(400, 0), 1000.0)
	fast.speed = float(data["sprinter"]["speed"])
	var slow := _enemy(rules, "runner", Vector2(-400, 0), 1000.0)
	slow.speed = float(data["runner"]["speed"])
	_run(rules, 30)
	expect_true(400.0 - fast.position.length() > 400.0 - slow.position.length() + 40.0, "the sprinter covers more ground in a second")


# ------------------------------------------------------------------ the boss's shroud

func test_a_shrouded_boss_takes_no_damage_from_arrows() -> void:
	var rules := _world()
	var boss := _enemy(rules, "fog_warden", Vector2(0, -60), 500.0)
	_run(rules, 90)
	expect_eq(boss.health, 500.0, "arrows hit and do nothing")
	expect_true(rules.projectiles.size() < 4, "and are spent on it")


func test_the_hero_ability_lifts_the_shroud_for_the_packs_seconds() -> void:
	var rules := _world()
	var boss := _enemy(rules, "fog_warden", Vector2(0, -60), 5000.0)
	_run(rules, 1, {"ability": true})
	expect_near(boss.exposed_left, 6.0, 0.001, "six seconds from the cast (pack: exposed_seconds)")
	_run(rules, 30)
	expect_true(boss.health < 5000.0, "hurt while exposed")
	expect_near(boss.exposed_left, 5.0, 0.001, "and the window runs down")
	_run(rules, 180)
	expect_eq(boss.exposed_left, 0.0, "shrouded again after the window")
	var after := boss.health
	_run(rules, 60)
	expect_eq(boss.health, after, "no damage once the shroud is back, the barrage over")


func test_every_hero_path_lifts_the_shroud_with_its_own_ability() -> void:
	for pillar in PILLARS:
		var rules := _world("gull_rock", pillar)
		var boss := _enemy(rules, "fog_warden", Vector2(0, 20), 5000.0)
		_run(rules, 1, {"ability": true})
		expect_true(boss.exposed_left > 5.0, "%s opens the shroud" % pillar)
		_run(rules, 60)
		expect_true(boss.health < 5000.0, "%s hurts the boss inside the window" % pillar)


func test_burning_and_the_old_aura_cannot_hurt_a_shrouded_boss_either() -> void:
	var rules := _world()
	var boss := _enemy(rules, "fog_warden", Vector2(300, 300), 500.0)
	boss.burn_dps = 50.0
	boss.burn_left = 3.0
	_run(rules, 30)
	expect_eq(boss.health, 500.0, "a burn does nothing to it")
	rules.aura_dps = 100.0
	rules.apply_aura(boss.position, 1.0)
	expect_eq(boss.health, 500.0, "nor does the aura")
	boss.exposed_left = 2.0
	boss.burn_left = 3.0
	_run(rules, 30)
	expect_true(boss.health < 500.0, "but both do once it is exposed")


func test_a_boss_dies_when_its_health_runs_out_and_only_then() -> void:
	var rules := _world()
	var boss := _enemy(rules, "fog_warden", Vector2(0, -60), 3.0)
	_run(rules, 1, {"ability": true})
	_run(rules, 40)
	expect_eq(rules.enemies.size(), 0, "gone once its health is spent")
	expect_eq(rules.kills, 1)
	expect_true(boss.health <= 0.0)


func test_an_ordinary_enemy_is_hurt_whatever_the_ability() -> void:
	var rules := _world()
	var grunt := _enemy(rules, "grunt", Vector2(0, -60), 100.0)
	_run(rules, 30)
	expect_true(grunt.health < 100.0, "no shroud on a grunt")


func test_a_boss_without_an_ability_or_exposure_in_the_pack_is_refused() -> void:
	for bad in [{"required_ability": ""}, {"exposed_seconds": 0.0}]:
		var rules := _world("gull_rock", "flare_archer", {}, [], func(content: Dictionary) -> void:
			content["enemies"]["fog_warden"].merge(bad, true))
		expect_ne(rules.setup_error, "", "refused: %s" % [bad])


func test_the_schema_checks_the_boss_fields() -> void:
	var schema := PackSchema.load_file(SCHEMA)
	var warden: Dictionary = HoldfastContent.base()["enemies"]["fog_warden"].duplicate(true)
	var errors: PackedStringArray = []
	schema.validate_def(warden, "enemy", "enemies.json: $", errors, [])
	expect_true(errors.is_empty(), str(errors))
	for bad in [{"tier": "legend"}, {"exposed_seconds": 0}, {"exposed_seconds": -1}, {"required_ability": "Path Ability"}, {"besieges": "yes"}]:
		var broken := warden.duplicate(true)
		broken.merge(bad, true)
		errors.clear()
		schema.validate_def(broken, "enemy", "enemies.json: $", errors, [])
		expect_false(errors.is_empty(), "rejected: %s" % [bad])


# ------------------------------------------------------------------ elites and the gear they drop

func _kill(rules: HoldfastRules, enemy: HoldfastRules.Enemy) -> void:
	enemy.health = 0.0
	rules._any_dead = true
	_run(rules, 1)


func test_an_elite_on_level_two_always_drops_one_gear_item() -> void:
	for seed_value in 8:
		var rules := _world("shingle_beach")
		rules._rng = SimRng.new(seed_value + 1)
		_kill(rules, _enemy(rules, "tide_captain", Vector2(300, 0)))
		expect_eq(rules.gear_found.size(), 1, "seed %d" % seed_value)
		expect_true(rules.gear_found[0] in DROPS)


func test_an_elite_drops_on_level_three_but_not_on_levels_one_four_or_five() -> void:
	for level in ["outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]:
		var rules := _world(level)
		_kill(rules, _enemy(rules, "tide_captain", Vector2(300, 0)))
		var drops: bool = level in ["shingle_beach", "tidewrack_cove"]
		expect_eq(rules.gear_found.size(), 1 if drops else 0, level)


func test_ordinary_monsters_never_drop_gear() -> void:
	for level in ["shingle_beach", "tidewrack_cove", "gull_rock"]:
		var rules := _world(level)
		for type in ["grunt", "runner", "brute", "sprinter", "bulwark"]:
			_kill(rules, _enemy(rules, type, Vector2(300, 0)))
		expect_eq(rules.gear_found, [], level)


func test_the_boss_drops_gear_on_level_five_only() -> void:
	for level in ["tidewrack_cove", "gull_rock"]:
		var rules := _world(level)
		_kill(rules, _enemy(rules, "fog_warden", Vector2(300, 0)))
		expect_eq(rules.gear_found.size(), 1 if level == "gull_rock" else 0, level)


func test_a_besieging_boss_keeps_hitting_the_keep_and_an_ordinary_enemy_spends_itself() -> void:
	var rules := _world("gull_rock")
	# With no tower or Recruit left to fight, they walk straight to the keep.
	rules._defenders.clear()
	rules._targets_dirty = true
	rules._hero_targetable = false
	var boss := _enemy(rules, "fog_warden", Vector2(60, 0), 1000.0)
	boss.damage = 30
	boss.besieges = true
	boss.hit_interval = 2.0
	boss.hit_in = 0.0
	boss.engage_distance = 0.0
	var grunt := _enemy(rules, "grunt", Vector2(0, 40), 1000.0)
	grunt.damage = 5
	grunt.engage_distance = 0.0
	var before := rules.keep_health
	_run(rules, 1)
	expect_false(grunt in rules.enemies, "the grunt spent itself on one blow")
	expect_eq(rules.keep_health, before - 30 - 5, "both landed their first blow")
	_run(rules, int(2.0 * HoldfastRules.TICK_RATE) + 2)
	expect_true(boss in rules.enemies, "the boss stays at the keep")
	expect_eq(rules.keep_health, before - 30 - 5 - 30, "and hits again after its interval")


func test_gear_drops_read_the_pack_numbers_as_floats() -> void:
	var cfg := {"elite_levels": [2.0, 3.0], "elite_chance": 1.0, "boss_level": 5.0}
	expect_true(HeroGear.drops_gear(3, "elite", 0.5, cfg), "level 3 is an elite level")
	expect_false(HeroGear.drops_gear(4, "elite", 0.5, cfg), "level 4 is not")
	expect_false(HeroGear.drops_gear(3, "elite", 1.0, {"elite_levels": [3.0], "elite_chance": 1.0, "boss_level": 5.0}), "a roll at the chance does not drop")
	expect_true(HeroGear.drops_gear(5, "boss", 0.9, cfg), "the boss drops on its level")
	expect_false(HeroGear.drops_gear(4, "boss", 0.0, cfg), "and not on another")
	expect_false(HeroGear.drops_gear(5, "normal", 0.0, cfg), "ordinary kills never drop")


func test_a_drop_is_an_item_the_player_does_not_own_and_never_a_second_of_the_same() -> void:
	var rules := _world("tidewrack_cove", "flare_archer", {}, DROPS.slice(0, 6))
	_kill(rules, _enemy(rules, "tide_captain", Vector2(300, 0)))
	expect_eq(rules.gear_found, ["lamp_oil_flask"], "the only one left to find")
	_kill(rules, _enemy(rules, "tide_captain", Vector2(300, 0)))
	expect_eq(rules.gear_found, ["lamp_oil_flask"], "and not twice in a run")
	var full := _world("tidewrack_cove", "flare_archer", {}, DROPS)
	_kill(full, _enemy(full, "tide_captain", Vector2(300, 0)))
	expect_eq(full.gear_found, [], "nothing new to find")


func test_the_same_seed_drops_the_same_item() -> void:
	var found := []
	for round in 2:
		var rules := _world("shingle_beach")
		rules._rng = SimRng.new(5)
		_kill(rules, _enemy(rules, "tide_captain", Vector2(300, 0)))
		found.append(rules.gear_found)
	expect_eq(found[0], found[1])


func test_the_drops_cover_the_whole_pool() -> void:
	var seen := {}
	for seed_value in 60:
		var rules := _world("shingle_beach")
		rules._rng = SimRng.new(seed_value + 1)
		_kill(rules, _enemy(rules, "tide_captain", Vector2(300, 0)))
		seen[rules.gear_found[0]] = true
	expect_eq(seen.size(), DROPS.size(), "every dropped item can drop: %s" % [seen.keys()])


func test_the_result_carries_the_gear_found() -> void:
	var rules := _world("shingle_beach")
	_kill(rules, _enemy(rules, "tide_captain", Vector2(300, 0)))
	expect_eq(rules.result()["gear_found"], rules.gear_found)


func test_a_won_run_on_level_two_has_met_its_elite_and_found_gear() -> void:
	var content := HoldfastContent.base()
	var kit := HoldfastProgression.buy_cheapest(content["upgrade_nodes"], [], 500)
	var won := 0
	for seed_value in range(1, 5):
		var report := HoldfastSim.run_headless(seed_value, HoldfastContent.run_config("shingle_beach", kit, content, "flare_archer"))
		if report["result"]["outcome"] == HoldfastRules.OUTCOME_WON:
			won += 1
			# The elite's drop, and the level's own piece for a first win.
			expect_eq(report["result"]["gear_found"].size(), 2, "seed %d: the win found two pieces of gear" % seed_value)
			expect_true("gull_feather_fletching" in report["result"]["gear_found"], "one of them the level's first-clear piece")
	expect_true(won >= 1, "at least one win to check")


# ------------------------------------------------------------------ what gear does

func test_the_pool_has_twelve_items_five_slots_and_gear_rules_from_the_pack() -> void:
	var content := HoldfastContent.base()
	expect_eq(content["gear_items"].size(), 12)
	expect_eq(content["gear_rules"]["gear"]["slots"], ["weapon", "helmet", "armour", "boots", "ring"])
	var per_slot := {}
	for id in content["gear_items"]:
		var slot: String = content["gear_items"][id]["slot"]
		per_slot[slot] = int(per_slot.get(slot, 0)) + 1
		expect_true(slot in content["gear_rules"]["gear"]["slots"], "%s fits a slot" % id)
	expect_eq(per_slot, {"weapon": 3, "helmet": 2, "armour": 3, "boots": 2, "ring": 2})
	expect_eq(content["gear_rules"]["gear"]["elite_levels"], [2.0, 3.0])
	expect_eq(int(content["gear_rules"]["gear"]["boss_level"]), 5)
	expect_eq(float(content["gear_rules"]["gear"]["elite_chance"]), 1.0, "an elite always drops")


func test_each_item_changes_the_hero_by_its_pack_numbers() -> void:
	# Flare Archer pack values: arrow damage 7, cooldown 0.5, range 210, ability cooldown 14,
	# health 60, move speed 170.
	var base := _world()
	var expectations := {
		"weapon:gull_feather_fletching": [func(r: HoldfastRules) -> float: return r.hero_attack["damage"], 9.0],
		"weapon:tarred_bowstring": [func(r: HoldfastRules) -> float: return r.hero_attack["cooldown"], 0.45],
		"weapon:driftwood_stave": [func(r: HoldfastRules) -> float: return r.hero_attack["range"], 250.0],
		"ring:lamp_oil_flask": [func(r: HoldfastRules) -> float: return r.hero_ability["cooldown"], 11.9],
		"armour:sea_glass_charm": [func(r: HoldfastRules) -> float: return r.hero_state["max_health"], 80.0],
		"boots:wave_worn_boots": [func(r: HoldfastRules) -> float: return r.hero_speed, 195.0],
	}
	expect_eq(base.hero_attack["damage"], 7.0)
	for key in expectations:
		var parts: PackedStringArray = key.split(":")
		var rules := _world("gull_rock", "flare_archer", {parts[0]: parts[1]})
		expect_near(float(expectations[key][0].call(rules)), float(expectations[key][1]), 0.0001, key)


func test_gear_applies_to_whichever_hero_path_is_played() -> void:
	var dusk := _world("gull_rock", "dusk_mage", {"weapon": "gull_feather_fletching"})
	expect_eq(dusk.hero_attack["damage"], 7.0, "Dusk Mage 5 + 2")
	var tide := _world("gull_rock", "tideblade", {"armour": "sea_glass_charm"})
	expect_eq(tide.hero_state["max_health"], 100.0, "Tideblade 80 + 20")


func test_two_pieces_stack_and_a_wrong_slot_or_unknown_item_is_ignored() -> void:
	var both := _world("gull_rock", "flare_archer", {"weapon": "driftwood_stave", "boots": "wave_worn_boots"})
	expect_eq(both.hero_attack["range"], 250.0)
	expect_eq(both.hero_speed, 195.0)
	var wrong := _world("gull_rock", "flare_archer", {"armour": "driftwood_stave"})
	expect_eq(wrong.hero_attack["range"], 210.0, "a weapon in the armour slot does nothing")
	var unknown := _world("gull_rock", "flare_archer", {"weapon": "cursed_cutlass"})
	expect_eq(unknown.hero_attack["damage"], 7.0)
	expect_eq(unknown.setup_error, "")


func test_gear_never_touches_the_recruits_or_the_towers() -> void:
	var plain := _world("gull_rock")
	var worn := _world("gull_rock", "flare_archer", {"weapon": "gull_feather_fletching", "armour": "sea_glass_charm"})
	expect_eq(worn.tower.attack_range, plain.tower.attack_range)
	expect_eq(worn.tower.health["max_health"], plain.tower.health["max_health"])
	for i in plain.recruits.size():
		expect_eq(worn.recruits[i].health["max_health"], plain.recruits[i].health["max_health"], "recruit %d" % i)
		expect_eq(worn.recruits[i].attack_range, plain.recruits[i].attack_range)


func test_recruits_have_no_gear_slots() -> void:
	var unit := HeroGear.new_unit("recruit", ["weapon", "armour"])
	expect_eq(unit["slots"].size(), 0)
	var hero := HeroGear.new_unit("hero", HoldfastContent.base()["gear_rules"]["gear"]["slots"])
	expect_eq(hero["slots"].keys(), ["weapon", "helmet", "armour", "boots", "ring"])


func test_gear_in_a_run_changes_the_hash_and_is_replayable() -> void:
	var plain := SimBotRunner.run(HoldfastRules.new(), HoldfastHeroBot.new(), 3, HoldfastContent.run_config("outpost"), 100000, HoldfastRules.TICK_RATE)
	var gear := {"weapon": "gull_feather_fletching", "boots": "wave_worn_boots"}
	var a := SimBotRunner.run(HoldfastRules.new(), HoldfastHeroBot.new(), 3, HoldfastContent.run_config("outpost", [], {}, "", null, gear), 100000, HoldfastRules.TICK_RATE)
	var b := SimBotRunner.run(HoldfastRules.new(), HoldfastHeroBot.new(), 3, HoldfastContent.run_config("outpost", [], {}, "", null, gear), 100000, HoldfastRules.TICK_RATE)
	expect_eq(a["hash"], b["hash"], "same gear, same run")
	expect_ne(a["hash"], plain["hash"], "and it is not the same run as one without")


func test_headless_and_playable_build_match_with_gear_worn() -> void:
	var gear := {"weapon": "tarred_bowstring", "ring": "lamp_oil_flask"}
	for level in ["shingle_beach", "gull_rock"]:
		var config := HoldfastContent.run_config(level, ["keep_walls_1"], {}, "dusk_mage", null, gear, [])
		var headless := SimBotRunner.run(HoldfastRules.new(), HoldfastHeroBot.new(), 6, config, 100000, HoldfastRules.TICK_RATE)
		var source := HoldfastRunSource.new()
		source.auto_step = false
		source.rng_seed = 6
		source.hero_path = "dusk_mage"
		source.level_id = level
		source.upgrades = ["keep_walls_1"]
		source.gear = gear
		source.use_bot = true
		tree.root.add_child(source)
		source.start_run()
		var count := 0
		while source.is_running() and count < 100000:
			source.step(0.1)
			count += 1
		expect_eq(source.get_rules().result()["ticks"], headless["ticks"], level + " ticks")
		expect_eq(source.get_engine().state_hash(), headless["hash"], level + " state")
		source.free()


# ------------------------------------------------------------------ the bots and the boss fight

func test_without_the_ability_no_hero_path_can_beat_the_boss() -> void:
	var content := HoldfastContent.base()
	var kit := HoldfastProgression.buy_cheapest(content["upgrade_nodes"], [], 20000)
	for pillar in PILLARS:
		var report := SimBotRunner.run(HoldfastRules.new(), NoAbilityBot.new(), 1, HoldfastContent.run_config("gull_rock", kit, content, pillar), 6000, HoldfastRules.TICK_RATE)
		expect_ne(report["result"]["outcome"], HoldfastRules.OUTCOME_WON, "%s without its ability" % pillar)


func test_with_the_ability_every_hero_path_beats_the_boss() -> void:
	var content := HoldfastContent.base()
	var kit := HoldfastProgression.buy_cheapest(content["upgrade_nodes"], [], 20000)
	for pillar in PILLARS:
		var won := 0
		for seed_value in range(1, 7):
			var report := HoldfastSim.run_headless(seed_value, HoldfastContent.run_config("gull_rock", kit, content, pillar))
			expect_true(report["finished"], "%s seed %d ended (the boss does not stall a run)" % [pillar, seed_value])
			won += 1 if report["result"]["outcome"] == HoldfastRules.OUTCOME_WON else 0
		expect_true(won >= 1, "%s beat the boss in %d of 6" % [pillar, won])


func test_the_bot_keeps_its_ability_for_a_boss_that_is_still_far_away() -> void:
	var rules := _world()
	var bot := HoldfastHeroBot.new()
	bot.dt = DT
	for crowd in 4:
		_enemy(rules, "grunt", rules.hero_position + Vector2(20 * crowd, -40), 1000.0)
	expect_true(bot.get_input(rules, 1)["ability"], "a crowd at hand spends it")
	var boss := _enemy(rules, "fog_warden", Vector2(0, -450), 500.0)
	expect_false(bot.get_input(rules, 2)["ability"], "a far boss is waited for")
	boss.position = Vector2(0, -250)
	expect_true(bot.get_input(rules, 3)["ability"], "a near one is worth it")
	boss.exposed_left = 3.0
	expect_false(bot.get_input(rules, 4)["ability"], "no second cast while it is open")


# ------------------------------------------------------------------ what the player sees

func test_the_hud_note_says_whether_the_boss_is_shrouded() -> void:
	var main := _main()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.level_id = "gull_rock"
	source.start_run()
	expect_eq(source.get_boss_note(), "", "no boss yet")
	var rules := source.get_rules()
	var boss := _enemy(rules, "fog_warden", Vector2(300, 300), 500.0)
	expect_eq(source.get_boss_note(), "Fog Warden shrouded: use your special")
	boss.exposed_left = 3.2
	expect_eq(source.get_boss_note(), "Fog Warden exposed: 4 s", "rounded up")
	main.free()


func test_the_summary_names_the_gear_a_run_found() -> void:
	var main := _main()
	main.summary.show_summary({"gold_earned": 10, "waves_cleared": 5, "total_waves": 6, "keep_fell": false, "result": {"gear_found": ["driftwood_stave", "sea_glass_charm"]}}, "")
	var label: Label = main.summary.get_node("%GearFound")
	expect_true(label.visible)
	expect_eq(label.text, "Gear found: Driftwood stave, Sea-glass charm")
	main.summary.show_summary({"gold_earned": 10, "waves_cleared": 5, "total_waves": 6, "keep_fell": false, "result": {"gear_found": []}}, "")
	expect_false(label.visible, "nothing found, nothing said")
	main.free()


func test_the_hero_page_lists_owned_gear_and_toggles_it() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var bag: HFlowContainer = main.hero_page.get_node("%Bag")
	expect_eq(bag.get_child_count(), 0, "an empty bag while there is no gear")
	expect_true((main.hero_page.get_node("%BagHint") as Label).text.begins_with("Gear: none yet"))
	profile.bank_run({"outcome": "won", "level": "shingle_beach", "gold": 0, "gear_found": ["driftwood_stave", "sea_glass_charm"]})
	await tree.process_frame
	expect_eq(bag.get_child_count(), 2, "the two pieces")
	expect_eq(profile.get_gear_worn(), {"weapon": "driftwood_stave", "armour": "sea_glass_charm"}, "worn as found")
	var stave: Button = bag.get_child(0)
	expect_eq(stave.text, "Driftwood stave")
	expect_true(stave.button_pressed, "lit while worn")
	stave.pressed.emit()
	expect_eq(profile.get_gear_worn(), {"armour": "sea_glass_charm"}, "pressing takes it off")
	main.free()


func test_the_run_flow_sends_the_worn_gear_and_the_owned_list_to_the_run() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	ThroughLevelZero.apply(profile)
	profile.bank_run({"outcome": "lost", "level": "outpost", "gold": 0, "gear_found": ["tarred_bowstring"]})
	main.journey._buttons["outpost"].pressed.emit()
	main.planning.auto_place()
	main.planning.get_node("%StartButton").pressed.emit()
	expect_true(source.is_running())
	expect_eq(source.gear, {"weapon": "tarred_bowstring"})
	expect_eq(source.gear_owned, ["tarred_bowstring"])
	expect_near(source.get_rules().hero_attack["cooldown"], 0.45, 0.0001, "and the Hero wears it")
	main.free()


# ------------------------------------------------------------------ the profile and its save

func test_a_new_profile_has_five_empty_gear_slots() -> void:
	var profile := HoldfastMeta.new_profile(HoldfastContent.base())
	expect_eq(profile["gear"], {"owned": [], "equipped": {"weapon": "", "helmet": "", "armour": "", "boots": "", "ring": ""}})
	expect_eq(HoldfastMeta.worn_gear(profile), {})


func test_banking_a_run_keeps_its_gear_won_or_lost_and_wears_it_in_a_free_slot() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "lost", "level": "shingle_beach", "gold": 5, "gear_found": ["driftwood_stave"]})
	expect_eq(profile["gear"]["owned"], ["driftwood_stave"], "a lost run keeps what it found")
	expect_eq(profile["gear"]["equipped"]["weapon"], "driftwood_stave", "worn at once")
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "tidewrack_cove", "gold": 5, "gear_found": ["tarred_bowstring", "lamp_oil_flask"]})
	expect_eq(profile["gear"]["owned"], ["driftwood_stave", "tarred_bowstring", "lamp_oil_flask"])
	expect_eq(profile["gear"]["equipped"], {"weapon": "driftwood_stave", "helmet": "", "armour": "", "boots": "", "ring": "lamp_oil_flask"}, "a worn slot is not taken over")


func test_banking_ignores_unknown_and_repeated_gear() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "shingle_beach", "gold": 0, "gear_found": ["driftwood_stave", "driftwood_stave", "cursed_cutlass"]})
	expect_eq(profile["gear"]["owned"], ["driftwood_stave"])
	var again := HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": "shingle_beach", "gold": 0, "gear_found": ["driftwood_stave"]})
	expect_eq(again["gear"], profile["gear"])


func test_wearing_replaces_the_slots_piece_and_taking_off_empties_it() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile["gear"]["owned"] = ["driftwood_stave", "tarred_bowstring"]
	var worn := HoldfastMeta.toggle_gear(content, profile, "driftwood_stave")
	expect_eq(worn["gear"]["equipped"]["weapon"], "driftwood_stave")
	var swapped := HoldfastMeta.toggle_gear(content, worn, "tarred_bowstring")
	expect_eq(swapped["gear"]["equipped"]["weapon"], "tarred_bowstring")
	expect_eq(swapped["gear"]["owned"], ["driftwood_stave", "tarred_bowstring"], "the old piece is still owned")
	var bare := HoldfastMeta.toggle_gear(content, swapped, "tarred_bowstring")
	expect_eq(bare["gear"]["equipped"]["weapon"], "")
	expect_eq(profile["gear"]["equipped"]["weapon"], "", "the profile passed in is not changed")


func test_wearing_what_you_do_not_own_changes_nothing() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	expect_eq(HoldfastMeta.toggle_gear(content, profile, "driftwood_stave"), profile)
	expect_eq(HoldfastMeta.toggle_gear(content, profile, "cursed_cutlass"), profile)


func test_a_save_with_no_gear_loads_and_a_damaged_one_is_repaired() -> void:
	var content := HoldfastContent.base()
	var old := HoldfastMeta.from_save(content, {"gold": 7, "upgrades": ["keep_walls_1"]})
	expect_eq(old["gear"], {"owned": [], "equipped": {"weapon": "", "helmet": "", "armour": "", "boots": "", "ring": ""}}, "a Build 5 save has no gear")
	expect_eq(old["gold"], 7)
	var damaged := HoldfastMeta.from_save(content, {"gear": {
		"owned": ["driftwood_stave", "driftwood_stave", "cursed_cutlass", 7],
		"equipped": {"weapon": "tarred_bowstring", "armour": "driftwood_stave", "hat": "cursed_cutlass"}}})
	expect_eq(damaged["gear"]["owned"], ["driftwood_stave"], "unknown and repeated entries go")
	expect_eq(damaged["gear"]["equipped"], {"weapon": "", "helmet": "", "armour": "", "boots": "", "ring": ""}, "not owned or in the wrong slot: not worn")
	var weird := HoldfastMeta.from_save(content, {"gear": "all of it"})
	expect_eq(weird["gear"]["owned"], [])
	var ok := HoldfastMeta.from_save(content, {"gear": {"owned": ["driftwood_stave", "sea_glass_charm"], "equipped": {"weapon": "driftwood_stave", "armour": "sea_glass_charm"}}})
	expect_eq(ok["gear"]["equipped"], {"weapon": "driftwood_stave", "helmet": "", "armour": "sea_glass_charm", "boots": "", "ring": ""})


func test_gear_survives_a_save_and_a_reload() -> void:
	var path := _save_path("gear")
	var main := _main(path)
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.bank_run({"outcome": "won", "level": "shingle_beach", "gold": 1, "gear_found": ["wave_worn_boots", "tarred_bowstring"]})
	profile.toggle_gear("tarred_bowstring")
	main.free()
	var again := _main(path)
	var loaded: HoldfastProfile = again.get_node("Profile")
	expect_eq(loaded.get_gear_owned(), ["wave_worn_boots", "tarred_bowstring"])
	expect_eq(loaded.get_gear_worn(), {"boots": "wave_worn_boots"})
	again.free()


func test_the_progression_bot_banks_and_wears_what_its_runs_find() -> void:
	var report := HoldfastProgression.play(1, 3.0, "shingle_beach")
	expect_true(report["runs_played"] >= 1)
	expect_eq(report["hash"], HoldfastProgression.play(1, 3.0, "shingle_beach")["hash"], "and is repeatable")


# ------------------------------------------------------------------ QA follow-ups from Build 5

func test_a_damaged_save_with_no_list_or_number_in_the_field_still_loads() -> void:
	var content := HoldfastContent.base()
	for bad in [null, "x", {}, true]:
		var loaded := HoldfastMeta.from_save(content, {"gold": bad, "runs": bad, "upgrades": bad, "levels_won": [], "unlocked": []})
		expect_eq(loaded["gold"], 0)
		expect_eq(loaded["runs"], 0)
		expect_eq(loaded["upgrades"], [])
		var migrated := HoldfastMeta.migrate_v2({"gold": bad, "upgrades": bad}, content)
		expect_eq(migrated["gold"], 0)
		expect_eq(migrated["upgrades"], [])
	var mixed := HoldfastMeta.migrate_v2({"gold": null, "upgrades": ["tower_drills_1", "keep_walls_1"]}, content)
	expect_eq(mixed["gold"], int(HoldfastMeta.V2_TOWER_COSTS["tower_drills_1"]), "the refund still counts on a null gold")


func test_a_hero_node_of_another_path_cannot_be_bought() -> void:
	var content := HoldfastContent.base()
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	profile["gold"] = 5000
	profile["pillar"] = "dusk_mage"
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "flare_boots"), "Belongs to another Hero")
	var refused := HoldfastMeta.buy(content, profile, "flare_boots")
	expect_false(refused["ok"])
	expect_eq(refused["profile"]["gold"], 5000, "nothing was spent")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "post_drills"), "", "a node for every Hero is open")
	profile["pillar"] = "flare_archer"
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "flare_boots"), "", "and the path's own is open")
