class_name HoldfastAuraBot
extends SimController
## Bot model of the player's mouse aura. It moves a virtual cursor, no faster
## than the level's cursor speed, towards the enemy nearest the keep, and sends
## that position as the tick's aura input: the same input the player's mouse
## produces, so the rules apply the same damage either way.

var cursor := Vector2.ZERO


func get_input(rules: SimRules, _tick: int) -> Dictionary:
	var run := rules as HoldfastRules
	var target := cursor
	var best := INF
	for enemy in run.enemies:
		var to_keep := enemy.position.length()
		if to_keep < best:
			best = to_keep
			target = enemy.position
	var max_move := run.cursor_speed * dt
	cursor = cursor.move_toward(target, max_move)
	return {"aura": [cursor.x, cursor.y]}
