extends RefCounted
## Test support for strict tests that are written before the code they test.
##
## A test asks for a "seam" (the script the build must provide). Until the build
## lands the seam's id is listed in the project's qa_pending.json and its tests
## report PENDING and pass. The build's PR removes the id from that file, and
## from then on the tests are strict. The ratchet cannot be skipped:
##   - seam missing and id not listed  -> FAIL (renamed, moved or never built)
##   - seam present and id still listed -> FAIL (the build landed; remove the id)
## so a test can never sit pending behind a finished build.
##
##   const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
##   var seam := QaSeam.new(self, "res://tests/qa_pending.json").use("thing", "res://scripts/thing.gd")
##   if seam == null: return

static var _announced := {}

var _case: KitTestCase
var _pending: PackedStringArray = []


func _init(case: KitTestCase, pending_file: String) -> void:
	_case = case
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pending_file))
	if parsed is Array:
		for id in parsed:
			_pending.append(str(id))
	else:
		_case.fail("%s is missing or is not a JSON list of seam ids" % pending_file)


## Returns the seam's script, or null when the test must stop here (pending, or
## a failure has already been recorded).
func use(id: String, script_path: String) -> GDScript:
	if not check(id, ResourceLoader.exists(script_path), script_path):
		return null
	return load(script_path) as GDScript


## True when `present` and the id is no longer pending, so the test should run.
func check(id: String, present: bool, what: String) -> bool:
	var listed := _pending.has(id)
	if present and listed:
		_case.fail("%s: %s exists now, so remove %s from qa_pending.json (the tests are strict from here)" % [id, what, id])
		return false
	if not present and not listed:
		_case.fail("%s: %s does not exist and %s is not listed as pending in qa_pending.json" % [id, what, id])
		return false
	if not present:
		if not _announced.has(id):
			_announced[id] = true
			print("PENDING %s: %s is not built yet" % [id, what])
		_case.expect_true(true, "pending")
		return false
	return true


## Files under `dir` (not the seam itself) that mention any of `names`.
static func mentions_outside(dir: String, except_path: String, names: PackedStringArray) -> PackedStringArray:
	var hits: PackedStringArray = []
	_walk(dir, except_path, names, hits)
	return hits


static func _walk(dir_path: String, except_path: String, names: PackedStringArray, hits: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_walk(dir_path.path_join(sub), except_path, names, hits)
	for file in dir.get_files():
		var path := dir_path.path_join(file)
		if not file.ends_with(".gd") or path == except_path:
			continue
		var source := FileAccess.get_file_as_string(path)
		for name in names:
			if source.contains(name):
				hits.append(path)
				break


## Equality that also checks types, all the way down (Godot's == treats 5 and 5.0 as equal).
static func same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not same(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	return a == b


## True when `actual` holds every key of `expected` with the same value and type.
## Extra keys in `actual` are fine, so a build may add fields.
static func has_fields(actual: Variant, expected: Dictionary) -> bool:
	if not actual is Dictionary:
		return false
	for key in expected:
		if not actual.has(key) or not same(actual[key], expected[key]):
			return false
	return true
