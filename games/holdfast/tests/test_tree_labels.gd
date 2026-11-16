extends KitTestCase
## HF-M2-74: a tree node has its glyph inside and its price tag under it; owned is green with a
## tick; nothing on the web is within 6 px of anything else, at the first view and fully zoomed in;
## the shape key; the detail card (section colour on its header only, the coin on Buy, what a link needs).

const Main := preload("res://scenes/main.tscn")
const CLEAR := 6.0
const SECTION_TOKENS := [&"sec_hero", &"sec_post", &"sec_keep", &"sec_gold", &"sec_castle"]
const THEME := "res://assets/ui/theme.tres"


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


## A new game (one node to see), a busy mid-game web, and every node there is.
func _profile_for(main: Node, which: String) -> HoldfastProfile:
	var profile: HoldfastProfile = main.get_node("Profile")
	var content := HoldfastContent.base()
	if which == "new":
		profile.new_game()
		return profile
	ThroughLevelZero.apply_castle(profile)
	profile.data["gold"] = 1000000
	if which == "mid":
		for id in ["castle_slot_2", "castle_slot_3", "castle_archer_2", "post_timbers", "post_drills", "post_sight", "post_rate", "post_mend", "flare_boots", "flare_hide", "flare_focus", "keep_walls_1", "keep_walls_2", "keep_beam_1", "tithe_1", "gate_mage", "mage_sight"]:
			profile.data["stars"]["first_watch"] = int(profile.data["stars"]["first_watch"]) + 6
			profile.data = HoldfastMeta.buy(content, profile.data, id)["profile"]
	else:
		for id in content["upgrade_nodes"]:
			if not content["upgrade_nodes"][id].has("excludes"):
				profile.data["stars"]["first_watch"] = int(profile.data["stars"]["first_watch"]) + 6
				var bought := HoldfastMeta.buy(content, profile.data, id)
				if bought["ok"]:
					profile.data = bought["profile"]
	profile.changed.emit()
	return profile


func _open(main: Node) -> Control:
	main.call("_show", main.Screen.TREE)
	return main.keep_screen


func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


## Everything on show on the web, as rects on the screen.
func _items(page: Control) -> Array:
	var web: Control = page._web
	var out := []
	for id in page._node_buttons:
		var button: Button = page._node_buttons[id]
		if button.visible and button.get_parent().visible:
			var foot: Vector2 = page._foot(id)
			out.append({"what": "node " + id, "id": id, "rect": web.get_global_transform() * Rect2(page._point(id) - foot * 0.5, foot), "own": id})
			if page._labels[id].visible:
				out.append({"what": "name " + id, "id": id, "rect": page._labels[id].get_global_transform() * Rect2(Vector2.ZERO, page._labels[id].size), "own": ""})
			if page._tags[id].visible:
				out.append({"what": "tag " + id, "id": id, "rect": page._tags[id].get_global_transform() * Rect2(Vector2.ZERO, page._tags[id].size), "own": id})
	for section in page._headings:
		var heading: Label = page._headings[section]
		if heading.visible and heading.get_parent().visible:
			var rect: Rect2 = page._text_rect(heading, page._web.scale.x)
			out.append({"what": "heading " + section, "id": "", "rect": web.get_global_transform() * rect, "own": ""})
	return out


func _check_clear(page: Control, label: String) -> void:
	var items := _items(page)
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: Dictionary = items[i]
			var b: Dictionary = items[j]
			# A tag hangs from its own node, so those two touch by design.
			if (a["own"] != "" and a["own"] == b["id"] and a["what"].begins_with("node")) or (b["own"] != "" and b["own"] == a["id"] and b["what"].begins_with("node")):
				continue
			# Two nodes are round: they only have to stay apart (the rule is about names, tags and headings).
			if a["what"].begins_with("node") and b["what"].begins_with("node"):
				var apart: float = a["rect"].get_center().distance_to(b["rect"].get_center()) - (a["rect"].size.x + b["rect"].size.x) * 0.5
				expect_true(apart > 0.0, "%s: %s and %s overlap" % [label, a["what"], b["what"]])
				continue
			if a["rect"].grow(CLEAR - 0.5).intersects(b["rect"]):
				expect_true(false, "%s: %s and %s are less than 6 px apart" % [label, a["what"], b["what"]])


func _check_buyable_tags(page: Control, label: String) -> void:
	var owned: Array = page._profile.get_upgrades()
	for id in page._node_buttons:
		var button: Button = page._node_buttons[id]
		if button.visible and button.get_parent().visible and page._is_lit(id) and not id in owned and page._marks[id].get_meta("state") != "closed":
			expect_true(page._tags[id].visible, "%s: %s is buyable and keeps its tag" % [label, id])


# ------------------------------------------------------------------ the node

func test_a_node_has_no_number_inside_and_its_price_is_the_tag_under_it() -> void:
	var main := _main()
	_profile_for(main, "mid")
	var page := _open(main)
	await _settle()
	for id in page._node_buttons:
		expect_eq(page._node_buttons[id].text, "", "%s: no number inside the circle" % id)
		var tag: Control = page._tags[id]
		var node: Dictionary = HoldfastContent.base()["upgrade_nodes"][id]
		expect_eq(tag.get_node("Value").text, str(int(node["cost"])) if HoldfastMeta.is_star_node(node) else page.Hud.format_number(int(node["cost"])), "%s: the tag says the price" % id)
		var icon: TextureRect = tag.get_child(0)
		expect_true(icon.texture != null, "%s: the tag has its coin or star" % id)
		expect_eq(icon.texture.resource_path.get_file(), "star.svg" if HoldfastMeta.is_star_node(node) else "coin.svg", "%s: a star for stars, a coin for gold" % id)
	main.free()


func test_owned_is_green_with_a_tick_in_every_section_and_buyable_is_an_amber_ring() -> void:
	var main := _main()
	_profile_for(main, "mid")
	var page := _open(main)
	await _settle()
	var owned: Array = page._profile.get_upgrades()
	var seen := {}
	for id in page._node_buttons:
		var state: String = page._marks[id].get_meta("state")
		if id in owned:
			expect_eq(state, "owned", "%s is owned" % id)
			seen[HoldfastContent.base()["upgrade_nodes"][id]["branch"]] = true
		elif page._profile.is_near(id):
			expect_eq(state, "open", "%s is one buy away: an amber ring" % id)
			expect_eq(page._edge(state), page.COLOUR_ACT, "the ring is the amber token")
	expect_eq(page._edge("owned"), page.OWNED_EDGE, "owned is the green token")
	expect_true(seen.size() >= 4, "owned nodes in several sections (%d)" % seen.size())
	for section in page._section_columns:
		expect_true(page.SECTION_TOKEN.has(section), "%s has a section colour" % section)
	main.free()


func test_the_pack_has_all_six_kinds_and_each_node_has_a_glyph() -> void:
	var main := _main()
	var page := _open(main)
	var found := {}
	for id in page._node_buttons:
		found[page._kind(id)] = true
		expect_true(page._icon(page._glyph(id)) != null, "%s has a glyph" % id)
		expect_true(page._icon("tick") != null)
	for kind in page.KINDS:
		expect_true(found.has(kind), "the pack has a %s node" % kind)
	expect_eq(page._kind("link_rally"), "link")
	expect_eq(page._kind("gate_mage"), "gate")
	expect_eq(page._kind("castle_slot_1"), "castle")
	expect_eq(page._kind("post_piercing"), "capstone")
	expect_eq(page._kind("post_twin"), "behaviour")
	expect_eq(page._kind("post_drills"), "stat")
	main.free()


func test_no_screen_colour_is_missing_from_the_theme_for_the_sections() -> void:
	var theme: Theme = load(THEME)
	for token in SECTION_TOKENS:
		expect_true(theme.has_color(token, UiTokens.TYPE), "the theme has %s" % token)
	var main := _main()
	var page := _open(main)
	for section in HoldfastContent.base()["upgrade_sections"]:
		expect_true(page.SECTION_TOKEN.has(section), "%s has a colour for the card's header" % section)
		expect_true(theme.has_color(page.SECTION_TOKEN[section], UiTokens.TYPE), "%s's colour is in the theme" % section)
	main.free()


# ------------------------------------------------------------------ nothing within 6 px

func test_nothing_is_within_6_px_of_anything_at_the_first_view_and_buyable_nodes_keep_their_tags() -> void:
	for which in ["new", "mid", "all"]:
		var main := _main()
		_profile_for(main, which)
		var page := _open(main)
		await _settle()
		page.show_overview()
		await _settle()
		_check_clear(page, "%s web at the first view (zoom %.2f)" % [which, page._web.scale.x])
		_check_buyable_tags(page, "%s web at the first view" % which)
		main.free()


func test_nothing_is_within_6_px_of_anything_fully_zoomed_in_or_out_and_at_every_tab() -> void:
	for which in ["mid", "all"]:
		var main := _main()
		_profile_for(main, which)
		var page := _open(main)
		await _settle()
		for zoom in [page.ZOOM_MAX, 1.5, 1.0, 0.6, page.ZOOM_MIN]:
			page._web.scale = Vector2.ONE * zoom
			page._sync_labels()
			_check_clear(page, "%s web at zoom %.2f" % [which, zoom])
			if zoom >= 1.0:
				_check_buyable_tags(page, "%s web at zoom %.2f" % [which, zoom])
		for tab in page.tab_names():
			page.show_tab(tab)
			await _settle()
			_check_clear(page, "%s web at tab %s (zoom %.2f)" % [which, tab, page._web.scale.x])
		main.free()


func test_a_tag_that_has_no_room_under_its_node_moves_above_and_a_name_goes_first() -> void:
	var main := _main()
	_profile_for(main, "mid")
	var page := _open(main)
	await _settle()
	page._web.scale = Vector2.ONE * page.ZOOM_MIN
	page._sync_labels()
	var above := 0
	var hidden_names := 0
	for id in page._node_buttons:
		if page._tags[id].visible and page._tag_side[id] != page.Side.BELOW:
			above += 1
		if page._node_buttons[id].visible and not page._labels[id].visible:
			hidden_names += 1
	expect_true(above > 0, "some tags had to move off the spot under their node (%d)" % above)
	expect_true(hidden_names > 0, "and names with no room are left off (%d)" % hidden_names)
	main.free()


# ------------------------------------------------------------------ the key

func test_the_key_shows_every_kind_as_owned_buyable_and_locked() -> void:
	var main := _main()
	var page := _open(main)
	await _settle()
	var key: Control = page._key
	expect_false(key.visible, "the key is shut until asked for")
	page.get_node("%KeyButton").button_pressed = true
	expect_true(key.visible, "the Key button opens it")
	var grid: GridContainer = key.get_child(0)
	expect_eq(grid.get_child_count(), 4 * (1 + page.KINDS.size()), "a header row and a row for each kind, with three states")
	var names := []
	for i in range(4, grid.get_child_count(), 4):
		names.append(grid.get_child(i).text)
	expect_eq(names, ["Stat", "Behaviour", "Castle", "Link", "Gate", "Capstone"])
	await _settle()
	expect_true(page._view.get_global_rect().encloses(key.get_global_rect()), "and stays inside the view (%s in %s)" % [key.get_global_rect(), page._view.get_global_rect()])
	for control in key.find_children("*", "Label", true, false):
		expect_true(control.get_global_rect().size.y > 0.0)
	page.get_node("%KeyButton").button_pressed = false
	expect_false(key.visible, "and shuts again")
	main.free()


# ------------------------------------------------------------------ the card

func test_the_card_header_carries_the_section_colour_and_nothing_else_on_it_does() -> void:
	var main := _main()
	_profile_for(main, "mid")
	var page := _open(main)
	await _settle()
	var colours := {}
	for id in ["post_drills", "flare_hide", "keep_walls_1", "tithe_1", "castle_slot_2", "mage_sight"]:
		page.open_card(id)
		var branch: String = HoldfastContent.base()["upgrade_nodes"][id]["branch"]
		expect_eq(page._card_bar.color, UiTokens.colour(page.SECTION_TOKEN[branch]), "%s: the header bar is %s's colour" % [id, branch])
		colours[branch] = page._card_bar.color
		expect_eq(page._card_style.border_color, page.CARD_EDGE, "%s: the card's own edge stays neutral" % id)
		page.close_card()
	expect_eq(colours.size(), 6, "six sections, six colours")
	expect_eq(colours.values().size(), colours.values().reduce(func(seen: Array, c: Color) -> Array: return seen if c in seen else seen + [c], []).size(), "all different")
	main.free()


func test_buy_carries_the_coin_or_star_and_a_link_with_two_parents_says_so() -> void:
	var main := _main()
	_profile_for(main, "mid")
	var page := _open(main)
	await _settle()
	page.open_card("post_drills")
	expect_eq(page._card_buy.text, "Buy")
	expect_eq(page._card_buy.icon.resource_path.get_file(), "coin.svg", "a gold price has the coin on Buy")
	page.close_card()
	page.open_card("castle_slot_2")
	expect_eq(page._card_buy.icon.resource_path.get_file(), "star.svg" if HoldfastMeta.is_star_node(HoldfastContent.base()["upgrade_nodes"]["castle_slot_2"]) else "coin.svg")
	page.close_card()
	for id in ["link_last_light", "link_posted_hand", "link_pillar_echo"]:
		var node: Dictionary = HoldfastContent.base()["upgrade_nodes"][id]
		page.open_card(id)
		var said := false
		for label in page._card_extra.get_children():
			if label is Label and label.text.begins_with("Needs both"):
				said = true
				for required in node["requires"]:
					expect_true(label.text.contains(str(HoldfastContent.base()["upgrade_nodes"][required]["name"])), "%s: names %s" % [id, required])
		expect_true(said, "%s needs two parents and its card says so" % id)
		page.close_card()
	page.open_card("link_rally")
	for label in page._card_extra.get_children():
		expect_false(label is Label and label.text.begins_with("Needs both"), "a link with one parent does not say it")
	page.close_card()
	main.free()
