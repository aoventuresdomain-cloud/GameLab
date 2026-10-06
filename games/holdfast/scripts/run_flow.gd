extends Node
## Run flow: start screen -> run (HUD) -> summary -> play again.
## Game layer, not UI: it is the only place that tells the run source to start.

enum Screen { START, RUN, SUMMARY }

@export var source_path: NodePath
@export var start_screen_path: NodePath
@export var hud_path: NodePath
@export var summary_path: NodePath

@onready var source: Node = get_node(source_path)
@onready var start_screen: Control = get_node(start_screen_path)
@onready var hud: Control = get_node(hud_path)
@onready var summary: Control = get_node(summary_path)

var screen := Screen.START


func _ready() -> void:
	hud.bind(source)
	start_screen.play_requested.connect(_start_run)
	summary.play_again_requested.connect(_start_run)
	source.run_ended.connect(_on_run_ended)
	_show(Screen.START)


func _start_run() -> void:
	if source.is_running():
		return
	_show(Screen.RUN)
	source.start_run()


func _on_run_ended(result: Dictionary) -> void:
	summary.show_summary(result)
	_show(Screen.SUMMARY)


func _show(next: Screen) -> void:
	screen = next
	start_screen.visible = next == Screen.START
	hud.visible = next == Screen.RUN
	summary.visible = next == Screen.SUMMARY
