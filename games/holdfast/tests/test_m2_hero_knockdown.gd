extends KitTestCase
## HF-M2-14 Hero knock-down: strict tests written before the build (Head of QA, M2).
##
## The seam the build must provide (names are QA's; ask QA before the build if
## one has to change, never after). Pure functions on plain data, no nodes:
##
##   res://scripts/rules/hero_knockdown.gd   class_name HeroKnockdown
##
##   static delay_for(delays: Array, knockdown_number: int) -> float
##       Seconds the Hero stays down on their Nth knock-down in a run (1-based).
##       delays comes from the pack; past the end it holds the last entry.
##   static validate(delays: Variant) -> PackedStringArray
##       Pack check: empty array when fine, one message per problem otherwise.
##   static new_state(max_health: float) -> Dictionary
##       {max_health, health (= max), downed: false, knockdowns: 0, get_up_in: 0.0}
##   static take_damage(state: Dictionary, damage: float, delays: Array) -> Dictionary
##   static tick(state: Dictionary, dt: float) -> Dictionary
##       Both return a new state and never change the one passed in.
##
## States may carry extra fields (a build needs the spot where the Hero fell);
## the tests check the named ones.
##
## Rules pinned here (QA's reading of the board; the Head of Engineering rules on
## any that is wrong before the build starts):
##   - Health at or below zero knocks the Hero down once: health is clamped to 0,
##     knockdowns goes up by one, get_up_in = delay_for(delays, knockdowns).
##   - Damage while down, zero damage and negative damage change nothing.
##   - tick counts get_up_in down; at or below zero the Hero is up with full
##     health and the knock-down count is kept. A Hero who is up never regenerates.
##   - Delays: a zero is honoured (no wait), never replaced by a default.
##     An empty, negative, non-number or shrinking list is a pack error.
##
## Worked numbers use delays [5, 8, 12, 20] and max health 100.

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const SEAM := "res://scripts/rules/hero_knockdown.gd"
const DELAYS := [5, 8, 12, 20]


func _seam() -> GDScript:
	return QaSeam.new(self, "res://tests/qa_pending.json").use("hero_knockdown", SEAM)


func _same_state(a: Dictionary, b: Dictionary) -> bool:
	return QaSeam.same(a, b)


func test_delay_grows_per_knockdown_and_holds_at_the_last_entry() -> void:
	var hk := _seam()
	if hk == null:
		return
	# 1st -> index 0, 4th -> index 3 (the last), 5th and 100th hold the last.
	var expected := {1: 5.0, 2: 8.0, 3: 12.0, 4: 20.0, 5: 20.0, 100: 20.0}
	for n in expected:
		expect_eq(hk.call("delay_for", DELAYS, n), expected[n], "knock-down %d" % n)


func test_delay_edge_lists() -> void:
	var hk := _seam()
	if hk == null:
		return
	expect_eq(hk.call("delay_for", [7], 1), 7.0, "one entry, first")
	expect_eq(hk.call("delay_for", [7], 4), 7.0, "one entry, fourth")
	expect_eq(hk.call("delay_for", [0, 0], 1), 0.0, "zero is honoured, not replaced by a default")
	expect_eq(hk.call("delay_for", [0, 0], 2), 0.0)
	expect_eq(hk.call("delay_for", [0, 10], 1), 0.0, "a zero first delay, then a wait")
	expect_eq(hk.call("delay_for", [0, 10], 2), 10.0)
	expect_eq(hk.call("delay_for", [2.5, 4.25], 2), 4.25, "fractions pass through")


func test_pack_values_that_are_valid() -> void:
	var hk := _seam()
	if hk == null:
		return
	for ok in [[5], [5, 5], [0], [0, 0, 10], [5, 8, 12, 20], [0.5, 1.5]]:
		expect_eq(hk.call("validate", ok), PackedStringArray(), "valid: %s" % [ok])


func test_pack_values_that_are_errors() -> void:
	var hk := _seam()
	if hk == null:
		return
	var bad := {
		"empty list": [],
		"negative": [-1],
		"negative later": [5, -2],
		"shrinks": [5, 3],
		"a string": ["5"],
		"a null": [5, null],
		"not a list (null)": null,
		"not a list (number)": 5,
		"not a list (string)": "5, 8",
	}
	for label in bad:
		var errors: PackedStringArray = hk.call("validate", bad[label])
		expect_true(errors.size() >= 1, label + " must be rejected")
		for message in errors:
			expect_ne(message, "", label + ": every error says something")


func test_damage_below_lethal_just_hurts() -> void:
	var hk := _seam()
	if hk == null:
		return
	var start: Dictionary = hk.call("new_state", 100.0)
	expect_true(QaSeam.has_fields(start, {"max_health": 100.0, "health": 100.0, "downed": false, "knockdowns": 0, "get_up_in": 0.0}), "fresh state: " + str(start))
	var hurt: Dictionary = hk.call("take_damage", start, 30.0, DELAYS)
	expect_true(QaSeam.has_fields(hurt, {"max_health": 100.0, "health": 70.0, "downed": false, "knockdowns": 0, "get_up_in": 0.0}), str(hurt))
	expect_eq(start["health"], 100.0, "the state passed in is not changed")
	var almost: Dictionary = hk.call("take_damage", start, 99.5, DELAYS)
	expect_eq(almost["health"], 0.5)
	expect_false(almost["downed"], "0.5 health left is not down")


func test_exactly_lethal_and_overkill_knock_down_once() -> void:
	var hk := _seam()
	if hk == null:
		return
	var start: Dictionary = hk.call("new_state", 100.0)
	for damage in [100.0, 250.0, 100.0000001]:
		var down: Dictionary = hk.call("take_damage", start, damage, DELAYS)
		expect_true(down["downed"], "damage %s knocks down (zero health counts)" % damage)
		expect_eq(down["health"], 0.0, "health clamps at zero, never negative")
		expect_eq(down["knockdowns"], 1)
		expect_eq(down["get_up_in"], 5.0, "first knock-down waits delays[0]")


func test_damage_that_changes_nothing() -> void:
	var hk := _seam()
	if hk == null:
		return
	var up: Dictionary = hk.call("take_damage", hk.call("new_state", 100.0), 30.0, DELAYS)
	expect_true(_same_state(hk.call("take_damage", up, 0.0, DELAYS), up), "zero damage")
	expect_true(_same_state(hk.call("take_damage", up, -30.0, DELAYS), up), "negative damage must not heal")
	var down: Dictionary = hk.call("take_damage", up, 70.0, DELAYS)
	expect_true(down["downed"])
	expect_true(_same_state(hk.call("take_damage", down, 40.0, DELAYS), down), "hits while down do not count as another knock-down or restart the wait")


func test_tick_counts_down_then_gets_up_with_full_health() -> void:
	var hk := _seam()
	if hk == null:
		return
	var down: Dictionary = hk.call("take_damage", hk.call("new_state", 100.0), 100.0, DELAYS)
	var waiting: Dictionary = hk.call("tick", down, 2.0)
	expect_true(waiting["downed"])
	expect_eq(waiting["get_up_in"], 3.0)
	expect_eq(waiting["health"], 0.0, "no health while down")
	var up: Dictionary = hk.call("tick", waiting, 3.0)
	expect_false(up["downed"], "exactly zero left: up")
	expect_eq(up["health"], 100.0, "back at the keep with full health")
	expect_eq(up["get_up_in"], 0.0)
	expect_eq(up["knockdowns"], 1, "the count is kept")
	var overshoot: Dictionary = hk.call("tick", waiting, 10.0)
	expect_false(overshoot["downed"])
	expect_eq(overshoot["get_up_in"], 0.0, "the timer never goes negative")
	expect_true(_same_state(hk.call("tick", waiting, 0.0), waiting), "dt of zero changes nothing")


func test_a_hero_who_is_up_never_regenerates() -> void:
	var hk := _seam()
	if hk == null:
		return
	var hurt: Dictionary = hk.call("take_damage", hk.call("new_state", 100.0), 30.0, DELAYS)
	expect_true(_same_state(hk.call("tick", hurt, 5.0), hurt), "tick is only about getting up")


func test_four_knockdowns_in_one_run_wait_5_8_12_then_20() -> void:
	var hk := _seam()
	if hk == null:
		return
	var state: Dictionary = hk.call("new_state", 100.0)
	var expected_waits := [5.0, 8.0, 12.0, 20.0, 20.0]
	for i in expected_waits.size():
		state = hk.call("take_damage", state, 100.0, DELAYS)
		expect_eq(state["knockdowns"], i + 1)
		expect_eq(state["get_up_in"], expected_waits[i], "knock-down %d" % (i + 1))
		state = hk.call("tick", state, expected_waits[i])
		expect_false(state["downed"], "up again after waiting %s" % expected_waits[i])
		expect_eq(state["health"], 100.0)
	expect_eq(state["knockdowns"], 5, "the count survives every get-up")


func test_zero_delays_get_up_on_the_first_tick() -> void:
	var hk := _seam()
	if hk == null:
		return
	var down: Dictionary = hk.call("take_damage", hk.call("new_state", 100.0), 100.0, [0, 0])
	expect_true(down["downed"], "still counts as a knock-down")
	expect_eq(down["get_up_in"], 0.0)
	var up: Dictionary = hk.call("tick", down, 0.1)
	expect_false(up["downed"])
	expect_eq(up["health"], 100.0)


func test_the_rules_actually_use_the_knockdown_module() -> void:
	var qa := QaSeam.new(self, "res://tests/qa_pending.json")
	if not qa.check("hero_knockdown", ResourceLoader.exists(SEAM), SEAM):
		return
	var hits := QaSeam.mentions_outside("res://scripts", SEAM, PackedStringArray(["HeroKnockdown", "hero_knockdown.gd"]))
	expect_true(hits.size() >= 1, "no script under res://scripts calls HeroKnockdown, so the wiring is missing")
