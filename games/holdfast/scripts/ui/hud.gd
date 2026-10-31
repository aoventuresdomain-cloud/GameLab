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
## The player pressed while the special's first-time prompt waited; the run flow lets the Hero fire.
signal special_requested

## Under a teaching note while the run waits.
const HOLD_HINT := "Click, tap or press a key to begin."

var _source: Node


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
	var down: float = _source.get_hero_down_seconds()
	if down > 0.0:
		_hero_value.text = "Down %d s" % ceili(down)
	else:
		_hero_value.text = "%d / %d" % [_source.get_hero_health(), _source.get_hero_health_max()]
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


## 1234567 -> "1,234,567".
static func format_number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
