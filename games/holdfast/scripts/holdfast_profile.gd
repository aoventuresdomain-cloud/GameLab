class_name HoldfastProfile
extends Node
## The player's saved progress. Loads at start, applies HoldfastMeta actions and
## saves through the kit's SaveService after each change. Screens read it through
## get_* accessors and ask the run flow for changes; only the run flow calls the
## action methods here.
##
## Headless runs (tests, CI) keep the profile in memory and never touch the
## player's save, unless `save_path` is set.

signal changed
## Something the player must be told: a damaged, newer or unreadable save, or a failed save.
signal notice(message: String)

const DEFAULT_PATH := "user://holdfast_profile.sav"

## Where the profile is saved; "" keeps it in memory only.
var save_path := ""
var data: Dictionary = {}
## What the last load found: a SaveService status ("missing" when there was no save to read), or "new" for a fresh profile.
var load_status := "new"
var load_message := ""

var _service: SaveService
var _content: Dictionary


func _ready() -> void:
	if save_path == "" and DisplayServer.get_name() != "headless":
		save_path = DEFAULT_PATH
	load_profile()


## Reads the save (if any) into `data`. A missing or unreadable save gives a new profile.
func load_profile() -> void:
	_content = HoldfastContent.base()
	data = HoldfastMeta.new_profile(_content)
	load_status = "new"
	load_message = ""
	if save_path == "":
		_service = null
		changed.emit()
		return
	_service = SaveService.new(save_path, HoldfastMeta.SAVE_VERSION, {1: HoldfastMeta.migrate_v1.bind(_content), 2: HoldfastMeta.migrate_v2.bind(_content), 3: HoldfastMeta.migrate_v3.bind(_content), 4: HoldfastMeta.migrate_v4.bind(_content)})
	var loaded := _service.load_save()
	load_status = str(loaded["status"])
	load_message = str(loaded["message"])
	if loaded["data"] is Dictionary and not (loaded["data"] as Dictionary).is_empty():
		data = HoldfastMeta.from_save(_content, loaded["data"])
	print("[profile] loaded %s, gold %d, %d upgrades" % [load_status, get_gold(), get_upgrades().size()])
	if load_message != "":
		notice.emit(load_message)
	changed.emit()


## Playing without a save: in memory, starting fresh.
func use_memory_only() -> void:
	save_path = ""
	load_profile()


## True when a save was loaded, so Continue has something to continue.
func has_progress() -> bool:
	return load_status in ["ok", "migrated", "recovered"] or int(data["runs"]) > 0 or int(data["gold"]) > 0 or not data["upgrades"].is_empty()


func new_game() -> void:
	data = HoldfastMeta.new_profile(_content)
	load_status = "new"
	_save()
	changed.emit()


func buy(id: String) -> bool:
	var result := HoldfastMeta.buy(_content, data, id)
	if result["ok"]:
		data = result["profile"]
		_save()
		changed.emit()
	return result["ok"]


## Takes every bought upgrade back and empties the tree: the gold of gold nodes less a fee for
## each node, the stars of star nodes free again. Refused (with a notice) when the fees are more
## than the gold the player has.
func respec() -> void:
	var reason := why_not_respec()
	if reason != "":
		notice.emit(reason)
		return
	_apply(HoldfastMeta.respec(_content, data))


## "" when a respec can go ahead, else why not.
func why_not_respec() -> String:
	return HoldfastMeta.why_not_respec(_content, data)


## What a respec would do to the gold: the refunds less the fees (negative when fees win).
func get_respec_gold_change() -> int:
	return HoldfastMeta.respec_gold_change(_content, data)


## Sets the Archer Post sites for a level (ignored when they are not valid for it).
func set_layout(level: String, layout: Array) -> void:
	_apply(HoldfastMeta.set_layout(_content, data, level, layout))


## Wears an owned item, or takes it off when it is already worn.
func toggle_gear(id: String) -> void:
	_apply(HoldfastMeta.toggle_gear(_content, data, id))


## The Hero page's numbers for the path and gear the profile has (HoldfastMeta.hero_breakdown).
func get_hero_breakdown() -> Array:
	return HoldfastMeta.hero_breakdown(_content, data)


## Wears an owned piece in its slot (no change when it is already worn).
func wear_gear(id: String) -> void:
	_apply(HoldfastMeta.wear_gear(_content, data, id))


## Takes off whatever the slot holds.
func take_off_gear(slot: String) -> void:
	_apply(HoldfastMeta.take_off_gear(data, slot))


func select_level(id: String) -> void:
	_apply(HoldfastMeta.select_level(_content, data, id))


func select_pillar(id: String) -> void:
	_apply(HoldfastMeta.select_pillar(_content, data, id))


func bank_run(result: Dictionary) -> void:
	_apply(HoldfastMeta.bank_run(_content, data, result))


func _apply(next: Dictionary) -> void:
	if next == data:
		return
	data = next
	_save()
	changed.emit()


func _save() -> void:
	if _service == null:
		return
	if _service.save(data):
		print("[profile] saved, gold %d, %d upgrades" % [get_gold(), get_upgrades().size()])
	else:
		notice.emit("Your progress could not be saved.")


func get_gold() -> int:
	return int(data["gold"])


func get_upgrades() -> Array:
	return data["upgrades"]


## Stars earned in all, spent on star nodes, and free to spend.
func get_stars_earned() -> int:
	return HoldfastMeta.stars_earned(data)


func get_stars() -> int:
	return HoldfastMeta.stars_available(_content, data)


## Stars `level` has paid so far (0 to 3).
func get_level_stars(level: String) -> int:
	return int(data["stars"].get(level, 0))


## Castle slots bought, and Archer Post cards (what the Plan page lets the player place).
func get_castle_slots() -> int:
	return HoldfastMeta.castle_slots(_content, data)


func get_castle_cards() -> int:
	return HoldfastMeta.castle_cards(_content, data)


## The castle spots the player owns, in the pack's order: [{id, name, x, y}].
func get_owned_spots() -> Array:
	return HoldfastMeta.owned_spots(_content, data)


## True once the player has a slot and an Archer Post to put in it, so any level can be planned.
func has_a_tower() -> bool:
	return HoldfastMeta.has_a_tower(_content, data)


func get_level() -> String:
	return str(data["level"])


## The castle spots a run on `level` builds on ([] for the tutorial, or before the first Archer Post).
func get_layout(level: String) -> Array:
	return HoldfastMeta.layout_for(_content, data, level)


## True when the player's own layout for `level` is saved (the one Quick start reuses).
func has_saved_layout(level: String) -> bool:
	return HoldfastMeta.has_saved_layout(_content, data, level)


## Owned gear item ids, in the order found.
func get_gear_owned() -> Array:
	return data["gear"]["owned"]


## {slot: item id} for what the Hero wears (empty slots left out).
func get_gear_worn() -> Dictionary:
	return HoldfastMeta.worn_gear(data)


func get_pillar() -> String:
	return str(data["pillar"])


func get_unlocked_levels() -> Array:
	return HoldfastMeta.unlocked_levels(_content, data)


## The level after `id` when the player can play it now, else "".
func get_next_level(id: String) -> String:
	var next := HoldfastMeta.next_level(_content, id)
	return next if next in get_unlocked_levels() else ""


## True for a tutorial level (Level 0): no Plan page, a Keep that cannot fall, a fixed reward.
func is_tutorial(id: String) -> bool:
	return bool(_content.get("levels", {}).get(id, {}).get("tutorial", false))


## The gold a level pays the first time it is won, besides what the run collects.
func get_reward_gold(id: String) -> int:
	return int(_content.get("levels", {}).get(id, {}).get("reward", {}).get("gold", 0))


func is_level_won(id: String) -> bool:
	return id in data["levels_won"]


func is_near(id: String) -> bool:
	return HoldfastMeta.is_near(_content, data, id)


## True when the tree shows the node: the first, one next to a bought node, or a bought one.
func is_visible(id: String) -> bool:
	return HoldfastMeta.is_visible(_content, data, id)


## Up to two nodes one buy away, cheapest first.
func get_next_unlocks() -> Array:
	return HoldfastMeta.next_unlocks(_content, data, 2)


func why_not_buy(id: String) -> String:
	return HoldfastMeta.why_not_buy(_content, data, id)
