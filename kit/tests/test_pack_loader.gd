extends KitTestCase

const PACKS := "res://addons/gamelab_kit/tests/fixtures/packs/"
const SCHEMA := PACKS + "test.schema.json"
const BASE_SCHEMA := "res://addons/gamelab_kit/schema/pack.v0.schema.json"


func test_valid_pack_loads() -> void:
	var pack := PackLoader.load_pack(PACKS + "valid", SCHEMA)
	expect_true(pack.ok, "errors: %s" % [pack.errors])
	expect_eq(pack.manifest["id"], "test_pack")
	expect_eq(pack.get_entries("enemies").keys(), ["walker", "runner"])
	expect_eq(pack.get_entry("enemies", "runner")["health"], 4.5)
	expect_eq(pack.get_entry("levels", "first")["waves"].size(), 2)


func test_base_schema_is_versioned_and_has_every_content_type() -> void:
	var schema := PackSchema.load_file(BASE_SCHEMA)
	expect_true(schema.errors.is_empty(), "errors: %s" % [schema.errors])
	expect_eq(schema.root["format_version"], 0.0)
	for def_name in ["manifest", "content", "level", "enemy", "tower", "staff", "upgrade_node"]:
		expect_false(schema.get_def(def_name).is_empty(), "base schema defines " + def_name)


func test_extended_schema_adds_fields() -> void:
	var schema := PackSchema.load_file(SCHEMA)
	var enemy := schema.get_def("enemy")
	expect_true(enemy["properties"].has("health"), "keeps base fields")
	expect_true(enemy["properties"].has("reward"), "adds game fields")
	expect_true("reward" in enemy["required"] and "health" in enemy["required"], "required lists merge")


func test_wrong_type_names_file_and_field() -> void:
	var pack := PackLoader.load_pack(PACKS + "bad_field", SCHEMA)
	expect_false(pack.ok)
	expect_any_contains(pack.errors, "enemies.json: $.enemies[0].health: expected number, got string")
	expect_true(pack.content.is_empty(), "a rejected pack gives no content")


func test_missing_and_unknown_fields_are_rejected() -> void:
	var errors: PackedStringArray = []
	var schema := PackSchema.load_file(SCHEMA)
	schema.validate_def({"id": "x", "name": "X", "health": 1, "speed": 1, "colour": "red"}, "enemy", "e.json: $", errors, [])
	expect_any_contains(errors, "e.json: $: missing required field reward")
	expect_any_contains(errors, "e.json: $.colour: unknown field")


func test_script_file_in_pack_is_refused() -> void:
	var pack := PackLoader.load_pack(PACKS + "has_script", SCHEMA)
	expect_false(pack.ok)
	expect_any_contains(pack.errors, "payload.gd: not a data file")


func test_engine_path_value_is_refused() -> void:
	var pack := PackLoader.load_pack(PACKS + "engine_path", SCHEMA)
	expect_false(pack.ok)
	expect_any_contains(pack.errors, "enemies.json: $.enemies[1].name: \"res://evil.gd\" is not data")


func test_non_data_strings() -> void:
	for bad in ["res://a.json", "user://save", "uid://abc", "boss.tscn", "skin.tres", "x.gd", "lib.dll", "[gd_scene format=3]"]:
		expect_false(PackLoader._is_plain_text(bad), bad)
	for good in ["Grunt", "a fast runner", "ice_biome", "1.5x damage"]:
		expect_true(PackLoader._is_plain_text(good), good)


func test_invalid_json_names_file_and_line() -> void:
	var pack := PackLoader.load_pack(PACKS + "bad_json", SCHEMA)
	expect_false(pack.ok)
	expect_any_contains(pack.errors, "enemies.json:2: invalid JSON")


func test_unknown_reference_is_rejected() -> void:
	var pack := PackLoader.load_pack(PACKS + "bad_ref", SCHEMA)
	expect_false(pack.ok)
	expect_any_contains(pack.errors, "levels.json: $.levels[0].waves[1].spawns[0].enemy: no enemies entry with id \"ghost\"")


func test_missing_pack_folder_is_an_error_not_a_crash() -> void:
	var pack := PackLoader.load_pack(PACKS + "does_not_exist", SCHEMA)
	expect_false(pack.ok)
	expect_any_contains(pack.errors, "cannot open pack folder")
