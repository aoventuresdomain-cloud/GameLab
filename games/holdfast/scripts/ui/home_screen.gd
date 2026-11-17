extends Control
## Home screen: the lighthouse and the sea, with Continue (the one main button, saying where the
## player is), New game, Settings and a small Quit. It only asks; the run flow acts. New game asks
## twice when there is progress to lose.

signal continue_requested
signal new_game_requested
signal settings_requested
signal quit_requested

const CONFIRM_TEXT := "Erase your progress?\nClick again to start over"

@onready var _continue: Button = %ContinueButton
@onready var _new_game: Button = %NewGameButton
@onready var _settings: Button = %SettingsButton
@onready var _quit: Button = %QuitButton
@onready var _notice: Label = %Notice
@onready var _scene: Control = %Scene

var _profile: Node
var _confirming := false


func _ready() -> void:
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_on_new_game)
	_settings.pressed.connect(_on_settings)
	_quit.pressed.connect(quit_requested.emit)
	_quit.visible = not OS.has_feature("web")
	visibility_changed.connect(_on_visibility_changed)
	# The title is up from the start, so no change of visibility will give it the focus.
	_on_visibility_changed.call_deferred()


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	profile.notice.connect(show_notice)
	refresh()
	if profile.load_message != "":
		show_notice(profile.load_message)


func refresh() -> void:
	var has_progress: bool = _profile != null and _profile.has_progress()
	_continue.disabled = not has_progress
	_continue.text = _continue_text() if has_progress else "Continue"
	if not _confirming:
		_new_game.text = "New game"


## "Continue", and under it where the player is: the level's number and name.
func _continue_text() -> String:
	var level: Dictionary = HoldfastContent.base()["levels"][_profile.get_level()]
	return "Continue\nLevel %d · %s" % [int(level.get("number", 0)), level["name"]]


## Lets the beam stand still when the player asked for reduced motion.
func bind_settings(settings: Node) -> void:
	settings.changed.connect(func() -> void: _scene.set_moving(not settings.is_motion_reduced()))
	_scene.set_moving(not settings.is_motion_reduced())


## True while the beam is swinging (for tests).
func is_beam_moving() -> bool:
	return _scene.is_moving()


func show_notice(message: String) -> void:
	_notice.text = message


func _on_continue() -> void:
	_cancel_confirm()
	continue_requested.emit()


func _on_new_game() -> void:
	if _profile != null and _profile.has_progress() and not _confirming:
		_confirming = true
		_new_game.text = CONFIRM_TEXT
		return
	_cancel_confirm()
	new_game_requested.emit()


func _on_settings() -> void:
	_cancel_confirm()
	settings_requested.emit()


func _cancel_confirm() -> void:
	_confirming = false
	_new_game.text = "New game"


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_cancel_confirm()
		refresh()
		(_continue if not _continue.disabled else _new_game).grab_focus()
