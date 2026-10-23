class_name HeroGear
extends RefCounted
## Gear is the Hero's alone. A unit is plain data: {kind, slots: {slot: item id}}, a Hero with
## one empty slot per name the pack lists and a Recruit with none. Every function returns a
## new dictionary and leaves the one it was given alone.


static func new_unit(kind: String, hero_slots: Array) -> Dictionary:
	var slots := {}
	if kind == "hero":
		for slot in hero_slots:
			slots[str(slot)] = ""
	return {"kind": kind, "slots": slots}


## {ok, unit, replaced, reason}. A slot the unit lacks is refused with "no_slot" and an empty
## item with "empty_item"; the unit comes back unchanged. `replaced` is what the slot held.
static func equip(unit: Dictionary, slot: String, item_id: String) -> Dictionary:
	var out := unit.duplicate(true)
	if not out["slots"].has(slot):
		return {"ok": false, "unit": out, "replaced": "", "reason": "no_slot"}
	if item_id == "":
		return {"ok": false, "unit": out, "replaced": "", "reason": "empty_item"}
	var replaced: String = out["slots"][slot]
	out["slots"][slot] = item_id
	return {"ok": true, "unit": out, "replaced": replaced, "reason": ""}


## Whether a kill drops gear. `cfg` is {elite_levels, boss_level, elite_chance}. Normal enemies
## never do; an elite does on an elite level when `roll` is under the chance; the boss always
## does on its own level.
static func drops_gear(level: int, tier: String, roll: float, cfg: Dictionary) -> bool:
	match tier:
		"elite":
			# Pack numbers arrive as floats, which `in` does not match to an int.
			for elite_level in cfg["elite_levels"]:
				if int(elite_level) == level:
					return roll < float(cfg["elite_chance"])
			return false
		"boss":
			return level == int(cfg["boss_level"])
	return false


## The item `roll` (0 to 1) picks from `pool`, evenly; "" for an empty pool.
static func pick_item(pool: Array, roll: float) -> String:
	if pool.is_empty():
		return ""
	return str(pool[clampi(int(floorf(roll * pool.size())), 0, pool.size() - 1)])
