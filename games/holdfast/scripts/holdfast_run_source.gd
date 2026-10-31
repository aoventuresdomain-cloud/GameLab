class_name HoldfastRunSource
extends "res://scripts/ui/run_state_source.gd"
## Drives a Holdfast run in the playable build: owns the kit SimEngine with
## Holdfast's rules and feeds it frame time. It never steps the rules itself;
## SimEngine.advance() runs whole fixed ticks only, so a seeded run with the bot
## Hero ends exactly as it does headless (tests/test_holdfast_rules.gd).
##
## The UI reads it through run_state_source.gd's signals and get_* accessors; the
## world view reads get_rules() and get_engine() for drawing.

@export var level_id := HoldfastContent.DEFAULT_LEVEL
@export var rng_seed := 1
## The Hero path to play ("" for the level's own).
@export var hero_path := ""
## Let the bot play the Hero instead of the keyboard (tests, attract mode).
@export var use_bot := false
## Replaces the keyboard and the bot, for tests and replays of recorded inputs.
var controller_override: SimController = null
## When false, nothing moves until step() is called (used by tests).
@export var auto_step := true
## When false, a refused run is not logged as an error (tests that cause one).
var report_errors := true

var upgrades: Array = []
## The Archer Post sites or castle spots to build on (null: the level's default layout).
var layout: Variant = null
## True for the tutorial's stand: a short fight on the castle's own posts after the two guided buys.
var stand := false
## The blessing picked for the run ("" for none).
var blessing := ""
## The Recruits that go on the run (null: the level's own two, as the rules tests have them).
var squad: Variant = null
## The Recruit set on each castle spot's post, {spot id: Recruit id} (see RecruitMeta).
var posted: Dictionary = {}
## True when a run that has a teaching note waits for a click, tap or key before it starts moving.
var wait_for_press := false
## What the Hero wears ({slot: item id}) and what the player owns, so a drop is new.
var gear: Dictionary = {}
var gear_owned: Array = []

var _engine: SimEngine
var _rules: HoldfastRules
var _player := HoldfastPlayerHero.new()
var _running := false
## A teaching run stands still, note up, until the player presses; then it never holds again.
var _held := false
## The pause screen is up: nothing moves, and the keyboard is not read.
var _paused := false
## 1 or 2: how much game time passes for each frame of real time.
var _speed := 1
var _runs := 0
var _last := {}


## Longest frame time fed to the engine at once; a longer hitch slows the game
## down rather than letting it jump ahead.
const MAX_FRAME_SECONDS := 0.25


func _ready() -> void:
	HoldfastPlayerHero.ensure_actions()


func _process(delta: float) -> void:
	if auto_step and not _held and not _paused:
		_player.sample()
		step(minf(delta, MAX_FRAME_SECONDS) * _speed)


## Starts a run. With a fixed rng_seed, play-again runs use rng_seed + run number.
## Refuses (no run_started, nothing running) when the rules reject the setup,
## for example an unknown level.
func start_run() -> void:
	var content := HoldfastContent.base()
	if content.is_empty():
		push_error("Holdfast: cannot start a run without valid content")
		return
	var run_seed := rng_seed + _runs
	_runs += 1
	var rules := HoldfastRules.new()
	rules.report_errors = report_errors
	var controller: SimController = controller_override
	if controller == null:
		controller = HoldfastHeroBot.new() if use_bot else _player
	var engine := SimEngine.new(rules, controller, run_seed, HoldfastContent.run_config(level_id, upgrades, content, hero_path, layout, gear, gear_owned, stand, squad, blessing, posted), HoldfastRules.TICK_RATE)
	if rules.setup_error != "":
		if report_errors:
			push_error("Holdfast: cannot start a run: " + rules.setup_error)
		return
	_rules = rules
	_engine = engine
	_running = true
	_held = wait_for_press and (rules.tutorial or rules.stand)
	_paused = false
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


## What the keyboard says right now, for tests and replays: the Hero's move
## direction and whether Space was pressed since the last tick.
func set_hero_input(move: Vector2, ability_pressed: bool) -> void:
	_player.move = move
	_player.ability_pressed = _player.ability_pressed or ability_pressed


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


## True while a teaching run waits for the player's press.
func is_held() -> bool:
	return _held


func is_paused() -> bool:
	return _paused


## Pauses or resumes a run in progress; with none running it does nothing.
func set_paused(paused: bool) -> void:
	_paused = paused and _running


func get_speed() -> int:
	return _speed


## 2 for double speed, anything else 1. The rules tick the same either way: only the game time fed per frame changes.
func set_speed(speed: int) -> void:
	_speed = 2 if speed == 2 else 1


## Ends the run without a result: nothing is banked or paid and no run_ended is sent.
func leave_run() -> void:
	if not _running:
		return
	_running = false
	_paused = false
	_held = false
	run_left.emit()


## The player's click, tap or key: the run starts moving.
func release_hold() -> void:
	_held = false


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


func get_wave_banner() -> String:
	return _rules.wave_banner() if _rules else ""


## How many posts stand, until the first wave starts; a tutorial says its teaching
## text instead ("" when there is nothing to say).
func get_posts_note() -> String:
	if _rules == null or _rules.wave > 0:
		return ""
	var content := HoldfastContent.base()
	if (_rules.stand or _rules.tutorial) and wait_for_press and not _held:
		return ""
	if _rules.stand:
		return str(content["levels"][_rules.level_id]["stand"]["intro"])
	if _rules.tutorial:
		return str(content["levels"][_rules.level_id].get("intro", ""))
	if _rules.layout_ids.is_empty():
		return ""
	return "Posts: %d" % _rules.layout_ids.size()


## While a boss is on the field: whether its shroud is up and what lifts it.
func get_boss_note() -> String:
	if _rules == null:
		return ""
	for enemy in _rules.enemies:
		if enemy.required_ability != "" and enemy.health > 0.0:
			var name := str(HoldfastContent.base()["enemies"][enemy.type]["name"])
			if enemy.exposed_left > 0.0:
				return "%s exposed: %d s" % [name, ceili(enemy.exposed_left)]
			return "%s shrouded: use your special" % name
	return ""


## Read-only use: drawing and tests. Never step or change it.
func get_rules() -> HoldfastRules:
	return _rules


func get_engine() -> SimEngine:
	return _engine


func get_hero_health() -> int:
	return ceili(float(_rules.hero_state["health"])) if _rules else 0


func get_hero_health_max() -> int:
	return ceili(float(_rules.hero_state["max_health"])) if _rules else 0


func get_ability_wait() -> float:
	return _rules.hero_ability_ready_in if _rules else 0.0


func get_hero_down_seconds() -> float:
	return float(_rules.hero_state["get_up_in"]) if _rules and _rules.hero_state["downed"] else 0.0


func get_towers_lost() -> int:
	return _rules.towers_lost if _rules else 0


func get_recruits_lost() -> int:
	return _rules.recruits_downed if _rules else 0
