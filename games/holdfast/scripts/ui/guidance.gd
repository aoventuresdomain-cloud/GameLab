extends RefCounted
## What the screens tell the player to do next: the line on the Journey map, and the notes on the
## run summary (the boss beaten, what a win opened, the way on, a tip after a loss). Pure reads of the
## pack and the profile, so each case can be tested without a screen.

const Hud = preload("res://scripts/ui/hud.gd")
const MORE_COMING := "You have cleared every level there is. More are coming."
const STAND_LINE := "Your post is up. Try it out."
const GUIDE_NOTE := "Next: spend your stars in the Skill tree on a castle slot and an Archer Post. Then you can take on the next level."
const FALLBACK_TIP := "Try the posts on other spots, or send the Hero to where the monsters come in."


## The line the Journey map shows when nothing is hovered, in the order the player can act on it: an
## upgrade nearly affordable, the next level, the next boss ("" while the guide has the player's
## attention, or before there is anything to say). Past the last level it says more is coming.
static func next_goal(content: Dictionary, profile: Node) -> String:
	if profile.get_guided_step() != "" or profile.is_stand_due():
		return ""
	var levels: Dictionary = content["levels"]
	var next := ""
	var boss_level := ""
	for id in levels:
		if levels[id].get("tutorial", false) or profile.is_level_won(id):
			continue
		if next == "" and id in profile.get_unlocked_levels():
			next = id
		if boss_name(content, id) != "":
			boss_level = id
			break
	if next == "":
		return MORE_COMING if _last_won(content, profile) else ""
	var parts := PackedStringArray()
	var upgrade := _nearly_affordable(content, profile)
	if upgrade != "":
		parts.append(upgrade)
	if next == boss_level:
		parts.append("%s, where %s waits" % [levels[next]["name"], boss_name(content, next)])
	else:
		parts.append(str(levels[next]["name"]))
		if boss_level != "":
			parts.append("%s at %s" % [boss_name(content, boss_level), levels[boss_level]["name"]])
	return "Next: " + ", then ".join(parts)


## "Sight in 30 gold" for the cheapest upgrade one buy away that costs gold and is no more than half its
## price out of reach; "" when there is none.
static func _nearly_affordable(content: Dictionary, profile: Node) -> String:
	for id in profile.get_next_unlocks():
		var node: Dictionary = content["upgrade_nodes"][id]
		var short: int = int(node["cost"]) - profile.get_gold()
		if not HoldfastMeta.is_star_node(node) and short > 0 and short * 2 <= int(node["cost"]):
			return "%s in %s gold" % [node["name"], Hud.format_number(short)]
	return ""


## The first boss-tier enemy in a level's waves, or "".
static func boss_name(content: Dictionary, level: String) -> String:
	for wave in content["levels"][level]["waves"]:
		for spawn in wave["spawns"]:
			var enemy: Dictionary = content["enemies"][spawn["enemy"]]
			if str(enemy.get("tier", "normal")) == "boss":
				return str(enemy["name"])
	return ""


## True once the last level of the pack is won.
## shortcut: reads the pack's level order; swap for the end-of-content state of HF-M2-64 when it lands.
static func _last_won(content: Dictionary, profile: Node) -> bool:
	var ids: Array = content["levels"].keys()
	return not ids.is_empty() and profile.is_level_won(str(ids[-1]))


## The notes for a finished run, to go with the run flow's summary: {"boss", "unlocked", "way_on",
## "tip"} (each "" or [] when there is nothing to say). `result` is the run's result (outcome,
## level) and `next` the level the summary offers ("" for none). Call it after the run is banked.
static func summary_notes(content: Dictionary, profile: Node, result: Dictionary, next: String) -> Dictionary:
	var notes := {"boss": "", "unlocked": [], "way_on": "", "tip": ""}
	var level := str(result.get("level", ""))
	if not content["levels"].has(level) or content["levels"][level].get("tutorial", false):
		return notes
	if result.get("outcome") != HoldfastRules.OUTCOME_WON:
		notes["tip"] = loss_tip(content, profile)
		return notes
	var boss := boss_name(content, level)
	if boss != "":
		notes["boss"] = "%s is beaten." % boss
	notes["unlocked"] = unlock_lines(content, profile, level)
	if next == "" and level == str(content["levels"].keys()[-1]):
		notes["way_on"] = MORE_COMING
	return notes


## What winning `level` opened, as lines for the summary. A Hero path that opens at that level is one.
## shortcut: the profile has no pillar gating yet (HF-M2-64); it names `get_paths_opened_by(level)` when it does.
static func unlock_lines(content: Dictionary, profile: Node, level: String) -> Array:
	var out := []
	if not profile.has_method("get_paths_opened_by"):
		return out
	for id in profile.get_paths_opened_by(level):
		out.append("The %s path is open on the Hero page." % content["hero_paths"][id]["name"])
	return out


## One tip for a lost run, by what the player has not used yet: stars, gold, gear, else a general one.
static func loss_tip(content: Dictionary, profile: Node) -> String:
	var nodes: Dictionary = content["upgrade_nodes"]
	var buyable: Array = profile.get_buyable_nodes()
	if buyable.any(func(id: String) -> bool: return HoldfastMeta.is_star_node(nodes[id])):
		var stars: int = profile.get_stars()
		return "You have %d unspent star%s. The Skill tree turns them into slots, towers and links." % [stars, "" if stars == 1 else "s"]
	# A node that costs nothing (the Squad's root) is not gold to spend.
	if buyable.any(func(id: String) -> bool: return not HoldfastMeta.is_star_node(nodes[id]) and int(nodes[id]["cost"]) > 0):
		return "You have %s gold to spend. Upgrades in the Skill tree make the next try easier." % Hud.format_number(profile.get_gold())
	if has_unworn_gear(content, profile):
		return "You carry gear you are not wearing. Put it on from the Hero page."
	return FALLBACK_TIP


## True when the Hero carries nothing in a slot that a piece in the bag would fill.
static func has_unworn_gear(content: Dictionary, profile: Node) -> bool:
	var worn: Dictionary = profile.get_gear_worn()
	for id in profile.get_gear_owned():
		var item: Dictionary = content["gear_items"].get(id, {})
		if not item.is_empty() and worn.get(item["slot"], "") == "":
			return true
	return false


## The compulsory first purchases and the short fight after them, as the Journey map and the Skill tree
## both show them: {} when none is due, else {"text", "button", "disabled", "node"} ("node" is the
## upgrade to buy, "" for the fight).
static func guide(content: Dictionary, profile: Node) -> Dictionary:
	var id: String = profile.get_guide_node()
	if id == "":
		return {"text": STAND_LINE, "button": "Start", "disabled": false, "node": ""} if profile.is_stand_due() else {}
	var node: Dictionary = content["upgrade_nodes"][id]
	var why: String = profile.why_not_buy(id)
	if why == "Not enough stars":
		why = "Refund a node to free a star"
	return {
		"text": "Spend a star on %s: %s.%s" % [node["name"], _grant_text(node), "" if why == "" else " " + why + "."],
		"button": "Buy %s (%s)" % [node["name"], HoldfastMeta.cost_text(node)],
		"disabled": why != "",
		"node": id,
	}


static func _grant_text(node: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(node.get("grants", {}).get("slots", 0)) > 0:
		parts.append("a place on the castle ring for a post")
	if int(node.get("grants", {}).get("cards", 0)) > 0:
		parts.append("an Archer Post to put in it")
	return " and ".join(parts)
