class_name ThroughLevelZero
extends RefCounted
## Test set-up for a player who has finished Level 0 and made the two guided buys (First
## Slot, then the first Archer Post): Level 1 is open and the Plan page has one slot and
## one card. It gives the stars directly, not the Level 0 reward gold, so tests that count
## gold keep their numbers.


## `profile` (a Dictionary, as HoldfastMeta works on it) past Level 0, with both purchases made.
static func of(content: Dictionary, profile: Dictionary) -> Dictionary:
	var out := profile.duplicate(true)
	var first := HoldfastMeta.tutorial_level(content)
	out["stars"][first] = int(content["levels"][first]["reward"]["stars"])
	for list in [["levels_won", first], ["unlocked", HoldfastMeta.next_level(content, first)]]:
		if not list[1] in out[list[0]]:
			out[list[0]].append(list[1])
	for id in HoldfastMeta.castle_rules(content)["guided"]:
		out = HoldfastMeta.buy(content, out, id)["profile"]
	return out


## The same for a HoldfastProfile node.
static func apply(profile: HoldfastProfile) -> void:
	profile.data = of(HoldfastContent.base(), profile.data)
	profile.changed.emit()
