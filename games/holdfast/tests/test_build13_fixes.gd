extends KitTestCase
## Build 13 follow-ups from QA: a run_open that is not a boolean (F-160), the stars of a Hard win read
## against the Keep the player had (F-163), and the Plan title of a Hard replay clear of "+ Tower" (F-164).

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://build13_fix_tests"


func _content() -> Dictionary:
	return HoldfastContent.base()


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


# ------------------------------------------------------------------ F-160

func test_a_run_open_that_is_not_a_boolean_is_not_an_open_run() -> void:
	var content := _content()
	for value in ["yes", 1, 1.0, "true", [true], {"a": 1}, null]:
		var data := HoldfastMeta.new_profile(content)
		data["run_open"] = value
		var loaded := HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(data)))
		expect_false(loaded["run_open"], "%s is no open run" % JSON.stringify(value))
	var data := HoldfastMeta.new_profile(content)
	data["run_open"] = true
	expect_true(HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(data)))["run_open"], "true still is")


func test_a_real_save_with_a_run_open_of_the_wrong_type_loads() -> void:
	for value in ["yes", 1]:
		var path := _save_path("run_open")
		var profile := HoldfastProfile.new()
		profile.save_path = path
		tree.root.add_child(profile)
		profile.data["run_open"] = value
		profile._save()
		profile.free()
		var again := HoldfastProfile.new()
		again.save_path = path
		tree.root.add_child(again)
		expect_eq(again.load_status, "ok", "%s: the save loads with its checksum" % JSON.stringify(value))
		expect_false(again.data["run_open"], "%s: and holds no open run" % JSON.stringify(value))
		again.free()


# ------------------------------------------------------------------ F-163

func _rules(level: String, hard: bool, blessing := "") -> HoldfastRules:
	var rules := HoldfastRules.new()
	rules.report_errors = false
	rules.setup(HoldfastContent.run_config(level, [], _content(), "flare_archer", null, {}, [], false, null, blessing, {}, hard), SimRng.new(5))
	return rules


func test_a_fragile_keep_is_judged_against_the_keep_it_had() -> void:
	var rules := _rules("old_pier", true)
	expect_true(rules.keep_health_max < roundi(float(_content()["levels"]["old_pier"]["keep_health"]) * 0.5), "Fragile cuts the Keep: %d" % rules.keep_health_max)
	rules._keep_damage = float(rules.keep_health_max) * 0.5
	rules.outcome = HoldfastRules.OUTCOME_WON
	expect_near(rules.result()["keep_left"], 0.5, 0.01, "half the Keep gone is half the Keep left, not nine tenths")
	rules._keep_damage = 0.0
	expect_near(rules.result()["keep_left"], 1.0, 0.0001, "untouched is all of it")


func test_a_normal_run_and_a_blessing_are_judged_as_before() -> void:
	var normal := _rules("old_pier", false)
	normal.outcome = HoldfastRules.OUTCOME_WON
	expect_false(normal.result().has("keep_left"), "a plain Normal run reports none (the profile reads the Keep itself)")
	var content := _content()
	var blessing := str(content["blessings"].keys()[0])
	var blessed := _rules("old_pier", false, blessing)
	blessed._keep_damage = float(blessed._keep_star_max) * 0.25
	blessed.outcome = HoldfastRules.OUTCOME_WON
	expect_near(blessed.result()["keep_left"], 0.75, 0.01, "a blessing never changes the star yardstick")


func test_every_hard_replay_reads_its_stars_against_its_own_keep() -> void:
	for level in ["outpost", "shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]:
		var rules := _rules(level, true)
		rules._keep_damage = float(rules.keep_health_max) * 0.3
		rules.outcome = HoldfastRules.OUTCOME_WON
		var left: float = rules.result()["keep_left"]
		expect_true(left >= 0.0 and left <= 1.0, "%s: %.2f left" % [level, left])
		expect_near(left, 1.0 - 0.3 * float(rules.keep_health_max) / maxf(rules._keep_star_max, 1.0), 0.0001, "%s: the damage over the Keep the player had" % level)


# ------------------------------------------------------------------ F-164

func test_the_hard_plan_title_leaves_room_for_the_tower_button_at_720p() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	var screen: Node = main.planning
	var title: Label = screen._title
	var font := title.get_theme_font("font")
	var font_size := title.get_theme_font_size("font_size")
	var content := _content()
	var widest := 0.0
	for level in content["levels"]:
		if content["levels"][level].get("modifiers", []).is_empty():
			continue
		screen.open(level, [], false, [], 1)
		screen.set_hard(HoldfastMeta.hard_label(content, level))
		widest = maxf(widest, font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	# What the header leaves the title: the page's width less the margins, the "+ Tower" button and the posts count.
	var count: Label = screen._count
	count.text = "Posts: 8 of 8"
	var tower: Button = screen._tower
	var room: float = 1280.0 - 2.0 * 24.0 - tower.get_combined_minimum_size().x - count.get_combined_minimum_size().x - 2.0 * 12.0
	expect_true(widest + 48.0 <= room, "the longest Hard title %.0f px leaves 48 px of the %.0f px the header gives it" % [widest, room])
	main.free()
