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


## What the between-waves banner says ("Wave N" just before it starts); "" otherwise.
func get_wave_banner() -> String:
	return ""


## Where the Archer Posts stand, shown until the first wave starts; "" when there is nothing to say.
func get_posts_note() -> String:
	return ""


## True while a teaching run stands still, its note up, waiting for the player's press.
func is_held() -> bool:
	return false


## The player's click, tap or key: a held run starts moving.
func release_hold() -> void:
	pass


## What a boss on the field says about its shroud, "" when there is none.
func get_boss_note() -> String:
	return ""


## The Hero's health now and at most.
func get_hero_health() -> int:
	return 0


func get_hero_health_max() -> int:
	return 0


## Seconds until the Hero's ability is ready; 0 when it is.
func get_ability_wait() -> float:
	return 0.0


## Seconds until a knocked-down Hero gets back up; 0 when they are up.
func get_hero_down_seconds() -> float:
	return 0.0


func get_towers_lost() -> int:
	return 0


func get_recruits_lost() -> int:
	return 0
