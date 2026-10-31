extends Control
## End-of-run summary: outcome, gold earned and waves cleared.

signal play_again_requested
signal map_requested
signal tree_requested
## The level offered after a win, by id.
signal next_level_requested(id: String)
## A Recruit's skill, picked from the level-up card.
signal pick_requested(id: String, skill_id: String)

const Hud = preload("res://scripts/ui/hud.gd")

@onready var _title: Label = %Title
@onready var _gold_value: Label = %GoldValue
@onready var _stars_value: Label = %StarsValue
@onready var _reward: Label = %Reward
@onready var _waves_value: Label = %WavesValue
@onready var _moment: Label = %Moment
@onready var _unlocked: Label = %UnlockedLine
@onready var _way_on: Label = %WayOn
@onready var _tip: Label = %Tip
@onready var _guide_note: Label = %GuideNote
@onready var _stars_note: Label = %StarsNote
@onready var _gear_found: Label = %GearFound
@onready var _salvaged: Label = %Salvaged
@onready var _card: PanelContainer = %CardPanel
@onready var _levelled: Label = %Levelled
@onready var _pick_card: VBoxContainer = %PickCard
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _map_button: Button = %MapButton
@onready var _tree_button: Button = %TreeButton
@onready var _next_level_button: Button = %NextLevelButton

var _next_level := ""


func _ready() -> void:
	_play_again_button.pressed.connect(play_again_requested.emit)
	_map_button.pressed.connect(map_requested.emit)
	_tree_button.pressed.connect(tree_requested.emit)
	_next_level_button.pressed.connect(func() -> void: next_level_requested.emit(_next_level))
	visibility_changed.connect(_on_visibility_changed)


## summary is the run_ended payload of a RunStateSource, with the run flow's `stars_paid` and
## `reward_gold` (what banking it gave that the level had not given before) and, once, `stars_note`
## (the line on what stars buy). `next_level` is the level
## to offer after a win ("" offers none: a loss, or the last level). `summary["notes"]` is the run
## flow's Guidance.summary_notes: the boss beaten, what the win opened, the way on and a tip.
func show_summary(summary: Dictionary, next_level: String = "") -> void:
	_next_level = next_level
	_next_level_button.visible = _next_level != ""
	_play_again_button.text = "Retry" if summary.get("keep_fell", false) else "Play again"
	_title.text = "The keep has fallen" if summary.get("keep_fell", false) else "Holdfast holds!"
	_gold_value.text = Hud.format_number(int(summary.get("gold_earned", 0)))
	_stars_value.text = "+%d" % int(summary.get("stars_paid", 0))
	_reward.text = "First win reward: +%s gold" % Hud.format_number(int(summary.get("reward_gold", 0)))
	_reward.visible = int(summary.get("reward_gold", 0)) > 0
	_stars_note.text = str(summary.get("stars_note", ""))
	_stars_note.visible = _stars_note.text != ""
	_waves_value.text = "%d / %d" % [int(summary.get("waves_cleared", 0)), int(summary.get("total_waves", 0))]
	var notes: Dictionary = summary.get("notes", {})
	var moment := str(notes.get("boss", ""))
	if summary.get("keep_fell", false) and int(summary.get("total_waves", 0)) > 0:
		moment = "The keep fell in wave %d of %d." % [mini(int(summary.get("waves_cleared", 0)) + 1, int(summary["total_waves"])), int(summary["total_waves"])]
	_set_line(_moment, moment)
	_set_line(_unlocked, " ".join(PackedStringArray(notes.get("unlocked", []))))
	_set_line(_way_on, str(notes.get("way_on", "")))
	_set_line(_tip, str(notes.get("tip", "")))
	_set_line(_guide_note, str(notes.get("guide_note", "")))
	var found: PackedStringArray = []
	var items: Dictionary = HoldfastContent.base().get("gear_items", {})
	for id in summary.get("result", {}).get("gear_found", []):
		found.append(str(items.get(id, {}).get("name", id)))
	_gear_found.text = "Gear found: " + ", ".join(found)
	_gear_found.visible = not found.is_empty()
	var salvaged := int(summary.get("result", {}).get("salvaged", 0))
	_salvaged.text = "Salvaged: %s gold" % Hud.format_number(salvaged)
	_salvaged.visible = salvaged > 0
	var levelled := PackedStringArray()
	for change in summary.get("recruit_changes", []):
		if change.get("joined", false):
			levelled.append("%s the %s joins you" % [change["name"], HoldfastContent.base()["recruit_classes"][change["class"]]["name"]])
			continue
		var line := "%s is level %d" % [change["name"], int(change["to"])]
		if str(change["trait"]) != "":
			line += " and gained %s" % HoldfastContent.base()["recruit_traits"][change["trait"]]["name"]
		levelled.append(line)
	_levelled.text = ". ".join(levelled) + "." if not levelled.is_empty() else ""
	_levelled.visible = not levelled.is_empty()
	_card.visible = _levelled.visible or _pick_card.visible


func _set_line(label: Label, text: String) -> void:
	label.text = text
	label.visible = text != ""


## The level-up card: the first Recruit with a skill to pick, and the two choices (from the profile's
## pending picks, so each pick brings up the next). Nothing waiting hides the card.
func set_picks(waiting: Array) -> void:
	for child in _pick_card.get_children():
		_pick_card.remove_child(child)
		child.queue_free()
	_pick_card.visible = not waiting.is_empty()
	_card.visible = _levelled.visible or _pick_card.visible
	if waiting.is_empty():
		return
	var content := HoldfastContent.base()
	var label := Label.new()
	label.text = "%s can learn a skill%s. Pick one:" % [waiting[0]["name"], "" if waiting.size() == 1 else " (%d waiting)" % waiting.size()]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 0)
	_pick_card.add_child(label)
	for skill_id in waiting[0]["options"]:
		var button := Button.new()
		button.text = "%s: %s" % [content["recruit_skills"][skill_id]["name"], content["recruit_skills"][skill_id]["text"]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(400, 0)
		button.pressed.connect(func() -> void: pick_requested.emit(waiting[0]["id"], skill_id))
		_pick_card.add_child(button)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		# While the note says to spend stars first, the pointer is on the Skill tree, not on another run.
		(_tree_button if _guide_note.visible else _next_level_button if _next_level_button.visible else _play_again_button).grab_focus()
