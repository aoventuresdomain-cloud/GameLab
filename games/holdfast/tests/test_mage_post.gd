extends KitTestCase
## HF-M2-37: the Mage Post and the first Tower Gate. The gate is a star node that opens one Mage
## card once five nodes are owned; the Mage Post blasts an area, hardest outside the posts' light;
## a short Mage branch follows it, with one Hero link for the Dusk Mage's Eclipse. Numbers are
## worked by hand from the pack: castle spot_1 is at (100, 0) and spot_2 at (-100, 0); the Mage
## Post has damage 5, range 150, cooldown 1.6 s, health 50, a 45 blast and 0.6 more in the dark.

const DT := 1.0 / HoldfastRules.TICK_RATE
const BIG := 1000000.0
const Main := preload("res://scenes/main.tscn")
## Five nodes and the castle that goes with them, so the gate is next to be taken.
const FIVE := ["castle_slot_1", "castle_archer_1", "castle_slot_2", "flare_boots", "flare_hide"]


func _content() -> Dictionary:
	return HoldfastContent.base()


## A profile that owns `upgrades` and has stars to spare.
func _profile(upgrades: Array, pillar := "flare_archer") -> Dictionary:
	var profile := HoldfastMeta.new_profile(_content())
	profile["upgrades"] = upgrades.duplicate()
	profile["stars"] = {"first_watch": 2, "outpost": 3, "shingle_beach": 3, "tidewrack_cove": 3}
	profile["gold"] = 1000
	profile["pillar"] = pillar
	return profile


## Rules with nothing happening: no wave for 1000 s, the Hero, Recruits and Archer Post harmless.
## `layout` names the posts (castle spots, "mage:" for a Mage Post).
func _rules(upgrades: Array, layout: Array, hero := "flare_archer") -> HoldfastRules:
	var content: Dictionary = _content().duplicate(true)
	content["levels"]["shingle_beach"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 0.0
	for id in content["staff"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	# No Recruit staffs a post, so nothing marks an enemy for extra damage.
	content["levels"]["shingle_beach"]["staff"].erase("post")
	for at in content["levels"]["shingle_beach"]["recruits"]:
		at.erase("post")
	for id in content["hero_paths"]:
		content["hero_paths"][id]["attack"]["damage"] = 0.0
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("shingle_beach", upgrades, content, hero, layout), SimRng.new(1))
	# No light posts: everything is in the dark unless a test says otherwise.
	rules._post_points = []
	return rules


func _enemy(rules: HoldfastRules, at: Vector2, health := BIG) -> HoldfastRules.Enemy:
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = health
	enemy.max_health = health
	enemy.radius = 10.0
	enemy.speed = 0.0
	enemy.damage = 0
	rules.enemies.append(enemy)
	return enemy


func _run(rules: HoldfastRules, ticks: int, input: Dictionary = {}) -> void:
	for i in ticks:
		rules.step(DT, input)


func _mage(rules: HoldfastRules) -> HoldfastRules.Attacker:
	for built in rules.towers:
		if built.tower_id == "mage_post":
			return built
	return null


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


# ------------------------------------------------------------------ the pack

func test_the_mage_post_is_pack_data_with_its_own_numbers() -> void:
	var mage: Dictionary = _content()["towers"]["mage_post"]
	expect_eq([mage["damage"], mage["range"], mage["cooldown"], mage["health"]], [5.0, 150.0, 1.6, 50.0])
	expect_eq([mage["splash_radius"], mage["unlit_bonus"]], [45.0, 0.6])
	expect_true(mage["range"] != _content()["towers"]["archer_post"]["range"], "its own range, not the Archer's")


func test_tower_gate_one_is_a_star_node_that_needs_two_stars_and_five_nodes() -> void:
	var gate: Dictionary = _content()["upgrade_nodes"]["gate_mage"]
	expect_true(HoldfastMeta.is_star_node(gate))
	expect_eq(int(gate["cost"]), 2)
	expect_eq(int(gate["needs_nodes"]), 5)
	expect_eq(gate["requires"], ["castle_archer_1"])
	expect_eq(gate["grants"].keys(), ["mage_cards"])
	expect_eq(int(gate["grants"]["mage_cards"]), 1)
	expect_eq(gate["branch"], "mage_post")


# ------------------------------------------------------------------ the gate

func test_the_gate_says_how_many_more_nodes_it_needs_and_opens_at_five() -> void:
	var content := _content()
	var profile := _profile(["castle_slot_1", "castle_archer_1"])
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "gate_mage"), "Needs 3 more nodes owned")
	profile["upgrades"].append("castle_slot_2")
	profile["upgrades"].append("flare_boots")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "gate_mage"), "Needs 1 more node owned")
	profile["upgrades"].append("flare_hide")
	expect_eq(HoldfastMeta.why_not_buy(content, profile, "gate_mage"), "")
	var short := _profile(FIVE)
	short["stars"] = {"first_watch": 2, "outpost": 2}
	expect_eq(HoldfastMeta.why_not_buy(content, short, "gate_mage"), "Not enough stars", "three of the four stars are spent on the castle, one is left")


func test_the_gate_is_next_to_the_first_archer_post_but_not_near_until_five_are_owned() -> void:
	var content := _content()
	var few := _profile(["castle_slot_1", "castle_archer_1"])
	expect_true(HoldfastMeta.is_visible(content, few, "gate_mage"), "next to the first Archer Post")
	expect_false(HoldfastMeta.is_near(content, few, "gate_mage"), "but not one buy away")
	expect_true(HoldfastMeta.is_near(content, _profile(FIVE), "gate_mage"))
	expect_false(HoldfastMeta.is_visible(content, _profile(["castle_slot_1"]), "gate_mage"), "hidden before the first Archer Post")


func test_taking_the_gate_opens_one_mage_card_and_a_respec_takes_it_back() -> void:
	var content := _content()
	var profile := _profile(FIVE)
	expect_eq(HoldfastMeta.castle_mage_cards(content, profile), 0)
	var bought := HoldfastMeta.buy(content, profile, "gate_mage")
	expect_true(bought["ok"])
	expect_eq(HoldfastMeta.castle_mage_cards(content, bought["profile"]), 1)
	expect_eq(HoldfastMeta.castle_cards(content, bought["profile"]), 1, "the Archer cards are not touched")
	var respec := HoldfastMeta.respec(content, bought["profile"])
	expect_eq(HoldfastMeta.castle_mage_cards(content, respec), 0)
	var one_slot := _profile(["castle_slot_1", "castle_archer_1", "gate_mage"])
	expect_eq(HoldfastMeta.castle_mage_cards(content, one_slot), 1, "one slot holds one card")
	var none := _profile(["gate_mage"])
	expect_eq(HoldfastMeta.castle_mage_cards(content, none), 0, "a card needs a slot")


# ------------------------------------------------------------------ layouts

func test_a_layout_entry_is_a_spot_or_mage_and_a_spot() -> void:
	expect_eq(HoldfastRules.layout_spot("spot_3"), "spot_3")
	expect_eq(HoldfastRules.layout_spot("mage:spot_3"), "spot_3")
	expect_eq(HoldfastRules.layout_entry("spot_3", "archer_post"), "spot_3")
	expect_eq(HoldfastRules.layout_entry("spot_3", "mage_post"), "mage:spot_3")
	expect_eq(HoldfastRules.layout_towers(["spot_1", "mage:spot_2"]), {"spot_2": "mage_post"})


func test_a_layout_may_hold_a_mage_only_with_a_mage_card_and_a_slot_for_it() -> void:
	var content := _content()
	var gated := _profile(FIVE + ["gate_mage"])
	expect_true(HoldfastMeta.is_valid_layout(content, gated, ["spot_1", "mage:spot_2"]))
	expect_true(HoldfastMeta.is_valid_layout(content, gated, ["mage:spot_1"]), "a Mage alone is a layout")
	expect_false(HoldfastMeta.is_valid_layout(content, gated, ["mage:spot_1", "mage:spot_2"]), "one Mage card")
	expect_false(HoldfastMeta.is_valid_layout(content, gated, ["spot_1", "spot_2"]), "one Archer card")
	expect_false(HoldfastMeta.is_valid_layout(content, gated, ["spot_1", "mage:spot_1"]), "one post to a slot")
	expect_true(HoldfastMeta.is_valid_layout(content, gated, ["mage:spot_3"]), "any spot of the ring: slots are a count")
	expect_false(HoldfastMeta.is_valid_layout(content, gated, ["mage:nowhere"]), "a spot that is not on the ring")
	expect_false(HoldfastMeta.is_valid_layout(content, gated, ["owl:spot_1"]), "an unknown kind of post")
	expect_false(HoldfastMeta.is_valid_layout(content, _profile(FIVE), ["mage:spot_1"]), "no gate, no Mage")
	expect_false(HoldfastMeta.is_valid_layout(content, _profile(FIVE), ["spot_1", "spot_2"]), "and the Archer limit is as before")


func test_the_suggested_layout_puts_the_archer_first_and_the_mage_on_the_next_site() -> void:
	var content := _content()
	var plain := _profile(FIVE)
	expect_eq(HoldfastMeta.layout_for(content, plain, "shingle_beach").size(), 1)
	var gated := _profile(FIVE + ["gate_mage"])
	var layout := HoldfastMeta.layout_for(content, gated, "shingle_beach")
	expect_eq(layout.size(), 2)
	expect_false(":" in str(layout[0]), "the Archer first")
	expect_true(str(layout[1]).begins_with("mage:"), "then the Mage")
	expect_true(HoldfastMeta.is_valid_layout(content, gated, layout))


func test_post_counts_use_every_mage_card_and_keep_one_slot_for_an_archer() -> void:
	expect_eq(HoldfastMeta.post_counts(4, 2, 1), [2, 1], "room for all: nothing given up")
	expect_eq(HoldfastMeta.post_counts(3, 3, 1), [2, 1], "a full ring: the last Archer makes way for the Mage")
	expect_eq(HoldfastMeta.post_counts(2, 2, 2), [1, 1], "never every slot to Mages")
	expect_eq(HoldfastMeta.post_counts(1, 1, 1), [1, 0], "one slot stays an Archer's")
	expect_eq(HoldfastMeta.post_counts(3, 1, 0), [1, 0], "no Mage card, no Mage")
	expect_eq(HoldfastMeta.post_counts(0, 0, 0), [0, 0])


func test_the_suggested_layout_still_has_a_mage_when_every_slot_has_an_archer_card() -> void:
	var content := _content()
	var full := _profile(FIVE + ["gate_mage", "castle_slot_3", "castle_archer_2", "castle_archer_3"])
	expect_eq(HoldfastMeta.castle_slots(content, full), 3)
	expect_eq(HoldfastMeta.castle_cards(content, full), 3)
	var layout := HoldfastMeta.layout_for(content, full, "shingle_beach")
	expect_eq(layout.size(), 3)
	var mages := 0
	for entry in layout:
		mages += 1 if ":" in str(entry) else 0
	expect_eq(mages, 1, "one Mage in a ring of three Archer cards")
	expect_true(HoldfastMeta.is_valid_layout(content, full, layout))


func test_auto_place_uses_the_mage_card_when_the_ring_is_full_and_the_count_shows_slots() -> void:
	var plan := _plan([], 3, 3, 1)
	plan.auto_place()
	expect_eq(plan._chosen.size(), 3)
	expect_eq(plan._placed("mage_post"), 1, "the Mage card is used")
	expect_eq(plan._placed("archer_post"), 2)
	expect_eq(plan.get_node("%Count").text, "Posts: 3 of 3", "three slots, not four cards")
	plan.get_parent().get_parent().free()


func test_a_saved_layout_with_a_mage_loads_only_when_the_card_is_there() -> void:
	var content := _content()
	var save := _profile(FIVE + ["gate_mage"])
	save["layouts"] = {"shingle_beach": ["spot_1", "mage:spot_2"]}
	save["unlocked"] = ["shingle_beach"]
	var loaded := HoldfastMeta.from_save(content, save)
	expect_eq(loaded["layouts"]["shingle_beach"], ["spot_1", "mage:spot_2"], "kept with the gate")
	var without := save.duplicate(true)
	without["upgrades"] = FIVE.duplicate()
	var loaded_without := HoldfastMeta.from_save(content, without)
	expect_false(loaded_without["layouts"].has("shingle_beach"), "dropped without it")


func test_an_old_save_with_archer_layouts_loads_unchanged() -> void:
	var content := _content()
	var save := _profile(FIVE)
	save["layouts"] = {"shingle_beach": ["spot_2"]}
	save["unlocked"] = ["shingle_beach"]
	var loaded := HoldfastMeta.from_save(content, save)
	expect_eq(loaded["layouts"], {"shingle_beach": ["spot_2"]})
	expect_eq(loaded["upgrades"], FIVE)
	expect_eq(HoldfastMeta.castle_mage_cards(content, loaded), 0, "the gate is simply not taken")


# ------------------------------------------------------------------ in a run

func test_a_run_builds_a_mage_post_on_its_spot_and_the_archer_stays_first() -> void:
	var rules := _rules([], ["mage:spot_1", "spot_2"])
	expect_eq(rules.towers.size(), 2)
	expect_eq(rules.towers[0].tower_id, "archer_post", "the Archer is the first post even when listed second")
	expect_eq(rules.towers[0].id, "archer_post")
	expect_eq(rules.towers[1].tower_id, "mage_post")
	expect_eq(rules.towers[1].id, "mage_post@spot_1")
	expect_eq(rules.towers[1].position, Vector2(100, 0))
	expect_eq(rules.towers[0].position, Vector2(-100, 0))
	expect_eq(rules.layout_ids, ["spot_2", "spot_1"])
	var mage := _mage(rules)
	expect_eq([mage.attack_range, mage.cooldown, mage.damage], [150.0, 1.6, 5.0])
	expect_eq(float(mage.health["max_health"]), 50.0)
	expect_eq(mage.colour, "#9b7be0")
	expect_eq(rules.towers[0].colour, "", "the Archer keeps the plain tower colour")


func test_a_layout_with_two_posts_on_one_spot_is_refused() -> void:
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config("shingle_beach", [], _content(), "flare_archer", ["spot_1", "mage:spot_1"]), SimRng.new(1))
	expect_eq(rules.outcome, HoldfastRules.OUTCOME_INVALID)
	expect_true(rules.setup_error.contains("not a valid set of sites"), rules.setup_error)


func test_the_mage_blasts_everything_near_its_target_and_nothing_further() -> void:
	var rules := _rules([], ["mage:spot_1"])
	var target := _enemy(rules, Vector2(100, 100))
	var near := _enemy(rules, Vector2(100, 140))
	var far := _enemy(rules, Vector2(160, 100))
	_run(rules, 1)
	expect_near(BIG - target.health, 8.0, 0.001, "the target takes 5 plus 60% in the dark")
	expect_near(BIG - near.health, 8.0, 0.001, "40 away, inside the blast of 45 and a body's width")
	expect_near(BIG - far.health, 0.0, 0.001, "60 away is outside the blast")


func test_the_mage_hits_hardest_in_the_dark() -> void:
	var rules := _rules([], ["mage:spot_1"])
	rules._post_points = [Vector2(100, 100)]
	rules.light_radius = 20.0
	rules.light_bonus = 0.0
	var lit := _enemy(rules, Vector2(100, 100))
	var dark := _enemy(rules, Vector2(100, 140))
	_run(rules, 1)
	expect_near(BIG - lit.health, 5.0, 0.001, "lit: the plain shot")
	expect_near(BIG - dark.health, 8.0, 0.001, "dark: 5 x 1.6")


func test_the_mage_shoots_only_within_its_range_and_reloads_slowly() -> void:
	var out_of_range := _rules([], ["mage:spot_1"])
	var out := _enemy(out_of_range, Vector2(100, 170))
	_run(out_of_range, 40)
	expect_near(BIG - out.health, 0.0, 0.001, "170 away is beyond 150 and a body's width")
	var rules := _rules([], ["mage:spot_1"])
	var inside := _enemy(rules, Vector2(100, 145))
	_run(rules, 1)
	expect_near(BIG - inside.health, 8.0, 0.001, "145 away is in range")
	_run(rules, 40)
	expect_near(BIG - inside.health, 8.0, 0.001, "still reloading after 1.4 s of a 1.6 s cooldown")
	_run(rules, 20)
	expect_near(BIG - inside.health, 16.0, 0.001, "the second shot")


func test_the_mage_shoots_the_enemy_nearest_the_keep() -> void:
	var rules := _rules([], ["mage:spot_1"])
	var nearer := _enemy(rules, Vector2(100, 60))
	var further := _enemy(rules, Vector2(100, 140))
	nearer.radius = 1.0
	further.radius = 1.0
	_run(rules, 1)
	expect_near(BIG - nearer.health, 8.0, 0.001, "the nearer one is shot")
	expect_near(BIG - further.health, 0.0, 0.001, "80 away from it: outside the blast of 45")


func test_monsters_go_for_a_mage_post_like_any_other_post() -> void:
	var rules := _rules([], ["mage:spot_1"])
	var enemy := _enemy(rules, Vector2(130, 0))
	enemy.damage = 5
	enemy.speed = 60.0
	enemy.hit_interval = 0.5
	_run(rules, 30)
	expect_eq(enemy.target, "tower:mage_post", "it picks the post as its target")
	expect_true(float(_mage(rules).health["health"]) < 50.0, "and hurts it")


# ------------------------------------------------------------------ the Mage branch

func test_the_mage_branch_is_gold_stat_nodes_behind_the_gate_scoped_to_the_mage_post() -> void:
	var nodes: Dictionary = _content()["upgrade_nodes"]
	for id in ["mage_force", "mage_sight", "mage_wards"]:
		expect_eq(nodes[id]["requires"], ["gate_mage"], id)
		expect_eq(nodes[id]["tower"], "mage_post", id)
		expect_false(HoldfastMeta.is_star_node(nodes[id]), id + " costs gold")
	expect_true(HoldfastMeta.is_visible(_content(), _profile(FIVE + ["gate_mage"]), "mage_force"))
	expect_false(HoldfastMeta.is_visible(_content(), _profile(FIVE), "mage_force"), "hidden until the gate is taken")


func test_the_mage_nodes_change_the_mage_and_not_the_archer() -> void:
	var plain := _rules([], ["spot_2", "mage:spot_1"])
	var tuned := _rules(["mage_force", "mage_sight", "mage_wards"], ["spot_2", "mage:spot_1"])
	expect_eq(_mage(tuned).damage, _mage(plain).damage + 2.0)
	expect_eq(_mage(tuned).attack_range, _mage(plain).attack_range + 25.0)
	expect_eq(float(_mage(tuned).health["max_health"]), float(_mage(plain).health["max_health"]) + 25.0)
	expect_eq(tuned.towers[0].damage, plain.towers[0].damage, "the Archer is as before")
	expect_eq(tuned.towers[0].attack_range, plain.towers[0].attack_range)
	expect_eq(float(tuned.towers[0].health["max_health"]), float(plain.towers[0].health["max_health"]))


# ------------------------------------------------------------------ the Hero link

func test_dusk_eclipse_belongs_to_the_dusk_mage_and_is_hidden_from_the_flare_archer() -> void:
	var content := _content()
	var owned := FIVE + ["gate_mage", "mage_sight"]
	expect_eq(content["upgrade_nodes"]["link_eclipse"]["hero"], "dusk_mage")
	expect_false(HoldfastMeta.is_visible(content, _profile(owned, "flare_archer"), "link_eclipse"))
	expect_eq(HoldfastMeta.why_not_buy(content, _profile(owned, "flare_archer"), "link_eclipse"), "Belongs to another Hero")
	expect_true(HoldfastMeta.is_visible(content, _profile(owned, "dusk_mage"), "link_eclipse"))
	expect_eq(HoldfastMeta.why_not_buy(content, _profile(owned, "dusk_mage"), "link_eclipse"), "")
	expect_eq(content["upgrade_nodes"]["link_eclipse"]["requires"], ["mage_sight"])


## An Eclipse cast at the nearest enemy `a`, with a second enemy 300 away from it on the far side.
func _eclipse(upgrades: Array, layout: Array, at: Vector2) -> Array:
	var rules := _rules(upgrades, layout, "dusk_mage")
	var first := _enemy(rules, at)
	var second := _enemy(rules, at + Vector2(300, 0))
	_run(rules, 1, {"ability": true})
	_run(rules, 1)
	return [rules, first, second]


func test_an_eclipse_centred_near_a_mage_post_is_wider_and_reaches_a_further_enemy() -> void:
	var near := _eclipse(["link_eclipse"], ["spot_2", "mage:spot_1"], Vector2(90, 10))
	expect_near(near[0].zone_scale, 1.3, 0.0001, "30% wider within 120 of the post")
	expect_true(near[2].slow_amount > 0.0, "an enemy 300 from the centre is inside 255 x 1.3")
	var plain := _eclipse([], ["spot_2", "mage:spot_1"], Vector2(90, 10))
	expect_eq(plain[0].zone_scale, 1.0, "no link, no widening")
	expect_eq(plain[2].slow_amount, 0.0, "300 is beyond the plain 255")


func test_an_eclipse_far_from_every_mage_post_is_not_wider() -> void:
	var far := _eclipse(["link_eclipse"], ["spot_2", "mage:spot_1"], Vector2(-90, -10))
	expect_eq(far[0].zone_scale, 1.0, "the post is 190 away, beyond 120")
	var archer_only := _eclipse(["link_eclipse"], ["spot_1"], Vector2(90, 10))
	expect_eq(archer_only[0].zone_scale, 1.0, "an Archer Post does not widen it")


func test_a_fallen_mage_post_no_longer_widens_the_eclipse() -> void:
	var rules := _rules(["link_eclipse"], ["spot_2", "mage:spot_1"], "dusk_mage")
	_mage(rules).up = false
	_enemy(rules, Vector2(90, 10))
	_run(rules, 1, {"ability": true})
	expect_eq(rules.zone_scale, 1.0)


func test_the_collapse_is_as_wide_as_the_zone() -> void:
	# The collapse hurts within 130 (+10 for a body) of the centre, or 169 (+10) when widened;
	# an enemy 165 from the centre is outside the first and inside the second.
	for linked in [true, false]:
		var rules := _rules(["link_eclipse"] if linked else [], ["spot_2", "mage:spot_1"], "dusk_mage")
		var first := _enemy(rules, Vector2(90, 10))
		var edge := _enemy(rules, Vector2(90 + 165, 10))
		_run(rules, 1, {"ability": true})
		rules.zone_left = 0.02
		_run(rules, 2)
		expect_true(first.health < BIG, "the centre is hurt")
		expect_eq(edge.health < BIG, linked, "165 from the centre: hurt only by the wider collapse (linked: %s)" % linked)


# ------------------------------------------------------------------ the screens

func test_the_tree_names_the_gate_with_its_shortfall_and_shows_the_mage_tab() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	var keep: Control = main.keep_screen
	keep.visible = true
	expect_true(keep._node_buttons["gate_mage"].visible, "next to the first Archer Post")
	expect_true("Mage Post" in keep.tab_names())
	expect_true(keep._node_text("gate_mage").contains("Needs 3 more nodes owned"), keep._node_text("gate_mage"))
	expect_true(keep._node_text("gate_mage").contains("Cost"), "and still says what it costs")
	main.free()


## Opens the Plan page with `slots` castle spots, `cards` Archer Posts and `mage_cards` Mage Posts.
func _plan(layout: Array = [], slots := 4, cards := 1, mage_cards := 1) -> Control:
	var plan: Control = _main().planning
	plan.open("shingle_beach", layout, false, HoldfastMeta.castle_rules(_content())["spots"].slice(0, slots), cards, mage_cards)
	return plan


func _card(tower: String, from := "") -> Dictionary:
	return {"kind": "tower", "tower": tower, "from": from}


func test_the_plan_page_has_an_archer_card_and_a_mage_card_and_counts_both() -> void:
	var plan := _plan()
	expect_eq(plan._tray.get_child_count(), 2)
	expect_eq((plan._tray.get_child(0).get_child(0) as Label).text, "Archer post")
	expect_eq((plan._tray.get_child(1).get_child(0) as Label).text, "Mage post")
	expect_eq(plan.get_node("%Count").text, "Posts: 0 of 2")
	plan.get_parent().get_parent().free()


func test_a_mage_card_goes_into_the_same_slots_as_an_archer_and_only_once() -> void:
	var plan := _plan()
	expect_true(plan._slot_can_drop(Vector2.ZERO, _card("mage_post"), "spot_3"))
	plan._slot_drop(Vector2.ZERO, _card("mage_post"), "spot_3")
	expect_eq(plan._chosen, ["mage:spot_3"])
	expect_false(plan._slot_can_drop(Vector2.ZERO, _card("mage_post"), "spot_1"), "one Mage card")
	plan._slot_drop(Vector2.ZERO, _card("archer_post"), "spot_1")
	expect_eq(plan._chosen, ["mage:spot_3", "spot_1"])
	expect_false(plan._slot_can_drop(Vector2.ZERO, _card("archer_post"), "spot_2"), "one Archer card")
	expect_eq(plan._site_buttons["spot_3"].text, "Mage")
	expect_eq(plan._site_buttons["spot_1"].text, "Archer")
	expect_eq(plan.get_node("%Count").text, "Posts: 2 of 2")
	plan.get_parent().get_parent().free()


func test_a_lifted_mage_keeps_its_kind_when_moved_and_returns_its_card() -> void:
	var plan := _plan(["mage:spot_2"])
	expect_eq(plan._slot_drag(Vector2.ZERO, "spot_2", plan._site_buttons["spot_2"]), _card("mage_post", "spot_2"))
	plan._slot_drop(Vector2.ZERO, _card("mage_post", "spot_2"), "spot_4")
	expect_eq(plan._chosen, ["mage:spot_4"], "moved, still a Mage")
	plan._side_drop(Vector2.ZERO, _card("mage_post", "spot_4"))
	expect_eq(plan._chosen, [], "let go elsewhere: the card is back")
	plan._slot_drop(Vector2.ZERO, _card("mage_post"), "spot_1")
	expect_eq(plan._chosen, ["mage:spot_1"], "and can be placed again")
	plan.get_parent().get_parent().free()


func test_pressing_slots_places_the_archer_then_the_mage_and_the_oldest_makes_way_at_the_limit() -> void:
	var plan := _plan()
	plan._site_buttons["spot_1"].pressed.emit()
	plan._site_buttons["spot_2"].pressed.emit()
	expect_eq(plan._chosen, ["spot_1", "mage:spot_2"], "an Archer while a card is left, then the Mage")
	plan._site_buttons["spot_3"].pressed.emit()
	expect_eq(plan._chosen, ["mage:spot_2", "spot_3"], "the oldest (the Archer) makes way and the new post is an Archer")
	plan._site_buttons["spot_3"].pressed.emit()
	expect_eq(plan._chosen, ["mage:spot_2"], "pressing a placed slot clears it")
	plan.get_parent().get_parent().free()


func test_when_the_oldest_post_is_a_mage_the_new_one_is_a_mage() -> void:
	var plan := _plan(["mage:spot_2", "spot_1"])
	plan._site_buttons["spot_3"].pressed.emit()
	expect_eq(plan._chosen, ["spot_1", "mage:spot_3"], "the Mage made way and its card goes to the new post")
	plan.get_parent().get_parent().free()


func test_auto_place_fills_the_archers_then_the_mages() -> void:
	var plan := _plan()
	plan.get_node("%AutoButton").pressed.emit()
	expect_eq(plan._chosen.size(), 2)
	expect_false(":" in str(plan._chosen[0]))
	expect_true(str(plan._chosen[1]).begins_with("mage:"))
	plan.get_parent().get_parent().free()


func test_the_flow_starts_a_run_with_the_mage_post_on_its_spot() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["upgrades"] = FIVE + ["gate_mage"]
	profile.data["stars"]["first_watch"] = 30
	profile.changed.emit()
	expect_eq(profile.get_castle_mage_cards(), 1)
	main.journey.level_requested.emit("outpost")
	expect_eq(main.planning._tray.get_child_count(), 2, "an Archer card and a Mage card")
	main.planning._site_buttons["spot_1"].pressed.emit()
	main.planning._site_buttons["spot_2"].pressed.emit()
	main.planning.get_node("%StartButton").pressed.emit()
	expect_eq(profile.get_layout("outpost"), ["spot_1", "mage:spot_2"], "saved with the kind")
	var rules: HoldfastRules = main.get_node("RunSource").get_rules()
	expect_eq(rules.towers.size(), 2)
	expect_eq(rules.towers[1].tower_id, "mage_post")
	main.free()
