class_name RecruitMeta
extends RefCounted
## The Recruit part of the player's profile, and the only ways it changes: hire from the board,
## pick the squad, pick a skill, rename. Like HoldfastMeta, every function returns a new profile
## (or a result holding one) and leaves the one it was given alone.
##
## profile["recruits"]: {
##   roster: [RecruitRoster recruits]   everyone the player has hired or rescued (none at the start)
##   squad: [ids]                       who goes on the next run, in the order they take the light posts
##   round: int                         the board's round: a new one after each run
##   hired: [offer indexes]             what has been taken from this round's board
##   next: int                          the number the next hire's id carries
##   bought: int                        how many the board has sold, which sets the next price
## }
## profile["names"]: {keep, hero}       what the player calls them ("" for the default)

## The squad slots the player starts with; the tree sells the rest, up to RecruitRoster.SQUAD_MAX.
const BASE_SLOTS := 2
const DEFAULT_NAMES := {"keep": "The Keep", "hero": "Hero"}


static func new_state(_content: Dictionary) -> Dictionary:
	return {"roster": [], "squad": [], "round": 0, "hired": [], "next": 1, "bought": 0}


## Everything the profile holds about Recruits, as a save left it, made safe to use.
static func from_save(content: Dictionary, profile: Dictionary, data: Dictionary) -> void:
	var state := new_state(content)
	var saved: Variant = data.get("recruits")
	if saved is Dictionary and saved.get("roster") is Array:
		var roster := []
		var seen := []
		for entry in saved["roster"]:
			var recruit := RecruitRoster.clean(content, entry)
			if not recruit.is_empty() and not recruit["id"] in seen and roster.size() < RecruitRoster.ROSTER_MAX:
				roster.append(recruit)
				seen.append(recruit["id"])
		state["roster"] = roster
		state["squad"] = []
		for id in (saved.get("squad") if saved.get("squad") is Array else []):
			if id in seen and not id in state["squad"]:
				state["squad"].append(id)
		state["round"] = maxi(int(saved["round"]), 0) if saved.get("round") is int or saved.get("round") is float else 0
		for index in (saved.get("hired") if saved.get("hired") is Array else []):
			if (index is int or index is float) and int(index) >= 0 and int(index) < RecruitRoster.BOARD_OFFERS and not int(index) in state["hired"]:
				state["hired"].append(int(index))
		state["next"] = maxi(int(saved["next"]), 1) if saved.get("next") is int or saved.get("next") is float else 1
		state["bought"] = maxi(int(saved["bought"]), 0) if saved.get("bought") is int or saved.get("bought") is float else 0
	profile["recruits"] = state
	profile["recruits"]["squad"] = profile["recruits"]["squad"].slice(0, slots(content, profile))
	var names := {"keep": "", "hero": ""}
	var saved_names: Variant = data.get("names")
	if saved_names is Dictionary:
		for key in names:
			names[key] = RecruitRoster.clean_name(str(saved_names.get(key, "")))
	profile["names"] = names


## How many Recruits the player may take on a run.
static func slots(content: Dictionary, profile: Dictionary) -> int:
	return clampi(BASE_SLOTS + HoldfastMeta.granted(content, profile, "squad"), 0, RecruitRoster.SQUAD_MAX)


static func recruit(profile: Dictionary, id: String) -> Dictionary:
	for each in profile["recruits"]["roster"]:
		if each["id"] == id:
			return each
	return {}


## The squad's Recruits in order, as a run's config takes them.
static func squad_for_run(content: Dictionary, profile: Dictionary) -> Array:
	var out := []
	for id in profile["recruits"]["squad"].slice(0, slots(content, profile)):
		var found := recruit(profile, id)
		if not found.is_empty():
			out.append(found.duplicate(true))
	return out


## Puts a Recruit on the squad, or takes them off it when they are on it. A full squad takes no one.
static func toggle_squad(content: Dictionary, profile: Dictionary, id: String) -> Dictionary:
	if recruit(profile, id).is_empty():
		return profile
	var out := profile.duplicate(true)
	var squad: Array = out["recruits"]["squad"]
	if id in squad:
		squad.erase(id)
	elif squad.size() < slots(content, profile):
		squad.append(id)
	return out


## "" when `id` can join the squad now, else why not.
static func why_not_squad(content: Dictionary, profile: Dictionary, id: String) -> String:
	if recruit(profile, id).is_empty():
		return "Nobody by that name."
	if id in profile["recruits"]["squad"] or profile["recruits"]["squad"].size() < slots(content, profile):
		return ""
	return "The squad is full (%d of %d). Take someone off first." % [slots(content, profile), slots(content, profile)]


## What the board's next hire costs: the pack's price list by how many it has sold, the last price once the list runs out.
static func hire_cost(content: Dictionary, profile: Dictionary) -> int:
	var costs: Array = content.get("recruit_prices", {}).get("board", {}).get("costs", [0])
	return int(costs[mini(int(profile["recruits"]["bought"]), costs.size() - 1)])


## This round's board: [{index, class, name, traits, cost}], without the ones already hired. A name
## on the roster is never offered, and every offer costs the same, the price of the next hire.
static func board(content: Dictionary, profile: Dictionary) -> Array:
	var taken := []
	for each in profile["recruits"]["roster"]:
		taken.append(each["name"])
	var out := []
	var offers := RecruitRoster.offers(content, int(profile["recruits"]["round"]), taken)
	for i in offers.size():
		if not i in profile["recruits"]["hired"]:
			var offer: Dictionary = offers[i]
			offer["index"] = i
			offer["cost"] = hire_cost(content, profile)
			out.append(offer)
	return out


## "" when the board's Recruit `index` can be hired now, else why not.
static func why_not_hire(content: Dictionary, profile: Dictionary, index: int) -> String:
	for offer in board(content, profile):
		if offer["index"] == index:
			if profile["recruits"]["roster"].size() >= RecruitRoster.ROSTER_MAX:
				return "Your roster is full (%d)." % RecruitRoster.ROSTER_MAX
			if int(profile["gold"]) < int(offer["cost"]):
				return "Not enough gold."
			return ""
	return "They have left the board."


static func hire(content: Dictionary, profile: Dictionary, index: int) -> Dictionary:
	if why_not_hire(content, profile, index) != "":
		return profile
	var offer: Dictionary = {}
	for each in board(content, profile):
		if each["index"] == index:
			offer = each
	var out := profile.duplicate(true)
	out["gold"] = int(out["gold"]) - int(offer["cost"])
	out["recruits"]["roster"].append(RecruitRoster.new_recruit("r%d" % out["recruits"]["next"], offer["name"], offer["class"], offer["traits"]))
	out["recruits"]["next"] = int(out["recruits"]["next"]) + 1
	out["recruits"]["hired"].append(index)
	out["recruits"]["bought"] = int(out["recruits"]["bought"]) + 1
	return out


## The picks waiting: [{id, name, class, fork, options}], one for each Recruit with a fork open.
static func pending_picks(content: Dictionary, profile: Dictionary) -> Array:
	var out := []
	for each in profile["recruits"]["roster"]:
		var waiting := RecruitRoster.offer(each, content)
		if not waiting.is_empty():
			out.append({"id": each["id"], "name": each["name"], "class": each["class"], "fork": waiting["fork"], "options": waiting["options"]})
	return out


static func pick_skill(content: Dictionary, profile: Dictionary, id: String, skill_id: String) -> Dictionary:
	var picked := RecruitRoster.pick(recruit(profile, id), skill_id, content) if not recruit(profile, id).is_empty() else {}
	if picked.is_empty():
		return profile
	var out := profile.duplicate(true)
	for i in out["recruits"]["roster"].size():
		if out["recruits"]["roster"][i]["id"] == id:
			out["recruits"]["roster"][i] = picked
	return out


## What `who` ("keep", "hero" or a Recruit's id) is called, or the default when they have no name.
static func name_of(profile: Dictionary, who: String) -> String:
	if DEFAULT_NAMES.has(who):
		var given := str(profile["names"][who])
		return given if given != "" else str(DEFAULT_NAMES[who])
	return str(recruit(profile, who).get("name", ""))


## Renames the keep, the Hero or a Recruit. A name with nothing in it changes nothing, except that
## it puts the keep's and the Hero's default back.
static func rename(profile: Dictionary, who: String, text: String) -> Dictionary:
	var cleaned := RecruitRoster.clean_name(text)
	var out := profile.duplicate(true)
	if DEFAULT_NAMES.has(who):
		out["names"][who] = cleaned
		return out
	if cleaned == "" or recruit(profile, who).is_empty():
		return profile
	for each in out["recruits"]["roster"]:
		if each["id"] == who:
			each["name"] = cleaned
	return out


## A banked run: a won level may rescue a Recruit (free, and onto the squad if there is a place),
## every Recruit who fought gains the XP the run gave them (a Recruit who reaches
## RecruitRoster.TRAIT_LEVEL may gain a trait), and the board turns over for the next run.
static func bank_run(content: Dictionary, profile: Dictionary, result: Dictionary) -> Dictionary:
	var out := profile.duplicate(true)
	if result.get("outcome") == HoldfastRules.OUTCOME_WON:
		for rescue in content.get("recruit_rescues", {}).values():
			var class_data: Dictionary = content.get("recruit_classes", {}).get(rescue["class"], {})
			if rescue["level"] == result.get("level") and recruit(out, rescue["id"]).is_empty() and not class_data.is_empty() and not class_data.get("locked", false):
				out["recruits"]["roster"].append(RecruitRoster.new_recruit(str(rescue["id"]), str(rescue["name"]), str(rescue["class"])))
				if out["recruits"]["squad"].size() < slots(content, out):
					out["recruits"]["squad"].append(rescue["id"])
	var gained: Variant = result.get("recruit_xp", {})
	if gained is Dictionary:
		for i in out["recruits"]["roster"].size():
			var each: Dictionary = out["recruits"]["roster"][i]
			if gained.has(each["id"]) and int(gained[each["id"]]) > 0:
				out["recruits"]["roster"][i] = RecruitRoster.grow(each, content, int(gained[each["id"]]))["recruit"]
	out["recruits"]["round"] = int(out["recruits"]["round"]) + 1
	out["recruits"]["hired"] = []
	return out


## What changed for the Recruits between two profiles, for the level-up card: [{id, name, class, from,
## to, trait, joined}] for each whose level rose, who gained a trait, or who joined (a rescue).
static func changes(content: Dictionary, before: Dictionary, after: Dictionary) -> Array:
	var out := []
	for now in after["recruits"]["roster"]:
		var was := recruit(before, now["id"])
		if was.is_empty():
			out.append({"id": now["id"], "name": now["name"], "class": now["class"], "from": 0, "to": RecruitRoster.level_of(now, content), "trait": "", "joined": true})
			continue
		var from := RecruitRoster.level_of(was, content)
		var to := RecruitRoster.level_of(now, content)
		var gained_trait := ""
		for id in now["traits"]:
			if not id in was["traits"]:
				gained_trait = str(id)
		if to > from or gained_trait != "":
			out.append({"id": now["id"], "name": now["name"], "class": now["class"], "from": from, "to": to, "trait": gained_trait, "joined": false})
	return out


## The squad a bot plays with: the highest levels, one of each class before a second of any.
static func bot_squad(content: Dictionary, profile: Dictionary) -> Array:
	var roster: Array = profile["recruits"]["roster"].duplicate()
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return RecruitRoster.level_of(a, content) > RecruitRoster.level_of(b, content))
	var out := []
	var classes := []
	for pass_no in 2:
		for each in roster:
			if out.size() < slots(content, profile) and not each in out and (pass_no == 1 or not each["class"] in classes):
				out.append(each.duplicate(true))
				classes.append(each["class"])
	return out


## The profile with every waiting fork picked as a bot does: the first of the two.
static func bot_picks(content: Dictionary, profile: Dictionary) -> Dictionary:
	var out := profile
	var waiting := pending_picks(content, out)
	while not waiting.is_empty():
		for pick in waiting:
			out = pick_skill(content, out, pick["id"], pick["options"][0])
		waiting = pending_picks(content, out)
	return out
