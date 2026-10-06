class_name KitTestCase
extends RefCounted
## Base class for GameLab tests. Put tests in files named test_*.gd, extend this
## class and name each test method test_*. Run them with testing/run_tests.gd.
##
## A test passes when it made at least one expectation and none failed. A test
## that makes no expectation fails, which also catches a script error that
## stopped it early.

## The running SceneTree, for tests that need to add nodes. Free what you add.
var tree: SceneTree

var _failures: PackedStringArray = []
var _expectations := 0


func expect_true(value: bool, message: String = "") -> void:
	_expectations += 1
	if not value:
		_fail("expected true" + _suffix(message))


func expect_false(value: bool, message: String = "") -> void:
	_expectations += 1
	if value:
		_fail("expected false" + _suffix(message))


func expect_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_expectations += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected %s, got %s%s" % [var_to_str(expected), var_to_str(actual), _suffix(message)])


func expect_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_expectations += 1
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		_fail("expected anything but %s%s" % [var_to_str(unexpected), _suffix(message)])


func expect_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	_expectations += 1
	if absf(actual - expected) > tolerance:
		_fail("expected %s ± %s, got %s%s" % [expected, tolerance, actual, _suffix(message)])


## Passes when some entry of `lines` contains `fragment`.
func expect_any_contains(lines: PackedStringArray, fragment: String, message: String = "") -> void:
	_expectations += 1
	for line in lines:
		if line.contains(fragment):
			return
	_fail("no line contains %s in %s%s" % [var_to_str(fragment), var_to_str(lines), _suffix(message)])


func fail(message: String) -> void:
	_expectations += 1
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)


func _suffix(message: String) -> String:
	return "" if message.is_empty() else " (" + message + ")"


## Called by the runner before each test.
func _begin_test() -> void:
	_failures = []
	_expectations = 0


## Called by the runner after each test; returns its failures.
func _end_test() -> PackedStringArray:
	if _expectations == 0 and _failures.is_empty():
		_failures.append("made no expectation (did a script error stop it?)")
	return _failures
