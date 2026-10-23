extends Control
## Plan page, shown before a run on a level with Archer Post sites: a map of the level with
## the places enemies come from, slots around the keep, and the tower cards (the pack's post
## limit) the player drags into them, or presses a slot to place and lift one. Auto-place
## suggests a layout and Quick start reuses the last one. It shows the choice and asks for
## the run through signals; the run flow acts. Mouse only.

signal start_requested(layout: Array)
signal back_requested

const FONT_PX := 20
const COLOUR_ARENA := Color(0.35, 0.4, 0.5)
const COLOUR_KEEP := Color(0.85, 0.8, 0.55)
const COLOUR_ARC := Color(0.9, 0.3, 0.25)
const COLOUR_RANGE := Color(0.55, 0.75, 0.95, 0.25)
const ARC_STEPS := 24
const SITE_FILL := 0.55
const ARC_FILL := 0.92
const COLOUR_SLOT := Color(0.95, 0.85, 0.5)

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _count: Label = %Count
@onready var _map: Control = %Map
@onready var _back: Button = %BackButton
@onready var _start: Button = %StartButton
@onready var _auto: Button = %AutoButton
@onready var _quick: Button = %QuickButton
@onready var _side: Control = %Side
@onready var _tray: VBoxContainer = %Tray

var _content: Dictionary
var _level_id := ""
var _level: Dictionary = {}
var _chosen: Array = []
## The layout of the last run on this level ("" none yet): what Quick start reuses.
var _saved: Array = []
var _site_buttons: Dictionary = {}


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_start.pressed.connect(func() -> void: start_requested.emit(_chosen.duplicate()))
	_auto.pressed.connect(auto_place)
	_quick.pressed.connect(func() -> void: start_requested.emit(_saved.duplicate()))
	# A lifted post goes back to the tray when let go anywhere that is not a free slot.
	for target in [self, _map, _side, _auto, _quick, _start, _back]:
		target.set_drag_forwarding(Callable(), _side_can_drop, _side_drop)
	_map.draw.connect(_draw_map)
	_map.resized.connect(_place_buttons)
	visibility_changed.connect(_on_visibility_changed)


## Shows the level's map with `layout` (site ids) already placed. `saved` says the layout is
## the player's own from an earlier run, which Quick start can then reuse.
func open(level_id: String, layout: Array, saved := false) -> void:
	_level_id = level_id
	_level = _content["levels"][level_id]
	_chosen = layout.duplicate()
	_saved = layout.duplicate() if saved else []
	for button in _site_buttons.values():
		button.queue_free()
	_site_buttons.clear()
	for site in _level["sites"]:
		var id := str(site["id"])
		var button := Button.new()
		button.tooltip_text = id.replace("_", " ").capitalize()
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", FONT_PX)
		button.pressed.connect(_toggle.bind(id))
		button.set_drag_forwarding(_slot_drag.bind(id, button), _slot_can_drop.bind(id), _slot_drop.bind(id))
		_map.add_child(button)
		_site_buttons[id] = button
	_title.text = "Plan your defence: %s" % _level["name"]
	_hint.text = "Enemies come from the red edges. Drag an Archer Post card onto a slot, or press a slot, before the first wave."
	_place_buttons()
	_refresh()


## Chooses or drops a site. At the limit, the oldest choice makes way.
func _toggle(id: String) -> void:
	if id in _chosen:
		_chosen.erase(id)
	else:
		_chosen.append(id)
		while _chosen.size() > int(_level.get("max_posts", 1)):
			_chosen.pop_front()
	_refresh()


## The suggested layout: the sites nearest where the enemies come from.
func auto_place() -> void:
	_chosen = HoldfastRules.best_layout(_level)
	_refresh()


func _refresh() -> void:
	for id in _site_buttons:
		var placed: bool = id in _chosen
		_site_buttons[id].set_pressed_no_signal(placed)
		_site_buttons[id].text = "%s: %s" % [_tower_name(), _slot_name(id)] if placed else _slot_name(id)
		_site_buttons[id].reset_size()
	_count.text = "Posts: %d of %d" % [_chosen.size(), int(_level.get("max_posts", 1))]
	_start.disabled = _chosen.is_empty()
	_quick.disabled = _saved.is_empty()
	_refresh_cards()
	_place_buttons()
	_map.queue_redraw()


func _tower_name() -> String:
	return "Archer"


func _slot_name(id: String) -> String:
	return id.trim_suffix("_gate").replace("_", " ").capitalize()


## One card for each post the level allows: the ones in hand can be dragged, the placed ones wait greyed.
func _refresh_cards() -> void:
	for child in _tray.get_children():
		_tray.remove_child(child)
		child.queue_free()
	var tower: Dictionary = _content["towers"][str(_level["tower"]["id"])]
	for i in int(_level.get("max_posts", 1)):
		var in_hand: bool = i >= _chosen.size()
		var card := PanelContainer.new()
		var label := Label.new()
		label.text = "%s\n%s" % [tower["name"], "in hand: drag it to a slot" if in_hand else "placed"]
		label.add_theme_font_size_override("font_size", FONT_PX)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		card.modulate = Color.WHITE if in_hand else Color(1, 1, 1, 0.45)
		card.set_drag_forwarding(_card_drag.bind(card) if in_hand else Callable(), _side_can_drop, _side_drop)
		if in_hand:
			card.mouse_default_cursor_shape = Control.CURSOR_DRAG
		_tray.add_child(card)


## What is dragged: a post from the tray (`from` ""), or one lifted off a slot.
func _post_data(from: String) -> Dictionary:
	return {"kind": "tower", "tower": str(_level["tower"]["id"]), "from": from}


func _drag_preview(held: Control) -> void:
	# A preview can only be set while the viewport is dragging.
	if not held.get_viewport().gui_is_dragging():
		return
	var preview := Label.new()
	preview.text = "Archer Post"
	preview.add_theme_font_size_override("font_size", FONT_PX)
	held.set_drag_preview(preview)


func _card_drag(_at: Vector2, card: Control) -> Variant:
	_drag_preview(card)
	return _post_data("")


func _slot_drag(_at: Vector2, id: String, button: Control) -> Variant:
	if not id in _chosen:
		return null
	_drag_preview(button)
	return _post_data(id)


## A slot takes a card from the tray while a post is left to place, or a post lifted from another slot.
func _slot_can_drop(_at: Vector2, data: Variant, id: String) -> bool:
	if not data is Dictionary or str(data.get("kind", "")) != "tower" or id in _chosen:
		return false
	var from := str(data.get("from", ""))
	return _chosen.size() < int(_level.get("max_posts", 1)) if from == "" else from in _chosen


func _slot_drop(_at: Vector2, data: Variant, id: String) -> void:
	if not _slot_can_drop(_at, data, id):
		return
	var from := str(data["from"])
	if from == "":
		_chosen.append(id)
	else:
		_chosen[_chosen.find(from)] = id
	_refresh()


## Letting a lifted post go on the cards, the buttons, the map or anywhere else returns its card.
func _side_can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "tower" and str(data.get("from", "")) in _chosen


func _side_drop(_at: Vector2, data: Variant) -> void:
	if _side_can_drop(_at, data):
		_chosen.erase(str(data["from"]))
		_refresh()


## World units to map pixels: zoomed on the keep so the sites fill most of the map.
func _scale() -> float:
	var reach := 100.0
	for site in _level["sites"]:
		reach = maxf(reach, Vector2(float(site["x"]), float(site["y"])).length())
	return minf(_map.size.x, _map.size.y) * 0.5 * SITE_FILL / reach


func _place_buttons() -> void:
	if _level.is_empty():
		return
	for site in _level["sites"]:
		var button: Button = _site_buttons.get(str(site["id"]))
		if button == null:
			continue
		var at: Vector2 = _map.size * 0.5 + Vector2(float(site["x"]), float(site["y"])) * _scale()
		button.reset_size()
		button.position = at - button.size * 0.5


func _draw_map() -> void:
	if _level.is_empty():
		return
	var scale := _scale()
	var centre: Vector2 = _map.size * 0.5
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), COLOUR_ARENA, false, 2.0)
	_map.draw_circle(centre, float(_level["keep_radius"]) * scale, COLOUR_KEEP)
	var reach := float(_content["towers"][str(_level["tower"]["id"])]["range"])
	for site in _level["sites"]:
		var at: Vector2 = centre + Vector2(float(site["x"]), float(site["y"])) * scale
		_map.draw_circle(at, 6.0, COLOUR_SLOT)
		if str(site["id"]) in _chosen:
			_map.draw_circle(at, reach * scale, COLOUR_RANGE)
	# The red arcs show which way the enemies come from, drawn at the edge of the map.
	var edge := minf(_map.size.x, _map.size.y) * 0.5 * ARC_FILL
	for arc in _level.get("spawn_arcs", []):
		var points := PackedVector2Array()
		for i in ARC_STEPS + 1:
			var angle := deg_to_rad(float(arc["centre"]) + (float(i) / ARC_STEPS - 0.5) * float(arc["width"]))
			points.append(centre + Vector2(cos(angle), sin(angle)) * edge)
		_map.draw_polyline(points, COLOUR_ARC, 5.0)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_start.grab_focus()
