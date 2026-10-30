extends Control
## Recruits page: the recruitment board, the roster and the squad. The roster is a row of chips (one
## for each Recruit, the squad's marked); pressing one shows who they are below, where they are
## renamed and put on or taken off the squad. A Recruit with a skill pick waiting shows the two choices
## at the top, so a pick needs no screen of its own. The keep and the Hero are renamed here too.
## It shows the profile and asks for changes through signals; the run flow acts. Mouse only.

signal back_requested
signal squad_toggled(id: String)
signal hire_requested(index: int)
signal pick_requested(id: String, skill_id: String)
signal rename_requested(who: String, text: String)

const Hud = preload("res://scripts/ui/hud.gd")
const FONT_PX := 20
## Waiting picks shown at once; the rest follow as these are made.
const PICKS_SHOWN := 1

var _profile: Node
var _content: Dictionary
var _selected := ""
var _building := false

var _back: Button
var _title: Label
var _gold: Label
var _keep_name: LineEdit
var _hero_name: LineEdit
var _picks: VBoxContainer
var _roster: HFlowContainer
var _detail_name: LineEdit
var _detail_text: Label
var _squad_button: Button
var _board: HBoxContainer
var _board_note: Label


func _ready() -> void:
	_content = HoldfastContent.base()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.1, 0.12, 0.16, 1)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_back = _button("Back")
	_back.pressed.connect(back_requested.emit)
	header.add_child(_back)
	_title = _label("Recruits")
	_title.theme_type_variation = &"HudValue"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_gold = _label("")
	header.add_child(_gold)

	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 8)
	column.add_child(names)
	names.add_child(_label("Keep"))
	_keep_name = _name_box("keep")
	names.add_child(_keep_name)
	names.add_child(_label("Hero"))
	_hero_name = _name_box("hero")
	names.add_child(_hero_name)

	_picks = VBoxContainer.new()
	_picks.add_theme_constant_override("separation", 4)
	column.add_child(_picks)

	_roster = HFlowContainer.new()
	_roster.add_theme_constant_override("h_separation", 6)
	_roster.add_theme_constant_override("v_separation", 4)
	column.add_child(_roster)

	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	column.add_child(detail)
	_detail_name = LineEdit.new()
	_detail_name.custom_minimum_size = Vector2(220, 0)
	_detail_name.max_length = RecruitRoster.NAME_MAX
	_detail_name.add_theme_font_size_override("font_size", FONT_PX)
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
	column.add_child(_board_note)
	_board = HBoxContainer.new()
	_board.add_theme_constant_override("separation", 8)
	column.add_child(_board)
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
	_gold.text = "Gold %s" % Hud.format_number(_profile.get_gold())
	_title.text = "Recruits: squad %d of %d (marked *)" % [_profile.get_squad_ids().size(), _profile.get_squad_slots()]
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
		row.add_child(_label("%s picks:" % pick["name"]))
		for skill_id in pick["options"]:
			var skill: Dictionary = _content["recruit_skills"][skill_id]
			var button := _button("%s: %s" % [skill["name"], skill["text"]])
			button.pressed.connect(func() -> void: pick_requested.emit(pick["id"], skill_id))
			row.add_child(button)
		_picks.add_child(row)
	if waiting.size() > PICKS_SHOWN:
		_picks.add_child(_label("%d more Recruits have a pick waiting." % (waiting.size() - PICKS_SHOWN)))


func _fill_roster() -> void:
	for child in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	var roster: Array = _profile.get_recruits()
	if _selected == "" or _profile.get_recruit(_selected).is_empty():
		_selected = str(roster[0]["id"]) if not roster.is_empty() else ""
	for recruit in roster:
		var on_squad: bool = recruit["id"] in _profile.get_squad_ids()
		var button := _button("%s %d%s" % [recruit["name"], RecruitRoster.level_of(recruit, _content), " *" if on_squad else ""])
		button.toggle_mode = true
		button.button_pressed = recruit["id"] == _selected
		button.icon = shape_icon(_content["recruit_classes"][recruit["class"]])
		button.pressed.connect(_select.bind(str(recruit["id"])))
		_roster.add_child(button)


func _select(id: String) -> void:
	_selected = id
	refresh()


func _fill_detail() -> void:
	var recruit: Dictionary = _profile.get_recruit(_selected)
	_detail_name.editable = not recruit.is_empty()
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
	_board_note.text = why if why != "" else ""


func _fill_board() -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	var offers: Array = _profile.get_board()
	for offer in offers:
		var cls: Dictionary = _content["recruit_classes"][offer["class"]]
		var trait_data: Dictionary = _content["recruit_traits"][offer["traits"][0]]
		var button := _button("Hire %s, %s (%s gold)\n%s: %s" % [offer["name"], cls["name"], Hud.format_number(int(offer["cost"])), trait_data["name"], trait_data["text"]])
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
	box.custom_minimum_size = Vector2(220, 0)
	box.max_length = RecruitRoster.NAME_MAX
	box.add_theme_font_size_override("font_size", FONT_PX)
	box.text_submitted.connect(func(_text: String) -> void: box.release_focus())
	box.focus_exited.connect(func() -> void: _rename(who, box.text))
	return box


## A class's shape in its colour, the same polygon as the Recruit on the field.
static func shape_icon(cls: Dictionary) -> ImageTexture:
	var size := 28
	var sides: int = cls["sides"]
	var colour := Color(str(cls["colour"]))
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
			image.set_pixel(x, y, colour if inner else (Color.BLACK if outer else Color(0, 0, 0, 0)))
	return ImageTexture.create_from_image(image)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", FONT_PX)
	return button


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_PX)
	return label


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_back.grab_focus()
