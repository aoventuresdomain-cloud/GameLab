extends KitTestCase
## Layout fixes of HF-M2-33: the Plan page's eight slot buttons never overlap one another (QA saw
## slots 3/5/7 and 4/6/8 collide at eight spots and eight cards), and the journey map's header
## keeps each caption beside its value and the map where it is whether or not the guide strip shows.

const Main := preload("res://scenes/main.tscn")
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 600)]


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	return main


func _all_spots() -> Array:
	return HoldfastMeta.castle_rules(HoldfastContent.base())["spots"]


## The Plan page for a player who owns all eight spots and eight cards, at `size`.
func _plan(main: Node, size: Vector2i, placed: bool) -> Control:
	tree.root.size = size
	var plan: Control = main.planning
	var ids := []
	for spot in _all_spots():
		ids.append(spot["id"])
	plan.open("shingle_beach", ids if placed else [], placed, _all_spots(), 8)
	main.call("_show", main.Screen.PLAN)
	return plan


func _rects(plan: Control) -> Dictionary:
	var out := {}
	for id in plan._site_buttons:
		out[id] = plan._site_buttons[id].get_global_rect()
	return out


func _no_two_overlap(rects: Dictionary, what: String) -> void:
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			expect_false(rects[ids[i]].intersects(rects[ids[j]]), "%s: %s and %s do not overlap (%s, %s)" % [what, ids[i], ids[j], rects[ids[i]], rects[ids[j]]])


func test_eight_slots_do_not_overlap_empty_or_placed_at_any_window_size() -> void:
	for size in SIZES:
		for placed in [false, true]:
			var main := _main()
			var plan := _plan(main, size, placed)
			await tree.process_frame
			await tree.process_frame
			var rects := _rects(plan)
			expect_eq(rects.size(), 8)
			var what := "%dx%d %s" % [size.x, size.y, "placed" if placed else "empty"]
			_no_two_overlap(rects, what)
			var map_rect: Rect2 = plan._map.get_global_rect()
			for id in rects:
				expect_true(map_rect.encloses(rects[id]), "%s: %s sits inside the map" % [what, id])
			main.free()


func test_eight_cards_fit_their_tray_without_overlapping() -> void:
	for size in SIZES:
		var main := _main()
		var plan := _plan(main, size, false)
		await tree.process_frame
		await tree.process_frame
		var cards: Array = plan._tray.get_children()
		expect_eq(cards.size(), 8, "one card for each post")
		var tray: Rect2 = plan._tray.get_global_rect()
		for i in cards.size():
			var rect: Rect2 = cards[i].get_global_rect()
			expect_true(tray.grow(1.0).encloses(rect), "%dx%d: card %d is inside the tray" % [size.x, size.y, i])
			for j in range(i + 1, cards.size()):
				expect_false(rect.intersects(cards[j].get_global_rect()), "%dx%d: cards %d and %d do not overlap" % [size.x, size.y, i, j])
		main.free()


func _map_page(guided: bool) -> Array:
	var main := _main()
	tree.root.size = Vector2i(1280, 720)
	var profile: HoldfastProfile = main.get_node("Profile")
	if guided:
		var content := HoldfastContent.base()
		var first := HoldfastMeta.tutorial_level(content)
		profile.data["stars"][first] = int(content["levels"][first]["reward"]["stars"])
		profile.data["levels_won"].append(first)
		profile.data["unlocked"].append(HoldfastMeta.next_level(content, first))
	else:
		ThroughLevelZero.apply(profile)
	profile.changed.emit()
	main.call("_show", main.Screen.MAP)
	await tree.process_frame
	await tree.process_frame
	return [main, main.journey]


func test_the_map_does_not_move_when_the_guide_strip_goes() -> void:
	var made := await _map_page(true)
	var main: Node = made[0]
	var map: Control = made[1]
	expect_true(map.get_node("%Guide").visible, "the guide is on")
	var guide: Rect2 = map.get_node("%Guide").get_global_rect()
	expect_true(guide.size.y >= 56.0, "the strip has room for its two-line text (%s)" % guide.size)
	expect_false(guide.intersects(map._map.get_global_rect()), "and does not sit over the map")
	var before: Rect2 = map._map.get_global_rect()
	var positions := {}
	for id in map._ids:
		positions[id] = map._buttons[id].get_global_rect()
	ThroughLevelZero.apply(main.get_node("Profile"))
	await tree.process_frame
	await tree.process_frame
	expect_false(map.get_node("%Guide").visible, "the guide is gone once both buys are made")
	expect_eq(map._map.get_global_rect(), before, "the map keeps its place and size")
	for id in map._ids:
		expect_eq(map._buttons[id].get_global_rect(), positions[id], "%s has not moved" % id)
	main.free()


func test_the_map_header_keeps_each_caption_beside_its_value_and_clear_of_the_next() -> void:
	var made := await _map_page(false)
	var main: Node = made[0]
	var map: Control = made[1]
	var gold_caption: Label = map.get_node("Margin/Column/Header/GoldCaption")
	var gold: Label = map.get_node("%GoldValue")
	var stars_caption: Label = map.get_node("Margin/Column/Header/StarsCaption")
	var stars: Label = map.get_node("%StarsValue")
	map.get_node("%GoldValue").text = "9,999,999"
	await tree.process_frame
	expect_eq(gold.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT, "the value starts beside its caption")
	expect_eq(stars.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	var gap := gold.get_global_rect().position.x - gold_caption.get_global_rect().end.x
	expect_true(gap >= 8.0 and gap <= 24.0, "the Gold value sits right after its caption (gap %s)" % gap)
	var text_end := gold.get_global_rect().position.x + gold.get_theme_font("font").get_string_size(gold.text, HORIZONTAL_ALIGNMENT_LEFT, -1, gold.get_theme_font_size("font_size")).x
	expect_true(text_end + 8.0 <= stars_caption.get_global_rect().position.x, "even a long figure clears the Stars caption")
	var star_gap := stars.get_global_rect().position.x - stars_caption.get_global_rect().end.x
	expect_true(star_gap >= 8.0 and star_gap <= 24.0, "the Stars value sits right after its caption (gap %s)" % star_gap)
	main.free()
