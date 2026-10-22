extends KitTestCase
## HF-M2-18 The Hero gets back up where they fell: strict tests written before the build (Head of QA, M2).
##
## Seam proposed by QA (the Gameplay Engineer names it for real: tell QA before the build
## starts and the tests follow). Pure statics on plain data, no nodes. The wait itself is
## HeroKnockdown's (built, unchanged); this module adds where the Hero rises and the grace.
##
##   res://scripts/rules/hero_getup.gd   class_name HeroGetUp
##
##   static start_fall(hero_pos: Vector2, unbanked_xp: int) -> Dictionary
##       {fell_at, drop_pos, drop_amount}: the Hero's fall point, and the unbanked XP dropped
##       there. A negative amount counts as 0.
##   static rise(fell_at: Vector2, playfield: Rect2, blocked: Array, grace_time: float) -> Dictionary
##       {pos, grace_left}. pos is fell_at when that is open ground inside the playfield;
##       otherwise the nearest open point inside the playfield. grace_left = grace_time.
##       playfield: every edge counts as inside. blocked: Array of Rect2; only the INTERIOR of
##       a blocked Rect2 is blocked, so its edges are open ground. "Nearest" is straight-line.
##       When two points are equally near any one of them will do.
##   static tick_grace(grace_left: float, dt: float) -> float
##       Counts down, never below 0; dt of 0 or less changes nothing.
##   static take_damage(state: Dictionary, damage: float, delays: Array, grace_left: float) -> Dictionary
##       While grace_left is above 0 the Hero is untouchable: state returned unchanged. At 0
##       it is HeroKnockdown.take_damage(state, damage, delays). A hit in grace is not
##       remembered afterwards and never counts as a knock-down.
##   static validate_grace(v: Variant) -> PackedStringArray
##       Pack check: a finite number at or above zero (zero allowed).
##
## Rules pinned: same wait (HeroKnockdown) and same XP drop as before, but where the Hero fell
## and not at the keep; untouchable for grace_time, hits land again from exactly the end of it.
## Worked numbers: delays [3, 6, 10], playfield (0,0)-(100,100), grace 2.0 (ticks of 0.25 and
## 1.5 are exact in floating point).

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const SEAM := "res://scripts/rules/hero_getup.gd"
const DELAYS := [3, 6, 10]
const FIELD := Rect2(0, 0, 100, 100)
const NEAR := 0.001


func _seam() -> GDScript:
	return QaSeam.new(self, "res://tests/qa_pending.json").use("hero_getup", SEAM)


func _rise(hg: GDScript, fell: Vector2, blocked: Array = [], grace: float = 2.0) -> Dictionary:
	return hg.call("rise", fell, FIELD, blocked, grace)


func _at(result: Dictionary, expected: Vector2, message: String) -> void:
	var pos: Vector2 = result["pos"]
	expect_true(pos.distance_to(expected) <= NEAR, "%s: expected %s, got %s" % [message, expected, pos])


func _open_and_inside(pos: Vector2, blocked: Array) -> bool:
	if pos.x < -NEAR or pos.y < -NEAR or pos.x > 100.0 + NEAR or pos.y > 100.0 + NEAR:
		return false
	for rect: Rect2 in blocked:
		var inner := rect.grow(-NEAR)
		if inner.has_point(pos):
			return false
	return true


# ---------------------------------------------------------------- the fall

func test_the_fall_records_where_and_how_much_xp_drops() -> void:
	var hg := _seam()
	if hg == null:
		return
	var fall: Dictionary = hg.call("start_fall", Vector2(30, 40), 25)
	expect_true(QaSeam.has_fields(fall, {"fell_at": Vector2(30, 40), "drop_pos": Vector2(30, 40), "drop_amount": 25}), str(fall))
	expect_eq(hg.call("start_fall", Vector2(30, 40), 0)["drop_amount"], 0, "nothing unbanked, nothing dropped")
	expect_eq(hg.call("start_fall", Vector2(30, 40), -5)["drop_amount"], 0, "never a negative drop")


# ---------------------------------------------------------------- where the Hero rises

func test_open_ground_inside_the_field_is_where_they_fell() -> void:
	var hg := _seam()
	if hg == null:
		return
	_at(_rise(hg, Vector2(30, 40)), Vector2(30, 40), "open ground")
	_at(_rise(hg, Vector2(100, 50)), Vector2(100, 50), "on the playfield edge is inside")
	_at(_rise(hg, Vector2(0, 0)), Vector2(0, 0), "in the corner")
	_at(_rise(hg, Vector2(30, 40), [Rect2(60, 60, 10, 10)]), Vector2(30, 40), "a blocked area elsewhere does not matter")


func test_outside_the_field_is_the_nearest_point_inside() -> void:
	var hg := _seam()
	if hg == null:
		return
	_at(_rise(hg, Vector2(-30, 50)), Vector2(0, 50), "left of the field")
	_at(_rise(hg, Vector2(50, -5)), Vector2(50, 0), "above the field")
	_at(_rise(hg, Vector2(120, 130)), Vector2(100, 100), "beyond a corner")


func test_blocked_ground_moves_them_to_the_nearest_edge() -> void:
	var hg := _seam()
	if hg == null:
		return
	var wall := Rect2(20, 20, 20, 20)  # x 20 to 40, y 20 to 40
	# (25,30): left edge 5 away, right 15, top 10, bottom 10.
	_at(_rise(hg, Vector2(25, 30), [wall]), Vector2(20, 30), "nearest edge")
	_at(_rise(hg, Vector2(20, 30), [wall]), Vector2(20, 30), "standing on the edge is open ground")
	var centre: Dictionary = _rise(hg, Vector2(30, 30), [wall])
	expect_true(_open_and_inside(centre["pos"], [wall]), "dead centre: some open edge, got " + str(centre["pos"]))
	expect_true((centre["pos"] as Vector2).distance_to(Vector2(30, 30)) <= 10.0 + NEAR, "and no further than the nearest edge")


func test_the_nearest_open_ground_must_be_inside_the_field() -> void:
	var hg := _seam()
	if hg == null:
		return
	# Blocked x -20 to 40: the nearest edge (x = -20, 25 away) is outside the field.
	var wall := Rect2(-20, 0, 60, 100)
	_at(_rise(hg, Vector2(5, 50), [wall]), Vector2(40, 50), "the far edge, which is inside the field")


func test_nearest_open_ground_skips_edges_that_are_blocked_by_another_area() -> void:
	var hg := _seam()
	if hg == null:
		return
	var a := Rect2(20, 20, 20, 20)  # x 20 to 40, y 20 to 40
	var b := Rect2(20, 10, 40, 40)  # x 20 to 60, y 10 to 50: covers a's right, top and bottom edges; a's left edge is also b's, so open
	_at(_rise(hg, Vector2(38, 30), [a, b]), Vector2(20, 30), "left edge of the first area, 18 away")
	_at(_rise(hg, Vector2(38, 30), [b, a]), Vector2(20, 30), "and the same whichever order the areas are listed in")


func test_a_hero_who_fell_outside_and_blocked_still_ends_on_open_ground() -> void:
	var hg := _seam()
	if hg == null:
		return
	var wall := Rect2(-10, 40, 30, 20)  # x -10 to 20, y 40 to 60: reaches past the field's left edge
	var blocked := [wall]
	var result: Dictionary = _rise(hg, Vector2(-30, 50), blocked)
	expect_true(_open_and_inside(result["pos"], blocked), "got " + str(result["pos"]))


func test_rise_reports_the_grace_and_does_not_touch_its_inputs() -> void:
	var hg := _seam()
	if hg == null:
		return
	var blocked := [Rect2(20, 20, 20, 20)]
	expect_eq(_rise(hg, Vector2(30, 40), blocked, 2.0)["grace_left"], 2.0)
	expect_eq(_rise(hg, Vector2(30, 40), blocked, 0.0)["grace_left"], 0.0, "zero is allowed")
	expect_eq(blocked.size(), 1)
	expect_true(QaSeam.same(blocked[0], Rect2(20, 20, 20, 20)), "the blocked list is untouched")


# ---------------------------------------------------------------- the first and fourth knock-down

func test_first_and_fourth_knockdown_keep_the_wait_and_drop_xp_where_they_fell() -> void:
	var hg := _seam()
	if hg == null:
		return
	var keep := Vector2(50, 95)
	var falls := [Vector2(30, 40), Vector2(10, 80), Vector2(90, 10), Vector2(70, 20)]
	var xp := [25, 0, 7, 140]
	var waits := [3.0, 6.0, 10.0, 10.0]
	var state: Dictionary = HeroKnockdown.new_state(100.0)
	for i in 4:
		state = HeroKnockdown.take_damage(state, 100.0, DELAYS)
		expect_eq(state["get_up_in"], waits[i], "knock-down %d waits as before" % (i + 1))
		var fall: Dictionary = hg.call("start_fall", falls[i], xp[i])
		expect_eq(fall["drop_pos"], falls[i], "knock-down %d: XP drops where they fell" % (i + 1))
		expect_eq(fall["drop_amount"], xp[i])
		state = HeroKnockdown.tick(state, waits[i])
		expect_false(state["downed"])
		var up: Dictionary = _rise(hg, fall["fell_at"])
		_at(up, falls[i], "knock-down %d: back up where they fell" % (i + 1))
		expect_true((up["pos"] as Vector2).distance_to(keep) > 1.0, "not at the keep")


# ---------------------------------------------------------------- the untouchable time

func test_grace_counts_down_and_stops_at_zero() -> void:
	var hg := _seam()
	if hg == null:
		return
	expect_eq(hg.call("tick_grace", 2.0, 1.5), 0.5)
	expect_eq(hg.call("tick_grace", 0.5, 0.5), 0.0, "exactly used up")
	expect_eq(hg.call("tick_grace", 0.5, 9.0), 0.0, "never below zero")
	expect_eq(hg.call("tick_grace", 0.5, 0.0), 0.5, "dt 0")
	expect_eq(hg.call("tick_grace", 0.5, -1.0), 0.5, "negative dt does not add time")
	expect_eq(hg.call("tick_grace", 0.0, 1.0), 0.0)


func test_hits_during_grace_do_nothing_and_land_from_exactly_the_end() -> void:
	var hg := _seam()
	if hg == null:
		return
	var up: Dictionary = HeroKnockdown.new_state(100.0)
	var grace := 2.0
	grace = hg.call("tick_grace", grace, 1.5)
	grace = hg.call("tick_grace", grace, 0.25)
	expect_eq(grace, 0.25)
	var shielded: Dictionary = hg.call("take_damage", up, 1000.0, DELAYS, grace)
	expect_true(QaSeam.same(shielded, up), "a lethal hit in the last quarter second does nothing")
	expect_eq(shielded["knockdowns"], 0, "and is not a knock-down")
	grace = hg.call("tick_grace", grace, 0.25)
	expect_eq(grace, 0.0)
	var hit: Dictionary = hg.call("take_damage", up, 30.0, DELAYS, grace)
	expect_eq(hit["health"], 70.0, "from exactly the end of the grace hits land")
	var down: Dictionary = hg.call("take_damage", up, 1000.0, DELAYS, grace)
	expect_true(down["downed"])
	expect_eq(down["get_up_in"], 3.0)


func test_a_hit_in_grace_is_not_remembered() -> void:
	var hg := _seam()
	if hg == null:
		return
	var up: Dictionary = HeroKnockdown.new_state(100.0)
	hg.call("take_damage", up, 60.0, DELAYS, 1.0)
	var after: Dictionary = hg.call("take_damage", up, 30.0, DELAYS, 0.0)
	expect_eq(after["health"], 70.0, "the 60 absorbed in grace is not owed afterwards")


func test_zero_grace_means_no_untouchable_time() -> void:
	var hg := _seam()
	if hg == null:
		return
	var up: Dictionary = _rise(hg, Vector2(30, 40), [], 0.0)
	var hit: Dictionary = hg.call("take_damage", HeroKnockdown.new_state(100.0), 1000.0, DELAYS, up["grace_left"])
	expect_true(hit["downed"], "grace 0: the first hit after getting up lands")


func test_the_fourth_knockdown_after_grace_still_waits_ten() -> void:
	var hg := _seam()
	if hg == null:
		return
	var state: Dictionary = HeroKnockdown.new_state(100.0)
	for i in 3:
		state = HeroKnockdown.take_damage(state, 100.0, DELAYS)
		state = HeroKnockdown.tick(state, 99.0)
		var shielded: Dictionary = hg.call("take_damage", state, 100.0, DELAYS, 1.0)
		expect_true(QaSeam.same(shielded, state), "grace after knock-down %d" % (i + 1))
	var fourth: Dictionary = hg.call("take_damage", state, 100.0, DELAYS, 0.0)
	expect_eq(fourth["knockdowns"], 4)
	expect_eq(fourth["get_up_in"], 10.0, "grace changes nothing about the wait")


func test_grace_pack_values() -> void:
	var hg := _seam()
	if hg == null:
		return
	for ok in [2.0, 2, 0.0, 0, 0.5]:
		expect_eq(hg.call("validate_grace", ok), PackedStringArray(), "valid: %s" % [ok])
	var bad := {"negative": -0.5, "a string": "2", "null": null, "infinity": INF, "NaN": NAN, "a list": [2.0]}
	for label in bad:
		var errors: PackedStringArray = hg.call("validate_grace", bad[label])
		expect_true(errors.size() >= 1, label + " must be rejected")
		for message in errors:
			expect_ne(message, "", label + ": every error says something")


# ---------------------------------------------------------------- wiring

func test_the_game_actually_gets_the_hero_up_where_they_fell() -> void:
	var qa := QaSeam.new(self, "res://tests/qa_pending.json")
	if not qa.check("hero_getup", ResourceLoader.exists(SEAM), SEAM):
		return
	var hits := QaSeam.mentions_outside("res://scripts", SEAM, PackedStringArray(["HeroGetUp", "hero_getup.gd"]))
	expect_true(hits.size() >= 1, "no script under res://scripts uses HeroGetUp, so the Hero still gets up somewhere else")
