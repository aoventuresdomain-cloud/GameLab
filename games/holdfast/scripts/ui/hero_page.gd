extends Control
## Hero page: choose the Hero's path, wear the gear found so far (five slots, each with its own
## stat identity) and read what the Hero's numbers come to. Gear is worn by dragging a piece from
## the bag onto its slot (the same gesture as the Plan page's cards) or by pressing it, and taken
## off by dragging it back or pressing its slot. It shows the profile and asks for changes through
## signals; the run flow acts. Mouse only.

signal back_requested
signal tree_requested
signal pillar_requested(id: String)
signal gear_requested(id: String)
signal gear_wear_requested(id: String)
signal gear_off_requested(slot: String)

const Keep = preload("res://scripts/ui/keep_screen.gd")
const FONT_PX := 20
const DEFAULT_INFO := "Pick a path. Gear is the Hero's alone: drag a piece onto its slot or press it to wear it; drag it back or press its slot to take it off."

## The Hero path id the profile has picked.
var selected_pillar := ""

@onready var _pillar_row: HBoxContainer = %PillarRow
@onready var _pillar_info: Label = %PillarInfo
@onready var _slot_column: VBoxContainer = %SlotColumn
@onready var _bag: HFlowContainer = %Bag
@onready var _bag_hint: Label = %BagHint
@onready var _main: Control = %Main
@onready var _stats: Label = %Stats
@onready var _info: Label = %Info
@onready var _tree: Button = %TreeButton
@onready var _back: Button = %BackButton

var _profile: Node
var _content: Dictionary
var _pillar_buttons: Dictionary = {}
## Each slot's drop target, by slot name.
var _slot_panels: Dictionary = {}


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_tree.pressed.connect(tree_requested.emit)
	visibility_changed.connect(_on_visibility_changed)
	_build_pillars()
	_build_slots()
	# A piece let go anywhere that is not its slot goes back to the bag.
	for target in [_main, _bag, _slot_column]:
		target.set_drag_forwarding(Callable(), _off_can_drop, _off_drop)
	_info.text = DEFAULT_INFO


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	refresh()


## Asks for a Hero path; an unknown id changes nothing.
func select_pillar(id: String) -> void:
	pillar_requested.emit(id)


## Redraws everything from the profile.
func refresh() -> void:
	if _profile == null:
		return
	selected_pillar = _profile.get_pillar()
	for id in _pillar_buttons:
		_pillar_buttons[id].set_pressed_no_signal(id == selected_pillar)
	var path: Dictionary = _content["hero_paths"][selected_pillar]
	_pillar_info.text = "%s: %s" % [path["name"], path.get("blurb", "")]
	_tree.text = "Open the %s section of the skill tree" % path["name"]
	_refresh_gear()


## The slots, the bag and the numbers, redrawn from the profile.
func _refresh_gear() -> void:
	var worn: Dictionary = _profile.get_gear_worn()
	for slot in _slot_panels:
		var id: String = worn.get(slot, "")
		_slot_panels[slot].get_node("Row/Item").text = _content["gear_items"][id]["name"] if id != "" else "empty"
		_slot_panels[slot].mouse_default_cursor_shape = Control.CURSOR_DRAG if id != "" else Control.CURSOR_ARROW
	for child in _bag.get_children():
		_bag.remove_child(child)
		child.queue_free()
	var owned: Array = _profile.get_gear_owned()
	_bag_hint.text = "Gear: none yet. Each level's first win gives a piece, and elites and bosses may drop more." if owned.is_empty() else "Gear (the bag is below the slots): drag a piece onto its slot, or press it."
	for id in owned:
		var item: Dictionary = _content["gear_items"][id]
		var button := Button.new()
		button.text = str(item["name"])
		button.add_theme_font_size_override("font_size", FONT_PX)
		_compact(button)
		button.toggle_mode = true
		button.set_pressed_no_signal(worn.get(item["slot"], "") == id)
		button.pressed.connect(func() -> void: gear_requested.emit(id))
		button.set_drag_forwarding(_bag_drag.bind(id, button), _off_can_drop, _off_drop)
		button.mouse_entered.connect(func() -> void: _info.text = _gear_text(id, worn.get(item["slot"], "") == id))
		button.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
		_bag.add_child(button)
	_stats.text = _stats_text()


## What the Hero's numbers come to with the tree and the gear worn: "Health 80 (base 60, tree +0, gear +20)".
func _stats_text() -> String:
	var lines: PackedStringArray = []
	for row in _profile.get_hero_breakdown():
		var unit: String = row["unit"] if row["unit"] == "%" else ""
		lines.append("%s %s%s (base %s, tree %s, gear %s)" % [row["label"], _num(float(row["final"])), unit, _num(float(row["base"])), _num(float(row["tree"]), true), _num(float(row["gear"]), true)])
	return "\n".join(lines)


## A number to two places without trailing zeros; `signed` puts a + on a positive one.
static func _num(value: float, signed := false) -> String:
	var text := Keep._trim(snappedf(value, 0.01))
	if signed and value > 0.0001:
		text = "+" + text
	return text


func _build_slots() -> void:
	var info: Dictionary = {}
	for rules in _content["gear_rules"].values():
		info = rules.get("slot_info", {})
		break
	for slot in HoldfastMeta.gear_slots(_content):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_compact(panel)
		var row := HBoxContainer.new()
		row.name = "Row"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		var title := Label.new()
		title.name = "Title"
		var data: Dictionary = info.get(slot, {"name": str(slot).capitalize(), "identity": ""})
		title.text = "%s: %s" % [data["name"], data["identity"]] if str(data["identity"]) != "" else str(data["name"])
		title.add_theme_font_size_override("font_size", FONT_PX)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.custom_minimum_size = Vector2(380, 0)
		var item := Label.new()
		item.name = "Item"
		item.add_theme_font_size_override("font_size", FONT_PX)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		row.add_child(item)
		panel.add_child(row)
		panel.set_drag_forwarding(_slot_drag.bind(str(slot), panel), _slot_can_drop.bind(str(slot)), _slot_drop.bind(str(slot)))
		panel.gui_input.connect(_slot_input.bind(str(slot)))
		_slot_column.add_child(panel)
		_slot_panels[str(slot)] = panel


## A copy of a control's styles with less padding above and below, so twelve pieces and five slots
## fit the page.
static func _compact(control: Control) -> void:
	var states := ["panel"] if control is PanelContainer else ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
	for state in states:
		var box := control.get_theme_stylebox(state)
		if box != null:
			var slim := box.duplicate()
			slim.content_margin_top = 2.0
			slim.content_margin_bottom = 2.0
			control.add_theme_stylebox_override(state, slim)


func _slot_input(event: InputEvent, slot: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _profile.get_gear_worn().get(slot, "") == "":
		gear_off_requested.emit(slot)


## What is dragged: a piece from the bag ("from" ""), or one lifted off its slot.
static func _gear_data(id: String, slot: String, from: String) -> Dictionary:
	return {"kind": "gear", "item": id, "slot": slot, "from": from}


func _bag_drag(_at: Vector2, id: String, button: Control) -> Variant:
	_drag_preview(button, str(_content["gear_items"][id]["name"]))
	return _gear_data(id, str(_content["gear_items"][id]["slot"]), "")


func _slot_drag(_at: Vector2, slot: String, panel: Control) -> Variant:
	var id: String = _profile.get_gear_worn().get(slot, "")
	if id == "":
		return null
	_drag_preview(panel, str(_content["gear_items"][id]["name"]))
	return _gear_data(id, slot, slot)


func _drag_preview(held: Control, text: String) -> void:
	# A preview can only be set while the viewport is dragging.
	if not held.get_viewport().gui_is_dragging():
		return
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", FONT_PX)
	held.set_drag_preview(preview)


## A slot takes a piece that belongs in it.
func _slot_can_drop(_at: Vector2, data: Variant, slot: String) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "gear" and str(data.get("slot", "")) == slot and str(data.get("from", "")) == ""


func _slot_drop(at: Vector2, data: Variant, slot: String) -> void:
	if _slot_can_drop(at, data, slot):
		gear_wear_requested.emit(str(data["item"]))


## Letting a worn piece go anywhere else takes it off.
func _off_can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "gear" and str(data.get("from", "")) != ""


func _off_drop(at: Vector2, data: Variant) -> void:
	if _off_can_drop(at, data):
		gear_off_requested.emit(str(data["from"]))


func _build_pillars() -> void:
	var group := ButtonGroup.new()
	for id in _content["hero_paths"]:
		var path: Dictionary = _content["hero_paths"][id]
		var button := Button.new()
		button.text = str(path["name"])
		button.add_theme_font_size_override("font_size", 24)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: pillar_requested.emit(id))
		button.mouse_entered.connect(func() -> void: _info.text = "%s: %s" % [path["name"], path.get("blurb", "")])
		button.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
		_pillar_row.add_child(button)
		_pillar_buttons[id] = button


func _gear_text(id: String, worn: bool) -> String:
	var item: Dictionary = _content["gear_items"][id]
	return "%s (%s): %s. %s." % [item["name"], item["slot"], Keep._effects_text(item["effects"]), "Worn, press to take off" if worn else "Not worn, drag it to its slot or press to wear"]


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_info.text = DEFAULT_INFO
		_back.grab_focus()
