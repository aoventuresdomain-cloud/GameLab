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


## Rules config for one run. `hero` is the Hero path to play ("" for the level's own).
## `layout` is the Archer Post sites to build on, for a level that has them (null: the
## sites nearest where the enemies come from, as a bot or an untouched profile plays it).
static func run_config(level: String = DEFAULT_LEVEL, upgrades: Array = [], content: Dictionary = {}, hero: String = "", layout: Variant = null) -> Dictionary:
	var config := {
		"content": content if not content.is_empty() else base(),
		"level": level,
		"upgrades": upgrades,
	}
	if hero != "":
		config["hero"] = hero
	var level_data: Dictionary = config["content"].get("levels", {}).get(level, {})
	if layout != null:
		config["layout"] = layout
	elif level_data.has("sites"):
		config["layout"] = HoldfastRules.best_layout(level_data)
	return config
