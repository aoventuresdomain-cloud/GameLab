extends SceneTree
## Headless test runner for GameLab projects.
##
##   godot --headless --path <project> -s res://addons/gamelab_kit/testing/run_tests.gd -- <res://dir> [...]
##
## Finds every test_*.gd under the given folders (recursively), runs each test_*
## method of each KitTestCase and exits 0 when all pass, 1 otherwise. Tests run
## once the tree is up (nodes added to tree.root get _ready), and a test may be a
## coroutine (await tree.process_frame). A script error logged while a test runs fails it,
## even when the test had already passed some expectations before it stopped.

## Collects the script errors Godot logs, so the runner can tell which test caused them.
class ScriptErrors extends Logger:
	var _lock := Mutex.new()
	var _seen: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		_lock.lock()
		_seen.append("script error: %s (%s:%d)" % [rationale if not rationale.is_empty() else code, file.get_file(), line])
		_lock.unlock()

	## The errors since the last call.
	func take() -> PackedStringArray:
		_lock.lock()
		var out := _seen
		_seen = []
		_lock.unlock()
		return out



func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dirs := OS.get_cmdline_user_args()
	if dirs.is_empty():
		printerr("run_tests: give at least one res:// folder after --")
		quit(2)
		return
	var files: PackedStringArray = []
	for dir in dirs:
		_collect(dir, files)
	files.sort()

	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	var passed := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	for path in files:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL %s: could not load the script" % path)
			failed += 1
			continue
		var case: Variant = script.new()
		if not case is KitTestCase:
			print("FAIL %s: does not extend KitTestCase" % path)
			failed += 1
			continue
		case.tree = self
		var seen := {}
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_") or seen.has(name):
				continue
			seen[name] = true
			case._begin_test()
			errors.take()
			await case.call(name)
			var failures: PackedStringArray = case._end_test()
			failures.append_array(errors.take())
			if failures.is_empty():
				passed += 1
				print("ok   %s :: %s" % [path.get_file(), name])
			else:
				failed += 1
				print("FAIL %s :: %s" % [path.get_file(), name])
				for failure in failures:
					print("       " + failure)
	OS.remove_logger(errors)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("%d passed, %d failed, %d files, %.2f s" % [passed, failed, files.size(), elapsed])
	if passed + failed == 0:
		print("FAIL no tests found in %s" % [dirs])
		failed = 1
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("run_tests: cannot open %s" % dir_path)
		return
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
