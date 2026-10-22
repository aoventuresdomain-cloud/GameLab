extends KitTestCase
## HF-M2-17 slice 2b: monsters that can beat the Hero (health and damage rising by
## wave, set in the pack), and Recruits who leave their home to fight and go back
## to it. Expected numbers are worked by hand from the pack values noted beside them.
##
## Pack: Bryn (Warden, health 40, range 70) is placed at (112, -48) with no post:
## leash 160, speed 90 px/s (3 px a tick), retreat below 0.6 of his health, rests at
## 2 health a second. Wren staffs the west post and so stays there. The leash seam
## itself (RecruitLeash.step and validate) is pinned by QA's test_m2_recruit_leash.gd.

const DT := 1.0 / HoldfastRules.TICK_RATE
const HOME := Vector2(112, -48)
const BIG := 1000000.0
const PILLARS := ["flare_archer", "dusk_mage", "tideblade"]


## Rules with no wave for 1000 s and nothing of ours doing damage.
func _quiet(edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content), SimRng.new(1))
	return rules


func _enemy(rules: HoldfastRules, at: Vector2, health: float = BIG) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	enemy.speed = 0.0
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int) -> void:
	for i in ticks:
		rules.step(DT, {})


# ------------------------------------------------------------------ RecruitRules.rest

func test_resting_heals_up_to_the_maximum_and_only_the_living() -> void:
	var hurt := RecruitRules.damage(RecruitRules.new_recruit("warden", 40.0), 30.0)
	expect_eq(RecruitRules.rest(hurt, 4.0)["health"], 14.0, "10 + 4")
	expect_eq(RecruitRules.rest(hurt, 100.0)["health"], 40.0, "stops at the maximum")
	expect_eq(hurt["health"], 10.0, "the one passed in is not changed")
	expect_eq(RecruitRules.rest(hurt, 0.0)["health"], 10.0)
	expect_eq(RecruitRules.rest(hurt, -5.0)["health"], 10.0)
	expect_eq(RecruitRules.rest(hurt, NAN)["health"], 10.0)
	var downed := RecruitRules.damage(RecruitRules.new_recruit("warden", 40.0), 40.0)
	expect_eq(RecruitRules.rest(downed, 10.0)["health"], 0.0, "a downed Recruit is not healed by rest")
	expect_true(RecruitRules.rest(downed, 10.0)["downed"])


# ------------------------------------------------------------------ Recruits move in the rules

func test_a_recruit_walks_out_to_an_enemy_in_reach_and_stops_at_his_attack_range() -> void:
	# Enemy at (112,102): 150 from Bryn and from home, inside the leash of 160. He walks until
	# 70 away (his range), so 80 px at 3 px a tick: 27 ticks, ending at (112,32).
	var rules := _quiet()
	_enemy(rules, HOME + Vector2(0, 150))
	_run(rules, 60)
	expect_near(rules.recruits[0].position.x, 112.0, 0.0001)
	expect_near(rules.recruits[0].position.y, 32.0, 0.0001)
	expect_true(rules.recruits[0].position.distance_to(HOME) <= 160.0)


func test_enemies_target_a_recruit_where_he_is_now_not_where_he_started() -> void:
	# Bryn walks out to (112,32). An enemy at (112,75) is then 43 from him but 112 from the Hero
	# (0,80) and 123 from his home: if the targeting still used his home it would go for the Hero.
	var rules := _quiet()
	_enemy(rules, HOME + Vector2(0, 150))
	_run(rules, 60)
	expect_near(rules.recruits[0].position.y, 32.0, 0.0001)
	var near := _enemy(rules, Vector2(112, 75))
	_run(rules, 1)
	expect_eq(near.target, "recruit:bryn")


func test_a_recruit_ignores_an_enemy_outside_the_leash_of_home() -> void:
	# 161 from home: out; 160 from home: in (and he walks at it).
	var out := _quiet()
	_enemy(out, HOME + Vector2(0, 161))
	_run(out, 30)
	expect_eq(out.recruits[0].position, HOME, "stays")
	var edge := _quiet()
	_enemy(edge, HOME + Vector2(0, 160))
	_run(edge, 30)
	expect_ne(edge.recruits[0].position, HOME, "goes")


func test_a_recruit_with_a_zero_leash_never_moves() -> void:
	var rules := _quiet(func(c: Dictionary) -> void: c["staff"]["bryn"]["leash"] = 0.0)
	_enemy(rules, HOME + Vector2(0, 100))
	_run(rules, 60)
	expect_eq(rules.recruits[0].position, HOME)


func test_a_recruit_staffing_a_post_stays_at_it_and_keeps_the_effect() -> void:
	var rules := _quiet(func(c: Dictionary) -> void: c["levels"]["outpost"]["staff"]["post"] = "east_post")
	_enemy(rules, HOME + Vector2(0, 120))  # inside the leash and past his range: a roaming Bryn would go
	_run(rules, 60)
	expect_eq(rules.recruits[0].position, HOME, "a staffing Warden does not roam")
	var taunted := _enemy(rules, Vector2(-20, -20))
	_run(rules, 1)
	expect_eq(taunted.target, "recruit:bryn", "and still taunts")


func test_a_downed_recruit_does_not_move() -> void:
	# A retreat fraction of 0 so the only thing keeping him still is being downed.
	var rules := _quiet(func(c: Dictionary) -> void: c["staff"]["bryn"]["retreat_below"] = 0.0)
	var hitter := _enemy(rules, HOME)
	hitter.damage = 40
	_run(rules, 1)
	expect_false(rules.recruits[0].up)
	rules.enemies.clear()
	var lure := _enemy(rules, HOME + Vector2(0, 120))
	_run(rules, 60)
	expect_eq(rules.recruits[0].position, HOME)
	expect_true(lure.health > 0.0)


func test_a_hurt_recruit_goes_home_rests_and_only_then_goes_out_again() -> void:
	# Hurt is below 0.6 of 40 = 24. At 19 he walks the 60 px home (20 ticks) enemy or not, and
	# rests from that tick at 2 a second: 31 ticks by tick 50 (19 + 2.07), still hurt, still home.
	var rules := _quiet()
	var bryn: HoldfastRules.Attacker = rules.recruits[0]
	bryn.position = HOME + Vector2(0, 60)
	bryn.health = RecruitRules.damage(bryn.health, 21.0)
	_enemy(rules, HOME + Vector2(0, 100))
	_run(rules, 20)
	expect_eq(bryn.position, HOME, "60 px at 3 px a tick: home in 20 ticks")
	_run(rules, 30)
	expect_near(bryn.health["health"], 19.0 + 31.0 * 2.0 * DT, 0.001, "2 health a second at home")
	expect_eq(bryn.position, HOME, "stays while hurt even with an enemy in reach")
	# 24 is reached 75 rest ticks in (tick 95): by tick 120 he is out after the enemy.
	_run(rules, 70)
	expect_ne(bryn.position, HOME, "no longer hurt: back out")
	expect_true(bryn.health["health"] >= 24.0)


func test_a_revived_recruit_rests_before_going_out() -> void:
	# He gets up with half his health (20 of 40), below 0.6, so he holds at home until 24.
	var rules := _quiet()
	var hitter := _enemy(rules, HOME)
	hitter.damage = 40
	_run(rules, 1)
	rules.enemies.clear()
	rules.hero_position = HOME
	_run(rules, 91)
	expect_true(rules.recruits[0].up)
	_enemy(rules, HOME + Vector2(0, 150))
	_run(rules, 30)
	expect_eq(rules.recruits[0].position, HOME, "still resting")
	_run(rules, 90)
	expect_ne(rules.recruits[0].position, HOME, "rested to 24: out")


func test_a_bad_leash_in_the_pack_is_refused() -> void:
	for edit in [{"leash": -1.0}, {"move_speed": -1.0}, {"retreat_below": 1.5}]:
		var rules := HoldfastRules.new()
		rules.report_errors = false
		var content: Dictionary = HoldfastContent.base().duplicate(true)
		content["staff"]["bryn"].merge(edit, true)
		rules.setup(HoldfastContent.run_config("outpost", [], content), SimRng.new(1))
		expect_eq(rules.outcome, HoldfastRules.OUTCOME_INVALID, str(edit))
		expect_ne(rules.setup_error, "", str(edit))


func test_a_recruit_never_leaves_the_leash_across_a_bot_run_on_every_pillar() -> void:
	for id in PILLARS:
		var rules := HoldfastRules.new()
		rules.setup(HoldfastContent.run_config("outpost", [], {}, id), SimRng.new(2))
		var bot := HoldfastHeroBot.new()
		var farthest := 0.0
		var moved := false
		for tick in 20000:
			rules.step(DT, bot.get_input(rules, tick))
			var bryn: HoldfastRules.Attacker = rules.recruits[0]
			farthest = maxf(farthest, bryn.position.distance_to(bryn.home))
			moved = moved or bryn.position != bryn.home
			expect_eq(rules.recruits[1].position, rules.recruits[1].home, "the Recruit at a post never moves")
			if rules.is_finished():
				break
		expect_true(farthest <= 160.0 + 0.001, "%s: Bryn went %.2f from home" % [id, farthest])
		expect_true(moved, id + ": Bryn did walk out")


# ------------------------------------------------------------------ monsters rise by wave

func test_a_waves_scales_set_its_enemies_health_and_damage() -> void:
	# Grunt: health 10, damage 5. Scale 2 and 1.5 on wave 1: health 20, damage 7.5 -> 8.
	var scaled := _quiet(func(c: Dictionary) -> void:
		c["levels"]["outpost"]["first_wave_delay"] = 0.0
		c["levels"]["outpost"]["waves"][0]["health_scale"] = 2.0
		c["levels"]["outpost"]["waves"][0]["damage_scale"] = 1.5)
	_run(scaled, 1)
	expect_eq(scaled.enemies[0].type, "grunt")
	expect_eq(scaled.enemies[0].max_health, 20.0)
	expect_eq(scaled.enemies[0].damage, 8)
	var plain := _quiet(func(c: Dictionary) -> void:
		c["levels"]["outpost"]["first_wave_delay"] = 0.0
		var wave: Dictionary = c["levels"]["outpost"]["waves"][0]
		wave.erase("health_scale")
		wave.erase("damage_scale"))
	_run(plain, 1)
	expect_eq(plain.enemies[0].max_health, 10.0, "no scale means the enemy's own numbers")
	expect_eq(plain.enemies[0].damage, 5)


func test_monsters_get_stronger_wave_by_wave_in_the_pack() -> void:
	var waves: Array = HoldfastContent.base()["levels"]["outpost"]["waves"]
	var health := 0.0
	var damage := 0.0
	for wave in waves:
		var h := float(wave.get("health_scale", 1.0))
		var d := float(wave.get("damage_scale", 1.0))
		expect_true(h >= health and d >= damage, "no wave is weaker than the one before")
		health = h
		damage = d
	expect_true(health > 1.0 and damage > 1.0, "the last wave is stronger than the first")


# ------------------------------------------------------------------ a Hero can lose, and can win

func _bot_run(id: String, run_seed: int) -> Dictionary:
	var config := HoldfastContent.run_config("outpost", [], {}, id)
	return SimBotRunner.run(HoldfastRules.new(), HoldfastHeroBot.new(), run_seed, config, 200000, HoldfastRules.TICK_RATE)["result"]


func test_a_bot_on_each_pillar_wins_some_runs_and_has_hard_ones() -> void:
	# Pack thresholds. A hard run ends with the keep fallen or the Hero knocked down more than once.
	var check: Dictionary = HoldfastContent.base()["levels"]["outpost"]["balance_check"]
	for id in PILLARS:
		var won := 0
		var hard := 0
		for run_seed in range(1, int(check["seeds"]) + 1):
			var result := _bot_run(id, run_seed)
			if result["outcome"] == HoldfastRules.OUTCOME_WON:
				won += 1
			if result["outcome"] != HoldfastRules.OUTCOME_WON or int(result["hero_knockdowns"]) > 1:
				hard += 1
		expect_true(won >= int(check["min_won_runs"]), "%s won %d of %d: it must win at least %d" % [id, won, check["seeds"], check["min_won_runs"]])
		expect_true(hard >= int(check["min_hard_runs"]), "%s had %d hard runs of %d: it needs at least %d, or the Hero can never lose" % [id, hard, check["seeds"], check["min_hard_runs"]])


func test_a_run_with_no_input_is_lost_on_every_pillar() -> void:
	for id in PILLARS:
		for run_seed in [1, 2, 3]:
			var config := HoldfastContent.run_config("outpost", [], {}, id)
			var result: Dictionary = SimBotRunner.run(HoldfastRules.new(), SimController.new(), run_seed, config, 200000, HoldfastRules.TICK_RATE)["result"]
			expect_eq(result["outcome"], HoldfastRules.OUTCOME_LOST, "%s seed %d with no input" % [id, run_seed])
