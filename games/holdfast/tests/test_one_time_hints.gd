extends KitTestCase
## HF-M2-60: each new system says one line once and never again (blessings, the Mage Post, a new Hero
## path), kept in the settings file; F-152 (Start level says why it is greyed) and F-153 (the summary
## points at the Skill tree while the note says to spend stars).

const Main := preload("res://scenes/main.tscn")
const HeroPageScene := preload("res://scenes/ui/hero_page.tscn")
const JourneyScene := preload("res://scenes/ui/journey_map.tscn")
const Guidance := preload("res://scripts/ui/guidance.gd")


## A profile that gates Hero paths the way HF-M2-64 will.
class GatedProfile extends HoldfastProfile:
	var locks := {}

	func get_pillar_lock_reason(id: String) -> String:
		return str(locks.get(id, ""))


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _plan(main: Node, cards := 1, mage_cards := 0) -> Control:
	var planning: Control = main.planning
	planning.open("outpost", [], true, HoldfastContent.base()["castle_rules"]["castle"]["spots"].slice(0, 3), cards, mage_cards)
	return planning


## Opens the page for the player the way the run flow does: shown, then looked at.
func _show(page: Control) -> void:
	page.visible = false
	page.visible = true


func test_the_blessings_line_is_said_once_and_then_never_again() -> void:
	var main := _main()
	var planning := _plan(main)
	planning.set_blessings(["steady_flame", "second_wind"])
	var hint: Label = planning.get_node("%Hint")
	expect_true(hint.text.contains(planning.BLESSING_HINT), "the first time it says it")
	expect_false(main.settings.has_seen_hint("blessings"), "not yet looked at")
	_show(planning)
	expect_true(main.settings.has_seen_hint("blessings"), "now it has been seen")
	planning = _plan(main)
	planning.set_blessings(["steady_flame", "second_wind"])
	expect_false(hint.text.contains(planning.BLESSING_HINT), "never again")
	main.settings.see_hint("blessings")
	main.free()


func test_the_mage_post_line_is_said_once_and_then_never_again() -> void:
	var main := _main()
	var planning := _plan(main, 1, 1)
	var hint: Label = planning.get_node("%Hint")
	expect_true(hint.text.contains(planning.MAGE_HINT))
	_show(planning)
	expect_true(main.settings.has_seen_hint("mage_post"))
	planning = _plan(main, 1, 1)
	expect_false(hint.text.contains(planning.MAGE_HINT), "never again")
	main.free()


func test_a_hint_that_was_not_on_the_page_is_not_marked_seen() -> void:
	var main := _main()
	var planning := _plan(main)
	planning.set_blessings([])
	_show(planning)
	expect_false(main.settings.has_seen_hint("blessings"), "no blessings were on offer")
	expect_false(main.settings.has_seen_hint("mage_post"), "no Mage Post card in hand")
	main.free()


func test_a_new_hero_path_gets_a_dot_and_one_line_then_neither() -> void:
	var settings := HoldfastSettings.new()
	var profile := GatedProfile.new()
	tree.root.add_child(profile)
	ThroughLevelZero.apply(profile)
	profile.locks = {"dusk_mage": "Opens at Gull Rock.", "tideblade": "Opens later."}
	var content := HoldfastContent.base()
	expect_false(Guidance.has_pillar_news(content, profile, settings), "every other path is locked")
	var map: Control = JourneyScene.instantiate()
	tree.root.add_child(map)
	map.bind(profile)
	map.bind_hints(settings)
	var page: Control = HeroPageScene.instantiate()
	tree.root.add_child(page)
	page.bind(profile)
	page.bind_hints(settings)
	page.hint_seen.connect(settings.see_hint)
	page.visible = false
	expect_false(map._hero_dot.visible)
	profile.locks = {"tideblade": "Opens later."}
	map.refresh()
	expect_true(map._hero_dot.visible, "the Dusk Mage opened: a dot on the Hero tab")
	page.visible = true
	expect_eq(page.get_node("%Info").text, Guidance.PILLARS_LINE, "and one line on the Hero page")
	expect_true(settings.has_seen_hint(Guidance.HINT_PILLARS))
	expect_false(map._hero_dot.visible, "the dot clears once the line was shown")
	page.visible = false
	page.visible = true
	expect_eq(page.get_node("%Info").text, "", "the line is not said twice")
	page.free()
	map.free()
	profile.free()
	settings.free()


func test_no_news_while_the_profile_has_no_path_gating() -> void:
	var profile := HoldfastProfile.new()
	tree.root.add_child(profile)
	expect_false(Guidance.has_pillar_news(HoldfastContent.base(), profile, null), "nothing to point at before HF-M2-64")
	profile.free()


func test_the_hints_come_back_from_the_settings_file() -> void:
	var path := "user://hint_tests/hints.sav"
	DirAccess.make_dir_recursive_absolute("user://hint_tests")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	var settings := HoldfastSettings.new()
	settings.save_path = path
	settings.load_settings()
	settings.see_hint("blessings")
	settings.see_hint(Guidance.HINT_PILLARS)
	settings.free()
	var again := HoldfastSettings.new()
	again.save_path = path
	again.load_settings()
	expect_true(again.has_seen_hint("blessings") and again.has_seen_hint(Guidance.HINT_PILLARS))
	again.free()


# --- F-152 and F-153 ---

func test_start_level_says_why_it_is_greyed_until_a_post_is_placed() -> void:
	var main := _main()
	var planning := _plan(main)
	var start: Button = planning.get_node("%StartButton")
	expect_true(start.disabled)
	expect_true(start.text.contains(planning.NEED_A_POST), start.text)
	planning._toggle("spot_1")
	expect_false(start.disabled)
	expect_eq(start.text, "Start level", "no reason needed once it works")
	planning._toggle("spot_1")
	expect_true(start.text.contains(planning.NEED_A_POST), "and the reason is back when the post is taken off")
	main.free()


func test_the_summary_points_at_the_skill_tree_while_the_note_says_to_spend_stars() -> void:
	var main := _main()
	var summary: Control = main.summary
	summary.show_summary({"gold_earned": 50, "waves_cleared": 2, "total_waves": 2, "result": {"outcome": "won", "level": "first_watch"}, "notes": {"guide_note": Guidance.GUIDE_NOTE}}, "")
	summary.visible = false
	summary.visible = true
	expect_true(summary.get_node("%TreeButton").has_focus(), "the Skill tree is the one in front")
	expect_false(summary.get_node("%PlayAgainButton").has_focus())
	summary.show_summary({"gold_earned": 50, "waves_cleared": 2, "total_waves": 2, "result": {"outcome": "won", "level": "first_watch"}, "notes": {}}, "")
	summary.visible = false
	summary.visible = true
	expect_true(summary.get_node("%PlayAgainButton").has_focus(), "without the note it is as before")
	main.free()
