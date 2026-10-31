class_name HoldfastContent
extends RefCounted
## Loads Holdfast's content packs once, validated against Holdfast's schema.

const BASE_PACK := "res://content/base"
const SCHEMA := "res://content/schema/holdfast.pack.schema.json"
const DEFAULT_LEVEL := "outpost"

static var _base: PackLoader.Pack


## The base pack's content ({type: {id: entry}}). Reports every pack error and
## returns {} when the pack is invalid.
static func base() -> Dictionary:
	if _base == null:
		_base = PackLoader.load_pack(BASE_PACK, SCHEMA)
		for error in _base.errors:
			push_error("content pack: " + error)
	return _base.content


## About what one run pays at level number `number`: the gold_per_run of the last tier opened by then.
static func gold_per_run_at(content: Dictionary, number: int) -> int:
	var best := -1
	var out := 0
	for id in content.get("gold_tiers", {}):
		var tier: Dictionary = content["gold_tiers"][id]
		if int(tier["first_level"]) <= number and int(tier["first_level"]) > best:
			best = int(tier["first_level"])
			out = int(tier["gold_per_run"])
	return out


## Rules config for one run. `hero` is the Hero path to play ("" for the level's own).
## `layout` is the Archer Post sites to build on, for a level that has them (null: the
## sites nearest where the enemies come from, as a bot or an untouched profile plays it).
## `gear` is {slot: item id} the Hero wears; `gear_owned` is what the player has, so a drop is new.
## `squad` is the Recruits that go on the run (RecruitRoster data, in the order they take the light posts; [] for
## none); null leaves the level's own two (Bryn and Wren), which the rules tests rely on.
## `posted` is {castle spot id: Recruit id}: a squad Recruit set on the post built at that spot stands there.
## `blessing` is the id of the blessing picked for the run ("" for none; bots play without one).
## `hard` plays the level as its Hard replay: the level's modifiers apply.
static func run_config(level: String = DEFAULT_LEVEL, upgrades: Array = [], content: Dictionary = {}, hero: String = "", layout: Variant = null, gear: Dictionary = {}, gear_owned: Array = [], stand := false, squad: Variant = null, blessing := "", posted: Dictionary = {}, hard := false) -> Dictionary:
	var config := {
		"content": content if not content.is_empty() else base(),
		"level": level,
		"upgrades": upgrades,
	}
	if hero != "":
		config["hero"] = hero
	config["gear"] = gear
	config["gear_owned"] = gear_owned
	if stand:
		config["stand"] = true
	if squad is Array:
		config["squad"] = squad
	if not posted.is_empty():
		config["posted"] = posted
	if blessing != "":
		config["blessing"] = blessing
	if hard:
		config["hard"] = true
	var level_data: Dictionary = config["content"].get("levels", {}).get(level, {})
	if layout != null:
		config["layout"] = layout
	elif level_data.has("sites"):
		config["layout"] = HoldfastRules.best_layout(level_data)
	return config
