extends KitTestCase
## HF-M2-75: finding your way on the tree. Section chips only for a section with a revealed node and
## no totals on them; one line "Found 12 of about 70"; a minimap of what is found, in a side column;
## a Can buy now strip below the view that takes you to a node; the guided banner only for the guided
## first buys. Nothing sits over the view (chips above, the strip below, the map beside it), so nothing
## covers a buyable node. The first visit is tested from a new save and a late-game save, each
## written to disk and read back as JSON.

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://tree_navigation_tests"


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


func _main(path: String) -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	main.get_node("Profile").save_path = path
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


## Writes `data` as a save and opens the game on that file: the profile is what JSON gives back.
func _from_save(name: String, data: Dictionary) -> Node:
	var path := _path(name)
	var first := _main(path)
	first.get_node("Profile").data = data
	first.get_node("Profile")._save()
	first.free()
	var text := FileAccess.get_file_as_string(path)
	expect_true(text.begins_with("GLSAVE") and JSON.parse_string(text.substr(text.find("\n") + 1)) is Dictionary, "%s: the save on disk is a header and then JSON" % name)
	return _main(path)


func _open(main: Node) -> Control:
	main.call("_show", main.Screen.TREE)
	return main.keep_screen


func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


func _content() -> Dictionary:
	return HoldfastContent.base()


## A player who has won Level 0 and not yet made the two guided buys.
func _guided() -> Dictionary:
	var content := _content()
	var profile := HoldfastMeta.new_profile(content)
	profile = HoldfastMeta.bank_run(content, profile, {"outcome": "won", "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	profile["gold"] = 150
	return profile


## A player well into the game: the castle, the stand done, a good many nodes owned, gold in hand.
func _late() -> Dictionary:
	var content := _content()
	var profile := ThroughLevelZero.of(content, HoldfastMeta.new_profile(content))
	profile["stand_done"] = true
	profile["gold"] = 4000
	profile["stars"]["first_watch"] = int(profile["stars"]["first_watch"]) + 12
	for id in ["castle_slot_2", "post_timbers", "post_drills", "flare_boots", "keep_walls_1", "tithe_1"]:
		var bought := HoldfastMeta.buy(content, profile, id)
		if bought["ok"]:
			profile = bought["profile"]
	profile["gold"] = 4000
	return profile


## Everything on the page that is not the web: its global rects.
func _furniture(page: Control) -> Dictionary:
	var out := {"chips": page.get_node("%Tabs"), "strip": page.get_node("%BuyStrip"), "side": page.get_node("%Side"), "footer": page.get_node("%Info").get_parent(), "guide": page.get_node("%Guide")}
	var rects := {}
	for name in out:
		if out[name].is_visible_in_tree():
			rects[name] = out[name].get_global_rect()
	return rects


## Nothing but the web is in the view, and every node that can be bought is whole inside it.
func _check_nothing_covers_a_buyable_node(page: Control, label: String) -> void:
	var view: Rect2 = page.get_node("%View").get_global_rect()
	var rects := _furniture(page)
	for name in rects:
		expect_false(view.intersects(rects[name]), "%s: the %s is outside the view (%s, %s)" % [label, name, rects[name], view])
	var minimap: Control = page.get_node("%Minimap")
	if minimap.is_visible_in_tree():
		expect_false(view.intersects(minimap.get_global_rect()), "%s: the minimap is in the side column, outside the view" % label)
	expect_false(page._key.visible, "%s: the key is shut, so it covers nothing" % label)
	var buyable: Array = page._profile.get_buyable_nodes()
	for id in buyable:
		var button: Button = page._node_buttons[id]
		if button.visible and button.get_parent().visible:
			# What is outside the view is clipped away, so what is seen of a node is the part inside it.
			var rect: Rect2 = button.get_global_rect().intersection(view)
			if rect.has_area():
				for name in rects:
					expect_false(rect.intersects(rects[name]), "%s: %s is not under the %s" % [label, id, name])


# ------------------------------------------------------------------ chips and the count

func test_a_chip_is_there_only_for_a_section_with_a_revealed_node_and_carries_no_total() -> void:
	for which in ["guided", "late"]:
		var main := _from_save("chips_" + which, _guided() if which == "guided" else _late())
		var page := _open(main)
		await _settle()
		var content := _content()
		var wanted := {}
		for id in content["upgrade_nodes"]:
			if page._profile.is_visible(id):
				var section: Dictionary = content["upgrade_sections"][content["upgrade_nodes"][id]["branch"]]
				wanted[str(section.get("tab", section["name"]))] = true
		var chips: Array = page._tab_buttons.keys()
		chips.sort()
		var expected: Array = wanted.keys()
		expected.sort()
		expect_eq(chips, expected, "%s: a chip for each section with a node found, and no other" % which)
		for chip in page._tab_buttons.values():
			expect_true(chip.visible, "%s: %s is shown" % [which, chip.text])
			var digits := RegEx.create_from_string("[0-9]")
			expect_true(digits.search(chip.text) == null, "%s: %s has no number on it" % [which, chip.text])
		main.free()


func test_the_found_line_counts_what_is_revealed_out_of_a_round_figure() -> void:
	var main := _from_save("found", _guided())
	var page := _open(main)
	await _settle()
	var label: Label = page.get_node("%FoundLabel")
	var pattern := RegEx.create_from_string("^Found (\\d+) of about (\\d+)$")
	var found := pattern.search(label.text)
	expect_true(found != null, "the line reads 'Found N of about M' (%s)" % label.text)
	if found != null:
		var seen := 0
		for id in _content()["upgrade_nodes"]:
			if page._profile.is_visible(id):
				seen += 1
		expect_eq(int(found.get_string(1)), seen, "N is the nodes on show")
		var total := int(found.get_string(2))
		expect_eq(total % 10, 0, "M is a round figure, not the exact total")
		expect_true(total >= _content()["upgrade_nodes"].size() - 30 and total >= seen, "and it is about the size of the tree")
	var before := int(found.get_string(1)) if found != null else 0
	page._profile.data["stars"]["first_watch"] = 0
	page._profile.data["gold"] = 9000
	page._profile.data["stars"][HoldfastMeta.tutorial_level(_content())] = 4
	var bought: Dictionary = HoldfastMeta.buy(_content(), page._profile.data, HoldfastMeta.castle_rules(_content())["guided"][0])
	expect_true(bought["ok"], "the first guided buy goes through")
	page._profile.data = bought["profile"]
	page._profile.changed.emit()
	var after := pattern.search(label.text)
	expect_true(int(after.get_string(1)) > before, "buying reveals more, and the line follows (%s)" % label.text)
	main.free()


# ------------------------------------------------------------------ the minimap

func test_the_minimap_shows_only_found_nodes_and_a_press_on_it_moves_the_view() -> void:
	var main := _from_save("minimap", _late())
	var page := _open(main)
	await _settle()
	var minimap: Control = page.get_node("%Minimap")
	expect_true(minimap.visible, "a web of this size has a map")
	var shown: Array = page.found_ids()
	for id in page._node_buttons:
		expect_eq(id in shown, page._profile.is_visible(id), "%s: on the map exactly when it is found" % id)
	expect_true(shown.size() >= 3 and shown.size() < _content()["upgrade_nodes"].size(), "not every node there is (%d)" % shown.size())
	var side: Rect2 = page.get_node("%Side").get_global_rect()
	expect_true(side.encloses(minimap.get_global_rect()), "it sits in the side column")
	# A press on a dot's place on the map brings that part of the web to the middle of the view.
	var web: Control = page.get_node("%Web")
	page.zoom_by(1.0 / page.ZOOM_STEP)
	await _settle()
	var far := ""
	var best := 0.0
	var middle: Vector2 = (page.get_node("%View").size * 0.5 - web.position) / web.scale.x
	for id in shown:
		var gap: float = page._point(id).distance_to(middle)
		if gap > best:
			best = gap
			far = id
	minimap.queue_redraw()
	await _settle()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = page._map_origin + (page._point(far) - page._map_bounds.position) * page._map_scale
	var before: Vector2 = web.position
	page._on_minimap_input(press)
	expect_true(web.position != before, "the view moved")
	var now: Vector2 = (page.get_node("%View").size * 0.5 - web.position) / web.scale.x
	expect_true(now.distance_to(page._point(far)) < best, "and is nearer %s than it was (%s of %s)" % [far, now.distance_to(page._point(far)), best])
	main.free()


func test_a_new_game_has_no_map_to_draw_yet() -> void:
	var main := _from_save("map_new", HoldfastMeta.new_profile(_content()))
	var page := _open(main)
	await _settle()
	expect_false(page.get_node("%Minimap").visible, "one node needs no map")
	expect_true(page.get_node("%FoundLabel").visible, "but the count is there")
	main.free()


# ------------------------------------------------------------------ the strip

func test_the_can_buy_now_strip_lists_what_is_affordable_cheapest_first_and_takes_you_there() -> void:
	var main := _from_save("strip", _late())
	var page := _open(main)
	await _settle()
	var strip: HBoxContainer = page.get_node("%BuyStrip")
	var ids: Array = page.buy_now_ids()
	expect_true(ids.size() >= 1, "there is something to buy")
	var content := _content()
	for id in ids:
		expect_eq(page._profile.why_not_buy(id), "", "%s can be bought now" % id)
	for i in range(1, ids.size()):
		expect_true(int(content["upgrade_nodes"][ids[i - 1]]["cost"]) <= int(content["upgrade_nodes"][ids[i]]["cost"]), "cheapest first")
	var buttons := strip.get_children().filter(func(c: Node) -> bool: return c is Button)
	expect_eq(buttons.size(), mini(ids.size(), page.STRIP_MAX), "a button for each, up to %d" % page.STRIP_MAX)
	for button in buttons:
		expect_true(button.size.y >= 44.0 and button.size.x >= 44.0, "%s is at least 44 px" % button.text)
		expect_true(button.icon != null, "%s has its coin or star" % button.text)
	expect_true(strip.get_children()[0].text == "Can buy now", "the strip says what it is")
	# A press takes the view to the node: it is in view, its button has the focus.
	var target: String = ids[ids.size() - 1] if ids.size() <= page.STRIP_MAX else ids[0]
	var chosen: Button = buttons[ids.find(target)] if ids.find(target) < buttons.size() else buttons[0]
	chosen.pressed.emit()
	await _settle()
	var view: Rect2 = page.get_node("%View").get_global_rect()
	var node: Button = page._node_buttons[ids[buttons.find(chosen)]]
	expect_true(view.encloses(node.get_global_rect()), "the node is in view")
	expect_true(node.has_focus(), "and has the focus")
	expect_true(node.get_global_rect().get_center().distance_to(view.get_center()) < 60.0, "near the middle of it")
	_check_nothing_covers_a_buyable_node(page, "after going to a node")
	main.free()


func test_nothing_is_listed_while_the_guided_buys_are_due() -> void:
	var main := _from_save("strip_guided", _guided())
	var page := _open(main)
	await _settle()
	expect_eq(page.buy_now_ids(), [], "the banner asks instead")
	expect_eq(page.get_node("%BuyStrip").get_child_count(), 0, "and the strip is empty")
	main.free()


# ------------------------------------------------------------------ the banner and the first visit

func test_the_banner_is_for_the_guided_first_buys_and_then_gone() -> void:
	var main := _from_save("banner_guided", _guided())
	var page := _open(main)
	await _settle()
	expect_true(page.get_node("%Guide").visible, "it is there while the guided buys are due")
	expect_true(page.get_node("%GuideLabel").text.begins_with("Spend a star on"), "and says what to buy: %s" % page.get_node("%GuideLabel").text)
	main.free()
	var later := _from_save("banner_late", _late())
	var late_page := _open(later)
	await _settle()
	expect_false(late_page.get_node("%Guide").visible, "and it is gone once they are made")
	later.free()


func test_the_first_visit_fits_the_one_node_you_can_buy_with_the_banner_from_a_json_save() -> void:
	var main := _from_save("first_visit_guided", _guided())
	var page := _open(main)
	await _settle()
	var guide: String = page._profile.get_guide_node()
	expect_true(guide != "", "a node is the one to buy (%s)" % guide)
	expect_true(page.get_node("%Guide").visible, "with the banner up")
	var view: Rect2 = page.get_node("%View").get_global_rect()
	var button: Button = page._node_buttons[guide]
	expect_true(button.visible and view.grow(-8.0).encloses(button.get_global_rect()), "that node is whole in the view, clear of its edge (%s in %s)" % [button.get_global_rect(), view])
	expect_true(page._tags[guide].visible, "with its price tag")
	expect_true(page.get_node("%GuideButton").get_global_rect().size.y >= 44.0, "and a banner button to press")
	_check_nothing_covers_a_buyable_node(page, "first visit, banner up")
	main.free()


func test_the_first_visit_of_a_new_save_and_a_late_save_leave_the_buyable_nodes_clear_from_json() -> void:
	for which in ["new", "late"]:
		var data := HoldfastMeta.new_profile(_content()) if which == "new" else _late()
		var main := _from_save("first_visit_" + which, data)
		var page := _open(main)
		await _settle()
		var view: Rect2 = page.get_node("%View").get_global_rect()
		var checked := 0
		# A new save has nothing it can afford yet: the node there is to find is the one that is shown.
		var ids: Array = page.found_ids() if which == "new" else page._profile.get_buyable_nodes()
		for id in ids:
			var button: Button = page._node_buttons[id]
			if button.visible and button.get_parent().visible:
				if which == "new" or view.encloses(button.get_global_rect()):
					checked += 1
				expect_true(which != "new" or view.encloses(button.get_global_rect()), "%s: %s is whole in the first view" % [which, id])
		expect_true(checked > 0, "%s: a node to find or buy is in the first view" % which)
		_check_nothing_covers_a_buyable_node(page, which + " first visit")
		for label in page._tab_buttons:
			page.show_tab(label)
			await _settle()
			_check_nothing_covers_a_buyable_node(page, "%s, tab %s" % [which, label])
		main.free()
