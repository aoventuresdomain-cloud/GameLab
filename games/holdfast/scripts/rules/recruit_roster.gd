class_name RecruitRoster
extends RefCounted
## The Recruits the player has between runs, as plain data, and what makes one: the pack's class,
## traits and skill choices turned into the numbers a run uses. Every function returns a new value
## and leaves what it was given alone.
##
## recruit: {id, name, class, traits: [ids], xp: int, skills: [ids picked, one for each fork so far]}
##
## A Recruit's level comes from their XP: level n to n+1 costs the class's `xp_per_level` times n.
## Levels 2, 3 and 4 each offer one fork of two skills (pick one); level 5 can add a trait.

const SQUAD_MAX := 4
const ROSTER_MAX := 12
const NAME_MAX := 16
## What the recruitment board shows at a time.
const BOARD_OFFERS := 3
## The level that opens each fork (fork 1, 2 and 3), and the level that can add a trait.
const FORK_LEVELS := [2, 3, 4]
const TRAIT_LEVEL := 5
const TRAITS_MAX := 2
## The most XP a saved Recruit is believed to have.
const XP_MAX := 1000000
const ARMOUR_CAP := 0.75
## The post effects a skill can change; every other stat is a number on the Recruit.
const EFFECT_STATS := ["taunt_radius", "effect_radius", "slow", "mark_bonus", "field_dps", "repair_per_second", "heal_per_second"]


static func new_recruit(id: String, name: String, class_id: String, traits: Array = []) -> Dictionary:
	return {"id": id, "name": name, "class": class_id, "traits": traits.duplicate(), "xp": 0, "skills": []}


## What a saved Recruit becomes when it is not whole (a damaged save): {} when it cannot be used.
static func clean(content: Dictionary, saved: Variant) -> Dictionary:
	if not saved is Dictionary:
		return {}
	var classes: Dictionary = content.get("recruit_classes", {})
	var id := str(saved.get("id", ""))
	var class_id := str(saved.get("class", ""))
	var name := clean_name(str(saved.get("name", "")))
	if id == "" or name == "" or not classes.has(class_id):
		return {}
	var out := new_recruit(id, name, class_id)
	for trait_id in (saved.get("traits") if saved.get("traits") is Array else []):
		if content.get("recruit_traits", {}).has(trait_id) and not trait_id in out["traits"] and out["traits"].size() < TRAITS_MAX:
			out["traits"].append(str(trait_id))
	var xp: Variant = saved.get("xp")
	# Capped: the level is found by counting up through the XP, so a hand-edited huge number would hang the game.
	out["xp"] = clampi(int(clampf(float(xp), 0.0, float(XP_MAX))), 0, XP_MAX) if xp is int or xp is float else 0
	# A skill counts only as the next fork's pick, in order, for the Recruit's class.
	for skill_id in (saved.get("skills") if saved.get("skills") is Array else []):
		var skill: Dictionary = content.get("recruit_skills", {}).get(skill_id, {})
		if not skill.is_empty() and skill["class"] == class_id and int(skill["fork"]) == out["skills"].size() + 1 and out["skills"].size() < FORK_LEVELS.size():
			out["skills"].append(str(skill_id))
	return out


## A name as the player typed it: control characters out, spaces trimmed and squeezed, at most
## NAME_MAX letters. "" when nothing is left.
static func clean_name(text: String) -> String:
	var kept := ""
	for i in text.length():
		var code := text.unicode_at(i)
		kept += " " if code < 32 or code == 127 else text[i]
	var words := kept.strip_edges().split(" ", false)
	return " ".join(words).left(NAME_MAX).strip_edges()


## How many levels' worth of XP the Recruit has: 1 with none.
static func level_for(xp: int, xp_per_level: int) -> int:
	var level := 1
	var left := maxi(xp, 0)
	var step := maxi(xp_per_level, 1)
	while left >= step * level:
		left -= step * level
		level += 1
	return level


static func level_of(recruit: Dictionary, content: Dictionary) -> int:
	var cls: Dictionary = content.get("recruit_classes", {}).get(recruit["class"], {})
	return level_for(int(recruit["xp"]), int(cls.get("xp_per_level", 1)))


## The XP a Recruit gets from `amount` banked: an Eager one gets more. Whole numbers, never zero for a gain.
static func xp_for(recruit: Dictionary, content: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	return maxi(roundi(float(amount) * float(build(recruit, content).get("xp_gain", 1.0))), 1)


## The numbers a run uses for this Recruit (the shape of a pack `staff` entry, plus `level`,
## `flee_below`, `armour`, `xp_gain` and `fx`, the post effect their class gives with the traits and
## skills applied). {} for a class the pack does not have. `tree` is the run's stat table (see
## StatModel); the `recruit.*` stats in it, from the tree, apply to every Recruit alongside their
## own traits and skills, by the same rule: (base + every add) x every multiply.
static func build(recruit: Dictionary, content: Dictionary, tree := {}) -> Dictionary:
	var cls: Dictionary = content.get("recruit_classes", {}).get(recruit["class"], {})
	if cls.is_empty():
		return {}
	var stats := {}
	for stat in tree:
		if str(stat).begins_with("recruit."):
			stats[stat] = tree[stat]
	for trait_id in recruit["traits"]:
		for effect in content.get("recruit_traits", {}).get(trait_id, {}).get("effects", []):
			StatModel.put(stats, str(effect["stat"]), effect)
	for skill_id in recruit["skills"]:
		for effect in content.get("recruit_skills", {}).get(skill_id, {}).get("effects", []):
			StatModel.put(stats, str(effect["stat"]), effect)
	var data := {"id": recruit["id"], "name": recruit["name"], "class": recruit["class"]}
	for key in ["range", "cooldown", "health", "leash", "move_speed", "retreat_below", "rest_heal", "revive_seconds", "revive_health"]:
		data[key] = StatModel.apply(stats, "recruit." + key, float(cls[key]))
	data["radius"] = cls["radius"]
	data["xp_per_level"] = cls["xp_per_level"]
	var level := level_of(recruit, content)
	data["level"] = level
	# A level's worth of damage grows with the damage, so a levelled blow keeps its share.
	data["damage"] = StatModel.apply(stats, "recruit.damage", float(cls["damage"]) + float(level - 1) * float(cls["damage_per_level"]))
	data["damage_per_level"] = float(cls["damage_per_level"]) * StatModel.multiplier(stats, "recruit.damage")
	data["barks"] = cls["barks"]
	data["flee_below"] = StatModel.apply(stats, "recruit.flee_below", 0.0)
	data["armour"] = StatModel.apply(stats, "recruit.armour", 0.0)
	data["xp_gain"] = StatModel.apply(stats, "recruit.xp_gain", 1.0)
	var fx: Dictionary = content.get("role_effects", {}).get(recruit["class"], {}).duplicate()
	fx.erase("id")
	for stat in EFFECT_STATS:
		if fx.has(stat) or stats.has("recruit." + stat):
			fx[stat] = StatModel.apply(stats, "recruit." + stat, float(fx.get(stat, 0.0)))
	data["cooldown"] = maxf(float(data["cooldown"]), 0.1)
	data["armour"] = clampf(float(data["armour"]), 0.0, ARMOUR_CAP)
	for key in ["retreat_below", "flee_below"]:
		data[key] = clampf(float(data[key]), 0.0, 1.0)
	data["revive_health"] = clampf(float(data["revive_health"]), 0.01, 1.0)
	if fx.has("slow"):
		fx["slow"] = clampf(float(fx["slow"]), 0.0, 0.9)
	data["fx"] = fx
	return data


## The fork a Recruit can pick from now: {fork: 1 to 3, options: [skill ids]}, or {} when they have
## no pick waiting (their level has not opened the next fork, or all three are made).
static func offer(recruit: Dictionary, content: Dictionary) -> Dictionary:
	var made: int = recruit["skills"].size()
	if made >= FORK_LEVELS.size() or level_of(recruit, content) < FORK_LEVELS[made]:
		return {}
	var options := []
	for id in content.get("recruit_skills", {}):
		var skill: Dictionary = content["recruit_skills"][id]
		if skill["class"] == recruit["class"] and int(skill["fork"]) == made + 1:
			options.append(id)
	return {"fork": made + 1, "options": options}


## The Recruit with `skill_id` picked, or {} when it is not one of the two on offer.
static func pick(recruit: Dictionary, skill_id: String, content: Dictionary) -> Dictionary:
	var waiting := offer(recruit, content)
	if waiting.is_empty() or not skill_id in waiting["options"]:
		return {}
	var out := recruit.duplicate(true)
	out["skills"].append(skill_id)
	return out


## The Recruit after `gained` XP: {recruit, from, to (levels), trait: the id of a trait they gained or ""}.
## Reaching TRAIT_LEVEL adds one trait the Recruit does not have, chosen from their id so it is the same every time.
static func grow(recruit: Dictionary, content: Dictionary, gained: int) -> Dictionary:
	var out := recruit.duplicate(true)
	var from := level_of(out, content)
	out["xp"] = int(out["xp"]) + maxi(gained, 0)
	var to := level_of(out, content)
	var gained_trait := ""
	if from < TRAIT_LEVEL and to >= TRAIT_LEVEL and out["traits"].size() < TRAITS_MAX:
		var free := []
		for id in content.get("recruit_traits", {}):
			if not id in out["traits"]:
				free.append(id)
		if not free.is_empty():
			gained_trait = str(free[_mix(str(out["id"])) % free.size()])
			out["traits"].append(gained_trait)
	return {"recruit": out, "from": from, "to": to, "trait": gained_trait}


static func _mix(text: String) -> int:
	var value := 17
	for i in text.length():
		value = (value * 31 + text.unicode_at(i)) % 1000003
	return value


## What the board offers in round `round_no`: BOARD_OFFERS Recruits as [{class, name, traits: [id]}], the same
## every time for the same round, from the classes the pack has not locked. Names in `taken` are not offered again.
static func offers(content: Dictionary, round_no: int, taken: Array) -> Array:
	var classes: Array = content.get("recruit_classes", {}).keys().filter(func(id: Variant) -> bool: return not content["recruit_classes"][id].get("locked", false))
	var traits: Array = content.get("recruit_traits", {}).keys()
	var pool: Array = []
	for entry in content.get("recruit_names", {}).values():
		pool.append_array(entry["names"])
	pool = pool.filter(func(name: Variant) -> bool: return not name in taken)
	var out := []
	if classes.is_empty() or traits.is_empty() or pool.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = round_no * 7919 + 13
	for i in BOARD_OFFERS:
		if pool.is_empty():
			break
		var class_id: String = classes[rng.randi_range(0, classes.size() - 1)]
		var name: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var trait_id: String = traits[rng.randi_range(0, traits.size() - 1)]
		out.append({"class": class_id, "name": name, "traits": [trait_id]})
	return out
