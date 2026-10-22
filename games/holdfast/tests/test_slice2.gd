extends KitTestCase
## HF-M2-14 / HF-M2-15 slice 2: the Dusk Mage and Tideblade, light posts, enemies
## that fight back, the Hero's knock-down and Recruits that fall and are revived.
## Expected numbers are worked by hand from the pack values noted beside them.
##
## Pack: Hero starts (0, 80); keep at (0, 0); tower (-90, 30) health 60; Bryn
## (Warden, health 40) at (112, -48) staffing the east post (130, -60); Wren
## (Lookout, health 35) at (-118, 58) staffing the west post (-130, 70); lit
## radius 90, bonus 0.5.

const Main := preload("res://scenes/main.tscn")
const DT := 1.0 / HoldfastRules.TICK_RATE
const BIG := 1000000.0


## Rules with no wave for 1000 s and nothing of ours doing damage, so only what a
## test adds hurts anything. `hero` picks the pillar; `edit` changes the content.
func _quiet(hero: String = "flare_archer", edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	if hero != "":
		content["hero_paths"][hero]["attack"]["damage"] = 0.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, hero), SimRng.new(1))
	return rules


## `_quiet` with the Hero's attack at its pack damage, so only the ability is silent.
func _with_attack(hero: String, edit: Callable = Callable()) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content, hero), SimRng.new(1))
	return rules


func _drop_posts(content: Dictionary) -> void:
	content["levels"]["outpost"]["staff"].erase("post")
	for at in content["levels"]["outpost"]["recruits"]:
		at.erase("post")


func _enemy(rules: HoldfastRules, at: Vector2, health: float = 100.0, damage: int = 0) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	enemy.speed = 0.0
	enemy.damage = damage
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


# ------------------------------------------------------------------ the pack

func test_the_three_pillars_are_in_the_pack_with_what_their_behaviours_need() -> void:
	var paths: Dictionary = HoldfastContent.base()["hero_paths"]
	expect_eq(paths.keys().size(), 3)
	for id in ["flare_archer", "dusk_mage", "tideblade"]:
		expect_true(paths.has(id), id)
	for id in paths:
		for slot in ["attack", "ability"]:
			var action: Dictionary = paths[id][slot]
			match action["kind"]:
				"projectile":
					expect_true(action.has("speed") and action.has("radius"), "%s %s needs speed and radius" % [id, slot])
				"area":
					expect_true(action.has("radius"), "%s %s needs a radius" % [id, slot])
	expect_eq(paths["dusk_mage"]["ability"]["name"], "Eclipse")
	expect_eq(paths["tideblade"]["ability"]["name"], "Dash-Strike")


func test_an_unknown_hero_path_is_refused_by_name() -> void:
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config("outpost", [], {}, "no_such_path"), SimRng.new(1))
	expect_eq(rules.setup_error, "unknown Hero path no_such_path")
	expect_eq(rules.outcome, HoldfastRules.OUTCOME_INVALID)


# ------------------------------------------------------------------ Dusk Mage

func test_the_mage_hits_harder_in_the_dark() -> void:
	# Pack: area attack, damage 5, unlit bonus 0.6, range 190, radius 40. Hero at (0,80).
	# Unlit enemy (0,-100), 180 away, far from both posts: 5 x 1.6 = 8, so 92.
	var rules := _with_attack("dusk_mage")
	var dark := _enemy(rules, Vector2(0, -100))
	_run(rules, 1)
	expect_near(dark.health, 92.0, 0.0001, "unlit: 5 x 1.6")
	# Enemy on the east post (130,-60), 191 away: lit, so 5 x 1.5 = 7.5 (the unlit bonus is for the dark only).
	var lit_rules := _with_attack("dusk_mage")
	var lit := _enemy(lit_rules, Vector2(130, -60))
	_run(lit_rules, 1)
	expect_near(lit.health, 92.5, 0.0001, "lit: 5 x 1.5")


func test_the_mage_burst_hits_only_what_is_within_its_radius() -> void:
	# Burst radius 40 round the target at (0,-100), plus an enemy's radius 10.
	var rules := _with_attack("dusk_mage")
	var target := _enemy(rules, Vector2(0, -100))
	var close := _enemy(rules, Vector2(-50, -100))  # exactly 50 = 40 + 10: in
	var far := _enemy(rules, Vector2(-51, -100))
	_run(rules, 1)
	expect_near(close.health, 92.0, 0.0001, "on the edge is hit")
	expect_eq(far.health, 100.0, "a pixel beyond is not")
	expect_near(target.health, 92.0, 0.0001)


func test_eclipse_blasts_round_the_hero_and_slows() -> void:
	# Pack: damage 14, unlit bonus 1.0, radius 150 round the Hero (0,80), slow 0.5 for 3 s.
	# Reach is 150 + 10: an enemy at (0,-60) is 140 away. Unlit: 14 x 2 = 28, so 72.
	var rules := _quiet("dusk_mage")
	var dark := _enemy(rules, Vector2(0, -60))
	var out := _enemy(rules, Vector2(0, -90))  # 170 away
	_run(rules, 1, {"ability": true})
	expect_near(dark.health, 72.0, 0.0001, "unlit: 14 x 2")
	expect_eq(out.health, 100.0, "out of reach")
	expect_near(dark.slow_amount, 0.5, 0.0001)
	expect_near(dark.slowed_for, 3.0, 0.0001)
	expect_near(rules.hero_ability_ready_in, 10.0, 0.0001, "ten seconds to recharge")


func test_eclipse_in_the_light_gets_the_lit_bonus_instead() -> void:
	# Enemy at (-100,60), 31.6 from the west post: lit, so 14 x 1.5 = 21 (no unlit bonus). Wren's
	# post is dropped so her mark does not add to it.
	var rules := _quiet("dusk_mage", _drop_posts)
	var lit := _enemy(rules, Vector2(-100, 60))
	_run(rules, 1, {"ability": true})
	expect_near(lit.health, 79.0, 0.0001, "lit: 14 x 1.5")


# ------------------------------------------------------------------ Tideblade

func test_the_tideblade_arc_hits_what_is_in_front_and_in_range_only() -> void:
	# Pack: arc attack, damage 9, range 60, 100 degrees (50 either side). Hero (0,80) faces the
	# nearest enemy A, straight up. Reach is 60 + 10 = 70.
	var rules := _with_attack("tideblade", _drop_posts)
	var a := _enemy(rules, Vector2(0, 40))        # 40 away, ahead: hit, and the one faced
	var b := _enemy(rules, Vector2(35, 35))       # 57 away, 38 degrees off: hit
	var c := _enemy(rules, Vector2(60, 60))       # 63 away, 72 degrees off: outside the arc
	var behind := _enemy(rules, Vector2(0, 125))  # 45 away, behind
	var far := _enemy(rules, Vector2(0, 5))       # 75 away, ahead: out of reach
	_run(rules, 1)
	expect_eq(a.health, 91.0, "ahead")
	expect_eq(b.health, 91.0, "within the arc")
	expect_eq(c.health, 100.0, "outside the arc")
	expect_eq(behind.health, 100.0, "behind")
	expect_eq(far.health, 100.0, "out of reach")


func test_the_arc_edge_is_inclusive_at_fifty_degrees() -> void:
	var rules := _with_attack("tideblade", _drop_posts)
	_enemy(rules, Vector2(0, 40))  # faced
	var inside := _enemy(rules, Vector2(0, 80) + Vector2(sin(deg_to_rad(49.0)), -cos(deg_to_rad(49.0))) * 50.0)
	var outside := _enemy(rules, Vector2(0, 80) + Vector2(sin(deg_to_rad(51.0)), -cos(deg_to_rad(51.0))) * 50.0)
	_run(rules, 1)
	expect_eq(inside.health, 91.0, "49 degrees")
	expect_eq(outside.health, 100.0, "51 degrees")


func test_dash_strike_runs_through_enemies_along_the_path() -> void:
	# Pack: dash 150, range 40 (reach 50 with an enemy's radius), damage 20, cooldown 6.
	# Hero (0,80) faces N at (0,0), straight up, and ends the dash at (0,-70).
	var rules := _quiet("tideblade")
	var n := _enemy(rules, Vector2(0, 0))
	var near_path := _enemy(rules, Vector2(30, -30))  # 30 from the path
	var edge := _enemy(rules, Vector2(50, 10))        # exactly 50 from the path: hit
	var wide := _enemy(rules, Vector2(51, 10))        # 51: missed
	var past_end := _enemy(rules, Vector2(0, -200))   # 130 beyond the end of the dash
	_run(rules, 1, {"ability": true})
	expect_near(rules.hero_position.y, -70.0, 0.0001, "dashed 150 up")
	expect_near(rules.hero_position.x, 0.0, 0.0001)
	for hit in [n, near_path, edge]:
		expect_eq(hit.health, 80.0)
	expect_eq(wide.health, 100.0)
	expect_eq(past_end.health, 100.0)
	expect_near(rules.hero_ability_ready_in, 6.0, 0.0001, "no kill, so the full cooldown")


func test_dash_strike_that_kills_gives_the_ability_back() -> void:
	var rules := _quiet("tideblade")
	var weak := _enemy(rules, Vector2(0, 0), 20.0)
	_run(rules, 1, {"ability": true})
	expect_eq(rules.kills, 1)
	expect_true(weak.health <= 0.0)
	expect_eq(rules.hero_ability_ready_in, 0.0, "refunded on a kill")
	var spared := _quiet("tideblade")
	_enemy(spared, Vector2(0, 0), 20.5)
	_run(spared, 1, {"ability": true})
	expect_eq(spared.kills, 0)
	expect_near(spared.hero_ability_ready_in, 6.0, 0.0001, "left alive: not refunded")


# ------------------------------------------------------------------ light posts

func test_the_light_bonus_applies_to_tower_shots_inside_the_light() -> void:
	# Tower damage 4. (-90,170) is 107 from the west post: unlit, so 4. The post's Lookout is
	# dropped so no mark is added. Moving the enemy onto the post makes it lit: 4 x 1.5 = 6.
	var unlit := _quiet("flare_archer", func(c: Dictionary) -> void:
		_drop_posts(c)
		c["towers"]["archer_post"]["damage"] = 4.0)
	var dark := _enemy(unlit, Vector2(-90, 170))
	_run(unlit, 1)
	expect_eq(dark.health, 96.0, "unlit")
	var lit := _quiet("flare_archer", func(c: Dictionary) -> void:
		_drop_posts(c)
		c["towers"]["archer_post"]["damage"] = 4.0)
	var bright := _enemy(lit, Vector2(-130, 70))
	_run(lit, 1)
	expect_eq(bright.health, 94.0, "lit: 4 x 1.5")
	var none := _quiet("flare_archer", func(c: Dictionary) -> void:
		_drop_posts(c)
		c["towers"]["archer_post"]["damage"] = 4.0
		c["levels"]["outpost"]["light"]["bonus"] = 0.0)
	var plain := _enemy(none, Vector2(-130, 70))
	_run(none, 1)
	expect_eq(plain.health, 96.0, "a bonus of 0 is base damage")


# ------------------------------------------------------------------ enemies pick targets

func test_an_enemy_goes_for_the_nearest_tower_recruit_or_hero() -> void:
	var rules := _quiet("flare_archer", _drop_posts)
	var by_tower := _enemy(rules, Vector2(-90, 10))   # 20 from the tower, 55 from Wren
	var by_bryn := _enemy(rules, Vector2(130, 0))     # 51 from Bryn, 152 from the Hero
	var by_hero := _enemy(rules, Vector2(0, 60))      # 20 from the Hero
	_run(rules, 1)
	expect_eq(by_tower.target, "tower:archer_post")
	expect_eq(by_bryn.target, "recruit:bryn")
	expect_eq(by_hero.target, "hero")


func test_a_staffed_warden_pulls_enemies_within_reach_off_what_is_nearer() -> void:
	# (-20,-20): the tower is 86 away, Bryn 135, so the tower is nearer. Staffing the east post
	# makes Bryn's taunt (150) reach this enemy, so it goes for Bryn.
	var staffed := _quiet("flare_archer", func(c: Dictionary) -> void: c["levels"]["outpost"]["staff"]["post"] = "east_post")
	var pulled := _enemy(staffed, Vector2(-20, -20))
	_run(staffed, 1)
	expect_eq(pulled.target, "recruit:bryn", "taunted")
	var idle := _quiet("flare_archer", _drop_posts)
	var free := _enemy(idle, Vector2(-20, -20))
	_run(idle, 1)
	expect_eq(free.target, "tower:archer_post", "no post, no taunt")


func test_enemies_work_through_everything_then_hit_the_keep() -> void:
	# One enemy that kills with a hit and walks at 200 px/s, the Hero's knock-down never ending.
	# It takes the tower, then Wren, the Hero, Bryn, and only then the keep.
	var rules := _quiet("flare_archer", func(c: Dictionary) -> void:
		_drop_posts(c)
		c["hero_paths"]["flare_archer"]["knockdown_delays"] = [100000])
	var enemy := _enemy(rules, Vector2(-90, 10), BIG, 1000)
	enemy.speed = 200.0
	var seen: Array = []
	for i in 600:
		rules.step(DT, {})
		if seen.is_empty() or seen[-1] != enemy.target:
			seen.append(enemy.target)
		if rules.is_finished():
			break
	expect_eq(seen, ["tower:archer_post", "recruit:wren", "hero", "recruit:bryn", ""])
	expect_eq(rules.outcome, HoldfastRules.OUTCOME_LOST)
	expect_eq(rules.towers_lost, 1)
	expect_eq(rules.recruits_downed, 2)
	expect_eq(int(rules.hero_state["knockdowns"]), 1)
	expect_eq(rules.keep_health, 0)


func test_enemies_hit_on_their_interval_not_every_tick() -> void:
	# Damage 10 every 1 s at the tower: one hit at once, the second a second later.
	var rules := _quiet()
	_enemy(rules, Vector2(-90, 30), BIG, 10)
	_run(rules, 29)
	expect_eq(rules.tower.health["health"], 50.0, "one hit in the first 29 ticks")
	_run(rules, 6)
	expect_eq(rules.tower.health["health"], 40.0, "the second by tick 35")
	_run(rules, 30)
	expect_eq(rules.tower.health["health"], 30.0, "the third by tick 65")


# ------------------------------------------------------------------ towers

func test_a_tower_is_destroyed_at_zero_and_stops_shooting() -> void:
	# Health 60, so a 60 hit destroys it and a 59 hit leaves 1.
	var down := _quiet("flare_archer", func(c: Dictionary) -> void:
		c["towers"]["archer_post"]["damage"] = 4.0)
	var hitter := _enemy(down, Vector2(-90, 30), BIG, 60)
	_run(down, 5)
	expect_eq(down.towers_lost, 1)
	expect_false(down.tower.up)
	expect_eq(down.tower.health["health"], 0.0)
	expect_eq(hitter.health, BIG, "the destroyed tower fired nothing")
	var up := _quiet("flare_archer", func(c: Dictionary) -> void:
		c["towers"]["archer_post"]["damage"] = 4.0)
	var gentle := _enemy(up, Vector2(-90, 30), BIG, 59)
	_run(up, 1)
	expect_eq(up.towers_lost, 0)
	expect_true(up.tower.up)
	expect_eq(up.tower.health["health"], 1.0)
	expect_true(gentle.health < BIG, "the standing tower fires")


# ------------------------------------------------------------------ Recruits fall and are revived

func _down_bryn(rules: HoldfastRules) -> void:
	# Bryn has health 40: a 40 hit downs him, and the enemy is then taken away.
	_enemy(rules, Vector2(112, -48), BIG, 40)
	_run(rules, 1)
	rules.enemies.clear()


func test_a_recruit_at_zero_is_downed_for_the_run() -> void:
	var rules := _quiet()
	_down_bryn(rules)
	expect_eq(rules.recruits_downed, 1)
	expect_false(rules.recruits[0].up)
	expect_eq(rules.recruits[0].health["health"], 0.0)
	_run(rules, 600)
	expect_false(rules.recruits[0].up, "nothing but the Hero revives him")
	var spared := _quiet()
	_enemy(spared, Vector2(112, -48), BIG, 39)
	_run(spared, 1)
	expect_eq(spared.recruits_downed, 0, "one health left is still up")


func test_the_hero_standing_on_a_downed_recruit_revives_them_after_their_time() -> void:
	# revive_seconds 3 = 90 ticks, back with half of 40 health. 85 ticks is short, 91 enough.
	var rules := _quiet()
	_down_bryn(rules)
	rules.hero_position = Vector2(112, -48)
	_run(rules, 85)
	expect_false(rules.recruits[0].up, "85 ticks is not enough")
	_run(rules, 6)
	expect_true(rules.recruits[0].up, "91 ticks is")
	expect_eq(rules.recruits[0].health["health"], 20.0, "half of 40")
	expect_eq(rules.recruits_revived, 1)


func test_stepping_off_a_downed_recruit_starts_the_count_again() -> void:
	var rules := _quiet()
	_down_bryn(rules)
	rules.hero_position = Vector2(112, -48)
	_run(rules, 60)
	rules.hero_position = Vector2(0, 80)
	_run(rules, 1)
	expect_eq(rules.recruits[0].health["revive_progress"], 0.0, "reset when the Hero leaves")
	rules.hero_position = Vector2(112, -48)
	_run(rules, 60)
	expect_false(rules.recruits[0].up, "60 + 60 with a gap is not 90 in a row")
	_run(rules, 31)
	expect_true(rules.recruits[0].up)


func test_a_downed_recruit_is_not_targeted_and_the_edge_of_standing_counts() -> void:
	# Standing reach is the Recruit's radius 13 + the Hero's 12 = 25, edge included.
	var rules := _quiet()
	_down_bryn(rules)
	var near := _enemy(rules, Vector2(112, -40))
	_run(rules, 1)
	expect_ne(near.target, "recruit:bryn", "a downed Recruit is nobody's target")
	rules.hero_position = Vector2(112, -48 + 25)
	_run(rules, 91)
	expect_true(rules.recruits[0].up, "25 px away is still standing on them")
	var off := _quiet()
	_down_bryn(off)
	off.hero_position = Vector2(112, -48 + 26)
	_run(off, 200)
	expect_false(off.recruits[0].up, "26 px is not")


# ------------------------------------------------------------------ staffed posts

func test_a_staffed_lookout_slows_and_marks_inside_its_reach() -> void:
	# Wren staffs the west post (-130,70): reach 130 + an enemy's radius 10 = 140, edge included.
	# Slow 0.3 and mark 0.25.
	var rules := _quiet()
	var inside := _enemy(rules, Vector2(10, 70))
	var outside := _enemy(rules, Vector2(11, 70))
	_run(rules, 1)
	expect_near(inside.zone_slow, 0.3, 0.0001)
	expect_near(inside.mark_bonus, 0.25, 0.0001)
	expect_eq(outside.zone_slow, 0.0)
	expect_eq(outside.mark_bonus, 0.0)


func test_a_marked_enemy_takes_a_quarter_more() -> void:
	# Tower damage 4 on an unlit enemy at (10,70), 107 from the tower: marked 4 x 1.25 = 5.
	var marked := _quiet("flare_archer", func(c: Dictionary) -> void:
		c["towers"]["archer_post"]["damage"] = 4.0)
	var hit := _enemy(marked, Vector2(10, 70))
	_run(marked, 1)
	expect_near(hit.health, 95.0, 0.0001, "4 x 1.25")
	var unmarked := _quiet("flare_archer", func(c: Dictionary) -> void:
		_drop_posts(c)
		c["towers"]["archer_post"]["damage"] = 4.0)
	var plain := _enemy(unmarked, Vector2(10, 70))
	_run(unmarked, 1)
	expect_near(plain.health, 96.0, 0.0001, "no post, no mark")


func test_a_recruit_that_falls_takes_their_posts_effect_with_them() -> void:
	var rules := _quiet()
	var enemy := _enemy(rules, Vector2(10, 70))
	_run(rules, 1)
	expect_near(enemy.mark_bonus, 0.25, 0.0001)
	var hitter := _enemy(rules, Vector2(-118, 58), BIG, 35)  # Wren's health
	_run(rules, 1)
	expect_false(rules.recruits[1].up)
	hitter.health = 0.0
	rules.enemies.erase(hitter)
	_run(rules, 11)  # retargeted at once on a fall, then at the normal pace
	expect_eq(enemy.mark_bonus, 0.0, "the mark ends with the Lookout")


func test_a_staffed_alchemist_burns_enemies_in_the_field() -> void:
	# Wren as an Alchemist at the west post: 4 damage a second within 120 + 10 of it. An enemy at
	# (-5,70) is 125 away (unlit): 30 ticks = 1 s = 4 damage. At (6,70) it is 136: out.
	var rules := _quiet("flare_archer", func(c: Dictionary) -> void:
		c["staff"]["wren"]["class"] = "alchemist")
	var in_field := _enemy(rules, Vector2(-5, 70))
	var out := _enemy(rules, Vector2(6, 70))
	_run(rules, 30)
	expect_near(in_field.health, 96.0, 0.001)
	expect_eq(out.health, 100.0)


func test_a_staffed_engineer_repairs_the_tower_up_to_its_maximum() -> void:
	# Wren as an Engineer at the west post (56.6 from the tower): 4 health a second.
	var edit := func(c: Dictionary) -> void:
		c["staff"]["wren"]["class"] = "engineer"
	var rules := _quiet("flare_archer", edit)
	rules.tower.health = UnitHealth.damage(rules.tower.health, 50.0)
	_run(rules, 30)
	expect_near(rules.tower.health["health"], 14.0, 0.001, "10 + 4 in a second")
	rules.tower.health = UnitHealth.repair(rules.tower.health, 100.0)
	rules.tower.health = UnitHealth.damage(rules.tower.health, 1.0)
	_run(rules, 60)
	expect_eq(rules.tower.health["health"], 60.0, "stops at the maximum")
	var wrecked := _quiet("flare_archer", edit)
	wrecked.tower.health = UnitHealth.damage(wrecked.tower.health, 60.0)
	wrecked.tower.up = false
	_run(wrecked, 60)
	expect_eq(wrecked.tower.health["health"], 0.0, "a destroyed tower is not repaired")


# ------------------------------------------------------------------ the Hero falls

func test_a_hero_who_falls_drops_their_xp_and_gets_up_where_they_fell() -> void:
	var rules := _quiet("flare_archer", _drop_posts)
	rules.carried_xp = 25
	rules.hero_position = Vector2(50, 80)
	var hitter := _enemy(rules, Vector2(50, 80), BIG, 60)  # the Hero's health
	_run(rules, 1)
	rules.enemies.erase(hitter)
	expect_true(rules.hero_state["downed"])
	expect_eq(rules.carried_xp, 0, "the carried XP is dropped")
	expect_eq(rules.xp_tokens.size(), 1)
	expect_eq(rules.xp_tokens[0].amount, 25)
	expect_eq(rules.xp_tokens[0].position, Vector2(50, 80))
	expect_near(rules.hero_state["get_up_in"], 3.0 - DT, 0.001, "first fall: 3 s")
	_run(rules, 80)
	expect_true(rules.hero_state["downed"], "still down after 81 ticks")
	_run(rules, 15)
	expect_false(rules.hero_state["downed"], "up by 96")
	expect_eq(rules.hero_position, Vector2(50, 80), "up where they fell")
	expect_eq(rules.hero_state["health"], 60.0, "with full health")
	expect_eq(rules.carried_xp, 25, "and standing on the token, they pick it up")
	expect_true(rules.xp_tokens.is_empty())
	# The second fall waits 6 s (the 2 s of being untouchable are over first).
	_run(rules, 60)
	var again := _enemy(rules, rules.hero_position, BIG, 60)
	_run(rules, 1)
	rules.enemies.erase(again)
	expect_near(rules.hero_state["get_up_in"], 6.0 - DT, 0.001, "second fall: 6 s")


func test_the_hero_picks_their_dropped_xp_up_by_walking_to_it() -> void:
	# Pickup radius 30, edge included.
	var rules := _quiet("flare_archer", _drop_posts)
	var token := HoldfastRules.XpToken.new()
	token.position = Vector2(50, 80)
	token.amount = 25
	rules.xp_tokens.append(token)
	rules.hero_position = Vector2(19, 80)  # 31 away
	_run(rules, 1)
	expect_eq(rules.carried_xp, 0, "31 px is out of reach")
	rules.hero_position = Vector2(20, 80)  # 30 away
	_run(rules, 1)
	expect_eq(rules.carried_xp, 25, "30 px picks it up")
	expect_true(rules.xp_tokens.is_empty())


func test_a_hero_who_is_down_does_nothing_and_enemies_leave_them_alone() -> void:
	var rules := _quiet("flare_archer", func(c: Dictionary) -> void:
		_drop_posts(c)
		c["hero_paths"]["flare_archer"]["knockdown_delays"] = [100000]
		c["hero_paths"]["flare_archer"]["attack"]["damage"] = 6.0)
	var hitter := _enemy(rules, Vector2(0, 80), BIG, 60)
	_run(rules, 1)
	rules.enemies.erase(hitter)
	expect_true(rules.hero_state["downed"])
	var bystander := _enemy(rules, Vector2(100, 80))
	_run(rules, 60, {"move": [1, 0], "ability": true})
	expect_eq(rules.hero_position, Vector2(0, 80), "no moving while down")
	expect_true(rules.projectiles.is_empty(), "no shooting while down")
	expect_eq(bystander.health, 100.0)
	expect_ne(bystander.target, "hero", "a downed Hero is not a target")


# ------------------------------------------------------------------ playable build

func test_the_keep_screen_pick_chooses_the_pillar_of_the_run() -> void:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	tree.root.add_child(main)
	main.keep_screen.select_pillar("tideblade")
	main.keep_screen.select_pillar("not_a_pillar")
	expect_eq(main.keep_screen.selected_pillar, "tideblade", "an unknown id changes nothing")
	main.call("_start_run")
	expect_eq(source.get_rules().hero_path_id, "tideblade")
	main.free()


# ------------------------------------------------------------------ simulator: Recruits fall mid-wave

## Content with Recruits and tower that die at a touch, so runs have them fall mid-wave.
func _fragile(content: Dictionary) -> void:
	for id in ["bryn", "wren"]:
		content["staff"][id]["health"] = 5.0


func test_the_simulator_covers_runs_where_recruits_fall_mid_wave_on_every_pillar() -> void:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	_fragile(content)
	for id in ["flare_archer", "dusk_mage", "tideblade"]:
		var config := HoldfastContent.run_config("outpost", [], content, id)
		var first := SimBotRunner.run(HoldfastRules.new(), HoldfastHeroBot.new(), 1, config, 100000, HoldfastRules.TICK_RATE)
		var second := SimBotRunner.run(HoldfastRules.new(), HoldfastHeroBot.new(), 1, config, 100000, HoldfastRules.TICK_RATE)
		expect_eq(first["hash"], second["hash"], id + " is deterministic")
		expect_ne(first["result"]["outcome"], HoldfastRules.OUTCOME_RUNNING, id + " finished")
		expect_true(first["result"]["recruits_downed"] >= 1, id + ": a Recruit went down")
		expect_true(first["result"]["wave"] >= 1, id + ": and the run was past wave 1")


func test_a_recruit_falls_while_enemies_remain_in_a_wave() -> void:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	_fragile(content)
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", [], content), SimRng.new(1))
	var bot := HoldfastHeroBot.new()
	var fell_with_enemies := false
	for tick in 20000:
		rules.step(DT, bot.get_input(rules, tick))
		if rules.recruits_downed > 0:
			fell_with_enemies = rules.wave >= 1 and not rules.enemies.is_empty()
			break
		if rules.is_finished():
			break
	expect_true(fell_with_enemies, "the first fall comes mid-wave")


# ------------------------------------------------------------------ headless and playable agree

class Replay:
	extends SimController
	var inputs: Array = []

	func get_input(_rules: SimRules, tick: int) -> Dictionary:
		return inputs[tick] if tick < inputs.size() else {}


func test_headless_and_playable_build_match_for_every_pillar() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 77
	var directions := [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1]]
	var inputs := []
	var heading: Array = directions[0]
	for tick in 3000:
		if tick % 20 == 0:
			heading = directions[dice.randi_range(0, directions.size() - 1)]
		inputs.append({"move": heading, "ability": dice.randf() < 0.02})
	var frames := RandomNumberGenerator.new()
	frames.seed = 5
	for id in ["flare_archer", "dusk_mage", "tideblade"]:
		var replay := Replay.new()
		replay.inputs = inputs
		var headless := SimBotRunner.run(HoldfastRules.new(), replay, 3, HoldfastContent.run_config("outpost", [], {}, id), 100000, HoldfastRules.TICK_RATE)
		var source := HoldfastRunSource.new()
		source.auto_step = false
		source.rng_seed = 3
		source.hero_path = id
		var played := Replay.new()
		played.inputs = inputs
		source.controller_override = played
		tree.root.add_child(source)
		source.start_run()
		var count := 0
		while source.is_running() and count < 1_000_000:
			source.step(frames.randf_range(1.0 / 144.0, 1.0 / 15.0))
			count += 1
		expect_false(source.is_running(), id + " ended")
		expect_eq(source.get_engine().state_hash(), headless["hash"], id + " state hash")
		expect_eq(source.get_rules().result(), headless["result"], id + " result")
		source.free()
