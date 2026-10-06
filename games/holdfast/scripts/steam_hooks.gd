extends Node
## Holdfast's use of the kit Steam service: start it, pump callbacks, and unlock
## the test achievement when a run clears the level. A no-op wherever Steam is
## unavailable (web, headless, CI, Steam not running).

## Valve's public test app (Spacewar) until Holdfast has its own app ID.
const APP_ID := 480
## Spacewar's "win one game" achievement stands in for "clear the level".
const LEVEL_CLEARED_ACHIEVEMENT := "ACH_WIN_ONE_GAME"

## Opt-in flag for a manual Steam check: clears the test achievement at startup so
## the next won run shows the unlock again. Only honoured for Valve's test app.
const RESET_FLAG := "--steam-reset-test-achievement"
## Steam may need a moment after init before it accepts the clear (real seconds;
## autoplay speeds up game time).
const RESET_RETRY_MSEC := 5000

@export var source_path: NodePath

var steam := SteamService.new()
var _reset_pending := false
var _reset_deadline_msec := 0


func _ready() -> void:
	steam.init(APP_ID)
	get_node(source_path).run_ended.connect(_on_run_ended)
	start_reset(OS.get_cmdline_user_args())


## Clears the test achievement when the reset flag allows it, retrying for a few
## seconds; does nothing without Steam.
func start_reset(user_args: PackedStringArray) -> void:
	if not resets_test_achievement(APP_ID, user_args) or not steam.is_available():
		return
	_reset_pending = true
	_reset_deadline_msec = Time.get_ticks_msec() + RESET_RETRY_MSEC
	_try_reset()


func _process(_delta: float) -> void:
	steam.poll()
	if _reset_pending:
		_try_reset()


func _try_reset() -> void:
	if steam.clear_achievement(LEVEL_CLEARED_ACHIEVEMENT):
		_reset_pending = false
	elif Time.get_ticks_msec() >= _reset_deadline_msec:
		_reset_pending = false
		print("[steam] could not clear %s; it may already show as unlocked" % LEVEL_CLEARED_ACHIEVEMENT)


## True only when the reset flag was passed and the app is Valve's test app (480);
## a real app's achievements are never cleared, whatever the command line says.
static func resets_test_achievement(app_id: int, user_args: PackedStringArray) -> bool:
	return app_id == 480 and RESET_FLAG in user_args


func _on_run_ended(summary: Dictionary) -> void:
	if clears_level(summary):
		steam.unlock_achievement(LEVEL_CLEARED_ACHIEVEMENT)


## Only a won run clears the level; a lost or invalid run never unlocks it.
static func clears_level(summary: Dictionary) -> bool:
	return summary.get("result", {}).get("outcome") == HoldfastRules.OUTCOME_WON
