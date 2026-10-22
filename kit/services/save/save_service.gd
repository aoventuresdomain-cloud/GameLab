class_name SaveService
extends RefCounted
## Versioned, crash-safe local saves (KIT-07). One file per save, written to a
## user:// path, which is the user's data folder on desktop and browser storage
## in the web build.
##
##   var svc := SaveService.new("user://profile.sav", 2, {1: _v1_to_v2})
##   svc.save({"gold": 120})
##   var loaded := svc.load_save()   # {status, data, message, from_version}
##
## status is "ok", "missing", "migrated", "recovered", "corrupt", "newer" or
## "unsupported". data is {} unless status is ok, migrated or recovered. message
## is never empty when the player has to be told something.
##
## Rules this service keeps:
##  - A save is written to a temporary file, then swapped in; the file it
##    replaces becomes the "<path>.bak" copy. A damaged save falls back to that
##    copy, and the player is told.
##  - Loading never writes. A save made by a newer build, or one that cannot be
##    converted, is refused and left exactly as it is; saving over a newer save
##    is refused too, so rolling back to an older build cannot destroy it.
##  - Only null, bool, int, float, String, Array and Dictionary (String keys that
##    do not start with "$") are saved. NaN, infinity, objects and anything else
##    are refused before any file is touched.
##  - Types survive exactly. JSON alone would turn every number into a float and
##    drop float digits, so floats are stored as their 64 bits and large ints as
##    text. Plain small ints stay plain numbers.
##  - Each file starts with a header line (format, version, SHA-256 of the body),
##    so a truncated or edited file is detected rather than half-read.
##
## Migrations: `migrations` maps a version number to a Callable that takes the
## data of that version and returns the data of the next. Loading an older save
## runs the steps in order; a missing or failing step refuses the save.

const FORMAT := "GLSAVE1"
## Ints beyond this are stored as text (JSON numbers are doubles; 2^53 is the edge).
const MAX_PLAIN_INT := 1000000000000000
const MAX_DEPTH := 64

var path: String
var version: int
var migrations: Dictionary
var _bad := false


func _init(save_path: String, save_version: int, step_migrations: Dictionary = {}) -> void:
	path = save_path
	version = save_version
	migrations = step_migrations


func backup_path() -> String:
	return path + ".bak"


func _temp_path() -> String:
	return path + ".tmp"


## Writes `data` as the new save. Returns false, changing nothing that was good,
## when the data cannot be saved exactly or a newer build's save is in the way.
func save(data: Dictionary) -> bool:
	if version < 1:
		push_error("SaveService: version must be 1 or more")
		return false
	_bad = false
	var body_value: Variant = _encode(data, 0)
	if _bad:
		return false
	var body := JSON.stringify(body_value, "", true)
	var text := "%s %d %s\n%s" % [FORMAT, version, body.sha256_text(), body]

	var existing := _read_file(path)
	if existing["status"] == "newer":
		push_warning("SaveService: %s was made by a newer build; not overwriting it" % path)
		return false

	if not _write(_temp_path(), text):
		DirAccess.remove_absolute(_temp_path())
		return false
	# Keep the file being replaced as the previous good save, unless it is broken.
	if existing["status"] == "ok":
		DirAccess.remove_absolute(backup_path())
		if DirAccess.rename_absolute(path, backup_path()) != OK:
			DirAccess.remove_absolute(_temp_path())
			return false
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(_temp_path(), path) != OK:
		DirAccess.remove_absolute(_temp_path())
		return false
	return true


func load_save() -> Dictionary:
	var main := _read_file(path)
	var status: String = main["status"]
	if status == "missing" and FileAccess.file_exists(backup_path()):
		# A swap was interrupted after the old save moved aside: use that copy.
		status = "corrupt"
	if status == "newer":
		return _result("newer", {}, main["version"],
			"This save was made by a newer version of the game (save version %d; this build reads up to %d). Please update the game. The save has not been changed." % [main["version"], version])
	if status == "missing":
		return _result("missing", {}, 0, "")
	if status == "ok":
		return _upgrade(main["data"], main["version"], "ok")

	var fallback := _read_file(backup_path())
	if fallback["status"] == "ok":
		var recovered := _upgrade(fallback["data"], fallback["version"], "recovered")
		if recovered["status"] == "recovered":
			recovered["message"] = "Your latest save was damaged or missing, so the previous save has been loaded. Some recent progress may be missing."
			return recovered
	return _result("corrupt", {}, 0,
		"Your save file is damaged and cannot be read. You can start a new game; nothing is deleted until you save again.")


## Runs the migration steps from `from_version` to this build's version.
func _upgrade(data: Dictionary, from_version: int, ok_status: String) -> Dictionary:
	if from_version == version:
		return _result(ok_status, data, from_version, "")
	var current := data
	for step in range(from_version, version):
		var fn: Variant = migrations.get(step)
		if not fn is Callable or not (fn as Callable).is_valid():
			return _unsupported(from_version)
		var next: Variant = (fn as Callable).call(current.duplicate(true))
		if not next is Dictionary:
			return _unsupported(from_version)
		current = next
	return _result("migrated" if ok_status == "ok" else ok_status, current, from_version, "")


func _unsupported(from_version: int) -> Dictionary:
	return _result("unsupported", {}, from_version,
		"This save is from an older version of the game (save version %d) that this build cannot convert. The save has not been changed." % from_version)


func _result(status: String, data: Dictionary, from_version: int, message: String) -> Dictionary:
	return {"status": status, "data": data, "message": message, "from_version": from_version}


## Reads and checks one file: {status: ok|missing|corrupt|newer, version, data}.
func _read_file(file_path: String) -> Dictionary:
	var out := {"status": "corrupt", "version": 0, "data": {}}
	if not FileAccess.file_exists(file_path):
		out["status"] = "missing"
		return out
	var text := FileAccess.get_file_as_string(file_path)
	var newline := text.find("\n")
	if newline < 0:
		return out
	var header := text.substr(0, newline).split(" ")
	var body := text.substr(newline + 1)
	if header.size() != 3 or header[0] != FORMAT or not header[1].is_valid_int():
		return out
	var file_version := header[1].to_int()
	if file_version < 1:
		return out
	out["version"] = file_version
	if file_version > version:
		out["status"] = "newer"
		return out
	if body.sha256_text() != header[2]:
		return out
	var json := JSON.new()
	if json.parse(body) != OK:
		return out
	_bad = false
	var decoded: Variant = _decode(json.data, 0)
	if _bad or not decoded is Dictionary:
		return out
	out["status"] = "ok"
	out["data"] = decoded
	return out


func _write(file_path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: cannot write %s (%s)" % [file_path, error_string(FileAccess.get_open_error())])
		return false
	var stored := file.store_string(text)
	file.close()
	return stored and file.get_error() == OK


## Turns a value into JSON-safe form. Sets _bad when something cannot be saved
## exactly, so a saved null and a failure stay distinguishable.
func _encode(value: Variant, depth: int) -> Variant:
	if depth > MAX_DEPTH:
		return _refuse("data nested deeper than %d" % MAX_DEPTH)
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return value
		TYPE_INT:
			return {"$i": str(value)} if value > MAX_PLAIN_INT or value < -MAX_PLAIN_INT else value
		TYPE_FLOAT:
			if is_nan(value) or is_inf(value):
				return _refuse("NaN and infinity cannot be saved")
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0, value)
			return {"$f": bytes.hex_encode()}
		TYPE_ARRAY:
			var list := []
			for item in value:
				list.append(_encode(item, depth + 1))
			return list
		TYPE_DICTIONARY:
			var map := {}
			for key in value:
				if typeof(key) != TYPE_STRING or (key as String).begins_with("$"):
					return _refuse("keys must be strings that do not start with $ (got %s)" % [key])
				map[key] = _encode(value[key], depth + 1)
			return map
	return _refuse("cannot save a value of type %s" % type_string(typeof(value)))


func _refuse(reason: String) -> Variant:
	push_warning("SaveService: " + reason)
	_bad = true
	return null


## Reverses _encode on parsed JSON. Sets _bad for anything _encode could not
## have written, and the file is then treated as corrupt.
func _decode(value: Variant, depth: int) -> Variant:
	if depth > MAX_DEPTH:
		return _fail()
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return value
		TYPE_FLOAT:
			# JSON parses every plain number as a float; only whole numbers were written plain.
			if value != floorf(value) or absf(value) > MAX_PLAIN_INT:
				return _fail()
			return int(value)
		TYPE_ARRAY:
			var list := []
			for item in value:
				list.append(_decode(item, depth + 1))
			return list
		TYPE_DICTIONARY:
			if value.size() == 1 and value.has("$f"):
				var hex := str(value["$f"])
				if hex.length() != 16 or not hex.is_valid_hex_number(false):
					return _fail()
				return hex.hex_decode().decode_double(0)
			if value.size() == 1 and value.has("$i"):
				var text := str(value["$i"])
				return text.to_int() if text.is_valid_int() and (text.to_int() > MAX_PLAIN_INT or text.to_int() < -MAX_PLAIN_INT) else _fail()
			var map := {}
			for key in value:
				if (key as String).begins_with("$"):
					return _fail()
				map[key] = _decode(value[key], depth + 1)
			return map
	return _fail()


func _fail() -> Variant:
	_bad = true
	return null
