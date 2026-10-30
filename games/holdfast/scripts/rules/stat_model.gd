class_name StatModel
extends RefCounted
## The one stat model. Everything that changes a number in a run (tree nodes, gear, blessings, a
## Recruit's traits and skills) is an effect `{stat, add?, multiply?}` on a named stat, and every
## named stat is read the same way: (base + every add) x every multiply. Nothing else multiplies.
##
## Stat names: a bare name is global (`keep_health`), `tower.<stat>` and `hero.<stat>` belong to a
## kind of tower or the Hero path played, `recruit.<stat>` belongs to every Recruit. A node that
## names a `tower` or `hero` scopes its `tower.`/`hero.` stats to it (see `scoped`).
##
## STATS lists every stat a pack may change and what may change it, and `test_stat_model.gd`
## holds the packs to it: a pack effect on a stat that is not here, or from a source that is not
## listed for it, fails the test.

const TREE := "tree"
const GEAR := "gear"
const BLESSING := "blessing"
const TRAIT := "trait"
const SKILL := "skill"

## The stats Recruits carry: the numbers on a Recruit's class (the first group), the post effect
## their class gives (the second), and the two a trait or skill can add (`flee_below`, `xp_gain`).
const RECRUIT_STATS := [
	"damage", "range", "cooldown", "health", "move_speed", "leash", "rest_heal", "revive_seconds",
	"revive_health", "retreat_below", "flee_below", "armour", "xp_gain",
	"taunt_radius", "effect_radius", "slow", "mark_bonus", "field_dps", "repair_per_second", "heal_per_second",
]
## What each global stat is read by in a run, and what may change it.
const GLOBAL_STATS := {
	"keep_health": [TREE, BLESSING],
	"enemy_speed": [BLESSING],
	"repair_share": [BLESSING],
	"gold_multiplier": [TREE, BLESSING],
	"beam_reach": [TREE, GEAR],
	"aura_radius": [TREE],
	"aura_dps": [TREE],
}
## Prefixes: what may change a stat that begins with one (the rest of the name is the pack's).
const PREFIXES := {
	"tower.": [TREE, BLESSING],
	"hero.": [TREE, GEAR, BLESSING],
	"recruit.": [TREE, TRAIT, SKILL],
}


## Every effect's stats added up: {stat: {add, multiply}}. `purchased` are ids in `nodes`; an id
## that is not there is skipped with an error.
static func sum(nodes: Dictionary, purchased: Array) -> Dictionary:
	var stats := {}
	for id in purchased:
		var node: Dictionary = nodes.get(id, {})
		if node.is_empty():
			push_error("HoldfastRules: unknown upgrade %s, ignored" % id)
			continue
		for effect in node.get("effects", []):
			put(stats, scoped(node, str(effect["stat"])), effect)
	return stats


## Adds one effect to a stats table.
static func put(stats: Dictionary, stat: String, effect: Dictionary) -> void:
	var entry: Dictionary = stats.get(stat, {"add": 0.0, "multiply": 1.0})
	entry["add"] += float(effect.get("add", 0.0))
	entry["multiply"] *= float(effect.get("multiply", 1.0))
	stats[stat] = entry


## Two stats tables as one: every add summed, every multiply multiplied.
static func combine(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for stat in b:
		put(out, stat, b[stat])
	return out


## The stats that begin with `prefix`, with the prefix cut off.
static func under(stats: Dictionary, prefix: String) -> Dictionary:
	var out := {}
	for stat in stats:
		if str(stat).begins_with(prefix):
			out[str(stat).substr(prefix.length())] = stats[stat]
	return out


## A tower or Hero node's stat is scoped to what it belongs to: `tower.damage` on an archer_post
## node is `tower.archer_post.damage`, `hero.attack.damage` on a flare_archer node is
## `hero.flare_archer.attack.damage`. Every other stat is global.
static func scoped(node: Dictionary, stat: String) -> String:
	if node.has("tower") and stat.begins_with("tower."):
		return "tower.%s.%s" % [node["tower"], stat.substr(6)]
	if node.has("hero") and stat.begins_with("hero."):
		return "hero.%s.%s" % [node["hero"], stat.substr(5)]
	return stat


static func add(stats: Dictionary, stat: String) -> float:
	return float(stats.get(stat, {}).get("add", 0.0))


static func multiplier(stats: Dictionary, stat: String) -> float:
	return float(stats.get(stat, {}).get("multiply", 1.0))


## `base` with the stat's adds and multiplies: (base + adds) x multiplies.
static func apply(stats: Dictionary, stat: String, base: float) -> float:
	var entry: Dictionary = stats.get(stat, {"add": 0.0, "multiply": 1.0})
	return (base + float(entry["add"])) * float(entry["multiply"])


## The sources a pack stat may come from, or [] when the model has no such stat.
static func allowed_sources(stat: String) -> Array:
	if GLOBAL_STATS.has(stat):
		return GLOBAL_STATS[stat]
	for prefix in PREFIXES:
		if stat.begins_with(prefix):
			if prefix == "recruit." and not stat.substr(8) in RECRUIT_STATS:
				return []
			return PREFIXES[prefix]
	return []
