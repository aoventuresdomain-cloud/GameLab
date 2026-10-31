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
		price_by_tier(_base.content)
	return _base.content


## Prices the gold nodes from the pack's `gold_tiers`. A node's `cost` in the pack is its price at the first
## tier (its weight); it is scaled by the gold a run pays where its `gold_tier` opens over what the first tier
## pays, to the nearest 10, and the pack's figure is kept as `base_cost`. Levels past the ones built add
## tiers (rows in gold_tiers.json), not new prices for the old nodes. Star nodes and nodes with no tier keep their cost.
static func price_by_tier(content: Dictionary) -> void:
	for id in content.get("upgrade_nodes", {}):
		var node: Dictionary = content["upgrade_nodes"][id]
		if not node.has("gold_tier") or node.has("base_cost"):
			continue
		node["base_cost"] = node["cost"]
		node["cost"] = roundi(float(node["cost"]) * tier_scale(content, str(node["gold_tier"])) / 10.0) * 10


## How much a tier's prices are over the first tier's: the gold a run pays where it opens, over the first tier's.
static func tier_scale(content: Dictionary, tier: String) -> float:
	var tiers: Dictionary = content.get("gold_tiers", {})
	var first := 0.0
	var first_level := 1 << 30
	for id in tiers:
		if int(tiers[id]["first_level"]) < first_level:
			first_level = int(tiers[id]["first_level"])
			first = float(tiers[id]["gold_per_run"])
	return float(tiers[tier]["gold_per_run"]) / first if first > 0.0 and tiers.has(tier) else 1.0


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
