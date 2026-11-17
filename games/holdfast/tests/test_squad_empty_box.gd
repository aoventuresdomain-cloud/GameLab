extends KitTestCase
## Follow-up F-new1 to quick fix 14c-a: with nobody hired the Squad page shows no empty name box (or
## its Add to squad button), and the box comes back once a Recruit is hired.

const Main := preload("res://scenes/main.tscn")


func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


func test_no_recruits_means_no_empty_name_box_and_one_hire_brings_it_back() -> void:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	var profile: HoldfastProfile = main.get_node("Profile")
	ThroughLevelZero.apply(profile)
	profile.data["gold"] = 100000
	profile.changed.emit()
	main.call("_show", main.Screen.RECRUITS)
	await _settle()
	var page: Control = main.recruits_page
	expect_true(profile.get_recruits().is_empty(), "a save with nobody hired")
	expect_false(page._detail_name.visible, "no empty name box")
	expect_false(page._squad_button.visible, "and no Add to squad button")
	profile.hire(0)
	profile.changed.emit()
	await _settle()
	expect_false(profile.get_recruits().is_empty(), "a Recruit is hired")
	expect_true(page._detail_name.visible, "the name box is back")
	expect_true(page._squad_button.visible, "and the squad button")
	main.free()
