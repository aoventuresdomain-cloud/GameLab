extends KitTestCase
## HF-M2-79: the in-run HUD frame (Hero health, wave, speed, pause), the special's ready and cooling
## looks, Auto only once Keeper's Habit is owned, the pause panel, and the boss bar.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CLEAR := 6.0


func _run() -> Dictionary:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	main.call("_start_run")
	main.hud.set_process(false)
	return {"main": main, "hud": main.hud, "source": main.get_node("RunSource")}


func _boss(rules: HoldfastRules, exposed := 0.0) -> HoldfastRules.Enemy:
	var data: Dictionary = HoldfastContent.base()["enemies"]["fog_warden"]
	var enemy := HoldfastRules.Enemy.new()
	enemy.type = "fog_warden"
	enemy.position = Vector2(300, 300)
	enemy.health = 400.0
	enemy.max_health = 500.0
	enemy.radius = float(data["radius"])
	enemy.speed = 0.0
	enemy.required_ability = str(data.get("required_ability", ""))
	enemy.exposed_left = exposed
	rules.enemies.append(enemy)
	return enemy


func test_the_special_shows_ready_in_the_lamp_colour_and_cooling_muted() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var rules: HoldfastRules = run["source"].get_rules()
	var value: Label = hud.get_node("%AbilityValue")
	hud._refresh_hero()
	expect_eq(value.text, "Ready")
	expect_eq(value.theme_type_variation, &"HudReady")
	rules.hero_ability_ready_in = 3.2
	hud._refresh_hero()
	expect_eq(value.text, "3.2 s")
	expect_eq(value.theme_type_variation, &"HudCooling")
	expect_true(value.get_theme_color("font_color") != UiTokens.colour(&"lamp"), "cooling is not the ready colour")
	expect_eq(value.get_theme_color("font_color"), UiTokens.colour(&"mute"))
	rules.hero_ability_ready_in = 0.0
	hud._refresh_hero()
	expect_eq(value.get_theme_color("font_color"), UiTokens.colour(&"lamp"))
	run["main"].free()


func test_auto_is_hidden_until_keepers_habit_is_owned() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var rules: HoldfastRules = run["source"].get_rules()
	hud._refresh_hero()
	expect_false(hud.get_node("%AutoTag").visible, "no Habit, no tag")
	rules.hero_ability["auto_power"] = 0.7
	hud._refresh_hero()
	expect_true(hud.get_node("%AutoTag").visible, "the Habit fires it on its own")
	expect_eq(hud.get_node("%AutoTag").text, "Auto")
	run["main"].free()


func test_the_pause_and_speed_buttons_sit_inside_the_frame() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var window_before := tree.root.size
	for window in WINDOWS:
		tree.root.size = window
		await tree.process_frame
		var bar: Rect2 = hud.get_node("TopBar").get_global_rect()
		for button in [hud._pause_button, hud._speed_button]:
			var rect: Rect2 = button.get_global_rect()
			expect_true(bar.encloses(rect), "%s: %s is inside the frame, not on its edge" % [window, button.name])
			expect_true(rect.size.x >= 44.0 and rect.size.y >= 44.0, "%s: %s is at least 44 px" % [window, button.name])
		expect_true(hud._pause_button.get_global_rect().end.x + CLEAR <= hud._speed_button.get_global_rect().position.x, "%s: Pause and speed are apart" % window)
		expect_true(hud.get_node("%KeepBar").get_global_rect().end.x + CLEAR <= hud._pause_button.get_global_rect().position.x, "%s: the Keep bar stops short of Pause" % window)
	tree.root.size = window_before
	run["main"].free()


func test_the_pause_panel_has_resume_and_back_to_map() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var source: HoldfastRunSource = run["source"]
	var requests := []
	hud.pause_requested.connect(func(on: bool) -> void: requests.append(on))
	var left := [0]
	hud.leave_requested.connect(func() -> void: left[0] += 1)
	source.set_paused(true)
	hud._refresh_hero()
	expect_true(hud._pause_screen.visible)
	var buttons: Array = hud._pause_screen.find_children("*", "Button", true, false)
	var texts := []
	for button in buttons:
		texts.append(button.text)
		expect_true(button.custom_minimum_size.y >= 44.0, "%s is a big enough target" % button.text)
	expect_eq(texts, ["Resume", "Back to map"])
	buttons[0].pressed.emit()
	expect_eq(requests, [false])
	hud._leave_button.pressed.emit()
	expect_eq(left[0], 0, "the first press asks")
	expect_true(hud._leave_button.text.contains("Nothing is banked"))
	hud._leave_button.pressed.emit()
	expect_eq(left[0], 1, "the second leaves")
	expect_true(hud._pause_screen.find_children("*", "PanelContainer", true, false).size() > 0, "the buttons sit on a card")
	run["main"].free()


func test_the_boss_bar_says_shielded_or_exposed() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var source: HoldfastRunSource = run["source"]
	var rules := source.get_rules()
	hud._refresh_hero()
	expect_false(hud.get_node("%BossBar").visible, "no boss, no bar")
	var boss := _boss(rules)
	hud._refresh_hero()
	expect_true(hud.get_node("%BossBar").visible)
	expect_eq(hud.get_node("%BossName").text, "Fog Warden")
	expect_eq(hud.get_node("%BossState").text, "Shielded")
	expect_eq(hud.get_node("%BossHealth").value, 400.0)
	expect_eq(hud.get_node("%BossHealth").max_value, 500.0)
	boss.exposed_left = 3.2
	hud._refresh_hero()
	expect_eq(hud.get_node("%BossState").text, "Exposed: 4 s", "rounded up")
	boss.health = 0.0
	hud._refresh_hero()
	expect_false(hud.get_node("%BossBar").visible, "gone when it falls")
	run["main"].free()


func test_the_source_reports_the_boss_and_the_habit() -> void:
	var run := _run()
	var source: HoldfastRunSource = run["source"]
	expect_eq(source.get_boss_state(), {})
	expect_false(source.is_special_automatic())
	_boss(source.get_rules(), 2.0)
	var state := source.get_boss_state()
	expect_eq(state["name"], "Fog Warden")
	expect_false(state["shielded"])
	expect_eq(float(state["exposed_left"]), 2.0)
	var base: Node = preload("res://scripts/ui/run_state_source.gd").new()
	expect_eq(base.get_boss_state(), {})
	expect_false(base.is_special_automatic())
	base.free()
	run["main"].free()


func test_the_longest_wave_banner_and_boss_name_fit_at_both_sizes() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	hud.get_node("%WaveBanner").text = "Wave 99"
	hud.get_node("%WaveBanner").visible = true
	hud.show_boss({"name": "The Fog Warden of the Longest Night at Gull Rock", "health": 500.0, "max_health": 500.0, "exposed_left": 12.0, "shielded": false})
	hud._pause_screen.visible = true
	var window_before := tree.root.size
	for window in WINDOWS:
		tree.root.size = window
		await tree.process_frame
		var view := tree.root.get_visible_rect()
		var banner: Label = hud.get_node("%WaveBanner")
		expect_true(view.encloses(banner.get_global_rect()), "%s: the banner is on screen" % window)
		expect_true(banner.size.x + 0.5 >= banner.get_minimum_size().x, "%s: the banner is not clipped" % window)
		expect_true(banner.get_global_rect().position.y >= hud.get_node("TopBar").get_global_rect().end.y, "%s: the banner is below the frame" % window)
		var bar: Control = hud.get_node("%BossBar")
		expect_true(view.encloses(bar.get_global_rect()), "%s: the boss bar is on screen" % window)
		var title: Label = hud.get_node("%BossName")
		var state: Label = hud.get_node("%BossState")
		expect_true(bar.get_global_rect().encloses(title.get_global_rect()) and bar.get_global_rect().encloses(state.get_global_rect()), "%s: name and state sit inside the bar" % window)
		expect_true(title.get_global_rect().end.x + CLEAR <= state.get_global_rect().position.x, "%s: a long name leaves the state clear" % window)
		expect_true(state.size.x + 0.5 >= state.get_minimum_size().x, "%s: the state is not clipped" % window)
		for card in hud._pause_screen.find_children("*", "PanelContainer", true, false):
			expect_true(view.encloses(card.get_global_rect()), "%s: the pause card is on screen" % window)
	tree.root.size = window_before
	run["main"].free()
