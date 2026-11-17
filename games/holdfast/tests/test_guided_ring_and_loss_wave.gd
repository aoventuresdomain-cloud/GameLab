extends KitTestCase
## HF-M2-85: while a guided buy is due only the guided step shows the amber buyable ring or opens a detail
## card (F-195, HF-M2-38), and a loss panel states its wave once (F-196).

const Main := preload("res://scenes/main.tscn")


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


## A profile that has won Level 0 and has made `bought` of the guided buys.
func _guided(main: Node, bought: Array) -> HoldfastProfile:
	var content := HoldfastContent.base()
	var data := HoldfastMeta.new_profile(content)
	data = HoldfastMeta.bank_run(content, data, {"outcome": "won", "level": HoldfastMeta.tutorial_level(content), "gold": 0})
	data["gold"] = 5000
	for id in bought:
		data = HoldfastMeta.buy(content, data, id)["profile"]
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data = data
	profile.changed.emit()
	return profile


func _ringed(page: Control) -> Array:
	var out := []
	for id in page._node_buttons:
		if page._node_buttons[id].visible and page._marks[id].get_meta("state", "far") == "open":
			out.append(id)
	return out


func _opens_a_card(page: Control, id: String) -> bool:
	page.close_card()
	page._node_clicked(id)
	return page._card.visible and page._card_id == id


func test_on_the_first_step_only_the_slot_is_ringed_and_opens() -> void:
	var main := _main()
	_guided(main, [])
	var page: Control = main.keep_screen
	expect_eq(_ringed(page), ["castle_slot_1"])
	expect_true(_opens_a_card(page, "castle_slot_1"), "the step opens its card")
	for id in page._node_buttons:
		if id != "castle_slot_1":
			expect_false(_opens_a_card(page, id), "%s opens nothing" % id)
	main.free()


func test_on_the_second_step_slot_two_has_no_ring_and_no_card() -> void:
	var main := _main()
	_guided(main, ["castle_slot_1"])
	var page: Control = main.keep_screen
	expect_eq(_ringed(page), ["castle_archer_1"], "only the Archer Post is ringed")
	expect_true(_opens_a_card(page, "castle_archer_1"), "the step opens its card")
	expect_false(_opens_a_card(page, "castle_slot_2"), "Slot II opens nothing")
	expect_false(page._card.visible, "and no card is left up from the step")
	expect_false(_opens_a_card(page, "castle_slot_1"), "even a node already owned stays shut until the guide is done")
	main.free()


func test_a_click_on_slot_two_with_the_guided_card_up_closes_it_and_buys_nothing() -> void:
	var main := _main()
	var profile := _guided(main, ["castle_slot_1"])
	var page: Control = main.keep_screen
	page._node_clicked("castle_archer_1")
	expect_true(page._card.visible)
	page._node_clicked("castle_slot_2")
	expect_false(page._card.visible, "the guided card goes, no card for Slot II")
	expect_eq(profile.get_upgrades(), ["castle_slot_1"], "nothing was bought")
	main.free()


func test_once_the_guide_is_done_slot_two_is_ringed_and_opens_again() -> void:
	var main := _main()
	var profile := _guided(main, ["castle_slot_1", "castle_archer_1"])
	profile.data["stars"]["outpost"] = 3
	profile.changed.emit()
	var page: Control = main.keep_screen
	expect_eq(profile.get_guided_step(), "")
	expect_true("castle_slot_2" in _ringed(page), "Slot II shows its ring once it is buyable")
	expect_true(_opens_a_card(page, "castle_slot_2"), "and opens its card")
	main.free()


# ------------------------------------------------------------------ F-196

func _wave_figures(summary: Control) -> Array:
	var out := []
	for label in summary.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.text.to_lower().contains("wave"):
			out.append(label.text)
	return out


func test_a_loss_states_its_wave_once() -> void:
	var main := _main()
	var summary: Control = main.summary
	summary.show_summary({"gold_earned": 40, "waves_cleared": 3, "total_waves": 5, "keep_fell": true})
	main.call("_show", main.Screen.SUMMARY)
	expect_eq(_wave_figures(summary), ["The keep fell in wave 4 of 5."], "one line, one figure")
	expect_false(summary.get_node("%WavesValue").get_parent().visible, "no Waves row beside it")
	main.free()


func test_a_win_still_shows_the_waves_cleared() -> void:
	var main := _main()
	var summary: Control = main.summary
	summary.show_summary({"gold_earned": 40, "waves_cleared": 5, "total_waves": 5, "keep_fell": false})
	main.call("_show", main.Screen.SUMMARY)
	expect_true(summary.get_node("%WavesValue").get_parent().visible)
	expect_eq(summary.get_node("%WavesValue").text, "5 / 5")
	summary.show_summary({"gold_earned": 40, "waves_cleared": 3, "total_waves": 5, "keep_fell": true})
	expect_false(summary.get_node("%WavesValue").get_parent().visible, "a loss after a win hides it again")
	summary.show_summary({"gold_earned": 40, "waves_cleared": 5, "total_waves": 5, "keep_fell": false})
	expect_true(summary.get_node("%WavesValue").get_parent().visible, "and a win after a loss brings it back")
	main.free()
