extends Node
## Holdfast's use of the kit Steam service: start it, pump callbacks, and unlock
## the test achievement when a run clears the level. A no-op wherever Steam is
## unavailable (web, headless, CI, Steam not running).

## Valve's public test app (Spacewar) until Holdfast has its own app ID.
const APP_ID := 480
## Spacewar's "win one game" achievement stands in for "clear the level".
const LEVEL_CLEARED_ACHIEVEMENT := "ACH_WIN_ONE_GAME"

@export var source_path: NodePath

var steam := SteamService.new()


func _ready() -> void:
	steam.init(APP_ID)
	get_node(source_path).run_ended.connect(_on_run_ended)


func _process(_delta: float) -> void:
	steam.poll()


func _on_run_ended(summary: Dictionary) -> void:
	if not summary.get("keep_fell", true):
		steam.unlock_achievement(LEVEL_CLEARED_ACHIEVEMENT)
