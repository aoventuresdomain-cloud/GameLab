extends Control
## Hero page: choose the Hero's path and wear the gear found so far (two slots, one piece in
## each). It shows the profile and asks for changes through signals; the run flow acts.
## Mouse only.

signal back_requested
signal tree_requested
signal pillar_requested(id: String)
signal gear_requested(id: String)

const Keep = preload("res://scripts/ui/keep_screen.gd")
const FONT_PX := 20
const DEFAULT_INFO := "Pick a path. Gear is the Hero's alone: press a piece to wear it, press it again to take it off."

## The Hero path id the profile has picked.
var selected_pillar := ""

@onready var _pillar_row: HBoxContainer = %PillarRow
@onready var _pillar_info: Label = %PillarInfo
@onready var _slots: Label = %Slots
@onready var _gear_row: HBoxContainer = %GearRow
@onready var _info: Label = %Info
@onready var _tree: Button = %TreeButton
@onready var _back: Button = %BackButton

var _profile: Node
var _content: Dictionary
var _pillar_buttons: Dictionary = {}


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_tree.pressed.connect(tree_requested.emit)
	visibility_changed.connect(_on_visibility_changed)
	_build_pillars()
	_info.text = DEFAULT_INFO


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	refresh()


## Asks for a Hero path; an unknown id changes nothing.
func select_pillar(id: String) -> void:
	pillar_requested.emit(id)


## Redraws everything from the profile.
func refresh() -> void:
	if _profile == null:
		return
	selected_pillar = _profile.get_pillar()
	for id in _pillar_buttons:
		_pillar_buttons[id].set_pressed_no_signal(id == selected_pillar)
	var path: Dictionary = _content["hero_paths"][selected_pillar]
	_pillar_info.text = "%s: %s" % [path["name"], path.get("blurb", "")]
	_tree.text = "Open the %s section of the skill tree" % path["name"]
	_refresh_gear()


## One toggle per gear item the player owns (lit when worn), or a hint that there is none yet.
func _refresh_gear() -> void:
	var worn: Dictionary = _profile.get_gear_worn()
	var parts: PackedStringArray = []
	for slot in HoldfastMeta.gear_slots(_content):
		var id: String = worn.get(slot, "")
		parts.append("%s: %s" % [str(slot).capitalize(), _content["gear_items"][id]["name"] if id != "" else "empty"])
	_slots.text = "   ".join(parts)
	for child in _gear_row.get_children():
		_gear_row.remove_child(child)
		child.queue_free()
	var owned: Array = _profile.get_gear_owned()
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", FONT_PX)
	caption.text = "Gear:" if not owned.is_empty() else "Gear: none yet. An elite on levels 2 and 3 drops the first piece."
	_gear_row.add_child(caption)
	for id in owned:
		var item: Dictionary = _content["gear_items"][id]
		var button := Button.new()
		button.text = str(item["name"])
		button.add_theme_font_size_override("font_size", FONT_PX)
		button.toggle_mode = true
		button.set_pressed_no_signal(worn.get(item["slot"], "") == id)
		button.pressed.connect(func() -> void: gear_requested.emit(id))
		button.mouse_entered.connect(func() -> void: _info.text = _gear_text(id, worn.get(item["slot"], "") == id))
		button.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
		_gear_row.add_child(button)


func _build_pillars() -> void:
	var group := ButtonGroup.new()
	for id in _content["hero_paths"]:
		var path: Dictionary = _content["hero_paths"][id]
		var button := Button.new()
		button.text = str(path["name"])
		button.add_theme_font_size_override("font_size", 24)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: pillar_requested.emit(id))
		button.mouse_entered.connect(func() -> void: _info.text = "%s: %s" % [path["name"], path.get("blurb", "")])
		button.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
		_pillar_row.add_child(button)
		_pillar_buttons[id] = button


func _gear_text(id: String, worn: bool) -> String:
	var item: Dictionary = _content["gear_items"][id]
	return "%s (%s): %s. %s." % [item["name"], item["slot"], Keep._effects_text(item["effects"]), "Worn, press to take off" if worn else "Not worn, press to wear"]


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_info.text = DEFAULT_INFO
		_back.grab_focus()
