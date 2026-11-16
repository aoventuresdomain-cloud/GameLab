extends ColorRect
## A full-screen backdrop in one of the theme's colour tokens, so no screen writes a colour of its own.

@export var token: StringName = &"night"
@export var alpha := 1.0


func _ready() -> void:
	color = UiTokens.colour(token, alpha)
