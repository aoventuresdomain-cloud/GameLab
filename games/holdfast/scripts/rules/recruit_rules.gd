class_name RecruitRules
extends RefCounted
## A Recruit's health, being downed and revived, the taunt that pulls enemies,
## and what staffing a light post adds. A Recruit is plain data:
## {role, max_health, health, downed, revive_progress}. Every function returns a
## new value and leaves what it was given alone.


static func new_recruit(role: String, max_health: float) -> Dictionary:
	return {"role": role, "max_health": max_health, "health": max_health, "downed": false, "revive_progress": 0.0}


## Health at or below zero means downed. A downed Recruit, and zero, negative or
## NaN damage, change nothing.
static func damage(recruit: Dictionary, amount: float) -> Dictionary:
	var out := recruit.duplicate()
	if out["downed"] or not (amount > 0.0):
		return out
	out["health"] = maxf(float(out["health"]) - amount, 0.0)
	if float(out["health"]) <= 0.0:
		out["downed"] = true
		out["revive_progress"] = 0.0
	return out


## The Hero is standing on a Recruit within `radius`, edge included.
static func standing(hero_pos: Vector2, recruit_pos: Vector2, radius: float) -> bool:
	return hero_pos.distance_squared_to(recruit_pos) <= radius * radius


## Only a downed Recruit changes. While the Hero is on them the progress grows by
## `dt` (never by a zero or negative one); at `revive_time` they get up with
## `revive_health` of their maximum (a fraction, default all of it). With the Hero
## off them the progress goes back to nothing. A `revive_time` of 0 revives on the
## first tick with the Hero on them, and never without the Hero.
static func tick_revive(recruit: Dictionary, hero_on: bool, dt: float, revive_time: float, revive_health: float = 1.0) -> Dictionary:
	var out := recruit.duplicate()
	if not out["downed"]:
		return out
	if not hero_on:
		out["revive_progress"] = 0.0
		return out
	if dt > 0.0:
		out["revive_progress"] = float(out["revive_progress"]) + dt
	if float(out["revive_progress"]) >= revive_time:
		out["downed"] = false
		out["health"] = float(out["max_health"]) * clampf(revive_health, 0.01, 1.0)
		out["revive_progress"] = 0.0
	return out


static func validate_revive_time(value: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not (value is int or value is float) or not is_finite(value) or value < 0:
		errors.append("revive time must be a number of seconds at or above zero")
	return errors


## candidates: [{id, pos, taunt_radius, downed}]. Downed ones are never targeted.
## An enemy within a candidate's taunt radius (edge included) goes for the nearest
## such taunter; otherwise for the nearest candidate. Ties follow EnemyTargeting.
## "" when nothing is left (the caller then heads for the keep).
static func pick_target(enemy_pos: Vector2, candidates: Array, tie_order: Array) -> String:
	var live := []
	var taunters := []
	for candidate in candidates:
		if candidate["downed"]:
			continue
		live.append(candidate)
		var reach: float = candidate["taunt_radius"]
		if reach > 0.0 and enemy_pos.distance_squared_to(candidate["pos"]) <= reach * reach:
			taunters.append(candidate)
	return EnemyTargeting.pick(enemy_pos, live if taunters.is_empty() else taunters, tie_order)


## What a light post gets from the Recruits staffing it, in staff order:
## [{role, effect}], the effect a copy of role_effects[role]. Downed Recruits and
## roles the pack has no effect for add nothing.
static func post_effects(staff: Array, role_effects: Dictionary) -> Array:
	var effects := []
	for recruit in staff:
		var role: String = recruit["role"]
		if recruit["downed"] or not role_effects.has(role):
			continue
		effects.append({"role": role, "effect": role_effects[role].duplicate(true)})
	return effects


## Pack check: every role in `roles` has a non-empty dictionary of effects.
static func validate_effects(role_effects: Variant, roles: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	if not role_effects is Dictionary:
		errors.append("role effects must be a dictionary of roles")
		return errors
	for role in roles:
		var effect: Variant = role_effects.get(role)
		if not effect is Dictionary or effect.is_empty():
			errors.append("role %s needs a non-empty set of effects" % role)
	return errors
