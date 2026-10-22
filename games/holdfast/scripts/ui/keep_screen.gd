extends Control
## Keep screen, the hub between runs: pick a level, pick a Hero pillar, spend gold
## on the upgrade tree, start a run. It shows the profile and asks for changes
## through signals; the run flow acts on them. Mouse only.

signal play_requested
signal home_requested
signal buy_requested(id: String)
signal level_requested(id: String)
signal pillar_requested(id: String)

const Hud = preload("res://scripts/ui/hud.gd")
const FONT_PX := 20
const BRANCHES := [
	["towers", "Towers"],
	["keep", "Keep"],
	["gold", "Gold"],
	["unlocks", "Levels"],
]
const STAT_TEXT := {
	"tower_damage": "tower damage",
	"tower_health": "tower health",
	"tower_repair": "tower repair a second between waves",
	"keep_health": "keep health",
	"beam_reach": "beam reach: enemies start further out",
	"gold_multiplier": "gold from kills",
	"aura_dps": "aura damage",
	"aura_radius": "aura size",
	"staff_damage": "staff damage",
}

## The Hero path id and level id the profile has picked.
var selected_pillar := ""
var selected_level := ""

@onready var _gold: Label = %GoldValue
@onready var _level_row: HBoxContainer = %LevelRow
@onready var _pillar_row: HBoxContainer = %PillarRow
@onready var _tree_row: HBoxContainer = %TreeRow
@onready var _info: Label = %Info
@onready var _back: Button = %BackButton
@onready var _play: Button = %PlayButton

var _profile: Node
var _content: Dictionary
var _level_buttons: Dictionary = {}
var _pillar_buttons: Dictionary = {}
var _node_buttons: Dictionary = {}
var _default_info := "Pick a level and a Hero, spend gold on upgrades, then start a run."


func _ready() -> void:
	_content = HoldfastContent.base()
	_play.pressed.connect(play_requested.emit)
	_back.pressed.connect(home_requested.emit)
	visibility_changed.connect(_on_visibility_changed)
	_build_levels()
	_build_pillars()
	_build_tree()
	_info.text = _default_info


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	profile.notice.connect(show_info)
	refresh()


## Asks for a Hero pillar; an unknown id changes nothing.
func select_pillar(id: String) -> void:
	pillar_requested.emit(id)


func show_info(text: String) -> void:
	_info.text = text


## Redraws everything from the profile.
func refresh() -> void:
	if _profile == null:
		return
	_gold.text = Hud.format_number(_profile.get_gold())
	selected_pillar = _profile.get_pillar()
	selected_level = _profile.get_level()
	var unlocked: Array = _profile.get_unlocked_levels()
	for id in _level_buttons:
		var button: Button = _level_buttons[id]
		var open: bool = id in unlocked
		var name := str(_content["levels"][id]["name"])
		button.disabled = not open
		if not open:
			name += " (locked)"
		elif _profile.is_level_won(id):
			name += " (won)"
		button.text = name
		button.set_pressed_no_signal(id == selected_level)
	for id in _pillar_buttons:
		_pillar_buttons[id].set_pressed_no_signal(id == selected_pillar)
	var owned: Array = _profile.get_upgrades()
	for id in _node_buttons:
		var node: Dictionary = _content["upgrade_nodes"][id]
		var button: Button = _node_buttons[id]
		var bought: bool = id in owned
		button.text = "%s (bought)" % node["name"] if bought else "%s  %d" % [node["name"], int(node["cost"])]
		button.disabled = bought or _profile.why_not_buy(id) != ""
		button.set_pressed_no_signal(bought)


func _build_levels() -> void:
	var group := ButtonGroup.new()
	for id in _content["levels"]:
		var button := _button(str(_content["levels"][id]["name"]))
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: level_requested.emit(id))
		button.mouse_entered.connect(func() -> void: show_info(_level_text(id)))
		button.mouse_exited.connect(_show_default)
		_level_row.add_child(button)
		_level_buttons[id] = button


func _build_pillars() -> void:
	var group := ButtonGroup.new()
	for id in _content["hero_paths"]:
		var path: Dictionary = _content["hero_paths"][id]
		var button := _button(str(path["name"]))
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: pillar_requested.emit(id))
		button.mouse_entered.connect(func() -> void: show_info("%s: %s" % [path["name"], path.get("blurb", "")]))
		button.mouse_exited.connect(_show_default)
		_pillar_row.add_child(button)
		_pillar_buttons[id] = button


func _build_tree() -> void:
	for branch in BRANCHES:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 2)
		var heading := Label.new()
		heading.text = branch[1]
		heading.add_theme_font_size_override("font_size", FONT_PX)
		heading.theme_type_variation = &"HudCaption"
		column.add_child(heading)
		for id in _content["upgrade_nodes"]:
			var node: Dictionary = _content["upgrade_nodes"][id]
			if node["branch"] != branch[0]:
				continue
			var button := _button(str(node["name"]))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(func() -> void: buy_requested.emit(id))
			button.mouse_entered.connect(func() -> void: show_info(_node_text(id)))
			button.mouse_exited.connect(_show_default)
			column.add_child(button)
			_node_buttons[id] = button
		_tree_row.add_child(column)


## A compact button at the screen's text size: the theme's button look with slim margins.
func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", FONT_PX)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(style_name).duplicate()
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(style_name, style)
	return button


func _show_default() -> void:
	_info.text = _default_info


func _level_text(id: String) -> String:
	var level: Dictionary = _content["levels"][id]
	var waves: Array = level["waves"]
	var open: bool = _profile != null and id in _profile.get_unlocked_levels()
	return "%s: %d waves. %s" % [level["name"], waves.size(), "" if open else "Locked: buy its unlock in the Levels column."]


func _node_text(id: String) -> String:
	var node: Dictionary = _content["upgrade_nodes"][id]
	var parts: PackedStringArray = []
	for effect in node.get("effects", []):
		var what: String = STAT_TEXT.get(str(effect["stat"]), str(effect["stat"]))
		if effect.has("add"):
			parts.append("+%s %s" % [_trim(float(effect["add"])), what])
		if effect.has("multiply"):
			parts.append("x%s %s" % [_trim(float(effect["multiply"])), what])
	if node.has("unlocks"):
		parts.append("opens %s" % _content["levels"][node["unlocks"]]["name"])
	var text := "%s: %s. Cost %d." % [node["name"], ", ".join(parts), int(node["cost"])]
	if _profile == null:
		return text
	if id in _profile.get_upgrades():
		return text + " Bought."
	var reason: String = _profile.why_not_buy(id)
	return text if reason == "" else "%s %s." % [text, reason]


static func _trim(value: float) -> String:
	return str(int(value)) if value == floorf(value) else str(value)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_show_default()
		_play.grab_focus()
