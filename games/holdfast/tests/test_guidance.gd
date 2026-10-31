extends KitTestCase
## HF-M2-61: guidance and the end of content. The map names the next goal, a win names the boss and
## what it opened, the way on at the last level, a loss gives its wave and one tip by state, the Hero
## page says how to wear gear and shows locked paths as locked, the Plan page explains itself, the
## guide follows the player to the Skill tree, and "Refund all" asks first and keeps the guided buys.

const Main := preload("res://scenes/main.tscn")
const HeroPageScene := preload("res://scenes/ui/hero_page.tscn")
const Guidance := preload("res://scripts/ui/guidance.gd")
const BOSS_LEVEL := "gull_rock"
const GOAL := "Next: The Outpost, then Fog Warden at Gull Rock"


## A profile that gates Hero paths and opens them at levels, the way HF-M2-64 will.
class GatedProfile extends HoldfastProfile:
	var locks := {}
	var opens := {}

	func get_pillar_lock_reason(id: String) -> String:
		return str(locks.get(id, ""))

	func get_paths_opened_by(level: String) -> Array:
		return opens.get(level, [])


func _content() -> Dictionary:
	return HoldfastContent.base()


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func _profile() -> HoldfastProfile:
	var profile := HoldfastProfile.new()
	tree.root.add_child(profile)
	return profile


## Level 0 won and nothing bought: the guide is due.
func _after_level_zero(profile: HoldfastProfile) -> void:
	var first := HoldfastMeta.tutorial_level(_content())
	profile.data["stars"][first] = 2
	profile.data["levels_won"].append(first)
	profile.data["unlocked"].append(HoldfastMeta.next_level(_content(), first))
	profile.changed.emit()


## Every level won and open.
func _all_won(profile: HoldfastProfile) -> void:
	ThroughLevelZero.apply(profile)
	for id in _content()["levels"]:
		if not id in profile.data["levels_won"]:
			profile.data["levels_won"].append(id)
		if not id in profile.data["unlocked"]:
			profile.data["unlocked"].append(id)
	profile.changed.emit()


func _ended(level: String, outcome: String, cleared := 6, total := 6) -> Dictionary:
	return {"gold_earned": 50, "waves_cleared": cleared, "total_waves": total, "keep_fell": outcome == HoldfastRules.OUTCOME_LOST,
			"result": {"outcome": outcome, "level": level, "gold": 50}}


# ------------------------------------------------------------------ the goal on the map

func test_the_map_names_the_next_goal_and_the_boss_it_ends_on() -> void:
	var profile := _profile()
	expect_eq(Guidance.next_goal(_content(), profile), "", "a new game: Level 0 speaks for itself")
	_after_level_zero(profile)
	expect_eq(Guidance.next_goal(_content(), profile), "", "the guide has the player's attention")
	ThroughLevelZero.apply(profile)
	expect_eq(Guidance.next_goal(_content(), profile), "", "and so does the fight it leads to")
	profile.begin_stand()
	expect_eq(Guidance.next_goal(_content(), profile), "Next: The Outpost, then Fog Warden at Gull Rock")
	for id in ["outpost", "shingle_beach", "tidewrack_cove", "old_pier"]:
		profile.data["levels_won"].append(id)
		profile.data["unlocked"].append(HoldfastMeta.next_level(_content(), id))
	expect_eq(Guidance.next_goal(_content(), profile), "Next: Gull Rock, where Fog Warden waits")
	profile.free()


func test_the_goal_leads_with_an_upgrade_that_is_nearly_affordable() -> void:
	var profile := _profile()
	ThroughLevelZero.apply(profile)
	profile.begin_stand()
	var id: String = HoldfastMeta.next_unlocks(_content(), profile.data)[0]
	var name: String = _content()["upgrade_nodes"][id]["name"]
	var cost := int(_content()["upgrade_nodes"][id]["cost"])
	expect_true(cost % 2 == 0 and cost >= 40, "the cheapest upgrade in reach costs an even sum of at least 40: %s %d" % [id, cost])
	profile.data["gold"] = cost - 30
	expect_eq(Guidance.next_goal(_content(), profile), "Next: %s in 30 gold, then The Outpost, then Fog Warden at Gull Rock" % name)
	profile.data["gold"] = cost / 2
	expect_true(Guidance.next_goal(_content(), profile).begins_with("Next: %s in %d gold, then" % [name, cost / 2]), "exactly half the price away still counts")
	profile.data["gold"] = cost / 2 - 1
	expect_false(Guidance.next_goal(_content(), profile).begins_with("Next: " + name), "a little more than half is too far")
	profile.data["gold"] = cost
	expect_false(Guidance.next_goal(_content(), profile).begins_with("Next: " + name), "affordable now is not a goal, it is a purchase")
	profile.free()


func test_the_map_says_more_is_coming_once_every_level_is_won() -> void:
	var profile := _profile()
	_all_won(profile)
	profile.begin_stand()
	expect_eq(Guidance.next_goal(_content(), profile), Guidance.MORE_COMING)
	profile.free()


func test_the_goal_shows_on_the_journey_map_when_nothing_is_hovered() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.begin_stand()
	expect_eq(main.journey.get_node("%Info").text, GOAL)
	main.journey._buttons["outpost"].mouse_entered.emit()
	expect_true(main.journey.get_node("%Info").text.begins_with("The Outpost: "), "a hover says what the level is")
	main.journey._buttons["outpost"].mouse_exited.emit()
	expect_eq(main.journey.get_node("%Info").text, GOAL, "and the goal comes back")
	main.free()


# ------------------------------------------------------------------ the summary after a win

func test_winning_the_boss_level_names_the_boss_what_it_opened_and_that_more_is_coming() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	_all_won(profile)
	main.call("_on_run_ended", _ended(BOSS_LEVEL, HoldfastRules.OUTCOME_WON))
	var summary: Control = main.summary
	expect_eq(summary.get_node("%Moment").text, "Fog Warden is beaten.")
	expect_eq(summary.get_node("%WayOn").text, Guidance.MORE_COMING)
	expect_false(summary.get_node("%NextLevelButton").visible, "no Next level to dead-end on")
	expect_false(summary.get_node("%Tip").visible, "a win has no loss tip")
	main.free()


func test_a_win_lists_what_it_opened_when_the_profile_says_so() -> void:
	var profile := GatedProfile.new()
	tree.root.add_child(profile)
	profile.opens = {BOSS_LEVEL: ["dusk_mage"]}
	ThroughLevelZero.apply(profile)
	var notes := Guidance.summary_notes(_content(), profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": BOSS_LEVEL}, "")
	expect_eq(notes["unlocked"], ["The Dusk Mage path is open on the Hero page."])
	var none := Guidance.summary_notes(_content(), profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": "outpost"}, "shingle_beach")
	expect_eq(none["unlocked"], [], "a level that opens nothing lists nothing")
	profile.free()


func test_a_win_before_the_last_level_has_no_way_on_note_and_keeps_its_next_level() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON))
	expect_false(main.summary.get_node("%WayOn").visible)
	expect_false(main.summary.get_node("%Moment").visible, "the Outpost has no boss")
	expect_true(main.summary.get_node("%NextLevelButton").visible)
	main.free()


# ------------------------------------------------------------------ the summary after a loss

func test_a_loss_says_the_wave_it_fell_in() -> void:
	var main := _main()
	ThroughLevelZero.apply(main.get_node("Profile"))
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_LOST, 2, 5))
	expect_eq(main.summary.get_node("%Moment").text, "The keep fell in wave 3 of 5.")
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_LOST, 0, 5))
	expect_eq(main.summary.get_node("%Moment").text, "The keep fell in wave 1 of 5.", "none cleared is wave 1")
	main.free()


func test_the_loss_tip_follows_the_state_stars_then_gold_then_gear_then_a_general_one() -> void:
	var profile := _profile()
	ThroughLevelZero.apply(profile)
	var content := _content()
	expect_eq(Guidance.loss_tip(content, profile), Guidance.FALLBACK_TIP, "nothing to spend, nothing to wear")
	profile.data["gear"]["owned"].append("wave_worn_boots")
	expect_true(Guidance.loss_tip(content, profile).contains("gear"), "a piece in the bag")
	profile.wear_gear("wave_worn_boots")
	expect_eq(Guidance.loss_tip(content, profile), Guidance.FALLBACK_TIP, "worn, so nothing is left unused")
	profile.data["gold"] = 1000
	expect_true(Guidance.loss_tip(content, profile).contains("gold to spend"), "gold beats gear")
	profile.data["stars"]["outpost"] = 1
	expect_true(Guidance.loss_tip(content, profile).contains("1 unspent star."), "one star, said in the singular, beats gold")
	profile.data["stars"]["shingle_beach"] = 3
	expect_true(Guidance.loss_tip(content, profile).contains("4 unspent stars."), "four stars")
	profile.free()


func test_a_loss_panel_shows_its_tip_and_a_win_panel_does_not() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["gold"] = 500
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_LOST, 1, 5))
	expect_true(main.summary.get_node("%Tip").visible and main.summary.get_node("%Tip").text.contains("gold to spend"))
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON))
	expect_false(main.summary.get_node("%Tip").visible)
	main.free()


func test_the_tutorial_has_no_loss_tip_and_no_boss_line() -> void:
	var profile := _profile()
	var notes := Guidance.summary_notes(_content(), profile, {"outcome": HoldfastRules.OUTCOME_WON, "level": "first_watch"}, "outpost")
	expect_eq(notes, {"boss": "", "unlocked": [], "way_on": "", "tip": ""})
	profile.free()


# ------------------------------------------------------------------ the Hero page

func test_the_hero_page_says_how_to_wear_gear_until_the_first_piece_is_worn() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	var page: Control = main.hero_page
	var hint: Label = page.get_node("%BagHint")
	expect_true(hint.text.begins_with("Gear: none yet"), "no gear: where it comes from")
	profile.data["gear"]["owned"].append("wave_worn_boots")
	profile.changed.emit()
	expect_eq(hint.text, page.WEAR_HINT, "a piece in the bag and none worn: how to wear it")
	profile.wear_gear("wave_worn_boots")
	expect_eq(hint.text, "Bag", "the first piece is on: the how-to is gone")
	main.free()


func test_a_locked_path_looks_locked_says_what_opens_it_and_a_press_changes_nothing() -> void:
	var profile := GatedProfile.new()
	tree.root.add_child(profile)
	profile.locks = {"dusk_mage": "Opens when you beat the boss at Gull Rock."}
	var page: Control = HeroPageScene.instantiate()
	tree.root.add_child(page)
	page.bind(profile)
	var heard := []
	page.pillar_requested.connect(func(id: String) -> void: heard.append(id))
	var locked: Button = page._pillar_buttons["dusk_mage"]
	expect_true(locked.text.ends_with("(locked)"), locked.text)
	expect_true(locked.modulate.a < 1.0, "dimmed")
	expect_false(page._pillar_buttons["flare_archer"].text.contains("locked"))
	locked.pressed.emit()
	expect_eq(heard, [], "a locked path asks for nothing")
	expect_eq(page.get_node("%Info").text, "Dusk Mage: Opens when you beat the boss at Gull Rock.")
	expect_true(page._pillar_buttons["flare_archer"].button_pressed and not locked.button_pressed, "the path held stays held")
	page._pillar_buttons["flare_archer"].pressed.emit()
	expect_eq(heard, ["flare_archer"], "an open path is asked for as before")
	page.free()
	profile.free()


func test_every_path_is_open_while_the_profile_has_no_gating() -> void:
	var main := _main()
	for id in main.hero_page._pillar_buttons:
		expect_false(main.hero_page._pillar_buttons[id].text.contains("locked"), id)
	main.free()


# ------------------------------------------------------------------ the Plan page

func _plan(main: Node, cards := 1, mage_cards := 0, saved := false) -> Control:
	var planning: Control = main.planning
	planning.open("outpost", [], saved, _content()["castle_rules"]["castle"]["spots"].slice(0, 3), cards, mage_cards)
	return planning


func test_quick_start_says_why_it_is_greyed_and_stops_saying_it_once_a_layout_is_saved() -> void:
	var main := _main()
	var planning := _plan(main)
	var quick: Button = planning.get_node("%QuickButton")
	expect_true(quick.disabled)
	expect_eq(quick.tooltip_text, planning.QUICK_WHY)
	expect_eq(quick.text, "Quick start (no layout yet)", "the button says why on its face")
	expect_true(planning.get_node("%Hint").text.contains(planning.QUICK_WHY), "on the page as well as on hover")
	planning = _plan(main, 1, 0, true)
	planning.open("outpost", ["spot_1"], true, _content()["castle_rules"]["castle"]["spots"].slice(0, 3), 1)
	expect_false(quick.disabled)
	expect_eq(quick.text, "Quick start")
	expect_eq(quick.tooltip_text, "")
	expect_false(planning.get_node("%Hint").text.contains(planning.QUICK_WHY))
	main.free()


func test_the_plan_page_explains_blessings_and_the_mage_post_until_they_are_used() -> void:
	var main := _main()
	var planning := _plan(main, 1, 0, true)
	var hint: Label = planning.get_node("%Hint")
	planning.set_blessings(["steady_flame", "second_wind"])
	expect_true(hint.text.contains(planning.BLESSING_HINT), hint.text)
	planning.set_blessings([])
	expect_false(hint.text.contains(planning.BLESSING_HINT), "no blessings on offer, no hint")
	planning = _plan(main, 1, 1, true)
	expect_true(hint.text.contains(planning.MAGE_HINT), "a Mage Post card and none placed: how to place it")
	planning._toggle("spot_1")
	planning._toggle("spot_2")
	expect_true(planning._placed("mage_post") == 1)
	expect_false(hint.text.contains(planning.MAGE_HINT), "placed once: the hint is gone")
	main.free()


func test_a_reason_for_plus_tower_stands_alone_in_the_hint() -> void:
	var main := _main()
	var planning := _plan(main)
	planning.set_blessings(["steady_flame"])
	planning.set_tower_offer("+ Tower (1 star)", "Not enough stars")
	expect_eq(planning.get_node("%Hint").text, "Not enough stars")
	main.free()


func test_the_recruit_picker_shows_only_with_posted_hand_and_says_what_it_does() -> void:
	var main := _main()
	var planning := _plan(main)
	planning._toggle("spot_1")
	var squad := [{"id": "bryn", "name": "Bryn"}]
	planning.set_posted(squad, {}, false)
	expect_false(planning._recruit_buttons["spot_1"].visible, "Posted Hand not owned: nothing to pick for")
	planning.set_posted(squad, {}, true)
	expect_true(planning._recruit_buttons["spot_1"].visible)
	expect_false(planning._recruit_buttons["spot_1"].flat, "it looks like a button")
	expect_eq(planning._recruit_buttons["spot_1"].tooltip_text, planning.RECRUIT_TIP)
	main.free()


func test_moving_a_post_takes_its_recruit_with_it() -> void:
	var main := _main()
	var planning := _plan(main)
	planning._toggle("spot_1")
	planning.set_posted([{"id": "bryn", "name": "Bryn"}], {"spot_1": "bryn"}, true)
	var heard := []
	planning.recruit_posted.connect(func(site: String, id: String) -> void: heard.append([site, id]))
	planning._slot_drop(Vector2.ZERO, {"kind": "tower", "tower": "archer_post", "from": "spot_1"}, "spot_3")
	expect_eq(planning.chosen(), ["spot_3"], "the post moved")
	expect_eq(heard, [["spot_3", "bryn"]], "and Bryn is set on the new spot")
	heard.clear()
	planning._toggle("spot_2")
	planning._slot_drop(Vector2.ZERO, {"kind": "tower", "tower": "archer_post", "from": "spot_2"}, "spot_1")
	expect_eq(heard, [], "a post with nobody on it moves with nobody")
	main.free()


func test_the_flow_hides_the_picker_until_posted_hand_is_owned() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	_plan(main)
	main.call("_show_posted")
	expect_false(main.planning._posting)
	profile.data["upgrades"].append("link_posted_hand")
	main.call("_show_posted")
	expect_true(main.planning._posting)
	main.free()


# ------------------------------------------------------------------ the guide on both routes

func test_the_guide_shows_on_the_tree_as_well_as_the_map_and_its_button_buys() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	_after_level_zero(profile)
	var guide: Control = main.keep_screen.get_node("%Guide")
	expect_true(guide.visible, "the tree has the guide too")
	expect_eq(main.keep_screen.get_node("%GuideLabel").text, main.journey.get_node("%GuideLabel").text, "the same words on both")
	main.keep_screen.get_node("%GuideButton").pressed.emit()
	expect_true("castle_slot_1" in profile.get_upgrades(), "the button buys the guided step")
	main.keep_screen.get_node("%GuideButton").pressed.emit()
	expect_true(profile.has_a_tower(), "and the next")
	expect_true(guide.visible and main.keep_screen.get_node("%GuideButton").text == "Start", "then it offers the fight")
	main.keep_screen.get_node("%GuideButton").pressed.emit()
	expect_true(main.get_node("RunSource").is_running(), "Start on the tree begins the stand")
	main.free()


func test_the_tree_shows_no_guide_once_the_buys_are_made_and_the_stand_begun() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	expect_true(main.keep_screen.get_node("%Guide").visible, "the stand is still due")
	profile.begin_stand()
	expect_false(main.keep_screen.get_node("%Guide").visible)
	expect_false(main.journey.get_node("%Guide").visible)
	main.free()


func test_next_level_waits_for_the_guided_buys_and_is_there_after_them() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	main.call("_on_run_ended", _ended("first_watch", HoldfastRules.OUTCOME_WON, 2, 2))
	var summary: Control = main.summary
	expect_false(summary.get_node("%NextLevelButton").visible, "no Next level before the buys")
	expect_true(summary.get_node("%GuideNote").visible, "the summary says what to do instead")
	summary.get_node("%TreeButton").pressed.emit()
	expect_true(main.keep_screen.visible and main.keep_screen.get_node("%Guide").visible, "the Skill tree route has the guide")
	main.keep_screen.get_node("%GuideButton").pressed.emit()
	main.keep_screen.get_node("%GuideButton").pressed.emit()
	main.call("_show", main.Screen.MAP)
	expect_true(main.journey.get_node("%Guide").visible and main.journey.get_node("%GuideButton").text == "Start", "the map route has it too")
	main.call("_on_run_ended", _ended("outpost", HoldfastRules.OUTCOME_WON))
	expect_true(summary.get_node("%NextLevelButton").visible, "after the buys Next level is back")
	expect_false(summary.get_node("%GuideNote").visible)
	main.free()


func test_the_map_route_has_the_same_next_level_rule() -> void:
	var main := _main()
	_after_level_zero(main.get_node("Profile"))
	main.call("_on_run_ended", _ended("first_watch", HoldfastRules.OUTCOME_WON, 2, 2))
	main.summary.get_node("%MapButton").pressed.emit()
	expect_true(main.journey.visible and main.journey.get_node("%Guide").visible, "the map shows the guide")
	expect_false(main.summary.get_node("%NextLevelButton").visible)
	main.free()


# ------------------------------------------------------------------ Refund all

func _with_spent_tree(main: Node) -> HoldfastProfile:
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["gold"] = 1000
	profile.data["stars"]["outpost"] = 3
	profile.changed.emit()
	TreeCard.buy(main.keep_screen, "post_drills")
	TreeCard.buy(main.keep_screen, "castle_slot_2")
	return profile


func test_refund_all_asks_first_and_changes_nothing_until_it_is_confirmed() -> void:
	var main := _main()
	var profile := _with_spent_tree(main)
	profile.begin_stand()
	var page: Control = main.keep_screen
	var owned_before := profile.get_upgrades().duplicate()
	page.get_node("%RespecButton").pressed.emit()
	expect_eq(profile.get_upgrades(), owned_before, "pressing Refund all takes nothing back")
	expect_true(page.get_node("%ConfirmButton").visible and page.get_node("%CancelButton").visible, "it asks")
	expect_false(page.get_node("%RespecButton").visible or page.get_node("%BackButton").visible, "and nothing else can be pressed by mistake")
	expect_true(page.get_node("%Info").text.contains("first castle slot and Archer Post stay"), page.get_node("%Info").text)
	page.get_node("%CancelButton").pressed.emit()
	expect_eq(profile.get_upgrades(), owned_before, "No keeps everything")
	expect_true(page.get_node("%RespecButton").visible and not page.get_node("%ConfirmButton").visible)
	page.get_node("%RespecButton").pressed.emit()
	page.get_node("%ConfirmButton").pressed.emit()
	expect_false("post_drills" in profile.get_upgrades() or "castle_slot_2" in profile.get_upgrades(), "Yes takes them back")
	expect_true("castle_slot_1" in profile.get_upgrades() and "castle_archer_1" in profile.get_upgrades(), "the tutorial buys stay")
	expect_eq(profile.get_guide_node(), "", "so the guide is not due again")
	expect_eq(profile.get_guided_step(), "")
	expect_false(page.get_node("%Guide").visible or main.journey.get_node("%Guide").visible, "and neither screen shows it")
	expect_true(profile.has_a_tower(), "the castle still has its post")
	expect_true(page.get_node("%RespecButton").visible and not page.get_node("%ConfirmButton").visible, "the question is gone")
	main.free()


func test_the_question_does_not_stay_open_when_the_page_is_left() -> void:
	var main := _main()
	_with_spent_tree(main)
	var page: Control = main.keep_screen
	page.visible = true
	page.get_node("%RespecButton").pressed.emit()
	page.visible = false
	expect_true(page.get_node("%RespecButton").visible and not page.get_node("%ConfirmButton").visible)
	main.free()


func test_refund_all_has_nothing_to_do_when_only_the_tutorial_buys_are_left() -> void:
	var main := _main()
	ThroughLevelZero.apply(main.get_node("Profile"))
	var page: Control = main.keep_screen
	expect_true(page.get_node("%RespecButton").disabled, "the two guided buys are not for taking back")
	expect_eq(page.get_node("%RespecButton").text, "Refund all")
	main.free()


# ------------------------------------------------------------------ comparable numbers

func test_a_link_card_says_its_effect_once_not_as_a_number_from_nothing() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	var page: Control = main.keep_screen
	page.open_card("link_posted_hand")
	var text: String = TreeCard.text(page)
	expect_false(text.contains("0 -> 0.1"), text)
	expect_false(text.to_lower().contains("hero near"), text)
	expect_true(text.contains("10% faster"), "the description carries it: " + text)
	page.open_card("post_sight")
	expect_true(TreeCard.text(page).contains("Range 170 -> 200"), "a plain stat still shows before and after: " + TreeCard.text(page))
	main.free()


# ------------------------------------------------------------------ the busiest summary

## A win on the last level with every line it can carry (the first-win reward and the stars line belong
## to Level 0, a loss has a tip instead).
func test_the_busiest_summary_still_fits_the_screen() -> void:
	var main := _main()
	var summary: Control = main.summary
	var notes := {"boss": "Fog Warden is beaten.", "unlocked": ["The Dusk Mage path is open on the Hero page."],
			"way_on": Guidance.MORE_COMING}
	summary.show_summary({"gold_earned": 90, "waves_cleared": 8, "total_waves": 8, "keep_fell": false, "stars_paid": 1, "notes": notes, "result": {"gear_found": ["wave_worn_boots", "storm_cap"]},
			"recruit_changes": [{"joined": true, "name": "Bryn", "class": "warden"}]}, "")
	summary.visible = true
	await tree.process_frame
	await tree.process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for node in [summary.get_node("Centre/Row/Panel"), summary.get_node("%TreeButton"), summary.get_node("%Moment")]:
		expect_true(screen.encloses(node.get_global_rect()), "%s at %s is on the 1280x720 screen" % [node.name, node.get_global_rect()])
	main.free()


func test_the_level_zero_summary_with_its_reward_and_notes_fits_the_screen() -> void:
	var main := _main()
	var summary: Control = main.summary
	summary.show_summary({"gold_earned": 50, "waves_cleared": 2, "total_waves": 2, "keep_fell": false, "stars_paid": 2, "reward_gold": 150,
			"stars_note": main.STARS_LINE, "notes": {"guide_note": Guidance.GUIDE_NOTE}, "result": {}}, "")
	summary.visible = true
	await tree.process_frame
	await tree.process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for node in [summary.get_node("Centre/Row/Panel"), summary.get_node("%TreeButton")]:
		expect_true(screen.encloses(node.get_global_rect()), "%s at %s is on the 1280x720 screen" % [node.name, node.get_global_rect()])
	main.free()
