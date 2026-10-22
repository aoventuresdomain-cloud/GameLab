class_name EnemyTargeting
extends RefCounted
## Which tower, Recruit or Hero an enemy walks to. Plain data in, an id out.


## The candidates an enemy may go for. A candidate with "always" (the tower) is
## always open to it. Any other is open only while it is within `engage` of the
## enemy (centre to centre, edge included) or within its own "taunt_radius"; an
## `engage` of 0 means never. So an enemy heads for the tower and fights the Hero
## or a Recruit only up close, and drops them again once they are out of range.
static func within_reach(enemy_pos: Vector2, candidates: Array, engage: float) -> Array:
	var out := []
	for candidate in candidates:
		var dist_sq := enemy_pos.distance_squared_to(candidate["pos"])
		var taunt: float = candidate["taunt_radius"]
		if candidate.get("always", false) \
				or (engage > 0.0 and dist_sq <= engage * engage) \
				or (taunt > 0.0 and dist_sq <= taunt * taunt):
			out.append(candidate)
	return out


## candidates: [{"id": String, "pos": Vector2}]. The nearest by straight-line
## distance wins. An exact tie goes to the id that comes first in tie_order, ids
## missing from tie_order lose to listed ones, and a tie that is still a tie goes
## to the smaller id, so the answer never depends on array order. No candidates
## gives "" (the enemy then heads for the keep).
static func pick(enemy_pos: Vector2, candidates: Array, tie_order: Array) -> String:
	var best_id := ""
	var best_dist := INF
	var best_rank := 0
	var found := false
	for candidate in candidates:
		var id: String = candidate["id"]
		var dist := enemy_pos.distance_squared_to(candidate["pos"])
		var rank := tie_order.find(id)
		if rank < 0:
			rank = tie_order.size()
		if not found or dist < best_dist or (dist == best_dist and (rank < best_rank or (rank == best_rank and id < best_id))):
			best_id = id
			best_dist = dist
			best_rank = rank
			found = true
	return best_id
