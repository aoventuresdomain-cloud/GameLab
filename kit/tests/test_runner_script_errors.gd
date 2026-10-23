extends KitTestCase
## The runner fails a test that hits a script error, even when an earlier expectation passed.

const FIXTURE := "res://addons/gamelab_kit/tests/.fixtures/script_error"


func test_a_script_error_after_a_passing_expectation_is_a_failure() -> void:
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://addons/gamelab_kit/testing/run_tests.gd", "--", FIXTURE,
	], output, true)
	var text := "\n".join(output)
	expect_eq(code, 1, "the run fails")
	expect_true(text.contains("FAIL test_dies_after_passing.gd :: test_passes_then_dies"), "the erroring test is named: " + text)
	expect_true(text.contains("script error:"), "with the error: " + text)
	expect_true(text.contains("ok   test_dies_after_passing.gd :: test_is_fine"), "the next test is not blamed: " + text)
	expect_true(text.contains("1 passed, 1 failed"), "the totals: " + text)
