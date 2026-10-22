class_name LitArea
extends RefCounted
## Light posts light a small area; enemies inside it take extra damage.


## True when `pos` is within `radius` (inclusive) of any post.
static func is_lit(pos: Vector2, posts: Array, radius: float) -> bool:
	var limit := radius * radius
	for post in posts:
		if pos.distance_squared_to(post) <= limit:
			return true
	return false


## base * (1 + bonus) when the enemy is lit, else base. Several posts never stack.
static func damage_for(base: float, enemy_pos: Vector2, posts: Array, radius: float, bonus: float) -> float:
	return base * (1.0 + bonus) if is_lit(enemy_pos, posts, radius) else base


## Pack check: radius and bonus are finite numbers at or above zero.
static func validate(radius: Variant, bonus: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	for entry in [["radius", radius], ["bonus", bonus]]:
		var value: Variant = entry[1]
		if not (value is int or value is float) or not is_finite(value) or value < 0:
			errors.append("light %s must be a number at or above zero" % entry[0])
	return errors
