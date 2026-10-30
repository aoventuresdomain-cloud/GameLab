extends KitTestCase
## HF-M2-01 and HF-M2-05: the pacing bands file is well formed, agrees with the pack for the
## Flare Archer, and the gate judges figures the way it says (the sweep itself runs in CI as
## tools/bands.gd; here only a one-player sweep proves every cell is played).


## Counts how often a bot asks for the Hero's special.
class AbilityCounter:
	extends SimController
	var bot: HoldfastSkilledBot
	var presses := 0

	func _init(model: Dictionary) -> void:
		bot = HoldfastSkilledBot.new(model)

	func get_input(rules: SimRules, tick: int) -> Dictionary:
		var input := bot.get_input(rules, tick)
		if input.get("ability", false):
			presses += 1
		return input


func test_the_bands_file_names_every_level_with_a_sensible_band() -> void:
	var bands := HoldfastBands.load_bands()
	expect_false(bands.is_empty(), "pacing-bands.json loads")
	expect_eq(bands["bands"].keys().size(), HoldfastBands.levels().size(), "one row for each of levels 1 to 5")
	for level in HoldfastBands.levels():
		var row: Dictionary = bands["bands"][level]
		expect_true(float(row["average"][0]) < float(row["average"][1]), "%s: the average band has room" % level)
		expect_true(float(row["average"][1]) <= 1.0 and float(row["poor_min"]) > 0.0 and float(row["poor_min"]) < float(row["average"][0]), "%s: the poor floor sits below the average band" % level)
	for key in ["seeds", "first_time_floor", "fork_gap", "special_gap", "one_post", "measure"]:
		expect_true(bands.has(key), "%s is in the file" % key)
	for fork in ["fork_gap", "special_gap", "one_post"]:
		expect_false(str(bands[fork]["how"]).is_empty(), "%s says how the simulator measures it" % fork)


func test_the_flare_archer_bands_are_the_packs_curve_bands() -> void:
	var bands := HoldfastBands.load_bands()
	var levels: Dictionary = HoldfastContent.base()["levels"]
	for level in HoldfastBands.levels():
		var curve: Dictionary = levels[level]["balance_check"]["curve"]
		expect_eq(bands["bands"][level]["average"], [float(curve["min_win_rate"]), float(curve["max_win_rate"])], "%s: the average band is the pack's" % level)
		expect_eq(float(bands["bands"][level]["poor_min"]), float(curve["poor_min_win_rate"]), "%s: the poor floor is the pack's" % level)


func test_the_fork_and_one_post_skips_are_real_nodes() -> void:
	var nodes: Dictionary = HoldfastContent.base()["upgrade_nodes"]
	var skips: Array = [HoldfastBands.ONE_POST_SKIP]
	for side in HoldfastBands.FORK_SKIPS:
		skips.append(HoldfastBands.FORK_SKIPS[side])
	for skip in skips:
		for id in skip:
			expect_true(nodes.has(id), "%s is a node" % id)
	var volley: Array = HoldfastBands.FORK_SKIPS["volley"]
	var sniper: Array = HoldfastBands.FORK_SKIPS["sniper"]
	expect_eq(volley.filter(func(id: String) -> bool: return id in sniper), [], "the two sides share no node")


func test_a_rate_counts_only_the_players_who_reached_the_level() -> void:
	var rows := [{"a": true, "b": true}, {"a": false}, {"a": true, "b": false}, {"a": true}]
	expect_eq(HoldfastBands.rate(rows, "a"), 0.75, "three wins of four")
	expect_eq(HoldfastBands.rate(rows, "b"), 0.5, "one win of the two who got there")
	expect_eq(HoldfastBands.rate(rows, "a", 2), 0.5, "the first two players only")
	expect_eq(HoldfastBands.rate(rows, "c"), 0.0, "nobody got there")


func test_the_figures_are_the_gaps_and_floors_the_bands_describe() -> void:
	var bands := HoldfastBands.load_bands()
	bands["seeds"]["special"] = 2
	var cells := {}
	for pillar in HoldfastBands.PILLARS:
		for cell in ["average", "poor", "volley", "sniper", "no_special"]:
			cells["%s/%s" % [pillar, cell]] = []
	# One row per player over all the levels. The second player loses the last level; the third and
	# fourth reach every level and lose it.
	var all := {}
	var all_off := {}
	var lost_last := {}
	var lost_all := {}
	var last: String = HoldfastBands.levels()[-1]
	for level in HoldfastBands.levels():
		all[level] = true
		all_off[level] = false
		lost_last[level] = level != last
		lost_all[level] = false
	cells["flare_archer/average"] = [all, lost_last, lost_all, lost_all]
	cells["flare_archer/no_special"] = [all_off, all]
	cells["flare_archer/volley"] = [all]
	cells["flare_archer/sniper"] = [all_off]
	cells["dusk_mage/volley"] = [all_off]
	cells["dusk_mage/sniper"] = [all]
	cells["dusk_mage/one_post"] = [{"shingle_beach": true}, {"shingle_beach": false}]
	var figs := HoldfastBands.figures(bands, cells)
	var level: String = HoldfastBands.levels()[0]
	expect_eq(figs["flare_archer/average/%s" % level]["value"], 0.5, "the rate over the players who got there")
	expect_eq(figs["flare_archer/average/%s" % last]["value"], 0.25, "the last level is won by one in four")
	expect_eq(figs["flare_archer/fork_gap/%s" % level]["value"], 1.0, "Volley won, Sniper lost: the whole gap")
	expect_eq(figs["dusk_mage/fork_gap/%s" % level]["value"], 1.0, "Sniper ahead is the same gap")
	expect_eq(figs["flare_archer/special_gap/%s" % level]["value"], 0.5, "special on (the first two players, 100%) less off (50%)")
	expect_eq(figs["flare_archer/special_gap/%s" % last]["value"], 0.0, "special on (the first two players, 50%) less off (50%)")
	expect_eq(figs["flare_archer/special_gap/mean"]["value"], 0.4, "the mean over the five levels")
	expect_eq(figs["flare_archer/floor"]["value"], 0.25, "the lowest level rate")
	expect_eq(figs["dusk_mage/one_post/shingle_beach"]["value"], 0.5, "the one-post rate")
	expect_eq(figs["dusk_mage/average/%s" % level]["value"], 0.0, "nobody reached the level")
	expect_eq(figs.size(), 3 * (5 * 4 + 2) + 1, "every pillar has 4 figures a level, a floor and a mean gap, plus the one-post figure")
	# Each figure is held to the bound the file states for it.
	expect_eq([figs["flare_archer/fork_gap/%s" % level]["lo"], figs["flare_archer/fork_gap/%s" % level]["hi"]], [0.0, float(bands["fork_gap"]["max"])], "the fork gap bound")
	expect_eq([figs["flare_archer/special_gap/mean"]["lo"], figs["flare_archer/special_gap/mean"]["hi"]], [float(bands["special_gap"]["mean_min"]), float(bands["special_gap"]["mean_max"])], "the mean special gap bound")
	expect_eq([figs["flare_archer/special_gap/%s" % level]["lo"], figs["flare_archer/special_gap/%s" % level]["hi"]], [float(bands["special_gap"]["level_min"]), float(bands["special_gap"]["level_max"])], "the special gap bound on a level")
	expect_eq(figs["flare_archer/floor"]["lo"], float(bands["first_time_floor"]), "the floor bound")
	expect_eq(figs["flare_archer/poor/%s" % level]["lo"], float(bands["bands"][level]["poor_min"]), "the poor bot's floor")
	expect_eq(figs["flare_archer/average/%s" % level]["hi"], float(bands["bands"][level]["average"][1]), "the average band's top")


func test_a_band_is_met_missed_or_pinned() -> void:
	var figs := {
		"in": {"value": 0.5, "lo": 0.4, "hi": 0.6},
		"low": {"value": 0.3, "lo": 0.4, "hi": 0.6},
		"high": {"value": 0.9, "lo": 0.4, "hi": 0.6},
		"pinned_low": {"value": 0.3, "lo": 0.4, "hi": 0.6},
		"pinned_high": {"value": 0.9, "lo": 0.4, "hi": 0.6},
		"worse_low": {"value": 0.2, "lo": 0.4, "hi": 0.6},
		"worse_high": {"value": 0.95, "lo": 0.4, "hi": 0.6},
		"recovered": {"value": 0.5, "lo": 0.4, "hi": 0.6},
		"edge": {"value": 0.4, "lo": 0.4, "hi": 0.6},
	}
	var pins := {"pinned_low": 0.3, "pinned_high": 0.9, "worse_low": 0.3, "worse_high": 0.9, "recovered": 0.3, "gone": 0.1}
	var judged := HoldfastBands.evaluate(figs, pins)
	expect_eq(judged["in"]["state"], "met", "inside the band")
	expect_eq(judged["edge"]["state"], "met", "the band's edge is inside it")
	expect_eq(judged["low"]["state"], "MISSED", "below the band with no pin")
	expect_eq(judged["high"]["state"], "MISSED", "above the band with no pin")
	expect_eq(judged["pinned_low"]["state"], "known miss", "pinned and no worse")
	expect_eq(judged["pinned_high"]["state"], "known miss", "pinned above and no worse")
	expect_eq(judged["worse_low"]["state"], "WORSE than its pin", "further below than the pin")
	expect_eq(judged["worse_high"]["state"], "WORSE than its pin", "further above than the pin")
	expect_eq(judged["recovered"]["state"], "BACK IN BAND (delete the pin)", "a pin on a figure that is now fine")
	expect_eq(judged["gone"]["state"], "PIN FOR NO FIGURE (delete it)", "a pin for nothing")
	var failures := HoldfastBands.failures(judged)
	expect_eq(failures.size(), 6, "low, high, both worse, recovered and gone fail; the rest pass")
	expect_true(failures[0].begins_with("low: MISSED"), "a failure names the figure and what happened")


func test_the_report_shows_every_pillar_and_level_for_both_bots() -> void:
	var bands := HoldfastBands.load_bands()
	var cells := {}
	for pillar in HoldfastBands.PILLARS:
		for cell in ["average", "poor", "volley", "sniper", "no_special"]:
			cells["%s/%s" % [pillar, cell]] = [{}]
	cells["dusk_mage/one_post"] = [{}]
	var text := HoldfastBands.report(bands, HoldfastBands.evaluate(HoldfastBands.figures(bands, cells), {}))
	for pillar in HoldfastBands.PILLARS:
		expect_true(text.contains("| %s |" % pillar), "%s has a row" % pillar)
	for bot in HoldfastBands.BOTS:
		expect_true(text.contains("## %s bot" % bot.capitalize()), "%s has a table" % bot)
	for level in HoldfastBands.levels():
		expect_true(text.contains(level), "%s is in the report" % level)
	expect_true(text.contains("MISSED"), "a missed band is marked in the report")


func test_the_no_special_bot_never_presses_the_special_and_the_average_bot_does() -> void:
	var content := HoldfastContent.base()
	var level: String = HoldfastBands.levels()[1]
	var config := HoldfastContent.run_config(level, [], content, "flare_archer", null, {}, [], false, false)
	var average := AbilityCounter.new(HoldfastSkilledBot.AVERAGE)
	SimBotRunner.run(HoldfastRules.new(), average, 1, config, 20000, HoldfastRules.TICK_RATE)
	var off := AbilityCounter.new(HoldfastSkilledBot.AVERAGE_NO_SPECIAL)
	SimBotRunner.run(HoldfastRules.new(), off, 1, config, 20000, HoldfastRules.TICK_RATE)
	expect_true(average.presses > 0, "the average bot uses its special")
	expect_eq(off.presses, 0, "the no-special bot never does")


func test_one_player_of_every_cell_is_played() -> void:
	var bands := HoldfastBands.load_bands()
	for key in bands["seeds"]:
		bands["seeds"][key] = 1
	var cells := HoldfastBands.measure(bands)
	expect_eq(cells.size(), 3 * 5 + 1, "five cells for each pillar (two bots, two fork sides, no special) and the one-post cell")
	for name in cells:
		expect_eq(cells[name].size(), 1, "%s: one climb" % name)
		expect_true(cells[name][0].has(HoldfastBands.levels()[0]), "%s: the climb played level 1" % name)
	expect_true(cells.has("dusk_mage/one_post"), "the one-post cell is the one the bands name")
