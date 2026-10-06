class_name PackSchema
extends RefCounted
## A JSON schema for content packs, with the subset of JSON Schema that packs need.
##
## Keywords: type, enum, properties, required, additionalProperties (bool or
## schema), items, minItems, maxItems, minimum, maximum, exclusiveMinimum,
## minLength, maxLength, pattern, $ref ("#/$defs/name") and two GameLab ones:
##   "x-ref": "<content type>"  the string must be the id of an entry of that
##                              type in the same pack (checked by PackLoader).
##   "$extends": "<res:// path>" (top level) builds on a base schema: each of
##                              the extending schema's $defs is merged into the
##                              base's (properties and required are combined,
##                              other keywords replaced).

var path := ""
var root: Dictionary = {}
## Problems found while loading the schema itself.
var errors: PackedStringArray = []

var _regex_cache := {}


## Loads a schema file, following $extends. Check `errors` afterwards.
static func load_file(schema_path: String) -> PackSchema:
	var schema := PackSchema.new()
	schema.path = schema_path
	schema.root = schema._load_merged(schema_path, [])
	return schema


func _load_merged(schema_path: String, chain: Array) -> Dictionary:
	if schema_path in chain:
		errors.append("%s: $extends loops back to itself" % schema_path)
		return {}
	var text := FileAccess.get_file_as_string(schema_path)
	if text.is_empty():
		errors.append("%s: cannot read schema (%s)" % [schema_path, error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s:%d: %s" % [schema_path, json.get_error_line() + 1, json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: schema must be a JSON object" % schema_path)
		return {}
	var data: Dictionary = json.data
	if not data.has("$extends"):
		return data
	var base_path := str(data["$extends"])
	if base_path.is_relative_path():
		base_path = schema_path.get_base_dir().path_join(base_path)
	var merged := _load_merged(base_path, chain + [schema_path])
	return PackSchema.merge(merged, data)


## Merges an extending schema over a base: $defs are combined def by def.
static func merge(base: Dictionary, ext: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in ext:
		if key == "$extends":
			continue
		if key == "$defs":
			var defs: Dictionary = out.get("$defs", {})
			for def_name in ext["$defs"]:
				defs[def_name] = PackSchema._merge_def(defs.get(def_name, {}), ext["$defs"][def_name])
			out["$defs"] = defs
		else:
			out[key] = ext[key]
	return out


static func _merge_def(base: Dictionary, ext: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in ext:
		if key == "properties":
			var props: Dictionary = out.get("properties", {})
			props.merge(ext["properties"], true)
			out["properties"] = props
		elif key == "required":
			var required: Array = out.get("required", [])
			for name in ext["required"]:
				if not name in required:
					required.append(name)
			out["required"] = required
		else:
			out[key] = ext[key]
	return out


## Returns the named definition from $defs, or {} if there is none.
func get_def(def_name: String) -> Dictionary:
	return root.get("$defs", {}).get(def_name, {})


## Validates `value` against the named $defs entry. Appends "<where>: <problem>"
## lines to `out_errors` and [where, target_type, id] to `out_refs` for x-ref checks.
func validate_def(value: Variant, def_name: String, where: String, out_errors: PackedStringArray, out_refs: Array) -> void:
	if get_def(def_name).is_empty():
		out_errors.append("%s: schema %s has no definition %s" % [where, path, def_name])
		return
	_validate(value, get_def(def_name), where, out_errors, out_refs)


func _validate(value: Variant, schema: Dictionary, where: String, errs: PackedStringArray, refs: Array) -> void:
	if schema.has("$ref"):
		var ref := str(schema["$ref"])
		if not ref.begins_with("#/$defs/") or get_def(ref.trim_prefix("#/$defs/")).is_empty():
			errs.append("%s: schema reference %s not found" % [where, ref])
			return
		_validate(value, get_def(ref.trim_prefix("#/$defs/")), where, errs, refs)
	if schema.has("type") and not _type_matches(value, schema["type"]):
		errs.append("%s: expected %s, got %s" % [where, _type_label(schema["type"]), _json_type(value)])
		return
	if schema.has("enum") and not _in_enum(value, schema["enum"]):
		errs.append("%s: must be one of %s" % [where, JSON.stringify(schema["enum"])])
	match typeof(value):
		TYPE_DICTIONARY:
			_validate_object(value, schema, where, errs, refs)
		TYPE_ARRAY:
			_validate_array(value, schema, where, errs, refs)
		TYPE_STRING:
			_validate_string(value, schema, where, errs, refs)
		TYPE_FLOAT, TYPE_INT:
			_validate_number(float(value), schema, where, errs)


func _validate_object(value: Dictionary, schema: Dictionary, where: String, errs: PackedStringArray, refs: Array) -> void:
	var props: Dictionary = schema.get("properties", {})
	for name in schema.get("required", []):
		if not value.has(name):
			errs.append("%s: missing required field %s" % [where, name])
	var extra: Variant = schema.get("additionalProperties", true)
	for key in value:
		var child := "%s.%s" % [where, key]
		if props.has(key):
			_validate(value[key], props[key], child, errs, refs)
		elif typeof(extra) == TYPE_BOOL:
			if not extra:
				errs.append("%s: unknown field" % child)
		elif typeof(extra) == TYPE_DICTIONARY:
			_validate(value[key], extra, child, errs, refs)


func _validate_array(value: Array, schema: Dictionary, where: String, errs: PackedStringArray, refs: Array) -> void:
	if schema.has("minItems") and value.size() < int(schema["minItems"]):
		errs.append("%s: needs at least %d items, has %d" % [where, int(schema["minItems"]), value.size()])
	if schema.has("maxItems") and value.size() > int(schema["maxItems"]):
		errs.append("%s: allows at most %d items, has %d" % [where, int(schema["maxItems"]), value.size()])
	if schema.has("items"):
		for i in value.size():
			_validate(value[i], schema["items"], "%s[%d]" % [where, i], errs, refs)


func _validate_string(value: String, schema: Dictionary, where: String, errs: PackedStringArray, refs: Array) -> void:
	if schema.has("minLength") and value.length() < int(schema["minLength"]):
		errs.append("%s: must be at least %d characters" % [where, int(schema["minLength"])])
	if schema.has("maxLength") and value.length() > int(schema["maxLength"]):
		errs.append("%s: must be at most %d characters" % [where, int(schema["maxLength"])])
	if schema.has("pattern"):
		var regex := _regex(str(schema["pattern"]))
		if regex == null:
			errs.append("%s: schema pattern %s does not compile" % [where, schema["pattern"]])
		elif regex.search(value) == null:
			errs.append("%s: %s does not match %s" % [where, JSON.stringify(value), schema["pattern"]])
	if schema.has("x-ref"):
		refs.append([where, str(schema["x-ref"]), value])


func _validate_number(value: float, schema: Dictionary, where: String, errs: PackedStringArray) -> void:
	if schema.has("minimum") and value < float(schema["minimum"]):
		errs.append("%s: must be at least %s" % [where, schema["minimum"]])
	if schema.has("maximum") and value > float(schema["maximum"]):
		errs.append("%s: must be at most %s" % [where, schema["maximum"]])
	if schema.has("exclusiveMinimum") and value <= float(schema["exclusiveMinimum"]):
		errs.append("%s: must be more than %s" % [where, schema["exclusiveMinimum"]])


func _type_matches(value: Variant, expected: Variant) -> bool:
	if typeof(expected) == TYPE_ARRAY:
		for one in expected:
			if _type_matches(value, one):
				return true
		return false
	var actual := _json_type(value)
	if expected == "number":
		return actual == "number" or actual == "integer"
	return actual == expected


## The JSON type name of a parsed value. JSON numbers arrive as floats; whole
## ones count as integers.
func _json_type(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "boolean"
		TYPE_INT:
			return "integer"
		TYPE_FLOAT:
			var number: float = value
			return "integer" if is_finite(number) and number == floorf(number) else "number"
		TYPE_STRING, TYPE_STRING_NAME:
			return "string"
		TYPE_ARRAY:
			return "array"
		TYPE_DICTIONARY:
			return "object"
	return type_string(typeof(value))


func _type_label(expected: Variant) -> String:
	if typeof(expected) == TYPE_ARRAY:
		return " or ".join(PackedStringArray(expected))
	return str(expected)


func _in_enum(value: Variant, options: Array) -> bool:
	for option in options:
		var both_numbers := typeof(value) in [TYPE_INT, TYPE_FLOAT] and typeof(option) in [TYPE_INT, TYPE_FLOAT]
		if (both_numbers and float(value) == float(option)) or (typeof(value) == typeof(option) and value == option):
			return true
	return false


func _regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		var regex := RegEx.new()
		_regex_cache[pattern] = regex if regex.compile(pattern) == OK else null
	return _regex_cache[pattern]
