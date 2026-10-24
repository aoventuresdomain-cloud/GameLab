extends KitTestCase
## HF-M2-39: the castle's ring is open. Slots bought say how many posts may stand, not where:
## with N slots and cards the player puts posts on any N of the ring's spots. The Plan page
## shows no compass names, old saved layouts load unchanged, and a "+ Tower" button buys the
## next slot or Archer Post at the tree's price.

const Main := preload("res://scenes/main.tscn")
const COMPASS := ["East", "West", "North", "South"]


func _content() -> Dictionary:
	return HoldfastContent.base()


## A profile past Level 0 that owns `ids` (bought in order, with stars to pay for all of them).
func _owning(ids: Array) -> Dictionary:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	profile["stars"] = {"first_watch": 2, "outpost": 3, "shingle_beach": 3, "tidewrack_cove": 3, "old_pier": 3, "gull_rock": 3}
	for id in ids:
		var bought := HoldfastMeta.buy(content, profile, id)
		expect_true(bought["ok"], "set-up: %s: %s" % [id, bought["reason"]])
		profile = bought["profile"]
	return profile


func _spot_ids() -> Array:
	return HoldfastMeta.ring_spots(_content()).map(func(spot: Dictionary) -> String: return str(spot["id"]))


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


## The flow with `profile_data` and the Plan page open on the Outpost.
func _planning(profile_data: Dictionary) -> Array:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data = profile_data
	profile.changed.emit()
	main.journey.level_requested.emit("outpost")
	return [main, main.planning, profile]


# ------------------------------------------------------------------ the rules

func test_every_spot_of_the_ring_takes_a_post_and_the_slots_bought_cap_how_many() -> void:
	var content := _content()
	var ids := _spot_ids()
	expect_eq(ids.size(), 8)
	var two := _owning(["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"])
	for spot in ids:
		expect_true(HoldfastMeta.is_valid_layout(content, two, [spot]), "%s alone" % spot)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			expect_true(HoldfastMeta.is_valid_layout(content, two, [ids[i], ids[j]]), "%s and %s" % [ids[i], ids[j]])
	expect_false(HoldfastMeta.is_valid_layout(content, two, ["spot_1", "spot_3", "spot_5"]), "three posts on two slots")
	expect_false(HoldfastMeta.is_valid_layout(content, two, ["spot_9"]), "a spot that is not on the ring")
	var one_card := _owning(["castle_slot_1", "castle_archer_1", "castle_slot_2"])
	expect_true(HoldfastMeta.is_valid_layout(content, one_card, ["spot_8"]))
	expect_false(HoldfastMeta.is_valid_layout(content, one_card, ["spot_8", "spot_4"]), "two slots but one card")


func test_a_saved_layout_from_before_loads_unchanged_and_so_does_one_on_a_far_spot() -> void:
	var content := _content()
	var profile := _owning(["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"])
	var saved := {"outpost": ["spot_1", "spot_2"], "shingle_beach": ["spot_6", "spot_3"], "tidewrack_cove": ["spot_1", "spot_2", "spot_3"]}
	profile["layouts"] = saved.duplicate(true)
	var loaded := HoldfastMeta.from_save(content, profile)
	expect_eq(loaded["layouts"]["outpost"], ["spot_1", "spot_2"], "a layout made when the first N spots were the only ones")
	expect_eq(loaded["layouts"]["shingle_beach"], ["spot_6", "spot_3"], "any spots of the ring")
	expect_false(loaded["layouts"].has("tidewrack_cove"), "still no more posts than slots")


func test_the_default_layout_takes_the_best_spots_of_the_whole_ring() -> void:
	var content := _content()
	var level: Dictionary = content["levels"]["shingle_beach"]
	for owned in [["castle_slot_1", "castle_archer_1"], ["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"]]:
		var profile := _owning(owned)
		var layout := HoldfastMeta.layout_for(content, profile, "shingle_beach")
		expect_eq(layout, HoldfastRules.best_sites(HoldfastMeta.ring_spots(content), level["spawn_arcs"], layout.size()), "%d slots" % (owned.size() / 2))
	var first := HoldfastMeta.layout_for(content, _owning(["castle_slot_1", "castle_archer_1"]), "shingle_beach")
	expect_eq(first.size(), 1)
	expect_true(first != ["spot_1"], "not simply the first spot of the ring: it faces where the enemies come from")


func test_the_button_for_the_next_tower_follows_slots_then_cards() -> void:
	var content := _content()
	var steps := [
		[["castle_slot_1", "castle_archer_1"], "castle_slot_2"],
		[["castle_slot_1", "castle_archer_1", "castle_slot_2"], "castle_archer_2"],
		[["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"], "castle_slot_3"],
		[["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2", "castle_slot_3", "castle_archer_3"], "castle_slot_4"],
	]
	for step in steps:
		expect_eq(HoldfastMeta.next_tower_node(content, _owning(step[0])), step[1], "after %s" % [step[0]])
	var everything := _owning(["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2", "castle_slot_3", "castle_archer_3", "castle_slot_4", "castle_slot_5"])
	expect_eq(HoldfastMeta.next_tower_node(content, everything), "", "nothing left to buy")


func test_a_mage_card_fills_a_slot_so_the_button_offers_the_next_slot_not_another_archer() -> void:
	var content := _content()
	# QA's save: two slots, one Archer card, one Mage card. Both slots can hold a post already.
	var save := _owning(["castle_slot_1", "castle_archer_1", "castle_slot_2"])
	expect_eq(HoldfastMeta.next_tower_node(content, save), "castle_archer_2", "set-up: without the Mage card the second slot wants an Archer")
	save["upgrades"].append("gate_mage")
	expect_eq(HoldfastMeta.castle_mage_cards(content, save), 1, "set-up: the Mage card is held")
	expect_eq(HoldfastMeta.next_tower_node(content, save), "castle_slot_3", "a Mage card fills the second slot, so the next tower is a slot")


# ------------------------------------------------------------------ the Plan page

func test_the_plan_page_shows_the_whole_ring_with_no_compass_names() -> void:
	var made := _planning(_owning(["castle_slot_1", "castle_archer_1"]))
	var main: Node = made[0]
	var plan: Control = made[1]
	expect_eq(plan._site_buttons.size(), 8, "every spot of the ring")
	for id in plan._site_buttons:
		var button: Button = plan._site_buttons[id]
		expect_eq(button.text, "Empty", id)
		expect_eq(button.tooltip_text, "", id + " has no name to show")
	plan._site_buttons["spot_7"].pressed.emit()
	expect_eq(plan._site_buttons["spot_7"].text, "Archer")
	for word in COMPASS:
		expect_false(plan.get_node("%Hint").text.contains(word) or plan.get_node("%Title").text.contains(word), "no %s in the page text" % word)
	main.free()


func test_a_post_goes_on_any_spot_up_to_the_slots_and_a_full_plan_swaps_the_oldest() -> void:
	var made := _planning(_owning(["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"]))
	var main: Node = made[0]
	var plan: Control = made[1]
	plan._site_buttons["spot_7"].pressed.emit()
	plan._site_buttons["spot_3"].pressed.emit()
	expect_eq(plan._chosen, ["spot_7", "spot_3"], "far spots, not just the first two")
	expect_eq(plan.get_node("%Count").text, "Posts: 2 of 2")
	plan._site_buttons["spot_5"].pressed.emit()
	expect_eq(plan._chosen, ["spot_3", "spot_5"], "the oldest makes way, the count stays at the slots")
	var card_drop: Variant = plan._slot_can_drop(Vector2.ZERO, {"kind": "tower", "tower": "archer_post", "from": ""}, "spot_1")
	expect_false(card_drop, "no card drops while the slots are full")
	plan._site_buttons["spot_3"].pressed.emit()
	expect_true(plan._slot_can_drop(Vector2.ZERO, {"kind": "tower", "tower": "archer_post", "from": ""}, "spot_1"), "and one does when a spot is freed")
	main.free()


func test_auto_place_fills_no_more_than_the_slots_bought() -> void:
	var content := _content()
	var made := _planning(_owning(["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2"]))
	var main: Node = made[0]
	var plan: Control = made[1]
	plan.auto_place()
	expect_eq(plan._chosen.size(), 2)
	expect_eq(plan._chosen, HoldfastRules.best_sites(HoldfastMeta.ring_spots(content), content["levels"]["outpost"]["spawn_arcs"], 2))
	main.free()


func test_cards_beyond_the_slots_cannot_all_be_placed() -> void:
	# Two slots, two Archer cards and a Mage card: three cards for two places.
	var main := _main()
	var plan: Control = main.planning
	var spots: Array = HoldfastMeta.ring_spots(_content())
	plan.open("outpost", [], false, spots, 2, 1, 2)
	for id in ["spot_1", "spot_2", "spot_3"]:
		plan._site_buttons[id].pressed.emit()
	expect_eq(plan._chosen, ["spot_2", "spot_3"], "the third press makes the oldest give way")
	expect_eq(plan.get_node("%Count").text, "Posts: 2 of 2")
	expect_false(plan._slot_can_drop(Vector2.ZERO, {"kind": "tower", "tower": "mage_post", "from": ""}, "spot_4"), "no card drops on a full plan")
	plan.auto_place()
	expect_eq(plan._chosen.size(), 2, "auto-place fills the slots, not the cards")
	plan.open("outpost", ["spot_1", "spot_2", "spot_3"], false, spots, 2, 1, 2)
	expect_eq(plan._chosen.size(), 2, "a plan longer than the slots is cut to them")
	main.free()


# ------------------------------------------------------------------ "+ Tower"

func test_plus_tower_buys_the_next_slot_then_its_card_at_the_trees_price_and_keeps_the_plan() -> void:
	var content := _content()
	var made := _planning(_owning(["castle_slot_1", "castle_archer_1"]))
	var main: Node = made[0]
	var plan: Control = made[1]
	var profile: HoldfastProfile = made[2]
	var button: Button = plan.get_node("%TowerButton")
	expect_true(button.visible and not button.disabled)
	expect_eq(button.text, "+ Tower (%s)" % HoldfastMeta.cost_text(content["upgrade_nodes"]["castle_slot_2"]), "the tree's price")
	plan._site_buttons["spot_6"].pressed.emit()
	var stars := profile.get_stars()
	button.pressed.emit()
	expect_eq(profile.get_castle_slots(), 2, "the slot is bought")
	expect_eq(profile.get_stars(), stars - int(content["upgrade_nodes"]["castle_slot_2"]["cost"]), "and paid in stars")
	expect_eq(plan._chosen, ["spot_6"], "the plan stays")
	expect_eq(button.text, "+ Tower (%s)" % HoldfastMeta.cost_text(content["upgrade_nodes"]["castle_archer_2"]), "then the card for it")
	button.pressed.emit()
	expect_eq(profile.get_castle_cards(), 2)
	expect_eq(plan.get_node("%Count").text, "Posts: 1 of 2", "the new tower shows at once")
	expect_eq(plan._tray.get_child_count(), 2)
	plan._site_buttons["spot_2"].pressed.emit()
	expect_eq(plan._chosen, ["spot_6", "spot_2"])
	main.free()


func test_plus_tower_is_refused_when_it_cannot_be_afforded_and_goes_when_nothing_is_left() -> void:
	var broke := _owning(["castle_slot_1", "castle_archer_1"])
	broke["stars"] = {"first_watch": 2}
	var made := _planning(broke)
	var main: Node = made[0]
	var plan: Control = made[1]
	var profile: HoldfastProfile = made[2]
	var button: Button = plan.get_node("%TowerButton")
	expect_true(button.disabled, "no stars")
	expect_eq(button.tooltip_text, "Not enough stars")
	expect_eq(plan.get_node("%Hint").text, "Not enough stars", "the reason is on the page, not only on hover")
	plan.tower_requested.emit()
	expect_eq(profile.get_castle_slots(), 1, "a press that gets through buys nothing either")
	main.free()
	var full := _planning(_owning(["castle_slot_1", "castle_archer_1", "castle_slot_2", "castle_archer_2", "castle_slot_3", "castle_archer_3", "castle_slot_4", "castle_slot_5"]))
	expect_false(full[1].get_node("%TowerButton").visible, "nothing left to buy")
	full[0].free()


# ------------------------------------------------------------------ the rules read the real place

const DT := 1.0 / HoldfastRules.TICK_RATE
const BIG := 1000000.0


## What one tick of fire takes off an enemy standing at `at`, with posts on `layout` and Crossfire
## owned: nothing else is happening (no wave, the Hero and Recruits harmless).
func _loss_at(at: Vector2, layout: Array) -> float:
	var content: Dictionary = HoldfastContent.base().duplicate(true)
	content["levels"]["outpost"]["first_wave_delay"] = 1000.0
	content["towers"]["archer_post"]["damage"] = 10.0
	for id in ["bryn", "wren"]:
		content["staff"][id]["damage"] = 0.0
		content["staff"][id]["damage_per_level"] = 0.0
	content["hero_paths"]["flare_archer"]["attack"]["damage"] = 0.0
	content["levels"]["outpost"]["staff"].erase("post")
	for recruit in content["levels"]["outpost"]["recruits"]:
		recruit.erase("post")
	var upgrades := ["post_rate", "castle_archer_2", "link_crossfire"]
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config("outpost", upgrades, content, "flare_archer", layout), SimRng.new(1))
	var enemy := HoldfastRules.Enemy.new()
	enemy.position = at
	enemy.health = BIG
	enemy.max_health = BIG
	enemy.radius = 10.0
	enemy.speed = 0.0
	enemy.damage = 0
	rules.enemies.append(enemy)
	rules.step(DT, {})
	return BIG - enemy.health


func test_the_same_number_of_posts_on_different_spots_behaves_by_geometry_only() -> void:
	# An enemy 200 paces east of the keep: the East post and the South-east post reach it, the West one does not.
	var east := Vector2(200, 0)
	var both_near := _loss_at(east, ["spot_1", "spot_5"])
	var one_near := _loss_at(east, ["spot_1", "spot_2"])
	expect_true(both_near > 0.0 and one_near > 0.0)
	expect_near(both_near / one_near, 2.5 / 1.0, 0.01, "two posts in range crossfire, one in range does not (same count, other spots)")
	# The mirror image behaves the same: spots are only places.
	expect_near(_loss_at(Vector2(-200, 0), ["spot_2", "spot_7"]), both_near, 0.0001, "West and South-west facing west")
	expect_near(_loss_at(east, ["spot_5", "spot_1"]), both_near, 0.0001, "the order of the layout does not matter")
