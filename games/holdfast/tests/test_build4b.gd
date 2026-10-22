extends KitTestCase
## Build 4b (HF-M2-27): the post-win screen offers Next level and the Upgrade
## screen, and the Dusk Mage's Eclipse and the Tideblade's Dash-Strike are the
## Advisor's zone and three dashes. The Flare Barrage burst is tested in test_hero.gd.
## Expected numbers are worked by hand from the pack values noted beside them.

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://build4b_tests"
const DT := 1.0 / HoldfastRules.TICK_RATE
const SCHEMA := HoldfastContent.SCHEMA


func _main(path: String = "") -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	if path != "":
		main.get_node("Profile").save_path = path
	tree.root.add_child(main)
	return main


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


## The run_ended payload for a run of `level` that ended with `outcome` and earned `gold`.
func _ended(level: String, outcome: String, gold: int) -> Dictionary:
	return {"gold_earned": gold, "waves_cleared": 6, "total_waves": 6, "keep_fell": outcome == HoldfastRules.OUTCOME_LOST,
			"result": {"outcome": outcome, "level": level, "gold": gold}}


func test_a_win_offers_the_next_level_and_the_upgrade_screen() -> void:
	var main := _main()
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON, 50))
	expect_true(main.summary.visible)
	expect_true(main.summary.get_node("%NextLevelButton").visible, "Shingle Beach opened by the win")
	expect_eq(main.summary.get_node("%KeepButton").text, "Upgrade screen")
	main.summary.get_node("%KeepButton").pressed.emit()
	expect_true(main.keep_screen.visible and not main.summary.visible, "the upgrade screen is the keep")
	main.free()


func test_next_level_starts_a_run_on_the_next_level() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON, 50))
	main.summary.get_node("%NextLevelButton").pressed.emit()
	main.planning.get_node("%StartButton").pressed.emit()
	expect_eq(profile.get_level(), "shingle_beach")
	expect_true(source.is_running())
	expect_true(main.hud.visible and not main.summary.visible, "the run is on screen")
	expect_eq(source.get_rules().level_id, "shingle_beach")
	main.free()


func test_a_loss_keeps_its_screen_with_no_next_level() -> void:
	var main := _main()
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_LOST, 5))
	expect_false(main.summary.get_node("%NextLevelButton").visible, "no next level after a loss")
	expect_eq(main.summary.get_node("%KeepButton").text, "Back to the keep")
	expect_true(main.summary.get_node("%PlayAgainButton").visible)
	expect_eq(main.summary.get_node("%Title").text, "The keep has fallen")
	main.free()


func test_a_loss_on_a_level_already_won_still_offers_no_next_level() -> void:
	# Level 2 is open from an earlier win, but a lost replay of level 1 offers nothing.
	var main := _main()
	main.get_node("Profile").bank_run({"gold": 0, "outcome": HoldfastRules.OUTCOME_WON, "level": "outpost"})
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_LOST, 5))
	expect_false(main.summary.get_node("%NextLevelButton").visible)
	main.free()


func test_the_last_level_has_no_next_level() -> void:
	var main := _main()
	var levels: Array = HoldfastContent.base()["levels"].keys()
	main.call("_on_run_ended", _ended(levels[levels.size() - 1], HoldfastRules.OUTCOME_WON, 50))
	expect_false(main.summary.get_node("%NextLevelButton").visible, "nothing after the last level")
	expect_eq(main.summary.get_node("%KeepButton").text, "Upgrade screen")
	main.free()


func test_a_win_that_does_not_open_the_next_level_does_not_offer_it() -> void:
	# A summary shown for a level whose successor is still locked offers nothing.
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_eq(profile.get_next_level("shingle_beach"), "", "level 3 is locked until level 2 is won")
	expect_eq(profile.get_next_level("outpost"), "", "and level 2 until level 1 is won")
	profile.bank_run({"gold": 0, "outcome": HoldfastRules.OUTCOME_WON, "level": "outpost"})
	expect_eq(profile.get_next_level("outpost"), "shingle_beach")
	expect_eq(profile.get_next_level("nowhere"), "", "an unknown level has none")
	main.free()


func test_gold_and_unlocks_are_saved_before_the_screen_shows() -> void:
	var path := _save_path("before_summary")
	var main := _main(path)
	var seen := {}
	main.summary.visibility_changed.connect(func() -> void:
		if main.summary.visible and not seen.has("gold"):
			var check := HoldfastProfile.new()
			check.save_path = path
			check.load_profile()
			seen["gold"] = check.get_gold()
			seen["unlocked"] = check.get_unlocked_levels()
			check.free())
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON, 77))
	expect_eq(seen.get("gold"), 77, "the gold was on disk when the screen appeared")
	expect_true("shingle_beach" in seen.get("unlocked", []), "and the level it opened")
	main.free()


# ------------------------------------------------------------------ the specials

## Outpost rules with no wave for 1000 s, no light bonus, no posts lit, and nothing but the
## Hero's special able to hurt: tower, staff and the Hero's own attack do no damage.
func _rules(hero: String, edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	var level: Dictionary = content["levels"]["outpost"]
	level["first_wave_delay"] = 1000.0
	level["light"]["bonus"] = 0.0
	level["staff"].erase("post")
	for at in level["recruits"]:
		at.erase("post")
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	content["hero_paths"][hero]["attack"]["damage"] = 0.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, hero), SimRng.new(1))
	return rules


func _enemy(rules: HoldfastRules, at: Vector2, health: float = 100.0) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	enemy.speed = 0.0
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


func test_the_shipped_specials_are_the_advisors_numbers() -> void:
	# Eclipse: a zone 1.5 times the tower's range, 4 s, slow 60%, a collapse of 4 hits, cooldown 16 s.
	# Dash-Strike: 3 dashes of 300 px in 1.2 s, each hit 3 times the attack, cooldown 12 s.
	var content := HoldfastContent.base()
	var tower_range := float(content["towers"]["archer_post"]["range"])
	var dusk: Dictionary = content["hero_paths"]["dusk_mage"]
	var eclipse: Dictionary = dusk["ability"]
	expect_eq(float(eclipse["zone_radius"]), tower_range * 1.5)
	expect_eq(float(eclipse["zone_seconds"]), 4.0)
	expect_eq(float(eclipse["slow"]), 0.6)
	expect_eq(float(eclipse["damage"]), float(dusk["attack"]["damage"]) * 4.0)
	expect_eq(float(eclipse["cooldown"]), 16.0)
	var tide: Dictionary = content["hero_paths"]["tideblade"]
	var dash: Dictionary = tide["ability"]
	expect_eq(int(dash["dash_count"]), 3)
	expect_eq(float(dash["dash_seconds"]), 1.2)
	expect_eq(float(dash["dash_distance"]), 300.0)
	expect_eq(float(dash["damage"]), float(tide["attack"]["damage"]) * 3.0)
	expect_eq(float(dash["cooldown"]), 12.0)
	expect_false(dash.has("refund_on_kill"), "no refund on a kill")


func test_eclipse_pulls_and_slows_inside_the_zone_and_leaves_the_rest() -> void:
	# Hero (0, 80) faces the nearest enemy A at (200, 80), so the zone is centred there. Radius 255
	# (reach 265 with an enemy's 10). B is 240 from the centre and is pulled 60 px/s, 2 px a tick,
	# from the tick after the press: 30 ticks later it is 60 px closer. C is 270 away: outside.
	var rules := _rules("dusk_mage")
	_enemy(rules, Vector2(200, 80))
	var b := _enemy(rules, Vector2(440, 80))
	var c := _enemy(rules, Vector2(470, 80))
	_run(rules, 1, {"ability": true})
	expect_eq(rules.zone_position, Vector2(200, 80))
	_run(rules, 30)
	expect_near(b.position.x, 380.0, 0.001, "B pulled 60 px towards the centre")
	expect_near(b.slow_amount, 0.6, 0.0001)
	expect_true(b.slowed_for > 0.0, "and slowed")
	expect_eq(c.position.x, 470.0, "C is not pulled")
	expect_eq(c.slowed_for, 0.0, "or slowed")
	expect_near(rules.hero_ability_ready_in, 16.0 - 30 * DT, 0.0001, "cooldown 16 s from the press")


func test_the_eclipse_zone_reaches_exactly_its_pack_radius() -> void:
	# Radius 255 plus an enemy's 10: 265 from the centre is pulled (2 px on the first tick of the
	# zone after the press), 266 is not.
	var rules := _rules("dusk_mage")
	_enemy(rules, Vector2(200, 80))
	var edge := _enemy(rules, Vector2(465, 80))
	var past := _enemy(rules, Vector2(466, 80))
	_run(rules, 2, {"ability": true})
	expect_near(edge.position.x, 463.0, 0.001, "265 away: pulled")
	expect_eq(past.position.x, 466.0, "266 away: left alone")


func test_eclipse_collapses_after_four_seconds_on_what_is_near_the_middle() -> void:
	# The collapse is 20 (4 hits of 5) x 1.6 unlit = 32. A sits on the middle, B is pulled in to it
	# by the end (240 px at 60 px/s is exactly 4 s), C was never in the zone.
	var rules := _rules("dusk_mage")
	var a := _enemy(rules, Vector2(200, 80))
	var b := _enemy(rules, Vector2(440, 80))
	var c := _enemy(rules, Vector2(470, 80))
	_run(rules, 1, {"ability": true})
	_run(rules, 119)
	expect_true(rules.zone_left > 0.0, "still open after 4 s minus a tick")
	expect_eq(a.health, 100.0, "nothing hurts before the collapse")
	_run(rules, 4)
	expect_eq(rules.zone_left, 0.0, "collapsed")
	expect_near(a.health, 68.0, 0.001, "20 x 1.6")
	expect_near(b.health, 68.0, 0.001, "pulled in, so caught")
	expect_eq(c.health, 100.0, "never in the zone")


func test_the_eclipse_collapse_reaches_exactly_its_pack_radius() -> void:
	# No pull. Collapse radius 130 plus an enemy's 10: 140 from the centre is hit, 141 is not.
	var rules := _rules("dusk_mage", func(c: Dictionary) -> void: c["hero_paths"]["dusk_mage"]["ability"]["pull"] = 0.0)
	_enemy(rules, Vector2(200, 80))
	var edge := _enemy(rules, Vector2(340, 80))
	var past := _enemy(rules, Vector2(341, 80))
	_run(rules, 1, {"ability": true})
	_run(rules, 125)
	expect_near(edge.health, 68.0, 0.001, "140 away: hit")
	expect_eq(past.health, 100.0, "141 away: missed")


func test_an_eclipse_of_zero_seconds_is_the_plain_blast_round_the_target() -> void:
	var rules := _rules("dusk_mage", func(c: Dictionary) -> void: c["hero_paths"]["dusk_mage"]["ability"]["zone_seconds"] = 0.0)
	var a := _enemy(rules, Vector2(200, 80))
	_run(rules, 1, {"ability": true})
	expect_eq(rules.zone_left, 0.0, "no zone")
	expect_near(a.health, 68.0, 0.001, "hurt at once")


func test_dash_strike_makes_three_dashes_and_hits_each_enemy_once_per_dash() -> void:
	# Hero (0, 80). E1 (0,-100) and E2 (0,-200) are in a line. Dash 1 runs up 300 px to y = -220 over
	# ticks 1 to 12 and hits both (27 each). Dash 2 turns to the nearest, E2, which is now below the
	# Hero, and runs back down to y = 80; dash 3 turns to E1 and runs up again to y = -220. Each
	# enemy is hit three times in all: 1000 - 81 = 919. A dash is 12 ticks (0.4 s at 750 px/s).
	var rules := _rules("tideblade")
	var e1 := _enemy(rules, Vector2(0, -100), 1000.0)
	var e2 := _enemy(rules, Vector2(0, -200), 1000.0)
	_run(rules, 1, {"ability": true})
	_run(rules, 12)
	expect_near(rules.hero_position.y, -220.0, 0.01, "first dash: 300 px up")
	expect_near(e1.health, 973.0, 0.001, "hit once in the first dash, however many ticks it touched it")
	expect_near(e2.health, 973.0, 0.001)
	_run(rules, 12)
	expect_near(rules.hero_position.y, 80.0, 0.01, "second dash: back down")
	expect_near(e1.health, 946.0, 0.001)
	_run(rules, 12)
	expect_near(rules.hero_position.y, -220.0, 0.01, "third dash: up again, and the chain is over")
	expect_near(e1.health, 919.0, 0.001)
	expect_near(e2.health, 919.0, 0.001)
	expect_eq(rules.hero_dash_left, 0.0)
	expect_near(rules.hero_ability_ready_in, 12.0 - 36 * DT, 0.0001, "cooldown 12 s from the press, nothing refunded")


func test_nothing_can_hurt_the_hero_during_the_dashes_and_the_grace_ends_with_them() -> void:
	var rules := _rules("tideblade")
	_enemy(rules, Vector2(0, -100), 1000.0)
	_run(rules, 1, {"ability": true})
	_run(rules, 18)
	expect_true(rules.hero_untouchable(), "mid-chain")
	_run(rules, 30)
	expect_false(rules.hero_untouchable(), "grace over soon after the last dash")


func test_the_hero_is_untouchable_from_the_tick_of_the_cast() -> void:
	# QA follow-up: the grace was set a tick late, so the tick after the cast could still hurt.
	var rules := _rules("tideblade")
	_enemy(rules, Vector2(0, -100), 1000.0)
	_run(rules, 1, {"ability": true})
	expect_true(rules.hero_untouchable(), "on the cast tick itself")
	_run(rules, 1)
	expect_true(rules.hero_untouchable(), "and on the tick after")


func test_a_dash_chain_of_one_and_of_zero_seconds() -> void:
	# One dash of 0.4 s: a single 300 px run, hit once. Zero seconds is the plain one-off dash.
	var one := _rules("tideblade", func(c: Dictionary) -> void:
		c["hero_paths"]["tideblade"]["ability"].merge({"dash_count": 1, "dash_seconds": 0.4}, true))
	var e := _enemy(one, Vector2(0, -100), 1000.0)
	_run(one, 1, {"ability": true})
	_run(one, 20)
	expect_near(one.hero_position.y, -220.0, 0.01)
	expect_near(e.health, 973.0, 0.001, "hit once")
	var plain := _rules("tideblade", func(c: Dictionary) -> void: c["hero_paths"]["tideblade"]["ability"]["dash_seconds"] = 0.0)
	_enemy(plain, Vector2(0, -100), 1000.0)
	_run(plain, 1, {"ability": true})
	expect_near(plain.hero_position.y, -220.0, 0.01, "the whole run in one tick")
	expect_eq(plain.hero_dash_left, 0.0)


func test_zone_and_dash_values_outside_the_limits_are_rejected() -> void:
	var schema := PackSchema.load_file(SCHEMA)
	var paths: Dictionary = HoldfastContent.base()["hero_paths"]
	var cases := {
		"zone seconds negative": ["dusk_mage", "zone_seconds", -1.0],
		"zone radius 0": ["dusk_mage", "zone_radius", 0.0],
		"pull negative": ["dusk_mage", "pull", -1.0],
		"eclipse cooldown 0": ["dusk_mage", "cooldown", 0.0],
		"dash count 0": ["tideblade", "dash_count", 0],
		"dash count 11": ["tideblade", "dash_count", 11],
		"dash seconds negative": ["tideblade", "dash_seconds", -0.1],
		"dash cooldown 0": ["tideblade", "cooldown", 0.0],
	}
	for label in cases:
		var bad: Dictionary = paths[cases[label][0]].duplicate(true)
		bad["ability"][cases[label][1]] = cases[label][2]
		var errors := PackedStringArray()
		schema.validate_def(bad, "hero_path", label, errors, [])
		expect_false(errors.is_empty(), "rejected: " + label)
	for id in ["dusk_mage", "tideblade"]:
		var errors := PackedStringArray()
		schema.validate_def(paths[id], "hero_path", id, errors, [])
		expect_true(errors.is_empty(), "%s is valid: %s" % [id, errors])


# ------------------------------------------------------------------ follow-ups from QA of the burst

func test_an_enemy_the_burn_kills_neither_hits_nor_moves_that_tick() -> void:
	var rules := _rules("flare_archer")
	var enemy := _enemy(rules, rules.tower.position + Vector2(20, 0), 0.05)
	enemy.damage = 5
	enemy.hit_interval = 1.0
	enemy.speed = 60.0
	enemy.burn_dps = 3.0
	enemy.burn_left = 2.0
	_run(rules, 1)
	expect_eq(rules.tower.health["health"], 60.0, "the dead enemy did not hit the tower")
	expect_eq(rules.enemies.size(), 0, "and is gone with its kill counted")
	expect_eq(rules.kills, 1)
	var alive := _enemy(rules, rules.tower.position + Vector2(20, 0), 5.0)
	alive.damage = 5
	alive.hit_interval = 1.0
	alive.burn_dps = 3.0
	alive.burn_left = 2.0
	_run(rules, 1)
	expect_eq(rules.tower.health["health"], 55.0, "one that survives its burn still hits")


func test_the_shipped_burst_fires_an_arrow_every_five_ticks_for_five_seconds() -> void:
	# Pack: 5 s of rapid fire, an arrow every 0.16 s. A tick is 1/30 s, so 0.16 s is reached on the
	# fifth tick: arrows on ticks 1, 6, 11 ... 146, thirty of them. The burst's last tick is the
	# 150th (a 151st would sit on the float edge of 5 s, so the count is checked as 30 or 31).
	var rules := _rules("flare_archer")
	var shots := []
	var seen := []
	for tick in range(1, 200):
		_run(rules, 1, {"ability": tick == 1})
		var fresh := 0
		for arrow in rules.projectiles:
			if not arrow in seen:
				seen.append(arrow)
				fresh += 1
		if fresh > 0:
			shots.append(tick)
	expect_true(seen.size() >= 30 and seen.size() <= 31, "arrows spawned in one burst: %d" % seen.size())
	expect_eq(seen.size(), shots.size(), "one arrow per shot, never two at once")
	expect_eq(shots.slice(0, 4), [1, 6, 11, 16], "one every five ticks")
	expect_eq(shots[29], 146, "the thirtieth")
