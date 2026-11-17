extends KitTestCase
## HF-M2-86: between waves the player can call the next wave at once. It never skips a wave, never starts
## two at once, is refused while a wave spawns and after the last one, and changes no reward.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const DT := 1.0 / float(HoldfastRules.TICK_RATE)


func _rules(level := "outpost") -> HoldfastRules:
	var rules := HoldfastRules.new()
	rules.setup(HoldfastContent.run_config(level), SimRng.new(1))
	# A Keep that cannot fall, so a run nobody fights can still be stepped through every wave.
	rules.keep_health = 1000000
	rules.keep_health_max = 1000000
	return rules


func _step(rules: HoldfastRules, ticks: int) -> void:
	for i in ticks:
		rules.step(DT, {})


## Steps until `wave` has started and none is spawning (the next is still to come).
func _until_between_waves(rules: HoldfastRules, wave: int) -> void:
	var guard := 0
	while guard < 20000 and not (rules.wave >= wave and rules.can_call_next_wave()):
		rules.step(DT, {})
		guard += 1


func test_the_first_wave_can_be_called_before_it_is_due() -> void:
	var rules := _rules()
	expect_true(rules.can_call_next_wave(), "nothing has started and the first wave is still to come")
	expect_eq(rules.wave, 0)
	expect_true(rules.call_next_wave())
	_step(rules, 1)
	expect_eq(rules.wave, 1, "the first wave spawns on the next tick, not after its delay")
	expect_true(rules.time < 0.5, "at %.2f s instead of its own start" % rules.time)


func test_calling_between_waves_starts_the_next_at_once() -> void:
	var rules := _rules()
	_until_between_waves(rules, 1)
	expect_eq(rules.wave, 1)
	var next_due: float = rules._wave_starts[rules.wave]
	expect_true(next_due > rules.time + 0.1, "the second wave is still some way off (%.1f s)" % (next_due - rules.time))
	expect_true(rules.call_next_wave())
	_step(rules, 1)
	expect_eq(rules.wave, 2, "the second wave spawned on the next tick")
	expect_true(rules.time < next_due - 0.1, "at %.1f s, sooner than its own %.1f s" % [rules.time, next_due])


func test_the_waves_after_a_call_keep_their_own_gaps() -> void:
	var rules := _rules()
	var gaps: Array = []
	for w in range(1, rules.total_waves):
		gaps.append(rules._wave_starts[w] - rules._wave_starts[w - 1])
	_until_between_waves(rules, 1)
	rules.call_next_wave()
	var after: Array = []
	for w in range(1, rules.total_waves):
		after.append(rules._wave_starts[w] - rules._wave_starts[w - 1])
	expect_eq(after.size(), gaps.size())
	# Wave 2 moved up to now; waves 3 onwards moved by the same amount, so their gaps are as they were.
	for w in range(2, rules.total_waves):
		expect_near(after[w - 1], gaps[w - 1], 0.000001, "the gap before wave %d" % (w + 1))


func test_it_is_refused_while_a_wave_is_spawning() -> void:
	var rules := _rules()
	_step(rules, 1)
	var guard := 0
	while rules.wave < 1 and guard < 2000:
		rules.step(DT, {})
		guard += 1
	expect_eq(rules.wave, 1, "the first wave has started")
	var before: Array = rules._schedule.duplicate(true)
	var spawning := rules._next_spawn < rules._schedule.size() and int(rules._schedule[rules._next_spawn][1]) == 0
	expect_true(spawning, "and has enemies still to come")
	expect_false(rules.can_call_next_wave(), "so it cannot be called")
	expect_false(rules.call_next_wave())
	expect_eq(rules._schedule, before, "and nothing moved")


func test_a_second_press_before_the_wave_spawns_does_nothing() -> void:
	var rules := _rules()
	_until_between_waves(rules, 1)
	expect_true(rules.call_next_wave())
	expect_false(rules.can_call_next_wave(), "it is due this tick, so there is nothing to call")
	var schedule: Array = rules._schedule.duplicate(true)
	expect_false(rules.call_next_wave(), "a second press in the same frame")
	expect_eq(rules._schedule, schedule)
	_step(rules, 1)
	expect_eq(rules.wave, 2, "one wave started, not two")


func test_a_run_that_calls_every_wave_as_soon_as_it_can_starts_each_wave_once_in_order() -> void:
	var rules := _rules()
	var seen: Array = []
	var last := 0
	var guard := 0
	while guard < 40000 and rules.outcome == HoldfastRules.OUTCOME_RUNNING and rules.wave < rules.total_waves:
		rules.call_next_wave()
		rules.step(DT, {})
		if rules.wave != last:
			seen.append(rules.wave)
			last = rules.wave
		guard += 1
	var expected: Array = []
	for w in range(1, rules.total_waves + 1):
		expected.append(w)
	expect_eq(seen, expected, "every wave started, one at a time, none skipped")


func test_it_is_refused_after_the_last_wave_has_started() -> void:
	var rules := _rules()
	var guard := 0
	while guard < 40000 and rules.wave < rules.total_waves:
		rules.call_next_wave()
		rules.step(DT, {})
		guard += 1
	expect_eq(rules.wave, rules.total_waves)
	expect_false(rules.can_call_next_wave(), "no wave is left to call")
	expect_false(rules.call_next_wave())
	_step(rules, 30)
	expect_false(rules.can_call_next_wave(), "still none, whether or not the last wave has finished spawning")


func test_it_is_refused_once_the_run_is_over() -> void:
	var rules := _rules()
	rules.outcome = HoldfastRules.OUTCOME_LOST
	expect_false(rules.can_call_next_wave())
	expect_false(rules.call_next_wave())


func test_calling_a_wave_changes_no_reward() -> void:
	var rules := _rules()
	_until_between_waves(rules, 1)
	var before := {"gold": rules.gold, "xp": rules.xp, "carried": rules.carried_xp, "multiplier": rules.gold_multiplier, "cleared": rules.waves_cleared, "gear": rules.gear_found.duplicate()}
	rules.call_next_wave()
	var after := {"gold": rules.gold, "xp": rules.xp, "carried": rules.carried_xp, "multiplier": rules.gold_multiplier, "cleared": rules.waves_cleared, "gear": rules.gear_found.duplicate()}
	expect_eq(after, before, "the call itself pays and takes nothing")
	_step(rules, 1)
	var data: Dictionary = HoldfastContent.base()["enemies"]
	for enemy in rules.enemies:
		expect_eq(enemy.gold, int(data[enemy.type]["gold"]), "%s pays what the level says" % enemy.type)


# ------------------------------------------------------------------ the run and the HUD

func _run() -> Dictionary:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	main.call("_start_run")
	main.hud.set_process(false)
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.release_hold()
	return {"main": main, "hud": main.hud, "source": source}


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func test_the_run_refuses_the_call_while_paused_or_held() -> void:
	var run := _run()
	var source: HoldfastRunSource = run["source"]
	expect_true(source.is_wave_callable(), "running, moving and between waves")
	source.set_paused(true)
	expect_false(source.is_wave_callable(), "not while paused")
	source.call_wave()
	expect_eq(source.get_rules().wave, 0)
	source.set_paused(false)
	source._held = true
	expect_false(source.is_wave_callable(), "not while a teaching note holds the run")
	source._held = false
	source.call_wave()
	source.step(DT)
	expect_eq(source.get_rules().wave, 1, "and it works the moment the run moves")
	run["main"].free()


func test_the_button_is_labelled_and_works_only_between_waves() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var source: HoldfastRunSource = run["source"]
	var button: Button = hud.get_node("%CallWaveButton")
	expect_true(button.text.to_lower().contains("wave"), "it says what it does: %s" % button.text)
	hud._refresh_hero()
	expect_false(button.disabled, "between waves it is live")
	var calls := [0]
	hud.call_wave_requested.connect(func() -> void: calls[0] += 1)
	button.pressed.emit()
	expect_eq(calls[0], 1)
	source.step(DT)
	hud._refresh_hero()
	expect_true(button.disabled, "a wave is spawning, so it is grey")
	button.pressed.emit()
	expect_eq(calls[0], 1, "and a press does nothing")
	run["main"].free()


func test_the_key_and_the_pad_button_call_the_wave() -> void:
	HoldfastInput.ensure_actions()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	expect_true(InputMap.event_is_action(_key(KEY_N), HoldfastInput.ACTION_CALL_WAVE), "N")
	expect_true(InputMap.event_is_action(pad, HoldfastInput.ACTION_CALL_WAVE), "X on a pad")
	for event in [_key(KEY_N), pad]:
		var run := _run()
		var hud: Control = run["hud"]
		var source: HoldfastRunSource = run["source"]
		var calls := [0]
		hud.call_wave_requested.connect(func() -> void: calls[0] += 1)
		hud._input(event)
		expect_eq(calls[0], 1, "%s asks for the wave" % event.as_text())
		source.step(DT)
		expect_eq(source.get_wave(), 1, "and the run starts it")
		hud._input(event)
		expect_eq(calls[0], 1, "not again while that wave spawns")
		run["main"].free()


func test_the_key_does_nothing_while_paused() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var source: HoldfastRunSource = run["source"]
	var calls := [0]
	hud.call_wave_requested.connect(func() -> void: calls[0] += 1)
	source.set_paused(true)
	hud._input(_key(KEY_N))
	expect_eq(calls[0], 0, "paused")
	expect_eq(source.get_wave(), 0)
	run["main"].free()


func test_pressing_it_in_a_run_starts_the_next_wave_through_the_run_flow() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var source: HoldfastRunSource = run["source"]
	hud.get_node("%CallWaveButton").pressed.emit()
	source.step(DT)
	expect_eq(source.get_wave(), 1, "the HUD's request reaches the run")
	run["main"].free()


func test_the_button_sits_with_pause_and_speed_without_overlapping_at_both_sizes() -> void:
	var run := _run()
	var hud: Control = run["hud"]
	var window_before := tree.root.size
	var button: Button = hud.get_node("%CallWaveButton")
	for window in WINDOWS:
		tree.root.size = window
		await tree.process_frame
		var rect: Rect2 = button.get_global_rect()
		var bar: Rect2 = hud.get_node("TopBar").get_global_rect()
		expect_true(Rect2(Vector2.ZERO, Vector2(window)).encloses(rect), "%s: it is on the screen" % window)
		expect_true(rect.size.x >= 44.0 and rect.size.y >= 44.0, "%s: at least 44 px" % window)
		expect_false(rect.intersects(bar), "%s: clear of the top bar" % window)
		expect_false(rect.intersects(hud._pause_button.get_global_rect()), "%s: clear of Pause" % window)
		expect_false(rect.intersects(hud._speed_button.get_global_rect()), "%s: clear of speed" % window)
		expect_true(rect.end.x <= bar.end.x + 0.5 and rect.position.y >= bar.end.y, "%s: it sits under the controls, in line with them" % window)
		expect_false(rect.intersects(hud.get_node("%WaveBanner").get_global_rect()) and hud.get_node("%WaveBanner").visible, "%s: clear of the banner" % window)
	tree.root.size = window_before
	run["main"].free()
