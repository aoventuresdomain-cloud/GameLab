extends Control
## Squad page: the recruitment board, the roster and the squad. The roster is a set of cards (one for
## each Recruit: name and level, class, post and traits; the squad's say so) and a plain "?" for each
## Recruit not yet found; a line says how many deploy slots the squad uses. Pressing a card shows who
## they are below, where they are renamed and put on or taken off the squad. A Recruit with a skill pick waiting shows the two choices
## at the top, so a pick needs no screen of its own. The keep and the Hero are renamed here too.
## It shows the profile and asks for changes through signals; the run flow acts. Mouse only.

signal back_requested
signal squad_toggled(id: String)
signal hire_requested(index: int)
signal pick_requested(id: String, skill_id: String)
signal rename_requested(who: String, text: String)

const Hud = preload("res://scripts/ui/hud.gd")
const HUB_HEADER = preload("res://scenes/ui/hub_header.tscn")
const HUB_RAIL = preload("res://scenes/ui/hub_rail.tscn")
## Waiting picks shown at once; the rest follow as these are made.
const PICKS_SHOWN := 1
## A Recruit's card is at least this wide, so four fit a row.
const CARD_WIDTH := 270.0

var _profile: Node
var _content: Dictionary
var _selected := ""
var _building := false

## The rail on the left, which goes to the other hub screens.
var rail: HubRail
var _back: Button
var _title: Label
var _gold: Label
var _stars: Label
var _keep_name: LineEdit
var _hero_name: LineEdit
var _picks: VBoxContainer
var _roster: HFlowContainer
var _slots_line: Label
## The roster's cards by Recruit id, and the "?" cards for those not found.
var _cards := {}
var _unfound: Array = []
var _detail_name: LineEdit
var _detail_text: Label
var _squad_button: Button
var _board: HFlowContainer
var _board_note: Label


func _ready() -> void:
	_content = HoldfastContent.base()
	var backdrop := ColorRect.new()
	backdrop.color = UiTokens.colour(&"night")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var header: Control = HUB_HEADER.instantiate()
	column.add_child(header)
	# Everything under the header sits right of the rail.
	var inset := MarginContainer.new()
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_left", int(HubRail.CONTENT_MARGIN))
	column.add_child(inset)
	# A full roster and board are taller than the screen: the page scrolls, never squeezes.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inset.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	_back = header.get_node("BackButton")
	_back.pressed.connect(back_requested.emit)
	_title = header.get_node("Title")
	_gold = header.get_node("GoldChip/Row/GoldValue")
	_stars = header.get_node("StarsChip/Row/StarsValue")

	# The keep's and the Hero's names sit in the header, beside the title.
	var names: HBoxContainer = header.get_node("Extra")
	names.add_theme_constant_override("separation", 8)
	names.add_child(_label("Keep"))
	_keep_name = _name_box("keep")
	names.add_child(_keep_name)
	names.add_child(_label("Hero"))
	_hero_name = _name_box("hero")
	names.add_child(_hero_name)

	_picks = VBoxContainer.new()
	_picks.add_theme_constant_override("separation", 8)
	body.add_child(_picks)

	_slots_line = _label("")
	body.add_child(_slots_line)
	_roster = HFlowContainer.new()
	_roster.add_theme_constant_override("h_separation", 6)
	_roster.add_theme_constant_override("v_separation", 8)
	body.add_child(_roster)

	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	body.add_child(detail)
	_detail_name = LineEdit.new()
	_detail_name.custom_minimum_size = Vector2(220, 0)
	_detail_name.max_length = RecruitRoster.NAME_MAX
	_detail_name.text_submitted.connect(func(_text: String) -> void: _detail_name.release_focus())
	_detail_name.focus_exited.connect(func() -> void: _rename(_selected, _detail_name.text))
	detail.add_child(_detail_name)
	_detail_text = _label("")
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(200, 0)
	detail.add_child(_detail_text)
	_squad_button = _button("Add to squad")
	_squad_button.pressed.connect(func() -> void: squad_toggled.emit(_selected))
	detail.add_child(_squad_button)

	_board_note = _label("")
	_board_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_board_note)
	_board = HFlowContainer.new()
	_board.add_theme_constant_override("h_separation", 8)
	_board.add_theme_constant_override("v_separation", 8)
	body.add_child(_board)
	rail = HUB_RAIL.instantiate()
	rail.current = "Squad"
	add_child(rail)
	visibility_changed.connect(_on_visibility_changed)


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	refresh()


## Redraws everything from the profile.
func refresh() -> void:
	if _profile == null or _building or _roster == null:
		return
	_building = true
	_gold.text = Hud.format_number(_profile.get_gold())
	_stars.text = str(_profile.get_stars())
	_title.text = "Squad"
	_slots_line.text = slots_text(_profile.get_squad_ids().size(), _profile.get_squad_slots())
	_set_text(_keep_name, _profile.get_given_name("keep"), _profile.get_name_of("keep"))
	_set_text(_hero_name, _profile.get_given_name("hero"), _profile.get_name_of("hero"))
	_fill_picks()
	_fill_roster()
	_fill_detail()
	_fill_board()
	_building = false


## Puts `given` in a name box the player is not typing in (the default shows as a hint).
func _set_text(box: LineEdit, given: String, default: String) -> void:
	box.placeholder_text = default
	if not box.has_focus():
		box.text = given


func _fill_picks() -> void:
	for child in _picks.get_children():
		_picks.remove_child(child)
		child.queue_free()
	var waiting: Array = _profile.get_pending_picks()
	for pick in waiting.slice(0, PICKS_SHOWN):
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		row.add_child(_label("%s picks:" % pick["name"]))
		for skill_id in pick["options"]:
			var skill: Dictionary = _content["recruit_skills"][skill_id]
			var button := _button("%s: %s" % [skill["name"], skill["text"]])
			button.pressed.connect(func() -> void: pick_requested.emit(pick["id"], skill_id))
			row.add_child(button)
		_picks.add_child(row)
	if waiting.size() > PICKS_SHOWN:
		_picks.add_child(_label(more_picks_text(waiting.size() - PICKS_SHOWN)))


## "2 slots, 1 used": the squad's deploy places and how many hold a Recruit.
static func slots_text(used: int, total: int) -> String:
	return "%d %s, %d used" % [total, "slot" if total == 1 else "slots", used]


static func more_picks_text(count: int) -> String:
	return "%d more %s waiting for a pick." % [count, "Recruit is" if count == 1 else "Recruits are"]


func _fill_roster() -> void:
	for child in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	_cards.clear()
	_unfound.clear()
	var roster: Array = _profile.get_recruits()
	if _selected == "" or _profile.get_recruit(_selected).is_empty():
		_selected = str(roster[0]["id"]) if not roster.is_empty() else ""
	for recruit in roster:
		var button := _button(card_text(recruit))
		button.toggle_mode = true
		button.button_pressed = recruit["id"] == _selected
		button.icon = shape_icon(_content["recruit_classes"][recruit["class"]])
		button.custom_minimum_size = Vector2(CARD_WIDTH, 0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select.bind(str(recruit["id"])))
		_roster.add_child(button)
		_cards[str(recruit["id"])] = button
	# A Recruit not yet found is a plain "?": no class, no name, no picture.
	for rescue in _content.get("recruit_rescues", {}).values():
		if _profile.get_recruit(str(rescue["id"])).is_empty():
			var card := PanelContainer.new()
			card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
			var mark := _label("?")
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(mark)
			_roster.add_child(card)
			_unfound.append(card)


## A card's lines: "Bryn, level 3", the class, the post (or that they are off the squad) and the traits.
func card_text(recruit: Dictionary) -> String:
	var id := str(recruit["id"])
	var traits := PackedStringArray()
	for trait_id in recruit["traits"]:
		traits.append(str(_content["recruit_traits"][trait_id]["name"]))
	var post := "Off the squad"
	if id in _profile.get_squad_ids():
		var where := post_name(id)
		post = "Post: %s" % where if where != "" else "On the squad, no post"
	return "%s, level %d\n%s\n%s\n%s" % [recruit["name"], RecruitRoster.level_of(recruit, _content), _content["recruit_classes"][recruit["class"]]["name"], post, ", ".join(traits) if not traits.is_empty() else "No trait yet"]


## The name of the spot a Recruit's post stands on ("" when they have none).
func post_name(id: String) -> String:
	var posted: Dictionary = _profile.get_posted()
	for site in posted:
		if posted[site] == id:
			for castle in _content.get("castle_rules", {}).values():
				for spot in castle["spots"]:
					if str(spot["id"]) == site:
						return str(spot["name"])
	return ""


func _select(id: String) -> void:
	_selected = id
	refresh()


func _fill_detail() -> void:
	var recruit: Dictionary = _profile.get_recruit(_selected)
	_detail_name.editable = not recruit.is_empty()
	# With nobody hired there is no name to edit: no empty box.
	_detail_name.visible = not recruit.is_empty()
	_squad_button.visible = not recruit.is_empty()
	if recruit.is_empty():
		_detail_name.text = ""
		_detail_text.text = ""
		return
	_set_text(_detail_name, str(recruit["name"]), str(recruit["name"]))
	var cls: Dictionary = _content["recruit_classes"][recruit["class"]]
	var lines := PackedStringArray(["%s, level %d. %s" % [cls["name"], RecruitRoster.level_of(recruit, _content), cls["text"]]])
	var traits := PackedStringArray()
	for id in recruit["traits"]:
		traits.append("%s (%s)" % [_content["recruit_traits"][id]["name"], _content["recruit_traits"][id]["text"]])
	var skills := PackedStringArray()
	for id in recruit["skills"]:
		skills.append(str(_content["recruit_skills"][id]["name"]))
	lines.append("Traits: %s. Skills: %s." % [", ".join(traits) if not traits.is_empty() else "none", ", ".join(skills) if not skills.is_empty() else "none yet"])
	_detail_text.text = "\n".join(lines)
	var on_squad: bool = _selected in _profile.get_squad_ids()
	_squad_button.text = "Take off squad" if on_squad else "Add to squad"
	var why: String = "" if on_squad else _profile.why_not_squad(_selected)
	_squad_button.disabled = why != ""
	_squad_button.tooltip_text = why
	_board_note.text = why
	_board_note.visible = why != ""


func _fill_board() -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	var offers: Array = _profile.get_board()
	for offer in offers:
		var cls: Dictionary = _content["recruit_classes"][offer["class"]]
		var trait_data: Dictionary = _content["recruit_traits"][offer["traits"][0]]
		var button := _button("Hire %s, %s (%s gold)\n%s: %s" % [offer["name"], cls["name"], ShortNumber.exact(int(offer["cost"])), trait_data["name"], trait_data["text"]])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = shape_icon(cls)
		var why: String = _profile.why_not_hire(int(offer["index"]))
		button.disabled = why != ""
		button.tooltip_text = why
		button.pressed.connect(func() -> void: hire_requested.emit(int(offer["index"])))
		_board.add_child(button)
	if offers.is_empty():
		_board.add_child(_label("Nobody is left on the board. New faces come after the next run."))


func _rename(who: String, text: String) -> void:
	if _building or who == "":
		return
	rename_requested.emit(who, text)


func _name_box(who: String) -> LineEdit:
	var box := LineEdit.new()
	box.custom_minimum_size = Vector2(180, 0)
	box.max_length = RecruitRoster.NAME_MAX
	box.text_submitted.connect(func(_text: String) -> void: box.release_focus())
	box.focus_exited.connect(func() -> void: _rename(who, box.text))
	return box


## A class's shape in its colour, the same polygon as the Recruit on the field.
static func shape_icon(cls: Dictionary) -> ImageTexture:
	var size := 28
	var sides: int = cls["sides"]
	var colour := UiTokens.pack_colour(str(cls["colour"]))
	var edge := UiTokens.colour(&"night")
	var clear := UiTokens.colour(&"night", 0.0)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle := Vector2(size, size) * 0.5
	var reach := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - middle
			var outer := true
			var inner := true
			for i in sides:
				var normal := Vector2.from_angle(-PI / 2.0 + TAU * (float(i) + 0.5) / float(sides))
				outer = outer and p.dot(normal) <= reach * cos(PI / float(sides))
				inner = inner and p.dot(normal) <= (reach - 2.5) * cos(PI / float(sides))
			image.set_pixel(x, y, colour if inner else (edge if outer else clear))
	return ImageTexture.create_from_image(image)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_back.grab_focus()
