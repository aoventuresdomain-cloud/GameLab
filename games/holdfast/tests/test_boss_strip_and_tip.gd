extends KitTestCase
## Quick fix 14c-b (from QA's pass on HF-M2-79): the boss bar has a strip of its own under the field, the
## exposed line above the field is gone (the bar says it), and Escape, Start or B get a pad or keyboard
## player out of the first-run "special is ready" prompt by way of the pause card.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 600)]


func _run() -> Dictionary:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	main.call("_start_run")
	main.hud.set_process(false)
	return {"main": main, "hud": main.hud, "source": main.get_node("RunSource")}


func _boss(rules: HoldfastRules, at: Vector2, exposed := 0.0) -> HoldfastRules.Enemy:
	var data: Dictionary = HoldfastContent.base()["enemies"]["fog_warden"]
	var enemy := HoldfastRules.Enemy.new()
	enemy.type = "fog_warden"
	enemy.position = at
	enemy.health = 400.0
	enemy.max_health = 500.0
	enemy.radius = float(data["radius"])
	enemy.speed = 0.0
	enemy.required_ability = str(data.get("required_ability", ""))
	enemy.exposed_left = exposed
	rules.enemies.append(enemy)
	return enemy


func _press(event: InputEvent) -> void:
	tree.root.push_input(event)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _pad(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


# ------------------------------------------------------------------ the note above the field

func test_only_the_shrouded_note_shows_above_the_field_and_the_bar_says_exposed() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var rules: HoldfastRules = run["source"].get_rules()
	var boss := _boss(rules, Vector2(300, 300))
	hud._refresh_hero()
	expect_eq(hud.get_node("%PostsNote").text, "Fog Warden shrouded: use your special", "shrouded: what lifts it")
	boss.exposed_left = 4.0
	hud._refresh_hero()
	expect_false(hud.get_node("%PostsNote").text.to_lower().contains("exposed"), "exposed: no line above the field")
	expect_eq(hud.get_node("%BossState").text, "Exposed: 4 s", "the bar says it")
	run["main"].free()


# ------------------------------------------------------------------ the strip

func test_the_boss_bar_sits_below_the_field_and_clear_of_its_border() -> void:
	var run := _run()
	var main: Node = run["main"]
	var hud: Control = run["hud"]
	var world: Node2D = main.get_node("World")
	var rules: HoldfastRules = run["source"].get_rules()
	var arena: Vector2 = rules.arena_size()
	# A boss at the bottom edge of the field, where it used to run under the bar.
	_boss(rules, Vector2(0.0, arena.y * 0.5 - 20.0))
	hud._refresh_hero()
	var window_before := tree.root.size
	for window in WINDOWS:
		tree.root.size = window
		await tree.process_frame
		world._process(0.0)
		var to_window := tree.root.get_final_transform()
		var bar: Rect2 = hud.get_node("%BossBar").get_global_rect()
		var border: float = (to_window * world.world_to_screen(Vector2(0.0, arena.y * 0.5))).y
		expect_true(hud.get_node("%BossBar").visible, "%s: the bar is up" % window)
		expect_true(border + 6.0 <= (to_window * bar.position).y, "%s: the field's border (y %.0f) is clear of the bar (y %.0f)" % [window, border, (to_window * bar.position).y])
		expect_true(tree.root.get_visible_rect().encloses(bar), "%s: the bar is on screen" % window)
		var name_box: Rect2 = hud.get_node("%BossName").get_global_rect()
		var state_box: Rect2 = hud.get_node("%BossState").get_global_rect()
		var health_box: Rect2 = hud.get_node("%BossHealth").get_global_rect()
		expect_true(name_box.end.x + 6.0 <= health_box.position.x and health_box.end.x + 6.0 <= state_box.position.x, "%s: name, bar and state sit side by side with room" % window)
	tree.root.size = window_before
	main.free()


# ------------------------------------------------------------------ the first-run prompt

func _teaching() -> Dictionary:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.teach_special = true
	source.level_id = "outpost"
	main.call("_show", main.Screen.RUN)
	source.start_run()
	source.step(120.0)
	return {"main": main, "source": source}


func test_escape_start_and_b_open_and_close_the_pause_card_while_the_prompt_waits() -> void:
	for event in [_key(KEY_ESCAPE), _pad(JOY_BUTTON_START), _pad(JOY_BUTTON_B)]:
		var run := _teaching()
		var source: HoldfastRunSource = run["source"]
		expect_true(source.is_teaching_special(), "stopped at the prompt")
		expect_false(source.is_paused())
		_press(event)
		expect_true(source.is_paused(), "%s opens the pause card" % event.as_text())
		_press(event)
		expect_false(source.is_paused(), "and closes it")
		expect_true(source.is_teaching_special(), "the prompt is still waiting for the special")
		run["main"].free()


func test_a_click_on_the_pause_card_does_not_answer_the_prompt() -> void:
	var run := _teaching()
	var source: HoldfastRunSource = run["source"]
	_press(_key(KEY_ESCAPE))
	expect_true(source.is_paused())
	var asked := [0]
	run["main"].hud.special_requested.connect(func() -> void: asked[0] += 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_press(click)
	expect_eq(asked[0], 0, "a click while paused is the card's, not the special's")
	run["main"].free()
