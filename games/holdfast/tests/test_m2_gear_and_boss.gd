extends KitTestCase
## HF-M2-16 Hero-only gear and the level 5 boss: strict tests written before the build (Head of QA, M2).
##
## Seams the build must provide (pure statics on plain data):
##
##   res://scripts/rules/hero_gear.gd   class_name HeroGear
##     static new_unit(kind: String, hero_slots: Array) -> Dictionary
##       kind is "hero" or "recruit". A Hero gets one empty slot per name in hero_slots;
##       a Recruit gets none, whatever hero_slots holds. Result: {kind, slots: {slot: ""}}.
##     static equip(unit, slot: String, item_id: String) -> Dictionary
##       {ok, unit, replaced, reason}. A slot the unit lacks gives ok false, reason
##       "no_slot", unit unchanged. Equipping over an item returns it in replaced.
##       An empty item_id is refused with reason "empty_item".
##     static drops_gear(level: int, tier: String, roll: float, cfg: Dictionary) -> bool
##       tier is "normal", "elite" or "boss"; roll is in [0, 1). cfg: {elite_levels: Array,
##       boss_level: int, elite_chance: float}. Normal enemies never drop gear. Elites drop
##       only on elite_levels and only when roll < elite_chance. The boss drops on
##       boss_level whatever the roll, and never elsewhere.
##     static pick_item(pool: Array, roll: float) -> String
##       Index floor(roll * pool.size()), clamped to the last entry; empty pool gives "".
##
##   res://scripts/rules/boss_rules.gd   class_name BossRules
##     static new_boss(max_health: float, required_ability: String) -> Dictionary
##       {max_health, health, required_ability, defeated}
##     static take_hit(boss, damage: float, hero_abilities: Array) -> Dictionary
##       Without required_ability among hero_abilities the hit does nothing. With it,
##       health drops (clamped at 0) and 0 means defeated. Zero and negative damage do nothing.
##     static validate(max_health: Variant, required_ability: Variant) -> PackedStringArray
##       max_health must be a number above zero, required_ability a non-empty string.
##
## Worked numbers: elite_levels [2, 3], boss_level 5, elite_chance 0.5, pool of four.

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const GEAR := "res://scripts/rules/hero_gear.gd"
const BOSS := "res://scripts/rules/boss_rules.gd"
const SLOTS := ["weapon", "lantern", "charm"]
const CFG := {"elite_levels": [2, 3], "boss_level": 5, "elite_chance": 0.5}


func _qa() -> QaSeam:
	return QaSeam.new(self, "res://tests/qa_pending.json")


func test_the_hero_has_every_slot_empty() -> void:
	var g := _qa().use("hero_gear", GEAR)
	if g == null:
		return
	var hero: Dictionary = g.call("new_unit", "hero", SLOTS)
	expect_eq(hero["kind"], "hero")
	expect_true(QaSeam.same(hero["slots"], {"weapon": "", "lantern": "", "charm": ""}), str(hero))


func test_recruits_have_no_slots_whatever_they_are_offered() -> void:
	var g := _qa().use("hero_gear", GEAR)
	if g == null:
		return
	var recruit: Dictionary = g.call("new_unit", "recruit", SLOTS)
	expect_eq(recruit["kind"], "recruit")
	expect_eq(recruit["slots"].size(), 0, "Hero-only gear: a Recruit has nowhere to put it")
	for slot in SLOTS:
		var result: Dictionary = g.call("equip", recruit, slot, "sword")
		expect_false(result["ok"], "a Recruit cannot equip into " + slot)
		expect_eq(result["reason"], "no_slot")
		expect_true(QaSeam.same(result["unit"], recruit), "and nothing changes")


func test_equip_replace_and_refusals() -> void:
	var g := _qa().use("hero_gear", GEAR)
	if g == null:
		return
	var hero: Dictionary = g.call("new_unit", "hero", SLOTS)
	var first: Dictionary = g.call("equip", hero, "weapon", "sword")
	expect_true(first["ok"])
	expect_eq(first["replaced"], "", "nothing was there")
	expect_eq(first["unit"]["slots"]["weapon"], "sword")
	expect_eq(hero["slots"]["weapon"], "", "the unit passed in is not changed")
	var second: Dictionary = g.call("equip", first["unit"], "weapon", "axe")
	expect_true(second["ok"])
	expect_eq(second["replaced"], "sword", "the old item comes back so it is not lost")
	expect_eq(second["unit"]["slots"]["weapon"], "axe")
	expect_eq(second["unit"]["slots"]["lantern"], "", "other slots untouched")
	var no_slot: Dictionary = g.call("equip", hero, "boots", "sword")
	expect_false(no_slot["ok"])
	expect_eq(no_slot["reason"], "no_slot")
	var empty: Dictionary = g.call("equip", first["unit"], "weapon", "")
	expect_false(empty["ok"])
	expect_eq(empty["reason"], "empty_item")
	expect_eq(empty["unit"]["slots"]["weapon"], "sword", "an empty item never unequips")


func test_elite_drops_on_level_2_and_3_only_below_the_chance() -> void:
	var g := _qa().use("hero_gear", GEAR)
	if g == null:
		return
	for level in [2, 3]:
		expect_true(g.call("drops_gear", level, "elite", 0.0, CFG), "level %d, roll 0" % level)
		expect_true(g.call("drops_gear", level, "elite", 0.49, CFG), "level %d, roll 0.49" % level)
		expect_false(g.call("drops_gear", level, "elite", 0.5, CFG), "level %d, roll equal to the chance does not drop" % level)
		expect_false(g.call("drops_gear", level, "elite", 0.99, CFG))
	for level in [1, 4, 5, 6, 0]:
		expect_false(g.call("drops_gear", level, "elite", 0.0, CFG), "level %d is not an elite level" % level)


func test_elite_chance_extremes() -> void:
	var g := _qa().use("hero_gear", GEAR)
	if g == null:
		return
	var never := {"elite_levels": [2], "boss_level": 5, "elite_chance": 0.0}
	var always := {"elite_levels": [2], "boss_level": 5, "elite_chance": 1.0}
	expect_false(g.call("drops_gear", 2, "elite", 0.0, never), "chance 0 never drops, even on roll 0")
	expect_true(g.call("drops_gear", 2, "elite", 0.999999, always), "chance 1 always drops")
	var none := {"elite_levels": [], "boss_level": 5, "elite_chance": 1.0}
	expect_false(g.call("drops_gear", 2, "elite", 0.0, none), "no elite levels, no elite drops")


func test_normal_enemies_never_drop_gear() -> void:
	var g := _qa().use("hero_gear", GEAR)
	if g == null:
		return
	for level in [1, 2, 3, 4, 5]:
		expect_false(g.call("drops_gear", level, "normal", 0.0, CFG), "level %d normal" % level)


func test_the_boss_drops_on_its_level_whatever_the_roll() -> void:
	var g := _qa().use("hero_gear", GEAR)
	if g == null:
		return
	for roll in [0.0, 0.5, 0.999]:
		expect_true(g.call("drops_gear", 5, "boss", roll, CFG), "boss level, roll %s" % roll)
	for level in [1, 2, 3, 4, 6]:
		expect_false(g.call("drops_gear", level, "boss", 0.0, CFG), "a boss on level %d is not this game's boss" % level)


func test_pick_item_covers_the_pool_evenly_and_never_overruns() -> void:
	var g := _qa().use("hero_gear", GEAR)
	if g == null:
		return
	var pool := ["a", "b", "c", "d"]
	var expected := {0.0: "a", 0.24: "a", 0.25: "b", 0.49: "b", 0.5: "c", 0.74: "c", 0.75: "d", 0.999: "d", 1.0: "d"}
	for roll in expected:
		expect_eq(g.call("pick_item", pool, roll), expected[roll], "roll %s" % roll)
	expect_eq(g.call("pick_item", [], 0.3), "", "empty pool gives nothing")
	expect_eq(g.call("pick_item", ["only"], 0.99), "only")


# ---------------------------------------------------------------- boss

func test_the_boss_needs_the_path_ability() -> void:
	var b := _qa().use("boss_rules", BOSS)
	if b == null:
		return
	var boss: Dictionary = b.call("new_boss", 200.0, "shatter")
	expect_true(QaSeam.has_fields(boss, {"max_health": 200.0, "health": 200.0, "required_ability": "shatter", "defeated": false}), str(boss))
	for abilities in [[], ["pierce"], ["pierce", "volley"]]:
		var unharmed: Dictionary = b.call("take_hit", boss, 50.0, abilities)
		expect_eq(unharmed["health"], 200.0, "no shatter in %s: no damage" % [abilities])
		expect_false(unharmed["defeated"])
	var hurt: Dictionary = b.call("take_hit", boss, 50.0, ["pierce", "shatter"])
	expect_eq(hurt["health"], 150.0, "with the ability the hit lands")
	expect_eq(boss["health"], 200.0, "the boss passed in is not changed")


func test_boss_defeat_boundaries() -> void:
	var b := _qa().use("boss_rules", BOSS)
	if b == null:
		return
	var boss: Dictionary = b.call("new_boss", 200.0, "shatter")
	var abilities := ["shatter"]
	var almost: Dictionary = b.call("take_hit", boss, 199.5, abilities)
	expect_false(almost["defeated"], "0.5 left")
	expect_eq(almost["health"], 0.5)
	var exact: Dictionary = b.call("take_hit", boss, 200.0, abilities)
	expect_true(exact["defeated"])
	expect_eq(exact["health"], 0.0)
	var over: Dictionary = b.call("take_hit", boss, 900.0, abilities)
	expect_eq(over["health"], 0.0, "never negative")
	expect_true(over["defeated"])
	expect_true(QaSeam.same(b.call("take_hit", boss, 0.0, abilities), boss), "zero damage")
	expect_true(QaSeam.same(b.call("take_hit", boss, -20.0, abilities), boss), "negative damage does not heal")
	expect_true(QaSeam.same(b.call("take_hit", exact, 10.0, abilities), exact), "a defeated boss stays as it was")


func test_boss_pack_values() -> void:
	var b := _qa().use("boss_rules", BOSS)
	if b == null:
		return
	expect_eq(b.call("validate", 200.0, "shatter"), PackedStringArray())
	expect_eq(b.call("validate", 1, "x"), PackedStringArray(), "integers are numbers")
	var bad := {
		"zero health": [0.0, "shatter"],
		"negative health": [-5.0, "shatter"],
		"string health": ["200", "shatter"],
		"null health": [null, "shatter"],
		"empty ability": [200.0, ""],
		"null ability": [200.0, null],
		"number ability": [200.0, 7],
	}
	for label in bad:
		var errors: PackedStringArray = b.call("validate", bad[label][0], bad[label][1])
		expect_true(errors.size() >= 1, label + " must be rejected")
		for message in errors:
			expect_ne(message, "", label + ": every error says something")


func test_the_game_actually_uses_gear_and_boss_rules() -> void:
	var qa := _qa()
	for entry in [["hero_gear", GEAR, "HeroGear"], ["boss_rules", BOSS, "BossRules"]]:
		if not qa.check(entry[0], ResourceLoader.exists(entry[1]), entry[1]):
			continue
		var hits := QaSeam.mentions_outside("res://scripts", entry[1], PackedStringArray([entry[2], entry[1].get_file()]))
		expect_true(hits.size() >= 1, "no script under res://scripts uses %s, so the wiring is missing" % entry[2])
