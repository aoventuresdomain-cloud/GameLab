extends KitTestCase
## HF-M2-52: nothing about the Mage makes a page jump or run off the screen. The CEO's comment was
## "description in mage is making the screen act weird". The cause: Dusk Mage's Hero-page blurb ran to
## two lines where every other blurb is one, so choosing (or hovering) Dusk Mage pushed the whole Hero
## page down and, in a small window, squeezed it. These checks hold for every Hero path, the Mage Post
## and Tower Gate I cards on the tree and the Mage cards on the Plan page, at the two standard sizes and
## a small Mac window.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1100, 650)]


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	ThroughLevelZero.apply(main.get_node("Profile"))
	return main


func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


func _label(window: Vector2i) -> String:
	return "%dx%d" % [window.x, window.y]


# ------------------------------------------------------------------ the Hero page

func test_choosing_or_hovering_any_hero_path_leaves_the_hero_page_where_it_was() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	main.call("_show", main.Screen.HERO)
	var page: Control = main.hero_page
	var pillar_info: Label = page.get_node("%PillarInfo")
	var info: Label = page.get_node("%Info")
	var body: Control = page.get_node("%Main")
	for window in WINDOWS:
		tree.root.size = window
		await _settle()
		var base_info := info.text
		var rest_y := -1.0
		var rest_h := -1.0
		for id in HoldfastContent.base()["hero_paths"]:
			var what := "%s, %s" % [_label(window), id]
			profile.select_pillar(id)
			await _settle()
			if rest_y < 0.0:
				rest_y = body.get_global_rect().position.y
				rest_h = body.size.y
			expect_eq(pillar_info.get_line_count(), 1, "%s: the path's line is one line" % what)
			expect_eq(body.get_global_rect().position.y, rest_y, "%s: the page does not jump" % what)
			expect_eq(body.size.y, rest_h, "%s: nor change size" % what)
			page._pillar_buttons[id].mouse_entered.emit()
			await _settle()
			expect_eq(info.get_line_count(), 1, "%s: hovering it is one line too" % what)
			expect_eq(body.get_global_rect().position.y, rest_y, "%s: and does not move the page" % what)
			page._pillar_buttons[id].mouse_exited.emit()
		expect_eq(info.text, base_info)
	main.free()


# ------------------------------------------------------------------ the tree's cards

func test_the_mage_post_and_tower_gate_cards_fit_the_window_and_their_text_fits_them() -> void:
	var main := _main()
	main.call("_show", main.Screen.TREE)
	var page: Control = main.keep_screen
	for window in WINDOWS:
		tree.root.size = window
		await _settle()
		var to_window := tree.root.get_final_transform()
		for id in ["gate_mage", "mage_force", "mage_sight", "mage_wards"]:
			page.open_card(id)
			await _settle()
			var what := "%s, %s" % [_label(window), id]
			var rect: Rect2 = to_window * page._card_panel.get_global_rect()
			expect_true(page._card.visible, "%s: opens" % what)
			expect_true(Rect2(Vector2.ZERO, Vector2(window)).grow(0.5).encloses(rect), "%s: the card is inside the window (%s)" % [what, rect])
			for label in _labels(page._card_panel):
				expect_true(label.get_minimum_size().y <= label.size.y + 0.5, "%s: '%s' fits its label (%s in %s)" % [what, label.text.left(24), label.get_minimum_size(), label.size])
				var edge: Rect2 = to_window * label.get_global_rect()
				expect_true(edge.end.x <= rect.end.x + 0.5, "%s: '%s' stays inside the card width" % [what, label.text.left(24)])
			page.close_card()
	main.free()


func _labels(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if child is Label and child.visible:
			out.append(child)
		out.append_array(_labels(child))
	return out


# ------------------------------------------------------------------ the Plan page

func test_the_mage_cards_on_the_plan_page_fit_their_tray_at_every_size() -> void:
	var main := _main()
	var plan: Control = main.planning
	var spots: Array = HoldfastMeta.castle_rules(HoldfastContent.base())["spots"]
	main.call("_show", main.Screen.PLAN)
	for window in WINDOWS:
		tree.root.size = window
		plan.open("shingle_beach", [], false, spots, 5, 3, spots.size())
		await _settle()
		var tray: Rect2 = plan._tray.get_global_rect()
		var cards: Array = plan._tray.get_children()
		expect_eq(cards.size(), 8, "%s: five Archer and three Mage cards" % _label(window))
		for i in cards.size():
			var rect: Rect2 = cards[i].get_global_rect()
			expect_true(tray.grow(1.0).encloses(rect), "%s: card %d is inside the tray" % [_label(window), i])
			for j in range(i + 1, cards.size()):
				expect_false(rect.intersects(cards[j].get_global_rect()), "%s: cards %d and %d do not overlap" % [_label(window), i, j])
			for label in _labels(cards[i]):
				expect_true(label.get_minimum_size().x <= label.size.x + 0.5, "%s: '%s' fits its card" % [_label(window), label.text.left(24)])
	main.free()
