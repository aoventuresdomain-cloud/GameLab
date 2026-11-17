extends KitTestCase
## Build 21a (HF-M2-91, F-209): a shrouded Fog Warden tells the player what to press, and the special's reach
## shows as a ring round the Hero while the special is ready. The shroud still lifts wherever the Hero stands.

const Main := preload("res://scenes/main.tscn")
const WINDOWS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 600)]
const READY_NOTE := "Fog Warden shrouded: press Space (A on a pad) with it in reach"
const DT := 1.0 / HoldfastRules.TICK_RATE


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
	enemy.exposed_seconds = float(data["exposed_seconds"])
	enemy.exposed_left = exposed
	rules.enemies.append(enemy)
	return enemy


func test_the_note_says_what_to_press_when_the_special_is_ready() -> void:
	var run := _run()
	var source: HoldfastRunSource = run["source"]
	var rules := source.get_rules()
	rules.hero_ability_ready_in = 0.0
	_boss(rules, Vector2(300, 300))
	expect_eq(source.get_boss_note(), READY_NOTE)
	run["main"].free()


func test_the_note_says_when_the_special_will_be_ready() -> void:
	var run := _run()
	var source: HoldfastRunSource = run["source"]
	var rules := source.get_rules()
	_boss(rules, Vector2(300, 300))
	rules.hero_ability_ready_in = 8.2
	expect_eq(source.get_boss_note(), "Fog Warden shrouded: special ready in 9 s", "rounded up")
	rules.hero_ability_ready_in = 0.0
	expect_eq(source.get_boss_note(), READY_NOTE, "and the key once it is")
	run["main"].free()


func test_a_downed_hero_is_told_when_they_are_up_not_to_press() -> void:
	var run := _run()
	var source: HoldfastRunSource = run["source"]
	var rules := source.get_rules()
	_boss(rules, Vector2(300, 300))
	rules.hero_ability_ready_in = 0.0
	rules.hero_state["downed"] = true
	rules.hero_state["get_up_in"] = 3.4
	expect_eq(source.get_boss_note(), "Fog Warden shrouded: you are down, up in 4 s")
	expect_eq(source.get_special_reach(), 0.0, "no ring on a Hero who is down")
	run["main"].free()


func test_the_exposed_note_and_the_bar_are_unchanged() -> void:
	var run := _run()
	var source: HoldfastRunSource = run["source"]
	var rules := source.get_rules()
	_boss(rules, Vector2(300, 300), 3.2)
	expect_eq(source.get_boss_note(), "Fog Warden exposed: 4 s")
	expect_eq(source.get_special_reach(), 0.0, "no ring once the shroud is down")
	run["main"].free()


func test_the_ring_shows_only_while_a_boss_is_shrouded_and_the_special_is_ready() -> void:
	var run := _run()
	var source: HoldfastRunSource = run["source"]
	var rules := source.get_rules()
	var reach := float(rules.hero_ability["range"])
	rules.hero_ability_ready_in = 0.0
	expect_eq(source.get_special_reach(), 0.0, "no boss, no ring")
	_boss(rules, Vector2(300, 300))
	expect_eq(source.get_special_reach(), reach, "shrouded and ready: the special's own range")
	rules.hero_ability_ready_in = 5.0
	expect_eq(source.get_special_reach(), 0.0, "cooling: no ring")
	run["main"].free()


func test_the_shroud_lifts_on_a_press_wherever_the_hero_stands() -> void:
	var run := _run()
	var source: HoldfastRunSource = run["source"]
	var rules := source.get_rules()
	rules.hero_ability_ready_in = 0.0
	rules.hero_position = -rules.arena_half * 0.8
	var boss := _boss(rules, rules.arena_half * 0.8)
	expect_true(boss.position.distance_to(rules.hero_position) > float(rules.hero_ability["range"]) + boss.radius, "the boss is out of reach")
	rules.step(DT, {"ability": true})
	expect_near(boss.exposed_left, 6.0, 0.1, "lifted from across the field, for the pack's seconds")
	run["main"].free()


## The ring and the longer note, clear of everything around the field at each window size.
func test_the_note_and_the_ring_overlap_nothing_at_any_window_size() -> void:
	var run := _run()
	var main: Node = run["main"]
	var hud: Control = run["hud"]
	var world: Node2D = main.get_node("World")
	var rules: HoldfastRules = run["source"].get_rules()
	rules.hero_ability_ready_in = 0.0
	_boss(rules, Vector2(300, 300))
	hud._refresh_hero()
	var field := Rect2(-rules.arena_half, rules.arena_half * 2.0)
	var reach := rules.special_reach_hint()
	var window_before := tree.root.size
	for window in WINDOWS:
		tree.root.size = window
		await tree.process_frame
		world._process(0.0)
		var to_window := tree.root.get_final_transform()
		var note: Label = hud.get_node("%PostsNote")
		var note_box := Rect2(to_window * note.get_global_rect().position, note.get_global_rect().size * to_window.get_scale())
		expect_eq(note.text, READY_NOTE, "%s: the note is up" % window)
		expect_true(tree.root.get_visible_rect().encloses(note.get_global_rect()), "%s: the note is on screen" % window)
		for id in ["PauseButton", "SpeedButton", "CallWaveButton", "BossBar", "SpecialTip"]:
			var other: Control = hud.get_node("%" + id)
			if not other.is_visible_in_tree():
				continue
			var box := Rect2(to_window * other.get_global_rect().position, other.get_global_rect().size * to_window.get_scale())
			expect_false(note_box.intersects(box), "%s: the note is clear of %s" % [window, id])
		# The Hero's start: no point of the ring lies under the note's text.
		var text_box := _text_box(note, note_box)
		var under := 0
		for i in 96:
			var point: Vector2 = rules.hero_position + Vector2.RIGHT.rotated(TAU * i / 96.0) * reach
			if field.has_point(point) and text_box.has_point(to_window * world.world_to_screen(point)):
				under += 1
		expect_eq(under, 0, "%s: the ring does not cross the note's words" % window)
	tree.root.size = window_before
	main.free()


## The box the label's words fill: the label is wide and its text centred, so the full rect overstates it.
func _text_box(label: Label, box: Rect2) -> Rect2:
	var size := label.get_theme_font("font").get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x / maxf(tree.root.get_final_transform().get_scale().x, 0.01), label.get_theme_font_size("font_size"))
	var scaled := size * tree.root.get_final_transform().get_scale()
	return Rect2(box.position + Vector2((box.size.x - scaled.x) * 0.5, 0.0), scaled)
