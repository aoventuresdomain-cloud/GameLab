class_name SimController
extends RefCounted
## Supplies the input for each tick. A player controller turns devices into
## input; a bot controller decides from the rules' state. Either way the rules
## see the same Dictionary shape, so the headless run and the playable build
## share one set of rules.

## Seconds per tick; set by SimEngine when the controller is attached.
var dt := 0.0


## Returns the input for the tick about to run. Must not change `rules`.
func get_input(_rules: SimRules, _tick: int) -> Dictionary:
	return {}
