class_name HoldfastSim
extends RefCounted
## Headless Holdfast: plays seeded runs on the kit engine with the bot aura,
## as fast as the machine allows. The playable build runs the same rules through
## scripts/holdfast_run_source.gd.

const MAX_RUN_SECONDS := 3600


## Plays one run and returns the kit bot runner's report ({ticks, seconds,
## finished, result, hash}).
static func run_headless(p_seed: int, config: Dictionary = {}) -> Dictionary:
	var run_config := config if not config.is_empty() else HoldfastContent.run_config()
	return SimBotRunner.run(HoldfastRules.new(), HoldfastAuraBot.new(), p_seed, run_config,
		MAX_RUN_SECONDS * HoldfastRules.TICK_RATE, HoldfastRules.TICK_RATE)
