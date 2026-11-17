extends KitTestCase
## HF-M2-80: the game is called Fogwatch. No player-facing text still says Holdfast (the shipped UI
## scenes, the UI scripts' strings, the content pack, the window title), and the internal names stay, so
## an old save and old settings file still load.

const SCAN_DIRS := ["res://scenes", "res://scripts/ui", "res://content"]
const OLD_NAME := "Holdfast"


func _files(dir: String, out: Array) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["tscn", "gd", "json"]:
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		_files(dir.path_join(sub), out)


## A quoted string that says the old name as a word (class names such as HoldfastMeta are not words).
func _left_over(path: String) -> Array:
	var regex := RegEx.create_from_string("\"[^\"\\n]*\\bHoldfast\\b[^\"\\n]*\"")
	var found := []
	var text := FileAccess.get_file_as_string(path)
	for hit in regex.search_all(text):
		found.append(hit.get_string())
	return found


func test_no_shipped_text_still_says_the_old_name() -> void:
	var files := []
	for dir in SCAN_DIRS:
		_files(dir, files)
	expect_true(files.size() > 20, "the scan found the files (%d)" % files.size())
	for path in files:
		expect_eq(_left_over(path), [], "%s has no %s in a string" % [path, OLD_NAME])
	expect_eq(ProjectSettings.get_setting("application/config/name"), "Fogwatch", "the window title")


func test_the_home_title_and_the_win_line_say_fogwatch() -> void:
	var home: String = FileAccess.get_file_as_string("res://scenes/ui/home_screen.tscn")
	expect_true(home.contains("text = \"Fogwatch\""), "home title")
	var summary: String = FileAccess.get_file_as_string("res://scripts/ui/run_summary.gd")
	expect_true(summary.contains("\"Fogwatch holds!\""), "win line")


func test_the_save_files_keep_their_names_and_an_old_save_still_loads() -> void:
	expect_eq(HoldfastProfile.DEFAULT_PATH, "user://holdfast_profile.sav", "profile file name unchanged")
	expect_eq(HoldfastSettings.DEFAULT_PATH, "user://holdfast_settings.sav", "settings file name unchanged")
	var path := "user://fogwatch_rename_test.sav"
	var profile := HoldfastProfile.new()
	profile.save_path = path
	tree.root.add_child(profile)
	profile.data["gold"] = 77
	profile._save()
	profile.free()
	var again := HoldfastProfile.new()
	again.save_path = path
	tree.root.add_child(again)
	expect_eq(again.load_status, "ok", "a real JSON save loads")
	expect_eq(int(again.data["gold"]), 77, "and keeps what it held")
	again.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
