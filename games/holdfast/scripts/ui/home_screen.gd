extends Control
## Home screen: Continue, New game, Settings, Quit. It only asks; the run flow
## acts. New game asks twice when there is progress to lose.

signal continue_requested
signal new_game_requested
signal settings_requested
signal quit_requested

const Hud = preload("res://scripts/ui/hud.gd")
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
	_continue.text = _continue_text() if has_progress else "Continue"
	if not _confirming:
		_new_game.text = "New game"


## "Continue", and under it where the player is: level, Hero path and gold.
func _continue_text() -> String:
	var content := HoldfastContent.base()
	var level: Dictionary = content["levels"][_profile.get_level()]
	return "Continue\nLevel %d · %s · %s gold" % [int(level.get("number", 0)), content["hero_paths"][_profile.get_pillar()]["name"], Hud.format_number(_profile.get_gold())]


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
