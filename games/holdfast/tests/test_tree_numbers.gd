extends KitTestCase
## HF-M2-68: the pacing gate measures the tree and the stars: hours to fill the tree, the longest
## run of returns with nothing affordable, and the first star, new tower and boss.


func _row(hours: float, dry: int, filled := true) -> Dictionary:
	return {"hours": hours, "filled": filled, "dry": dry, "first_star": 4.0, "first_tower": 30.0, "first_boss": -1.0, "stars": 17, "stars_in_tree": 44}


func _cells(rows: Array) -> Dictionary:
	var cells := {}
	for pillar in HoldfastBands.PILLARS:
		for cell in ["average", "poor", "volley", "sniper", "no_special"]:
			cells["%s/%s" % [pillar, cell]] = [{}]
		cells["%s/tree" % pillar] = rows
	return cells


func _tree_figures(rows: Array) -> Dictionary:
	var bands := HoldfastBands.load_bands()
	return HoldfastBands.figures(bands, _cells(rows))


## The failures that are about the tree: the other cells of these tests are empty and miss their own bands.
func _tree_failures(judged: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for failure in HoldfastBands.failures(judged):
		if failure.contains("/tree/"):
			out.append(failure)
	return out


func test_the_bands_file_states_the_tree_band_and_the_dry_run_limit() -> void:
	var tree: Dictionary = HoldfastBands.load_bands()["tree"]
	expect_eq([float(tree["hours_min"]), float(tree["hours_max"])], [3.0, 4.0], "3 to 4 hours to fill the tree")
	expect_eq(int(tree["dry_max"]), 3, "never more than 3 dry runs in a row")
	expect_false(str(tree["how"]).is_empty(), "it says how the simulator measures it")
	expect_true(HoldfastBands.load_bands()["seeds"].has("tree"), "and how many players")


func test_the_figures_are_the_mean_hours_and_the_worst_dry_run() -> void:
	var figs := _tree_figures([_row(3.0, 1), _row(4.0, 3)])
	var hours: Dictionary = figs["flare_archer/tree/hours"]
	expect_eq(hours["value"], 3.5, "the mean of the players")
	expect_eq([hours["lo"], hours["hi"]], [3.0, 4.0], "held to the band in the file")
	var dry: Dictionary = figs["dusk_mage/tree/dry_runs"]
	expect_eq(dry["value"], 3.0, "the worst of the players")
	expect_eq([dry["lo"], dry["hi"]], [0.0, 3.0], "never more than 3")
	for pillar in HoldfastBands.PILLARS:
		expect_true(figs.has("%s/tree/hours" % pillar) and figs.has("%s/tree/dry_runs" % pillar), "%s has both figures" % pillar)


func test_a_pillar_with_no_tree_cell_has_no_tree_figures() -> void:
	var bands := HoldfastBands.load_bands()
	var cells := _cells([_row(12.0, 1)])
	cells.erase("tideblade/tree")
	var figs := HoldfastBands.figures(bands, cells)
	expect_false(figs.has("tideblade/tree/hours"), "nothing was measured for it")
	expect_true(figs.has("flare_archer/tree/hours"), "the others are judged")


func test_a_tree_that_fills_too_fast_or_too_slow_fails_the_gate() -> void:
	for hours in [0.7, 2.9, 4.1, 16.0]:
		var judged := HoldfastBands.evaluate(_tree_figures([_row(hours, 0)]), {})
		var failures := _tree_failures(judged)
		expect_true(judged["flare_archer/tree/hours"]["state"] == "MISSED", "%.1f hours is outside 3 to 4" % hours)
		expect_true(failures[0].contains("tree/hours: MISSED") and failures[0].contains(" h, band 3.0 h to 4.0 h"), "the failure names the figure in hours: %s" % failures[0])
	var inside := HoldfastBands.evaluate(_tree_figures([_row(3.5, 0)]), {})
	expect_eq(_tree_failures(inside), PackedStringArray(), "3.5 hours and no dry run passes")


func test_more_than_three_dry_runs_in_a_row_fails_the_gate() -> void:
	var judged := HoldfastBands.evaluate(_tree_figures([_row(3.5, 2), _row(3.5, 4)]), {})
	expect_eq(judged["flare_archer/tree/dry_runs"]["state"], "MISSED", "four in a row is one too many")
	var failures := _tree_failures(judged)
	expect_eq(failures.size(), 3, "all three pillars")
	expect_true(failures[0].contains("tree/dry_runs: MISSED") and failures[0].contains("4 runs, band 0 runs to 3 runs"), "the failure counts runs: %s" % failures[0])
	expect_eq(HoldfastBands.evaluate(_tree_figures([_row(3.5, 3)]), {})["flare_archer/tree/dry_runs"]["state"], "met", "three is allowed")


func test_a_pinned_tree_miss_may_not_get_worse_or_come_back_in_band() -> void:
	var pins := {"flare_archer/tree/hours": 0.7, "dusk_mage/tree/hours": 0.7, "tideblade/tree/hours": 0.7}
	expect_eq(HoldfastBands.evaluate(_tree_figures([_row(0.7, 0)]), pins)["flare_archer/tree/hours"]["state"], "known miss", "as pinned")
	expect_eq(HoldfastBands.evaluate(_tree_figures([_row(0.5, 0)]), pins)["flare_archer/tree/hours"]["state"], "WORSE than its pin", "a tree that fills even faster")
	expect_eq(HoldfastBands.evaluate(_tree_figures([_row(3.5, 0)]), pins)["flare_archer/tree/hours"]["state"], "BACK IN BAND (delete the pin)", "back in the band")


func test_the_report_has_a_tree_and_stars_table() -> void:
	var bands := HoldfastBands.load_bands()
	var cells := _cells([_row(3.0, 2), _row(4.0, 1, false)])
	var judged := HoldfastBands.evaluate(HoldfastBands.figures(bands, cells), {})
	var text := HoldfastBands.report(bands, judged, cells)
	expect_true(text.contains("## Tree and stars"), "the section is there")
	expect_true(text.contains("| flare_archer | 4 | 30 | -1 | 3.5 | 1 of 2 | 17 / 44 |"), "minutes to the first star and new tower, nobody reached a boss, mean hours, how many filled, stars against the tree's price")
	expect_true(text.contains("| 3.5 h | 3.0 h to 4.0 h |") and text.contains("| 2 runs | 0 runs to 3 runs |"), "the judged figures are in hours and runs, not per cent")
	expect_false(HoldfastBands.report(bands, judged).contains("## Tree and stars"), "no table without a tree cell")


func test_the_tree_cell_summarises_a_progression_per_player() -> void:
	var rows := HoldfastBands.tree_cell("dusk_mage", 1, 0.3)
	expect_eq(rows.size(), 1, "one player")
	var row: Dictionary = rows[0]
	expect_false(row["filled"], "twenty minutes cannot fill the tree")
	expect_true(float(row["hours"]) >= 0.3, "an unfilled tree reports the whole time played")
	expect_true(float(row["first_star"]) > 0.0, "a first star was earned on the first level")
	expect_true(int(row["stars_in_tree"]) > int(row["stars"]), "the tree costs more stars than the player has")


func test_a_progression_reports_when_the_tree_filled_and_its_firsts() -> void:
	var report := HoldfastProgression.play(1, 3.0)
	var filled := float(report["filled_at"])
	expect_true(filled > 0.0 and filled <= float(report["sim_seconds"]), "the tree filled within the time (%.0f s)" % filled)
	expect_eq(report["upgrades_owned"], report["upgrades_total"], "and every node the Hero can reach is bought")
	expect_true(float(report["first_star_at"]) > 0.0, "first star at %.0f s" % float(report["first_star_at"]))
	expect_true(float(report["first_new_tower_at"]) >= 0.0, "the Tower Gate was bought")
	expect_true(float(report["first_boss_at"]) > 0.0, "and a boss won")
	expect_true(int(report["dry_runs"]) >= 0 and int(report["dry_runs"]) <= int(report["runs_played"]), "the dry run streak is a count of runs")
	expect_true(int(report["stars_earned"]) <= int(report["stars_in_tree"]), "five levels cannot pay the whole tree")


func test_a_progression_that_runs_out_of_time_says_it_never_filled() -> void:
	var report := HoldfastProgression.play(1, 0.05)
	expect_eq(report["filled_at"], -1.0, "not filled")
	expect_eq(report["first_boss_at"], -1.0, "no boss yet")


func test_a_progression_can_play_another_hero_with_a_skilled_bot() -> void:
	var a := HoldfastProgression.play(2, 0.2, "", [], "tideblade", HoldfastSkilledBot.AVERAGE)
	var b := HoldfastProgression.play(2, 0.2, "", [], "tideblade", HoldfastSkilledBot.AVERAGE)
	expect_eq(a["hash"], b["hash"], "deterministic")
	expect_true(a["runs_played"] > 0, "it plays")
	expect_eq(HoldfastProgression.has_boss(HoldfastContent.base(), "gull_rock"), true, "Gull Rock ends on a boss")
	expect_eq(HoldfastProgression.has_boss(HoldfastContent.base(), "outpost"), false, "Outpost has none")
