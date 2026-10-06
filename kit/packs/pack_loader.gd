class_name PackLoader
extends RefCounted
## Loads a content pack: a folder holding pack.json (the manifest) and the JSON
## content files it lists, validated against a PackSchema.
##
## Packs are data only. The loader parses JSON (which can only produce plain
## values, never objects) and refuses any file that is not .json and any value
## that points at code or engine resources (res://, user://, uid:// paths,
## scripts, scenes, resources, shaders or native libraries).
##
##   var pack := PackLoader.load_pack("res://content/base", "res://content/schema/pack.schema.json")
##   if not pack.ok: for e in pack.errors: push_error(e)
##   var enemy: Dictionary = pack.get_entry("enemies", "grunt")

const MANIFEST := "pack.json"
## File types that can hold or point at code or engine resources.
const NON_DATA_SUFFIXES := [
	".gd", ".gdc", ".gde", ".cs", ".tscn", ".scn", ".tres", ".res", ".gdshader", ".shader",
	".gdextension", ".gdns", ".dll", ".so", ".dylib", ".wasm", ".js", ".pck", ".zip", ".exe",
]
const NON_DATA_PREFIXES := ["res://", "user://", "uid://", "file://"]
## Godot text formats for scenes and resources.
const NON_DATA_MARKERS := ["[gd_scene", "[gd_resource", "[ext_resource", "[sub_resource"]


class Pack:
	extends RefCounted
	var ok := false
	var errors: PackedStringArray = []
	var dir := ""
	var manifest: Dictionary = {}
	## content type -> {id -> entry}, entries in file order.
	var content: Dictionary = {}

	func get_entries(content_type: String) -> Dictionary:
		return content.get(content_type, {})

	func get_entry(content_type: String, id: String) -> Dictionary:
		return get_entries(content_type).get(id, {})


static func load_pack(pack_dir: String, schema_path: String) -> Pack:
	var pack := Pack.new()
	pack.dir = pack_dir
	var schema := PackSchema.load_file(schema_path)
	if not schema.errors.is_empty():
		pack.errors.append_array(schema.errors)
		return pack
	var listing := DirAccess.open(pack_dir)
	if listing == null:
		pack.errors.append("%s: cannot open pack folder (%s)" % [pack_dir, error_string(DirAccess.get_open_error())])
		return pack

	# Only JSON files, and nothing nested, may sit in a pack folder.
	for sub in listing.get_directories():
		pack.errors.append("%s: pack folders hold files only, found folder %s/" % [pack_dir, sub])
	for file in listing.get_files():
		if file.get_extension().to_lower() != "json" and not file.ends_with(".import"):
			pack.errors.append("%s: not a data file (packs hold .json only)" % file)

	var refs := []
	var manifest: Variant = _read_json(pack_dir, MANIFEST, pack.errors)
	if manifest == null:
		return _finish(pack)
	_check_data_only(manifest, MANIFEST, "$", pack.errors)
	schema.validate_def(manifest, "manifest", MANIFEST + ": $", pack.errors, refs)
	if typeof(manifest) != TYPE_DICTIONARY or not pack.errors.is_empty():
		return _finish(pack)
	pack.manifest = manifest

	for file in manifest["files"]:
		var file_name := str(file)
		var data: Variant = _read_json(pack_dir, file_name, pack.errors)
		if data == null:
			continue
		var before := pack.errors.size()
		_check_data_only(data, file_name, "$", pack.errors)
		schema.validate_def(data, "content", file_name + ": $", pack.errors, refs)
		if pack.errors.size() > before or typeof(data) != TYPE_DICTIONARY:
			continue
		for content_type in data:
			var entries: Dictionary = pack.content.get(content_type, {})
			var list: Array = data[content_type]
			for i in list.size():
				var entry: Dictionary = list[i]
				var id := str(entry.get("id", ""))
				if entries.has(id):
					pack.errors.append("%s: $.%s[%d].id: duplicate id %s" % [file_name, content_type, i, id])
				entries[id] = entry
			pack.content[content_type] = entries

	for ref in refs:
		var where: String = ref[0]
		var target: String = ref[1]
		if not pack.get_entries(target).has(ref[2]):
			pack.errors.append("%s: no %s entry with id %s" % [where, target, JSON.stringify(ref[2])])
	return _finish(pack)


static func _finish(pack: Pack) -> Pack:
	pack.ok = pack.errors.is_empty()
	if not pack.ok:
		pack.content = {}
	return pack


static func _read_json(pack_dir: String, file_name: String, errors: PackedStringArray) -> Variant:
	if file_name.contains("/") or file_name.contains("\\") or file_name.get_extension() != "json":
		errors.append("%s: listed files must be .json files in the pack folder" % file_name)
		return null
	var full_path := pack_dir.path_join(file_name)
	if not FileAccess.file_exists(full_path):
		errors.append("%s: file not found in %s" % [file_name, pack_dir])
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(full_path)) != OK:
		errors.append("%s:%d: invalid JSON: %s" % [file_name, json.get_error_line() + 1, json.get_error_message()])
		return null
	return json.data


## Appends an error for every key or string value that points at code or engine resources.
static func _check_data_only(value: Variant, file_name: String, where: String, errors: PackedStringArray) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for key in value:
				var child := "%s.%s" % [where, key]
				if not _is_plain_text(str(key)):
					errors.append("%s: %s: field name is not data (refers to code or engine resources)" % [file_name, child])
				_check_data_only(value[key], file_name, child, errors)
		TYPE_ARRAY:
			for i in value.size():
				_check_data_only(value[i], file_name, "%s[%d]" % [where, i], errors)
		TYPE_STRING:
			if not _is_plain_text(value):
				errors.append("%s: %s: %s is not data (refers to code or engine resources)" % [file_name, where, JSON.stringify(value)])


static func _is_plain_text(text: String) -> bool:
	var lower := text.strip_edges().to_lower()
	for prefix in NON_DATA_PREFIXES:
		if lower.begins_with(prefix):
			return false
	for suffix in NON_DATA_SUFFIXES:
		if lower.ends_with(suffix):
			return false
	for marker in NON_DATA_MARKERS:
		if lower.contains(marker):
			return false
	return true
