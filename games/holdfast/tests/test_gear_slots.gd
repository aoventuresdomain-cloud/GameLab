extends KitTestCase
## HF-M2-36: five gear slots with their own stat identities, twelve pieces, one first-clear piece
## for each level, the Hero numbers breakdown, and the Hero page (a bag, drag into a slot or press).
## Expected numbers are worked by hand from the Flare Archer's pack values: health 60, move speed
## 170, arrow damage 7, cooldown 0.5, range 210, ability cooldown 14, pickup 30, get-up waits 3, 6, 10.

const Main := preload("res://scenes/main.tscn")
const SLOTS := ["weapon", "helmet", "armour", "boots", "ring"]
const FIRST_CLEAR := {
	"outpost": "wave_worn_boots",
	"shingle_beach": "gull_feather_fletching",
	"tidewrack_cove": "storm_cap",
	"old_pier": "oilskin_vest",
	"gull_rock": "tide_band",
}


func _content() -> Dictionary:
	return HoldfastContent.base()


## Rules on the Flare Archer with `gear` worn, no wave for 1000 s. `edit` changes a copy of the pack.
func _world(gear: Dictionary = {}, edit: Callable = Callable(), level := "gull_rock", owned: Array = []) -> HoldfastRules:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"][level]["first_wave_delay"] = 1000.0
	if edit.is_valid():
		edit.call(content)
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config(level, [], content, "flare_archer", null, gear, owned), SimRng.new(1))
	return rules


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


# ------------------------------------------------------------------ the pack

func test_each_slot_has_a_stat_identity_in_the_pack() -> void:
	var rules: Dictionary = _content()["gear_rules"]["gear"]
	expect_eq(rules["slots"], SLOTS)
	for slot in SLOTS:
		var info: Dictionary = rules["slot_info"][slot]
		expect_true(str(info["name"]) != "" and str(info["identity"]) != "", slot + " names itself and says what it is for")
	expect_eq(rules["slot_info"]["boots"]["identity"], "move speed, faster get-up")


func test_every_level_but_the_tutorial_hands_out_one_piece_for_a_first_win() -> void:
	var content := _content()
	var seen := []
	for level in content["levels"]:
		var given := str(content["levels"][level].get("first_clear_gear", ""))
		if FIRST_CLEAR.has(level):
			expect_eq(given, FIRST_CLEAR[level], level)
			expect_true(content["gear_items"].has(given), level + " names a piece that exists")
			expect_false(given in seen, level + " hands out its own piece")
			seen.append(given)
		else:
			expect_eq(given, "", level + " (the tutorial) gives none")
	expect_eq(seen.size(), 5)


func test_the_six_old_pieces_keep_their_ids_and_move_to_the_right_slots() -> void:
	var items: Dictionary = _content()["gear_items"]
	var slots := {"gull_feather_fletching": "weapon", "tarred_bowstring": "weapon", "driftwood_stave": "weapon", "sea_glass_charm": "armour", "wave_worn_boots": "boots", "lamp_oil_flask": "ring"}
	for id in slots:
		expect_eq(items[id]["slot"], slots[id], id)
	expect_eq(items.size(), 12)


# ------------------------------------------------------------------ first-clear pieces and drops

func test_a_first_win_gives_the_levels_piece_once() -> void:
	var won := _world({}, Callable(), "outpost")
	won._finish(HoldfastRules.OUTCOME_WON)
	expect_eq(won.gear_found, ["wave_worn_boots"])
	expect_eq(won.result()["gear_found"], ["wave_worn_boots"], "and the result carries it")
	var lost := _world({}, Callable(), "outpost")
	lost._finish(HoldfastRules.OUTCOME_LOST)
	expect_eq(lost.gear_found, [], "a loss gives nothing")
	var again := _world({}, Callable(), "outpost", ["wave_worn_boots"])
	again._finish(HoldfastRules.OUTCOME_WON)
	expect_eq(again.gear_found, [], "owned already: not given twice")
	var tutorial := _world({}, Callable(), "first_watch")
	tutorial._finish(HoldfastRules.OUTCOME_WON)
	expect_eq(tutorial.gear_found, [], "the tutorial gives none")


func test_a_drop_never_takes_a_piece_a_level_hands_out() -> void:
	var drops := ["tarred_bowstring", "driftwood_stave", "beacon_visor", "sea_glass_charm", "barnacle_plate", "kelp_sandals", "lamp_oil_flask"]
	for seed_value in 30:
		var rules := _world({}, Callable(), "shingle_beach")
		rules._rng = SimRng.new(seed_value + 1)
		var elite := HoldfastRules.Enemy.new()
		elite.tier = "elite"
		elite.health = 0.0
		elite.max_health = 1.0
		rules.enemies.append(elite)
		rules._any_dead = true
		rules.step(1.0 / HoldfastRules.TICK_RATE, {})
		expect_eq(rules.gear_found.size(), 1, "seed %d" % seed_value)
		expect_true(rules.gear_found[0] in drops, "%s is a drop" % rules.gear_found[0])


# ------------------------------------------------------------------ what the new pieces do

func test_the_new_pieces_change_the_hero_by_their_pack_numbers() -> void:
	var base := _world()
	var storm := _world({"helmet": "storm_cap"})
	expect_near(storm.hero_ability["cooldown"], 14.0 * 0.92, 0.0001, "storm cap")
	var visor := _world({"helmet": "beacon_visor"})
	expect_eq(visor.spawn_radius, base.spawn_radius + 25.0, "beacon visor: enemies start further out")
	var vest := _world({"armour": "oilskin_vest"})
	expect_eq(vest.hero_state["max_health"], 70.0, "oilskin vest health")
	expect_near(vest.hero_armour, 0.05, 0.0001)
	var plate := _world({"armour": "barnacle_plate"})
	expect_near(plate.hero_armour, 0.12, 0.0001)
	var sandals := _world({"boots": "kelp_sandals"})
	expect_eq(sandals.hero_speed, 180.0)
	expect_near(float(sandals.hero_delays[0]), 2.4, 0.0001, "get up in 80% of 3 s")
	expect_near(float(sandals.hero_delays[2]), 8.0, 0.0001, "and 80% of 10 s")
	var band := _world({"ring": "tide_band"})
	expect_eq(band.hero_pickup_radius, base.hero_pickup_radius + 30.0, "tide band reaches further")
	expect_eq(base.hero_armour, 0.0)
	expect_eq(base.hero_delays, _content()["hero_paths"]["flare_archer"]["knockdown_delays"], "no sandals, the pack's own waits")


func test_armour_turns_damage_away_up_to_seventy_percent() -> void:
	var bare := _world()
	bare._hit_unit(null, 10.0)
	expect_eq(bare.hero_state["health"], 50.0)
	var plated := _world({"armour": "barnacle_plate"})
	plated._hit_unit(null, 10.0)
	expect_near(plated.hero_state["health"], 60.0 - 8.8, 0.0001, "12% of 10 turned away")
	var huge := _world({"armour": "barnacle_plate"}, func(content: Dictionary) -> void:
		content["gear_items"]["barnacle_plate"]["effects"][0]["add"] = 500)
	expect_near(huge.hero_armour, 0.7, 0.0001, "capped at 70%")
	huge._hit_unit(null, 10.0)
	expect_near(huge.hero_state["health"], 57.0, 0.0001)


func test_the_get_up_wait_cannot_fall_below_half() -> void:
	var quick := _world({"boots": "kelp_sandals"}, func(content: Dictionary) -> void:
		content["gear_items"]["kelp_sandals"]["effects"][1]["multiply"] = 0.1)
	expect_near(float(quick.hero_delays[0]), 1.5, 0.0001)
	expect_near(float(quick.hero_delays[1]), 3.0, 0.0001)


func test_a_downed_hero_in_sandals_gets_up_sooner() -> void:
	var bare := _world()
	var shod := _world({"boots": "kelp_sandals"})
	for rules in [bare, shod]:
		rules._hit_unit(null, 1000.0)
	expect_true(shod.hero_state["downed"] and bare.hero_state["downed"])
	expect_near(float(bare.hero_state["get_up_in"]), 3.0, 0.0001)
	expect_near(float(shod.hero_state["get_up_in"]), 2.4, 0.0001)


# ------------------------------------------------------------------ the numbers breakdown

func _row(rows: Array, label: String) -> Dictionary:
	for row in rows:
		if row["label"] == label:
			return row
	return {}


func test_the_breakdown_adds_up_and_matches_what_a_run_starts_with() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1", "flare_boots", "flare_hide", "flare_focus", "flare_quick"]
	profile["gear"]["owned"] = ["driftwood_stave", "storm_cap", "oilskin_vest", "kelp_sandals", "tide_band"]
	for item in profile["gear"]["owned"]:
		profile = HoldfastMeta.wear_gear(content, profile, item)
	expect_eq(HoldfastMeta.worn_gear(profile).size(), 5, "one piece in every slot")
	var rows := HoldfastMeta.hero_breakdown(content, profile)
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config("gull_rock", profile["upgrades"], content, "flare_archer", null, HoldfastMeta.worn_gear(profile)), SimRng.new(1))
	expect_eq(rules.setup_error, "")
	var expected := {
		"Health": rules.hero_state["max_health"],
		"Move speed": rules.hero_speed,
		"Arrow damage": rules.hero_attack["damage"],
		"Time between arrows": rules.hero_attack["cooldown"],
		"Arrow range": rules.hero_attack["range"],
		"Ability cooldown": rules.hero_ability["cooldown"],
		"Armour": rules.hero_armour * 100.0,
		"Get-up wait": float(rules.hero_delays[0]),
		"Pickup reach": rules.hero_pickup_radius,
	}
	expect_eq(rows.size(), expected.size())
	for label in expected:
		var row := _row(rows, label)
		expect_near(float(row["final"]), float(expected[label]), 0.0001, "%s is what the run starts with" % label)
		expect_near(float(row["base"]) + float(row["tree"]) + float(row["gear"]), float(row["final"]), 0.0001, "%s: base, tree and gear add up" % label)
	var speed := _row(rows, "Move speed")
	expect_eq(speed["base"], 170.0)
	expect_eq(speed["tree"], 20.0, "Light feet")
	expect_eq(speed["gear"], 10.0, "Kelp sandals")
	expect_eq(_row(rows, "Health")["gear"], 10.0)
	expect_eq(_row(rows, "Armour")["gear"], 5.0)
	expect_eq(_row(rows, "Armour")["tree"], 0.0)


func test_the_breakdown_without_gear_is_the_pack_and_the_tree() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	for row in HoldfastMeta.hero_breakdown(content, profile):
		expect_eq(float(row["gear"]), 0.0, "%s: no gear" % row["label"])
		expect_eq(float(row["tree"]), 0.0, "%s: no tree" % row["label"])
		expect_eq(row["final"], row["base"])


# ------------------------------------------------------------------ wearing and the save

func test_wearing_by_drag_replaces_and_taking_off_empties_one_slot() -> void:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile["gear"]["owned"] = ["driftwood_stave", "tarred_bowstring", "storm_cap"]
	var worn := HoldfastMeta.wear_gear(content, profile, "driftwood_stave")
	expect_eq(worn["gear"]["equipped"]["weapon"], "driftwood_stave")
	expect_eq(HoldfastMeta.wear_gear(content, worn, "driftwood_stave"), worn, "already worn: nothing changes (it is not a toggle)")
	var swapped := HoldfastMeta.wear_gear(content, worn, "tarred_bowstring")
	expect_eq(swapped["gear"]["equipped"]["weapon"], "tarred_bowstring")
	var capped := HoldfastMeta.wear_gear(content, swapped, "storm_cap")
	expect_eq(HoldfastMeta.worn_gear(capped), {"weapon": "tarred_bowstring", "helmet": "storm_cap"})
	var bare := HoldfastMeta.take_off_gear(capped, "weapon")
	expect_eq(HoldfastMeta.worn_gear(bare), {"helmet": "storm_cap"})
	expect_eq(bare["gear"]["owned"], capped["gear"]["owned"], "still owned")
	expect_eq(HoldfastMeta.take_off_gear(bare, "weapon"), bare, "an empty slot changes nothing")
	expect_eq(HoldfastMeta.take_off_gear(bare, "hat"), bare, "and so does an unknown one")
	expect_eq(HoldfastMeta.wear_gear(content, profile, "cursed_cutlass"), profile)
	var not_owned := HoldfastMeta.wear_gear(content, profile, "barnacle_plate")
	expect_eq(not_owned, profile, "a piece the player does not own is not worn")


func test_a_save_from_before_the_five_slots_loads_and_each_piece_lands_in_its_slot() -> void:
	var content := _content()
	var old := HoldfastMeta.from_save(content, {"gear": {
		"owned": ["tarred_bowstring", "sea_glass_charm", "wave_worn_boots", "lamp_oil_flask"],
		"equipped": {"weapon": "tarred_bowstring", "charm": "sea_glass_charm"}}})
	expect_eq(old["gear"]["owned"], ["tarred_bowstring", "sea_glass_charm", "wave_worn_boots", "lamp_oil_flask"], "what the player owns is kept")
	expect_eq(old["gear"]["equipped"], {"weapon": "tarred_bowstring", "helmet": "", "armour": "sea_glass_charm", "boots": "", "ring": ""}, "the old charm slot's piece sits in its new slot")
	var boots := HoldfastMeta.from_save(content, {"gear": {"owned": ["wave_worn_boots"], "equipped": {"charm": "wave_worn_boots"}}})
	expect_eq(boots["gear"]["equipped"]["boots"], "wave_worn_boots")
	var two := HoldfastMeta.from_save(content, {"gear": {"owned": ["wave_worn_boots", "kelp_sandals"], "equipped": {"charm": "wave_worn_boots", "boots": "kelp_sandals"}}})
	expect_eq(two["gear"]["equipped"]["boots"], "wave_worn_boots", "two pieces for one slot: the first wins")
	var wrong := HoldfastMeta.from_save(content, {"gear": {"owned": ["driftwood_stave"], "equipped": {"armour": "driftwood_stave"}}})
	expect_eq(HoldfastMeta.worn_gear(wrong), {}, "a slot the pack still has must match the piece")


## F-069: in a damaged save the first entry for a slot wins, whichever key it comes under, and a
## slot name the pack does not have wears the piece in its own slot.
func test_a_damaged_save_wears_the_first_entry_for_a_slot_and_an_unknown_name_wears_the_piece_where_it_belongs() -> void:
	var content := _content()
	var owned := ["driftwood_stave", "tarred_bowstring"]
	var charm_first := HoldfastMeta.from_save(content, {"gear": {"owned": owned, "equipped": {"charm": "driftwood_stave", "weapon": "tarred_bowstring"}}})
	expect_eq(charm_first["gear"]["equipped"]["weapon"], "driftwood_stave", "the old-slot entry comes first, so it wins")
	var weapon_first := HoldfastMeta.from_save(content, {"gear": {"owned": owned, "equipped": {"weapon": "tarred_bowstring", "charm": "driftwood_stave"}}})
	expect_eq(weapon_first["gear"]["equipped"]["weapon"], "tarred_bowstring", "and the other order gives the other piece")
	var unknown := HoldfastMeta.from_save(content, {"gear": {"owned": ["tide_band"], "equipped": {"hat": "tide_band"}}})
	expect_eq(unknown["gear"]["equipped"]["ring"], "tide_band", "an unknown slot name wears the piece in its own slot")
	var unowned := HoldfastMeta.from_save(content, {"gear": {"owned": [], "equipped": {"hat": "tide_band"}}})
	expect_eq(HoldfastMeta.worn_gear(unowned), {}, "but never a piece the player does not own")


# ------------------------------------------------------------------ the Hero page

func _page_with(main: Node, owned: Array) -> Control:
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.bank_run({"outcome": "lost", "level": "outpost", "gold": 0, "gear_found": owned})
	profile.take_off_gear("weapon")
	return main.hero_page


func _slot(page: Control, slot: String) -> Control:
	return page._slot_panels[slot]


func test_the_hero_page_shows_five_slots_with_what_each_is_for() -> void:
	var main := _main()
	var page: Control = main.hero_page
	expect_eq(page.get_node("%SlotColumn").get_child_count(), 5)
	var title: Label = _slot(page, "boots").get_node("Row/Title")
	expect_eq(title.text, "Boots")
	expect_eq(_slot(page, "boots").tooltip_text, "Boots: move speed, faster get-up")
	expect_eq(_slot(page, "weapon").get_node("Row/Item").text, "")
	main.free()


func test_dragging_a_piece_onto_its_slot_wears_it_and_the_wrong_slot_refuses() -> void:
	var main := _main()
	var page := _page_with(main, ["driftwood_stave", "wave_worn_boots"])
	var profile: HoldfastProfile = main.get_node("Profile")
	var data: Dictionary = page._bag_drag(Vector2.ZERO, "driftwood_stave", page.get_node("%Bag").get_child(0))
	expect_eq(data["slot"], "weapon")
	expect_false(page._slot_can_drop(Vector2.ZERO, data, "boots"), "the boots slot refuses a weapon")
	expect_true(page._slot_can_drop(Vector2.ZERO, data, "weapon"))
	page._slot_drop(Vector2.ZERO, data, "boots")
	expect_eq(profile.get_gear_worn().get("weapon", ""), "", "a refused drop wears nothing")
	page._slot_drop(Vector2.ZERO, data, "weapon")
	expect_eq(profile.get_gear_worn()["weapon"], "driftwood_stave")
	expect_eq(_slot(page, "weapon").get_node("Row/Item").text, "Driftwood stave", "the slot shows it")
	main.free()


func test_dragging_a_worn_piece_off_its_slot_takes_it_off_and_a_press_does_too() -> void:
	var main := _main()
	var page := _page_with(main, ["driftwood_stave", "wave_worn_boots"])
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.wear_gear("driftwood_stave")
	profile.wear_gear("wave_worn_boots")
	var lifted: Variant = page._slot_drag(Vector2.ZERO, "weapon", _slot(page, "weapon"))
	expect_true(lifted is Dictionary and lifted["from"] == "weapon")
	expect_true(page._off_can_drop(Vector2.ZERO, lifted))
	page._off_drop(Vector2.ZERO, lifted)
	expect_eq(profile.get_gear_worn(), {"boots": "wave_worn_boots"})
	expect_true(page._slot_drag(Vector2.ZERO, "weapon", _slot(page, "weapon")) == null, "an empty slot lifts nothing")
	expect_false(page._off_can_drop(Vector2.ZERO, page._bag_drag(Vector2.ZERO, "driftwood_stave", page.get_node("%Bag").get_child(0))), "a piece from the bag is not 'taken off'")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = false
	page._slot_input(press, "boots")
	expect_eq(profile.get_gear_worn(), {}, "pressing a worn slot takes it off")
	main.free()


func test_pressing_a_piece_in_the_bag_still_wears_and_removes_it() -> void:
	var main := _main()
	var page := _page_with(main, ["driftwood_stave"])
	var profile: HoldfastProfile = main.get_node("Profile")
	var button: Button = page.get_node("%Bag").get_child(0)
	button.pressed.emit()
	expect_eq(profile.get_gear_worn(), {"weapon": "driftwood_stave"})
	expect_eq(page.get_node("%Bag").get_child_count(), 0, "a worn piece leaves the bag")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = false
	page._slot_input(press, "weapon")
	expect_eq(profile.get_gear_worn(), {})
	expect_eq(page.get_node("%Bag").get_child_count(), 1, "taken off, it is back in the bag")
	main.free()


func test_the_hero_page_shows_the_breakdown_of_the_numbers() -> void:
	var main := _main()
	var page := _page_with(main, ["wave_worn_boots"])
	page.get_node("%StatsInfoButton").button_pressed = true
	page.get_node("%StatsInfoButton").pressed.emit()
	var text: String = page.get_node("%Stats").text
	expect_true(text.contains("Move speed 195 (base 170, tree 0, gear +25)"), text)
	expect_true(text.contains("Health 60 (base 60, tree 0, gear 0)"), text)
	expect_true(text.contains("Armour 0% (base 0, tree 0, gear 0)"), text)
	expect_eq(text.split("\n").size(), 9)
	main.free()


func test_a_first_win_in_the_flow_puts_the_piece_in_the_bag_and_wears_it() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	var rules := _world({}, Callable(), "outpost")
	rules._finish(HoldfastRules.OUTCOME_WON)
	profile.bank_run(rules.result())
	expect_eq(profile.get_gear_owned(), ["wave_worn_boots"])
	expect_eq(profile.get_gear_worn(), {"boots": "wave_worn_boots"}, "worn at once in its free slot")
	main.free()
