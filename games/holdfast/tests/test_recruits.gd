extends KitTestCase
## HF-M2-03: Recruits. Four classes, eight traits and a skill fork for each class, all from the pack;
## hired with gold from a board, picked onto a squad before each run, levelled by the XP a run pays.
## Each trait and each of the 24 skill choices changes the run the way its pack entry says.
## The pack's numbers are the Advisor's placeholders; the figures below are worked from them by hand.

const DT := 1.0 / HoldfastRules.TICK_RATE
const CLASSES := ["warden", "lookout", "alchemist", "engineer"]
## Round 0's board, as the pack and seed give it (a regression pin: the board must be stable between runs).
const PINNED_ROUND_ZERO := ["Isolde", "Jory", "Yara"]
const TRAITS := ["steady", "coward", "sturdy", "sharp", "quick", "nimble", "loyal", "eager"]


func _content() -> Dictionary:
	return HoldfastContent.base()


## A Recruit as the roster holds them.
func _r(class_id: String, traits: Array = [], skills: Array = [], xp := 0, id := "t1") -> Dictionary:
	var recruit := RecruitRoster.new_recruit(id, "Test", class_id, traits)
	recruit["skills"] = skills
	recruit["xp"] = xp
	return recruit


## Outpost with no wave for 1000 s and nothing but the squad able to do damage.
func _quiet(squad: Array, edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = _content().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config("outpost", [], content, "flare_archer", null, {}, [], false, squad), SimRng.new(1))
	return rules


func _run(rules: HoldfastRules, ticks: int) -> void:
	for i in ticks:
		rules.step(DT, {})


func _enemy(rules: HoldfastRules, at: Vector2, health := 100.0, damage := 0) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	enemy.speed = 0.0
	enemy.damage = damage
	rules.enemies.append(enemy)
	return enemy


## What a run reads for one stat from the unit it built.
func _stat(unit: HoldfastRules.Attacker, stat: String) -> float:
	match stat:
		"damage":
			return unit.damage
		"range":
			return unit.attack_range
		"cooldown":
			return unit.cooldown
		"health":
			return float(unit.health["max_health"])
		"leash":
			return unit.leash
		"rest_heal":
			return unit.rest_heal
		"armour":
			return unit.armour
		"flee_below":
			return unit.flee_below
		"xp_gain":
			return unit.xp_gain
		"move_speed", "revive_seconds", "retreat_below", "revive_health":
			return float(unit.role[stat])
	return float(unit.fx.get(stat, 0.0))


# ------------------------------------------------------------------ the pack

func test_the_pack_has_four_classes_eight_traits_and_three_forks_of_two_for_each_class() -> void:
	var content := _content()
	expect_eq(content["recruit_classes"].keys(), CLASSES, "the four classes")
	expect_eq(content["recruit_traits"].keys(), TRAITS, "eight traits")
	expect_eq(content["recruit_skills"].size(), 24, "24 skill choices in all")
	for class_id in CLASSES:
		for fork in [1, 2, 3]:
			var options: Array = content["recruit_skills"].values().filter(func(skill: Dictionary) -> bool: return skill["class"] == class_id and skill["fork"] == fork)
			expect_eq(options.size(), 2, "%s fork %d offers two" % [class_id, fork])
		expect_true(content["role_effects"].has(class_id), class_id + " has its post effect")
		expect_eq(content["recruit_classes"][class_id]["barks"].keys().size(), 4, class_id + " has barks for the four events")
	var names: Array = content["recruit_names"]["pool"]["names"]
	expect_true(names.size() >= 30, "a pool of names to draw from")
	expect_true(names.all(func(name: String) -> bool: return name == RecruitRoster.clean_name(name)), "every name is a clean one")


func test_a_recruit_is_bigger_than_the_common_enemies_and_smaller_than_the_hero() -> void:
	var content := _content()
	var hero: float = content["hero_paths"]["flare_archer"]["radius"]
	for class_id in CLASSES:
		var radius: float = content["recruit_classes"][class_id]["radius"]
		expect_true(radius < hero, class_id + " is smaller than the Hero")
		for enemy in ["grunt", "runner", "sprinter"]:
			expect_true(radius > float(content["enemies"][enemy]["radius"]), "%s is bigger than a %s" % [class_id, enemy])


func _win(content: Dictionary, profile: Dictionary, level: String) -> Dictionary:
	return HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": level, "gold": 0})


func test_nobody_starts_on_the_roster_and_winning_level_two_and_four_rescues_bryn_and_wren_free() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	expect_eq(profile["recruits"]["roster"], [], "no Recruits at the start")
	expect_eq(RecruitMeta.slots(content, profile), 2, "two slots to begin with")
	var lost := HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_LOST, "level": "shingle_beach", "gold": 0})
	expect_eq(lost["recruits"]["roster"], [], "a lost run rescues no one")
	expect_eq(_win(content, profile, "outpost")["recruits"]["roster"], [], "level one rescues no one")
	var one := _win(content, profile, "shingle_beach")
	expect_eq(one["recruits"]["roster"].map(func(r: Dictionary) -> String: return r["id"]), ["bryn"], "level two: the Warden")
	expect_eq(one["recruits"]["roster"][0]["class"], "warden")
	expect_eq(one["recruits"]["squad"], ["bryn"], "straight onto the squad")
	expect_eq(one["gold"], profile["gold"] + int(content["levels"]["shingle_beach"].get("reward", {}).get("gold", 0)), "free: no gold is taken")
	var changes := RecruitMeta.changes(content, profile, one)
	expect_eq([changes.size(), changes[0]["name"], changes[0]["class"], changes[0]["joined"]], [1, "Bryn", "warden", true], "the summary is told who joined")
	var two := _win(content, one, "old_pier")
	expect_eq(two["recruits"]["roster"].map(func(r: Dictionary) -> String: return r["id"]), ["bryn", "wren"], "level four: the Lookout")
	expect_eq(two["recruits"]["roster"][1]["class"], "lookout")
	expect_eq(two["recruits"]["squad"], ["bryn", "wren"])
	expect_eq(_win(content, two, "shingle_beach")["recruits"]["roster"].size(), 2, "a second win does not rescue again")
	var renamed := RecruitMeta.rename(one, "bryn", "Big Bryn")
	expect_eq(_win(content, renamed, "shingle_beach")["recruits"]["roster"].size(), 1, "nor does a renamed Recruit come back")
	var tight: Dictionary = _content().duplicate(true)
	tight["recruit_rescues"]["wren"]["level"] = "shingle_beach"
	tight["recruit_classes"]["lookout"]["locked"] = true
	expect_eq(_win(tight, profile, "shingle_beach")["recruits"]["roster"].size(), 1, "a class the pack has locked is never rescued")


# ------------------------------------------------------------------ what a Recruit is built from

func test_a_plain_recruit_has_their_classes_numbers() -> void:
	var content := _content()
	var warden := RecruitRoster.build(_r("warden"), content)
	var base: Dictionary = content["recruit_classes"]["warden"]
	for key in ["damage", "range", "cooldown", "health", "radius", "leash", "move_speed", "retreat_below", "rest_heal", "revive_seconds", "revive_health"]:
		expect_eq(warden[key], base[key], "warden " + key)
	expect_eq(warden["level"], 1)
	expect_eq(warden["fx"].keys(), ["taunt_radius"], "the class's post effect")
	expect_eq(float(warden["fx"]["taunt_radius"]), 150.0)
	expect_eq(RecruitRoster.build(_r("nobody"), content), {}, "a class the pack lacks builds nothing")


func test_levels_come_from_xp_each_costing_more() -> void:
	# xp_per_level 5: 1 to 2 costs 5, 2 to 3 costs 10, 3 to 4 costs 15.
	for pair in [[0, 1], [4, 1], [5, 2], [14, 2], [15, 3], [29, 3], [30, 4], [50, 5]]:
		expect_eq(RecruitRoster.level_for(pair[0], 5), pair[1], "%d xp" % pair[0])
	var content := _content()
	var warden := RecruitRoster.build(_r("warden", [], [], 15), content)
	expect_eq(warden["level"], 3)
	expect_eq(warden["damage"], 3.0 + 2.0, "two levels of 1 damage each on the warden's 3")


func test_every_trait_changes_the_unit_the_run_builds_as_its_text_says() -> void:
	# Each against the plain Warden: 70 range, 40 health, 3 damage, 0.8 s between blows, 90 speed, 3 s revive.
	var expected := {
		"steady": ["range", 84.0], "coward": ["flee_below", 0.5], "sturdy": ["health", 50.0], "sharp": ["damage", 3.6],
		"quick": ["move_speed", 112.5], "nimble": ["cooldown", 0.68], "loyal": ["revive_seconds", 1.5], "eager": ["xp_gain", 1.25],
	}
	for trait_id in TRAITS:
		var unit: HoldfastRules.Attacker = _quiet([_r("warden", [trait_id])]).recruits[0]
		expect_near(_stat(unit, expected[trait_id][0]), expected[trait_id][1], 0.0001, trait_id)
		var plain: HoldfastRules.Attacker = _quiet([_r("warden")]).recruits[0]
		expect_true(absf(_stat(plain, expected[trait_id][0]) - expected[trait_id][1]) > 0.001, trait_id + " is a change from plain")


func test_a_coward_flees_below_half_health_rests_at_the_keep_and_comes_back() -> void:
	var rules := _quiet([_r("warden", ["coward"])])
	var unit: HoldfastRules.Attacker = rules.recruits[0]
	var enemy := _enemy(rules, unit.position + Vector2(30, 0))
	_run(rules, 1)
	expect_true(unit.last_target >= 0 or unit.ready_in >= 0.0, "a healthy Coward fights")
	unit.health["health"] = 25.0
	_run(rules, 1)
	expect_false(unit.fleeing, "25 of 40 is above half")
	unit.health["health"] = 19.0
	_run(rules, 1)
	expect_true(unit.fleeing, "19 of 40 is below half")
	_run(rules, 1)
	expect_eq(unit.last_target, -1, "a fleeing Recruit holds their fire")
	_run(rules, 120)
	expect_true(unit.position.distance_to(unit.refuge) < 0.001, "they reach the keep's side")
	expect_true(unit.health["health"] > 19.0, "and rest there")
	enemy.health = 0.0
	rules.enemies.erase(enemy)
	_run(rules, 30 * 12)
	expect_false(unit.fleeing, "healed to half plus a quarter, they come back")
	expect_eq(unit.position, unit.home, "to their post")
	var brave := _quiet([_r("warden")])
	brave.recruits[0].health["health"] = 5.0
	_run(brave, 5)
	expect_false(brave.recruits[0].fleeing, "nobody else ever flees")


func test_a_loyal_recruit_gets_up_in_half_the_time() -> void:
	for pair in [[[], 3.0], [["loyal"], 1.5]]:
		var rules := _quiet([_r("warden", pair[0])])
		rules.hero_position = rules.recruits[0].position
		rules._hit_unit(rules.recruits[0], 1000.0)
		expect_false(rules.recruits[0].up)
		_run(rules, int(pair[1] * HoldfastRules.TICK_RATE) - 2)
		expect_false(rules.recruits[0].up, "%s: not yet" % [pair[0]])
		_run(rules, 4)
		expect_true(rules.recruits[0].up, "%s: up after %s s with the Hero on them" % [pair[0], pair[1]])


func test_a_damage_trait_scales_the_levels_damage_gain_too_and_armour_is_capped() -> void:
	var content: Dictionary = _content().duplicate(true)
	# Warden 3 damage, +1 a level; Sharp is x1.2 on damage: level 3 is 3 x 1.2 + 2 x 1.2 = 6.
	var sharp := RecruitRoster.build(_r("warden", ["sharp"], [], 15), content)
	expect_eq(sharp["level"], 3)
	expect_near(float(sharp["damage"]), 6.0, 0.0001, "the level gain is multiplied as well")
	content["recruit_traits"]["steady"]["effects"] = [{"stat": "armour", "add": 0.9}]
	expect_eq(RecruitRoster.build(_r("warden", ["steady"]), content)["armour"], RecruitRoster.ARMOUR_CAP, "armour stops at the cap")
	content["recruit_traits"]["steady"]["effects"] = [{"stat": "armour", "add": -0.5}]
	expect_eq(RecruitRoster.build(_r("warden", ["steady"]), content)["armour"], 0.0, "and never goes below nothing")


func test_each_round_has_its_own_board_and_the_first_is_pinned() -> void:
	var content := _content()
	var names := []
	for round_no in 6:
		names.append(RecruitRoster.offers(content, round_no, []).map(func(o: Dictionary) -> String: return o["name"]))
	for i in names.size() - 1:
		expect_ne(names[i], names[i + 1], "round %d is not round %d" % [i, i + 1])
	expect_eq(names[0], PINNED_ROUND_ZERO, "round 0 offers the same three every time the pack and seed are the same")


func test_the_boards_price_rises_with_each_hire_and_stays_at_the_last() -> void:
	var content := _content()
	var profile := _rich(100000)
	var paid := []
	for i in 7:
		var before: int = profile["gold"]
		profile = RecruitMeta.hire(content, profile, 0)
		paid.append(before - int(profile["gold"]))
		profile = RecruitMeta.bank_run(content, profile, {})
	expect_eq(paid, [150, 300, 600, 1200, 1200, 1200, 1200], "the pack's price list, then the last price")
	expect_eq(RecruitMeta.board(content, profile)[0]["cost"], 1200)


func test_a_class_the_pack_locks_is_never_on_the_board() -> void:
	var content := _content()
	expect_true(content["recruit_classes"]["alchemist"]["locked"] and content["recruit_classes"]["engineer"]["locked"], "the Alchemist and Engineer ship locked")
	expect_false(content["recruit_classes"]["warden"].get("locked", false) or content["recruit_classes"]["lookout"].get("locked", false))
	for round_no in 40:
		for offer in RecruitRoster.offers(content, round_no, []):
			expect_true(offer["class"] in ["warden", "lookout"], "round %d offers only unlocked classes" % round_no)


# ------------------------------------------------------------------ the 24 skill choices

## The unit a run builds for a Recruit holding `picks` (the first of each earlier fork) and then `skill_id`.
func _with_skill(skill_id: String, with: bool) -> HoldfastRules.Attacker:
	var skill: Dictionary = _content()["recruit_skills"][skill_id]
	var picks := []
	for fork in range(1, int(skill["fork"])):
		for id in _content()["recruit_skills"]:
			if _content()["recruit_skills"][id]["class"] == skill["class"] and _content()["recruit_skills"][id]["fork"] == fork and picks.size() < fork:
				picks.append(id)
	var recruit := _r(skill["class"], [], picks + ([skill_id] if with else []), 100)
	return _quiet([recruit]).recruits[0]


func test_every_skill_choice_changes_the_unit_by_what_its_effects_say() -> void:
	for skill_id in _content()["recruit_skills"]:
		var skill: Dictionary = _content()["recruit_skills"][skill_id]
		var before := _with_skill(skill_id, false)
		var after := _with_skill(skill_id, true)
		for effect in skill["effects"]:
			var want := _stat(before, effect["stat"])
			want = (want + float(effect.get("add", 0.0))) * float(effect.get("multiply", 1.0))
			expect_near(_stat(after, effect["stat"]), want, 0.0001, "%s changes %s" % [skill_id, effect["stat"]])
			expect_true(absf(_stat(after, effect["stat"]) - _stat(before, effect["stat"])) > 0.0001, "%s is a change from not having it" % skill_id)


func test_the_skills_do_what_the_pack_describes_in_numbers() -> void:
	# Hand-worked from the Warden (40 health, 3 damage + 1 a level), Lookout, Alchemist and Engineer entries; level 5 (xp 100).
	var cases := [
		["warden", [], "warden_taunt", "taunt_radius", 210.0],
		["warden", [], "warden_bulwark", "health", 56.0],
		["warden", [], "warden_bulwark", "armour", 0.15],
		["warden", ["warden_taunt"], "warden_quick_blows", "cooldown", 0.64],
		["lookout", [], "lookout_hard_mark", "mark_bonus", 0.5],
		["lookout", [], "lookout_wide_watch", "effect_radius", 170.0],
		["lookout", ["lookout_wide_watch"], "lookout_cold_snap", "slow", 0.45],
		["alchemist", [], "alchemist_slow_field", "slow", 0.25],
		["alchemist", [], "alchemist_mending_field", "heal_per_second", 3.0],
		["alchemist", ["alchemist_slow_field"], "alchemist_hotter_burn", "field_dps", 6.4],
		["engineer", [], "engineer_fast_repairs", "repair_per_second", 8.0],
		["engineer", ["engineer_wide_reach"], "engineer_spanner", "damage", 10.5],
	]
	for each in cases:
		var unit: HoldfastRules.Attacker = _quiet([_r(each[0], [], each[1] + [each[2]], 100)]).recruits[0]
		expect_near(_stat(unit, each[3]), each[4], 0.0001, "%s: %s" % [each[2], each[3]])


func test_a_skill_is_only_picked_from_the_fork_on_offer() -> void:
	var content := _content()
	var fresh := _r("warden")
	expect_eq(RecruitRoster.offer(fresh, content), {}, "level 1 has no pick")
	var second := _r("warden", [], [], 5)
	expect_eq(RecruitRoster.offer(second, content), {"fork": 1, "options": ["warden_taunt", "warden_bulwark"]}, "level 2 opens the first fork")
	expect_eq(RecruitRoster.pick(second, "warden_heavy", content), {}, "not one from the second fork yet")
	expect_eq(RecruitRoster.pick(second, "lookout_wide_watch", content), {}, "nor another class's")
	var picked := RecruitRoster.pick(second, "warden_bulwark", content)
	expect_eq(picked["skills"], ["warden_bulwark"])
	expect_eq(second["skills"], [], "the one given is left alone")
	expect_eq(RecruitRoster.offer(picked, content), {}, "the second fork waits for level 3")
	var third := _r("warden", [], ["warden_bulwark"], 15)
	expect_eq(RecruitRoster.offer(third, content)["fork"], 2, "level 3 opens the second")
	var all := _r("warden", [], ["warden_bulwark", "warden_heavy", "warden_rally"], 500)
	expect_eq(RecruitRoster.offer(all, content), {}, "three forks and no more")


# ------------------------------------------------------------------ XP, levels and traits

func test_a_recruit_who_reaches_level_five_gains_one_trait_the_same_way_every_time() -> void:
	var content := _content()
	var recruit := _r("lookout", ["sharp"], [], 29, "r7")
	var grown := RecruitRoster.grow(recruit, content, 21)
	expect_eq(grown["from"], 3)
	expect_eq(grown["to"], 5, "50 xp is level 5")
	expect_true(grown["trait"] != "" and grown["trait"] != "sharp", "a trait they did not have")
	expect_eq(grown["recruit"]["traits"].size(), 2)
	expect_eq(RecruitRoster.grow(recruit, content, 21)["trait"], grown["trait"], "the same every time")
	expect_eq(RecruitRoster.grow(grown["recruit"], content, 200)["recruit"]["traits"].size(), 2, "never a third")
	expect_eq(RecruitRoster.grow(_r("lookout", [], [], 0), content, 5)["trait"], "", "no trait before level 5")
	expect_eq(recruit["xp"], 29, "the one given is left alone")
	for trait_id in TRAITS:
		for n in 12:
			var held := RecruitRoster.grow(_r("lookout", [trait_id], [], 29, "r%d" % n), content, 21)
			expect_true(held["trait"] != trait_id and content["recruit_traits"].has(held["trait"]), "a Recruit with %s (r%d) gains a different trait" % [trait_id, n])


func test_the_xp_a_run_pays_levels_the_squad_in_the_run_and_is_reported() -> void:
	var content := _content()
	var rules := _quiet([_r("warden", [], [], 0, "a"), _r("lookout", ["eager"], [], 0, "b")])
	var warden: HoldfastRules.Attacker = rules.recruits[0]
	var lookout: HoldfastRules.Attacker = rules.recruits[1]
	var damage := warden.damage
	rules._gain_xp(5)
	expect_eq(warden.level, 2, "5 xp is a level")
	expect_eq(warden.damage, damage + 1.0, "a level's damage lands in the run")
	expect_true(warden.flash_left > 0.0 and warden.bark != "" and warden.bark_left > 0.0, "the level-up flashes and calls out")
	expect_eq(lookout.run_xp, 6, "an Eager Recruit's 5 is 6 (5 x 1.25, rounded)")
	expect_eq(rules.result()["recruit_xp"], {"a": 5, "b": 6}, "the run reports each Recruit's XP")
	var profile := _rich(0)
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": HoldfastRules.OUTCOME_LOST, "level": "outpost", "gold": 0, "recruit_xp": {"bryn": 5, "wren": 3, "nobody": 9}})
	expect_eq(RecruitMeta.recruit(profile, "bryn")["xp"], 5)
	expect_eq(RecruitMeta.recruit(profile, "wren")["xp"], 3)
	expect_eq(RecruitMeta.pending_picks(content, profile).map(func(p: Dictionary) -> String: return p["id"]), ["bryn"], "Bryn's level opens a pick")
	var changes := RecruitMeta.changes(content, _rich(0), profile)
	expect_eq(changes.size(), 1, "one level-up to tell the player about")
	expect_eq([changes[0]["name"], changes[0]["from"], changes[0]["to"]], ["Bryn", 1, 2])


# ------------------------------------------------------------------ the squad in the run

func test_the_squad_takes_the_posts_in_order_and_the_rest_stand_round_the_keep() -> void:
	var squad := [_r("warden", [], [], 0, "a"), _r("lookout", [], [], 0, "b"), _r("alchemist", [], [], 0, "c"), _r("engineer", [], [], 0, "d")]
	var rules := _quiet(squad)
	expect_eq(rules.recruits.size(), 4)
	expect_eq(rules.recruits.map(func(u: HoldfastRules.Attacker) -> String: return u.post), ["east_post", "west_post", "", ""], "two posts, so two staff them")
	expect_eq(rules.recruits[0].position, Vector2(130, -60) + HoldfastRules.POST_OFFSET)
	expect_true(rules.recruits[2].position.distance_to(Vector2.ZERO) < 200.0 and rules.recruits[3].position.distance_to(Vector2.ZERO) < 200.0, "the others stand by the keep")
	expect_ne(rules.recruits[2].position, rules.recruits[3].position, "not on top of each other")
	expect_eq(rules.posts.size(), 2, "the light posts are always there")
	var gull := HoldfastRules.new()
	gull.setup(HoldfastContent.run_config("gull_rock", [], _content(), "flare_archer", null, {}, [], false, squad), SimRng.new(1))
	expect_eq(gull.recruits.map(func(u: HoldfastRules.Attacker) -> String: return u.post), ["east_post", "west_post", "south_post", ""], "three posts on Gull Rock")


func test_no_squad_still_lights_the_posts_and_an_unusable_squad_is_refused() -> void:
	var empty := _quiet([])
	expect_eq(empty.recruits.size(), 0)
	expect_eq(empty.staff, null)
	expect_eq(empty.posts.size(), 2, "the lights stand without Recruits")
	var five := _quiet([_r("warden", [], [], 0, "a"), _r("warden", [], [], 0, "b"), _r("warden", [], [], 0, "c"), _r("warden", [], [], 0, "d"), _r("warden", [], [], 0, "e")])
	expect_eq(five.outcome, HoldfastRules.OUTCOME_INVALID, "five is one too many")
	expect_eq(_quiet([_r("warden"), _r("lookout")]).outcome, HoldfastRules.OUTCOME_INVALID, "two with the same id")
	expect_eq(_quiet([_r("nobody")]).outcome, HoldfastRules.OUTCOME_INVALID, "a class the pack lacks")
	expect_ne(_quiet([_r("warden", [], [], 0, "a"), _r("lookout", [], [], 0, "b")]).outcome, HoldfastRules.OUTCOME_INVALID, "a good pair is fine")


func test_a_run_without_a_squad_in_its_config_keeps_the_levels_own_pair() -> void:
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost"), SimRng.new(1))
	expect_eq(rules.recruits.map(func(u: HoldfastRules.Attacker) -> String: return u.id), ["bryn", "wren"])


func test_armour_turns_a_share_of_each_blow_away() -> void:
	var plain := _quiet([_r("warden", [], [], 0, "a")])
	var bulwark := _quiet([_r("warden", [], ["warden_bulwark"], 5, "a")])
	plain._hit_unit(plain.recruits[0], 10.0)
	bulwark._hit_unit(bulwark.recruits[0], 10.0)
	expect_near(plain.recruits[0].health["health"], 30.0, 0.0001)
	expect_near(bulwark.recruits[0].health["health"], 56.0 - 8.5, 0.0001, "10 x 0.85 off 56")


func test_a_mending_field_heals_recruits_standing_in_it() -> void:
	# The Alchemist at the east post stands inside their own field: 3 a second, and 2 a second of rest heal at their post.
	var rules := _quiet([_r("alchemist", [], ["alchemist_mending_field"], 5, "a")])
	rules.recruits[0].health["health"] = 10.0
	_run(rules, 30)
	expect_near(rules.recruits[0].health["health"], 15.0, 0.2, "10 + 3 + 2")
	var without := _quiet([_r("alchemist", [], [], 0, "a")])
	without.recruits[0].health["health"] = 10.0
	_run(without, 30)
	expect_near(without.recruits[0].health["health"], 12.0, 0.2, "the rest heal alone")


func test_a_slowing_field_slows_enemies_in_it() -> void:
	# The Alchemist at the east post (130,-60): the field reaches 120 + an enemy's 10.
	var rules := _quiet([_r("alchemist", [], ["alchemist_slow_field"], 5, "a")])
	var inside := _enemy(rules, Vector2(130, 60))
	var outside := _enemy(rules, Vector2(130, 71))
	_run(rules, 1)
	expect_near(inside.zone_slow, 0.25, 0.0001)
	expect_eq(outside.zone_slow, 0.0)


func test_a_recruits_fall_calls_out_and_is_plain_to_see() -> void:
	var rules := _quiet([_r("warden", [], [], 0, "a")])
	var unit: HoldfastRules.Attacker = rules.recruits[0]
	rules._hit_unit(unit, 1000.0)
	expect_false(unit.up, "knocked out")
	expect_true(unit.bark != "" and unit.bark_left > 0.0, "with a cry")
	_run(rules, int(HoldfastRules.BARK_SECONDS * HoldfastRules.TICK_RATE) + 2)
	expect_eq(unit.bark_left, 0.0, "which fades")


func test_a_wave_starting_has_one_recruit_call_out() -> void:
	var content: Dictionary = _content().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 0.0
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, "flare_archer", null, {}, [], false, [_r("warden", [], [], 0, "a"), _r("lookout", [], [], 0, "b")]), SimRng.new(1))
	_run(rules, 2)
	var calling := rules.recruits.filter(func(u: HoldfastRules.Attacker) -> bool: return u.bark != "")
	expect_eq(calling.size(), 1, "one of the two")
	expect_true(calling[0].role["barks"]["wave"].has(calling[0].bark), "a line from their class")


func test_a_level_gained_in_the_run_grows_with_a_damage_trait() -> void:
	var rules := _quiet([_r("warden", ["sharp"])])
	var unit: HoldfastRules.Attacker = rules.recruits[0]
	expect_near(unit.damage, 3.6, 0.0001, "3 x 1.2")
	rules._gain_xp(5)
	expect_near(unit.damage, 4.8, 0.0001, "a level's +1 is +1.2 for a Sharp Recruit")


func test_a_rescue_with_a_full_squad_joins_the_roster_but_not_the_squad() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile["recruits"]["roster"] = [_r("lookout", [], [], 0, "x"), _r("lookout", [], [], 0, "y")]
	profile["recruits"]["squad"] = ["x", "y"]
	var won := _win(content, profile, "shingle_beach")
	expect_eq(won["recruits"]["roster"].size(), 3, "Bryn is rescued all the same")
	expect_eq(won["recruits"]["squad"], ["x", "y"], "but the player's squad is not changed under them")


func test_the_wave_callouts_go_round_the_squad() -> void:
	var rules := _quiet([_r("warden", [], [], 0, "a"), _r("lookout", [], [], 0, "b")])
	rules._bark_a_wave(1)
	expect_eq([rules.recruits[0].bark, rules.recruits[1].bark != ""], ["", true], "wave 1: the second Recruit calls")
	rules._bark_a_wave(2)
	expect_true(rules.recruits[0].bark != "", "wave 2: the first again")


func test_a_recruit_who_gets_up_says_so() -> void:
	var rules := _quiet([_r("warden")])
	var unit: HoldfastRules.Attacker = rules.recruits[0]
	rules.hero_position = unit.position
	rules._hit_unit(unit, 1000.0)
	unit.bark = ""
	_run(rules, 3 * HoldfastRules.TICK_RATE + 2)
	expect_true(unit.up and unit.role["barks"]["up"].has(unit.bark), "back on their feet, a line from the class")


func test_a_recruit_exactly_at_their_flee_line_stands_and_a_fleeing_one_never_strikes() -> void:
	var rules := _quiet([_r("warden", ["coward"])])
	var unit: HoldfastRules.Attacker = rules.recruits[0]
	unit.health["health"] = 20.0
	_run(rules, 1)
	expect_false(unit.fleeing, "20 of 40 is exactly half: not below it")
	unit.health["health"] = 19.0
	var enemy := _enemy(rules, unit.position + Vector2(20, 0), 100.0)
	for i in 10:
		enemy.position = unit.position + Vector2(20, 0)
		_run(rules, 1)
	expect_true(unit.fleeing, "below half")
	expect_eq(enemy.health, 100.0, "and not one blow struck while fleeing")


func test_a_fleeing_warden_stops_taunting_and_a_fleeing_alchemist_stops_its_field() -> void:
	var rules := _quiet([_r("warden", ["coward"], ["warden_taunt"], 100)])
	rules._refresh_targets()
	var unit: HoldfastRules.Attacker = rules.recruits[0]
	expect_true(unit.candidate["taunt_radius"] > 0.0, "a standing Warden with a taunt pulls enemies")
	unit.fleeing = true
	rules._targets_dirty = true
	rules._refresh_targets()
	expect_eq(unit.candidate["taunt_radius"], 0.0, "a fleeing one does not")


func test_a_squad_can_win_a_level_in_the_simulator() -> void:
	var content := _content()
	var profile := _rich(0)
	var config := HoldfastContent.run_config("first_watch", [], content, "flare_archer", null, {}, [], false, RecruitMeta.bot_squad(content, profile))
	var report := SimBotRunner.run(HoldfastRules.new(), HoldfastHeroBot.new(), 1, config, 40000, HoldfastRules.TICK_RATE)
	expect_true(report["finished"], "the run ends")
	expect_true(report["result"]["recruit_xp"].size() == 2 and report["result"]["recruit_xp"].values().all(func(v: int) -> bool: return v >= 0), "and reports what each Recruit earned")


func _collect(content: Dictionary, id: String, out: Array) -> void:
	for required in content["upgrade_nodes"][id].get("requires", []):
		_collect(content, required, out)
	if not id in out:
		out.append(id)


## How long the Outpost's post waits after its first shot at an enemy 90 paces off, with Lit Post
## owned, `squad` standing at the post and the Hero at `hero_at`.
func _post_ready_in(squad: Array, hero_at: Vector2) -> float:
	var content: Dictionary = _content().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 5.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	var owned := []
	_collect(content, "link_lit_post", owned)
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config("outpost", owned, content, "flare_archer", null, {}, [], false, squad), SimRng.new(1))
	rules.hero_position = hero_at
	var post := Vector2(-90, 30)
	for recruit in rules.recruits:
		recruit.position = post + Vector2(20, 0)
	_enemy(rules, post + Vector2(0, -90), 1000000.0)
	_run(rules, 1)
	return rules.tower.ready_in


func test_recruits_do_not_count_as_the_hero_for_lit_post() -> void:
	var squad := [_r("warden", [], [], 0, "a"), _r("lookout", [], [], 0, "b")]
	expect_near(_post_ready_in(squad, Vector2(700, 0)), _post_ready_in([], Vector2(700, 0)), 0.0001, "two Recruits beside the post, Hero far: the plain cooldown")
	expect_true(_post_ready_in([], Vector2(-70, 30)) < _post_ready_in(squad, Vector2(700, 0)) - 0.05, "the Hero beside the post does light it")


func test_a_blessing_never_changes_a_recruit() -> void:
	var content: Dictionary = _content().duplicate(true)
	var squad := [_r("warden", ["sturdy"], [], 5, "a"), _r("lookout", [], ["lookout_long_sight"], 10, "b")]
	var plain := HoldfastRules.new()
	plain.report_errors = false
	plain.setup(HoldfastContent.run_config("outpost", [], content, "flare_archer", null, {}, [], false, squad), SimRng.new(1))
	for blessing in content["blessings"]:
		var blessed := HoldfastRules.new()
		blessed.report_errors = false
		blessed.setup(HoldfastContent.run_config("outpost", [], content, "flare_archer", null, {}, [], false, squad, blessing), SimRng.new(1))
		for i in plain.recruits.size():
			for stat in ["damage", "range", "cooldown", "health", "armour", "flee_below", "xp_gain", "leash"]:
				expect_eq(_stat(blessed.recruits[i], stat), _stat(plain.recruits[i], stat), "%s leaves %s alone" % [blessing, stat])


# ------------------------------------------------------------------ the profile: slots, board, hiring

## A profile with Bryn and Wren rescued and `gold` in hand.
func _rich(gold := 1000) -> Dictionary:
	var content := _content()
	var profile := _win(content, _win(content, HoldfastMeta.new_profile(content), "shingle_beach"), "old_pier")
	profile["gold"] = gold
	return profile


func test_the_squad_arm_sells_the_third_and_fourth_slot_for_stars() -> void:
	var content := _content()
	var third: Dictionary = content["upgrade_nodes"]["squad_hand_3"]
	var fourth: Dictionary = content["upgrade_nodes"]["squad_hand_4"]
	expect_eq([third["currency"], int(third["cost"]), fourth["currency"], int(fourth["cost"])], ["stars", 2, "stars", 3], "2 stars, then 3")
	expect_eq(Array(fourth["requires"]), ["squad_hand_3"], "the fourth needs the third")
	expect_eq(Array(third["requires"]), ["castle_archer_1"], "the arm starts at the first Archer Post")
	var profile := _rich()
	expect_eq(RecruitMeta.slots(content, profile), 2)
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1", "squad_hand_3"]
	expect_eq(RecruitMeta.slots(content, profile), 3)
	profile["upgrades"].append("squad_hand_4")
	expect_eq(RecruitMeta.slots(content, profile), 4)
	var early := _rich()
	early["upgrades"] = ["castle_slot_1"]
	early["stars"] = {"x": 9}
	expect_eq(HoldfastMeta.why_not_buy(content, early, "squad_hand_3"), "Needs Archer Post first", "closed until the Archer Post is owned")


func test_the_tree_sells_the_third_and_fourth_slot() -> void:
	var content: Dictionary = _content().duplicate(true)
	content["upgrade_nodes"]["castle_slot_1"]["grants"]["squad"] = 1
	content["upgrade_nodes"]["castle_slot_2"]["grants"]["squad"] = 1
	var profile := _rich()
	expect_eq(RecruitMeta.slots(content, profile), 2)
	profile["upgrades"] = ["castle_slot_1"]
	expect_eq(RecruitMeta.slots(content, profile), 3)
	profile["upgrades"] = ["castle_slot_1", "castle_slot_2"]
	expect_eq(RecruitMeta.slots(content, profile), 4)
	content["upgrade_nodes"]["castle_slot_3"]["grants"]["squad"] = 5
	profile["upgrades"].append("castle_slot_3")
	expect_eq(RecruitMeta.slots(content, profile), 4, "never more than four")


func test_the_squad_is_picked_from_the_roster_up_to_the_slots() -> void:
	var content := _content()
	var profile := _rich()
	profile = RecruitMeta.hire(content, profile, 0)
	var hired: String = profile["recruits"]["roster"][2]["id"]
	expect_eq(RecruitMeta.why_not_squad(content, profile, hired), "The squad is full (2 of 2). Take someone off first.")
	expect_eq(RecruitMeta.toggle_squad(content, profile, hired)["recruits"]["squad"], ["bryn", "wren"], "a full squad takes no one")
	var off := RecruitMeta.toggle_squad(content, profile, "bryn")
	expect_eq(off["recruits"]["squad"], ["wren"], "taking Bryn off")
	var swapped := RecruitMeta.toggle_squad(content, off, hired)
	expect_eq(swapped["recruits"]["squad"], ["wren", hired], "and the new one on, in the order they were put")
	expect_eq(RecruitMeta.squad_for_run(content, swapped).map(func(r: Dictionary) -> String: return r["id"]), ["wren", hired])
	expect_eq(RecruitMeta.toggle_squad(content, profile, "nobody"), profile, "no one by that name")
	expect_eq(profile["recruits"]["squad"], ["bryn", "wren"], "the profile given is left alone")


func test_the_board_offers_three_the_same_every_time_and_a_hire_costs_gold() -> void:
	var content := _content()
	var profile := _rich(1000)
	var board := RecruitMeta.board(content, profile)
	expect_eq(board.size(), 3)
	expect_eq(RecruitMeta.board(content, profile), board, "the same board for the same round")
	for offer in board:
		expect_true(content["recruit_classes"].has(offer["class"]) and offer["traits"].size() == 1 and content["recruit_traits"].has(offer["traits"][0]), "a class and one trait from the pack")
		expect_eq(offer["cost"], 150, "the first hire's price")
		expect_false(content["recruit_classes"][offer["class"]].get("locked", false), "never a locked class")
		expect_false(offer["name"] in ["Bryn", "Wren"], "never a name already on the roster")
	var hired := RecruitMeta.hire(content, profile, 1)
	expect_eq(hired["gold"], 1000 - 150, "the price is paid")
	expect_eq(hired["recruits"]["roster"].size(), 3)
	var joined: Dictionary = hired["recruits"]["roster"][2]
	expect_eq([joined["name"], joined["class"], joined["traits"], joined["xp"]], [board[1]["name"], board[1]["class"], board[1]["traits"], 0])
	expect_eq(RecruitMeta.board(content, hired).map(func(o: Dictionary) -> int: return o["index"]), [0, 2], "off the board once hired")
	expect_eq(RecruitMeta.why_not_hire(content, hired, 1), "They have left the board.")
	expect_eq(RecruitMeta.hire(content, hired, 1), hired, "and not hired twice")
	expect_eq(profile["gold"], 1000, "the profile given is left alone")
	var next := RecruitMeta.bank_run(content, hired, {})
	expect_eq(next["recruits"]["round"], hired["recruits"]["round"] + 1)
	expect_ne(RecruitMeta.board(content, next), board, "a new board after a run")
	expect_eq(RecruitMeta.board(content, next).size(), 3, "all three open again")


func test_a_hire_is_refused_without_the_gold_or_a_place_on_the_roster() -> void:
	var content := _content()
	var broke := _rich(0)
	expect_eq(RecruitMeta.why_not_hire(content, broke, 0), "Not enough gold.")
	expect_eq(RecruitMeta.hire(content, broke, 0), broke)
	var full := _rich(100000)
	for i in 10:
		full = RecruitMeta.hire(content, full, 0)
		full = RecruitMeta.bank_run(content, full, {})
	expect_eq(full["recruits"]["roster"].size(), 12, "the roster fills at twelve")
	expect_eq(RecruitMeta.why_not_hire(content, full, 0), "Your roster is full (12).")
	var ids: Array = full["recruits"]["roster"].map(func(r: Dictionary) -> String: return r["id"])
	var names: Array = full["recruits"]["roster"].map(func(r: Dictionary) -> String: return r["name"])
	expect_eq(ids.size(), ids.duplicate().filter(func(id: String) -> bool: return ids.count(id) == 1).size(), "every id is their own")
	expect_eq(names.size(), names.duplicate().filter(func(n: String) -> bool: return names.count(n) == 1).size(), "and every name")


func test_a_pick_goes_to_the_recruit_and_the_profile_given_is_left_alone() -> void:
	var content := _content()
	var profile := _rich()
	profile["recruits"]["roster"][0]["xp"] = 5
	expect_eq(RecruitMeta.pick_skill(content, profile, "bryn", "warden_heavy"), profile, "the wrong fork changes nothing")
	var picked := RecruitMeta.pick_skill(content, profile, "bryn", "warden_taunt")
	expect_eq(picked["recruits"]["roster"][0]["skills"], ["warden_taunt"])
	expect_eq(profile["recruits"]["roster"][0]["skills"], [])
	expect_eq(RecruitMeta.pending_picks(content, picked), [], "nothing waiting once made")


# ------------------------------------------------------------------ names and saves

func test_the_keep_the_hero_and_every_recruit_can_be_renamed() -> void:
	var profile := _rich()
	expect_eq(RecruitMeta.name_of(profile, "keep"), "The Keep")
	expect_eq(RecruitMeta.name_of(profile, "hero"), "Hero")
	expect_eq(RecruitMeta.name_of(profile, "bryn"), "Bryn")
	profile = RecruitMeta.rename(profile, "keep", "  Mossgate\tHold  ")
	profile = RecruitMeta.rename(profile, "hero", "Ada")
	profile = RecruitMeta.rename(profile, "bryn", "Big   Bryn")
	expect_eq(RecruitMeta.name_of(profile, "keep"), "Mossgate Hold", "control characters and spare spaces go")
	expect_eq(RecruitMeta.name_of(profile, "hero"), "Ada")
	expect_eq(RecruitMeta.name_of(profile, "bryn"), "Big Bryn")
	expect_eq(RecruitMeta.rename(profile, "bryn", "   "), profile, "a blank name changes no Recruit")
	expect_eq(RecruitMeta.name_of(RecruitMeta.rename(profile, "keep", ""), "keep"), "The Keep", "a blank keep goes back to the default")
	expect_eq(RecruitMeta.name_of(RecruitMeta.rename(profile, "hero", "A".repeat(40)), "hero").length(), RecruitRoster.NAME_MAX, "long names are cut")
	expect_eq(RecruitMeta.rename(profile, "nobody", "X"), profile, "no one by that id")


func test_names_the_roster_and_the_squad_survive_a_save() -> void:
	var content := _content()
	var profile := _rich(500)
	profile = RecruitMeta.hire(content, profile, 0)
	profile = RecruitMeta.rename(profile, "keep", "Mossgate")
	profile = RecruitMeta.rename(profile, "wren", "Wrenna")
	profile["recruits"]["roster"][0]["xp"] = 20
	profile = RecruitMeta.pick_skill(content, profile, "bryn", "warden_bulwark")
	profile["recruits"]["squad"] = ["wren"]
	var loaded := HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(profile)))
	expect_eq(loaded["recruits"], profile["recruits"], "the roster, squad, board round and picks come back whole")
	expect_eq(loaded["names"], profile["names"])


func test_a_save_without_recruits_or_with_damaged_ones_is_made_safe() -> void:
	var content := _content()
	var old := HoldfastMeta.from_save(content, {"gold": 10})
	expect_eq(old["recruits"], {"roster": [], "squad": [], "round": 0, "hired": [], "next": 1, "bought": 0}, "an old save has no Recruits yet")
	var damaged := HoldfastMeta.from_save(content, {"recruits": {"roster": [
		{"id": "x", "name": "Fine", "class": "alchemist", "traits": ["sharp", "nonsense", "sharp"], "xp": -5, "skills": ["alchemist_hotter_burn", "alchemist_slow_field"]},
		{"id": "x", "name": "Twin", "class": "warden"},
		{"id": "y", "name": "", "class": "warden"},
		{"id": "z", "name": "Lost", "class": "pirate"},
		"junk",
	], "squad": ["x", "x", "gone", "y"], "round": "two", "hired": [0, 0, 7, "a"], "next": 0, "bought": -4}, "names": {"keep": 7, "hero": "\u0001\u0002"}})
	var roster: Array = damaged["recruits"]["roster"]
	expect_eq(roster.size(), 1, "only the whole one is kept")
	expect_eq(roster[0]["traits"], ["sharp"], "a trait the pack has, once")
	expect_eq(roster[0]["xp"], 0)
	expect_eq(roster[0]["skills"], ["alchemist_slow_field"], "a pick made out of order (fork two first) is dropped, the fork-one pick after it stays")
	expect_eq(damaged["recruits"]["squad"], ["x"], "the squad holds only who is on the roster, once")
	expect_eq([damaged["recruits"]["round"], damaged["recruits"]["hired"], damaged["recruits"]["next"], damaged["recruits"]["bought"]], [0, [0], 1, 0])
	expect_eq(damaged["names"], {"keep": "7", "hero": ""})
	var crowded := HoldfastMeta.from_save(content, {"recruits": {"roster": [{"id": "a", "name": "A", "class": "warden"}, {"id": "b", "name": "B", "class": "warden"}, {"id": "c", "name": "C", "class": "warden"}], "squad": ["a", "b", "c"]}})
	expect_eq(crowded["recruits"]["squad"], ["a", "b"], "a squad longer than the slots is cut")


# ------------------------------------------------------------------ what the bots do

func test_a_bot_takes_the_highest_levels_one_of_each_class_first() -> void:
	var content := _content()
	var profile := _rich()
	profile["recruits"]["roster"] = [_r("warden", [], [], 30, "a"), _r("warden", [], [], 50, "b"), _r("lookout", [], [], 5, "c"), _r("engineer", [], [], 0, "d")]
	expect_eq(RecruitMeta.bot_squad(content, profile).map(func(r: Dictionary) -> String: return r["id"]), ["b", "c"], "the best warden, then the next class, before a second warden")
	profile["upgrades"] = []
	var picked := RecruitMeta.bot_picks(content, profile)
	expect_eq(RecruitMeta.recruit(picked, "b")["skills"].size(), 3, "a bot takes every pick waiting, the first of each two")
	expect_eq(RecruitMeta.recruit(picked, "d")["skills"], [], "and none that is not open")
