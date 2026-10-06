class_name HoldfastProgression
extends RefCounted
## Plays many Holdfast runs in a row headless, buying upgrades between runs, to
## check progression pacing. Each run uses the bot aura on the same rules the
## playable build uses. Simulated time counts run time plus a fixed pause
## between runs (menus, choosing upgrades).

const BETWEEN_RUNS_SECONDS := 10.0


## Buys the cheapest affordable upgrades whose requirements are met, until none
## is affordable. Ties go to the id that sorts first. Returns the ids bought.
static func buy_cheapest(nodes: Dictionary, owned: Array, gold: int) -> Array:
	var bought := []
	while true:
		var best := ""
		var best_cost := 0
		for id in nodes:
			if id in owned or id in bought:
				continue
			var node: Dictionary = nodes[id]
			var cost := int(node["cost"])
			if cost > gold or not _requirements_met(node, owned + bought):
				continue
			if best == "" or cost < best_cost or (cost == best_cost and str(id) < best):
				best = id
				best_cost = cost
		if best == "":
			return bought
		bought.append(best)
		gold -= best_cost
	return bought


static func _requirements_met(node: Dictionary, owned: Array) -> bool:
	for required in node.get("requires", []):
		if not required in owned:
			return false
	return true


## Plays `sim_hours` of progression from `p_seed` and returns the report.
static func play(p_seed: int, sim_hours: float, level: String = HoldfastContent.DEFAULT_LEVEL) -> Dictionary:
	var content := HoldfastContent.base()
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var budget := sim_hours * 3600.0
	var sim_time := 0.0
	var bank := 0
	var owned := []
	var unlocks := []
	var runs := []
	var outcomes := {}
	while sim_time < budget:
		var run_seed := p_seed * 100003 + runs.size()
		var report := HoldfastSim.run_headless(run_seed, HoldfastContent.run_config(level, owned, content))
		var result: Dictionary = report["result"]
		sim_time += float(report["seconds"]) + BETWEEN_RUNS_SECONDS
		bank += int(result["gold"])
		var outcome := str(result["outcome"])
		outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
		runs.append({
			"gold": result["gold"],
			"xp": result["xp"],
			"outcome": outcome,
			"waves_cleared": result["waves_cleared"],
			"seconds": report["seconds"],
		})
		for id in buy_cheapest(nodes, owned, bank):
			bank -= int(nodes[id]["cost"])
			owned.append(id)
			unlocks.append({"id": id, "cost": int(nodes[id]["cost"]), "at_seconds": sim_time, "after_run": runs.size()})
	var gold_per_run := []
	for run in runs:
		gold_per_run.append(run["gold"])
	var report := {
		"seed": p_seed,
		"level": level,
		"sim_hours": sim_hours,
		"sim_seconds": sim_time,
		"runs_played": runs.size(),
		"outcomes": outcomes,
		"unlocks": unlocks,
		"upgrades_owned": owned.size(),
		"upgrades_total": nodes.size(),
		"gold_per_run": gold_per_run,
		"bank": bank,
		"runs": runs,
	}
	report["hash"] = SimEngine.hash_data(report)
	return report
