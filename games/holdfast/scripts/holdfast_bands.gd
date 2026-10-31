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


static func load_bands() -> Dictionary:
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## The level ids in play order, without the tutorial.
static func levels() -> Array:
	return HoldfastCurve._levels(HoldfastContent.base())


## The levels a pillar is judged on: the pack's `pillar_levels` entry, or every level. A pillar is
## tuned to the biomes it unlocks into, so it is judged only there. Widen the scope when a later biome
## exists; the gate fails if a pillar's scope is empty or names a level that does not exist.
static func scope(bands: Dictionary, pillar: String) -> Array:
	var named: Variant = bands.get("pillar_levels", {}).get(pillar)
	if named is Array:
		return named.filter(func(level: Variant) -> bool: return level in levels())
	return levels()


## The levels a pillar is not judged on (shown in the report as not played by it yet).
static func out_of_scope(bands: Dictionary, pillar: String) -> Array:
	var inside := scope(bands, pillar)
	return levels().filter(func(level: String) -> bool: return not inside.has(level))


## Problems with the bands file itself: a pillar judged on nothing, or on a level that is not there.
static func scope_problems(bands: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for pillar in PILLARS:
		var named: Variant = bands.get("pillar_levels", {}).get(pillar)
		if named is Array:
			for level in named:
				if not levels().has(level):
					out.append("%s is judged on %s, which is not a level" % [pillar, level])
		if scope(bands, pillar).is_empty():
			out.append("%s is judged on no level at all" % pillar)
	return out


## One cell of the sweep: the climbs of seeds 1..`seeds`, as one {level: won first time} per seed
## (a level the climb never reached is left out), with how its first attempt felt under the FEEL key.
static func cell(model: Dictionary, pillar: String, seeds: int, skip: Array = [], prefer: Array = []) -> Array:
	var out := []
	for run_seed in range(1, seeds + 1):
		var row := {FEEL: {}}
		var climb := HoldfastCurve.climb(run_seed, model, pillar, 5, skip, true, prefer)
		for id in climb["levels"]:
			row[id] = climb["levels"][id]["first"]
			row[FEEL][id] = {"keep": climb["levels"][id]["keep"], "seconds": climb["levels"][id]["seconds"]}
		out.append(row)
	return out


## The Hard cell: the climbs of seeds 1..`seeds`, as one {level: won its Hard replay first time} per seed. A player
## plays each level's Hard replay once, right after clearing the level; a level never cleared is left out.
static func hard_cell(pillar: String, seeds: int) -> Array:
	var out := []
	for run_seed in range(1, seeds + 1):
		var row := {}
		var climb := HoldfastCurve.climb(run_seed, HoldfastSkilledBot.AVERAGE, pillar, 5, [], false, [], true)
		for id in climb["levels"]:
			if climb["levels"][id].has("hard"):
				row[id] = climb["levels"][id]["hard"]
		out.append(row)
	return out


## Plays every cell the bands ask for. Returns {cell name: climbs}.
static func measure(bands: Dictionary) -> Dictionary:
	var seeds: Dictionary = bands["seeds"]
	var out := {}
	for pillar in PILLARS:
		for bot in BOTS:
			out["%s/%s" % [pillar, bot]] = cell(BOTS[bot], pillar, int(seeds["band"]))
		for side in FORK_SKIPS:
			out["%s/%s" % [pillar, side]] = cell(HoldfastSkilledBot.AVERAGE, pillar, int(seeds["fork"]), FORK_SKIPS[side] + auto_nodes(), FORK_PREFER[side] if pillar == FORK_PREFER_PILLAR else [])
		out["%s/no_special" % pillar] = cell(HoldfastSkilledBot.AVERAGE_NO_SPECIAL, pillar, int(seeds["special"]), auto_nodes())
		if bands.has("hard"):
			out["%s/hard" % pillar] = hard_cell(pillar, int(seeds["hard"]))
		if _has_auto_node(pillar):
			out["%s/auto" % pillar] = cell(HoldfastSkilledBot.AVERAGE_NO_SPECIAL, pillar, int(seeds["special"]), [], auto_chain())
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


## Every figure the bands judge, as {key: {"value", "lo", "hi", "how"}}. A pillar is judged on its scope.
static func figures(bands: Dictionary, cells: Dictionary) -> Dictionary:
	var out := {}
	var seeds: Dictionary = bands["seeds"]
	var fork_max := float(bands["fork_gap"]["max"])
	var feel_min := float(bands["fork_feel"]["min"])
	var feel_from: int = maxi(levels().find(str(bands["fork_feel"].get("first_level", ""))), 0)
	var special: Dictionary = bands["special_gap"]
	for pillar in PILLARS:
		var inside := scope(bands, pillar)
		var low := 1.0
		var gaps := []
		var never: Array = cells.get("%s/auto" % pillar, cells["%s/no_special" % pillar])
		for level in inside:
			var avg: Array = bands["bands"][level]["average"]
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
		out["%s/floor" % pillar] = {"value": low, "lo": float(bands["first_time_floor"]), "hi": 1.0, "how": "the lowest average-bot first-time win rate over the levels judged"}
		var mean := 0.0
		for g in gaps:
			mean += g
		out["%s/special_gap/mean" % pillar] = {"value": mean / maxi(gaps.size(), 1), "lo": float(special["mean_min"]), "hi": float(special["mean_max"]), "how": "special pressed less never pressed, averaged over the levels judged"}
		var first: String = levels()[0]
		if first in inside:
			out["%s/no_special/%s" % [pillar, first]] = {"value": rate(cells["%s/no_special" % pillar], first), "lo": float(special["first_level_off_min"]), "hi": 1.0, "how": "first-time win rate of the average bot that never presses the special, %d players" % seeds["special"]}
	# Each cleared level's Hard replay is held to a band of its own (first attempt, the average bot).
	for pillar in PILLARS:
		if not bands.has("hard") or not cells.has("%s/hard" % pillar):
			continue
		for level in scope(bands, pillar):
			var hard_band: Array = bands["hard"][level]["average"]
			out["%s/hard/%s" % [pillar, level]] = {"value": rate(cells["%s/hard" % pillar], level), "lo": float(hard_band[0]), "hi": float(hard_band[1]), "how": "first-time win rate of the average bot on the Hard replay (%s), %d players" % [HoldfastMeta.hard_label(HoldfastContent.base(), level), seeds["hard"]]}
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


static func failures(judged: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key in judged:
		var fig: Dictionary = judged[key]
		if fig["state"] != "met" and fig["state"] != "known miss":
			out.append("%s: %s (%.0f%%, band %.0f%% to %.0f%%)" % [key, fig["state"], float(fig["value"]) * 100.0, float(fig["lo"]) * 100.0, float(fig["hi"]) * 100.0])
	return out


## The report: win rates per level and pillar for both bots, then every figure that is not plainly met.
static func report(bands: Dictionary, judged: Dictionary) -> String:
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
		lines.append("| %s | %.0f%% | %.0f%% to %.0f%% | %s | %s |" % [key, float(fig["value"]) * 100.0, float(fig["lo"]) * 100.0, float(fig["hi"]) * 100.0, fig["state"], fig["how"]])
	return "\n".join(lines) + "\n"
