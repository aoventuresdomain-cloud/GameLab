extends Control
## The achievements list: every achievement with what it asks and how far the player is. It works
## without Steam. It reads the profile and asks to go back through a signal; the run flow acts.

signal back_requested

@onready var _title: Label = %Title
@onready var _rows: VBoxContainer = %Rows
@onready var _back: Button = %BackButton

var _profile: Node


func _ready() -> void:
	_back.pressed.connect(back_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	refresh()


## Shows every achievement from the profile, the unlocked ones first marked done.
func refresh() -> void:
	if _profile == null:
		return
	var list: Array = _profile.get_achievements()
	var done := list.filter(func(entry: Dictionary) -> bool: return entry["done"]).size()
	_title.text = "Achievements: %d of %d" % [done, list.size()]
	for child in _rows.get_children():
		child.queue_free()
		_rows.remove_child(child)
	for entry in list:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(600, 0)
		var status := "Done" if entry["done"] else "%d of %d" % [entry["value"], entry["goal"]]
		row.text = "%s: %s (%s)" % [entry["name"], entry["text"], status]
		if not entry["done"]:
			row.modulate = Color(1, 1, 1, 0.7)
		_rows.add_child(row)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_back.grab_focus()
