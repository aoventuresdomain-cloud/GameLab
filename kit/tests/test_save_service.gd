extends KitTestCase
## KIT-07 save service: strict tests written before the build (Head of QA, M2).
##
## The seam the build must provide (names are QA's; ask QA before the build if
## one has to change, never after):
##
##   res://addons/gamelab_kit/services/save/save_service.gd   class_name SaveService
##
##   SaveService.new(path: String, version: int, migrations: Dictionary = {})
##       migrations maps a version number to a Callable that takes the data
##       Dictionary of that version and returns the data Dictionary of the next.
##   save(data: Dictionary) -> bool
##   load_save() -> Dictionary  { status, data, message, from_version }
##       status is one of "ok", "missing", "migrated", "recovered", "corrupt",
##       "newer", "unsupported". data is {} unless status is ok, migrated or
##       recovered. message is non-empty whenever the player has to be told.
##
## Nothing here knows the file format, so the build may pick any. Expected values
## are worked by hand (see each test) and never read back from the service.
## Known Godot traps these tests exist for (checked on 4.7.2): JSON.parse_string
## returns every number as a float, JSON.stringify drops float digits unless
## asked for full precision (0.1 + 0.2 saves as 0.3), turns NaN into null and an
## Object into a string, and a whole int above 2^53 loses its last digits.

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const SEAM := "res://addons/gamelab_kit/services/save/save_service.gd"
const DIR := "user://qa_save_tests"


func _seam() -> GDScript:
	return QaSeam.new(self, "res://addons/gamelab_kit/tests/qa_pending.json").use("save_service", SEAM)


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR.path_join(name + ".sav")
	_clean(name)
	return path


func _clean(name: String) -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)


func _service(seam: GDScript, path: String, version: int = 1, migrations: Dictionary = {}) -> Object:
	return seam.new(path, version, migrations)


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## Names and files a player's folder holds, to prove a refusal wrote nothing.
func _listing(name: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			out.append("%s:%d" % [file, FileAccess.get_file_as_bytes(DIR.path_join(file)).size()])
	out.sort()
	return out


## A mid-run save shaped like the game's: nested, empty containers, unicode and
## quote characters in player-chosen names, every int and float edge.
func _mid_run() -> Dictionary:
	return {
		"gold": 120,
		"gold_zero": 0,
		"debt": -1,
		"big_int": 2147483648,
		"above_2_53": 9007199254740993,   # 2^53 + 1: not representable as a float
		"max_int": 9223372036854775807,   # 2^63 - 1
		"whole_float": 5.0,               # must stay a float, not become the int 5
		"sum": 0.1 + 0.2,                 # 0.30000000000000004: needs full precision
		"third": 1.0 / 3.0,
		"tiny": 1e-300,
		"flag": true,
		"nothing": null,
		"hero": {"name": "Ælfred 🛡️ O'Neil \"the Keeper\"", "paths": {"guardian": ["g1a", "g1b"], "marksman": []}},
		"recruits": [{"name": "Ser Wulfric", "level": 3, "picks": [1, 0]}, {"name": "", "level": 1, "picks": []}],
		"run": {"wave": 4, "enemies": [[10.5, -20.25], [0.1 + 0.2, 7.0]], "empty": {}},
	}


func test_round_trip_is_exact_including_types() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("round_trip")
	var data := _mid_run()
	var svc := _service(seam, path)
	expect_true(svc.save(data), "save succeeds")
	var loaded: Dictionary = _service(seam, path).load_save()
	expect_eq(loaded["status"], "ok")
	expect_true(QaSeam.same(loaded["data"], data), "same values and same types, all the way down")
	for key in ["gold", "above_2_53", "max_int", "whole_float", "sum", "third"]:
		expect_eq(typeof(loaded["data"].get(key)), typeof(data[key]), key + " keeps its type")
	expect_eq(loaded["data"].get("above_2_53"), 9007199254740993, "no digits lost above 2^53")
	expect_eq(loaded["data"].get("sum"), 0.1 + 0.2, "float is bit-exact")
	_clean("round_trip")


func test_save_twice_then_load_gives_the_latest() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("latest")
	var svc := _service(seam, path)
	svc.save({"gold": 1})
	svc.save({"gold": 2, "upgrades": ["a"]})
	var loaded: Dictionary = _service(seam, path).load_save()
	expect_eq(loaded["status"], "ok")
	expect_true(QaSeam.same(loaded["data"], {"gold": 2, "upgrades": ["a"]}), "latest save, nothing merged from the first")
	_clean("latest")


func test_missing_file_is_a_new_game_not_an_error() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("missing")
	var loaded: Dictionary = _service(seam, path).load_save()
	expect_eq(loaded["status"], "missing")
	expect_eq(loaded["data"], {})
	expect_false(FileAccess.file_exists(path), "loading never creates a file")


func test_unsavable_values_are_refused_and_the_good_save_survives() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("unsavable")
	var svc := _service(seam, path)
	var good := {"gold": 7, "ratio": 0.5}
	expect_true(svc.save(good))
	var before := _bytes(path)
	var object := Object.new()
	var bad_saves := {
		"NaN": {"x": NAN},
		"infinity": {"x": INF},
		"minus infinity": {"x": -INF},
		"an object": {"x": object},
		"an object deep inside": {"deep": {"list": [1, object]}},
	}
	for label in bad_saves:
		expect_false(svc.save(bad_saves[label]), "refuses " + label)
	object.free()
	expect_eq(_bytes(path), before, "the good save is byte-for-byte untouched")
	var loaded: Dictionary = _service(seam, path).load_save()
	expect_true(QaSeam.same(loaded["data"], good), "and still loads")
	_clean("unsavable")


func test_truncated_garbage_and_wrong_shape_are_corrupt() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("corrupt")
	var svc := _service(seam, path)
	var original := _mid_run()
	svc.save(original)
	var good := _bytes(path)
	var cases := {
		"empty file": PackedByteArray(),
		"one byte": good.slice(0, 1),
		"half the file": good.slice(0, good.size() / 2),
		"last two bytes missing": good.slice(0, good.size() - 2),
		"garbage": "\u0000\u0001 not a save ￿".to_utf8_buffer(),
		"a list": "[1, 2, 3]".to_utf8_buffer(),
		"an object with no version": "{\"hello\": \"world\"}".to_utf8_buffer(),
		"null": "null".to_utf8_buffer(),
		"a number": "42".to_utf8_buffer(),
	}
	for label in cases:
		_write(path, cases[label])
		var loaded: Dictionary = _service(seam, path).load_save()
		expect_eq(loaded["status"], "corrupt", label)
		expect_eq(loaded["data"], {}, label + ": no half-read data is handed over")
		expect_ne(loaded["message"], "", label + ": the player is told")
	_clean("corrupt")


func test_corrupt_save_falls_back_to_the_previous_good_one_and_tells_the_player() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("recover")
	var svc := _service(seam, path)
	var first := {"gold": 100, "name": "first"}
	var second := {"gold": 250, "name": "second"}
	svc.save(first)
	svc.save(second)
	var latest := _bytes(path)
	_write(path, latest.slice(0, latest.size() / 2))
	var loaded: Dictionary = _service(seam, path).load_save()
	expect_eq(loaded["status"], "recovered")
	expect_true(QaSeam.same(loaded["data"], first), "the previous good save, not the broken newer one")
	expect_ne(loaded["message"], "", "the player is told")
	var again: Dictionary = _service(seam, path).load_save()
	expect_true(QaSeam.same(again["data"], first), "loading again still finds the previous good save")
	expect_true(again["status"] in ["ok", "recovered"], "and does not report it as corrupt: " + str(again["status"]))
	_clean("recover")


func test_a_corrupt_only_save_does_not_brick_the_game() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("brick")
	var svc := _service(seam, path)
	svc.save({"gold": 1})
	var bytes := _bytes(path)
	_write(path, bytes.slice(0, bytes.size() / 2))
	expect_eq(_service(seam, path).load_save()["status"], "corrupt")
	var fresh := {"gold": 5}
	expect_true(_service(seam, path).save(fresh), "the player can start again and save")
	var loaded: Dictionary = _service(seam, path).load_save()
	expect_eq(loaded["status"], "ok")
	expect_true(QaSeam.same(loaded["data"], fresh))
	_clean("brick")


# Migration worked example. v1 -> v2 moves "gold" under "currency"; v2 -> v3
# renames "currency" to "wallet" and turns each upgrade id into {id, level 1}.
# v3 only comes out right if the steps run in order (step 2 needs step 1's key).
func _step_1(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["currency"] = {"gold": out["gold"]}
	out.erase("gold")
	return out


func _step_2(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["wallet"] = out["currency"]
	out.erase("currency")
	var upgrades := []
	for id in out["upgrades"]:
		upgrades.append({"id": id, "level": 1})
	out["upgrades"] = upgrades
	return out


func _v1_data() -> Dictionary:
	return {"gold": 120, "upgrades": ["a", "b"], "hero_name": "Keeper"}


func test_a_v1_save_loads_after_the_format_changed_twice() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("migrate")
	_service(seam, path, 1).save(_v1_data())
	var steps := {1: _step_1, 2: _step_2}
	var loaded: Dictionary = _service(seam, path, 3, steps).load_save()
	expect_eq(loaded["status"], "migrated")
	expect_eq(loaded["from_version"], 1)
	var expected := {"wallet": {"gold": 120}, "upgrades": [{"id": "a", "level": 1}, {"id": "b", "level": 1}], "hero_name": "Keeper"}
	expect_true(QaSeam.same(loaded["data"], expected), "both steps, in order, ints still ints: " + str(loaded["data"]))
	# The player's next save writes the new format and loads as plain ok.
	var current := _service(seam, path, 3, steps)
	expect_true(current.save(loaded["data"]))
	var after: Dictionary = _service(seam, path, 3, steps).load_save()
	expect_eq(after["status"], "ok")
	expect_eq(after["from_version"], 3)
	expect_true(QaSeam.same(after["data"], expected))
	_clean("migrate")


func test_a_v2_save_only_runs_the_later_step() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("migrate_v2")
	var v2 := {"currency": {"gold": 9}, "upgrades": ["z"]}
	_service(seam, path, 2).save(v2)
	var loaded: Dictionary = _service(seam, path, 3, {1: _step_1, 2: _step_2}).load_save()
	expect_eq(loaded["status"], "migrated")
	expect_eq(loaded["from_version"], 2)
	expect_true(QaSeam.same(loaded["data"], {"wallet": {"gold": 9}, "upgrades": [{"id": "z", "level": 1}]}))
	_clean("migrate_v2")


func test_a_missing_or_failing_migration_refuses_and_touches_nothing() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("migrate_fail")
	_service(seam, path, 1).save(_v1_data())
	var before := _bytes(path)
	var listing := _listing("migrate_fail")
	var no_step_1: Dictionary = _service(seam, path, 3, {2: _step_2}).load_save()
	expect_eq(no_step_1["status"], "unsupported", "no step from v1")
	expect_eq(no_step_1["data"], {})
	expect_ne(no_step_1["message"], "")
	var returns_null := func(_d: Dictionary) -> Variant: return null
	var bad_step: Dictionary = _service(seam, path, 2, {1: returns_null}).load_save()
	expect_eq(bad_step["status"], "unsupported", "a step that returns no data")
	expect_eq(bad_step["data"], {})
	expect_eq(_bytes(path), before, "file untouched")
	expect_eq(_listing("migrate_fail"), listing, "and nothing was written beside it")
	_clean("migrate_fail")


# Rollback note: an older build opening a newer save refuses safely, leaves the
# file untouched, and cannot overwrite it by saving.
func test_an_older_build_refuses_a_newer_save_and_leaves_it_untouched() -> void:
	var seam := _seam()
	if seam == null:
		return
	var path := _path("rollback")
	var newer := {"wallet": {"gold": 500}, "future_field": [1, 2, 3]}
	_service(seam, path, 3).save(newer)
	var before := _bytes(path)
	var listing := _listing("rollback")
	var old_build := _service(seam, path, 2)
	var loaded: Dictionary = old_build.load_save()
	expect_eq(loaded["status"], "newer")
	expect_eq(loaded["data"], {}, "no data from a format it does not understand")
	expect_ne(loaded["message"], "", "the player is told to update")
	expect_eq(loaded["from_version"], 3)
	expect_eq(_bytes(path), before, "file untouched by the load")
	expect_eq(_listing("rollback"), listing, "no backup or temp file written either")
	old_build.save({"gold": 1})
	expect_eq(_bytes(path), before, "saving from the old build cannot overwrite the newer save")
	var back_on_new: Dictionary = _service(seam, path, 3).load_save()
	expect_eq(back_on_new["status"], "ok", "the newer build still reads it")
	expect_true(QaSeam.same(back_on_new["data"], newer))
	_clean("rollback")

