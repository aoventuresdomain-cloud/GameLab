class_name UnitHealth
extends RefCounted
## Health of one tower or Recruit as plain data: {max_health, health, alive}.
## Every function returns a new dictionary and leaves the one it was given alone.


static func new_unit(max_health: float) -> Dictionary:
	return {"max_health": max_health, "health": max_health, "alive": max_health > 0.0}


## Health stops at 0, and 0 means not alive. The dead and non-positive (or NaN)
## amounts change nothing.
static func damage(unit: Dictionary, amount: float) -> Dictionary:
	var out := unit.duplicate()
	if not (amount > 0.0) or not out["alive"]:
		return out
	out["health"] = maxf(float(out["health"]) - amount, 0.0)
	out["alive"] = float(out["health"]) > 0.0
	return out


## Health stops at the maximum. The dead are not repaired.
static func repair(unit: Dictionary, amount: float) -> Dictionary:
	var out := unit.duplicate()
	if not (amount > 0.0) or not out["alive"]:
		return out
	out["health"] = minf(float(out["health"]) + amount, float(out["max_health"]))
	return out
