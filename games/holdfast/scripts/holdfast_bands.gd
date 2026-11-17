class_name HoldfastBands
extends RefCounted
## HF-M2-01 and HF-M2-05: the pacing bands and the gate that holds the game to them.
## `content/pacing-bands.json` says what a first-time player's win rate should be; `measure`
## plays the climbs (HoldfastCurve) and `evaluate` checks every figure against its band.
## Every figure has a key such as "flare_archer/average/outpost". A band can be missed only
## by a pinned known miss (`known_misses`: key to the measured figure); the gate then fails
## if the figure gets worse, or if it comes back inside its band (delete the pin).

const PATH := "res://content/pacing-bands.json"
const PILLARS := ["flare_archer", "dusk_mage", "tideblade"]
const BOTS := {"average": HoldfastSkilledBot.AVERAGE, "poor": HoldfastSkilledBot.POOR}
## The Archer fork: a player on one side never buys the other side's chain.
const FORK_SKIPS := {
	"volley": ["post_scope", "post_marksman", "post_piercing"],
	"sniper": ["post_twin", "post_burst", "post_storm"],
}
## The chain a player who picked that side buys first, saving up for each node: without it the
## cheapest-first bot reaches neither side's 600 gold nodes in five levels and the forks never differ.
## Only the Flare Archer saves up for a side: its tower is its kit. The Dusk Mage and the Tideblade spend
## on their own nodes first, and saving for a 1400 gold tower node would starve them.
const FORK_PREFER_PILLAR := "flare_archer"
const FORK_PREFER := {
	"volley": ["post_sight", "post_scope", "post_marksman", "post_piercing"],
	"sniper": ["post_drills", "post_twin", "post_burst", "post_storm"],
}
## The nodes that make a Hero's special fire on its own (Keeper's Habit). The player who never presses
## the special is measured twice: without these ("no_special", the button taught and ignored) and
## with them saved up for ("auto", like the Fork sides' chains).
static func auto_nodes() -> Array:
	var out := []
	var nodes: Dictionary = HoldfastContent.base().get("upgrade_nodes", {})
	for id in nodes:
		for effect in nodes[id].get("effects", []):
			if str(effect["stat"]).ends_with("ability.auto_power"):
				out.append(id)
	return out


## What the player who never presses the special saves up for: each auto-cast node with the nodes it needs, in order.
static func auto_chain() -> Array:
	var nodes: Dictionary = HoldfastContent.base().get("upgrade_nodes", {})
	var out := []
	for id in auto_nodes():
		_with_requirements(nodes, id, out)
	return out


static func _with_requirements(nodes: Dictionary, id: String, out: Array) -> void:
	for need in nodes[id].get("requires", []):
		_with_requirements(nodes, need, out)
	if not id in out:
		out.append(id)


## One post at a time: the second castle slot is never bought.
const ONE_POST_SKIP := ["castle_slot_2"]
## Pins are written to four places; a rate is a whole number of players, so a real change is far bigger.
const PIN_TOLERANCE := 0.0001
## The key in a climb's row that holds how each level's first attempt went (Keep health left, seconds).
const FEEL := "_feel"
## What a fork cell remembers about the fork nodes: {"owned": {level: owned at its first attempt}, "arrival": {level: run}, "first": first run played owning one}.
const WATCH := "_watch"
## The nodes that make an Archer side a side: the 600 gold node and the 1,400 gold one of each (the tier 1 nodes before them are shared by habit).
const FORK_NODES := ["post_scope", "post_marksman", "post_twin", "post_burst"]
## What a fork player who never buys a fork node counts as when the wait is averaged (runs).
const FORK_NEVER := 8
## Keeps the Extreme probes' seeds apart from the players' own runs.
const EXTREME_SEED := 60013


static func load_bands() -> Dictionary:
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## The level ids in play order, without the tutorial. `content` is the pack to read (the base pack when empty).
static func levels(content: Dictionary = {}) -> Array:
	return HoldfastCurve._levels(content if not content.is_empty() else HoldfastContent.base())


## The levels a pillar is judged on: the pack's `pillar_levels` entry, or every level. A pillar is
## tuned to the biomes it unlocks into, so it is judged only there. Widen the scope when a later biome
## exists; the gate fails if a pillar's scope is empty or names a level that does not exist.
static func scope(bands: Dictionary, pillar: String, content: Dictionary = {}) -> Array:
	var named: Variant = bands.get("pillar_levels", {}).get(pillar)
	var all := levels(content)
	if named is Array:
		return named.filter(func(level: Variant) -> bool: return level in all)
	return all


## The levels a pillar is not judged on (shown in the report as not played by it yet).
static func out_of_scope(bands: Dictionary, pillar: String) -> Array:
	var inside := scope(bands, pillar)
	return levels().filter(func(level: String) -> bool: return not inside.has(level))


## Problems with the bands file itself: a level (a new biome's, say) with no band entry, a pillar judged
## on nothing, or on a level that is not there. `content` is the pack to read (the base pack when empty).
static func scope_problems(bands: Dictionary, content: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = []
	var all := levels(content)
	var pack: Dictionary = content if not content.is_empty() else HoldfastContent.base()
	for level in all:
		if not bands.get("bands", {}).has(level):
			out.append("%s has no band entry (`bands`): give it first-time bands before it ships" % level)
		if not pack["levels"][level].get("modifiers", []).is_empty() and not bands.get("hard", {}).has(level):
			out.append("%s has a Hard replay but no `hard` band entry" % level)
		if bands.has("easy") and not level in bands["easy"]["gain_levels"] and not level in bands["easy"]["mild_levels"]:
			out.append("%s is in neither `easy` list (gain_levels, mild_levels)" % level)
	for pillar in PILLARS:
		var named: Variant = bands.get("pillar_levels", {}).get(pillar)
		if named is Array:
			for level in named:
				if not all.has(level):
					out.append("%s is judged on %s, which is not a level" % [pillar, level])
		if scope(bands, pillar, content).is_empty():
			out.append("%s is judged on no level at all" % pillar)
	return out


## One cell of the sweep: the climbs of seeds 1..`seeds`, as one {level: won first time} per seed
## (a level the climb never reached is left out), with how its first attempt felt under the FEEL key. With `tiers` each
## row also says how an Easy run from the same build and seed as the first attempt went ("easy:<level>": won, "easy_keep:<level>":
## the share of the Keep's health left; a probe, nothing banked).
static func cell(model: Dictionary, pillar: String, seeds: int, skip: Array = [], prefer: Array = [], watch: Array = [], tiers := false) -> Array:
	var out := []
	for run_seed in range(1, seeds + 1):
		var row := {FEEL: {}, WATCH: {"owned": {}, "arrival": {}, "first": -1}}
		var climb := HoldfastCurve.climb(run_seed, model, pillar, levels().size(), skip, true, prefer, false, watch, tiers)
		for id in climb["levels"]:
			row[id] = climb["levels"][id]["first"]
			if tiers:
				row["easy:%s" % id] = climb["levels"][id]["easy"]
				row["easy_keep:%s" % id] = climb["levels"][id]["easy_keep"]
			row[FEEL][id] = {"keep": climb["levels"][id]["keep"], "seconds": climb["levels"][id]["seconds"]}
			row[WATCH]["owned"][id] = climb["levels"][id]["watched"]
			row[WATCH]["arrival"][id] = climb["levels"][id]["arrival"]
		row[WATCH]["first"] = int(climb["watch_run"])
		out.append(row)
	return out


## The Hard cell: the climbs of seeds 1..`seeds`, as one {level: won its Hard replay first time} per seed. A player
## plays each level's Hard replay once, right after clearing the level; a level never cleared is left out.
static func hard_cell(pillar: String, seeds: int) -> Array:
	var out := []
	for run_seed in range(1, seeds + 1):
		var row := {}
		var climb := HoldfastCurve.climb(run_seed, HoldfastSkilledBot.AVERAGE, pillar, levels().size(), [], false, [], true)
		for id in climb["levels"]:
			if climb["levels"][id].has("hard"):
				row[id] = climb["levels"][id]["hard"]
		out.append(row)
	return out


## The tree cell: the progression of seeds 1..`seeds` played for `sim_hours` of simulated time by the
## average bot, as one summary per seed ({hours: until every gold node the Hero can reach is bought,
## or the whole budget if it never was; filled; dry: the longest run of returns with nothing
## affordable; the first star, new tower and boss in minutes, -1 for never; stars earned and the
## stars the tree costs}). With an `extreme` entry of the bands naming this pillar, each row also says how the player
## fared on every level's Extreme replay from the build it ended on (the full gold tree, gear worn), as {level: [wins,
## runs]} for the average bot ("extreme") and, on the judged level, the poor bot ("extreme_poor"): Extreme is held to a
## full build.
static func tree_cell(pillar: String, seeds: int, sim_hours: float, extreme := {}) -> Array:
	var out := []
	for run_seed in range(1, seeds + 1):
		var played := HoldfastProgression.play(run_seed, sim_hours, "", [], pillar, BOTS["average"], true)
		var filled: bool = float(played["filled_at"]) >= 0.0
		out.append({
			"hours": (float(played["filled_at"]) if filled else float(played["sim_seconds"])) / 3600.0,
			"filled": filled,
			"dry": int(played["dry_runs"]),
			"dry_median": float(played["dry_median"]),
			"first_star": _minutes(float(played["first_star_at"])),
			"first_tower": _minutes(float(played["first_new_tower_at"])),
			"first_boss": _minutes(float(played["first_boss_at"])),
			"stars": int(played["stars_earned"]),
			"stars_in_tree": int(played["stars_in_tree"]),
			"extreme": _extreme_wins(played["profile"], pillar, run_seed, extreme, BOTS["average"], false),
			"extreme_poor": _extreme_wins(played["profile"], pillar, run_seed, extreme, BOTS["poor"], true),
		})
	return out


## {level: [Extreme runs won, runs played]} for a player with `profile` and the bot `model`: `runs` on every level and
## `judged_runs` on the judged one (alone when `judged_only`); {} for a pillar the bands do not judge Extreme on.
static func _extreme_wins(profile: Dictionary, pillar: String, run_seed: int, extreme: Dictionary, model: Dictionary, judged_only: bool) -> Dictionary:
	var out := {}
	if extreme.is_empty() or str(extreme["pillar"]) != pillar:
		return out
	var content := HoldfastContent.base()
	for level in levels():
		var judged: bool = level == str(extreme["level"])
		if judged_only and not judged:
			continue
		var runs := int(extreme["judged_runs"]) if judged else int(extreme["runs"])
		var wins := 0
		for k in runs:
			wins += 1 if HoldfastCurve.probe(content, profile, level, pillar, model, run_seed * 100003 + k + EXTREME_SEED, "extreme") else 0
		out[level] = [wins, runs]
	return out


static func _minutes(seconds: float) -> float:
	return seconds / 60.0 if seconds >= 0.0 else -1.0


## Plays every cell the bands ask for. Returns {cell name: climbs}.
static func measure(bands: Dictionary) -> Dictionary:
	var seeds: Dictionary = bands["seeds"]
	var out := {}
	for pillar in PILLARS:
		for bot in BOTS:
			out["%s/%s" % [pillar, bot]] = cell(BOTS[bot], pillar, int(seeds["band"]), [], [], [], bot == "poor" and bands.has("easy"))
		for side in FORK_SKIPS:
			out["%s/%s" % [pillar, side]] = cell(HoldfastSkilledBot.AVERAGE, pillar, int(seeds["fork"]), FORK_SKIPS[side] + auto_nodes(), FORK_PREFER[side] if pillar == FORK_PREFER_PILLAR else [], FORK_NODES)
		out["%s/no_special" % pillar] = cell(HoldfastSkilledBot.AVERAGE_NO_SPECIAL, pillar, int(seeds["special"]), auto_nodes())
		if bands.has("hard"):
			out["%s/hard" % pillar] = hard_cell(pillar, int(seeds["hard"]))
		if _has_auto_node(pillar):
			out["%s/auto" % pillar] = cell(HoldfastSkilledBot.AVERAGE_NO_SPECIAL, pillar, int(seeds["special"]), [], auto_chain())
		if bands.has("tree"):
			out["%s/tree" % pillar] = tree_cell(pillar, int(seeds["tree"]), float(bands["tree"]["sim_hours"]), bands.get("extreme", {}))
	var one_post: Dictionary = bands["one_post"]
	if str(one_post["level"]) in scope(bands, str(one_post["pillar"])):
		out["%s/one_post" % one_post["pillar"]] = cell(HoldfastSkilledBot.AVERAGE, str(one_post["pillar"]), int(seeds["one_post"]), ONE_POST_SKIP)
	return out


## True when the pillar has a node that fires its special for it.
static func _has_auto_node(pillar: String) -> bool:
	var nodes: Dictionary = HoldfastContent.base().get("upgrade_nodes", {})
	for id in auto_nodes():
		if not nodes[id].has("hero") or str(nodes[id]["hero"]) == pillar:
			return true
	return false


## First-time win rate of the first `seeds` climbs at `level` (0 means all), over the players who
## reached it; 0.0 when nobody did.
static func rate(climbs: Array, level: String, seeds := 0) -> float:
	var reached := 0
	var won := 0
	for row in climbs.slice(0, seeds if seeds > 0 else climbs.size()):
		if row.has(level):
			reached += 1
			won += 1 if row[level] else 0
	return float(won) / float(reached) if reached > 0 else 0.0


## The share of Extreme runs won at `level` over the players of the tree cell `rows`, by the bot `field` names
## ("extreme" or "extreme_poor"); 0.0 when none was played.
static func extreme_rate(rows: Array, field: String, level: String) -> float:
	var played := 0
	var won := 0
	for row in rows:
		if row.get(field, {}).has(level):
			won += int(row[field][level][0])
			played += int(row[field][level][1])
	return float(won) / float(played) if played > 0 else 0.0


## How much more of the Keep's health is left on the Easy probe than on the first attempt at `level`, over the players
## who reached it (as a share of full health, so a sturdier Keep does not count by itself); 0.0 when nobody did.
static func easy_keep_gain(climbs: Array, level: String) -> float:
	var total := 0.0
	var count := 0
	for row in climbs:
		if row.has("easy_keep:%s" % level) and row.get(FEEL, {}).has(level):
			total += float(row["easy_keep:%s" % level]) - float(row[FEEL][level]["keep"])
			count += 1
	return total / float(count) if count > 0 else 0.0


## The mean of `field` ("keep" or "seconds") over the first attempts at `level` in `climbs`, or -1 when nobody reached it.
static func feel(climbs: Array, level: String, field: String) -> float:
	var total := 0.0
	var count := 0
	for row in climbs:
		if row.get(FEEL, {}).has(level):
			total += float(row[FEEL][level][field])
			count += 1
	return total / float(count) if count > 0 else -1.0


## How differently two sets of climbs felt at `level`: the larger of the gap in the Keep's health left
## (a share of its full health) and the gap in clear time (a share of the longer one). 0 when either side never reached it.
static func feel_gap(a: Array, b: Array, level: String) -> float:
	var keep_a := feel(a, level, "keep")
	var keep_b := feel(b, level, "keep")
	if keep_a < 0.0 or keep_b < 0.0:
		return 0.0
	var time_a := feel(a, level, "seconds")
	var time_b := feel(b, level, "seconds")
	return maxf(absf(keep_a - keep_b), absf(time_a - time_b) / maxf(maxf(time_a, time_b), 1.0))


## The first level where the players of the two fork cells own a fork node at their first attempt in at least `fork_feel.owned_share` of
## the runs ("" if there is none): the level from which the two sides can feel different, so it moves by itself when the pacing does.
static func fork_start(bands: Dictionary, volley: Array, sniper: Array) -> String:
	var share := float(bands["fork_feel"]["owned_share"])
	for level in levels():
		var reached := 0
		var owned := 0
		for row in volley + sniper:
			var owned_at: Dictionary = row.get(WATCH, {}).get("owned", {})
			if owned_at.has(level):
				reached += 1
				owned += 1 if owned_at[level] else 0
		if reached > 0 and float(owned) / float(reached) >= share:
			return level
	return ""


## The mean number of runs between a fork player reaching `level` and playing a run that owns a fork node (0 when one was owned on
## arrival, FORK_NEVER for a player who never owned one), or -1 when nobody reached the level.
static func fork_wait(volley: Array, sniper: Array, level: String) -> float:
	var total := 0.0
	var count := 0
	for row in volley + sniper:
		var watch: Dictionary = row.get(WATCH, {})
		if not watch.get("arrival", {}).has(level):
			continue
		var first := int(watch.get("first", -1))
		total += float(FORK_NEVER) if first < 0 else maxf(float(first - int(watch["arrival"][level])), 0.0)
		count += 1
	return total / float(count) if count > 0 else -1.0


## Every figure the bands judge, as {key: {"value", "lo", "hi", "how"}}. A pillar is judged on its scope.
static func figures(bands: Dictionary, cells: Dictionary) -> Dictionary:
	var out := {}
	var seeds: Dictionary = bands["seeds"]
	var fork_max := float(bands["fork_gap"]["max"])
	var feel_min := float(bands["fork_feel"]["min"])
	var special: Dictionary = bands["special_gap"]
	for pillar in PILLARS:
		var inside := scope(bands, pillar)
		var volley: Array = cells["%s/volley" % pillar]
		var sniper: Array = cells["%s/sniper" % pillar]
		var feel_start := fork_start(bands, volley, sniper)
		var feel_from: int = levels().find(feel_start) if feel_start != "" else levels().size()
		var low := 1.0
		var gaps := []
		var never: Array = cells.get("%s/auto" % pillar, cells["%s/no_special" % pillar])
		for level in inside:
			var avg: Array = bands["bands"][level]["average"]
			avg = [avg[0], maxf(float(avg[1]), float(bands.get("pillar_ceilings", {}).get(pillar, 0.0)))]
			var poor_min := float(bands["bands"][level]["poor_min"])
			var on := rate(cells["%s/average" % pillar], level)
			low = minf(low, on)
			out["%s/average/%s" % [pillar, level]] = {"value": on, "lo": float(avg[0]), "hi": float(avg[1]), "how": "first-time win rate of the average bot, %d players" % seeds["band"]}
			out["%s/poor/%s" % [pillar, level]] = {"value": rate(cells["%s/poor" % pillar], level), "lo": poor_min, "hi": 1.0, "how": "first-time win rate of the poor bot, %d players" % seeds["band"]}
			var gap := absf(rate(cells["%s/volley" % pillar], level) - rate(cells["%s/sniper" % pillar], level))
			out["%s/fork_gap/%s" % [pillar, level]] = {"value": gap, "lo": 0.0, "hi": fork_max, "how": "Volley against Sniper, average bot, %d players each" % seeds["fork"]}
			if levels().find(level) >= feel_from:
				out["%s/fork_feel/%s" % [pillar, level]] = {"value": feel_gap(cells["%s/volley" % pillar], cells["%s/sniper" % pillar], level), "lo": feel_min, "hi": 1.0, "how": "Volley against Sniper: the larger of the gap in Keep health left and in clear time, first attempts"}
			var pressed := rate(cells["%s/average" % pillar], level, int(seeds["special"]))
			var diff := pressed - rate(never, level)
			gaps.append(diff)
			out["%s/special_gap/%s" % [pillar, level]] = {"value": diff, "lo": float(special["level_min"]), "hi": float(special["level_max"]), "how": "special pressed less never pressed (having saved up for Keeper's Habit, where the pillar has one), average bot, the same %d players" % seeds["special"]}
			if cells.has("%s/auto" % pillar):
				# The special's worth with and without the node, for the report (nothing to judge).
				out["%s/special_worth/%s/without_node" % [pillar, level]] = {"value": pressed - rate(cells["%s/no_special" % pillar], level), "lo": -1.0, "hi": 1.0, "how": "special pressed less never pressed, no Keeper's Habit"}
				out["%s/special_worth/%s/with_node" % [pillar, level]] = {"value": diff, "lo": -1.0, "hi": 1.0, "how": "special pressed less never pressed, saved up for Keeper's Habit"}
		var reach: Dictionary = bands["fork_reach"]
		var wait := fork_wait(volley, sniper, str(reach["level"]))
		if pillar == FORK_PREFER_PILLAR and str(reach["level"]) in inside and wait >= 0.0:
			out["%s/fork_reach/%s" % [pillar, reach["level"]]] = {"value": wait, "lo": 0.0, "hi": float(reach["max_runs"]), "unit": "runs", "how": "the first fork node is owned within this many runs of reaching the level, mean of the fork players (%d each side)" % seeds["fork"]}
		out["%s/floor" % pillar] = {"value": low, "lo": float(bands["first_time_floor"]), "hi": 1.0, "how": "the lowest average-bot first-time win rate over the levels judged"}
		var mean := 0.0
		for g in gaps:
			mean += g
		out["%s/special_gap/mean" % pillar] = {"value": mean / maxi(gaps.size(), 1), "lo": float(special["mean_min"]), "hi": float(special["mean_max"]), "how": "special pressed less never pressed, averaged over the levels judged"}
		var first: String = levels()[0]
		if first in inside:
			out["%s/no_special/%s" % [pillar, first]] = {"value": rate(cells["%s/no_special" % pillar], first), "lo": float(special["first_level_off_min"]), "hi": 1.0, "how": "first-time win rate of the average bot that never presses the special, %d players" % seeds["special"]}
	# Easy is judged by the poor bot (Advisor ruling, 17 Nov 2026): on the levels where it is meant to help the poor
	# bot wins clearly more often than on Normal; where it is mild it is at least as forgiving and leaves the Keep
	# healthier. Both runs are of the same players, build and seed.
	for pillar in PILLARS:
		if not bands.has("easy"):
			continue
		var easy: Dictionary = bands["easy"]
		var poor: Array = cells["%s/poor" % pillar]
		for level in scope(bands, pillar):
			var gap := rate(poor, "easy:%s" % level) - rate(poor, level)
			if level in easy["gain_levels"]:
				out["%s/easy_gain/%s" % [pillar, level]] = {"value": gap, "lo": float(easy["gain_min"]), "hi": 1.0, "how": "the poor bot's first-time win rate on Easy less on Normal, same players and builds, %d players" % seeds["band"]}
			else:
				out["%s/easy_gain/%s" % [pillar, level]] = {"value": gap, "lo": 0.0, "hi": 1.0, "how": "the poor bot's first-time win rate on Easy less on Normal: at least as forgiving, %d players" % seeds["band"]}
				out["%s/easy_keep/%s" % [pillar, level]] = {"value": easy_keep_gain(poor, level), "lo": float(easy["keep_gain_min"]), "hi": 1.0, "how": "the Keep's health left (a share of full) on Easy less on Normal, poor bot, first attempts of the same players and builds"}
	# Extreme is held to the Advisor's target (a full build wins 30 to 50% for the average bot, at most 10% for the poor
	# bot) on the level a full build is stretched by, for the pillar the bands name; every other level must stay winnable.
	if bands.has("extreme") and cells.has("%s/tree" % bands["extreme"]["pillar"]):
		var extreme: Dictionary = bands["extreme"]
		var pillar := str(extreme["pillar"])
		var rows: Array = cells["%s/tree" % pillar]
		var average_band: Array = extreme["average"]
		for level in levels():
			if level == str(extreme["level"]):
				out["%s/extreme/%s" % [pillar, level]] = {"value": extreme_rate(rows, "extreme", level), "lo": float(average_band[0]), "hi": float(average_band[1]), "how": "win rate of the average bot on the Extreme replay, from the full build, %d players of %d runs" % [seeds["tree"], extreme["judged_runs"]]}
				out["%s/extreme_poor/%s" % [pillar, level]] = {"value": extreme_rate(rows, "extreme_poor", level), "lo": 0.0, "hi": float(extreme["poor_max"]), "how": "win rate of the poor bot on the Extreme replay, from the full build, %d players of %d runs" % [seeds["tree"], extreme["judged_runs"]]}
			else:
				out["%s/extreme/%s" % [pillar, level]] = {"value": extreme_rate(rows, "extreme", level), "lo": float(extreme["winnable_min"]), "hi": 1.0, "how": "win rate of the average bot on the Extreme replay, from the full build, %d players of %d runs: it must be winnable" % [seeds["tree"], extreme["runs"]]}
	# Each cleared level's Hard replay is held to a band of its own (first attempt, the average bot).
	for pillar in PILLARS:
		if not bands.has("hard") or not cells.has("%s/hard" % pillar):
			continue
		for level in scope(bands, pillar):
			var hard_band: Array = bands["hard"][level]["average"]
			out["%s/hard/%s" % [pillar, level]] = {"value": rate(cells["%s/hard" % pillar], level), "lo": float(hard_band[0]), "hi": float(hard_band[1]), "how": "first-time win rate of the average bot on the Hard replay (%s), %d players" % [HoldfastMeta.hard_label(HoldfastContent.base(), level), seeds["hard"]]}
	for pillar in PILLARS:
		if bands.has("tree") and cells.has("%s/tree" % pillar):
			var tree: Dictionary = bands["tree"]
			var hours := 0.0
			var dry := 0
			var dry_median := 0.0
			for row in cells["%s/tree" % pillar]:
				hours += float(row["hours"])
				dry = maxi(dry, int(row["dry"]))
				dry_median = maxf(dry_median, float(row.get("dry_median", 0.0)))
			out["%s/tree/hours" % pillar] = {"value": hours / maxi(cells["%s/tree" % pillar].size(), 1), "lo": float(tree["hours_min"]), "hi": float(tree["hours_max"]), "unit": "h", "how": "hours of play until every gold node the Hero can reach is bought, average bot, mean of %d players" % seeds["tree"]}
			out["%s/tree/dry_runs" % pillar] = {"value": float(dry), "lo": 0.0, "hi": float(tree["dry_max"]), "unit": "runs", "how": "the longest run of returns to the tree with nothing affordable, average bot, worst of %d players" % seeds["tree"]}
			out["%s/tree/dry_median" % pillar] = {"value": dry_median, "lo": 0.0, "hi": float(tree["dry_median_max"]), "unit": "runs", "how": "the median wait before a purchase, in returns to the tree with nothing affordable, average bot, worst of %d players (the first hour stays quick)" % seeds["tree"]}
	var post: Dictionary = bands["one_post"]
	if str(post["level"]) in scope(bands, str(post["pillar"])):
		out["%s/one_post/%s" % [post["pillar"], post["level"]]] = {"value": rate(cells["%s/one_post" % post["pillar"]], str(post["level"])), "lo": float(post["min"]), "hi": 1.0, "how": "first-time win rate of the average bot with one post, %d players" % seeds["one_post"]}
	return out


## Judges each figure. Returns the figures with a "state" added: "met", "known miss" (a pinned
## miss no worse than its pin), or a failure: "MISSED", "WORSE than its pin", "BACK IN BAND (delete the pin)".
static func evaluate(figs: Dictionary, known_misses: Dictionary) -> Dictionary:
	var out := {}
	for key in figs:
		var fig: Dictionary = figs[key].duplicate()
		var value := float(fig["value"])
		var inside := value >= float(fig["lo"]) - 1e-9 and value <= float(fig["hi"]) + 1e-9
		if inside:
			fig["state"] = "BACK IN BAND (delete the pin)" if known_misses.has(key) else "met"
		elif not known_misses.has(key):
			fig["state"] = "MISSED"
		else:
			var pin := float(known_misses[key])
			var worse := value < pin - PIN_TOLERANCE if value < float(fig["lo"]) else value > pin + PIN_TOLERANCE
			fig["state"] = "WORSE than its pin" if worse else "known miss"
		out[key] = fig
	for key in known_misses:
		if not figs.has(key):
			out[key] = {"value": 0.0, "lo": 0.0, "hi": 0.0, "how": "", "state": "PIN FOR NO FIGURE (delete it)"}
	return out


## A figure's number in its own unit: a win rate in per cent, else hours or runs.
static func shown(fig: Dictionary, value: float) -> String:
	match str(fig.get("unit", "")):
		"h":
			return "%.1f h" % value
		"runs":
			return "%d runs" % int(value)
	return "%.0f%%" % (value * 100.0)


static func failures(judged: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key in judged:
		var fig: Dictionary = judged[key]
		if fig["state"] != "met" and fig["state"] != "known miss":
			out.append("%s: %s (%s, band %s to %s)" % [key, fig["state"], shown(fig, float(fig["value"])), shown(fig, float(fig["lo"])), shown(fig, float(fig["hi"]))])
	return out


## The report: win rates per level and pillar for both bots, then every figure that is not plainly met.
static func report(bands: Dictionary, judged: Dictionary, cells := {}) -> String:
	var lines: PackedStringArray = []
	lines.append("# Holdfast pacing bands")
	lines.append("")
	lines.append("First-time win rates over levels 1 to 5 (`content/pacing-bands.json`). A pillar is judged on the levels of its scope (`pillar_levels`); the others read \"not played by this pillar yet\" and widen when a later biome exists. A figure marked known miss is pinned: it may not get worse, and CI fails if it comes back inside its band.")
	lines.append("")
	for bot in BOTS:
		lines.append("## %s bot, first-time win rate per level" % bot.capitalize())
		lines.append("")
		lines.append("| Pillar | " + " | ".join(levels()) + " |")
		lines.append("|---|" + "---:|".repeat(levels().size()))
		for pillar in PILLARS:
			var cols: PackedStringArray = []
			for level in levels():
				if not judged.has("%s/%s/%s" % [pillar, bot, level]):
					cols.append("not played by this pillar yet")
					continue
				var fig: Dictionary = judged["%s/%s/%s" % [pillar, bot, level]]
				cols.append("%.0f%% (%.0f to %.0f)%s" % [float(fig["value"]) * 100.0, float(fig["lo"]) * 100.0, float(fig["hi"]) * 100.0, "" if fig["state"] == "met" else " " + str(fig["state"])])
			lines.append("| %s | %s |" % [pillar, " | ".join(cols)])
		lines.append("")
	lines.append("## Everything else judged")
	lines.append("")
	lines.append("| Figure | Value | Band | State | How it is measured |")
	lines.append("|---|---:|---|---|---|")
	for key in judged:
		var fig: Dictionary = judged[key]
		if key.contains("/average/") or key.contains("/poor/"):
			continue
		lines.append("| %s | %s | %s to %s | %s | %s |" % [key, shown(fig, float(fig["value"])), shown(fig, float(fig["lo"])), shown(fig, float(fig["hi"])), fig["state"], fig["how"]])
	lines.append_array(_tree_lines(cells))
	return "\n".join(lines) + "\n"


## The tree and stars table: how long a first-time player takes to the first star, the first new tower
## and the first boss, and what the stars on offer come to against what the tree costs (over the players).
static func _tree_lines(cells: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for pillar in PILLARS:
		if not cells.has("%s/tree" % pillar):
			continue
		if lines.is_empty():
			lines.append("")
			lines.append("## Tree and stars")
			lines.append("")
			lines.append("Means over the players of the tree cell who got there, in minutes of play; -1 means nobody did within the simulated time. The stars the five levels pay cannot fill the tree yet: more levels pay the rest.")
			lines.append("")
			lines.append("| Pillar | First star | First new tower | First boss | Hours to fill the gold nodes | Filled | Stars earned / tree costs |")
			lines.append("|---|---:|---:|---:|---:|---:|---:|")
		var rows: Array = cells["%s/tree" % pillar]
		var filled := rows.filter(func(row: Dictionary) -> bool: return row["filled"]).size()
		lines.append("| %s | %.0f | %.0f | %.0f | %.1f | %d of %d | %d / %d |" % [pillar, _mean(rows, "first_star"), _mean(rows, "first_tower"), _mean(rows, "first_boss"), _mean(rows, "hours"), filled, rows.size(), int(_mean(rows, "stars")), int(_mean(rows, "stars_in_tree"))])
	return lines


## The mean of `field` over the rows that have it (a negative value means never), or -1 when none do.
static func _mean(rows: Array, field: String) -> float:
	var total := 0.0
	var count := 0
	for row in rows:
		if float(row[field]) >= 0.0:
			total += float(row[field])
			count += 1
	return total / float(count) if count > 0 else -1.0
