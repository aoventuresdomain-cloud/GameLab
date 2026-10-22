class_name HoldfastSkilledBot
extends HoldfastHeroBot
## A weaker player than HoldfastHeroBot, for checking that early levels can be won by a
## first-time player: it only decides what to do every `reaction_ticks` ticks (the move
## and the ability press are held in between), and acts on the ability only at one
## decision in `ability_every`. Deterministic: no randomness, so runs repeat exactly.

## An average player reacts in about a fifth of a second, a poor one in over half a second.
const AVERAGE := {"reaction_ticks": 6, "ability_every": 1}
const POOR := {"reaction_ticks": 18, "ability_every": 2}

var reaction_ticks := 1
var ability_every := 1
var _decisions := 0
var _held := {}


func _init(model: Dictionary = AVERAGE) -> void:
	reaction_ticks = maxi(int(model["reaction_ticks"]), 1)
	ability_every = maxi(int(model["ability_every"]), 1)


func get_input(rules: SimRules, tick: int) -> Dictionary:
	if tick % reaction_ticks != 0 and not _held.is_empty():
		return _held
	var input := super.get_input(rules, tick)
	_decisions += 1
	if input.get("ability", false) and _decisions % ability_every != 0:
		input = input.duplicate()
		input["ability"] = false
	_held = input
	return input
