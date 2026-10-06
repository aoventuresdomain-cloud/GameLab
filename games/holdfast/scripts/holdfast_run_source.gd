class_name HoldfastRunSource
extends "res://scripts/ui/run_state_source.gd"
## Drives a Holdfast run in the playable build: owns the kit SimEngine with
## Holdfast's rules and feeds it frame time. It never steps the rules itself;
## SimEngine.advance() runs whole fixed ticks only, so a seeded run with the bot
## aura ends exactly as it does headless (tests/test_holdfast_rules.gd).
##
## The UI reads it through run_state_source.gd's signals and get_* accessors; the
## world view reads get_rules() and get_engine() for drawing.

@export var level_id := HoldfastContent.DEFAULT_LEVEL
@export var rng_seed := 1
## Let the bot drive the aura instead of the mouse (tests, attract mode).
@export var use_bot := false
## When false, nothing moves until step() is called (used by tests).
@export var auto_step := true

var upgrades: Array = []

var _engine: SimEngine
var _rules: HoldfastRules
var _player := HoldfastPlayerAura.new()
var _running := false
var _runs := 0
var _last := {}


## Longest frame time fed to the engine at once; a longer hitch slows the game
## down rather than letting it jump ahead.
const MAX_FRAME_SECONDS := 0.25


func _process(delta: float) -> void:
	if auto_step:
		step(minf(delta, MAX_FRAME_SECONDS))


## Starts a run. With a fixed rng_seed, play-again runs use rng_seed + run number.
func start_run() -> void:
	var content := HoldfastContent.base()
	if content.is_empty():
		push_error("Holdfast: cannot start a run without valid content")
		return
	var run_seed := rng_seed + _runs
	_runs += 1
	_rules = HoldfastRules.new()
	var controller: SimController = HoldfastAuraBot.new() if use_bot else _player
	_engine = SimEngine.new(_rules, controller, run_seed, HoldfastContent.run_config(level_id, upgrades, content), HoldfastRules.TICK_RATE)
	_running = true
	_last = {}
	run_started.emit()
	_emit_changes()


## Feeds `delta` seconds of frame time to the engine. Any length works (tools
## and tests pass whole seconds); it is fed in slices the engine never caps.
func step(delta: float) -> void:
	if not _running:
		return
	var left := delta
	while left > 0.0 and not _rules.is_finished():
		var slice := minf(left, MAX_FRAME_SECONDS)
		_engine.advance(slice)
		left -= slice
	_emit_changes()
	if _rules.is_finished():
		_running = false
		var result := _rules.result()
		run_ended.emit({
			"gold_earned": result["gold"],
			"waves_cleared": result["waves_cleared"],
			"total_waves": result["total_waves"],
			"keep_fell": result["outcome"] == HoldfastRules.OUTCOME_LOST,
			"result": result,
		})


## Where the mouse is, in world coordinates (the keep is at the origin), or null.
func set_cursor(world_position: Variant) -> void:
	_player.cursor = world_position


func _emit_changes() -> void:
	if _last.get("gold") != _rules.gold:
		_last["gold"] = _rules.gold
		gold_changed.emit(_rules.gold)
	if _last.get("keep") != _rules.keep_health:
		_last["keep"] = _rules.keep_health
		keep_health_changed.emit(_rules.keep_health, _rules.keep_health_max)
	if _last.get("wave") != _rules.wave:
		_last["wave"] = _rules.wave
		wave_changed.emit(_rules.wave, _rules.total_waves)


func is_running() -> bool:
	return _running


func get_gold() -> int:
	return _rules.gold if _rules else 0


func get_keep_health() -> int:
	return _rules.keep_health if _rules else 0


func get_keep_health_max() -> int:
	return _rules.keep_health_max if _rules else 0


func get_wave() -> int:
	return _rules.wave if _rules else 0


func get_total_waves() -> int:
	return _rules.total_waves if _rules else 0


## Read-only use: drawing and tests. Never step or change it.
func get_rules() -> HoldfastRules:
	return _rules


func get_engine() -> SimEngine:
	return _engine
