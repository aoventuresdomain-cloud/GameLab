extends Node
## Read-only view of a run, for the HUD and the run flow screens.
##
## The UI binds to this and nothing else: it listens to the signals and calls
## the get_* accessors, and never writes to the rules' state. Whatever drives the
## run (the stub today, the kit-engine adapter from HF-M1-01 later) extends this
## script, emits the signals and overrides the accessors.
##
## start_run() is the one command. Only the game layer (scripts/run_flow.gd)
## calls it, in answer to a UI request signal; UI scripts never do.

signal run_started
signal gold_changed(gold: int)
signal keep_health_changed(current: int, maximum: int)
signal wave_changed(wave: int, total: int)
## summary keys: gold_earned (int), waves_cleared (int), total_waves (int),
## keep_fell (bool).
signal run_ended(summary: Dictionary)


func start_run() -> void:
	push_error("RunStateSource.start_run() is not implemented by %s" % get_script().resource_path)


func is_running() -> bool:
	return false


func get_gold() -> int:
	return 0


func get_keep_health() -> int:
	return 0


func get_keep_health_max() -> int:
	return 0


## 1-based number of the current wave; 0 before the first wave starts.
func get_wave() -> int:
	return 0


func get_total_waves() -> int:
	return 0
