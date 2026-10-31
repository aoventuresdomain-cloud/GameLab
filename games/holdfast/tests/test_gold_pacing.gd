extends KitTestCase
## HF-M2-70: node gold prices follow the pack's tier table (priced from the gold a run pays where each tier
## opens), the Tithe chain is additive and capped, and a gear drop with nothing left to give is salvaged for
## about one run's gold and said on the result panel (F-149).

const Main := preload("res://scenes/main.tscn")
const Hud = preload("res://scripts/ui/hud.gd")
const DT := 1.0 / HoldfastRules.TICK_RATE
const DROPS := ["tarred_bowstring", "driftwood_stave", "beacon_visor", "sea_glass_charm", "barnacle_plate", "kelp_sandals", "lamp_oil_flask"]
const TITHE := ["tithe_1", "tithe_2", "tithe_3", "tithe_4", "tithe_5", "tithe_6"]
## The first purchases of the first three runs: their prices are not touched.
const FIRST_BUYS := {"keep_walls_1": 60, "post_timbers": 70, "flare_hide": 80, "flare_boots": 90, "post_drills": 110, "flare_focus": 120, "post_sight": 120, "post_rate": 160, "tithe_1": 160, "flare_habit": 300}


func _content() -> Dictionary:
	return HoldfastContent.base()


func _tiers() -> Array:
	var out: Array = _content()["gold_tiers"].values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["first_level"]) < int(b["first_level"]))
	return out


# ------------------------------------------------------------------ the tier table

func test_the_tiers_open_at_rising_levels_and_each_pays_two_to_two_and_a_half_times_the_last() -> void:
	var tiers := _tiers()
	expect_true(tiers.size() >= 6, "rows for the levels to come, to about level 21 and past: %d" % tiers.size())
	expect_eq(int(tiers[0]["first_level"]), 1, "the first tier opens with the first level")
	expect_true(int(tiers[-1]["first_level"]) >= 21, "the last row is for the last levels planned")
	for i in range(1, tiers.size()):
		var ratio := float(tiers[i]["gold_per_run"]) / float(tiers[i - 1]["gold_per_run"])
		expect_true(ratio >= 2.0 and ratio <= 2.5, "%s pays %.2f times %s" % [tiers[i]["id"], ratio, tiers[i - 1]["id"]])
		expect_true(int(tiers[i]["first_level"]) > int(tiers[i - 1]["first_level"]), "%s opens later" % tiers[i]["id"])


func test_what_a_tier_pays_is_about_what_the_bot_earns_in_a_run_where_it_opens() -> void:
	# Measured over the average bot's runs at each level (about 250 at the first levels, 1,150 at Gull Rock).
	var content := _content()
	expect_eq(HoldfastContent.gold_per_run_at(content, 1), 250)
	expect_eq(HoldfastContent.gold_per_run_at(content, 2), 250, "a level between two rows reads the last row opened")
	expect_eq(HoldfastContent.gold_per_run_at(content, 5), 1200, "Gull Rock")
	expect_eq(HoldfastContent.gold_per_run_at(content, 6), 2600, "the next biome")


# ------------------------------------------------------------------ prices

## A node costs between this many and this many runs of the gold a run pays where its tier opens. The top is
## the pacing gate's rule: no more than 3 runs of waiting for anything, so nothing may cost much more than that.
const MIN_RUNS := 0.2
const MAX_RUNS := 3.5


func test_every_gold_node_names_a_tier_and_costs_a_few_runs_of_that_tiers_gold() -> void:
	var content := _content()
	var nodes: Dictionary = content["upgrade_nodes"]
	var priced := 0
	for id in nodes:
		var node: Dictionary = nodes[id]
		if HoldfastMeta.is_star_node(node) or int(node["cost"]) == 0:
			expect_false(node.has("gold_tier"), "%s is not a priced gold node" % id)
			continue
		expect_true(node.has("gold_tier"), "%s names its tier" % id)
		var income := float(content["gold_tiers"][node["gold_tier"]]["gold_per_run"])
		var runs := float(node["cost"]) / income
		expect_true(runs >= MIN_RUNS and runs <= MAX_RUNS, "%s costs %d, %.2f runs of %s's %d" % [id, int(node["cost"]), runs, node["gold_tier"], int(income)])
		priced += 1
	expect_true(priced >= 40, "all the gold nodes: %d" % priced)


func test_the_first_buys_of_the_first_runs_keep_their_prices() -> void:
	for id in FIRST_BUYS:
		expect_eq(int(_content()["upgrade_nodes"][id]["cost"]), FIRST_BUYS[id], id)
		expect_eq(_content()["upgrade_nodes"][id]["gold_tier"], "tier_1", id)


func test_the_dearest_nodes_sit_in_a_tier_priced_for_more_than_the_first_five_levels_pay() -> void:
	# Marksman and Burst fire stay in the tier that opens at Gull Rock: the bands gate judges the two Archer sides
	# in the first five levels, and a node out of reach there would make the sides play the same.
	var content := _content()
	for id in ["tithe_4", "tithe_5", "tithe_6", "keep_walls_5"]:
		var tier: Dictionary = content["gold_tiers"][content["upgrade_nodes"][id]["gold_tier"]]
		expect_true(int(tier["gold_per_run"]) >= 2 * HoldfastContent.gold_per_run_at(content, 5), "%s is priced from %d gold a run" % [id, int(tier["gold_per_run"])])


func test_a_node_in_a_later_tier_costs_more_than_any_in_an_earlier_one() -> void:
	var content := _content()
	var low := {}
	var high := {}
	for id in content["upgrade_nodes"]:
		var node: Dictionary = content["upgrade_nodes"][id]
		if node.has("gold_tier"):
			var tier: String = node["gold_tier"]
			low[tier] = mini(int(low.get(tier, 1 << 30)), int(node["cost"]))
			high[tier] = maxi(int(high.get(tier, 0)), int(node["cost"]))
	var last_high := 0
	for tier in _tiers():
		if high.has(tier["id"]):
			expect_true(int(high[tier["id"]]) >= last_high, "%s: its dearest node %d is no cheaper than the tier before's %d" % [tier["id"], int(high[tier["id"]]), last_high])
			last_high = int(high[tier["id"]])


func test_a_new_tier_is_a_row_and_checks_the_nodes_that_name_it() -> void:
	# Levels past the ones built add a row; a node in it is checked against that row's gold with no change to the old ones.
	var content := _content().duplicate(true)
	content["gold_tiers"]["tier_8"] = {"id": "tier_8", "name": "Tier 8", "first_level": 26, "gold_per_run": 60000}
	expect_eq(HoldfastContent.gold_per_run_at(content, 25), 27500, "level 25 still reads the row before")
	expect_eq(HoldfastContent.gold_per_run_at(content, 26), 60000, "and level 26 reads the new row")
	var node := {"cost": 150000, "gold_tier": "tier_8"}
	var runs := float(node["cost"]) / float(content["gold_tiers"][node["gold_tier"]]["gold_per_run"])
	expect_true(runs >= MIN_RUNS and runs <= MAX_RUNS, "a 150,000 gold node is %.1f runs of the new tier" % runs)


# ------------------------------------------------------------------ Tithe

func test_the_tithe_chain_is_additive_and_adds_up_to_half_as_much_again() -> void:
	var content := _content()
	var total := 0.0
	for id in TITHE:
		var effects: Array = content["upgrade_nodes"][id]["effects"]
		expect_eq(effects.size(), 1, id)
		expect_eq(effects[0]["stat"], "gold_multiplier", id)
		expect_true(effects[0].has("add") and not effects[0].has("multiply"), "%s adds; it does not compound" % id)
		total += float(effects[0]["add"])
	expect_near(total, 0.55, 0.0001, "about +50% in all, capped there")
	var all := HoldfastRules.new()
	all.report_errors = false
	all.setup(HoldfastContent.run_config("outpost", TITHE), SimRng.new(7))
	expect_near(all.gold_multiplier, 1.55, 0.0001, "all six together")
	var first := HoldfastRules.new()
	first.report_errors = false
	first.setup(HoldfastContent.run_config("outpost", ["tithe_1"]), SimRng.new(7))
	expect_near(first.gold_multiplier, 1.25, 0.0001, "Tithe I alone is still a quarter more")


# ------------------------------------------------------------------ salvage

func _boss_rules(owned: Array) -> HoldfastRules:
	var rules := HoldfastRules.new()
	rules.report_errors = false
	var content: Dictionary = _content().duplicate(true)
	content["levels"]["gull_rock"]["first_wave_delay"] = 1000.0
	rules.setup(HoldfastContent.run_config("gull_rock", [], content, "flare_archer", null, {}, owned), SimRng.new(3))
	return rules


func _kill_boss(rules: HoldfastRules) -> void:
	var data: Dictionary = _content()["enemies"]["fog_warden"]
	var enemy := HoldfastRules.Enemy.new()
	enemy.type = "fog_warden"
	enemy.position = Vector2(300, 300)
	enemy.health = 0.0
	enemy.max_health = 100.0
	enemy.radius = float(data["radius"])
	enemy.speed = 0.0
	enemy.tier = "boss"
	enemy.gold = 0
	enemy.xp_chance = 0.0
	rules.enemies.append(enemy)
	rules._any_dead = true
	rules.step(DT, {})


func test_a_boss_drop_with_every_piece_owned_is_salvaged_for_about_a_runs_gold() -> void:
	var rules := _boss_rules(DROPS + ["gull_feather_fletching", "storm_cap", "oilskin_vest", "wave_worn_boots", "tide_band"])
	var before := rules.gold
	_kill_boss(rules)
	expect_eq(rules.gear_found, [], "nothing to find")
	expect_eq(rules.salvaged, 1200, "one run's gold at Gull Rock (its tier)")
	expect_eq(rules.gold - before, 1200, "paid into the run's gold")
	expect_eq(rules.result()["salvaged"], 1200, "and said in the result")
	expect_eq(rules.result()["gold"], rules.gold, "which banks it")


func test_a_drop_that_still_has_something_to_give_is_not_salvaged() -> void:
	var rules := _boss_rules(DROPS.slice(1))
	_kill_boss(rules)
	expect_eq(rules.gear_found, [DROPS[0]], "the one piece left drops")
	expect_eq(rules.salvaged, 0)
	expect_false(rules.result().has("salvaged"), "so the result says nothing of salvage")


func test_the_result_panel_says_what_was_salvaged() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var label: Label = main.summary.get_node("%Salvaged")
	main.summary.show_summary({"gold_earned": 1500, "waves_cleared": 8, "total_waves": 8, "keep_fell": false, "result": {"gear_found": [], "salvaged": 1200}}, "")
	expect_true(label.visible)
	expect_eq(label.text, "Salvaged: %s gold" % Hud.format_number(1200))
	main.summary.show_summary({"gold_earned": 300, "waves_cleared": 8, "total_waves": 8, "keep_fell": false, "result": {"gear_found": []}}, "")
	expect_false(label.visible, "nothing salvaged, nothing said")
	main.free()
