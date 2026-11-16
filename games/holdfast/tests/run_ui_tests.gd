extends SceneTree
## HF-M1-04 run UI tests. Run headless from the repository root:
##   godot --headless --path games/holdfast --script res://tests/run_ui_tests.gd
## Exits 1 if any check fails.

const Main = preload("res://scenes/main.tscn")
## The UI is tested on the stub run source, so these checks cover the UI and not
## the level's balance (Head of Engineering OK, board Test changes, 2026-10-06).
## The real rules are covered by tests/test_playable_level.gd and the exported
## builds' autoplay smoke tests.
const StubRunSource = preload("res://scripts/stub_run_source.gd")
const BASE_SIZE := Vector2i(1280, 720)
const MIN_FONT_PX := 20 # on-screen pixels
const MIN_TREE_FONT_PX := 12 # the skill tree's node prices and names, as the radial web mock-up has them
## The CEO's rule (16 Nov): icons, titles and labels never overlap and keep this far apart, in pixels
## of the 1280x720 layout (the same layout at every window size).
const MIN_CLEAR_PX := 6.0
## Every button is at least this big, each way, in pixels of the 1280x720 layout.
const MIN_BUTTON_PX := 44
## A spread over every section of the tree, bought in an order the rules allow.
const MID_GAME_NODES := ["castle_slot_2", "castle_slot_3", "castle_archer_2", "post_timbers", "post_drills", "post_sight", "post_rate", "post_mend", "flare_boots", "flare_hide", "flare_focus", "keep_walls_1", "keep_walls_2", "keep_beam_1", "tithe_1", "gate_mage", "mage_sight"]

var _failures := 0
var _main: Node
var _source: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_ui_is_read_only()
	root.size = BASE_SIZE # headless windows start at 64x64
	_main = Main.instantiate()
	_source = _main.get_node("RunSource")
	_source.set_script(StubRunSource)
	_source.auto_step = false
	root.add_child(_main)
	await process_frame
	await _test_flow_with_mouse()
	await _test_readable_layout()
	print("run UI tests: %s" % ("FAILED (%d)" % _failures if _failures else "passed"))
	quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _test_flow_with_mouse() -> void:
	print("flow: start -> run -> summary -> play again, mouse only")
	var home: Control = _main.home
	var start: Control = _main.journey
	var hud: Control = _main.hud
	var summary: Control = _main.summary
	_check(home.visible and not start.visible and not hud.visible and not summary.visible, "opens on the home screen")
	await _click(home.get_node("%NewGameButton"))
	_check(start.visible and not home.visible, "New game opens the journey map")

	# Level 0 has its own post, so it starts at once; the stub run does not bank a result, so the
	# profile is told Level 0 was won and the two guided buys are clicked on the map.
	await _click(start._buttons["first_watch"])
	_check(hud.visible and not start.visible and _source.is_running(), "Tapping Level 0 starts it with no planning")
	_source.step(1000.0)
	await process_frame
	_check(summary.visible, "Level 0 ends on the summary")
	await _click(summary.get_node("%MapButton"))
	_check(start.visible and not start.get_node("%Guide").visible, "the map has no guide until Level 0 is won")
	_main.get_node("Profile").bank_run({"outcome": "won", "level": "first_watch", "gold": 0})
	await process_frame
	_check(start.get_node("%Guide").visible and start._buttons["outpost"].disabled, "after Level 0 the guide asks for the First Slot and Level 1 waits")
	await _click(start.get_node("%GuideButton"))
	await _click(start.get_node("%GuideButton"))
	_check(start.get_node("%Guide").visible and start.get_node("%GuideButton").text == "Start" and not start._buttons["outpost"].disabled, "two clicks buy the First Slot and the first Archer Post and open Level 1; the strip offers Start")
	_check(start.visible and not _source.is_running(), "and nothing starts by itself")
	await _click(start.get_node("%GuideButton"))
	_check(hud.visible and _source.is_running() and _main.get_node("Profile").data["stand_done"], "the Start click begins the stand, the short fight on the post just bought")
	_source.step(1000.0)
	await process_frame
	_check(summary.visible and not summary.get_node("%Reward").visible, "the stand ends on the summary and pays no second Level 0 reward")
	await _click(summary.get_node("%MapButton"))
	_check(start.visible, "and the map is back")

	await _click(start._buttons["outpost"])
	_check(_main.planning.visible and not start.visible, "Tapping the first level opens the planning screen (it has Archer Post sites)")
	await _click(_main.planning.get_node("%AutoButton"))
	await _click(_main.planning.get_node("%StartButton"))
	_check(hud.visible and not start.visible, "Play shows the HUD")
	_check(_source.is_running(), "Play starts a run")

	_source.step(3.0)
	_check_hud_matches_source(hud)
	var gold_before: int = _source.get_gold()
	_source.step(7.0)
	_check(_source.get_gold() > gold_before, "gold rises during the run")
	_check(_source.get_wave() >= 2, "wave advances during the run")
	_check_hud_matches_source(hud)

	var result := {}
	_source.run_ended.connect(func(s): result.merge(s), CONNECT_ONE_SHOT)
	for i in 600:
		if not _source.is_running():
			break
		_source.step(0.5)
	_check(not _source.is_running(), "run ends")
	_check(summary.visible and not hud.visible, "run end shows the summary")
	_check(summary.get_node("%GoldValue").text == hud.format_number(result.get("gold_earned", -1)), "summary shows gold earned")
	_check(summary.get_node("%WavesValue").text == "%d / %d" % [result.get("waves_cleared", -1), result.get("total_waves", -1)], "summary shows waves cleared")

	root.size = Vector2i(1920, 1080) # the second run is clicked at 1080p
	await process_frame
	await _click(summary.get_node("%PlayAgainButton"))
	_check(_main.planning.visible and not summary.visible, "Play again opens the planning screen")
	await _click(_main.planning.get_node("%StartButton"))
	_check(hud.visible and not summary.visible, "Play again shows the HUD")
	_check(_source.is_running() and _source.get_gold() == 0, "Play again starts a fresh run")
	_check(hud.get_node("%GoldValue").text == "0", "HUD resets for the new run")


func _check_hud_matches_source(hud: Control) -> void:
	_check(hud.get_node("%GoldValue").text == hud.format_number(_source.get_gold()), "HUD gold is live")
	_check(hud.get_node("%WaveValue").text == "%d / %d" % [_source.get_wave(), _source.get_total_waves()], "HUD wave is live")
	_check(int(hud.get_node("%KeepBar").value) == _source.get_keep_health(), "HUD keep health is live")


## Clicks a control the way a player would: mouse move, press and release at its
## centre, in window pixels (so the 1080p click goes through the UI scaling).
func _click(control: Control) -> void:
	var at := root.get_final_transform() * control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	root.push_input(move)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		root.push_input(click)
		await process_frame


## The window scales the 1280x720 base (canvas_items stretch), so the layout is
## the same at 1920x1080, drawn 1.5x larger. Checked with worst-case numbers.
func _test_readable_layout() -> void:
	print("layout: readable, on screen and clear of each other at 1280x720, 960x540 and 1920x1080")
	_source.step(1000.0) # end the run
	# The map at its fullest: Level 0 won, and the guide asks for a star that is not there yet.
	_main.get_node("Profile").new_game()
	_main.get_node("Profile").data["levels_won"].append("first_watch")
	# The Hero page at its fullest: all twelve pieces in the bag, one worn in every slot.
	_main.get_node("Profile").data["gear"]["owned"] = HoldfastContent.base()["gear_items"].keys()
	for id in ["gull_feather_fletching", "beacon_visor", "oilskin_vest", "kelp_sandals", "lamp_oil_flask"]:
		_main.get_node("Profile").wear_gear(id)
	# The Recruits page at its fullest: a roster of twelve with long names, two skill picks waiting.
	var profile: Node = _main.get_node("Profile")
	profile.data["gold"] = 1_000_000
	for i in 10:
		profile.hire(0)
		profile.data["recruits"]["hired"] = []
		profile.data["recruits"]["round"] += 1
	for each in profile.data["recruits"]["roster"]:
		each["name"] = "Longest Name Ok"
	profile.data["recruits"]["roster"][0]["xp"] = 5
	profile.data["recruits"]["roster"][1]["xp"] = 5
	profile.data["recruits"]["roster"][2]["xp"] = 5
	# The skill tree at a busy mid-game: many nodes on show, so the names must find room or go.
	ThroughLevelZero.apply_castle(profile)
	for id in MID_GAME_NODES:
		profile.data["stars"]["first_watch"] = int(profile.data["stars"]["first_watch"]) + 6
		var bought := HoldfastMeta.buy(HoldfastContent.base(), profile.data, id)
		_check(bought["ok"], "%s can be bought for the busy tree (%s)" % [id, bought.get("reason", "")])
		profile.data = bought["profile"]
	profile.changed.emit()
	_main.summary.show_summary({"gold_earned": 9_999_999, "waves_cleared": 99, "total_waves": 99, "keep_fell": true})
	var hud: Control = _main.hud
	hud._on_gold_changed(9_999_999)
	hud._on_keep_health_changed(99_999, 99_999)
	hud._on_wave_changed(99, 99)
	for window in [BASE_SIZE, Vector2i(960, 540), Vector2i(1920, 1080)]:
		root.size = window
		await process_frame
		var scale := float(window.y) / BASE_SIZE.y
		var view := root.get_visible_rect()
		_check(Vector2i(view.size) == BASE_SIZE, "%dx%d window shows the whole 1280x720 layout" % [window.x, window.y])
		_main.planning.open("shingle_beach", ["spot_2", "spot_1", "mage:spot_3"], false, HoldfastContent.base()["castle_rules"]["castle"]["spots"], 8, 2)
		_main.planning.set_blessings(["steady_flame", "second_wind", "tides_gift"])
		_main.planning.set_squad(["Longest Name Ok", "Longest Name Ok", "Longest Name Ok", "Longest Name Ok"])
		hud.get_node("%PostsNote").text = "Posts: North Gate, South Gate"
		hud.get_node("%PostsNote").visible = true
		for screen in [_main.home, _main.journey, _main.hero_page, _main.recruits_page, _main.menu, _main.keep_screen, hud, _main.summary, _main.planning]:
			await _check_layout(screen, window, scale, view)
		hud.get_node("%PostsNote").text = "Fog Warden shrouded: use your special"
		await _check_layout(hud, window, scale, view)
		hud.get_node("%PostsNote").visible = false
		# The summary after a win, with Next level and the Upgrade screen as well.
		_main.summary.show_summary({"gold_earned": 9_999_999, "waves_cleared": 99, "total_waves": 99, "keep_fell": false, "stars_paid": 2, "reward_gold": 150, "stars_note": "Stars buy slots and towers. Gold buys upgrades.", "recruit_changes": [{"name": "Longest Name Ok", "to": 5, "trait": "steady"}, {"name": "Longest Name Ok", "to": 3, "trait": ""}, {"name": "Longest Name Ok", "class": "lookout", "to": 1, "trait": "", "joined": true}]}, "shingle_beach")
		_main.summary.set_picks(profile.get_pending_picks())
		await _check_layout(_main.summary, window, scale, view)
		_main.summary.show_summary({"gold_earned": 9_999_999, "waves_cleared": 99, "total_waves": 99, "keep_fell": true})


func _check_layout(screen: Control, window: Vector2i, scale: float, view: Rect2) -> void:
	screen.visible = true
	await process_frame
	var web: Control = screen.get_node_or_null("%Web")
	for control in _texts(screen, web):
		var name := "%dp %s/%s" % [window.y, screen.name, screen.get_path_to(control)]
		var px := roundi(control.get_theme_font_size("font_size") * scale)
		# The smallest window is checked for room, not for type size (it is the same layout, drawn smaller).
		_check(px >= MIN_FONT_PX or scale < 1.0, "%s text is %dpx on screen" % [name, px])
		# Inside a scrolling page, a control must fit across the screen; down it, the page scrolls.
		var scroll := _scroll_of(control)
		var rect: Rect2 = control.get_global_rect()
		_check(view.encloses(rect) if scroll == null else (view.encloses(scroll.get_global_rect()) and rect.position.x >= view.position.x and rect.end.x <= view.end.x), "%s fits on screen" % name)
		_check(control.size.x + 0.5 >= control.get_minimum_size().x, "%s is not clipped" % name)
		if control is Button:
			_check(control.size.x >= MIN_BUTTON_PX - 0.5 and control.size.y >= MIN_BUTTON_PX - 0.5, "%s is at least %dpx each way (%s)" % [name, MIN_BUTTON_PX, control.size])
	_check_clear(_items(screen, web), "%dp %s" % [window.y, screen.name])
	# A pan-and-zoom web shows one tab at a time: each tab, as the jump tab leaves it, must hold
	# all its nodes inside the view at a readable size.
	if web != null:
		for tab in screen.tab_names():
			screen.show_tab(tab)
			await process_frame
			for id in screen._node_buttons:
				var node: Button = screen._node_buttons[id]
				if screen._tab_rect(tab).encloses(Rect2(node.position, node.size)) and node.get_parent().visible:
					var name := "%dp %s tab %s/%s" % [window.y, screen.name, tab, id]
					var px := roundi(node.get_theme_font_size("font_size") * web.scale.x * scale)
					_check(px >= MIN_TREE_FONT_PX or scale < 1.0, "%s text is %dpx on screen" % [name, px])
					var label: Label = screen._labels[id]
					var label_px := roundi(label.get_theme_font_size("font_size") * label.scale.x * web.scale.x * scale)
					_check(label_px >= MIN_TREE_FONT_PX or scale < 1.0 or web.scale.x < screen.LABELS_MIN_ZOOM, "%s name is %dpx on screen" % [name, label_px])
					_check(screen.get_node("%View").get_global_rect().encloses(node.get_global_rect()), "%s fits in the view" % name)
					_check(node.size.x + 0.5 >= node.get_minimum_size().x, "%s is not clipped" % name)
			var on_show: Array = []
			var view_rect: Rect2 = screen.get_node("%View").get_global_rect()
			for id in screen._node_buttons:
				var node: Button = screen._node_buttons[id]
				if node.visible and node.get_parent().visible and view_rect.intersects(_screen_rect(node)):
					on_show.append(node)
					var label: Label = screen._labels[id]
					if label.visible and label.self_modulate.a > 0.0:
						on_show.append(label)
			for heading in screen._headings.values():
				if heading.visible and heading.get_parent().visible and view_rect.encloses(_screen_rect(heading)):
					on_show.append(heading)
			_check_clear(on_show, "%dp %s tab %s" % [window.y, screen.name, tab], screen._node_buttons.values())
	screen.visible = false


## The ScrollContainer a control sits in, if any.
func _scroll_of(control: Node) -> ScrollContainer:
	var up := control.get_parent()
	while up != null:
		if up is ScrollContainer:
			return up
		up = up.get_parent()
	return null


## What a player reads or presses on a screen: its names, buttons and icons that are drawn, apart
## from what sits inside a button (its own text) and `skip` (a web, checked on its own).
func _items(node: Node, skip: Node = null) -> Array:
	var out := []
	for child in node.get_children():
		if child == skip:
			continue
		var drawn: bool = child is Control and child.is_visible_in_tree() and child.modulate.a > 0.05 and child.self_modulate.a > 0.05
		if drawn and (child is Button or child is TextureRect or (child is Label and child.text != "")):
			out.append(child)
		if not child is Button:
			out.append_array(_items(child, skip))
	return out


## Where a control really is on screen, whatever its scale.
func _screen_rect(control: Control) -> Rect2:
	var rect := control.get_global_transform() * Rect2(Vector2.ZERO, control.size)
	if control is Label and (control as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and not control.clip_text:
		# Only the text itself takes room, not the empty space of a label stretched by its row.
		var label := control as Label
		var text_size := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
		var width := minf(text_size.x * control.get_global_transform().get_scale().x, rect.size.x)
		var left := rect.position.x
		if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			left += (rect.size.x - width) * 0.5
		elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			left += rect.size.x - width
		rect = Rect2(left, rect.position.y, width, rect.size.y)
	return rect


## Fails for any two of `items` that overlap or come nearer than MIN_CLEAR_PX on screen. The
## `round_items` (a web's round nodes) count as circles, not as the squares that hold them.
func _check_clear(items: Array, where: String, round_items: Array = []) -> void:
	var rects := items.map(func(item: Control) -> Rect2: return _screen_rect(item))
	var bad := 0
	for i in items.size():
		for j in range(i + 1, items.size()):
			if items[i].is_ancestor_of(items[j]) or items[j].is_ancestor_of(items[i]):
				continue
			var gap := _gap(rects[i], items[i] in round_items, rects[j], items[j] in round_items)
			if gap < MIN_CLEAR_PX - 0.01:
				bad += 1
				if bad <= 6:
					_check(false, "%s: %s and %s are %.1fpx apart (need %.0f)" % [where, _describe(items[i]), _describe(items[j]), gap, MIN_CLEAR_PX])
	_check(bad == 0, "%s: icons, titles and labels are clear of each other" % where)


## The room between two shapes (a rect, or the circle in a rect): negative when they overlap.
func _gap(a: Rect2, a_round: bool, b: Rect2, b_round: bool) -> float:
	if a_round and b_round:
		return a.get_center().distance_to(b.get_center()) - (minf(a.size.x, a.size.y) + minf(b.size.x, b.size.y)) * 0.5
	if a_round or b_round:
		var circle := a if a_round else b
		var box := b if a_round else a
		var nearest := Vector2(clampf(circle.get_center().x, box.position.x, box.end.x), clampf(circle.get_center().y, box.position.y, box.end.y))
		return circle.get_center().distance_to(nearest) - minf(circle.size.x, circle.size.y) * 0.5
	var dx := maxf(a.position.x - b.end.x, b.position.x - a.end.x)
	var dy := maxf(a.position.y - b.end.y, b.position.y - a.end.y)
	return Vector2(dx, dy).length() if dx > 0.0 and dy > 0.0 else maxf(dx, dy)


func _describe(control: Control) -> String:
	var text: String = control.text if "text" in control else control.name
	return "%s '%s'" % [control.name, text.substr(0, 24)]


func _texts(node: Node, skip: Node = null) -> Array:
	var out := []
	for child in node.get_children():
		if child == skip:
			continue
		if (child is Label or child is Button) and child.is_visible_in_tree():
			out.append(child)
		out.append_array(_texts(child, skip))
	return out


## Done when: the UI reads state only through signals or read-only accessors.
func _test_ui_is_read_only() -> void:
	print("read-only: UI scripts touch the run source only through its signals and get_/is_ accessors")
	var allowed := ["gold_changed", "keep_health_changed", "wave_changed", "run_started", "run_ended"]
	var dir := "res://scripts/ui/"
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd") or file == "run_state_source.gd":
			continue
		var text := FileAccess.get_file_as_string(dir + file)
		var bad := []
		var re := RegEx.create_from_string("\\b_?source\\.(\\w+)")
		for m in re.search_all(text):
			var member := m.get_string(1)
			if not (member.begins_with("get_") or member.begins_with("is_") or member in allowed):
				bad.append(member)
		_check(bad.is_empty(), "%s uses only reads%s" % [file, "" if bad.is_empty() else " (found %s)" % ", ".join(bad)])
		_check(not text.contains("start_run"), "%s never starts a run itself" % file)
