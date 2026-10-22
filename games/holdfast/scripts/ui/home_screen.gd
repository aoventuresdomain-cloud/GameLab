extends Control
## Home screen: Continue, New game, Settings, Quit. It only asks; the run flow
## acts. New game asks twice when there is progress to lose.

signal continue_requested
signal new_game_requested
signal quit_requested

const SETTINGS_NOTICE := "Settings (volume, screen shake, flashes) arrive in a later build."
const CONFIRM_TEXT := "Erase your progress?\nClick again to start over"

@onready var _continue: Button = %ContinueButton
@onready var _new_game: Button = %NewGameButton
@onready var _settings: Button = %SettingsButton
@onready var _quit: Button = %QuitButton
@onready var _notice: Label = %Notice

var _profile: Node
var _confirming := false


func _ready() -> void:
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_on_new_game)
	_settings.pressed.connect(_on_settings)
	_quit.pressed.connect(quit_requested.emit)
	_quit.visible = not OS.has_feature("web")
	visibility_changed.connect(_on_visibility_changed)


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
	if not _confirming:
		_new_game.text = "New game"


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
	show_notice(SETTINGS_NOTICE)


func _cancel_confirm() -> void:
	_confirming = false
	_new_game.text = "New game"


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_cancel_confirm()
		refresh()
		(_continue if not _continue.disabled else _new_game).grab_focus()
