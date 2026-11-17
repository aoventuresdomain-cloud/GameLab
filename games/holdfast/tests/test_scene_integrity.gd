extends KitTestCase
## F-183: a merge once left two Rails and two HeroName labels in the Map scene. No scene file may name
## the same node twice under one parent, and each hub screen has exactly one rail.

const HUBS := [
	"res://scenes/ui/journey_map.tscn", "res://scenes/ui/keep_screen.tscn", "res://scenes/ui/hero_page.tscn",
	"res://scenes/ui/recruits_page.tscn", "res://scenes/ui/menu_screen.tscn",
]


func _scenes(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scenes(dir.path_join(sub)))
	return out


func test_no_scene_names_a_node_twice_under_the_same_parent() -> void:
	var scenes := _scenes("res://scenes")
	expect_true(scenes.size() > 10, "the scan found %d scenes" % scenes.size())
	var re := RegEx.create_from_string("(?m)^\\[node name=\"([^\"]+)\"(?: type=\"[^\"]*\")?(?: parent=\"([^\"]*)\")?")
	var repeated := []
	for path in scenes:
		var seen := {}
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			var key := "%s/%s" % [m.get_string(2), m.get_string(1)]
			if seen.has(key):
				repeated.append("%s: %s" % [path, key])
			seen[key] = true
	expect_eq(repeated, [], "nodes named twice")


func test_each_hub_screen_has_exactly_one_rail() -> void:
	for path in HUBS:
		var screen: Node = load(path).instantiate()
		tree.root.add_child(screen)
		var rails := screen.find_children("*", "HubRail", true, false)
		expect_eq(rails.size(), 1, "%s has one rail" % path)
		screen.free()


func test_the_map_has_one_hero_name_and_one_title() -> void:
	var map: Node = load("res://scenes/ui/journey_map.tscn").instantiate()
	tree.root.add_child(map)
	expect_eq(map.find_children("HeroName", "", true, false).size(), 1)
	expect_eq(map.find_children("Rail", "", true, false).size(), 1)
	map.free()
