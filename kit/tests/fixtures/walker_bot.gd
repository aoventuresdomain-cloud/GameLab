extends SimController
## Test fixture: aims at the first walker, read from the rules' state only.


func get_input(rules: SimRules, _tick: int) -> Dictionary:
	var walkers: Array[Vector2] = rules.get("walkers")
	var first := walkers[0]
	return {"x": first.x + 3.0, "y": first.y - 3.0}
