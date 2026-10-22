extends KitTestCase
## KIT-06: a pack names its format version, and references between its files are checked.
## Packs are written to a scratch folder so each case shows exactly one thing.

const SCHEMA := "res://addons/gamelab_kit/tests/fixtures/packs/test.schema.json"
const DIR := "user://kit_pack_tests"


func _pack(name: String, manifest: Dictionary, files: Dictionary) -> String:
	var dir := DIR.path_join(name)
	DirAccess.make_dir_recursive_absolute(dir)
	_write(dir.path_join("pack.json"), JSON.stringify(manifest))
	for file_name in files:
		_write(dir.path_join(file_name), JSON.stringify(files[file_name]))
	return dir


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _manifest(files: Array, format_version: Variant = 0) -> Dictionary:
	var manifest := {"id": "scratch", "name": "Scratch", "version": "0.1.0", "files": files}
	if format_version != null:
		manifest["format_version"] = format_version
	return manifest


func _node(id: String, requires: Array) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "cost": 5, "requires": requires}


func test_references_resolve_across_files() -> void:
	var dir := _pack("cross_ok", _manifest(["nodes_a.json", "nodes_b.json"]), {
		"nodes_a.json": {"upgrade_nodes": [_node("root", [])]},
		"nodes_b.json": {"upgrade_nodes": [_node("leaf", ["root"])]},
	})
	var pack := PackLoader.load_pack(dir, SCHEMA)
	expect_true(pack.ok, "errors: %s" % [pack.errors])
	expect_eq(pack.get_entries("upgrade_nodes").keys(), ["root", "leaf"])


func test_a_dangling_reference_in_another_file_names_the_file_and_field() -> void:
	var dir := _pack("cross_bad", _manifest(["nodes_a.json", "nodes_b.json"]), {
		"nodes_a.json": {"upgrade_nodes": [_node("root", [])]},
		"nodes_b.json": {"upgrade_nodes": [_node("leaf", ["root"]), _node("orphan", ["root", "nowhere"])]},
	})
	var pack := PackLoader.load_pack(dir, SCHEMA)
	expect_false(pack.ok)
	expect_eq(pack.errors.size(), 1, "only the dangling id is reported: %s" % [pack.errors])
	expect_any_contains(pack.errors, "nodes_b.json: $.upgrade_nodes[1].requires[1]: no upgrade_nodes entry with id \"nowhere\"")


func test_the_current_format_version_loads() -> void:
	var dir := _pack("version_ok", _manifest(["nodes_a.json"], 0), {"nodes_a.json": {"upgrade_nodes": [_node("root", [])]}})
	expect_true(PackLoader.load_pack(dir, SCHEMA).ok)


func test_an_unknown_major_version_is_rejected_with_one_clear_error() -> void:
	for version in [1, 2, 99, -1]:
		var dir := _pack("version_future", _manifest(["nodes_a.json"], version), {"nodes_a.json": {"upgrade_nodes": [_node("root", [])]}})
		var pack := PackLoader.load_pack(dir, SCHEMA)
		expect_false(pack.ok, "version %d" % version)
		expect_eq(pack.errors.size(), 1, "just the version error: %s" % [pack.errors])
		expect_any_contains(pack.errors, "pack.json: $.format_version: unknown major version %d (this kit reads pack format 0)" % version)
		expect_true(pack.content.is_empty(), "a rejected pack gives no content")


func test_a_missing_or_odd_version_is_rejected() -> void:
	var dir := _pack("version_missing", _manifest(["nodes_a.json"], null), {"nodes_a.json": {"upgrade_nodes": [_node("root", [])]}})
	var missing := PackLoader.load_pack(dir, SCHEMA)
	expect_false(missing.ok)
	expect_any_contains(missing.errors, "missing required field format_version")
	for odd in ["0", 0.5, true]:
		dir = _pack("version_odd", _manifest(["nodes_a.json"], odd), {"nodes_a.json": {"upgrade_nodes": [_node("root", [])]}})
		var pack := PackLoader.load_pack(dir, SCHEMA)
		expect_false(pack.ok, "version %s" % [odd])
		expect_any_contains(pack.errors, "pack.json: $.format_version: expected a whole number")
