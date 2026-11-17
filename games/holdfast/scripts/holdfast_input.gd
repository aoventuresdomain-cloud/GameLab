class_name HoldfastInput
extends RefCounted
## The input actions the screens use beyond Godot's built-in ui_* ones (those cover the d-pad and the
## left stick; A to accept and B to cancel are added here when the build's map lacks them): pausing, the game speed and calling the next wave in a run, and stepping
## between the hub tabs. Keys and pad buttons for the Hero's own actions are in HoldfastPlayerHero.

const ACTION_PAUSE := "run_pause"
const ACTION_SPEED := "run_speed"
const ACTION_CALL_WAVE := "run_call_wave"
const ACTION_TAB_PREV := "tab_prev"
const ACTION_TAB_NEXT := "tab_next"


## Adds the actions when they are missing. Safe to call from every screen that needs one.
static func ensure_actions() -> void:
	_pad_on("ui_accept", JOY_BUTTON_A)
	_pad_on("ui_cancel", JOY_BUTTON_B)
	var keys := {
		ACTION_PAUSE: [KEY_ESCAPE, KEY_P],
		ACTION_SPEED: [KEY_F],
		ACTION_CALL_WAVE: [KEY_N],
		ACTION_TAB_PREV: [KEY_PAGEUP],
		ACTION_TAB_NEXT: [KEY_PAGEDOWN],
	}
	var pads := {
		ACTION_PAUSE: JOY_BUTTON_START,
		ACTION_SPEED: JOY_BUTTON_Y,
		ACTION_CALL_WAVE: JOY_BUTTON_X,
		ACTION_TAB_PREV: JOY_BUTTON_LEFT_SHOULDER,
		ACTION_TAB_NEXT: JOY_BUTTON_RIGHT_SHOULDER,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
		var pad := InputEventJoypadButton.new()
		pad.button_index = pads[action]
		InputMap.action_add_event(action, pad)


## A pad button on a built-in action, unless it already has it.
static func _pad_on(action: String, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	if InputMap.has_action(action) and not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
