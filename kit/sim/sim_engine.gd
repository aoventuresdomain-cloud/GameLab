class_name SimEngine
extends RefCounted
## Fixed-timestep driver for a game's SimRules.
##
## Headless runs call step() or run_to_end() directly. The playable build calls
## advance() once per frame with the frame time; it only ever runs whole fixed
## ticks, so a seeded run reaches exactly the same states whatever the frame
## rate. Rendering reads the rules' state (and interpolation_alpha()) but never
## steps the rules itself.

signal ticked(tick: int)
signal finished(result: Dictionary)

const DEFAULT_TICK_RATE := 30
## Most ticks one advance() call will run; the rest of a long frame is dropped
## (the game slows down rather than freezing to catch up).
const MAX_TICKS_PER_ADVANCE := 8

var rules: SimRules
var controller: SimController
var rng: SimRng
var tick_rate: int
var tick := 0

var _dt: float
var _accumulator := 0.0
var _finished_emitted := false


func _init(p_rules: SimRules, p_controller: SimController, p_seed: int, p_config: Dictionary = {}, p_tick_rate: int = DEFAULT_TICK_RATE) -> void:
	assert(p_rules != null, "SimEngine needs rules")
	assert(p_tick_rate > 0, "tick rate must be positive")
	rules = p_rules
	controller = p_controller
	tick_rate = p_tick_rate
	_dt = 1.0 / p_tick_rate
	if controller != null:
		controller.dt = _dt
	rng = SimRng.new(p_seed)
	rules.setup(p_config, rng)


## Seconds per tick.
func get_dt() -> float:
	return _dt


## Simulated seconds so far.
func get_time() -> float:
	return tick * _dt


func is_finished() -> bool:
	return rules.is_finished()


## Runs one fixed tick. Does nothing once the rules are finished.
func step() -> void:
	if rules.is_finished():
		return
	var input: Dictionary = controller.get_input(rules, tick) if controller != null else {}
	rules.step(_dt, input)
	tick += 1
	ticked.emit(tick)
	if rules.is_finished() and not _finished_emitted:
		_finished_emitted = true
		finished.emit(rules.result())


## Runs as many whole ticks as `real_delta` seconds of frame time cover. Returns
## the number of ticks run.
func advance(real_delta: float) -> int:
	if rules.is_finished():
		return 0
	_accumulator += maxf(real_delta, 0.0)
	var steps := 0
	while _accumulator >= _dt and steps < MAX_TICKS_PER_ADVANCE and not rules.is_finished():
		_accumulator -= _dt
		step()
		steps += 1
	if steps == MAX_TICKS_PER_ADVANCE:
		_accumulator = minf(_accumulator, _dt)
	return steps


## How far the frame is between the last tick and the next, 0 to 1, for smooth drawing.
func interpolation_alpha() -> float:
	return clampf(_accumulator / _dt, 0.0, 1.0)


## Steps until the rules finish or `max_ticks` ticks have run. Returns ticks run.
func run_to_end(max_ticks: int) -> int:
	var start := tick
	while not rules.is_finished() and tick - start < max_ticks:
		step()
	return tick - start


## SHA-256 of the rules' snapshot plus the engine's own state.
func state_hash() -> String:
	return SimEngine.hash_data({"tick": tick, "rng": rng.get_state(), "rules": rules.snapshot()})


## SHA-256 of JSON-safe data, with keys sorted and floats at full precision, so
## equal data always gives an equal hash.
static func hash_data(data: Variant) -> String:
	return JSON.stringify(data, "", true, true).sha256_text()
