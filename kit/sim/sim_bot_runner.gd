class_name SimBotRunner
extends RefCounted
## Plays a game's rules headless with a bot controller, as fast as possible.


## Runs one seeded game from start to end (or `max_ticks`) and returns
## {ticks, seconds, finished, result, hash}.
static func run(rules: SimRules, bot: SimController, p_seed: int, config: Dictionary, max_ticks: int, tick_rate: int = SimEngine.DEFAULT_TICK_RATE) -> Dictionary:
	var engine := SimEngine.new(rules, bot, p_seed, config, tick_rate)
	engine.run_to_end(max_ticks)
	return {
		"ticks": engine.tick,
		"seconds": engine.get_time(),
		"finished": rules.is_finished(),
		"result": rules.result(),
		"hash": engine.state_hash(),
	}
