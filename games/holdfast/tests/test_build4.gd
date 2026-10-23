extends KitTestCase
## Build 4: HF-M2-22 (early levels are winnable). The win-rate bands are pack values
## (`balance_check.first_time` in levels.json); the bots are HoldfastSkilledBot's
## average and poor first-time players with no upgrades. Hero numbers are pinned
## here as floors, so a retune can raise them but never lower them.

const PILLARS := ["flare_archer", "dusk_mage", "tideblade"]
## The Hero's numbers when this item was done: health, move speed, attack damage, ability damage.
const HERO_FLOORS := {
	"flare_archer": [60, 170, 7, 6],
	"dusk_mage": [50, 160, 5, 14],
	"tideblade": [80, 190, 9, 20],
}


func _win_rate(level: String, pillar: String, model: Dictionary, seeds: int) -> float:
	var won := 0
	for run_seed in range(1, seeds + 1):
		var config := HoldfastContent.run_config(level, [], {}, pillar)
		var bot := HoldfastSkilledBot.new(model)
		var result: Dictionary = SimBotRunner.run(HoldfastRules.new(), bot, run_seed, config, 200000, HoldfastRules.TICK_RATE)["result"]
		won += 1 if result["outcome"] == HoldfastRules.OUTCOME_WON else 0
	return float(won) / seeds


func test_first_time_players_win_levels_one_and_two_inside_the_pack_bands() -> void:
	# The average bot stands in for a first-time player: its win rate over the three
	# pillars must sit inside the band. The poor bot has a lower floor.
	var levels: Dictionary = HoldfastContent.base()["levels"]
	var banded := 0
	for level in levels:
		if levels[level].get("tutorial", false):
			continue
		var check: Dictionary = levels[level]["balance_check"]
		if not check.has("first_time"):
			continue
		banded += 1
		var band: Dictionary = check["first_time"]
		var average_total := 0.0
		var poor_total := 0.0
		for pillar in PILLARS:
			average_total += _win_rate(level, pillar, HoldfastSkilledBot.AVERAGE, int(band["seeds"]))
			poor_total += _win_rate(level, pillar, HoldfastSkilledBot.POOR, int(band["seeds"]))
		var average := average_total / PILLARS.size()
		var poor := poor_total / PILLARS.size()
		expect_true(average >= float(band["min_win_rate"]), "%s: the average bot won %.0f%%, the band starts at %.0f%%" % [level, average * 100.0, float(band["min_win_rate"]) * 100.0])
		expect_true(average <= float(band["max_win_rate"]), "%s: the average bot won %.0f%%, the band ends at %.0f%%" % [level, average * 100.0, float(band["max_win_rate"]) * 100.0])
		expect_true(poor >= float(band["poor_min_win_rate"]), "%s: the poor bot won %.0f%%, its floor is %.0f%%" % [level, poor * 100.0, float(band["poor_min_win_rate"]) * 100.0])
		expect_true(poor <= average, "%s: the poor bot (%.0f%%) does no better than the average one (%.0f%%)" % [level, poor * 100.0, average * 100.0])
	expect_eq(banded, 2, "levels 1 and 2 have a band, and later levels do not")


func test_the_hero_is_not_weaker_than_it_was() -> void:
	var paths: Dictionary = HoldfastContent.base()["hero_paths"]
	for pillar in HERO_FLOORS:
		var floors: Array = HERO_FLOORS[pillar]
		var path: Dictionary = paths[pillar]
		expect_true(float(path["health"]) >= floors[0] and float(path["move_speed"]) >= floors[1], pillar + ": health and speed")
		expect_true(float(path["attack"]["damage"]) >= floors[2], pillar + ": attack damage")
		expect_true(float(path["ability"].get("damage", 0.0)) >= floors[3], pillar + ": ability damage")


## How hard a wave hits: its enemies' health and damage, as scaled.
func _strength(content: Dictionary, wave: Dictionary) -> float:
	var health := 0.0
	for spawn in wave["spawns"]:
		health += float(spawn["count"]) * float(content["enemies"][spawn["enemy"]]["health"])
	return health * float(wave.get("health_scale", 1.0)) * float(wave.get("damage_scale", 1.0))


func test_every_level_still_gets_harder_wave_by_wave_in_the_pack() -> void:
	var content := HoldfastContent.base()
	for level in content["levels"]:
		var strength := 0.0
		for i in content["levels"][level]["waves"].size():
			var now := _strength(content, content["levels"][level]["waves"][i])
			expect_true(now > strength, "%s wave %d (%.0f) is stronger than the one before (%.0f)" % [level, i + 1, now, strength])
			strength = now


func test_a_run_with_no_input_is_lost_on_the_first_two_levels() -> void:
	for level in ["outpost", "shingle_beach"]:
		for pillar in PILLARS:
			for run_seed in [1, 2, 3]:
				var config := HoldfastContent.run_config(level, [], {}, pillar)
				var result: Dictionary = SimBotRunner.run(HoldfastRules.new(), SimController.new(), run_seed, config, 200000, HoldfastRules.TICK_RATE)["result"]
				expect_eq(result["outcome"], HoldfastRules.OUTCOME_LOST, "%s %s seed %d with no input" % [level, pillar, run_seed])


func test_the_band_schema_refuses_nonsense() -> void:
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var level: Dictionary = HoldfastContent.base()["levels"]["outpost"].duplicate(true)
	var errors: PackedStringArray = []
	schema.validate_def(level, "level", "levels.json: $", errors, [])
	expect_true(errors.is_empty(), str(errors))
	for bad in [{"seeds": 0, "min_win_rate": 0.5, "max_win_rate": 1.0, "poor_min_win_rate": 0.2}, {"seeds": 5, "min_win_rate": -0.1, "max_win_rate": 1.0, "poor_min_win_rate": 0.2}, {"seeds": 5, "min_win_rate": 0.5, "max_win_rate": 1.5, "poor_min_win_rate": 0.2}, {"seeds": 5, "min_win_rate": 0.5, "max_win_rate": 1.0}]:
		level["balance_check"]["first_time"] = bad
		errors.clear()
		schema.validate_def(level, "level", "levels.json: $", errors, [])
		expect_false(errors.is_empty(), "refused: " + str(bad))


func test_the_skilled_bots_are_deterministic_and_the_poor_one_reacts_slower() -> void:
	expect_true(HoldfastSkilledBot.POOR["reaction_ticks"] > HoldfastSkilledBot.AVERAGE["reaction_ticks"])
	var a := _win_rate("outpost", "flare_archer", HoldfastSkilledBot.POOR, 5)
	var b := _win_rate("outpost", "flare_archer", HoldfastSkilledBot.POOR, 5)
	expect_eq(a, b, "the same seeds give the same result")


func test_the_later_levels_can_still_be_lost_by_the_pillar_bots() -> void:
	var content := HoldfastContent.base()
	for level in content["levels"]:
		if content["levels"][level].get("tutorial", false):
			continue
		var check: Dictionary = content["levels"][level]["balance_check"]
		if check.has("first_time"):
			continue
		var kit := HoldfastProgression.buy_cheapest(content["upgrade_nodes"], [], int(check.get("kit_gold", 0)))
		var lost := false
		for pillar in PILLARS:
			for run_seed in range(1, int(check["seeds"]) + 1):
				var result: Dictionary = HoldfastSim.run_headless(run_seed, HoldfastContent.run_config(level, kit, {}, pillar))["result"]
				if result["outcome"] != HoldfastRules.OUTCOME_WON:
					lost = true
					break
			if lost:
				break
		expect_true(lost, "%s: some pillar bot loses some run, or the tower can never fall" % level)
