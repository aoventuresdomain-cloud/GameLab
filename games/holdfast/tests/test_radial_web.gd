extends KitTestCase
## HF-M2-55: the skill tree is a radial web (First Slot in the middle, one ring a step, each section
## in its own wedge). The positions are pack data, the names under the nodes stay 12 px on screen,
## the first view fits what is revealed and the card never sits on the node it shows. Checked at the
## two standard window sizes and a small Mac window.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1100, 650)]
## The Designer's measured closest pair is 65: a 44 px node leaves 20 px or more between two.
const CLOSEST_PAIR := 64.0
const LONGEST_SPOKE := 425.0
## A mid-game set: a spread over every section, bought in an order the rules allow.
const MID := ["castle_slot_2", "castle_slot_3", "castle_archer_2", "post_timbers", "post_drills", "post_sight", "post_rate", "post_mend", "flare_boots", "flare_hide", "flare_focus", "keep_walls_1", "keep_walls_2", "keep_beam_1", "tithe_1", "gate_mage", "mage_sight"]


func _nodes() -> Dictionary:
	return HoldfastContent.base()["upgrade_nodes"]


func _at(id: String) -> Vector2:
	return Vector2(float(_nodes()[id]["at"]["x"]), float(_nodes()[id]["at"]["y"]))


func _tree_page(mid := false) -> Array:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	if mid:
		var content := HoldfastContent.base()
		profile.data["gold"] = 1000000
		for id in MID:
			profile.data["stars"]["first_watch"] = int(profile.data["stars"]["first_watch"]) + 6
			var bought := HoldfastMeta.buy(content, profile.data, id)
			expect_true(bought["ok"], "%s can be bought for the set-up (%s)" % [id, bought.get("reason", "")])
			profile.data = bought["profile"]
		profile.changed.emit()
	main.journey.get_node("%TreeButton").pressed.emit()
	await tree.process_frame
	await tree.process_frame
	return [main, main.keep_screen]


func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


## Where a control really is on the page, whatever its scale.
func _rect(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


# ------------------------------------------------------------------ the data

func test_the_positions_are_a_web_from_the_middle_with_room_between_nodes() -> void:
	var ids: Array = _nodes().keys()
	expect_eq(ids.size(), 62, "no node was lost")
	var low := Vector2.ZERO
	var high := Vector2.ZERO
	var closest := INF
	var farthest := 0.0
	for i in ids.size():
		low = low.min(_at(ids[i]))
		high = high.max(_at(ids[i]))
		farthest = maxf(farthest, _at(ids[i]).length())
		for j in range(i + 1, ids.size()):
			closest = minf(closest, _at(ids[i]).distance_to(_at(ids[j])))
	expect_true(low.x < -300.0 and low.y < -300.0 and high.x > 300.0 and high.y > 300.0, "the web spreads on every side of the middle (%s to %s)" % [low, high])
	expect_true(closest >= CLOSEST_PAIR, "the closest pair is %s apart" % closest)
	expect_true(farthest <= LONGEST_SPOKE, "the longest spoke is %s" % farthest)
	for id in ["castle_slot_1", "castle_archer_1"]:
		expect_true(_at(id).length() < 50.0, "%s is in the small core" % id)
	for id in ids:
		if id != "castle_slot_1" and id != "castle_archer_1":
			expect_true(_at(id).length() > 100.0, "%s is out on a ring" % id)


func test_a_node_is_no_further_in_than_the_nodes_it_needs_and_links_are_dashed_where_they_cross() -> void:
	var crossing := []
	for id in _nodes():
		for required in _nodes()[id].get("requires", []):
			expect_true(_at(id).length() >= _at(required).length() - 1.0, "%s is as far out as %s" % [id, required])
			if _nodes()[required]["branch"] != _nodes()[id]["branch"] and id.begins_with("link_"):
				crossing.append(id)
	crossing.sort()
	expect_eq(crossing, ["link_crossfire", "link_pillar_echo", "link_posted_hand"], "the three link nodes that join two sections")


func test_only_the_three_lines_where_a_link_joins_two_sections_are_dashed() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var dashed := []
	for id in _nodes():
		for required in _nodes()[id].get("requires", []):
			if page._joins_sections(id, required):
				dashed.append("%s>%s" % [id, required])
	dashed.sort()
	expect_eq(dashed, ["link_crossfire>castle_archer_2", "link_pillar_echo>flare_embers", "link_posted_hand>squad_root"])
	main.free()


func test_names_are_at_most_two_short_words_and_each_section_has_a_one_word_rim_name() -> void:
	for id in _nodes():
		var name := str(_nodes()[id].get("label", _nodes()[id]["name"]))
		expect_true(name.split(" ").size() <= 2 and name.length() <= 14, "%s: '%s' is two short words at most" % [id, name])
	var rims := []
	for section in HoldfastContent.base()["upgrade_sections"].values():
		expect_true(section.has("rim") and not str(section["rim"]).contains(" "), "%s has a one-word rim name" % section["id"])
		rims.append(section["rim"])
	expect_eq(rims.size(), 6)
	rims.sort()
	expect_eq(rims, ["Archer", "Castle", "Hero", "Keep", "Mage", "Tithe"])


# ------------------------------------------------------------------ the page

func test_nodes_are_round_and_a_44_px_target_at_real_size_and_the_card_still_names_them_in_full() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	for id in page._node_buttons:
		expect_true(page._node_buttons[id].size.x >= 44.0 and page._node_buttons[id].size.y >= 44.0, "%s is a 44 px target" % id)
	expect_eq(page._node_buttons["gate_mage"].text, "\n2", "the price, with room for the star")
	expect_eq(page._labels["gate_mage"].text, "Mage Gate", "short under the node")
	page.open_card("gate_mage")
	expect_eq(page._card_title.text, "Tower Gate I: Mage Post", "and in full on its card")
	expect_true(page._node_buttons["gate_mage"].tooltip_text.begins_with("Tower Gate I: Mage Post"), "and on the tooltip")
	main.free()


func test_the_names_stay_12_px_on_screen_and_go_when_the_web_is_too_small_for_them() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	for zoom in [page.ZOOM_MAX, 1.0, page.OVERVIEW_ZOOM_MIN, page.LABELS_MIN_ZOOM]:
		page.zoom_by(zoom / web.scale.x)
		var label: Label = page._labels["flare_boots"]
		expect_near(label.scale.x * web.scale.x, 1.0, 0.001, "zoom %s: the name is its own size" % zoom)
		expect_eq(label.get_theme_font_size("font_size"), 12)
		expect_eq(label.self_modulate.a, 1.0, "zoom %s: shown" % zoom)
		expect_near(page._headings["archer_post"].scale.x * web.scale.x, 1.0, 0.001, "and so is the rim name")
	page.zoom_by(0.5)
	expect_true(web.scale.x < page.LABELS_MIN_ZOOM)
	expect_eq(page._labels["flare_boots"].self_modulate.a, 0.0, "too small: the names go (the tooltip stays)")
	expect_true(page._node_buttons["flare_boots"].tooltip_text != "")
	page.zoom_by(2.0)
	expect_eq(page._labels["flare_boots"].self_modulate.a, 1.0, "and come back")
	main.free()


func test_no_name_sits_on_a_node_or_another_name_at_real_size() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var ids: Array = page._labels.keys()
	for i in ids.size():
		var name_rect := Rect2(page._labels[ids[i]].position, page._labels[ids[i]].size)
		for other in ids:
			if other != ids[i]:
				var node: Button = page._node_buttons[other]
				expect_false(name_rect.intersects(Rect2(node.position, node.size)), "the name of %s is not on %s" % [ids[i], other])
		for j in range(i + 1, ids.size()):
			expect_false(name_rect.intersects(Rect2(page._labels[ids[j]].position, page._labels[ids[j]].size)), "names of %s and %s apart" % [ids[i], ids[j]])
	main.free()


func test_a_new_game_with_one_node_to_show_opens_at_the_largest_first_view() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	main.call("_show", main.Screen.TREE)
	await _settle()
	var page: Control = main.keep_screen
	var shown: Array = page._node_buttons.keys().filter(func(id: String) -> bool: return page._node_buttons[id].visible)
	expect_eq(shown, ["castle_slot_1"], "only First Slot is on show")
	expect_eq(page.get_node("%Web").scale.x, page.OVERVIEW_ZOOM_MAX, "so it is shown as large as the first view goes")
	main.free()


func test_the_first_view_fits_everything_revealed_at_every_window_size() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var view: Rect2 = page.get_node("%View").get_global_rect()
	var web: Control = page.get_node("%Web")
	for window in WINDOWS:
		tree.root.size = window
		await _settle()
		view = page.get_node("%View").get_global_rect()
		var what := "%dx%d" % [window.x, window.y]
		expect_true(web.scale.x >= page.OVERVIEW_ZOOM_MIN and web.scale.x <= page.OVERVIEW_ZOOM_MAX, "%s: zoom %s" % [what, web.scale.x])
		var shown := 0
		for id in page._node_buttons:
			if page._node_buttons[id].visible:
				shown += 1
				expect_true(view.encloses(_rect(page._node_buttons[id])), "%s: %s is in view" % [what, id])
				expect_true(view.grow(1.0).encloses(_rect(page._labels[id])), "%s: and so is its name (%s in %s)" % [what, _rect(page._labels[id]), view])
		expect_true(shown >= 13, "%s: the first ring is out (%d shown)" % [what, shown])
		for section in page._headings:
			if page._headings[section].visible:
				expect_true(view.grow(1.0).encloses(_rect(page._headings[section])), "%s: rim name %s is in view" % [what, section])
	main.free()


func test_a_mid_game_web_opens_on_what_is_owned_at_the_floor() -> void:
	var made := await _tree_page(true)
	var main: Node = made[0]
	var page: Control = made[1]
	var profile: HoldfastProfile = main.get_node("Profile")
	var web: Control = page.get_node("%Web")
	for window in WINDOWS:
		tree.root.size = window
		await _settle()
		var view: Rect2 = page.get_node("%View").get_global_rect()
		var what := "%dx%d" % [window.x, window.y]
		expect_eq(web.scale.x, page.OVERVIEW_ZOOM_MIN, "%s: too much for one view, so at the floor" % what)
		var near := 0
		for id in profile.get_upgrades():
			expect_eq(page._node_buttons[id].text, "", "%s: %s is a tick" % [what, id])
			if view.encloses(_rect(page._node_buttons[id])):
				near += 1
		expect_true(near >= 6, "%s: what the player owns is around the middle of the view (%d in view)" % [what, near])
	main.free()


func test_every_tab_of_a_mid_game_web_keeps_its_nodes_in_view_at_every_window_size() -> void:
	var made := await _tree_page(true)
	var main: Node = made[0]
	var page: Control = made[1]
	for window in WINDOWS:
		tree.root.size = window
		await _settle()
		var view: Rect2 = page.get_node("%View").get_global_rect()
		var what := "%dx%d" % [window.x, window.y]
		for tab in page.tab_names():
			page.show_tab(tab)
			await tree.process_frame
			for id in page._node_buttons:
				if page._tab_rect(tab).encloses(Rect2(page._node_buttons[id].position, page._node_buttons[id].size)) and page._node_buttons[id].get_parent().visible:
					expect_true(view.encloses(_rect(page._node_buttons[id])), "%s, %s: %s is in view" % [what, tab, id])
	main.free()


func test_the_card_stands_on_the_other_side_of_the_page_from_its_node() -> void:
	var made := await _tree_page(true)
	var main: Node = made[0]
	var page: Control = made[1]
	for window in WINDOWS:
		tree.root.size = window
		await _settle()
		var left := false
		var right := false
		for id in ["castle_slot_3", "castle_archer_2", "post_drills", "flare_hide", "keep_walls_2", "gate_mage", "castle_slot_1", "castle_archer_1"]:
			page.open_card(id)
			await tree.process_frame
			var card := _rect(page._card_panel)
			var node := _rect(page._node_buttons[id])
			var what := "%dx%d, %s" % [window.x, window.y, id]
			expect_false(card.intersects(node), "%s: the card (%s) does not hide the node (%s)" % [what, card, node])
			expect_true(page.get_global_rect().grow(0.5).encloses(card), "%s: and is inside the page" % what)
			left = left or card.get_center().x < page.size.x * 0.5
			right = right or card.get_center().x > page.size.x * 0.5
			page.close_card()
		expect_true(left and right, "%dx%d: it goes to either side as the node needs" % [window.x, window.y])
	main.free()


func test_an_old_save_draws_the_same_nodes_with_the_new_layout() -> void:
	var made := await _tree_page(true)
	var main: Node = made[0]
	var page: Control = made[1]
	var profile: HoldfastProfile = main.get_node("Profile")
	var owned: Array = profile.get_upgrades().duplicate()
	expect_true(owned.size() >= 17, "the set-up bought them")
	for id in page._node_buttons:
		var bought: bool = id in owned
		expect_eq(page._marks[id].get_meta("state") == "owned", bought, "%s is drawn owned only when owned" % id)
		if bought:
			expect_true(page._node_buttons[id].visible, "%s shows" % id)
	profile.respec()
	var guided: Array = HoldfastMeta.castle_rules(HoldfastContent.base())["guided"]
	for id in owned:
		if id in guided:
			expect_eq(page._marks[id].get_meta("state"), "owned", "%s stays drawn owned: a refund leaves the two guided buys" % id)
		else:
			expect_ne(page._marks[id].get_meta("state"), "owned", "%s is no longer drawn owned after a refund" % id)
	main.free()
