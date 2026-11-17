extends KitTestCase
## HF-M2-72 QA fixes (F-172, F-173): the Hero page header shows the profile's gold and stars, and the
## gear slot rows, which can be pressed, are 44 px high with 6 px between them.

const Main := preload("res://scenes/main.tscn")


func _main() -> Node:
	var main := Main.instantiate()
	main.get_node("RunSource").auto_step = false
	tree.root.add_child(main)
	tree.root.size = Vector2i(1280, 720)
	return main


func test_the_hero_page_header_shows_the_gold_and_stars_the_profile_has() -> void:
	var main := _main()
	var profile: HoldfastProfile = main.get_node("Profile")
	profile.data["gold"] = 1234
	profile.data["stars"]["first_watch"] = 5
	profile.changed.emit()
	main.call("_show", main.Screen.HERO)
	await tree.process_frame
	var page: Control = main.hero_page
	expect_eq(page.get_node("%GoldValue").text, page.Hud.format_number(1234), "the gold is not 0")
	expect_eq(page.get_node("%StarsValue").text, str(profile.get_stars()), "nor the stars")
	expect_true(profile.get_stars() >= 5, "and the profile does hold stars")
	profile.data["gold"] = 80
	profile.changed.emit()
	expect_eq(page.get_node("%GoldValue").text, "80", "and it follows a change")
	main.free()


func test_the_gear_slots_are_44_px_high_and_6_px_apart() -> void:
	var main := _main()
	main.call("_show", main.Screen.HERO)
	await tree.process_frame
	await tree.process_frame
	var rows: Array = main.hero_page.get_node("%SlotColumn").get_children()
	expect_eq(rows.size(), 5, "five slots")
	var view := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for i in rows.size():
		expect_true(rows[i].size.y >= 44.0, "slot %d is %s high" % [i, rows[i].size.y])
		expect_true(view.encloses(rows[i].get_global_rect()), "slot %d is on screen" % i)
		for j in range(i + 1, rows.size()):
			var a: Rect2 = rows[i].get_global_rect()
			var b: Rect2 = rows[j].get_global_rect()
			var gap := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), maxf(a.position.y - b.end.y, b.position.y - a.end.y))
			expect_true(gap >= 6.0, "slots %d and %d are %s apart" % [i, j, gap])
	main.free()
