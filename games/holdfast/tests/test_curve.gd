extends KitTestCase
## HF-M2-35: the early levels are tuned for the empty-castle start. HoldfastCurve plays a
## first-time Flare Archer who spends stars and gold between runs, wears the gear found and
## places Archers and the Mage; each level's first-attempt win rate sits inside its pack band
## (`balance_check.curve`, from the Advisor's targets about 90, 75, 60, 50 and 50 per cent).


func _levels() -> Array:
	var out := []
	var levels: Dictionary = HoldfastContent.base()["levels"]
	for id in levels:
		if not levels[id].get("tutorial", false):
			out.append(id)
	return out


func _rates(model: Dictionary, seeds: int, skip: Array = []) -> Dictionary:
	var won := {}
	var reached := {}
	var cleared := 0
	var worst_dry := 0
	for run_seed in range(1, seeds + 1):
		var climb := HoldfastCurve.climb(run_seed, model, "flare_archer", 5, skip)
		worst_dry = maxi(worst_dry, int(climb["dry_runs"]))
		var all := true
		for id in climb["levels"]:
			reached[id] = int(reached.get(id, 0)) + 1
			won[id] = int(won.get(id, 0)) + (1 if climb["levels"][id]["first"] else 0)
			all = all and climb["levels"][id]["cleared"]
		cleared += 1 if all and climb["levels"].size() == _levels().size() else 0
	return {"won": won, "reached": reached, "cleared": cleared, "dry": worst_dry}


func test_each_early_level_is_won_first_time_at_the_rate_the_pack_sets() -> void:
	var levels: Dictionary = HoldfastContent.base()["levels"]
	var seeds := 0
	for id in _levels():
		seeds = maxi(seeds, int(levels[id]["balance_check"]["curve"]["seeds"]))
	var average := _rates(HoldfastSkilledBot.AVERAGE, seeds)
	for id in _levels():
		var band: Dictionary = levels[id]["balance_check"]["curve"]
		expect_true(int(average["reached"].get(id, 0)) >= seeds / 2, "%s: only %d of %d players got this far" % [id, average["reached"].get(id, 0), seeds])
		var rate := float(average["won"].get(id, 0)) / maxf(float(average["reached"].get(id, 0)), 1.0)
		expect_true(rate >= float(band["min_win_rate"]), "%s: won first time %.0f%%, the band starts at %.0f%%" % [id, rate * 100.0, float(band["min_win_rate"]) * 100.0])
		expect_true(rate <= float(band["max_win_rate"]), "%s: won first time %.0f%%, the band ends at %.0f%%" % [id, rate * 100.0, float(band["max_win_rate"]) * 100.0])
	expect_eq(average["cleared"], seeds, "every player reaches Level 5, within 8 attempts at each level")
	expect_true(average["dry"] <= 3, "a player went %d runs without anything new to buy" % average["dry"])


func test_a_poor_player_keeps_the_floor_the_pack_sets() -> void:
	# The poor bot reacts about a third as fast and holds its ability back; half the seeds is enough for a floor.
	var levels: Dictionary = HoldfastContent.base()["levels"]
	var poor := _rates(HoldfastSkilledBot.POOR, 12)
	for id in _levels():
		var rate := float(poor["won"].get(id, 0)) / maxf(float(poor["reached"].get(id, 0)), 1.0)
		expect_true(poor["reached"].get(id, 0) > 0, "%s: no poor player got this far" % id)
		expect_true(rate >= float(levels[id]["balance_check"]["curve"]["poor_min_win_rate"]), "%s: the poor bot won first time %.0f%%, below its floor" % [id, rate * 100.0])


func test_each_side_of_the_archer_fork_reaches_level_five() -> void:
	var forks := {"scope": ["post_twin", "post_burst", "post_storm"], "twin": ["post_scope", "post_marksman", "post_piercing"]}
	for fork in forks:
		var result := _rates(HoldfastSkilledBot.AVERAGE, 6, forks[fork])
		expect_eq(result["cleared"], 6, "the %s side: every player reaches Level 5" % fork)


func test_the_bot_only_offers_a_gate_once_it_owns_enough_nodes() -> void:
	var nodes := {
		"a": {"id": "a", "cost": 1},
		"x": {"id": "x", "cost": 5},
		"y": {"id": "y", "cost": 5},
		"gate": {"id": "gate", "cost": 1, "requires": ["a"], "needs_nodes": 3},
	}
	expect_eq(HoldfastProgression.buy_cheapest(nodes, ["a"], 1), [], "one node owned: the gate waits")
	expect_eq(HoldfastProgression.buy_cheapest(nodes, ["a", "x", "y"], 1), ["gate"], "three owned: it is offered")


func test_a_player_with_nothing_to_buy_is_counted_as_dry() -> void:
	# Only the first slot and the Archer Post are bought, so there is a post to play with and then nothing.
	var skip: Array = HoldfastContent.base()["upgrade_nodes"].keys().filter(func(id: String) -> bool: return not id in ["castle_slot_1", "castle_archer_1"])
	var climb := HoldfastCurve.climb(1, HoldfastSkilledBot.AVERAGE, "flare_archer", 5, skip)
	expect_true(climb["dry_runs"] >= 3, "every run came with nothing to buy: %d" % climb["dry_runs"])


func test_the_curve_is_deterministic_and_wins_move_the_player_on() -> void:
	var a := HoldfastCurve.climb(3, HoldfastSkilledBot.AVERAGE)
	var b := HoldfastCurve.climb(3, HoldfastSkilledBot.AVERAGE)
	expect_eq(a, b, "the same seed gives the same climb")
	expect_true(a["runs"] >= a["levels"].size(), "at least one run for each level reached")


func test_the_curve_bot_places_a_mage_once_it_has_taken_the_gate() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile["pillar"] = "flare_archer"
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	var avoid := HoldfastProgression.other_hero_nodes(content["upgrade_nodes"], "flare_archer")
	var layout := []
	for round in 40:
		for bought in HoldfastProgression.buy_for_profile(content, profile, avoid):
			profile = bought["profile"]
		profile["gold"] = int(profile["gold"]) + 400
		profile["stars"]["outpost"] = 3
		profile["stars"]["shingle_beach"] = 3
		profile["stars"]["tidewrack_cove"] = 3
		profile["stars"]["old_pier"] = 3
		profile["stars"]["gull_rock"] = 3
		profile["unlocked"] = ["shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]
		layout = HoldfastMeta.layout_for(content, profile, "tidewrack_cove")
		if "gate_mage" in profile["upgrades"]:
			break
	expect_true("gate_mage" in profile["upgrades"], "the bot takes the gate once it has five nodes")
	var mages := 0
	for entry in layout:
		mages += 1 if ":" in str(entry) else 0
	expect_eq(mages, 1, "and the layout it plays has the Mage")


func test_the_curve_band_schema_refuses_nonsense() -> void:
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var level: Dictionary = HoldfastContent.base()["levels"]["outpost"].duplicate(true)
	for bad in [{"seeds": 0, "min_win_rate": 0.5, "max_win_rate": 1.0, "poor_min_win_rate": 0.2}, {"seeds": 5, "min_win_rate": -0.1, "max_win_rate": 1.0, "poor_min_win_rate": 0.2}, {"seeds": 5, "min_win_rate": 0.5, "max_win_rate": 1.5, "poor_min_win_rate": 0.2}, {"seeds": 5, "min_win_rate": 0.5, "max_win_rate": 1.0}]:
		level["balance_check"]["curve"] = bad
		var errors: PackedStringArray = []
		schema.validate_def(level, "level", "levels.json: $", errors, [])
		expect_false(errors.is_empty(), "refused: " + str(bad))
