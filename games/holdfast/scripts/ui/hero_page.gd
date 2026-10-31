extends Control
## Hero page: choose the Hero's path, wear the gear found so far and read what the Hero's numbers
## come to. The Hero stands in the middle (placeholder art), the numbers on the left and the five
## gear slots on the right, each with its own stat identity (shown on hover); the bag of pieces not
## worn is below. A piece is worn by dragging it from the bag onto its slot (the same gesture as the
## Plan page's cards) or by pressing it, and taken off by dragging it back or pressing its slot.
## It shows the profile and asks for changes through signals; the run flow acts. Mouse only.

signal back_requested
signal tree_requested
signal pillar_requested(id: String)
signal gear_requested(id: String)
signal gear_wear_requested(id: String)
signal gear_off_requested(slot: String)

const Keep = preload("res://scripts/ui/keep_screen.gd")
const FONT_PX := 20
const DEFAULT_INFO := ""
const WEAR_HINT := "Bag: press a piece, or drag it onto its slot, to wear it."
const LOCKED_ALPHA := 0.5
const COLOUR_HERO := Color(0.95, 0.6, 0.2)
const COLOUR_WORN := Color(0.2, 0.5, 0.3)
const COLOUR_WORN_EDGE := Color(0.45, 0.85, 0.55)

## The Hero path id the profile has picked.
var selected_pillar := ""

@onready var _pillar_row: HBoxContainer = %PillarRow
@onready var _pillar_info: Label = %PillarInfo
@onready var _slot_column: VBoxContainer = %SlotColumn
@onready var _bag: HFlowContainer = %Bag
@onready var _bag_hint: Label = %BagHint
@onready var _main: Control = %Main
@onready var _stats: Label = %Stats
@onready var _stats_info: Button = %StatsInfoButton
@onready var _figure: Control = %HeroFigure
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
	_stats_info.pressed.connect(func() -> void: _stats.text = _stats_text(_stats_info.button_pressed))
	_figure.draw.connect(_draw_figure)
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		var reason := _lock_reason(id)
		_pillar_buttons[id].text = "%s (locked)" % _content["hero_paths"][id]["name"] if reason != "" else str(_content["hero_paths"][id]["name"])
		_pillar_buttons[id].modulate = Color(1, 1, 1, LOCKED_ALPHA) if reason != "" else Color.WHITE
	var path: Dictionary = _content["hero_paths"][selected_pillar]
	_pillar_info.text = "%s: %s" % [path["name"], path.get("blurb", "")]
	_refresh_gear()


## The slots, the bag and the numbers, redrawn from the profile.
func _refresh_gear() -> void:
	var worn: Dictionary = _profile.get_gear_worn()
	for slot in _slot_panels:
		var id: String = worn.get(slot, "")
		_slot_panels[slot].get_node("Row/Item").text = _content["gear_items"][id]["name"] if id != "" else ""
		_slot_panels[slot].mouse_default_cursor_shape = Control.CURSOR_DRAG if id != "" else Control.CURSOR_ARROW
		_light(_slot_panels[slot], id != "")
	for child in _bag.get_children():
		_bag.remove_child(child)
		child.queue_free()
	var owned: Array = _profile.get_gear_owned()
	# The how-to shows until the first piece is on.
	_bag_hint.text = "Gear: none yet. Each level's first win gives a piece, and elites and bosses may drop more." if owned.is_empty() else (WEAR_HINT if worn.is_empty() else "Bag")
	for id in owned:
		var item: Dictionary = _content["gear_items"][id]
		# A worn piece is on its slot, not in the bag.
		if worn.get(item["slot"], "") == id:
			continue
		var button := Button.new()
		button.text = str(item["name"])
		button.add_theme_font_size_override("font_size", FONT_PX)
		_compact(button)
		button.pressed.connect(func() -> void: gear_requested.emit(id))
		button.set_drag_forwarding(_bag_drag.bind(id, button), _off_can_drop, _off_drop)
		button.mouse_entered.connect(func() -> void: _info.text = _gear_text(id))
		button.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
		_bag.add_child(button)
	_stats.text = _stats_text(_stats_info.button_pressed)
	_figure.queue_redraw()


## A slot with a piece on it glows green; an empty one is plain.
static func _light(panel: PanelContainer, worn: bool) -> void:
	if not worn:
		panel.remove_theme_stylebox_override("panel")
		_compact(panel)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = COLOUR_WORN
	box.border_color = COLOUR_WORN_EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", box)


## The Hero's numbers with the tree and the gear worn: "Health 80", or with `breakdown` "Health 80
## (base 60, tree +0, gear +20)".
func _stats_text(breakdown := false) -> String:
	var lines: PackedStringArray = []
	for row in _profile.get_hero_breakdown():
		var unit: String = row["unit"] if row["unit"] == "%" else ""
		var line := "%s %s%s" % [row["label"], _num(float(row["final"])), unit]
		if breakdown:
			line += " (base %s, tree %s, gear %s)" % [_num(float(row["base"])), _num(float(row["tree"]), true), _num(float(row["gear"]), true)]
		lines.append(line)
	return "\n".join(lines)


## The placeholder Hero: a head and a cloaked body, until the final art.
func _draw_figure() -> void:
	var centre := _figure.size * 0.5
	var unit := minf(_figure.size.x, _figure.size.y) * 0.5
	_figure.draw_circle(centre + Vector2(0, -unit * 0.45), unit * 0.22, COLOUR_HERO)
	_figure.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -unit * 0.2), centre + Vector2(unit * 0.4, unit * 0.65), centre + Vector2(-unit * 0.4, unit * 0.65)]), COLOUR_HERO)


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
		title.text = str(data["name"])
		panel.tooltip_text = "%s: %s" % [data["name"], data["identity"]] if str(data["identity"]) != "" else str(data["name"])
		title.add_theme_font_size_override("font_size", FONT_PX)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.custom_minimum_size = Vector2(110, 0)
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
		button.pressed.connect(_pillar_pressed.bind(id))
		button.mouse_entered.connect(func() -> void: _info.text = _pillar_text(id))
		button.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
		_pillar_row.add_child(button)
		_pillar_buttons[id] = button


## "" when the Hero path can be picked, else what opens it.
## shortcut: the profile has no pillar gating yet (HF-M2-64); it names `get_pillar_lock_reason(id)` when it does.
func _lock_reason(id: String) -> String:
	return str(_profile.get_pillar_lock_reason(id)) if _profile != null and _profile.has_method("get_pillar_lock_reason") else ""


## A locked path says what opens it and changes nothing; the pick that was held stays held.
func _pillar_pressed(id: String) -> void:
	var reason := _lock_reason(id)
	if reason == "":
		pillar_requested.emit(id)
		return
	_pillar_buttons[id].set_pressed_no_signal(false)
	_pillar_buttons[selected_pillar].set_pressed_no_signal(true)
	_info.text = _pillar_text(id)


func _pillar_text(id: String) -> String:
	var path: Dictionary = _content["hero_paths"][id]
	var reason := _lock_reason(id)
	return "%s: %s" % [path["name"], reason if reason != "" else path.get("blurb", "")]


func _gear_text(id: String) -> String:
	var item: Dictionary = _content["gear_items"][id]
	return "%s: %s" % [item["name"], Keep._effects_text(item["effects"])]


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_info.text = DEFAULT_INFO
		_back.grab_focus()
