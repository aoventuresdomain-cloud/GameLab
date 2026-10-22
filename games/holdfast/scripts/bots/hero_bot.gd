class_name HoldfastHeroBot
extends SimController
## Bot Hero for headless runs, the same input the keyboard produces. It keeps
## the enemy nearest to it at about three quarters of the attack range (walking
## towards it when it is further, away when it is closer) and presses the
## ability when enough enemies are within the ability's reach. When a Recruit is
## down and no enemy is close to them, it walks over and stands on them.

const KITE_FRACTION := 0.75
## Distance either side of the kiting distance where the bot stands still, so
## it doesn't shuffle back and forth.
const HOLD_BAND := 15.0
const ABILITY_MIN_ENEMIES := 3
## A downed Recruit is only worth a trip when no enemy is within this of them.
const REVIVE_CLEARANCE := 100.0


func get_input(rules: SimRules, _tick: int) -> Dictionary:
	var run := rules as HoldfastRules
	if run.hero_state["downed"]:
		return {}
	var nearest: HoldfastRules.Enemy = null
	var nearest_dist := INF
	var in_ability_reach := 0
	var ability_reach := _reach(run.hero_ability)
	for enemy in run.enemies:
		if enemy.health <= 0.0:
			continue
		var dist := enemy.position.distance_to(run.hero_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
		if dist <= ability_reach:
			in_ability_reach += 1
	var move := Vector2.ZERO
	var downed := _downed_recruit_to_help(run)
	if downed != null:
		move = (downed.position - run.hero_position).normalized() if run.hero_position.distance_to(downed.position) > 2.0 else Vector2.ZERO
	elif nearest != null:
		var want := float(run.hero_attack["range"]) * KITE_FRACTION
		var towards := (nearest.position - run.hero_position).normalized()
		if nearest_dist > want + HOLD_BAND:
			move = towards
		elif nearest_dist < want - HOLD_BAND:
			move = -towards
	return {"move": [move.x, move.y], "ability": in_ability_reach >= ABILITY_MIN_ENEMIES}


## How far from the Hero an ability reaches: its range, or its radius when it
## bursts round the Hero, plus the dash.
static func _reach(action: Dictionary) -> float:
	if str(action["kind"]) == "area" and str(action.get("centre", "")) == "hero":
		return float(action["radius"])
	return float(action["range"]) + float(action.get("dash_distance", 0.0))


## The nearest downed Recruit with no enemy close to them, or null.
static func _downed_recruit_to_help(run: HoldfastRules) -> HoldfastRules.Attacker:
	var best: HoldfastRules.Attacker = null
	var best_dist := INF
	for recruit in run.recruits:
		if recruit.up:
			continue
		var clear := true
		for enemy in run.enemies:
			if enemy.health > 0.0 and enemy.position.distance_to(recruit.position) < REVIVE_CLEARANCE:
				clear = false
				break
		var dist := run.hero_position.distance_to(recruit.position)
		if clear and dist < best_dist:
			best = recruit
			best_dist = dist
	return best
