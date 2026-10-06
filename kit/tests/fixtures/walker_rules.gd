extends SimRules
## Test fixture: walkers take random steps toward a target the input sets.

var walkers: Array[Vector2] = []
var score := 0.0
var steps := 0
var limit := 0
var rng: SimRng


func setup(config: Dictionary, p_rng: SimRng) -> void:
	rng = p_rng
	limit = int(config.get("limit", 300))
	for i in int(config.get("walkers", 5)):
		walkers.append(Vector2(rng.range_float(-100.0, 100.0), rng.range_float(-100.0, 100.0)))


func step(dt: float, input: Dictionary) -> void:
	var target := Vector2(float(input.get("x", 0.0)), float(input.get("y", 0.0)))
	for i in walkers.size():
		var jitter := Vector2(rng.range_float(-1.0, 1.0), rng.range_float(-1.0, 1.0))
		walkers[i] += (target - walkers[i]) * dt + jitter
		score += 1.0 / (1.0 + walkers[i].distance_to(target))
	steps += 1


func is_finished() -> bool:
	return steps >= limit


func snapshot() -> Dictionary:
	var positions := []
	for w in walkers:
		positions.append([w.x, w.y])
	return {"walkers": positions, "score": score, "steps": steps}
