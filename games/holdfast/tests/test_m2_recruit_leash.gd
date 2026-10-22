extends KitTestCase
## HF-M2-17 Recruits that move: strict tests written before the build (Head of QA, M2).
##
## Seam proposed by QA (the Gameplay Engineer may rename it, but must tell QA before
## the build starts so the tests follow). A pure static on plain data, no nodes:
##
##   res://scripts/rules/recruit_leash.gd   class_name RecruitLeash
##
##   static step(r: Dictionary, enemies: Array, dt: float) -> Dictionary
##       r (all keys always present): {role: String, home: Vector2, pos: Vector2,
##         leash: float, speed: float, range: float, health: float, max_health: float,
##         retreat_below: float, downed: bool, staffing: bool}
##       enemies: positions (Vector2). Returns a new Recruit with pos moved and
##       mode set to "hold", "engage", "retreat" or "down". Other fields are kept.
##       The Recruit passed in is never changed.
##   static validate(leash: Variant, speed: Variant, range_: Variant, retreat_below: Variant) -> PackedStringArray
##       Pack check: leash, speed and range are numbers at or above zero (zero allowed);
##       retreat_below is a number from 0 to 1.
##
## Rules pinned here (QA's reading of HF-M2-17; the Head of Engineering rules on any that is wrong):
##   - A downed Recruit does not move: mode "down", pos unchanged.
##   - A staffing Recruit never engages and never leaves its post: it walks to home at
##     speed if it is away (mode "retreat"), and is "hold" once there. It stays up, so it
##     still adds its role effect (RecruitRules.post_effects).
##   - Hurt means health / max_health strictly below retreat_below: the Recruit walks to
##     home (mode "retreat"), even with an enemy in range, and is "hold" once there.
##   - Otherwise the Recruit engages the nearest enemy to ITSELF among those within leash
##     of HOME (edge included). It moves straight at it by speed * dt, stopping at `range`
##     from the enemy, never past it. Mode "engage" (also when already in range and not moving).
##   - No enemy within leash of home: walk back to home (mode "retreat"), "hold" once there.
##   - Retreating never overshoots home. dt of zero or less moves nothing.
##   - A Recruit that starts inside its leash never ends a step outside it.
##
## Worked numbers: home (0,0), leash 100, speed 10, range 5, retreat_below 0.25. The point
## (60,80) is exactly 100 from home (3-4-5 triangle scaled by 20).

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const SEAM := "res://scripts/rules/recruit_leash.gd"
const NEAR := 0.001


func _seam() -> GDScript:
	return QaSeam.new(self, "res://tests/qa_pending.json").use("recruit_leash", SEAM)


func _unit(changes: Dictionary = {}) -> Dictionary:
	var u := {
		"role": "warden", "home": Vector2.ZERO, "pos": Vector2.ZERO, "leash": 100.0, "speed": 10.0,
		"range": 5.0, "health": 40.0, "max_health": 40.0, "retreat_below": 0.25,
		"downed": false, "staffing": false,
	}
	u.merge(changes, true)
	return u


func _at(result: Dictionary, expected: Vector2, message: String) -> void:
	var pos: Vector2 = result["pos"]
	expect_true(pos.distance_to(expected) <= NEAR, "%s: expected %s, got %s" % [message, expected, pos])


# ---------------------------------------------------------------- the leash boundary

func test_an_enemy_exactly_at_the_leash_is_engaged() -> void:
	var rl := _seam()
	if rl == null:
		return
	var out: Dictionary = rl.call("step", _unit(), [Vector2(60, 80)], 1.0)
	expect_eq(out["mode"], "engage", "100 from home with a leash of 100 is in range")
	_at(out, Vector2(6, 8), "10 along the line to the enemy")


func test_an_enemy_just_past_the_leash_is_ignored() -> void:
	var rl := _seam()
	if rl == null:
		return
	var out: Dictionary = rl.call("step", _unit(), [Vector2(60, 80.5)], 1.0)
	expect_eq(out["mode"], "hold", "out of range and already home")
	_at(out, Vector2.ZERO, "stays at the post")


func test_the_leash_is_measured_from_home_not_from_the_recruit() -> void:
	var rl := _seam()
	if rl == null:
		return
	# The Recruit stands at (0,50). Enemy A (0,130) is 80 from the Recruit but 130 from home:
	# out of range. Enemy B (-60,-80) is 100 from home but 143 from the Recruit: in range.
	var out: Dictionary = rl.call("step", _unit({"pos": Vector2(0, 50)}), [Vector2(0, 130), Vector2(-60, -80)], 1.0)
	expect_eq(out["mode"], "engage")
	var heading: Vector2 = (out["pos"] as Vector2) - Vector2(0, 50)
	expect_true(heading.y < 0.0, "heads for B, not A: moved " + str(heading))
	var only_far: Dictionary = rl.call("step", _unit({"pos": Vector2(0, 50)}), [Vector2(0, 130)], 1.0)
	expect_eq(only_far["mode"], "retreat", "only an enemy beyond the leash: go home")
	_at(only_far, Vector2(0, 40), "10 back towards home")


func test_it_picks_the_enemy_nearest_to_itself_among_those_in_range() -> void:
	var rl := _seam()
	if rl == null:
		return
	var out: Dictionary = rl.call("step", _unit(), [Vector2(30, 40), Vector2(0, 20)], 1.0)
	_at(out, Vector2(0, 10), "the enemy 20 away, not the one 50 away")
	# Nearest to the Recruit, not to home: from (0,50), C at (0,80) is 30 away (80 from home),
	# D at (0,-70) is 120 away (70 from home). Both are inside the leash; C is the target.
	var away: Dictionary = rl.call("step", _unit({"pos": Vector2(0, 50)}), [Vector2(0, -70), Vector2(0, 80)], 1.0)
	_at(away, Vector2(0, 60), "towards C, the enemy nearest the Recruit")


func test_zero_leash_never_leaves_the_post() -> void:
	var rl := _seam()
	if rl == null:
		return
	var out: Dictionary = rl.call("step", _unit({"leash": 0.0}), [Vector2(1, 0)], 5.0)
	expect_eq(out["mode"], "hold", "an enemy 1 away is beyond a leash of 0")
	_at(out, Vector2.ZERO, "zero leash")
	var on_top: Dictionary = rl.call("step", _unit({"leash": 0.0}), [Vector2.ZERO], 5.0)
	expect_eq(on_top["mode"], "engage", "an enemy exactly on the post is in range of a zero leash")
	_at(on_top, Vector2.ZERO, "and the Recruit still does not move")


# ---------------------------------------------------------------- moving

func test_it_stops_at_its_attack_range_and_never_runs_through_the_enemy() -> void:
	var rl := _seam()
	if rl == null:
		return
	var enemy := [Vector2(0, 8)]
	var first: Dictionary = rl.call("step", _unit(), enemy, 1.0)
	_at(first, Vector2(0, 3), "8 away, range 5: only 3 of the 10 it could move")
	var second: Dictionary = rl.call("step", first, enemy, 1.0)
	_at(second, Vector2(0, 3), "already in range: stays")
	expect_eq(second["mode"], "engage")
	var huge_step: Dictionary = rl.call("step", _unit(), [Vector2(0, 60)], 100.0)
	_at(huge_step, Vector2(0, 55), "a huge dt stops 5 short, not on top of the enemy")


func test_zero_and_negative_dt_move_nothing() -> void:
	var rl := _seam()
	if rl == null:
		return
	var away := _unit({"pos": Vector2(0, 50)})
	_at(rl.call("step", away, [Vector2(0, 90)], 0.0), Vector2(0, 50), "dt 0")
	_at(rl.call("step", away, [Vector2(0, 90)], -1.0), Vector2(0, 50), "negative dt does not move backwards")


func test_the_recruit_passed_in_is_not_changed() -> void:
	var rl := _seam()
	if rl == null:
		return
	var u := _unit()
	rl.call("step", u, [Vector2(60, 80)], 1.0)
	expect_true(QaSeam.same(u, _unit()), "step returns a new Recruit")


# ---------------------------------------------------------------- hurt, downed, staffing

func test_hurt_recruits_retreat_even_with_an_enemy_in_range() -> void:
	var rl := _seam()
	if rl == null:
		return
	# 10 of 40 is 0.25, which is not below 0.25: still fights. 9.9 of 40 is below: retreats.
	var fit: Dictionary = rl.call("step", _unit({"health": 10.0, "pos": Vector2(0, 50)}), [Vector2(0, 70)], 1.0)
	expect_eq(fit["mode"], "engage", "exactly at the threshold is not hurt")
	var hurt: Dictionary = rl.call("step", _unit({"health": 9.9, "pos": Vector2(0, 50)}), [Vector2(0, 70)], 1.0)
	expect_eq(hurt["mode"], "retreat")
	_at(hurt, Vector2(0, 40), "10 back towards home")


func test_retreat_stops_at_home_and_then_holds() -> void:
	var rl := _seam()
	if rl == null:
		return
	var hurt := _unit({"health": 1.0, "pos": Vector2(0, 50)})
	var home: Dictionary = rl.call("step", hurt, [Vector2(0, 70)], 100.0)
	_at(home, Vector2.ZERO, "does not overshoot past home")
	var next: Dictionary = rl.call("step", home, [Vector2(0, 70)], 1.0)
	expect_eq(next["mode"], "hold", "at home and hurt: holds")
	_at(next, Vector2.ZERO, "stays")


func test_retreat_threshold_extremes() -> void:
	var rl := _seam()
	if rl == null:
		return
	var nearly_dead := _unit({"health": 0.5, "retreat_below": 0.0})
	expect_eq(rl.call("step", nearly_dead, [Vector2(0, 20)], 1.0)["mode"], "engage", "a threshold of 0 never retreats")
	var scratched := _unit({"health": 39.0, "retreat_below": 1.0})
	expect_eq(rl.call("step", scratched, [Vector2(0, 20)], 1.0)["mode"], "hold", "a threshold of 1 retreats unless at full health (already home: hold)")
	var full := _unit({"retreat_below": 1.0})
	expect_eq(rl.call("step", full, [Vector2(0, 20)], 1.0)["mode"], "engage", "full health is never hurt")


func test_a_downed_recruit_does_not_move() -> void:
	var rl := _seam()
	if rl == null:
		return
	var down := _unit({"downed": true, "health": 0.0, "pos": Vector2(0, 50)})
	var out: Dictionary = rl.call("step", down, [Vector2(0, 55), Vector2(60, 80)], 10.0)
	expect_eq(out["mode"], "down")
	_at(out, Vector2(0, 50), "stays where it fell, not sent home and not sent to fight")
	expect_true(out["downed"])


func test_a_staffing_recruit_stays_at_its_post_and_keeps_its_effect() -> void:
	var rl := _seam()
	if rl == null:
		return
	var post := _unit({"staffing": true})
	var out: Dictionary = rl.call("step", post, [Vector2(0, 20), Vector2(60, 80)], 10.0)
	expect_eq(out["mode"], "hold", "enemies in range do not draw it away")
	_at(out, Vector2.ZERO, "at the post")
	expect_false(out["downed"])
	var arriving: Dictionary = rl.call("step", _unit({"staffing": true, "pos": Vector2(0, 50)}), [Vector2(0, 60)], 1.0)
	expect_eq(arriving["mode"], "retreat", "assigned to a post while away: goes to it rather than fighting")
	_at(arriving, Vector2(0, 40), "at speed")
	# Still staffing after the step, so the post still gets the role's effect.
	var rr := load("res://scripts/rules/recruit_rules.gd") as GDScript
	if rr != null:
		var effects: Array = rr.call("post_effects", [out], {"warden": {"taunt": true}})
		expect_true(QaSeam.same(effects, [{"role": "warden", "effect": {"taunt": true}}]), "role effect kept: " + str(effects))


# ---------------------------------------------------------------- the leash holds over a long fight

func test_a_recruit_never_ends_a_step_outside_its_leash() -> void:
	var rl := _seam()
	if rl == null:
		return
	for range_ in [0.0, 5.0, 40.0]:
		var u := _unit({"range": range_})
		# A deterministic run of enemies sweeping in and out across the leash edge.
		for i in 300:
			var angle := float(i) * 0.7
			var radius := 20.0 + float((i * 37) % 110)  # 20 to 129: some inside the leash, some beyond
			var enemy := Vector2(cos(angle), sin(angle)) * radius
			u = rl.call("step", u, [enemy], 0.5)
			var away := (u["pos"] as Vector2).distance_to(u["home"])
			expect_true(away <= 100.0 + NEAR, "range %s, step %d: %s from home" % [range_, i, away])
			if away > 100.0 + NEAR:
				return


# ---------------------------------------------------------------- pack values

func test_pack_values() -> void:
	var rl := _seam()
	if rl == null:
		return
	for ok in [[100.0, 10.0, 5.0, 0.25], [0.0, 10.0, 0.0, 0.0], [100, 10, 5, 1], [0, 0, 0, 0.5]]:
		expect_eq(rl.call("validate", ok[0], ok[1], ok[2], ok[3]), PackedStringArray(), "valid: %s" % [ok])
	var bad := {
		"negative leash": [-1.0, 10.0, 5.0, 0.25],
		"negative speed": [100.0, -1.0, 5.0, 0.25],
		"negative range": [100.0, 10.0, -1.0, 0.25],
		"retreat above 1": [100.0, 10.0, 5.0, 1.5],
		"retreat below 0": [100.0, 10.0, 5.0, -0.1],
		"a string leash": ["100", 10.0, 5.0, 0.25],
		"a null speed": [100.0, null, 5.0, 0.25],
		"a null retreat": [100.0, 10.0, 5.0, null],
	}
	for label in bad:
		var args: Array = bad[label]
		var errors: PackedStringArray = rl.call("validate", args[0], args[1], args[2], args[3])
		expect_true(errors.size() >= 1, label + " must be rejected")
		for message in errors:
			expect_ne(message, "", label + ": every error says something")


# ---------------------------------------------------------------- wiring

func test_the_game_actually_moves_recruits_with_the_leash_rules() -> void:
	var qa := QaSeam.new(self, "res://tests/qa_pending.json")
	if not qa.check("recruit_leash", ResourceLoader.exists(SEAM), SEAM):
		return
	var hits := QaSeam.mentions_outside("res://scripts", SEAM, PackedStringArray(["RecruitLeash", "recruit_leash.gd"]))
	expect_true(hits.size() >= 1, "no script under res://scripts uses RecruitLeash, so Recruits still do not move")
