class_name HeroKnockdown
extends RefCounted
## The Hero's health, knock-down and getting back up, as plain data:
## {max_health, health, downed, knockdowns, get_up_in}. Every function returns a
## new state and leaves the one it was given alone.


## Seconds the Hero stays down on their Nth knock-down of the run (1-based). The
## list holds its last entry for any later one.
static func delay_for(delays: Array, knockdown_number: int) -> float:
	return float(delays[clampi(knockdown_number - 1, 0, delays.size() - 1)])


## Pack check: a non-empty list of finite numbers at or above zero that never shrinks.
static func validate(delays: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not delays is Array:
		errors.append("knock-down delays must be a list of seconds")
		return errors
	if delays.is_empty():
		errors.append("knock-down delays must not be empty")
	var previous := 0.0
	for i in delays.size():
		var value: Variant = delays[i]
		if not (value is int or value is float) or not is_finite(value) or value < 0:
			errors.append("knock-down delay %d must be a number at or above zero" % (i + 1))
			continue
		if value < previous:
			errors.append("knock-down delay %d is shorter than the one before" % (i + 1))
		previous = value
	return errors


static func new_state(max_health: float) -> Dictionary:
	return {"max_health": max_health, "health": max_health, "downed": false, "knockdowns": 0, "get_up_in": 0.0}


## Health at or below zero knocks the Hero down once. A Hero who is down, and
## zero, negative or NaN damage, change nothing.
static func take_damage(state: Dictionary, damage: float, delays: Array) -> Dictionary:
	var out := state.duplicate()
	if out["downed"] or not (damage > 0.0):
		return out
	out["health"] = maxf(float(out["health"]) - damage, 0.0)
	if float(out["health"]) <= 0.0:
		out["downed"] = true
		out["knockdowns"] = int(out["knockdowns"]) + 1
		out["get_up_in"] = delay_for(delays, int(out["knockdowns"]))
	return out


## Counts the wait down; at zero the Hero is up with full health and the count is
## kept. A Hero who is up never regenerates here.
static func tick(state: Dictionary, dt: float) -> Dictionary:
	var out := state.duplicate()
	if not out["downed"] or not (dt > 0.0):
		return out
	out["get_up_in"] = maxf(float(out["get_up_in"]) - dt, 0.0)
	if float(out["get_up_in"]) <= 0.0:
		out["downed"] = false
		out["health"] = out["max_health"]
	return out
