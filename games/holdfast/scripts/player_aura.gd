class_name HoldfastPlayerAura
extends SimController
## The player's aura: whatever world position the mouse is over, sampled once
## per tick. The playable build sets `cursor` every frame.

## World position under the mouse, or null when the mouse is off the field.
var cursor: Variant = null


func get_input(_rules: SimRules, _tick: int) -> Dictionary:
	if cursor is Vector2:
		var at: Vector2 = cursor
		return {"aura": [at.x, at.y]}
	return {}
