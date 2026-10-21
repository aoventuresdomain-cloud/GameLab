extends KitTestCase
## HF-M2-15 Enemies fight back: strict tests written before the build (Head of QA, M2).
##
## Seams the build must provide (pure statics on plain data, no nodes):
##
##   res://scripts/rules/enemy_targeting.gd   class_name EnemyTargeting
##     static pick(enemy_pos: Vector2, candidates: Array, tie_order: Array) -> String
##       candidates: [{"id": String, "pos": Vector2}, ...] (towers and the Hero's side).
##       Returns the id of the nearest by straight-line distance. An exact tie goes to
##       the id that comes first in tie_order; ids missing from tie_order lose to listed
##       ones; if still tied the smaller id string wins (so the result never depends on
##       array order). No candidates returns "" (the caller then heads for the keep).
##
##   res://scripts/rules/unit_health.gd       class_name UnitHealth
##     static new_unit(max_health: float) -> Dictionary  {max_health, health, alive}
##     static damage(unit, amount: float) -> Dictionary   health clamps at 0; 0 means not alive
##     static repair(unit, amount: float) -> Dictionary   clamps at max; the dead are not repaired
##     Both return a new dictionary; zero and negative amounts change nothing.
##
##   res://scripts/rules/lit_area.gd          class_name LitArea
##     static damage_for(base: float, enemy_pos: Vector2, posts: Array, radius: float, bonus: float) -> float
##       base * (1 + bonus) when the enemy is within radius (inclusive) of any post, else base.
##       Several posts never stack. No posts, radius 0 away from a post, or bonus 0 give base.
##     static validate(radius: Variant, bonus: Variant) -> PackedStringArray
##       Pack check: radius and bonus must be numbers at or above zero (zero is allowed).
##
## Worked numbers: a 3-4-5 triangle gives distances that are exact in floating point.

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const TARGETING := "res://scripts/rules/enemy_targeting.gd"
const HEALTH := "res://scripts/rules/unit_health.gd"
const LIT := "res://scripts/rules/lit_area.gd"


func _qa() -> QaSeam:
	return QaSeam.new(self, "res://tests/qa_pending.json")


func _cand(id: String, x: float, y: float) -> Dictionary:
	return {"id": id, "pos": Vector2(x, y)}


# ---------------------------------------------------------------- targeting

func test_nearest_wins_whatever_the_array_order() -> void:
	var t := _qa().use("enemy_targeting", TARGETING)
	if t == null:
		return
	var a := _cand("a", 30, 40)    # distance 50
	var b := _cand("b", 0, 49)     # distance 49
	var c := _cand("c", -60, -80)  # distance 100
	for order in [[a, b, c], [c, b, a], [b, c, a]]:
		expect_eq(t.call("pick", Vector2.ZERO, order, []), "b", "49 beats 50 and 100")


func test_an_exact_tie_follows_tie_order_not_array_order() -> void:
	var t := _qa().use("enemy_targeting", TARGETING)
	if t == null:
		return
	# (30,40) and (-40,30): squared distance 2500 each, so exactly 50 apart from the enemy.
	var a := _cand("a", 30, 40)
	var b := _cand("b", -40, 30)
	for order in [[a, b], [b, a]]:
		expect_eq(t.call("pick", Vector2.ZERO, order, ["b", "a"]), "b", "tie_order says b first")
		expect_eq(t.call("pick", Vector2.ZERO, order, ["a", "b"]), "a", "tie_order says a first")


func test_a_tie_with_unlisted_ids_prefers_listed_then_smaller_id() -> void:
	var t := _qa().use("enemy_targeting", TARGETING)
	if t == null:
		return
	var a := _cand("a", 30, 40)
	var b := _cand("b", -40, 30)
	expect_eq(t.call("pick", Vector2.ZERO, [a, b], ["b"]), "b", "listed beats unlisted")
	expect_eq(t.call("pick", Vector2.ZERO, [b, a], []), "a", "no order at all: smaller id, whatever the array order")
	expect_eq(t.call("pick", Vector2.ZERO, [a, b], ["zz"]), "a", "an irrelevant tie_order changes nothing")


func test_a_nearer_candidate_beats_the_tie_order() -> void:
	var t := _qa().use("enemy_targeting", TARGETING)
	if t == null:
		return
	var far := _cand("a", 30, 40)  # 50
	var near := _cand("z", 0, 10)  # 10
	expect_eq(t.call("pick", Vector2.ZERO, [far, near], ["a", "z"]), "z", "tie_order only breaks ties")


func test_no_towers_left_means_no_target() -> void:
	var t := _qa().use("enemy_targeting", TARGETING)
	if t == null:
		return
	expect_eq(t.call("pick", Vector2(5, 5), [], ["a"]), "", "empty list: no target, no crash")
	expect_eq(t.call("pick", Vector2(5, 5), [], []), "")


func test_one_candidate_and_an_enemy_standing_on_it() -> void:
	var t := _qa().use("enemy_targeting", TARGETING)
	if t == null:
		return
	expect_eq(t.call("pick", Vector2(7, 7), [_cand("only", 900, -900)], []), "only", "a lone candidate is the target however far")
	expect_eq(t.call("pick", Vector2(7, 7), [_cand("a", 7, 7), _cand("b", 8, 7)], []), "a", "distance zero is allowed and nearest")


func test_pick_does_not_change_its_inputs() -> void:
	var t := _qa().use("enemy_targeting", TARGETING)
	if t == null:
		return
	var list := [_cand("b", -40, 30), _cand("a", 30, 40)]
	var order := ["b", "a"]
	t.call("pick", Vector2.ZERO, list, order)
	expect_eq(list[0]["id"], "b", "candidates keep their order")
	expect_eq(order, ["b", "a"], "tie_order is untouched")


# ---------------------------------------------------------------- unit health

func test_unit_health_damage_and_repair() -> void:
	var u := _qa().use("unit_health", HEALTH)
	if u == null:
		return
	var fresh: Dictionary = u.call("new_unit", 80.0)
	expect_true(QaSeam.has_fields(fresh, {"max_health": 80.0, "health": 80.0, "alive": true}), str(fresh))
	var hurt: Dictionary = u.call("damage", fresh, 30.0)
	expect_true(QaSeam.has_fields(hurt, {"health": 50.0, "alive": true}), str(hurt))
	expect_eq(fresh["health"], 80.0, "the unit passed in is not changed")
	var mended: Dictionary = u.call("repair", hurt, 10.0)
	expect_eq(mended["health"], 60.0)
	var capped: Dictionary = u.call("repair", hurt, 1000.0)
	expect_eq(capped["health"], 80.0, "repair stops at max")


func test_unit_health_boundaries() -> void:
	var u := _qa().use("unit_health", HEALTH)
	if u == null:
		return
	var fresh: Dictionary = u.call("new_unit", 80.0)
	var exact: Dictionary = u.call("damage", fresh, 80.0)
	expect_eq(exact["health"], 0.0)
	expect_false(exact["alive"], "exactly lethal is dead")
	var over: Dictionary = u.call("damage", fresh, 500.0)
	expect_eq(over["health"], 0.0, "never negative")
	expect_false(over["alive"])
	expect_true(u.call("damage", fresh, 79.5)["alive"], "0.5 left is alive")
	expect_true(QaSeam.same(u.call("damage", fresh, 0.0), fresh), "zero damage changes nothing")
	expect_true(QaSeam.same(u.call("damage", fresh, -10.0), fresh), "negative damage does not heal")
	expect_true(QaSeam.same(u.call("repair", fresh, -10.0), fresh), "negative repair does not hurt")
	expect_true(QaSeam.same(u.call("repair", fresh, 0.0), fresh), "zero repair changes nothing")


func test_a_dead_unit_stays_dead() -> void:
	var u := _qa().use("unit_health", HEALTH)
	if u == null:
		return
	var dead: Dictionary = u.call("damage", u.call("new_unit", 80.0), 80.0)
	expect_true(QaSeam.same(u.call("repair", dead, 40.0), dead), "repair does not revive")
	expect_true(QaSeam.same(u.call("damage", dead, 5.0), dead), "more damage changes nothing")


# ---------------------------------------------------------------- lit area

func test_lit_area_bonus_inside_on_the_edge_and_outside() -> void:
	var l := _qa().use("lit_area", LIT)
	if l == null:
		return
	var enemy := Vector2.ZERO
	# (60,80) is exactly 100 away (3-4-5 scaled by 20).
	expect_eq(l.call("damage_for", 10.0, enemy, [Vector2(60, 80)], 100.0, 0.5), 15.0, "on the edge counts as lit")
	expect_eq(l.call("damage_for", 10.0, enemy, [Vector2(30, 40)], 100.0, 0.5), 15.0, "well inside")
	expect_eq(l.call("damage_for", 10.0, enemy, [Vector2(60, 80.5)], 100.0, 0.5), 10.0, "just outside")
	expect_eq(l.call("damage_for", 10.0, enemy, [Vector2(600, 800)], 100.0, 0.5), 10.0, "far outside")


func test_lit_area_does_not_stack_and_uses_any_post() -> void:
	var l := _qa().use("lit_area", LIT)
	if l == null:
		return
	var posts := [Vector2(600, 800), Vector2(30, 40), Vector2(-30, -40)]
	expect_eq(l.call("damage_for", 10.0, Vector2.ZERO, posts, 100.0, 0.5), 15.0, "one far post and two near ones: bonus once")


func test_lit_area_zero_bonus_no_posts_and_radius_zero() -> void:
	var l := _qa().use("lit_area", LIT)
	if l == null:
		return
	expect_eq(l.call("damage_for", 10.0, Vector2.ZERO, [Vector2(30, 40)], 100.0, 0.0), 10.0, "zero bonus is base damage")
	expect_eq(l.call("damage_for", 10.0, Vector2.ZERO, [], 100.0, 0.5), 10.0, "no posts is base damage")
	expect_eq(l.call("damage_for", 10.0, Vector2.ZERO, [Vector2(1, 0)], 0.0, 0.5), 10.0, "radius 0 lights nothing away from the post")
	expect_eq(l.call("damage_for", 10.0, Vector2.ZERO, [Vector2.ZERO], 0.0, 0.5), 15.0, "radius 0 still lights the post's own spot")
	expect_eq(l.call("damage_for", 0.0, Vector2.ZERO, [Vector2.ZERO], 100.0, 0.5), 0.0, "zero base stays zero")


func test_lit_area_pack_values() -> void:
	var l := _qa().use("lit_area", LIT)
	if l == null:
		return
	for ok in [[100.0, 0.5], [0.0, 0.0], [100, 1], [0.5, 0.0]]:
		expect_eq(l.call("validate", ok[0], ok[1]), PackedStringArray(), "valid: %s" % [ok])
	var bad := {
		"negative radius": [-1.0, 0.5],
		"negative bonus": [100.0, -0.1],
		"string radius": ["100", 0.5],
		"null bonus": [100.0, null],
		"null radius": [null, 0.5],
	}
	for label in bad:
		var errors: PackedStringArray = l.call("validate", bad[label][0], bad[label][1])
		expect_true(errors.size() >= 1, label + " must be rejected")
		for message in errors:
			expect_ne(message, "", label + ": every error says something")


# ---------------------------------------------------------------- wiring

func test_the_game_actually_uses_these_rules() -> void:
	var qa := _qa()
	for entry in [["enemy_targeting", TARGETING, "EnemyTargeting"], ["unit_health", HEALTH, "UnitHealth"], ["lit_area", LIT, "LitArea"]]:
		if not qa.check(entry[0], ResourceLoader.exists(entry[1]), entry[1]):
			continue
		var hits := QaSeam.mentions_outside("res://scripts", entry[1], PackedStringArray([entry[2], entry[1].get_file()]))
		expect_true(hits.size() >= 1, "no script under res://scripts uses %s, so the wiring is missing" % entry[2])
