class_name HoldfastPlayerHero
extends SimController
## The player's Hero: WASD, the arrow keys, the left stick or the d-pad to move; Space or A for the ability.
## The playable build calls sample() every frame and the engine takes the state
## once per tick, so a Space press between two ticks is kept until a tick takes it.

const ACTION_LEFT := "hero_left"
const ACTION_RIGHT := "hero_right"
const ACTION_UP := "hero_up"
const ACTION_DOWN := "hero_down"
const ACTION_ABILITY := "hero_ability"
## How far a stick must lean before it counts as a move.
const PAD_DEADZONE := 0.3

var move := Vector2.ZERO
var ability_pressed := false
var _ability_was_down := false
var _last_sample_frame := -1


## Adds the Hero's input actions when they are missing. Keys are physical
## positions, so WASD is the same keys on any keyboard layout.
static func ensure_actions() -> void:
	var keys := {
		ACTION_LEFT: [KEY_A, KEY_LEFT],
		ACTION_RIGHT: [KEY_D, KEY_RIGHT],
		ACTION_UP: [KEY_W, KEY_UP],
		ACTION_DOWN: [KEY_S, KEY_DOWN],
		ACTION_ABILITY: [KEY_SPACE],
	}
	# The pad: the left stick or the d-pad to move, A for the ability.
	var pad_buttons := {
		ACTION_LEFT: JOY_BUTTON_DPAD_LEFT, ACTION_RIGHT: JOY_BUTTON_DPAD_RIGHT,
		ACTION_UP: JOY_BUTTON_DPAD_UP, ACTION_DOWN: JOY_BUTTON_DPAD_DOWN, ACTION_ABILITY: JOY_BUTTON_A,
	}
	var pad_axes := {
		ACTION_LEFT: [JOY_AXIS_LEFT_X, -1.0], ACTION_RIGHT: [JOY_AXIS_LEFT_X, 1.0],
		ACTION_UP: [JOY_AXIS_LEFT_Y, -1.0], ACTION_DOWN: [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, PAD_DEADZONE)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
		var button := InputEventJoypadButton.new()
		button.button_index = pad_buttons[action]
		InputMap.action_add_event(action, button)
		if pad_axes.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = pad_axes[action][0]
			motion.axis_value = pad_axes[action][1]
			InputMap.action_add_event(action, motion)


func sample() -> void:
	move = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
	# just_pressed catches a tap shorter than a frame, and holds for the whole frame,
	# so it counts once per frame; the held-state edge covers a press that arrived
	# outside the frame loop.
	var down := Input.is_action_pressed(ACTION_ABILITY)
	var frame := Engine.get_process_frames()
	if (Input.is_action_just_pressed(ACTION_ABILITY) and frame != _last_sample_frame) or (down and not _ability_was_down):
		ability_pressed = true
	_last_sample_frame = frame
	_ability_was_down = down


func get_input(_rules: SimRules, _tick: int) -> Dictionary:
	var input := {"move": [move.x, move.y], "ability": ability_pressed}
	ability_pressed = false
	return input
