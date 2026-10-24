extends Control
## Journey map, the hub between runs: a path of level nodes (cleared ones ticked, the next
## one glowing, locked ones dimmed, a boss level ringed), the Hero as a figure at the
## lighthouse, and a button to the skill tree. It shows the profile and asks for what the
## player taps through signals; the run flow acts. Mouse only.

signal level_requested(id: String)
signal hero_requested
signal tree_requested
signal home_requested
## A guided purchase (an upgrade node id) the player pressed.
signal buy_requested(id: String)

const Hud = preload("res://scripts/ui/hud.gd")
const FONT_PX := 20
const NODE_RADIUS := 32.0
const PATH_STEPS := 12
const COLOUR_PATH := Color(0.45, 0.5, 0.6)
const COLOUR_WON := Color(0.25, 0.6, 0.35)
const COLOUR_OPEN := Color(0.3, 0.38, 0.52)
const COLOUR_LOCKED := Color(0.2, 0.22, 0.27)
const COLOUR_GLOW := Color(0.95, 0.7, 0.25)
const COLOUR_BOSS := Color(0.85, 0.3, 0.25)
const COLOUR_KEEP := Color(0.85, 0.8, 0.55)
const COLOUR_HERO := Color(0.95, 0.6, 0.2)
## Clear of the glow ring (12 out, 4 thick), so a name never touches it.
const LABEL_GAP := 20.0
const HERO_FIGURE := Vector2(44, 64)
const GLOW_TINT := Color(1.0, 0.85, 0.45)
const DEFAULT_INFO := "Tap an open level to plan it, the Hero to change path and gear, or the skill tree to spend gold and stars."

@onready var _gold: Label = %GoldValue
@onready var _stars: Label = %StarsValue
@onready var _guide: Control = %Guide
@onready var _guide_label: Label = %GuideLabel
@onready var _guide_button: Button = %GuideButton
@onready var _map: Control = %Map
@onready var _tree: Button = %TreeButton
@onready var _back: Button = %BackButton
@onready var _info: Label = %Info

var _profile: Node
var _content: Dictionary
var _ids: Array = []
var _buttons: Dictionary = {}
var _names: Dictionary = {}
var _hero_button: Button
## The drawn Hero is a button too (transparent), so the figure itself can be tapped.
var _hero_figure: Button
var _next := ""
## The guided purchase on offer ("" when there is none).
var _guided := ""


func _ready() -> void:
	_content = HoldfastContent.base()
	_ids = _content["levels"].keys()
	_back.pressed.connect(home_requested.emit)
	_tree.pressed.connect(tree_requested.emit)
	_guide_button.pressed.connect(func() -> void: buy_requested.emit(_guided))
	_map.draw.connect(_draw_map)
	_map.resized.connect(_place)
	_build_nodes()
	_info.text = DEFAULT_INFO
	visibility_changed.connect(_on_visibility_changed)


func bind(profile: Node) -> void:
	_profile = profile
	profile.changed.connect(refresh)
	refresh()


## Redraws everything from the profile.
func refresh() -> void:
	if _profile == null:
		return
	_gold.text = Hud.format_number(_profile.get_gold())
	_stars.text = str(_profile.get_stars())
	_refresh_guide()
	_next = ""
	for id in _ids:
		if _is_open(id) and not _profile.is_level_won(id):
			_next = id
			break
	for id in _ids:
		var button: Button = _buttons[id]
		var open: bool = _is_open(id)
		var won: bool = _profile.is_level_won(id)
		button.disabled = not open
		button.text = "" if won else str(int(_content["levels"][id].get("number", 0)))
		_names[id].text = "%s\n%s" % [_content["levels"][id]["name"], _status(id, open, won)]
		_names[id].size = _names[id].get_minimum_size()
	_hero_button.text = "Hero: %s" % _content["hero_paths"][_profile.get_pillar()]["name"]
	_hero_button.reset_size()
	var buyable := upgrades_available()
	_tree.text = "Skill tree: %d to buy" % buyable if buyable > 0 else "Skill tree"
	_tree.modulate = GLOW_TINT if buyable > 0 else Color.WHITE
	# The guided buy comes first: until it is made the tree and the Hero page stay shut.
	_tree.disabled = _guided != ""
	_hero_button.disabled = _guided != ""
	_hero_figure.disabled = _guided != ""
	_place()
	_map.queue_redraw()


## True when the player can plan the level: it is unlocked and, past the tutorial, the
## castle has a slot with an Archer Post for it.
func _is_open(id: String) -> bool:
	return id in _profile.get_unlocked_levels() and (_content["levels"][id].get("tutorial", false) or _profile.has_a_tower())


## Shows the next compulsory purchase (First Slot, then the first Archer Post) once the
## tutorial is won, until the castle has a tower.
func _refresh_guide() -> void:
	_guided = _profile.get_guided_step()
	_guide.visible = _guided != ""
	if _guided == "":
		return
	var node: Dictionary = _content["upgrade_nodes"][_guided]
	var why: String = _profile.why_not_buy(_guided)
	_guide_label.text = "Before the next level, spend a star on %s: %s.%s" % [node["name"], _grant_text(node), "" if why == "" else " " + why + "."]
	_guide_button.text = "Buy %s (%s)" % [node["name"], HoldfastMeta.cost_text(node)]
	_guide_button.disabled = why != ""


static func _grant_text(node: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(node.get("grants", {}).get("slots", 0)) > 0:
		parts.append("a place on the castle ring for a post")
	if int(node.get("grants", {}).get("cards", 0)) > 0:
		parts.append("an Archer Post to put in it")
	return " and ".join(parts)


## How many tree nodes the player could buy right now.
func upgrades_available() -> int:
	var count := 0
	for id in _content["upgrade_nodes"]:
		if _profile.why_not_buy(id) == "":
			count += 1
	return count


## The boss on a level, or "" (the first enemy of the boss tier in its waves).
func boss_name(level_id: String) -> String:
	for wave in _content["levels"][level_id]["waves"]:
		for spawn in wave["spawns"]:
			var enemy: Dictionary = _content["enemies"][spawn["enemy"]]
			if str(enemy.get("tier", "normal")) == "boss":
				return str(enemy["name"])
	return ""


func _status(id: String, open: bool, won: bool) -> String:
	var boss := boss_name(id)
	if not open:
		return "Boss: %s (locked)" % boss if boss != "" else "Locked"
	if id == _next:
		return "Boss: %s" % boss if boss != "" else "Next"
	if won:
		return "Won, %s" % _stars_text(id)
	return "Boss: %s" % boss if boss != "" else "Open"


## "2 of 3 stars" for a level; a tutorial, which pays a fixed reward, says "2 stars".
func _stars_text(id: String) -> String:
	var level: Dictionary = _content["levels"][id]
	var got: int = _profile.get_level_stars(id)
	if level.get("tutorial", false):
		return "%d stars" % got
	return "%d of %d stars" % [got, HoldfastMeta.MAX_LEVEL_STARS]


func _build_nodes() -> void:
	for id in _ids:
		var button := Button.new()
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		button.focus_entered.connect(_map.queue_redraw)
		button.focus_exited.connect(_map.queue_redraw)
		button.custom_minimum_size = Vector2.ONE * NODE_RADIUS * 2.0
		button.size = button.custom_minimum_size
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(func() -> void: level_requested.emit(id))
		button.mouse_entered.connect(func() -> void: _info.text = _level_text(id))
		button.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
		_map.add_child(button)
		_buttons[id] = button
		var caption := Label.new()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", FONT_PX)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.add_child(caption)
		_names[id] = caption
	_hero_button = Button.new()
	_hero_button.add_theme_font_size_override("font_size", FONT_PX)
	_hero_button.pressed.connect(hero_requested.emit)
	_hero_button.mouse_entered.connect(func() -> void: _info.text = "Change the Hero's path and wear the gear you have found.")
	_hero_button.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
	_map.add_child(_hero_button)
	_hero_figure = Button.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		_hero_figure.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_hero_figure.custom_minimum_size = HERO_FIGURE
	_hero_figure.size = HERO_FIGURE
	_hero_figure.focus_entered.connect(_map.queue_redraw)
	_hero_figure.focus_exited.connect(_map.queue_redraw)
	_hero_figure.pressed.connect(hero_requested.emit)
	_hero_figure.mouse_entered.connect(func() -> void: _info.text = "Change the Hero's path and wear the gear you have found.")
	_hero_figure.mouse_exited.connect(func() -> void: _info.text = DEFAULT_INFO)
	_map.add_child(_hero_figure)


func _level_text(id: String) -> String:
	var level: Dictionary = _content["levels"][id]
	var open: bool = _profile != null and _is_open(id)
	var text := "%s: %d waves. " % [level["name"], level["waves"].size()]
	if level.get("tutorial", false):
		text += str(level["intro"]) + " "
	if open:
		return text + ("Tap to play it." if level.get("tutorial", false) else "Tap to plan it.")
	if _profile != null and id in _profile.get_unlocked_levels():
		return text + "Buy your First Slot and Archer Post first."
	return text + "Locked. Win the previous level."


## Where level `i` of `n` sits on the map: a path rising to the right with a gentle wiggle.
func _node_at(i: int, n: int) -> Vector2:
	var area := _map.size
	var t := float(i) / maxf(float(n - 1), 1.0)
	var x := lerpf(area.x * 0.24, area.x * 0.9, t)
	var y := lerpf(area.y * 0.7, area.y * 0.3, t) + sin(float(i) * 1.835) * area.y * 0.07
	return Vector2(x, y)


func _lighthouse_at() -> Vector2:
	return Vector2(_map.size.x * 0.1, _map.size.y * 0.74)


func _hero_at() -> Vector2:
	return _lighthouse_at() + Vector2(46, 14)


## The path from the lighthouse through every level node, as a smooth line.
func path_points() -> PackedVector2Array:
	var n := _ids.size()
	var points := PackedVector2Array([_lighthouse_at()])
	for i in n:
		points.append(_node_at(i, n))
	var curve := PackedVector2Array()
	for i in points.size() - 1:
		var before := points[maxi(i - 1, 0)]
		var after := points[mini(i + 2, points.size() - 1)]
		for step in PATH_STEPS:
			curve.append(points[i].cubic_interpolate(points[i + 1], before, after, float(step) / PATH_STEPS))
	curve.append(points[points.size() - 1])
	return curve


func _place() -> void:
	if _ids.is_empty() or _hero_button == null:
		return
	for i in _ids.size():
		var at := _node_at(i, _ids.size())
		_buttons[_ids[i]].position = at - Vector2.ONE * NODE_RADIUS
		var label: Label = _names[_ids[i]]
		# Below the node and clear of its glow ring, which also keeps it off the path.
		label.position = Vector2(clampf(at.x - label.size.x * 0.5, 0.0, _map.size.x - label.size.x), at.y + NODE_RADIUS + LABEL_GAP)
	_hero_button.position = _lighthouse_at() + Vector2(-_hero_button.size.x * 0.5, -125.0)
	_hero_figure.position = _hero_at() - HERO_FIGURE * 0.5 + Vector2(0, -4)


func _draw_map() -> void:
	if _ids.is_empty():
		return
	var n := _ids.size()
	_map.draw_polyline(path_points(), COLOUR_PATH, 6.0, true)
	# The lighthouse and the Hero beside it.
	var base := _lighthouse_at()
	_map.draw_rect(Rect2(base - Vector2(22, 30), Vector2(44, 60)), COLOUR_KEEP)
	_map.draw_circle(base + Vector2(0, -38), 10.0, COLOUR_GLOW)
	# The Hero: a head and a cloaked body beside the lighthouse.
	var hero := _hero_at()
	_map.draw_circle(hero + Vector2(0, -22), 8.0, COLOUR_HERO)
	_map.draw_colored_polygon(PackedVector2Array([hero + Vector2(0, -14), hero + Vector2(14, 22), hero + Vector2(-14, 22)]), COLOUR_HERO)
	if _hero_figure.has_focus():
		_map.draw_rect(Rect2(_hero_figure.position, HERO_FIGURE), Color.WHITE, false, 3.0)
	for i in n:
		var id: String = _ids[i]
		var at := _node_at(i, n)
		var open: bool = _profile != null and _is_open(id)
		var won: bool = _profile != null and _profile.is_level_won(id)
		_map.draw_circle(at, NODE_RADIUS, COLOUR_WON if won else (COLOUR_OPEN if open else COLOUR_LOCKED))
		if boss_name(id) != "":
			_map.draw_arc(at, NODE_RADIUS + 6.0, 0.0, TAU, 40, COLOUR_BOSS, 4.0, true)
		if id == _next:
			_map.draw_arc(at, NODE_RADIUS + 12.0, 0.0, TAU, 40, COLOUR_GLOW, 4.0, true)
		if _buttons[id].has_focus():
			_map.draw_arc(at, NODE_RADIUS + 3.0, 0.0, TAU, 40, Color.WHITE, 3.0, true)
		if won:
			_map.draw_polyline(PackedVector2Array([at + Vector2(-14, 0), at + Vector2(-4, 11), at + Vector2(15, -11)]), Color.WHITE, 5.0, true)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_info.text = DEFAULT_INFO
		var target: Button = _buttons.get(_next)
		if _guided != "" and not _guide_button.disabled:
			_guide_button.grab_focus()
		else:
			(target if target != null and not target.disabled else _tree).grab_focus()
