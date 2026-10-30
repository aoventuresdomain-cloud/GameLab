class_name HoldfastCurve
extends RefCounted
## A first-time player's climb through the first levels, played headless by a Hero bot that
## plans like a player: between runs it spends its stars and gold (cheapest first), wears what
## it found, and places the posts the castle allows (Archers, and a Mage once the Gate is
## taken). It replays a level until it wins, then moves on. HF-M2-35 tunes levels 1 to 5
## against the first-attempt win rates this reports.

## Attempts at one level before the player is counted as stuck.
const MAX_ATTEMPTS := 8
const MAX_TICKS := 200000


## Plays levels 1 to `level_count` once each (replaying until won) with `model`
## (HoldfastSkilledBot.AVERAGE or POOR) and returns
## {levels: {id: {"first": won the first attempt, "keep": the Keep's health left after it (0 to 1),
## "seconds": how long it ran, "attempts": int, "cleared": won within MAX_ATTEMPTS}}, "dry_runs": most runs in a row with nothing new to buy, "gaps": every return
## to the tree with nothing the player could afford ("level" and "attempt", one entry each; a gap
## is a finding), "runs": runs played}.
## A level the player never wins ends the climb. `skip` lists nodes the player never buys (one
## side of a fork). `first_only` is for a caller that reads only the first attempts: the last level is
## played once, as nothing comes after it. `prefer` is a chain the player saves up for (see
## HoldfastProgression.buy_for_profile).
static func climb(p_seed: int, model: Dictionary, pillar := "flare_archer", level_count := 5, skip: Array = [], first_only := false, prefer: Array = []) -> Dictionary:
	var content := HoldfastContent.base()
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var avoid := HoldfastProgression.other_hero_nodes(nodes, pillar) + skip
	var profile := HoldfastMeta.new_profile(content)
	profile["pillar"] = pillar
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	var levels := {}
	var runs := 0
	var dry := 0
	var worst_dry := 0
	var gaps := []
	for level in _levels(content).slice(0, level_count):
		var attempts := 0
		var won := false
		var last_level: bool = first_only and level == _levels(content).slice(0, level_count)[-1]
		while not won and attempts < MAX_ATTEMPTS and not (last_level and attempts > 0):
			var bought := HoldfastProgression.buy_for_profile(content, profile, avoid, prefer)
			if bought.is_empty():
				dry += 1
				gaps.append({"level": level, "attempt": attempts + 1})
			else:
				profile = bought[-1]["profile"]
				dry = 0
			worst_dry = maxi(worst_dry, dry)
			var config := HoldfastContent.run_config(level, profile["upgrades"], content, pillar, HoldfastMeta.layout_for(content, profile, level), HoldfastMeta.worn_gear(profile), profile["gear"]["owned"], false, RecruitMeta.bot_squad(content, profile))
			var result: Dictionary = SimBotRunner.run(HoldfastRules.new(), HoldfastSkilledBot.new(model), p_seed * 100003 + runs, config, MAX_TICKS, HoldfastRules.TICK_RATE)["result"]
			profile = RecruitMeta.bot_picks(content, HoldfastMeta.bank_run(content, profile, result))
			profile = HoldfastMeta.wear_free_slots(content, profile)
			won = result["outcome"] == HoldfastRules.OUTCOME_WON
			if attempts == 0:
				levels[level] = {"first": won, "keep": float(result.get("keep_health", 0.0)) / maxf(float(result.get("keep_health_max", 1.0)), 1.0), "seconds": float(result.get("seconds", 0.0))}
			attempts += 1
			runs += 1
		levels[level]["attempts"] = attempts
		levels[level]["cleared"] = won
		if not won:
			break
	return {"levels": levels, "dry_runs": worst_dry, "gaps": gaps, "runs": runs}


## The level ids in play order, without the tutorial.
static func _levels(content: Dictionary) -> Array:
	var out := []
	for id in content.get("levels", {}):
		if not content["levels"][id].get("tutorial", false):
			out.append(id)
	return out
