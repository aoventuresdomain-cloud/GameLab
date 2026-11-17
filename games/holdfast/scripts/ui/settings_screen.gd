extends Control
## Settings: volume, screen shake, flashes and reduced motion. It reads the settings and asks for changes through
## signals; the run flow acts and saves them.

signal volume_requested(value: float)
signal shake_requested(on: bool)
signal flashes_requested(on: bool)
signal reduced_motion_requested(on: bool)
signal back_requested
signal achievements_requested

@onready var _volume: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _volume_ring: Panel = %FocusRing
@onready var _shake: CheckButton = %ShakeButton
@onready var _flashes: CheckButton = %FlashesButton
@onready var _motion: CheckButton = %MotionButton
@onready var _note: Label = %Note
@onready var _back: Button = %BackButton
@onready var _achievements: Button = %AchievementsButton

var _settings: Node


func _ready() -> void:
	_volume.value_changed.connect(func(value: float) -> void: volume_requested.emit(value / 100.0))
	# A slider draws no focus ring of its own, so it has the same ring as every other control (F-201).
	_volume.focus_entered.connect(func() -> void: _volume_ring.visible = true)
	_volume.focus_exited.connect(func() -> void: _volume_ring.visible = false)
	_shake.toggled.connect(shake_requested.emit)
	_flashes.toggled.connect(flashes_requested.emit)
	_motion.toggled.connect(reduced_motion_requested.emit)
	_back.pressed.connect(back_requested.emit)
	_achievements.pressed.connect(achievements_requested.emit)
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
	_motion.set_pressed_no_signal(_settings.is_motion_reduced())
	_motion.text = "Reduce motion: %s" % ("On" if _settings.is_motion_reduced() else "Off")


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_back.grab_focus()
