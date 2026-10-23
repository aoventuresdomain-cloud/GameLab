extends KitTestCase
## Build 4: HF-M2-22 (early levels are winnable). The first-time win-rate bands moved to
## test_curve.gd with HF-M2-35; the bots here are HoldfastSkilledBot's average and poor players
## with no upgrades. Hero numbers are pinned here as floors, so a retune can raise them but
## never lower them.

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
