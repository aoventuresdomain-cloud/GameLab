extends KitTestCase
## HF-M2-15 slice 2 Recruit rules: strict tests written before the build (Head of QA, M2).
##
## Seam the build must provide (pure statics on plain data, no nodes):
##
##   res://scripts/rules/recruit_rules.gd   class_name RecruitRules
##
##   static new_recruit(role: String, max_health: float) -> Dictionary
##       {role, max_health, health (= max), downed: false, revive_progress: 0.0}
##   static damage(r: Dictionary, amount: float) -> Dictionary
##       Health at or below zero means downed: health 0, downed true, revive_progress 0.
##       A downed Recruit is not changed by further hits; zero and negative amounts change nothing.
##   static standing(hero_pos: Vector2, recruit_pos: Vector2, radius: float) -> bool
##       The Hero is "standing on" a Recruit within radius, edge included.
##   static tick_revive(r: Dictionary, hero_on: bool, dt: float, revive_time: float) -> Dictionary
##       Only a downed Recruit changes. While hero_on, revive_progress grows by dt (dt at or
##       below zero adds nothing); progress at or above revive_time revives: downed false,
##       health above 0 and at most max_health, revive_progress 0. When the Hero is not on
##       the Recruit the progress drops back to 0 (stepping off loses it). A revive_time of 0
##       revives on the first tick with the Hero on, even with dt 0, and never without the Hero.
##   static validate_revive_time(v: Variant) -> PackedStringArray
##       Pack check: a number at or above zero (zero allowed).
##   static pick_target(enemy_pos: Vector2, candidates: Array, tie_order: Array) -> String
##       candidates: [{id, pos, taunt_radius: float, downed: bool}] (all four keys always present).
##       Downed candidates are never targeted. If any candidate has taunt_radius above 0 and
##       the enemy is within it (edge included), the enemy goes for the nearest such taunter;
##       otherwise for the nearest candidate. Ties follow tie_order, then the smaller id, as in
##       EnemyTargeting. Nothing left to target returns "".
##   static post_effects(staff: Array, role_effects: Dictionary) -> Array
##       The effects a light post gets from the Recruits staffing it, in staff order:
##       [{role, effect}], effect being a copy of role_effects[role]. Downed Recruits and roles
##       missing from the pack add nothing. An empty post gives [].
##   static validate_effects(role_effects: Variant, roles: Array) -> PackedStringArray
##       Pack check: every role in roles has a non-empty Dictionary of effects.
##
## Worked numbers: revive_time 3.0 with ticks of 0.5 and 2.75 (both exact in floating point);
## 3-4-5 triangles for distances.

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const SEAM := "res://scripts/rules/recruit_rules.gd"
const EFFECTS := {
	"warden": {"taunt": true},
	"lookout": {"mark": true, "slow": 0.5},
	"alchemist": {"field": "burn"},
	"engineer": {"repair": 5.0},
}


func _seam() -> GDScript:
	return QaSeam.new(self, "res://tests/qa_pending.json").use("recruit_rules", SEAM)


func _down(rr: GDScript, role: String = "warden") -> Dictionary:
	return rr.call("damage", rr.call("new_recruit", role, 40.0), 40.0)


func _cand(id: String, x: float, y: float, taunt: float = 0.0, downed: bool = false) -> Dictionary:
	return {"id": id, "pos": Vector2(x, y), "taunt_radius": taunt, "downed": downed}


# ---------------------------------------------------------------- going down

func test_a_recruit_goes_down_at_zero_health_and_not_before() -> void:
	var rr := _seam()
	if rr == null:
		return
	var fresh: Dictionary = rr.call("new_recruit", "warden", 40.0)
	expect_true(QaSeam.has_fields(fresh, {"role": "warden", "max_health": 40.0, "health": 40.0, "downed": false, "revive_progress": 0.0}), str(fresh))
	var hurt: Dictionary = rr.call("damage", fresh, 39.5)
	expect_false(hurt["downed"], "0.5 left is still up")
	expect_eq(hurt["health"], 0.5)
	var exact: Dictionary = rr.call("damage", fresh, 40.0)
	expect_true(exact["downed"], "exactly lethal is down")
	expect_eq(exact["health"], 0.0)
	var over: Dictionary = rr.call("damage", fresh, 900.0)
	expect_eq(over["health"], 0.0, "never negative")
	expect_eq(fresh["health"], 40.0, "the Recruit passed in is not changed")


func test_damage_that_changes_nothing() -> void:
	var rr := _seam()
	if rr == null:
		return
	var fresh: Dictionary = rr.call("new_recruit", "warden", 40.0)
	expect_true(QaSeam.same(rr.call("damage", fresh, 0.0), fresh), "zero damage")
	expect_true(QaSeam.same(rr.call("damage", fresh, -5.0), fresh), "negative damage does not heal")
	var down := _down(rr)
	expect_true(QaSeam.same(rr.call("damage", down, 10.0), down), "a downed Recruit stays as it was")


# ---------------------------------------------------------------- reviving

func test_the_hero_must_stand_on_them_for_the_whole_time() -> void:
	var rr := _seam()
	if rr == null:
		return
	var r := _down(rr)
	for i in 5:
		r = rr.call("tick_revive", r, true, 0.5, 3.0)
		expect_true(r["downed"], "after %s s on them: still down" % (0.5 * (i + 1)))
	r = rr.call("tick_revive", r, true, 0.5, 3.0)
	expect_false(r["downed"], "exactly 3 s is enough")
	expect_true(r["health"] > 0.0 and r["health"] <= 40.0, "back on their feet: " + str(r["health"]))
	expect_eq(r["revive_progress"], 0.0)
	expect_eq(r["role"], "warden", "still the same Recruit")


func test_one_big_step_and_one_step_short() -> void:
	var rr := _seam()
	if rr == null:
		return
	expect_false(rr.call("tick_revive", _down(rr), true, 3.0, 3.0)["downed"], "a single 3 s step revives")
	expect_false(rr.call("tick_revive", _down(rr), true, 10.0, 3.0)["downed"], "overshoot revives")
	expect_true(rr.call("tick_revive", _down(rr), true, 2.75, 3.0)["downed"], "2.75 s is not enough")


func test_stepping_off_just_short_loses_the_progress() -> void:
	var rr := _seam()
	if rr == null:
		return
	var r: Dictionary = rr.call("tick_revive", _down(rr), true, 2.75, 3.0)
	expect_true(r["downed"])
	r = rr.call("tick_revive", r, false, 0.5, 3.0)
	expect_eq(r["revive_progress"], 0.0, "the Hero stepped off: back to nothing")
	r = rr.call("tick_revive", r, true, 0.5, 3.0)
	expect_true(r["downed"], "0.5 s more must not finish a revive that was lost")
	r = rr.call("tick_revive", r, true, 2.75, 3.0)
	expect_false(r["downed"], "0.5 + 2.75 on a fresh start does finish")


func test_hero_away_never_revives_even_for_a_long_time() -> void:
	var rr := _seam()
	if rr == null:
		return
	var r := _down(rr)
	for i in 100:
		r = rr.call("tick_revive", r, false, 1.0, 3.0)
	expect_true(r["downed"], "downed for the rest of the run unless the Hero stands on them")
	expect_eq(r["revive_progress"], 0.0)


func test_zero_and_negative_steps_add_nothing() -> void:
	var rr := _seam()
	if rr == null:
		return
	var r: Dictionary = rr.call("tick_revive", _down(rr), true, 1.0, 3.0)
	expect_true(QaSeam.same(rr.call("tick_revive", r, true, 0.0, 3.0), r), "dt 0")
	expect_true(QaSeam.same(rr.call("tick_revive", r, true, -1.0, 3.0), r), "negative dt does not undo progress")


func test_zero_revive_time_needs_the_hero_but_no_waiting() -> void:
	var rr := _seam()
	if rr == null:
		return
	expect_false(rr.call("tick_revive", _down(rr), true, 0.0, 0.0)["downed"], "Hero on them, zero time: up at once")
	expect_false(rr.call("tick_revive", _down(rr), true, 0.1, 0.0)["downed"])
	expect_true(rr.call("tick_revive", _down(rr), false, 5.0, 0.0)["downed"], "zero time is not 'revive without the Hero'")


func test_a_recruit_who_is_up_is_never_changed_by_the_revive_tick() -> void:
	var rr := _seam()
	if rr == null:
		return
	var hurt: Dictionary = rr.call("damage", rr.call("new_recruit", "archer", 40.0), 10.0)
	expect_true(QaSeam.same(rr.call("tick_revive", hurt, true, 5.0, 3.0), hurt), "no healing by standing on a Recruit who is up")


func test_two_downed_at_once_are_revived_independently() -> void:
	var rr := _seam()
	if rr == null:
		return
	var a := _down(rr, "warden")
	var b := _down(rr, "engineer")
	# The Hero stands on A for 2.5 s, then walks to B for 3.0 s.
	a = rr.call("tick_revive", a, true, 2.5, 3.0)
	b = rr.call("tick_revive", b, false, 2.5, 3.0)
	expect_eq(b["revive_progress"], 0.0, "B got nothing while the Hero was on A")
	a = rr.call("tick_revive", a, false, 3.0, 3.0)
	b = rr.call("tick_revive", b, true, 3.0, 3.0)
	expect_false(b["downed"], "B is up")
	expect_true(a["downed"], "A lost its progress when the Hero left, and is still down")
	expect_eq(a["revive_progress"], 0.0)
	# Standing where both overlap revives both on the same schedule.
	var c := _down(rr)
	var d := _down(rr)
	for i in 6:
		c = rr.call("tick_revive", c, true, 0.5, 3.0)
		d = rr.call("tick_revive", d, true, 0.5, 3.0)
	expect_false(c["downed"])
	expect_false(d["downed"])


func test_a_revived_recruit_can_fall_and_be_revived_again() -> void:
	var rr := _seam()
	if rr == null:
		return
	var up: Dictionary = rr.call("tick_revive", _down(rr), true, 3.0, 3.0)
	expect_false(up["downed"])
	var again: Dictionary = rr.call("damage", up, 1000.0)
	expect_true(again["downed"], "a revived Recruit can be knocked out again")
	expect_eq(again["revive_progress"], 0.0)
	expect_false(rr.call("tick_revive", again, true, 3.0, 3.0)["downed"])


func test_standing_on_is_by_distance_edge_included() -> void:
	var rr := _seam()
	if rr == null:
		return
	# (30,40) is exactly 50 from the origin.
	expect_true(rr.call("standing", Vector2.ZERO, Vector2(30, 40), 50.0), "on the edge")
	expect_false(rr.call("standing", Vector2.ZERO, Vector2(30, 40.5), 50.0), "just outside")
	expect_true(rr.call("standing", Vector2(7, 7), Vector2(7, 7), 0.0), "radius 0 still counts the same spot")
	expect_false(rr.call("standing", Vector2.ZERO, Vector2(1, 0), 0.0))


func test_revive_time_pack_values() -> void:
	var rr := _seam()
	if rr == null:
		return
	for ok in [3.0, 3, 0.0, 0, 0.5]:
		expect_eq(rr.call("validate_revive_time", ok), PackedStringArray(), "valid: %s" % [ok])
	var bad := {"negative": -1.0, "a string": "3", "null": null, "a list": [3.0]}
	for label in bad:
		var errors: PackedStringArray = rr.call("validate_revive_time", bad[label])
		expect_true(errors.size() >= 1, label + " must be rejected")
		for message in errors:
			expect_ne(message, "", label + ": every error says something")


# ---------------------------------------------------------------- taunt

func test_a_wardens_taunt_pulls_enemies_from_a_nearer_tower() -> void:
	var rr := _seam()
	if rr == null:
		return
	# Warden at (60,80): exactly 100 away. Tower at (0,10): 10 away.
	var warden := _cand("warden", 60, 80, 100.0)
	var tower := _cand("tower", 0, 10)
	for order in [[warden, tower], [tower, warden]]:
		expect_eq(rr.call("pick_target", Vector2.ZERO, order, []), "warden", "inside the taunt radius, edge included")
	var out_warden := _cand("warden", 60, 80.5, 100.0)
	expect_eq(rr.call("pick_target", Vector2.ZERO, [out_warden, tower], []), "tower", "just outside: the nearest wins as usual")


func test_taunt_edge_cases() -> void:
	var rr := _seam()
	if rr == null:
		return
	var tower := _cand("tower", 0, 10)
	expect_eq(rr.call("pick_target", Vector2.ZERO, [_cand("w", 0, 5, 0.0), tower], []), "w", "a taunt radius of 0 is no taunt: plain nearest")
	expect_eq(rr.call("pick_target", Vector2.ZERO, [_cand("w", 0, 50, 0.0), tower], []), "tower", "and a 0 radius never pulls from afar")
	# A plain Recruit on top of the enemy (radius 0 at distance 0) must not count as a taunter:
	# the real taunter 50 away still pulls the enemy.
	expect_eq(rr.call("pick_target", Vector2.ZERO, [_cand("plain", 0, 0, 0.0), _cand("warden", 30, 40, 100.0)], []), "warden", "radius 0 at distance 0 is not a taunt")
	var near := _cand("w1", 0, 20, 100.0)
	var far := _cand("w2", 0, 80, 100.0)
	expect_eq(rr.call("pick_target", Vector2.ZERO, [far, near, tower], []), "w1", "two taunters: the nearer one")
	# An exact tie between taunters (3-4-5) follows tie_order.
	var a := _cand("a", 30, 40, 100.0)
	var b := _cand("b", -40, 30, 100.0)
	expect_eq(rr.call("pick_target", Vector2.ZERO, [a, b], ["b", "a"]), "b")
	expect_eq(rr.call("pick_target", Vector2.ZERO, [b, a], []), "a", "no order: smaller id")


func test_downed_recruits_are_not_targets_and_do_not_taunt() -> void:
	var rr := _seam()
	if rr == null:
		return
	var tower := _cand("tower", 0, 90)
	var downed_warden := _cand("warden", 0, 5, 100.0, true)
	expect_eq(rr.call("pick_target", Vector2.ZERO, [downed_warden, tower], []), "tower", "a downed Warden neither taunts nor gets hit")
	var downed_plain := _cand("archer", 0, 5, 0.0, true)
	expect_eq(rr.call("pick_target", Vector2.ZERO, [downed_plain, tower], []), "tower")
	expect_eq(rr.call("pick_target", Vector2.ZERO, [downed_warden, downed_plain], []), "", "everything downed: nothing to target")
	expect_eq(rr.call("pick_target", Vector2.ZERO, [], []), "", "no candidates")


# ---------------------------------------------------------------- staffed posts

func test_a_staffed_post_gets_each_staffing_recruits_effect_in_order() -> void:
	var rr := _seam()
	if rr == null:
		return
	var warden: Dictionary = rr.call("new_recruit", "warden", 40.0)
	var engineer: Dictionary = rr.call("new_recruit", "engineer", 40.0)
	var got: Array = rr.call("post_effects", [warden, engineer], EFFECTS)
	expect_true(QaSeam.same(got, [{"role": "warden", "effect": {"taunt": true}}, {"role": "engineer", "effect": {"repair": 5.0}}]), str(got))
	var lookout: Dictionary = rr.call("new_recruit", "lookout", 40.0)
	var alchemist: Dictionary = rr.call("new_recruit", "alchemist", 40.0)
	var more: Array = rr.call("post_effects", [lookout, alchemist], EFFECTS)
	expect_true(QaSeam.same(more, [{"role": "lookout", "effect": {"mark": true, "slow": 0.5}}, {"role": "alchemist", "effect": {"field": "burn"}}]), str(more))


func test_an_empty_post_a_downed_staffer_and_an_unknown_role_add_nothing() -> void:
	var rr := _seam()
	if rr == null:
		return
	expect_eq(rr.call("post_effects", [], EFFECTS), [], "nobody staffing")
	expect_eq(rr.call("post_effects", [_down(rr, "warden")], EFFECTS), [], "a downed Recruit stops adding their effect")
	var archer: Dictionary = rr.call("new_recruit", "archer", 40.0)
	expect_eq(rr.call("post_effects", [archer], EFFECTS), [], "a role with no staffed effect in the pack adds nothing, and does not crash")
	var mixed: Array = rr.call("post_effects", [_down(rr, "warden"), rr.call("new_recruit", "engineer", 40.0)], EFFECTS)
	expect_true(QaSeam.same(mixed, [{"role": "engineer", "effect": {"repair": 5.0}}]), "only the one still up counts")


func test_effects_are_copies_not_the_packs_own_data() -> void:
	var rr := _seam()
	if rr == null:
		return
	var pack := {"engineer": {"repair": 5.0}}
	var got: Array = rr.call("post_effects", [rr.call("new_recruit", "engineer", 40.0)], pack)
	got[0]["effect"]["repair"] = 99.0
	expect_eq(pack["engineer"]["repair"], 5.0, "changing a result must not change the pack")


func test_effect_pack_values() -> void:
	var rr := _seam()
	if rr == null:
		return
	var roles := ["warden", "lookout", "alchemist", "engineer"]
	expect_eq(rr.call("validate_effects", EFFECTS, roles), PackedStringArray())
	var bad := {
		"a missing role": {"warden": {"taunt": true}, "lookout": {"mark": true}, "alchemist": {"field": "burn"}},
		"an empty effect": {"warden": {}, "lookout": {"mark": true}, "alchemist": {"field": "burn"}, "engineer": {"repair": 5.0}},
		"effect not a dictionary": {"warden": "taunt", "lookout": {"mark": true}, "alchemist": {"field": "burn"}, "engineer": {"repair": 5.0}},
		"empty pack": {},
		"not a dictionary": [1, 2],
		"null": null,
	}
	for label in bad:
		var errors: PackedStringArray = rr.call("validate_effects", bad[label], roles)
		expect_true(errors.size() >= 1, label + " must be rejected")
		for message in errors:
			expect_ne(message, "", label + ": every error says something")


# ---------------------------------------------------------------- wiring

func test_the_game_actually_uses_the_recruit_rules() -> void:
	var qa := QaSeam.new(self, "res://tests/qa_pending.json")
	if not qa.check("recruit_rules", ResourceLoader.exists(SEAM), SEAM):
		return
	var hits := QaSeam.mentions_outside("res://scripts", SEAM, PackedStringArray(["RecruitRules", "recruit_rules.gd"]))
	expect_true(hits.size() >= 1, "no script under res://scripts uses RecruitRules, so downing, reviving, taunt and posts are not wired")
