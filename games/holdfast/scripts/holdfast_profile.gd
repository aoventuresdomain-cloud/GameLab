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
## Hard is on for the next run (only for the session; see select_hard).
var _hard := false


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
	_service = SaveService.new(save_path, HoldfastMeta.SAVE_VERSION, HoldfastMeta.migrations(_content))
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


## The nodes a respec would take back (the guided first buys stay).
func get_respec_nodes() -> Array:
	return HoldfastMeta.respec_nodes(_content, data)


## What a respec would do to the gold: the refunds less the fees (negative when fees win).
func get_respec_gold_change() -> int:
	return HoldfastMeta.respec_gold_change(_content, data)


## The stars a respec would give back.
func get_respec_stars() -> int:
	return HoldfastMeta.respec_stars(_content, data)


## Takes one bought node back (see HoldfastMeta.refund_node); refused with a notice when it cannot go.
func refund(id: String) -> void:
	var reason := why_not_refund(id)
	if reason != "":
		notice.emit(reason)
		return
	_apply(HoldfastMeta.refund_node(_content, data, id))


## "" when the bought node can be taken back on its own, else why not.
func why_not_refund(id: String) -> String:
	return HoldfastMeta.why_not_refund_node(_content, data, id)


## What taking the node back gives: {"gold", "stars"}.
func get_refund_gain(id: String) -> Dictionary:
	return HoldfastMeta.refund_gain(_content, id)


## A node's effects with the stat before and after it (HoldfastMeta.effect_lines).
func get_effect_lines(id: String) -> Array:
	return HoldfastMeta.effect_lines(_content, data, id)


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


## The nodes that can be bought now.
func get_buyable_nodes() -> Array:
	return HoldfastMeta.buyable_nodes(_content, data)


## True while a gear piece has not been looked at on the Hero page.
func has_unseen_gear() -> bool:
	return HoldfastMeta.has_unseen_gear(data)


func see_gear() -> void:
	_apply(HoldfastMeta.see_gear(data))


## The tutorial level's id (Level 0).
func get_tutorial_level() -> String:
	return HoldfastMeta.tutorial_level(_content)


## True when the stand (the short fight after the two guided buys) is due.
func is_stand_due() -> bool:
	return HoldfastMeta.stand_due(_content, data)


## The castle spots the stand is fought from.
func get_stand_layout() -> Array:
	return HoldfastMeta.stand_layout(_content, data)


## Marks the stand as begun, so it is offered once.
func begin_stand() -> void:
	_apply(HoldfastMeta.begin_stand(data))


## True once the line on what stars buy has been shown.
func has_seen_stars_line() -> bool:
	return bool(data["stars_line_seen"])


func show_stars_line() -> void:
	_apply(HoldfastMeta.show_stars_line(data))


## True when a run on `level` should stop at the special's first-time prompt.
func is_special_due(level: String) -> bool:
	return HoldfastMeta.special_due(_content, data, level)


## Marks the special's prompt as answered.
func teach_special() -> void:
	_apply(HoldfastMeta.teach_special(data))


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


## Mage Post cards the Tower Gate has opened.
func get_castle_mage_cards() -> int:
	return HoldfastMeta.castle_mage_cards(_content, data)


## The castle's ring of spots, in the pack's order: [{id, name, x, y}]. Any can hold a post, up to the slots bought.
func get_ring_spots() -> Array:
	return HoldfastMeta.ring_spots(_content)


## The upgrade the Plan page's "+ Tower" buys ("" when none is left), and what it costs.
func get_next_tower_node() -> String:
	return HoldfastMeta.next_tower_node(_content, data)


func get_cost_text(id: String) -> String:
	var node: Dictionary = _content["upgrade_nodes"][id]
	return HoldfastMeta.cost_text(node) if HoldfastMeta.is_star_node(node) else "%s gold" % ShortNumber.of(int(node["cost"]))


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


## The blessings on offer at the start of `level` (ids; "No blessing" is always there as well).
func get_blessing_offer(level: String, rng: RandomNumberGenerator) -> Array:
	return HoldfastMeta.blessing_offer(_content, data, level, rng)


## The Recruits and the squad (see RecruitMeta). Only the run flow calls the ones that change them.
func get_recruits() -> Array:
	return data["recruits"]["roster"]


## "Bryn and Wren have joined you" until the Recruits page has been opened ("" otherwise).
func get_welcome() -> String:
	return RecruitMeta.welcome_text(data)


func clear_welcome() -> void:
	if get_welcome() != "":
		_apply(RecruitMeta.clear_welcome(data))


func get_squad() -> Array:
	return RecruitMeta.squad_for_run(_content, data)


func get_squad_ids() -> Array:
	return data["recruits"]["squad"]


func get_squad_slots() -> int:
	return RecruitMeta.slots(_content, data)


func get_board() -> Array:
	return RecruitMeta.board(_content, data)


func get_pending_picks() -> Array:
	return RecruitMeta.pending_picks(_content, data)


func get_name_of(who: String) -> String:
	return RecruitMeta.name_of(data, who)


## What the player typed for "keep" or "hero" ("" for the default), so a name box can show it apart from the default.
func get_given_name(who: String) -> String:
	return str(data["names"].get(who, ""))


## One Recruit from the roster, or {} when there is no such id.
func get_recruit(id: String) -> Dictionary:
	return RecruitMeta.recruit(data, id)


func why_not_squad(id: String) -> String:
	return RecruitMeta.why_not_squad(_content, data, id)


func why_not_hire(index: int) -> String:
	return RecruitMeta.why_not_hire(_content, data, index)


func get_posted() -> Dictionary:
	return RecruitMeta.posted(data)


## Sets a squad Recruit on the post at a castle spot ("" for nobody).
func post_recruit(site: String, id: String) -> void:
	_apply(RecruitMeta.post_recruit(_content, data, site, id))


func toggle_squad(id: String) -> void:
	_apply(RecruitMeta.toggle_squad(_content, data, id))


func hire(index: int) -> void:
	_apply(RecruitMeta.hire(_content, data, index))


func pick_skill(id: String, skill_id: String) -> void:
	_apply(RecruitMeta.pick_skill(_content, data, id, skill_id))


func rename(who: String, text: String) -> void:
	_apply(RecruitMeta.rename(data, who, text))


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


## True when `id` has a Hard replay the player has opened by winning the level.
func is_hard_open(id: String) -> bool:
	return HoldfastMeta.hard_open(_content, data, id)


## The stars the level's Hard replay has paid so far (0 to 3).
func get_hard_stars(id: String) -> int:
	return int(data.get("hard_stars", {}).get(id, 0))


## The icon and one word of the level's Hard replay, such as ">> Swift" ("" when it has none).
func get_hard_label(id: String) -> String:
	return HoldfastMeta.hard_label(_content, id)


## What the level's Hard replay changes, in words.
func get_hard_text(id: String) -> String:
	return " ".join(HoldfastMeta.hard_modifiers(_content, id).map(func(modifier: Dictionary) -> String: return str(modifier["text"])))


## The player turns Hard on or off for the runs they plan next. It is not saved: a new session starts on Normal.
func select_hard(on: bool) -> void:
	if _hard == on:
		return
	_hard = on
	changed.emit()


## True while Hard is switched on, whether or not the selected level has a Hard replay open.
func is_hard_on() -> bool:
	return _hard


## True when the next run on the selected level is its Hard replay: Hard is on and the level has one open.
func is_hard_selected() -> bool:
	return _hard and is_hard_open(get_level())


func is_near(id: String) -> bool:
	return HoldfastMeta.is_near(_content, data, id)


## True when the tree shows the node: the first, one next to a bought node, or a bought one.
func is_visible(id: String) -> bool:
	return HoldfastMeta.is_visible(_content, data, id)


## Up to two nodes one buy away, cheapest first.
func get_next_unlocks() -> Array:
	return HoldfastMeta.next_unlocks(_content, data, 2)


## The node the map's guide offers ("" when none), affordable or not.
func get_guide_node() -> String:
	return HoldfastMeta.guide_node(_content, data)


## The compulsory purchase due ("" when none): the player can buy nothing else until it is made.
func get_guided_step() -> String:
	return HoldfastMeta.guided_step(_content, data)


func why_not_buy(id: String) -> String:
	return HoldfastMeta.why_not_buy(_content, data, id)
