extends Control
## Skill tree page: spend gold and stars on the upgrade tree, one web the player pans and zooms. Node
## positions and the tab each section belongs to come from the pack. It shows the profile and
## asks for changes through signals; the run flow acts on them. Mouse only.

signal back_requested
signal buy_requested(id: String)
signal respec_requested

const Hud = preload("res://scripts/ui/hud.gd")
const FONT_PX := 20
const DIMMED := Color(1, 1, 1, 0.45)
const NODE_SIZE := Vector2(260, 48)
## A section's heading sits this far above its first row.
const HEADING_GAP := 44.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.5
const ZOOM_STEP := 1.15
## Space kept around a tab's sections, and the part of the web that must stay in view.
const FIT_PAD := 12.0
const KEEP_IN_VIEW := 120.0
const LINK_BOUGHT := Color(0.95, 0.75, 0.3, 0.9)
const LINK_OPEN := Color(0.55, 0.62, 0.72, 0.6)
const LINK_FORK := Color(0.9, 0.4, 0.35, 0.8)
## What a stat means to the player, by the stat's own name without its tower or Hero scope.
const STAT_TEXT := {
	"keep_health": "keep health",
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
@onready var _next: Label = %NextUnlocks
@onready var _respec: Button = %RespecButton
@onready var _back: Button = %BackButton

var _profile: Node
var _content: Dictionary
var _node_buttons: Dictionary = {}
## Each section's holder in the web: hiding it hides its nodes and their links.
var _section_columns: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _tab_group := ButtonGroup.new()
var _tab := ""
var _panning := false
var _default_info := "Spend gold and stars on upgrades. Point at one to read what it does."


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_respec.pressed.connect(respec_requested.emit)
	_zoom_out.pressed.connect(zoom_by.bind(1.0 / ZOOM_STEP))
	_zoom_in.pressed.connect(zoom_by.bind(ZOOM_STEP))
	_view.gui_input.connect(_on_view_input)
	_view.resized.connect(func() -> void: show_tab(_tab))
	_web.draw.connect(_draw_links)
	visibility_changed.connect(_on_visibility_changed)
	_build_tree()
	_info.text = _default_info


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	profile.notice.connect(show_info)
	refresh()


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
		button.text = "%s (bought)" % node["name"] if bought else ("%s (closed)" % node["name"] if closed else "%s  %s" % [node["name"], _price(node)])
		button.disabled = bought or _profile.why_not_buy(id) != ""
		button.set_pressed_no_signal(bought)
		# Only what is one buy away (or already bought) is drawn in full; the rest is dimmed.
		button.modulate = Color.WHITE if bought or _profile.is_near(id) else DIMMED
	for section in _section_columns:
		_section_columns[section].visible = not _content["hero_paths"].has(section) or section == selected_pillar
	_refresh_tabs()
	_web.queue_redraw()
	_respec.disabled = owned.is_empty()
	var next_parts: PackedStringArray = []
	for id in _profile.get_next_unlocks():
		next_parts.append("%s (%s): %s" % [_content["upgrade_nodes"][id]["name"], _price(_content["upgrade_nodes"][id]), _effect_text(id)])
	_next.text = "Next: " + ("  |  ".join(next_parts) if not next_parts.is_empty() else "nothing left to buy here")


func _build_tree() -> void:
	for section in _sections_in_order():
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_web.add_child(holder)
		_section_columns[str(section["id"])] = holder
		var top_left := Vector2(INF, INF)
		for id in _content["upgrade_nodes"]:
			var node: Dictionary = _content["upgrade_nodes"][id]
			if node["branch"] != section["id"]:
				continue
			var at := Vector2(float(node["at"]["x"]), float(node["at"]["y"]))
			top_left = top_left.min(at - NODE_SIZE * 0.5)
			var button := _button(str(node["name"]), FONT_PX, 1)
			button.clip_text = true
			button.custom_minimum_size = NODE_SIZE
			button.position = at - NODE_SIZE * 0.5
			button.pressed.connect(func() -> void: buy_requested.emit(id))
			button.mouse_entered.connect(func() -> void: show_info(_node_text(id)))
			button.mouse_exited.connect(_show_default)
			holder.add_child(button)
			_node_buttons[id] = button
		var heading := Label.new()
		heading.text = str(section["name"])
		heading.add_theme_font_size_override("font_size", FONT_PX)
		heading.theme_type_variation = &"HudCaption"
		heading.position = top_left - Vector2(0, HEADING_GAP)
		holder.add_child(heading)
	# The web is as big as everything in it, so what it draws is never culled.
	_web.custom_minimum_size = _holders_rect(_section_columns.values()).end


## The tab labels in section order, for the sections that are shown.
func tab_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for section in _sections_in_order():
		var label := str(section.get("tab", section["name"]))
		if _section_columns[section["id"]].visible and not label in out:
			out.append(label)
	return out


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
		show_tab(names[0])


## Moves the view to a tab's sections at real size, or smaller when they would not fit.
func show_tab(label: String) -> void:
	if not label in tab_names():
		return
	_tab = label
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
	_keep_in_view()
	_web.queue_redraw()


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
			var child_rect := Rect2(child.position, child.size.max(child.get_combined_minimum_size()))
			rect = child_rect if not found else rect.merge(child_rect)
			found = true
	return rect


func zoom_by(factor: float, around := Vector2(-1, -1)) -> void:
	var point := _view.size * 0.5 if around.x < 0.0 else around
	var zoom := clampf(_web.scale.x * factor, ZOOM_MIN, ZOOM_MAX)
	_web.position = point - (point - _web.position) * (zoom / _web.scale.x)
	_web.scale = Vector2.ONE * zoom
	_keep_in_view()


## Drag the background to pan, scroll or pinch to zoom.
func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(ZOOM_STEP, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / ZOOM_STEP, event.position)
	elif event is InputEventMouseMotion and _panning:
		_web.position += event.relative
		_keep_in_view()
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor, event.position)
	elif event is InputEventPanGesture:
		_web.position -= event.delta * 20.0
		_keep_in_view()


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


## A line from each node to the nodes it needs; a dashed one between the two sides of a fork.
func _draw_links() -> void:
	var half := Vector2(0, NODE_SIZE.y * 0.5)
	var owned: Array = _profile.get_upgrades() if _profile != null else []
	for id in _node_buttons:
		var node: Dictionary = _content["upgrade_nodes"][id]
		if not _section_columns[node["branch"]].visible:
			continue
		var here := Vector2(float(node["at"]["x"]), float(node["at"]["y"]))
		for required in node.get("requires", []):
			var other: Dictionary = _content["upgrade_nodes"][required]
			var there := Vector2(float(other["at"]["x"]), float(other["at"]["y"]))
			var middle := (there.y + here.y) * 0.5
			var elbow := PackedVector2Array([there + half, Vector2(there.x, middle), Vector2(here.x, middle), here - half])
			_web.draw_polyline(elbow, LINK_BOUGHT if id in owned and required in owned else LINK_OPEN, 3.0)
		for other_id in node.get("excludes", []):
			if str(other_id) > id:
				var other: Dictionary = _content["upgrade_nodes"][other_id]
				# Side by side: from the edge of one node to the edge of the other.
				var there := Vector2(float(other["at"]["x"]), float(other["at"]["y"]))
				var edge := Vector2(NODE_SIZE.x * 0.5 * signf(there.x - here.x), 0)
				_web.draw_dashed_line(here + edge, there - edge, LINK_FORK, 3.0, 8.0)


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


func _show_default() -> void:
	_info.text = _default_info


func _effect_text(id: String) -> String:
	var node: Dictionary = _content["upgrade_nodes"][id]
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
static func _stat_text(stat: String) -> String:
	var field := stat
	for scope in ["tower.", "hero."]:
		if stat.begins_with(scope):
			field = stat.substr(scope.length())
	return STAT_TEXT.get(field, field)


func _node_text(id: String) -> String:
	var node: Dictionary = _content["upgrade_nodes"][id]
	var text := "%s: %s. Cost %s." % [node["name"], _effect_text(id), HoldfastMeta.cost_text(node)]
	if node.has("excludes"):
		var names: PackedStringArray = []
		for other in node["excludes"]:
			names.append(str(_content["upgrade_nodes"][other]["name"]))
		text += " Choosing it closes %s." % ", ".join(names)
	if _profile == null:
		return text
	if id in _profile.get_upgrades():
		return text + " Bought."
	var reason: String = _profile.why_not_buy(id)
	return text if reason == "" else "%s %s." % [text, reason]


static func _trim(value: float) -> String:
	return str(int(value)) if value == floorf(value) else str(value)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_show_default()
		_back.grab_focus()
