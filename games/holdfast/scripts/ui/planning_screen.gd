extends Control
## Planning screen, shown before a run on a level with Archer Post sites: a map of
## the level with the places enemies come from and the sites the player may build
## on. It shows the choice and asks for the run through signals; the run flow acts.
## Mouse only.

signal start_requested(layout: Array)
signal back_requested

const FONT_PX := 20
const COLOUR_ARENA := Color(0.35, 0.4, 0.5)
const COLOUR_KEEP := Color(0.85, 0.8, 0.55)
const COLOUR_ARC := Color(0.9, 0.3, 0.25)
const COLOUR_RANGE := Color(0.55, 0.75, 0.95, 0.25)
const ARC_STEPS := 24

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _count: Label = %Count
@onready var _map: Control = %Map
@onready var _back: Button = %BackButton
@onready var _start: Button = %StartButton

var _content: Dictionary
var _level_id := ""
var _level: Dictionary = {}
var _chosen: Array = []
var _site_buttons: Dictionary = {}


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_start.pressed.connect(func() -> void: start_requested.emit(_chosen.duplicate()))
	_map.draw.connect(_draw_map)
	_map.resized.connect(_place_buttons)
	visibility_changed.connect(_on_visibility_changed)


## Shows the level's map with `layout` (site ids) already chosen.
func open(level_id: String, layout: Array) -> void:
	_level_id = level_id
	_level = _content["levels"][level_id]
	_chosen = layout.duplicate()
	for button in _site_buttons.values():
		button.queue_free()
	_site_buttons.clear()
	for site in _level["sites"]:
		var id := str(site["id"])
		var button := Button.new()
		button.text = id.trim_suffix("_gate").replace("_", " ").capitalize()
		button.tooltip_text = id.replace("_", " ").capitalize()
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", FONT_PX)
		button.pressed.connect(_toggle.bind(id))
		_map.add_child(button)
		_site_buttons[id] = button
	_title.text = "Plan the posts: %s" % _level["name"]
	_hint.text = "Enemies come from the red edges. Pick where the Archer Post%s stand%s before the first wave." % [
		"s" if int(_level.get("max_posts", 1)) > 1 else "", "" if int(_level.get("max_posts", 1)) > 1 else "s"]
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


func _refresh() -> void:
	for id in _site_buttons:
		_site_buttons[id].set_pressed_no_signal(id in _chosen)
	_count.text = "Posts: %d of %d" % [_chosen.size(), int(_level.get("max_posts", 1))]
	_start.disabled = _chosen.is_empty()
	_map.queue_redraw()


## World units to map pixels, and where the keep (the world's origin) sits on the map.
func _scale() -> float:
	var arena: Dictionary = _level.get("arena", {"width": HoldfastRules.DEFAULT_ARENA.x, "height": HoldfastRules.DEFAULT_ARENA.y})
	return minf(_map.size.x / float(arena["width"]), _map.size.y / float(arena["height"]))


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
	var arena: Dictionary = _level.get("arena", {"width": HoldfastRules.DEFAULT_ARENA.x, "height": HoldfastRules.DEFAULT_ARENA.y})
	var half := Vector2(float(arena["width"]), float(arena["height"])) * 0.5
	_map.draw_rect(Rect2(centre - half * scale, half * 2.0 * scale), COLOUR_ARENA, false, 2.0)
	_map.draw_circle(centre, float(_level["keep_radius"]) * scale, COLOUR_KEEP)
	var reach := float(_content["towers"][str(_level["tower"]["id"])]["range"])
	for site in _level["sites"]:
		if str(site["id"]) in _chosen:
			_map.draw_circle(centre + Vector2(float(site["x"]), float(site["y"])) * scale, reach * scale, COLOUR_RANGE)
	for arc in _level.get("spawn_arcs", []):
		var points := PackedVector2Array()
		for i in ARC_STEPS + 1:
			var angle := deg_to_rad(float(arc["centre"]) + (float(i) / ARC_STEPS - 0.5) * float(arc["width"]))
			var at := Vector2(cos(angle), sin(angle)) * float(_level["spawn_radius"])
			points.append(centre + at.clamp(-half, half) * scale)
		_map.draw_polyline(points, COLOUR_ARC, 5.0)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_start.grab_focus()
