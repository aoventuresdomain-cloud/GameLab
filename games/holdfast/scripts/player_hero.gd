class_name HoldfastPlayerHero
extends SimController
## The player's Hero: WASD or the arrow keys to move, Space for the ability.
## The playable build calls sample() every frame and the engine takes the state
## once per tick, so a Space press between two ticks is kept until a tick takes it.

const ACTION_LEFT := "hero_left"
const ACTION_RIGHT := "hero_right"
const ACTION_UP := "hero_up"
const ACTION_DOWN := "hero_down"
const ACTION_ABILITY := "hero_ability"

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
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)


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
