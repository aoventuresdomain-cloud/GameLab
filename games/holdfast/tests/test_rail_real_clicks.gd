extends KitTestCase
## HF-M2-85 (F-194): the left rail marks the screen you are on after any run of real clicks between
## Map, Tree, Hero, Squad and Menu, and when you come back to a screen you visited before. Every step is a
## real mouse press and release on the tab, never a helper.

const Main := preload("res://scenes/main.tscn")
const HUBS := {"Map": "journey", "Tree": "keep_screen", "Hero": "hero_page", "Squad": "recruits_page", "Menu": "menu"}


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	main.get_node("Profile").save_path = "user://rail_real_clicks.sav"
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["gold"] = 100000
	profile.hire(0)
	profile.changed.emit()
	main.call("_show", main.Screen.MAP)
	return main


func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


## A real left click on `tab` of the rail of the screen that is up.
func _click(main: Node, from: String, tab: String) -> void:
	var button: Button = main.get(HUBS[from]).rail.tab(tab)
	var at := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		tree.root.push_input(click)
	await _settle()


func _up(main: Node) -> Array:
	var out := []
	for tab in HUBS:
		if main.get(HUBS[tab]).visible:
			out.append(tab)
	return out


## The screen that is up shows its own tab and no other as in use, and so does every rail waiting behind it.
func _expect_every_rail_right(main: Node, where: String) -> void:
	expect_eq(_up(main), [where], "%s is the screen that is up" % where)
	for screen_tab in HUBS:
		var rail: HubRail = main.get(HUBS[screen_tab]).rail
		var lit := []
		for tab in HUBS:
			if rail.tab(tab).button_pressed:
				lit.append(tab)
		expect_eq(lit, [screen_tab], "the %s page's rail marks only %s after reaching %s" % [screen_tab, screen_tab, where])


func test_map_to_tree_and_back_marks_map() -> void:
	var main := _main()
	await _settle()
	await _click(main, "Map", "Tree")
	_expect_every_rail_right(main, "Tree")
	await _click(main, "Tree", "Map")
	_expect_every_rail_right(main, "Map")
	main.free()


func test_every_tab_to_every_other_by_real_clicks_and_back_again() -> void:
	var main := _main()
	await _settle()
	for from in HUBS:
		for to in HUBS:
			if from == to:
				continue
			await _go(main, from)
			await _click(main, from, to)
			_expect_every_rail_right(main, to)
			await _click(main, to, from)
			_expect_every_rail_right(main, from)
	main.free()


func test_a_long_walk_round_the_tabs_twice() -> void:
	var main := _main()
	await _settle()
	var at := "Map"
	for tab in ["Tree", "Map", "Hero", "Menu", "Map", "Tree", "Hero", "Squad", "Hero", "Menu", "Tree", "Squad", "Map", "Menu", "Hero", "Tree", "Map"]:
		await _click(main, at, tab)
		at = tab
		_expect_every_rail_right(main, at)
	main.free()


func test_clicking_the_tab_you_are_on_changes_nothing() -> void:
	var main := _main()
	await _settle()
	await _click(main, "Map", "Map")
	_expect_every_rail_right(main, "Map")
	await _click(main, "Map", "Hero")
	await _click(main, "Hero", "Hero")
	_expect_every_rail_right(main, "Hero")
	main.free()


## Gets to `tab` by real clicks from wherever the walk is (always by way of the Map's own tab).
func _go(main: Node, tab: String) -> void:
	var now: String = _up(main)[0]
	if now != tab:
		await _click(main, now, tab)
