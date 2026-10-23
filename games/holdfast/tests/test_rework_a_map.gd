extends KitTestCase
## The journey map's Hero figure is itself tappable (F-054) and the level names stay clear of the
## glow ring, the path and each other (F-055).

const Main := preload("res://scenes/main.tscn")


func _map() -> Array:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	main.journey.visible = true
	await tree.process_frame
	await tree.process_frame
	return [main, main.journey]


func test_tapping_the_drawn_hero_opens_the_hero_page() -> void:
	var made := await _map()
	var main: Node = made[0]
	var map: Control = made[1]
	var figure: Button = map._hero_figure
	expect_true(Rect2(figure.position, figure.size).has_point(map._hero_at()), "the button sits on the drawn figure")
	expect_true(figure.is_visible_in_tree() and not figure.disabled)
	figure.pressed.emit()
	expect_true(main.hero_page.visible and not map.visible, "the Hero page opens")
	main.free()


func test_the_figure_button_does_not_cover_a_level_node() -> void:
	var made := await _map()
	var main: Node = made[0]
	var map: Control = made[1]
	var figure := Rect2(map._hero_figure.position, map._hero_figure.size)
	for id in map._ids:
		expect_false(figure.intersects(Rect2(map._buttons[id].position, map._buttons[id].size)), "%s is not under the figure" % id)
	main.free()


func test_level_names_clear_the_glow_ring_the_path_and_each_other() -> void:
	var made := await _map()
	var main: Node = made[0]
	var map: Control = made[1]
	var path: PackedVector2Array = map.path_points()
	var rects := {}
	for i in map._ids.size():
		var id: String = map._ids[i]
		var label: Label = map._names[id]
		var rect := Rect2(label.position, label.size)
		rects[id] = rect
		var node: Vector2 = map._node_at(i, map._ids.size())
		expect_true(rect.position.y >= node.y + map.NODE_RADIUS + 14.0, "%s: name starts below the glow ring" % id)
		expect_true(Rect2(Vector2.ZERO, map._map.size).encloses(rect), "%s: name is on the map" % id)
		for point in path:
			expect_false(rect.has_point(point), "%s: the path does not run through the name" % id)
	for a in rects:
		for b in rects:
			if a < b:
				expect_false(rects[a].intersects(rects[b]), "%s and %s do not overlap" % [a, b])
	main.free()
