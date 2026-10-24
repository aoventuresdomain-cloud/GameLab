extends Control
## Plan page, shown before a run: a map of the level, the
## castle's ring of spots around the keep (any of them can hold a post, as many as the slots the
## player has bought), and the tower cards the player owns, which they drag onto a spot, or
## press a spot to place and lift one.
## Auto-place suggests a layout and Quick start reuses the last one. It shows the choice and
## asks for the run through signals; the run flow acts. Mouse only.

signal start_requested(layout: Array)
signal back_requested
## "+ Tower" was pressed: the player wants the next slot or Archer Post bought.
signal tower_requested

const FONT_PX := 20
const COLOUR_ARENA := Color(0.35, 0.4, 0.5)
const COLOUR_KEEP := Color(0.85, 0.8, 0.55)
const COLOUR_RANGE := Color(0.55, 0.75, 0.95, 0.25)
const COLOUR_MAGE_RANGE := Color(0.6, 0.48, 0.88, 0.25)
## How far out the ring's spots sit on the map (of the way to its edge): far enough that the
## buttons of neighbouring spots clear each other.
const SITE_FILL := 0.78
const COLOUR_SLOT := Color(0.95, 0.85, 0.5)
const MAGE_ID := "mage_post"
const EMPTY_SPOT := "Empty"
const HINT := "Drag a post onto a spot, or press a spot."

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _count: Label = %Count
@onready var _map: Control = %Map
@onready var _back: Button = %BackButton
@onready var _start: Button = %StartButton
@onready var _tower: Button = %TowerButton
@onready var _auto: Button = %AutoButton
@onready var _quick: Button = %QuickButton
@onready var _side: Control = %Side
@onready var _tray: GridContainer = %Tray

var _content: Dictionary
var _level_id := ""
var _level: Dictionary = {}
var _chosen: Array = []
## The castle's ring of spots ({id, name, x, y}, by id), the slots bought (how many posts may stand
## on it) and the Archer Post cards held.
var _spots: Dictionary = {}
var _slots := 0
var _cards := 0
## The Mage Post cards the player holds, on top of the Archer cards.
var _mage_cards := 0
## The layout of the last run on this level ("" none yet): what Quick start reuses.
var _saved: Array = []
var _site_buttons: Dictionary = {}


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_start.pressed.connect(func() -> void: start_requested.emit(_chosen.duplicate()))
	_auto.pressed.connect(auto_place)
	_quick.pressed.connect(func() -> void: start_requested.emit(_saved.duplicate()))
	_tower.pressed.connect(tower_requested.emit)
	# A lifted post goes back to the tray when let go anywhere that is not a free slot.
	for target in [self, _map, _side, _auto, _quick, _start, _back]:
		target.set_drag_forwarding(Callable(), _side_can_drop, _side_drop)
	_map.draw.connect(_draw_map)
	_map.resized.connect(_place_buttons)
	visibility_changed.connect(_on_visibility_changed)


## Shows the level's map with `layout` (entries: a spot id, or "mage:<spot id>") already placed.
## `saved` says the layout is the player's own from an earlier run, which Quick start can then
## reuse. The castle is set by `set_castle`.
func open(level_id: String, layout: Array, saved: bool, spots: Array, cards: int, mage_cards := 0, slots := -1) -> void:
	_level_id = level_id
	_level = _content["levels"][level_id]
	_chosen = layout.duplicate()
	_saved = layout.duplicate() if saved else []
	_title.text = "Plan your defence: %s" % _level["name"]
	_hint.text = HINT
	set_castle(spots, cards, mage_cards, slots)


## Sets what the player has: the ring's `spots`, the Archer Post `cards` and Mage Post
## `mage_cards` they hold and the `slots` they have bought (a post on every spot of `spots` when
## -1). Posts already placed stay, to the new limit, so buying a slot here keeps the plan.
func set_castle(spots: Array, cards: int, mage_cards := 0, slots := -1) -> void:
	_cards = cards
	_mage_cards = mage_cards
	_spots.clear()
	for spot in spots:
		_spots[str(spot["id"])] = spot
	_slots = _spots.size() if slots < 0 else slots
	while _chosen.size() > _slots:
		_chosen.pop_back()
	for button in _site_buttons.values():
		button.queue_free()
	_site_buttons.clear()
	for id in _spots:
		var button := Button.new()
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", FONT_PX)
		button.pressed.connect(_toggle.bind(id))
		button.set_drag_forwarding(_slot_drag.bind(id, button), _slot_can_drop.bind(id), _slot_drop.bind(id))
		_map.add_child(button)
		_site_buttons[id] = button
	_place_buttons()
	_refresh()


## The "+ Tower" button: `text` ("" hides it) and, when it cannot be pressed, why not.
func set_tower_offer(text: String, why_not := "") -> void:
	_tower.visible = text != ""
	_tower.text = text
	_tower.disabled = why_not != ""
	_tower.tooltip_text = why_not
	# The reason shows where the player looks, not only on hover.
	_hint.text = why_not if why_not != "" else HINT


## The posts placed now, as layout entries.
func chosen() -> Array:
	return _chosen.duplicate()


## Chooses or drops a site: an Archer while there is an Archer card left, then a Mage. At the
## limit, the oldest choice makes way and the new post is of its kind.
func _toggle(id: String) -> void:
	var at := _index_of(id)
	if at >= 0:
		_chosen.remove_at(at)
	elif _chosen.size() < _slots and _placed(_archer_id()) < _cards:
		_chosen.append(id)
	elif _chosen.size() < _slots and _placed(MAGE_ID) < _mage_cards:
		_chosen.append(HoldfastRules.layout_entry(id, MAGE_ID))
	elif not _chosen.is_empty():
		var oldest: String = _chosen.pop_front()
		_chosen.append(HoldfastRules.layout_entry(id, _tower_of(oldest)))
	_refresh()


## The suggested layout: the sites nearest where the enemies come from, Archers then Mages.
func auto_place() -> void:
	var counts := HoldfastMeta.post_counts(_slots, _cards, _mage_cards)
	var ids := HoldfastRules.best_sites(_spots.values(), _level.get("spawn_arcs", []), counts[0] + counts[1])
	_chosen = []
	for i in ids.size():
		_chosen.append(ids[i] if i < counts[0] else HoldfastRules.layout_entry(ids[i], MAGE_ID))
	_refresh()


func _archer_id() -> String:
	return str(_level["tower"]["id"])


## The tower id of a layout entry.
func _tower_of(entry: String) -> String:
	return MAGE_ID if ":" in entry else _archer_id()


## Where the spot `id` is in the layout, -1 when it holds no post.
func _index_of(id: String) -> int:
	for i in _chosen.size():
		if HoldfastRules.layout_spot(_chosen[i]) == id:
			return i
	return -1


func _placed(tower_id: String) -> int:
	var count := 0
	for entry in _chosen:
		if _tower_of(entry) == tower_id:
			count += 1
	return count


func _cards_of(tower_id: String) -> int:
	return _mage_cards if tower_id == MAGE_ID else _cards


func _refresh() -> void:
	for id in _site_buttons:
		var at := _index_of(id)
		_site_buttons[id].set_pressed_no_signal(at >= 0)
		# A placed post says what it is; the dot and range circle on the map say where.
		_site_buttons[id].text = _tower_name(_tower_of(_chosen[at])) if at >= 0 else EMPTY_SPOT
		_site_buttons[id].reset_size()
	_count.text = "Posts: %d of %d" % [_chosen.size(), mini(_slots, _cards + _mage_cards)]
	_start.disabled = _chosen.is_empty()
	_quick.disabled = _saved.is_empty()
	_refresh_cards()
	_place_buttons()
	_map.queue_redraw()


func _tower_name(tower_id: String) -> String:
	return "Mage" if tower_id == MAGE_ID else "Archer"


## One card for each post the level allows, Archers then Mages: the ones in hand can be dragged,
## the placed ones wait greyed.
func _refresh_cards() -> void:
	for child in _tray.get_children():
		_tray.remove_child(child)
		child.queue_free()
	for tower_id in [_archer_id(), MAGE_ID]:
		var tower: Dictionary = _content["towers"][tower_id]
		for i in _cards_of(tower_id):
			var in_hand: bool = i >= _placed(tower_id)
			var card := PanelContainer.new()
			card.name = "%sCard%d" % [tower_id, i]
			var label := Label.new()
			label.text = str(tower["name"]) if in_hand else "Placed"
			label.add_theme_font_size_override("font_size", FONT_PX)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(label)
			card.modulate = Color.WHITE if in_hand else Color(1, 1, 1, 0.45)
			card.set_drag_forwarding(_card_drag.bind(card, tower_id) if in_hand else Callable(), _side_can_drop, _side_drop)
			if in_hand:
				card.mouse_default_cursor_shape = Control.CURSOR_DRAG
			_tray.add_child(card)


## What is dragged: a post of `tower_id` from the tray (`from` ""), or one lifted off a slot.
func _post_data(from: String, tower_id: String) -> Dictionary:
	return {"kind": "tower", "tower": tower_id, "from": from}


func _drag_preview(held: Control, tower_id: String) -> void:
	# A preview can only be set while the viewport is dragging.
	if not held.get_viewport().gui_is_dragging():
		return
	var preview := Label.new()
	preview.text = str(_content["towers"][tower_id]["name"])
	preview.add_theme_font_size_override("font_size", FONT_PX)
	held.set_drag_preview(preview)


func _card_drag(_at: Vector2, card: Control, tower_id: String) -> Variant:
	_drag_preview(card, tower_id)
	return _post_data("", tower_id)


func _slot_drag(_at: Vector2, id: String, button: Control) -> Variant:
	var at := _index_of(id)
	if at < 0:
		return null
	_drag_preview(button, _tower_of(_chosen[at]))
	return _post_data(id, _tower_of(_chosen[at]))


## A slot takes a card from the tray while a post of its kind is left to place, or a post lifted
## from another slot.
func _slot_can_drop(_at: Vector2, data: Variant, id: String) -> bool:
	if not data is Dictionary or str(data.get("kind", "")) != "tower" or _index_of(id) >= 0:
		return false
	var from := str(data.get("from", ""))
	if from != "":
		return _index_of(from) >= 0
	var tower_id := str(data.get("tower", ""))
	return _chosen.size() < _slots and tower_id in [_archer_id(), MAGE_ID] and _placed(tower_id) < _cards_of(tower_id)


func _slot_drop(_at: Vector2, data: Variant, id: String) -> void:
	if not _slot_can_drop(_at, data, id):
		return
	var from := str(data["from"])
	if from == "":
		_chosen.append(HoldfastRules.layout_entry(id, str(data["tower"])))
	else:
		var at := _index_of(from)
		_chosen[at] = HoldfastRules.layout_entry(id, _tower_of(_chosen[at]))
	_refresh()


## Letting a lifted post go on the cards, the buttons, the map or anywhere else returns its card.
func _side_can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "tower" and _index_of(str(data.get("from", ""))) >= 0


func _side_drop(_at: Vector2, data: Variant) -> void:
	if _side_can_drop(_at, data):
		_chosen.remove_at(_index_of(str(data["from"])))
		_refresh()


## World units to map pixels: zoomed on the keep so the whole ring fills most of the map,
## whichever of its spots are owned yet.
func _scale() -> float:
	var reach := 100.0
	for spot in HoldfastMeta.castle_rules(_content).get("spots", []):
		reach = maxf(reach, Vector2(float(spot["x"]), float(spot["y"])).length())
	return minf(_map.size.x, _map.size.y) * 0.5 * SITE_FILL / reach


func _place_buttons() -> void:
	if _level.is_empty():
		return
	for id in _spots:
		var button: Button = _site_buttons.get(id)
		if button == null:
			continue
		var at: Vector2 = _map.size * 0.5 + Vector2(float(_spots[id]["x"]), float(_spots[id]["y"])) * _scale()
		button.reset_size()
		button.position = at - button.size * 0.5


func _draw_map() -> void:
	if _level.is_empty():
		return
	var scale := _scale()
	var centre: Vector2 = _map.size * 0.5
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), COLOUR_ARENA, false, 2.0)
	_map.draw_circle(centre, float(_level["keep_radius"]) * scale, COLOUR_KEEP)
	for id in _spots:
		var at: Vector2 = centre + Vector2(float(_spots[id]["x"]), float(_spots[id]["y"])) * scale
		_map.draw_circle(at, 6.0, COLOUR_SLOT)
		var placed := _index_of(id)
		if placed >= 0:
			var tower_id := _tower_of(_chosen[placed])
			_map.draw_circle(at, float(_content["towers"][tower_id]["range"]) * scale, COLOUR_MAGE_RANGE if tower_id == MAGE_ID else COLOUR_RANGE)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_start.grab_focus()
