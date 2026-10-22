extends Control
## Title screen. Pick a Hero pillar, then ask for a run; the game layer starts it.

signal play_requested

## The Hero path id the player has picked (from the pack's hero_paths).
var selected_pillar := ""

@onready var _play_button: Button = %PlayButton
@onready var _pillar_row: HBoxContainer = %PillarRow
@onready var _pillar_blurb: Label = %PillarBlurb

var _paths: Dictionary = {}
var _buttons: Dictionary = {}


func _ready() -> void:
	_play_button.pressed.connect(play_requested.emit)
	visibility_changed.connect(_on_visibility_changed)
	_paths = HoldfastContent.base().get("hero_paths", {})
	var group := ButtonGroup.new()
	for id in _paths:
		var button := Button.new()
		button.text = str(_paths[id]["name"])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(200, 0)
		button.pressed.connect(select_pillar.bind(id))
		_pillar_row.add_child(button)
		_buttons[id] = button
	if not _paths.is_empty():
		select_pillar(_paths.keys()[0])


## Picks a Hero path by id; an unknown id changes nothing.
func select_pillar(id: String) -> void:
	if not _paths.has(id):
		return
	selected_pillar = id
	_buttons[id].button_pressed = true
	_pillar_blurb.text = str(_paths[id].get("blurb", ""))


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_play_button.grab_focus()
