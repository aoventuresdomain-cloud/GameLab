class_name HoldfastHeroBot
extends SimController
## Bot Hero for headless runs, the same input the keyboard produces. It keeps
## the enemy nearest to it at about three quarters of the attack range (walking
## towards it when it is further, away when it is closer) and presses the
## ability when enough enemies are within the ability's reach.

const KITE_FRACTION := 0.75
## Distance either side of the kiting distance where the bot stands still, so
## it doesn't shuffle back and forth.
const HOLD_BAND := 15.0
const ABILITY_MIN_ENEMIES := 3


func get_input(rules: SimRules, _tick: int) -> Dictionary:
	var run := rules as HoldfastRules
	var nearest: HoldfastRules.Enemy = null
	var nearest_dist := INF
	var in_ability_reach := 0
	var ability_range := float(run.hero_ability["range"])
	for enemy in run.enemies:
		if enemy.health <= 0.0:
			continue
		var dist := enemy.position.distance_to(run.hero_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
		if dist <= ability_range:
			in_ability_reach += 1
	var move := Vector2.ZERO
	if nearest != null:
		var want := float(run.hero_attack["range"]) * KITE_FRACTION
		var towards := (nearest.position - run.hero_position).normalized()
		if nearest_dist > want + HOLD_BAND:
			move = towards
		elif nearest_dist < want - HOLD_BAND:
			move = -towards
	return {"move": [move.x, move.y], "ability": in_ability_reach >= ABILITY_MIN_ENEMIES}
