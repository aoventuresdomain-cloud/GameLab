class_name SimRules
extends RefCounted
## Base class for a game's simulation rules, driven by SimEngine.
##
## Rules hold the whole game state as plain data and change it only in step().
## To stay deterministic they must not read the clock, the scene tree, input
## devices or rendering, and must draw random numbers only from the SimRng
## passed to setup(). Input arrives as a Dictionary from a SimController, so a
## bot and a player drive exactly the same code.


## Builds the starting state. `config` is game-defined data (content, level, upgrades).
func setup(_config: Dictionary, _rng: SimRng) -> void:
	pass


## Advances the state by one fixed tick of `dt` seconds.
func step(_dt: float, _input: Dictionary) -> void:
	pass


## True once the run is over; the engine stops stepping.
func is_finished() -> bool:
	return true


## The full state as JSON-safe data (no objects). Used for the determinism hash,
## so it must include everything that affects later ticks.
func snapshot() -> Dictionary:
	return {}


## The run's outcome as JSON-safe data, for reports and tests.
func result() -> Dictionary:
	return snapshot()
