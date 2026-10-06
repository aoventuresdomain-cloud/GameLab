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
	var start: Control = _main.start_screen
	var hud: Control = _main.hud
	var summary: Control = _main.summary
	_check(start.visible and not hud.visible and not summary.visible, "opens on the start screen")

	await _click(start.get_node("%PlayButton"))
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
	print("layout: readable and on screen at 1280x720 and 1920x1080")
	_source.step(1000.0) # end the run
	_main.summary.show_summary({"gold_earned": 9_999_999, "waves_cleared": 99, "total_waves": 99, "keep_fell": true})
	var hud: Control = _main.hud
	hud._on_gold_changed(9_999_999)
	hud._on_keep_health_changed(99_999, 99_999)
	hud._on_wave_changed(99, 99)
	for window in [BASE_SIZE, Vector2i(1920, 1080)]:
		root.size = window
		await process_frame
		var scale := float(window.y) / BASE_SIZE.y
		var view := root.get_visible_rect()
		_check(Vector2i(view.size) == BASE_SIZE, "%dx%d window shows the whole 1280x720 layout" % [window.x, window.y])
		for screen in [_main.start_screen, hud, _main.summary]:
			screen.visible = true
			await process_frame
			for control in _texts(screen):
				var name := "%dp %s/%s" % [window.y, screen.name, screen.get_path_to(control)]
				var px := roundi(control.get_theme_font_size("font_size") * scale)
				_check(px >= MIN_FONT_PX, "%s text is %dpx on screen" % [name, px])
				_check(view.encloses(control.get_global_rect()), "%s fits on screen" % name)
				_check(control.size.x + 0.5 >= control.get_minimum_size().x, "%s is not clipped" % name)
			screen.visible = false


func _texts(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if (child is Label or child is Button) and child.is_visible_in_tree():
			out.append(child)
		out.append_array(_texts(child))
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
