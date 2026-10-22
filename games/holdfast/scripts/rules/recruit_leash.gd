class_name RecruitLeash
extends RefCounted
## Where a Recruit goes in one step. A Recruit is plain data:
## {role, home, pos, leash, speed, range, health, max_health, retreat_below,
## downed, staffing}. `step` returns a new Recruit with `pos` moved and `mode` set
## to "hold", "engage", "retreat" or "down"; the one passed in is not changed.
##
## A downed Recruit stays where it fell. One staffing a post walks to it if away and
## stays. A hurt one (health strictly below `retreat_below` of the maximum) walks home,
## and so does one with no enemy within the leash of home. Otherwise it walks at the
## enemy nearest to itself among those within the leash of home (edge included),
## stopping at its attack range, and never ends a step beyond the leash.


## Pack check: leash, speed and range are numbers at or above zero; `retreat_below`
## is a fraction from 0 to 1.
static func validate(leash: Variant, speed: Variant, range_: Variant, retreat_below: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _is_number(leash) or leash < 0:
		errors.append("leash must be a number of pixels at or above zero")
	if not _is_number(speed) or speed < 0:
		errors.append("move speed must be a number at or above zero")
	if not _is_number(range_) or range_ < 0:
		errors.append("attack range must be a number at or above zero")
	if not _is_number(retreat_below) or retreat_below < 0 or retreat_below > 1:
		errors.append("retreat_below must be a fraction from 0 to 1")
	return errors


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value)


## `enemies` are positions.
static func step(r: Dictionary, enemies: Array, dt: float) -> Dictionary:
	var out := r.duplicate()
	var pos: Vector2 = r["pos"]
	var home: Vector2 = r["home"]
	if r["downed"]:
		out["mode"] = "down"
		return out
	var reach := maxf(dt, 0.0) * float(r["speed"])
	var aim := home
	var stop_short := 0.0
	var mode := "retreat"
	if not r["staffing"] and not _hurt(r):
		var goal: Variant = _nearest_in_leash(pos, home, float(r["leash"]), enemies)
		if goal != null:
			aim = goal
			stop_short = float(r["range"])
			mode = "engage"
	if mode == "retreat" and pos == home:
		mode = "hold"
	var to_aim := aim - pos
	var dist := to_aim.length()
	var travel := minf(reach, maxf(dist - stop_short, 0.0))
	var next := pos
	if dist > 0.0:
		next = aim if travel >= dist else pos + to_aim / dist * travel
	out["pos"] = home + (next - home).limit_length(float(r["leash"]))
	out["mode"] = mode
	return out


static func _hurt(r: Dictionary) -> bool:
	return float(r["max_health"]) > 0.0 and float(r["health"]) / float(r["max_health"]) < float(r["retreat_below"])


static func _nearest_in_leash(pos: Vector2, home: Vector2, leash: float, enemies: Array) -> Variant:
	var best: Variant = null
	var best_dist := INF
	var limit := leash * leash
	for at: Vector2 in enemies:
		if at.distance_squared_to(home) > limit:
			continue
		var dist := at.distance_squared_to(pos)
		if dist < best_dist:
			best = at
			best_dist = dist
	return best
