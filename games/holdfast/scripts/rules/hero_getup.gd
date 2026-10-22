class_name HeroGetUp
extends RefCounted
## Where a knocked-down Hero falls and gets back up, and the short time they cannot
## be hurt afterwards. The wait itself is HeroKnockdown's. Pure statics on plain data.


## The fall: where the Hero went down, and the unbanked XP dropped on that spot.
static func start_fall(hero_pos: Vector2, unbanked_xp: int) -> Dictionary:
	return {"fell_at": hero_pos, "drop_pos": hero_pos, "drop_amount": maxi(unbanked_xp, 0)}


## Where the Hero rises: `fell_at` when that is open ground inside `playfield`, else
## the nearest open point inside it. Every playfield edge counts as inside; only the
## interior of a blocked Rect2 is blocked. `grace_left` starts at `grace_time`.
static func rise(fell_at: Vector2, playfield: Rect2, blocked: Array, grace_time: float) -> Dictionary:
	var field := playfield.abs()
	var rects: Array[Rect2] = []
	for area: Rect2 in blocked:
		var rect := area.abs()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			rects.append(rect)
	var pos := field.get_center()
	if is_finite(fell_at.x) and is_finite(fell_at.y):
		pos = _nearest_open(fell_at, field, rects)
	return {"pos": pos, "grace_left": grace_time}


## Counts the grace down, never below zero. A dt of zero or less changes nothing.
static func tick_grace(grace_left: float, dt: float) -> float:
	if not dt > 0.0:
		return grace_left
	return maxf(grace_left - dt, 0.0)


## A hit while any grace is left does nothing (and is not remembered); at zero it is
## HeroKnockdown's.
static func take_damage(state: Dictionary, damage: float, delays: Array, grace_left: float) -> Dictionary:
	if grace_left > 0.0:
		return state.duplicate()
	return HeroKnockdown.take_damage(state, damage, delays)


## Pack check: the grace is a finite number, zero or more.
static func validate_grace(v: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not (v is int or v is float):
		errors.append("untouchable_seconds must be a number")
	elif not is_finite(v):
		errors.append("untouchable_seconds must be a finite number")
	elif v < 0:
		errors.append("untouchable_seconds must be zero or more")
	return errors


static func _nearest_open(fell_at: Vector2, field: Rect2, rects: Array[Rect2]) -> Vector2:
	var inside := _clamp(fell_at, field)
	if _is_open(inside, rects):
		return inside
	# The nearest open point of a field with rectangular holes is on a hole's edge: where
	# fell_at projects onto it, at an end of it, or where two edges cross.
	var segments: Array = []
	for rect in rects:
		var left := rect.position.x
		var right := rect.end.x
		var top := rect.position.y
		var bottom := rect.end.y
		segments.append([Vector2(left, top), Vector2(right, top)])
		segments.append([Vector2(left, bottom), Vector2(right, bottom)])
		segments.append([Vector2(left, top), Vector2(left, bottom)])
		segments.append([Vector2(right, top), Vector2(right, bottom)])
	var candidates: Array[Vector2] = []
	for segment: Array in segments:
		var a: Vector2 = _clamp(segment[0], field)
		var b: Vector2 = _clamp(segment[1], field)
		candidates.append(a)
		candidates.append(b)
		candidates.append(_clamp(Geometry2D.get_closest_point_to_segment(fell_at, a, b), field))
		for other: Array in segments:
			var crossing := _cross(segment, other)
			if crossing.is_finite() and field.has_point(crossing):
				candidates.append(crossing)
	var best := inside
	var best_dist := INF
	for point in candidates:
		if not _is_open(point, rects):
			continue
		var dist := point.distance_squared_to(fell_at)
		if dist < best_dist:
			best = point
			best_dist = dist
	return best


static func _clamp(point: Vector2, field: Rect2) -> Vector2:
	return Vector2(clampf(point.x, field.position.x, field.end.x), clampf(point.y, field.position.y, field.end.y))


static func _is_open(point: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if point.x > rect.position.x and point.x < rect.end.x and point.y > rect.position.y and point.y < rect.end.y:
			return false
	return true


## Where a horizontal segment crosses a vertical one, else a point that is not finite.
static func _cross(a: Array, b: Array) -> Vector2:
	var horizontal: Array = a
	var vertical: Array = b
	if a[0].y != a[1].y:
		horizontal = b
		vertical = a
	if horizontal[0].y != horizontal[1].y or vertical[0].x != vertical[1].x:
		return Vector2(INF, INF)
	var x: float = vertical[0].x
	var y: float = horizontal[0].y
	if x < minf(horizontal[0].x, horizontal[1].x) or x > maxf(horizontal[0].x, horizontal[1].x):
		return Vector2(INF, INF)
	if y < minf(vertical[0].y, vertical[1].y) or y > maxf(vertical[0].y, vertical[1].y):
		return Vector2(INF, INF)
	return Vector2(x, y)
