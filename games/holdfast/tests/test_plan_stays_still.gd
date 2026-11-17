extends KitTestCase
## HF-M2-81 (quick fix 14c-a): nothing on the Plan page moves when the first post is placed, so a tap
## straight after Auto-place cannot miss. QA saw Start drop 32 px at 1280 x 720 when its second line
## ("Need a post") went and the hint line came and went above the map.

const Main := preload("res://scenes/main.tscn")
const Guidance := preload("res://scripts/ui/guidance.gd")
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 600)]


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


func _open(main: Node, size: Vector2i, squad: bool, mage_cards: int) -> Control:
	tree.root.size = size
	var plan: Control = main.planning
	var spots: Array = HoldfastMeta.castle_rules(HoldfastContent.base())["spots"]
	plan.open("shingle_beach", [], false, spots, 4, mage_cards, 4)
	if squad:
		plan.set_squad(["Bryn"], 1)
	main.call("_show", main.Screen.PLAN)
	return plan


func _frames() -> void:
	await tree.process_frame
	await tree.process_frame


func _watched(plan: Control) -> Dictionary:
	return {
		"Start": plan._start.get_global_rect(),
		"Auto-place": plan._auto.get_global_rect(),
		"map": plan._map.get_global_rect(),
		"tray": plan._tray.get_global_rect(),
	}


func _same(before: Dictionary, after: Dictionary, what: String) -> void:
	for key in before:
		expect_eq(after[key], before[key], "%s: %s does not move" % [what, key])


func test_placing_and_clearing_the_first_post_moves_nothing() -> void:
	for size in SIZES:
		for squad in [false, true]:
			var main := _main()
			var plan := _open(main, size, squad, 0)
			await _frames()
			var what := "%dx%d%s" % [size.x, size.y, " with a squad" if squad else ""]
			var before := _watched(plan)
			plan.auto_place()
			await _frames()
			expect_false(plan.chosen().is_empty(), "%s: auto-place put a post down" % what)
			_same(before, _watched(plan), what + " after the first post")
			plan._toggle(plan.chosen()[0])
			await _frames()
			_same(before, _watched(plan), what + " after taking it off again")
			main.free()


func test_the_mage_post_hint_going_after_the_first_mage_post_moves_nothing() -> void:
	for size in SIZES:
		var main := _main()
		var plan := _open(main, size, true, 1)
		await _frames()
		var before := _watched(plan)
		plan.auto_place()
		await _frames()
		_same(before, _watched(plan), "%dx%d after Auto-place with a Mage Post card" % [size.x, size.y])
		main.free()


func test_start_still_starts_a_layout_that_is_not_the_saved_one() -> void:
	var main := _main()
	var plan := _open(main, Vector2i(1280, 720), false, 0)
	await _frames()
	var spots: Array = HoldfastMeta.castle_rules(HoldfastContent.base())["spots"]
	var saved: Array = [str(spots[0]["id"])]
	plan.open("shingle_beach", saved, true, spots, 4, 0, 4)
	await _frames()
	var other := str(spots[spots.size() - 1]["id"])
	plan._toggle(saved[0])
	plan._toggle(other)
	var heard := []
	plan.start_requested.connect(func(layout: Array) -> void: heard.append(layout))
	plan._start.pressed.emit()
	expect_eq(heard.size(), 1, "Start asked for the run once")
	expect_eq(heard[0], [other], "with the layout on the page, not the saved one")
	main.free()


# ------------------------------------------------------------------ a late save on the map

func test_a_save_that_has_won_a_real_level_is_not_held_up_by_the_stand() -> void:
	var content := HoldfastContent.base()
	var first := HoldfastMeta.tutorial_level(content)
	var profile := HoldfastMeta.bank_run(content, HoldfastMeta.new_profile(content), {"outcome": "won", "level": first, "gold": 0})
	for id in ["castle_slot_1", "castle_archer_1"]:
		profile = HoldfastMeta.buy(content, profile, id)["profile"]
	expect_true(HoldfastMeta.stand_due(content, profile), "the stand is due straight after the guided buys")
	var next := HoldfastMeta.next_level(content, first)
	profile["levels_won"].append(next)
	expect_false(HoldfastMeta.stand_due(content, profile), "once a real level is won it is not offered")
	expect_true(str(Guidance.guide(content, _profile_of(profile)).get("text", "")) != Guidance.STAND_LINE, "so the guide line does not say the post is up")


func _profile_of(data: Dictionary) -> HoldfastProfile:
	var profile := HoldfastProfile.new()
	tree.root.add_child(profile)
	profile.data = data
	return profile
