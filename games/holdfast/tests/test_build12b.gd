extends KitTestCase
## Build 12b: Posted Hand (a link that needs the Squad and Lit Post) and setting a Recruit on a placed
## post from the Plan page. Numbers are worked by hand from the pack: the Outpost's cooldown is 1 s, Quick
## hands (a step on the way to Lit Post) makes it 0.75 s, Lit Post a quarter faster (0.6 s) and Posted Hand
## another tenth (0.6 / 1.1).

const Main := preload("res://scenes/main.tscn")
const DT := 1.0 / HoldfastRules.TICK_RATE
const BIG := 1000000.0
const SPOT := Vector2(100, 0)


func _content() -> Dictionary:
	return HoldfastContent.base()


func _with(id: String, out: Array = []) -> Array:
	for required in _content()["upgrade_nodes"][id].get("requires", []):
		_with(required, out)
	if not id in out:
		out.append(id)
	return out


## The Outpost with one post on castle spot 1 (100, 0), nothing hurting anything, and Bryn on the squad.
func _rules(upgrades: Array, posted: Dictionary, layout: Array = ["spot_1"]) -> HoldfastRules:
	var content: Dictionary = _content().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 5.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	var squad := [RecruitRoster.new_recruit("bryn", "Bryn", "warden")]
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config("outpost", upgrades, content, "flare_archer", layout, {}, [], false, squad, "", posted), SimRng.new(1))
	return rules


func _ready_in_after_first_shot(rules: HoldfastRules, hero_at: Vector2) -> float:
	rules.hero_position = hero_at
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = SPOT + Vector2(0, -90)
	enemy.health = BIG
	enemy.max_health = BIG
	enemy.radius = 10.0
	enemy.speed = 0.0
	enemy.damage = 0
	rules.enemies.append(enemy)
	rules.step(DT, {})
	return rules.tower.ready_in


# ------------------------------------------------------------------ the node

func test_posted_hand_is_a_two_star_link_that_needs_the_squad_and_lit_post() -> void:
	var node: Dictionary = _content()["upgrade_nodes"]["link_posted_hand"]
	expect_true(HoldfastMeta.is_star_node(node))
	expect_eq(int(node["cost"]), 2)
	expect_eq(Array(node["requires"]), ["squad_root", "link_lit_post"])
	expect_eq(node["effects"], [{"stat": "tower.posted_haste", "add": 0.1}])


func test_the_rules_read_posted_haste() -> void:
	var owned := _with("link_posted_hand")
	expect_near(_rules(owned, {}).tower.posted_haste, 0.1, 0.0001)
	expect_true(_rules(owned, {}).tower.links)
	expect_eq(_rules(_with("link_lit_post"), {}).tower.posted_haste, 0.0)


# ------------------------------------------------------------------ a Recruit on a post

func test_a_posted_recruit_stands_at_the_tower_and_staffs_it() -> void:
	var rules := _rules([], {"spot_1": "bryn"})
	var bryn: HoldfastRules.Attacker = rules.recruits[0]
	expect_eq(bryn.position, SPOT + HoldfastRules.POST_OFFSET)
	expect_eq(bryn.home, bryn.position)
	expect_eq(bryn.post, "tower:spot_1")
	expect_true(rules.tower.staffer == bryn)
	expect_true(bryn.walker["staffing"])


func test_without_a_post_there_the_recruit_takes_a_light_post_as_before() -> void:
	var plain := _rules([], {})
	var elsewhere := _rules([], {"spot_2": "bryn"})
	expect_eq(elsewhere.recruits[0].position, plain.recruits[0].position, "no tower on spot 2")
	expect_eq(elsewhere.recruits[0].post, plain.recruits[0].post)
	expect_true(elsewhere.tower.staffer == null)


func test_a_recruit_off_the_squad_cannot_be_posted() -> void:
	var rules := _rules([], {"spot_1": "nobody"})
	expect_true(rules.tower.staffer == null)


# ------------------------------------------------------------------ Posted Hand

func test_posted_hand_adds_a_tenth_with_a_recruit_up_and_the_hero_near() -> void:
	var owned := _with("link_posted_hand")
	var near := SPOT + Vector2(60, 0)
	expect_near(_ready_in_after_first_shot(_rules(owned, {"spot_1": "bryn"}), near), 0.6 / 1.1, 0.0001, "Recruit and Hero near")
	expect_near(_ready_in_after_first_shot(_rules(owned, {}), near), 0.6, 0.0001, "nobody on the post: Lit Post alone")
	expect_near(_ready_in_after_first_shot(_rules(owned, {"spot_1": "bryn"}), SPOT + Vector2(700, 0)), 0.75, 0.0001, "Hero far: the plain cooldown")


func test_posted_hand_stops_when_the_recruit_is_down_or_the_hero_is() -> void:
	var owned := _with("link_posted_hand")
	var near := SPOT + Vector2(60, 0)
	var hurt := _rules(owned, {"spot_1": "bryn"})
	hurt.recruits[0].up = false
	hurt.recruits[0].health["downed"] = true
	expect_near(_ready_in_after_first_shot(hurt, near), 0.6, 0.0001, "Recruit down")
	var hero_down := _rules(owned, {"spot_1": "bryn"})
	hero_down.hero_state["downed"] = true
	hero_down.hero_state["get_up_in"] = 100.0
	expect_near(_ready_in_after_first_shot(hero_down, near), 0.75, 0.0001, "Hero down: neither Lit Post nor Posted Hand")


func test_a_recruit_alone_does_not_light_a_post() -> void:
	# Recruits do not count as the Hero for Lit Post: Posted Hand gives nothing without it near.
	var owned := _with("link_posted_hand")
	expect_near(_ready_in_after_first_shot(_rules(owned, {"spot_1": "bryn"}), Vector2.ZERO), 0.75, 0.0001)


# ------------------------------------------------------------------ the profile

func _squad_profile(ids: Array) -> Dictionary:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	for id in ids:
		profile["recruits"]["roster"].append(RecruitRoster.new_recruit(id, id.capitalize(), "warden"))
		profile["recruits"]["squad"].append(id)
	return profile


func test_a_squad_recruit_is_set_on_one_spot_and_moves_when_set_on_another() -> void:
	var content := _content()
	var profile := _squad_profile(["bryn", "wren"])
	profile = RecruitMeta.post_recruit(content, profile, "spot_1", "bryn")
	profile = RecruitMeta.post_recruit(content, profile, "spot_2", "wren")
	expect_eq(RecruitMeta.posted(profile), {"spot_1": "bryn", "spot_2": "wren"})
	profile = RecruitMeta.post_recruit(content, profile, "spot_2", "bryn")
	expect_eq(RecruitMeta.posted(profile), {"spot_2": "bryn"}, "one Recruit, one post: spot 2 now holds Bryn")
	profile = RecruitMeta.post_recruit(content, profile, "spot_2", "")
	expect_false(profile["recruits"].has("posted"), "Nobody clears the post and the key")


func test_only_a_squad_recruit_and_a_castle_spot_are_accepted() -> void:
	var content := _content()
	var profile := _squad_profile(["bryn"])
	expect_eq(RecruitMeta.post_recruit(content, profile, "spot_1", "wren"), profile, "not on the squad")
	expect_eq(RecruitMeta.post_recruit(content, profile, "nowhere", "bryn"), profile, "not a castle spot")


func test_leaving_the_squad_takes_the_recruit_off_their_post() -> void:
	var content := _content()
	var profile := RecruitMeta.post_recruit(content, _squad_profile(["bryn", "wren"]), "spot_1", "bryn")
	var out := RecruitMeta.toggle_squad(content, profile, "bryn")
	expect_false(out["recruits"].has("posted"))
	expect_eq(RecruitMeta.posted(profile), {"spot_1": "bryn"}, "the profile given is left alone")


func test_a_saved_post_survives_json_and_a_damaged_one_is_dropped() -> void:
	var content := _content()
	var profile := RecruitMeta.post_recruit(content, _squad_profile(["bryn", "wren"]), "spot_1", "bryn")
	var read: Dictionary = JSON.parse_string(JSON.stringify(profile))
	expect_eq(RecruitMeta.posted(HoldfastMeta.from_save(content, read)), {"spot_1": "bryn"})
	for bad in [5, [], {"spot_1": "stranger"}, {"nowhere": "bryn"}, {"spot_1": 7}, {"spot_1": "bryn", "spot_2": "bryn"}]:
		var damaged: Dictionary = read.duplicate(true)
		damaged["recruits"]["posted"] = bad
		var kept := RecruitMeta.posted(HoldfastMeta.from_save(content, damaged))
		expect_true(kept == {} or kept == {"spot_1": "bryn"}, "damaged posted %s gives %s" % [bad, kept])


# ------------------------------------------------------------------ the Plan page

func test_a_placed_post_offers_the_squad_and_a_pick_is_heard() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var planning: Control = main.planning
	planning.open("outpost", ["spot_1"], false, _content()["castle_rules"]["castle"]["spots"].slice(0, 3), 1)
	planning.set_posted([], {})
	expect_false(planning._recruit_buttons["spot_1"].visible, "no squad, no choice")
	planning.set_posted([{"id": "bryn", "name": "Bryn"}, {"id": "wren", "name": "Wren"}], {"spot_1": "wren"})
	expect_true(planning._recruit_buttons["spot_1"].visible, "a placed post offers one")
	expect_false(planning._recruit_buttons["spot_2"].visible, "an empty spot does not")
	expect_eq(planning._recruit_buttons["spot_1"].text, "Wren")
	expect_eq(planning._recruit_buttons["spot_1"].get_popup().item_count, 3, "Nobody, Bryn, Wren")
	var heard := []
	planning.recruit_posted.connect(func(site: String, id: String) -> void: heard.append([site, id]))
	planning._recruit_buttons["spot_1"].get_popup().id_pressed.emit(1)
	planning._recruit_buttons["spot_1"].get_popup().id_pressed.emit(0)
	expect_eq(heard, [["spot_1", "bryn"], ["spot_1", ""]])
	main.free()


# ------------------------------------------------------------------ the bot

func test_the_bot_keeps_its_stars_from_a_node_that_pays_only_for_a_posted_recruit() -> void:
	var nodes: Dictionary = _content()["upgrade_nodes"]
	expect_eq(HoldfastProgression.unposted_nodes(nodes), ["link_posted_hand"])
	var profile := _squad_profile(["bryn"])
	profile["pillar"] = "flare_archer"
	profile["stars"] = {"x": 99}
	profile["upgrades"] = _with("link_posted_hand").filter(func(id: String) -> bool: return id != "link_posted_hand")
	var bought := HoldfastProgression.buy_for_profile(_content(), profile, [])
	expect_false(bought.any(func(each: Dictionary) -> bool: return each["id"] == "link_posted_hand"))


# ------------------------------------------------------------------ the whole way, on a real profile

func test_a_pick_on_the_plan_page_is_saved_and_stands_at_the_post_in_the_run() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	var source: HoldfastRunSource = main.get_node("RunSource")
	ThroughLevelZero.apply(profile)
	profile.data["recruits"]["roster"].append(RecruitRoster.new_recruit("bryn", "Bryn", "warden"))
	profile.data["recruits"]["squad"].append("bryn")
	main.journey._buttons["outpost"].pressed.emit()
	var planning: Control = main.planning
	planning._site_buttons["spot_1"].pressed.emit()
	planning._recruit_buttons["spot_1"].get_popup().id_pressed.emit(1)
	expect_eq(profile.get_posted(), {"spot_1": "bryn"}, "the pick reached the profile")
	expect_eq(planning._recruit_buttons["spot_1"].text, "Bryn", "and the page shows it")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(profile.data))
	expect_eq(RecruitMeta.posted(HoldfastMeta.from_save(HoldfastContent.base(), saved)), {"spot_1": "bryn"}, "and survives a save")
	planning.get_node("%StartButton").pressed.emit()
	expect_true(source.is_running())
	var bryn: HoldfastRules.Attacker = source._rules.recruits[0]
	expect_eq(bryn.post, "tower:spot_1", "Bryn staffs the post that was placed")
	expect_true(source._rules.tower.staffer == bryn)
	main.free()
