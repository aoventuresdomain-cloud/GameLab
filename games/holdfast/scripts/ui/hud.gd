extends Control
## Run HUD: gold, keep health and wave. Reads the run through a RunStateSource
## (signals and get_* accessors only).

@onready var _gold_value: Label = %GoldValue
@onready var _wave_value: Label = %WaveValue
@onready var _keep_value: Label = %KeepValue
@onready var _keep_bar: ProgressBar = %KeepBar
@onready var _hero_value: Label = %HeroValue
@onready var _ability_value: Label = %AbilityValue
@onready var _lost_value: Label = %LostValue
@onready var _wave_banner: Label = %WaveBanner
@onready var _posts_note: Label = %PostsNote

## The player pressed while a teaching run waited; the run flow lifts the hold.
signal begin_requested
## The player asked to pause (true) or resume (false) the run.
signal pause_requested(paused: bool)
## The player asked for 1x or 2x game speed.
signal speed_requested(speed: int)
## The player confirmed leaving the run from the pause screen.
signal leave_requested
## The player pressed while the special's first-time prompt waited; the run flow lets the Hero fire.
signal special_requested

## Under a teaching note while the run waits.
const HOLD_HINT := "Click, tap or press a key to begin."

const LEAVE_TEXT := "Leave run"
const LEAVE_CONFIRM_TEXT := "Leave? Nothing is banked.\nClick again to leave"

var _source: Node
var _pause_button: Button
var _speed_button: Button
var _pause_screen: Control
var _leave_button: Button
var _confirming_leave := false


func _ready() -> void:
	_build_controls()


## The Pause and Speed buttons under the top bar's right end, and the pause screen over the run.
func _build_controls() -> void:
	var box := HBoxContainer.new()
	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.tooltip_text = "Pause (Esc or P)"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(func() -> void: pause_requested.emit(not _paused()))
	box.add_child(_pause_button)
	_speed_button = Button.new()
	_speed_button.text = "1x"
	_speed_button.tooltip_text = "Game speed"
	_speed_button.focus_mode = Control.FOCUS_NONE
	_speed_button.pressed.connect(func() -> void: speed_requested.emit(1 if _speed() == 2 else 2))
	box.add_child(_speed_button)
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_top = 104.0
	box.offset_right = -16.0
	add_child(box)
	_pause_screen = ColorRect.new()
	(_pause_screen as ColorRect).color = Color(0, 0, 0, 0.6)
	_pause_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_screen.visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_screen.add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(320, 0)
	centre.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.theme_type_variation = &"HudValue"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func() -> void: pause_requested.emit(false))
	column.add_child(resume)
	_leave_button = Button.new()
	_leave_button.text = LEAVE_TEXT
	_leave_button.pressed.connect(_on_leave_pressed)
	column.add_child(_leave_button)
	add_child(_pause_screen)


func _paused() -> bool:
	return _source != null and _source.is_paused()


func _speed() -> int:
	return _source.get_speed() if _source != null else 1


## The first press asks; the second leaves.
func _on_leave_pressed() -> void:
	if not _confirming_leave:
		_confirming_leave = true
		_leave_button.text = LEAVE_CONFIRM_TEXT
		return
	_confirming_leave = false
	_leave_button.text = LEAVE_TEXT
	leave_requested.emit()


func bind(source: Node) -> void:
	if _source == source:
		return
	if _source:
		_source.gold_changed.disconnect(_on_gold_changed)
		_source.keep_health_changed.disconnect(_on_keep_health_changed)
		_source.wave_changed.disconnect(_on_wave_changed)
	_source = source
	if not _source:
		return
	_source.gold_changed.connect(_on_gold_changed)
	_source.keep_health_changed.connect(_on_keep_health_changed)
	_source.wave_changed.connect(_on_wave_changed)
	refresh()


func _process(_delta: float) -> void:
	if visible and _source:
		_refresh_hero()


## A click, tap or key asks to lift a teaching run's hold; the press is spent on that and nothing else.
func _input(event: InputEvent) -> void:
	if visible and _source != null and _source.is_running() and not _source.is_held() and event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_P):
		pause_requested.emit(not _paused())
		get_viewport().set_input_as_handled()
		return
	if not visible or _source == null or not _source.is_held():
		return
	if _source.is_teaching_special():
		# Only the special's own key, or a click or tap, answers its prompt.
		var fires: bool = event.is_action_pressed(HoldfastPlayerHero.ACTION_ABILITY, false) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if fires:
			special_requested.emit()
			get_viewport().set_input_as_handled()
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		begin_requested.emit()
		get_viewport().set_input_as_handled()


## The Hero's health, ability wait and knock-down timer, and what has been lost
## so far. Read every frame: the run changes them every tick.
func _refresh_hero() -> void:
	var paused := _paused()
	if _pause_screen != null:
		_pause_screen.visible = paused
		if not paused and _confirming_leave:
			_confirming_leave = false
			_leave_button.text = LEAVE_TEXT
		_pause_button.text = ">" if paused else "II"
		_speed_button.text = "%dx" % _speed()
	var down: float = _source.get_hero_down_seconds()
	if down > 0.0:
		_hero_value.text = "Down %d s" % ceili(down)
	else:
		_hero_value.text = "%s / %s" % [format_number(_source.get_hero_health()), format_number(_source.get_hero_health_max())]
	var wait: float = _source.get_ability_wait()
	_ability_value.text = "Ready" if wait <= 0.0 else "%.1f s" % wait
	_lost_value.text = "%d / %d" % [_source.get_towers_lost(), _source.get_recruits_lost()]
	var banner: String = _source.get_wave_banner()
	_wave_banner.text = banner
	_wave_banner.visible = banner != ""
	# A boss's note outranks the posts line (that one is only up before wave 1).
	var note: String = _source.get_special_note()
	if note == "":
		note = _source.get_boss_note()
	if note == "":
		note = _source.get_posts_note()
		if note != "" and _source.is_held():
			note += "\n" + HOLD_HINT
	_posts_note.text = note
	_posts_note.visible = note != ""


## Pulls the current values, for when the HUD is shown mid-run.
func refresh() -> void:
	if not _source:
		return
	_refresh_hero()
	_on_gold_changed(_source.get_gold())
	_on_keep_health_changed(_source.get_keep_health(), _source.get_keep_health_max())
	_on_wave_changed(_source.get_wave(), _source.get_total_waves())


func _on_gold_changed(gold: int) -> void:
	_gold_value.text = format_number(gold)


func _on_keep_health_changed(current: int, maximum: int) -> void:
	_keep_value.text = "%s / %s" % [format_number(current), format_number(maximum)]
	_keep_bar.max_value = maxi(maximum, 1)
	_keep_bar.value = current


func _on_wave_changed(wave: int, total: int) -> void:
	_wave_value.text = "%d / %d" % [wave, total]


## 1234 -> "1.2K" (see ShortNumber).
static func format_number(value: int) -> String:
	return ShortNumber.of(value)
