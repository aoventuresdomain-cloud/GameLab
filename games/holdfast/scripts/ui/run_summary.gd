extends Control
## End-of-run summary: three star slots over a thin Keep-health bar with the marks the stars are earned at,
## the gold and stars gained, what the win unlocked (read from the pack, an icon for each), what a spare drop
## was salvaged for, and one main button: the next level, or Spend stars while a guided buy is waiting.

signal play_again_requested
signal map_requested
signal tree_requested
## The level offered after a win, by id.
signal next_level_requested(id: String)
## A Recruit's skill, picked from the level-up card.
signal pick_requested(id: String, skill_id: String)

const Hud = preload("res://scripts/ui/hud.gd")
const ICON_DIR := "res://assets/ui/icons/"
## The picture for each kind of unlock (the blessing has its own, not the flame).
const UNLOCK_ICONS := {"blessing": "unlock_blessing", "recruit": "node_recruit", "gear": "unlock_gear", "hero_path": "unlock_path"}
const UNLOCK_ICON_PX := 24.0
const BAR_HEIGHT := 10.0

@onready var _title: Label = %Title
@onready var _gold_value: Label = %GoldValue
@onready var _stars_value: Label = %StarsValue
@onready var _reward: Label = %Reward
@onready var _waves_value: Label = %WavesValue
@onready var _moment: Label = %Moment
@onready var _stars_row: Control = %StarRow
@onready var _keep_bar: Control = %KeepBar
@onready var _unlocked: Control = %Unlocked
@onready var _unlocked_list: VBoxContainer = %UnlockedList
@onready var _way_on: Label = %WayOn
@onready var _tip: Label = %Tip
@onready var _salvaged: Label = %Salvaged
@onready var _card: PanelContainer = %CardPanel
@onready var _levelled: Label = %Levelled
@onready var _pick_card: VBoxContainer = %PickCard
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _map_button: Button = %MapButton
@onready var _tree_button: Button = %TreeButton
@onready var _next_level_button: Button = %NextLevelButton
@onready var _spend_button: Button = %SpendButton

var _next_level := ""
## True while a guided buy is waiting: the main button is Spend stars, which goes to the tree.
var _spend := false
## The Keep's health when the run ended (0 to 1) and the marks on the bar where a star is earned.
var _keep_left := 0.0
var _tiers: Array = []


func _ready() -> void:
	_play_again_button.pressed.connect(play_again_requested.emit)
	_map_button.pressed.connect(map_requested.emit)
	_tree_button.pressed.connect(tree_requested.emit)
	_next_level_button.pressed.connect(func() -> void: next_level_requested.emit(_next_level))
	_spend_button.pressed.connect(tree_requested.emit)
	_keep_bar.draw.connect(_draw_keep_bar)
	visibility_changed.connect(_on_visibility_changed)


## summary is the run_ended payload of a RunStateSource, with the run flow's `stars_paid` and
## `reward_gold` (what banking it gave that the level had not given before) and `unlocks` (what the bank
## unlocked, HoldfastMeta.unlocks). `next_level` is the level
## to offer after a win ("" offers none: a loss, or the last level). `summary["notes"]` is the run
## flow's Guidance.summary_notes: the boss beaten, what the win opened, the way on and a tip.
func show_summary(summary: Dictionary, next_level: String = "") -> void:
	_next_level = next_level
	var notes: Dictionary = summary.get("notes", {})
	# A guided buy comes first: the main button takes the player to the tree to make it.
	_spend = str(notes.get("guide_note", "")) != ""
	_next_level_button.visible = _next_level != ""
	_spend_button.visible = _spend
	_tree_button.visible = not _spend
	# One amber button: Spend stars while a buy waits, else the next level when there is one, else playing again.
	_spend_button.theme_type_variation = &"MainButton"
	_next_level_button.theme_type_variation = &"MainButton"
	_play_again_button.theme_type_variation = &"" if _next_level_button.visible or _spend else &"MainButton"
	_play_again_button.text = "Retry" if summary.get("keep_fell", false) else "Play again"
	_title.text = "The keep has fallen" if summary.get("keep_fell", false) else "Fogwatch holds!"
	_gold_value.text = Hud.format_number(int(summary.get("gold_earned", 0)))
	_stars_value.text = "+%d" % int(summary.get("stars_paid", 0))
	_reward.text = "First win reward: +%s gold" % Hud.format_number(int(summary.get("reward_gold", 0)))
	_reward.visible = int(summary.get("reward_gold", 0)) > 0
	_show_stars(summary)
	_waves_value.text = "%d / %d" % [int(summary.get("waves_cleared", 0)), int(summary.get("total_waves", 0))]
	var moment := str(notes.get("boss", ""))
	if summary.get("keep_fell", false) and int(summary.get("total_waves", 0)) > 0:
		moment = "The keep fell in wave %d of %d." % [mini(int(summary.get("waves_cleared", 0)) + 1, int(summary["total_waves"])), int(summary["total_waves"])]
	_set_line(_moment, moment)
	_show_unlocks(summary.get("unlocks", []))
	_set_line(_way_on, str(notes.get("way_on", "")))
	_set_line(_tip, str(notes.get("tip", "")))
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


## The three star slots (lit for the stars this run earned) and the Keep-health bar with a mark where
## each star above the first is earned. A run with no result (the tutorial's stand) has neither.
func _show_stars(summary: Dictionary) -> void:
	var result: Dictionary = summary.get("result", {})
	_stars_row.visible = not result.is_empty()
	_keep_bar.visible = not result.is_empty()
	var earned := HoldfastMeta.stars_for_run(HoldfastContent.base(), result) if not result.is_empty() else 0
	for i in 3:
		_stars_row.get_child(i).modulate = UiTokens.fade(1.0) if i < earned else UiTokens.fade(0.25)
	var max_health := float(summary.get("keep_health_max", 0))
	_keep_left = clampf(float(summary.get("keep_health", 0)) / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	_tiers = HoldfastMeta.castle_rules(HoldfastContent.base()).get("star_tiers", []).filter(func(tier: Dictionary) -> bool: return float(tier["above"]) > 0.0)
	_keep_bar.queue_redraw()


func _draw_keep_bar() -> void:
	var size := _keep_bar.size
	_keep_bar.draw_rect(Rect2(Vector2.ZERO, size), UiTokens.colour(&"raise"))
	_keep_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _keep_left, size.y)), UiTokens.colour(&"good"))
	for tier in _tiers:
		var x := size.x * float(tier["above"])
		_keep_bar.draw_rect(Rect2(x - 1.0, -3.0, 2.0, size.y + 6.0), UiTokens.colour(&"bone"))


## What the win unlocked, one row each: its picture, its name and, where the pack has one, its line.
## What a spare drop was salvaged for has its own line, not a row.
func _show_unlocks(unlocks: Array) -> void:
	for child in _unlocked_list.get_children():
		_unlocked_list.remove_child(child)
		child.queue_free()
	var rows := 0
	for unlock in unlocks:
		if not UNLOCK_ICONS.has(str(unlock["kind"])):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.texture = load(ICON_DIR + UNLOCK_ICONS[str(unlock["kind"])] + ".svg")
		icon.custom_minimum_size = Vector2.ONE * UNLOCK_ICON_PX
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var label := Label.new()
		label.text = unlock_text(unlock)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_unlocked_list.add_child(row)
		rows += 1
	_unlocked.visible = rows > 0


## "Steady Flame: the pack's line", "Wren the Warden joins you", "Tarred Bowstring", "Dusk Mage path".
static func unlock_text(unlock: Dictionary) -> String:
	match str(unlock["kind"]):
		"blessing":
			return "%s: %s" % [unlock["name"], unlock["text"]] if str(unlock["text"]) != "" else str(unlock["name"])
		"recruit":
			return "%s the %s joins you" % [unlock["name"], unlock["text"]] if str(unlock["text"]) != "" else "%s joins you" % unlock["name"]
		"hero_path":
			return "%s path" % unlock["name"]
	return str(unlock["name"])


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
		(_spend_button if _spend else _next_level_button if _next_level_button.visible else _play_again_button).grab_focus()
