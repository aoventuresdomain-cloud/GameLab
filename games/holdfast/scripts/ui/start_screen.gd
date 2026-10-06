extends Control
## Title screen. Asks for a run; the game layer starts it.

signal play_requested

@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	_play_button.pressed.connect(play_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_play_button.grab_focus()
