class_name HubRail
extends PanelContainer
## The left rail every hub screen has: Map, Tree, Hero, Menu, and Squad once a Recruit has joined.
## One word each. A dot on a tab means there is something worth doing there. It reads the profile
## and asks to move through `tab_requested`; the run flow acts. L1 and R1 (Page Up and Page Down on a
## keyboard) step between the tabs.

signal tab_requested(tab: String)

const WIDTH := 112.0
## Where the rail starts: the bottom edge of the header (12 px margin and a 56 px chip row).
const TOP := 68.0
## Where a screen's content starts, as a margin inside the 24 px screen margin: 16 px clear of the rail.
const CONTENT_MARGIN := 104.0
const TABS := ["Map", "Tree", "Hero", "Squad", "Menu"]
const DOT_PX := 12.0
const Guidance = preload("res://scripts/ui/guidance.gd")

## The tab of the screen this rail is on.
@export var current := "Map"

var _profile: Node
var _hints: Node
var _content: Dictionary
var _buttons := {}
var _dots := {}


func _ready() -> void:
	HoldfastInput.ensure_actions()
	_place()
	_content = HoldfastContent.base()
	var group := ButtonGroup.new()
	for tab in TABS:
		var button: Button = get_node("Column/%sTab" % tab)
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_pressed.bind(tab))
		_buttons[tab] = button
		_dots[tab] = _make_dot(button)
	set_current(current)


## Pins the rail to the left edge, from the header's bottom edge to the bottom of the screen, in code so
## every screen has the same rail whatever its scene or export stores (HF-M2-73, F-177). It grows
## downwards only, so it can never reach up over the header.
func _place() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = WIDTH
	offset_top = TOP
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END


func bind(profile: Node, hints: Node) -> void:
	_profile = profile
	_hints = hints
	profile.changed.connect(refresh)
	hints.changed.connect(refresh)
	refresh()


func set_current(tab: String) -> void:
	current = tab
	for each in _buttons:
		_buttons[each].set_pressed_no_signal(each == tab)


## The button of a tab.
func tab(name: String) -> Button:
	return _buttons[name]


## True while a tab shows its dot.
func has_dot(name: String) -> bool:
	return _dots[name].visible


## Presses a tab the way a click does.
func press(name: String) -> void:
	_buttons[name].pressed.emit()


## Shows the tabs and dots for what the profile has: Squad only once a Recruit has joined; Tree, Hero
## and Squad shut while the guided buys are due, and no dots then (the guide asks instead).
func refresh() -> void:
	if _profile == null:
		return
	var locked: bool = _profile.get_guided_step() != ""
	for tab_name in ["Tree", "Hero", "Squad"]:
		_buttons[tab_name].disabled = locked
	_buttons["Squad"].visible = not _profile.get_recruits().is_empty()
	var seen: Array = _profile.get_seen_buyable()
	_dots["Tree"].visible = not locked and _profile.get_buyable_nodes().any(func(id: String) -> bool: return not id in seen)
	_dots["Hero"].visible = not locked and (_profile.has_unseen_gear() or Guidance.has_pillar_news(_content, _profile, _hints))
	_dots["Squad"].visible = not locked and (not _profile.get_pending_picks().is_empty() or _profile.get_welcome() != "")
	for tab_name in TABS:
		_dots[tab_name].queue_redraw()


## L1 and R1 step to the previous or next open tab, wrapping round, while this rail's screen is up.
func _unhandled_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed(HoldfastInput.ACTION_TAB_NEXT):
		step = 1
	elif event.is_action_pressed(HoldfastInput.ACTION_TAB_PREV):
		step = -1
	if step == 0 or not is_visible_in_tree():
		return
	var tabs: Array = TABS.filter(func(name: String) -> bool: return _buttons[name].visible and not _buttons[name].disabled)
	var at := tabs.find(current)
	if tabs.size() < 2 or at < 0:
		return
	get_viewport().set_input_as_handled()
	press(tabs[posmod(at + step, tabs.size())])


## A real click leaves the clicked tab pressed (it is a toggle in a group), but this rail belongs to its own
## screen: it goes on marking that screen, so it is right again whenever the screen is next shown (F-194).
func _pressed(tab_name: String) -> void:
	if tab_name != current:
		tab_requested.emit(tab_name)
	set_current(current)


## A small round dot on the top right corner of a tab, hidden until it is wanted.
func _make_dot(tab_button: Button) -> Control:
	var dot := Control.new()
	dot.size = Vector2(DOT_PX, DOT_PX)
	dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -DOT_PX - 6.0
	dot.offset_right = -6.0
	dot.offset_top = 6.0
	dot.offset_bottom = 6.0 + DOT_PX
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false
	dot.draw.connect(func() -> void: dot.draw_circle(dot.size * 0.5, DOT_PX * 0.5, UiTokens.colour(&"lamp")))
	tab_button.add_child(dot)
	return dot
