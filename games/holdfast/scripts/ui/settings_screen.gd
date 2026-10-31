extends Control
## Settings: volume, screen shake and flashes. It reads the settings and asks for changes through
## signals; the run flow acts and saves them.

signal volume_requested(value: float)
signal shake_requested(on: bool)
signal flashes_requested(on: bool)
signal back_requested

@onready var _volume: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _shake: CheckButton = %ShakeButton
@onready var _flashes: CheckButton = %FlashesButton
@onready var _note: Label = %Note
@onready var _back: Button = %BackButton

var _settings: Node


func _ready() -> void:
	_volume.value_changed.connect(func(value: float) -> void: volume_requested.emit(value / 100.0))
	_shake.toggled.connect(shake_requested.emit)
	_flashes.toggled.connect(flashes_requested.emit)
	_back.pressed.connect(back_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


func bind(settings: Node) -> void:
	_settings = settings
	settings.changed.connect(refresh)
	settings.notice.connect(func(message: String) -> void: _note.text = message)
	refresh()
	if settings.load_message != "":
		_note.text = settings.load_message


## Shows the settings as they are, without asking for anything back.
func refresh() -> void:
	if _settings == null:
		return
	_volume.set_value_no_signal(roundf(_settings.get_volume() * 100.0))
	_volume_value.text = "%d%%" % roundi(_settings.get_volume() * 100.0)
	_shake.set_pressed_no_signal(_settings.is_shake_on())
	_shake.text = "Screen shake: %s" % ("On" if _settings.is_shake_on() else "Off")
	_flashes.set_pressed_no_signal(_settings.are_flashes_on())
	_flashes.text = "Flashes: %s" % ("On" if _settings.are_flashes_on() else "Off")


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_back.grab_focus()
