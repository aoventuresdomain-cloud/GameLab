extends Control
## Menu, the last tab of the rail: Settings, Achievements, Reset all upgrades (asks twice) and Back
## to title. It only asks; the run flow acts.

signal back_requested
signal settings_requested
signal achievements_requested
signal reset_requested
signal title_requested

const Hud = preload("res://scripts/ui/hud.gd")
const RESET_TEXT := "Reset all upgrades"
const CONFIRM_TEXT := "Refund every upgrade?\nPress again to confirm"

@onready var rail: HubRail = %Rail
@onready var _gold: Label = %GoldValue
@onready var _stars: Label = %StarsValue
@onready var _back: Button = %BackButton
@onready var _settings: Button = %SettingsButton
@onready var _achievements: Button = %AchievementsButton
@onready var _reset: Button = %ResetButton
@onready var _title: Button = %TitleButton

var _profile: Node
var _confirming := false


func _ready() -> void:
	_back.pressed.connect(back_requested.emit)
	_settings.pressed.connect(settings_requested.emit)
	_achievements.pressed.connect(achievements_requested.emit)
	_reset.pressed.connect(_on_reset)
	_title.pressed.connect(title_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _profile == null:
		return
	_gold.text = Hud.format_number(_profile.get_gold())
	_stars.text = str(_profile.get_stars())
	var has_upgrades: bool = not _profile.get_respec_nodes().is_empty()
	_reset.disabled = not has_upgrades
	_reset.tooltip_text = "" if has_upgrades else "Nothing to refund yet."
	if not has_upgrades:
		_confirming = false
	_reset.text = CONFIRM_TEXT if _confirming else RESET_TEXT


## The first press asks; the second refunds everything.
func _on_reset() -> void:
	if not _confirming:
		_confirming = true
		_reset.text = CONFIRM_TEXT
		return
	_confirming = false
	_reset.text = RESET_TEXT
	reset_requested.emit()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_confirming = false
		refresh()
		_settings.grab_focus()
