class_name BossRules
extends RefCounted
## A boss as plain data: {max_health, health, required_ability, defeated}. Its shroud
## turns every hit away unless the Hero has the ability the pack names in play.
## Every function returns a new dictionary and leaves the one it was given alone.


static func new_boss(max_health: float, required_ability: String) -> Dictionary:
	return {"max_health": max_health, "health": max_health, "required_ability": required_ability, "defeated": false}


## A hit lands only while `required_ability` is among `hero_abilities`. Health stops at 0
## and 0 means defeated. Zero or negative (or NaN) damage and a defeated boss change nothing.
static func take_hit(boss: Dictionary, damage: float, hero_abilities: Array) -> Dictionary:
	var out := boss.duplicate()
	if not (damage > 0.0) or out["defeated"] or not str(out["required_ability"]) in hero_abilities:
		return out
	out["health"] = maxf(float(out["health"]) - damage, 0.0)
	out["defeated"] = float(out["health"]) <= 0.0
	return out


## Pack check: the health is a finite number above zero and the ability a non-empty string.
static func validate(max_health: Variant, required_ability: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not (max_health is int or max_health is float) or not is_finite(max_health) or max_health <= 0:
		errors.append("boss health must be a number above zero")
	if not required_ability is String or required_ability == "":
		errors.append("boss required ability must be a non-empty string")
	return errors
