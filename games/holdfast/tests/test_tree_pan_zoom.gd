extends KitTestCase
## Tree pan and zoom (HF-M2-33): a drag pans from anywhere, over a node included, and a click
## without movement still buys; the wheel and a trackpad zoom at the pointer between the limits.
## The page-level scroll and browser zoom suppression is checked in a real browser, not here.

const Main := preload("res://scenes/main.tscn")


func _tree_page() -> Array:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	ThroughLevelZero.apply_castle(main.get_node("Profile"))
	main.get_node("Profile").data["gold"] = 5000
	main.get_node("Profile").changed.emit()
	main.journey.get_node("%TreeButton").pressed.emit()
	await tree.process_frame
	await tree.process_frame
	return [main, main.keep_screen]


func _motion(page: Control, relative: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.relative = relative
	page._on_view_input(move)


func _wheel(page: Control, up: bool, at: Vector2, factor := 1.0) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = at
	wheel.factor = factor
	page._on_view_input(wheel)


func test_dragging_from_a_node_pans_the_tree_and_buys_nothing() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var button: Button = page._node_buttons["flare_boots"]
	var start := web.position
	button.button_down.emit()
	_motion(page, Vector2(30, 0))
	_motion(page, Vector2(0, 12))
	expect_eq(web.position, start + Vector2(30, 12), "the drag moved the tree although it began on a node")
	button.button_up.emit()
	button.pressed.emit()
	expect_false("flare_boots" in main.get_node("Profile").get_upgrades(), "and the let-go did not buy it")
	_motion(page, Vector2(50, 50))
	expect_eq(web.position, start + Vector2(30, 12), "the tree stops following once the button is up")
	main.free()


func test_a_click_without_movement_still_buys_and_a_wobble_under_the_threshold_too() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var profile: HoldfastProfile = main.get_node("Profile")
	var start := web.position
	var boots: Button = page._node_buttons["flare_boots"]
	boots.button_down.emit()
	boots.button_up.emit()
	boots.pressed.emit()
	expect_true(page._card.visible and page._card_id == "flare_boots", "a plain click opens its card")
	page._card_buy.pressed.emit()
	expect_true("flare_boots" in profile.get_upgrades(), "a plain click buys")
	var hide: Button = page._node_buttons["flare_hide"]
	hide.button_down.emit()
	_motion(page, Vector2(2, 1))
	_motion(page, Vector2(-1, 2))
	hide.button_up.emit()
	hide.pressed.emit()
	expect_true(page._card.visible and page._card_id == "flare_hide", "a hand that shakes a few pixels still opens the card")
	page._card_buy.pressed.emit()
	expect_true("flare_hide" in profile.get_upgrades(), "a hand that shakes a few pixels still buys")
	expect_eq(web.position, start, "without moving the tree")
	main.free()


func test_a_drag_does_not_leave_the_next_click_unable_to_buy() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var profile: HoldfastProfile = main.get_node("Profile")
	var focus: Button = page._node_buttons["flare_focus"]
	focus.button_down.emit()
	_motion(page, Vector2(80, 0))
	focus.button_up.emit()
	# The pointer left the button before it was let go, so no pressed signal came.
	focus.button_down.emit()
	focus.button_up.emit()
	focus.pressed.emit()
	page._card_buy.pressed.emit()
	expect_true("flare_focus" in profile.get_upgrades(), "the click after a drag buys")
	main.free()


func test_a_drag_on_the_background_still_pans() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var start := web.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	page._on_view_input(press)
	_motion(page, Vector2(-25, 10))
	expect_eq(web.position, start + Vector2(-25, 10))
	main.free()


func test_the_wheel_zooms_at_the_pointer_and_stays_between_the_limits() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var point := Vector2(300, 220)
	var world: Vector2 = (point - web.position) / web.scale.x
	var scale_before := web.scale.x
	_wheel(page, true, point)
	expect_true(web.scale.x > scale_before, "wheel up zooms in")
	expect_true(((point - web.position) / web.scale.x).is_equal_approx(world), "the point under the pointer stays put")
	_wheel(page, false, point)
	expect_near(web.scale.x, scale_before, 0.0001, "wheel down undoes it")
	for i in 60:
		_wheel(page, true, point)
	expect_eq(web.scale.x, page.ZOOM_MAX, "capped in at 2.5x")
	expect_eq(page.ZOOM_MAX, 2.5)
	for i in 120:
		_wheel(page, false, point)
	expect_eq(web.scale.x, page.ZOOM_MIN, "capped out")
	expect_true(page.ZOOM_MIN >= 0.375 and page.ZOOM_MIN <= 0.4, "at about 0.4x")
	main.free()


func test_a_trackpad_scroll_zooms_by_the_fraction_of_a_step_it_sends() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var point := Vector2(300, 220)
	var full := web.scale.x
	_wheel(page, true, point, 1.0)
	var one_step: float = web.scale.x / full
	page.zoom_by(1.0 / page.ZOOM_STEP)
	var from := web.scale.x
	_wheel(page, true, point, 0.25)
	var small: float = web.scale.x / from
	expect_true(small > 1.0 and small < one_step, "a small turn is a small zoom (%s of %s)" % [small, one_step])
	expect_near(small, pow(page.ZOOM_STEP, 0.25), 0.0001)
	main.free()


func test_a_pinch_zooms_and_a_two_finger_scroll_pans() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	var web: Control = page.get_node("%Web")
	var before := web.scale.x
	var pinch := InputEventMagnifyGesture.new()
	pinch.position = Vector2(300, 220)
	pinch.factor = 1.2
	page._on_view_input(pinch)
	expect_near(web.scale.x, before * 1.2, 0.0001)
	var position := web.position
	var scroll := InputEventPanGesture.new()
	scroll.delta = Vector2(2, 1)
	page._on_view_input(scroll)
	expect_eq(web.position, position - Vector2(40, 20), "the tree follows the fingers")
	main.free()


func _fade_of(page: Control, section: String) -> float:
	return page._section_columns[section].modulate.a


func test_the_sections_of_other_tabs_fade_until_the_player_pans_or_zooms() -> void:
	var made := await _tree_page()
	var main: Node = made[0]
	var page: Control = made[1]
	page.show_tab("Castle")
	expect_eq(_fade_of(page, "castle"), 1.0, "the shown tab is clear")
	expect_near(_fade_of(page, "archer_post"), page.OTHER_TAB_ALPHA, 0.001, "the rest are faded")
	_motion(page, Vector2.ZERO)
	expect_near(_fade_of(page, "archer_post"), page.OTHER_TAB_ALPHA, 0.001, "a mouse move alone changes nothing")
	page._panning = true
	_motion(page, Vector2(10, 0))
	expect_eq(_fade_of(page, "archer_post"), 1.0, "panning brings them back")
	page.show_tab("Castle")
	expect_near(_fade_of(page, "archer_post"), page.OTHER_TAB_ALPHA, 0.001, "choosing a tab fades them again")
	_wheel(page, true, Vector2(300, 220))
	expect_eq(_fade_of(page, "archer_post"), 1.0, "so does zooming")
	main.free()
