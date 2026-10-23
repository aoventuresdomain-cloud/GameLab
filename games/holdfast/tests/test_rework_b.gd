extends KitTestCase
## Navigation rework, part 2 (HF-M2-30): the skill tree is one web the player pans and zooms,
## with jump tabs along the top. Node positions and the tabs come from the packs.

const Main := preload("res://scenes/main.tscn")
const NODE_COUNT := 35


func _tree_page() -> Array:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	main.journey.get_node("%TreeButton").pressed.emit()
	# One frame for the layout, one for the deferred move to the first tab.
	await tree.process_frame
	await tree.process_frame
	return [main, main.keep_screen]


func _view_rect(page: Control) -> Rect2:
	return page.get_node("%View").get_global_rect()


## True when the node's button lies wholly inside the view.
func _in_view(page: Control, id: String) -> bool:
	return _view_rect(page).encloses(page._node_buttons[id].get_global_rect())


# ------------------------------------------------------------------ the data

func test_every_node_has_a_position_and_no_two_overlap() -> void:
	var nodes: Dictionary = HoldfastContent.base()["upgrade_nodes"]
	expect_eq(nodes.size(), NODE_COUNT, "no node id was lost")
	var size: Vector2 = load("res://scripts/ui/keep_screen.gd").NODE_SIZE
	var ids := nodes.keys()
	for i in ids.size():
		expect_true(nodes[ids[i]].has("at"), "%s has a position" % ids[i])
		for j in range(i + 1, ids.size()):
			var a := Rect2(Vector2(float(nodes[ids[i]]["at"]["x"]), float(nodes[ids[i]]["at"]["y"])) - size * 0.5, size)
			var b := Rect2(Vector2(float(nodes[ids[j]]["at"]["x"]), float(nodes[ids[j]]["at"]["y"])) - size * 0.5, size)
			expect_false(a.intersects(b), "%s and %s do not overlap" % [ids[i], ids[j]])


func test_a_node_sits_below_every_node_it_needs() -> void:
	var nodes: Dictionary = HoldfastContent.base()["upgrade_nodes"]
	for id in nodes:
		for required in nodes[id].get("requires", []):
			expect_true(float(nodes[id]["at"]["y"]) > float(nodes[required]["at"]["y"]), "%s is below %s" % [id, required])


func test_a_pack_node_without_a_position_is_refused() -> void:
	var schema := PackSchema.load_file(HoldfastContent.SCHEMA)
	var node: Dictionary = HoldfastContent.base()["upgrade_nodes"]["post_timbers"].duplicate(true)
	var errors: PackedStringArray = []
	schema.validate_def(node, "upgrade_node", "upgrades.json: $", errors, [])
	expect_eq(errors, PackedStringArray(), "the real node is valid")
	for bad in [null, {"x": 1}, {"x": "left", "y": 2}, {"x": 1, "y": 2, "z": 3}]:
		if bad == null:
			node.erase("at")
		else:
			node["at"] = bad
		errors = []
		schema.validate_def(node, "upgrade_node", "upgrades.json: $", errors, [])
		expect_true(errors.size() >= 1, "rejected: " + str(bad))


# ------------------------------------------------------------------ the tabs

func test_the_tabs_are_hero_archer_post_and_keep_and_opening_lands_on_the_hero() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	expect_eq(page.tab_names(), PackedStringArray(["Hero", "Archer Post", "Keep"]))
	expect_eq(page.get_node("%Tabs").get_child_count(), 3)
	expect_eq(page._tab, "Hero")
	expect_true(_in_view(page, "flare_boots") and _in_view(page, "flare_inferno"), "the Hero section is on show")
	expect_false(_in_view(page, "post_timbers"), "the other sections are out of view")
	main.free()


func test_each_tab_moves_the_view_to_its_sections_at_real_size() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var expected := {
		"Hero": ["flare_boots", "flare_inferno", "flare_twin"],
		"Archer Post": ["post_timbers", "post_rate", "post_piercing", "post_storm"],
		"Keep": ["keep_walls_1", "keep_walls_5", "keep_beam_3", "tithe_1", "tithe_6"],
	}
	for label in expected:
		page._tab_buttons[label].pressed.emit()
		await tree.process_frame
		expect_eq(page._tab, label)
		expect_eq(page.get_node("%Web").scale.x, 1.0, "%s fits at real size, so text stays readable" % label)
		for id in expected[label]:
			expect_true(_in_view(page, id), "%s: %s is in view" % [label, id])
		for other in expected:
			if other != label:
				expect_false(_in_view(page, expected[other][0]), "%s: %s is not" % [label, expected[other][0]])
	main.free()


func test_the_hero_tab_goes_when_the_profile_plays_another_hero() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	main.get_node("Profile").select_pillar("tideblade")
	expect_eq(page.tab_names(), PackedStringArray(["Archer Post", "Keep"]))
	expect_eq(page._tab_buttons.keys(), ["Archer Post", "Keep"])
	expect_eq(page._tab, "Archer Post", "the view moves off a tab that is gone")
	main.free()


# ------------------------------------------------------------------ pan and zoom

func test_zoom_stays_between_its_limits_and_keeps_the_point_under_the_pointer() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var point := Vector2(500, 200)
	var before: Vector2 = (point - web.position) / web.scale.x
	page.zoom_by(0.9, point)
	expect_true(web.scale.x < 1.0, "zoomed out")
	expect_true(((point - web.position) / web.scale.x).is_equal_approx(before), "the world point under the pointer stays put")
	for i in 30:
		page.zoom_by(1.15)
	expect_eq(web.scale.x, page.ZOOM_MAX, "capped in")
	for i in 60:
		page.zoom_by(1.0 / 1.15)
	expect_eq(web.scale.x, page.ZOOM_MIN, "capped out")
	main.free()


func test_dragging_the_background_pans_and_the_wheel_zooms() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var view: Control = page.get_node("%View")
	var start := web.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	page._on_view_input(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(-60, 25)
	page._on_view_input(move)
	expect_eq(web.position, start + Vector2(-60, 25), "moved with the drag")
	press.pressed = false
	page._on_view_input(press)
	page._on_view_input(move)
	expect_eq(web.position, start + Vector2(-60, 25), "and not after the button is let go")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = view.size * 0.5
	page._on_view_input(wheel)
	expect_true(web.scale.x > 1.0, "wheel up zooms in")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	page._on_view_input(wheel)
	page._on_view_input(wheel)
	expect_true(web.scale.x < 1.0, "wheel down zooms out")
	main.free()


func test_the_web_cannot_be_panned_out_of_sight() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	page._on_view_input(press)
	for direction in [Vector2(-9000, 0), Vector2(18000, 0), Vector2(0, -9000), Vector2(0, 18000)]:
		var move := InputEventMouseMotion.new()
		move.relative = direction
		page._on_view_input(move)
		var all := Rect2()
		var found := false
		for id in page._node_buttons:
			var rect: Rect2 = page._node_buttons[id].get_global_rect()
			all = rect if not found else all.merge(rect)
			found = true
		var shown := all.intersection(_view_rect(page))
		expect_true(shown.size.x >= 60.0 and shown.size.y >= 60.0, "a good part of the web is still in view after a pan of %s (%s)" % [direction, shown.size])
	main.free()


# ------------------------------------------------------------------ the tree itself

func test_every_node_is_on_the_web_and_buying_and_respec_work_from_it() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var profile: HoldfastProfile = main.get_node("Profile")
	expect_eq(page._node_buttons.size(), NODE_COUNT)
	for id in HoldfastContent.base()["upgrade_nodes"]:
		expect_true(page._node_buttons.has(id), id)
		expect_eq(page._node_buttons[id].get_parent().get_parent(), page.get_node("%Web"), "%s is a child of the web" % id)
	profile.bank_run({"gold": 500, "outcome": "lost", "level": "outpost"})
	page._node_buttons["flare_focus"].pressed.emit()
	expect_true("flare_focus" in profile.get_upgrades(), "buying works")
	expect_eq(page._node_buttons["flare_focus"].text, "Steady aim (bought)")
	page.get_node("%RespecButton").pressed.emit()
	expect_true(profile.get_upgrades().is_empty(), "respec works")
	main.free()


func test_the_hero_pages_tree_link_opens_the_hero_tab_and_the_map_keeps_the_last_one() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	page._tab_buttons["Keep"].pressed.emit()
	await tree.process_frame
	expect_eq(page._tab, "Keep")
	page.get_node("%BackButton").pressed.emit()
	main.hero_page.get_node("%TreeButton").pressed.emit()
	await tree.process_frame
	expect_true(page.visible, "the tree is open")
	expect_eq(page._tab, "Hero", "from the Hero page it opens on the Hero tab")
	expect_true(_in_view(page, "flare_boots"), "and shows it")
	page.show_tab("Nowhere")
	expect_eq(page._tab, "Hero", "a tab that does not exist changes nothing")
	main.free()
