extends Control
## End-of-run summary: outcome, gold earned and waves cleared.

signal play_again_requested

const Hud = preload("res://scripts/ui/hud.gd")

@onready var _title: Label = %Title
@onready var _gold_value: Label = %GoldValue
@onready var _waves_value: Label = %WavesValue
@onready var _play_again_button: Button = %PlayAgainButton


func _ready() -> void:
	_play_again_button.pressed.connect(play_again_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


## summary is the run_ended payload of a RunStateSource.
func show_summary(summary: Dictionary) -> void:
	_title.text = "The keep has fallen" if summary.get("keep_fell", false) else "Holdfast holds!"
	_gold_value.text = Hud.format_number(int(summary.get("gold_earned", 0)))
	_waves_value.text = "%d / %d" % [int(summary.get("waves_cleared", 0)), int(summary.get("total_waves", 0))]


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_play_again_button.grab_focus()
