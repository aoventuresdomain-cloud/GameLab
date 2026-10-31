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
## The Squad button was pressed: the player wants to see or change who goes on the run.
signal squad_requested
## A Recruit was picked for a placed post's spot (the id of the Recruit, "" for nobody).
signal recruit_posted(site: String, id: String)

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
const NO_BLESSING := "No blessing"
const NOBODY := "Nobody"
const QUICK_WHY := "Quick start needs a layout you have played here before."
const BLESSING_HINT := "A blessing lasts one run. Take one, or none."
const MAGE_HINT := "Drag a Mage Post onto a spot like an Archer Post."
## The one-time lines (each said once, the first time the page has the thing to say it about).
const HINT_BLESSINGS := "blessings"
const HINT_MAGE_POST := "mage_post"
const NEED_A_POST := "(place a post first)"
const RECRUIT_TIP := "Who stands at this post. With Posted Hand, a post with a Recruit on it shoots faster."

## A one-time hint was on the page as it opened; the run flow keeps it from showing again.
signal hint_seen(id: String)

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
@onready var _squad: Button = %SquadButton
@onready var _blessings: HBoxContainer = %Blessings
@onready var _blessing_text: Label = %BlessingText

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
## The blessing picked for the run ("" for none), and each blessing on offer's button by id.
var _blessing := ""
var _blessing_buttons: Dictionary = {}
## The one-time hint on the page now ("" for none), and where they are kept.
var _extra_hint := ""
var _hints: Node

## The hint's own line and the squad's, which sits under it.
var _hint_text := ""
var _squad_line := ""
## The squad's Recruits as [{id, name}], who is set on which spot ({spot id: Recruit id}), and the
## button under each spot that picks one.
var _squad_picks: Array = []
var _posted: Dictionary = {}
## False while the player does not own what a Recruit on a post is for (Posted Hand): no pickers then.
var _posting := true
var _recruit_buttons: Dictionary = {}


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_start.pressed.connect(func() -> void: start_requested.emit(_chosen.duplicate()))
	_auto.pressed.connect(auto_place)
	_quick.pressed.connect(func() -> void: start_requested.emit(_saved.duplicate()))
	_tower.pressed.connect(tower_requested.emit)
	_squad.pressed.connect(squad_requested.emit)
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
	_show_hint(HINT)
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
	for button in _site_buttons.values() + _recruit_buttons.values():
		button.queue_free()
	_site_buttons.clear()
	_recruit_buttons.clear()
	for id in _spots:
		var button := Button.new()
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", FONT_PX)
		button.pressed.connect(_toggle.bind(id))
		button.set_drag_forwarding(_slot_drag.bind(id, button), _slot_can_drop.bind(id), _slot_drop.bind(id))
		_map.add_child(button)
		_site_buttons[id] = button
		var picker := MenuButton.new()
		picker.flat = false
		picker.tooltip_text = RECRUIT_TIP
		picker.add_theme_font_size_override("font_size", FONT_PX)
		picker.get_popup().add_theme_font_size_override("font_size", FONT_PX)
		picker.get_popup().id_pressed.connect(_pick_recruit.bind(id))
		_map.add_child(picker)
		_recruit_buttons[id] = picker
	_place_buttons()
	_refresh()


## The "+ Tower" button: `text` ("" hides it) and, when it cannot be pressed, why not.
func set_tower_offer(text: String, why_not := "") -> void:
	_tower.visible = text != ""
	_tower.text = text
	_tower.disabled = why_not != ""
	_tower.tooltip_text = why_not
	# The reason shows where the player looks, not only on hover.
	_show_hint(why_not if why_not != "" else HINT)


## Offers the blessings in `offer` (ids from the pack) beside "No blessing", which is picked to begin
## with. An empty offer hides the choice (a tutorial, or nothing earned yet).
func set_blessings(offer: Array) -> void:
	for button in _blessing_buttons.values():
		_blessings.remove_child(button)
		button.queue_free()
	_blessing_buttons.clear()
	_blessing = ""
	_blessings.visible = not offer.is_empty()
	_blessing_text.visible = not offer.is_empty()
	_show_hint(_hint_text)
	if offer.is_empty():
		return
	var group := ButtonGroup.new()
	for id in offer + [""]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override("font_size", FONT_PX)
		button.text = str(_content["blessings"][id]["name"]) if id != "" else NO_BLESSING
		button.pressed.connect(_pick_blessing.bind(id))
		_blessings.add_child(button)
		_blessing_buttons[id] = button
	_blessing_buttons[""].button_pressed = true
	_pick_blessing("")


## Who goes on the run, by name: a line under the hint, and the tooltip of the Squad button.
## Who goes on the run, out of `known` Recruits; the button and the line wait for the first one.
func set_squad(names: Array, known := -1) -> void:
	var have := names.size() if known < 0 else known
	_squad.visible = have > 0
	_squad_line = "" if have == 0 else ("Squad: %s" % ", ".join(PackedStringArray(names)) if not names.is_empty() else "Squad: nobody")
	_squad.tooltip_text = "Pick who goes on the run"
	_show_hint(_hint_text)


## The squad's Recruits ([{id, name}]) and who is set on which spot ({spot id: Recruit id}): a placed post
## gets a button to pick one, who then stands at that post on the run. `offered` is false while that
## would do nothing (Posted Hand is not owned), which hides the buttons.
func set_posted(squad: Array, posted: Dictionary, offered := true) -> void:
	_squad_picks = squad
	_posted = posted
	_posting = offered
	_refresh()


func _pick_recruit(index: int, site: String) -> void:
	recruit_posted.emit(site, "" if index == 0 else str(_squad_picks[index - 1]["id"]))


## What the spot's Recruit button says: who is set on it, or Nobody.
func _posted_name(site: String) -> String:
	for pick in _squad_picks:
		if pick["id"] == _posted.get(site, ""):
			return str(pick["name"])
	return NOBODY


func bind_hints(settings: Node) -> void:
	_hints = settings


func _seen(id: String) -> bool:
	return _hints != null and _hints.has_seen_hint(id)


## The hint line, then in the same paragraph one thing the page has not said yet (the Mage Post cards
## in hand, the blessings, or why Quick start is shut), and under it the squad.
func _show_hint(text: String) -> void:
	_hint_text = text
	var extra := ""
	_extra_hint = ""
	# A reason (why "+ Tower" is shut) stands alone.
	if text == HINT:
		if _mage_cards > 0 and _placed(MAGE_ID) == 0 and not _seen(HINT_MAGE_POST):
			extra = MAGE_HINT
			_extra_hint = HINT_MAGE_POST
		elif _blessings.visible and not _seen(HINT_BLESSINGS):
			extra = BLESSING_HINT
			_extra_hint = HINT_BLESSINGS
		elif _saved.is_empty():
			extra = QUICK_WHY
	var line := "%s %s" % [text, extra] if extra != "" else text
	_hint.text = "%s\n%s" % [line, _squad_line] if _squad_line != "" else line


## The blessing picked for the run: an id, or "" for none.
func blessing() -> String:
	return _blessing


func _pick_blessing(id: String) -> void:
	_blessing = id
	_blessing_text.text = str(_content["blessings"][id]["text"]) if id != "" else "Play the level as it is."


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
	for id in _recruit_buttons:
		var picker: MenuButton = _recruit_buttons[id]
		picker.visible = _posting and _index_of(id) >= 0 and not _squad_picks.is_empty()
		picker.text = _posted_name(id)
		var popup := picker.get_popup()
		popup.clear()
		popup.add_item(NOBODY)
		for pick in _squad_picks:
			popup.add_item(str(pick["name"]))
		picker.reset_size()
	_count.text = "Posts: %d of %d" % [_chosen.size(), mini(_slots, _cards + _mage_cards)]
	_start.disabled = _chosen.is_empty()
	_start.text = "Start level" if not _chosen.is_empty() else "Start level\n%s" % NEED_A_POST
	_quick.disabled = _saved.is_empty()
	_quick.text = "Quick start" if not _saved.is_empty() else "Quick start (no layout yet)"
	_quick.tooltip_text = QUICK_WHY if _saved.is_empty() else ""
	_show_hint(_hint_text)
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
		# A moved post takes its Recruit with it.
		if _posted.has(from):
			recruit_posted.emit(id, str(_posted[from]))
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
		var picker: Control = _recruit_buttons.get(id)
		if picker != null:
			picker.reset_size()
			picker.position = Vector2(at.x - picker.size.x * 0.5, button.position.y + button.size.y + 2.0)


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
		if _extra_hint != "":
			hint_seen.emit(_extra_hint)
