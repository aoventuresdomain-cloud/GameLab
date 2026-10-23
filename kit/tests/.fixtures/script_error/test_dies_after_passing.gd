extends KitTestCase
## Run by test_runner_script_errors.gd, never by the suite itself (the folder is hidden).


func test_passes_then_dies() -> void:
	expect_true(true, "an expectation that passes first")
	var nothing: Node = null
	nothing.queue_free()
	expect_true(true, "never reached")


func test_is_fine() -> void:
	expect_true(true)
