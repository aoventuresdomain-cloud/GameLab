extends KitTestCase
## F-018: the HUD bar never covers the keep, the tower and staff range circles,
## or any point within their reach of the keep, at 1280x720 and 1920x1080.

const Main := preload("res://scenes/main.tscn")


func test_hud_never_covers_the_keep_or_the_attack_ranges() -> void:
	var main := Main.instantiate()
	var source: HoldfastRunSource = main.get_node("RunSource")
	source.auto_step = false
	tree.root.add_child(main)
	main.call("_start_run")
	var world: Node2D = main.get_node("World")
	var rules := source.get_rules()
	var bar: Control = main.get_node("UI/Hud/TopBar")
	var window_before := tree.root.size
	for window in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = window
		await tree.process_frame
		world._process(0.0) # place the world for this window size
		var to_window := tree.root.get_final_transform()
		var hud_bottom: float = (to_window * bar.get_global_rect().end).y
		var reach := maxf(rules.tower.attack_range, rules.staff.attack_range)
		var size := "%dx%d" % [window.x, window.y]
		var keep_top: float = (to_window * world.world_to_screen(Vector2(0.0, -reach))).y
		expect_true(keep_top > hud_bottom,
				"%s: keep plus the longer range reaches y=%.0f, below the HUD at y=%.0f" % [size, keep_top, hud_bottom])
		for attacker in [rules.tower, rules.staff]:
			var top: float = (to_window * world.world_to_screen(attacker.position - Vector2(0.0, attacker.attack_range))).y
			expect_true(top > hud_bottom,
					"%s: range circle top at y=%.0f, below the HUD at y=%.0f" % [size, top, hud_bottom])
	tree.root.size = window_before
	main.free()
