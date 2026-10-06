extends Control
## Run HUD: gold, keep health and wave. Reads the run through a RunStateSource
## (signals and get_* accessors only).

@onready var _gold_value: Label = %GoldValue
@onready var _wave_value: Label = %WaveValue
@onready var _keep_value: Label = %KeepValue
@onready var _keep_bar: ProgressBar = %KeepBar

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


## Pulls the current values, for when the HUD is shown mid-run.
func refresh() -> void:
	if not _source:
		return
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
