class_name HoldfastSettings
extends Node
## The player's settings: volume, screen shake and flashes, and which one-time hints they have
## seen. Saved through the kit's SaveService in a file of their own, apart from the profile, so
## "New game" keeps them and a profile reset cannot lose them. Screens read it through get_/is_/
## are_ accessors; the run flow is the only caller of the setters.
##
## Headless runs (tests, CI) keep the settings in memory and never touch the player's file,
## unless `save_path` is set.

signal changed
## Something the player must be told: a damaged or newer file, or a failed save.
signal notice(message: String)

const DEFAULT_PATH := "user://holdfast_settings.sav"
const SAVE_VERSION := 1
const DEFAULT_VOLUME := 0.7

## Where the settings are saved; "" keeps them in memory only.
var save_path := ""
var load_message := ""

var _volume := DEFAULT_VOLUME
var _shake := true
var _flashes := true
var _hints_seen: Array = []
var _service: SaveService


func _ready() -> void:
	if save_path == "" and DisplayServer.get_name() != "headless":
		save_path = DEFAULT_PATH
	load_settings()


## Reads the file (if any). A missing or unreadable file gives the defaults.
func load_settings() -> void:
	_volume = DEFAULT_VOLUME
	_shake = true
	_flashes = true
	_hints_seen = []
	load_message = ""
	_service = null
	if save_path != "":
		_service = SaveService.new(save_path, SAVE_VERSION)
		var loaded := _service.load_save()
		load_message = str(loaded["message"])
		var saved: Dictionary = loaded["data"]
		var volume: Variant = saved.get("volume")
		_volume = clampf(float(volume), 0.0, 1.0) if volume is float or volume is int else DEFAULT_VOLUME
		_shake = saved.get("shake") if saved.get("shake") is bool else true
		_flashes = saved.get("flashes") if saved.get("flashes") is bool else true
		var seen: Variant = saved.get("hints_seen", [])
		for id in seen if seen is Array else []:
			if id is String and not id in _hints_seen:
				_hints_seen.append(id)
		if load_message != "":
			notice.emit(load_message)
	_apply_volume()
	changed.emit()


func get_volume() -> float:
	return _volume


func is_shake_on() -> bool:
	return _shake


func are_flashes_on() -> bool:
	return _flashes


func has_seen_hint(id: String) -> bool:
	return id in _hints_seen


func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_commit()


func set_shake(on: bool) -> void:
	_shake = on
	_commit()


func set_flashes(on: bool) -> void:
	_flashes = on
	_commit()


## A one-time hint has been shown; it is not shown again.
func see_hint(id: String) -> void:
	if id in _hints_seen:
		return
	_hints_seen.append(id)
	_commit()


## The master bus follows the volume: silent at zero, else the volume as a loudness.
func _apply_volume() -> void:
	AudioServer.set_bus_mute(0, _volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.0001)))


func _commit() -> void:
	if _service != null and not _service.save({"volume": _volume, "shake": _shake, "flashes": _flashes, "hints_seen": _hints_seen}):
		notice.emit("Your settings could not be saved.")
	changed.emit()
