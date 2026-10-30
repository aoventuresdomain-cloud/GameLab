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
## One post at a time: the second castle slot is never bought.
const ONE_POST_SKIP := ["castle_slot_2"]
## Pins are written to four places; a rate is a whole number of players, so a real change is far bigger.
const PIN_TOLERANCE := 0.0001


static func load_bands() -> Dictionary:
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## The level ids in play order, without the tutorial.
static func levels() -> Array:
	return HoldfastCurve._levels(HoldfastContent.base())


## One cell of the sweep: the climbs of seeds 1..`seeds`, as one {level: won first time} per seed
## (a level the climb never reached is left out).
static func cell(model: Dictionary, pillar: String, seeds: int, skip: Array = []) -> Array:
	var out := []
	for run_seed in range(1, seeds + 1):
		var row := {}
		var climb := HoldfastCurve.climb(run_seed, model, pillar, 5, skip)
		for id in climb["levels"]:
			row[id] = climb["levels"][id]["first"]
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
			out["%s/%s" % [pillar, side]] = cell(HoldfastSkilledBot.AVERAGE, pillar, int(seeds["fork"]), FORK_SKIPS[side])
		out["%s/no_special" % pillar] = cell(HoldfastSkilledBot.AVERAGE_NO_SPECIAL, pillar, int(seeds["special"]))
	var one_post: Dictionary = bands["one_post"]
	out["%s/one_post" % one_post["pillar"]] = cell(HoldfastSkilledBot.AVERAGE, str(one_post["pillar"]), int(seeds["one_post"]), ONE_POST_SKIP)
	return out


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


## Every figure the bands judge, as {key: {"value", "lo", "hi", "how"}}.
static func figures(bands: Dictionary, cells: Dictionary) -> Dictionary:
	var out := {}
	var seeds: Dictionary = bands["seeds"]
	var fork_max := float(bands["fork_gap"]["max"])
	var special: Dictionary = bands["special_gap"]
	for pillar in PILLARS:
		var low := 1.0
		var gaps := []
		for level in levels():
			var avg: Array = bands["bands"][level]["average"]
			var poor_min := float(bands["bands"][level]["poor_min"])
			var on := rate(cells["%s/average" % pillar], level)
			low = minf(low, on)
			out["%s/average/%s" % [pillar, level]] = {"value": on, "lo": float(avg[0]), "hi": float(avg[1]), "how": "first-time win rate of the average bot, %d players" % seeds["band"]}
			out["%s/poor/%s" % [pillar, level]] = {"value": rate(cells["%s/poor" % pillar], level), "lo": poor_min, "hi": 1.0, "how": "first-time win rate of the poor bot, %d players" % seeds["band"]}
			var gap := absf(rate(cells["%s/volley" % pillar], level) - rate(cells["%s/sniper" % pillar], level))
			out["%s/fork_gap/%s" % [pillar, level]] = {"value": gap, "lo": 0.0, "hi": fork_max, "how": "Volley against Sniper, average bot, %d players each" % seeds["fork"]}
			var diff := rate(cells["%s/average" % pillar], level, int(seeds["special"])) - rate(cells["%s/no_special" % pillar], level)
			gaps.append(diff)
			out["%s/special_gap/%s" % [pillar, level]] = {"value": diff, "lo": float(special["level_min"]), "hi": float(special["level_max"]), "how": "special on less special off, average bot, the same %d players" % seeds["special"]}
		out["%s/floor" % pillar] = {"value": low, "lo": float(bands["first_time_floor"]), "hi": 1.0, "how": "the lowest average-bot first-time win rate over levels 1 to 5"}
		var mean := 0.0
		for g in gaps:
			mean += g
		out["%s/special_gap/mean" % pillar] = {"value": mean / gaps.size(), "lo": float(special["mean_min"]), "hi": float(special["mean_max"]), "how": "special on less special off, averaged over levels 1 to 5"}
	var post: Dictionary = bands["one_post"]
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
	lines.append("First-time win rates over levels 1 to 5 (`content/pacing-bands.json`). A figure marked known miss is pinned: it may not get worse, and CI fails if it comes back inside its band.")
	lines.append("")
	for bot in BOTS:
		lines.append("## %s bot, first-time win rate per level" % bot.capitalize())
		lines.append("")
		lines.append("| Pillar | " + " | ".join(levels()) + " |")
		lines.append("|---|" + "---:|".repeat(levels().size()))
		for pillar in PILLARS:
			var cols: PackedStringArray = []
			for level in levels():
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
