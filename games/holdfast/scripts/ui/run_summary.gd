extends Control
## End-of-run summary: outcome, gold earned and waves cleared.

signal play_again_requested
signal keep_requested
## The level offered after a win, by id.
signal next_level_requested(id: String)

const Hud = preload("res://scripts/ui/hud.gd")

@onready var _title: Label = %Title
@onready var _gold_value: Label = %GoldValue
@onready var _waves_value: Label = %WavesValue
@onready var _gear_found: Label = %GearFound
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _keep_button: Button = %KeepButton
@onready var _next_level_button: Button = %NextLevelButton

var _next_level := ""


func _ready() -> void:
	_play_again_button.pressed.connect(play_again_requested.emit)
	_keep_button.pressed.connect(keep_requested.emit)
	_next_level_button.pressed.connect(func() -> void: next_level_requested.emit(_next_level))
	visibility_changed.connect(_on_visibility_changed)


## summary is the run_ended payload of a RunStateSource. `next_level` is the level
## to offer after a win ("" offers none: a loss, or the last level).
func show_summary(summary: Dictionary, next_level: String = "") -> void:
	_next_level = next_level
	_next_level_button.visible = _next_level != ""
	_keep_button.text = "Back to the keep" if summary.get("keep_fell", false) else "Upgrade screen"
	_title.text = "The keep has fallen" if summary.get("keep_fell", false) else "Holdfast holds!"
	_gold_value.text = Hud.format_number(int(summary.get("gold_earned", 0)))
	_waves_value.text = "%d / %d" % [int(summary.get("waves_cleared", 0)), int(summary.get("total_waves", 0))]
	var found: PackedStringArray = []
	var items: Dictionary = HoldfastContent.base().get("gear_items", {})
	for id in summary.get("result", {}).get("gear_found", []):
		found.append(str(items.get(id, {}).get("name", id)))
	_gear_found.text = "Gear found: " + ", ".join(found)
	_gear_found.visible = not found.is_empty()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		(_next_level_button if _next_level_button.visible else _play_again_button).grab_focus()
