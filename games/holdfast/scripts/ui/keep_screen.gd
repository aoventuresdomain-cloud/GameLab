extends Control
## Skill tree page: spend gold and stars on the upgrade tree, one radial web the player pans and
## zooms. Node positions (from the middle of the web, y down), short labels, the one-word section
## names on the rim and the tab each section belongs to come from the pack. Pressing a node opens its
## detail card on the side away from it, over the dimmed tree: the card shows only that node and is
## where it is bought or taken back. The page shows the profile and asks for changes through signals; the run flow acts
## on them.

signal back_requested
signal buy_requested(id: String)
## The whole tree taken back.
signal respec_requested
## One bought node taken back, from its card.
signal refund_requested(id: String)

const Hud = preload("res://scripts/ui/hud.gd")
const FONT_PX := 20
const DIMMED := Color(1, 1, 1, 0.45)
const OWNED_FILL := Color(0.2, 0.5, 0.3)
const OWNED_EDGE := Color(0.45, 0.85, 0.55)
## A round node: big enough to press at real size.
const NODE_SIZE := Vector2(44, 44)
const PRICE_PX := 14
const CLOSED_PX := 11
## Names under the nodes and on the rim keep their size on screen at any zoom, and the node names
## are left off when the web is too small for them to be told apart.
const LABEL_PX := 12
const LABEL_WIDTH := 96.0
const LABEL_GAP := 2.0
const LABELS_MIN_ZOOM := 0.6
const RIM_PX := 16
const RIM_SIZE := Vector2(100, 24)
## A section's name sits this far beyond its outermost node, and never nearer the middle than RIM_MIN.
const RIM_GAP := 56.0
const RIM_MIN := 120.0
## Link nodes (they join two parts of the web) have a dashed ring.
const LINK_PREFIX := "link_"
const LINK_DASHES := 16
const FAR_EDGE := Color(0.55, 0.62, 0.72)
const NODE_FILL := Color(0.14, 0.16, 0.21)
## The card keeps this far from the edge of the page.
const CARD_MARGIN := 24.0
## About 0.4, a power-of-two fraction so the stored scale equals the limit exactly.
const ZOOM_MIN := 0.375
const ZOOM_MAX := 2.5
## The tree opens at the size that shows everything on show, from OVERVIEW_ZOOM_MIN (below it the
## player pans) to OVERVIEW_ZOOM_MAX, so a node and its name stay easy to read and press.
## About 0.9, a binary fraction so the stored scale equals the limit exactly.
const OVERVIEW_ZOOM_MIN := 0.90625
const OVERVIEW_ZOOM_MAX := 1.5
## How visible the sections of other tabs are while a tab is in view.
const OTHER_TAB_ALPHA := 0.3
const ZOOM_STEP := 1.15
## A press that moves further than this is a drag that pans the web, not a click that buys.
const DRAG_PX := 6.0
## Space kept around a tab's sections, and the part of the web that must stay in view.
const FIT_PAD := 12.0
const KEEP_IN_VIEW := 120.0
const LINK_BOUGHT := Color(0.95, 0.75, 0.3, 0.9)
const LINK_OPEN := Color(0.55, 0.62, 0.72, 0.6)
const LINK_FORK := Color(0.9, 0.4, 0.35, 0.8)
const COLOUR_ACT := Color(0.95, 0.7, 0.25)
const COLOUR_SHORT := Color(0.95, 0.4, 0.35)
## The outline that shows where a controller or the keyboard is, apart from the act and done colours.
const COLOUR_FOCUS := Color(0.35, 0.6, 1.0)
const CARD_WIDTH := 480.0
const CARD_EDGE := Color(0.45, 0.5, 0.6)
## How long a node that a purchase made buyable glows, and the card's glow after a purchase.
const GLOW_SECONDS := 0.9
## What a stat means to the player, by the stat's own name without its tower or Hero scope.
const STAT_TEXT := {
	"keep_health": "keep health",
	"eclipse_widen": "wider Eclipse near a Mage Post",
	"eclipse_radius": "reach of a Mage Post's Eclipse bonus",
	"beam_reach": "beam reach: enemies start further out",
	"gold_multiplier": "gold from kills",
	"aura_dps": "aura damage",
	"aura_radius": "aura size",
	"staff_damage": "staff damage",
	"health": "health",
	"damage": "damage",
	"range": "range",
	"cooldown": "time between shots",
	"repair": "repair a second between waves",
	"extra_targets": "extra targets a shot",
	"lone_bonus": "damage on a lone target",
	"pierce": "enemies pierced",
	"burst_every": "shots between bursts",
	"burst_extra": "burst damage",
	"storm_every": "seconds between storms",
	"storm_share": "storm damage",
	"move_speed": "move speed",
	"attack.damage": "arrow damage",
	"attack.cooldown": "time between arrows",
	"attack.range": "arrow range",
	"attack.count": "arrows a shot",
	"attack.spread_degrees": "spread (degrees)",
	"ability.rapid_seconds": "barrage seconds",
	"ability.pierce": "barrage pierce",
	"ability.burn_dps": "burn damage a second",
	"ability.burn_seconds": "burn seconds",
	"ability.cooldown": "barrage cooldown (seconds)",
	"armour": "percent of damage turned away",
	"getup_time": "time to get up",
	"pickup_radius": "XP pickup reach",
	"hero_haste": "faster shots with the Hero near",
	"hero_radius": "how near the Hero must be",
	"crossfire": "damage when another post hit the same enemy",
	"burn_dps": "burn damage a second",
	"burn_seconds": "burn seconds",
	"rally_repair": "repair a second beside the Hero",
	"rally_shield": "damage turned away",
	"rally_radius": "how near the Hero must stand",
	"rally_seconds": "shield seconds",
	"last_light": "times its damage in the last volley",
	"last_light_radius": "how near the Hero must be",
	"watch_range": "Hero arrow range beside a post",
	"watch_radius": "how near the Hero must stand",
}

## The Hero path id the profile has picked (its section is the one the tree shows).
var selected_pillar := ""

@onready var _gold: Label = %GoldValue
@onready var _stars: Label = %StarsValue
@onready var _view: Control = %View
@onready var _web: Control = %Web
@onready var _tabs: HBoxContainer = %Tabs
@onready var _zoom_out: Button = %ZoomOut
@onready var _zoom_in: Button = %ZoomIn
@onready var _info: Label = %Info
@onready var _respec: Button = %RespecButton
@onready var _back: Button = %BackButton

var _profile: Node
## The look of an owned node.
var _owned_style := _make_owned_style()
var _owned_focus_style := _make_owned_style(COLOUR_FOCUS)
var _content: Dictionary
var _node_buttons: Dictionary = {}
## The name under each node, and the mark drawn on it (tick, star, dashed ring).
var _labels: Dictionary = {}
var _marks: Dictionary = {}
## The way each section lies from the middle, which is where its name goes on the rim.
var _rim_dirs: Dictionary = {}
var _styles: Dictionary = {}
## Each section's holder in the web: hiding it hides its nodes and their links.
var _section_columns: Dictionary = {}
## Each section's name on the rim, beyond the nodes of it that are shown.
var _headings: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _tab_group := ButtonGroup.new()
var _tab := ""
## True once the player (or the Hero page) has picked a tab, so opening the tree keeps it.
var _tab_picked := false
## True once the player has panned or zoomed, so opening the tree again keeps their view.
var _moved_view := false
var _panning := false
## A mouse button is down on a node, how far the pointer has moved since, and whether that made
## it a drag (the press then pans the web and buys nothing).
var _held := false
var _moved := 0.0
var _dragged := false
var _card: Control
var _card_id := ""
var _card_title: Label
var _card_close: Button
var _card_lines: VBoxContainer
var _card_extra: VBoxContainer
var _card_tick: Control
var _card_price: Label
var _card_buy: Button
var _card_refund: Button
var _card_note: Label
var _card_panel: PanelContainer
var _card_row: HBoxContainer
var _card_style: StyleBoxFlat
## The node whose button had the focus when its card opened, which gets it back on close.
var _card_from: Button
## Nodes glowing because the last purchase made them buyable.
var _glowing: Array = []


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_respec.pressed.connect(respec_requested.emit)
	_zoom_out.pressed.connect(zoom_by.bind(1.0 / ZOOM_STEP))
	_zoom_in.pressed.connect(zoom_by.bind(ZOOM_STEP))
	_view.gui_input.connect(_on_view_input)
	_view.resized.connect(_fit_view)
	_web.draw.connect(_draw_links)
	visibility_changed.connect(_on_visibility_changed)
	_build_tree()
	_build_card()


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	profile.notice.connect(show_info)
	refresh()


## A line at the foot of the page: why something was refused.
func show_info(text: String) -> void:
	_info.text = text


## Redraws everything from the profile.
func refresh() -> void:
	if _profile == null:
		return
	_gold.text = Hud.format_number(_profile.get_gold())
	_stars.text = str(_profile.get_stars())
	selected_pillar = _profile.get_pillar()
	var owned: Array = _profile.get_upgrades()
	for id in _node_buttons:
		var node: Dictionary = _content["upgrade_nodes"][id]
		var button: Button = _node_buttons[id]
		var bought: bool = id in owned
		var closed: bool = _profile.why_not_buy(id).begins_with("Closed")
		var near: bool = bought or _profile.is_near(id)
		button.visible = _profile.is_visible(id)
		_labels[id].visible = button.visible
		button.tooltip_text = _tip_text(id)
		# The price on the node (a tick when owned); the name is under it and on its tooltip.
		button.text = "" if bought else ("closed" if closed else _face(node))
		button.add_theme_font_size_override("font_size", CLOSED_PX if closed else PRICE_PX)
		var state := "owned" if bought else ("closed" if closed else ("open" if near else "far"))
		_marks[id].set_meta("state", state)
		_marks[id].queue_redraw()
		_light(button, state, _is_link(id))
		# Every node can be pressed: its card says what is open to the player, and what is not.
		button.set_pressed_no_signal(bought)
		# Only what is one buy away (or already bought) is drawn in full; the rest is dimmed.
		button.modulate = Color.WHITE if near else DIMMED
		_labels[id].modulate = button.modulate
	for section in _section_columns:
		_section_columns[section].visible = (not _content["hero_paths"].has(section) or section == selected_pillar) and _section_has_shown_node(section)
		_place_heading(section)
	_refresh_tabs()
	_sync_labels()
	_web.queue_redraw()
	_respec.disabled = owned.is_empty()
	_respec.text = refund_all_text(_profile.get_respec_stars(), _profile.get_respec_gold_change()) if not owned.is_empty() else "Refund all"
	_info.text = ""
	if _card.visible:
		_fill_card()


static func _make_owned_style(edge := OWNED_EDGE, bordered := true) -> StyleBoxFlat:
	return _round_style(OWNED_FILL, edge, bordered)


static func _round_style(fill: Color, edge: Color, bordered: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(3 if bordered else 0)
	box.set_corner_radius_all(int(NODE_SIZE.x * 0.5))
	return box


## The look of a node by state: owned (green), open (an amber ring: one buy away), far or closed
## (a grey ring). A link node's ring is drawn dashed on its mark, so its box has no border.
func _node_style(state: String, link: bool, hover: bool) -> StyleBoxFlat:
	var key := "%s%s%s" % [state, link, hover]
	if not _styles.has(key):
		var fill := OWNED_FILL if state == "owned" else NODE_FILL
		_styles[key] = _round_style(fill.lightened(0.15) if hover else fill, _edge(state), not link)
	return _styles[key]


static func _edge(state: String) -> Color:
	return OWNED_EDGE if state == "owned" else (COLOUR_ACT if state == "open" else FAR_EDGE)


## What the node's button looks like in a state; every state of the button looks the same, save
## a brighter fill under the pointer.
func _light(button: Button, state: String, link: bool) -> void:
	var rest: StyleBoxFlat = _owned_style if state == "owned" and not link else _node_style(state, link, false)
	for name in ["normal", "pressed", "disabled"]:
		button.add_theme_stylebox_override(name, rest)
	for name in ["hover", "hover_pressed"]:
		button.add_theme_stylebox_override(name, _node_style(state, link, true))
	button.add_theme_stylebox_override("focus", _owned_focus_style if state == "owned" else _focus_style(int(NODE_SIZE.x * 0.5)))


func _is_link(id: String) -> bool:
	return id.begins_with(LINK_PREFIX)


## True when the line from a node to one it needs joins two sections: a link node reaching over.
func _joins_sections(id: String, required: String) -> bool:
	return _is_link(id) and _content["upgrade_nodes"][required]["branch"] != _content["upgrade_nodes"][id]["branch"]


## Where a node sits in the web: its place in the pack, from the middle of the web.
func _point(id: String) -> Vector2:
	var at: Dictionary = _content["upgrade_nodes"][id]["at"]
	return Vector2(float(at["x"]), float(at["y"]))


## What a node's button says: its price, with room above it for the star of a star price.
func _face(node: Dictionary) -> String:
	return ("\n%d" if HoldfastMeta.is_star_node(node) else "%d") % int(node["cost"])


func _build_tree() -> void:
	for section in _sections_in_order():
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_web.add_child(holder)
		_section_columns[str(section["id"])] = holder
		var middle := Vector2.ZERO
		var count := 0
		for id in _content["upgrade_nodes"]:
			var node: Dictionary = _content["upgrade_nodes"][id]
			if node["branch"] != section["id"]:
				continue
			var point := _point(id)
			middle += point
			count += 1
			var button := Button.new()
			button.clip_text = true
			# Pass the mouse on, so a wheel turn or a drag that starts on a node still reaches the view.
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.custom_minimum_size = NODE_SIZE
			button.position = point - NODE_SIZE * 0.5
			button.button_down.connect(_node_pressed)
			button.button_up.connect(_node_released)
			button.pressed.connect(_node_clicked.bind(id))
			holder.add_child(button)
			_node_buttons[id] = button
			var mark := Control.new()
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(mark)
			mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			mark.draw.connect(_draw_mark.bind(id))
			_marks[id] = mark
			var text := str(node.get("label", node["name"]))
			var width := get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_PX).x + 4.0
			var label := _caption(text, LABEL_PX, Vector2(width, LABEL_PX + 4))
			holder.add_child(label)
			label.reset_size()
			_labels[id] = label
		_rim_dirs[str(section["id"])] = (middle / maxf(count, 1)).normalized() if middle.length() > 1.0 else Vector2.LEFT
		var heading := _caption(str(section.get("rim", section["name"])), RIM_PX, RIM_SIZE)
		heading.pivot_offset = RIM_SIZE * 0.5
		heading.theme_type_variation = &"HudCaption"
		holder.add_child(heading)
		_headings[str(section["id"])] = heading
	_place_labels()
	# The web is as big as everything in it, so what it draws is never culled.
	_web.custom_minimum_size = _holders_rect(_section_columns.values()).end


## Each node's name goes on the side of it (below, above, right, left, then the corners) that crowds the other nodes
## least, worked out once for the whole web at real size. A name grows from the edge of its
## node, so it never runs back over it as it keeps its size when the web is zoomed out.
func _place_labels() -> void:
	var half := NODE_SIZE * 0.5
	var taken: Array[Rect2] = []
	for id in _node_buttons:
		taken.append(Rect2(_point(id) - half, NODE_SIZE))
	for id in _labels:
		var label: Label = _labels[id]
		var at := _point(id)
		var box := label.size
		# Where the name hangs from, and the point of the name that sits on it.
		var options: Array = [
			[at + Vector2(0, half.y + LABEL_GAP), Vector2(box.x * 0.5, 0)],
			[at + Vector2(0, -half.y - LABEL_GAP), Vector2(box.x * 0.5, box.y)],
			[at + Vector2(half.x + LABEL_GAP, 0), Vector2(0, box.y * 0.5)],
			[at + Vector2(-half.x - LABEL_GAP, 0), Vector2(box.x, box.y * 0.5)],
			[at + half * 0.7 + Vector2.ONE * LABEL_GAP, Vector2.ZERO],
			[at + Vector2(-half.x * 0.7 - LABEL_GAP, half.y * 0.7 + LABEL_GAP), Vector2(box.x, 0)],
			[at + Vector2(half.x * 0.7 + LABEL_GAP, -half.y * 0.7 - LABEL_GAP), Vector2(0, box.y)],
			[at - half * 0.7 - Vector2.ONE * LABEL_GAP, box],
		]
		var best := 0
		var best_cost := INF
		for i in options.size():
			var rect := Rect2(options[i][0] - options[i][1], box)
			var cost := float(i) * 0.1
			for other in taken:
				cost += rect.intersection(other).get_area() if other != Rect2(at - half, NODE_SIZE) else 0.0
			if cost < best_cost:
				best = i
				best_cost = cost
		label.pivot_offset = options[best][1]
		label.position = options[best][0] - options[best][1]


## A name that does not take the mouse, centred in a box of a given size.
func _caption(text: String, font_px: int, box: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.1))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = box
	return label


## The tick of an owned node, the star of a star price, the dashed ring of a link.
func _draw_mark(id: String) -> void:
	var mark: Control = _marks[id]
	var state: String = mark.get_meta("state", "far")
	var middle := NODE_SIZE * 0.5
	if _is_link(id):
		var step := TAU / LINK_DASHES
		for i in LINK_DASHES:
			mark.draw_arc(middle, middle.x - 1.5, i * step, (i + 0.55) * step, 4, _edge(state), 3.0, true)
	if state == "owned":
		mark.draw_polyline(PackedVector2Array([Vector2(12, 23), Vector2(19, 30), Vector2(32, 15)]), Color.WHITE, 4.0, true)
	elif state != "closed" and HoldfastMeta.is_star_node(_content["upgrade_nodes"][id]):
		var points := PackedVector2Array()
		for i in 10:
			var angle := -PI * 0.5 + i * PI * 0.2
			points.append(Vector2(middle.x, 12.0) + Vector2.from_angle(angle) * (6.0 if i % 2 == 0 else 2.6))
		mark.draw_colored_polygon(points, COLOUR_ACT)


## Names keep their size on screen whatever the zoom; node names go when the web is too small for them.
func _sync_labels() -> void:
	var zoom := _web.scale.x
	if zoom <= 0.0:
		return
	var shown := zoom >= LABELS_MIN_ZOOM
	for id in _labels:
		_labels[id].scale = Vector2.ONE / zoom
		_labels[id].self_modulate.a = 1.0 if shown else 0.0
	for section in _headings:
		_headings[section].scale = Vector2.ONE / zoom


## The tab labels in section order, for the sections that are shown.
func tab_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for section in _sections_in_order():
		var label := str(section.get("tab", section["name"]))
		if _section_columns[section["id"]].visible and not label in out:
			out.append(label)
	return out


## True when some node of the section is on show (the heading goes with the section).
func _section_has_shown_node(section: String) -> bool:
	for id in _node_buttons:
		if _content["upgrade_nodes"][id]["branch"] == section and _node_buttons[id].visible:
			return true
	return false


## The section's name sits on the rim, out along the way the section lies, just beyond its
## outermost node on show.
func _place_heading(section: String) -> void:
	var far := 0.0
	var found := false
	for id in _node_buttons:
		if _content["upgrade_nodes"][id]["branch"] == section and _node_buttons[id].visible:
			far = maxf(far, _point(id).length())
			found = true
	if found:
		_headings[section].position = _rim_dirs[section] * maxf(far + RIM_GAP, RIM_MIN) - RIM_SIZE * 0.5


func _sections_in_order() -> Array:
	var sections: Array = _content["upgrade_sections"].values()
	sections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	return sections


## One button along the top for each tab; it moves the view to its sections.
func _refresh_tabs() -> void:
	var names := tab_names()
	if names == PackedStringArray(_tab_buttons.keys()):
		return
	for button in _tab_buttons.values():
		_tabs.remove_child(button)
		button.queue_free()
	_tab_buttons.clear()
	for label in names:
		var button := _button(label, FONT_PX, 6)
		button.toggle_mode = true
		button.button_group = _tab_group
		button.pressed.connect(show_tab.bind(label))
		_tabs.add_child(button)
		_tab_buttons[label] = button
	if not _tab in names and not names.is_empty():
		show_tab(names[0], false)


## Moves the view to a tab's sections at real size, or smaller when they would not fit.
func show_tab(label: String, picked := true) -> void:
	if not label in tab_names():
		return
	_tab = label
	_tab_picked = _tab_picked or picked
	_moved_view = false
	if _tab_buttons.has(label):
		_tab_buttons[label].set_pressed_no_signal(true)
	var rect := _tab_rect(label)
	# Until the page is laid out the view has no size; its resized signal calls this again.
	if rect.size == Vector2.ZERO or _view.size == Vector2.ZERO:
		return
	var room := _view.size - Vector2.ONE * FIT_PAD * 2.0
	var zoom := clampf(minf(1.0, minf(room.x / rect.size.x, room.y / rect.size.y)), ZOOM_MIN, ZOOM_MAX)
	_web.scale = Vector2.ONE * zoom
	_web.position = _view.size * 0.5 - rect.get_center() * zoom
	_sync_labels()
	_keep_in_view()
	_fade_other_tabs(true)
	_web.queue_redraw()


## Opening the tree: everything on show in one view, as large as fits between OVERVIEW_ZOOM_MIN
## and OVERVIEW_ZOOM_MAX.
## When it cannot all fit at that size the view is centred on what the player owns (or on the
## middle of what is shown, when they own nothing yet) and they pan from there.
func show_overview() -> void:
	var holders := _section_columns.values().filter(func(holder: Control) -> bool: return holder.visible)
	var rect := _holders_rect(holders)
	if rect.size == Vector2.ZERO or _view.size == Vector2.ZERO:
		return
	var room := _view.size - Vector2.ONE * FIT_PAD * 2.0
	var fit := minf(room.x / rect.size.x, room.y / rect.size.y)
	var zoom := clampf(fit, OVERVIEW_ZOOM_MIN, OVERVIEW_ZOOM_MAX)
	var centre := rect.get_center()
	if fit < OVERVIEW_ZOOM_MIN:
		var owned_rect := Rect2()
		var found := false
		for id in (_profile.get_upgrades() if _profile != null else []):
			if _node_buttons.has(id) and _node_buttons[id].visible:
				var node_rect := Rect2(_node_buttons[id].position, _node_buttons[id].size.max(NODE_SIZE))
				owned_rect = node_rect if not found else owned_rect.merge(node_rect)
				found = true
		if found:
			centre = owned_rect.get_center()
	_web.scale = Vector2.ONE * zoom
	_web.position = _view.size * 0.5 - centre * zoom
	_sync_labels()
	_keep_in_view()
	_fade_other_tabs(false)
	_web.queue_redraw()


## The view settles again when the page is resized: the tab the player picked, or the overview.
func _fit_view() -> void:
	if _moved_view:
		return
	if _tab_picked:
		show_tab(_tab, false)
	else:
		show_overview()


## While a tab is in view the sections of the other tabs fade, so what shows at its edges is not
## read as part of it; panning or zooming brings them back.
func _fade_other_tabs(fade: bool) -> void:
	for section in _sections_in_order():
		var here := str(section.get("tab", section["name"])) == _tab
		_section_columns[section["id"]].modulate.a = OTHER_TAB_ALPHA if fade and not here else 1.0


## The area the shown sections of a tab cover in the web, headings included.
func _tab_rect(label: String) -> Rect2:
	var holders := []
	for section in _sections_in_order():
		if str(section.get("tab", section["name"])) == label and _section_columns[section["id"]].visible:
			holders.append(_section_columns[section["id"]])
	return _holders_rect(holders)


func _holders_rect(holders: Array) -> Rect2:
	var rect := Rect2()
	var found := false
	for holder in holders:
		for child in holder.get_children():
			if not child.visible:
				continue
			var child_rect := Rect2(child.position, child.size.max(child.get_combined_minimum_size()))
			rect = child_rect if not found else rect.merge(child_rect)
			found = true
	return rect


func zoom_by(factor: float, around := Vector2(-1, -1)) -> void:
	var point := _view.size * 0.5 if around.x < 0.0 else around
	var zoom := clampf(_web.scale.x * factor, ZOOM_MIN, ZOOM_MAX)
	_moved_view = true
	_fade_other_tabs(false)
	_web.position = point - (point - _web.position) * (zoom / _web.scale.x)
	_web.scale = Vector2.ONE * zoom
	_sync_labels()
	_keep_in_view()


## Drag anywhere (a node included) to pan, wheel, trackpad scroll or pinch to zoom at the pointer.
func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# A trackpad sends many small turns: the factor says how much of a step each is.
			var turn: float = event.factor if event.factor > 0.0 else 1.0
			zoom_by(pow(ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP, turn), event.position)
			accept_event()
	elif event is InputEventMouseMotion and (_panning or _held):
		_moved += event.relative.length()
		if _held and _moved > DRAG_PX:
			_dragged = true
			_panning = true
		if _panning:
			_moved_view = true
			_fade_other_tabs(false)
			_web.position += event.relative
			_keep_in_view()
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor, event.position)
		accept_event()
	elif event is InputEventPanGesture:
		_moved_view = true
		_fade_other_tabs(false)
		_web.position -= event.delta * 20.0
		_keep_in_view()
		accept_event()


## A press on a node may turn into a drag, so it buys only when let go without having moved.
func _node_pressed() -> void:
	_held = true
	_moved = 0.0
	_dragged = false


func _node_released() -> void:
	_held = false
	_panning = false


func _node_clicked(id: String) -> void:
	if _dragged:
		_dragged = false
		return
	open_card(id)


## Never lets the shown sections be panned out of sight altogether.
func _keep_in_view() -> void:
	var holders := _section_columns.values().filter(func(holder: Control) -> bool: return holder.visible)
	var rect := _holders_rect(holders)
	if rect.size == Vector2.ZERO:
		return
	var zoom := _web.scale.x
	var low := Vector2.ONE * KEEP_IN_VIEW - rect.end * zoom
	var high := _view.size - Vector2.ONE * KEEP_IN_VIEW - rect.position * zoom
	_web.position = _web.position.clamp(low, high)
	_follow_view_tab()


## The tab lit is the one whose sections are centred nearest the middle of the view.
func _follow_view_tab() -> void:
	if _view.size == Vector2.ZERO or _web.scale.x <= 0.0:
		return
	var middle := (_view.size * 0.5 - _web.position) / _web.scale.x
	var best := ""
	var best_gap := INF
	for label in tab_names():
		var gap := _tab_rect(label).get_center().distance_to(middle)
		if gap < best_gap:
			best = label
			best_gap = gap
	for label in _tab_buttons:
		_tab_buttons[label].set_pressed_no_signal(label == best)


## A straight line from each node to the nodes it needs, dashed where a link node joins two
## sections; a dashed red one between the two sides of a fork.
func _draw_links() -> void:
	var owned: Array = _profile.get_upgrades() if _profile != null else []
	for id in _node_buttons:
		var node: Dictionary = _content["upgrade_nodes"][id]
		if not _node_buttons[id].visible:
			continue
		var here := _point(id)
		for required in node.get("requires", []):
			if not _node_buttons[required].visible:
				continue
			var colour := LINK_BOUGHT if id in owned and required in owned else LINK_OPEN
			if _joins_sections(id, required):
				_web.draw_dashed_line(_point(required), here, colour, 3.0, 8.0)
			else:
				_web.draw_line(_point(required), here, colour, 3.0, true)
		for other_id in node.get("excludes", []):
			if str(other_id) > id and _node_buttons[other_id].visible:
				_web.draw_dashed_line(here, _point(other_id), LINK_FORK, 3.0, 8.0)


## A compact button at the screen's text size: the theme's button look with slim margins.
func _button(text: String, font_px := FONT_PX, margin := 3) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_px)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(style_name).duplicate()
		style.content_margin_top = margin
		style.content_margin_bottom = margin
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(style_name, style)
	return button


## A transparent box with a blue outline: where a controller or the keyboard is.
static func _focus_style(radius := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = COLOUR_FOCUS
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	return box


# ------------------------------------------------------------------ the detail card

## The card is built here, hidden, over the whole page: a dim backdrop (a press on it closes the
## card) and a panel in the middle that shows one node.
func _build_card() -> void:
	_card = Control.new()
	_card.name = "Card"
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.gui_input.connect(_on_card_backdrop_input)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The card stands at one side of the page and an empty space fills the rest, so it can be put
	# on the side away from the node it shows.
	_card_row = HBoxContainer.new()
	_card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_row)
	_card_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(CARD_MARGIN))
	var space := Control.new()
	space.name = "Space"
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_row.add_child(space)
	_card_panel = PanelContainer.new()
	_card_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_panel.name = "Panel"
	_card_panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(0.14, 0.16, 0.21)
	_card_style.border_color = CARD_EDGE
	_card_style.set_border_width_all(3)
	_card_style.set_corner_radius_all(10)
	_card_style.set_content_margin_all(16.0)
	_card_panel.add_theme_stylebox_override("panel", _card_style)
	_card_row.add_child(_card_panel)
	_card_row.move_child(_card_panel, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 28)
	_card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_card_title)
	_card_close = _button("\u00d7", 28, 0)
	_card_close.name = "Close"
	_card_close.add_theme_stylebox_override("focus", _focus_style())
	_card_close.pressed.connect(close_card)
	header.add_child(_card_close)
	_card_lines = VBoxContainer.new()
	column.add_child(_card_lines)
	_card_extra = VBoxContainer.new()
	_card_extra.add_theme_constant_override("separation", 6)
	column.add_child(_card_extra)
	_card_note = _card_label("")
	_card_note.modulate = Color(1, 1, 1, 0.75)
	column.add_child(_card_note)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	_card_tick = Control.new()
	_card_tick.custom_minimum_size = Vector2(36, 36)
	_card_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_tick.draw.connect(_draw_tick)
	footer.add_child(_card_tick)
	_card_price = _card_label("")
	_card_price.add_theme_font_size_override("font_size", 24)
	_card_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_card_price)
	_card_buy = _act_button("Buy")
	_card_buy.pressed.connect(_card_buy_pressed)
	footer.add_child(_card_buy)
	_card_refund = _button("Refund", 24, 3)
	_card_refund.add_theme_stylebox_override("focus", _focus_style())
	_card_refund.pressed.connect(func() -> void: refund_requested.emit(_card_id))
	footer.add_child(_card_refund)


func _card_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## The one amber button of a card.
func _act_button(text: String) -> Button:
	var button := _button(text, 24, 3)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = COLOUR_ACT if state != "hover" else COLOUR_ACT.lightened(0.2)
		box.set_corner_radius_all(6)
		box.content_margin_left = 24.0
		box.content_margin_right = 24.0
		box.content_margin_top = 4.0
		box.content_margin_bottom = 4.0
		button.add_theme_stylebox_override(state, box)
		button.add_theme_color_override("font_color" if state == "normal" else "font_%s_color" % state, Color(0.1, 0.1, 0.12))
	button.add_theme_color_override("font_focus_color", Color(0.1, 0.1, 0.12))
	button.add_theme_stylebox_override("focus", _focus_style())
	return button


func _draw_tick() -> void:
	_card_tick.draw_circle(Vector2(18, 18), 17.0, OWNED_FILL)
	_card_tick.draw_arc(Vector2(18, 18), 17.0, 0.0, TAU, 32, OWNED_EDGE, 2.0, true)
	_card_tick.draw_polyline(PackedVector2Array([Vector2(9, 18), Vector2(16, 25), Vector2(27, 11)]), Color.WHITE, 4.0, true)


## Shows the card of one node over the dimmed tree. The focus goes to what the player most likely
## wants: Buy, else the close button. Never Refund, so that Enter or a second A cannot take back what
## was just looked at.
func open_card(id: String) -> void:
	if _profile == null or not _content["upgrade_nodes"].has(id):
		return
	_card_id = id
	_card_from = _node_buttons.get(id)
	_fill_card()
	_place_card()
	_card.visible = true
	_set_tree_focus(false)
	for control in [_card_buy, _card_close]:
		if control.visible and not control.disabled:
			control.grab_focus()
			break


## The card stands on the half of the page away from its node, so it never hides it.
func _place_card() -> void:
	var node_x := size.x * 0.5
	if _card_from != null and _card_from.is_visible_in_tree():
		node_x = _card_from.get_global_rect().get_center().x - get_global_rect().position.x
	_card_row.move_child(_card_panel, 0 if node_x > size.x * 0.5 else 1)


func close_card() -> void:
	if not _card.visible:
		return
	_card.visible = false
	_card_id = ""
	_set_tree_focus(true)
	if _card_from != null and _card_from.is_visible_in_tree():
		_card_from.grab_focus()
	_card_from = null


## While the card is open the page behind it cannot take the focus.
func _set_tree_focus(on: bool) -> void:
	$Margin.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if on else Control.FOCUS_BEHAVIOR_DISABLED


func _on_card_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_card()


## Escape on the keyboard, B on a controller.
func _input(event: InputEvent) -> void:
	if _card != null and _card.visible and event.is_action_pressed("ui_cancel"):
		close_card()
		get_viewport().set_input_as_handled()


## Fills the card from the profile: only this node, never one further on.
func _fill_card() -> void:
	var id := _card_id
	var node: Dictionary = _content["upgrade_nodes"][id]
	var owned: bool = id in _profile.get_upgrades()
	_card_title.text = str(node["name"])
	_clear(_card_lines)
	_clear(_card_extra)
	var lines: Array = _profile.get_effect_lines(id)
	for line in lines:
		var change := _num(float(line["after"])) if owned else "%s -> %s" % [_num(float(line["before"])), _num(float(line["after"]))]
		_card_lines.add_child(_card_label("%s %s" % [_capital(_stat_text(str(line["stat"]))), change]))
	if lines.is_empty() or node.has("text"):
		var text := _effect_text(id)
		if text != "":
			_card_lines.add_child(_card_label(text))
	if node.has("excludes"):
		var names: PackedStringArray = []
		for other in node["excludes"]:
			names.append(str(_content["upgrade_nodes"][other]["name"]))
		_card_extra.add_child(_card_label("Replaces %s" % ", ".join(names)))
	if node.has("hero") and node.has("tower"):
		_card_extra.add_child(_card_label("Joins %s and %s" % [_content["hero_paths"][node["hero"]]["name"], _content["towers"][node["tower"]]["name"]]))
	if int(node.get("grants", {}).get("mage_cards", 0)) > 0:
		_card_extra.add_child(_gate_cards())
	_card_tick.visible = owned
	_card_buy.visible = not owned
	_card_refund.visible = owned
	_card_price.remove_theme_font_override("font")
	_card_price.remove_theme_color_override("font_color")
	var reason: String = _profile.why_not_refund(id) if owned else _profile.why_not_buy(id)
	var shortfall := _shortfall(node, reason)
	_card_note.text = "" if reason == "" or shortfall > 0 else reason
	if owned:
		var gain: Dictionary = _profile.get_refund_gain(id)
		_card_price.text = "+%d gold" % int(gain["gold"]) if int(gain["stars"]) == 0 else "+%d %s, fee %d gold" % [int(gain["stars"]), "star" if int(gain["stars"]) == 1 else "stars", -int(gain["gold"])]
		_card_price.add_theme_font_override("font", _bold_font())
		_card_refund.disabled = reason != ""
	else:
		_card_price.text = _price(node) + (" gold" if not HoldfastMeta.is_star_node(node) else "")
		if shortfall > 0:
			# A cue besides the red: the words say how much is missing.
			_card_price.text += "  (need %d more)" % shortfall
			_card_price.add_theme_color_override("font_color", COLOUR_SHORT)
		_card_buy.disabled = reason != ""


## How much gold or stars short the player is for a node refused only for want of them (else 0).
func _shortfall(node: Dictionary, reason: String) -> int:
	if reason == "Not enough gold":
		return int(node["cost"]) - _profile.get_gold()
	if reason == "Not enough stars":
		return int(node["cost"]) - _profile.get_stars()
	return 0


## The Tower Gate shows its towers to pick one from: the Mage Post, built, and two dark
## silhouettes for the towers still to come.
func _gate_cards() -> Control:
	var row := HBoxContainer.new()
	row.name = "GateCards"
	row.add_theme_constant_override("separation", 10)
	for i in 3:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(130, 64)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.3, 0.2, 0.5) if i == 0 else Color(0.08, 0.09, 0.11)
		box.border_color = Color(0.6, 0.48, 0.88) if i == 0 else Color(0.2, 0.22, 0.27)
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", box)
		if i == 0:
			var label := _card_label(str(_content["towers"]["mage_post"]["name"]))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			panel.add_child(label)
		row.add_child(panel)
	return row


func _clear(box: Control) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _bold_font() -> Font:
	var font := FontVariation.new()
	font.base_font = get_theme_default_font()
	font.variation_embolden = 0.9
	return font


static func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


static func _num(value: float) -> String:
	return _trim(snappedf(value, 0.01))


## Buying from the card closes it, and the nodes the buy made buyable light up on the tree behind
## it. A refused buy leaves the card open with its reason.
func _card_buy_pressed() -> void:
	var id := _card_id
	var before := _buyable_ids()
	buy_requested.emit(id)
	if id in _profile.get_upgrades():
		close_card()
		_light_up(before, id)


func _buyable_ids() -> Array:
	return _node_buttons.keys().filter(func(id: String) -> bool: return _profile.is_visible(id) and _profile.why_not_buy(id) == "")


func _light_up(before: Array, bought: String) -> void:
	_glowing = _buyable_ids().filter(func(id: String) -> bool: return not id in before and id != bought)
	for id in _glowing:
		var button: Button = _node_buttons[id]
		button.modulate = COLOUR_ACT.lightened(0.5)
		create_tween().tween_property(button, "modulate", Color.WHITE, GLOW_SECONDS)
	get_tree().create_timer(GLOW_SECONDS).timeout.connect(_glowing.clear)


func _effect_text(id: String) -> String:
	var node: Dictionary = _content["upgrade_nodes"][id]
	if node.has("text"):
		return str(node["text"])
	var parts: PackedStringArray = []
	if int(node.get("grants", {}).get("slots", 0)) > 0:
		parts.append("+%d castle slot" % int(node["grants"]["slots"]))
	if int(node.get("grants", {}).get("cards", 0)) > 0:
		parts.append("+%d Archer Post card" % int(node["grants"]["cards"]))
	var effects := _effects_text(node.get("effects", []))
	if effects != "":
		parts.append(effects)
	return ", ".join(parts)


## What a node costs as its button and the Next line say it: a gold price as a bare number.
static func _price(node: Dictionary) -> String:
	return HoldfastMeta.cost_text(node) if HoldfastMeta.is_star_node(node) else str(int(node["cost"]))


static func _effects_text(effects: Array) -> String:
	var parts: PackedStringArray = []
	for effect in effects:
		var what := _stat_text(str(effect["stat"]))
		if effect.has("add"):
			parts.append("%s%s %s" % ["+" if float(effect["add"]) >= 0.0 else "", _trim(float(effect["add"])), what])
		if effect.has("multiply"):
			parts.append("x%s %s" % [_trim(float(effect["multiply"])), what])
	return ", ".join(parts)


## "tower.range" is "range", "hero.attack.damage" is "arrow damage": the scope is dropped.
## The Refund all button: the gold and the stars it gives back, and a fee only as a fee.
static func refund_all_text(stars: int, change: int) -> String:
	var parts := PackedStringArray()
	if change > 0 or stars == 0:
		parts.append("%s%s gold" % ["+" if change >= 0 else "-", Hud.format_number(absi(change))])
	if stars > 0:
		parts.append("+%d %s" % [stars, "star" if stars == 1 else "stars"])
	if change < 0 and stars > 0:
		parts.append("fee %s gold" % Hud.format_number(-change))
	return "Refund all: %s" % ", ".join(parts)


static func _stat_text(stat: String) -> String:
	var field := stat
	for scope in ["tower.", "hero.", "recruit."]:
		if stat.begins_with(scope):
			field = stat.substr(scope.length())
	return STAT_TEXT.get(field, field)


## The hover tooltip: the node's name and what it does, nothing more.
func _tip_text(id: String) -> String:
	var node: Dictionary = _content["upgrade_nodes"][id]
	return "%s: %s" % [node["name"], _effect_text(id)]


static func _trim(value: float) -> String:
	return str(int(value)) if value == floorf(value) else str(value)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		if not _tab_picked and not _moved_view and not tab_names().is_empty():
			show_tab(tab_names()[0], false)
			show_overview()
		_info.text = ""
		_back.grab_focus()
	else:
		close_card()
