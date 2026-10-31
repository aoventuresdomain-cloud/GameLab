class_name HoldfastAchievements
extends RefCounted
## HF-M2-66: achievements. The pack lists them (`content/base/achievements.json`): each names a counter
## and a goal. Every counter is read from the profile, so an achievement fires from the same events that
## change the profile (a win, a purchase, a hire, a piece of gear worn) and the list can show progress.
## Unlocks are kept in the profile (`achievements`). A Steam name rides along in the data for the
## Steam hooks to use when Steam is present.


## What `counter` reads from the profile now.
static func counter(content: Dictionary, profile: Dictionary, kind: String) -> int:
	var levels: Dictionary = content.get("levels", {})
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	match kind:
		"levels_cleared":
			return _won(levels, profile).size()
		"bosses_beaten":
			return _won(levels, profile).filter(func(id: String) -> bool: return HoldfastProgression.has_boss(content, id)).size()
		"clean_wins":
			return int(profile.get("counters", {}).get("clean_wins", 0))
		"best_stars":
			var best := 0
			for id in _real(levels, profile["stars"].keys()):
				best = maxi(best, int(profile["stars"][id]))
			return best
		"level_stars":
			var total := 0
			for id in _real(levels, profile["stars"].keys()):
				total += int(profile["stars"][id])
			return total
		"node_kinds":
			var kinds := {}
			for id in profile["upgrades"]:
				if nodes.has(id):
					kinds["star" if HoldfastMeta.is_star_node(nodes[id]) else "hero" if nodes[id].has("hero") else "gold"] = true
			return kinds.size()
		"nodes_owned":
			return profile["upgrades"].size()
		"recruits_hired":
			return profile["recruits"]["roster"].size()
		"gear_worn":
			return profile["gear"]["equipped"].values().filter(func(id: Variant) -> bool: return str(id) != "").size()
		"gear_owned":
			return profile["gear"]["owned"].size()
		"runs":
			return int(profile["runs"])
	return 0


## Every achievement with its progress, in the pack's order: {id, name, text, value (capped at the goal),
## goal, done}.
static func progress(content: Dictionary, profile: Dictionary) -> Array:
	var out := []
	for id in content.get("achievements", {}):
		var entry: Dictionary = content["achievements"][id]
		var goal := int(entry["goal"])
		var value := counter(content, profile, str(entry["counter"]))
		out.append({"id": id, "name": entry["name"], "text": entry["text"], "value": mini(value, goal), "goal": goal, "done": id in profile.get("achievements", []) or value >= goal})
	return out


## The profile with every achievement whose goal is now met added to its unlocks (in the pack's order);
## the profile as it was when nothing is new.
static func unlock(content: Dictionary, profile: Dictionary) -> Dictionary:
	var fresh := newly_met(content, profile)
	if fresh.is_empty():
		return profile
	var out := profile.duplicate(true)
	out["achievements"] = profile.get("achievements", []) + fresh
	return out


## The ids whose goal is met and that the profile has not unlocked yet.
static func newly_met(content: Dictionary, profile: Dictionary) -> Array:
	var out := []
	for id in content.get("achievements", {}):
		var entry: Dictionary = content["achievements"][id]
		if not id in profile.get("achievements", []) and counter(content, profile, str(entry["counter"])) >= int(entry["goal"]):
			out.append(id)
	return out


## The Steam achievement name for `id` ("" when there is none).
static func steam_name(content: Dictionary, id: String) -> String:
	return str(content.get("achievements", {}).get(id, {}).get("steam", ""))


## The levels past the tutorial that the profile has won.
static func _won(levels: Dictionary, profile: Dictionary) -> Array:
	return _real(levels, profile["levels_won"])


static func _real(levels: Dictionary, ids: Array) -> Array:
	return ids.filter(func(id: Variant) -> bool: return levels.has(id) and not bool(levels[id].get("tutorial", false)))
