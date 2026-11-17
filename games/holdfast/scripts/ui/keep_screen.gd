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
## The Start button of the guide, once both guided buys are made: the short fight with the new post.
signal stand_requested

const Hud = preload("res://scripts/ui/hud.gd")
const Guidance = preload("res://scripts/ui/guidance.gd")
## Every colour is a token of the theme (UiTokens), read once when the script loads.
static var DIMMED := UiTokens.fade(0.45)
static var OWNED_FILL := UiTokens.colour(&"good").darkened(0.4)
static var OWNED_EDGE := UiTokens.colour(&"good")
## No button is smaller than this on either side (the CEO's 44 px rule).
const MIN_BUTTON := 44.0
## A round node: big enough to press at real size.
const NODE_SIZE := Vector2(44, 44)
## Names under the nodes and on the rim keep their size on screen at any zoom (theme types TreeName
## and TreeRim), and the node names are left off when the web is too small for them to be told apart.
const LABEL_WIDTH := 96.0
## The room a name and a node keep from every other node and name, in pixels on screen (the CEO's 6 px rule).
const NAME_CLEAR := 6.0
const LABEL_GAP := 8
## A gate or a capstone sits inside a thin outer ring, so it takes more room than a plain node.
const RING_SIZE := Vector2(54, 54)
## The price tag (a coin or star and the number) hangs this far under its node, or above it when
## there is no room under.
const TAG_GAP := 4.0
const TAG_ICON := 14.0
## About one line of the TreePrice type, for placing names clear of the tags.
const TAG_HEIGHT := 20.0
const TAG_WIDTH := 56.0
const ICON_DIR := "res://assets/ui/icons/"
const KINDS := ["stat", "behaviour", "castle", "link", "gate", "capstone"]
## Stats that change how a post or the Hero fights rather than how hard: they make a Behaviour node.
const BEHAVIOUR_STATS := ["extra_targets", "burst_every", "storm_every", "lone_bonus", "attack.count", "ability.auto_power", "ability.pierce", "pierce", "crossfire", "hero_haste", "posted_haste"]
## The glyph inside a node, by the first stat it changes (the scope is dropped).
const STAT_GLYPH := {
	"damage": "damage", "attack.damage": "damage", "ability.burn_dps": "burn", "burn_dps": "burn", "burn_seconds": "burn", "ability.burn_seconds": "burn",
	"aura_dps": "damage", "staff_damage": "damage", "burst_extra": "damage", "storm_share": "damage", "lone_bonus": "damage", "last_light": "damage", "crossfire": "damage",
	"cooldown": "speed", "attack.cooldown": "speed", "ability.cooldown": "speed", "burst_every": "speed", "storm_every": "speed", "move_speed": "speed", "hero_haste": "speed",
	"posted_haste": "speed", "ability.rapid_seconds": "speed", "getup_time": "speed", "rally_seconds": "speed",
	"range": "range", "attack.range": "range", "watch_range": "range", "beam_reach": "range", "pickup_radius": "range", "hero_radius": "range", "watch_radius": "range",
	"rally_radius": "range", "eclipse_radius": "range", "eclipse_widen": "range", "last_light_radius": "range", "attack.spread_degrees": "range",
	"health": "health", "keep_health": "health", "armour": "health", "repair": "health", "rally_repair": "health", "rally_shield": "health",
	"extra_targets": "multi", "pierce": "multi", "ability.pierce": "multi", "attack.count": "multi",
	"gold_multiplier": "coin", "ability.auto_power": "speed",
}
const LABELS_MIN_ZOOM := 0.6
const RIM_SIZE := Vector2(100, 24)
## A section's name sits this far beyond its outermost node, and never nearer the middle than RIM_MIN.
const RIM_GAP := 56.0
const RIM_MIN := 120.0
## Link nodes (they join two parts of the web) have a dashed ring.
const LINK_PREFIX := "link_"
const LINK_DASHES := 16
static var FAR_EDGE := UiTokens.colour(&"mute")
static var NODE_FILL := UiTokens.colour(&"raise")
## The colour of a section's name on the card's header bar, and nowhere else (a token of the theme).
const SECTION_TOKEN := {
	"flare_archer": &"sec_hero", "archer_post": &"sec_post", "keep": &"sec_keep", "gold": &"sec_gold", "castle": &"sec_castle", "mage_post": &"arcane",
}
## The card keeps this far from the edge of the page.
const CARD_MARGIN := 24.0
## About 0.4, a power-of-two fraction so the stored scale equals the limit exactly.
const ZOOM_MIN := 0.375
const ZOOM_MAX := 2.5
## The tree opens at the size that shows everything on show, from OVERVIEW_ZOOM_MIN (below it the
## player pans) to OVERVIEW_ZOOM_MAX, so a node and its name stay easy to read and press.
## About 0.84 (it was 0.9 before the minimap column and the Can buy now strip took room from the view),
## a binary fraction so the stored scale equals the limit exactly.
const OVERVIEW_ZOOM_MIN := 0.84375
const OVERVIEW_ZOOM_MAX := 1.5
## How visible the sections of other tabs are while a tab is in view.
const OTHER_TAB_ALPHA := 0.3
const ZOOM_STEP := 1.15
## A press that moves further than this is a drag that pans the web, not a click that buys.
const DRAG_PX := 6.0
## Space kept around a tab's sections, and the part of the web that must stay in view.
const FIT_PAD := 12.0
const KEEP_IN_VIEW := 120.0
## The minimap: shown from this many nodes found, with a dot of MINIMAP_DOT for each, MINIMAP_INSET
## clear of its edge, and MINIMAP_PAD of web round the outermost. The Can buy now strip lists at most STRIP_MAX.
const MINIMAP_MIN_NODES := 3
const MINIMAP_DOT := 3.0
const MINIMAP_INSET := 8.0
const MINIMAP_PAD := 30.0
const STRIP_MAX := 3
static var LINK_BOUGHT := UiTokens.colour(&"lamp", 0.9)
static var LINK_OPEN := UiTokens.colour(&"mute", 0.6)
static var LINK_FORK := UiTokens.colour(&"warning", 0.8)
static var COLOUR_ACT := UiTokens.colour(&"lamp")
static var COLOUR_SHORT := UiTokens.colour(&"warning")
## The outline that shows where a controller or the keyboard is, apart from the act and done colours.
static var COLOUR_FOCUS := UiTokens.colour(&"focus")
const CARD_WIDTH := 480.0
static var CARD_EDGE := UiTokens.colour(&"mute", 0.6)
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
	"ability.auto_power": "barrage power when it fires itself",
	"armour": "percent of damage turned away",
	"getup_time": "time to get up",
	"pickup_radius": "XP pickup reach",
	"hero_haste": "faster shots with the Hero near",
	"posted_haste": "faster again with a Recruit on the post and the Hero near",
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
@onready var _side: Control = %Side
@onready var _found: Label = %FoundLabel
@onready var _minimap: Control = %Minimap
@onready var _strip: HBoxContainer = %BuyStrip
@onready var _tabs: HBoxContainer = %Tabs
@onready var _zoom_out: Button = %ZoomOut
@onready var _zoom_in: Button = %ZoomIn
@onready var _key_button: Button = %KeyButton
@onready var _info: Label = %Info
@onready var _respec: Button = %RespecButton
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton
@onready var _guide: Control = %Guide
@onready var _guide_label: Label = %GuideLabel
@onready var _guide_button: Button = %GuideButton
@onready var rail: HubRail = %Rail
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
## The price tag under each node (a coin or star and the number), and which of them stand above
## their node at the zoom the web is at.
var _tags: Dictionary = {}
var _tag_side: Dictionary = {}
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
## The upgrade the guide offers ("" for the fight).
var _guide_node := ""
var _card: Control
var _card_bar: ColorRect
## The key to the shapes, over a corner of the view while it is open.
var _key: Control
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
## What the Can buy now strip lists (so it is rebuilt only when that changes), and how the minimap
## maps the web onto itself: the web rect it shows, and the scale and offset of that.
var _strip_ids: Array = []
var _map_bounds := Rect2()
var _map_scale := 1.0
var _map_origin := Vector2.ZERO


func _ready() -> void:
	_content = HoldfastContent.base()
	_back.pressed.connect(back_requested.emit)
	_respec.pressed.connect(_ask_refund_all)
	_confirm.pressed.connect(_refund_all_confirmed)
	_cancel.pressed.connect(_cancel_refund_all)
	_guide_button.pressed.connect(_on_guide_pressed)
	_zoom_out.pressed.connect(zoom_by.bind(1.0 / ZOOM_STEP))
	_zoom_in.pressed.connect(zoom_by.bind(ZOOM_STEP))
	_key_button.toggled.connect(func(on: bool) -> void: _key.visible = on)
	_view.gui_input.connect(_on_view_input)
	_view.resized.connect(_fit_view)
	_web.draw.connect(_draw_links)
	_minimap.draw.connect(_draw_minimap)
	_minimap.gui_input.connect(_on_minimap_input)
	visibility_changed.connect(_on_visibility_changed)
	_build_tree()
	_build_key()
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
		_tags[id].visible = button.visible
		button.tooltip_text = _tip_text(id)
		# Nothing is written inside a node: its glyph is drawn on it, and its price is the tag under it.
		button.text = ""
		button.theme_type_variation = &"TreePriceButton"
		var state := "owned" if bought else ("closed" if closed else ("open" if near else "far"))
		_marks[id].set_meta("state", state)
		_marks[id].queue_redraw()
		_light(button, state, _is_link(id), _kind(id))
		# Every node can be pressed: its card says what is open to the player, and what is not.
		button.set_pressed_no_signal(bought)
		# Only what is one buy away (or already bought) is drawn in full; the rest is dimmed.
		button.modulate = UiTokens.fade(1.0) if near else DIMMED
		_labels[id].modulate = button.modulate
		# The tag is dimmed, never reddened, while the player cannot afford it.
		var short := _shortfall(node, _profile.why_not_buy(id)) > 0
		_tags[id].modulate = DIMMED if not near else (UiTokens.fade(0.55) if short else UiTokens.fade(1.0))
	for section in _section_columns:
		_section_columns[section].visible = (not _content["hero_paths"].has(section) or section == selected_pillar) and _section_has_shown_node(section)
		_place_heading(section)
	_refresh_tabs()
	_sync_labels()
	_refresh_side()
	_web.queue_redraw()
	var takes_back: bool = not _profile.get_respec_nodes().is_empty()
	_respec.disabled = not takes_back
	_respec.text = refund_all_text(_profile.get_respec_stars(), _profile.get_respec_gold_change()) if takes_back else "Refund all"
	_end_refund_ask()
	_refresh_guide()
	_info.text = ""
	if _card.visible:
		_fill_card()


## The same guide the Journey map shows, so a player who comes to the tree first is told the same thing.
func _refresh_guide() -> void:
	var guide := Guidance.guide(_content, _profile)
	_guide.visible = not guide.is_empty()
	if guide.is_empty():
		return
	_guide_label.text = str(guide["text"])
	_guide_button.text = str(guide["button"])
	_guide_button.disabled = bool(guide["disabled"])
	_guide_node = str(guide["node"])


## "Refund all" asks first: the line says what comes back and what stays, and the two buttons that
## replace it and Back answer it.
func _ask_refund_all() -> void:
	_info.text = "Take back every upgrade? The first castle slot and Archer Post stay. %s" % _respec.text.replace("Refund all:", "You get")
	_respec.visible = false
	_back.visible = false
	_confirm.visible = true
	_cancel.visible = true
	_cancel.grab_focus()


func _refund_all_confirmed() -> void:
	_end_refund_ask()
	respec_requested.emit()


func _cancel_refund_all() -> void:
	_end_refund_ask()
	_info.text = ""
	_respec.grab_focus()


func _end_refund_ask() -> void:
	_respec.visible = true
	_back.visible = true
	_confirm.visible = false
	_cancel.visible = false


func _on_guide_pressed() -> void:
	if _guide_node == "":
		stand_requested.emit()
	else:
		buy_requested.emit(_guide_node)


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
func _light(button: Button, state: String, link: bool, kind := "stat") -> void:
	if kind != "stat":
		# Every other shape is drawn whole on the node's mark; the button only takes the press and the focus.
		for name in ["normal", "pressed", "disabled", "hover", "hover_pressed"]:
			button.add_theme_stylebox_override(name, StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", _focus_style(int(NODE_SIZE.x * 0.5)))
		return
	var rest: StyleBoxFlat = _owned_style if state == "owned" and not link else _node_style(state, link, false)
	for name in ["normal", "pressed", "disabled"]:
		button.add_theme_stylebox_override(name, rest)
	for name in ["hover", "hover_pressed"]:
		button.add_theme_stylebox_override(name, _node_style(state, link, true))
	button.add_theme_stylebox_override("focus", _owned_focus_style if state == "owned" else _focus_style(int(NODE_SIZE.x * 0.5)))


## Which of the six shapes of the key a node is: a Link joins two parts of the web, a Gate opens a
## tower, a Castle node grants slots or cards, a Capstone is a star-priced end of a section, a
## Behaviour changes how a post or the Hero fights, and a Stat only adds to a number.
func _kind(id: String) -> String:
	var node: Dictionary = _content["upgrade_nodes"][id]
	if _is_link(id):
		return "link"
	if id.begins_with("gate_") or node.has("needs_nodes"):
		return "gate"
	if node.has("grants"):
		return "castle"
	if str(node.get("currency", "")) == "stars" and node.has("effects"):
		return "capstone"
	if node.has("text") or (node.has("effects") and _field(str(node["effects"][0]["stat"])) in BEHAVIOUR_STATS):
		return "behaviour"
	return "stat"


## The room a node takes: the gate and the capstone have a ring around them.
func _foot(id: String) -> Vector2:
	return RING_SIZE if _kind(id) in ["gate", "capstone"] else NODE_SIZE


static func _field(stat: String) -> String:
	for scope in ["tower.", "hero.", "recruit."]:
		if stat.begins_with(scope):
			return stat.substr(scope.length())
	return stat


## The picture inside a node, by what it does.
func _glyph(id: String) -> String:
	var node: Dictionary = _content["upgrade_nodes"][id]
	match _kind(id):
		"link":
			return "link"
		"gate":
			return "gate"
		"castle":
			return "recruit" if node["grants"].has("squad") else "castle"
	if node.has("effects"):
		if str(node["effects"][0]["stat"]).begins_with("recruit."):
			return "recruit"
		return STAT_GLYPH.get(_field(str(node["effects"][0]["stat"])), "damage")
	return "damage"


static var _icons := {}


## An icon of the tree: a glyph (node_*.svg), or the coin or star of a price.
static func _icon(name: String) -> Texture2D:
	if not _icons.has(name):
		_icons[name] = load("%s%s.svg" % [ICON_DIR, name if name in ["coin", "star"] else "node_" + name])
	return _icons[name]


func _is_link(id: String) -> bool:
	return id.begins_with(LINK_PREFIX)


## True when the line from a node to one it needs joins two sections: a link node reaching over.
func _joins_sections(id: String, required: String) -> bool:
	return _is_link(id) and _content["upgrade_nodes"][required]["branch"] != _content["upgrade_nodes"][id]["branch"]


## Where a node sits in the web: its place in the pack, from the middle of the web.
func _point(id: String) -> Vector2:
	var at: Dictionary = _content["upgrade_nodes"][id]["at"]
	return Vector2(float(at["x"]), float(at["y"]))


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
			button.focus_entered.connect(_node_focused.bind(id))
			holder.add_child(button)
			_node_buttons[id] = button
			var mark := Control.new()
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.mouse_entered.connect(mark.queue_redraw)
			button.mouse_exited.connect(mark.queue_redraw)
			button.add_child(mark)
			mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			mark.draw.connect(_draw_mark.bind(id))
			_marks[id] = mark
			var text := str(node.get("label", node["name"]))
			var label_px := get_theme_font_size(&"font_size", &"TreeName")
			var width := get_theme_font(&"font", &"TreeName").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_px).x + 4.0
			var label := _caption(text, &"TreeName", Vector2(width, label_px + 4))
			holder.add_child(label)
			label.reset_size()
			_labels[id] = label
			var tag := _make_tag(node)
			holder.add_child(tag)
			_tags[id] = tag
		_rim_dirs[str(section["id"])] = (middle / maxf(count, 1)).normalized() if middle.length() > 1.0 else Vector2.LEFT
		var heading := _caption(str(section.get("rim", section["name"])), &"TreeRim", RIM_SIZE)
		heading.pivot_offset = RIM_SIZE * 0.5
		holder.add_child(heading)
		_headings[str(section["id"])] = heading
	_place_labels()
	# The web is as big as everything in it, so what it draws is never culled.
	_web.custom_minimum_size = _holders_rect(_section_columns.values()).end


## The price tag: the coin or star, and the number.
func _make_tag(node: Dictionary) -> Control:
	var tag := HBoxContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_constant_override("separation", 3)
	var icon := TextureRect.new()
	icon.texture = _icon("star" if HoldfastMeta.is_star_node(node) else "coin")
	icon.custom_minimum_size = Vector2(TAG_ICON, TAG_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(icon)
	var value := Label.new()
	value.name = "Value"
	value.theme_type_variation = &"TreePrice"
	value.text = str(int(node["cost"])) if HoldfastMeta.is_star_node(node) else Hud.format_number(int(node["cost"]))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(value)
	tag.size = tag.get_combined_minimum_size()
	return tag


## Which side of its node a tag hangs from, in the order they are tried.
enum Side { BELOW, ABOVE, RIGHT, LEFT }


## Hangs a tag from its node: under it, else above it, and only when neither has room beside it.
func _place_tag(id: String, side: int) -> void:
	var tag: Control = _tags[id]
	# Sized from the theme it is in, not the default one it was made under.
	tag.size = tag.get_combined_minimum_size()
	var at := _point(id)
	var half := _foot(id) * 0.5
	_tag_side[id] = side
	match side:
		Side.ABOVE:
			tag.pivot_offset = Vector2(tag.size.x * 0.5, tag.size.y)
			tag.position = at + Vector2(0, -half.y - TAG_GAP) - tag.pivot_offset
		Side.RIGHT:
			tag.pivot_offset = Vector2(0, tag.size.y * 0.5)
			tag.position = at + Vector2(half.x + TAG_GAP, 0) - tag.pivot_offset
		Side.LEFT:
			tag.pivot_offset = Vector2(tag.size.x, tag.size.y * 0.5)
			tag.position = at + Vector2(-half.x - TAG_GAP, 0) - tag.pivot_offset
		_:
			tag.pivot_offset = Vector2(tag.size.x * 0.5, 0)
			tag.position = at + Vector2(0, half.y + TAG_GAP) - tag.pivot_offset


## Where a node's tag is at the zoom the web is at (its size on screen stays the same).
func _tag_rect(id: String, zoom: float) -> Rect2:
	var tag: Control = _tags[id]
	return Rect2(tag.position + tag.pivot_offset * (1.0 - 1.0 / zoom), tag.size / zoom)


## Each node's name goes on the side of it (under its tag, below, above, right, left, then the corners) that crowds the
## other nodes, tags and names least, worked out once for the whole web at real size. A name grows from the edge of its
## node, so it never runs back over it as it keeps its size when the web is zoomed out. Which names
## are left off at the zoom the web is at is _declutter's job.
func _place_labels() -> void:
	var taken: Array[Rect2] = []
	for id in _node_buttons:
		_place_tag(id, Side.BELOW)
		taken.append(Rect2(_point(id) - _foot(id) * 0.5, _foot(id)))
		taken.append(Rect2(_tags[id].position, _tags[id].size))
	for id in _labels:
		var label: Label = _labels[id]
		var at := _point(id)
		var box := label.size
		var half := _foot(id) * 0.5
		var tag_h: float = _tags[id].size.y
		# Where the name hangs from, and the point of the name that sits on it.
		var options: Array = [
			[at + Vector2(0, half.y + TAG_GAP + tag_h + LABEL_GAP), Vector2(box.x * 0.5, 0)],
			[at + Vector2(0, half.y + LABEL_GAP), Vector2(box.x * 0.5, 0)],
			[at + Vector2(0, -half.y - LABEL_GAP), Vector2(box.x * 0.5, box.y)],
			[at + Vector2(half.x + LABEL_GAP, 0), Vector2(0, box.y * 0.5)],
			[at + Vector2(-half.x - LABEL_GAP, 0), Vector2(box.x, box.y * 0.5)],
			[at + half * 0.7 + Vector2.ONE * LABEL_GAP, Vector2.ZERO],
			[at + Vector2(-half.x * 0.7 - LABEL_GAP, half.y * 0.7 + LABEL_GAP), Vector2(box.x, 0)],
			[at + Vector2(half.x * 0.7 + LABEL_GAP, -half.y * 0.7 - LABEL_GAP), Vector2(0, box.y)],
			[at - half * 0.7 - Vector2.ONE * LABEL_GAP, box],
		]
		var own := Rect2(at - half, _foot(id))
		var own_tag := Rect2(_tags[id].position, _tags[id].size)
		var best := 0
		var best_cost := INF
		for i in options.size():
			var rect := Rect2(options[i][0] - options[i][1], box)
			var cost := float(i) * 0.1
			for other in taken:
				cost += rect.intersection(other).get_area() if other != own and other != own_tag else 0.0
			if rect.intersects(own_tag):
				cost += rect.intersection(own_tag).get_area()
			if cost < best_cost:
				best = i
				best_cost = cost
		label.pivot_offset = options[best][1]
		label.position = options[best][0] - options[best][1]


## Settles the names and tags at the zoom the web is at (the CEO's rule: nothing is within NAME_CLEAR px
## on screen of another node, name or tag). A buyable node's tag goes first, under the node, else above
## it, else beside it; then the names of the nodes one buy away, then the tags of the rest, then every other name. A name
## with no room is left off (the card and the tooltip still say it); so is a tag with no room either side.
func _declutter() -> void:
	var zoom := _web.scale.x
	if zoom <= 0.0:
		return
	var clear := NAME_CLEAR / zoom
	var on_show: Array = _node_buttons.keys().filter(func(id: String) -> bool: return _node_buttons[id].visible and _node_buttons[id].get_parent().visible)
	var nodes := {}
	for id in on_show:
		nodes[id] = Rect2(_point(id) - _foot(id) * 0.5, _foot(id)).grow(clear)
	var kept: Array[Rect2] = []
	# The section names on the rim are in the way of a name too, so they stand clear of every node first.
	for section in _headings:
		var heading: Label = _headings[section]
		if heading.visible and heading.get_parent().visible:
			_stand_clear(section, zoom, nodes, kept)
			kept.append(_text_rect(heading, zoom).grow(clear))
	for id in _labels:
		_labels[id].visible = false
		_tags[id].visible = false
	var lit: Array = on_show.filter(func(id: String) -> bool: return _is_lit(id))
	var rest: Array = on_show.filter(func(id: String) -> bool: return not _is_lit(id))
	var owned: Array = _profile.get_upgrades() if _profile != null else []
	for id in lit:
		if not id in owned:
			_keep_tag(id, zoom, clear, nodes, kept)
	for id in lit:
		_keep_name(id, zoom, clear, nodes, kept)
	for id in rest:
		_keep_tag(id, zoom, clear, nodes, kept)
	for id in rest:
		_keep_name(id, zoom, clear, nodes, kept)


## Moves a section's name out along its rim until it touches no node and no other section name.
func _stand_clear(section: String, zoom: float, nodes: Dictionary, kept: Array[Rect2]) -> void:
	var heading: Label = _headings[section]
	_place_heading(section)
	var step := 8.0 / zoom
	for i in 80:
		if _is_free(_text_rect(heading, zoom), "", nodes, kept):
			return
		heading.position += _rim_dirs[section] * step


## The room a name's own letters take at this zoom (its box is wider than its text).
func _text_rect(label: Label, zoom: float) -> Rect2:
	var box := Rect2(label.position + label.pivot_offset * (1.0 - 1.0 / zoom), label.size / zoom)
	var font := label.get_theme_font(&"font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x + 4.0
	var wide := minf(width / zoom, box.size.x)
	return Rect2(box.position + Vector2((box.size.x - wide) * 0.5, 0.0), Vector2(wide, box.size.y))


## Shows a node's tag under it, or else above it, where it is clear of every node and of what is kept.
func _keep_tag(id: String, zoom: float, clear: float, nodes: Dictionary, kept: Array[Rect2]) -> void:
	if _profile != null and (id in _profile.get_upgrades() or _profile.why_not_buy(id).begins_with("Closed")):
		return
	for side in [Side.BELOW, Side.ABOVE, Side.RIGHT, Side.LEFT]:
		_place_tag(id, side)
		var rect := _tag_rect(id, zoom)
		if _is_free(rect, id, nodes, kept):
			_tags[id].visible = true
			kept.append(rect.grow(clear))
			return
	_place_tag(id, Side.BELOW)


## Shows a node's name where it was placed, if that is clear of every node and of what is kept.
func _keep_name(id: String, zoom: float, clear: float, nodes: Dictionary, kept: Array[Rect2]) -> void:
	var label: Label = _labels[id]
	# The name is scaled about the point it hangs from, so its rect at this zoom is smaller or larger than at real size.
	var rect := Rect2(label.position + label.pivot_offset * (1.0 - 1.0 / zoom), label.size / zoom)
	if _is_free(rect, "", nodes, kept):
		label.visible = true
		kept.append(rect.grow(clear))


## True when a rect touches no node (but its own) and nothing kept.
func _is_free(rect: Rect2, own: String, nodes: Dictionary, kept: Array[Rect2]) -> bool:
	for other in nodes:
		if other != own and rect.intersects(nodes[other]):
			return false
	for other in kept:
		if rect.intersects(other):
			return false
	return true


## True when a node is bought or one buy away: drawn in full, not dimmed.
func _is_lit(id: String) -> bool:
	return _profile != null and (id in _profile.get_upgrades() or _profile.is_near(id))


## A name that does not take the mouse, centred in a box of a given size.
func _caption(text: String, variation: StringName, box: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = box
	return label


## A node drawn whole: its shape by kind, its glyph (a tick once owned) inside. The key draws the
## same shapes with the same call.
func _draw_mark(id: String) -> void:
	var mark: Control = _marks[id]
	var state: String = mark.get_meta("state", "far")
	var kind := _kind(id)
	var middle := NODE_SIZE * 0.5
	if kind != "stat":
		var fill := OWNED_FILL if state == "owned" else NODE_FILL
		if _node_buttons[id].is_hovered():
			fill = fill.lightened(0.15)
		draw_shape(mark, kind, middle, fill, _edge(state))
	var tint := UiTokens.colour(&"bone") if state == "owned" else (COLOUR_ACT if state == "open" else FAR_EDGE)
	var glyph := "tick" if state == "owned" else _glyph(id)
	mark.draw_texture_rect(_icon(glyph), Rect2(middle - Vector2(10, 10), Vector2(20, 20)), false, tint if glyph != "coin" else UiTokens.fade(1.0))


## One of the six shapes of the key: a Stat is a circle, a Behaviour a hexagon, a Castle node a
## rounded square, a Link a dashed diamond, a Gate a square in a thin ring and a Capstone a circle in a thin ring.
static func draw_shape(canvas: CanvasItem, kind: String, centre: Vector2, fill: Color, edge: Color) -> void:
	var ring := UiTokens.colour(&"line")
	match kind:
		"behaviour":
			var points := PackedVector2Array()
			for i in 6:
				points.append(centre + Vector2.from_angle(-PI * 0.5 + i * PI / 3.0) * 22.0)
			canvas.draw_colored_polygon(points, fill)
			points.append(points[0])
			canvas.draw_polyline(points, edge, 3.0, true)
		"castle":
			var box := StyleBoxFlat.new()
			box.bg_color = fill
			box.border_color = edge
			box.set_border_width_all(3)
			box.set_corner_radius_all(8)
			canvas.draw_style_box(box, Rect2(centre - Vector2(20, 20), Vector2(40, 40)))
		"link":
			var points := PackedVector2Array([centre + Vector2(0, -22), centre + Vector2(22, 0), centre + Vector2(0, 22), centre + Vector2(-22, 0)])
			canvas.draw_colored_polygon(points, fill)
			for i in 4:
				canvas.draw_dashed_line(points[i], points[(i + 1) % 4], edge, 3.0, 5.0)
		"gate":
			canvas.draw_arc(centre, 26.0, 0.0, TAU, 48, ring, 1.5, true)
			var box := StyleBoxFlat.new()
			box.bg_color = fill
			box.border_color = edge
			box.set_border_width_all(3)
			box.set_corner_radius_all(6)
			canvas.draw_style_box(box, Rect2(centre - Vector2(18, 18), Vector2(36, 36)))
		"capstone":
			canvas.draw_arc(centre, 26.0, 0.0, TAU, 48, ring, 1.5, true)
			canvas.draw_circle(centre, 20.0, fill)
			canvas.draw_arc(centre, 19.0, 0.0, TAU, 40, edge, 3.0, true)
		_:
			canvas.draw_circle(centre, 20.0, fill)
			canvas.draw_arc(centre, 20.0, 0.0, TAU, 40, edge, 3.0, true)


## Names keep their size on screen whatever the zoom; node names go when the web is too small for them.
func _sync_labels() -> void:
	var zoom := _web.scale.x
	if zoom <= 0.0:
		return
	var shown := zoom >= LABELS_MIN_ZOOM
	for id in _labels:
		_labels[id].scale = Vector2.ONE / zoom
		_labels[id].self_modulate.a = 1.0 if shown else 0.0
		_tags[id].scale = Vector2.ONE / zoom
	_declutter()
	for section in _headings:
		_headings[section].scale = Vector2.ONE / zoom


# ------------------------------------------------------------------ finding your way

## The nodes the tree shows the player: every one found so far.
func found_ids() -> Array:
	return _node_buttons.keys().filter(func(id: String) -> bool: return _node_buttons[id].visible)


## "Found 12 of about 70": the total is only a round figure (up to the next ten) of the nodes this Hero's tree holds.
func found_text() -> String:
	var all := 0
	for id in _content["upgrade_nodes"]:
		var node: Dictionary = _content["upgrade_nodes"][id]
		if not node.has("hero") or str(node["hero"]) == selected_pillar:
			all += 1
	return "Found %d of about %d" % [found_ids().size(), ceili(all / 10.0) * 10]


## The line, the minimap and the Can buy now strip, from what the profile has.
func _refresh_side() -> void:
	_found.text = found_text()
	# One or two nodes need no map.
	_minimap.visible = found_ids().size() >= MINIMAP_MIN_NODES
	_minimap.queue_redraw()
	_refresh_strip()


## What can be bought now, cheapest first; nothing while the guided buys are due (the banner asks instead).
func buy_now_ids() -> Array:
	if _profile == null or _profile.get_guided_step() != "":
		return []
	var ids: Array = _profile.get_buyable_nodes().filter(func(id: String) -> bool: return _node_buttons.has(id) and _node_buttons[id].visible)
	var nodes: Dictionary = _content["upgrade_nodes"]
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := int(nodes[a]["cost"])
		var cb := int(nodes[b]["cost"])
		return ca < cb or (ca == cb and a < b))
	return ids


func _refresh_strip() -> void:
	var ids := buy_now_ids()
	if ids == _strip_ids:
		return
	_strip_ids = ids
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	if ids.is_empty():
		return
	var caption := Label.new()
	caption.text = "Can buy now"
	caption.theme_type_variation = &"Caption"
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_strip.add_child(caption)
	for id in ids.slice(0, STRIP_MAX):
		var node: Dictionary = _content["upgrade_nodes"][id]
		var star := HoldfastMeta.is_star_node(node)
		var button := _button("%s  %s" % [node["name"], str(int(node["cost"])) if star else Hud.format_number(int(node["cost"]))])
		button.icon = _icon("star" if star else "coin")
		button.pressed.connect(go_to.bind(id))
		_strip.add_child(button)
	if ids.size() > STRIP_MAX:
		var more := Label.new()
		more.text = "and %d more" % (ids.size() - STRIP_MAX)
		more.theme_type_variation = &"Caption"
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_strip.add_child(more)


## Takes the view to a node: at real size at least, the node in the middle, the focus on it.
func go_to(id: String) -> void:
	if not _node_buttons.has(id) or not _node_buttons[id].visible or _view.size == Vector2.ZERO:
		return
	close_card()
	var zoom := clampf(maxf(_web.scale.x, 1.0), ZOOM_MIN, ZOOM_MAX)
	_moved_view = true
	_fade_other_tabs(false)
	_web.scale = Vector2.ONE * zoom
	_web.position = _view.size * 0.5 - _point(id) * zoom
	_sync_labels()
	_keep_in_view()
	_node_buttons[id].grab_focus()


## A pad or the keyboard took the focus to a node: if it is off the edge of the view, the view moves
## to put it in the middle, so the focus is never out of sight.
func _node_focused(id: String) -> void:
	if _view.size == Vector2.ZERO or not is_visible_in_tree():
		return
	var rect: Rect2 = _node_buttons[id].get_global_rect()
	var view := _view.get_global_rect().grow(-NODE_SIZE.x * 0.5)
	if view.encloses(rect):
		return
	_moved_view = true
	_web.position += _view.get_global_rect().get_center() - rect.get_center()
	_sync_labels()
	_keep_in_view()


## The web, small: one dot for each node found, and a frame round what the view shows now.
func _draw_minimap() -> void:
	var box := Rect2(Vector2.ZERO, _minimap.size)
	_minimap.draw_rect(box, UiTokens.colour(&"raise", 0.6))
	_minimap.draw_rect(box, CARD_EDGE, false, 1.0)
	var ids := found_ids()
	if ids.is_empty() or box.size.x <= 0.0:
		return
	var bounds := Rect2(_point(ids[0]), Vector2.ZERO)
	for id in ids:
		bounds = bounds.expand(_point(id))
	bounds = bounds.grow(MINIMAP_PAD)
	_map_bounds = bounds
	_map_scale = minf((box.size.x - 2.0 * MINIMAP_INSET) / bounds.size.x, (box.size.y - 2.0 * MINIMAP_INSET) / bounds.size.y)
	_map_origin = (box.size - bounds.size * _map_scale) * 0.5
	var owned: Array = _profile.get_upgrades() if _profile != null else []
	for id in ids:
		var colour := OWNED_EDGE if id in owned else (COLOUR_ACT if _profile != null and _profile.is_near(id) else FAR_EDGE)
		_minimap.draw_circle(_map_origin + (_point(id) - bounds.position) * _map_scale, MINIMAP_DOT, colour)
	if _web.scale.x > 0.0:
		var shown := Rect2(-_web.position / _web.scale.x, _view.size / _web.scale.x)
		var frame := Rect2(_map_origin + (shown.position - bounds.position) * _map_scale, shown.size * _map_scale)
		_minimap.draw_rect(frame.intersection(box), UiTokens.colour(&"bone", 0.8), false, 1.0)


## A press or a drag on the map takes the view there.
func _on_minimap_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = event.position
	else:
		return
	if _map_scale <= 0.0 or _view.size == Vector2.ZERO:
		return
	var point := (at - _map_origin) / _map_scale + _map_bounds.position
	_moved_view = true
	_fade_other_tabs(false)
	_web.position = _view.size * 0.5 - point * _web.scale.x
	_keep_in_view()
	accept_event()



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
		var button := _button(label)
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
	# The section names move out as the zoom settles, so the fit is made twice: the second time with them where they now are.
	for pass_number in 2:
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
	# Twice, as in show_tab: the section names move out as the zoom settles.
	_fit_overview()
	_fit_overview()


func _fit_overview() -> void:
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
	_minimap.queue_redraw()
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


## A button in the theme's look, at least 44 px tall.
func _button(text: String, variation := &"") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size.y = MIN_BUTTON
	return button


## A transparent box with a blue outline: where a controller or the keyboard is.
static func _focus_style(radius := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.colour(&"night", 0.0)
	box.border_color = COLOUR_FOCUS
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	return box


# ------------------------------------------------------------------ the detail card

## The key: each shape (Stat, Behaviour, Castle, Link, Gate, Capstone) drawn as owned, buyable and
## locked, over the foot of the view while it is open.
func _build_key() -> void:
	var panel := PanelContainer.new()
	panel.name = "Key"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.add_child(panel)
	panel.position = Vector2(12, 12)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	panel.add_child(grid)
	grid.add_child(Control.new())
	for state in ["Owned", "Buyable", "Locked"]:
		var head := Label.new()
		head.text = state
		head.theme_type_variation = &"Caption"
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(head)
	for kind in KINDS:
		var name := Label.new()
		name.text = str(kind).capitalize()
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(name)
		for state in ["owned", "open", "far"]:
			var swatch := Control.new()
			swatch.custom_minimum_size = Vector2(48, 48)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch.draw.connect(func() -> void:
				var fill := OWNED_FILL if state == "owned" else NODE_FILL
				draw_shape(swatch, kind, swatch.size * 0.5, fill, _edge(state)))
			grid.add_child(swatch)
	_key = panel


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
	dim.color = UiTokens.colour(&"night", 0.7)
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
	_card_style.bg_color = UiTokens.colour(&"raise")
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
	# The section's colour is on this bar over the header and nowhere else on the card.
	_card_bar = ColorRect.new()
	_card_bar.custom_minimum_size = Vector2(0, 6)
	_card_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_card_bar)
	var header := HBoxContainer.new()
	column.add_child(header)
	_card_title = Label.new()
	_card_title.theme_type_variation = &"Heading"
	_card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_card_title)
	_card_close = _button("\u00d7")
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
	_card_note.modulate = UiTokens.fade(0.75)
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
	_card_price.theme_type_variation = &"CardPrice"
	_card_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_card_price)
	_card_buy = _act_button("Buy")
	_card_buy.pressed.connect(_card_buy_pressed)
	footer.add_child(_card_buy)
	_card_refund = _button("Refund")
	_card_refund.add_theme_stylebox_override("focus", _focus_style())
	_card_refund.pressed.connect(func() -> void: refund_requested.emit(_card_id))
	footer.add_child(_card_refund)


func _card_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## The one amber button of a card.
func _act_button(text: String) -> Button:
	return _button(text, &"MainButton")


func _draw_tick() -> void:
	_card_tick.draw_circle(Vector2(18, 18), 17.0, OWNED_FILL)
	_card_tick.draw_arc(Vector2(18, 18), 17.0, 0.0, TAU, 32, OWNED_EDGE, 2.0, true)
	_card_tick.draw_polyline(PackedVector2Array([Vector2(9, 18), Vector2(16, 25), Vector2(27, 11)]), UiTokens.colour(&"bone"), 4.0, true)


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
	_card_bar.color = UiTokens.colour(SECTION_TOKEN.get(str(node["branch"]), &"mute"))
	_clear(_card_lines)
	_clear(_card_extra)
	for line in _change_lines(id, owned):
		_card_lines.add_child(_card_label(_capital(line)))
	if node.has("excludes"):
		var names: PackedStringArray = []
		for other in node["excludes"]:
			names.append(str(_content["upgrade_nodes"][other]["name"]))
		_card_extra.add_child(_card_label("Replaces %s" % ", ".join(names)))
	if node.get("requires", []).size() > 1:
		var parents: PackedStringArray = []
		for required in node["requires"]:
			parents.append(str(_content["upgrade_nodes"][required]["name"]))
		_card_extra.add_child(_card_label("Needs both %s" % " and ".join(parents)))
	if node.has("hero") and node.has("tower"):
		_card_extra.add_child(_card_label("Joins %s and %s" % [_content["hero_paths"][node["hero"]]["name"], _content["towers"][node["tower"]]["name"]]))
	if int(node.get("grants", {}).get("mage_cards", 0)) > 0:
		_card_extra.add_child(_gate_cards())
	_card_tick.visible = owned
	_card_buy.visible = not owned
	_card_buy.icon = _icon("star" if HoldfastMeta.is_star_node(node) else "coin")
	_card_refund.visible = owned
	_card_price.theme_type_variation = &"CardPrice"
	var reason: String = _profile.why_not_refund(id) if owned else _profile.why_not_buy(id)
	var shortfall := _shortfall(node, reason)
	_card_note.text = "" if reason == "" or shortfall > 0 else reason
	if owned:
		var gain: Dictionary = _profile.get_refund_gain(id)
		_card_price.text = "+%s gold" % Hud.format_number(int(gain["gold"])) if int(gain["stars"]) == 0 else "+%d %s, fee %s gold" % [int(gain["stars"]), "star" if int(gain["stars"]) == 1 else "stars", Hud.format_number(-int(gain["gold"]))]
		_card_price.theme_type_variation = &"CardPriceBold"
		_card_refund.disabled = reason != ""
	else:
		_card_price.text = _price(node) + (" gold" if not HoldfastMeta.is_star_node(node) else "")
		if shortfall > 0:
			# A cue besides the red: the words say how much is missing.
			_card_price.text += "  (need %s more)" % Hud.format_number(shortfall)
			_card_price.theme_type_variation = &"CardPriceShort"
		_card_buy.disabled = reason != ""


## What a node does, one line each, in numbers that can be set beside another node's: each stat it
## changes with the value before and after (just the value once owned). A node with its own
## description (a link, a gate) says that, with the numbers that start above zero: a bonus that
## starts from nothing is already in the description, so it is not told twice.
func _change_lines(id: String, owned: bool) -> PackedStringArray:
	var node: Dictionary = _content["upgrade_nodes"][id]
	var out := PackedStringArray()
	for line in _profile.get_effect_lines(id):
		if node.has("text") and float(line["before"]) <= 0.0:
			continue
		var change := _num(float(line["after"])) if owned else "%s -> %s" % [_num(float(line["before"])), _num(float(line["after"]))]
		# A Recruit's stat has no one number to start from (each class has its own), so a card says how much it multiplies.
		if str(line["stat"]).begins_with("recruit.") and float(line["before"]) > 0.0:
			change = "x%s" % _num(float(line["after"]) / float(line["before"]))
		out.append("%s %s" % [_stat_text(str(line["stat"])), change])
	if out.is_empty() or node.has("text"):
		var text := _effect_text(id)
		if text != "":
			out.append(text)
	return out


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
		box.bg_color = UiTokens.colour(&"arcane").darkened(0.6) if i == 0 else UiTokens.colour(&"deep")
		box.border_color = UiTokens.colour(&"arcane") if i == 0 else UiTokens.colour(&"line")
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
		create_tween().tween_property(button, "modulate", UiTokens.fade(1.0), GLOW_SECONDS)
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
	return HoldfastMeta.cost_text(node) if HoldfastMeta.is_star_node(node) else Hud.format_number(int(node["cost"]))


static func _effects_text(effects: Array) -> String:
	var parts: PackedStringArray = []
	for effect in effects:
		var what := _stat_text(str(effect["stat"]))
		if effect.has("add"):
			parts.append("%s%s %s" % ["+" if float(effect["add"]) >= 0.0 else "", _trim(float(effect["add"])), what])
		if effect.has("multiply"):
			parts.append("x%s %s" % [_trim(float(effect["multiply"])), what])
	return ", ".join(parts)


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


## "tower.range" is "range", "hero.attack.damage" is "arrow damage": the scope is dropped.
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
		_end_refund_ask()
		if _guide.visible and not _guide_button.disabled:
			_guide_button.grab_focus()
		else:
			_back.grab_focus()
	else:
		_end_refund_ask()
		close_card()
