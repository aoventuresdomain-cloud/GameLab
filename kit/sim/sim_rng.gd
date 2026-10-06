class_name SimRng
extends RefCounted
## Seeded random numbers for simulation rules. The same seed always gives the
## same sequence. Rules must draw every random number from the SimRng they are
## given and never from the global random functions.

var seed_value: int
var _rng := RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	_rng.seed = p_seed


## A float in [0, 1).
func next_float() -> float:
	return _rng.randf()


func range_float(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## An int in [from, to], both included.
func range_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## True with the given probability.
func chance(probability: float) -> bool:
	return _rng.randf() < probability


## The generator's position in its sequence, for snapshots and saves.
func get_state() -> int:
	return _rng.state


func set_state(state: int) -> void:
	_rng.state = state
