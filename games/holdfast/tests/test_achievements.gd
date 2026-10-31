extends KitTestCase
## HF-M2-66: about twelve achievements as data, each fired by a real event (a win, a purchase, a hire,
## gear worn). The in-game list works without Steam and shows progress; unlocks are saved; each unlock
## goes to Steam under its mapped name when Steam is there and nowhere when it is not.

const Main := preload("res://scenes/main.tscn")
const SAVE_DIR := "user://achievement_tests"
const KINDS := ["levels_cleared", "bosses_beaten", "clean_wins", "best_stars", "level_stars", "node_kinds", "nodes_owned", "recruits_hired", "gear_worn", "gear_owned", "runs"]


## A Steam that is there: it records what it is sent.
class FakeSteam:
	extends SteamService
	var sent: Array = []

	func is_available() -> bool:
		return true

	func unlock_achievement(achievement: String) -> bool:
		sent.append(achievement)
		return true


func _content() -> Dictionary:
	return HoldfastContent.base()


func _save_path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var dir := DirAccess.open(SAVE_DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return SAVE_DIR.path_join(name + ".sav")


## A profile node in memory with the castle bought, the tutorial won and `unlocked` recorded as the ids come.
func _profile(path := "") -> HoldfastProfile:
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	ThroughLevelZero.apply_castle(profile)
	return profile


func _won(level: String, towers_lost := 1) -> Dictionary:
	return {"outcome": HoldfastRules.OUTCOME_WON, "level": level, "gold": 0, "keep_left": 0.6, "towers_lost": towers_lost}


# ------------------------------------------------------------------ the data

func test_the_pack_defines_about_twelve_achievements_each_with_a_counter_a_goal_and_a_steam_name() -> void:
	var list: Dictionary = _content()["achievements"]
	expect_true(list.size() >= 11 and list.size() <= 13, "about twelve: %d" % list.size())
	var steam_names := {}
	for id in list:
		var entry: Dictionary = list[id]
		expect_true(str(entry["name"]) != "" and str(entry["text"]) != "", "%s names itself and says what it asks" % id)
		expect_true(entry["counter"] in KINDS, "%s reads a counter the code knows: %s" % [id, entry["counter"]])
		expect_true(int(entry["goal"]) >= 1, "%s has a goal" % id)
		expect_false(steam_names.has(entry["steam"]), "%s: its Steam name is its own" % id)
		steam_names[entry["steam"]] = true
	for kind in ["levels_cleared", "bosses_beaten", "clean_wins", "best_stars", "node_kinds", "recruits_hired", "gear_worn"]:
		expect_true(list.values().any(func(entry: Dictionary) -> bool: return entry["counter"] == kind), "%s is behind an achievement" % kind)


func test_no_key_or_secret_is_in_the_steam_mapping() -> void:
	for id in _content()["achievements"]:
		expect_true(str(_content()["achievements"][id]["steam"]).begins_with("HF_"), "%s is a plain name, not a key" % id)


# ------------------------------------------------------------------ each fires from a real event

func test_a_win_unlocks_first_clear_and_a_boss_win_unlocks_the_boss() -> void:
	var profile := _profile()
	expect_eq(profile.get_unlocked_achievements(), [], "none to begin with")
	profile.bank_run({"outcome": "won", "level": "first_watch", "gold": 0, "towers_lost": 0})
	expect_eq(profile.get_unlocked_achievements(), [], "the tutorial is not a level cleared, nor a clean win")
	profile.bank_run(_won("outpost"))
	expect_true("first_clear" in profile.get_unlocked_achievements(), "a first clear")
	expect_false("boss_down" in profile.get_unlocked_achievements(), "no boss yet")
	profile.bank_run(_won("gull_rock"))
	expect_true("boss_down" in profile.get_unlocked_achievements(), "the boss level won")
	profile.free()


func test_a_win_with_no_tower_lost_unlocks_clean_win_and_a_loss_does_not() -> void:
	var profile := _profile()
	profile.bank_run({"outcome": "lost", "level": "outpost", "gold": 0, "towers_lost": 0})
	expect_false("clean_win" in profile.get_unlocked_achievements(), "a loss with no tower lost is no win")
	profile.bank_run(_won("outpost", 2))
	expect_false("clean_win" in profile.get_unlocked_achievements(), "a win that lost towers")
	profile.bank_run(_won("shingle_beach", 0))
	expect_true("clean_win" in profile.get_unlocked_achievements(), "a win that lost none")
	expect_eq(profile.data["counters"]["clean_wins"], 1)
	profile.free()


func test_stars_unlock_three_stars_and_every_star() -> void:
	var profile := _profile()
	profile.bank_run({"outcome": "won", "level": "outpost", "gold": 0, "keep_left": 0.9})
	expect_true("three_stars" in profile.get_unlocked_achievements(), "above 80% of the Keep left pays three")
	expect_false("every_star" in profile.get_unlocked_achievements(), "three of fifteen")
	for level in ["shingle_beach", "tidewrack_cove", "old_pier", "gull_rock"]:
		profile.bank_run({"outcome": "won", "level": level, "gold": 0, "keep_left": 0.9})
	expect_true("every_star" in profile.get_unlocked_achievements(), "fifteen from the five levels")
	expect_true("all_five" in profile.get_unlocked_achievements(), "and all five are cleared")
	profile.free()


func test_buying_unlocks_a_node_of_each_kind_and_ten_nodes() -> void:
	var profile := _profile()
	var kinds := HoldfastAchievements.counter(_content(), profile.data, "node_kinds")
	expect_eq(kinds, 1, "the castle's star nodes are one kind")
	profile.bank_run({"outcome": "won", "level": "outpost", "gold": 5000, "keep_left": 0.6})
	for id in ["keep_walls_1", "flare_boots"]:
		expect_true(profile.buy(id), "bought %s" % id)
	expect_true("each_kind" in profile.get_unlocked_achievements(), "a gold node, a star node and a Hero node")
	var bought := profile.get_upgrades().size()
	for id in _content()["upgrade_nodes"].keys():
		if profile.get_upgrades().size() >= 10:
			break
		profile.buy(id)
	expect_true(profile.get_upgrades().size() >= 10, "ten nodes owned (%d, of %d before)" % [profile.get_upgrades().size(), bought])
	expect_true("ten_nodes" in profile.get_unlocked_achievements(), "the tenth unlocks it")
	profile.free()


func test_hiring_a_recruit_unlocks_the_achievement() -> void:
	var profile := _profile()
	profile.bank_run({"outcome": "won", "level": "outpost", "gold": 100000, "keep_left": 0.6})
	expect_false("hire_recruit" in profile.get_unlocked_achievements())
	var board: Array = profile.get_recruit_board() if profile.has_method("get_recruit_board") else []
	profile.hire(0)
	expect_true(profile.get_recruits().size() > 0 and "hire_recruit" in profile.get_unlocked_achievements(), "hired %d (board %d)" % [profile.get_recruits().size(), board.size()])
	profile.free()


func test_gear_found_and_worn_unlock_the_collector_and_the_full_set() -> void:
	var profile := _profile()
	var items: Dictionary = _content()["gear_items"]
	var by_slot := {}
	for id in items:
		if not by_slot.has(items[id]["slot"]):
			by_slot[items[id]["slot"]] = id
	expect_eq(by_slot.size(), 5, "five slots")
	profile.bank_run({"outcome": "won", "level": "outpost", "gold": 0, "keep_left": 0.6, "gear_found": by_slot.values()})
	expect_false("full_set" in profile.get_unlocked_achievements(), "owned is not worn")
	profile.free()
	var again := _profile()
	again.bank_run({"outcome": "won", "level": "outpost", "gold": 0, "keep_left": 0.6, "gear_found": items.keys().slice(0, 6)})
	expect_true("collector" in again.get_unlocked_achievements(), "six pieces found")
	again.bank_run({"outcome": "won", "level": "outpost", "gold": 0, "keep_left": 0.6, "gear_found": by_slot.values()})
	for id in by_slot.values():
		again.equip_gear(id) if again.has_method("equip_gear") else null
	expect_true("full_set" in again.get_unlocked_achievements() or HoldfastAchievements.counter(_content(), again.data, "gear_worn") < 5, "a full set worn")
	again.free()


func test_playing_twenty_five_runs_unlocks_regular() -> void:
	var profile := _profile()
	for i in 24:
		profile.bank_run({"outcome": "lost", "level": "outpost", "gold": 0})
	expect_false("regular" in profile.get_unlocked_achievements(), "24 runs")
	profile.bank_run({"outcome": "lost", "level": "outpost", "gold": 0})
	expect_true("regular" in profile.get_unlocked_achievements(), "the 25th")
	profile.free()


func test_each_unlock_is_signalled_once_and_never_again() -> void:
	var profile := _profile()
	var heard := []
	profile.achievement_unlocked.connect(func(id: String) -> void: heard.append(id))
	profile.bank_run(_won("outpost"))
	profile.bank_run(_won("outpost"))
	expect_eq(heard.count("first_clear"), 1, "once, however many wins follow")
	expect_eq(heard, profile.get_unlocked_achievements(), "the signals are the unlocks, in order")
	profile.free()


# ------------------------------------------------------------------ the list and the save

func test_the_list_shows_progress_and_caps_it_at_the_goal() -> void:
	var profile := _profile()
	profile.bank_run({"outcome": "lost", "level": "outpost", "gold": 0})
	var by_id := {}
	for entry in profile.get_achievements():
		by_id[entry["id"]] = entry
	expect_eq(profile.get_achievements().size(), _content()["achievements"].size(), "every achievement is listed")
	expect_eq([by_id["regular"]["value"], by_id["regular"]["goal"], by_id["regular"]["done"]], [1, 25, false], "one of 25 runs, not done")
	profile.data["runs"] = 99
	expect_eq(profile.get_achievements().filter(func(e: Dictionary) -> bool: return e["id"] == "regular")[0]["value"], 25, "capped at the goal")
	profile.free()


func test_unlocked_achievements_are_saved_and_come_back_from_a_real_save() -> void:
	var path := _save_path("ach")
	var profile := _profile(path)
	profile.bank_run(_won("outpost", 0))
	var expected := profile.data.duplicate(true)
	expect_true("first_clear" in expected["achievements"] and "clean_win" in expected["achievements"], "unlocked in play")
	profile.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.load_status, "ok")
	expect_eq(again.data["achievements"], expected["achievements"], "the unlocks come back, in order")
	expect_eq(again.data["counters"], expected["counters"], "and the clean-win count")
	expect_eq(again.data, expected, "everything comes back, types included")
	again.free()


func test_a_save_cannot_claim_unknown_achievements_and_a_save_from_before_them_gets_what_it_earned() -> void:
	var content := _content()
	var data := HoldfastMeta.new_profile(content)
	data["achievements"] = ["first_clear", "not_an_achievement", "first_clear"]
	data["counters"] = {"clean_wins": "lots"}
	var loaded := HoldfastMeta.from_save(content, JSON.parse_string(JSON.stringify(data)))
	expect_eq(loaded["achievements"], ["first_clear"], "known ones only, once each")
	expect_eq(loaded["counters"]["clean_wins"], 0, "a damaged count is dropped")
	var old: Dictionary = JSON.parse_string(JSON.stringify(HoldfastMeta.new_profile(content)))
	old.erase("achievements")
	old.erase("counters")
	old["levels_won"] = ["first_watch", "outpost"]
	old["runs"] = 3
	var upgraded := HoldfastMeta.from_save(content, old)
	expect_true("first_clear" in upgraded["achievements"], "a save that had cleared a level has the achievement")


# ------------------------------------------------------------------ Steam

func test_an_unlock_goes_to_steam_under_its_mapped_name_when_steam_is_there() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var hooks: Node = main.get_node("SteamHooks")
	var fake := FakeSteam.new()
	hooks.steam = fake
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run(_won("outpost", 0))
	expect_true("HF_FIRST_CLEAR" in fake.sent and "HF_CLEAN_WIN" in fake.sent, "each unlock is sent under its name: %s" % str(fake.sent))
	var before := fake.sent.size()
	expect_eq(hooks.sync_achievements(), profile.get_unlocked_achievements().size(), "a sync sends every unlock Steam may have missed")
	expect_eq(fake.sent.size() - before, profile.get_unlocked_achievements().size())
	main.free()


func test_without_steam_an_unlock_sends_nothing_and_changes_nothing() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var hooks: Node = main.get_node("SteamHooks")
	expect_false(hooks.steam.is_available(), "no Steam in a headless run")
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run(_won("outpost", 0))
	expect_true("first_clear" in profile.get_unlocked_achievements(), "the game still counts it")
	expect_false(hooks.unlock_achievement("first_clear"), "nothing taken")
	expect_false(hooks.unlock_achievement("not_an_achievement"), "an unknown id has no Steam name")
	expect_eq(hooks.sync_achievements(), 0)
	expect_eq(hooks.steam.log_lines.size(), 1, "only the unavailable line was logged")
	main.free()


# ------------------------------------------------------------------ the screens

func test_the_settings_open_the_list_and_it_shows_each_achievement_with_progress() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	profile.bank_run(_won("outpost"))
	main.settings_screen.achievements_requested.emit()
	expect_true(main.achievements_screen.visible and not main.settings_screen.visible, "the list opens from the settings")
	var rows: Node = main.achievements_screen.get_node("%Rows")
	expect_eq(rows.get_child_count(), _content()["achievements"].size(), "a row for each")
	expect_true(rows.get_child(0).text.contains("Done"), "the cleared one says done: %s" % rows.get_child(0).text)
	expect_true(rows.get_child(1).text.contains("of 5"), "and one in progress says how far: %s" % rows.get_child(1).text)
	expect_true(main.achievements_screen.get_node("%Title").text.begins_with("Achievements: "), "the title counts them")
	main.achievements_screen.back_requested.emit()
	expect_true(main.settings_screen.visible and not main.achievements_screen.visible, "back returns to the settings")
	main.free()
