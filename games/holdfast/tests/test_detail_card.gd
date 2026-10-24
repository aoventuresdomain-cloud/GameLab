extends KitTestCase
## HF-M2-43: the skill tree has no bottom strip; pressing a node opens a detail card over the dimmed
## tree that shows only that node, and the card is where it is bought or taken back.

const Main := preload("res://scenes/main.tscn")


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


## The flow with the castle's two guided buys made, the tree page open, and `gold` in the purse.
func _tree(gold := 1000) -> Array:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply_castle(profile)
	profile.data["gold"] = gold
	profile.changed.emit()
	main.keep_screen.visible = true
	return [main, main.keep_screen, profile]


func _escape(page: Control) -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	page._input(event)


# ------------------------------------------------------------------ the page

func test_the_bottom_strip_is_gone_and_a_hover_is_a_small_name_and_effect_tooltip() -> void:
	var made := _tree()
	var page: Control = made[1]
	expect_true(page.get_node_or_null("%NextUnlocks") == null, "no strip of what is next")
	var tip: String = page._node_buttons["post_sight"].tooltip_text
	expect_eq(tip, "Archer sights: +30 range".replace("Archer sights", str(HoldfastContent.base()["upgrade_nodes"]["post_sight"]["name"])))
	expect_false(tip.contains("120"), "the price is for the card")
	made[0].free()


func test_pressing_a_node_opens_its_card_over_the_dimmed_tree_and_buys_nothing() -> void:
	var made := _tree()
	var page: Control = made[1]
	var profile: HoldfastProfile = made[2]
	expect_false(page._card.visible, "closed to begin with")
	var upgrades: Array = profile.get_upgrades().duplicate()
	page._node_buttons["post_sight"].pressed.emit()
	expect_true(page._card.visible)
	expect_eq(page._card_title.text, str(HoldfastContent.base()["upgrade_nodes"]["post_sight"]["name"]))
	expect_eq(profile.get_upgrades(), upgrades, "opening a card buys nothing")
	expect_true(page._card.get_child(0).color.a > 0.4, "the tree behind is dimmed")
	expect_eq(page._card.mouse_filter, Control.MOUSE_FILTER_STOP, "and cannot be pressed through it")
	made[0].free()


func test_an_unknown_node_opens_no_card() -> void:
	var made := _tree()
	var page: Control = made[1]
	page.open_card("no_such_node")
	expect_false(page._card.visible, "nothing to show, so nothing opens")
	made[0].free()


func test_the_card_closes_on_the_cross_a_press_outside_escape_and_a_controller_b() -> void:
	var made := _tree()
	var page: Control = made[1]
	page.open_card("post_sight")
	page._card_close.pressed.emit()
	expect_false(page._card.visible, "the cross")
	page.open_card("post_sight")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	page._card.gui_input.emit(outside)
	expect_false(page._card.visible, "a press outside the card")
	expect_eq(page._card_panel.mouse_filter, Control.MOUSE_FILTER_STOP, "a press on the card itself is not outside")
	page.open_card("post_sight")
	_escape(page)
	expect_false(page._card.visible, "escape and the controller's B, which are both ui_cancel")
	made[0].free()


func test_the_card_shows_only_its_node_and_nothing_about_nodes_further_ahead() -> void:
	var made := _tree()
	var page: Control = made[1]
	var nodes: Dictionary = HoldfastContent.base()["upgrade_nodes"]
	page.open_card("post_sight")
	var shown: String = TreeCard.text(page)
	expect_true(shown.contains(str(nodes["post_sight"]["name"])))
	for id in nodes:
		if "post_sight" in nodes[id].get("requires", []):
			expect_false(shown.contains(str(nodes[id]["name"])), "%s is further ahead" % id)
	made[0].free()


# ------------------------------------------------------------------ the effect line

func test_the_effect_line_has_the_stat_before_and_after() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1"]
	var lines := HoldfastMeta.effect_lines(content, profile, "post_sight")
	expect_eq(lines.size(), 1)
	expect_eq(lines[0]["stat"], "tower.range")
	expect_eq(lines[0]["before"], 170.0, "the Archer Post's own range")
	expect_eq(lines[0]["after"], 200.0)
	var hero := HoldfastMeta.effect_lines(content, profile, "flare_hide")
	expect_eq([hero[0]["before"], hero[0]["after"]], [60.0, 80.0], "the Hero's health")
	var keep := HoldfastMeta.effect_lines(content, profile, "keep_walls_1")
	expect_eq([keep[0]["before"], keep[0]["after"]], [0.0, 25.0], "a stat with no base starts at nothing")
	# Bought, the same line reads from the tree without the node, so it is still before and after.
	profile["upgrades"].append("post_sight")
	var again := HoldfastMeta.effect_lines(content, profile, "post_sight")
	expect_eq([again[0]["before"], again[0]["after"]], [170.0, 200.0])
	profile["upgrades"].append("post_scope")
	expect_eq(HoldfastMeta.effect_lines(content, profile, "post_scope")[0]["before"], 200.0, "a later node counts the earlier ones")


func test_the_card_writes_the_change_and_an_owned_node_just_its_value() -> void:
	var made := _tree()
	var page: Control = made[1]
	page.open_card("post_sight")
	expect_true(TreeCard.text(page).contains("Range 170 -> 200"), TreeCard.text(page))
	TreeCard.buy(page, "post_sight")
	expect_true(TreeCard.text(page).contains("Range 200"), TreeCard.text(page))
	expect_false(TreeCard.text(page).contains("->"), "owned: the value it gives")
	made[0].free()


# ------------------------------------------------------------------ buying

func test_the_card_buys_and_stays_with_a_tick_a_glow_and_the_neighbours_lit() -> void:
	var made := _tree(5000)
	var page: Control = made[1]
	var profile: HoldfastProfile = made[2]
	page.open_card("post_sight")
	expect_true(page._card_buy.visible and not page._card_buy.disabled)
	expect_false(page._card_tick.visible)
	page._card_buy.pressed.emit()
	expect_true("post_sight" in profile.get_upgrades(), "bought")
	expect_eq(profile.get_gold(), 5000 - 120)
	expect_true(page._card.visible, "the card stays")
	expect_true(page._card_tick.visible and page._card_refund.visible and not page._card_buy.visible, "with a tick and a Refund")
	expect_eq(page._card_style.border_color, page.COLOUR_ACT, "and a brief glow")
	expect_true("post_scope" in page._glowing, "the node it opened lights up behind it")
	expect_false("post_sight" in page._glowing)
	made[0].free()


func test_an_unaffordable_node_has_a_dimmed_buy_and_a_cue_besides_the_colour() -> void:
	var made := _tree(100)
	var page: Control = made[1]
	var profile: HoldfastProfile = made[2]
	page.open_card("post_sight")
	expect_true(page._card_buy.disabled, "dimmed")
	expect_true(page._card_price.text.contains("120") and page._card_price.text.contains("need 20 more"), page._card_price.text)
	expect_eq(page._card_price.get_theme_color("font_color"), page.COLOUR_SHORT, "price in red")
	page._card_buy.pressed.emit()
	expect_false("post_sight" in profile.get_upgrades())
	expect_false(page._card_note.visible and page._card_note.text != "", "no sentence for a want of gold")
	made[0].free()


func test_a_node_refused_for_another_reason_says_so_on_the_card() -> void:
	var made := _tree()
	var page: Control = made[1]
	page.open_card("gate_mage")
	expect_true(page._card_buy.disabled)
	expect_true(page._card_note.text.contains("Needs 3 more nodes owned"), page._card_note.text)
	made[0].free()


# ------------------------------------------------------------------ taking one back

func test_the_rules_take_one_node_back_for_its_price_less_the_fee() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1", "post_sight"]
	profile["gold"] = 50
	expect_eq(HoldfastMeta.refund_gain(content, "post_sight"), {"gold": 100, "stars": 0}, "120 less the fee")
	expect_eq(HoldfastMeta.why_not_refund_node(content, profile, "post_sight"), "")
	var after := HoldfastMeta.refund_node(content, profile, "post_sight")
	expect_eq(after["gold"], 150)
	expect_eq(after["upgrades"], ["castle_slot_1", "castle_archer_1"])
	expect_eq(profile["upgrades"].size(), 3, "the profile given is untouched")
	expect_eq(HoldfastMeta.refund_gain(content, "castle_slot_1"), {"gold": -50, "stars": 1}, "a star node frees its stars for a flat fee")


func test_the_two_guided_buys_and_a_node_something_needs_cannot_be_taken_back() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1", "post_sight", "post_scope"]
	profile["gold"] = 1000
	expect_eq(HoldfastMeta.why_not_refund_node(content, profile, "castle_slot_1"), "Needed to start")
	expect_eq(HoldfastMeta.why_not_refund_node(content, profile, "castle_archer_1"), "Needed to start")
	expect_eq(HoldfastMeta.why_not_refund_node(content, profile, "post_sight"), "Needed by %s" % content["upgrade_nodes"]["post_scope"]["name"])
	expect_eq(HoldfastMeta.why_not_refund_node(content, profile, "post_drills"), "Not bought")
	expect_eq(HoldfastMeta.refund_node(content, profile, "castle_slot_1"), profile, "refused: unchanged")
	# A gate that needs five nodes owned apart from itself cannot be left standing on four.
	var gated := HoldfastMeta.new_profile(content)
	gated["upgrades"] = ["castle_slot_1", "castle_archer_1", "post_sight", "keep_walls_1", "post_timbers", "gate_mage"]
	gated["gold"] = 1000
	expect_eq(HoldfastMeta.why_not_refund_node(content, gated, "keep_walls_1"), "Needed by %s" % content["upgrade_nodes"]["gate_mage"]["name"], "the gate counts the nodes owned")
	gated["upgrades"].append("post_drills")
	expect_eq(HoldfastMeta.why_not_refund_node(content, gated, "keep_walls_1"), "", "with a node to spare it can go")


func test_a_fee_the_purse_cannot_pay_stops_a_refund() -> void:
	var content := HoldfastContent.base()
	var profile := HoldfastMeta.new_profile(content)
	profile["upgrades"] = ["castle_slot_1", "castle_archer_1", "castle_slot_2"]
	profile["gold"] = 49
	expect_eq(HoldfastMeta.why_not_refund_node(content, profile, "castle_slot_2"), "Not enough gold for the refund fee")
	profile["gold"] = 50
	expect_eq(HoldfastMeta.why_not_refund_node(content, profile, "castle_slot_2"), "")


func test_an_owned_card_shows_what_comes_back_in_bold_and_refunds_it() -> void:
	var made := _tree(5000)
	var page: Control = made[1]
	var profile: HoldfastProfile = made[2]
	TreeCard.buy(page, "post_sight")
	expect_true(page._card_price.text == "+100 gold", page._card_price.text)
	expect_true(page._card_price.get_theme_font("font") is FontVariation, "in bold")
	page._card_refund.pressed.emit()
	expect_false("post_sight" in profile.get_upgrades(), "refunded")
	expect_eq(profile.get_gold(), 5000 - 120 + 100)
	expect_true(page._card_buy.visible and not page._card_refund.visible, "the card is the unowned one again")
	made[0].free()


func test_the_card_of_a_guided_buy_has_a_refund_that_is_shut() -> void:
	var made := _tree()
	var page: Control = made[1]
	page.open_card("castle_slot_1")
	expect_true(page._card_refund.visible and page._card_refund.disabled)
	expect_eq(page._card_note.text, "Needed to start")
	made[0].free()


func test_a_refund_waits_until_the_run_is_over() -> void:
	var made := _tree(5000)
	var main: Node = made[0]
	var page: Control = made[1]
	var profile: HoldfastProfile = made[2]
	TreeCard.buy(page, "post_sight")
	var notes := []
	profile.notice.connect(func(text: String) -> void: notes.append(text))
	main.call("_start_run")
	expect_true(main.get_node("RunSource").is_running())
	page.refund_requested.emit("post_sight")
	expect_true("post_sight" in profile.get_upgrades(), "not taken back mid-run")
	expect_eq(notes, ["A refund waits until the run is over."])
	main.free()


# ------------------------------------------------------------------ special cards

func test_a_fork_says_what_it_replaces() -> void:
	var made := _tree()
	var page: Control = made[1]
	var forked: Dictionary = HoldfastContent.base().duplicate(true)
	forked["upgrade_nodes"]["post_scope"]["excludes"] = ["post_twin"]
	forked["upgrade_nodes"]["post_twin"]["excludes"] = ["post_scope"]
	made[2]._content = forked
	page._content = forked
	page.open_card("post_scope")
	expect_true(TreeCard.text(page).contains("Replaces %s" % forked["upgrade_nodes"]["post_twin"]["name"]), TreeCard.text(page))
	made[0].free()


func test_the_tower_gate_shows_three_tower_cards_and_only_the_mage_is_built() -> void:
	var made := _tree()
	var page: Control = made[1]
	page.open_card("gate_mage")
	var row: Control = page._card_extra.get_node("GateCards")
	expect_eq(row.get_child_count(), 3)
	expect_eq(row.get_child(0).get_child_count(), 1, "the Mage Post has its name")
	expect_eq(row.get_child(0).get_child(0).text, "Mage post")
	expect_eq(row.get_child(1).get_child_count() + row.get_child(2).get_child_count(), 0, "the others are dark silhouettes with no text")
	made[0].free()


func test_a_link_node_names_the_two_things_it_joins() -> void:
	var made := _tree()
	var page: Control = made[1]
	page.open_card("link_eclipse")
	expect_true(TreeCard.text(page).contains("Joins Dusk Mage and Mage post"), TreeCard.text(page))
	made[0].free()


# ------------------------------------------------------------------ keys and the controller

func test_the_focus_goes_to_buy_on_open_and_back_to_the_node_on_close() -> void:
	var made := _tree()
	var page: Control = made[1]
	var node: Button = page._node_buttons["post_sight"]
	node.grab_focus()
	node.pressed.emit()
	expect_true(page._card_buy.has_focus(), "A on a node opens the card and the next A buys")
	_escape(page)
	expect_true(node.has_focus(), "B closes it and the focus is back where it was")
	page.open_card("gate_mage")
	expect_true(page._card_close.has_focus(), "with nothing to press, the cross")
	made[0].free()


func test_an_owned_card_opens_on_the_cross_never_on_refund() -> void:
	var made := _tree(5000)
	var page: Control = made[1]
	var profile: HoldfastProfile = made[2]
	profile.data["stars"]["outpost"] = 3
	for id in ["post_sight", "keep_walls_1", "post_timbers", "post_drills", "post_rate"]:
		profile.buy(id)
	expect_true(profile.buy("gate_mage"), "the Tower Gate is owned too")
	var refunds: Array = []
	page.refund_requested.connect(func(id: String) -> void: refunds.append(id))
	for id in ["post_sight", "gate_mage"]:
		page.open_card(id)
		expect_true(page._card_refund.visible, "%s is owned and can be taken back" % id)
		expect_true(page._card_close.has_focus(), "%s: the cross has the focus" % id)
		expect_false(page._card_refund.has_focus(), "%s: Refund does not, so Enter or a second A cannot take it back" % id)
		page._card_close.pressed.emit()
		expect_false(page._card.visible, "and the press closes it")
	expect_eq(refunds, [], "nothing was taken back")
	made[0].free()


func test_the_focus_outline_is_blue_and_neither_the_act_nor_the_done_colour() -> void:
	var made := _tree()
	var page: Control = made[1]
	var open: StyleBoxFlat = page._node_buttons["post_sight"].get_theme_stylebox("focus")
	var owned: StyleBoxFlat = page._node_buttons["castle_slot_1"].get_theme_stylebox("focus")
	expect_eq(open.border_color, page.COLOUR_FOCUS)
	expect_eq(owned.border_color, page.COLOUR_FOCUS)
	expect_true(page.COLOUR_FOCUS != page.COLOUR_ACT and page.COLOUR_FOCUS != page.OWNED_EDGE)
	expect_eq(page._card_buy.get_theme_stylebox("focus").border_color, page.COLOUR_FOCUS)
	made[0].free()


func test_the_page_behind_the_card_cannot_take_the_focus() -> void:
	var made := _tree()
	var page: Control = made[1]
	page.open_card("post_sight")
	expect_eq(page.get_node("Margin").focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	page.close_card()
	expect_eq(page.get_node("Margin").focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED)
	made[0].free()


func test_the_card_fits_at_both_window_sizes_in_readable_type() -> void:
	var made := _tree(5000)
	var page: Control = made[1]
	for window in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = window
		await tree.process_frame
		var scale := float(window.y) / 720.0
		for id in ["post_sight", "gate_mage", "castle_slot_1", "link_eclipse"]:
			page.open_card(id)
			await tree.process_frame
			await tree.process_frame
			var view := tree.root.get_visible_rect()
			expect_true(view.encloses(page._card_panel.get_global_rect()), "%s at %s fits" % [id, window])
			for control in _controls(page._card_panel):
				var px := roundi(control.get_theme_font_size("font_size") * scale)
				expect_true(px >= 20, "%s: '%s' is %d px" % [id, control.text, px])
	made[0].free()


func _controls(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if (child is Label or child is Button) and child.is_visible_in_tree():
			out.append(child)
		out.append_array(_controls(child))
	return out
