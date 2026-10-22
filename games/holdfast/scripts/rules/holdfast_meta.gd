class_name HoldfastMeta
extends RefCounted
## The player's progress between runs, as plain data, and the only ways it changes:
## buy an upgrade, pick a level or a Hero pillar, bank a finished run. Every
## function returns a new profile (or a result holding one) and leaves the one
## it was given alone. Screens ask for these actions; none writes the profile.
##
## profile: {
##   gold: int,            banked gold, spent on upgrades
##   upgrades: [ids],      bought upgrade nodes, in the order bought
##   levels_won: [ids],
##   unlocked: [ids],      levels opened beyond the first, by winning the one before
##   level: id,            the level the next run plays
##   pillar: id,           the Hero path the next run plays
##   runs: int,            runs banked
## }
## The save format version is SAVE_VERSION; bump it with a migration when the shape changes.
## Version 2: levels open by winning the previous one (`unlocked`), no longer by buying a
## node; migrate_v1 turns a version 1 save's bought level nodes into `unlocked`.

const SAVE_VERSION := 2

## The level-unlock nodes version 1 sold: node id -> [level it opened, what it cost].
const V1_LEVEL_NODES := {
	"unlock_shingle_beach": ["shingle_beach", 120],
	"unlock_tidewrack_cove": ["tidewrack_cove", 500],
	"unlock_old_pier": ["old_pier", 1400],
	"unlock_gull_rock": ["gull_rock", 3000],
}


static func new_profile(content: Dictionary) -> Dictionary:
	var paths: Array = content.get("hero_paths", {}).keys()
	var levels: Array = content.get("levels", {}).keys()
	return {
		"gold": 0,
		"upgrades": [],
		"levels_won": [],
		"unlocked": [],
		"level": levels[0] if not levels.is_empty() else "",
		"pillar": paths[0] if not paths.is_empty() else "",
		"runs": 0,
	}


## A profile read from a save, made safe to use: missing fields get their
## defaults, and ids the content no longer has are dropped (a level or pillar
## falls back to the first, a locked level to the first unlocked one).
static func from_save(content: Dictionary, data: Dictionary) -> Dictionary:
	var profile := new_profile(content)
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	profile["gold"] = maxi(int(data.get("gold", 0)), 0)
	profile["runs"] = maxi(int(data.get("runs", 0)), 0)
	for id in data.get("upgrades", []):
		if nodes.has(id) and not id in profile["upgrades"]:
			profile["upgrades"].append(id)
	for id in data.get("levels_won", []):
		if content.get("levels", {}).has(id) and not id in profile["levels_won"]:
			profile["levels_won"].append(id)
	for id in data.get("unlocked", []):
		if content.get("levels", {}).has(id) and not id in profile["unlocked"]:
			profile["unlocked"].append(id)
	var unlocked := unlocked_levels(content, profile)
	if str(data.get("level", "")) in unlocked:
		profile["level"] = str(data["level"])
	if content.get("hero_paths", {}).has(str(data.get("pillar", ""))):
		profile["pillar"] = str(data["pillar"])
	return profile


## Level ids the player can play, in pack order: the first level, and each level
## whose previous level has been won.
static func unlocked_levels(content: Dictionary, profile: Dictionary) -> Array:
	var out := []
	for id in content.get("levels", {}).keys():
		if out.is_empty() or id in profile["unlocked"]:
			out.append(id)
	return out


## A version 1 save as version 2. Each bought level node opens its level and is
## removed from the upgrades, its gold refunded: the levels are kept, nothing
## is paid for twice.
static func migrate_v1(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var unlocked := []
	var upgrades := []
	var gold := maxi(int(out.get("gold", 0)), 0)
	for id in out.get("upgrades", []):
		if V1_LEVEL_NODES.has(id):
			unlocked.append(V1_LEVEL_NODES[id][0])
			gold += int(V1_LEVEL_NODES[id][1])
		else:
			upgrades.append(id)
	out["upgrades"] = upgrades
	out["unlocked"] = unlocked
	out["gold"] = gold
	return out


## "" when `id` can be bought now, else why not.
static func why_not_buy(content: Dictionary, profile: Dictionary, id: String) -> String:
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	if not nodes.has(id):
		return "No such upgrade"
	if id in profile["upgrades"]:
		return "Already bought"
	for required in nodes[id].get("requires", []):
		if not required in profile["upgrades"]:
			return "Needs %s first" % str(nodes.get(required, {}).get("name", required))
	if int(profile["gold"]) < int(nodes[id]["cost"]):
		return "Not enough gold"
	return ""


## {ok, profile, reason}: the profile with the upgrade bought and its cost paid,
## or the same profile and the reason it was refused.
static func buy(content: Dictionary, profile: Dictionary, id: String) -> Dictionary:
	var reason := why_not_buy(content, profile, id)
	if reason != "":
		return {"ok": false, "profile": profile, "reason": reason}
	var out := profile.duplicate(true)
	out["gold"] = int(out["gold"]) - int(content["upgrade_nodes"][id]["cost"])
	out["upgrades"].append(id)
	return {"ok": true, "profile": out, "reason": ""}


## A locked or unknown level changes nothing.
static func select_level(content: Dictionary, profile: Dictionary, id: String) -> Dictionary:
	if not id in unlocked_levels(content, profile):
		return profile
	var out := profile.duplicate(true)
	out["level"] = id
	return out


## An unknown pillar changes nothing.
static func select_pillar(content: Dictionary, profile: Dictionary, id: String) -> Dictionary:
	if not content.get("hero_paths", {}).has(id):
		return profile
	var out := profile.duplicate(true)
	out["pillar"] = id
	return out


## Banks a finished run's result (HoldfastRules.result()): its gold, and on a win
## the level as won and the next level in pack order as unlocked.
static func bank_run(content: Dictionary, profile: Dictionary, result: Dictionary) -> Dictionary:
	var out := profile.duplicate(true)
	out["gold"] = int(out["gold"]) + maxi(int(result.get("gold", 0)), 0)
	out["runs"] = int(out["runs"]) + 1
	var level := str(result.get("level", ""))
	if result.get("outcome") == HoldfastRules.OUTCOME_WON and level != "" and not level in out["levels_won"]:
		out["levels_won"].append(level)
	if result.get("outcome") == HoldfastRules.OUTCOME_WON:
		var ids: Array = content.get("levels", {}).keys()
		var at := ids.find(level)
		if at >= 0 and at + 1 < ids.size() and not ids[at + 1] in out["unlocked"]:
			out["unlocked"].append(ids[at + 1])
	return out
