extends KitTestCase
## HF-M1-02: progression across runs with a stub upgrade policy.

const NODES := {
	"a": {"id": "a", "cost": 10},
	"b": {"id": "b", "cost": 5, "requires": ["a"]},
	"c": {"id": "c", "cost": 30},
}


func test_buys_cheapest_affordable_with_requirements_met() -> void:
	expect_eq(HoldfastProgression.buy_cheapest(NODES, [], 9), [])
	expect_eq(HoldfastProgression.buy_cheapest(NODES, [], 15), ["a", "b"], "b unlocks once a is bought")
	expect_eq(HoldfastProgression.buy_cheapest(NODES, ["a", "b"], 100), ["c"])


func test_short_progression_is_deterministic_and_buys_upgrades() -> void:
	var first := HoldfastProgression.play(7, 0.25)
	var second := HoldfastProgression.play(7, 0.25)
	expect_eq(first["hash"], second["hash"])
	expect_true(first["runs_played"] > 1, "plays several runs")
	expect_false(first["unlocks"].is_empty(), "buys upgrades between runs")
	expect_true(first["sim_seconds"] >= 0.25 * 3600.0, "covers the simulated time")
