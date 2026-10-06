extends "res://scripts/ui/run_state_source.gd"
## Stand-in run for building the UI before the real rules land (HF-M1-01).
## Fakes waves, gold drops and keep damage from a seeded generator. Replace it
## in scenes/main.tscn with the kit-engine adapter; the UI does not change.

@export var total_waves := 5
@export var wave_seconds := 6.0
@export var keep_health_max := 100
@export var rng_seed := 1
## When false, nothing moves until step() is called (used by tests).
@export var auto_step := true

const TICK := 0.25

var _rng := RandomNumberGenerator.new()
var _running := false
var _gold := 0
var _keep := 0
var _wave := 0
var _wave_time := 0.0
var _tick_time := 0.0
var _runs := 0


func _process(delta: float) -> void:
	if auto_step:
		step(delta)


func start_run() -> void:
	_runs += 1
	_rng.seed = rng_seed + _runs
	_running = true
	_gold = 0
	_keep = keep_health_max
	_wave = 1
	_wave_time = 0.0
	_tick_time = 0.0
	run_started.emit()
	gold_changed.emit(_gold)
	keep_health_changed.emit(_keep, keep_health_max)
	wave_changed.emit(_wave, total_waves)


func step(delta: float) -> void:
	if not _running:
		return
	_tick_time += delta
	while _running and _tick_time >= TICK:
		_tick_time -= TICK
		_tick()


func _tick() -> void:
	_gold += _rng.randi_range(1, 2 + _wave)
	gold_changed.emit(_gold)
	if _rng.randf() < 0.08 * _wave:
		_keep = maxi(_keep - _rng.randi_range(2, 6), 0)
		keep_health_changed.emit(_keep, keep_health_max)
		if _keep == 0:
			_end(true)
			return
	_wave_time += TICK
	if _wave_time >= wave_seconds:
		_wave_time = 0.0
		if _wave >= total_waves:
			_end(false)
			return
		_wave += 1
		wave_changed.emit(_wave, total_waves)


func _end(keep_fell: bool) -> void:
	_running = false
	run_ended.emit({
		"gold_earned": _gold,
		"waves_cleared": _wave - 1 if keep_fell else _wave,
		"total_waves": total_waves,
		"keep_fell": keep_fell,
	})


func is_running() -> bool:
	return _running


func get_gold() -> int:
	return _gold


func get_keep_health() -> int:
	return _keep


func get_keep_health_max() -> int:
	return keep_health_max


func get_wave() -> int:
	return _wave


func get_total_waves() -> int:
	return total_waves
