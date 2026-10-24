class_name HoldfastProgression
extends RefCounted
## Plays many Holdfast runs in a row headless, buying upgrades between runs, to
## check progression pacing. Each run uses the bot aura on the same rules the
## playable build uses. Simulated time counts run time plus a fixed pause
## between runs (menus, choosing upgrades).

const BETWEEN_RUNS_SECONDS := 10.0


## Buys what the bot can afford: first star nodes (`stars` to spend, cheapest first), then the
## cheapest affordable gold upgrades, each with its requirements met and no owned (or bought
## here) upgrade closing it, until nothing is affordable. Ties go to the id that sorts first.
## `avoid` lists nodes never to buy, which is how a run picks the other side of a fork.
## Returns the ids bought.
static func buy_cheapest(nodes: Dictionary, owned: Array, gold: int, avoid: Array = [], stars := 0) -> Array:
	var bought := []
	while true:
		var best := _cheapest(nodes, owned + bought, stars, avoid, true)
		if best == "":
			break
		bought.append(best)
		stars -= int(nodes[best]["cost"])
	while true:
		var best := _cheapest(nodes, owned + bought, gold, avoid, false)
		if best == "":
			break
		bought.append(best)
		gold -= int(nodes[best]["cost"])
	return bought


## The cheapest node of one currency (`stars_nodes`: stars, else gold) that `purse` pays for, whose
## requirements are met, that nothing closes and that is not owned or avoided; "" when none.
static func _cheapest(nodes: Dictionary, owned: Array, purse: int, avoid: Array, stars_nodes: bool) -> String:
	var best := ""
	var best_cost := 0
	for id in nodes:
		if id in owned or id in avoid:
			continue
		var node: Dictionary = nodes[id]
		var cost := int(node["cost"])
		if HoldfastMeta.is_star_node(node) != stars_nodes or cost > purse or not _requirements_met(node, owned) or _closed(nodes, owned, id):
			continue
		if best == "" or cost < best_cost or (cost == best_cost and str(id) < best):
			best = id
			best_cost = cost
	return best


## True when a node in `owned` excludes `id`, or `id` excludes one of them.
static func _closed(nodes: Dictionary, owned: Array, id: String) -> bool:
	for other in owned:
		if other in nodes[id].get("excludes", []) or id in nodes[other].get("excludes", []):
			return true
	return false


## How many gold upgrades the owned set could still grow to: the owned ones and every other
## node whose requirements are all reachable, that nothing owned closes and that `avoid` does
## not rule out. Star nodes are steps on the way but are not counted. Nodes are listed after
## the ones they require.
static func reachable_total(nodes: Dictionary, owned: Array, avoid: Array = []) -> int:
	var reachable := {}
	var counted := 0
	for id in nodes:
		var open: bool = id in owned or (not id in avoid and not _closed(nodes, owned, id))
		for required in nodes[id].get("requires", []):
			open = open and reachable.has(required)
		if open:
			reachable[id] = true
			if not HoldfastMeta.is_star_node(nodes[id]):
				counted += 1
	return counted


## How many of `owned` are gold nodes.
static func _gold_nodes(nodes: Dictionary, owned: Array) -> int:
	var count := 0
	for id in owned:
		if not HoldfastMeta.is_star_node(nodes[id]):
			count += 1
	return count


static func _requirements_met(node: Dictionary, owned: Array) -> bool:
	for required in node.get("requires", []):
		if not required in owned:
			return false
	return owned.size() >= int(node.get("needs_nodes", 0))


## Plays up to `sim_hours` of progression from `p_seed` and returns the report. It
## stops early once every upgrade is bought, since later runs would only repeat.
## Each run plays `level`, or the latest level the wins so far have unlocked
## when it is "". `avoid` lists nodes the bot never buys (the other side of a fork).
static func play(p_seed: int, sim_hours: float, level: String = "", avoid: Array = []) -> Dictionary:
	var content := HoldfastContent.base()
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var budget := sim_hours * 3600.0
	var sim_time := 0.0
	var profile := HoldfastMeta.new_profile(content)
	avoid = avoid + other_hero_nodes(nodes, str(profile["pillar"]))
	# The bot plays as a player past the tutorial, so it starts on the first real level.
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	var unlocks := []
	var star_unlocks := []
	var runs := []
	var outcomes := {}
	while sim_time < budget:
		# Between runs, as a player does: spend the stars and the gold, then plan and play.
		for bought in buy_for_profile(content, profile, avoid):
			profile = bought["profile"]
			var entry := {"id": bought["id"], "cost": int(nodes[bought["id"]]["cost"]), "at_seconds": sim_time, "after_run": runs.size()}
			(star_unlocks if HoldfastMeta.is_star_node(nodes[bought["id"]]) else unlocks).append(entry)
		if _gold_nodes(nodes, profile["upgrades"]) == reachable_total(nodes, profile["upgrades"], avoid):
			break
		var run_seed := p_seed * 100003 + runs.size()
		var run_level := level if level != "" else str(HoldfastMeta.unlocked_levels(content, profile)[-1])
		var layout := HoldfastMeta.layout_for(content, profile, run_level)
		var report := HoldfastSim.run_headless(run_seed, HoldfastContent.run_config(run_level, profile["upgrades"], content, "", layout, HoldfastMeta.worn_gear(profile), profile["gear"]["owned"], false, true))
		var result: Dictionary = report["result"]
		sim_time += float(report["seconds"]) + BETWEEN_RUNS_SECONDS
		profile = HoldfastMeta.bank_run(content, profile, result)
		profile = HoldfastMeta.wear_free_slots(content, profile)
		var outcome := str(result["outcome"])
		outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
		runs.append({
			"level": run_level,
			"gold": result["gold"],
			"xp": result["xp"],
			"outcome": outcome,
			"waves_cleared": result["waves_cleared"],
			"seconds": report["seconds"],
		})
	var gold_per_run := []
	for run in runs:
		gold_per_run.append(run["gold"])
	var report := {
		"seed": p_seed,
		"level": level if level != "" else "latest unlocked",
		"sim_hours": sim_hours,
		"sim_seconds": sim_time,
		"runs_played": runs.size(),
		"outcomes": outcomes,
		"unlocks": unlocks,
		"star_unlocks": star_unlocks,
		"upgrades_owned": _gold_nodes(nodes, profile["upgrades"]),
		"upgrades_total": reachable_total(nodes, profile["upgrades"], avoid),
		"gold_per_run": gold_per_run,
		"bank": int(profile["gold"]),
		"runs": runs,
	}
	report["hash"] = SimEngine.hash_data(report)
	return report


## The nodes that belong to another Hero than `pillar`, which the bot never buys.
static func other_hero_nodes(nodes: Dictionary, pillar: String) -> Array:
	var out := []
	for id in nodes:
		if nodes[id].has("hero") and str(nodes[id]["hero"]) != pillar:
			out.append(id)
	return out


## What the bot buys with the stars and gold the profile has: [{id, profile}] in the order
## bought, each bought through the same rules the Keep screen uses.
static func buy_for_profile(content: Dictionary, profile: Dictionary, avoid: Array) -> Array:
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var out := []
	for id in buy_cheapest(nodes, profile["upgrades"], int(profile["gold"]), avoid, HoldfastMeta.stars_available(content, profile)):
		var bought := HoldfastMeta.buy(content, profile, id)
		if not bought["ok"]:
			push_error("progression: the bot could not buy %s: %s" % [id, bought["reason"]])
			break
		profile = bought["profile"]
		out.append({"id": id, "profile": profile})
	return out
