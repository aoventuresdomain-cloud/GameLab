extends KitTestCase
## HF-M2-92 (F-210): the loss panel's "The keep fell in wave N of M" says the wave the HUD showed when the keep fell,
## not the number of leak-free waves plus one.

const Main := preload("res://scenes/main.tscn")


func _lost_run(level: String) -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	main.get_node("Profile").save_path = "user://loss_wave_hud.sav"
	tree.root.add_child(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.select_level(level)
	main.call("_start_run")
	# No post stands, so every wave leaks and the keep falls some waves in.
	main.get_node("RunSource").step(4000.0)
	return main


func test_the_loss_panel_names_the_wave_the_hud_showed() -> void:
	for level in ["outpost", "shingle_beach"]:
		var main := _lost_run(level)
		var source: HoldfastRunSource = main.get_node("RunSource")
		var hud_wave := source.get_wave()
		var total := source.get_total_waves()
		expect_true(main.summary.visible, "set-up: the run ended on the summary")
		var hud_text: String = main.hud.get_node("%WaveValue").text
		expect_eq(hud_text, "%d / %d" % [hud_wave, total], "set-up: the HUD reads the engine's wave")
		expect_true(hud_wave > source._rules.waves_cleared + 1, "set-up: an earlier wave leaked, so the HUD is ahead of clean waves plus one")
		expect_eq(main.summary.get_node("%Moment").text, "The keep fell in wave %d of %d." % [hud_wave, total], "%s: the panel and the HUD agree" % level)
		main.free()
