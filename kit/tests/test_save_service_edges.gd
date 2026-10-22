extends KitTestCase
## KIT-07 edges beyond QA's strict tests: damaged bytes, interrupted swaps, number limits,
## and what the service refuses to store. Expected values are worked by hand.

const QaSeam = preload("res://addons/gamelab_kit/tests/fixtures/qa_seam.gd")
const DIR := "user://save_edge_tests"


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var dir := DirAccess.open(DIR)
	for file in dir.get_files():
		if file.begins_with(name + "."):
			dir.remove(file)
	return DIR.path_join(name + ".sav")


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func test_one_changed_byte_in_the_body_is_corrupt() -> void:
	var path := _path("flip")
	var svc := SaveService.new(path, 1)
	svc.save({"gold": 100})
	var bytes := _bytes(path)
	# "gold" is 100: change the last digit by editing the body text, keeping its length.
	var text := bytes.get_string_from_utf8().replace("100", "900")
	_write(path, text.to_utf8_buffer())
	var loaded := SaveService.new(path, 1).load_save()
	expect_eq(loaded["status"], "corrupt")
	expect_eq(loaded["data"], {})


func test_an_interrupted_swap_recovers_from_the_backup() -> void:
	var path := _path("swap")
	var svc := SaveService.new(path, 1)
	svc.save({"gold": 1})
	svc.save({"gold": 2})
	# Power loss after the old save moved aside and before the new one was in place.
	DirAccess.remove_absolute(path)
	var loaded := SaveService.new(path, 1).load_save()
	expect_eq(loaded["status"], "recovered")
	expect_eq(loaded["data"], {"gold": 1})
	expect_ne(loaded["message"], "")


func test_the_backup_is_migrated_like_the_main_save() -> void:
	var path := _path("bak_migrate")
	SaveService.new(path, 1).save({"gold": 4})
	SaveService.new(path, 1).save({"gold": 5})
	_write(path, PackedByteArray([1, 2, 3]))
	var add_wallet := func(d: Dictionary) -> Dictionary: return {"wallet": d["gold"]}
	var loaded := SaveService.new(path, 2, {1: add_wallet}).load_save()
	expect_eq(loaded["status"], "recovered")
	expect_eq(loaded["data"], {"wallet": 4})
	expect_eq(loaded["from_version"], 1)


func test_a_damaged_save_and_damaged_backup_is_corrupt_and_left_alone() -> void:
	var path := _path("both_bad")
	SaveService.new(path, 1).save({"gold": 1})
	SaveService.new(path, 1).save({"gold": 2})
	_write(path, "nope".to_utf8_buffer())
	_write(path + ".bak", "nope too".to_utf8_buffer())
	var loaded := SaveService.new(path, 1).load_save()
	expect_eq(loaded["status"], "corrupt")
	expect_eq(_bytes(path), "nope".to_utf8_buffer(), "loading never writes")


func test_saving_over_a_damaged_save_keeps_the_good_backup() -> void:
	var path := _path("keep_bak")
	var svc := SaveService.new(path, 1)
	svc.save({"gold": 1})
	svc.save({"gold": 2})
	_write(path, "broken".to_utf8_buffer())
	expect_true(svc.save({"gold": 3}))
	expect_eq(SaveService.new(path, 1).load_save()["data"], {"gold": 3})
	_write(path, "broken again".to_utf8_buffer())
	expect_eq(SaveService.new(path, 1).load_save()["data"], {"gold": 1}, "the backup is the last good save from before the damage")


func test_no_temporary_file_is_left_behind() -> void:
	var path := _path("tidy")
	var svc := SaveService.new(path, 1)
	svc.save({"a": 1})
	svc.save({"a": 2})
	expect_false(FileAccess.file_exists(path + ".tmp"))
	expect_true(FileAccess.file_exists(path + ".bak"))


func test_int_limits_keep_their_exact_value() -> void:
	# 10^15 is the largest int stored as a plain number; one more goes through text.
	var values := [0, 1, -1, 1000000000000000, 1000000000000001, -1000000000000000, -1000000000000001,
		9007199254740992, 9007199254740993, 9223372036854775807, -9223372036854775807 - 1]
	var path := _path("ints")
	var data := {"values": values}
	expect_true(SaveService.new(path, 1).save(data))
	var loaded: Array = SaveService.new(path, 1).load_save()["data"]["values"]
	expect_eq(loaded.size(), values.size())
	for i in values.size():
		expect_eq(typeof(loaded[i]), TYPE_INT, "index %d is an int" % i)
		expect_eq(loaded[i], values[i], "index %d" % i)


func test_floats_keep_their_exact_bits() -> void:
	var values := [0.0, -0.0, 5.0, 0.1, 123456789.123456789, 1e-300, 1.7976931348623157e308, -2.5e-8]
	var path := _path("floats")
	expect_true(SaveService.new(path, 1).save({"values": values}))
	var loaded: Array = SaveService.new(path, 1).load_save()["data"]["values"]
	for i in values.size():
		expect_eq(typeof(loaded[i]), TYPE_FLOAT, "index %d is a float" % i)
		expect_eq(var_to_bytes(loaded[i]), var_to_bytes(values[i]), "index %d bit for bit" % i)


func test_what_cannot_be_stored_is_refused() -> void:
	var path := _path("refuse")
	var svc := SaveService.new(path, 1)
	var cases := {
		"integer key": {1: "a"},
		"key starting with $": {"$f": "00"},
		"vector": {"p": Vector2(1, 2)},
		"packed array": {"p": PackedInt32Array([1])},
		"string name": {"p": &"name"},
		"callable": {"p": func() -> void: pass},
	}
	for label in cases:
		expect_false(svc.save(cases[label]), "refuses " + label)
	expect_false(FileAccess.file_exists(path), "nothing was written")
	var deep: Variant = 1
	for i in 70:
		deep = [deep]
	expect_false(svc.save({"deep": deep}), "refuses nesting beyond 64")
	var ok_deep: Variant = 1
	for i in 60:
		ok_deep = [ok_deep]
	expect_true(svc.save({"deep": ok_deep}), "accepts reasonable nesting")


func test_null_and_empty_values_survive() -> void:
	var path := _path("nulls")
	var data := {"n": null, "list": [null, [], {}], "s": "", "b": false}
	SaveService.new(path, 1).save(data)
	expect_true(QaSeam.same(SaveService.new(path, 1).load_save()["data"], data))


func test_a_file_with_a_forged_tag_is_corrupt_not_a_crash() -> void:
	var path := _path("forged")
	SaveService.new(path, 1).save({"gold": 1})
	# Rewrite the body with a bad float tag and fix the checksum so only the decoder can object.
	var body := '{"x":{"$f":"zz"}}'
	var text := "GLSAVE1 1 %s\n%s" % [body.sha256_text(), body]
	_write(path, text.to_utf8_buffer())
	var loaded := SaveService.new(path, 1).load_save()
	expect_eq(loaded["status"], "corrupt", "no earlier save to fall back to")
	expect_eq(loaded["data"], {})
	for bad in ['{"$f":"12"}', '{"$i":"5"}', '{"$i":"x"}', '{"$q":1}', '{"x":1.5}']:
		var text2 := "GLSAVE1 1 %s\n%s" % [bad.sha256_text(), bad]
		_write(path, text2.to_utf8_buffer())
		expect_eq(SaveService.new(path, 1).load_save()["status"], "corrupt", bad)
