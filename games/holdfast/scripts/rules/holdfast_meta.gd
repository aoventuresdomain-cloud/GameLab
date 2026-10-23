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
##   stars: {level: int}   the most stars each level has paid (1 to 3; a tutorial pays its reward)
##   levels_won: [ids],
##   unlocked: [ids],      levels opened beyond the first, by winning the one before
##   level: id,            the level the next run plays
##   pillar: id,           the Hero path the next run plays
##   runs: int,            runs banked
##   layouts: {level: [spot ids]}   the castle spots the player put Archer Posts on, per level
##   gear: {owned: [item ids], equipped: {slot: item id or ""}}   the Hero's gear (the Hero only)
## }
## The save format version is SAVE_VERSION; bump it with a migration when the shape changes.
## Version 2: levels open by winning the previous one (`unlocked`), no longer by buying a
## node; migrate_v1 turns a version 1 save's bought level nodes into `unlocked`.

## Version 3: the tree is split into sections (Flare Archer, Archer Post, Keep, Tithe) and
## the three Archer Post chains (drills, timbers, patch-up) became different nodes;
## migrate_v2 refunds the old ones at their price and keeps everything else.

## Version 4: stars and the castle. The player starts with an empty castle and buys slots and
## Archer Post cards with stars; migrate_v3 refunds every bought node in gold, grants the stars
## the won levels would have paid and resets the layouts.

## Version 5: one connected tree. Every node but the first needs another, the three capstones
## cost stars, and a respec costs a fee; migrate_v4 refunds every bought node in gold (the
## capstones at the gold they cost before), keeps the stars and resets the layouts.

const SAVE_VERSION := 5

## The most stars one level can pay; the pack's star tiers never go above it.
const MAX_LEVEL_STARS := 3
## The castle's own id in the pack's `castle_rules`.
const CASTLE := "castle"
## A respec takes a tenth of a gold node's price (at least the minimum) and a flat fee for a star node.
const RESPEC_FEE_SHARE := 0.1
const RESPEC_MIN_FEE := 20
const RESPEC_STAR_FEE := 50
## The capstones were bought with gold until version 5.
const V4_CAPSTONE_GOLD := {"flare_inferno": 2400, "post_piercing": 3000, "post_storm": 3000}

## The Archer Post nodes version 2 sold, which no longer exist: node id -> what it cost.
const V2_TOWER_COSTS := {
	"tower_drills_1": 110, "tower_drills_2": 450, "tower_drills_3": 900, "tower_drills_4": 1600, "tower_drills_5": 2600,
	"tower_stone_1": 70, "tower_stone_2": 260, "tower_stone_3": 700, "tower_stone_4": 1400,
	"tower_mend_1": 150, "tower_mend_2": 520, "tower_mend_3": 1200,
}

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
		"stars": {},
		"levels_won": [],
		"unlocked": [],
		"level": levels[0] if not levels.is_empty() else "",
		"pillar": paths[0] if not paths.is_empty() else "",
		"runs": 0,
		"layouts": {},
		"gear": {"owned": [], "equipped": HeroGear.new_unit("hero", gear_slots(content))["slots"]},
	}


## A saved value that should be a list or a whole number, or an empty one when it is neither (a damaged file).
static func _list(value: Variant) -> Array:
	return value if value is Array else []


static func _whole(value: Variant) -> int:
	return int(value) if value is int or value is float else 0


## A profile read from a save, made safe to use: missing fields get their
## defaults, and ids the content no longer has are dropped (a level or pillar
## falls back to the first, a locked level to the first unlocked one).
static func from_save(content: Dictionary, data: Dictionary) -> Dictionary:
	var profile := new_profile(content)
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var levels: Dictionary = content.get("levels", {})
	profile["gold"] = maxi(_whole(data.get("gold")), 0)
	profile["runs"] = maxi(_whole(data.get("runs")), 0)
	var saved_stars: Variant = data.get("stars", {})
	if saved_stars is Dictionary:
		for level in saved_stars:
			if levels.has(level) and (saved_stars[level] is int or saved_stars[level] is float):
				profile["stars"][level] = clampi(int(saved_stars[level]), 0, MAX_LEVEL_STARS)
	for id in _list(data.get("upgrades")):
		if nodes.has(id) and not id in profile["upgrades"] and _closed_by(nodes, profile["upgrades"], id) == "":
			# A save cannot hold more star nodes than the stars it has earned.
			if is_star_node(nodes[id]) and stars_spent(content, profile) + int(nodes[id]["cost"]) > stars_earned(profile):
				continue
			profile["upgrades"].append(id)
	for id in _list(data.get("levels_won")):
		if levels.has(id) and not id in profile["levels_won"]:
			profile["levels_won"].append(id)
	for id in _list(data.get("unlocked")):
		if levels.has(id) and not id in profile["unlocked"]:
			profile["unlocked"].append(id)
	var saved_layouts: Variant = data.get("layouts", {})
	if saved_layouts is Dictionary:
		for level in saved_layouts:
			if levels.has(level) and is_valid_layout(content, profile, saved_layouts[level]):
				profile["layouts"][level] = saved_layouts[level].duplicate()
	var saved_gear: Variant = data.get("gear", {})
	if saved_gear is Dictionary:
		var items: Dictionary = content.get("gear_items", {})
		for id in _list(saved_gear.get("owned")):
			if items.has(id) and not id in profile["gear"]["owned"]:
				profile["gear"]["owned"].append(id)
		var worn: Variant = saved_gear.get("equipped", {})
		if worn is Dictionary:
			for slot in profile["gear"]["equipped"]:
				var id: Variant = worn.get(slot, "")
				if id in profile["gear"]["owned"] and str(items[id]["slot"]) == slot:
					profile["gear"]["equipped"][slot] = id
	var unlocked := unlocked_levels(content, profile)
	if str(data.get("level", "")) in unlocked:
		profile["level"] = str(data["level"])
	if content.get("hero_paths", {}).has(str(data.get("pillar", ""))):
		profile["pillar"] = str(data["pillar"])
	return profile


## The gear slots the pack gives the Hero ([] when it has no gear).
static func gear_slots(content: Dictionary) -> Array:
	for rules in content.get("gear_rules", {}).values():
		return rules["slots"]
	return []


## The gear to wear in a run: {slot: item id}, empty slots left out.
static func worn_gear(profile: Dictionary) -> Dictionary:
	var out := {}
	for slot in profile["gear"]["equipped"]:
		if profile["gear"]["equipped"][slot] != "":
			out[slot] = profile["gear"]["equipped"][slot]
	return out


## Wears an owned item in its slot (the item it replaces stays owned), or takes it off when
## it is already worn. An item the profile does not own changes nothing.
static func toggle_gear(content: Dictionary, profile: Dictionary, id: String) -> Dictionary:
	var item: Dictionary = content.get("gear_items", {}).get(id, {})
	if item.is_empty() or not id in profile["gear"]["owned"] or not profile["gear"]["equipped"].has(item["slot"]):
		return profile
	var out := profile.duplicate(true)
	if profile["gear"]["equipped"][item["slot"]] == id:
		out["gear"]["equipped"][item["slot"]] = ""
		return out
	var unit := {"kind": "hero", "slots": profile["gear"]["equipped"]}
	out["gear"]["equipped"] = HeroGear.equip(unit, str(item["slot"]), id)["unit"]["slots"]
	return out


## Level ids the player can play, in pack order: the first level, and each level
## whose previous level has been won.
static func unlocked_levels(content: Dictionary, profile: Dictionary) -> Array:
	var out := []
	for id in content.get("levels", {}).keys():
		if out.is_empty() or id in profile["unlocked"]:
			out.append(id)
	return out


## A version 1 save as version 2. Each bought level node opens its level (once,
## however many times it is listed) and is removed from the upgrades, its gold
## refunded: the levels are kept, nothing is paid for twice. Each level the save
## has won also opens the next, as winning now does.
static func migrate_v1(data: Dictionary, content: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var unlocked := []
	var upgrades := []
	var gold := maxi(int(out.get("gold", 0)), 0)
	for id in out.get("upgrades", []):
		if not V1_LEVEL_NODES.has(id):
			upgrades.append(id)
		elif not V1_LEVEL_NODES[id][0] in unlocked:
			unlocked.append(V1_LEVEL_NODES[id][0])
			gold += int(V1_LEVEL_NODES[id][1])
	for won in out.get("levels_won", []):
		var next := next_level(content, str(won))
		if next != "" and not next in unlocked:
			unlocked.append(next)
	out["upgrades"] = upgrades
	out["unlocked"] = unlocked
	out["gold"] = gold
	return out


## A version 2 save as version 3: each upgrade it bought that the tree no longer has
## (once, whatever the list says) leaves the list and its price goes back to the gold;
## every other upgrade is kept, so nobody loses gold or progress to the new tree.
static func migrate_v2(data: Dictionary, _content: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var gold := maxi(_whole(out.get("gold")), 0)
	var kept := []
	var refunded := []
	for id in _list(out.get("upgrades")):
		if not V2_TOWER_COSTS.has(id):
			kept.append(id)
		elif not id in refunded:
			refunded.append(id)
			gold += int(V2_TOWER_COSTS[id])
	out["upgrades"] = kept
	out["gold"] = gold
	return out


## A version 3 save as version 4. Every bought node goes back to the gold at its pack
## price (the castle is empty now, so the tree is bought again from the start), each level
## it won pays 3 stars and the tutorial pays its own, and the layouts are reset to a first visit.
static func migrate_v3(data: Dictionary, content: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var levels: Dictionary = content.get("levels", {})
	var gold := maxi(_whole(out.get("gold")), 0)
	var refunded := []
	for id in _list(out.get("upgrades")):
		if nodes.has(id) and not id in refunded:
			refunded.append(id)
			gold += _refund_price(nodes, id)
	var stars := {}
	var won := _list(out.get("levels_won")).duplicate()
	for id in won:
		if levels.has(id) and not _tutorial(levels[id]):
			stars[id] = MAX_LEVEL_STARS
	var first := tutorial_level(content)
	if first != "":
		stars[first] = int(levels[first]["reward"]["stars"])
		if not first in won:
			won.append(first)
		var unlocked := _list(out.get("unlocked")).duplicate()
		var next := next_level(content, first)
		if next != "" and not next in unlocked:
			unlocked.append(next)
		out["unlocked"] = unlocked
	out["upgrades"] = []
	out["gold"] = gold
	out["stars"] = stars
	out["levels_won"] = won
	out["layouts"] = {}
	return out


## A version 4 save as version 5. Every bought node goes back to the gold it cost, the tree
## is bought again from the first slot, and the layouts are reset. Stars are kept: they are
## worked out from the levels won, and the star nodes are free again.
static func migrate_v4(data: Dictionary, content: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var gold := maxi(_whole(out.get("gold")), 0)
	var refunded := []
	for id in _list(out.get("upgrades")):
		if nodes.has(id) and not id in refunded:
			refunded.append(id)
			gold += _refund_price(nodes, id)
	out["upgrades"] = []
	out["gold"] = gold
	out["layouts"] = {}
	return out


## The gold a bought node goes back for in a migration: nothing for a star node (its stars are
## free again), its price for a gold node, and what the capstones cost before they took stars.
static func _refund_price(nodes: Dictionary, id: String) -> int:
	if V4_CAPSTONE_GOLD.has(id):
		return int(V4_CAPSTONE_GOLD[id])
	return 0 if is_star_node(nodes[id]) else int(nodes[id]["cost"])


static func _tutorial(level: Dictionary) -> bool:
	return bool(level.get("tutorial", false))


## The tutorial level's id (Level 0), or "" when the pack has none.
static func tutorial_level(content: Dictionary) -> String:
	for id in content.get("levels", {}):
		if _tutorial(content["levels"][id]):
			return str(id)
	return ""


## True for a node paid for with stars rather than gold.
static func is_star_node(node: Dictionary) -> bool:
	return str(node.get("currency", "gold")) == "stars"


## "90 gold", "1 star" or "3 stars": what a node costs, in words.
static func cost_text(node: Dictionary) -> String:
	var cost := int(node["cost"])
	if is_star_node(node):
		return "%d star%s" % [cost, "" if cost == 1 else "s"]
	return "%d gold" % cost


## Stars the player has earned in all: the most each level has paid, added up.
static func stars_earned(profile: Dictionary) -> int:
	var total := 0
	for level in profile["stars"]:
		total += int(profile["stars"][level])
	return total


## Stars tied up in the star nodes the player owns (a respec gives them back).
static func stars_spent(content: Dictionary, profile: Dictionary) -> int:
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var total := 0
	for id in profile["upgrades"]:
		if nodes.has(id) and is_star_node(nodes[id]):
			total += int(nodes[id]["cost"])
	return total


## Stars the player can spend now.
static func stars_available(content: Dictionary, profile: Dictionary) -> int:
	return stars_earned(profile) - stars_spent(content, profile)


## The stars a finished run pays on this visit: 0 unless it was won; a tutorial pays its
## reward; any other level pays the pack's highest tier the Keep's health left is above
## (a win alone is the first). It is the level's total; bank_run pays only what is new.
static func stars_for_run(content: Dictionary, result: Dictionary) -> int:
	var level: Dictionary = content.get("levels", {}).get(str(result.get("level", "")), {})
	if result.get("outcome") != HoldfastRules.OUTCOME_WON or level.is_empty():
		return 0
	if _tutorial(level):
		return int(level["reward"]["stars"])
	var left := float(result.get("keep_health", 0)) / float(result["keep_health_max"]) if float(result.get("keep_health_max", 0)) > 0.0 else 0.0
	var stars := 1
	for tier in castle_rules(content).get("star_tiers", []):
		if left > float(tier["above"]):
			stars = maxi(stars, int(tier["stars"]))
	return stars


## The castle's pack entry ({} when the pack has none).
static func castle_rules(content: Dictionary) -> Dictionary:
	return content.get("castle_rules", {}).get(CASTLE, {})


## Castle slots the player has bought, and Archer Post cards (what the Plan page lets them place).
static func castle_slots(content: Dictionary, profile: Dictionary) -> int:
	return _granted(content, profile, "slots")


static func castle_cards(content: Dictionary, profile: Dictionary) -> int:
	return mini(_granted(content, profile, "cards"), castle_slots(content, profile))


static func _granted(content: Dictionary, profile: Dictionary, what: String) -> int:
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var total := 0
	for id in profile["upgrades"]:
		total += int(nodes.get(id, {}).get("grants", {}).get(what, 0))
	return total


## The castle spots the player can use, in the pack's order (the first `slots` of the ring).
static func owned_spots(content: Dictionary, profile: Dictionary) -> Array:
	var spots: Array = castle_rules(content).get("spots", [])
	return spots.slice(0, castle_slots(content, profile))


## True when the player has what a first run needs: a slot and an Archer Post to put in it.
static func has_a_tower(content: Dictionary, profile: Dictionary) -> bool:
	return castle_cards(content, profile) >= 1


## The castle spots a layout may use: owned spot ids, no repeats, at least one and no more
## than the cards the player has.
static func is_valid_layout(content: Dictionary, profile: Dictionary, layout: Variant) -> bool:
	if not layout is Array or layout.is_empty() or layout.size() > castle_cards(content, profile):
		return false
	var known := []
	for spot in owned_spots(content, profile):
		known.append(str(spot["id"]))
	var seen := []
	for id in layout:
		if not id is String or not id in known or id in seen:
			return false
		seen.append(id)
	return true


## The spots a run on `level` builds on: the player's saved choice if it is still valid, else
## the spots nearest where the enemies come from. [] for a tutorial (it has its own post) and
## for a profile with no Archer Post yet.
static func layout_for(content: Dictionary, profile: Dictionary, level: String) -> Array:
	var data: Dictionary = content.get("levels", {}).get(level, {})
	if data.is_empty() or _tutorial(data) or not has_a_tower(content, profile):
		return []
	var saved: Variant = profile.get("layouts", {}).get(level)
	if saved != null and is_valid_layout(content, profile, saved):
		return saved.duplicate()
	return HoldfastRules.best_sites(owned_spots(content, profile), data.get("spawn_arcs", []), castle_cards(content, profile))


## True when the player has a valid layout of their own saved for `level` (not just the suggested one).
static func has_saved_layout(content: Dictionary, profile: Dictionary, level: String) -> bool:
	var data: Dictionary = content.get("levels", {}).get(level, {})
	return not data.is_empty() and not _tutorial(data) and profile.get("layouts", {}).has(level) and is_valid_layout(content, profile, profile["layouts"][level])


## The profile with `level`'s layout set; an invalid layout changes nothing.
static func set_layout(content: Dictionary, profile: Dictionary, level: String, layout: Array) -> Dictionary:
	var data: Dictionary = content.get("levels", {}).get(level, {})
	if data.is_empty() or _tutorial(data) or not is_valid_layout(content, profile, layout):
		return profile
	var out := profile.duplicate(true)
	out["layouts"][level] = layout.duplicate()
	return out


## The level after `id` in pack order, or "" for the last level or an unknown one.
static func next_level(content: Dictionary, id: String) -> String:
	var ids: Array = content.get("levels", {}).keys()
	var at := ids.find(id)
	return str(ids[at + 1]) if at >= 0 and at + 1 < ids.size() else ""


## "" when `id` can be bought now, else why not.
static func why_not_buy(content: Dictionary, profile: Dictionary, id: String) -> String:
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	if not nodes.has(id):
		return "No such upgrade"
	if id in profile["upgrades"]:
		return "Already bought"
	if nodes[id].has("hero") and str(nodes[id]["hero"]) != str(profile["pillar"]):
		return "Belongs to another Hero"
	for required in nodes[id].get("requires", []):
		if not required in profile["upgrades"]:
			return "Needs %s first" % str(nodes.get(required, {}).get("name", required))
	var closed := _closed_by(nodes, profile["upgrades"], id)
	if closed != "":
		return "Closed by %s" % str(nodes.get(closed, {}).get("name", closed))
	if is_star_node(nodes[id]):
		if stars_available(content, profile) < int(nodes[id]["cost"]):
			return "Not enough stars"
	elif int(profile["gold"]) < int(nodes[id]["cost"]):
		return "Not enough gold"
	return ""


## True when every node `id` requires is bought and nothing bought closes it: one buy
## away, whether or not the gold is there. A node belonging to a Hero other than the
## one the profile plays is never near.
static func is_near(content: Dictionary, profile: Dictionary, id: String) -> bool:
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	if not nodes.has(id) or id in profile["upgrades"] or _closed_by(nodes, profile["upgrades"], id) != "":
		return false
	if nodes[id].has("hero") and str(nodes[id]["hero"]) != str(profile["pillar"]):
		return false
	for required in nodes[id].get("requires", []):
		if not required in profile["upgrades"]:
			return false
	return true


## True when the tree shows the node: the first one, any node next to one the player owns (it
## needs it), and every bought one. A node of another Hero's path is never shown.
static func is_visible(content: Dictionary, profile: Dictionary, id: String) -> bool:
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	if not nodes.has(id):
		return false
	if nodes[id].has("hero") and str(nodes[id]["hero"]) != str(profile["pillar"]):
		return false
	if id in profile["upgrades"]:
		return true
	var needs: Array = nodes[id].get("requires", [])
	if needs.is_empty():
		return true
	for required in needs:
		if required in profile["upgrades"]:
			return true
	return false


## The next gold upgrades to show: up to `limit` near nodes, cheapest first (ties by id).
## Star nodes are left out: their price is not comparable with gold, and the map guides
## the first of them.
static func next_unlocks(content: Dictionary, profile: Dictionary, limit := 2) -> Array:
	var near := []
	for id in content.get("upgrade_nodes", {}):
		if is_near(content, profile, id) and not is_star_node(content["upgrade_nodes"][id]):
			near.append(id)
	var nodes: Dictionary = content["upgrade_nodes"] if content.has("upgrade_nodes") else {}
	near.sort_custom(func(a: String, b: String) -> bool:
		var ca := int(nodes[a]["cost"])
		var cb := int(nodes[b]["cost"])
		return ca < cb or (ca == cb and a < b))
	return near.slice(0, limit)


## The bought node that rules `id` out (either lists the other in `excludes`), or "".
static func _closed_by(nodes: Dictionary, bought: Array, id: String) -> String:
	for other in bought:
		if other in nodes.get(id, {}).get("excludes", []) or id in nodes.get(other, {}).get("excludes", []):
			return str(other)
	return ""


## What taking one bought node back costs, in gold: a tenth of a gold node's price (at least
## RESPEC_MIN_FEE), a flat RESPEC_STAR_FEE for a star node (its stars come back in full).
static func respec_fee(node: Dictionary) -> int:
	if is_star_node(node):
		return RESPEC_STAR_FEE
	return maxi(RESPEC_MIN_FEE, int(round(float(node.get("cost", 0)) * RESPEC_FEE_SHARE)))


## The gold a respec changes the purse by: each gold node's price less its fee, less the fee of
## each star node. Negative when the fees are more than the refunds.
static func respec_gold_change(content: Dictionary, profile: Dictionary) -> int:
	var nodes: Dictionary = content.get("upgrade_nodes", {})
	var change := 0
	for id in profile["upgrades"]:
		if not nodes.has(id):
			continue
		change -= respec_fee(nodes[id])
		if not is_star_node(nodes[id]):
			change += int(nodes[id]["cost"])
	return change


## "" when a respec can go ahead, else why not.
static func why_not_respec(content: Dictionary, profile: Dictionary) -> String:
	if profile["upgrades"].is_empty():
		return "Nothing to respec"
	if int(profile["gold"]) + respec_gold_change(content, profile) < 0:
		return "Not enough gold for the respec fee"
	return ""


## The profile with every upgrade taken back and the tree empty, so the choices can be made
## again: each gold node's price comes back less its fee, a star node costs its fee in gold and
## frees its stars. Unchanged when `why_not_respec` says no.
static func respec(content: Dictionary, profile: Dictionary) -> Dictionary:
	if why_not_respec(content, profile) != "":
		return profile
	var out := profile.duplicate(true)
	out["gold"] = int(out["gold"]) + respec_gold_change(content, profile)
	out["upgrades"] = []
	return out


## {ok, profile, reason}: the profile with the upgrade bought and its cost paid,
## or the same profile and the reason it was refused.
static func buy(content: Dictionary, profile: Dictionary, id: String) -> Dictionary:
	var reason := why_not_buy(content, profile, id)
	if reason != "":
		return {"ok": false, "profile": profile, "reason": reason}
	var out := profile.duplicate(true)
	if not is_star_node(content["upgrade_nodes"][id]):
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
## the level as won, the next level in pack order as unlocked, the stars it pays that the
## level has not paid before and, on the first win of a tutorial, its reward gold.
static func bank_run(content: Dictionary, profile: Dictionary, result: Dictionary) -> Dictionary:
	var out := profile.duplicate(true)
	out["gold"] = int(out["gold"]) + maxi(int(result.get("gold", 0)), 0)
	out["runs"] = int(out["runs"]) + 1
	var level := str(result.get("level", ""))
	var first_win: bool = result.get("outcome") == HoldfastRules.OUTCOME_WON and level != "" and not level in out["levels_won"]
	if first_win:
		out["levels_won"].append(level)
		out["gold"] = int(out["gold"]) + int(content.get("levels", {}).get(level, {}).get("reward", {}).get("gold", 0))
	var stars := stars_for_run(content, result)
	if stars > int(out["stars"].get(level, 0)):
		out["stars"][level] = stars
	# Gear a run found is kept whatever its outcome, and worn at once when its slot is free.
	for id in result.get("gear_found", []):
		var item: Dictionary = content.get("gear_items", {}).get(id, {})
		if item.is_empty() or id in out["gear"]["owned"]:
			continue
		out["gear"]["owned"].append(id)
		if out["gear"]["equipped"].get(item["slot"], "x") == "":
			out["gear"]["equipped"] = HeroGear.equip({"kind": "hero", "slots": out["gear"]["equipped"]}, str(item["slot"]), id)["unit"]["slots"]
	var next := next_level(content, level) if result.get("outcome") == HoldfastRules.OUTCOME_WON else ""
	if next != "" and not next in out["unlocked"]:
		out["unlocked"].append(next)
	return out
